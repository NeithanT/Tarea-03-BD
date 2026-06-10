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
    DECLARE @idEmpClose        INT;
    DECLARE @idPlanillaClose   INT;
    DECLARE @idPlanillaSemClose INT;
    DECLARE @ingresoBruto      DECIMAL(10, 2);
    DECLARE @totalDed          DECIMAL(10, 2);
    DECLARE @lastDayMes        DATE;
    DECLARE @lastDayISO        INT;
    DECLARE @lastJuevesMes     DATE;
    DECLARE @prevLastDay       DATE;
    DECLARE @prevLastDayISO    INT;
    DECLARE @monthPayStart     DATE;
    DECLARE @numJueves         INT;
    DECLARE @idPlanillaMens    INT;

    BEGIN TRY

        -- Temp tables para evitar cursores anidados
        CREATE TABLE #TempAsist (
            Id          INT IDENTITY(1,1) PRIMARY KEY
            , Cedula    VARCHAR(20)
            , Entrada   NVARCHAR(20)
            , Salida    NVARCHAR(20)
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
        -- Cursor principal: itera fechas del XML en orden ascendente
        -- ===================================================================
        DECLARE cDates CURSOR LOCAL FAST_FORWARD FOR
            SELECT DISTINCT TRY_CAST(n.value('@Fecha', 'NVARCHAR(20)') AS DATE)
            FROM @XmlOperaciones.nodes('/Operaciones/FechaOperacion') T(n)
            WHERE @FechaOperacion IS NULL
               OR TRY_CAST(n.value('@Fecha', 'NVARCHAR(20)') AS DATE) = @FechaOperacion
            ORDER BY 1;

        OPEN cDates;
        FETCH NEXT FROM cDates INTO @FechaActual;

        WHILE @@FETCH_STATUS = 0
        BEGIN
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
                SELECT TRY_CAST(n.value('@InicioSemana', 'NVARCHAR(20)') AS DATE) AS InicioSem
                FROM @XmlOperaciones.nodes(
                    '/Operaciones/FechaOperacion[@Fecha=sql:variable("@FechaStr")]/AsignarJornada'
                ) T(n)
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
                SELECT TRY_CAST(n.value('@InicioSemana', 'NVARCHAR(20)') AS DATE) AS InicioSem
                FROM @XmlOperaciones.nodes(
                    '/Operaciones/FechaOperacion[@Fecha=sql:variable("@FechaStr")]/AsignarJornada'
                ) T(n)
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
                n.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
                -- Nombre = todo antes del ultimo espacio; Apellido = ultima palabra
                , CASE
                    WHEN CHARINDEX(' ', RTRIM(n.value('@Nombre', 'VARCHAR(255)'))) > 0
                    THEN LEFT(
                        n.value('@Nombre', 'VARCHAR(255)'),
                        LEN(n.value('@Nombre', 'VARCHAR(255)'))
                            - CHARINDEX(' ', REVERSE(RTRIM(n.value('@Nombre', 'VARCHAR(255)'))))
                    )
                    ELSE n.value('@Nombre', 'VARCHAR(255)')
                  END
                , CASE
                    WHEN CHARINDEX(' ', RTRIM(n.value('@Nombre', 'VARCHAR(255)'))) > 0
                    THEN RIGHT(
                        n.value('@Nombre', 'VARCHAR(255)'),
                        CHARINDEX(' ', REVERSE(RTRIM(n.value('@Nombre', 'VARCHAR(255)')))) - 1
                    )
                    ELSE ''
                  END
                , TRY_CAST(n.value('@FechaContratacion', 'NVARCHAR(20)') AS DATE)
                , NULL
                , (SELECT p.id FROM dbo.Puesto p
                   WHERE p.Nombre = n.value('@Puesto', 'VARCHAR(255)'))
                , 1
            FROM @XmlOperaciones.nodes(
                '/Operaciones/FechaOperacion[@Fecha=sql:variable("@FechaStr")]/InsertarEmpleado'
            ) T(n)
            WHERE NOT EXISTS (
                SELECT 1 FROM dbo.Empleado e2
                WHERE e2.Cedula = n.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
            );

            -- ---------------------------------------------------------------
            -- EliminaEmpleado (baja logica)
            -- ---------------------------------------------------------------
            UPDATE dbo.Empleado
            SET Activo = 0
            WHERE Cedula IN (
                SELECT n.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
                FROM @XmlOperaciones.nodes(
                    '/Operaciones/FechaOperacion[@Fecha=sql:variable("@FechaStr")]/EliminaEmpleado'
                ) T(n)
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
                    WHEN TRY_CAST(n.value('@MontoFijo', 'NVARCHAR(20)') AS DECIMAL(10,4)) = 0
                    THEN td.Valor
                    ELSE TRY_CAST(n.value('@MontoFijo', 'NVARCHAR(20)') AS DECIMAL(10,4))
                  END
                , @FechaInicioDeduccion
                , NULL
                , 1
            FROM @XmlOperaciones.nodes(
                '/Operaciones/FechaOperacion[@Fecha=sql:variable("@FechaStr")]/AsociaEmpleadoConDeduccion'
            ) T(n)
            INNER JOIN dbo.Empleado e
                ON e.Cedula = n.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
                AND e.Activo = 1
            INNER JOIN dbo.TipoDeduccion td
                ON td.Nombre = n.value('@TipoDeduccion', 'VARCHAR(100)')
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
                ) T(n)
                WHERE e.Cedula  = n.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
                  AND td.Nombre = n.value('@TipoDeduccion', 'VARCHAR(100)')
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
            ) T(n)
            INNER JOIN dbo.Empleado e
                ON e.Cedula = n.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
                AND e.Activo = 1
            INNER JOIN dbo.TipoJornada tj
                ON tj.Nombre = n.value('@Jornada', 'VARCHAR(50)')
            INNER JOIN dbo.Semana s
                ON s.FechaInicio = TRY_CAST(n.value('@InicioSemana', 'NVARCHAR(20)') AS DATE)
            CROSS JOIN (VALUES (1),(2),(3),(4),(5),(6),(7)) d(DiaSemana)
            WHERE NOT EXISTS (
                SELECT 1 FROM dbo.HorarioJornada hj2
                WHERE hj2.idEmpleado = e.id
                  AND hj2.idSemana   = s.id
                  AND hj2.DiaSemana  = d.DiaSemana
            );

            -- ---------------------------------------------------------------
            -- MarcaAsistencia: carga en temp table y procesa con cursor
            -- ---------------------------------------------------------------
            TRUNCATE TABLE #TempAsist;

            INSERT INTO #TempAsist (Cedula, Entrada, Salida)
            SELECT
                n.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
                , n.value('@HoraEntrada', 'NVARCHAR(20)')
                , n.value('@HoraSalida',  'NVARCHAR(20)')
            FROM @XmlOperaciones.nodes(
                '/Operaciones/FechaOperacion[@Fecha=sql:variable("@FechaStr")]/MarcaAsistencia'
            ) T(n);

            DECLARE cAsist CURSOR LOCAL FAST_FORWARD FOR
                SELECT Cedula, Entrada, Salida FROM #TempAsist;

            OPEN cAsist;
            FETCH NEXT FROM cAsist INTO @cedula, @dtEntradaStr, @dtSalidaStr;

            WHILE @@FETCH_STATUS = 0
            BEGIN
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
                                , Cantidad, Monto, Fecha
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
                                , Cantidad, Monto, Fecha
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
                                , Cantidad, Monto, Fecha
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

                FETCH NEXT FROM cAsist INTO @cedula, @dtEntradaStr, @dtSalidaStr;
            END

            CLOSE cAsist;
            DEALLOCATE cAsist;

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

                SET @prevLastDay      = DATEADD(DAY, -1, DATEFROMPARTS(@MesAno, @MesNumero, 1));
                SET @prevLastDayISO   = (DATEPART(dw, @prevLastDay) + @@DATEFIRST - 2) % 7 + 1;
                SET @monthPayStart    = DATEADD(DAY, -((@prevLastDayISO - 5 + 7) % 7), @prevLastDay);

                SET @numJueves = (DATEDIFF(DAY, @monthPayStart, @lastJuevesMes) + 1) / 7;
                IF @numJueves < 1 SET @numJueves = 4;

                DECLARE cClose CURSOR LOCAL FAST_FORWARD FOR
                    SELECT idEmp, idPlanilla, idPlanillaSem FROM #TempClose;

                OPEN cClose;
                FETCH NEXT FROM cClose INTO @idEmpClose, @idPlanillaClose, @idPlanillaSemClose;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    SELECT @ingresoBruto = IngresoBruto
                    FROM dbo.Planilla WHERE id = @idPlanillaClose;

                    SET @totalDed = 0;

                    -- Deducciones porcentuales (sobre el salario bruto semanal)
                    INSERT INTO dbo.MovPlanilla (
                        idPlanillaSemanal, idAsistencia, idTipoMovimiento, Cantidad, Monto, Fecha
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
                        idPlanillaSemanal, idAsistencia, idTipoMovimiento, Cantidad, Monto, Fecha
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
                    SET IngresoBruto    = IngresoBruto    + @ingresoBruto
                      , TotalDeducciones = TotalDeducciones + @totalDed
                    WHERE id = @idPlanillaMens;

                    FETCH NEXT FROM cClose INTO @idEmpClose, @idPlanillaClose, @idPlanillaSemClose;
                END

                CLOSE cClose;
                DEALLOCATE cClose;
            END
            -- Fin bloque jueves

            COMMIT TRANSACTION;

            FETCH NEXT FROM cDates INTO @FechaActual;
        END
        -- Fin WHILE fechas

        CLOSE cDates;
        DEALLOCATE cDates;

        DROP TABLE #TempAsist;
        DROP TABLE #TempClose;

    END TRY
    BEGIN CATCH
        -- Limpiar cursores si quedaron abiertos
        IF CURSOR_STATUS('local', 'cDates')  >= 0 BEGIN CLOSE cDates;  DEALLOCATE cDates;  END
        IF CURSOR_STATUS('local', 'cAsist')  >= 0 BEGIN CLOSE cAsist;  DEALLOCATE cAsist;  END
        IF CURSOR_STATUS('local', 'cClose')  >= 0 BEGIN CLOSE cClose;  DEALLOCATE cClose;  END

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
DECLARE @myXml XML = N'
<Operaciones>
    <FechaOperacion Fecha="2026-04-30">
        <InsertarEmpleado ValorDocumentoIdentidad="110011001" Nombre="Carlos Mendoza"
            Puesto="Electricista" CuentaBancaria="CR2415115201001026284066"
            FechaContratacion="2026-05-01"/>
        <InsertarEmpleado ValorDocumentoIdentidad="305827920" Nombre="Ana Rodriguez"
            Puesto="Cajero" CuentaBancaria="CR2415115201901026284067"
            FechaContratacion="2026-05-01"/>
        <InsertarEmpleado ValorDocumentoIdentidad="194739285" Nombre="Nicolas Vargas"
            Puesto="Conductor" CuentaBancaria="CR2415115201901026392748"
            FechaContratacion="2026-05-01"/>

        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="110011001"
            TipoDeduccion="Ahorro Asociacion Solidarista" MontoFijo="0.00"/>
        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="305827920"
            TipoDeduccion="Pension Alimenticia" MontoFijo="50000.00"/>

        <AsignarJornada ValorDocumentoIdentidad="110011001" Jornada="Diurno"
            InicioSemana="2026-05-01"/>
        <AsignarJornada ValorDocumentoIdentidad="305827920" Jornada="Vespertino"
            InicioSemana="2026-05-01"/>
        <AsignarJornada ValorDocumentoIdentidad="194739285" Jornada="Nocturno"
            InicioSemana="2026-05-01"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-01">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-01 06:00" HoraSalida="2026-05-01 16:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-01 14:00" HoraSalida="2026-05-02 01:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-01 22:00" HoraSalida="2026-05-02 08:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-02">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-02 06:00" HoraSalida="2026-05-02 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-02 14:00" HoraSalida="2026-05-02 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-02 22:00" HoraSalida="2026-05-03 06:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-03">
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-03 14:00" HoraSalida="2026-05-03 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-03 22:00" HoraSalida="2026-05-04 06:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-04">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-04 06:00" HoraSalida="2026-05-04 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-04 14:00" HoraSalida="2026-05-04 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-04 22:00" HoraSalida="2026-05-05 08:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-05">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-05 06:00" HoraSalida="2026-05-05 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-05 14:00" HoraSalida="2026-05-05 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-05 22:00" HoraSalida="2026-05-06 06:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-06">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-06 06:00" HoraSalida="2026-05-06 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-06 14:00" HoraSalida="2026-05-07 00:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-06 22:00" HoraSalida="2026-05-07 06:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-07">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-07 06:00" HoraSalida="2026-05-07 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-07 14:00" HoraSalida="2026-05-07 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-07 22:00" HoraSalida="2026-05-08 06:00"/>

        <AsignarJornada ValorDocumentoIdentidad="110011001" Jornada="Vespertino" InicioSemana="2026-05-08"/>
        <AsignarJornada ValorDocumentoIdentidad="305827920" Jornada="Nocturno"   InicioSemana="2026-05-08"/>
        <AsignarJornada ValorDocumentoIdentidad="194739285" Jornada="Diurno"     InicioSemana="2026-05-08"/>

        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="305827920"
            TipoDeduccion="Ahorro Vacacional" MontoFijo="25000.00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-08">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-08 14:00" HoraSalida="2026-05-08 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-08 22:00" HoraSalida="2026-05-09 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-08 06:00" HoraSalida="2026-05-08 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-09">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-09 14:00" HoraSalida="2026-05-09 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-09 22:00" HoraSalida="2026-05-10 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-09 06:00" HoraSalida="2026-05-09 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-10">
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-10 22:00" HoraSalida="2026-05-11 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-10 06:00" HoraSalida="2026-05-10 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-11">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-11 14:00" HoraSalida="2026-05-11 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-11 06:00" HoraSalida="2026-05-11 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-12">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-12 14:00" HoraSalida="2026-05-12 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-12 22:00" HoraSalida="2026-05-13 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-12 06:00" HoraSalida="2026-05-12 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-13">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-13 14:00" HoraSalida="2026-05-13 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-13 22:00" HoraSalida="2026-05-14 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-13 06:00" HoraSalida="2026-05-13 14:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-14">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-14 14:00" HoraSalida="2026-05-14 22:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-14 22:00" HoraSalida="2026-05-15 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-14 06:00" HoraSalida="2026-05-14 14:00"/>

        <AsignarJornada ValorDocumentoIdentidad="110011001" Jornada="Nocturno"   InicioSemana="2026-05-15"/>
        <AsignarJornada ValorDocumentoIdentidad="305827920" Jornada="Diurno"     InicioSemana="2026-05-15"/>
        <AsignarJornada ValorDocumentoIdentidad="194739285" Jornada="Vespertino" InicioSemana="2026-05-15"/>

        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="110011001"
            TipoDeduccion="Ahorro Vacacional" MontoFijo="15000.00"/>
        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="194739285"
            TipoDeduccion="Ahorro Asociacion Solidarista" MontoFijo="0.00"/>

        <DesasociaEmpleadoConDeduccion ValorDocumentoIdentidad="194739285"
            TipoDeduccion="Pension Alimenticia"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-15">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-15 22:00" HoraSalida="2026-05-16 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-15 06:00" HoraSalida="2026-05-15 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-15 14:00" HoraSalida="2026-05-15 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-16">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-16 22:00" HoraSalida="2026-05-17 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-16 06:00" HoraSalida="2026-05-16 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-16 14:00" HoraSalida="2026-05-16 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-17">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-17 22:00" HoraSalida="2026-05-18 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-17 06:00" HoraSalida="2026-05-17 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-17 14:00" HoraSalida="2026-05-17 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-18">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-18 22:00" HoraSalida="2026-05-19 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-18 06:00" HoraSalida="2026-05-18 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-18 14:00" HoraSalida="2026-05-18 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-19">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-19 22:00" HoraSalida="2026-05-20 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-19 06:00" HoraSalida="2026-05-19 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-19 14:00" HoraSalida="2026-05-19 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-20">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-20 22:00" HoraSalida="2026-05-21 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-20 06:00" HoraSalida="2026-05-20 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-20 14:00" HoraSalida="2026-05-20 22:00"/>
    </FechaOperacion>

    <FechaOperacion Fecha="2026-05-21">
        <MarcaAsistencia ValorDocumentoIdentidad="110011001" HoraEntrada="2026-05-21 22:00" HoraSalida="2026-05-22 06:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="305827920" HoraEntrada="2026-05-21 06:00" HoraSalida="2026-05-21 14:00"/>
        <MarcaAsistencia ValorDocumentoIdentidad="194739285" HoraEntrada="2026-05-21 14:00" HoraSalida="2026-05-21 22:00"/>

        <AsignarJornada ValorDocumentoIdentidad="110011001" Jornada="Diurno"     InicioSemana="2026-05-22"/>
        <AsignarJornada ValorDocumentoIdentidad="305827920" Jornada="Vespertino" InicioSemana="2026-05-22"/>
        <AsignarJornada ValorDocumentoIdentidad="194739285" Jornada="Nocturno"   InicioSemana="2026-05-22"/>

        <AsociaEmpleadoConDeduccion ValorDocumentoIdentidad="305827920"
            TipoDeduccion="Pension Alimenticia" MontoFijo="30000.00"/>

        <DesasociaEmpleadoConDeduccion ValorDocumentoIdentidad="110011001"
            TipoDeduccion="Ahorro Asociacion Solidarista"/>
    </FechaOperacion>
</Operaciones>';

EXEC dbo.SP_ProcesarFechaOperacion @XmlOperaciones = @myXml;
GO
