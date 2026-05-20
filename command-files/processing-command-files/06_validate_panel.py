"""Validate data/analysis-data/panel_eaae.csv."""

from __future__ import annotations

import csv
import logging
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CONFIG_DIR = PROJECT_ROOT / "command-files" / "config"
sys.path.insert(0, str(CONFIG_DIR))

from eaae_config import CIIU_HOMOLOGATED_MINIMUM_SECTIONS, PANEL_OUTPUT, PANEL_YEARS  # noqa: E402


LOGGER = logging.getLogger(__name__)
FBCF_MISSING_YEARS = {2002, 2011}
STOCK_MISSING_YEARS = {2002, 2011}


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )


def to_float(value: str) -> float | None:
    if value == "":
        return None
    return float(value)


def read_panel(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as file:
        return list(csv.DictReader(file))


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
    path = PROJECT_ROOT / PANEL_OUTPUT
    rows = read_panel(path)
    validate(rows)
    LOGGER.info("Panel validation passed: %s rows", len(rows))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
