USE Tarea03;
GO

CREATE TRIGGER dbo.TR_Empleado_AsociarDeduccionesObligatorias
ON dbo.Empleado
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON

    BEGIN TRY

        INSERT INTO dbo.EmpXTipoDed (
            idEmpleado
            , idTipoDeduccion
            , Valor
            , FechaInicio
            , FechaFin
            , Activo
        )
        SELECT
            i.id
            , td.id
            , td.Valor
            , i.FechaIngreso
            , NULL
            , 1
        FROM inserted i
        CROSS JOIN dbo.TipoDeduccion td
        WHERE (td.Obligatorio = 1)

    END TRY
    BEGIN CATCH

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
            SUSER_SNAME()
            , ERROR_NUMBER()
            , ERROR_STATE()
            , ERROR_SEVERITY()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
            , ERROR_MESSAGE()
            , GETDATE()
        )

    END CATCH
END
GO
