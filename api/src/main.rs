mod db;
mod models;
mod routes;
mod services;

use axum::{routing::get, Router};
use dotenvy::dotenv;
use sqlx_core::pool::Pool;
use std::{env, net::SocketAddr};
use welds_sqlx_mssql::Mssql;

#[derive(Clone)]
struct AppState {
    db: Pool<Mssql>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenv().ok();

    let db_user = env::var("DB_USER").expect("DB_USER must be set in .env or the environment");
    let db_password = env::var("DB_PASSWORD").expect("DB_PASSWORD must be set in .env or the environment");
    let db_host = env::var("DB_HOST").unwrap_or_else(|_| "127.0.0.1".to_string());
    let db_port = env::var("DB_PORT").unwrap_or_else(|_| "1433".to_string());
    let db_name = env::var("DB_NAME").unwrap_or_else(|_| "master".to_string());
    let db_encrypt = env::var("DB_ENCRYPT").unwrap_or_else(|_| "false".to_string());

    let database_url = format!(
        "mssql://{}:{}@{}:{}/{}?encrypt={}",
        db_user, db_password, db_host, db_port, db_name, db_encrypt
    );

    let pool = db::connect(&database_url)
        .await
        .expect("Failed to connect to the database");

    let app = Router::new()
        .route("/", get(root))
        .merge(routes::users::router())
        .with_state(AppState { db: pool });

    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    println!("Listening on http://{}", addr);

    axum_server::bind(addr)
        .serve(app.into_make_service())
        .await?;

    Ok(())
}

async fn root() -> &'static str {
    "Hello, world!"
}
