CREATE OR ALTER PROCEDURE dbo.SP_ObtenerDetalleDeduccionesMensuales
  @EmpleadoId INT
  , @PlanillaMensualId INT
AS
BEGIN
  SET NOCOUNT ON;

  -- Resolver mes y validar que la planilla mensual pertenezca al empleado
  DECLARE @idMes INT;

  SELECT @idMes = pm.idMes
  FROM dbo.PlanillaMensual pm
  INNER JOIN dbo.Planilla p ON p.id = pm.idPlanilla
  WHERE pm.id = @PlanillaMensualId
    AND p.idEmpleado = @EmpleadoId;

  IF @idMes IS NULL
    RETURN;

  -- Sumar las deducciones de cada semana del mes para ese empleado,
  -- agrupadas por tipo de deduccion
  SELECT
    td.Nombre AS NombreDeduccion
    , td.Porcentual
    , CASE WHEN td.Porcentual = 1 THEN td.Valor ELSE NULL END AS Porcentaje
    , SUM(m.NuevoSaldo) AS Monto
  FROM dbo.MovPlanilla m
  INNER JOIN dbo.PlanillaSemanal ps ON ps.id = m.idPlanillaSemanal
  INNER JOIN dbo.Planilla p ON p.id = ps.idPlanilla
  INNER JOIN dbo.Semana s ON s.id = ps.idSemana
  INNER JOIN dbo.TipoMovimiento tm ON tm.id = m.idTipoMovimiento
  INNER JOIN dbo.TipoDeduccion td ON td.idTipoMovimiento = tm.id
  WHERE p.idEmpleado = @EmpleadoId
    AND s.idMes = @idMes
    AND m.idAsistencia IS NULL
  GROUP BY td.id, td.Nombre, td.Porcentual, td.Valor
  ORDER BY td.Nombre;
END;
GO
