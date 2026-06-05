use crate::{handlers, state::AppState};
use axum::{routing::post, Router};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/login", post(handlers::auth::login))
        .route("/logout", post(handlers::auth::logout))
}
