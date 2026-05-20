"""Shared FBCF extraction helpers for the EAAE pipeline."""

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
    EAAE_FBCF_CONFIG,
    PANEL_YEARS,
    homologate_ciiu_section,
)


LOGGER = logging.getLogger(__name__)


def find_fbcf_member(year: int, members: list[str]) -> str | None:
    config = EAAE_FBCF_CONFIG[year]
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
            f"Year {year}: expected exactly one FBCF XLS matching "
            f"{pattern_value!r}, found {matches}"
        )
    return matches[0]


def read_fbcf_source_rows(year: int, xls_path: Path) -> list[dict[str, object]]:
    config = EAAE_FBCF_CONFIG[year]
    workbook = xlrd.open_workbook(str(xls_path))
    sheet = workbook.sheet_by_index(0)
    detected_start = detect_data_start(sheet)
    configured_start = config["data_start_row"]
    if configured_start is not None and detected_start != configured_start:
        LOGGER.warning(
            "Year %s: detected FBCF data_start_row=%s differs from config=%s",
            year,
            detected_start,
            configured_start,
        )

    section_col = int(config["section_col"])
    division_col = config["division_col"]
    fbcf_col = int(config["fbcf_col"])
    adquisiciones_importadas_col = int(config["adquisiciones_importadas_col"])
    scale = float(config.get("value_scale", 1))

    rows: list[dict[str, object]] = []
    for row_idx in range(detected_start, sheet.nrows):
        section = str(sheet.cell_value(row_idx, section_col)).strip()
        if not re.fullmatch(r"[A-Z]", section):
            continue
        fbcf = to_number(sheet.cell_value(row_idx, fbcf_col))
        importadas = to_number(sheet.cell_value(row_idx, adquisiciones_importadas_col))
        row: dict[str, object] = {
            "seccion_fuente": section,
            "fbcf": fbcf * scale if fbcf is not None else None,
            # DECISION: In FBCF component tables, "-" in component columns means
            # zero value for that acquisition channel, not a missing source.
            "adquisiciones_importadas": (
                (importadas if importadas is not None else 0.0) * scale
            ),
        }
        if division_col is not None:
            row["division"] = sheet.cell_value(row_idx, int(division_col))
        rows.append(row)

    if not rows:
        raise RuntimeError(f"Year {year}: no FBCF rows extracted from {xls_path}")
    return rows


def extract_fbcf_year(
    year: int, unrar_bin: str | None = None
) -> list[dict[str, object]]:
    source_config = EAAE_CONFIG[year]
    fbcf_config = EAAE_FBCF_CONFIG[year]
    if fbcf_config["file_pattern"] is None:
        LOGGER.info("Year %s: no configured FBCF source; leaving fbcf empty", year)
        return []

    rar_path = PROJECT_ROOT / DATA_INPUT_EAAE_DIR / source_config["rar_name"]
    if not rar_path.exists():
        raise FileNotFoundError(f"Year {year}: missing RAR file {rar_path}")

    unrar = unrar_bin or find_unrar()
    members = list_archive_members(rar_path, unrar)
    member = find_fbcf_member(year, members)
    if member is None:
        return []
    LOGGER.info("Year %s: extracting FBCF from %s", year, member)

    with tempfile.TemporaryDirectory(prefix=f"eaae-fbcf-{year}-") as tmpdir:
        xls_path = extract_member(rar_path, member, Path(tmpdir), unrar)
        source_rows = read_fbcf_source_rows(year, xls_path)

    version = ciiu_version_for_year(year)
    sums: dict[str, defaultdict[str, float]] = defaultdict(lambda: defaultdict(float))
    present: dict[str, set[str]] = defaultdict(set)
    for row in select_additive_rows(source_rows):
        section = homologate_ciiu_section(str(row["seccion_fuente"]), version)
        for column in ["fbcf", "adquisiciones_importadas"]:
            value = row.get(column)
            if value is not None:
                sums[section][column] += float(value)
                present[section].add(column)

    records: list[dict[str, object]] = []
    for section in sorted(sums):
        record: dict[str, object] = {"anno": year, "seccion": section}
        for column in ["fbcf", "adquisiciones_importadas"]:
            record[column] = (
                sums[section][column] if column in present[section] else None
            )
        records.append(record)
    return records


def extract_fbcf_panel(years: list[int] | None = None) -> list[dict[str, object]]:
    selected_years = years if years is not None else PANEL_YEARS
    unrar = find_unrar()
    records: list[dict[str, object]] = []
    for year in selected_years:
        records.extend(extract_fbcf_year(year, unrar))
    return records


def validate_fbcf_year(year: int, rows: list[dict[str, object]]) -> None:
    if year in {2002, 2011}:
        if rows:
            raise AssertionError(f"Year {year}: unexpected FBCF rows")
        return

    sections = {str(row["seccion"]) for row in rows}
    if not sections.issuperset(CIIU_HOMOLOGATED_MINIMUM_SECTIONS):
        missing = sorted(CIIU_HOMOLOGATED_MINIMUM_SECTIONS - sections)
        raise AssertionError(f"Year {year}: missing FBCF sections {missing}")

    for row in rows:
        value = row.get("fbcf")
        importadas = row.get("adquisiciones_importadas")
        if value is None:
            raise AssertionError(f"Year {year}: null FBCF in {row['seccion']}")
        if float(value) < 0:
            raise AssertionError(f"Year {year}: negative FBCF in {row['seccion']}")
        if importadas is None:
            raise AssertionError(
                f"Year {year}: null adquisiciones_importadas in {row['seccion']}"
            )
        if float(importadas) < 0:
            raise AssertionError(
                f"Year {year}: negative adquisiciones_importadas in {row['seccion']}"
            )
