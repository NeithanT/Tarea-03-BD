export interface Empleado {
	id: number;
	Cedula: string;
	Nombre: string;
	Apellido: string;
	Puesto: string;
	FechaIngreso: string;
	Activo: boolean;
}

export interface EmpleadoDetalle {
	id: number;
	Cedula: string;
	Nombre: string;
	Apellido: string;
	idPuesto: number;
	NombrePuesto: string;
	FechaIngreso: string;
	FechaNacimiento: string | null;
	Activo: boolean;
}

export interface Puesto {
	id: number;
	Nombre: string;
	SalarioPorHora: number;
	Descripcion: string | null;
}

export interface EmpleadoPayload {
	nombre: string;
	apellido: string;
	fecha_ingreso: string;
	fecha_nacimiento: string | null;
	puesto_id: number;
	activo: boolean;
}

export interface SessionUser {
	user_id: number;
	username: string;
	role: string;
	employee_id: number | null;
	impersonated_employee_id: number | null;
}

export interface HorarioDia {
	DiaSemana: number;
	NombreDia: string;
	EsDiaDescanso: boolean;
	NombreJornada: string;
	HoraInicio: string;
	HoraFin: string;
	Fecha: string;
	SemanaInicio: string;
	SemanaFin: string;
}

export interface AuthState {
	token: string;
	user: SessionUser;
}

export interface PlanillaSemanal {
	id: number;
	idPlanilla: number;
	NumeroSemana: number;
	Ano: number;
	FechaInicio: string;
	FechaFin: string;
	FechaPago: string;
	IngresoBruto: number;
	TotalDeducciones: number;
	IngresoNeto: number;
	HorasOrdinarias: number;
	HorasExtraNormales: number;
	HorasExtraDobles: number;
}

export interface PlanillaMensual {
	id: number;
	idPlanilla: number;
	Numero: number;
	Ano: number;
	FechaInicio: string;
	FechaFin: string;
	FechaPago: string;
	IngresoBruto: number;
	TotalDeducciones: number;
	IngresoNeto: number;
}

export interface DeduccionDetalle {
	NombreDeduccion: string;
	Porcentual: boolean;
	Porcentaje: number | null;
	Monto: number;
}

export interface AsistenciaDetalle {
	Fecha: string;
	HoraEntrada: string | null;
	HoraSalida: string | null;
	HorasOrdinarias: number;
	MontoOrdinario: number;
	HorasExtraNormales: number;
	MontoExtraNormal: number;
	HorasExtraDobles: number;
	MontoExtraDoble: number;
}
