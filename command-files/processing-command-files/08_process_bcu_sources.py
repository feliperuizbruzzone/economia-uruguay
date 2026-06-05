"""Process BCU input sources into tidy CSV files."""

from __future__ import annotations

import csv
import re
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET


PROJECT_ROOT = Path(__file__).resolve().parents[2]
INPUT_DIR = PROJECT_ROOT / "data" / "input-data"
OUTPUT_DIR = PROJECT_ROOT / "data" / "analysis-data"

NS_XLSX = {"a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}

BCU_PIB_CURRENT_INPUT = INPUT_DIR / "bcu" / "PIB-corriente-industrias-2006-2019.xlsx"
BCU_PIB_CURRENT_OUTPUT = OUTPUT_DIR / "bcu_pib_corriente_industrias_2005_2019.csv"

D23_NOTE = (
    "En el valor agregado bruto del sector D.23-Fabricacion de coque, "
    "productos de la refinacion del petroleo y combustible nuclear; se incluye "
    "la comercializacion del combustible mayorista importado realizada por ANCAP."
)
MISSING_2019_DETAIL_NOTE = (
    "Debido a la priorizacion del cronograma del PLAE, para el ano 2019 no se "
    "dispone de estimaciones mas alla de los dos digitos de la CIIU Rev. 3."
)


def write_csv(path: Path, rows: list[dict[str, object]], columns: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def read_xlsx_sheet_rows(path: Path) -> list[list[str]]:
    with zipfile.ZipFile(path) as archive:
        shared_strings: list[str] = []
        if "xl/sharedStrings.xml" in archive.namelist():
            strings_root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
            shared_strings = [
                "".join(text.text or "" for text in item.findall(".//a:t", NS_XLSX))
                for item in strings_root.findall("a:si", NS_XLSX)
            ]
        root = ET.fromstring(archive.read("xl/worksheets/sheet1.xml"))

    rows: list[list[str]] = []
    for row in root.findall(".//a:row", NS_XLSX):
        values: dict[int, str] = {}
        for cell in row.findall("a:c", NS_XLSX):
            ref = cell.attrib["r"]
            column_letters = "".join(char for char in ref if char.isalpha())
            column = 0
            for char in column_letters:
                column = column * 26 + ord(char.upper()) - 64

            value_node = cell.find("a:v", NS_XLSX)
            if cell.attrib.get("t") == "s" and value_node is not None:
                value = shared_strings[int(value_node.text or "0")]
            elif cell.attrib.get("t") == "inlineStr":
                value = "".join(text.text or "" for text in cell.findall(".//a:t", NS_XLSX))
            elif value_node is not None and value_node.text is not None:
                value = value_node.text
            else:
                value = ""
            values[column] = value
        if values:
            rows.append([values.get(index, "") for index in range(1, max(values) + 1)])
    return rows


def normalize_space(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def to_number(value: str) -> float | None:
    clean = str(value).strip()
    if clean == "":
        return None
    try:
        return float(clean)
    except ValueError:
        return None


def parse_year_label(value: str) -> tuple[int, bool] | None:
    clean = str(value).strip()
    match = re.fullmatch(r"(\d{4})(\*)?", clean)
    if match is None:
        return None
    return int(match.group(1)), bool(match.group(2))


def find_year_header_row(rows: list[list[str]]) -> tuple[int, list[tuple[int, int, bool]]]:
    for row_index, row in enumerate(rows):
        year_columns: list[tuple[int, int, bool]] = []
        for column_index, value in enumerate(row):
            parsed = parse_year_label(value)
            if parsed is not None:
                year, preliminary = parsed
                year_columns.append((column_index, year, preliminary))
        if len(year_columns) >= 5:
            return row_index, year_columns
    raise ValueError("No year header row found in BCU workbook.")


def clean_source_code(value: str) -> str:
    return normalize_space(value).replace(" (1)", "")


def classify_code(source_code: str) -> str:
    code = clean_source_code(source_code)
    if code == "":
        return "agregado_sin_codigo"
    if re.fullmatch(r"[A-Z]", code):
        return "seccion"
    if re.fullmatch(r"[A-Z](?:\s*-\s*[A-Z])+", code) or re.fullmatch(r"[A-Z]\s+a\s+[A-Z]", code):
        return "agregado_secciones"
    if "-" in code or " a " in code or " y " in code:
        return "agregado_codigos"
    if ".TTTT" in code:
        return "total_seccion"
    if re.fullmatch(r"[A-Z]\.\d{2}", code):
        return "division"
    if re.fullmatch(r"[A-Z]\.\d{4}\.0", code):
        return "clase"
    return "grupo_bcu"


def source_section(source_code: str) -> str:
    code = clean_source_code(source_code)
    match = re.match(r"^([A-Z])", code)
    return match.group(1) if match else ""


def process_pib_current_industries() -> None:
    rows = read_xlsx_sheet_rows(BCU_PIB_CURRENT_INPUT)
    header_index, year_columns = find_year_header_row(rows)
    output_rows: list[dict[str, object]] = []

    for source_row in rows[header_index + 1 :]:
        code_raw = normalize_space(source_row[0]) if len(source_row) > 0 else ""
        description = normalize_space(source_row[1]) if len(source_row) > 1 else ""
        if description == "":
            continue

        values = [
            to_number(source_row[column_index]) if column_index < len(source_row) else None
            for column_index, _, _ in year_columns
        ]
        if all(value is None for value in values):
            continue

        code_normalized = clean_source_code(code_raw)
        for (column_index, year, preliminary), value in zip(year_columns, values):
            notes: list[str] = []
            if "(1)" in code_raw:
                notes.append(D23_NOTE)
            if year == 2019 and value is None:
                notes.append(MISSING_2019_DETAIL_NOTE)
            output_rows.append(
                {
                    "fuente": "bcu",
                    "archivo": BCU_PIB_CURRENT_INPUT.name,
                    "hoja": "Valores_C",
                    "tabla": "pib_corriente_industrias",
                    "codigo_fuente": code_raw,
                    "codigo_normalizado": code_normalized,
                    "nivel_codigo": classify_code(code_raw),
                    "seccion_ciiu_fuente": source_section(code_raw),
                    "descripcion": description,
                    "anno": year,
                    "valor": value,
                    # DECISION: BCU national accounts XLS values are kept in
                    # their published scale, interpreted as thousands of current
                    # pesos according to the usual BCU national-accounts table
                    # convention.
                    "unidad": "miles_de_pesos_corrientes",
                    "dato_preliminar": preliminary,
                    "nota_fuente": " | ".join(notes),
                }
            )

    write_csv(
        BCU_PIB_CURRENT_OUTPUT,
        output_rows,
        [
            "fuente",
            "archivo",
            "hoja",
            "tabla",
            "codigo_fuente",
            "codigo_normalizado",
            "nivel_codigo",
            "seccion_ciiu_fuente",
            "descripcion",
            "anno",
            "valor",
            "unidad",
            "dato_preliminar",
            "nota_fuente",
        ],
    )


def main() -> int:
    process_pib_current_industries()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
