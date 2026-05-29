use sqlx_core::pool::Pool;
use welds_sqlx_mssql::{Mssql, MssqlPoolOptions};

pub async fn connect(database_url: &str) -> anyhow::Result<Pool<Mssql>> {
    let pool = MssqlPoolOptions::new()
        .max_connections(5)
        .connect(database_url)
        .await?;

    Ok(pool)
}
