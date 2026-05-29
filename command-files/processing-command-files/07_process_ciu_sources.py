"""Process CIU and Oyanthabal input sources into tidy CSV files."""

from __future__ import annotations

import csv
import re
import subprocess
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET


PROJECT_ROOT = Path(__file__).resolve().parents[2]
INPUT_DIR = PROJECT_ROOT / "data" / "input-data"
OUTPUT_DIR = PROJECT_ROOT / "data" / "analysis-data"

NS_XLSX = {"a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def pdf_text(path: Path, first_page: int, last_page: int | None = None) -> str:
    last_page = first_page if last_page is None else last_page
    result = subprocess.run(
        [
            "pdftotext",
            "-layout",
            "-f",
            str(first_page),
            "-l",
            str(last_page),
            str(path),
            "-",
        ],
        check=True,
        text=True,
        capture_output=True,
    )
    return result.stdout


def write_csv(path: Path, rows: list[dict[str, object]], columns: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def number_value(value: str) -> float | None:
    clean = value.strip().replace("*", "")
    if clean in {"", "-", "sd"}:
        return None
    is_percent = clean.endswith("%")
    clean = clean.rstrip("%")
    clean = clean.replace(".", "").replace(",", ".")
    try:
        parsed = float(clean)
    except ValueError:
        return None
    return parsed if is_percent else parsed


def xlsx_number_value(value: str) -> float | None:
    clean = value.strip()
    if clean == "":
        return None
    try:
        return float(clean)
    except ValueError:
        return None


def split_label_numbers(line: str) -> tuple[str, list[str]] | None:
    clean = re.sub(r"\(\s*\d{4}\s*=\s*100\s*\)\**", "", line)
    clean = re.sub(r"\(\s*1995\s*=\s*100\s*\)", "", clean)
    parts = [part.strip() for part in re.split(r"\s{2,}", clean.strip()) if part.strip()]
    if len(parts) > 1:
        first_value = None
        for index, part in enumerate(parts):
            if re.fullmatch(r"sd|-?\d[\d.]*,?\d*%?|-", part):
                first_value = index
                break
        if first_value is not None and first_value > 0:
            label = normalize_space(" ".join(parts[:first_value]))
            values = parts[first_value:]
            return label, values

    tokens = re.findall(r"sd|-?\d[\d.]*,?\d*%?|-", clean)
    if not tokens:
        return None
    first = clean.find(tokens[0])
    label = normalize_space(clean[:first])
    if not label:
        return None
    return label, tokens


def normalize_space(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def clean_capacidad_label(label: str) -> str:
    replacements = {
        "Ins uf.": "Insuf.",
        "Ins ufic ienc ia": "Insuficiencia",
        "Sufufic iente": "Suficiente",
        "Sufic iente": "Suficiente",
        "Razones es tac ionales": "Razones estacionales",
        "N o es": "No es",
        "Limitac iones c apac idad": "Limitaciones capacidad",
        "Dis p. pers onal c alific ado": "Disp. personal calificado",
        "Dis p. pers onal no c alific ado": "Disp. personal no calificado",
        "Avers ión ries go c omerc ial": "Aversión riesgo comercial",
        "Oferta Energétic a": "Oferta Energética",
        "Oferta energétic a": "Oferta energética",
        "Financ iamiento": "Financiamiento",
        "Problemas logís tic os": "Problemas logísticos",
        "Res tric c . medioambientales": "Restricc. medioambientales",
    }
    clean = label
    for old, new in replacements.items():
        clean = clean.replace(old, new)
    return normalize_space(clean)


def parse_year_value_table(
    text: str,
    years: list[int],
    table_name: str,
    source_file: str,
    page: str,
    stop_patterns: tuple[str, ...] = ("Fuente:",),
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    previous_variable = ""
    previous_label = ""
    for raw_line in text.splitlines():
        line = normalize_space(raw_line)
        if not line:
            continue
        if any(pattern in line for pattern in stop_patterns):
            break
        parsed = split_label_numbers(raw_line)
        if parsed is None:
            continue
        label, tokens = parsed
        if label in {"MONITOREO INDUSTRIAL", "INDUSTRIAL"}:
            continue
        if len(tokens) < len(years):
            continue
        variable = canonical_variable(label)
        variable_label = label
        if variable == "variacion_anual" and previous_variable:
            variable = f"{previous_variable}_variacion_anual"
            variable_label = f"{previous_label} - Variación anual"
        else:
            previous_variable = variable
            previous_label = label
        values = tokens[: len(years)]
        for year, value in zip(years, values):
            rows.append(
                {
                    "fuente": "ciu",
                    "archivo": source_file,
                    "pagina": page,
                    "tabla": table_name,
                    "variable": variable,
                    "variable_etiqueta": variable_label,
                    "anno": year,
                    "valor": number_value(value),
                    "unidad": "porcentaje" if value.endswith("%") else "indice_o_nivel",
                }
            )
    return rows


def canonical_variable(label: str) -> str:
    replacements = {
        "á": "a",
        "é": "e",
        "í": "i",
        "ó": "o",
        "ú": "u",
        "ñ": "n",
        "ü": "u",
    }
    clean = label.lower()
    for old, new in replacements.items():
        clean = clean.replace(old, new)
    clean = clean.replace("$", "pesos").replace("%", "pct")
    clean = re.sub(r"[^a-z0-9]+", "_", clean).strip("_")
    return clean


def parse_estructura_costos() -> None:
    path = INPUT_DIR / "ciu-indicadores-economicos" / "8_Estructura-de-Costos-y-Ratios-Indicadores-Octubre-2025.pdf"
    text = pdf_text(path, 4)
    sectors = [
        ("15_16", "Alimentos, Bebidas y Tabaco"),
        ("17_18_19", "Textiles, Vestimenta y Cuero"),
        ("20", "Madera y productos de madera"),
        ("21_22", "Papel e imprenta"),
        ("23", "Prod. derivados del petroleo"),
        ("24_25", "Prod. quimicos, caucho y plastico"),
        ("26_27", "Minerales no metalicos y metalicas basicas"),
        ("28_29_30", "Metalicos, Maq. y Equipos"),
        ("31_32_33", "Maq. y aparatos electricos"),
        ("34_35", "Vehiculos y equipo de transporte"),
        ("36", "Muebles y Otras Industrias"),
    ]
    rows: list[dict[str, object]] = []
    current_group = ""
    for raw_line in text.splitlines():
        line = normalize_space(raw_line)
        if line.startswith("1. Costos de Producción"):
            current_group = "costos_produccion"
        elif line.startswith("2. Gastos Adm"):
            current_group = "gastos_administracion_ventas_diversos"
        if not current_group:
            continue
        parsed = split_label_numbers(raw_line)
        if parsed is None:
            continue
        label, values = parsed
        if len(values) < len(sectors):
            continue
        for (sector_codigo, sector), value in zip(sectors, values[: len(sectors)]):
            rows.append(
                {
                    "fuente": "ciu",
                    "archivo": path.name,
                    "pagina": 4,
                    "tabla": "estructura_costos_sectores_2005",
                    "grupo_costo": current_group,
                    "componente": canonical_variable(label),
                    "componente_etiqueta": label,
                    "sector_codigo": sector_codigo,
                    "sector": sector,
                    "anno": 2005,
                    "valor": number_value(value),
                    "unidad": "porcentaje",
                }
            )
    write_csv(
        OUTPUT_DIR / "ciu_indicadores_estructura_costos_2005.csv",
        rows,
        [
            "fuente",
            "archivo",
            "pagina",
            "tabla",
            "grupo_costo",
            "componente",
            "componente_etiqueta",
            "sector_codigo",
            "sector",
            "anno",
            "valor",
            "unidad",
        ],
    )


def parse_empleo() -> None:
    path = INPUT_DIR / "ciu-indicadores-economicos" / "4_Empleo-y-salarios-Indicadores-Oct-2025.pdf"
    rows = parse_year_value_table(
        pdf_text(path, 2),
        [2019, 2020, 2021, 2022, 2023, 2024, 2025],
        "empleo",
        path.name,
        "2",
    )
    write_csv(
        OUTPUT_DIR / "ciu_indicadores_empleo.csv",
        rows,
        ["fuente", "archivo", "pagina", "tabla", "variable", "variable_etiqueta", "anno", "valor", "unidad"],
    )


def parse_indices_salarios() -> None:
    path = INPUT_DIR / "ciu-indicadores-economicos" / "4_Empleo-y-salarios-Indicadores-Oct-2025.pdf"
    text = pdf_text(path, 3)
    rows: list[dict[str, object]] = []
    section = ""
    value_years = [2019, 2020, 2021, 2022, 2023, 2024, 2025]
    variation_years = [2020, 2021, 2022, 2023, 2024, 2025]
    for raw_line in text.splitlines():
        line = normalize_space(raw_line)
        if line == "REALES":
            section = "reales"
            continue
        if line == "NOMINALES":
            section = "nominales"
            continue
        if not section or "REMUNERACION NOMINAL" in line:
            continue
        parsed = split_label_numbers(line)
        if parsed is None:
            continue
        label, tokens = parsed
        if len(tokens) < 13:
            continue
        for year, value in zip(value_years, tokens[:7]):
            rows.append(
                {
                    "fuente": "ciu",
                    "archivo": path.name,
                    "pagina": 3,
                    "tabla": "indices_salarios",
                    "tipo_indice": section,
                    "sector": label,
                    "anno": year,
                    "medida": "indice",
                    "valor": number_value(value),
                    "unidad": "indice_1995_100",
                }
            )
        for year, value in zip(variation_years, tokens[7:13]):
            rows.append(
                {
                    "fuente": "ciu",
                    "archivo": path.name,
                    "pagina": 3,
                    "tabla": "indices_salarios",
                    "tipo_indice": section,
                    "sector": label,
                    "anno": year,
                    "medida": "variacion_anual",
                    "valor": number_value(value),
                    "unidad": "porcentaje",
                }
            )
    write_csv(
        OUTPUT_DIR / "ciu_indicadores_indices_salarios.csv",
        rows,
        ["fuente", "archivo", "pagina", "tabla", "tipo_indice", "sector", "anno", "medida", "valor", "unidad"],
    )


def parse_produccion_ivf_rama() -> None:
    path = INPUT_DIR / "ciu-indicadores-economicos" / "6_Evolucion-Sectorial-Indicadores-Oct-2025.pdf"
    text = pdf_text(path, 2, 3)
    years = list(range(2014, 2025)) + [2025]
    rows: list[dict[str, object]] = []
    pending_code: str | None = None
    pending_desc_parts: list[str] = []
    for raw_line in text.splitlines():
        line = normalize_space(raw_line)
        if not line or line.startswith(("MONITOREO", "INDUSTRIAL", "PRODUCCIÓN", "RAMA", "Fuente:")):
            continue
        if re.fullmatch(r"[0-9A-Z]{4}", line):
            pending_code = line
            pending_desc_parts = []
            continue
        match = re.match(r"^([0-9A-Z]{4})\s+(.+?)\s+((?:-|\d+)(?:\s+(?:-|\d+)){10,12})\s*(?:07)?$", line)
        if match:
            code, desc, value_text = match.groups()
        elif pending_code:
            values = re.findall(r"-|\d+", line)
            if len(values) >= 12:
                code = pending_code
                desc = normalize_space(" ".join(pending_desc_parts))
                value_text = " ".join(values[-12:])
                pending_code = None
                pending_desc_parts = []
            else:
                pending_desc_parts.append(line)
                continue
        else:
            continue
        values = re.findall(r"-|\d+", value_text)
        if len(values) < 12:
            continue
        for year, value in zip(years, values[:12]):
            rows.append(
                {
                    "fuente": "ciu",
                    "archivo": path.name,
                    "pagina": "2-3",
                    "tabla": "produccion_industrial_ivf_rama",
                    "rama_codigo": code,
                    "rama_descripcion": desc,
                    "anno": year,
                    "periodo": "anio" if year < 2025 else "ene_jul",
                    "valor": number_value(value),
                    "unidad": "indice_2018_100",
                }
            )
    write_csv(
        OUTPUT_DIR / "ciu_indicadores_produccion_industrial_ivf_rama.csv",
        rows,
        ["fuente", "archivo", "pagina", "tabla", "rama_codigo", "rama_descripcion", "anno", "periodo", "valor", "unidad"],
    )


def parse_inversion() -> None:
    path = INPUT_DIR / "ciu-indicadores-economicos" / "Inversion-y-capacidad-instalada-Indicadores-Octubre-2022.pdf"
    rows = parse_year_value_table(
        pdf_text(path, 2),
        [2018, 2019, 2020, 2021, 2022, 2023],
        "inversion",
        path.name,
        "2",
        stop_patterns=("INVERSIÓN PRIVADA",),
    )
    write_csv(
        OUTPUT_DIR / "ciu_indicadores_inversion.csv",
        rows,
        ["fuente", "archivo", "pagina", "tabla", "variable", "variable_etiqueta", "anno", "valor", "unidad"],
    )


def parse_imeq_fbkf() -> None:
    path = INPUT_DIR / "ciu-indicadores-economicos" / "Inversion-y-capacidad-instalada-Indicadores-Octubre-2022.pdf"
    rows = parse_year_value_table(
        pdf_text(path, 3),
        [2018, 2019, 2020, 2021, 2022, 2023],
        "imeq_fbkf",
        path.name,
        "3",
        stop_patterns=("Índices trimestrales",),
    )
    write_csv(
        OUTPUT_DIR / "ciu_indicadores_imeq_fbkf.csv",
        rows,
        ["fuente", "archivo", "pagina", "tabla", "variable", "variable_etiqueta", "anno", "valor", "unidad"],
    )


def parse_quarter(value: str) -> tuple[int, int]:
    month_map = {
        "mar": 1,
        "mar.": 1,
        "jun": 2,
        "jun.": 2,
        "set": 3,
        "sep": 3,
        "sep.": 3,
        "dic": 4,
        "dic.": 4,
    }
    month, year = value.replace("*", "").split("-")
    return int(year) + 2000, month_map[month.lower()]


def parse_quarter_rows(text: str, expected_values: int, row_pattern: str) -> list[tuple[str, list[str]]]:
    rows: list[tuple[str, list[str]]] = []
    for raw_line in text.splitlines():
        line = normalize_space(raw_line)
        match = re.match(row_pattern, line, flags=re.IGNORECASE)
        if not match:
            continue
        quarter = match.group(1)
        values = re.findall(r"-?\d[\d.]*,?\d*", match.group(2))
        if len(values) >= expected_values:
            rows.append((quarter, values[:expected_values]))
    return rows


def parse_imeq_maquinaria_equipos() -> None:
    files = [
        ("Inversion-en-Maquinaria-y-Equipos-3o-trimestre-2020.pdf", 8),
        ("IMEQN69-1Trim2026.pdf", 10),
    ]
    variables = [
        ("imeq_total_economia_sin_celulosa", "Economía sin celulosa"),
        ("imeq_sector_privado_sin_celulosa", "Sector privado sin celulosa"),
        ("imeq_sector_privado_sin_zf_ni_celulosa", "Sector privado sin ZF ni celulosa"),
        ("imeq_industria_sin_refineria_ni_zf", "Industria sin refinería ni ZF"),
    ]
    rows: list[dict[str, object]] = []
    for filename, page in files:
        path = INPUT_DIR / "ciu-inversion-maquinaria-equipos" / filename
        text = pdf_text(path, page)
        for quarter, values in parse_quarter_rows(text, 4, r"^([A-Za-z]{3}-\d{2}\*?)\s+(.+)$"):
            year, trimestre = parse_quarter(quarter)
            for (variable, label), value in zip(variables, values):
                rows.append(
                    {
                        "fuente": "ciu",
                        "archivo": filename,
                        "pagina": page,
                        "tabla": "imeq",
                        "anno": year,
                        "trimestre": trimestre,
                        "variable": variable,
                        "variable_etiqueta": label,
                        "valor": number_value(value),
                        "unidad": "indice_2002_100",
                    }
                )
    dedup: dict[tuple[int, int, str], dict[str, object]] = {}
    for row in rows:
        dedup[(int(row["anno"]), int(row["trimestre"]), str(row["variable"]))] = row
    write_csv(
        OUTPUT_DIR / "ciu_inversion_maquinaria_equipos_imeq.csv",
        sorted(dedup.values(), key=lambda row: (row["anno"], row["trimestre"], row["variable"])),
        ["fuente", "archivo", "pagina", "tabla", "anno", "trimestre", "variable", "variable_etiqueta", "valor", "unidad"],
    )


def parse_stock_capital() -> None:
    files = [("stock-de-capital-2017.pdf", 4), ("Stock-de-capital_15.pdf", 7)]
    rows: list[dict[str, object]] = []
    for filename, page in files:
        path = INPUT_DIR / "ciu-stock-capital" / filename
        text = pdf_text(path, page)
        for quarter, values in parse_quarter_rows(text, 1, r"^([A-Za-z]{3}\.?\-\d{2})\s+(.+)$"):
            year, trimestre = parse_quarter(quarter)
            rows.append(
                {
                    "fuente": "ciu",
                    "archivo": filename,
                    "pagina": page,
                    "tabla": "stock_capital_fijo_maquinaria_equipos_industria",
                    "anno": year,
                    "trimestre": trimestre,
                    "variable": "stock_capital_fijo_maquinaria_equipos_industria",
                    "valor": number_value(values[0]),
                    "unidad": "indice_dic_2008_100",
                }
            )
    dedup: dict[tuple[int, int], dict[str, object]] = {}
    for row in rows:
        dedup[(int(row["anno"]), int(row["trimestre"]))] = row
    write_csv(
        OUTPUT_DIR / "ciu_stock_capital.csv",
        sorted(dedup.values(), key=lambda row: (row["anno"], row["trimestre"])),
        ["fuente", "archivo", "pagina", "tabla", "anno", "trimestre", "variable", "valor", "unidad"],
    )


def parse_capacidad_instalada() -> None:
    files = [
        ("utilizacion-de-la-capacidad-instalada-1o-trimestre-2018.pdf", 4, list(range(2007, 2019))),
        ("utilizacion-de-la-capacidad-instalada-1o-trimestre-2021.pdf", 4, list(range(2013, 2022))),
        ("utilizacion-de-la-capacidad-instalada-1o-trimestre-2025.pdf", 4, list(range(2022, 2026))),
    ]
    rows: list[dict[str, object]] = []
    for filename, page, years in files:
        path = INPUT_DIR / "ciu-capacidad-instalada" / filename
        text = pdf_text(path, page)
        for raw_line in text.splitlines():
            parsed = split_label_numbers(raw_line)
            if parsed is None:
                continue
            label, values = parsed
            if len(values) < len(years) or label.upper().startswith("MOTIV"):
                continue
            clean_label = clean_capacidad_label(label)
            for year, value in zip(years, values[: len(years)]):
                rows.append(
                    {
                        "fuente": "ciu",
                        "archivo": filename,
                        "pagina": page,
                        "tabla": "motivos_producir_debajo_capacidad_plena",
                        "anno": year,
                        "trimestre": 1,
                        "motivo": canonical_variable(clean_label),
                        "motivo_etiqueta": clean_label,
                        "valor": number_value(value),
                        "unidad": "porcentaje_respuestas",
                    }
                )
    dedup: dict[tuple[int, str], dict[str, object]] = {}
    for row in rows:
        dedup[(int(row["anno"]), str(row["motivo"]))] = row
    write_csv(
        OUTPUT_DIR / "ciu_capacidad_instalada_motivos.csv",
        sorted(dedup.values(), key=lambda row: (row["anno"], row["motivo"])),
        ["fuente", "archivo", "pagina", "tabla", "anno", "trimestre", "motivo", "motivo_etiqueta", "valor", "unidad"],
    )


def parse_encuesta_industrial() -> None:
    input_dir = INPUT_DIR / "ciu-encuesta-industrial"
    rows: list[dict[str, object]] = []

    personal_path = input_dir / "Personal-EMI-nueva-trimestral.xlsx"
    for values in read_xlsx_sheet_rows(personal_path):
        if not values:
            continue
        parsed_quarter = parse_spanish_quarter_label(values[0])
        if parsed_quarter is None or len(values) < 2 or values[1] == "":
            continue
        year, trimestre = parsed_quarter
        rows.append(
            {
                "fuente": "ciu",
                "archivo": personal_path.name,
                "hoja": "PERSONAL",
                "tabla": "encuesta_industrial_trimestral",
                "anno": year,
                "trimestre": trimestre,
                "variable": "ipoi",
                "variable_etiqueta": "Índice de personal ocupado en la industria",
                "sector_destino": "",
                "sector_destino_etiqueta": "",
                "valor": xlsx_number_value(values[1]),
                "unidad": "indice_2021_100",
            }
        )

    ivfvi_path = input_dir / "IVFV-pordestino-trimestral.xlsx"
    destination_columns = [
        (1, "industria", "Industria", "ivfvi_ind"),
        (2, "exportaciones", "Exportaciones", "ivfvi_exp"),
        (3, "mercado_interno", "Mercado interno", "ivfvi_mi"),
    ]
    sector_order = {sector: order for order, (_, sector, _, _) in enumerate(destination_columns)}
    for values in read_xlsx_sheet_rows(ivfvi_path):
        if not values:
            continue
        parsed_quarter = parse_spanish_quarter_label(values[0])
        if parsed_quarter is None:
            continue
        year, trimestre = parsed_quarter
        for index, sector_destino, sector_destino_label, variable in destination_columns:
            if index >= len(values) or values[index] == "":
                continue
            rows.append(
                {
                    "fuente": "ciu",
                    "archivo": ivfvi_path.name,
                    "hoja": "IVFV_DESTINO",
                    "tabla": "encuesta_industrial_trimestral",
                    "anno": year,
                    "trimestre": trimestre,
                    "variable": variable,
                    "variable_etiqueta": "Índice de volumen físico de las ventas industriales",
                    "sector_destino": sector_destino,
                    "sector_destino_etiqueta": sector_destino_label,
                    "valor": xlsx_number_value(values[index]),
                    "unidad": "indice_2021_100",
                }
            )

    write_csv(
        OUTPUT_DIR / "ciu_encuesta_industrial_ipoi_ivfvi.csv",
        sorted(
            rows,
            key=lambda row: (
                row["anno"],
                row["trimestre"],
                row["variable"],
                sector_order.get(str(row["sector_destino"]), -1),
            ),
        ),
        [
            "fuente",
            "archivo",
            "hoja",
            "tabla",
            "anno",
            "trimestre",
            "variable",
            "variable_etiqueta",
            "sector_destino",
            "sector_destino_etiqueta",
            "valor",
            "unidad",
        ],
    )


def parse_spanish_quarter_label(value: str) -> tuple[int, int] | None:
    match = re.match(r"^\s*([1-4])\s*º?\s*trim\s+(\d{4})\s*$", value, flags=re.IGNORECASE)
    if not match:
        return None
    return int(match.group(2)), int(match.group(1))


def read_xlsx_sheet_rows(path: Path) -> list[list[str]]:
    with zipfile.ZipFile(path) as archive:
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
            if value_node is None or value_node.text is None:
                value = ""
            elif cell.attrib.get("t") == "s":
                value = shared_strings[int(value_node.text)]
            else:
                value = value_node.text
            values[column] = value
        if values:
            rows.append([values.get(index, "") for index in range(1, max(values) + 1)])
    return rows


def parse_oyanthabal() -> None:
    path = INPUT_DIR / "oyanthabal" / "Índices de Precios.xlsx"
    sheet_rows = read_xlsx_sheet_rows(path)
    header = sheet_rows[0]
    unit_row = sheet_rows[2]
    source_row = sheet_rows[3]
    variable_names = {
        "GDP": "gdp_current",
        "GDP $Uy2005 (right axis)": "gdp_2005",
        "GDP Price index (base 2005)": "gdp_price_index_base_2005",
        "IPC": "ipc_index_1983_1989",
    }
    rows: list[dict[str, object]] = []
    for values in sheet_rows[4:]:
        if not values or not values[0]:
            continue
        year = int(float(values[0]))
        for index, name in enumerate(header[1:], start=1):
            if not name or index >= len(values) or values[index] == "":
                continue
            rows.append(
                {
                    "fuente": "oyanthabal",
                    "archivo": path.name,
                    "hoja": "IPI PBI e IPC",
                    "anno": year,
                    "variable": variable_names.get(name, canonical_variable(name)),
                    "variable_etiqueta": name,
                    "valor": xlsx_number_value(values[index]),
                    "unidad": unit_row[index] if index < len(unit_row) else "",
                    "fuente_original": source_row[index] if index < len(source_row) else "",
                }
            )
    write_csv(
        OUTPUT_DIR / "oyanthabal_indices_precios.csv",
        rows,
        ["fuente", "archivo", "hoja", "anno", "variable", "variable_etiqueta", "valor", "unidad", "fuente_original"],
    )


def main() -> int:
    parse_estructura_costos()
    parse_empleo()
    parse_indices_salarios()
    parse_produccion_ivf_rama()
    parse_inversion()
    parse_imeq_fbkf()
    parse_capacidad_instalada()
    parse_imeq_maquinaria_equipos()
    parse_stock_capital()
    parse_encuesta_industrial()
    parse_oyanthabal()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
