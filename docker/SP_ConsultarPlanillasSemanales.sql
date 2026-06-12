CREATE OR ALTER PROCEDURE dbo.SP_ConsultarPlanillasSemanales
    @inEmpleadoId INT
    , @inLimit INT
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        DECLARE @tmOrd INT;
        DECLARE @tmExtra INT;
        DECLARE @tmExtraDob INT;

        SELECT @tmOrd = tm.id FROM dbo.TipoMovimiento tm WHERE (tm.Nombre = 'Credito Horas Ordinarias');
        SELECT @tmExtra = tm.id FROM dbo.TipoMovimiento tm WHERE (tm.Nombre = 'Credito Horas Extra Normales');
        SELECT @tmExtraDob = tm.id FROM dbo.TipoMovimiento tm WHERE (tm.Nombre = 'Credito Horas Extra Dobles');

        SELECT TOP (@inLimit)
            ps.id
            , CONVERT(VARCHAR(10), s.FechaInicio, 23) AS FechaInicio
            , CONVERT(VARCHAR(10), s.FechaFin, 23) AS FechaFin
            , p.IngresoBruto AS SalarioBruto
            , p.TotalDeducciones
            , p.IngresoNeto AS SalarioNeto
            , ISNULL(SUM(CASE WHEN mp.idTipoMovimiento = @tmOrd THEN mp.Cantidad ELSE 0 END), 0) AS HorasOrdinarias
            , ISNULL(SUM(CASE WHEN mp.idTipoMovimiento = @tmExtra THEN mp.Cantidad ELSE 0 END), 0) AS HorasExtra
            , ISNULL(SUM(CASE WHEN mp.idTipoMovimiento = @tmExtraDob THEN mp.Cantidad ELSE 0 END), 0) AS HorasExtraDoble
        FROM dbo.PlanillaSemanal ps
        INNER JOIN dbo.Planilla p ON (p.id = ps.idPlanilla)
        INNER JOIN dbo.Semana s ON (s.id = ps.idSemana)
        LEFT JOIN dbo.MovPlanilla mp ON (mp.idPlanillaSemanal = ps.id)
        WHERE (p.idEmpleado = @inEmpleadoId)
        GROUP BY
            ps.id
            , s.FechaInicio
            , s.FechaFin
            , p.IngresoBruto
            , p.TotalDeducciones
            , p.IngresoNeto
        ORDER BY s.FechaInicio DESC;

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
