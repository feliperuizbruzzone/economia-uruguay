"""Extract direct EAAE manufacturing sub-branch FBCF/FBKF variables.

This helper is called by
`13_build_panel_eaae_bcu_total_industria_subrama.R`. It reads the original EAAE
RAR files, extracts FBCF/acquisitions and machinery/equipment component tables,
and writes a tidy CSV with Rev.4-compatible manufacturing groups.
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
    EAAE_CONFIG,
    EAAE_FBCF_CONFIG,
    EAAE_FBKF_MAQ_EQ_CONFIG,
    PANEL_YEARS,
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
    "fbcf",
    "fbkf_maq_eq",
    "adquisiciones_importadas",
    "adquisiciones_origen_importado",
    "importaciones_maquinaria",
    "metodo_fbkf_eaae",
    "calidad_fbkf_eaae",
    "codigos_fbkf_fuente",
    "archivos_fbkf_fuente",
    "n_filas_fbcf_fuente",
    "n_filas_fbkf_maq_eq_fuente",
]

AUDIT_COLUMNS = [
    "anno",
    "variable",
    "seccion_fuente",
    "division_publicada",
    "grupo_rev4_homologado",
    "valor",
    "archivo_fuente",
    "cuadro_fuente",
    "usar_para_homologacion",
    "estado_mapeo",
]

# DECISION: The sub-branch panel uses the same 2001 two-digit, 5+ persons
# universe as `11_build_eaae_industria_subramas.py`. The letter-level 2001
# FBCF tables are valid for the main panel but not for sub-branch allocation.
YEAR_2001_FBCF = {
    "member": "2 Digitos/EAE_cu14afe2_01.xls",
    "section_col": 0,
    "division_col": 1,
    "fbcf_col": 3,
    "adquisiciones_importadas_col": 7,
    "adquisiciones_origen_importado_col": None,
    "value_scale": 1000,
    "cuadro_fuente": "C14_2dig_2001",
}
YEAR_2001_FBKF_MAQ_EQ = {
    "member": "2 Digitos/EAE_cu17afe2_01.xls",
    "section_col": 0,
    "division_col": 1,
    "fbkf_maq_eq_col": 5,
    "value_scale": 1000,
    "cuadro_fuente": "C17_2dig_2001",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract direct EAAE sub-branch FBCF/FBKF variables."
    )
    parser.add_argument("--output", required=True, help="CSV output path.")
    parser.add_argument(
        "--audit-output",
        help="Optional source-row audit CSV output path.",
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
        if stripped == "-":
            return 0.0
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


def has_any_value(row: dict[str, object]) -> bool:
    return any(row.get(column) is not None for column in row.get("value_columns", []))


def should_use_for_homologation(year: int, row: dict[str, object]) -> bool:
    if not row.get("division_publicada"):
        return False
    if not has_any_value(row):
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
        or "/tmp/unrar-local/usr/bin/unrar-nonfree"
    )
    if unrar and Path(unrar).exists():
        extractors.append(("unrar", [unrar]))

    bsdtar = shutil.which("bsdtar")
    if bsdtar:
        extractors.append(("bsdtar", [bsdtar]))

    seven_zip = shutil.which("7z")
    if seven_zip:
        # DECISION: 7z can list the project RAR5 files but cannot extract some
        # members. Keep it as a last-resort fallback for environments where it
        # does support the compression method.
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


def read_multi_value_rows(
    xls_path: Path,
    year: int,
    section_col: int,
    division_col: int,
    value_columns: dict[str, int],
    value_scale: float,
    member: str,
    cuadro_fuente: str,
) -> list[dict[str, object]]:
    workbook = xlrd.open_workbook(str(xls_path))
    sheet = workbook.sheet_by_index(0)
    rows: list[dict[str, object]] = []
    current: dict[str, object] | None = None

    def cell(row_idx: int, col_idx: int) -> object:
        if col_idx >= sheet.ncols:
            return ""
        return sheet.cell_value(row_idx, col_idx)

    def row_values(row_idx: int) -> dict[str, float | None]:
        values: dict[str, float | None] = {}
        for name, col_idx in value_columns.items():
            number = to_number(cell(row_idx, col_idx))
            values[name] = number * value_scale if number is not None else None
        return values

    def flush_current() -> None:
        nonlocal current
        if current is None:
            return
        current["usar_para_homologacion"] = (
            "si" if should_use_for_homologation(year, current) else "no"
        )
        rows.append(current)
        current = None

    for row_idx in range(sheet.nrows):
        section = str(cell(row_idx, section_col)).strip()
        division = normalize_code(cell(row_idx, division_col))
        values = row_values(row_idx)

        if re.fullmatch(r"[A-Z]", section):
            flush_current()
            current = {
                "anno": year,
                "seccion_fuente": section,
                "division_publicada": division,
                "archivo_fuente": member,
                "cuadro_fuente": cuadro_fuente,
                "value_columns": list(value_columns),
                **values,
            }
            continue

        if current is None:
            continue
        if any(value is not None for value in values.values()):
            for name, value in values.items():
                if value is not None:
                    current[name] = value

    flush_current()
    return rows


def extract_kind_year(
    year: int,
    kind: str,
    extractors: list[tuple[str, list[str]]],
) -> tuple[list[dict[str, object]], str | None]:
    source_config = EAAE_CONFIG[year]
    rar_path = PROJECT_ROOT / DATA_INPUT_EAAE_DIR / source_config["rar_name"]
    if not rar_path.exists():
        raise FileNotFoundError(f"Year {year}: missing RAR {rar_path}")

    members = list_members(rar_path, extractors)
    exact_member: str | None = None

    if kind == "fbcf":
        config = dict(EAAE_FBCF_CONFIG[year])
        if year == 2001:
            config.update(YEAR_2001_FBCF)
            exact_member = YEAR_2001_FBCF["member"]
        if config.get("file_pattern") is None and exact_member is None:
            return [], None
        value_columns = {
            "fbcf": int(config["fbcf_col"]),
            "adquisiciones_importadas": int(config["adquisiciones_importadas_col"]),
        }
        if config.get("adquisiciones_origen_importado_col") is not None:
            value_columns["adquisiciones_origen_importado"] = int(
                config["adquisiciones_origen_importado_col"]
            )
        cuadro_fuente = str(config.get("cuadro_fuente") or "FBCF")
    elif kind == "fbkf_maq_eq":
        config = dict(EAAE_FBKF_MAQ_EQ_CONFIG[year])
        if year == 2001:
            config.update(YEAR_2001_FBKF_MAQ_EQ)
            exact_member = YEAR_2001_FBKF_MAQ_EQ["member"]
        if config.get("file_pattern") is None and exact_member is None:
            return [], None
        value_columns = {"fbkf_maq_eq": int(config["fbkf_maq_eq_col"])}
        cuadro_fuente = str(config.get("cuadro_fuente") or "FBKF_componentes")
    else:
        raise ValueError(f"Unexpected kind: {kind}")

    member = find_member(year, members, config, exact_member)
    if member is None:
        return [], None

    section_col = int(config["section_col"])
    division_col = int(config["division_col"])
    value_scale = float(config.get("value_scale", 1))

    with tempfile.TemporaryDirectory(prefix=f"eaae-fbkf-subrama-{year}-") as tmp:
        xls_path = extract_member(rar_path, member, Path(tmp), extractors)
        rows = read_multi_value_rows(
            xls_path=xls_path,
            year=year,
            section_col=section_col,
            division_col=division_col,
            value_columns=value_columns,
            value_scale=value_scale,
            member=member,
            cuadro_fuente=cuadro_fuente,
        )
    return rows, member


def aggregate_homologated(
    raw_rows: list[dict[str, object]],
    mapping: dict[tuple[str, str], dict[str, str]],
) -> tuple[dict[tuple[int, str], dict[str, object]], list[dict[str, object]]]:
    grouped: dict[tuple[int, str], dict[str, object]] = {}
    audit_rows: list[dict[str, object]] = []

    for row in raw_rows:
        year = int(row["anno"])
        expected_section = expected_source_section(year)
        use_row = (
            row.get("usar_para_homologacion") == "si"
            and str(row.get("seccion_fuente", "")).strip() == expected_section
        )
        match = mapping_for_row(year, row, mapping) if use_row else None
        estado_mapeo = "mapeado" if match is not None else "no_mapeado_o_no_usado"
        group = match["grupo_rev4_homologado"] if match is not None else ""

        for variable in row.get("value_columns", []):
            audit_rows.append(
                {
                    "anno": year,
                    "variable": variable,
                    "seccion_fuente": row.get("seccion_fuente"),
                    "division_publicada": row.get("division_publicada"),
                    "grupo_rev4_homologado": group,
                    "valor": row.get(variable),
                    "archivo_fuente": row.get("archivo_fuente"),
                    "cuadro_fuente": row.get("cuadro_fuente"),
                    "usar_para_homologacion": row.get("usar_para_homologacion"),
                    "estado_mapeo": estado_mapeo,
                }
            )

        if match is None:
            continue

        key = (year, group)
        record = grouped.setdefault(
            key,
            {
                "anno": year,
                "grupo_rev4_homologado": group,
                "codigos_fbkf_fuente": set(),
                "archivos_fbkf_fuente": set(),
                "n_filas_fbcf_fuente": 0,
                "n_filas_fbkf_maq_eq_fuente": 0,
            },
        )
        record["archivos_fbkf_fuente"].add(str(row.get("archivo_fuente") or ""))
        for code in base_2dig_codes(
            str(row.get("division_publicada") or ""),
            ciiu_version_for_year(year),
        ):
            record["codigos_fbkf_fuente"].add(code)

        if "fbcf" in row.get("value_columns", []):
            record["n_filas_fbcf_fuente"] += 1
        if "fbkf_maq_eq" in row.get("value_columns", []):
            record["n_filas_fbkf_maq_eq_fuente"] += 1

        for variable in row.get("value_columns", []):
            value = row.get(variable)
            if value is not None:
                record[variable] = float(record.get(variable, 0) or 0) + float(value)

    return grouped, audit_rows


def finalize_rows(records: dict[tuple[int, str], dict[str, object]]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for key in sorted(records):
        record = records[key]
        if (
            record.get("adquisiciones_importadas") is not None
            and record.get("adquisiciones_origen_importado") is not None
        ):
            record["importaciones_maquinaria"] = (
                float(record["adquisiciones_importadas"])
                + float(record["adquisiciones_origen_importado"])
            )
        record["metodo_fbkf_eaae"] = "extraccion_directa_cuadros_fbkf_subrama_eaae"
        record["calidad_fbkf_eaae"] = "directo"
        output: dict[str, object] = {}
        for column in OUTPUT_COLUMNS:
            value = record.get(column)
            if isinstance(value, set):
                value = "|".join(sorted(item for item in value if item))
            output[column] = value
        rows.append(output)
    return rows


def write_csv(path: Path, columns: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    args = parse_args()
    extractors = candidate_extractors()
    if not extractors:
        raise RuntimeError("No RAR extractor candidate found.")

    mapping = read_homologation_config()
    raw_rows: list[dict[str, object]] = []

    for year in args.years:
        fbcf_rows, _fbcf_member = extract_kind_year(year, "fbcf", extractors)
        fbkf_rows, _fbkf_member = extract_kind_year(year, "fbkf_maq_eq", extractors)
        raw_rows.extend(fbcf_rows)
        raw_rows.extend(fbkf_rows)

    records, audit_rows = aggregate_homologated(raw_rows, mapping)
    output_rows = finalize_rows(records)

    write_csv(Path(args.output), OUTPUT_COLUMNS, output_rows)
    if args.audit_output:
        write_csv(Path(args.audit_output), AUDIT_COLUMNS, audit_rows)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
