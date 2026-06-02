"""Validate the final EAAE panel CSV and workbook."""

from __future__ import annotations

import csv
import logging
import statistics
import sys
from pathlib import Path

from eaae_enterprises import expected_enterprise_counts_for_year
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
    CAPITAL_ADVANCE_TURNOVER_FACTORS,
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
    "vab_pb_estimado",
    "consumo_intermedio_estimado",
    "remuneraciones",
    "puestos_trabajo",
    "n_empresas",
    "fbcf",
    "adquisiciones_importadas",
    "consumo_capital_fijo",
    "impuestos_netos",
    "stock_capital",
]
CAPITAL_ADVANCED_COLUMNS = [
    "capital_variable_adelantado",
    "capital_circulante_constante_adelantado",
    "capital_total_adelantado",
]
TOTAL_DERIVED_COLUMNS = [
    "capital_variable_adelantado",
    "capital_circulante_constante_adelantado",
    "capital_total_adelantado",
    "excedente_bruto",
    "part_salarial",
    "productividad",
]
TOTAL_QUALITY_COLUMNS = [
    "vab_vbp",
    "consumo_intermedio_estimado",
    "remuneraciones_vab",
    "stock_vab",
]


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )


def to_float(value: object) -> float | None:
    if value in ("", None):
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
    actual: object,
    expected: float | None,
    context: str,
    tolerance: float = 1e-6,
) -> None:
    if expected is None:
        if actual not in ("", None):
            raise AssertionError(f"{context}: expected blank, got {actual}")
        return
    actual_float = to_float(actual)
    if actual_float is None or abs(actual_float - expected) > tolerance * max(1.0, abs(expected)):
        raise AssertionError(f"{context}: expected {expected}, got {actual}")


def nearly_equal(left: float | None, right: float | None, tolerance: float = 1e-9) -> bool:
    if left is None or right is None:
        return False
    return abs(left - right) <= tolerance * max(1.0, abs(left), abs(right))


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
        add_expected_capital_advanced_values(total)
        totals[year] = total
    return totals


def add_expected_capital_advanced_values(
    row: dict[str, float | str | None]
) -> None:
    row["capital_variable_adelantado"] = None
    row["capital_circulante_constante_adelantado"] = None
    row["capital_total_adelantado"] = None

    factor = CAPITAL_ADVANCE_TURNOVER_FACTORS.get(str(row.get("seccion")))
    if factor in (None, 0):
        return

    remuneraciones = (
        row["remuneraciones"] if isinstance(row.get("remuneraciones"), float) else None
    )
    consumo_intermedio = (
        row["consumo_intermedio_estimado"]
        if isinstance(row.get("consumo_intermedio_estimado"), float)
        else None
    )
    stock_capital = (
        row["stock_capital"] if isinstance(row.get("stock_capital"), float) else None
    )

    if remuneraciones is not None:
        row["capital_variable_adelantado"] = remuneraciones / factor
    if consumo_intermedio is not None:
        row["capital_circulante_constante_adelantado"] = (
            consumo_intermedio / factor
        )
    if (
        stock_capital is not None
        and isinstance(row["capital_variable_adelantado"], float)
        and isinstance(row["capital_circulante_constante_adelantado"], float)
    ):
        row["capital_total_adelantado"] = (
            stock_capital
            + row["capital_variable_adelantado"]
            + row["capital_circulante_constante_adelantado"]
        )


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
            "consumo_intermedio_estimado": (
                row["consumo_intermedio_estimado"]
                if isinstance(row["consumo_intermedio_estimado"], float)
                else None
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


def validate_accounts_column_alignment(year: int, year_rows: list[dict[str, str]]) -> None:
    consumo_vab_pairs: list[tuple[float, float]] = []
    impuestos_vab_pairs: list[tuple[float, float]] = []
    consumo_rem_pairs: list[tuple[float, float]] = []
    consumo_vab_ratios: list[float] = []

    for row in year_rows:
        consumo = to_float(row["consumo_capital_fijo"])
        impuestos = to_float(row["impuestos_netos"])
        vab = to_float(row["vab_pp"])
        remuneraciones = to_float(row["remuneraciones"])
        if consumo is not None and vab not in (None, 0):
            consumo_vab_pairs.append((consumo, vab))
            consumo_vab_ratios.append(consumo / vab)
        if impuestos is not None and vab is not None:
            impuestos_vab_pairs.append((impuestos, vab))
        if consumo is not None and remuneraciones is not None:
            consumo_rem_pairs.append((consumo, remuneraciones))

    if consumo_vab_pairs and all(
        nearly_equal(consumo, vab) for consumo, vab in consumo_vab_pairs
    ):
        raise AssertionError(
            f"Year {year}: consumo_capital_fijo equals vab_pp in every section; "
            "probable accounts column misalignment"
        )
    if impuestos_vab_pairs and all(
        nearly_equal(impuestos, vab) for impuestos, vab in impuestos_vab_pairs
    ):
        raise AssertionError(
            f"Year {year}: impuestos_netos equals vab_pp in every section; "
            "probable accounts column misalignment"
        )
    if consumo_rem_pairs and all(
        nearly_equal(consumo, remuneraciones)
        for consumo, remuneraciones in consumo_rem_pairs
    ):
        raise AssertionError(
            f"Year {year}: consumo_capital_fijo equals remuneraciones in every section; "
            "probable accounts column misalignment"
        )
    if consumo_vab_ratios:
        median_ratio = statistics.median(consumo_vab_ratios)
        if median_ratio > 0.4:
            LOGGER.warning(
                "Year %s: median consumo_capital_fijo/vab_pp is high: %.3f",
                year,
                median_ratio,
            )


def validate_manufacturing_capital_consumption_bridge(
    rows: list[dict[str, str]]
) -> None:
    branch_c_by_year = {
        int(row["anno"]): row for row in rows if row["seccion"] == "C"
    }
    required_years = [2005, 2006, 2007, 2008]
    missing = [year for year in required_years if year not in branch_c_by_year]
    if missing:
        raise AssertionError(
            f"Manufacturing capital-consumption bridge missing years {missing}"
        )

    ratios: dict[int, float] = {}
    for year in required_years:
        row = branch_c_by_year[year]
        consumo = to_float(row["consumo_capital_fijo"])
        vab = to_float(row["vab_pp"])
        if consumo is None or vab in (None, 0):
            raise AssertionError(
                f"Year {year}: cannot validate manufacturing consumo_capital_fijo"
            )
        ratios[year] = consumo / vab

    benchmark_low = 0.5 * min(ratios[2005], ratios[2008])
    benchmark_high = 1.5 * max(ratios[2005], ratios[2008])
    for year in [2006, 2007]:
        ratio = ratios[year]
        # DECISION: 2006-2007 C2 layouts put VAB in column 7 and consumption of
        # fixed capital in column 6. If the wrong column is read, the ratio
        # consumo_capital_fijo/vab_pp approaches 1. The 2005/2008 envelope keeps
        # the check tied to neighboring observed years without hardcoding values.
        if ratio < benchmark_low or ratio > benchmark_high or ratio > 0.5:
            raise AssertionError(
                "Manufacturing consumo_capital_fijo anomaly in "
                f"{year}: ratio consumo/vab={ratio:.3f}, "
                f"expected between {benchmark_low:.3f} and {benchmark_high:.3f}; "
                "probable C2 column misalignment"
            )


def validate_estimated_vab_pb(rows: list[dict[str, str]]) -> None:
    ratios_by_section: dict[str, tuple[int, float]] = {}
    for row in sorted(rows, key=lambda value: (value["seccion"], int(value["anno"]))):
        section = row["seccion"]
        observed = to_float(row["vab_pb"])
        vab_pp = to_float(row["vab_pp"])
        if section not in ratios_by_section and observed is not None and vab_pp not in (None, 0):
            ratios_by_section[section] = (int(row["anno"]), observed / vab_pp)

    for row in rows:
        year = int(row["anno"])
        section = row["seccion"]
        estimate = to_float(row["vab_pb_estimado"])
        if estimate is None:
            raise AssertionError(
                f"Year {year}: null vab_pb_estimado in {section}"
            )
        observed = to_float(row["vab_pb"])
        if year >= 2017:
            assert_close(
                row["vab_pb_estimado"],
                observed,
                f"Year {year}: vab_pb_estimado must equal observed vab_pb in {section}",
            )
            continue

        anchor = ratios_by_section.get(section)
        if anchor is None:
            raise AssertionError(
                f"Year {year}: no observed VAB(pb) anchor for {section}"
            )
        anchor_year, anchor_ratio = anchor
        vab_pp = to_float(row["vab_pp"])
        expected = (
            vab_pp * anchor_ratio
            if year < anchor_year and vab_pp is not None
            else observed
        )
        assert_close(
            row["vab_pb_estimado"],
            expected,
            f"Year {year}: invalid backcasted vab_pb_estimado in {section}",
        )


def validate_estimated_intermediate_consumption(rows: list[dict[str, str]]) -> None:
    for row in rows:
        year = int(row["anno"])
        section = row["seccion"]
        vbp_pp = to_float(row["vbp_pp"])
        vab_pb_estimado = to_float(row["vab_pb_estimado"])
        if vbp_pp is None or vab_pb_estimado is None:
            raise AssertionError(
                f"Year {year}: missing inputs for consumo_intermedio_estimado "
                f"in {section}"
            )
        expected = vbp_pp - vab_pb_estimado
        assert_close(
            row["consumo_intermedio_estimado"],
            expected,
            f"Year {year}: invalid consumo_intermedio_estimado in {section}",
        )
        actual = to_float(row["consumo_intermedio_estimado"])
        if actual is not None and actual < 0:
            raise AssertionError(
                f"Year {year}: negative consumo_intermedio_estimado in {section}"
            )


def validate_capital_advanced_variables(rows: list[dict[str, str]]) -> None:
    for row in rows:
        year = int(row["anno"])
        section = row["seccion"]
        factor = CAPITAL_ADVANCE_TURNOVER_FACTORS.get(section)
        if factor in (None, 0):
            for column in CAPITAL_ADVANCED_COLUMNS:
                assert_close(
                    row[column],
                    None,
                    f"Year {year}: {column} must be blank without turnover factor in {section}",
                )
            continue

        remuneraciones = to_float(row["remuneraciones"])
        consumo_intermedio = to_float(row["consumo_intermedio_estimado"])
        stock_capital = to_float(row["stock_capital"])
        expected_variable = (
            remuneraciones / factor if remuneraciones is not None else None
        )
        expected_circulante = (
            consumo_intermedio / factor
            if consumo_intermedio is not None
            else None
        )
        expected_total = (
            stock_capital + expected_variable + expected_circulante
            if (
                stock_capital is not None
                and expected_variable is not None
                and expected_circulante is not None
            )
            else None
        )
        assert_close(
            row["capital_variable_adelantado"],
            expected_variable,
            f"Year {year}: invalid capital_variable_adelantado in {section}",
        )
        assert_close(
            row["capital_circulante_constante_adelantado"],
            expected_circulante,
            f"Year {year}: invalid capital_circulante_constante_adelantado in {section}",
        )
        assert_close(
            row["capital_total_adelantado"],
            expected_total,
            f"Year {year}: invalid capital_total_adelantado in {section}",
        )


def validate_enterprise_counts(rows: list[dict[str, str]]) -> None:
    expected_by_year = {
        year: expected_enterprise_counts_for_year(year)
        for year in sorted({int(row["anno"]) for row in rows})
    }
    for row in rows:
        year = int(row["anno"])
        section = row["seccion"]
        actual = to_float(row["n_empresas"])
        expected = expected_by_year.get(year, {}).get(section)
        assert_close(
            row["n_empresas"],
            float(expected) if expected is not None else None,
            f"Year {year}: invalid n_empresas in {section}",
        )
        if actual is not None:
            if actual < 0:
                raise AssertionError(
                    f"Year {year}: negative n_empresas in {section}"
                )
            if not actual.is_integer():
                raise AssertionError(
                    f"Year {year}: non-integer n_empresas in {section}"
                )


def validate(rows: list[dict[str, str]]) -> None:
    years = sorted({int(row["anno"]) for row in rows})
    if years != PANEL_YEARS:
        raise AssertionError(f"Panel years mismatch: expected {PANEL_YEARS}, got {years}")

    keys = [(row["anno"], row["seccion"]) for row in rows]
    if len(keys) != len(set(keys)):
        raise AssertionError("Panel has duplicated (anno, seccion) rows")

    validate_estimated_vab_pb(rows)
    validate_estimated_intermediate_consumption(rows)
    validate_capital_advanced_variables(rows)
    validate_enterprise_counts(rows)
    validate_manufacturing_capital_consumption_bridge(rows)

    by_year: dict[int, list[dict[str, str]]] = {}
    for row in rows:
        by_year.setdefault(int(row["anno"]), []).append(row)

    totals: dict[int, float] = {}
    for year, year_rows in sorted(by_year.items()):
        validate_accounts_column_alignment(year, year_rows)
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
            consumo_capital_fijo = to_float(row["consumo_capital_fijo"])
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
            if consumo_capital_fijo is None:
                raise AssertionError(
                    f"Year {year}: null consumo_capital_fijo in {row['seccion']}"
                )
            if consumo_capital_fijo < 0:
                raise AssertionError(
                    f"Year {year}: negative consumo_capital_fijo in {row['seccion']}"
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
