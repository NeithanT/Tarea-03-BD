use crate::{
    db::DbParam,
    error::ApiResult,
    procedures::Procedure,
    state::AppState,
};
use serde_json::Value;

pub async fn listar_empleados(state: &AppState) -> ApiResult<Vec<Value>> {
    Ok(state.db.call(Procedure::ListarEmpleados, vec![]).await?)
}

pub async fn listar_puestos(state: &AppState) -> ApiResult<Vec<Value>> {
    Ok(state.db.call(Procedure::ListarPuestos, vec![]).await?)
}

pub async fn obtener_empleado(state: &AppState, id: i32) -> ApiResult<Vec<Value>> {
    Ok(state.db.call(Procedure::ObtenerEmpleado, vec![DbParam::I32(id)]).await?)
}

pub async fn listar_empleados_con_filtro(
    state: &AppState,
    filtro: String,
) -> ApiResult<Vec<Value>> {
    Ok(state
        .db
        .call(
            Procedure::ListarEmpleadosConFiltro,
            vec![DbParam::String(filtro)],
        )
        .await?)
}

pub async fn insertar_empleado(
    state: &AppState,
    params: Vec<DbParam>,
) -> ApiResult<Vec<Value>> {
    Ok(state.db.call(Procedure::InsertarEmpleado, params).await?)
}

pub async fn editar_empleado(
    state: &AppState,
    params: Vec<DbParam>,
) -> ApiResult<Vec<Value>> {
    Ok(state.db.call(Procedure::EditarEmpleado, params).await?)
}

pub async fn eliminar_empleado(state: &AppState, id: i32) -> ApiResult<Vec<Value>> {
    Ok(state
        .db
        .call(Procedure::EliminarEmpleado, vec![DbParam::I32(id)])
        .await?)
}
