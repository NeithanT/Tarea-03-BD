USE Tarea03;
GO

CREATE PROCEDURE dbo.SP_Empleado_Insertar
    @inCedula VARCHAR(20)
    , @inNombre VARCHAR(255)
    , @inApellido VARCHAR(255)
    , @inFechaIngreso DATE
    , @inFechaNacimiento DATE
    , @inPuestoId INT
    , @outId INT OUTPUT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;
    SET @outId = 0;

    BEGIN TRY

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Puesto p
            WHERE (p.id = @inPuestoId)
        )
        BEGIN
            SET @outResultCode = 52001;
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM dbo.Empleado e
            WHERE (e.Cedula = @inCedula)
        )
        BEGIN
            SET @outResultCode = 52002;
            RETURN;
        END

        BEGIN TRANSACTION;

            INSERT INTO dbo.Empleado (
                Cedula
                , Nombre
                , Apellido
                , FechaIngreso
                , FechaNacimiento
                , PuestoId
                , Activo
            )
            VALUES (
                @inCedula
                , @inNombre
                , @inApellido
                , @inFechaIngreso
                , @inFechaNacimiento
                , @inPuestoId
                , 1
            );

            SET @outId = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        SET @outResultCode = 52099;

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

    END CATCH
END
GO

CREATE PROCEDURE dbo.SP_Empleado_ObtenerPorId
    @inId INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        SELECT
            e.id
            , e.Cedula
            , e.Nombre
            , e.Apellido
            , e.FechaIngreso
            , e.FechaNacimiento
            , e.PuestoId
            , p.Nombre AS NombrePuesto
            , p.SalarioPorHora
            , e.Activo
        FROM dbo.Empleado e
        INNER JOIN dbo.Puesto p ON (p.id = e.PuestoId)
        WHERE (e.id = @inId);

    END TRY
    BEGIN CATCH

        SET @outResultCode = 52099;

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

    END CATCH
END
GO

CREATE PROCEDURE dbo.SP_Empleado_Listar
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        SELECT
            e.id
            , e.Cedula
            , e.Nombre
            , e.Apellido
            , p.Nombre AS NombrePuesto
            , e.FechaIngreso
            , e.Activo
        FROM dbo.Empleado e
        INNER JOIN dbo.Puesto p ON (p.id = e.PuestoId)
        WHERE (e.Activo = 1)
        ORDER BY e.Nombre, e.Apellido;

    END TRY
    BEGIN CATCH

        SET @outResultCode = 52099;

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

    END CATCH
END
GO

CREATE PROCEDURE dbo.SP_Empleado_ListarConFiltro
    @inFiltro VARCHAR(255)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        SELECT
            e.id
            , e.Cedula
            , e.Nombre
            , e.Apellido
            , p.Nombre AS NombrePuesto
            , e.FechaIngreso
            , e.Activo
        FROM dbo.Empleado e
        INNER JOIN dbo.Puesto p ON (p.id = e.PuestoId)
        WHERE (e.Activo = 1)
        AND ((e.Nombre + ' ' + e.Apellido) LIKE ('%' + @inFiltro + '%'))
        ORDER BY e.Nombre, e.Apellido;

    END TRY
    BEGIN CATCH

        SET @outResultCode = 52099;

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

    END CATCH
END
GO

CREATE PROCEDURE dbo.SP_Empleado_Actualizar
    @inId INT
    , @inCedula VARCHAR(20)
    , @inNombre VARCHAR(255)
    , @inApellido VARCHAR(255)
    , @inFechaIngreso DATE
    , @inFechaNacimiento DATE
    , @inPuestoId INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Empleado e
            WHERE (e.id = @inId)
        )
        BEGIN
            SET @outResultCode = 52001;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Puesto p
            WHERE (p.id = @inPuestoId)
        )
        BEGIN
            SET @outResultCode = 52003;
            RETURN;
        END

        BEGIN TRANSACTION;

            UPDATE dbo.Empleado
            SET Cedula = @inCedula
                , Nombre = @inNombre
                , Apellido = @inApellido
                , FechaIngreso = @inFechaIngreso
                , FechaNacimiento = @inFechaNacimiento
                , PuestoId = @inPuestoId
            WHERE (id = @inId);

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        SET @outResultCode = 52099;

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

    END CATCH
END
GO

CREATE PROCEDURE dbo.SP_Empleado_Eliminar
    @inId INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Empleado e
            WHERE (e.id = @inId)
            AND (e.Activo = 1)
        )
        BEGIN
            SET @outResultCode = 52001;
            RETURN;
        END

        BEGIN TRANSACTION;

            UPDATE dbo.Empleado
            SET Activo = 0
            WHERE (id = @inId);

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        SET @outResultCode = 52099;

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

    END CATCH
END
GO
