use crate::{handlers, state::AppState};
use axum::{routing::{get, post}, Router};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/planillas-semanales", get(handlers::employee::planillas_semanales))
        .route(
            "/planillas-semanales/:id_planilla/deducciones",
            get(handlers::employee::deducciones_semanales),
        )
        .route(
            "/planillas-semanales/:id_planilla/asistencias",
            get(handlers::employee::asistencias_semanales),
        )
        .route("/planillas-mensuales", get(handlers::employee::planillas_mensuales))
        .route(
            "/planillas-mensuales/:id_planilla_mensual/deducciones",
            get(handlers::employee::deducciones_mensuales),
        )
        .route("/regresar-admin", post(handlers::employee::regresar_admin))
}
