"""Extract direct EAAE manufacturing sub-branch capital variables.

This helper is called by
`13_build_panel_eaae_bcu_total_industria_subrama.R`. It reads the original EAAE
RAR files, extracts C2/C2.1 and fixed-asset stock XLS tables, and writes a tidy
CSV with Rev.4-compatible manufacturing groups.
"""

from __future__ import annotations

import argparse
import csv
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
    EAAE_ACCOUNTS_CONFIG,
    EAAE_CONFIG,
    EAAE_STOCK_CONFIG,
    PANEL_YEARS,
    STOCK_CAPITAL_IMPUTATION_WINDOWS,
)


HOMOLOGATION_CONFIG = (
    PROJECT_ROOT
    / "command-files"
    / "config"
    / "eaae_industria_subramas_rev4_homologacion.csv"
)

OUTPUT_COLUMNS = [
    "anno",
    "grupo_rev4_homologado",
    "consumo_capital_fijo",
    "impuestos_netos",
    "stock_capital",
    "stock_capital_imputado",
    "metodo_capital_eaae",
    "metodo_stock_capital",
    "metodo_consumo_capital_fijo",
    "calidad_capital_eaae",
    "codigos_capital_fuente",
    "archivos_capital_fuente",
]

# DECISION: 2001 sub-branch analysis uses the same two-digit, 5+ persons
# universe as `11_build_eaae_industria_subramas.py`. For fixed assets, the
# correct two-digit table is Cuadro 15, not Cuadro 9: Cuadro 9 at two digits is
# hours worked.
YEAR_2001_ACCOUNTS = {
    "member": "2 Digitos/EAE_cu2afe2_01.xls",
    "section_col": 0,
    "division_col": 1,
    "impuestos_netos_col": 6,
    "consumo_capital_col": 7,
    "value_scale": 1000,
}
YEAR_2001_STOCK = {
    "member": "2 Digitos/EAE_cu15afe2_01.xls",
    "section_col": 0,
    "division_col": 1,
    "stock_capital_col": 3,
    "value_scale": 1000,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract direct EAAE sub-branch capital variables."
    )
    parser.add_argument(
        "--output",
        required=True,
        help="CSV output path.",
    )
    parser.add_argument(
        "--years",
        nargs="*",
        type=int,
        default=PANEL_YEARS,
        help="Years to extract. Defaults to 2001-2024.",
    )
    return parser.parse_args()


def ciiu_version_for_year(year: int) -> str:
    return "Rev.3" if year <= 2007 else "Rev.4"


def expected_source_section(year: int) -> str:
    return "D" if ciiu_version_for_year(year) == "Rev.3" else "C"


def to_number(value: object) -> float | None:
    if value is None:
        return None
    if isinstance(value, str):
        stripped = value.strip()
        if not stripped:
            return None
        value = stripped.replace(".", "").replace(",", ".")
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def normalize_code(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    text = str(value).strip()
    if not text:
        return ""
    if re.fullmatch(r"\d+\.0", text):
        text = text[:-2]
    text = re.sub(r"\s+", " ", text)
    text = text.replace(" Y ", " y ")
    return text


def component_codes(code: str) -> list[str]:
    normalized = normalize_code(code)
    if not normalized:
        return []
    return re.findall(r"\d{2,4}", normalized)


def base_2dig_codes(code: str, ciiu_version: str) -> list[str]:
    bases: list[str] = []
    for component in component_codes(code):
        base = component[:2] if ciiu_version == "Rev.3" else component
        if base not in bases:
            bases.append(base)
    return bases


def classify_level(code: str) -> str:
    normalized = normalize_code(code)
    if not normalized:
        return "seccion_total"
    if re.search(r"[-,]|\by\b", normalized):
        return "grupo_codigos_publicado"
    if re.fullmatch(r"\d{2}", normalized):
        return "division_2_digitos"
    if re.fullmatch(r"\d{3}", normalized):
        return "grupo_3_digitos"
    if re.fullmatch(r"\d{4}", normalized):
        return "clase_4_digitos"
    return "codigo_publicado"


def should_use_for_homologation(year: int, row: dict[str, object]) -> bool:
    if not row.get("division_publicada"):
        return False
    if row.get("valor") is None:
        return False
    if year == 2001:
        return True
    version = ciiu_version_for_year(year)
    level = classify_level(str(row.get("division_publicada") or ""))
    if version == "Rev.3" and year <= 2005:
        return level == "division_2_digitos"
    return bool(component_codes(str(row.get("division_publicada") or "")))


def read_homologation_config() -> dict[tuple[str, str], dict[str, str]]:
    with HOMOLOGATION_CONFIG.open(newline="", encoding="utf-8") as file:
        reader = csv.DictReader(file)
        mapping: dict[tuple[str, str], dict[str, str]] = {}
        for row in reader:
            if row["incluir_sector_industrial_rev4"] != "si":
                continue
            mapping[(row["ciiu_version_fuente"], row["codigo_fuente_2dig"])] = row
    return mapping


def mapping_for_row(
    year: int,
    row: dict[str, object],
    mapping: dict[tuple[str, str], dict[str, str]],
) -> dict[str, str] | None:
    version = ciiu_version_for_year(year)
    bases = base_2dig_codes(str(row.get("division_publicada") or ""), version)
    mapped = [mapping.get((version, base)) for base in bases]
    if not mapped or any(item is None for item in mapped):
        return None
    groups = {item["grupo_rev4_homologado"] for item in mapped if item is not None}
    if len(groups) != 1:
        return None
    return dict(mapped[0])


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
        # DECISION: In the current workstation, the available RAR5-capable
        # bsdtar is provided by the local Flatpak runtime. Mount the project and
        # /tmp explicitly so source RARs stay read-only and extracted XLS files
        # live only in temporary directories.
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
        # DECISION: Use 7z as a last-resort local fallback. Some RAR5 methods
        # can be listed but not extracted by 7z, so prefer unrar/bsdtar when
        # they are available.
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


def find_member(
    year: int,
    members: list[str],
    config: dict[str, object],
    exact_member: str | None = None,
) -> str | None:
    if exact_member is not None:
        if exact_member not in members:
            raise RuntimeError(f"Year {year}: missing expected member {exact_member}")
        return exact_member

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


def read_value_rows(
    xls_path: Path,
    year: int,
    section_col: int,
    division_col: int,
    value_col: int,
    value_scale: float,
    variable: str,
) -> list[dict[str, object]]:
    workbook = xlrd.open_workbook(str(xls_path))
    sheet = workbook.sheet_by_index(0)
    rows: list[dict[str, object]] = []
    current: dict[str, object] | None = None

    def cell(row_idx: int, col_idx: int) -> object:
        if col_idx >= sheet.ncols:
            return ""
        return sheet.cell_value(row_idx, col_idx)

    def flush_current() -> None:
        nonlocal current
        if current is None:
            return
        if should_use_for_homologation(year, current):
            rows.append(current)
        current = None

    for row_idx in range(sheet.nrows):
        section = str(cell(row_idx, section_col)).strip()
        division = normalize_code(cell(row_idx, division_col))
        raw_value = to_number(cell(row_idx, value_col))
        value = raw_value * value_scale if raw_value is not None else None

        if re.fullmatch(r"[A-Z]", section):
            flush_current()
            current = {
                "anno": year,
                "seccion_fuente": section,
                "division_publicada": division,
                "valor": value,
                "variable": variable,
            }
            continue

        if current is None:
            continue
        if value is not None:
            current["valor"] = value

    flush_current()
    return rows


def extract_variable_year(
    year: int,
    variable: str,
    extractors: list[tuple[str, list[str]]],
) -> tuple[list[dict[str, object]], str | None]:
    source_config = EAAE_CONFIG[year]
    rar_path = PROJECT_ROOT / DATA_INPUT_EAAE_DIR / source_config["rar_name"]
    if not rar_path.exists():
        raise FileNotFoundError(f"Year {year}: missing RAR {rar_path}")

    members = list_members(rar_path, extractors)
    exact_member: str | None = None
    if variable == "accounts":
        config = dict(EAAE_ACCOUNTS_CONFIG[year])
        if year == 2001:
            config.update(YEAR_2001_ACCOUNTS)
            exact_member = YEAR_2001_ACCOUNTS["member"]
        value_columns = {
            "consumo_capital_fijo": int(config["consumo_capital_col"]),
            "impuestos_netos": int(config["impuestos_netos_col"]),
        }
    elif variable == "stock":
        config = dict(EAAE_STOCK_CONFIG[year])
        if year == 2001:
            config.update(YEAR_2001_STOCK)
            exact_member = YEAR_2001_STOCK["member"]
        if config.get("file_pattern") is None and exact_member is None:
            return [], None
        value_columns = {"stock_capital": int(config["stock_capital_col"])}
    else:
        raise ValueError(f"Unexpected variable kind: {variable}")

    member = find_member(year, members, config, exact_member)
    if member is None:
        return [], None

    section_col = int(config["section_col"])
    division_col = int(config["division_col"])
    value_scale = float(config.get("value_scale", 1))

    records: list[dict[str, object]] = []
    with tempfile.TemporaryDirectory(prefix=f"eaae-capital-{year}-") as tmp:
        xls_path = extract_member(rar_path, member, Path(tmp), extractors)
        for name, col_idx in value_columns.items():
            records.extend(
                read_value_rows(
                    xls_path=xls_path,
                    year=year,
                    section_col=section_col,
                    division_col=division_col,
                    value_col=col_idx,
                    value_scale=value_scale,
                    variable=name,
                )
            )
    return records, member


def aggregate_homologated(
    raw_rows: list[dict[str, object]],
    mapping: dict[tuple[str, str], dict[str, str]],
) -> dict[tuple[int, str], dict[str, object]]:
    grouped: dict[tuple[int, str], dict[str, object]] = {}
    for row in raw_rows:
        year = int(row["anno"])
        if str(row.get("seccion_fuente", "")).strip() != expected_source_section(year):
            continue
        match = mapping_for_row(year, row, mapping)
        if match is None:
            continue
        group = match["grupo_rev4_homologado"]
        key = (year, group)
        record = grouped.setdefault(
            key,
            {
                "anno": year,
                "grupo_rev4_homologado": group,
                "codigos_capital_fuente": set(),
                "archivos_capital_fuente": set(),
            },
        )
        variable = str(row["variable"])
        record[variable] = float(record.get(variable, 0) or 0) + float(row["valor"])
        for code in base_2dig_codes(str(row.get("division_publicada") or ""), ciiu_version_for_year(year)):
            record["codigos_capital_fuente"].add(code)
    return grouped


def add_stock_imputation(records: dict[tuple[int, str], dict[str, object]]) -> None:
    groups = sorted({group for _, group in records})
    for group in groups:
        for missing_year, (start, end) in STOCK_CAPITAL_IMPUTATION_WINDOWS.items():
            key = (missing_year, group)
            record = records.get(key)
            if record is None:
                continue
            consumo = record.get("consumo_capital_fijo")
            ratios: list[float] = []
            for year in range(start, end + 1):
                ref = records.get((year, group), {})
                stock = ref.get("stock_capital")
                ccf = ref.get("consumo_capital_fijo")
                if stock is not None and ccf not in (None, 0):
                    ratios.append(float(stock) / float(ccf))
            if consumo is not None and ratios:
                factor = sum(ratios) / len(ratios)
                record["stock_capital_imputado"] = float(consumo) * factor
                record["metodo_stock_capital"] = (
                    f"stock_imputado_ratio_stock_consumo_capital_fijo_subrama_{start}_{end}"
                )
                record["calidad_capital_eaae"] = "directo_con_stock_imputado"

    for record in records.values():
        if record.get("stock_capital") is not None:
            record["stock_capital_imputado"] = record["stock_capital"]
            record["metodo_stock_capital"] = "stock_capital_directo_subrama"
            record["calidad_capital_eaae"] = "directo"
        record.setdefault("metodo_stock_capital", "stock_capital_no_disponible")
        record.setdefault("calidad_capital_eaae", "incompleto")
        record["metodo_capital_eaae"] = "extraccion_directa_subrama_eaae"
        record["metodo_consumo_capital_fijo"] = "consumo_capital_fijo_directo_subrama"


def main() -> int:
    args = parse_args()
    extractors = candidate_extractors()
    if not extractors:
        raise RuntimeError("No RAR extractor candidate found.")

    mapping = read_homologation_config()
    all_raw_rows: list[dict[str, object]] = []
    source_files: dict[tuple[int, str], set[str]] = defaultdict(set)

    for year in args.years:
        accounts_rows, accounts_member = extract_variable_year(year, "accounts", extractors)
        stock_rows, stock_member = extract_variable_year(year, "stock", extractors)
        all_raw_rows.extend(accounts_rows)
        all_raw_rows.extend(stock_rows)
        if accounts_member:
            for row in accounts_rows:
                if str(row.get("seccion_fuente", "")).strip() == expected_source_section(year):
                    source_files[(year, "accounts")].add(accounts_member)
        if stock_member:
            for row in stock_rows:
                if str(row.get("seccion_fuente", "")).strip() == expected_source_section(year):
                    source_files[(year, "stock")].add(stock_member)

    records = aggregate_homologated(all_raw_rows, mapping)
    for (year, _group), record in records.items():
        files = set()
        files.update(source_files.get((year, "accounts"), set()))
        files.update(source_files.get((year, "stock"), set()))
        record["archivos_capital_fuente"] = files

    add_stock_imputation(records)

    rows: list[dict[str, object]] = []
    for key in sorted(records):
        record = records[key]
        output: dict[str, object] = {}
        for column in OUTPUT_COLUMNS:
            value = record.get(column)
            if isinstance(value, set):
                value = "|".join(sorted(value))
            output[column] = value
        rows.append(output)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=OUTPUT_COLUMNS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
