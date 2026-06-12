CREATE OR ALTER PROCEDURE dbo.SP_EditarEmpleado
    @inIdEmpleado INT
    , @inNombre NVARCHAR(255)
    , @inApellido NVARCHAR(255)
    , @inFechaIngreso DATE
    , @inFechaNacimiento DATE = NULL
    , @inIdPuesto INT
    , @inActivo BIT
    , @inIp VARCHAR(45) = NULL
    , @inIdAdmin INT
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        DECLARE @idTipoEvento INT;

        SELECT @idTipoEvento = te.id
        FROM dbo.TipoEvento te
        WHERE (te.Nombre = 'Update exitoso');

        BEGIN TRANSACTION;

            UPDATE dbo.Empleado
            SET Nombre = @inNombre
                , Apellido = @inApellido
                , FechaIngreso = @inFechaIngreso
                , FechaNacimiento = @inFechaNacimiento
                , idPuesto = @inIdPuesto
                , Activo = @inActivo
            WHERE (id = @inIdEmpleado);

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
                , CONCAT('Empleado editado: ', @inNombre, ' ', @inApellido, ' (ID: ', @inIdEmpleado, ')')
            );

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

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
