use crate::{
    audit::{self, AuditEvent},
    db::DbParam,
    error::{ApiError, ApiResult},
    repository,
    routes::{client_ip, field_i32, require_admin, require_session},
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
pub struct BuscarEmpleadosQuery {
    pub filtro: String,
}

#[derive(Debug, Deserialize, serde::Serialize)]
pub struct EmpleadoPayload {
    pub nombre: String,
    pub apellido: String,
    pub fecha_ingreso: String,
    pub fecha_nacimiento: Option<String>,
    pub puesto_id: i32,
    pub activo: bool,
}

#[derive(Debug, Deserialize)]
pub struct ImpersonarRequest {
    pub empleado_id: i32,
}

pub async fn listar_puestos(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> ApiResult<Json<Value>> {
    let (_, session) = require_session(&state, &headers).await?;
    require_admin(&session)?;
    let data = repository::admin::listar_puestos(&state).await?;
    Ok(Json(json!({ "data": data })))
}

pub async fn obtener_empleado(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<i32>,
) -> ApiResult<Json<Value>> {
    let (_, session) = require_session(&state, &headers).await?;
    require_admin(&session)?;
    let data = repository::admin::obtener_empleado(&state, id).await?;
    Ok(Json(json!({ "data": data })))
}

pub async fn listar_empleados(
    State(state): State<AppState>,
    ConnectInfo(peer_addr): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
) -> ApiResult<Json<Value>> {
    let ip = client_ip(&headers, peer_addr);
    let (_, session) = require_session(&state, &headers).await?;
    require_admin(&session)?;

    let data = repository::admin::listar_empleados(&state, session.user_id, &ip).await?;
 
    audit::write_event(
        &state,
        Some(session.user_id),
        Some(&session.username),
        AuditEvent::ListarEmpleados,
        Some("Exitoso"),
        None,
        &ip,
    )
    .await?;

    Ok(Json(json!({ "data": data })))
}

pub async fn buscar_empleados(
    State(state): State<AppState>,
    ConnectInfo(peer_addr): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
    Query(query): Query<BuscarEmpleadosQuery>,
) -> ApiResult<Json<Value>> {
    let ip = client_ip(&headers, peer_addr);
    let (_, session) = require_session(&state, &headers).await?;
    require_admin(&session)?;

    let filtro = query.filtro.trim().to_owned();
    let data = repository::admin::listar_empleados_con_filtro(&state, filtro.clone()).await?;

    audit::write_event(
        &state,
        Some(session.user_id),
        Some(&session.username),
        AuditEvent::ListarEmpleadosConFiltro,
        Some("Exitoso"),
        Some(json!({ "filtro": filtro })),
        &ip,
    )
    .await?;

    Ok(Json(json!({ "data": data })))
}

pub async fn insertar_empleado(
    State(state): State<AppState>,
    ConnectInfo(peer_addr): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
    Json(payload): Json<EmpleadoPayload>,
) -> ApiResult<(StatusCode, Json<Value>)> {
    let ip = client_ip(&headers, peer_addr);
    let (_, session) = require_session(&state, &headers).await?;
    require_admin(&session)?;

    validate_employee_payload(&payload)?;

    let mut params = empleado_params(&payload);
    params.push(DbParam::I32(session.user_id));
    params.push(DbParam::String(ip.clone()));
    let result = repository::admin::insertar_empleado(&state, params).await?;

    audit::write_event(
        &state,
        Some(session.user_id),
        Some(&session.username),
        AuditEvent::InsertarEmpleado,
        Some("Exitoso"),
        Some(json!({ "atributos": payload })),
        &ip,
    )
    .await?;

    Ok((StatusCode::CREATED, Json(json!({ "data": result }))))
}

pub async fn editar_empleado(
    State(state): State<AppState>,
    ConnectInfo(peer_addr): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
    Path(id): Path<i32>,
    Json(payload): Json<EmpleadoPayload>,
) -> ApiResult<Json<Value>> {
    let ip = client_ip(&headers, peer_addr);
    let (_, session) = require_session(&state, &headers).await?;
    require_admin(&session)?;

    validate_employee_payload(&payload)?;

    let before = snapshot_empleado(&state, id).await?;

    let mut params = vec![DbParam::I32(id)];
    params.extend(empleado_params(&payload));
    params.push(DbParam::String(ip.clone()));
    params.push(DbParam::I32(session.user_id));

    let result = repository::admin::editar_empleado(&state, params).await?;
    let after = json!({
        "id": id,
        "nombre": payload.nombre,
        "apellido": payload.apellido,
        "fecha_ingreso": payload.fecha_ingreso,
        "fecha_nacimiento": payload.fecha_nacimiento,
        "puesto_id": payload.puesto_id,
        "activo": payload.activo,
    });

    audit::write_event(
        &state,
        Some(session.user_id),
        Some(&session.username),
        AuditEvent::EditarEmpleado,
        Some("Exitoso"),
        Some(json!({
            "empleado_id": id,
            "antes": before,
            "despues": payload,
            "detalle_sp": result,
            "estado_final": after,
        })),
        &ip,
    )
    .await?;

    Ok(Json(json!({ "data": result })))
}

pub async fn eliminar_empleado(
    State(state): State<AppState>,
    ConnectInfo(peer_addr): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
    Path(id): Path<i32>,
) -> ApiResult<StatusCode> {
    let ip = client_ip(&headers, peer_addr);
    let (_, session) = require_session(&state, &headers).await?;
    require_admin(&session)?;

    let before = snapshot_empleado(&state, id).await?;
    let result = repository::admin::eliminar_empleado(&state, id).await?;

    audit::write_event(
        &state,
        Some(session.user_id),
        Some(&session.username),
        AuditEvent::EliminarEmpleado,
        Some("Exitoso"),
        Some(json!({
            "empleado_id": id,
            "antes": before,
            "atributos_eliminados": result
        })),
        &ip,
    )
    .await?;

    Ok(StatusCode::NO_CONTENT)
}

pub async fn impersonar(
    State(state): State<AppState>,
    ConnectInfo(peer_addr): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
    Json(payload): Json<ImpersonarRequest>,
) -> ApiResult<Json<Value>> {
    let ip = client_ip(&headers, peer_addr);
    let (token, session) = require_session(&state, &headers).await?;
    require_admin(&session)?;

    let updated_session = state
        .sessions
        .impersonate(&token, payload.empleado_id)
        .await
        .ok_or(ApiError::Unauthorized)?;

    audit::write_event(
        &state,
        Some(session.user_id),
        Some(&session.username),
        AuditEvent::ImpersonarEmpleado,
        Some("Exitoso"),
        Some(json!({ "empleado_id": payload.empleado_id })),
        &ip,
    )
    .await?;

    Ok(Json(json!({
        "session": updated_session,
        "effective_role": "Empleado",
        "impersonando": true
    })))
}

fn empleado_params(payload: &EmpleadoPayload) -> Vec<DbParam> {
    vec![
        DbParam::String(payload.nombre.trim().to_owned()),
        DbParam::String(payload.apellido.trim().to_owned()),
        DbParam::String(payload.fecha_ingreso.trim().to_owned()),
        DbParam::NullableString(payload.fecha_nacimiento.clone()),
        DbParam::I32(payload.puesto_id),
        DbParam::I32(i32::from(payload.activo)),
    ]
}

fn validate_employee_payload(payload: &EmpleadoPayload) -> ApiResult<()> {
    if payload.nombre.trim().is_empty()
        || payload.apellido.trim().is_empty()
        || payload.fecha_ingreso.trim().is_empty()
    {
        return Err(ApiError::BadRequest(
            "nombre, apellido y fecha_ingreso son obligatorios".to_owned(),
        ));
    }

    Ok(())
}

async fn snapshot_empleado(state: &AppState, empleado_id: i32) -> ApiResult<Option<Value>> {
    let rows = repository::admin::obtener_empleado(state, empleado_id).await?;
    Ok(rows.into_iter().next())
}
