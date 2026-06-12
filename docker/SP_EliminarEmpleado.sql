CREATE OR ALTER PROCEDURE dbo.SP_EliminarEmpleado
    @inIdEmpleado INT
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Empleado e
            WHERE (e.id = @inIdEmpleado)
            AND (e.Activo = 1)
        )
        BEGIN
            SET @outResultCode = 52001;
            RETURN;
        END

        BEGIN TRANSACTION;

            UPDATE dbo.Empleado
            SET Activo = 0
            WHERE (id = @inIdEmpleado);

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
