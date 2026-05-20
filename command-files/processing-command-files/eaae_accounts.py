"""Shared production-account extraction helpers for the EAAE pipeline."""

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
    EAAE_ACCOUNTS_CONFIG,
    EAAE_CONFIG,
    PANEL_YEARS,
    homologate_ciiu_section,
)


LOGGER = logging.getLogger(__name__)


def find_accounts_member(year: int, members: list[str]) -> str:
    config = EAAE_ACCOUNTS_CONFIG[year]
    pattern = re.compile(str(config["file_pattern"]))
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
            f"Year {year}: expected exactly one accounts XLS matching "
            f"{config['file_pattern']!r}, found {matches}"
        )
    return matches[0]


def read_accounts_source_rows(year: int, xls_path: Path) -> list[dict[str, object]]:
    config = EAAE_ACCOUNTS_CONFIG[year]
    workbook = xlrd.open_workbook(str(xls_path))
    sheet = workbook.sheet_by_index(0)
    detected_start = detect_data_start(sheet)
    configured_start = config["data_start_row"]
    if configured_start is not None and detected_start != configured_start:
        LOGGER.warning(
            "Year %s: detected accounts data_start_row=%s differs from config=%s",
            year,
            detected_start,
            configured_start,
        )

    section_col = int(config["section_col"])
    division_col = config["division_col"]
    impuestos_col = int(config["impuestos_netos_col"])
    consumo_col = int(config["consumo_capital_col"])
    scale = float(config.get("value_scale", 1))

    rows: list[dict[str, object]] = []
    for row_idx in range(detected_start, sheet.nrows):
        section = str(sheet.cell_value(row_idx, section_col)).strip()
        if not re.fullmatch(r"[A-Z]", section):
            continue
        impuestos = to_number(sheet.cell_value(row_idx, impuestos_col))
        consumo = to_number(sheet.cell_value(row_idx, consumo_col))
        row: dict[str, object] = {
            "seccion_fuente": section,
            "impuestos_netos": (
                impuestos * scale if impuestos is not None else None
            ),
            "consumo_capital": consumo * scale if consumo is not None else None,
        }
        if division_col is not None:
            row["division"] = sheet.cell_value(row_idx, int(division_col))
        rows.append(row)

    if not rows:
        raise RuntimeError(f"Year {year}: no accounts rows extracted from {xls_path}")
    return rows


def extract_accounts_year(
    year: int, unrar_bin: str | None = None
) -> list[dict[str, object]]:
    source_config = EAAE_CONFIG[year]
    rar_path = PROJECT_ROOT / DATA_INPUT_EAAE_DIR / source_config["rar_name"]
    if not rar_path.exists():
        raise FileNotFoundError(f"Year {year}: missing RAR file {rar_path}")

    unrar = unrar_bin or find_unrar()
    members = list_archive_members(rar_path, unrar)
    member = find_accounts_member(year, members)
    LOGGER.info("Year %s: extracting accounts from %s", year, member)

    with tempfile.TemporaryDirectory(prefix=f"eaae-accounts-{year}-") as tmpdir:
        xls_path = extract_member(rar_path, member, Path(tmpdir), unrar)
        source_rows = read_accounts_source_rows(year, xls_path)

    version = ciiu_version_for_year(year)
    sums: dict[str, defaultdict[str, float]] = defaultdict(lambda: defaultdict(float))
    present: dict[str, set[str]] = defaultdict(set)
    for row in select_additive_rows(source_rows):
        section = homologate_ciiu_section(str(row["seccion_fuente"]), version)
        for column in ["consumo_capital", "impuestos_netos"]:
            value = row.get(column)
            if value is not None:
                sums[section][column] += float(value)
                present[section].add(column)

    records: list[dict[str, object]] = []
    for section in sorted(sums):
        record: dict[str, object] = {"anno": year, "seccion": section}
        for column in ["consumo_capital", "impuestos_netos"]:
            record[column] = (
                sums[section][column] if column in present[section] else None
            )
        records.append(record)
    return records


def extract_accounts_panel(years: list[int] | None = None) -> list[dict[str, object]]:
    selected_years = years if years is not None else PANEL_YEARS
    unrar = find_unrar()
    records: list[dict[str, object]] = []
    for year in selected_years:
        records.extend(extract_accounts_year(year, unrar))
    return records


def validate_accounts_year(year: int, rows: list[dict[str, object]]) -> None:
    sections = {str(row["seccion"]) for row in rows}
    if not sections.issuperset(CIIU_HOMOLOGATED_MINIMUM_SECTIONS):
        missing = sorted(CIIU_HOMOLOGATED_MINIMUM_SECTIONS - sections)
        raise AssertionError(f"Year {year}: missing accounts sections {missing}")

    for row in rows:
        consumo = row.get("consumo_capital")
        impuestos = row.get("impuestos_netos")
        if consumo is None:
            raise AssertionError(
                f"Year {year}: null consumo_capital in {row['seccion']}"
            )
        if float(consumo) < 0:
            raise AssertionError(
                f"Year {year}: negative consumo_capital in {row['seccion']}"
            )
        if impuestos is None:
            raise AssertionError(
                f"Year {year}: null impuestos_netos in {row['seccion']}"
            )
