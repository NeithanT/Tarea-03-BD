USE Tarea03;
GO

SET NOCOUNT ON;
GO

-- ===========================================================================
-- SP_ProcesarFechaOperacion
-- Simula la operacion diaria del sistema de planilla obrera.
-- Procesa nodos del XML de operaciones para una fecha dada (o todas si NULL).
-- Llamado: por la API con fecha especifica, o desde este script con NULL
--          para correr la simulacion completa.
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.SP_ProcesarFechaOperacion
    @FechaOperacion   DATE          = NULL
    , @XmlOperaciones XML           = NULL
    , @RutaArchivo    NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- -----------------------------------------------------------------------
    -- Variables generales (declaradas al inicio: SQL Server no acepta
    -- DECLARE dentro de bloques de control para variables de usuario)
    -- -----------------------------------------------------------------------
    DECLARE @FechaActual        DATE;
    DECLARE @FechaStr           NVARCHAR(20);
    DECLARE @ISODay             INT;
    DECLARE @EsJueves           BIT;
    DECLARE @EsDomingo          BIT;
    DECLARE @EsFeriado          BIT;
    DECLARE @EsDomingoOFeriado  BIT;

    -- Semana (Vie-Jue)
    DECLARE @DaysFromFri  INT;
    DECLARE @WeekStart    DATE;
    DECLARE @WeekEnd      DATE;
    DECLARE @idSemana     INT;
    DECLARE @NumSemana    INT;
    DECLARE @AnoSemana    INT;

    -- Mes
    DECLARE @MesNumero  INT;
    DECLARE @MesAno     INT;
    DECLARE @idMes      INT;

    -- Deduccion
    DECLARE @FechaInicioDeduccion DATE;

    -- Asistencia (por empleado)
    DECLARE @cedula          VARCHAR(20);
    DECLARE @dtEntradaStr    NVARCHAR(20);
    DECLARE @dtSalidaStr     NVARCHAR(20);
    DECLARE @dtEntrada       DATETIME;
    DECLARE @dtSalida        DATETIME;
    DECLARE @idEmp           INT;
    DECLARE @salarioXHora    DECIMAL(10, 2);
    DECLARE @idTipoJornada   INT;
    DECLARE @horaInicioJorn  TIME(0);
    DECLARE @horaFinJorn     TIME(0);
    DECLARE @idPlanilla      INT;
    DECLARE @idPlanillaSem   INT;
    DECLARE @jornadaFinDT    DATETIME;
    DECLARE @minutosTotales  INT;
    DECLARE @minutosOrd      INT;
    DECLARE @minutosExtra    INT;
    DECLARE @horasOrd        INT;
    DECLARE @horasExtraNorm  INT;
    DECLARE @horasExtraDob   INT;
    DECLARE @idHorarioJorn   INT;
    DECLARE @idAsistencia    INT;
    DECLARE @tmOrdinario     INT;
    DECLARE @tmExtraNorm     INT;
    DECLARE @tmExtraDoble    INT;
    DECLARE @montoOrd        DECIMAL(10, 2);
    DECLARE @montoExtraNorm  DECIMAL(10, 2);
    DECLARE @montoExtraDob   DECIMAL(10, 2);

    -- Cierre de semana (jueves)
    DECLARE @idEmpClose         INT;
    DECLARE @idPlanillaClose    INT;
    DECLARE @idPlanillaSemClose INT;
    DECLARE @ingresoBruto       DECIMAL(10, 2);
    DECLARE @totalDed           DECIMAL(10, 2);
    DECLARE @lastDayMes         DATE;
    DECLARE @lastDayISO         INT;
    DECLARE @lastJuevesMes      DATE;
    DECLARE @prevLastDay        DATE;
    DECLARE @prevLastDayISO     INT;
    DECLARE @monthPayStart      DATE;
    DECLARE @numJueves          INT;
    DECLARE @idPlanillaMens     INT;

    -- Iteradores de bucle (reemplazan cursores)
    DECLARE @CurrentDateRow INT;
    DECLARE @MaxDateRow     INT;
    DECLARE @AsistRow       INT;
    DECLARE @MaxAsistRow    INT;
    DECLARE @CloseRow       INT;
    DECLARE @MaxCloseRow    INT;

    BEGIN TRY

        -- Tabla de fechas a procesar (orden ascendente)
        CREATE TABLE #TempDates (
            RowNum      INT IDENTITY(1,1) PRIMARY KEY
            , FechaActual DATE
        );
        CREATE TABLE #TempAsist (
            Id        INT IDENTITY(1,1) PRIMARY KEY
            , Cedula  VARCHAR(20)
            , Entrada NVARCHAR(20)
            , Salida  NVARCHAR(20)
        );
        CREATE TABLE #TempClose (
            Id              INT IDENTITY(1,1) PRIMARY KEY
            , idEmp         INT
            , idPlanilla    INT
            , idPlanillaSem INT
        );

        -- Lookup de TipoMovimiento (una sola vez)
        SELECT @tmOrdinario  = id FROM dbo.TipoMovimiento WHERE Nombre = 'Credito Horas Ordinarias';
        SELECT @tmExtraNorm  = id FROM dbo.TipoMovimiento WHERE Nombre = 'Credito Horas Extra Normales';
        SELECT @tmExtraDoble = id FROM dbo.TipoMovimiento WHERE Nombre = 'Credito Horas Extra Dobles';

        -- ===================================================================
        -- Poblar lista de fechas a procesar en orden ascendente
        -- ===================================================================
        INSERT INTO #TempDates (FechaActual)
        SELECT DISTINCT TRY_CAST(FechaOp.value('@Fecha', 'NVARCHAR(20)') AS DATE)
        FROM @XmlOperaciones.nodes('/Operaciones/FechaOperacion') T(FechaOp)
        WHERE @FechaOperacion IS NULL
           OR TRY_CAST(FechaOp.value('@Fecha', 'NVARCHAR(20)') AS DATE) = @FechaOperacion
        ORDER BY 1;

        SET @CurrentDateRow = 1;
        SELECT @MaxDateRow = COUNT(*) FROM #TempDates;

        WHILE @CurrentDateRow <= @MaxDateRow
        BEGIN
            SELECT @FechaActual = FechaActual FROM #TempDates WHERE RowNum = @CurrentDateRow;
            SET @FechaStr = CONVERT(NVARCHAR(10), @FechaActual, 120); -- 'YYYY-MM-DD'

            BEGIN TRANSACTION;

            -- ---------------------------------------------------------------
            -- Dia de semana y flags
            -- ---------------------------------------------------------------
            SET @ISODay = (DATEPART(dw, @FechaActual) + @@DATEFIRST - 2) % 7 + 1;
            -- 1=Lun, 2=Mar, 3=Mie, 4=Jue, 5=Vie, 6=Sab, 7=Dom
            SET @EsJueves          = CASE WHEN @ISODay = 4 THEN 1 ELSE 0 END;
            SET @EsDomingo         = CASE WHEN @ISODay = 7 THEN 1 ELSE 0 END;
            SET @EsFeriado         = CASE WHEN EXISTS (
                SELECT 1 FROM dbo.Feriado WHERE Fecha = @FechaActual
            ) THEN 1 ELSE 0 END;
            SET @EsDomingoOFeriado = CASE WHEN @EsDomingo = 1 OR @EsFeriado = 1 THEN 1 ELSE 0 END;

            -- ---------------------------------------------------------------
            -- Semana de planilla: Vie - Jue
            -- DaysFromFri: Vie=0, Sab=1, Dom=2, Lun=3, Mar=4, Mie=5, Jue=6
            -- ---------------------------------------------------------------
            SET @DaysFromFri = (@ISODay - 5 + 7) % 7;
            SET @WeekStart   = DATEADD(DAY, -@DaysFromFri, @FechaActual);
            SET @WeekEnd     = DATEADD(DAY,  6,            @WeekStart);

            -- ---------------------------------------------------------------
            -- Asegurar Mes
            -- ---------------------------------------------------------------
            SET @MesNumero = MONTH(@FechaActual);
            SET @MesAno    = YEAR(@FechaActual);
            SET @idMes     = NULL;

            SELECT @idMes = id FROM dbo.Mes
            WHERE Numero = @MesNumero AND Ano = @MesAno;

            IF @idMes IS NULL
            BEGIN
                INSERT INTO dbo.Mes (Numero, Ano, FechaInicio, FechaFin)
                VALUES (
                    @MesNumero, @MesAno
                    , DATEFROMPARTS(@MesAno, @MesNumero, 1)
                    , EOMONTH(@FechaActual)
                );
                SET @idMes = SCOPE_IDENTITY();
            END

            -- ---------------------------------------------------------------
            -- Asegurar Semana actual
            -- ---------------------------------------------------------------
            SET @NumSemana = DATEPART(ISO_WEEK, @WeekStart);
            SET @AnoSemana = YEAR(@WeekStart);
            SET @idSemana  = NULL;

            SELECT @idSemana = id FROM dbo.Semana
            WHERE NumeroSemana = @NumSemana AND Ano = @AnoSemana;

            IF @idSemana IS NULL
            BEGIN
                INSERT INTO dbo.Semana (NumeroSemana, Ano, FechaInicio, FechaFin, idMes)
                VALUES (@NumSemana, @AnoSemana, @WeekStart, @WeekEnd, @idMes);
                SET @idSemana = SCOPE_IDENTITY();
            END

            -- ---------------------------------------------------------------
            -- AsignarJornada: crear Mes y Semana del PROXIMO periodo si faltan
            -- (ocurre jueves cuando InicioSemana es el viernes siguiente)
            -- ---------------------------------------------------------------
            INSERT INTO dbo.Mes (Numero, Ano, FechaInicio, FechaFin)
            SELECT DISTINCT
                MONTH(InicioSem), YEAR(InicioSem)
                , DATEFROMPARTS(YEAR(InicioSem), MONTH(InicioSem), 1)
                , EOMONTH(InicioSem)
            FROM (
                SELECT TRY_CAST(Semana.value('@InicioSemana', 'NVARCHAR(20)') AS DATE) AS InicioSem
                FROM @XmlOperaciones.nodes(
                    '/Operaciones/FechaOperacion[@Fecha=sql:variable("@FechaStr")]/AsignarJornada'
                ) T(Semana)
            ) Sub
            WHERE InicioSem IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1 FROM dbo.Mes m2
                  WHERE m2.Numero = MONTH(InicioSem) AND m2.Ano = YEAR(InicioSem)
              );

            INSERT INTO dbo.Semana (NumeroSemana, Ano, FechaInicio, FechaFin, idMes)
            SELECT DISTINCT
                DATEPART(ISO_WEEK, InicioSem)
                , YEAR(InicioSem)
                , InicioSem
                , DATEADD(DAY, 6, InicioSem)
                , (SELECT TOP 1 m3.id FROM dbo.Mes m3
                   WHERE m3.Numero = MONTH(InicioSem) AND m3.Ano = YEAR(InicioSem))
            FROM (
                SELECT TRY_CAST(Semana.value('@InicioSemana', 'NVARCHAR(20)') AS DATE) AS InicioSem
                FROM @XmlOperaciones.nodes(
                    '/Operaciones/FechaOperacion[@Fecha=sql:variable("@FechaStr")]/AsignarJornada'
                ) T(Semana)
            ) Sub
            WHERE InicioSem IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1 FROM dbo.Semana s2 WHERE s2.FechaInicio = InicioSem
              );

            -- ---------------------------------------------------------------
            -- InsertarEmpleado (trigger crea deducciones obligatorias)
            -- ---------------------------------------------------------------
            INSERT INTO dbo.Empleado (
                Cedula, Nombre, Apellido, FechaIngreso, FechaNacimiento, idPuesto, Activo
            )
            SELECT
                Empleado.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
                -- Nombre = todo antes del ultimo espacio; Apellido = ultima palabra
                , CASE
                    WHEN CHARINDEX(' ', RTRIM(Empleado.value('@Nombre', 'VARCHAR(255)'))) > 0
                    THEN LEFT(
                        Empleado.value('@Nombre', 'VARCHAR(255)'),
                        LEN(Empleado.value('@Nombre', 'VARCHAR(255)'))
                            - CHARINDEX(' ', REVERSE(RTRIM(Empleado.value('@Nombre', 'VARCHAR(255)'))))
                    )
                    ELSE Empleado.value('@Nombre', 'VARCHAR(255)')
                  END
                , CASE
                    WHEN CHARINDEX(' ', RTRIM(Empleado.value('@Nombre', 'VARCHAR(255)'))) > 0
                    THEN RIGHT(
                        Empleado.value('@Nombre', 'VARCHAR(255)'),
                        CHARINDEX(' ', REVERSE(RTRIM(Empleado.value('@Nombre', 'VARCHAR(255)')))) - 1
                    )
                    ELSE ''
                  END
                , ISNULL(
                    TRY_CAST(Empleado.value('@FechaContratacion', 'NVARCHAR(20)') AS DATE),
                    CAST(GETDATE() AS DATE)
                  )
                , NULL
                , (SELECT p.id FROM dbo.Puesto p
                   WHERE p.Nombre = Empleado.value('@Puesto', 'VARCHAR(255)'))
                , 1
            FROM @XmlOperaciones.nodes(
                '/Operaciones/FechaOperacion[@Fecha=sql:variable("@FechaStr")]/InsertarEmpleado'
            ) T(Empleado)
            WHERE NOT EXISTS (
                SELECT 1 FROM dbo.Empleado e2
                WHERE e2.Cedula = Empleado.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
            );

            -- ---------------------------------------------------------------
            -- EliminaEmpleado (baja logica)
            -- ---------------------------------------------------------------
            UPDATE dbo.Empleado
            SET Activo = 0
            WHERE Cedula IN (
                SELECT Empleado.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
                FROM @XmlOperaciones.nodes(
                    '/Operaciones/FechaOperacion[@Fecha=sql:variable("@FechaStr")]/EliminaEmpleado'
                ) T(Empleado)
            );

            -- ---------------------------------------------------------------
            -- AsociaEmpleadoConDeduccion
            -- Si es jueves, efectiva desde el viernes siguiente
            -- ---------------------------------------------------------------
            SET @FechaInicioDeduccion = CASE
                WHEN @EsJueves = 1 THEN DATEADD(DAY, 1, @FechaActual)
                ELSE @FechaActual
            END;

            INSERT INTO dbo.EmpXTipoDed (
                idEmpleado, idTipoDeduccion, Valor, FechaInicio, FechaFin, Activo
            )
            SELECT
                e.id
                , td.id
                , CASE
                    WHEN TRY_CAST(Deduccion.value('@MontoFijo', 'NVARCHAR(20)') AS DECIMAL(10,4)) = 0
                    THEN td.Valor
                    ELSE TRY_CAST(Deduccion.value('@MontoFijo', 'NVARCHAR(20)') AS DECIMAL(10,4))
                  END
                , @FechaInicioDeduccion
                , NULL
                , 1
            FROM @XmlOperaciones.nodes(
                '/Operaciones/FechaOperacion[@Fecha=sql:variable("@FechaStr")]/AsociaEmpleadoConDeduccion'
            ) T(Deduccion)
            INNER JOIN dbo.Empleado e
                ON e.Cedula = Deduccion.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
                AND e.Activo = 1
            INNER JOIN dbo.TipoDeduccion td
                ON td.Nombre = Deduccion.value('@TipoDeduccion', 'VARCHAR(100)')
            WHERE NOT EXISTS (
                SELECT 1 FROM dbo.EmpXTipoDed etd2
                WHERE etd2.idEmpleado = e.id
                  AND etd2.idTipoDeduccion = td.id
                  AND etd2.Activo = 1
            );

            -- ---------------------------------------------------------------
            -- DesasociaEmpleadoConDeduccion
            -- ---------------------------------------------------------------
            UPDATE etd
            SET etd.Activo   = 0
              , etd.FechaFin = @FechaActual
            FROM dbo.EmpXTipoDed etd
            INNER JOIN dbo.Empleado e
                ON e.id = etd.idEmpleado
            INNER JOIN dbo.TipoDeduccion td
                ON td.id = etd.idTipoDeduccion
            WHERE etd.Activo = 1
              AND EXISTS (
                SELECT 1
                FROM @XmlOperaciones.nodes(
                    '/Operaciones/FechaOperacion[@Fecha=sql:variable("@FechaStr")]/DesasociaEmpleadoConDeduccion'
                ) T(Deduccion)
                WHERE e.Cedula  = Deduccion.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
                  AND td.Nombre = Deduccion.value('@TipoDeduccion', 'VARCHAR(100)')
            );

            -- ---------------------------------------------------------------
            -- AsignarJornada: insertar HorarioJornada para los 7 dias
            -- ---------------------------------------------------------------
            INSERT INTO dbo.HorarioJornada (
                idEmpleado, idSemana, idTipoJornada, DiaSemana, EsDiaDescanso
            )
            SELECT
                e.id
                , s.id
                , tj.id
                , d.DiaSemana
                , 0
            FROM @XmlOperaciones.nodes(
                '/Operaciones/FechaOperacion[@Fecha=sql:variable("@FechaStr")]/AsignarJornada'
            ) T(Semana)
            INNER JOIN dbo.Empleado e
                ON e.Cedula = Semana.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
                AND e.Activo = 1
            INNER JOIN dbo.TipoJornada tj
                ON tj.Nombre = Semana.value('@Jornada', 'VARCHAR(50)')
            INNER JOIN dbo.Semana s
                ON s.FechaInicio = TRY_CAST(Semana.value('@InicioSemana', 'NVARCHAR(20)') AS DATE)
            CROSS JOIN (VALUES (1),(2),(3),(4),(5),(6),(7)) d(DiaSemana)
            WHERE NOT EXISTS (
                SELECT 1 FROM dbo.HorarioJornada hj2
                WHERE hj2.idEmpleado = e.id
                  AND hj2.idSemana   = s.id
                  AND hj2.DiaSemana  = d.DiaSemana
            );

            -- ---------------------------------------------------------------
            -- MarcaAsistencia: cargar registros del dia y procesar fila a fila
            -- ---------------------------------------------------------------
            TRUNCATE TABLE #TempAsist;

            INSERT INTO #TempAsist (Cedula, Entrada, Salida)
            SELECT
                Asistencia.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
                , Asistencia.value('@HoraEntrada', 'NVARCHAR(20)')
                , Asistencia.value('@HoraSalida',  'NVARCHAR(20)')
            FROM @XmlOperaciones.nodes(
                '/Operaciones/FechaOperacion[@Fecha=sql:variable("@FechaStr")]/MarcaAsistencia'
            ) T(Asistencia);

            SET @AsistRow = 1;
            SELECT @MaxAsistRow = ISNULL(MAX(Id), 0) FROM #TempAsist;

            WHILE @AsistRow <= @MaxAsistRow
            BEGIN
                SELECT
                    @cedula       = Cedula
                    , @dtEntradaStr = Entrada
                    , @dtSalidaStr  = Salida
                FROM #TempAsist WHERE Id = @AsistRow;

                SET @dtEntrada = TRY_CAST(@dtEntradaStr AS DATETIME);
                SET @dtSalida  = TRY_CAST(@dtSalidaStr  AS DATETIME);
                SET @idEmp     = NULL;

                SELECT @idEmp = e.id, @salarioXHora = p.SalarioPorHora
                FROM dbo.Empleado e
                INNER JOIN dbo.Puesto p ON p.id = e.idPuesto
                WHERE e.Cedula = @cedula AND e.Activo = 1;

                IF @idEmp IS NOT NULL AND @dtEntrada IS NOT NULL AND @dtSalida IS NOT NULL
                BEGIN
                    -- Jornada del empleado en este dia de la semana
                    SET @idTipoJornada  = NULL;
                    SET @horaInicioJorn = NULL;
                    SET @horaFinJorn    = NULL;

                    SELECT
                        @idTipoJornada  = hj.idTipoJornada
                        , @horaInicioJorn = tj.HoraInicio
                        , @horaFinJorn    = tj.HoraFin
                        , @idHorarioJorn  = hj.id
                    FROM dbo.HorarioJornada hj
                    INNER JOIN dbo.TipoJornada tj ON tj.id = hj.idTipoJornada
                    WHERE hj.idEmpleado = @idEmp
                      AND hj.idSemana   = @idSemana
                      AND hj.DiaSemana  = @ISODay;

                    -- Asegurar Planilla + PlanillaSemanal para este empleado/semana
                    SET @idPlanilla    = NULL;
                    SET @idPlanillaSem = NULL;

                    SELECT @idPlanilla = p.id, @idPlanillaSem = ps.id
                    FROM dbo.Planilla p
                    INNER JOIN dbo.PlanillaSemanal ps ON ps.idPlanilla = p.id
                    WHERE p.idEmpleado = @idEmp AND ps.idSemana = @idSemana;

                    IF @idPlanilla IS NULL
                    BEGIN
                        INSERT INTO dbo.Planilla (
                            idEmpleado, FechaPago, IngresoBruto, TotalDeducciones, Observaciones
                        )
                        VALUES (@idEmp, @WeekEnd, 0, 0, NULL);
                        SET @idPlanilla = SCOPE_IDENTITY();

                        INSERT INTO dbo.PlanillaSemanal (idPlanilla, idSemana)
                        VALUES (@idPlanilla, @idSemana);
                        SET @idPlanillaSem = SCOPE_IDENTITY();
                    END

                    -- Calcular fin de jornada como DATETIME
                    -- Para jornada nocturna (HoraFin < HoraInicio) el fin es al dia siguiente
                    IF @horaFinJorn IS NOT NULL
                    BEGIN
                        SET @jornadaFinDT = DATETIMEFROMPARTS(
                            CASE WHEN @horaFinJorn <= @horaInicioJorn
                                 THEN YEAR(DATEADD(DAY, 1, CAST(@dtEntrada AS DATE)))
                                 ELSE YEAR(CAST(@dtEntrada AS DATE)) END
                            , CASE WHEN @horaFinJorn <= @horaInicioJorn
                                   THEN MONTH(DATEADD(DAY, 1, CAST(@dtEntrada AS DATE)))
                                   ELSE MONTH(CAST(@dtEntrada AS DATE)) END
                            , CASE WHEN @horaFinJorn <= @horaInicioJorn
                                   THEN DAY(DATEADD(DAY, 1, CAST(@dtEntrada AS DATE)))
                                   ELSE DAY(CAST(@dtEntrada AS DATE)) END
                            , DATEPART(HOUR,   @horaFinJorn)
                            , DATEPART(MINUTE, @horaFinJorn)
                            , 0, 0
                        );
                    END
                    ELSE
                        SET @jornadaFinDT = @dtSalida; -- sin jornada asignada: todo ordinario

                    -- Calcular horas
                    SET @minutosTotales = DATEDIFF(MINUTE, @dtEntrada, @dtSalida);
                    SET @minutosOrd = CASE
                        WHEN @dtSalida <= @jornadaFinDT THEN @minutosTotales
                        ELSE DATEDIFF(MINUTE, @dtEntrada, @jornadaFinDT)
                    END;
                    IF @minutosOrd    < 0 SET @minutosOrd    = 0;
                    SET @minutosExtra = @minutosTotales - @minutosOrd;
                    IF @minutosExtra  < 0 SET @minutosExtra  = 0;

                    SET @horasOrd       = @minutosOrd   / 60; -- solo horas completas
                    SET @horasExtraNorm = 0;
                    SET @horasExtraDob  = 0;

                    IF @EsDomingoOFeriado = 0
                        SET @horasExtraNorm = @minutosExtra / 60;
                    ELSE
                        SET @horasExtraDob  = @minutosExtra / 60;

                    -- Insertar AsistenciaAJornada (idempotente por empleado+fecha)
                    IF NOT EXISTS (
                        SELECT 1 FROM dbo.AsistenciaAJornada
                        WHERE idEmpleado = @idEmp AND Fecha = @FechaActual
                    )
                    BEGIN
                        INSERT INTO dbo.AsistenciaAJornada (
                            idEmpleado, idHorarioJornada, Fecha
                            , HoraEntrada, HoraSalida, HorasTrabajadas, Estado
                        )
                        VALUES (
                            @idEmp, @idHorarioJorn, @FechaActual
                            , CAST(@dtEntrada AS TIME(0))
                            , CAST(@dtSalida  AS TIME(0))
                            , CAST(@minutosTotales / 60.0 AS DECIMAL(5, 2))
                            , 'Registrado'
                        );
                        SET @idAsistencia = SCOPE_IDENTITY();

                        -- Movimientos de planilla
                        SET @montoOrd       = @horasOrd       * @salarioXHora;
                        SET @montoExtraNorm = @horasExtraNorm * @salarioXHora * 1.5;
                        SET @montoExtraDob  = @horasExtraDob  * @salarioXHora * 2.0;

                        IF @horasOrd > 0
                        BEGIN
                            INSERT INTO dbo.MovPlanilla (
                                idPlanillaSemanal, idAsistencia, idTipoMovimiento
                                , Monto, NuevoSaldo, Fecha
                            )
                            VALUES (
                                @idPlanillaSem, @idAsistencia, @tmOrdinario
                                , @horasOrd, @montoOrd, @FechaActual
                            );
                            UPDATE dbo.Planilla
                            SET IngresoBruto = IngresoBruto + @montoOrd
                            WHERE id = @idPlanilla;
                        END

                        IF @horasExtraNorm > 0
                        BEGIN
                            INSERT INTO dbo.MovPlanilla (
                                idPlanillaSemanal, idAsistencia, idTipoMovimiento
                                , Monto, NuevoSaldo, Fecha
                            )
                            VALUES (
                                @idPlanillaSem, @idAsistencia, @tmExtraNorm
                                , @horasExtraNorm, @montoExtraNorm, @FechaActual
                            );
                            UPDATE dbo.Planilla
                            SET IngresoBruto = IngresoBruto + @montoExtraNorm
                            WHERE id = @idPlanilla;
                        END

                        IF @horasExtraDob > 0
                        BEGIN
                            INSERT INTO dbo.MovPlanilla (
                                idPlanillaSemanal, idAsistencia, idTipoMovimiento
                                , Monto, NuevoSaldo, Fecha
                            )
                            VALUES (
                                @idPlanillaSem, @idAsistencia, @tmExtraDoble
                                , @horasExtraDob, @montoExtraDob, @FechaActual
                            );
                            UPDATE dbo.Planilla
                            SET IngresoBruto = IngresoBruto + @montoExtraDob
                            WHERE id = @idPlanilla;
                        END
                    END
                END

                SET @AsistRow = @AsistRow + 1;
            END
            -- Fin WHILE asistencia

            -- ---------------------------------------------------------------
            -- Jueves: cierre de semana — aplicar deducciones a cada empleado
            -- ---------------------------------------------------------------
            IF @EsJueves = 1
            BEGIN
                TRUNCATE TABLE #TempClose;

                INSERT INTO #TempClose (idEmp, idPlanilla, idPlanillaSem)
                SELECT e.id, p.id, ps.id
                FROM dbo.Empleado e
                INNER JOIN dbo.Planilla p ON p.idEmpleado = e.id
                INNER JOIN dbo.PlanillaSemanal ps ON ps.idPlanilla = p.id
                WHERE e.Activo = 1 AND ps.idSemana = @idSemana;

                -- Calcular numero de jueves en el periodo mensual de planilla
                -- Periodo: desde el ultimo viernes del mes anterior
                --          hasta el ultimo jueves del mes actual
                SET @lastDayMes    = EOMONTH(@FechaActual);
                SET @lastDayISO    = (DATEPART(dw, @lastDayMes) + @@DATEFIRST - 2) % 7 + 1;
                SET @lastJuevesMes = DATEADD(DAY, -((@lastDayISO - 4 + 7) % 7), @lastDayMes);

                SET @prevLastDay    = DATEADD(DAY, -1, DATEFROMPARTS(@MesAno, @MesNumero, 1));
                SET @prevLastDayISO = (DATEPART(dw, @prevLastDay) + @@DATEFIRST - 2) % 7 + 1;
                SET @monthPayStart  = DATEADD(DAY, -((@prevLastDayISO - 5 + 7) % 7), @prevLastDay);

                SET @numJueves = (DATEDIFF(DAY, @monthPayStart, @lastJuevesMes) + 1) / 7;
                IF @numJueves < 1 SET @numJueves = 4;

                SET @CloseRow = 1;
                SELECT @MaxCloseRow = ISNULL(MAX(Id), 0) FROM #TempClose;

                WHILE @CloseRow <= @MaxCloseRow
                BEGIN
                    SELECT
                        @idEmpClose         = idEmp
                        , @idPlanillaClose    = idPlanilla
                        , @idPlanillaSemClose = idPlanillaSem
                    FROM #TempClose WHERE Id = @CloseRow;

                    SELECT @ingresoBruto = IngresoBruto
                    FROM dbo.Planilla WHERE id = @idPlanillaClose;

                    SET @totalDed = 0;

                    -- Deducciones porcentuales (sobre el salario bruto semanal)
                    INSERT INTO dbo.MovPlanilla (
                        idPlanillaSemanal, idAsistencia, idTipoMovimiento, Monto, NuevoSaldo, Fecha
                    )
                    SELECT
                        @idPlanillaSemClose
                        , NULL
                        , td.idTipoMovimiento
                        , NULL
                        , CAST(@ingresoBruto * etd.Valor AS DECIMAL(10, 2))
                        , @FechaActual
                    FROM dbo.EmpXTipoDed etd
                    INNER JOIN dbo.TipoDeduccion td ON td.id = etd.idTipoDeduccion
                    WHERE etd.idEmpleado = @idEmpClose
                      AND etd.Activo     = 1
                      AND etd.FechaInicio <= @FechaActual
                      AND (etd.FechaFin IS NULL OR etd.FechaFin >= @FechaActual)
                      AND td.Porcentual   = 1;

                    SELECT @totalDed = @totalDed + ISNULL(SUM(
                        CAST(@ingresoBruto * etd.Valor AS DECIMAL(10, 2))
                    ), 0)
                    FROM dbo.EmpXTipoDed etd
                    INNER JOIN dbo.TipoDeduccion td ON td.id = etd.idTipoDeduccion
                    WHERE etd.idEmpleado = @idEmpClose
                      AND etd.Activo     = 1
                      AND etd.FechaInicio <= @FechaActual
                      AND (etd.FechaFin IS NULL OR etd.FechaFin >= @FechaActual)
                      AND td.Porcentual   = 1;

                    -- Deducciones fijas no obligatorias (monto mensual / numJueves)
                    INSERT INTO dbo.MovPlanilla (
                        idPlanillaSemanal, idAsistencia, idTipoMovimiento, Monto, NuevoSaldo, Fecha
                    )
                    SELECT
                        @idPlanillaSemClose
                        , NULL
                        , td.idTipoMovimiento
                        , NULL
                        , CAST(etd.Valor / @numJueves AS DECIMAL(10, 2))
                        , @FechaActual
                    FROM dbo.EmpXTipoDed etd
                    INNER JOIN dbo.TipoDeduccion td ON td.id = etd.idTipoDeduccion
                    WHERE etd.idEmpleado = @idEmpClose
                      AND etd.Activo     = 1
                      AND etd.FechaInicio <= @FechaActual
                      AND (etd.FechaFin IS NULL OR etd.FechaFin >= @FechaActual)
                      AND td.Porcentual   = 0
                      AND td.Obligatorio  = 0;

                    SELECT @totalDed = @totalDed + ISNULL(SUM(
                        CAST(etd.Valor / @numJueves AS DECIMAL(10, 2))
                    ), 0)
                    FROM dbo.EmpXTipoDed etd
                    INNER JOIN dbo.TipoDeduccion td ON td.id = etd.idTipoDeduccion
                    WHERE etd.idEmpleado = @idEmpClose
                      AND etd.Activo     = 1
                      AND etd.FechaInicio <= @FechaActual
                      AND (etd.FechaFin IS NULL OR etd.FechaFin >= @FechaActual)
                      AND td.Porcentual   = 0
                      AND td.Obligatorio  = 0;

                    -- Actualizar TotalDeducciones de la planilla semanal
                    UPDATE dbo.Planilla
                    SET TotalDeducciones = TotalDeducciones + @totalDed
                    WHERE id = @idPlanillaClose;

                    -- Asegurar PlanillaMensual para este empleado/mes
                    SET @idPlanillaMens = NULL;

                    SELECT @idPlanillaMens = pm.idPlanilla
                    FROM dbo.PlanillaMensual pm
                    INNER JOIN dbo.Planilla p2 ON p2.id = pm.idPlanilla
                    WHERE p2.idEmpleado = @idEmpClose AND pm.idMes = @idMes;

                    IF @idPlanillaMens IS NULL
                    BEGIN
                        INSERT INTO dbo.Planilla (
                            idEmpleado, FechaPago, IngresoBruto, TotalDeducciones, Observaciones
                        )
                        VALUES (@idEmpClose, @lastJuevesMes, 0, 0, 'Planilla mensual');
                        SET @idPlanillaMens = SCOPE_IDENTITY();

                        INSERT INTO dbo.PlanillaMensual (idPlanilla, idMes)
                        VALUES (@idPlanillaMens, @idMes);
                    END

                    -- Acumular en planilla mensual
                    UPDATE dbo.Planilla
                    SET IngresoBruto     = IngresoBruto     + @ingresoBruto
                      , TotalDeducciones = TotalDeducciones + @totalDed
                    WHERE id = @idPlanillaMens;

                    SET @CloseRow = @CloseRow + 1;
                END
                -- Fin WHILE cierre
            END
            -- Fin bloque jueves

            COMMIT TRANSACTION;

            SET @CurrentDateRow = @CurrentDateRow + 1;
        END
        -- Fin WHILE fechas

        DROP TABLE #TempDates;
        DROP TABLE #TempAsist;
        DROP TABLE #TempClose;

    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#TempDates') IS NOT NULL DROP TABLE #TempDates;
        IF OBJECT_ID('tempdb..#TempAsist') IS NOT NULL DROP TABLE #TempAsist;
        IF OBJECT_ID('tempdb..#TempClose') IS NOT NULL DROP TABLE #TempClose;

        IF (XACT_STATE() <> 0) ROLLBACK TRANSACTION;

        INSERT INTO dbo.DBError (
            Username, [Number], [State], Severity, [Line], [Procedure], [Message], [DateTime]
        )
        VALUES (
            SUSER_SNAME()
            , ERROR_NUMBER()
            , ERROR_STATE()
            , ERROR_SEVERITY()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
            , ERROR_MESSAGE()
            , GETDATE()
        );

        THROW;
    END CATCH
END;
GO


-- ===========================================================================
-- Carga inicial: ejecutar la simulacion con el XML de Operaciones
-- ===========================================================================

DECLARE @myXml XML = N'<?xml version="1.0" encoding="UTF-8"?>
<Operaciones>

    <!-- ============================================================
         JUEVES 2026-03-05: inserción de empleados iniciales
         y jornada para semana 1 (inicia 2026-03-06)
    ============================================================ -->
    <FechaOperacion Fecha="2026-03-05">
        <InsertarEmpleado ValorDocumentoIdentidad="110011001" Nombre="Carlos Mendoza"
            Puesto="Electricista" CuentaBancaria="CR2415115201001026284066"
            Username="Mencar" Password="Gojira" TipoUsuario="0" FechaContratacion="2026-03-06"/>
        <InsertarEmpleado ValorDocumentoIdentidad="305827920" Nombre="Ana Rodriguez"
            Puesto="Cajero" CuentaBancaria="CR2415115201901026284067"
            Username="Rodana" Password="Seguridad" TipoUsuario="0" FechaContratacion="2026-03-06"/>
        <InsertarEmpleado ValorDocumentoIdentidad="194739285" Nombre="Nicolas Vargas"
            Puesto="Conductor" CuentaBancaria="CR2415115201901026392748"
            Username="Varnic" Password="EndgamE" TipoUsuario="0" FechaContratacion="2026-03-06"/>
        <InsertarEmpleado ValorDocumentoIdentidad="222333444" Nombre="Laura Castro"
            Puesto="Recepcionista" CuentaBancaria="CR2415115201901026111001"
            Username="Caslaur" Password="Laura123" TipoUsuario="0" FechaContratacion="2026-03-06"/>
        <InsertarEmpleado ValorDocumentoIdentidad="333444555" Nombre="Pedro Arias"
            Puesto="Fontanero" CuentaBancaria="CR2415115201901026111002"
            Username="Ariped" Password="Pedro456" TipoUsuario="0" FechaContratacion="2026-03-06"/>

        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="110011001"
            TipoDeduccion="Ahorro Asociacion Solidarista" MontoFijo="0.00"/>
        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="194739285"
            TipoDeduccion="Pension Alimenticia" MontoFijo="50000.00"/>
        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="222333444"
            TipoDeduccion="Ahorro Vacacional" MontoFijo="20000.00"/>
        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="333444555"
            TipoDeduccion="Ahorro Asociacion Solidarista" MontoFijo="0.00"/>

        <!-- Jornada semana 1 (InicioSemana 2026-03-06) -->
        <AsignarJornada ValorDocumentoIdentidad="110011001"
            Jornada="Diurno" InicioSemana="2026-03-06"/>
        <AsignarJornada ValorDocumentoIdentidad="305827920"
            Jornada="Vespertino" InicioSemana="2026-03-06"/>
        <AsignarJornada ValorDocumentoIdentidad="194739285"
            Jornada="Nocturno" InicioSemana="2026-03-06"/>
        <AsignarJornada ValorDocumentoIdentidad="222333444"
            Jornada="Diurno" InicioSemana="2026-03-06"/>
        <AsignarJornada ValorDocumentoIdentidad="333444555"
            Jornada="Vespertino" InicioSemana="2026-03-06"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-06"> <!-- Viernes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-06 06:00" HoraSalida="2026-03-06 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-06 14:00" HoraSalida="2026-03-07 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-06 22:00" HoraSalida="2026-03-07 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-06 06:00" HoraSalida="2026-03-06 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-06 14:00" HoraSalida="2026-03-06 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-07"> <!-- Sabado -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-07 06:00" HoraSalida="2026-03-07 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-07 14:00" HoraSalida="2026-03-07 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-07 22:00" HoraSalida="2026-03-08 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-07 06:00" HoraSalida="2026-03-07 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-07 14:00" HoraSalida="2026-03-08 00:30"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-08"> <!-- Domingo -->
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-08 14:00" HoraSalida="2026-03-09 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-08 22:00" HoraSalida="2026-03-09 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-08 06:00" HoraSalida="2026-03-08 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-08 14:00" HoraSalida="2026-03-09 01:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-09"> <!-- Lunes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-09 06:00" HoraSalida="2026-03-09 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-09 22:00" HoraSalida="2026-03-10 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-09 06:00" HoraSalida="2026-03-09 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-09 14:00" HoraSalida="2026-03-10 00:30"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-10"> <!-- Martes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-10 06:00" HoraSalida="2026-03-10 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-10 14:00" HoraSalida="2026-03-10 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-10 06:00" HoraSalida="2026-03-10 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-10 14:00" HoraSalida="2026-03-10 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-11"> <!-- Miercoles -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-11 06:00" HoraSalida="2026-03-11 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-11 14:00" HoraSalida="2026-03-12 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-11 22:00" HoraSalida="2026-03-12 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-11 14:00" HoraSalida="2026-03-11 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-12"> <!-- Jueves -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-12 06:00" HoraSalida="2026-03-12 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-12 14:00" HoraSalida="2026-03-13 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-12 22:00" HoraSalida="2026-03-13 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-12 06:00" HoraSalida="2026-03-12 14:00"/>

        <!-- Nuevos empleados: inician semana 2026-03-13 -->
        <InsertarEmpleado ValorDocumentoIdentidad="444555666" Nombre="Sofia Mora"
            Puesto="Asistente" CuentaBancaria="CR2415115201901026111003"
            Username="Morsofi" Password="Sofia789" TipoUsuario="0" FechaContratacion="2026-03-13"/>
        <InsertarEmpleado ValorDocumentoIdentidad="555666777" Nombre="Andres Vega"
            Puesto="Electricista" CuentaBancaria="CR2415115201901026111004"
            Username="Vegand" Password="Andres321" TipoUsuario="0" FechaContratacion="2026-03-13"/>

        <!-- Cierre semana 1: jornada semana 2 (InicioSemana 2026-03-13) -->
        <AsignarJornada ValorDocumentoIdentidad="110011001"
            Jornada="Vespertino" InicioSemana="2026-03-13"/>
        <AsignarJornada ValorDocumentoIdentidad="305827920"
            Jornada="Nocturno" InicioSemana="2026-03-13"/>
        <AsignarJornada ValorDocumentoIdentidad="194739285"
            Jornada="Diurno" InicioSemana="2026-03-13"/>
        <AsignarJornada ValorDocumentoIdentidad="222333444"
            Jornada="Vespertino" InicioSemana="2026-03-13"/>
        <AsignarJornada ValorDocumentoIdentidad="333444555"
            Jornada="Nocturno" InicioSemana="2026-03-13"/>
        <AsignarJornada ValorDocumentoIdentidad="444555666"
            Jornada="Diurno" InicioSemana="2026-03-13"/>
        <AsignarJornada ValorDocumentoIdentidad="555666777"
            Jornada="Vespertino" InicioSemana="2026-03-13"/>

        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="305827920"
            TipoDeduccion="Ahorro Vacacional" MontoFijo="25000.00"/>
        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="444555666"
            TipoDeduccion="Pension Alimenticia" MontoFijo="35000.00"/>
        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="555666777"
            TipoDeduccion="Ahorro Vacacional" MontoFijo="15000.00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-13"> <!-- Viernes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-13 14:00" HoraSalida="2026-03-14 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-13 22:00" HoraSalida="2026-03-14 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-13 06:00" HoraSalida="2026-03-13 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-13 14:00" HoraSalida="2026-03-13 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-13 22:00" HoraSalida="2026-03-14 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-03-13 14:00" HoraSalida="2026-03-13 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-14"> <!-- Sabado -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-14 14:00" HoraSalida="2026-03-14 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-14 22:00" HoraSalida="2026-03-15 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-14 06:00" HoraSalida="2026-03-14 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-14 14:00" HoraSalida="2026-03-14 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-14 22:00" HoraSalida="2026-03-15 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-03-14 06:00" HoraSalida="2026-03-14 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-15"> <!-- Domingo -->
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-15 22:00" HoraSalida="2026-03-16 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-15 06:00" HoraSalida="2026-03-15 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-15 14:00" HoraSalida="2026-03-16 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-15 22:00" HoraSalida="2026-03-16 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-03-15 06:00" HoraSalida="2026-03-15 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-03-15 14:00" HoraSalida="2026-03-16 01:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-16"> <!-- Lunes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-16 14:00" HoraSalida="2026-03-16 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-16 06:00" HoraSalida="2026-03-16 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-16 14:00" HoraSalida="2026-03-16 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-16 22:00" HoraSalida="2026-03-17 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-03-16 06:00" HoraSalida="2026-03-16 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-03-16 14:00" HoraSalida="2026-03-16 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-17"> <!-- Martes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-17 14:00" HoraSalida="2026-03-18 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-17 22:00" HoraSalida="2026-03-18 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-17 14:00" HoraSalida="2026-03-18 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-17 22:00" HoraSalida="2026-03-18 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-03-17 06:00" HoraSalida="2026-03-17 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-03-17 14:00" HoraSalida="2026-03-17 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-18"> <!-- Miercoles -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-18 14:00" HoraSalida="2026-03-18 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-18 22:00" HoraSalida="2026-03-19 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-18 06:00" HoraSalida="2026-03-18 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-18 22:00" HoraSalida="2026-03-19 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-03-18 06:00" HoraSalida="2026-03-18 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-03-18 14:00" HoraSalida="2026-03-18 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-19"> <!-- Jueves -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-19 14:00" HoraSalida="2026-03-20 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-19 22:00" HoraSalida="2026-03-20 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-19 06:00" HoraSalida="2026-03-19 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-19 14:00" HoraSalida="2026-03-19 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-03-19 06:00" HoraSalida="2026-03-19 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-03-19 14:00" HoraSalida="2026-03-19 22:00"/>

        <!-- Cierre semana 2: jornada semana 3 (InicioSemana 2026-03-20) -->
        <AsignarJornada ValorDocumentoIdentidad="110011001"
            Jornada="Nocturno" InicioSemana="2026-03-20"/>
        <AsignarJornada ValorDocumentoIdentidad="305827920"
            Jornada="Diurno" InicioSemana="2026-03-20"/>
        <AsignarJornada ValorDocumentoIdentidad="194739285"
            Jornada="Vespertino" InicioSemana="2026-03-20"/>
        <AsignarJornada ValorDocumentoIdentidad="222333444"
            Jornada="Nocturno" InicioSemana="2026-03-20"/>
        <AsignarJornada ValorDocumentoIdentidad="333444555"
            Jornada="Diurno" InicioSemana="2026-03-20"/>
        <AsignarJornada ValorDocumentoIdentidad="444555666"
            Jornada="Vespertino" InicioSemana="2026-03-20"/>
        <AsignarJornada ValorDocumentoIdentidad="555666777"
            Jornada="Nocturno" InicioSemana="2026-03-20"/>

        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="110011001"
            TipoDeduccion="Ahorro Vacacional" MontoFijo="15000.00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-20"> <!-- Viernes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-20 22:00" HoraSalida="2026-03-21 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-20 06:00" HoraSalida="2026-03-20 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-20 14:00" HoraSalida="2026-03-20 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-20 22:00" HoraSalida="2026-03-21 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-20 06:00" HoraSalida="2026-03-20 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-03-20 22:00" HoraSalida="2026-03-21 08:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-21"> <!-- Sabado -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-21 22:00" HoraSalida="2026-03-22 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-21 06:00" HoraSalida="2026-03-21 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-21 14:00" HoraSalida="2026-03-22 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-21 22:00" HoraSalida="2026-03-22 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-21 06:00" HoraSalida="2026-03-21 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-03-21 14:00" HoraSalida="2026-03-21 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-22"> <!-- Domingo -->
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-22 06:00" HoraSalida="2026-03-22 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-22 14:00" HoraSalida="2026-03-23 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-22 22:00" HoraSalida="2026-03-23 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-22 06:00" HoraSalida="2026-03-22 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-03-22 14:00" HoraSalida="2026-03-23 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-03-22 22:00" HoraSalida="2026-03-23 08:30"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-23"> <!-- Lunes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-23 22:00" HoraSalida="2026-03-24 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-23 14:00" HoraSalida="2026-03-23 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-23 22:00" HoraSalida="2026-03-24 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-23 06:00" HoraSalida="2026-03-23 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-03-23 14:00" HoraSalida="2026-03-23 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-03-23 22:00" HoraSalida="2026-03-24 08:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-24"> <!-- Martes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-24 22:00" HoraSalida="2026-03-25 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-24 06:00" HoraSalida="2026-03-24 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-24 22:00" HoraSalida="2026-03-25 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-24 06:00" HoraSalida="2026-03-24 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-03-24 14:00" HoraSalida="2026-03-24 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-03-24 22:00" HoraSalida="2026-03-25 08:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-25"> <!-- Miercoles -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-25 22:00" HoraSalida="2026-03-26 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-25 06:00" HoraSalida="2026-03-25 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-25 14:00" HoraSalida="2026-03-26 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-25 06:00" HoraSalida="2026-03-25 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-03-25 14:00" HoraSalida="2026-03-26 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-03-25 22:00" HoraSalida="2026-03-26 06:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-26"> <!-- Jueves -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-26 22:00" HoraSalida="2026-03-27 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-26 06:00" HoraSalida="2026-03-26 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-26 14:00" HoraSalida="2026-03-27 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-26 22:00" HoraSalida="2026-03-27 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-03-26 14:00" HoraSalida="2026-03-26 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-03-26 22:00" HoraSalida="2026-03-27 06:00"/>

        <!-- Nuevos empleados: inician semana 2026-03-27 -->
        <InsertarEmpleado ValorDocumentoIdentidad="666777888" Nombre="Gabriela Leon"
            Puesto="Cajero" CuentaBancaria="CR2415115201901026111005"
            Username="Leogab" Password="Gaby654" TipoUsuario="0" FechaContratacion="2026-03-27"/>
        
        <!-- Eliminar empleado: termina semana 2026-03-27 -->
        <EliminarEmpleado ValorDocumentoIdentidad="305827920"/>


        <!-- Cierre semana 3: jornada semana 4 (InicioSemana 2026-03-27) -->
        <AsignarJornada ValorDocumentoIdentidad="110011001"
            Jornada="Diurno" InicioSemana="2026-03-27"/>
        <AsignarJornada ValorDocumentoIdentidad="305827920"
            Jornada="Vespertino" InicioSemana="2026-03-27"/>
        <AsignarJornada ValorDocumentoIdentidad="194739285"
            Jornada="Nocturno" InicioSemana="2026-03-27"/>
        <AsignarJornada ValorDocumentoIdentidad="222333444"
            Jornada="Diurno" InicioSemana="2026-03-27"/>
        <AsignarJornada ValorDocumentoIdentidad="333444555"
            Jornada="Vespertino" InicioSemana="2026-03-27"/>
        <AsignarJornada ValorDocumentoIdentidad="444555666"
            Jornada="Nocturno" InicioSemana="2026-03-27"/>
        <AsignarJornada ValorDocumentoIdentidad="555666777"
            Jornada="Diurno" InicioSemana="2026-03-27"/>
        <AsignarJornada ValorDocumentoIdentidad="666777888"
            Jornada="Vespertino" InicioSemana="2026-03-27"/>

        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="194739285"
            TipoDeduccion="Ahorro Asociacion Solidarista" MontoFijo="0.00"/>
        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="666777888"
            TipoDeduccion="Ahorro Vacacional" MontoFijo="18000.00"/>
        <DesasociaEmpleadoConDeduccion ValorDocumentoIdentidad="194739285"
            TipoDeduccion="Pension Alimenticia"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-27"> <!-- Viernes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-27 06:00" HoraSalida="2026-03-27 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-27 14:00" HoraSalida="2026-03-27 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-27 22:00" HoraSalida="2026-03-28 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-27 06:00" HoraSalida="2026-03-27 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-27 14:00" HoraSalida="2026-03-27 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-03-27 06:00" HoraSalida="2026-03-27 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-03-27 14:00" HoraSalida="2026-03-27 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-28"> <!-- Sabado -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-28 06:00" HoraSalida="2026-03-28 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-28 14:00" HoraSalida="2026-03-29 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-28 22:00" HoraSalida="2026-03-29 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-28 06:00" HoraSalida="2026-03-28 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-28 14:00" HoraSalida="2026-03-28 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-03-28 22:00" HoraSalida="2026-03-29 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-03-28 14:00" HoraSalida="2026-03-28 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-29"> <!-- Domingo -->
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-29 14:00" HoraSalida="2026-03-30 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-29 22:00" HoraSalida="2026-03-30 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-29 06:00" HoraSalida="2026-03-29 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-29 14:00" HoraSalida="2026-03-30 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-03-29 22:00" HoraSalida="2026-03-30 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-03-29 06:00" HoraSalida="2026-03-29 17:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-30"> <!-- Lunes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-30 06:00" HoraSalida="2026-03-30 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-03-30 22:00" HoraSalida="2026-03-31 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-30 06:00" HoraSalida="2026-03-30 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-30 14:00" HoraSalida="2026-03-30 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-03-30 22:00" HoraSalida="2026-03-31 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-03-30 06:00" HoraSalida="2026-03-30 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-03-30 14:00" HoraSalida="2026-03-30 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-03-31"> <!-- Martes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-03-31 06:00" HoraSalida="2026-03-31 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-03-31 14:00" HoraSalida="2026-03-31 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-03-31 06:00" HoraSalida="2026-03-31 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-03-31 14:00" HoraSalida="2026-03-31 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-03-31 22:00" HoraSalida="2026-04-01 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-03-31 06:00" HoraSalida="2026-03-31 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-03-31 14:00" HoraSalida="2026-03-31 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-01"> <!-- Miercoles -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-01 06:00" HoraSalida="2026-04-01 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-01 14:00" HoraSalida="2026-04-01 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-01 22:00" HoraSalida="2026-04-02 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-01 14:00" HoraSalida="2026-04-01 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-01 22:00" HoraSalida="2026-04-02 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-01 06:00" HoraSalida="2026-04-01 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-01 14:00" HoraSalida="2026-04-01 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-02"> <!-- FERIADO: Jueves Santo -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-02 06:00" HoraSalida="2026-04-02 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-02 14:00" HoraSalida="2026-04-03 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-02 22:00" HoraSalida="2026-04-03 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-02 06:00" HoraSalida="2026-04-02 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-02 22:00" HoraSalida="2026-04-03 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-02 06:00" HoraSalida="2026-04-02 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-02 14:00" HoraSalida="2026-04-03 01:00"/>

        <!-- Cierre semana 4: jornada semana 5 (InicioSemana 2026-04-03) -->
        <AsignarJornada ValorDocumentoIdentidad="110011001"
            Jornada="Vespertino" InicioSemana="2026-04-03"/>
        <AsignarJornada ValorDocumentoIdentidad="305827920"
            Jornada="Nocturno" InicioSemana="2026-04-03"/>
        <AsignarJornada ValorDocumentoIdentidad="194739285"
            Jornada="Diurno" InicioSemana="2026-04-03"/>
        <AsignarJornada ValorDocumentoIdentidad="222333444"
            Jornada="Vespertino" InicioSemana="2026-04-03"/>
        <AsignarJornada ValorDocumentoIdentidad="333444555"
            Jornada="Nocturno" InicioSemana="2026-04-03"/>
        <AsignarJornada ValorDocumentoIdentidad="444555666"
            Jornada="Diurno" InicioSemana="2026-04-03"/>
        <AsignarJornada ValorDocumentoIdentidad="555666777"
            Jornada="Vespertino" InicioSemana="2026-04-03"/>
        <AsignarJornada ValorDocumentoIdentidad="666777888"
            Jornada="Nocturno" InicioSemana="2026-04-03"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-03"> <!-- FERIADO: Viernes Santo -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-03 14:00" HoraSalida="2026-04-04 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-03 22:00" HoraSalida="2026-04-04 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-03 06:00" HoraSalida="2026-04-03 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-03 14:00" HoraSalida="2026-04-04 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-03 22:00" HoraSalida="2026-04-04 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-03 14:00" HoraSalida="2026-04-04 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-03 22:00" HoraSalida="2026-04-04 08:30"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-04"> <!-- Sabado -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-04 14:00" HoraSalida="2026-04-04 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-04 22:00" HoraSalida="2026-04-05 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-04 06:00" HoraSalida="2026-04-04 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-04 14:00" HoraSalida="2026-04-05 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-04 22:00" HoraSalida="2026-04-05 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-04 06:00" HoraSalida="2026-04-04 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-04 22:00" HoraSalida="2026-04-05 08:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-05"> <!-- Domingo -->
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-05 22:00" HoraSalida="2026-04-06 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-05 06:00" HoraSalida="2026-04-05 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-05 14:00" HoraSalida="2026-04-06 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-05 22:00" HoraSalida="2026-04-06 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-05 06:00" HoraSalida="2026-04-05 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-05 14:00" HoraSalida="2026-04-06 01:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-06"> <!-- Lunes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-06 14:00" HoraSalida="2026-04-06 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-06 06:00" HoraSalida="2026-04-06 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-06 14:00" HoraSalida="2026-04-06 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-06 22:00" HoraSalida="2026-04-07 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-06 06:00" HoraSalida="2026-04-06 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-06 14:00" HoraSalida="2026-04-07 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-06 22:00" HoraSalida="2026-04-07 06:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-07"> <!-- Martes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-07 14:00" HoraSalida="2026-04-07 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-07 22:00" HoraSalida="2026-04-08 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-07 14:00" HoraSalida="2026-04-07 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-07 22:00" HoraSalida="2026-04-08 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-07 06:00" HoraSalida="2026-04-07 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-07 14:00" HoraSalida="2026-04-07 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-07 22:00" HoraSalida="2026-04-08 06:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-08"> <!-- Miercoles -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-08 14:00" HoraSalida="2026-04-09 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-08 22:00" HoraSalida="2026-04-09 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-08 06:00" HoraSalida="2026-04-08 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-08 22:00" HoraSalida="2026-04-09 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-08 06:00" HoraSalida="2026-04-08 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-08 14:00" HoraSalida="2026-04-09 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-08 22:00" HoraSalida="2026-04-09 08:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-09"> <!-- Jueves -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-09 14:00" HoraSalida="2026-04-09 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-09 22:00" HoraSalida="2026-04-10 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-09 06:00" HoraSalida="2026-04-09 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-09 14:00" HoraSalida="2026-04-09 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-09 06:00" HoraSalida="2026-04-09 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-09 14:00" HoraSalida="2026-04-10 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-09 22:00" HoraSalida="2026-04-10 06:00"/>

        <!-- Nuevos empleados: inician semana 2026-04-10 -->
        <InsertarEmpleado ValorDocumentoIdentidad="777888999" Nombre="Mario Quesada"
            Puesto="Conductor" CuentaBancaria="CR2415115201901026111006"
            Username="Quesmar" Password="Mario987" TipoUsuario="0" FechaContratacion="2026-04-10"/>
        <InsertarEmpleado ValorDocumentoIdentidad="888999000" Nombre="Diego Solano"
            Puesto="Asistente" CuentaBancaria="CR2415115201901026111007"
            Username="Soldieg" Password="Diego111" TipoUsuario="0" FechaContratacion="2026-04-10"/>
        
        <!-- Eliminar empleado: termina semana 2026-04-10 -->
        <EliminarEmpleado ValorDocumentoIdentidad="555666777"/>

        <!-- Cierre semana 5: jornada semana 6 (InicioSemana 2026-04-10) -->
        <AsignarJornada ValorDocumentoIdentidad="110011001"
            Jornada="Nocturno" InicioSemana="2026-04-10"/>
        <AsignarJornada ValorDocumentoIdentidad="305827920"
            Jornada="Diurno" InicioSemana="2026-04-10"/>
        <AsignarJornada ValorDocumentoIdentidad="194739285"
            Jornada="Vespertino" InicioSemana="2026-04-10"/>
        <AsignarJornada ValorDocumentoIdentidad="222333444"
            Jornada="Nocturno" InicioSemana="2026-04-10"/>
        <AsignarJornada ValorDocumentoIdentidad="333444555"
            Jornada="Diurno" InicioSemana="2026-04-10"/>
        <AsignarJornada ValorDocumentoIdentidad="444555666"
            Jornada="Vespertino" InicioSemana="2026-04-10"/>
        <AsignarJornada ValorDocumentoIdentidad="555666777"
            Jornada="Nocturno" InicioSemana="2026-04-10"/>
        <AsignarJornada ValorDocumentoIdentidad="666777888"
            Jornada="Diurno" InicioSemana="2026-04-10"/>
        <AsignarJornada ValorDocumentoIdentidad="777888999"
            Jornada="Vespertino" InicioSemana="2026-04-10"/>
        <AsignarJornada ValorDocumentoIdentidad="888999000"
            Jornada="Nocturno" InicioSemana="2026-04-10"/>

        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="305827920"
            TipoDeduccion="Pension Alimenticia" MontoFijo="30000.00"/>
        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="777888999"
            TipoDeduccion="Ahorro Asociacion Solidarista" MontoFijo="0.00"/>
        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="888999000"
            TipoDeduccion="Ahorro Vacacional" MontoFijo="12000.00"/>
        <DesasociaEmpleadoConDeduccion ValorDocumentoIdentidad="110011001"
            TipoDeduccion="Ahorro Asociacion Solidarista"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-10"> <!-- Viernes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-10 22:00" HoraSalida="2026-04-11 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-10 06:00" HoraSalida="2026-04-10 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-10 14:00" HoraSalida="2026-04-10 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-10 22:00" HoraSalida="2026-04-11 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-10 06:00" HoraSalida="2026-04-10 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-10 22:00" HoraSalida="2026-04-11 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-10 06:00" HoraSalida="2026-04-10 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-04-10 14:00" HoraSalida="2026-04-11 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-04-10 22:00" HoraSalida="2026-04-11 08:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-11"> <!-- FERIADO: Batalla de Rivas -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-11 22:00" HoraSalida="2026-04-12 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-11 06:00" HoraSalida="2026-04-11 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-11 14:00" HoraSalida="2026-04-12 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-11 22:00" HoraSalida="2026-04-12 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-11 06:00" HoraSalida="2026-04-11 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-11 14:00" HoraSalida="2026-04-12 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-11 06:00" HoraSalida="2026-04-11 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-04-11 14:00" HoraSalida="2026-04-12 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-04-11 22:00" HoraSalida="2026-04-12 08:30"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-12"> <!-- Domingo -->
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-12 06:00" HoraSalida="2026-04-12 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-12 14:00" HoraSalida="2026-04-13 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-12 22:00" HoraSalida="2026-04-13 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-12 06:00" HoraSalida="2026-04-12 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-12 14:00" HoraSalida="2026-04-13 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-12 22:00" HoraSalida="2026-04-13 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-04-12 14:00" HoraSalida="2026-04-13 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-04-12 22:00" HoraSalida="2026-04-13 08:30"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-13"> <!-- Lunes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-13 22:00" HoraSalida="2026-04-14 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-13 14:00" HoraSalida="2026-04-13 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-13 22:00" HoraSalida="2026-04-14 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-13 06:00" HoraSalida="2026-04-13 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-13 14:00" HoraSalida="2026-04-13 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-13 22:00" HoraSalida="2026-04-14 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-13 06:00" HoraSalida="2026-04-13 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-04-13 22:00" HoraSalida="2026-04-14 06:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-14"> <!-- Martes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-14 22:00" HoraSalida="2026-04-15 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-14 06:00" HoraSalida="2026-04-14 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-14 22:00" HoraSalida="2026-04-15 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-14 06:00" HoraSalida="2026-04-14 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-14 14:00" HoraSalida="2026-04-14 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-14 22:00" HoraSalida="2026-04-15 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-14 06:00" HoraSalida="2026-04-14 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-04-14 14:00" HoraSalida="2026-04-15 00:30"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-15"> <!-- Miercoles -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-15 22:00" HoraSalida="2026-04-16 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-15 06:00" HoraSalida="2026-04-15 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-15 14:00" HoraSalida="2026-04-15 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-15 06:00" HoraSalida="2026-04-15 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-15 14:00" HoraSalida="2026-04-16 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-15 22:00" HoraSalida="2026-04-16 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-15 06:00" HoraSalida="2026-04-15 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-04-15 14:00" HoraSalida="2026-04-15 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-04-15 22:00" HoraSalida="2026-04-16 06:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-16"> <!-- Jueves -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-16 22:00" HoraSalida="2026-04-17 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-16 06:00" HoraSalida="2026-04-16 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-16 14:00" HoraSalida="2026-04-16 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-16 22:00" HoraSalida="2026-04-17 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-16 14:00" HoraSalida="2026-04-16 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-16 22:00" HoraSalida="2026-04-17 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-16 06:00" HoraSalida="2026-04-16 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-04-16 14:00" HoraSalida="2026-04-16 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-04-16 22:00" HoraSalida="2026-04-17 06:00"/>

        <!-- Eliminar empleado: termina semana 2026-03-27 -->
        <EliminarEmpleado ValorDocumentoIdentidad="777888999"/>

        <!-- Cierre semana 6: jornada semana 7 (InicioSemana 2026-04-17) -->
        <AsignarJornada ValorDocumentoIdentidad="110011001"
            Jornada="Diurno" InicioSemana="2026-04-17"/>
        <AsignarJornada ValorDocumentoIdentidad="305827920"
            Jornada="Vespertino" InicioSemana="2026-04-17"/>
        <AsignarJornada ValorDocumentoIdentidad="194739285"
            Jornada="Nocturno" InicioSemana="2026-04-17"/>
        <AsignarJornada ValorDocumentoIdentidad="222333444"
            Jornada="Diurno" InicioSemana="2026-04-17"/>
        <AsignarJornada ValorDocumentoIdentidad="333444555"
            Jornada="Vespertino" InicioSemana="2026-04-17"/>
        <AsignarJornada ValorDocumentoIdentidad="444555666"
            Jornada="Nocturno" InicioSemana="2026-04-17"/>
        <AsignarJornada ValorDocumentoIdentidad="555666777"
            Jornada="Diurno" InicioSemana="2026-04-17"/>
        <AsignarJornada ValorDocumentoIdentidad="666777888"
            Jornada="Vespertino" InicioSemana="2026-04-17"/>
        <AsignarJornada ValorDocumentoIdentidad="777888999"
            Jornada="Nocturno" InicioSemana="2026-04-17"/>
        <AsignarJornada ValorDocumentoIdentidad="888999000"
            Jornada="Diurno" InicioSemana="2026-04-17"/>

        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="222333444"
            TipoDeduccion="Pension Alimenticia" MontoFijo="40000.00"/>
        <DesasociaEmpleadoConDeduccion ValorDocumentoIdentidad="305827920"
            TipoDeduccion="Ahorro Vacacional"/>
        <DesasociaEmpleadoConDeduccion ValorDocumentoIdentidad="555666777"
            TipoDeduccion="Ahorro Vacacional"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-17"> <!-- Viernes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-17 06:00" HoraSalida="2026-04-17 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-17 14:00" HoraSalida="2026-04-17 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-17 22:00" HoraSalida="2026-04-18 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-17 06:00" HoraSalida="2026-04-17 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-17 14:00" HoraSalida="2026-04-17 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-17 06:00" HoraSalida="2026-04-17 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-17 14:00" HoraSalida="2026-04-17 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-04-17 22:00" HoraSalida="2026-04-18 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-04-17 06:00" HoraSalida="2026-04-17 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-18"> <!-- Sabado -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-18 06:00" HoraSalida="2026-04-18 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-18 14:00" HoraSalida="2026-04-18 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-18 22:00" HoraSalida="2026-04-19 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-18 06:00" HoraSalida="2026-04-18 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-18 14:00" HoraSalida="2026-04-19 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-18 22:00" HoraSalida="2026-04-19 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-18 14:00" HoraSalida="2026-04-18 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-04-18 22:00" HoraSalida="2026-04-19 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-04-18 06:00" HoraSalida="2026-04-18 16:30"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-19"> <!-- Domingo -->
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-19 14:00" HoraSalida="2026-04-20 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-19 22:00" HoraSalida="2026-04-20 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-19 06:00" HoraSalida="2026-04-19 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-19 14:00" HoraSalida="2026-04-20 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-19 22:00" HoraSalida="2026-04-20 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-19 06:00" HoraSalida="2026-04-19 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-04-19 22:00" HoraSalida="2026-04-20 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-04-19 06:00" HoraSalida="2026-04-19 17:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-20"> <!-- Lunes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-20 06:00" HoraSalida="2026-04-20 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-20 22:00" HoraSalida="2026-04-21 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-20 06:00" HoraSalida="2026-04-20 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-20 14:00" HoraSalida="2026-04-20 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-20 22:00" HoraSalida="2026-04-21 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-20 06:00" HoraSalida="2026-04-20 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-20 14:00" HoraSalida="2026-04-21 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-04-20 06:00" HoraSalida="2026-04-20 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-21"> <!-- Martes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-21 06:00" HoraSalida="2026-04-21 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-21 14:00" HoraSalida="2026-04-21 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-21 06:00" HoraSalida="2026-04-21 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-21 14:00" HoraSalida="2026-04-21 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-21 22:00" HoraSalida="2026-04-22 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-21 06:00" HoraSalida="2026-04-21 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-21 14:00" HoraSalida="2026-04-21 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-04-21 22:00" HoraSalida="2026-04-22 08:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-22"> <!-- Miercoles -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-22 06:00" HoraSalida="2026-04-22 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-22 14:00" HoraSalida="2026-04-23 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-22 22:00" HoraSalida="2026-04-23 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-22 14:00" HoraSalida="2026-04-22 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-22 22:00" HoraSalida="2026-04-23 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-22 06:00" HoraSalida="2026-04-22 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-22 14:00" HoraSalida="2026-04-22 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-04-22 22:00" HoraSalida="2026-04-23 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-04-22 06:00" HoraSalida="2026-04-22 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-23"> <!-- Jueves -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-23 06:00" HoraSalida="2026-04-23 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-23 14:00" HoraSalida="2026-04-23 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-23 22:00" HoraSalida="2026-04-24 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-23 06:00" HoraSalida="2026-04-23 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-23 22:00" HoraSalida="2026-04-24 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-23 06:00" HoraSalida="2026-04-23 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-23 14:00" HoraSalida="2026-04-23 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-04-23 22:00" HoraSalida="2026-04-24 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-04-23 06:00" HoraSalida="2026-04-23 14:00"/>

        <!-- Nuevos empleados: inician semana 2026-04-24 -->
        <InsertarEmpleado ValorDocumentoIdentidad="999000111" Nombre="Valeria Nunez"
            Puesto="Recepcionista" CuentaBancaria="CR2415115201901026111008"
            Username="Nunval" Password="Vale222" TipoUsuario="0" FechaContratacion="2026-04-24"/>
        <InsertarEmpleado ValorDocumentoIdentidad="100200300" Nombre="Roberto Fallas"
            Puesto="Fontanero" CuentaBancaria="CR2415115201901026111009"
            Username="Falrob" Password="Rober333" TipoUsuario="0" FechaContratacion="2026-04-24"/>

        <!-- Cierre semana 7: jornada semana 8 (InicioSemana 2026-04-24) -->
        <AsignarJornada ValorDocumentoIdentidad="110011001"
            Jornada="Vespertino" InicioSemana="2026-04-24"/>
        <AsignarJornada ValorDocumentoIdentidad="305827920"
            Jornada="Nocturno" InicioSemana="2026-04-24"/>
        <AsignarJornada ValorDocumentoIdentidad="194739285"
            Jornada="Diurno" InicioSemana="2026-04-24"/>
        <AsignarJornada ValorDocumentoIdentidad="222333444"
            Jornada="Vespertino" InicioSemana="2026-04-24"/>
        <AsignarJornada ValorDocumentoIdentidad="333444555"
            Jornada="Nocturno" InicioSemana="2026-04-24"/>
        <AsignarJornada ValorDocumentoIdentidad="444555666"
            Jornada="Diurno" InicioSemana="2026-04-24"/>
        <AsignarJornada ValorDocumentoIdentidad="555666777"
            Jornada="Vespertino" InicioSemana="2026-04-24"/>
        <AsignarJornada ValorDocumentoIdentidad="666777888"
            Jornada="Nocturno" InicioSemana="2026-04-24"/>
        <AsignarJornada ValorDocumentoIdentidad="777888999"
            Jornada="Diurno" InicioSemana="2026-04-24"/>
        <AsignarJornada ValorDocumentoIdentidad="888999000"
            Jornada="Vespertino" InicioSemana="2026-04-24"/>
        <AsignarJornada ValorDocumentoIdentidad="999000111"
            Jornada="Nocturno" InicioSemana="2026-04-24"/>
        <AsignarJornada ValorDocumentoIdentidad="100200300"
            Jornada="Diurno" InicioSemana="2026-04-24"/>

        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="999000111"
            TipoDeduccion="Ahorro Vacacional" MontoFijo="22000.00"/>
        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="100200300"
            TipoDeduccion="Ahorro Asociacion Solidarista" MontoFijo="0.00"/>
        <DesasociaEmpleadoConDeduccion ValorDocumentoIdentidad="222333444"
            TipoDeduccion="Ahorro Vacacional"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-24"> <!-- Viernes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-24 14:00" HoraSalida="2026-04-25 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-24 22:00" HoraSalida="2026-04-25 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-24 06:00" HoraSalida="2026-04-24 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-24 14:00" HoraSalida="2026-04-24 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-24 22:00" HoraSalida="2026-04-25 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-24 14:00" HoraSalida="2026-04-24 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-24 22:00" HoraSalida="2026-04-25 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-04-24 06:00" HoraSalida="2026-04-24 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-04-24 14:00" HoraSalida="2026-04-24 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-04-24 22:00" HoraSalida="2026-04-25 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-04-24 06:00" HoraSalida="2026-04-24 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-25"> <!-- Sabado -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-25 14:00" HoraSalida="2026-04-26 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-25 22:00" HoraSalida="2026-04-26 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-25 06:00" HoraSalida="2026-04-25 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-25 14:00" HoraSalida="2026-04-25 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-25 22:00" HoraSalida="2026-04-26 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-25 06:00" HoraSalida="2026-04-25 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-25 22:00" HoraSalida="2026-04-26 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-04-25 06:00" HoraSalida="2026-04-25 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-04-25 14:00" HoraSalida="2026-04-25 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-04-25 22:00" HoraSalida="2026-04-26 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-04-25 06:00" HoraSalida="2026-04-25 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-26"> <!-- Domingo -->
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-26 22:00" HoraSalida="2026-04-27 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-26 06:00" HoraSalida="2026-04-26 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-26 14:00" HoraSalida="2026-04-27 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-26 22:00" HoraSalida="2026-04-27 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-26 06:00" HoraSalida="2026-04-26 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-26 14:00" HoraSalida="2026-04-27 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-04-26 06:00" HoraSalida="2026-04-26 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-04-26 14:00" HoraSalida="2026-04-27 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-04-26 22:00" HoraSalida="2026-04-27 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-04-26 06:00" HoraSalida="2026-04-26 17:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-27"> <!-- Lunes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-27 14:00" HoraSalida="2026-04-27 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-27 06:00" HoraSalida="2026-04-27 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-27 14:00" HoraSalida="2026-04-28 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-27 22:00" HoraSalida="2026-04-28 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-27 06:00" HoraSalida="2026-04-27 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-27 14:00" HoraSalida="2026-04-28 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-27 22:00" HoraSalida="2026-04-28 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-04-27 14:00" HoraSalida="2026-04-27 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-04-27 22:00" HoraSalida="2026-04-28 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-04-27 06:00" HoraSalida="2026-04-27 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-28"> <!-- Martes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-28 14:00" HoraSalida="2026-04-28 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-28 22:00" HoraSalida="2026-04-29 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-28 14:00" HoraSalida="2026-04-29 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-28 22:00" HoraSalida="2026-04-29 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-28 06:00" HoraSalida="2026-04-28 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-28 14:00" HoraSalida="2026-04-28 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-28 22:00" HoraSalida="2026-04-29 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-04-28 06:00" HoraSalida="2026-04-28 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-04-28 22:00" HoraSalida="2026-04-29 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-04-28 06:00" HoraSalida="2026-04-28 16:30"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-29"> <!-- Miercoles -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-29 14:00" HoraSalida="2026-04-30 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-29 22:00" HoraSalida="2026-04-30 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-29 06:00" HoraSalida="2026-04-29 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-04-29 22:00" HoraSalida="2026-04-30 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-29 06:00" HoraSalida="2026-04-29 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-29 14:00" HoraSalida="2026-04-29 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-29 22:00" HoraSalida="2026-04-30 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-04-29 06:00" HoraSalida="2026-04-29 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-04-29 14:00" HoraSalida="2026-04-30 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-04-29 06:00" HoraSalida="2026-04-29 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-04-30"> <!-- Jueves -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-04-30 14:00" HoraSalida="2026-04-30 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-04-30 22:00" HoraSalida="2026-05-01 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-04-30 06:00" HoraSalida="2026-04-30 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-04-30 14:00" HoraSalida="2026-05-01 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-04-30 06:00" HoraSalida="2026-04-30 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-04-30 14:00" HoraSalida="2026-04-30 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-04-30 22:00" HoraSalida="2026-05-01 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-04-30 06:00" HoraSalida="2026-04-30 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-04-30 14:00" HoraSalida="2026-04-30 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-04-30 22:00" HoraSalida="2026-05-01 08:00"/>

        <!-- Cierre semana 8: jornada semana 9 (InicioSemana 2026-05-01) -->
        <AsignarJornada ValorDocumentoIdentidad="110011001"
            Jornada="Nocturno" InicioSemana="2026-05-01"/>
        <AsignarJornada ValorDocumentoIdentidad="305827920"
            Jornada="Diurno" InicioSemana="2026-05-01"/>
        <AsignarJornada ValorDocumentoIdentidad="194739285"
            Jornada="Vespertino" InicioSemana="2026-05-01"/>
        <AsignarJornada ValorDocumentoIdentidad="222333444"
            Jornada="Nocturno" InicioSemana="2026-05-01"/>
        <AsignarJornada ValorDocumentoIdentidad="333444555"
            Jornada="Diurno" InicioSemana="2026-05-01"/>
        <AsignarJornada ValorDocumentoIdentidad="444555666"
            Jornada="Vespertino" InicioSemana="2026-05-01"/>
        <AsignarJornada ValorDocumentoIdentidad="555666777"
            Jornada="Nocturno" InicioSemana="2026-05-01"/>
        <AsignarJornada ValorDocumentoIdentidad="666777888"
            Jornada="Diurno" InicioSemana="2026-05-01"/>
        <AsignarJornada ValorDocumentoIdentidad="777888999"
            Jornada="Vespertino" InicioSemana="2026-05-01"/>
        <AsignarJornada ValorDocumentoIdentidad="888999000"
            Jornada="Nocturno" InicioSemana="2026-05-01"/>
        <AsignarJornada ValorDocumentoIdentidad="999000111"
            Jornada="Diurno" InicioSemana="2026-05-01"/>
        <AsignarJornada ValorDocumentoIdentidad="100200300"
            Jornada="Vespertino" InicioSemana="2026-05-01"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-01"> <!-- FERIADO: Día del Trabajo -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-01 22:00" HoraSalida="2026-05-02 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-01 06:00" HoraSalida="2026-05-01 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-01 14:00" HoraSalida="2026-05-02 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-01 22:00" HoraSalida="2026-05-02 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-01 06:00" HoraSalida="2026-05-01 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-01 22:00" HoraSalida="2026-05-02 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-01 06:00" HoraSalida="2026-05-01 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-01 14:00" HoraSalida="2026-05-02 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-05-01 22:00" HoraSalida="2026-05-02 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-01 06:00" HoraSalida="2026-05-01 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-01 14:00" HoraSalida="2026-05-02 01:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-02"> <!-- Sabado -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-02 22:00" HoraSalida="2026-05-03 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-02 06:00" HoraSalida="2026-05-02 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-02 14:00" HoraSalida="2026-05-02 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-02 22:00" HoraSalida="2026-05-03 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-02 06:00" HoraSalida="2026-05-02 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-02 14:00" HoraSalida="2026-05-02 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-02 06:00" HoraSalida="2026-05-02 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-02 14:00" HoraSalida="2026-05-02 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-05-02 22:00" HoraSalida="2026-05-03 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-02 06:00" HoraSalida="2026-05-02 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-02 14:00" HoraSalida="2026-05-02 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-03"> <!-- Domingo -->
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-03 06:00" HoraSalida="2026-05-03 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-03 14:00" HoraSalida="2026-05-04 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-03 22:00" HoraSalida="2026-05-04 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-03 06:00" HoraSalida="2026-05-03 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-03 14:00" HoraSalida="2026-05-04 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-03 22:00" HoraSalida="2026-05-04 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-03 14:00" HoraSalida="2026-05-04 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-05-03 22:00" HoraSalida="2026-05-04 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-03 06:00" HoraSalida="2026-05-03 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-03 14:00" HoraSalida="2026-05-04 01:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-04"> <!-- Lunes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-04 22:00" HoraSalida="2026-05-05 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-04 14:00" HoraSalida="2026-05-04 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-04 22:00" HoraSalida="2026-05-05 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-04 06:00" HoraSalida="2026-05-04 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-04 14:00" HoraSalida="2026-05-04 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-04 22:00" HoraSalida="2026-05-05 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-04 06:00" HoraSalida="2026-05-04 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-05-04 22:00" HoraSalida="2026-05-05 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-04 06:00" HoraSalida="2026-05-04 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-04 14:00" HoraSalida="2026-05-04 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-05"> <!-- Martes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-05 22:00" HoraSalida="2026-05-06 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-05 06:00" HoraSalida="2026-05-05 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-05 22:00" HoraSalida="2026-05-06 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-05 06:00" HoraSalida="2026-05-05 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-05 14:00" HoraSalida="2026-05-05 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-05 22:00" HoraSalida="2026-05-06 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-05 06:00" HoraSalida="2026-05-05 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-05 14:00" HoraSalida="2026-05-06 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-05 06:00" HoraSalida="2026-05-05 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-05 14:00" HoraSalida="2026-05-06 00:30"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-06"> <!-- Miercoles -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-06 22:00" HoraSalida="2026-05-07 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-06 06:00" HoraSalida="2026-05-06 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-06 14:00" HoraSalida="2026-05-07 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-06 06:00" HoraSalida="2026-05-06 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-06 14:00" HoraSalida="2026-05-06 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-06 22:00" HoraSalida="2026-05-07 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-06 06:00" HoraSalida="2026-05-06 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-06 14:00" HoraSalida="2026-05-06 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-05-06 22:00" HoraSalida="2026-05-07 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-06 14:00" HoraSalida="2026-05-06 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-07"> <!-- Jueves -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-07 22:00" HoraSalida="2026-05-08 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-07 06:00" HoraSalida="2026-05-07 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-07 14:00" HoraSalida="2026-05-08 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-07 22:00" HoraSalida="2026-05-08 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-07 14:00" HoraSalida="2026-05-07 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-07 22:00" HoraSalida="2026-05-08 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-07 06:00" HoraSalida="2026-05-07 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-07 14:00" HoraSalida="2026-05-07 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-05-07 22:00" HoraSalida="2026-05-08 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-07 06:00" HoraSalida="2026-05-07 16:30"/>

        <!-- Nuevos empleados: inician semana 2026-05-08 -->
        <InsertarEmpleado ValorDocumentoIdentidad="400500600" Nombre="Jimena Salazar"
            Puesto="Cajero" CuentaBancaria="CR2415115201901026111010"
            Username="Saljim" Password="Jime444" TipoUsuario="0" FechaContratacion="2026-05-08"/>

        <!-- Cierre semana 9: jornada semana 10 (InicioSemana 2026-05-08) -->
        <AsignarJornada ValorDocumentoIdentidad="110011001"
            Jornada="Diurno" InicioSemana="2026-05-08"/>
        <AsignarJornada ValorDocumentoIdentidad="305827920"
            Jornada="Vespertino" InicioSemana="2026-05-08"/>
        <AsignarJornada ValorDocumentoIdentidad="194739285"
            Jornada="Nocturno" InicioSemana="2026-05-08"/>
        <AsignarJornada ValorDocumentoIdentidad="222333444"
            Jornada="Diurno" InicioSemana="2026-05-08"/>
        <AsignarJornada ValorDocumentoIdentidad="333444555"
            Jornada="Vespertino" InicioSemana="2026-05-08"/>
        <AsignarJornada ValorDocumentoIdentidad="444555666"
            Jornada="Nocturno" InicioSemana="2026-05-08"/>
        <AsignarJornada ValorDocumentoIdentidad="555666777"
            Jornada="Diurno" InicioSemana="2026-05-08"/>
        <AsignarJornada ValorDocumentoIdentidad="666777888"
            Jornada="Vespertino" InicioSemana="2026-05-08"/>
        <AsignarJornada ValorDocumentoIdentidad="777888999"
            Jornada="Nocturno" InicioSemana="2026-05-08"/>
        <AsignarJornada ValorDocumentoIdentidad="888999000"
            Jornada="Diurno" InicioSemana="2026-05-08"/>
        <AsignarJornada ValorDocumentoIdentidad="999000111"
            Jornada="Vespertino" InicioSemana="2026-05-08"/>
        <AsignarJornada ValorDocumentoIdentidad="100200300"
            Jornada="Nocturno" InicioSemana="2026-05-08"/>
        <AsignarJornada ValorDocumentoIdentidad="400500600"
            Jornada="Diurno" InicioSemana="2026-05-08"/>

        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="110011001"
            TipoDeduccion="Pension Alimenticia" MontoFijo="20000.00"/>
        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="400500600"
            TipoDeduccion="Pension Alimenticia" MontoFijo="28000.00"/>
        <DesasociaEmpleadoConDeduccion ValorDocumentoIdentidad="305827920"
            TipoDeduccion="Pension Alimenticia"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-08"> <!-- Viernes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-08 06:00" HoraSalida="2026-05-08 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-08 14:00" HoraSalida="2026-05-08 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-08 22:00" HoraSalida="2026-05-09 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-08 06:00" HoraSalida="2026-05-08 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-08 14:00" HoraSalida="2026-05-08 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-08 06:00" HoraSalida="2026-05-08 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-08 14:00" HoraSalida="2026-05-08 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-08 22:00" HoraSalida="2026-05-09 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-05-08 06:00" HoraSalida="2026-05-08 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-08 14:00" HoraSalida="2026-05-08 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-08 22:00" HoraSalida="2026-05-09 08:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-09"> <!-- Sabado -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-09 06:00" HoraSalida="2026-05-09 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-09 14:00" HoraSalida="2026-05-09 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-09 22:00" HoraSalida="2026-05-10 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-09 06:00" HoraSalida="2026-05-09 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-09 14:00" HoraSalida="2026-05-09 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-09 22:00" HoraSalida="2026-05-10 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-09 14:00" HoraSalida="2026-05-09 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-09 22:00" HoraSalida="2026-05-10 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-05-09 06:00" HoraSalida="2026-05-09 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-09 14:00" HoraSalida="2026-05-09 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-09 22:00" HoraSalida="2026-05-10 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="400500600" HoraEntrada="2026-05-09 06:00" HoraSalida="2026-05-09 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-10"> <!-- Domingo -->
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-10 14:00" HoraSalida="2026-05-11 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-10 22:00" HoraSalida="2026-05-11 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-10 06:00" HoraSalida="2026-05-10 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-10 14:00" HoraSalida="2026-05-11 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-10 22:00" HoraSalida="2026-05-11 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-10 06:00" HoraSalida="2026-05-10 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-10 22:00" HoraSalida="2026-05-11 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-05-10 06:00" HoraSalida="2026-05-10 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-10 14:00" HoraSalida="2026-05-11 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-10 22:00" HoraSalida="2026-05-11 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="400500600" HoraEntrada="2026-05-10 06:00" HoraSalida="2026-05-10 17:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-11"> <!-- Lunes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-11 06:00" HoraSalida="2026-05-11 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-11 22:00" HoraSalida="2026-05-12 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-11 06:00" HoraSalida="2026-05-11 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-11 14:00" HoraSalida="2026-05-11 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-11 22:00" HoraSalida="2026-05-12 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-11 06:00" HoraSalida="2026-05-11 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-11 14:00" HoraSalida="2026-05-12 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-05-11 06:00" HoraSalida="2026-05-11 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-11 14:00" HoraSalida="2026-05-11 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-11 22:00" HoraSalida="2026-05-12 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="400500600" HoraEntrada="2026-05-11 06:00" HoraSalida="2026-05-11 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-12"> <!-- Martes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-12 06:00" HoraSalida="2026-05-12 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-12 14:00" HoraSalida="2026-05-12 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-12 06:00" HoraSalida="2026-05-12 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-12 14:00" HoraSalida="2026-05-13 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-12 22:00" HoraSalida="2026-05-13 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-12 06:00" HoraSalida="2026-05-12 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-12 14:00" HoraSalida="2026-05-13 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-12 22:00" HoraSalida="2026-05-13 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-12 14:00" HoraSalida="2026-05-12 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-12 22:00" HoraSalida="2026-05-13 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="400500600" HoraEntrada="2026-05-12 06:00" HoraSalida="2026-05-12 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-13"> <!-- Miercoles -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-13 06:00" HoraSalida="2026-05-13 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-13 14:00" HoraSalida="2026-05-14 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-13 22:00" HoraSalida="2026-05-14 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-13 14:00" HoraSalida="2026-05-13 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-13 22:00" HoraSalida="2026-05-14 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-13 06:00" HoraSalida="2026-05-13 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-13 14:00" HoraSalida="2026-05-14 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-13 22:00" HoraSalida="2026-05-14 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-05-13 06:00" HoraSalida="2026-05-13 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-13 22:00" HoraSalida="2026-05-14 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="400500600" HoraEntrada="2026-05-13 06:00" HoraSalida="2026-05-13 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-14"> <!-- Jueves -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-14 06:00" HoraSalida="2026-05-14 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-14 14:00" HoraSalida="2026-05-14 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-14 22:00" HoraSalida="2026-05-15 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-14 06:00" HoraSalida="2026-05-14 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-14 22:00" HoraSalida="2026-05-15 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-14 06:00" HoraSalida="2026-05-14 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-14 14:00" HoraSalida="2026-05-14 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-14 22:00" HoraSalida="2026-05-15 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="888999000" HoraEntrada="2026-05-14 06:00" HoraSalida="2026-05-14 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-14 14:00" HoraSalida="2026-05-14 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="400500600" HoraEntrada="2026-05-14 06:00" HoraSalida="2026-05-14 14:00"/>

        <!-- Diego Solano deja la empresa en esta fecha -->
        <EliminarEmpleado ValorDocumentoIdentidad="888999000"/>

        <!-- Cierre semana 10: jornada semana 11 (InicioSemana 2026-05-15) -->
        <AsignarJornada ValorDocumentoIdentidad="110011001"
            Jornada="Vespertino" InicioSemana="2026-05-15"/>
        <AsignarJornada ValorDocumentoIdentidad="305827920"
            Jornada="Nocturno" InicioSemana="2026-05-15"/>
        <AsignarJornada ValorDocumentoIdentidad="194739285"
            Jornada="Diurno" InicioSemana="2026-05-15"/>
        <AsignarJornada ValorDocumentoIdentidad="222333444"
            Jornada="Vespertino" InicioSemana="2026-05-15"/>
        <AsignarJornada ValorDocumentoIdentidad="333444555"
            Jornada="Nocturno" InicioSemana="2026-05-15"/>
        <AsignarJornada ValorDocumentoIdentidad="444555666"
            Jornada="Diurno" InicioSemana="2026-05-15"/>
        <AsignarJornada ValorDocumentoIdentidad="555666777"
            Jornada="Vespertino" InicioSemana="2026-05-15"/>
        <AsignarJornada ValorDocumentoIdentidad="666777888"
            Jornada="Nocturno" InicioSemana="2026-05-15"/>
        <AsignarJornada ValorDocumentoIdentidad="777888999"
            Jornada="Diurno" InicioSemana="2026-05-15"/>
        <AsignarJornada ValorDocumentoIdentidad="999000111"
            Jornada="Nocturno" InicioSemana="2026-05-15"/>
        <AsignarJornada ValorDocumentoIdentidad="100200300"
            Jornada="Diurno" InicioSemana="2026-05-15"/>
        <AsignarJornada ValorDocumentoIdentidad="400500600"
            Jornada="Vespertino" InicioSemana="2026-05-15"/>

        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="194739285"
            TipoDeduccion="Ahorro Vacacional" MontoFijo="10000.00"/>
        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="666777888"
            TipoDeduccion="Pension Alimenticia" MontoFijo="32000.00"/>
        <DesasociaEmpleadoConDeduccion ValorDocumentoIdentidad="444555666"
            TipoDeduccion="Pension Alimenticia"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-15"> <!-- Viernes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-15 14:00" HoraSalida="2026-05-15 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-15 22:00" HoraSalida="2026-05-16 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-15 06:00" HoraSalida="2026-05-15 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-15 14:00" HoraSalida="2026-05-15 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-15 22:00" HoraSalida="2026-05-16 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-15 14:00" HoraSalida="2026-05-15 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-15 22:00" HoraSalida="2026-05-16 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-15 06:00" HoraSalida="2026-05-15 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-15 22:00" HoraSalida="2026-05-16 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-15 06:00" HoraSalida="2026-05-15 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-16"> <!-- Sabado -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-16 14:00" HoraSalida="2026-05-16 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-16 22:00" HoraSalida="2026-05-17 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-16 06:00" HoraSalida="2026-05-16 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-16 14:00" HoraSalida="2026-05-16 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-16 22:00" HoraSalida="2026-05-17 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-16 06:00" HoraSalida="2026-05-16 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-16 22:00" HoraSalida="2026-05-17 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-16 06:00" HoraSalida="2026-05-16 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-16 22:00" HoraSalida="2026-05-17 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-16 06:00" HoraSalida="2026-05-16 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="400500600" HoraEntrada="2026-05-16 14:00" HoraSalida="2026-05-16 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-17"> <!-- Domingo -->
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-17 22:00" HoraSalida="2026-05-18 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-17 06:00" HoraSalida="2026-05-17 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-17 14:00" HoraSalida="2026-05-18 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-17 22:00" HoraSalida="2026-05-18 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-17 06:00" HoraSalida="2026-05-17 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-17 14:00" HoraSalida="2026-05-18 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-17 06:00" HoraSalida="2026-05-17 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-17 22:00" HoraSalida="2026-05-18 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-17 06:00" HoraSalida="2026-05-17 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="400500600" HoraEntrada="2026-05-17 14:00" HoraSalida="2026-05-18 01:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-18"> <!-- Lunes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-18 14:00" HoraSalida="2026-05-18 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-18 06:00" HoraSalida="2026-05-18 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-18 14:00" HoraSalida="2026-05-19 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-18 22:00" HoraSalida="2026-05-19 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-18 06:00" HoraSalida="2026-05-18 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-18 14:00" HoraSalida="2026-05-19 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-18 22:00" HoraSalida="2026-05-19 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-18 22:00" HoraSalida="2026-05-19 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-18 06:00" HoraSalida="2026-05-18 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="400500600" HoraEntrada="2026-05-18 14:00" HoraSalida="2026-05-19 00:30"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-19"> <!-- Martes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-19 14:00" HoraSalida="2026-05-19 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-19 22:00" HoraSalida="2026-05-20 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-19 14:00" HoraSalida="2026-05-19 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-19 22:00" HoraSalida="2026-05-20 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-19 06:00" HoraSalida="2026-05-19 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-19 14:00" HoraSalida="2026-05-19 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-19 22:00" HoraSalida="2026-05-20 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-19 06:00" HoraSalida="2026-05-19 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-19 22:00" HoraSalida="2026-05-20 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-19 06:00" HoraSalida="2026-05-19 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="400500600" HoraEntrada="2026-05-19 14:00" HoraSalida="2026-05-19 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-20"> <!-- Miercoles -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-20 14:00" HoraSalida="2026-05-20 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-20 22:00" HoraSalida="2026-05-21 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-20 06:00" HoraSalida="2026-05-20 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-20 22:00" HoraSalida="2026-05-21 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-20 06:00" HoraSalida="2026-05-20 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-20 14:00" HoraSalida="2026-05-21 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-20 22:00" HoraSalida="2026-05-21 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-20 06:00" HoraSalida="2026-05-20 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-20 06:00" HoraSalida="2026-05-20 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="400500600" HoraEntrada="2026-05-20 14:00" HoraSalida="2026-05-20 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-21"> <!-- Jueves -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-21 14:00" HoraSalida="2026-05-21 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-21 22:00" HoraSalida="2026-05-22 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-21 06:00" HoraSalida="2026-05-21 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-21 14:00" HoraSalida="2026-05-21 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-21 06:00" HoraSalida="2026-05-21 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-21 14:00" HoraSalida="2026-05-21 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-21 22:00" HoraSalida="2026-05-22 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-21 06:00" HoraSalida="2026-05-21 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-21 22:00" HoraSalida="2026-05-22 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="400500600" HoraEntrada="2026-05-21 14:00" HoraSalida="2026-05-22 00:30"/>

        <!-- Cierre semana 11: jornada semana 12 (InicioSemana 2026-05-22) -->
        <AsignarJornada ValorDocumentoIdentidad="110011001"
            Jornada="Nocturno" InicioSemana="2026-05-22"/>
        <AsignarJornada ValorDocumentoIdentidad="305827920"
            Jornada="Diurno" InicioSemana="2026-05-22"/>
        <AsignarJornada ValorDocumentoIdentidad="194739285"
            Jornada="Vespertino" InicioSemana="2026-05-22"/>
        <AsignarJornada ValorDocumentoIdentidad="222333444"
            Jornada="Nocturno" InicioSemana="2026-05-22"/>
        <AsignarJornada ValorDocumentoIdentidad="333444555"
            Jornada="Diurno" InicioSemana="2026-05-22"/>
        <AsignarJornada ValorDocumentoIdentidad="444555666"
            Jornada="Vespertino" InicioSemana="2026-05-22"/>
        <AsignarJornada ValorDocumentoIdentidad="555666777"
            Jornada="Nocturno" InicioSemana="2026-05-22"/>
        <AsignarJornada ValorDocumentoIdentidad="666777888"
            Jornada="Diurno" InicioSemana="2026-05-22"/>
        <AsignarJornada ValorDocumentoIdentidad="777888999"
            Jornada="Vespertino" InicioSemana="2026-05-22"/>
        <AsignarJornada ValorDocumentoIdentidad="999000111"
            Jornada="Diurno" InicioSemana="2026-05-22"/>
        <AsignarJornada ValorDocumentoIdentidad="100200300"
            Jornada="Vespertino" InicioSemana="2026-05-22"/>
        <AsignarJornada ValorDocumentoIdentidad="400500600"
            Jornada="Nocturno" InicioSemana="2026-05-22"/>

        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="333444555"
            TipoDeduccion="Ahorro Vacacional" MontoFijo="17000.00"/>
        <DesasociaEmpleadoConDeduccion ValorDocumentoIdentidad="110011001"
            TipoDeduccion="Pension Alimenticia"/>
        <DesasociaEmpleadoConDeduccion ValorDocumentoIdentidad="100200300"
            TipoDeduccion="Ahorro Asociacion Solidarista"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-22"> <!-- Viernes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-22 22:00" HoraSalida="2026-05-23 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-22 06:00" HoraSalida="2026-05-22 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-22 14:00" HoraSalida="2026-05-22 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-22 22:00" HoraSalida="2026-05-23 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-22 06:00" HoraSalida="2026-05-22 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-22 22:00" HoraSalida="2026-05-23 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-22 06:00" HoraSalida="2026-05-22 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-22 14:00" HoraSalida="2026-05-22 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-22 06:00" HoraSalida="2026-05-22 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-22 14:00" HoraSalida="2026-05-22 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-23"> <!-- Sabado -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-23 22:00" HoraSalida="2026-05-24 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-23 06:00" HoraSalida="2026-05-23 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-23 14:00" HoraSalida="2026-05-24 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-23 22:00" HoraSalida="2026-05-24 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-23 06:00" HoraSalida="2026-05-23 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-23 14:00" HoraSalida="2026-05-23 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-23 06:00" HoraSalida="2026-05-23 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-23 14:00" HoraSalida="2026-05-23 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-23 06:00" HoraSalida="2026-05-23 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-23 14:00" HoraSalida="2026-05-23 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="400500600" HoraEntrada="2026-05-23 22:00" HoraSalida="2026-05-24 06:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-24"> <!-- Domingo -->
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-24 06:00" HoraSalida="2026-05-24 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-24 14:00" HoraSalida="2026-05-25 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-24 22:00" HoraSalida="2026-05-25 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-24 06:00" HoraSalida="2026-05-24 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-24 14:00" HoraSalida="2026-05-25 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-24 22:00" HoraSalida="2026-05-25 08:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-24 14:00" HoraSalida="2026-05-25 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-24 06:00" HoraSalida="2026-05-24 17:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-24 14:00" HoraSalida="2026-05-25 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="400500600" HoraEntrada="2026-05-24 22:00" HoraSalida="2026-05-25 08:30"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-25"> <!-- Lunes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-25 22:00" HoraSalida="2026-05-26 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-25 14:00" HoraSalida="2026-05-26 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-25 22:00" HoraSalida="2026-05-26 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-25 06:00" HoraSalida="2026-05-25 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-25 14:00" HoraSalida="2026-05-26 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-25 22:00" HoraSalida="2026-05-26 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-25 06:00" HoraSalida="2026-05-25 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-25 06:00" HoraSalida="2026-05-25 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-25 14:00" HoraSalida="2026-05-25 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="400500600" HoraEntrada="2026-05-25 22:00" HoraSalida="2026-05-26 06:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-26"> <!-- Martes -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-26 22:00" HoraSalida="2026-05-27 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-26 06:00" HoraSalida="2026-05-26 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-26 22:00" HoraSalida="2026-05-27 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-26 06:00" HoraSalida="2026-05-26 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-26 14:00" HoraSalida="2026-05-26 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-26 22:00" HoraSalida="2026-05-27 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-26 06:00" HoraSalida="2026-05-26 16:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-26 14:00" HoraSalida="2026-05-27 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-26 06:00" HoraSalida="2026-05-26 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-26 14:00" HoraSalida="2026-05-26 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="400500600" HoraEntrada="2026-05-26 22:00" HoraSalida="2026-05-27 06:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-27"> <!-- Miercoles -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-27 22:00" HoraSalida="2026-05-28 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-27 06:00" HoraSalida="2026-05-27 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-27 14:00" HoraSalida="2026-05-28 00:30"/>
        <MarcaAsistencia ValorDocumentoIdentidad="333444555" HoraEntrada="2026-05-27 06:00" HoraSalida="2026-05-27 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-27 14:00" HoraSalida="2026-05-27 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-27 22:00" HoraSalida="2026-05-28 08:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-27 06:00" HoraSalida="2026-05-27 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-27 14:00" HoraSalida="2026-05-27 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="100200300" HoraEntrada="2026-05-27 14:00" HoraSalida="2026-05-27 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="400500600" HoraEntrada="2026-05-27 22:00" HoraSalida="2026-05-28 08:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-28"> <!-- Jueves -->
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-28 22:00" HoraSalida="2026-05-29 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-28 06:00" HoraSalida="2026-05-28 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-28 14:00" HoraSalida="2026-05-28 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="222333444" HoraEntrada="2026-05-28 22:00" HoraSalida="2026-05-29 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="444555666" HoraEntrada="2026-05-28 14:00" HoraSalida="2026-05-28 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="555666777" HoraEntrada="2026-05-28 22:00" HoraSalida="2026-05-29 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="666777888" HoraEntrada="2026-05-28 06:00" HoraSalida="2026-05-28 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="777888999" HoraEntrada="2026-05-28 14:00" HoraSalida="2026-05-28 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="999000111" HoraEntrada="2026-05-28 06:00" HoraSalida="2026-05-28 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="400500600" HoraEntrada="2026-05-28 22:00" HoraSalida="2026-05-29 08:00"/>

        <!-- Cierre semana 12: jornada semana 13 (InicioSemana 2026-05-29) -->
        <AsignarJornada ValorDocumentoIdentidad="110011001"
            Jornada="Diurno" InicioSemana="2026-05-29"/>
        <AsignarJornada ValorDocumentoIdentidad="305827920"
            Jornada="Vespertino" InicioSemana="2026-05-29"/>
        <AsignarJornada ValorDocumentoIdentidad="194739285"
            Jornada="Nocturno" InicioSemana="2026-05-29"/>
        <AsignarJornada ValorDocumentoIdentidad="222333444"
            Jornada="Diurno" InicioSemana="2026-05-29"/>
        <AsignarJornada ValorDocumentoIdentidad="333444555"
            Jornada="Vespertino" InicioSemana="2026-05-29"/>
        <AsignarJornada ValorDocumentoIdentidad="444555666"
            Jornada="Nocturno" InicioSemana="2026-05-29"/>
        <AsignarJornada ValorDocumentoIdentidad="555666777"
            Jornada="Diurno" InicioSemana="2026-05-29"/>
        <AsignarJornada ValorDocumentoIdentidad="666777888"
            Jornada="Vespertino" InicioSemana="2026-05-29"/>
        <AsignarJornada ValorDocumentoIdentidad="777888999"
            Jornada="Nocturno" InicioSemana="2026-05-29"/>
        <AsignarJornada ValorDocumentoIdentidad="999000111"
            Jornada="Vespertino" InicioSemana="2026-05-29"/>
        <AsignarJornada ValorDocumentoIdentidad="100200300"
            Jornada="Nocturno" InicioSemana="2026-05-29"/>
        <AsignarJornada ValorDocumentoIdentidad="400500600"
            Jornada="Diurno" InicioSemana="2026-05-29"/>
    </FechaOperacion>

</Operaciones>';
EXEC dbo.SP_ProcesarFechaOperacion @XmlOperaciones = @myXml;
GO


-- ===========================================================================
-- Crear usuarios de acceso al portal para cada empleado
-- (se ejecuta despues de la simulacion, cuando los empleados ya existen)
--   Username  = Cedula del empleado
--   Contrasena (y hash) = '123' por defecto
--   Rol       = 'Empleado' (TipoUsuario id = 2)
-- Idempotente: no duplica usuarios ni vinculos si se vuelve a ejecutar.
-- ===========================================================================

-- Asegurar el rol 'Empleado' (load_datos solo crea el rol 'Administrador')
IF NOT EXISTS (SELECT 1 FROM dbo.TipoUsuario WHERE id = 2)
BEGIN
    SET IDENTITY_INSERT dbo.TipoUsuario ON;
    INSERT INTO dbo.TipoUsuario (id, Nombre) VALUES (2, 'Empleado');
    SET IDENTITY_INSERT dbo.TipoUsuario OFF;
END
GO

-- Crear un Usuario por cada empleado que aun no tenga uno asociado
INSERT INTO dbo.Usuario (
    Username, Contrasena, NombreUsuario, ContrasenaHash, idRol, Activo
)
SELECT
    e.Cedula, '123', e.Cedula, '123', 2, 1
FROM dbo.Empleado e
WHERE NOT EXISTS (SELECT 1 FROM dbo.Usuario u WHERE u.Username = e.Cedula)
  AND NOT EXISTS (
      SELECT 1 FROM dbo.UsuarioEmpleado ue WHERE ue.idEmpleado = e.id
  );
GO

-- Vincular cada empleado con su usuario (Username = Cedula)
INSERT INTO dbo.UsuarioEmpleado (idUsuario, idEmpleado)
SELECT u.id, e.id
FROM dbo.Empleado e
INNER JOIN dbo.Usuario u ON u.Username = e.Cedula
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.UsuarioEmpleado ue WHERE ue.idEmpleado = e.id
);
GO
