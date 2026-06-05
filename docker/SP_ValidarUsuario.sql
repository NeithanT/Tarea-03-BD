CREATE OR ALTER PROCEDURE dbo.SP_ValidarUsuario
  @UserName NVARCHAR(100),
  @Contrasena NVARCHAR(512)
AS
BEGIN
  SET NOCOUNT ON;
  THROW 50000, 'SP_ValidarUsuario pendiente de implementar.', 1;
END;
GO
