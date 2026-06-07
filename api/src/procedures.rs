#[derive(Debug, Clone, Copy)]
pub enum Procedure {
    ValidarUsuario,
    InsertarBitacora,
    ListarEmpleados,
    ListarPuestos,
    ObtenerEmpleado,
    ListarEmpleadosConFiltro,
    InsertarEmpleado,
    EditarEmpleado,
    EliminarEmpleado,
    ConsultarPlanillasSemanales,
    ObtenerDetalleDeduccionesSemanales,
    ObtenerDetalleAsistenciasSemanales,
    ConsultarPlanillasMensuales,
    ObtenerDetalleDeduccionesMensuales,
    CargarCatalogosXml,
    ProcesarFechaOperacion,
}

impl Procedure {
    pub fn name(self) -> &'static str {
        match self {
            Self::ValidarUsuario => "SP_ValidarUsuario",
            Self::InsertarBitacora => "SP_InsertarBitacora",
            Self::ListarEmpleados => "SP_ListarEmpleados",
            Self::ListarPuestos => "SP_Puesto_Listar",
            Self::ObtenerEmpleado => "SP_Empleado_ObtenerPorId",
            Self::ListarEmpleadosConFiltro => "SP_ListarEmpleadosConFiltro",
            Self::InsertarEmpleado => "SP_InsertarEmpleado",
            Self::EditarEmpleado => "SP_EditarEmpleado",
            Self::EliminarEmpleado => "SP_EliminarEmpleado",
            Self::ConsultarPlanillasSemanales => "SP_ConsultarPlanillasSemanales",
            Self::ObtenerDetalleDeduccionesSemanales => "SP_ObtenerDetalleDeduccionesSemanales",
            Self::ObtenerDetalleAsistenciasSemanales => "SP_ObtenerDetalleAsistenciasSemanales",
            Self::ConsultarPlanillasMensuales => "SP_ConsultarPlanillasMensuales",
            Self::ObtenerDetalleDeduccionesMensuales => "SP_ObtenerDetalleDeduccionesMensuales",
            Self::CargarCatalogosXml => "SP_CargarCatalogosXML",
            Self::ProcesarFechaOperacion => "SP_ProcesarFechaOperacion",
        }
    }

    pub fn qualified_name(self) -> String {
        format!("dbo.{}", self.name())
    }
}
