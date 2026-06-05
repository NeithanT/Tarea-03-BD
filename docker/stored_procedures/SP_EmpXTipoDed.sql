USE Tarea03;
GO

CREATE PROCEDURE dbo.SP_EmpXTipoDed_Asociar
    @inEmpleadoId INT
    , @inTipoDeduccionId INT
    , @inValor DECIMAL(10, 4)
    , @inFechaInicio DATE
    , @outId INT OUTPUT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;
    SET @outId = 0;

    BEGIN TRY

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Empleado e
            WHERE (e.id = @inEmpleadoId)
            AND (e.Activo = 1)
        )
        BEGIN
            SET @outResultCode = 54001;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.TipoDeduccion td
            WHERE (td.id = @inTipoDeduccionId)
        )
        BEGIN
            SET @outResultCode = 54002;
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM dbo.EmpXTipoDed etd
            WHERE (etd.idEmpleado = @inEmpleadoId)
            AND (etd.idTipoDeduccion = @inTipoDeduccionId)
            AND (etd.Activo = 1)
        )
        BEGIN
            SET @outResultCode = 54003;
            RETURN;
        END

        BEGIN TRANSACTION;

            INSERT INTO dbo.EmpXTipoDed (
                idEmpleado
                , idTipoDeduccion
                , Valor
                , FechaInicio
                , FechaFin
                , Activo
            )
            VALUES (
                @inEmpleadoId
                , @inTipoDeduccionId
                , @inValor
                , @inFechaInicio
                , NULL
                , 1
            );

            SET @outId = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        SET @outResultCode = 54099;

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
        );

    END CATCH
END
GO

CREATE PROCEDURE dbo.SP_EmpXTipoDed_Desasociar
    @inEmpleadoId INT
    , @inTipoDeduccionId INT
    , @inFechaFin DATE
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.EmpXTipoDed etd
            WHERE (etd.idEmpleado = @inEmpleadoId)
            AND (etd.idTipoDeduccion = @inTipoDeduccionId)
            AND (etd.Activo = 1)
        )
        BEGIN
            SET @outResultCode = 54001;
            RETURN;
        END

        BEGIN TRANSACTION;

            UPDATE dbo.EmpXTipoDed
            SET Activo = 0
                , FechaFin = @inFechaFin
            WHERE (idEmpleado = @inEmpleadoId)
            AND (idTipoDeduccion = @inTipoDeduccionId)
            AND (Activo = 1);

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        SET @outResultCode = 54099;

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
        );

    END CATCH
END
GO

CREATE PROCEDURE dbo.SP_EmpXTipoDed_ListarPorEmpleado
    @inEmpleadoId INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        SELECT
            etd.id
            , etd.idEmpleado
            , etd.idTipoDeduccion
            , td.Nombre AS NombreDeduccion
            , td.Obligatorio
            , td.Porcentual
            , etd.Valor
            , etd.FechaInicio
            , etd.FechaFin
            , etd.Activo
        FROM dbo.EmpXTipoDed etd
        INNER JOIN dbo.TipoDeduccion td ON (td.id = etd.idTipoDeduccion)
        WHERE (etd.idEmpleado = @inEmpleadoId)
        ORDER BY td.Nombre;

    END TRY
    BEGIN CATCH

        SET @outResultCode = 54099;

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
        );

    END CATCH
END
GO
