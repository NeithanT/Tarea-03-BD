use crate::{
    db::DbParam,
    error::ApiResult,
    procedures::Procedure,
    state::AppState,
};
use serde_json::Value;

pub async fn validar_usuario(
    state: &AppState,
    username: String,
    password: String,
    ip: &str,
) -> ApiResult<Vec<Value>> {
    Ok(state
        .db
        .call(
            Procedure::ValidarUsuario,
            vec![
                DbParam::String(username),
                DbParam::String(password),
                DbParam::String(ip.to_owned()),
            ],
        )
        .await?)
}
