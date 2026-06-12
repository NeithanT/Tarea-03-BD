CREATE OR ALTER PROCEDURE dbo.SP_ValidarUsuario
    @inUserName NVARCHAR(100)
    , @inContrasena NVARCHAR(512)
    , @inIp VARCHAR(45) = NULL
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        DECLARE @userId INT = NULL;
        DECLARE @activo BIT = NULL;
        DECLARE @contrasenaOk BIT = 0;
        DECLARE @idEventoExitoso INT;
        DECLARE @idEventoFallido INT;
        DECLARE @idEventoDeshabilitado INT;

        SELECT
            @userId = u.id
            , @activo = u.Activo
            , @contrasenaOk = CASE WHEN (u.Contrasena = @inContrasena) THEN 1 ELSE 0 END
        FROM dbo.Usuario u
        WHERE (u.Username = @inUserName);

        IF (@userId IS NULL)
            RETURN;

        SELECT @idEventoDeshabilitado = te.id FROM dbo.TipoEvento te WHERE (te.Nombre = 'Login deshabilitado');
        SELECT @idEventoFallido = te.id FROM dbo.TipoEvento te WHERE (te.Nombre = 'Login No Exitoso');
        SELECT @idEventoExitoso = te.id FROM dbo.TipoEvento te WHERE (te.Nombre = 'Login Exitoso');

        IF (@activo = 0)
        BEGIN
            INSERT INTO dbo.BitacoraEvento (
                idUsuario
                , idTipoEvento
                , IP
                , Datos
            )
            VALUES (
                @userId
                , @idEventoDeshabilitado
                , @inIp
                , CONCAT('Intento de login deshabilitado: ', @inUserName)
            );
            RETURN;
        END

        IF (@contrasenaOk = 0)
        BEGIN
            INSERT INTO dbo.BitacoraEvento (
                idUsuario
                , idTipoEvento
                , IP
                , Datos
            )
            VALUES (
                @userId
                , @idEventoFallido
                , @inIp
                , CONCAT('Contraseña incorrecta para: ', @inUserName)
            );
            RETURN;
        END

        INSERT INTO dbo.BitacoraEvento (
            idUsuario
            , idTipoEvento
            , IP
            , Datos
        )
        VALUES (
            @userId
            , @idEventoExitoso
            , @inIp
            , CONCAT('Login exitoso: ', @inUserName)
        );

        SELECT
            u.id
            , tu.Nombre AS NombreRol
            , ue.idEmpleado AS EmpleadoId
        FROM dbo.Usuario u
        INNER JOIN dbo.TipoUsuario tu ON (tu.id = u.idRol)
        LEFT JOIN dbo.UsuarioEmpleado ue ON (ue.idUsuario = u.id)
        WHERE (u.id = @userId);

    END TRY
    BEGIN CATCH

        SET @outResultCode = 53099;

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
            @inUserName
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
