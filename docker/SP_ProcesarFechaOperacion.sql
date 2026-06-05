CREATE OR ALTER PROCEDURE dbo.SP_ProcesarFechaOperacion
  @FechaOperacion DATE = NULL,
  @XmlOperaciones XML = NULL,
  @RutaArchivo NVARCHAR(500) = NULL
AS
BEGIN
  SET NOCOUNT ON;
  THROW 50000, 'SP_ProcesarFechaOperacion pendiente de implementar.', 1;
END;
GO
