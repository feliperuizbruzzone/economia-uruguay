"""Compare EAAE and CIU industrial capital stock series.

Run from the project root:
  python3 command-files/processing-command-files/17_compare_eaae_ciu_stock_capital.py
"""

from __future__ import annotations

import csv
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
from collections import defaultdict
from pathlib import Path

import xlrd


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CONFIG_DIR = PROJECT_ROOT / "command-files" / "config"
sys.path.insert(0, str(CONFIG_DIR))

from eaae_config import (  # noqa: E402
    DATA_INPUT_EAAE_DIR,
    EAAE_CONFIG,
    EAAE_STOCK_CONFIG,
    PANEL_YEARS,
)


CIU_PATH = PROJECT_ROOT / "data" / "analysis-data" / "ciu_stock_capital_industria_1988_2025.csv"
EXCHANGE_PATH = (
    PROJECT_ROOT
    / "data"
    / "analysis-data"
    / "20260805_ine_uy_tipo_cambio_dolar_diciembre.csv"
)
INTEGRATED_PANEL_PATH = (
    PROJECT_ROOT
    / "data"
    / "analysis-data"
    / "20260727_panel_eeae_bcu_total_industria_subrama.csv"
)
OUTPUT_PATH = (
    PROJECT_ROOT
    / "data"
    / "analysis-data"
    / "20260805_comparacion_stock_capital_eaae_ciu.csv"
)

OUTPUT_COLUMNS = [
    "anno",
    "fecha_tipo_cambio",
    "dolar_usa_compra_dic_ine",
    "dolar_usa_venta_dic_ine",
    "stock_ciu_mill_usd_corriente",
    "stock_ciu_indice_dic_2008_100",
    "stock_eaae_total_activos_industria_uyu_corriente",
    "stock_eaae_construcciones_industria_uyu_corriente",
    "stock_eaae_maquinaria_equipos_industria_uyu_corriente",
    "stock_eaae_maquinaria_equipos_refinacion_uyu_corriente",
    "stock_eaae_maquinaria_equipos_sin_refinacion_uyu_corriente",
    "stock_eaae_maquinaria_equipos_sin_refinacion_mill_usd_corriente",
    "ratio_eaae_ciu_stock_usd_corriente_pct",
    "deflactor_bcu_proxy_sin_refinacion_2005",
    "stock_eaae_maquinaria_equipos_sin_refinacion_mill_usd_constante_2005_proxy",
    "stock_eaae_maquinaria_equipos_sin_refinacion_indice_2008_100",
    "ratio_indice_eaae_ciu_2008_pct",
    "stock_total_panel_industria_uyu_corriente",
    "diferencia_stock_total_extraido_panel_uyu",
    "metodo_eaae_stock",
    "fuente_tipo_cambio",
    "fuente_deflactor",
    "fuente_ciu",
    "nota_metodologica",
    "archivo_eaae_stock",
]

# DECISION: for the 2001 sub-branch refinery subtraction, use the two-digit
# C15 source so the industry total and refinery component come from the same
# universe. This differs from the letter-level stock used in the main panel.
YEAR_2001_STOCK_2DIG = {
    "member": "2 Digitos/EAE_cu15afe2_01.xls",
    "section_col": 0,
    "division_col": 1,
    "stock_capital_col": 3,
    "value_scale": 1000,
}


def to_number(value: object) -> float | None:
    if value is None:
        return None
    if isinstance(value, float) or isinstance(value, int):
        if isinstance(value, float) and math.isnan(value):
            return None
        return float(value)
    text = str(value).strip()
    if text in {"", "..", "NA", "N/A"}:
        return None
    text = text.replace("\xa0", "")
    if re.search(r",\d+$", text):
        text = text.replace(".", "").replace(",", ".")
    else:
        text = text.replace(",", "")
    try:
        return float(text)
    except ValueError:
        return None


def fmt(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, float):
        if math.isnan(value) or math.isinf(value):
            return ""
        return f"{value:.6f}".rstrip("0").rstrip(".")
    return str(value)


def normalize_code(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    text = str(value).strip()
    if re.fullmatch(r"\d+\.0", text):
        text = text[:-2]
    text = re.sub(r"\s+", " ", text)
    return text


def ciiu_version_for_year(year: int) -> str:
    return "Rev.3" if year <= 2007 else "Rev.4"


def expected_source_section(year: int) -> str:
    return "D" if ciiu_version_for_year(year) == "Rev.3" else "C"


def refinery_code(year: int) -> str:
    return "23" if ciiu_version_for_year(year) == "Rev.3" else "19"


def component_codes(code: str) -> list[str]:
    normalized = normalize_code(code)
    if not normalized:
        return []
    return re.findall(r"\d{2,4}", normalized)


def base_2dig_codes(code: str, year: int) -> list[str]:
    version = ciiu_version_for_year(year)
    bases: list[str] = []
    for component in component_codes(code):
        base = component[:2] if version == "Rev.3" else component
        if base not in bases:
            bases.append(base)
    return bases


def candidate_extractors() -> list[tuple[str, list[str]]]:
    extractors: list[tuple[str, list[str]]] = []
    unrar = (
        os.environ.get("UNRAR_BIN")
        or shutil.which("unrar")
        or shutil.which("unrar-nonfree")
    )
    if unrar:
        extractors.append(("unrar", [unrar]))

    bsdtar = shutil.which("bsdtar")
    if bsdtar:
        extractors.append(("bsdtar", [bsdtar]))

    flatpak = shutil.which("flatpak")
    if flatpak:
        extractors.append(
            (
                "flatpak-bsdtar",
                [
                    flatpak,
                    "run",
                    f"--filesystem={PROJECT_ROOT}",
                    "--filesystem=/tmp",
                    "--command=bsdtar",
                    "org.freedesktop.Platform//25.08",
                ],
            )
        )

    seven_zip = shutil.which("7z")
    if seven_zip:
        extractors.append(("7z", [seven_zip]))

    return extractors


def run_extractor(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=True, text=True, capture_output=True)


def list_members(rar_path: Path, extractors: list[tuple[str, list[str]]]) -> list[str]:
    errors: list[str] = []
    for kind, prefix in extractors:
        try:
            if kind == "unrar":
                result = run_extractor([*prefix, "lb", str(rar_path)])
            elif kind == "7z":
                result = run_extractor([*prefix, "l", "-slt", str(rar_path)])
            else:
                result = run_extractor([*prefix, "-tf", str(rar_path)])
            if kind == "7z":
                members = [
                    line.split("=", 1)[1].strip()
                    for line in result.stdout.splitlines()
                    if line.startswith("Path = ")
                    and line.split("=", 1)[1].strip() != str(rar_path)
                ]
            else:
                members = [line.strip() for line in result.stdout.splitlines() if line.strip()]
            if members:
                return members
        except (subprocess.CalledProcessError, FileNotFoundError) as exc:
            errors.append(f"{kind}: {exc}")
    raise RuntimeError(
        "No RAR extractor could list archive members. Tried: " + "; ".join(errors)
    )


def extract_member(
    rar_path: Path,
    member: str,
    output_dir: Path,
    extractors: list[tuple[str, list[str]]],
) -> Path:
    errors: list[str] = []
    for kind, prefix in extractors:
        try:
            if kind == "unrar":
                run_extractor([*prefix, "e", "-y", str(rar_path), member, str(output_dir) + "/"])
                extracted = output_dir / Path(member).name
            elif kind == "7z":
                run_extractor([*prefix, "x", "-y", f"-o{output_dir}", str(rar_path), member])
                extracted = output_dir / member
            else:
                run_extractor([*prefix, "-xf", str(rar_path), "-C", str(output_dir), member])
                extracted = output_dir / member
            if extracted.exists() and extracted.stat().st_size > 0:
                return extracted
            fallback = output_dir / Path(member).name
            if fallback.exists() and fallback.stat().st_size > 0:
                return fallback
            errors.append(f"{kind}: extracted file missing or empty for {member}")
        except (subprocess.CalledProcessError, FileNotFoundError) as exc:
            errors.append(f"{kind}: {exc}")
    raise RuntimeError(
        f"Could not extract {member!r} from {rar_path.name}. Tried: "
        + "; ".join(errors)
    )


def find_member(year: int, members: list[str], config: dict[str, object]) -> str | None:
    exact = config.get("member")
    if exact is not None:
        if str(exact) not in members:
            raise RuntimeError(f"Year {year}: missing expected member {exact}")
        return str(exact)

    pattern_value = config.get("file_pattern")
    if pattern_value is None:
        return None
    pattern = re.compile(str(pattern_value))
    subfolder = config.get("subfolder")
    matches: list[str] = []
    for member in members:
        if not member.lower().endswith(".xls"):
            continue
        if subfolder and not member.startswith(f"{subfolder}/"):
            continue
        if pattern.fullmatch(Path(member).name):
            matches.append(member)
    if len(matches) != 1:
        raise RuntimeError(
            f"Year {year}: expected one member matching {pattern_value!r}, found {matches}"
        )
    return matches[0]


def read_asset_rows(year: int, xls_path: Path, config: dict[str, object]) -> list[dict[str, object]]:
    workbook = xlrd.open_workbook(str(xls_path))
    sheet = workbook.sheet_by_index(0)
    section_col = int(config["section_col"])
    division_col = config.get("division_col")
    total_col = int(config["stock_capital_col"])
    construcciones_col = total_col + 1
    maquinaria_col = total_col + 2
    scale = float(config.get("value_scale", 1))

    def cell(row_idx: int, col_idx: int | None) -> object:
        if col_idx is None or col_idx >= sheet.ncols:
            return ""
        return sheet.cell_value(row_idx, col_idx)

    rows: list[dict[str, object]] = []
    current: dict[str, object] | None = None

    def values_for_row(row_idx: int) -> dict[str, float | None]:
        values = {
            "stock_total": to_number(cell(row_idx, total_col)),
            "construcciones": to_number(cell(row_idx, construcciones_col)),
            "maquinaria_equipos": to_number(cell(row_idx, maquinaria_col)),
        }
        return {
            key: value * scale if value is not None else None
            for key, value in values.items()
        }

    def flush_current() -> None:
        nonlocal current
        if current is not None:
            rows.append(current)
        current = None

    for row_idx in range(sheet.nrows):
        section = str(cell(row_idx, section_col)).strip()
        division = normalize_code(cell(row_idx, int(division_col) if division_col is not None else None))
        values = values_for_row(row_idx)
        has_any_value = any(value is not None for value in values.values())

        if re.fullmatch(r"[A-Z]", section):
            flush_current()
            current = {
                "anno": year,
                "seccion_fuente": section,
                "division_publicada": division,
                **values,
            }
            continue

        if current is None:
            continue

        if division and not current.get("division_publicada"):
            current["division_publicada"] = division
        if has_any_value:
            for key, value in values.items():
                if value is not None:
                    current[key] = value

    flush_current()
    return rows


def extract_eaae_assets_year(
    year: int,
    extractors: list[tuple[str, list[str]]],
) -> dict[str, object]:
    if year in {2002, 2011}:
        return {
            "anno": year,
            "metodo_eaae_stock": "sin_cuadro_activos_fijos_por_tipo",
            "nota_metodologica": "EAAE no publica cuadro de stock de activos fijos por tipo para este anio; no se imputa maquinaria en esta comparacion.",
        }

    source_config = EAAE_CONFIG[year]
    rar_path = PROJECT_ROOT / DATA_INPUT_EAAE_DIR / source_config["rar_name"]
    if year == 2001:
        config = dict(YEAR_2001_STOCK_2DIG)
    else:
        config = dict(EAAE_STOCK_CONFIG[year])

    if not rar_path.exists():
        raise FileNotFoundError(f"Year {year}: missing RAR {rar_path}")

    members = list_members(rar_path, extractors)
    member = find_member(year, members, config)
    if member is None:
        return {
            "anno": year,
            "metodo_eaae_stock": "sin_cuadro_activos_fijos_por_tipo",
            "nota_metodologica": "No se encontro cuadro de activos fijos por tipo.",
        }

    with tempfile.TemporaryDirectory(prefix=f"eaae-stock-assets-{year}-") as tmp:
        xls_path = extract_member(rar_path, member, Path(tmp), extractors)
        rows = read_asset_rows(year, xls_path, config)

    section = expected_source_section(year)
    relevant = [row for row in rows if row.get("seccion_fuente") == section]
    if not relevant:
        raise RuntimeError(f"Year {year}: no industry stock rows found in {member}")

    total_candidates = [
        row for row in relevant if not base_2dig_codes(str(row.get("division_publicada") or ""), year)
    ]
    total_method = "fila_total_industria"
    if total_candidates:
        industry_total = total_candidates[0]
    else:
        # DECISION: some stock tables, notably 2006, publish detailed industrial
        # activity rows but no manufacturing total row. In that case reconstruct
        # the industry total as the sum of published industrial rows.
        additive_rows = [
            row
            for row in relevant
            if base_2dig_codes(str(row.get("division_publicada") or ""), year)
        ]
        if not additive_rows:
            raise RuntimeError(f"Year {year}: no industry total or additive rows found in {member}")
        industry_total = {
            "stock_total": sum(
                float(row.get("stock_total") or 0) for row in additive_rows
            ),
            "construcciones": sum(
                float(row.get("construcciones") or 0) for row in additive_rows
            ),
            "maquinaria_equipos": sum(
                float(row.get("maquinaria_equipos") or 0) for row in additive_rows
            ),
        }
        total_method = "suma_filas_industriales_publicadas"

    refinery = None
    ref_code = refinery_code(year)
    for row in relevant:
        bases = base_2dig_codes(str(row.get("division_publicada") or ""), year)
        if bases == [ref_code] or ref_code in bases:
            refinery = row
            break

    maq_industria = industry_total.get("maquinaria_equipos")
    maq_ref = refinery.get("maquinaria_equipos") if refinery is not None else None
    maq_sin_ref = (
        float(maq_industria) - float(maq_ref)
        if maq_industria is not None and maq_ref is not None
        else None
    )

    note = (
        "Se usa columna directa de maquinaria y equipos; excluye construcciones, otros e intangibles."
        f" Total industrial: {total_method}."
    )
    if year == 2001:
        note += " Para 2001 se usa C15 a dos digitos para mantener total industrial y refineria en el mismo universo."
    if refinery is None:
        note += " No se encontro fila de refineria para restar."

    return {
        "anno": year,
        "stock_eaae_total_activos_industria_uyu_corriente": industry_total.get("stock_total"),
        "stock_eaae_construcciones_industria_uyu_corriente": industry_total.get("construcciones"),
        "stock_eaae_maquinaria_equipos_industria_uyu_corriente": maq_industria,
        "stock_eaae_maquinaria_equipos_refinacion_uyu_corriente": maq_ref,
        "stock_eaae_maquinaria_equipos_sin_refinacion_uyu_corriente": maq_sin_ref,
        "metodo_eaae_stock": "extraccion_directa_columna_maquinaria_equipos_eaae",
        "nota_metodologica": note,
        "archivo_eaae_stock": member,
    }


def read_csv_dict(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as file:
        return list(csv.DictReader(file))


def parse_float_cell(row: dict[str, str], column: str) -> float | None:
    if column not in row:
        return None
    return to_number(row[column])


def read_exchange() -> dict[int, dict[str, object]]:
    records: dict[int, dict[str, object]] = {}
    for row in read_csv_dict(EXCHANGE_PATH):
        year = int(row["anno"])
        records[year] = {
            "fecha_tipo_cambio": row["fecha_referencia"],
            "dolar_usa_compra_dic_ine": parse_float_cell(row, "dolar_usa_compra"),
            "dolar_usa_venta_dic_ine": parse_float_cell(row, "dolar_usa_venta"),
        }
    return records


def read_ciu() -> dict[int, dict[str, object]]:
    records: dict[int, dict[str, object]] = {}
    for row in read_csv_dict(CIU_PATH):
        year = int(float(row["anno"]))
        records[year] = {
            "stock_ciu_mill_usd_corriente": parse_float_cell(
                row, "stock_capital_fijo_maquinaria_equipos_mill_usd"
            ),
            "stock_ciu_indice_dic_2008_100": parse_float_cell(
                row, "stock_capital_fijo_maquinaria_equipos_indice_dic_2008_100"
            ),
        }
    return records


def read_integrated_panel() -> tuple[dict[int, float], dict[int, float]]:
    panel_rows = read_csv_dict(INTEGRATED_PANEL_PATH)
    industry_stock: dict[int, float] = {}
    deflator_numerators: dict[int, float] = defaultdict(float)
    deflator_denominators: dict[int, float] = defaultdict(float)

    for row in panel_rows:
        year = int(row["anno"])
        level = row["nivel_panel"]
        if level == "industria_total":
            value = parse_float_cell(row, "stock_capital")
            if value is not None:
                industry_stock[year] = value
        if level != "subrama_industrial":
            continue
        if row["grupo_rev4_homologado"] == "19_refinacion":
            continue
        current = parse_float_cell(row, "vab_bcu_corriente")
        deflator = parse_float_cell(row, "deflactor_2005")
        if current is None or deflator in (None, 0):
            continue
        deflator_numerators[year] += current
        deflator_denominators[year] += current / deflator

    deflators: dict[int, float] = {}
    for year, numerator in deflator_numerators.items():
        denominator = deflator_denominators[year]
        if denominator:
            deflators[year] = numerator / denominator

    return industry_stock, deflators


def main() -> int:
    for path in [CIU_PATH, EXCHANGE_PATH, INTEGRATED_PANEL_PATH]:
        if not path.exists():
            raise FileNotFoundError(path)

    extractors = candidate_extractors()
    if not extractors:
        raise RuntimeError("No RAR extractor candidate found.")

    exchange = read_exchange()
    ciu = read_ciu()
    panel_stock, deflators = read_integrated_panel()

    eaae_assets = {
        int(record["anno"]): record
        for record in (
            extract_eaae_assets_year(year, extractors)
            for year in PANEL_YEARS
        )
    }

    tc_venta_2005 = exchange.get(2005, {}).get("dolar_usa_venta_dic_ine")
    if tc_venta_2005 in (None, 0):
        raise RuntimeError("No se encontro tipo de cambio venta 2005 para convertir constantes.")

    rows: list[dict[str, object]] = []
    for year in range(2001, 2025):
        row: dict[str, object] = {"anno": year}
        row.update(exchange.get(year, {}))
        row.update(ciu.get(year, {}))
        row.update(eaae_assets.get(year, {}))

        tc_venta = row.get("dolar_usa_venta_dic_ine")
        stock_uyu = row.get("stock_eaae_maquinaria_equipos_sin_refinacion_uyu_corriente")
        deflator = deflators.get(year)
        row["deflactor_bcu_proxy_sin_refinacion_2005"] = deflator

        if stock_uyu is not None and tc_venta not in (None, 0):
            row["stock_eaae_maquinaria_equipos_sin_refinacion_mill_usd_corriente"] = (
                float(stock_uyu) / float(tc_venta) / 1_000_000
            )
        ciu_usd = row.get("stock_ciu_mill_usd_corriente")
        eaae_usd = row.get("stock_eaae_maquinaria_equipos_sin_refinacion_mill_usd_corriente")
        if eaae_usd is not None and ciu_usd not in (None, 0):
            row["ratio_eaae_ciu_stock_usd_corriente_pct"] = (
                float(eaae_usd) / float(ciu_usd) * 100
            )
        if stock_uyu is not None and deflator not in (None, 0):
            # DECISION: the constant USD proxy first deflates the peso-current
            # stock with the BCU implicit VAB deflator for industry excluding
            # refinery, then converts the 2005-peso value at the December 2005
            # INE sale exchange rate.
            row["stock_eaae_maquinaria_equipos_sin_refinacion_mill_usd_constante_2005_proxy"] = (
                float(stock_uyu) / float(deflator) / float(tc_venta_2005) / 1_000_000
            )

        panel_value = panel_stock.get(year)
        row["stock_total_panel_industria_uyu_corriente"] = panel_value
        extracted_total = row.get("stock_eaae_total_activos_industria_uyu_corriente")
        if panel_value is not None and extracted_total is not None:
            row["diferencia_stock_total_extraido_panel_uyu"] = (
                float(extracted_total) - float(panel_value)
            )

        row["fuente_tipo_cambio"] = "INE Uruguay, hoja Fuente BROU, ultimo valor de diciembre, Dolar.USA.Venta"
        row["fuente_deflactor"] = "proxy BCU: deflactor implicito VAB subramas industriales excluyendo refinacion, base 2005"
        row["fuente_ciu"] = "CIU stock capital fijo maquinaria y equipos industria sin refineria ANCAP ni zonas francas"
        rows.append(row)

    base_2008 = None
    for row in rows:
        if row["anno"] == 2008:
            base_2008 = row.get(
                "stock_eaae_maquinaria_equipos_sin_refinacion_mill_usd_constante_2005_proxy"
            )
            break
    if base_2008 in (None, 0):
        raise RuntimeError("No se pudo calcular base 2008 para indice EAAE.")

    for row in rows:
        value = row.get(
            "stock_eaae_maquinaria_equipos_sin_refinacion_mill_usd_constante_2005_proxy"
        )
        if value is not None:
            row["stock_eaae_maquinaria_equipos_sin_refinacion_indice_2008_100"] = (
                float(value) / float(base_2008) * 100
            )
        ciu_index = row.get("stock_ciu_indice_dic_2008_100")
        eaae_index = row.get("stock_eaae_maquinaria_equipos_sin_refinacion_indice_2008_100")
        if eaae_index is not None and ciu_index not in (None, 0):
            row["ratio_indice_eaae_ciu_2008_pct"] = (
                float(eaae_index) / float(ciu_index) * 100
            )

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT_PATH.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=OUTPUT_COLUMNS)
        writer.writeheader()
        for row in rows:
            writer.writerow({column: fmt(row.get(column)) for column in OUTPUT_COLUMNS})

    print(f"CSV escrito en {OUTPUT_PATH.relative_to(PROJECT_ROOT)}")
    print(f"Filas: {len(rows)}; rango: {rows[0]['anno']}-{rows[-1]['anno']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
