use crate::{
    db::DbParam,
    error::ApiResult,
    procedures::Procedure,
    state::AppState,
};
use serde_json::Value;

pub async fn consultar_planillas_semanales(
    state: &AppState,
    empleado_id: i32,
    limit: i32,
) -> ApiResult<Vec<Value>> {
    Ok(state
        .db
        .call(
            Procedure::ConsultarPlanillasSemanales,
            vec![DbParam::I32(empleado_id), DbParam::I32(limit)],
        )
        .await?)
}

pub async fn obtener_deducciones_semanales(
    state: &AppState,
    empleado_id: i32,
    id_planilla: i32,
) -> ApiResult<Vec<Value>> {
    Ok(state
        .db
        .call(
            Procedure::ObtenerDetalleDeduccionesSemanales,
            vec![DbParam::I32(empleado_id), DbParam::I32(id_planilla)],
        )
        .await?)
}

pub async fn obtener_asistencias_semanales(
    state: &AppState,
    empleado_id: i32,
    id_planilla: i32,
) -> ApiResult<Vec<Value>> {
    Ok(state
        .db
        .call(
            Procedure::ObtenerDetalleAsistenciasSemanales,
            vec![DbParam::I32(empleado_id), DbParam::I32(id_planilla)],
        )
        .await?)
}

pub async fn consultar_planillas_mensuales(
    state: &AppState,
    empleado_id: i32,
    limit: i32,
) -> ApiResult<Vec<Value>> {
    Ok(state
        .db
        .call(
            Procedure::ConsultarPlanillasMensuales,
            vec![DbParam::I32(empleado_id), DbParam::I32(limit)],
        )
        .await?)
}

pub async fn obtener_deducciones_mensuales(
    state: &AppState,
    empleado_id: i32,
    id_planilla_mensual: i32,
) -> ApiResult<Vec<Value>> {
    Ok(state
        .db
        .call(
            Procedure::ObtenerDetalleDeduccionesMensuales,
            vec![DbParam::I32(empleado_id), DbParam::I32(id_planilla_mensual)],
        )
        .await?)
}

pub async fn procesar_fecha_operacion(
    state: &AppState,
    fecha: Option<String>,
    xml: Option<String>,
    ruta_archivo: Option<String>,
) -> ApiResult<Vec<Value>> {
    Ok(state
        .db
        .call(
            Procedure::ProcesarFechaOperacion,
            vec![
                DbParam::NullableString(fecha),
                DbParam::NullableString(xml),
                DbParam::NullableString(ruta_archivo),
            ],
        )
        .await?)
}

pub async fn cargar_catalogos_xml(
    state: &AppState,
    xml: Option<String>,
    ruta_archivo: Option<String>,
) -> ApiResult<Vec<Value>> {
    Ok(state
        .db
        .call(
            Procedure::CargarCatalogosXml,
            vec![DbParam::NullableString(xml), DbParam::NullableString(ruta_archivo)],
        )
        .await?)
}
