CREATE OR ALTER PROCEDURE dbo.SP_ListarEmpleados
    @inIdAdmin INT
    , @inIp VARCHAR(45) = NULL
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        DECLARE @idTipoEvento INT;

        SELECT @idTipoEvento = te.id
        FROM dbo.TipoEvento te
        WHERE (te.Nombre = 'Listar empleados');

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
        ORDER BY e.Nombre, e.Apellido;

        INSERT INTO dbo.BitacoraEvento (
            idUsuario
            , idTipoEvento
            , IP
            , Datos
        )
        VALUES (
            @inIdAdmin
            , @idTipoEvento
            , @inIp
            , 'Listado de empleados'
        );

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
            (SELECT TOP 1 u.Username FROM dbo.Usuario u WHERE (u.id = @inIdAdmin))
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
