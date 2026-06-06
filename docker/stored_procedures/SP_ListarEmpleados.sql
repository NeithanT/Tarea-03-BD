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
      (SELECT id FROM dbo.TipoEvento WHERE Nombre = 'Consulta Empleados')
      , 'Listado de empleados por admin'
      , @inidAdmin
    );


  END TRY
  BEGIN CATCH
    SET @outResultCode = 50001;

    id INT PRIMARY KEY IDENTITY(1,1)
    , Username NVARCHAR(100) NOT NULL
    , [Number] INT NOT NULL
    , [State] INT NOT NULL
    , Severity INT NOT NULL
    , [Line] INT NOT NULL
    , [Procedure] NVARCHAR(200) NOT NULL
    , [Message] NVARCHAR(MAX) NOT NULL
    , [DateTime] DATETIME NOT NULL
    ;
    INSERT INTO dbo.DBError (
      Numero
      , Mensaje
      , Procedimiento
      , Linea
    )

  END CATCH
END;
GO
