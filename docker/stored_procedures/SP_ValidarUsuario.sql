CREATE OR ALTER PROCEDURE dbo.SP_ValidarUsuario
  @UserName NVARCHAR(100)
  , @Contrasena NVARCHAR(512)
  , @inip VARCHAR(45) = NULL
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @userId INT = NULL;
  DECLARE @activo BIT = NULL;
  DECLARE @contrasenaOk BIT = 0;

  -- Buscar usuario por username (sin importar si la contraseña es correcta aún)
  SELECT
    @userId    = u.id
    , @activo  = u.Activo
    , @contrasenaOk = CASE WHEN u.Contrasena = @Contrasena THEN 1 ELSE 0 END
  FROM dbo.Usuario u
  WHERE u.Username = @UserName;

  BEGIN TRY

    IF @userId IS NULL
    BEGIN
      -- Username no existe: no se puede loggear (FK en BitacoraEvento requiere usuario válido)
      RETURN;
    END

    IF @activo = 0
    BEGIN
      -- Usuario deshabilitado
      INSERT INTO dbo.BitacoraEvento (idUsuario, idTipoEvento, IP, Datos)
      VALUES (
        @userId
        , (SELECT id FROM dbo.TipoEvento WHERE Nombre = 'Login deshabilitado')
        , @inip
        , CONCAT('Intento de login deshabilitado: ', @UserName)
      );
      RETURN;
    END

    IF @contrasenaOk = 0
    BEGIN
      -- Contraseña incorrecta
      INSERT INTO dbo.BitacoraEvento (idUsuario, idTipoEvento, IP, Datos)
      VALUES (
        @userId
        , (SELECT id FROM dbo.TipoEvento WHERE Nombre = 'Login No Exitoso')
        , @inip
        , CONCAT('Contraseña incorrecta para: ', @UserName)
      );
      RETURN;
    END

    -- Credenciales válidas: registrar login exitoso y retornar datos de sesión
    INSERT INTO dbo.BitacoraEvento (idUsuario, idTipoEvento, IP, Datos)
    VALUES (
      @userId
      , (SELECT id FROM dbo.TipoEvento WHERE Nombre = 'Login Exitoso')
      , @inip
      , CONCAT('Login exitoso: ', @UserName)
    );

    SELECT
      u.id
      , tu.Nombre AS NombreRol
      , ue.idEmpleado AS EmpleadoId
    FROM dbo.Usuario u
    INNER JOIN dbo.TipoUsuario tu ON tu.id = u.idRol
    LEFT JOIN dbo.UsuarioEmpleado ue ON ue.idUsuario = u.id
    WHERE u.id = @userId;

  END TRY
  BEGIN CATCH

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
      @UserName
      , ERROR_NUMBER()
      , ERROR_STATE()
      , ERROR_SEVERITY()
      , ERROR_LINE()
      , ERROR_PROCEDURE()
      , ERROR_MESSAGE()
      , GETDATE()
    );

  END CATCH;
END;
GO
