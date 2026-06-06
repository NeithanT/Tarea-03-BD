CREATE OR ALTER PROCEDURE dbo.SP_InsertarEmpleado
  @Nombre NVARCHAR(255)
  , @Apellido NVARCHAR(255)
  , @FechaIngreso DATE
  , @FechaNacimiento DATE = NULL
  , @PuestoId INT
  , @Activo BIT = 1
  , @inidAdmin INT
  , @inip VARCHAR(45) = NULL
AS
BEGIN
  SET NOCOUNT ON;

  BEGIN TRY

    BEGIN TRANSACTION

    INSERT INTO dbo.Empleado (
      Nombre
      , Apellido
      , FechaIngreso
      , FechaNacimiento
      , idPuesto
      , Activo
    )
    VALUES (
      @Nombre
      , @Apellido
      , @FechaIngreso
      , @FechaNacimiento
      , @PuestoId
      , @Activo
    );

    INSERT INTO dbo.BitacoraEvento (
      idUsuario
      , idTipoEvento
      , IP
      , Datos
    )
    VALUES (
      @inidAdmin
      , (SELECT id FROM dbo.TipoEvento WHERE Nombre = 'Insercion exitosa')
      , @inip
      , 'Se insertó un empleado: ' + @Nombre + ' ' + @Apellido
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
