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

    UPDATE dbo.Empleado
    SET
      Nombre = @Nombre
      , Apellido = @Apellido
      , FechaIngreso = @FechaIngreso
      , FechaNacimiento = @FechaNacimiento
      , idPuesto = @idPuesto
      , Activo = @Activo
    WHERE id = @idEmpleado;

    INSERT INTO dbo.BitacoraEvento (
      idUsuario
      , idTipoEvento
      , IP
      , Datos
    )
    VALUES (
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
      (SELECT TOP 1 Username FROM dbo.Usuario WHERE id = @inidAdmin)
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
