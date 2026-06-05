CREATE OR ALTER PROCEDURE dbo.SP_EditarEmpleado
  @EmpleadoId INT,
  @Nombre NVARCHAR(255),
  @Apellido NVARCHAR(255),
  @FechaIngreso DATE,
  @FechaNacimiento DATE = NULL,
  @PuestoId INT,
  @Activo BIT
AS
BEGIN
  SET NOCOUNT ON;
  THROW 50000, 'SP_EditarEmpleado pendiente de implementar.', 1;
END;
GO
