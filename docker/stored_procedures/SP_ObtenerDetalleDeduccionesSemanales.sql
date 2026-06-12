CREATE OR ALTER PROCEDURE dbo.SP_ObtenerDetalleDeduccionesSemanales
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
    td.Nombre AS NombreDeduccion
    , td.Porcentual
    , CASE WHEN td.Porcentual = 1 THEN td.Valor ELSE NULL END AS Porcentaje
    , m.NuevoSaldo AS Monto
  FROM dbo.MovPlanilla m
  INNER JOIN dbo.TipoMovimiento tm ON tm.id = m.idTipoMovimiento
  INNER JOIN dbo.TipoDeduccion td ON td.idTipoMovimiento = tm.id
  WHERE m.idPlanillaSemanal = @PlanillaSemanalId
    AND m.idAsistencia IS NULL
  ORDER BY td.Nombre;
END;
GO
