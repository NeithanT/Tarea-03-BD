CREATE OR ALTER PROCEDURE dbo.SP_ListarEmpleadosConFiltro
    @inFiltro NVARCHAR(255)
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        SELECT
            e.id
            , e.Cedula
            , e.Nombre
            , e.Apellido
            , e.FechaIngreso
            , e.FechaNacimiento
            , p.Nombre AS Puesto
            , e.Activo
        FROM dbo.Empleado e
        INNER JOIN dbo.Puesto p ON (p.id = e.idPuesto)
        WHERE (e.Activo = 1)
        AND ((e.Nombre + ' ' + e.Apellido) LIKE ('%' + @inFiltro + '%'))
        ORDER BY e.Nombre, e.Apellido;

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
