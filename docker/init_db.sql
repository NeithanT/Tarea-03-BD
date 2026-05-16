-- [Previous comments maintained for reference]
-- ... (analysis comments)

-- =============================================
-- DATABASE SCHEMA DESIGN - PAYROLL SYSTEM
-- DIALECT: SQL SERVER
-- =============================================

-- 1. CATALOGOS
CREATE TABLE TipoEvento (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre VARCHAR(100) NOT NULL,
    Descripcion VARCHAR(255)
);

CREATE TABLE Feriado (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Fecha DATE NOT NULL,
    Nombre VARCHAR(100) NOT NULL
);

CREATE TABLE TipoMovimiento (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre VARCHAR(100) NOT NULL,
    EsDebito BIT NOT NULL DEFAULT 0 -- 1: Deducción, 0: Devengado
);

CREATE TABLE TipoDeduccion (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre VARCHAR(100) NOT NULL,
    EsObligatorio BIT NOT NULL DEFAULT 0
);

CREATE TABLE TipoJornada (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre VARCHAR(100) NOT NULL,
    HoraInicio TIME NOT NULL,
    HoraFin TIME NOT NULL,
    EsExtra BIT NOT NULL DEFAULT 0
);

-- 2. EMPLEADOS
CREATE TABLE Puesto (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre VARCHAR(100) NOT NULL,
    SalarioBasePorHora MONEY NOT NULL
);

CREATE TABLE Empleado (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre VARCHAR(100) NOT NULL,
    Apellido1 VARCHAR(100) NOT NULL,
    Apellido2 VARCHAR(100),
    DocumentoIdentidad VARCHAR(20) NOT NULL UNIQUE,
    IdPuesto INT NOT NULL,
    FechaIngreso DATE NOT NULL DEFAULT GETDATE(),
    Activo BIT NOT NULL DEFAULT 1,
    FOREIGN KEY (IdPuesto) REFERENCES Puesto(Id)
);

CREATE TABLE CuentaBancaria (
    Id INT PRIMARY KEY IDENTITY(1,1),
    IdEmpleado INT NOT NULL,
    NumeroCuenta VARCHAR(34) NOT NULL, -- Formato IBAN o similar
    Banco VARCHAR(100) NOT NULL,
    FOREIGN KEY (IdEmpleado) REFERENCES Empleado(Id)
);


-- 3. TIEMPO
CREATE TABLE Mes (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Anio INT NOT NULL,
    NumeroMes INT NOT NULL,
    FechaInicio DATE NOT NULL,
    FechaFin DATE NOT NULL,
    UNIQUE(Anio, NumeroMes)
);

CREATE TABLE Semana (
    Id INT PRIMARY KEY IDENTITY(1,1),
    IdMes INT NOT NULL,
    FechaInicio DATE NOT NULL,
    FechaFin DATE NOT NULL,
    FOREIGN KEY (IdMes) REFERENCES Mes(Id)
);

CREATE TABLE HorarioJornada (
    Id INT PRIMARY KEY IDENTITY(1,1),
    IdTipoJornada INT NOT NULL,
    DiaSemana INT NOT NULL, -- 1: Lunes, ..., 7: Domingo
    FOREIGN KEY (IdTipoJornada) REFERENCES TipoJornada(Id)
);

CREATE TABLE EmpleadoJornadaSemana (
    Id INT PRIMARY KEY IDENTITY(1,1),
    IdEmpleado INT NOT NULL,
    IdSemana INT NOT NULL,
    IdTipoJornada INT NOT NULL,
    FOREIGN KEY (IdEmpleado) REFERENCES Empleado(Id),
    FOREIGN KEY (IdSemana) REFERENCES Semana(Id),
    FOREIGN KEY (IdTipoJornada) REFERENCES TipoJornada(Id)
);

-- 4. ASISTENCIA
CREATE TABLE Asistencia (
    Id INT PRIMARY KEY IDENTITY(1,1),
    IdEmpleado INT NOT NULL,
    Fecha DATE NOT NULL,
    HoraEntrada DATETIME,
    HoraSalida DATETIME,
    FOREIGN KEY (IdEmpleado) REFERENCES Empleado(Id)
);

CREATE TABLE MovimientoHoras (
    Id INT PRIMARY KEY IDENTITY(1,1),
    IdAsistencia INT NOT NULL,
    IdTipoJornada INT NOT NULL,
    HorasTrabajadas DECIMAL(5,2) NOT NULL,
    EsExtra BIT NOT NULL DEFAULT 0,
    FOREIGN KEY (IdAsistencia) REFERENCES Asistencia(Id),
    FOREIGN KEY (IdTipoJornada) REFERENCES TipoJornada(Id)
);

-- 5. DEDUCCIONES, FALTAN HERENCIAS
CREATE TABLE DeduccionLey (
    Id INT PRIMARY KEY IDENTITY(1,1),
    IdTipoDeduccion INT NOT NULL,
    Porcentaje DECIMAL(5,2) NOT NULL,
    FOREIGN KEY (IdTipoDeduccion) REFERENCES TipoDeduccion(Id)
);

-- 6. PLANILLA
CREATE TABLE PlanillaSemanal (
    Id INT PRIMARY KEY IDENTITY(1,1),
    IdSemana INT NOT NULL,
    FechaGeneracion DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (IdSemana) REFERENCES Semana(Id)
);

CREATE TABLE PlanillaSemanalEmpleado (
    Id INT PRIMARY KEY IDENTITY(1,1),
    IdPlanillaSemanal INT NOT NULL,
    IdEmpleado INT NOT NULL,
    SalarioBruto MONEY NOT NULL DEFAULT 0,
    TotalDeducciones MONEY NOT NULL DEFAULT 0,
    SalarioNeto MONEY NOT NULL DEFAULT 0,
    FOREIGN KEY (IdPlanillaSemanal) REFERENCES PlanillaSemanal(Id),
    FOREIGN KEY (IdEmpleado) REFERENCES Empleado(Id)
);

CREATE TABLE PlanillaMensual (
    Id INT PRIMARY KEY IDENTITY(1,1),
    IdMes INT NOT NULL,
    FechaGeneracion DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (IdMes) REFERENCES Mes(Id)
);

CREATE TABLE PlanillaMensualEmpleado (
    Id INT PRIMARY KEY IDENTITY(1,1),
    IdPlanillaMensual INT NOT NULL,
    IdEmpleado INT NOT NULL,
    TotalSalarioBruto MONEY NOT NULL DEFAULT 0,
    TotalDeducciones MONEY NOT NULL DEFAULT 0,
    TotalSalarioNeto MONEY NOT NULL DEFAULT 0,
    FOREIGN KEY (IdPlanillaMensual) REFERENCES PlanillaMensual(Id),
    FOREIGN KEY (IdEmpleado) REFERENCES Empleado(Id)
);

CREATE TABLE MovimientoPlanilla (
    Id INT PRIMARY KEY IDENTITY(1,1),
    IdPlanillaSemanalEmpleado INT NOT NULL,
    IdTipoMovimiento INT NOT NULL,
    Monto MONEY NOT NULL,
    FOREIGN KEY (IdPlanillaSemanalEmpleado) REFERENCES PlanillaSemanalEmpleado(Id),
    FOREIGN KEY (IdTipoMovimiento) REFERENCES TipoMovimiento(Id)
);

CREATE TABLE Devengado (
    Id INT PRIMARY KEY IDENTITY(1,1),
    IdMovimientoPlanilla INT NOT NULL,
    Descripcion VARCHAR(255),
    FOREIGN KEY (IdMovimientoPlanilla) REFERENCES MovimientoPlanilla(Id)
);

CREATE TABLE DeduccionEmpleadoMes (
    Id INT PRIMARY KEY IDENTITY(1,1),
    IdPlanillaMensualEmpleado INT NOT NULL,
    IdEmpleadoDeduccion INT NOT NULL,
    Monto MONEY NOT NULL,
    FOREIGN KEY (IdPlanillaMensualEmpleado) REFERENCES PlanillaMensualEmpleado(Id),
    FOREIGN KEY (IdEmpleadoDeduccion) REFERENCES EmpleadoDeduccion(Id)
);

-- 7. LOGS

CREATE TABLE Error (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Fecha DATETIME NOT NULL DEFAULT GETDATE(),
    Username VARCHAR(50) NOT NULL,
    Descripcion VARCHAR(MAX) NOT NULL
);

CREATE TABLE DbError (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Fecha DATETIME NOT NULL DEFAULT GETDATE(),
    Username VARCHAR(50) NOT NULL,
    Descripcion VARCHAR(MAX) NOT NULL
);

CREATE TABLE BitacoraEvento (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Fecha DATETIME NOT NULL DEFAULT GETDATE(),
    Username VARCHAR(50) NOT NULL,
    IdTipoEvento INT NOT NULL,
    Descripcion VARCHAR(MAX) NOT NULL,
    ValorAnterior VARCHAR(MAX),
    ValorNuevo VARCHAR(MAX),
    FOREIGN KEY (IdTipoEvento) REFERENCES TipoEvento(Id)
);