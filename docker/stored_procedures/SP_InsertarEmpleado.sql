CREATE OR ALTER PROCEDURE dbo.SP_InsertarEmpleado
  @Nombre NVARCHAR(255)
  , @Apellido NVARCHAR(255)
  , @FechaIngreso DATE
  , @FechaNacimiento DATE = NULL
  , @PuestoId INT
  , @Activo BIT = 1
  , @inidAdmin INT
AS
BEGIN
  SET NOCOUNT ON;
  
  BEGIN TRY
    INSERT INTO dbo.Empleado (
      Nombre,
      Apellido,
      FechaIngreso,
      FechaNacimiento,
      idPuesto,
      Activo
    )
    VALUES (
      @Nombre,
      @Apellido,
      @FechaIngreso,
      @FechaNacimiento,
      @PuestoId,
      @Activo
    );

    INSERT INTO dbo.BitacoraEvento (
      idTipoEvento,
      Descripcion,
      idAdmin
    )    VALUES (
      (SELECT id FROM dbo.TipoEvento WHERE Nombre = 'Insercion exitosa')
      , 'Se insertó un empleado: ' + @Nombre + ' ' + @Apellido
      , @inidAdmin
    );
  END TRY
END;
GO
