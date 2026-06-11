CREATE OR ALTER PROCEDURE dbo.SP_ObtenerHorarioEmpleadoSemana
  @idEmpleado INT
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @idSemana INT;
  SELECT TOP 1 @idSemana = idSemana
  FROM dbo.HorarioJornada
  WHERE idEmpleado = @idEmpleado
  ORDER BY idSemana DESC;

  IF @idSemana IS NULL
    RETURN;

  SELECT
    hj.DiaSemana
    , CASE hj.DiaSemana
        WHEN 1 THEN 'Lunes'
        WHEN 2 THEN 'Martes'
        WHEN 3 THEN 'Miércoles'
        WHEN 4 THEN 'Jueves'
        WHEN 5 THEN 'Viernes'
        WHEN 6 THEN 'Sábado'
        WHEN 7 THEN 'Domingo'
      END AS NombreDia
    , hj.EsDiaDescanso
    , tj.Nombre AS NombreJornada
    , CONVERT(VARCHAR(5), tj.HoraInicio, 108) AS HoraInicio
    , CONVERT(VARCHAR(5), tj.HoraFin, 108) AS HoraFin
    , CONVERT(VARCHAR(10), DATEADD(day, (hj.DiaSemana + 2) % 7, s.FechaInicio), 23) AS Fecha
    , CONVERT(VARCHAR(10), s.FechaInicio, 23) AS SemanaInicio
    , CONVERT(VARCHAR(10), s.FechaFin, 23) AS SemanaFin
  FROM dbo.HorarioJornada hj
  INNER JOIN dbo.TipoJornada tj ON hj.idTipoJornada = tj.id
  INNER JOIN dbo.Semana s ON hj.idSemana = s.id
  WHERE hj.idEmpleado = @idEmpleado
    AND hj.idSemana = @idSemana
  ORDER BY DATEADD(day, (hj.DiaSemana + 2) % 7, s.FechaInicio);
END;
GO
