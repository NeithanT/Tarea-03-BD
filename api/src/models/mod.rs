use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Puesto {
    pub id: i32,
    pub nombre: String,
    pub salario_por_hora: f64,
    pub descripcion: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Empleado {
    pub id: i32,
    pub nombre: String,
    pub apellido: String,
    pub fecha_ingreso: String,
    pub fecha_nacimiento: Option<String>,
    pub puesto_id: i32,
    pub activo: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Mes {
    pub id: i32,
    pub numero: i32,
    pub ano: i32,
    pub fecha_inicio: String,
    pub fecha_fin: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Semana {
    pub id: i32,
    pub numero_semana: i32,
    pub ano: i32,
    pub fecha_inicio: String,
    pub fecha_fin: String,
    pub mes_id: Option<i32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiaSemana {
    pub id: i32,
    pub nombre: String,
    pub numero: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HorarioJornada {
    pub id: i32,
    pub empleado_id: i32,
    pub dia_semana: i32,
    pub hora_entrada: String,
    pub hora_salida: String,
    pub es_jornada_nocturna: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AsistenciaAJornada {
    pub id: i32,
    pub empleado_id: i32,
    pub horario_jornada_id: Option<i32>,
    pub fecha: String,
    pub hora_entrada: Option<String>,
    pub hora_salida: Option<String>,
    pub horas_trabajadas: Option<f64>,
    pub estado: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Planilla {
    pub id: i32,
    pub empleado_id: i32,
    pub fecha_pago: String,
    pub ingreso_bruto: f64,
    pub total_deducciones: f64,
    pub ingreso_neto: f64,
    pub observaciones: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlanillaSemanal {
    pub id: i32,
    pub planilla_id: i32,
    pub semana_id: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlanillaMensual {
    pub id: i32,
    pub planilla_id: i32,
    pub mes_id: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlanillaAplicada {
    pub id: i32,
    pub planilla_id: i32,
    pub empleado_id: i32,
    pub fecha_aplicacion: String,
    pub estado: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Deduccion {
    pub id: i32,
    pub nombre: String,
    pub descripcion: Option<String>,
    pub tipo: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeduccionFija {
    pub id: i32,
    pub deduccion_id: i32,
    pub monto: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeduccionPorcentual {
    pub id: i32,
    pub deduccion_id: i32,
    pub porcentaje: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeduccionAplicada {
    pub id: i32,
    pub planilla_id: i32,
    pub empleado_id: i32,
    pub deduccion_id: i32,
    pub monto: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Usuario {
    pub id: i32,
    pub username: String,
    pub contrasena: String,
    pub nombre_usuario: String,
    pub contrasena_hash: String,
    pub id_rol: i32,
    pub activo: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UsuarioEmpleado {
    pub id: i32,
    pub usuario_id: i32,
    pub empleado_id: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TipoUsuario {
    pub id: i32,
    pub tipo_usuario: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TipoEvento {
    pub id: i32,
    pub nombre: String,
    pub descripcion: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BitacoraEvento {
    pub id: i32,
    pub usuario_id: i32,
    pub tipo_evento_id: i32,
    pub fecha_hora: String,
    pub descripcion: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Error {
    pub id: i32,
    pub codigo: i32,
    pub descripcion: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DBError {
    pub id: i32,
    pub username: String,
    pub number: i32,
    pub state: i32,
    pub severity: i32,
    pub line: i32,
    pub procedure: String,
    pub message: String,
    pub datetime: String,
}
