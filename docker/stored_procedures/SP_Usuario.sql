USE Tarea03;
GO

CREATE PROCEDURE dbo.SP_Usuario_Insertar
    @inUsername VARCHAR(100)
    , @inContrasena VARCHAR(512)
    , @inNombreUsuario VARCHAR(100)
    , @inContrasenaHash VARCHAR(512)
    , @inIdRol INT
    , @outId INT OUTPUT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;
    SET @outId = 0;

    BEGIN TRY

        IF EXISTS (
            SELECT 1
            FROM dbo.Usuario u
            WHERE (u.Username = @inUsername)
        )
        BEGIN
            SET @outResultCode = 55001;
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM dbo.Usuario u
            WHERE (u.NombreUsuario = @inNombreUsuario)
        )
        BEGIN
            SET @outResultCode = 55002;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.TipoUsuario tu
            WHERE (tu.id = @inIdRol)
        )
        BEGIN
            SET @outResultCode = 55003;
            RETURN;
        END

        BEGIN TRANSACTION;

            INSERT INTO dbo.Usuario (
                Username
                , Contrasena
                , NombreUsuario
                , ContrasenaHash
                , idRol
                , Activo
            )
            VALUES (
                @inUsername
                , @inContrasena
                , @inNombreUsuario
                , @inContrasenaHash
                , @inIdRol
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

        SET @outResultCode = 55099;

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

CREATE PROCEDURE dbo.SP_Usuario_ObtenerPorId
    @inId INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        SELECT
            u.id
            , u.Username
            , u.NombreUsuario
            , u.idRol
            , tu.Nombre AS NombreRol
            , u.Activo
        FROM dbo.Usuario u
        INNER JOIN dbo.TipoUsuario tu ON (tu.id = u.idRol)
        WHERE (u.id = @inId);

    END TRY
    BEGIN CATCH

        SET @outResultCode = 55099;

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

CREATE PROCEDURE dbo.SP_Usuario_ObtenerPorUsername
    @inUsername VARCHAR(100)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        SELECT
            u.id
            , u.Username
            , u.ContrasenaHash
            , u.NombreUsuario
            , u.idRol
            , tu.Nombre AS NombreRol
            , u.Activo
        FROM dbo.Usuario u
        INNER JOIN dbo.TipoUsuario tu ON (tu.id = u.idRol)
        WHERE (u.Username = @inUsername)
        AND (u.Activo = 1);

    END TRY
    BEGIN CATCH

        SET @outResultCode = 55099;

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

CREATE PROCEDURE dbo.SP_Usuario_Listar
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        SELECT
            u.id
            , u.Username
            , u.NombreUsuario
            , u.idRol
            , tu.Nombre AS NombreRol
            , u.Activo
        FROM dbo.Usuario u
        INNER JOIN dbo.TipoUsuario tu ON (tu.id = u.idRol)
        ORDER BY u.Username;

    END TRY
    BEGIN CATCH

        SET @outResultCode = 55099;

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

CREATE PROCEDURE dbo.SP_Usuario_Actualizar
    @inId INT
    , @inUsername VARCHAR(100)
    , @inNombreUsuario VARCHAR(100)
    , @inIdRol INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Usuario u
            WHERE (u.id = @inId)
        )
        BEGIN
            SET @outResultCode = 55001;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.TipoUsuario tu
            WHERE (tu.id = @inIdRol)
        )
        BEGIN
            SET @outResultCode = 55003;
            RETURN;
        END

        BEGIN TRANSACTION;

            UPDATE dbo.Usuario
            SET Username = @inUsername
                , NombreUsuario = @inNombreUsuario
                , idRol = @inIdRol
            WHERE (id = @inId);

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        SET @outResultCode = 55099;

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

CREATE PROCEDURE dbo.SP_Usuario_Eliminar
    @inId INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Usuario u
            WHERE (u.id = @inId)
            AND (u.Activo = 1)
        )
        BEGIN
            SET @outResultCode = 55001;
            RETURN;
        END

        BEGIN TRANSACTION;

            UPDATE dbo.Usuario
            SET Activo = 0
            WHERE (id = @inId);

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        SET @outResultCode = 55099;

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
