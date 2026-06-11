CREATE OR ALTER PROCEDURE dbo.SP_InsertarBitacora
  @UsuarioId INT = NULL,
  @UserName NVARCHAR(100) = NULL,
  @Evento NVARCHAR(100),
  @Resultado NVARCHAR(50) = NULL,
  @Parametros NVARCHAR(MAX) = NULL,
  @Ip NVARCHAR(45)
AS
BEGIN
  SET NOCOUNT ON;

  IF @UsuarioId IS NULL
    RETURN;

  BEGIN TRY

    DECLARE @idTipoEvento INT;
    SELECT @idTipoEvento = id FROM dbo.TipoEvento WHERE Nombre = @Evento;

    IF @idTipoEvento IS NULL
      RETURN;

    DECLARE @datos NVARCHAR(MAX) = @Resultado;
    IF @Parametros IS NOT NULL
      SET @datos = COALESCE(@datos + ' | ', '') + @Parametros;

    INSERT INTO dbo.BitacoraEvento (idUsuario, idTipoEvento, IP, Datos)
    VALUES (@UsuarioId, @idTipoEvento, @Ip, @datos);

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
      COALESCE(@UserName, CAST(@UsuarioId AS NVARCHAR(20)), 'unknown')
      , ERROR_NUMBER()
      , ERROR_STATE()
      , ERROR_SEVERITY()
      , ERROR_LINE()
      , ERROR_PROCEDURE()
      , ERROR_MESSAGE()
      , GETDATE()
    );

    THROW;

  END CATCH
END;
GO
