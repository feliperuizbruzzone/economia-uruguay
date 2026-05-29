"""Build the preliminary EAAE panel outputs from extracted EAAE variables."""

from __future__ import annotations

import argparse
import csv
import logging
import sys
from pathlib import Path

from eaae_accounts import extract_accounts_panel, validate_accounts_year
from eaae_c1 import extract_c1_panel, validate_extracted_year
from eaae_fbcf import extract_fbcf_panel, validate_fbcf_year
from eaae_stock import extract_stock_panel, validate_stock_year
from eaae_workbook import (
    BRANCH_C_SHEET,
    CHECK_C_SHEET,
    MAIN_SHEET,
    table_from_dicts,
    write_workbook,
)


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CONFIG_DIR = PROJECT_ROOT / "command-files" / "config"
sys.path.insert(0, str(CONFIG_DIR))

from eaae_config import (  # noqa: E402
    PANEL_COLUMNS,
    PANEL_CSV_OUTPUT,
    PANEL_OUTPUTS,
    PANEL_XLSX_OUTPUT,
    PANEL_YEARS,
)


LOGGER = logging.getLogger(__name__)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build dated data/analysis-data/panel_eaae CSV and Excel outputs."
    )
    parser.add_argument(
        "--years",
        nargs="*",
        type=int,
        default=PANEL_YEARS,
        help="Years to include. Defaults to configured panel years.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing panel_eaae outputs for today's date.",
    )
    return parser.parse_args()


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )


def safe_divide(numerator: object, denominator: object) -> float | None:
    if numerator in (None, "") or denominator in (None, "", 0):
        return None
    return float(numerator) / float(denominator)


def add_panel_variables(
    rows: list[dict[str, object]],
    fbcf_rows: list[dict[str, object]],
    accounts_rows: list[dict[str, object]],
    stock_rows: list[dict[str, object]],
) -> list[dict[str, object]]:
    fbcf_by_key = {
        (int(row["anno"]), str(row["seccion"])): row
        for row in fbcf_rows
    }
    accounts_by_key = {
        (int(row["anno"]), str(row["seccion"])): row
        for row in accounts_rows
    }
    stock_by_key = {
        (int(row["anno"]), str(row["seccion"])): row.get("stock_capital")
        for row in stock_rows
    }
    output: list[dict[str, object]] = []
    for row in rows:
        enriched = dict(row)
        # DECISION: Merge FBCF by the final homologated (anno, seccion) key.
        # Years with no published FBCF table, currently 2002 and 2011, remain
        # empty rather than being imputed.
        account_key = (int(row["anno"]), str(row["seccion"]))
        fbcf_row = fbcf_by_key.get(account_key, {})
        enriched["fbcf"] = fbcf_row.get("fbcf")
        enriched["adquisiciones_importadas"] = fbcf_row.get(
            "adquisiciones_importadas"
        )
        account_row = accounts_by_key.get(account_key, {})
        enriched["consumo_capital"] = account_row.get("consumo_capital")
        enriched["impuestos_netos"] = account_row.get("impuestos_netos")
        enriched["stock_capital"] = stock_by_key.get(account_key)
        enriched["excedente_bruto"] = (
            float(row["vab_pp"]) - float(row["remuneraciones"])
            if row.get("vab_pp") is not None and row.get("remuneraciones") is not None
            else None
        )
        enriched["part_salarial"] = safe_divide(
            row.get("remuneraciones"), row.get("vab_pp")
        )
        enriched["productividad"] = safe_divide(
            row.get("vab_pp"), row.get("puestos_trabajo")
        )
        output.append(enriched)
    return output


def build_branch_c_quality_checks(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    checks: list[dict[str, object]] = []
    for row in rows:
        vbp_pp = row.get("vbp_pp")
        vab_pp = row.get("vab_pp")
        remuneraciones = row.get("remuneraciones")
        stock_capital = row.get("stock_capital")
        checks.append(
            {
                "anno": row.get("anno"),
                "vab_vbp": safe_divide(vab_pp, vbp_pp),
                "consumo_intermedio_vbp_menos_vab": (
                    float(vbp_pp) - float(vab_pp)
                    if vbp_pp not in (None, "") and vab_pp not in (None, "")
                    else None
                ),
                "remuneraciones_vab": safe_divide(remuneraciones, vab_pp),
                "stock_vab": safe_divide(stock_capital, vab_pp),
            }
        )
    return checks


def write_panel_csv(rows: list[dict[str, object]], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=PANEL_COLUMNS, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def write_panel_workbook(rows: list[dict[str, object]], output_path: Path) -> None:
    # DECISION: The workbook keeps the full panel and a branch-C review subset
    # in separate sheets so co-investigators can inspect the GitHub artifact
    # without regenerating filtered files.
    branch_c_rows = [row for row in rows if row.get("seccion") == "C"]
    quality_columns = [
        "anno",
        "vab_vbp",
        "consumo_intermedio_vbp_menos_vab",
        "remuneraciones_vab",
        "stock_vab",
    ]
    write_workbook(
        output_path,
        {
            MAIN_SHEET: table_from_dicts(rows, PANEL_COLUMNS),
            BRANCH_C_SHEET: table_from_dicts(branch_c_rows, PANEL_COLUMNS),
            CHECK_C_SHEET: table_from_dicts(
                build_branch_c_quality_checks(branch_c_rows),
                quality_columns,
            ),
        },
    )


def main() -> int:
    configure_logging()
    args = parse_args()
    output_paths = [PROJECT_ROOT / output for output in PANEL_OUTPUTS]
    csv_output_path = PROJECT_ROOT / PANEL_CSV_OUTPUT
    xlsx_output_path = PROJECT_ROOT / PANEL_XLSX_OUTPUT

    if all(path.exists() for path in output_paths) and not args.force:
        LOGGER.info(
            "%s and %s already exist; use --force to rebuild",
            PANEL_CSV_OUTPUT,
            PANEL_XLSX_OUTPUT,
        )
        return 0

    rows = extract_c1_panel(args.years)
    fbcf_rows = extract_fbcf_panel(args.years)
    accounts_rows = extract_accounts_panel(args.years)
    stock_rows = extract_stock_panel(args.years)
    by_year: dict[int, list[dict[str, object]]] = {}
    for row in rows:
        by_year.setdefault(int(row["anno"]), []).append(row)
    for year, year_rows in sorted(by_year.items()):
        validate_extracted_year(year, year_rows)

    fbcf_by_year: dict[int, list[dict[str, object]]] = {}
    for row in fbcf_rows:
        fbcf_by_year.setdefault(int(row["anno"]), []).append(row)
    for year in args.years:
        validate_fbcf_year(year, fbcf_by_year.get(year, []))

    accounts_by_year: dict[int, list[dict[str, object]]] = {}
    for row in accounts_rows:
        accounts_by_year.setdefault(int(row["anno"]), []).append(row)
    for year in args.years:
        validate_accounts_year(year, accounts_by_year.get(year, []))

    stock_by_year: dict[int, list[dict[str, object]]] = {}
    for row in stock_rows:
        stock_by_year.setdefault(int(row["anno"]), []).append(row)
    for year in args.years:
        validate_stock_year(year, stock_by_year.get(year, []))

    panel = add_panel_variables(rows, fbcf_rows, accounts_rows, stock_rows)
    panel.sort(key=lambda row: (int(row["anno"]), str(row["seccion"])))
    write_panel_csv(panel, csv_output_path)
    write_panel_workbook(panel, xlsx_output_path)
    LOGGER.info(
        "Wrote %s rows to %s and %s",
        len(panel),
        PANEL_CSV_OUTPUT,
        PANEL_XLSX_OUTPUT,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
