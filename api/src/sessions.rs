use serde::Serialize;
use std::{collections::HashMap, sync::Arc};
use tokio::sync::RwLock;
use uuid::Uuid;

#[derive(Clone, Debug, Serialize)]
pub struct Session {
    pub user_id: i32,
    pub username: String,
    pub role: String,
    pub employee_id: Option<i32>,
    pub original_role: String,
    pub impersonated_employee_id: Option<i32>,
}

#[derive(Clone, Default)]
pub struct SessionStore {
    sessions: Arc<RwLock<HashMap<String, Session>>>,
}

#[derive(Debug, Serialize)]
pub struct CreatedSession {
    pub token: String,
    pub session: Session,
}

impl Session {
    pub fn is_original_admin(&self) -> bool {
        is_admin_role(&self.original_role)
    }

    pub fn effective_employee_id(&self) -> Option<i32> {
        self.impersonated_employee_id.or(self.employee_id)
    }

    pub fn is_impersonating(&self) -> bool {
        self.impersonated_employee_id.is_some()
    }
}

impl SessionStore {
    pub async fn create(
        &self,
        user_id: i32,
        username: String,
        role: String,
        employee_id: Option<i32>,
    ) -> CreatedSession {
        let token = Uuid::new_v4().to_string();
        let session = Session {
            user_id,
            username,
            original_role: role.clone(),
            role,
            employee_id,
            impersonated_employee_id: None,
        };

        self.sessions
            .write()
            .await
            .insert(token.clone(), session.clone());

        CreatedSession { token, session }
    }

    pub async fn get(&self, token: &str) -> Option<Session> {
        self.sessions.read().await.get(token).cloned()
    }

    pub async fn remove(&self, token: &str) -> Option<Session> {
        self.sessions.write().await.remove(token)
    }

    pub async fn impersonate(&self, token: &str, employee_id: i32) -> Option<Session> {
        let mut sessions = self.sessions.write().await;
        let session = sessions.get_mut(token)?;

        session.impersonated_employee_id = Some(employee_id);
        Some(session.clone())
    }

    pub async fn stop_impersonating(&self, token: &str) -> Option<Session> {
        let mut sessions = self.sessions.write().await;
        let session = sessions.get_mut(token)?;

        session.impersonated_employee_id = None;
        Some(session.clone())
    }
}

pub fn is_admin_role(role: &str) -> bool {
    matches!(
        role.trim().to_ascii_lowercase().as_str(),
        "admin" | "administrador" | "administrative"
    )
}
