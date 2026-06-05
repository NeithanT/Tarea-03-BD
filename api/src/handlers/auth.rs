use crate::{
    audit::{self, AuditEvent},
    error::{ApiError, ApiResult},
    repository,
    routes::{client_ip, field_bool, field_i32, field_string, require_session},
    state::AppState,
};
use axum::{
    Json,
    extract::{ConnectInfo, State},
    http::{HeaderMap, StatusCode},
};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::net::SocketAddr;

#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub username: String,
    pub password: String,
}

#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub token: String,
    pub user: UserSessionResponse,
}

#[derive(Debug, Serialize)]
pub struct UserSessionResponse {
    pub user_id: i32,
    pub username: String,
    pub role: String,
    pub employee_id: Option<i32>,
    pub impersonated_employee_id: Option<i32>,
}

pub async fn login(
    State(state): State<AppState>,
    ConnectInfo(peer_addr): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
    Json(payload): Json<LoginRequest>,
) -> ApiResult<(StatusCode, Json<LoginResponse>)> {
    let ip = client_ip(&headers, peer_addr);
    let username = payload.username.trim().to_owned();

    if username.is_empty() || payload.password.is_empty() {
        return Err(ApiError::BadRequest(
            "username y password son obligatorios".to_owned(),
        ));
    }

    let rows = repository::auth::validar_usuario(&state, username.clone(), payload.password).await?;
    let user = rows.first();
    let authenticated = user.map(is_authenticated).unwrap_or(false);
    let user_id = user.and_then(|value| {
        field_i32(
            value,
            &["UserId", "UsuarioId", "IdUsuario", "id", "usuario_id"],
        )
    });
    let outcome = if authenticated { "Exitoso" } else { "No exitoso" };

    audit::write_event(
        &state,
        user_id,
        Some(&username),
        AuditEvent::Login,
        Some(outcome),
        Some(json!({ "username": username, "resultado": outcome })),
        &ip,
    )
    .await?;

    if !authenticated {
        return Err(ApiError::Unauthorized);
    }

    let user = user.ok_or_else(|| ApiError::Unauthorized)?;
    let user_id = user_id.ok_or_else(|| {
        ApiError::Database("SP_ValidarUsuario no retorno UserId/UsuarioId".to_owned())
    })?;
    let role = resolve_role(user);
    let employee_id = field_i32(
        user,
        &["EmpleadoId", "IdEmpleado", "employee_id", "empleado_id"],
    );

    let created = state
        .sessions
        .create(user_id, username.clone(), role.clone(), employee_id)
        .await;

    Ok((
        StatusCode::OK,
        Json(LoginResponse {
            token: created.token,
            user: UserSessionResponse {
                user_id,
                username,
                role,
                employee_id,
                impersonated_employee_id: None,
            },
        }),
    ))
}

pub async fn logout(
    State(state): State<AppState>,
    ConnectInfo(peer_addr): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
) -> ApiResult<StatusCode> {
    let ip = client_ip(&headers, peer_addr);
    let (token, session) = require_session(&state, &headers).await?;

    audit::write_event(
        &state,
        Some(session.user_id),
        Some(&session.username),
        AuditEvent::Logout,
        Some("Exitoso"),
        None,
        &ip,
    )
    .await?;

    state.sessions.remove(&token).await;

    Ok(StatusCode::NO_CONTENT)
}

fn is_authenticated(value: &Value) -> bool {
    field_bool(
        value,
        &[
            "Autenticado",
            "Authenticated",
            "Success",
            "Exitoso",
            "Valido",
            "EsValido",
        ],
    )
    .unwrap_or(true)
}

fn resolve_role(value: &Value) -> String {
    field_string(
        value,
        &["Rol", "Role", "TipoUsuario", "NombreRol", "role", "tipo_usuario"],
    )
    .or_else(|| {
        field_i32(value, &["RolId", "idRol", "IdRol"]).map(|role_id| {
            if role_id == 1 {
                "Administrador".to_owned()
            } else {
                "Empleado".to_owned()
            }
        })
    })
    .unwrap_or_else(|| "Empleado".to_owned())
}
