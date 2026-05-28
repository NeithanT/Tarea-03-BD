use std::{env, net::SocketAddr};

const DEFAULT_BIND_HOST: &str = "127.0.0.1";
const DEFAULT_BIND_PORT: u16 = 3000;
const DEFAULT_CONNECTION_STRING: &str = "server=tcp:127.0.0.1,1433;user=sa;password=YourStrong@Passw0rd;database=master;TrustServerCertificate=true";

#[derive(Clone, Debug)]
pub struct Settings {
    pub api_host: String,
    pub api_port: u16,
    pub database_url: String,
}

impl Settings {
    pub fn from_env() -> Self {
        Self {
            api_host: env::var("API_HOST").unwrap_or_else(|_| DEFAULT_BIND_HOST.to_owned()),
            api_port: env::var("API_PORT")
                .ok()
                .and_then(|value| value.parse::<u16>().ok())
                .unwrap_or(DEFAULT_BIND_PORT),
            database_url: env::var("DATABASE_URL")
                .or_else(|_| env::var("MSSQL_CONNECTION_STRING"))
                .unwrap_or_else(|_| DEFAULT_CONNECTION_STRING.to_owned()),
        }
    }

    pub fn bind_addr(&self) -> anyhow::Result<SocketAddr> {
        Ok(format!("{}:{}", self.api_host, self.api_port).parse()?)
    }
}
