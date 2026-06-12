CREATE OR ALTER PROCEDURE dbo.SP_ObtenerDetalleAsistenciasSemanales
  @EmpleadoId INT
  , @PlanillaSemanalId INT
AS
BEGIN
  SET NOCOUNT ON;

  -- Validar que la planilla semanal pertenezca al empleado
  IF NOT EXISTS (
    SELECT 1
    FROM dbo.PlanillaSemanal ps
    INNER JOIN dbo.Planilla p ON p.id = ps.idPlanilla
    WHERE ps.id = @PlanillaSemanalId
      AND p.idEmpleado = @EmpleadoId
  )
    RETURN;

  SELECT
    CONVERT(VARCHAR(10), a.Fecha, 23) AS Fecha
    , CONVERT(VARCHAR(5), a.HoraEntrada, 108) AS HoraEntrada
    , CONVERT(VARCHAR(5), a.HoraSalida, 108) AS HoraSalida
    , ISNULL(SUM(CASE WHEN tm.Nombre = 'Credito Horas Ordinarias' THEN m.Monto END), 0) AS HorasOrdinarias
    , ISNULL(SUM(CASE WHEN tm.Nombre = 'Credito Horas Ordinarias' THEN m.NuevoSaldo END), 0) AS MontoOrdinario
    , ISNULL(SUM(CASE WHEN tm.Nombre = 'Credito Horas Extra Normales' THEN m.Monto END), 0) AS HorasExtraNormales
    , ISNULL(SUM(CASE WHEN tm.Nombre = 'Credito Horas Extra Normales' THEN m.NuevoSaldo END), 0) AS MontoExtraNormal
    , ISNULL(SUM(CASE WHEN tm.Nombre = 'Credito Horas Extra Dobles' THEN m.Monto END), 0) AS HorasExtraDobles
    , ISNULL(SUM(CASE WHEN tm.Nombre = 'Credito Horas Extra Dobles' THEN m.NuevoSaldo END), 0) AS MontoExtraDoble
  FROM dbo.MovPlanilla m
  INNER JOIN dbo.AsistenciaAJornada a ON a.id = m.idAsistencia
  INNER JOIN dbo.TipoMovimiento tm ON tm.id = m.idTipoMovimiento
  WHERE m.idPlanillaSemanal = @PlanillaSemanalId
    AND m.idAsistencia IS NOT NULL
  GROUP BY a.id, a.Fecha, a.HoraEntrada, a.HoraSalida
  ORDER BY a.Fecha;
END;
GO
