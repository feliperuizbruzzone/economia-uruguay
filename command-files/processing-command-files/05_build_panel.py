"""Build the preliminary EAAE panel outputs from extracted EAAE variables."""

from __future__ import annotations

import argparse
import csv
import logging
import sys
from pathlib import Path

from eaae_accounts import extract_accounts_panel, validate_accounts_year
from eaae_c1 import extract_c1_panel, validate_extracted_year
from eaae_enterprises import extract_enterprise_counts_panel
from eaae_fbcf import extract_fbcf_panel, validate_fbcf_year
from eaae_fbkf_maq_eq import extract_fbkf_maq_eq_panel, validate_fbkf_maq_eq_year
from eaae_stock import extract_stock_panel, validate_stock_year
from eaae_workbook import (
    BRANCH_C_SHEET,
    CHECK_C_SHEET,
    CHECK_TOTAL_SHEET,
    MAIN_SHEET,
    TOTAL_ECONOMY_SHEET,
    table_from_dicts,
    write_workbook,
)


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CONFIG_DIR = PROJECT_ROOT / "command-files" / "config"
sys.path.insert(0, str(CONFIG_DIR))

from eaae_config import (  # noqa: E402
    CAPITAL_ADVANCE_TURNOVER_FACTORS,
    PANEL_COLUMNS,
    PANEL_CSV_OUTPUT,
    PANEL_OUTPUTS,
    PANEL_XLSX_OUTPUT,
    PANEL_YEARS,
    STOCK_CAPITAL_IMPUTATION_WINDOWS,
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


def sum_present(values: list[object]) -> float | None:
    present = [float(value) for value in values if value not in (None, "")]
    if not present:
        return None
    return sum(present)


def sum_required(values: list[object]) -> float | None:
    if any(value in (None, "") for value in values):
        return None
    return sum(float(value) for value in values)


def add_panel_variables(
    rows: list[dict[str, object]],
    fbcf_rows: list[dict[str, object]],
    fbkf_maq_eq_rows: list[dict[str, object]],
    accounts_rows: list[dict[str, object]],
    stock_rows: list[dict[str, object]],
    enterprise_count_rows: list[dict[str, object]],
) -> list[dict[str, object]]:
    fbcf_by_key = {
        (int(row["anno"]), str(row["seccion"])): row
        for row in fbcf_rows
    }
    fbkf_maq_eq_by_key = {
        (int(row["anno"]), str(row["seccion"])): row.get("fbkf_maq_eq")
        for row in fbkf_maq_eq_rows
    }
    accounts_by_key = {
        (int(row["anno"]), str(row["seccion"])): row
        for row in accounts_rows
    }
    stock_by_key = {
        (int(row["anno"]), str(row["seccion"])): row.get("stock_capital")
        for row in stock_rows
    }
    enterprise_counts_by_key = {
        (int(row["anno"]), str(row["seccion"])): row.get("n_empresas")
        for row in enterprise_count_rows
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
        enriched["fbkf_maq_eq"] = fbkf_maq_eq_by_key.get(account_key)
        enriched["adquisiciones_importadas"] = fbcf_row.get(
            "adquisiciones_importadas"
        )
        enriched["adquisiciones_origen_importado"] = fbcf_row.get(
            "adquisiciones_origen_importado"
        )
        # DECISION: `importaciones_maquinaria` is the broader imported capital
        # acquisition measure requested by the team: direct imported
        # acquisitions plus in-plaza acquisitions of imported origin. If the
        # source lacks the origin-imported split, keep the sum empty rather
        # than treating the missing component as zero.
        enriched["importaciones_maquinaria"] = sum_required(
            [
                enriched["adquisiciones_importadas"],
                enriched["adquisiciones_origen_importado"],
            ]
        )
        account_row = accounts_by_key.get(account_key, {})
        enriched["consumo_capital_fijo"] = account_row.get("consumo_capital")
        enriched["impuestos_netos"] = account_row.get("impuestos_netos")
        enriched["stock_capital"] = stock_by_key.get(account_key)
        # DECISION: `n_empresas` is merged only when the methodology PDF
        # provides exact represented-enterprise counts at source section level.
        # Years or sections not supported by the PDF evidence remain empty.
        enriched["n_empresas"] = enterprise_counts_by_key.get(account_key)
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


def add_estimated_vab_pb(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    rows_by_section: dict[str, list[dict[str, object]]] = {}
    for row in rows:
        rows_by_section.setdefault(str(row["seccion"]), []).append(row)

    for section_rows in rows_by_section.values():
        section_rows.sort(key=lambda row: int(row["anno"]))
        first_observed_year: int | None = None
        first_observed_ratio: float | None = None
        for row in section_rows:
            observed = row.get("vab_pb")
            if observed not in (None, ""):
                vab_pp = row.get("vab_pp")
                if vab_pp not in (None, "", 0):
                    first_observed_year = int(row["anno"])
                    first_observed_ratio = float(observed) / float(vab_pp)
                    break

        # DECISION: Provisional team rule, June 2026. Before the first observed
        # VAB(pb), backcast by preserving the annual variation of VAB(pp):
        # vab_pb_est[t-1] = vab_pb_est[t] / (vab_pp[t] / vab_pp[t-1]). This is
        # algebraically equivalent to applying the first observed VAB(pb)/VAB(pp)
        # ratio to previous VAB(pp), and handles sections with missing years.
        for row in section_rows:
            year = int(row["anno"])
            observed = row.get("vab_pb")
            if observed not in (None, ""):
                row["vab_pb_estimado"] = float(observed)
                continue
            vab_pp = row.get("vab_pp")
            if (
                first_observed_year is not None
                and year < first_observed_year
                and first_observed_ratio is not None
                and vab_pp not in (None, "")
            ):
                row["vab_pb_estimado"] = float(vab_pp) * first_observed_ratio

    return rows


def add_estimated_intermediate_consumption(
    rows: list[dict[str, object]]
) -> list[dict[str, object]]:
    for row in rows:
        vbp_pp = row.get("vbp_pp")
        vab_pb_estimado = row.get("vab_pb_estimado")
        if vbp_pp in (None, "") or vab_pb_estimado in (None, ""):
            continue
        # DECISION: Provisional team rule, June 2026. Estimate intermediate
        # consumption as VBP at producer prices minus the observed/backcasted
        # VAB at basic prices. Keep the suffix `_estimado` because this mixes
        # valuation concepts and depends on `vab_pb_estimado` before 2017.
        row["consumo_intermedio_estimado"] = (
            float(vbp_pp) - float(vab_pb_estimado)
        )
    return rows


def stock_capital_imputation_factor_pct(
    rows: list[dict[str, object]],
    target_year: int,
    section: str,
) -> float | None:
    window = STOCK_CAPITAL_IMPUTATION_WINDOWS.get(target_year)
    if window is None:
        return None
    start_year, end_year = window
    ratios_pct: list[float] = []
    for row in rows:
        if str(row.get("seccion")) != section:
            continue
        year = int(row["anno"])
        if year < start_year or year > end_year:
            continue
        stock_capital = row.get("stock_capital")
        consumo_capital = row.get("consumo_capital_fijo")
        if stock_capital in (None, "") or consumo_capital in (None, "", 0):
            continue
        ratios_pct.append((float(stock_capital) / float(consumo_capital)) * 100)
    if not ratios_pct:
        return None
    return sum(ratios_pct) / len(ratios_pct)


def add_stock_capital_imputation(
    rows: list[dict[str, object]]
) -> list[dict[str, object]]:
    for row in rows:
        row["stock_capital_imputado"] = row.get("stock_capital")

        stock_capital = row.get("stock_capital")
        if stock_capital not in (None, ""):
            continue

        year = int(row["anno"])
        section = str(row.get("seccion"))
        factor_pct = stock_capital_imputation_factor_pct(rows, year, section)
        consumo_capital = row.get("consumo_capital_fijo")
        if factor_pct in (None, 0) or consumo_capital in (None, ""):
            continue

        # DECISION: Provisional team rule, June 2026. Keep only two stock
        # columns: `stock_capital` as the original source value and
        # `stock_capital_imputado` as the operative stock series. The operative
        # series copies the original stock when available; when missing but
        # fixed-capital consumption exists, it imputes the stock from the
        # historical same-section stock/consumption ratio. The factor is stored
        # conceptually as a percentage, so the formula is consumo_capital_fijo *
        # (factor_pct / 100).
        imputed = float(consumo_capital) * (float(factor_pct) / 100)
        row["stock_capital_imputado"] = imputed

    return rows


def add_capital_advanced_variables(
    rows: list[dict[str, object]]
) -> list[dict[str, object]]:
    for row in rows:
        row["capital_variable_adelantado"] = None
        row["capital_circulante_constante_adelantado"] = None
        row["capital_total_adelantado"] = None

        factor = CAPITAL_ADVANCE_TURNOVER_FACTORS.get(str(row.get("seccion")))
        if factor in (None, 0):
            continue

        remuneraciones = row.get("remuneraciones")
        consumo_intermedio = row.get("consumo_intermedio_estimado")
        stock_capital = row.get("stock_capital_imputado")

        # DECISION: Provisional team rule, June 2026. Advance variable capital
        # and constant circulating capital by dividing annual flows by the
        # configured turnover factor. With no factor, leave all three advanced
        # capital variables empty.
        if remuneraciones not in (None, ""):
            row["capital_variable_adelantado"] = (
                float(remuneraciones) / float(factor)
            )
        if consumo_intermedio not in (None, ""):
            row["capital_circulante_constante_adelantado"] = (
                float(consumo_intermedio) / float(factor)
            )
        if (
            stock_capital not in (None, "")
            and row["capital_variable_adelantado"] is not None
            and row["capital_circulante_constante_adelantado"] is not None
        ):
            row["capital_total_adelantado"] = (
                float(stock_capital)
                + float(row["capital_variable_adelantado"])
                + float(row["capital_circulante_constante_adelantado"])
            )
    return rows


def build_annual_economy_total(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    additive_columns = [
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
        "fbkf_maq_eq",
        "adquisiciones_importadas",
        "adquisiciones_origen_importado",
        "importaciones_maquinaria",
        "consumo_capital_fijo",
        "impuestos_netos",
        "stock_capital",
    ]
    rows_by_year: dict[int, list[dict[str, object]]] = {}
    for row in rows:
        rows_by_year.setdefault(int(row["anno"]), []).append(row)

    totals: list[dict[str, object]] = []
    for year, year_rows in sorted(rows_by_year.items()):
        epocas = sorted({str(row.get("epoca")) for row in year_rows if row.get("epoca") not in (None, "")})
        ciiu_versions = sorted(
            {str(row.get("ciiu_version")) for row in year_rows if row.get("ciiu_version") not in (None, "")}
        )
        total: dict[str, object] = {
            "anno": year,
            "seccion": "economia_total",
            "epoca": epocas[0] if len(epocas) == 1 else "|".join(epocas),
            "ciiu_version": ciiu_versions[0] if len(ciiu_versions) == 1 else "|".join(ciiu_versions),
        }
        for column in additive_columns:
            total[column] = sum_present([row.get(column) for row in year_rows])
        total["excedente_bruto"] = (
            float(total["vab_pp"]) - float(total["remuneraciones"])
            if total.get("vab_pp") is not None and total.get("remuneraciones") is not None
            else None
        )
        total["part_salarial"] = safe_divide(total.get("remuneraciones"), total.get("vab_pp"))
        total["productividad"] = safe_divide(total.get("vab_pp"), total.get("puestos_trabajo"))
        totals.append(total)
    add_stock_capital_imputation(totals)
    add_capital_advanced_variables(totals)
    return totals


def build_annual_quality_checks(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    checks: list[dict[str, object]] = []
    for row in rows:
        vbp_pp = row.get("vbp_pp")
        vab_pp = row.get("vab_pp")
        remuneraciones = row.get("remuneraciones")
        stock_capital = row.get("stock_capital_imputado")
        checks.append(
            {
                "anno": row.get("anno"),
                "vab_vbp": safe_divide(vab_pp, vbp_pp),
                "consumo_intermedio_estimado": row.get(
                    "consumo_intermedio_estimado"
                ),
                "remuneraciones_vab": safe_divide(remuneraciones, vab_pp),
                "stock_vab": safe_divide(stock_capital, vab_pp),
            }
        )
    return checks


def write_panel_csv(rows: list[dict[str, object]], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(
            file,
            fieldnames=PANEL_COLUMNS,
            extrasaction="ignore",
            lineterminator="\n",
        )
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def write_panel_workbook(rows: list[dict[str, object]], output_path: Path) -> None:
    # DECISION: The workbook keeps the full panel and a branch-C review subset
    # plus annual economy totals in separate sheets so co-investigators can
    # inspect the GitHub artifact without regenerating filtered files.
    branch_c_rows = [row for row in rows if row.get("seccion") == "C"]
    economy_total_rows = build_annual_economy_total(rows)
    quality_columns = [
        "anno",
        "vab_vbp",
        "consumo_intermedio_estimado",
        "remuneraciones_vab",
        "stock_vab",
    ]
    write_workbook(
        output_path,
        {
            MAIN_SHEET: table_from_dicts(rows, PANEL_COLUMNS),
            BRANCH_C_SHEET: table_from_dicts(branch_c_rows, PANEL_COLUMNS),
            CHECK_C_SHEET: table_from_dicts(
                build_annual_quality_checks(branch_c_rows),
                quality_columns,
            ),
            TOTAL_ECONOMY_SHEET: table_from_dicts(economy_total_rows, PANEL_COLUMNS),
            CHECK_TOTAL_SHEET: table_from_dicts(
                build_annual_quality_checks(economy_total_rows),
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
    fbkf_maq_eq_rows = extract_fbkf_maq_eq_panel(args.years)
    accounts_rows = extract_accounts_panel(args.years)
    stock_rows = extract_stock_panel(args.years)
    enterprise_count_rows = extract_enterprise_counts_panel(args.years)
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

    fbkf_maq_eq_by_year: dict[int, list[dict[str, object]]] = {}
    for row in fbkf_maq_eq_rows:
        fbkf_maq_eq_by_year.setdefault(int(row["anno"]), []).append(row)
    for year in args.years:
        validate_fbkf_maq_eq_year(year, fbkf_maq_eq_by_year.get(year, []))

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

    panel = add_panel_variables(
        rows,
        fbcf_rows,
        fbkf_maq_eq_rows,
        accounts_rows,
        stock_rows,
        enterprise_count_rows,
    )
    panel = add_estimated_vab_pb(panel)
    panel = add_estimated_intermediate_consumption(panel)
    panel = add_stock_capital_imputation(panel)
    panel = add_capital_advanced_variables(panel)
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
