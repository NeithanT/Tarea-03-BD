CREATE DATABASE Tarea03;
GO

USE Tarea03;
GO

-- El esquema para la Tarea 03 de Bases de Datos

-- Feriados
-- Puesto
-- Empleado
-- Semana
-- Mes
-- HorarioJornada
-- PlanillaMensual
-- PlanillaSemanal
-- MovPlanilla
-- TipoMov
-- Asistencia
-- MovHoras
-- Devengado
-- DeduccionXLey
-- DeduccionMontoFijo
-- Usuario
-- UsuarioEmpleado
-- DeduccionMensual
-- TipoEvento
-- BitacoraEvento
-- TipoDeduccion
-- DeduccionNoObligatoria
-- EmpXTipoDed
-- UsuarioAdministrador
-- DeduccionPorcentual
-- EXTDMontoFijo
-- EXTDPorcentual

-- ===== Plantilla Obrera =====
-- Listado de tablas:
-- TipoJornada,
-- TipoMovimiento,
-- TipoDeduccion,
-- TipoUsuario,
-- TipoEvento,
-- Feriado,
-- Puesto,
-- Empleado,
-- Mes,
-- Semana,
-- HorarioJornada,
-- AsistenciaAJornada,
-- Planilla,
-- PlanillaSemanal,
-- PlanillaMensual,
-- PlanillaAplicada,
-- MovPlanilla,
-- Deduccion,
-- DeduccionFija,
-- DeduccionPorcentual,
-- DeduccionAplicada,
-- EmpXTipoDed,
-- Usuario,
-- UsuarioEmpleado,
-- BitacoraEvento,
-- Error,
-- DBError

-- Catalogos

CREATE TABLE dbo.TipoJornada (
  id INT PRIMARY KEY
  , Nombre VARCHAR(50) NOT NULL
  , HoraInicio TIME(0) NOT NULL
  , HoraFin TIME(0) NOT NULL
);

CREATE TABLE dbo.TipoMovimiento (
  id INT PRIMARY KEY
  , Nombre VARCHAR(100) NOT NULL
  , Accion CHAR(1) NOT NULL CHECK (Accion IN ('+', '-'))
);

CREATE TABLE dbo.TipoDeduccion (
  id INT PRIMARY KEY
  , Nombre VARCHAR(100) NOT NULL
  , Obligatorio BIT NOT NULL DEFAULT 0
  , Porcentual BIT NOT NULL DEFAULT 0
  , Valor DECIMAL(10, 4) NOT NULL DEFAULT 0
  , idTipoMovimiento INT NOT NULL
  , CONSTRAINT FK_TipoDeduccion_TipoMovimiento FOREIGN KEY (idTipoMovimiento) REFERENCES dbo.TipoMovimiento(id)
);

CREATE TABLE dbo.TipoUsuario (
  id INT PRIMARY KEY IDENTITY(1,1)
  , Nombre VARCHAR(100) NOT NULL DEFAULT 'Usuario'
);

CREATE TABLE dbo.TipoEvento (
  id INT PRIMARY KEY
  , Nombre VARCHAR(100) NOT NULL
  , Descripcion VARCHAR(500) NULL
);

CREATE TABLE dbo.Feriado (
  id INT PRIMARY KEY
  , Nombre VARCHAR(255) NOT NULL
  , Fecha DATE NOT NULL
);

-- Todo inicia desde los empleados

CREATE TABLE dbo.Puesto (
  id INT PRIMARY KEY IDENTITY(1,1)
  , Nombre VARCHAR(255) NOT NULL
  , SalarioPorHora DECIMAL(10, 2) NOT NULL
  , Descripcion VARCHAR(500) NULL
);

CREATE TABLE dbo.Empleado (
  id INT PRIMARY KEY IDENTITY(1,1)
  , Cedula VARCHAR(20) NOT NULL UNIQUE
  , Nombre VARCHAR(255) NOT NULL
  , Apellido VARCHAR(255) NOT NULL
  , FechaIngreso DATE NOT NULL
  , FechaNacimiento DATE NULL
  , idPuesto INT NOT NULL
  , Activo BIT NOT NULL DEFAULT 1
  , CONSTRAINT FK_Empleado_Puesto FOREIGN KEY (idPuesto) REFERENCES dbo.Puesto(id)
);

-- Periodos de trabajo

CREATE TABLE dbo.Mes (
  id INT PRIMARY KEY IDENTITY(1,1)
  , Numero INT NOT NULL CHECK (Numero BETWEEN 1 AND 12)
  , Ano INT NOT NULL
  , FechaInicio DATE NOT NULL
  , FechaFin DATE NOT NULL
);

CREATE TABLE dbo.Semana (
  id INT PRIMARY KEY IDENTITY(1,1)
  , NumeroSemana INT NOT NULL CHECK (NumeroSemana BETWEEN 1 AND 53)
  , Ano INT NOT NULL
  , FechaInicio DATE NOT NULL
  , FechaFin DATE NOT NULL
  , idMes INT NULL
  , CONSTRAINT FK_Semana_Mes FOREIGN KEY (idMes) REFERENCES dbo.Mes(id)
);

-- Horarios y asistencia

CREATE TABLE dbo.HorarioJornada (
  id INT PRIMARY KEY IDENTITY(1,1)
  , idEmpleado INT NOT NULL
  , idSemana INT NOT NULL
  , idTipoJornada INT NOT NULL
  , DiaSemana INT NOT NULL CHECK (DiaSemana BETWEEN 1 AND 7)
  , EsDiaDescanso BIT NOT NULL DEFAULT 0
  , CONSTRAINT FK_HorarioJornada_Empleado FOREIGN KEY (idEmpleado) REFERENCES dbo.Empleado(id)
  , CONSTRAINT FK_HorarioJornada_Semana FOREIGN KEY (idSemana) REFERENCES dbo.Semana(id)
  , CONSTRAINT FK_HorarioJornada_TipoJornada FOREIGN KEY (idTipoJornada) REFERENCES dbo.TipoJornada(id)
  , CONSTRAINT UQ_HorarioJornada UNIQUE (idEmpleado, idSemana, DiaSemana)
);

CREATE TABLE dbo.AsistenciaAJornada (
  id INT PRIMARY KEY IDENTITY(1,1)
  , idEmpleado INT NOT NULL
  , idHorarioJornada INT NULL
  , Fecha DATE NOT NULL
  , HoraEntrada TIME(0) NULL
  , HoraSalida TIME(0) NULL
  , HorasTrabajadas DECIMAL(5, 2) NULL
  , Estado VARCHAR(50) NOT NULL DEFAULT 'Registrado'
  , CONSTRAINT FK_AsistenciaAJornada_Empleado FOREIGN KEY (idEmpleado) REFERENCES dbo.Empleado(id)
  , CONSTRAINT FK_AsistenciaAJornada_Horario FOREIGN KEY (idHorarioJornada) REFERENCES dbo.HorarioJornada(id)
);

-- Pagos (Planillas)

CREATE TABLE dbo.Planilla (
  id INT PRIMARY KEY IDENTITY(1,1)
  , idEmpleado INT NOT NULL
  , FechaPago DATE NOT NULL
  , IngresoBruto DECIMAL(10, 2) NOT NULL DEFAULT 0
  , TotalDeducciones DECIMAL(10, 2) NOT NULL DEFAULT 0
  , IngresoNeto AS (IngresoBruto - TotalDeducciones) PERSISTED
  , Observaciones VARCHAR(500) NULL
  , CONSTRAINT FK_Planilla_Empleado FOREIGN KEY (idEmpleado) REFERENCES dbo.Empleado(id)
);

CREATE TABLE dbo.PlanillaSemanal (
  id INT PRIMARY KEY IDENTITY(1,1)
  , idPlanilla INT NOT NULL UNIQUE
  , idSemana INT NOT NULL
  , CONSTRAINT FK_PlanillaSemanal_Planilla FOREIGN KEY (idPlanilla) REFERENCES dbo.Planilla(id)
  , CONSTRAINT FK_PlanillaSemanal_Semana FOREIGN KEY (idSemana) REFERENCES dbo.Semana(id)
);

CREATE TABLE dbo.PlanillaMensual (
  id INT PRIMARY KEY IDENTITY(1,1)
  , idPlanilla INT NOT NULL UNIQUE
  , idMes INT NOT NULL
  , CONSTRAINT FK_PlanillaMensual_Planilla FOREIGN KEY (idPlanilla) REFERENCES dbo.Planilla(id)
  , CONSTRAINT FK_PlanillaMensual_Mes FOREIGN KEY (idMes) REFERENCES dbo.Mes(id)
);

CREATE TABLE dbo.PlanillaAplicada (
  id INT PRIMARY KEY IDENTITY(1,1)
  , idPlanilla INT NOT NULL
  , idEmpleado INT NOT NULL
  , FechaAplicacion DATE NOT NULL DEFAULT (GETDATE())
  , Estado VARCHAR(50) NOT NULL DEFAULT 'Aplicada'
  , CONSTRAINT FK_PlanillaAplicada_Planilla FOREIGN KEY (idPlanilla) REFERENCES dbo.Planilla(id)
  , CONSTRAINT FK_PlanillaAplicada_Empleado FOREIGN KEY (idEmpleado) REFERENCES dbo.Empleado(id)
);

-- Movimientos de planilla

CREATE TABLE dbo.MovPlanilla (
  id INT PRIMARY KEY IDENTITY(1,1)
  , idPlanillaSemanal INT NOT NULL
  , idAsistencia INT NULL
  , idTipoMovimiento INT NOT NULL
  , Cantidad DECIMAL(5, 2) NULL
  , Monto DECIMAL(10, 2) NOT NULL
  , Fecha DATE NOT NULL
  , CONSTRAINT FK_MovPlanilla_PlanillaSemanal FOREIGN KEY (idPlanillaSemanal) REFERENCES dbo.PlanillaSemanal(id)
  , CONSTRAINT FK_MovPlanilla_Asistencia FOREIGN KEY (idAsistencia) REFERENCES dbo.AsistenciaAJornada(id)
  , CONSTRAINT FK_MovPlanilla_TipoMovimiento FOREIGN KEY (idTipoMovimiento) REFERENCES dbo.TipoMovimiento(id)
);

-- Deducciones

CREATE TABLE dbo.Deduccion (
  id INT PRIMARY KEY IDENTITY(1,1)
  , Nombre VARCHAR(255) NOT NULL
  , Descripcion VARCHAR(500) NULL
  , Tipo VARCHAR(50) NOT NULL CHECK (Tipo IN ('Fija', 'Porcentual', 'Otro'))
);

CREATE TABLE dbo.DeduccionFija (
  id INT PRIMARY KEY IDENTITY(1,1)
  , idDeduccion INT NOT NULL UNIQUE
  , Monto DECIMAL(10, 2) NOT NULL CHECK (Monto >= 0)
  , CONSTRAINT FK_DeduccionFija_Deduccion FOREIGN KEY (idDeduccion) REFERENCES dbo.Deduccion(id)
);

CREATE TABLE dbo.DeduccionPorcentual (
  id INT PRIMARY KEY IDENTITY(1,1)
  , idDeduccion INT NOT NULL UNIQUE
  , Porcentaje DECIMAL(5, 2) NOT NULL CHECK (Porcentaje BETWEEN 0 AND 100)
  , CONSTRAINT FK_DeduccionPorcentual_Deduccion FOREIGN KEY (idDeduccion) REFERENCES dbo.Deduccion(id)
);

CREATE TABLE dbo.DeduccionAplicada (
  id INT PRIMARY KEY IDENTITY(1,1)
  , idPlanilla INT NOT NULL
  , idEmpleado INT NOT NULL
  , idDeduccion INT NOT NULL
  , Monto DECIMAL(10, 2) NOT NULL CHECK (Monto >= 0)
  , CONSTRAINT FK_DeduccionAplicada_Planilla FOREIGN KEY (idPlanilla) REFERENCES dbo.Planilla(id)
  , CONSTRAINT FK_DeduccionAplicada_Empleado FOREIGN KEY (idEmpleado) REFERENCES dbo.Empleado(id)
  , CONSTRAINT FK_DeduccionAplicada_Deduccion FOREIGN KEY (idDeduccion) REFERENCES dbo.Deduccion(id)
);

CREATE TABLE dbo.EmpXTipoDed (
  id INT PRIMARY KEY IDENTITY(1,1)
  , idEmpleado INT NOT NULL
  , idTipoDeduccion INT NOT NULL
  , Valor DECIMAL(10, 4) NOT NULL
  , FechaInicio DATE NOT NULL
  , FechaFin DATE NULL
  , Activo BIT NOT NULL DEFAULT 1
  , CONSTRAINT FK_EmpXTipoDed_Empleado FOREIGN KEY (idEmpleado) REFERENCES dbo.Empleado(id)
  , CONSTRAINT FK_EmpXTipoDed_TipoDeduccion FOREIGN KEY (idTipoDeduccion) REFERENCES dbo.TipoDeduccion(id)
  , CONSTRAINT UQ_EmpXTipoDed UNIQUE (idEmpleado, idTipoDeduccion, FechaInicio)
);

-- Usuarios

CREATE TABLE dbo.Usuario (
  id INT PRIMARY KEY IDENTITY(1,1)
  , Username VARCHAR(100) NOT NULL UNIQUE
  , Contrasena VARCHAR(512) NOT NULL
  , NombreUsuario VARCHAR(100) NOT NULL UNIQUE
  , ContrasenaHash VARCHAR(512) NOT NULL
  , idRol INT NOT NULL
  , Activo BIT NOT NULL DEFAULT 1
  , CONSTRAINT FK_Usuario_TipoUsuario FOREIGN KEY (idRol) REFERENCES dbo.TipoUsuario(id)
);

CREATE TABLE dbo.UsuarioEmpleado (
  id INT PRIMARY KEY IDENTITY(1,1)
  , idUsuario INT NOT NULL
  , idEmpleado INT NOT NULL
  , CONSTRAINT FK_UsuarioEmpleado_Usuario FOREIGN KEY (idUsuario) REFERENCES dbo.Usuario(id)
  , CONSTRAINT FK_UsuarioEmpleado_Empleado FOREIGN KEY (idEmpleado) REFERENCES dbo.Empleado(id)
);

-- Bitacora de eventos

CREATE TABLE dbo.BitacoraEvento (
  id INT PRIMARY KEY IDENTITY(1,1)
  , idUsuario INT NOT NULL
  , idTipoEvento INT NOT NULL
  , IP VARCHAR(45) NULL
  , FechaHora DATETIME NOT NULL DEFAULT SYSUTCDATETIME()
  , Datos NVARCHAR(MAX) NULL
  , CONSTRAINT FK_BitacoraEvento_Usuario FOREIGN KEY (idUsuario) REFERENCES dbo.Usuario(id)
  , CONSTRAINT FK_BitacoraEvento_TipoEvento FOREIGN KEY (idTipoEvento) REFERENCES dbo.TipoEvento(id)
);

-- Manejo de errores

CREATE TABLE dbo.Error (
  id INT PRIMARY KEY IDENTITY(1,1)
  , Codigo INT NOT NULL
  , Descripcion NVARCHAR(255) NOT NULL
);

CREATE TABLE dbo.DBError (
  id INT PRIMARY KEY IDENTITY(1,1)
  , Username NVARCHAR(100) NOT NULL
  , [Number] INT NOT NULL
  , [State] INT NOT NULL
  , Severity INT NOT NULL
  , [Line] INT NOT NULL
  , [Procedure] NVARCHAR(200) NOT NULL
  , [Message] NVARCHAR(MAX) NOT NULL
  , [DateTime] DATETIME NOT NULL
);
GO
