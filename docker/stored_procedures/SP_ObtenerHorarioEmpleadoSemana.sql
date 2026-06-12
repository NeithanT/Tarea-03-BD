CREATE OR ALTER PROCEDURE dbo.SP_ObtenerHorarioEmpleadoSemana
    @inIdEmpleado INT
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        DECLARE @idSemana INT;

        SELECT TOP 1 @idSemana = hj.idSemana
        FROM dbo.HorarioJornada hj
        WHERE (hj.idEmpleado = @inIdEmpleado)
        ORDER BY hj.idSemana DESC;

        IF (@idSemana IS NULL)
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
            , CONVERT(VARCHAR(10), DATEADD(DAY, (hj.DiaSemana + 2) % 7, s.FechaInicio), 23) AS Fecha
            , CONVERT(VARCHAR(10), s.FechaInicio, 23) AS SemanaInicio
            , CONVERT(VARCHAR(10), s.FechaFin, 23) AS SemanaFin
        FROM dbo.HorarioJornada hj
        INNER JOIN dbo.TipoJornada tj ON (tj.id = hj.idTipoJornada)
        INNER JOIN dbo.Semana s ON (s.id = hj.idSemana)
        WHERE (hj.idEmpleado = @inIdEmpleado)
        AND (hj.idSemana = @idSemana)
        ORDER BY DATEADD(DAY, (hj.DiaSemana + 2) % 7, s.FechaInicio);

    END TRY
    BEGIN CATCH

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
