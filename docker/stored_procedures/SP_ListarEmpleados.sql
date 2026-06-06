CREATE OR ALTER PROCEDURE dbo.SP_ListarEmpleados
  @inidAdmin INT
  , @outResultCode INT OUTPUT
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
      idTipoEvento
      , Descripcion
      , idAdmin
    )

    SELECT (
      (SELECT id FROM dbo.TipoEvento WHERE Nombre = 'Listar Empleados')
      , 'Listado de empleados'
      , @inidAdmin
    );


  END TRY
  BEGIN CATCH
    SET @outResultCode = 50001;

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
      , GETDATE();
    );
    

  END CATCH
END;
GO
