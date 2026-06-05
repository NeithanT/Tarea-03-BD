use crate::{handlers, state::AppState};
use axum::{routing::post, Router};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/cargar-catalogos", post(handlers::simulation::cargar_catalogos))
        .route(
            "/ejecutar-operacion",
            post(handlers::simulation::ejecutar_operacion),
        )
}
