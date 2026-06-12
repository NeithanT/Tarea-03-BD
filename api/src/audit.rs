use crate::{
    db::DbParam,
    error::{ApiError, ApiResult},
    procedures::Procedure,
    state::AppState,
};
use serde_json::Value;

#[derive(Debug, Clone, Copy)]
pub enum AuditEvent {
    Login,
    Logout,
    ListarEmpleados,
    ListarEmpleadosConFiltro,
    InsertarEmpleado,
    EditarEmpleado,
    EliminarEmpleado,
    ImpersonarEmpleado,
    ConsultarPlanillaSemanal,
    ConsultarPlanillaMensual,
    RegresarAdmin,
}

impl AuditEvent {
    fn as_str(self) -> &'static str {
        match self {
            Self::Login => "Login",
            Self::Logout => "Logout",
            Self::ListarEmpleados => "Listar empleados",
            Self::ListarEmpleadosConFiltro => "Listar empleados con filtro",
            Self::InsertarEmpleado => "Insertar empleado",
            Self::EditarEmpleado => "Editar empleado",
            Self::EliminarEmpleado => "Eliminar empleado",
            Self::ImpersonarEmpleado => "Impersonar empleado",
            Self::ConsultarPlanillaSemanal => "Consultar una planilla semanal",
            Self::ConsultarPlanillaMensual => "Consultar una planilla mensual",
            Self::RegresarAdmin => "Regresar a interfaz de administrador",
        }
    }
}

pub async fn write_event(
    state: &AppState,
    user_id: Option<i32>,
    username: Option<&str>,
    event: AuditEvent,
    outcome: Option<&str>,
    parameters: Option<Value>,
    ip: &str,
) -> ApiResult<()> {
    let parameters = parameters.map(|value| value.to_string());

    state
        .db
        .call(
            Procedure::InsertarBitacora,
            vec![
                DbParam::NullableI32(user_id),
                DbParam::NullableString(username.map(str::to_owned)),
                DbParam::String(event.as_str().to_owned()),
                DbParam::NullableString(outcome.map(str::to_owned)),
                DbParam::NullableString(parameters),
                DbParam::String(ip.to_owned()),
            ],
        )
        .await
        .map(|_| ())
        .map_err(|error| ApiError::Database(format!("no se pudo registrar bitacora: {error:#}")))
}
