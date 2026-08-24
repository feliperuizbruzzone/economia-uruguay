#!/usr/bin/env python3
"""Extract direct EAAE source-division variables for manufacturing, 2020-2024.

This task-specific helper is used by
`11_build_eaae_industria_grupos_mussi_devaluacion.R`. It reuses the extraction
logic already validated for EAAE capital and FBCF helpers, but preserves the
published source divisions instead of aggregating them into Rev.4-compatible
groups. The output is intended as a temporary input to the analysis script.
"""

from __future__ import annotations

import argparse
import csv
import importlib.util
import shutil
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[2]
PROCESSING_DIR = PROJECT_ROOT / "command-files" / "processing-command-files"


def load_module(module_name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(module_name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load module from {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


capital = load_module(
    "eaae_subrama_capital_direct",
    PROCESSING_DIR / "eaae_subrama_capital_direct.py",
)
fbkf = load_module(
    "eaae_subrama_fbkf_direct",
    PROCESSING_DIR / "eaae_subrama_fbkf_direct.py",
)


OUTPUT_COLUMNS = [
    "anno",
    "seccion_fuente",
    "division_publicada",
    "codigos_base_2dig",
    "consumo_capital_fijo",
    "impuestos_netos",
    "stock_capital",
    "stock_capital_imputado",
    "fbcf",
    "fbkf_maq_eq",
    "adquisiciones_importadas",
    "adquisiciones_origen_importado",
    "importaciones_maquinaria",
    "archivos_capital_fuente",
    "archivos_fbkf_fuente",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract direct EAAE manufacturing source-division variables."
    )
    parser.add_argument("--output", required=True, help="CSV output path.")
    parser.add_argument(
        "--years",
        nargs="*",
        type=int,
        default=list(range(2020, 2025)),
        help="Years to extract. Defaults to 2020-2024.",
    )
    return parser.parse_args()


def row_key(year: int, section: str, division: str) -> tuple[int, str, str]:
    return (year, str(section).strip(), capital.normalize_code(division))


def base_codes_text(division: str, year: int) -> str:
    version = capital.ciiu_version_for_year(year)
    return "|".join(capital.base_2dig_codes(division, version))


def expected_section(year: int) -> str:
    return capital.expected_source_section(year)


def candidate_extractors(module: Any) -> list[tuple[str, list[str]]]:
    extractors = module.candidate_extractors()
    flatpak = shutil.which("flatpak")
    if flatpak:
        prefix = [
            flatpak,
            "run",
            f"--filesystem={PROJECT_ROOT}",
            "--filesystem=/tmp",
            "--command=bsdtar",
            "org.freedesktop.Platform//25.08",
        ]
        if not any(item[0] == "flatpak-bsdtar" for item in extractors):
            # DECISION: In the current workstation RAR5-capable bsdtar is
            # available inside the Flatpak runtime. Inject the same extractor
            # for both reused helpers so source RARs remain read-only and XLS
            # files are extracted only to temporary directories.
            extractors.insert(0, ("flatpak-bsdtar", prefix))
    return extractors


def is_manufacturing_source_row(year: int, row: dict[str, Any]) -> bool:
    return (
        str(row.get("seccion_fuente", "")).strip() == expected_section(year)
        and bool(row.get("division_publicada"))
    )


def ensure_record(
    records: dict[tuple[int, str, str], dict[str, Any]],
    year: int,
    section: str,
    division: str,
) -> dict[str, Any]:
    key = row_key(year, section, division)
    record = records.setdefault(
        key,
        {
            "anno": year,
            "seccion_fuente": str(section).strip(),
            "division_publicada": capital.normalize_code(division),
            "codigos_base_2dig": base_codes_text(division, year),
            "archivos_capital_fuente": set(),
            "archivos_fbkf_fuente": set(),
        },
    )
    return record


def add_capital_rows(
    records: dict[tuple[int, str, str], dict[str, Any]],
    years: list[int],
) -> None:
    extractors = candidate_extractors(capital)
    if not extractors:
        raise RuntimeError("No RAR extractor candidate found for capital tables.")

    for year in years:
        accounts_rows, accounts_member = capital.extract_variable_year(
            year,
            "accounts",
            extractors,
        )
        stock_rows, stock_member = capital.extract_variable_year(
            year,
            "stock",
            extractors,
        )

        for row in [*accounts_rows, *stock_rows]:
            if not is_manufacturing_source_row(year, row):
                continue
            record = ensure_record(
                records,
                year,
                str(row.get("seccion_fuente", "")),
                str(row.get("division_publicada", "")),
            )
            variable = str(row.get("variable"))
            value = row.get("valor")
            if value is not None:
                record[variable] = float(value)
            if variable in {"consumo_capital_fijo", "impuestos_netos"} and accounts_member:
                record["archivos_capital_fuente"].add(accounts_member)
            if variable == "stock_capital" and stock_member:
                record["archivos_capital_fuente"].add(stock_member)


def add_fbkf_rows(
    records: dict[tuple[int, str, str], dict[str, Any]],
    years: list[int],
) -> None:
    extractors = candidate_extractors(fbkf)
    if not extractors:
        raise RuntimeError("No RAR extractor candidate found for FBCF/FBKF tables.")

    for year in years:
        for kind in ("fbcf", "fbkf_maq_eq"):
            rows, _member = fbkf.extract_kind_year(year, kind, extractors)
            for row in rows:
                if (
                    str(row.get("usar_para_homologacion", "")) != "si"
                    or str(row.get("seccion_fuente", "")).strip() != expected_section(year)
                    or not row.get("division_publicada")
                ):
                    continue
                record = ensure_record(
                    records,
                    year,
                    str(row.get("seccion_fuente", "")),
                    str(row.get("division_publicada", "")),
                )
                record["archivos_fbkf_fuente"].add(str(row.get("archivo_fuente") or ""))
                for variable in row.get("value_columns", []):
                    value = row.get(variable)
                    if value is not None:
                        record[variable] = float(value)


def finalize_records(records: dict[tuple[int, str, str], dict[str, Any]]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for key in sorted(records):
        record = records[key]
        # DECISION: 2020-2024 have direct fixed-asset stock data, so the
        # operative stock used in downstream calculations equals the original
        # source stock. No 2002/2011 imputation rule is relevant here.
        if record.get("stock_capital") is not None:
            record["stock_capital_imputado"] = record["stock_capital"]
        if (
            record.get("adquisiciones_importadas") is not None
            and record.get("adquisiciones_origen_importado") is not None
        ):
            record["importaciones_maquinaria"] = (
                float(record["adquisiciones_importadas"])
                + float(record["adquisiciones_origen_importado"])
            )
        output: dict[str, Any] = {}
        for column in OUTPUT_COLUMNS:
            value = record.get(column)
            if isinstance(value, set):
                value = "|".join(sorted(item for item in value if item))
            output[column] = value
        rows.append(output)
    return rows


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=OUTPUT_COLUMNS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    args = parse_args()
    years = sorted(set(args.years))
    records: dict[tuple[int, str, str], dict[str, Any]] = {}
    add_capital_rows(records, years)
    add_fbkf_rows(records, years)
    write_csv(Path(args.output), finalize_records(records))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
