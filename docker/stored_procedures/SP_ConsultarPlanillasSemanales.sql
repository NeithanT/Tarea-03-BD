CREATE OR ALTER PROCEDURE dbo.SP_ConsultarPlanillasSemanales
  @EmpleadoId INT
  , @Limit INT
AS
BEGIN
  SET NOCOUNT ON;

  SELECT
    ps.id
    , p.id AS idPlanilla
    , s.NumeroSemana
    , s.Ano
    , CONVERT(VARCHAR(10), s.FechaInicio, 23) AS FechaInicio
    , CONVERT(VARCHAR(10), s.FechaFin, 23) AS FechaFin
    , CONVERT(VARCHAR(10), p.FechaPago, 23) AS FechaPago
    , p.IngresoBruto
    , p.TotalDeducciones
    , p.IngresoNeto
    , ISNULL(mov.HorasOrdinarias, 0) AS HorasOrdinarias
    , ISNULL(mov.HorasExtraNormales, 0) AS HorasExtraNormales
    , ISNULL(mov.HorasExtraDobles, 0) AS HorasExtraDobles
  FROM dbo.Planilla p
  INNER JOIN dbo.PlanillaSemanal ps ON ps.idPlanilla = p.id
  INNER JOIN dbo.Semana s ON s.id = ps.idSemana
  OUTER APPLY (
    SELECT
      SUM(CASE WHEN tm.Nombre = 'Credito Horas Ordinarias' THEN m.Monto END) AS HorasOrdinarias
      , SUM(CASE WHEN tm.Nombre = 'Credito Horas Extra Normales' THEN m.Monto END) AS HorasExtraNormales
      , SUM(CASE WHEN tm.Nombre = 'Credito Horas Extra Dobles' THEN m.Monto END) AS HorasExtraDobles
    FROM dbo.MovPlanilla m
    INNER JOIN dbo.TipoMovimiento tm ON tm.id = m.idTipoMovimiento
    WHERE m.idPlanillaSemanal = ps.id
      AND m.idAsistencia IS NOT NULL
  ) mov
  WHERE p.idEmpleado = @EmpleadoId
  ORDER BY s.FechaFin DESC
  OFFSET 0 ROWS FETCH NEXT @Limit ROWS ONLY;
END;
GO
