CREATE OR ALTER PROCEDURE dbo.SP_ObtenerDetalleAsistenciasSemanales
    @inEmpleadoId INT
    , @inPlanillaSemanalId INT
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

        SELECT
            CONVERT(VARCHAR(10), aj.Fecha, 23) AS Fecha
            , CONVERT(VARCHAR(5), aj.HoraEntrada, 108) AS HoraEntrada
            , CONVERT(VARCHAR(5), aj.HoraSalida, 108) AS HoraSalida
            , ISNULL(SUM(CASE WHEN mp.idTipoMovimiento = @tmOrd THEN mp.Cantidad ELSE 0 END), 0) AS HorasOrdinarias
            , ISNULL(SUM(CASE WHEN mp.idTipoMovimiento = @tmOrd THEN mp.Monto ELSE 0 END), 0) AS MontoOrdinario
            , ISNULL(SUM(CASE WHEN mp.idTipoMovimiento = @tmExtra THEN mp.Cantidad ELSE 0 END), 0) AS HorasExtra
            , ISNULL(SUM(CASE WHEN mp.idTipoMovimiento = @tmExtra THEN mp.Monto ELSE 0 END), 0) AS MontoExtra
            , ISNULL(SUM(CASE WHEN mp.idTipoMovimiento = @tmExtraDob THEN mp.Cantidad ELSE 0 END), 0) AS HorasExtraDoble
            , ISNULL(SUM(CASE WHEN mp.idTipoMovimiento = @tmExtraDob THEN mp.Monto ELSE 0 END), 0) AS MontoExtraDoble
        FROM dbo.MovPlanilla mp
        INNER JOIN dbo.PlanillaSemanal ps ON (ps.id = mp.idPlanillaSemanal)
        INNER JOIN dbo.Planilla p ON (p.id = ps.idPlanilla)
        INNER JOIN dbo.AsistenciaAJornada aj ON (aj.id = mp.idAsistencia)
        WHERE (ps.id = @inPlanillaSemanalId)
        AND (p.idEmpleado = @inEmpleadoId)
        AND (mp.idAsistencia IS NOT NULL)
        GROUP BY aj.Fecha, aj.HoraEntrada, aj.HoraSalida
        ORDER BY aj.Fecha;

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
