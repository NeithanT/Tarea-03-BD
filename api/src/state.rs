use crate::{config::Settings, db::Database, sessions::SessionStore};

#[derive(Clone)]
pub struct AppState {
    pub db: Database,
    pub sessions: SessionStore,
}

impl AppState {
    pub fn new(settings: Settings) -> Self {
        Self {
            db: Database::new(settings.database_url),
            sessions: SessionStore::default(),
        }
    }
}
