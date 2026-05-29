use axum::{extract::{State, Json}, routing::post, Router};
use crate::models::user::LoginRequest;
use crate::services::auth::AuthService;
use crate::AppState;

pub fn router() -> Router<AppState> {
    Router::new().route("/auth/login", post(login))
}

async fn login(
    State(state): State<AppState>,
    Json(payload): Json<LoginRequest>,
) -> Result<Json<crate::models::user::LoginResponse>, crate::services::auth::AuthError> {
    let auth_service = AuthService::new(&state.db);
    let response = auth_service.authenticate(&payload).await?;
    Ok(Json(response))
}
