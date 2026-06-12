CREATE OR ALTER PROCEDURE dbo.SP_ConsultarPlanillasMensuales
  @EmpleadoId INT
  , @Limit INT
AS
BEGIN
  SET NOCOUNT ON;

  SELECT
    pm.id
    , p.id AS idPlanilla
    , m.Numero
    , m.Ano
    , CONVERT(VARCHAR(10), m.FechaInicio, 23) AS FechaInicio
    , CONVERT(VARCHAR(10), m.FechaFin, 23) AS FechaFin
    , CONVERT(VARCHAR(10), p.FechaPago, 23) AS FechaPago
    , p.IngresoBruto
    , p.TotalDeducciones
    , p.IngresoNeto
  FROM dbo.Planilla p
  INNER JOIN dbo.PlanillaMensual pm ON pm.idPlanilla = p.id
  INNER JOIN dbo.Mes m ON m.id = pm.idMes
  WHERE p.idEmpleado = @EmpleadoId
  ORDER BY m.Ano DESC, m.Numero DESC
  OFFSET 0 ROWS FETCH NEXT @Limit ROWS ONLY;
END;
GO
