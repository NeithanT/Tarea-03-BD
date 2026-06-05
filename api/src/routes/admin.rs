use crate::{handlers, state::AppState};
use axum::{routing::{get, post, put}, Router};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/empleados", get(handlers::admin::listar_empleados).post(handlers::admin::insertar_empleado))
        .route("/empleados/buscar", get(handlers::admin::buscar_empleados))
        .route(
            "/empleados/:id",
            put(handlers::admin::editar_empleado).delete(handlers::admin::eliminar_empleado),
        )
        .route("/impersonar", post(handlers::admin::impersonar))
}
