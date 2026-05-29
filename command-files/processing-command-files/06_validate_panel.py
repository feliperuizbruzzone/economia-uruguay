"""Validate the final EAAE panel CSV and workbook."""

from __future__ import annotations

import csv
import logging
import sys
from pathlib import Path

from eaae_workbook import (
    CHECK_TOTAL_SHEET,
    MAIN_SHEET,
    TOTAL_ECONOMY_SHEET,
    read_sheet_as_dicts,
)

PROJECT_ROOT = Path(__file__).resolve().parents[2]
CONFIG_DIR = PROJECT_ROOT / "command-files" / "config"
sys.path.insert(0, str(CONFIG_DIR))

from eaae_config import (  # noqa: E402
    CIIU_HOMOLOGATED_MINIMUM_SECTIONS,
    PANEL_CSV_OUTPUT,
    PANEL_XLSX_OUTPUT,
    PANEL_YEARS,
)


LOGGER = logging.getLogger(__name__)
FBCF_MISSING_YEARS = {2002, 2011}
STOCK_MISSING_YEARS = {2002, 2011}
TOTAL_ADDITIVE_COLUMNS = [
    "vbp_pp",
    "vbp_pb",
    "vab_pp",
    "vab_pb",
    "remuneraciones",
    "puestos_trabajo",
    "fbcf",
    "adquisiciones_importadas",
    "consumo_capital",
    "impuestos_netos",
    "stock_capital",
]
TOTAL_DERIVED_COLUMNS = ["excedente_bruto", "part_salarial", "productividad"]
TOTAL_QUALITY_COLUMNS = [
    "vab_vbp",
    "consumo_intermedio_vbp_menos_vab",
    "remuneraciones_vab",
    "stock_vab",
]


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )


def to_float(value: str) -> float | None:
    if value == "":
        return None
    return float(value)


def safe_divide(numerator: float | None, denominator: float | None) -> float | None:
    if numerator is None or denominator in (None, 0):
        return None
    return numerator / denominator


def sum_present(values: list[str]) -> float | None:
    present = [float(value) for value in values if value != ""]
    if not present:
        return None
    return sum(present)


def assert_close(
    actual: str,
    expected: float | None,
    context: str,
    tolerance: float = 1e-6,
) -> None:
    if expected is None:
        if actual != "":
            raise AssertionError(f"{context}: expected blank, got {actual}")
        return
    actual_float = to_float(actual)
    if actual_float is None or abs(actual_float - expected) > tolerance * max(1.0, abs(expected)):
        raise AssertionError(f"{context}: expected {expected}, got {actual}")


def read_panel(path: Path) -> list[dict[str, str]]:
    return read_sheet_as_dicts(path, MAIN_SHEET)


def read_panel_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as file:
        return list(csv.DictReader(file))


def expected_economy_totals(rows: list[dict[str, str]]) -> dict[int, dict[str, float | str | None]]:
    by_year: dict[int, list[dict[str, str]]] = {}
    for row in rows:
        by_year.setdefault(int(row["anno"]), []).append(row)

    totals: dict[int, dict[str, float | str | None]] = {}
    for year, year_rows in sorted(by_year.items()):
        epocas = sorted({row["epoca"] for row in year_rows if row["epoca"] != ""})
        ciiu_versions = sorted(
            {row["ciiu_version"] for row in year_rows if row["ciiu_version"] != ""}
        )
        total: dict[str, float | str | None] = {
            "seccion": "economia_total",
            "epoca": epocas[0] if len(epocas) == 1 else "|".join(epocas),
            "ciiu_version": ciiu_versions[0] if len(ciiu_versions) == 1 else "|".join(ciiu_versions),
        }
        for column in TOTAL_ADDITIVE_COLUMNS:
            total[column] = sum_present([row[column] for row in year_rows])
        vab_pp = total["vab_pp"] if isinstance(total["vab_pp"], float) else None
        remuneraciones = (
            total["remuneraciones"] if isinstance(total["remuneraciones"], float) else None
        )
        puestos = total["puestos_trabajo"] if isinstance(total["puestos_trabajo"], float) else None
        total["excedente_bruto"] = (
            vab_pp - remuneraciones
            if vab_pp is not None and remuneraciones is not None
            else None
        )
        total["part_salarial"] = safe_divide(remuneraciones, vab_pp)
        total["productividad"] = safe_divide(vab_pp, puestos)
        totals[year] = total
    return totals


def expected_quality_checks(
    total_rows_by_year: dict[int, dict[str, float | str | None]]
) -> dict[int, dict[str, float | None]]:
    checks: dict[int, dict[str, float | None]] = {}
    for year, row in total_rows_by_year.items():
        vbp_pp = row["vbp_pp"] if isinstance(row["vbp_pp"], float) else None
        vab_pp = row["vab_pp"] if isinstance(row["vab_pp"], float) else None
        remuneraciones = (
            row["remuneraciones"] if isinstance(row["remuneraciones"], float) else None
        )
        stock_capital = row["stock_capital"] if isinstance(row["stock_capital"], float) else None
        checks[year] = {
            "vab_vbp": safe_divide(vab_pp, vbp_pp),
            "consumo_intermedio_vbp_menos_vab": (
                vbp_pp - vab_pp if vbp_pp is not None and vab_pp is not None else None
            ),
            "remuneraciones_vab": safe_divide(remuneraciones, vab_pp),
            "stock_vab": safe_divide(stock_capital, vab_pp),
        }
    return checks


def validate_total_workbook_sheets(
    panel_rows: list[dict[str, str]],
    total_rows: list[dict[str, str]],
    check_rows: list[dict[str, str]],
) -> None:
    expected_totals = expected_economy_totals(panel_rows)
    total_by_year = {int(row["anno"]): row for row in total_rows}
    if sorted(total_by_year) != PANEL_YEARS:
        raise AssertionError("Workbook economia_total years mismatch")
    for year, expected in expected_totals.items():
        actual = total_by_year[year]
        if actual["seccion"] != expected["seccion"]:
            raise AssertionError(f"Year {year}: invalid economia_total seccion")
        if actual["epoca"] != str(expected["epoca"]):
            raise AssertionError(f"Year {year}: invalid economia_total epoca")
        if actual["ciiu_version"] != str(expected["ciiu_version"]):
            raise AssertionError(f"Year {year}: invalid economia_total ciiu_version")
        for column in TOTAL_ADDITIVE_COLUMNS + TOTAL_DERIVED_COLUMNS:
            value = expected[column]
            assert_close(
                actual[column],
                value if isinstance(value, float) else None,
                f"Year {year}: economia_total {column}",
            )

    expected_checks = expected_quality_checks(expected_totals)
    check_by_year = {int(row["anno"]): row for row in check_rows}
    if sorted(check_by_year) != PANEL_YEARS:
        raise AssertionError("Workbook check-calidad-total years mismatch")
    for year, expected in expected_checks.items():
        actual = check_by_year[year]
        for column in TOTAL_QUALITY_COLUMNS:
            assert_close(
                actual[column],
                expected[column],
                f"Year {year}: check-calidad-total {column}",
            )


def validate(rows: list[dict[str, str]]) -> None:
    years = sorted({int(row["anno"]) for row in rows})
    if years != PANEL_YEARS:
        raise AssertionError(f"Panel years mismatch: expected {PANEL_YEARS}, got {years}")

    keys = [(row["anno"], row["seccion"]) for row in rows]
    if len(keys) != len(set(keys)):
        raise AssertionError("Panel has duplicated (anno, seccion) rows")

    by_year: dict[int, list[dict[str, str]]] = {}
    for row in rows:
        by_year.setdefault(int(row["anno"]), []).append(row)

    totals: dict[int, float] = {}
    for year, year_rows in sorted(by_year.items()):
        sections = {row["seccion"] for row in year_rows}
        if len(sections) < 6:
            raise AssertionError(f"Year {year}: only {len(sections)} sections")
        if year >= 2001 and not sections.issuperset(CIIU_HOMOLOGATED_MINIMUM_SECTIONS):
            missing = sorted(CIIU_HOMOLOGATED_MINIMUM_SECTIONS - sections)
            raise AssertionError(f"Year {year}: missing sections {missing}")

        total = 0.0
        for row in year_rows:
            vbp_pp = to_float(row["vbp_pp"])
            vbp_pb = to_float(row["vbp_pb"])
            vab_pp = to_float(row["vab_pp"])
            vab_pb = to_float(row["vab_pb"])
            remuneraciones = to_float(row["remuneraciones"])
            puestos = to_float(row["puestos_trabajo"])
            fbcf = to_float(row["fbcf"])
            adquisiciones_importadas = to_float(row["adquisiciones_importadas"])
            consumo_capital = to_float(row["consumo_capital"])
            impuestos_netos = to_float(row["impuestos_netos"])
            stock_capital = to_float(row["stock_capital"])
            if None in (vbp_pp, vab_pp, remuneraciones, puestos):
                raise AssertionError(f"Year {year}: null key value in {row['seccion']}")
            if vbp_pp < vab_pp:
                raise AssertionError(f"Year {year}: vbp_pp < vab_pp in {row['seccion']}")
            if vab_pp < remuneraciones:
                LOGGER.warning(
                    "Year %s: vab_pp < remuneraciones in %s",
                    year,
                    row["seccion"],
                )
            if puestos <= 0:
                raise AssertionError(
                    f"Year {year}: puestos_trabajo <= 0 in {row['seccion']}"
                )
            if year < 2017 and row["vab_pb"] != "":
                raise AssertionError(f"Year {year}: unexpected vab_pb before 2017")
            if year < 2017 and row["vbp_pb"] != "":
                raise AssertionError(f"Year {year}: unexpected vbp_pb before 2017")
            if year >= 2017:
                if vbp_pb is None:
                    raise AssertionError(f"Year {year}: null vbp_pb in {row['seccion']}")
                if vab_pb is None:
                    raise AssertionError(f"Year {year}: null vab_pb in {row['seccion']}")
                if vbp_pb < vab_pb:
                    raise AssertionError(f"Year {year}: vbp_pb < vab_pb in {row['seccion']}")
            if year in FBCF_MISSING_YEARS:
                if row["fbcf"] != "":
                    raise AssertionError(f"Year {year}: unexpected FBCF value")
                if row["adquisiciones_importadas"] != "":
                    raise AssertionError(
                        f"Year {year}: unexpected adquisiciones_importadas value"
                    )
            else:
                if fbcf is None:
                    raise AssertionError(f"Year {year}: null FBCF in {row['seccion']}")
                if fbcf < 0:
                    raise AssertionError(
                        f"Year {year}: negative FBCF in {row['seccion']}"
                    )
                if adquisiciones_importadas is None:
                    raise AssertionError(
                        f"Year {year}: null adquisiciones_importadas in {row['seccion']}"
                    )
                if adquisiciones_importadas < 0:
                    raise AssertionError(
                        f"Year {year}: negative adquisiciones_importadas in {row['seccion']}"
                    )
            if consumo_capital is None:
                raise AssertionError(
                    f"Year {year}: null consumo_capital in {row['seccion']}"
                )
            if consumo_capital < 0:
                raise AssertionError(
                    f"Year {year}: negative consumo_capital in {row['seccion']}"
                )
            if impuestos_netos is None:
                raise AssertionError(
                    f"Year {year}: null impuestos_netos in {row['seccion']}"
                )
            if year in STOCK_MISSING_YEARS:
                if row["stock_capital"] != "":
                    raise AssertionError(
                        f"Year {year}: unexpected stock_capital value"
                    )
            else:
                if stock_capital is None:
                    raise AssertionError(
                        f"Year {year}: null stock_capital in {row['seccion']}"
                    )
                if stock_capital < 0:
                    raise AssertionError(
                        f"Year {year}: negative stock_capital in {row['seccion']}"
                    )
            total += vab_pp
        totals[year] = total

    previous_year: int | None = None
    previous_total: float | None = None
    for year in sorted(totals):
        if previous_total:
            variation = abs(totals[year] / previous_total - 1)
            if variation > 0.5:
                LOGGER.warning(
                    "VAB total variation > 50%% between %s and %s: %.2f%%",
                    previous_year,
                    year,
                    variation * 100,
                )
        previous_year = year
        previous_total = totals[year]


def main() -> int:
    configure_logging()
    xlsx_path = PROJECT_ROOT / PANEL_XLSX_OUTPUT
    csv_path = PROJECT_ROOT / PANEL_CSV_OUTPUT

    xlsx_rows = read_panel(xlsx_path)
    validate(xlsx_rows)
    LOGGER.info("Workbook validation passed: %s rows", len(xlsx_rows))

    validate_total_workbook_sheets(
        xlsx_rows,
        read_sheet_as_dicts(xlsx_path, TOTAL_ECONOMY_SHEET),
        read_sheet_as_dicts(xlsx_path, CHECK_TOTAL_SHEET),
    )
    LOGGER.info("Workbook total economy sheets validation passed")

    csv_rows = read_panel_csv(csv_path)
    validate(csv_rows)
    LOGGER.info("CSV validation passed: %s rows", len(csv_rows))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
