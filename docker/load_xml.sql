USE Tarea03;
GO

SET NOCOUNT ON;
GO


CREATE PROCEDURE dbo.spLoadTiposJornada
    @inXml XML
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TipoJornada (
            id
            , Nombre
            , HoraInicio
            , HoraFin
        )
        SELECT
            TRY_CAST(JornadaRow.value('@Id', 'INT') AS INT)
            , JornadaRow.value('@Nombre', 'VARCHAR(50)')
            , TRY_CAST(JornadaRow.value('@HoraInicio', 'VARCHAR(20)') AS TIME(0))
            , TRY_CAST(JornadaRow.value('@HoraFin', 'VARCHAR(20)') AS TIME(0))
        FROM @inXml.nodes('/Datos/TiposJornada/TipoJornada') AS T(JornadaRow);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        INSERT INTO dbo.DBError (
            Username
            , [Number]
            , [State]
            , Severity
            , [Line]
            , [Procedure]
            , [Message]
            , [DateTime]
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


CREATE PROCEDURE dbo.spLoadPuestos
    @inXml XML
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Puesto (
            Nombre
            , SalarioPorHora
        )
        SELECT
            PuestoRow.value('@Nombre', 'VARCHAR(255)')
            , TRY_CAST(PuestoRow.value('@SalarioXHora', 'NVARCHAR(50)') AS DECIMAL(10, 2))
        FROM @inXml.nodes('/Datos/Puestos/Puesto') AS T(PuestoRow);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        INSERT INTO dbo.DBError (
            Username
            , [Number]
            , [State]
            , Severity
            , [Line]
            , [Procedure]
            , [Message]
            , [DateTime]
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


CREATE PROCEDURE dbo.spLoadFeriados
    @inXml XML
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Feriado (
            id
            , Nombre
            , Fecha
        )
        SELECT
            TRY_CAST(FeriadoRow.value('@Id', 'INT') AS INT)
            , FeriadoRow.value('@Nombre', 'VARCHAR(255)')
            , TRY_CAST(FeriadoRow.value('@Fecha', 'NVARCHAR(20)') AS DATE)
        FROM @inXml.nodes('/Datos/Feriados/Feriado') AS T(FeriadoRow);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        INSERT INTO dbo.DBError (
            Username
            , [Number]
            , [State]
            , Severity
            , [Line]
            , [Procedure]
            , [Message]
            , [DateTime]
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


CREATE PROCEDURE dbo.spLoadTiposEvento
    @inXml XML
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TipoEvento (
            id
            , Nombre
        )
        SELECT
            TRY_CAST(TipoEventoRow.value('@Id', 'INT') AS INT)
            , TipoEventoRow.value('@Nombre', 'VARCHAR(100)')
        FROM @inXml.nodes('/Datos/TiposEvento/TipoEvento') AS T(TipoEventoRow);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        INSERT INTO dbo.DBError (
            Username
            , [Number]
            , [State]
            , Severity
            , [Line]
            , [Procedure]
            , [Message]
            , [DateTime]
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


CREATE PROCEDURE dbo.spLoadTiposMovimiento
    @inXml XML
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TipoMovimiento (
            id
            , Nombre
            , Accion
        )
        SELECT
            TRY_CAST(TipoMovRow.value('@Id', 'INT') AS INT)
            , TipoMovRow.value('@Nombre', 'VARCHAR(100)')
            , CASE TipoMovRow.value('@Accion', 'CHAR(1)')
                WHEN 'C' THEN '+'
                WHEN 'D' THEN '-'
                ELSE TipoMovRow.value('@Accion', 'CHAR(1)')
              END
        FROM @inXml.nodes('/Datos/TiposMovimiento/TipoMovimiento') AS T(TipoMovRow);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        INSERT INTO dbo.DBError (
            Username
            , [Number]
            , [State]
            , Severity
            , [Line]
            , [Procedure]
            , [Message]
            , [DateTime]
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


CREATE PROCEDURE dbo.spLoadTiposDeduccion
    @inXml XML
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TipoDeduccion (
            id
            , Nombre
            , Obligatorio
            , Porcentual
            , Valor
            , TipoMovimientoId
        )
        SELECT
            TRY_CAST(TipoDeducRow.value('@Id', 'INT') AS INT)
            , TipoDeducRow.value('@Nombre', 'VARCHAR(100)')
            , TRY_CAST(TipoDeducRow.value('@EsObligatoria', 'BIT') AS BIT)
            , TRY_CAST(TipoDeducRow.value('@EsPorcentual', 'BIT') AS BIT)
            , TRY_CAST(TipoDeducRow.value('@Valor', 'NVARCHAR(20)') AS DECIMAL(10, 4))
            , (
                SELECT tm.id
                FROM dbo.TipoMovimiento tm
                WHERE tm.Nombre = TipoDeducRow.value('@TipoMovimiento', 'VARCHAR(100)')
              )
        FROM @inXml.nodes('/Datos/TiposDeduccion/TipoDeduccion') AS T(TipoDeducRow);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        INSERT INTO dbo.DBError (
            Username
            , [Number]
            , [State]
            , Severity
            , [Line]
            , [Procedure]
            , [Message]
            , [DateTime]
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


CREATE PROCEDURE dbo.spLoadTiposUsuario
    @inXml XML
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET IDENTITY_INSERT dbo.TipoUsuario ON;

        BEGIN TRANSACTION;

        INSERT INTO dbo.TipoUsuario (
            id
            , Nombre
        )
        SELECT DISTINCT
            TRY_CAST(UsuarioRow.value('@Tipo', 'INT') AS INT)
            , CASE TRY_CAST(UsuarioRow.value('@Tipo', 'INT') AS INT)
                WHEN 1 THEN 'Administrador'
                WHEN 2 THEN 'Empleado'
                ELSE 'Usuario'
              END
        FROM @inXml.nodes('/Datos/Usuarios/Usuario') AS T(UsuarioRow);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        SET IDENTITY_INSERT dbo.TipoUsuario OFF;

        INSERT INTO dbo.DBError (
            Username
            , [Number]
            , [State]
            , Severity
            , [Line]
            , [Procedure]
            , [Message]
            , [DateTime]
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

    SET IDENTITY_INSERT dbo.TipoUsuario OFF;
END;
GO


CREATE PROCEDURE dbo.spLoadUsuarios
    @inXml XML
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET IDENTITY_INSERT dbo.Usuario ON;

        BEGIN TRANSACTION;

        INSERT INTO dbo.Usuario (
            id
            , Username
            , Contrasena
            , NombreUsuario
            , ContrasenaHash
            , idRol
            , Activo
        )
        SELECT
            TRY_CAST(UsuarioRow.value('@Id', 'INT') AS INT)
            , UsuarioRow.value('@Username', 'VARCHAR(100)')
            , UsuarioRow.value('@PasswordHash', 'VARCHAR(512)')
            , UsuarioRow.value('@Username', 'VARCHAR(100)')
            , UsuarioRow.value('@PasswordHash', 'VARCHAR(512)')
            , TRY_CAST(UsuarioRow.value('@Tipo', 'INT') AS INT)
            , 1
        FROM @inXml.nodes('/Datos/Usuarios/Usuario') AS T(UsuarioRow);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        SET IDENTITY_INSERT dbo.Usuario OFF;

        INSERT INTO dbo.DBError (
            Username
            , [Number]
            , [State]
            , Severity
            , [Line]
            , [Procedure]
            , [Message]
            , [DateTime]
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

    SET IDENTITY_INSERT dbo.Usuario OFF;
END;
GO


CREATE PROCEDURE dbo.spLoadErrores
    @inXml XML
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Error (
            Codigo
            , Descripcion
        )
        SELECT
            TRY_CAST(ErrorRow.value('@Codigo', 'INT') AS INT)
            , ErrorRow.value('@Descripcion', 'NVARCHAR(255)')
        FROM @inXml.nodes('/Datos/Error/error') AS T(ErrorRow);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        INSERT INTO dbo.DBError (
            Username
            , [Number]
            , [State]
            , Severity
            , [Line]
            , [Procedure]
            , [Message]
            , [DateTime]
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


DECLARE @myXml XML = '<Datos>

    <Puestos>
        <Puesto Nombre="Electricista" SalarioXHora="1200.00"/>
        <Puesto Nombre="Auxiliar de Laboratorio" SalarioXHora="1250.00"/>
        <Puesto Nombre="Operador de Maquina" SalarioXHora="1025.00"/>
        <Puesto Nombre="Cajero" SalarioXHora="1100.00"/>
        <Puesto Nombre="Camarero" SalarioXHora="1000.00"/>
        <Puesto Nombre="Conductor" SalarioXHora="1500.00"/>
        <Puesto Nombre="Asistente" SalarioXHora="1100.00"/>
        <Puesto Nombre="Recepcionista" SalarioXHora="1200.00"/>
        <Puesto Nombre="Fontanero" SalarioXHora="1300.00"/>
        <Puesto Nombre="Albanil" SalarioXHora="1050.00"/>
    </Puestos>

    <TiposJornada>
        <TipoJornada Id="1" Nombre="Diurno" HoraInicio="06:00:00" HoraFin="14:00:00"/>
        <TipoJornada Id="2" Nombre="Vespertino" HoraInicio="14:00:00" HoraFin="22:00:00"/>
        <TipoJornada Id="3" Nombre="Nocturno" HoraInicio="22:00:00" HoraFin="06:00:00"/>
    </TiposJornada>

    <Feriados>
        <Feriado Id="1" Nombre="Dia de Juan Santamaria" Fecha="2026-04-11"/>
        <Feriado Id="2" Nombre="Jueves Santo" Fecha="2026-04-16"/>
        <Feriado Id="3" Nombre="Viernes Santo" Fecha="2026-04-17"/>
        <Feriado Id="4" Nombre="Dia del trabajo" Fecha="2026-05-01"/>
        <Feriado Id="5" Nombre="Anexion del Nicoya" Fecha="2026-07-25"/>
        <Feriado Id="6" Nombre="Dia de la Virgen de los Angeles" Fecha="2026-08-02"/>
        <Feriado Id="7" Nombre="Dia de la Independencia" Fecha="2026-09-15"/>
        <Feriado Id="8" Nombre="Dia de las Culturas" Fecha="2026-10-12"/>
        <Feriado Id="9" Nombre="Navidad" Fecha="2026-12-25"/>
    </Feriados>

    <TiposEvento>
        <TipoEvento Id="1" Nombre="Login Exitoso"/>
        <TipoEvento Id="2" Nombre="Login No Exitoso"/>
        <TipoEvento Id="3" Nombre="Login deshabilitado"/>
        <TipoEvento Id="4" Nombre="Logout"/>
        <TipoEvento Id="5" Nombre="Insercion no exitosa"/>
        <TipoEvento Id="6" Nombre="Insercion exitosa"/>
        <TipoEvento Id="7" Nombre="Update no exitoso"/>
        <TipoEvento Id="8" Nombre="Update exitoso"/>
        <TipoEvento Id="9" Nombre="Intento de borrado"/>
        <TipoEvento Id="10" Nombre="Borrado exitoso"/>
        <TipoEvento Id="11" Nombre="Consulta con filtro de nombre"/>
        <TipoEvento Id="12" Nombre="Consulta con filtro de cedula"/>
        <TipoEvento Id="13" Nombre="Intento de insertar movimiento"/>
        <TipoEvento Id="14" Nombre="Insertar movimiento exitoso"/>
    </TiposEvento>

    <TiposMovimiento>
        <TipoMovimiento Id="1" Nombre="Credito Horas Ordinarias" Accion="C"/>
        <TipoMovimiento Id="2" Nombre="Credito Horas Extra Normales" Accion="C"/>
        <TipoMovimiento Id="3" Nombre="Credito Horas Extra Dobles" Accion="C"/>
        <TipoMovimiento Id="4" Nombre="Caja" Accion="C"/>
        <TipoMovimiento Id="5" Nombre="Debito CCSS" Accion="D"/>
        <TipoMovimiento Id="6" Nombre="Debito Asociacion Solidarista" Accion="D"/>
        <TipoMovimiento Id="7" Nombre="Debito Ahorro Obligatorio" Accion="D"/>
        <TipoMovimiento Id="8" Nombre="Debito Pension Alimenticia" Accion="D"/>
    </TiposMovimiento>

    <TiposDeduccion>
        <TipoDeduccion Id="1" Nombre="Obligatorio de Ley" EsObligatoria="1" EsPorcentual="1" Valor="0.0950" TipoMovimiento="Debito CCSS"/>
        <TipoDeduccion Id="2" Nombre="Ahorro Asociacion Solidarista" EsObligatoria="0" EsPorcentual="1" Valor="0.0500" TipoMovimiento="Debito Asociacion Solidarista"/>
        <TipoDeduccion Id="3" Nombre="Ahorro Vacacional" EsObligatoria="0" EsPorcentual="0" Valor="0.0000" TipoMovimiento="Debito Ahorro Obligatorio"/>
        <TipoDeduccion Id="4" Nombre="Pension Alimenticia" EsObligatoria="0" EsPorcentual="0" Valor="0.0000" TipoMovimiento="Debito Pension Alimenticia"/>
    </TiposDeduccion>

    <Usuarios>
        <Usuario Id="1" Username="admin" PasswordHash="admin123" Tipo="1"/>
        <Usuario Id="2" Username="Goku" PasswordHash="1234" Tipo="1"/>
        <Usuario Id="3" Username="Willy" PasswordHash="1234" Tipo="1"/>
    </Usuarios>

    <Error>
        <error Codigo="50001" Descripcion="Username no existe"/>
        <error Codigo="50002" Descripcion="Password no existe"/>
        <error Codigo="50003" Descripcion="Login deshabilitado"/>
        <error Codigo="50004" Descripcion="Empleado con ValorDocumentoIdentidad ya existe en insercion"/>
        <error Codigo="50005" Descripcion="Empleado con mismo nombre ya existe en insercion"/>
        <error Codigo="50006" Descripcion="Empleado con ValorDocumentoIdentidad ya existe en actualizacion"/>
        <error Codigo="50007" Descripcion="Empleado con mismo nombre ya existe en actualizacion"/>
        <error Codigo="50008" Descripcion="Error de base de datos"/>
        <error Codigo="50009" Descripcion="Nombre de empleado no alfabetico"/>
        <error Codigo="50010" Descripcion="Valor de documento de identidad no alfabetico"/>
        <error Codigo="50011" Descripcion="Monto del movimiento rechazado pues si se aplica el saldo seria negativo."/>
    </Error>

</Datos>';

EXEC dbo.spLoadTiposJornada   @inXml = @myXml;
EXEC dbo.spLoadPuestos        @inXml = @myXml;
EXEC dbo.spLoadFeriados       @inXml = @myXml;
EXEC dbo.spLoadTiposEvento    @inXml = @myXml;
EXEC dbo.spLoadTiposMovimiento @inXml = @myXml;
EXEC dbo.spLoadTiposDeduccion @inXml = @myXml;
EXEC dbo.spLoadTiposUsuario   @inXml = @myXml;
EXEC dbo.spLoadUsuarios       @inXml = @myXml;
EXEC dbo.spLoadErrores        @inXml = @myXml;
GO
