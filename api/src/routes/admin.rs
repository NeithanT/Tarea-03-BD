use crate::{handlers, state::AppState};
use axum::{routing::{get, post}, Router};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/puestos", get(handlers::admin::listar_puestos))
        .route("/empleados", get(handlers::admin::listar_empleados).post(handlers::admin::insertar_empleado))
        .route("/empleados/buscar", get(handlers::admin::buscar_empleados))
        .route(
            "/empleados/:id",
            get(handlers::admin::obtener_empleado)
                .put(handlers::admin::editar_empleado)
                .delete(handlers::admin::eliminar_empleado),
        )
        .route("/empleados/:id/horario", get(handlers::admin::obtener_horario_empleado))
        .route("/impersonar", post(handlers::admin::impersonar))
}
