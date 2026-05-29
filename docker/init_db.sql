-- El esquema para la Tarea 03 de BasesTipoJornada

-- ===== Esquema Del Profesor =====
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
-- DeducciónXLey
-- DeducciónMontoFijo
-- Usuario
-- UsuarioEmpleado
-- DeduccionMensual
-- TipoEvento
-- BitacoraEvento
-- TipoDeducción
-- DeduccionNoObligatoria
-- EmpXTipoDed
-- UsuarioAdministrador
-- DeducciónPorcentual
-- EXTDMontoFijo
-- EXTDPorcentual


-- ===== Plantilla Obrera =====
-- Listado de tablas:
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
-- Deduccion,
-- DeduccionFija,
-- DeduccionPorcentual,
-- DeduccionAplicada,
-- Usuario,
-- TipoUsuario,
-- TipoEvento,
-- BitacoraEvento,
-- Error,
-- DBError


CREATE DATABASE PlanillaObrera;
GO

USE PlanillaObrera;
-- Todo inicia desde los empleados
CREATE TABLE Puesto (
  id INT PRIMARY KEY IDENTITY(1,1)
  , Nombre VARCHAR(255) NOT NULL
  , SalarioPorHora DECIMAL(10, 2) NOT NULL
  , Descripcion VARCHAR(500) NULL
);

CREATE TABLE Empleado (
  id INT PRIMARY KEY IDENTITY(1,1)
  , Nombre VARCHAR(255) NOT NULL
  , Apellido VARCHAR(255) NOT NULL
  , FechaIngreso DATE NOT NULL
  , FechaNacimiento DATE NULL
  , PuestoId INT NOT NULL
  , Activo BIT NOT NULL DEFAULT 1
  , CONSTRAINT FK_Empleado_Puesto FOREIGN KEY (PuestoId) REFERENCES Puesto(id)
);

-- Periodos de trabajo

CREATE TABLE Mes (
  id INT PRIMARY KEY IDENTITY(1,1)
  , Numero INT NOT NULL CHECK (Numero BETWEEN 1 AND 12)
  , Ano INT NOT NULL
  , FechaInicio DATE NOT NULL
  , FechaFin DATE NOT NULL
);

CREATE TABLE Semana (
  id INT PRIMARY KEY IDENTITY(1,1)
  , NumeroSemana INT NOT NULL CHECK (NumeroSemana BETWEEN 1 AND 53)
  , Ano INT NOT NULL
  , FechaInicio DATE NOT NULL
  , FechaFin DATE NOT NULL
  , MesId INT NULL
  , CONSTRAINT FK_Semana_Mes FOREIGN KEY (MesId) REFERENCES Mes(id)
);

CREATE TABLE DiaSemana (
  id INT PRIMARY KEY IDENTITY(1,1)
  , Nombre VARCHAR(20) NOT NULL
  , Numero INT NOT NULL CHECK (Numero BETWEEN 1 AND 7)
);

CREATE TABLE HorarioJornada (
  id INT PRIMARY KEY IDENTITY(1,1)
  , EmpleadoId INT NOT NULL
  , DiaSemana INT NOT NULL CHECK (DiaSemana BETWEEN 1 AND 7)
  , HoraEntrada TIME(0) NOT NULL
  , HoraSalida TIME(0) NOT NULL
  , EsJornadaNocturna BIT NOT NULL DEFAULT 0
  , CONSTRAINT FK_HorarioJornada_Empleado FOREIGN KEY (EmpleadoId) REFERENCES Empleado(id)
);

CREATE TABLE AsistenciaAJornada (
  id INT PRIMARY KEY IDENTITY(1,1)
  , EmpleadoId INT NOT NULL
  , HorarioJornadaId INT NULL
  , Fecha DATE NOT NULL
  , HoraEntrada TIME(0) NULL
  , HoraSalida TIME(0) NULL
  , HorasTrabajadas DECIMAL(5,2) NULL
  , Estado VARCHAR(50) NOT NULL DEFAULT 'Registrado'
  , CONSTRAINT FK_AsistenciaAJornada_Empleado FOREIGN KEY (EmpleadoId) REFERENCES Empleado(id)
  , CONSTRAINT FK_AsistenciaAJornada_Horario FOREIGN KEY (HorarioJornadaId) REFERENCES HorarioJornada(id)
);

-- Pagos (Planillas)
CREATE TABLE Planilla (
  id INT PRIMARY KEY IDENTITY(1,1)
  , EmpleadoId INT NOT NULL
  , FechaPago DATE NOT NULL
  , IngresoBruto DECIMAL(10,2) NOT NULL
  , TotalDeducciones DECIMAL(10,2) NOT NULL DEFAULT 0
  , IngresoNeto DECIMAL(10,2) NOT NULL
  , Observaciones VARCHAR(500) NULL
  , CONSTRAINT FK_Planilla_Empleado FOREIGN KEY (EmpleadoId) REFERENCES Empleado(id)
);

CREATE TABLE PlanillaSemanal (
  id INT PRIMARY KEY IDENTITY(1,1)
  , PlanillaId INT NOT NULL UNIQUE
  , SemanaId INT NOT NULL
  , CONSTRAINT FK_PlanillaSemanal_Planilla FOREIGN KEY (PlanillaId) REFERENCES Planilla(id)
  , CONSTRAINT FK_PlanillaSemanal_Semana FOREIGN KEY (SemanaId) REFERENCES Semana(id)
);

CREATE TABLE PlanillaMensual (
  id INT PRIMARY KEY IDENTITY(1,1)
  , PlanillaId INT NOT NULL UNIQUE
  , MesId INT NOT NULL
  , CONSTRAINT FK_PlanillaMensual_Planilla FOREIGN KEY (PlanillaId) REFERENCES Planilla(id)
  , CONSTRAINT FK_PlanillaMensual_Mes FOREIGN KEY (MesId) REFERENCES Mes(id)
);

CREATE TABLE PlanillaAplicada (
  id INT PRIMARY KEY IDENTITY(1,1)
  , PlanillaId INT NOT NULL
  , EmpleadoId INT NOT NULL
  , FechaAplicacion DATE NOT NULL DEFAULT (GETDATE())
  , Estado VARCHAR(50) NOT NULL DEFAULT 'Aplicada'
  , CONSTRAINT FK_PlanillaAplicada_Planilla FOREIGN KEY (PlanillaId) REFERENCES Planilla(id)
  , CONSTRAINT FK_PlanillaAplicada_Empleado FOREIGN KEY (EmpleadoId) REFERENCES Empleado(id)
);

-- Deducciones
CREATE TABLE Deduccion (
  id INT PRIMARY KEY IDENTITY(1,1)
  , Nombre VARCHAR(255) NOT NULL
  , Descripcion VARCHAR(500) NULL
  , Tipo VARCHAR(50) NOT NULL CHECK (Tipo IN ('Fija','Porcentual','Otro'))
);

CREATE TABLE DeduccionFija (
  id INT PRIMARY KEY IDENTITY(1,1)
  , DeduccionId INT NOT NULL UNIQUE
  , Monto DECIMAL(10,2) NOT NULL CHECK (Monto >= 0)
  , CONSTRAINT FK_DeduccionFija_Deduccion FOREIGN KEY (DeduccionId) REFERENCES Deduccion(id)
);

CREATE TABLE DeduccionPorcentual (
  id INT PRIMARY KEY IDENTITY(1,1)
  , DeduccionId INT NOT NULL UNIQUE
  , Porcentaje DECIMAL(5,2) NOT NULL CHECK (Porcentaje BETWEEN 0 AND 100)
  , CONSTRAINT FK_DeduccionPorcentual_Deduccion FOREIGN KEY (DeduccionId) REFERENCES Deduccion(id)
);

CREATE TABLE DeduccionAplicada (
  id INT PRIMARY KEY IDENTITY(1,1)
  , PlanillaId INT NOT NULL
  , EmpleadoId INT NOT NULL
  , DeduccionId INT NOT NULL
  , Monto DECIMAL(10,2) NOT NULL CHECK (Monto >= 0)
  , CONSTRAINT FK_DeduccionAplicada_Planilla FOREIGN KEY (PlanillaId) REFERENCES Planilla(id)
  , CONSTRAINT FK_DeduccionAplicada_Empleado FOREIGN KEY (EmpleadoId) REFERENCES Empleado(id)
  , CONSTRAINT FK_DeduccionAplicada_Deduccion FOREIGN KEY (DeduccionId) REFERENCES Deduccion(id)
);

-- Otros para la conexion

CREATE TABLE Usuario (
  id INT PRIMARY KEY IDENTITY(1,1)
  , Username        VARCHAR(100) NOT NULL UNIQUE
  , Contrasena      VARCHAR(512) NOT NULL
  , NombreUsuario   VARCHAR(100) NOT NULL UNIQUE
  , ContrasenaHash  VARCHAR(512) NOT NULL
  , idRol           INT NOT NULL
  , Activo          BIT NOT NULL DEFAULT 1
  , CONSTRAINT FK_Usuario_Role FOREIGN KEY (idRol) REFERENCES TipoUsuario(id)
);

CREATE TABLE UsuarioEmpleado (
  id INT PRIMARY KEY IDENTITY(1,1)
  , UsuarioId INT NOT NULL
  , EmpleadoId INT NOT NULL
  , CONSTRAINT FK_UsuarioEmpleado_Usuario FOREIGN KEY (UsuarioId) REFERENCES Usuario(id)
  , CONSTRAINT FK_UsuarioEmpleado_Empleado FOREIGN KEY (EmpleadoId) REFERENCES Empleado(id)
);

CREATE TABLE TipoUsuario (
  id        INT PRIMARY KEY IDENTITY(1,1)
  , TipoUsuario  VARCHAR(100) NOT NULL DEFAULT 'Usuario'
);

CREATE TABLE TipoEvento (
  id INT PRIMARY KEY IDENTITY(1,1)
  , Nombre      VARCHAR(100) NOT NULL
  , Descripcion VARCHAR(500) NULL
);

CREATE TABLE BitacoraEvento (
  id INT PRIMARY KEY IDENTITY(1,1)
  , UsuarioId     INT NOT NULL
  , TipoEventoId  INT NOT NULL
  , FechaHora     DATETIME NOT NULL DEFAULT SYSUTCDATETIME()
  , Descripcion   VARCHAR(1000) NULL
  , CONSTRAINT FK_BitacoraEvento_Usuario FOREIGN KEY (UsuarioId) REFERENCES Usuario(id)
  , CONSTRAINT FK_BitacoraEvento_TipoEvento FOREIGN KEY (TipoEventoId) REFERENCES TipoEvento(id)
);

CREATE TABLE dbo.Error (
  id INT PRIMARY KEY IDENTITY(1,1)
  , Codigo          INT NOT NULL
  , Descripcion     NVARCHAR(255) NOT NULL
)

CREATE TABLE dbo.DBError (
  id INT PRIMARY KEY IDENTITY(1,1)
  , Username    NVARCHAR(100) NOT NULL
  , [Number]    INT NOT NULL
  , [State]     INT NOT NULL
  , Severity    INT NOT NULL
  , [Line]      INT NOT NULL
  , [Procedure] NVARCHAR(200) NOT NULL
  , [Message]   NVARCHAR(MAX) NOT NULL
  , [DateTime]  DATETIME NOT NULL
)
