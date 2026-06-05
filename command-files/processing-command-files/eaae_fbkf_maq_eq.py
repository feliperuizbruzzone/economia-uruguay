"""Extract FBKF machinery/equipment component for the EAAE pipeline."""

from __future__ import annotations

import logging
import re
import sys
import tempfile
from collections import defaultdict
from pathlib import Path

import xlrd

from eaae_c1 import (
    ciiu_version_for_year,
    detect_data_start,
    extract_member,
    find_unrar,
    list_archive_members,
    select_additive_rows,
    to_number,
)


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CONFIG_DIR = PROJECT_ROOT / "command-files" / "config"
sys.path.insert(0, str(CONFIG_DIR))

from eaae_config import (  # noqa: E402
    CIIU_HOMOLOGATED_MINIMUM_SECTIONS,
    DATA_INPUT_EAAE_DIR,
    EAAE_CONFIG,
    EAAE_FBKF_MAQ_EQ_CONFIG,
    PANEL_YEARS,
    homologate_ciiu_section,
)


LOGGER = logging.getLogger(__name__)


def find_fbkf_maq_eq_member(year: int, members: list[str]) -> str | None:
    config = EAAE_FBKF_MAQ_EQ_CONFIG[year]
    pattern_value = config["file_pattern"]
    if pattern_value is None:
        return None

    pattern = re.compile(str(pattern_value))
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
            f"Year {year}: expected exactly one FBKF machinery/equipment XLS "
            f"matching {pattern_value!r}, found {matches}"
        )
    return matches[0]


def read_fbkf_maq_eq_source_rows(year: int, xls_path: Path) -> list[dict[str, object]]:
    config = EAAE_FBKF_MAQ_EQ_CONFIG[year]
    workbook = xlrd.open_workbook(str(xls_path))
    sheet = workbook.sheet_by_index(0)
    detected_start = detect_data_start(sheet)
    configured_start = config["data_start_row"]
    if configured_start is not None and detected_start != configured_start:
        LOGGER.warning(
            "Year %s: detected FBKF machinery/equipment data_start_row=%s "
            "differs from config=%s",
            year,
            detected_start,
            configured_start,
        )

    section_col = int(config["section_col"])
    division_col = config["division_col"]
    value_col = int(config["fbkf_maq_eq_col"])
    if value_col >= sheet.ncols:
        raise RuntimeError(
            f"Year {year}: configured fbkf_maq_eq_col={value_col} exceeds "
            "FBKF component sheet columns"
        )
    scale = float(config.get("value_scale", 1))

    rows: list[dict[str, object]] = []
    for row_idx in range(detected_start, sheet.nrows):
        section = str(sheet.cell_value(row_idx, section_col)).strip()
        if not re.fullmatch(r"[A-Z]", section):
            continue
        value = to_number(sheet.cell_value(row_idx, value_col))
        row: dict[str, object] = {
            "seccion_fuente": section,
            # DECISION: Component tables use "-" for zero-valued cells.
            "fbkf_maq_eq": (value if value is not None else 0.0) * scale,
        }
        if division_col is not None:
            row["division"] = sheet.cell_value(row_idx, int(division_col))
        rows.append(row)

    if not rows:
        raise RuntimeError(
            f"Year {year}: no FBKF machinery/equipment rows extracted from {xls_path}"
        )
    return rows


def extract_fbkf_maq_eq_year(
    year: int, unrar_bin: str | None = None
) -> list[dict[str, object]]:
    source_config = EAAE_CONFIG[year]
    component_config = EAAE_FBKF_MAQ_EQ_CONFIG[year]
    if component_config["file_pattern"] is None:
        LOGGER.info(
            "Year %s: no configured FBKF machinery/equipment source; leaving empty",
            year,
        )
        return []

    rar_path = PROJECT_ROOT / DATA_INPUT_EAAE_DIR / source_config["rar_name"]
    if not rar_path.exists():
        raise FileNotFoundError(f"Year {year}: missing RAR file {rar_path}")

    unrar = unrar_bin or find_unrar()
    members = list_archive_members(rar_path, unrar)
    member = find_fbkf_maq_eq_member(year, members)
    if member is None:
        return []
    LOGGER.info("Year %s: extracting FBKF machinery/equipment from %s", year, member)

    with tempfile.TemporaryDirectory(prefix=f"eaae-fbkf-maq-eq-{year}-") as tmpdir:
        xls_path = extract_member(rar_path, member, Path(tmpdir), unrar)
        source_rows = read_fbkf_maq_eq_source_rows(year, xls_path)

    version = ciiu_version_for_year(year)
    sums: dict[str, defaultdict[str, float]] = defaultdict(lambda: defaultdict(float))
    present: dict[str, set[str]] = defaultdict(set)
    for row in select_additive_rows(source_rows):
        section = homologate_ciiu_section(str(row["seccion_fuente"]), version)
        value = row.get("fbkf_maq_eq")
        if value is not None:
            sums[section]["fbkf_maq_eq"] += float(value)
            present[section].add("fbkf_maq_eq")

    records: list[dict[str, object]] = []
    for section in sorted(sums):
        records.append(
            {
                "anno": year,
                "seccion": section,
                "fbkf_maq_eq": (
                    sums[section]["fbkf_maq_eq"]
                    if "fbkf_maq_eq" in present[section]
                    else None
                ),
            }
        )
    return records


def extract_fbkf_maq_eq_panel(years: list[int] | None = None) -> list[dict[str, object]]:
    selected_years = years if years is not None else PANEL_YEARS
    unrar = find_unrar()
    records: list[dict[str, object]] = []
    for year in selected_years:
        records.extend(extract_fbkf_maq_eq_year(year, unrar))
    return records


def validate_fbkf_maq_eq_year(year: int, rows: list[dict[str, object]]) -> None:
    if EAAE_FBKF_MAQ_EQ_CONFIG[year]["file_pattern"] is None:
        if rows:
            raise AssertionError(f"Year {year}: unexpected FBKF machinery/equipment rows")
        return

    sections = {str(row["seccion"]) for row in rows}
    if not sections.issuperset(CIIU_HOMOLOGATED_MINIMUM_SECTIONS):
        missing = sorted(CIIU_HOMOLOGATED_MINIMUM_SECTIONS - sections)
        raise AssertionError(
            f"Year {year}: missing FBKF machinery/equipment sections {missing}"
        )

    for row in rows:
        value = row.get("fbkf_maq_eq")
        if value is None:
            raise AssertionError(f"Year {year}: null fbkf_maq_eq in {row['seccion']}")
