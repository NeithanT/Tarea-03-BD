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
  THROW 50000, 'SP_InsertarBitacora pendiente de implementar.', 1;
END;
GO
