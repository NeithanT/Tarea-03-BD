use crate::{error::ApiResult, repository, routes::{require_admin, require_session}, state::AppState};
use axum::{extract::State, http::HeaderMap, Json};
use serde::Deserialize;
use serde_json::Value;

#[derive(Debug, Deserialize, Default)]
pub struct CargarCatalogosRequest {
    pub xml: Option<String>,
    pub ruta_archivo: Option<String>,
}

#[derive(Debug, Deserialize, Default)]
pub struct EjecutarOperacionRequest {
    pub fecha: Option<String>,
    pub xml: Option<String>,
    pub ruta_archivo: Option<String>,
}

pub async fn cargar_catalogos(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(payload): Json<CargarCatalogosRequest>,
) -> ApiResult<Json<Value>> {
    let (_, session) = require_session(&state, &headers).await?;
    require_admin(&session)?;

    let data = repository::simulation::cargar_catalogos_xml(
        &state,
        payload.xml,
        payload.ruta_archivo,
    )
    .await?;

    Ok(Json(serde_json::json!({ "data": data })))
}

pub async fn ejecutar_operacion(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(payload): Json<EjecutarOperacionRequest>,
) -> ApiResult<Json<Value>> {
    let (_, session) = require_session(&state, &headers).await?;
    require_admin(&session)?;

    let data = repository::simulation::procesar_fecha_operacion(
        &state,
        payload.fecha,
        payload.xml,
        payload.ruta_archivo,
    )
    .await?;

    Ok(Json(serde_json::json!({ "data": data })))
}
