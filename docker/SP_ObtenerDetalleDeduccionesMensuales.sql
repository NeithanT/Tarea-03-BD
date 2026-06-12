CREATE OR ALTER PROCEDURE dbo.SP_ObtenerDetalleDeduccionesMensuales
    @inEmpleadoId INT
    , @inPlanillaMensualId INT
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        THROW 57000, 'SP_ObtenerDetalleDeduccionesMensuales: pendiente de implementar.', 1;

    END TRY
    BEGIN CATCH

        SET @outResultCode = 57099;

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
END
GO
