CREATE OR ALTER PROCEDURE dbo.SP_EditarEmpleado
  @idEmpleado INT
  , @Nombre NVARCHAR(255)
  , @Apellido NVARCHAR(255)
  , @FechaIngreso DATE
  , @FechaNacimiento DATE = NULL
  , @idPuesto INT
  , @Activo BIT
  , @inip VARCHAR(45) = NULL
  , @inidAdmin INT
AS
BEGIN
  SET NOCOUNT ON;
  
  BEGIN TRY

    BEGIN TRANSACTION
    UPDATE Empleados
    SET
      Nombre = @Nombre,
      Apellido = @Apellido,
      FechaIngreso = @FechaIngreso,
      FechaNacimiento = @FechaNacimiento,
      idPuesto = @idPuesto,
      Activo = @Activo
    WHERE idEmpleado = @idEmpleado;
    
    INSERT INTO dbo.BitacoraEventos (
      idUsuario
      , idTipoEvento
      , IP
      , Datos
    )
    SELECT 
      @inidAdmin
      , (SELECT id FROM dbo.TipoEvento WHERE Nombre = 'Update exitoso')
      , @inip
      , CONCAT('Empleado editado: ', @Nombre, ' ', @Apellido, ' (ID: ', @idEmpleado, ')')
    );
    COMMIT TRANSACTION

  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0
      ROLLBACK TRANSACTION;
    
    INSERT INTO dbo.DBError (
      id
      , Username
      , [Number]
      , [State]
      , Severity
      , [Line]
      , [Procedure] NVARCHAR(200) NOT NULL
      , [Message] NVARCHAR(MAX) NOT NULL
      , [DateTime] DATETIME NOT NULL
    )
    SELECT ( 
      (SELECT TOP 1 Username FROM dbo.Usuario WHERE id = @inidAdmin)
      , ERROR_NUMBER()
      , ERROR_STATE()
      , ERROR_SEVERITY()
      , ERROR_LINE()
      , ERROR_PROCEDURE()
      , ERROR_MESSAGE()
      , GETDATE()
    );

END;
GO
