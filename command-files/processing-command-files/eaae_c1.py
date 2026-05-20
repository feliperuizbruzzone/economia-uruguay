"""Shared C1/C1.1 extraction helpers for the EAAE pipeline."""

from __future__ import annotations

import logging
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
    CIIU_HOMOLOGATED_MINIMUM_SECTIONS,
    DATA_INPUT_EAAE_DIR,
    EAAE_CONFIG,
    PANEL_YEARS,
    homologate_ciiu_section,
)


LOGGER = logging.getLogger(__name__)
SECTION_RE = re.compile(r"^[A-Z]$")
NUMERIC_COLUMNS = [
    "vbp_pp",
    "vbp_pb",
    "vab_pp",
    "vab_pb",
    "remuneraciones",
    "puestos_trabajo",
]


def find_unrar() -> str:
    candidates = [
        os.environ.get("UNRAR_BIN"),
        shutil.which("unrar"),
        shutil.which("unrar-nonfree"),
        "/tmp/unrar-local/usr/bin/unrar-nonfree",
    ]
    for candidate in candidates:
        if candidate and Path(candidate).exists():
            return str(candidate)
    raise RuntimeError(
        "No unrar executable found. Install unrar or set UNRAR_BIN to an "
        "executable that can extract RAR5 archives."
    )


def list_archive_members(rar_path: Path, unrar_bin: str) -> list[str]:
    result = subprocess.run(
        [unrar_bin, "lb", str(rar_path)],
        check=True,
        text=True,
        capture_output=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def find_member(year: int, members: list[str]) -> str:
    config = EAAE_CONFIG[year]
    pattern = re.compile(config["file_pattern"])
    subfolder = config["subfolder"]
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
            f"Year {year}: expected exactly one C1/C1.1 XLS matching "
            f"{config['file_pattern']!r}, found {matches}"
        )
    return matches[0]


def extract_member(rar_path: Path, member: str, output_dir: Path, unrar_bin: str) -> Path:
    subprocess.run(
        [unrar_bin, "e", "-y", str(rar_path), member, str(output_dir) + "/"],
        check=True,
        text=True,
        capture_output=True,
    )
    extracted = output_dir / Path(member).name
    if not extracted.exists():
        raise RuntimeError(f"Archive member was not extracted: {member}")
    return extracted


def detect_data_start(sheet: xlrd.sheet.Sheet) -> int:
    for row_idx in range(sheet.nrows):
        value = str(sheet.cell_value(row_idx, 0)).strip()
        if SECTION_RE.fullmatch(value):
            return row_idx
    raise ValueError(f"No CIIU section start row found in sheet {sheet.name!r}")


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


def ciiu_version_for_year(year: int) -> str:
    return "Rev.3" if year <= 2007 else "Rev.4"


def read_source_rows(year: int, xls_path: Path) -> list[dict[str, object]]:
    config = EAAE_CONFIG[year]
    columns = config["columns"]
    if columns is None:
        raise ValueError(f"Year {year}: no C1/C1.1 column schema configured")

    workbook = xlrd.open_workbook(str(xls_path))
    sheet = workbook.sheet_by_index(0)
    detected_start = detect_data_start(sheet)
    configured_start = config["data_start_row"]
    if configured_start is not None and detected_start != configured_start:
        LOGGER.warning(
            "Year %s: detected data_start_row=%s differs from config=%s",
            year,
            detected_start,
            configured_start,
        )

    rows: list[dict[str, object]] = []
    for row_idx in range(detected_start, sheet.nrows):
        section = str(sheet.cell_value(row_idx, 0)).strip()
        if not SECTION_RE.fullmatch(section):
            continue

        row: dict[str, object] = {"seccion_fuente": section}
        for col_idx, name in enumerate(columns):
            value = sheet.cell_value(row_idx, col_idx)
            if name in NUMERIC_COLUMNS:
                number = to_number(value)
                scale = config.get("value_scale", {}).get(name, 1)
                # DECISION: 2001 publishes monetary values in thousands of
                # pesos. Apply configured scaling here so the panel keeps one
                # common peso-corriente unit without extra helper columns.
                row[name] = number * scale if number is not None else None
            elif name == "division":
                row["division"] = value
            elif name != "seccion":
                row[name] = str(value).strip()
        rows.append(row)

    if not rows:
        raise RuntimeError(f"Year {year}: no source rows extracted from {xls_path}")
    return rows


def has_blank_division(row: dict[str, object]) -> bool:
    if "division" not in row:
        return False
    return str(row.get("division", "")).strip() == ""


def select_additive_rows(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    total_rows = [row for row in rows if has_blank_division(row)]
    # DECISION: Older Rev.3 files include hierarchical detail plus section-total
    # rows with blank division. Use those totals to avoid double counting. Newer
    # files do not include such totals, so aggregate their additive rows.
    return total_rows if total_rows else rows


def extract_c1_year(year: int, unrar_bin: str | None = None) -> list[dict[str, object]]:
    config = EAAE_CONFIG[year]
    rar_path = PROJECT_ROOT / DATA_INPUT_EAAE_DIR / config["rar_name"]
    if not rar_path.exists():
        raise FileNotFoundError(f"Year {year}: missing RAR file {rar_path}")

    unrar = unrar_bin or find_unrar()
    members = list_archive_members(rar_path, unrar)
    member = find_member(year, members)
    LOGGER.info("Year %s: extracting %s", year, member)

    with tempfile.TemporaryDirectory(prefix=f"eaae-{year}-") as tmpdir:
        xls_path = extract_member(rar_path, member, Path(tmpdir), unrar)
        source_rows = read_source_rows(year, xls_path)

    version = ciiu_version_for_year(year)
    grouped: dict[str, dict[str, object]] = {}
    sums: dict[str, defaultdict[str, float]] = defaultdict(lambda: defaultdict(float))
    present: dict[str, set[str]] = defaultdict(set)

    for row in select_additive_rows(source_rows):
        section = homologate_ciiu_section(str(row["seccion_fuente"]), version)
        for column in NUMERIC_COLUMNS:
            value = row.get(column)
            if value is not None:
                sums[section][column] += float(value)
                present[section].add(column)

    for section in sorted(sums):
        record: dict[str, object] = {
            "anno": year,
            "seccion": section,
            "epoca": config["epoca"],
            "ciiu_version": version,
        }
        for column in NUMERIC_COLUMNS:
            record[column] = (
                sums[section][column] if column in present[section] else None
            )
        grouped[section] = record

    return list(grouped.values())


def extract_c1_panel(years: list[int] | None = None) -> list[dict[str, object]]:
    selected_years = years if years is not None else PANEL_YEARS
    unrar = find_unrar()
    records: list[dict[str, object]] = []
    for year in selected_years:
        records.extend(extract_c1_year(year, unrar))
    return records


def validate_extracted_year(year: int, rows: list[dict[str, object]]) -> None:
    sections = {str(row["seccion"]) for row in rows}
    if year >= 2001 and not sections.issuperset(CIIU_HOMOLOGATED_MINIMUM_SECTIONS):
        missing = sorted(CIIU_HOMOLOGATED_MINIMUM_SECTIONS - sections)
        raise AssertionError(f"Year {year}: missing homologated sections {missing}")

    for row in rows:
        for column in ["seccion", "anno", "vab_pp", "remuneraciones"]:
            if row.get(column) in (None, ""):
                raise AssertionError(f"Year {year}: null value in {column}")

        vbp_pp = row.get("vbp_pp")
        vab_pp = row.get("vab_pp")
        remuneraciones = row.get("remuneraciones")
        puestos = row.get("puestos_trabajo")
        if vbp_pp is not None and vab_pp is not None and vbp_pp < vab_pp:
            raise AssertionError(f"Year {year}: vbp_pp < vab_pp in {row['seccion']}")
        if vab_pp is not None and remuneraciones is not None and vab_pp < remuneraciones:
            LOGGER.warning(
                "Year %s: vab_pp < remuneraciones in %s",
                year,
                row["seccion"],
            )
        if puestos is not None and puestos <= 0:
            raise AssertionError(
                f"Year {year}: puestos_trabajo <= 0 in {row['seccion']}"
            )

    has_vbp_pb = any(row.get("vbp_pb") is not None for row in rows)
    if year >= 2017 and not has_vbp_pb:
        raise AssertionError(f"Year {year}: missing expected vbp_pb values")
    if year < 2017 and has_vbp_pb:
        raise AssertionError(f"Year {year}: unexpected vbp_pb before 2017")

    has_vab_pb = any(row.get("vab_pb") is not None for row in rows)
    if year >= 2017 and not has_vab_pb:
        raise AssertionError(f"Year {year}: missing expected vab_pb values")
    if year < 2017 and has_vab_pb:
        raise AssertionError(f"Year {year}: unexpected vab_pb before 2017")
