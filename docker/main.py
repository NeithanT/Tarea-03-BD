from pathlib import Path
import sys

base_dir = Path(__file__).resolve().parent

stored_procedures_dir = base_dir / "stored_procedures"

source_files = [
	base_dir / "init_db.sql",
	*sorted(stored_procedures_dir.glob("*.sql")),
	base_dir / "load_xml.sql",
	base_dir / "triggers.sql",
]

combined_parts: list[str] = []

for sql_file in source_files:
	if not sql_file.exists():
		raise FileNotFoundError(f"No se encontro: {sql_file}")

	combined_parts.append(f"-- Archivo: {sql_file.name}\n")
	combined_parts.append(sql_file.read_text(encoding="utf-8"))
	combined_parts.append("\n\n")

(base_dir / "combined.sql").write_text("".join(combined_parts).rstrip() + "\n", encoding="utf-8")


print(f"Creado {base_dir / 'combined.sql'}")
