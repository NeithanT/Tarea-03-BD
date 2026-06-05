mod admin;
mod auth;
mod employee;
mod simulation;

use crate::{
    error::{ApiError, ApiResult},
    sessions::Session,
    state::AppState,
};
use axum::{
    Json, Router,
    http::{HeaderMap, StatusCode, header},
    routing::get,
};
use serde_json::{Value, json};
use std::net::SocketAddr;

pub fn router(state: AppState) -> Router {
    Router::new()
        .route("/api/health", get(health))
        .nest("/api/auth", auth::router())
        .nest("/api/admin", admin::router())
        .nest("/api/empleado", employee::router())
        .nest("/api/simulacion", simulation::router())
        .with_state(state)
}

async fn health() -> (StatusCode, Json<Value>) {
    (StatusCode::OK, Json(json!({ "status": "ok" })))
}

pub(crate) async fn require_session(
    state: &AppState,
    headers: &HeaderMap,
) -> ApiResult<(String, Session)> {
    let token = bearer_token(headers).ok_or(ApiError::Unauthorized)?;
    let session = state
        .sessions
        .get(&token)
        .await
        .ok_or(ApiError::Unauthorized)?;

    Ok((token, session))
}

pub(crate) fn require_admin(session: &Session) -> ApiResult<()> {
    if session.is_original_admin() {
        Ok(())
    } else {
        Err(ApiError::Forbidden(
            "esta ruta requiere rol Administrador".to_owned(),
        ))
    }
}

pub(crate) fn require_employee_context(session: &Session) -> ApiResult<i32> {
    session.effective_employee_id().ok_or_else(|| {
        ApiError::Forbidden("no hay un empleado asociado a la sesion actual".to_owned())
    })
}

pub(crate) fn client_ip(headers: &HeaderMap, peer_addr: SocketAddr) -> String {
    headers
        .get("x-forwarded-for")
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.split(',').next())
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_owned)
        .unwrap_or_else(|| peer_addr.ip().to_string())
}

pub(crate) fn field_string(value: &Value, names: &[&str]) -> Option<String> {
    let object = value.as_object()?;

    names.iter().find_map(|name| {
        object.iter().find_map(|(key, value)| {
            if key.eq_ignore_ascii_case(name) {
                match value {
                    Value::String(value) => Some(value.clone()),
                    Value::Number(value) => Some(value.to_string()),
                    Value::Bool(value) => Some(value.to_string()),
                    _ => None,
                }
            } else {
                None
            }
        })
    })
}

pub(crate) fn field_i32(value: &Value, names: &[&str]) -> Option<i32> {
    let object = value.as_object()?;

    names.iter().find_map(|name| {
        object.iter().find_map(|(key, value)| {
            if key.eq_ignore_ascii_case(name) {
                match value {
                    Value::Number(value) => {
                        value.as_i64().and_then(|value| i32::try_from(value).ok())
                    }
                    Value::String(value) => value.parse::<i32>().ok(),
                    _ => None,
                }
            } else {
                None
            }
        })
    })
}

pub(crate) fn field_bool(value: &Value, names: &[&str]) -> Option<bool> {
    let object = value.as_object()?;

    names.iter().find_map(|name| {
        object.iter().find_map(|(key, value)| {
            if key.eq_ignore_ascii_case(name) {
                match value {
                    Value::Bool(value) => Some(*value),
                    Value::Number(value) => value.as_i64().map(|value| value != 0),
                    Value::String(value) => match value.trim().to_ascii_lowercase().as_str() {
                        "true" | "1" | "si" | "s" | "yes" | "exitoso" => Some(true),
                        "false" | "0" | "no" | "n" | "fallido" | "no exitoso" => Some(false),
                        _ => None,
                    },
                    _ => None,
                }
            } else {
                None
            }
        })
    })
}

fn bearer_token(headers: &HeaderMap) -> Option<String> {
    let value = headers.get(header::AUTHORIZATION)?.to_str().ok()?;
    let token = value.strip_prefix("Bearer ")?;

    (!token.trim().is_empty()).then(|| token.trim().to_owned())
}
