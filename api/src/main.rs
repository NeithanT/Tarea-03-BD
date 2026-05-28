mod audit;
mod config;
mod db;
mod error;
mod handlers;
mod models;
mod procedures;
mod repository;
mod routes;
mod sessions;
mod state;

use crate::{config::Settings, state::AppState};
use axum::http::{HeaderValue, Method, header};
use std::net::SocketAddr;
use tokio::net::TcpListener;
use tower_http::cors::CorsLayer;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenvy::dotenv().ok();

    let settings = Settings::from_env();
    let bind_addr = settings.bind_addr()?;
    let state = AppState::new(settings);

    let cors = CorsLayer::new()
        .allow_origin(HeaderValue::from_static("http://localhost:5173"))
        .allow_methods([
            Method::GET,
            Method::POST,
            Method::PUT,
            Method::DELETE,
            Method::OPTIONS,
        ])
        .allow_headers([header::AUTHORIZATION, header::CONTENT_TYPE]);

    let app = routes::router(state).layer(cors);
    let listener = TcpListener::bind(bind_addr).await?;

    println!("API listening on http://{}", bind_addr);

    axum::serve(
        listener,
        app.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .await?;

    Ok(())
}
