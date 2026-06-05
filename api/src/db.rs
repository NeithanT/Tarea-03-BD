use crate::procedures::Procedure;
use anyhow::Context;
use serde_json::{Map, Number, Value};
use std::{borrow::Cow, sync::Arc};
use tiberius::{Client, ColumnData, Config, Row, ToSql};
use tokio::net::TcpStream;
use tokio_util::compat::{Compat, TokioAsyncWriteCompatExt};

type SqlClient = Client<Compat<TcpStream>>;

#[derive(Clone)]
pub struct Database {
    connection_string: Arc<str>,
}

#[derive(Debug, Clone)]
pub enum DbParam {
    I32(i32),
    NullableI32(Option<i32>),
    String(String),
    NullableString(Option<String>),
}

impl Database {
    pub fn new(connection_string: String) -> Self {
        Self {
            connection_string: Arc::from(connection_string),
        }
    }

    pub async fn call(
        &self,
        procedure: Procedure,
        params: Vec<DbParam>,
    ) -> anyhow::Result<Vec<Value>> {
        let mut client = self.connect().await?;
        let statement = build_procedure_call(procedure, params.len());
        let param_refs = params
            .iter()
            .map(|param| param as &dyn ToSql)
            .collect::<Vec<_>>();

        let rows = client
            .query(statement.as_str(), &param_refs)
            .await
            .with_context(|| format!("fallo al ejecutar {}", procedure.name()))?
            .into_first_result()
            .await
            .with_context(|| format!("fallo al leer respuesta de {}", procedure.name()))?;

        Ok(rows.iter().map(row_to_json).collect())
    }

    async fn connect(&self) -> anyhow::Result<SqlClient> {
        let config = Config::from_ado_string(&self.connection_string)
            .context("DATABASE_URL/MSSQL_CONNECTION_STRING invalido")?;
        let tcp = TcpStream::connect(config.get_addr())
            .await
            .context("no se pudo conectar a SQL Server")?;

        tcp.set_nodelay(true)
            .context("no se pudo configurar TCP_NODELAY")?;

        Client::connect(config, tcp.compat_write())
            .await
            .context("no se pudo abrir la sesion de SQL Server")
    }
}

impl ToSql for DbParam {
    fn to_sql(&self) -> ColumnData<'_> {
        match self {
            Self::I32(value) => ColumnData::I32(Some(*value)),
            Self::NullableI32(value) => ColumnData::I32(*value),
            Self::String(value) => ColumnData::String(Some(Cow::Borrowed(value.as_str()))),
            Self::NullableString(Some(value)) => {
                ColumnData::String(Some(Cow::Borrowed(value.as_str())))
            }
            Self::NullableString(None) => ColumnData::String(None),
        }
    }
}

fn build_procedure_call(procedure: Procedure, param_count: usize) -> String {
    let mut statement = format!("EXEC {}", procedure.qualified_name());

    if param_count > 0 {
        let placeholders = (1..=param_count)
            .map(|index| format!("@P{}", index))
            .collect::<Vec<_>>()
            .join(", ");

        statement.push(' ');
        statement.push_str(&placeholders);
    }

    statement
}

fn row_to_json(row: &Row) -> Value {
    let mut map = Map::new();

    for (column, value) in row.cells() {
        map.insert(column.name().to_owned(), column_to_json(value));
    }

    Value::Object(map)
}

fn column_to_json(value: &ColumnData<'static>) -> Value {
    match value {
        ColumnData::U8(Some(value)) => Value::Number(Number::from(*value)),
        ColumnData::I16(Some(value)) => Value::Number(Number::from(*value)),
        ColumnData::I32(Some(value)) => Value::Number(Number::from(*value)),
        ColumnData::I64(Some(value)) => Value::Number(Number::from(*value)),
        ColumnData::F32(Some(value)) => Number::from_f64(*value as f64)
            .map(Value::Number)
            .unwrap_or(Value::Null),
        ColumnData::F64(Some(value)) => Number::from_f64(*value)
            .map(Value::Number)
            .unwrap_or(Value::Null),
        ColumnData::Bit(Some(value)) => Value::Bool(*value),
        ColumnData::String(Some(value)) => Value::String(value.to_string()),
        ColumnData::Guid(Some(value)) => Value::String(value.to_string()),
        ColumnData::Binary(Some(value)) => Value::Array(
            value
                .iter()
                .map(|byte| Value::Number(Number::from(*byte)))
                .collect(),
        ),
        ColumnData::Numeric(Some(value)) => Value::String(value.to_string()),
        ColumnData::Xml(Some(value)) => Value::String(value.to_string()),
        ColumnData::DateTime(Some(value)) => Value::String(format!("{:?}", value)),
        ColumnData::SmallDateTime(Some(value)) => Value::String(format!("{:?}", value)),
        #[cfg(feature = "tds73")]
        ColumnData::Time(Some(value)) => Value::String(format!("{:?}", value)),
        #[cfg(feature = "tds73")]
        ColumnData::Date(Some(value)) => Value::String(format!("{:?}", value)),
        #[cfg(feature = "tds73")]
        ColumnData::DateTime2(Some(value)) => Value::String(format!("{:?}", value)),
        #[cfg(feature = "tds73")]
        ColumnData::DateTimeOffset(Some(value)) => Value::String(format!("{:?}", value)),
        _ => Value::Null,
    }
}
