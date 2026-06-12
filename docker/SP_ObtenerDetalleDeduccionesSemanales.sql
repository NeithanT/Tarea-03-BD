CREATE OR ALTER PROCEDURE dbo.SP_ObtenerDetalleDeduccionesSemanales
    @inEmpleadoId INT
    , @inPlanillaSemanalId INT
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        SELECT
            td.Nombre
            , CASE
                WHEN (td.Porcentual = 1) THEN CAST(td.Valor * 100 AS DECIMAL(5, 2))
                ELSE NULL
              END AS Porcentaje
            , mp.Monto
        FROM dbo.MovPlanilla mp
        INNER JOIN dbo.PlanillaSemanal ps ON (ps.id = mp.idPlanillaSemanal)
        INNER JOIN dbo.Planilla p ON (p.id = ps.idPlanilla)
        INNER JOIN dbo.TipoMovimiento tm ON (tm.id = mp.idTipoMovimiento)
        INNER JOIN dbo.TipoDeduccion td ON (td.idTipoMovimiento = tm.id)
        WHERE (ps.id = @inPlanillaSemanalId)
        AND (p.idEmpleado = @inEmpleadoId)
        AND (tm.Accion = '-');

    END TRY
    BEGIN CATCH

        SET @outResultCode = 56099;

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
