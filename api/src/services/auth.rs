use axum::{response::{IntoResponse, Response}, Json};
use axum::http::StatusCode;
use serde_json::json;
use sqlx_core::{pool::Pool, query_as::query_as, error::Error as SqlxError};
use welds_sqlx_mssql::Mssql;

use crate::models::user::{LoginRequest, LoginResponse, Usuario};

#[derive(Debug)]
pub enum AuthError {
    Database(SqlxError),
    InvalidCredentials,
    InactiveUser,
}

impl From<SqlxError> for AuthError {
    fn from(error: SqlxError) -> Self {
        AuthError::Database(error)
    }
}

impl AuthError {
    fn status_code(&self) -> StatusCode {
        match self {
            AuthError::Database(_) => StatusCode::INTERNAL_SERVER_ERROR,
            AuthError::InvalidCredentials => StatusCode::UNAUTHORIZED,
            AuthError::InactiveUser => StatusCode::FORBIDDEN,
        }
    }

    fn message(&self) -> String {
        match self {
            AuthError::Database(err) => format!("Database error: {}", err),
            AuthError::InvalidCredentials => "Invalid username or password".to_string(),
            AuthError::InactiveUser => "User is inactive".to_string(),
        }
    }
}

impl IntoResponse for AuthError {
    fn into_response(self) -> Response {
        let body = Json(json!({ "error": self.message() }));
        (self.status_code(), body).into_response()
    }
}

pub struct AuthService<'a> {
    db: &'a Pool<Mssql>,
}

impl<'a> AuthService<'a> {
    pub fn new(db: &'a Pool<Mssql>) -> Self {
        Self { db }
    }

    pub async fn authenticate(
        &self,
        payload: &LoginRequest,
    ) -> Result<LoginResponse, AuthError> {
        let user = self.find_user(payload).await?;

        if !user.activo {
            return Err(AuthError::InactiveUser);
        }

        if user.contrasena != payload.password {
            return Err(AuthError::InvalidCredentials);
        }

        Ok(LoginResponse {
            id: user.id,
            username: user.username,
            nombre_usuario: user.nombre_usuario,
            id_rol: user.id_rol,
            activo: user.activo,
        })
    }

    async fn find_user(&self, payload: &LoginRequest) -> Result<Usuario, AuthError> {
        let user = query_as::<_, Usuario>(
            "EXEC LogInUser @Username = ?, @Password = ?",
        )
        .bind(&payload.username)
        .bind(&payload.password)
        .fetch_optional(self.db)
        .await?;

        user.ok_or(AuthError::InvalidCredentials)
    }
}
