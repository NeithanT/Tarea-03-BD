CREATE PROCEDURE dbo.SP_Puesto_Insertar
    @inNombre VARCHAR(255)
    , @inSalarioPorHora DECIMAL(10, 2)
    , @inDescripcion VARCHAR(500)
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
            FROM dbo.Puesto p
            WHERE (p.Nombre = @inNombre)
        )
        BEGIN
            SET @outResultCode = 51001;
            RETURN;
        END

        BEGIN TRANSACTION;

            INSERT INTO dbo.Puesto (
                Nombre
                , SalarioPorHora
                , Descripcion
            )
            VALUES (
                @inNombre
                , @inSalarioPorHora
                , @inDescripcion
            );

            SET @outId = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        SET @outResultCode = 51099;

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

CREATE PROCEDURE dbo.SP_Puesto_ObtenerPorId
    @inId INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        SELECT
            p.id
            , p.Nombre
            , p.SalarioPorHora
            , p.Descripcion
        FROM dbo.Puesto p
        WHERE (p.id = @inId);

    END TRY
    BEGIN CATCH

        SET @outResultCode = 51099;

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

CREATE PROCEDURE dbo.SP_Puesto_Listar
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        SELECT
            p.id
            , p.Nombre
            , p.SalarioPorHora
            , p.Descripcion
        FROM dbo.Puesto p
        ORDER BY p.Nombre;

    END TRY
    BEGIN CATCH

        SET @outResultCode = 51099;

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

CREATE PROCEDURE dbo.SP_Puesto_Actualizar
    @inId INT
    , @inNombre VARCHAR(255)
    , @inSalarioPorHora DECIMAL(10, 2)
    , @inDescripcion VARCHAR(500)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Puesto p
            WHERE (p.id = @inId)
        )
        BEGIN
            SET @outResultCode = 51001;
            RETURN;
        END

        BEGIN TRANSACTION;

            UPDATE dbo.Puesto
            SET Nombre = @inNombre
                , SalarioPorHora = @inSalarioPorHora
                , Descripcion = @inDescripcion
            WHERE (id = @inId);

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        SET @outResultCode = 51099;

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

CREATE PROCEDURE dbo.SP_Puesto_Eliminar
    @inId INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Puesto p
            WHERE (p.id = @inId)
        )
        BEGIN
            SET @outResultCode = 51001;
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM dbo.Empleado e
            WHERE (e.PuestoId = @inId)
            AND (e.Activo = 1)
        )
        BEGIN
            SET @outResultCode = 51002;
            RETURN;
        END

        BEGIN TRANSACTION;

            DELETE FROM dbo.Puesto
            WHERE (id = @inId);

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        SET @outResultCode = 51099;

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
