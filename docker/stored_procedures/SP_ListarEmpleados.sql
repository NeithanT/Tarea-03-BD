CREATE OR ALTER PROCEDURE dbo.SP_ListarEmpleados
  @inidAdmin INT
  , @inip VARCHAR(45) = NULL
  , @outResultCode INT = NULL OUTPUT
AS
BEGIN
  SET NOCOUNT ON;

  BEGIN TRY

    SET @outResultCode = 0;

    SELECT
      e.id
      , e.Cedula
      , e.Nombre
      , e.Apellido
      , e.FechaIngreso
      , e.FechaNacimiento
      , p.Nombre AS Puesto
      , e.Activo
    FROM dbo.Empleado e
    INNER JOIN dbo.Puesto p ON e.idPuesto = p.id
    WHERE e.Activo = 1
    ORDER BY e.Nombre, e.Apellido;

    INSERT INTO dbo.BitacoraEvento (
      idUsuario
      , idTipoEvento
      , IP
      , Datos
    )
    VALUES (
      @inidAdmin
      , (SELECT id FROM dbo.TipoEvento WHERE Nombre = 'Listar Empleados')
      , @inip
      , 'Listado de empleados'
    );

  END TRY
  BEGIN CATCH
    SET @outResultCode = 50001;

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

  END CATCH
END;
GO
