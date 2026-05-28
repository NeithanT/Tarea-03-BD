use crate::{
    audit::{self, AuditEvent},
    error::{ApiError, ApiResult},
    repository,
    routes::{client_ip, field_string, require_employee_context, require_session},
    state::AppState,
};
use axum::{
    Json,
    extract::{ConnectInfo, Path, Query, State},
    http::{HeaderMap, StatusCode},
};
use serde::Deserialize;
use serde_json::{Value, json};
use std::net::SocketAddr;

#[derive(Debug, Deserialize)]
pub struct LimitQuery {
    pub limit: Option<i32>,
}

pub async fn planillas_semanales(
    State(state): State<AppState>,
    ConnectInfo(peer_addr): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
    Query(query): Query<LimitQuery>,
) -> ApiResult<Json<Value>> {
    let ip = client_ip(&headers, peer_addr);
    let (_, session) = require_session(&state, &headers).await?;
    let empleado_id = require_employee_context(&session)?;
    let limit = normalize_limit(query.limit);

    let data = repository::employee::consultar_planillas_semanales(&state, empleado_id, limit).await?;

    audit::write_event(
        &state,
        Some(session.user_id),
        Some(&session.username),
        AuditEvent::ConsultarPlanillaSemanal,
        Some("Exitoso"),
        Some(json!({
            "empleado_id": empleado_id,
            "limit": limit,
            "periodos": extract_periods(&data)
        })),
        &ip,
    )
    .await?;

    Ok(Json(json!({ "data": data })))
}

pub async fn deducciones_semanales(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id_planilla): Path<i32>,
) -> ApiResult<Json<Value>> {
    let (_, session) = require_session(&state, &headers).await?;
    let empleado_id = require_employee_context(&session)?;

    let data = repository::employee::obtener_deducciones_semanales(&state, empleado_id, id_planilla)
        .await?;

    Ok(Json(json!({ "data": data })))
}

pub async fn asistencias_semanales(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id_planilla): Path<i32>,
) -> ApiResult<Json<Value>> {
    let (_, session) = require_session(&state, &headers).await?;
    let empleado_id = require_employee_context(&session)?;

    let data = repository::employee::obtener_asistencias_semanales(&state, empleado_id, id_planilla)
        .await?;

    Ok(Json(json!({ "data": data })))
}

pub async fn planillas_mensuales(
    State(state): State<AppState>,
    ConnectInfo(peer_addr): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
    Query(query): Query<LimitQuery>,
) -> ApiResult<Json<Value>> {
    let ip = client_ip(&headers, peer_addr);
    let (_, session) = require_session(&state, &headers).await?;
    let empleado_id = require_employee_context(&session)?;
    let limit = normalize_limit(query.limit);

    let data = repository::employee::consultar_planillas_mensuales(&state, empleado_id, limit).await?;

    audit::write_event(
        &state,
        Some(session.user_id),
        Some(&session.username),
        AuditEvent::ConsultarPlanillaMensual,
        Some("Exitoso"),
        Some(json!({
            "empleado_id": empleado_id,
            "limit": limit,
            "periodos": extract_periods(&data)
        })),
        &ip,
    )
    .await?;

    Ok(Json(json!({ "data": data })))
}

pub async fn deducciones_mensuales(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id_planilla_mensual): Path<i32>,
) -> ApiResult<Json<Value>> {
    let (_, session) = require_session(&state, &headers).await?;
    let empleado_id = require_employee_context(&session)?;

    let data = repository::employee::obtener_deducciones_mensuales(
        &state,
        empleado_id,
        id_planilla_mensual,
    )
    .await?;

    Ok(Json(json!({ "data": data })))
}

pub async fn regresar_admin(
    State(state): State<AppState>,
    ConnectInfo(peer_addr): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
) -> ApiResult<StatusCode> {
    let ip = client_ip(&headers, peer_addr);
    let (token, session) = require_session(&state, &headers).await?;

    if !session.is_original_admin() {
        return Err(ApiError::Forbidden(
            "solo un administrador original puede regresar a la interfaz de administrador"
                .to_owned(),
        ));
    }

    if !session.is_impersonating() {
        return Err(ApiError::BadRequest(
            "la sesion actual no esta impersonando a un empleado".to_owned(),
        ));
    }

    audit::write_event(
        &state,
        Some(session.user_id),
        Some(&session.username),
        AuditEvent::RegresarAdmin,
        Some("Exitoso"),
        None,
        &ip,
    )
    .await?;

    state.sessions.stop_impersonating(&token).await;

    Ok(StatusCode::NO_CONTENT)
}

fn normalize_limit(limit: Option<i32>) -> i32 {
    limit.unwrap_or(10).clamp(1, 104)
}

fn extract_periods(rows: &[Value]) -> Vec<Value> {
    rows.iter()
        .map(|row| {
            json!({
                "fecha_inicio": field_string(row, &["FechaInicio", "fecha_inicio"]),
                "fecha_fin": field_string(row, &["FechaFin", "fecha_fin"])
            })
        })
        .collect()
}
