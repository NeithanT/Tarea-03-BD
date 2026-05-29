use serde::{Deserialize, Serialize};
use sqlx_core::{from_row::FromRow, error::Error as SqlxError, row::Row};
use welds_sqlx_mssql::MssqlRow;

#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub username: String,
    pub password: String,
}

#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub id: i32,
    pub username: String,
    pub nombre_usuario: String,
    pub id_rol: i32,
    pub activo: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Usuario {
    pub id: i32,
    pub username: String,
    pub contrasena: String,
    pub nombre_usuario: String,
    pub contrasena_hash: String,
    pub id_rol: i32,
    pub activo: bool,
}

impl<'r> FromRow<'r, MssqlRow> for Usuario {
    fn from_row(row: &'r MssqlRow) -> Result<Self, SqlxError> {
        Ok(Self {
            id: row.try_get("id")?,
            username: row.try_get("Username")?,
            contrasena: row.try_get("Contrasena")?,
            nombre_usuario: row.try_get("NombreUsuario")?,
            contrasena_hash: row.try_get("ContrasenaHash")?,
            id_rol: row.try_get("idRol")?,
            activo: row.try_get("Activo")?,
        })
    }
}
