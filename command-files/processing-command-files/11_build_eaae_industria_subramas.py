"""Build EAAE manufacturing sub-branch source and Rev.4-compatible panels."""

from __future__ import annotations

import argparse
import csv
import logging
import re
import sys
import tempfile
from collections import defaultdict
from pathlib import Path

import xlrd

from eaae_c1 import (
    ciiu_version_for_year,
    extract_member,
    find_member,
    find_unrar,
    list_archive_members,
    read_source_rows,
    to_number,
)


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CONFIG_DIR = PROJECT_ROOT / "command-files" / "config"
sys.path.insert(0, str(CONFIG_DIR))

from eaae_config import (  # noqa: E402
    DATA_ANALYSIS_DIR,
    DATA_INPUT_EAAE_DIR,
    EAAE_CONFIG,
    PANEL_DATE_PREFIX,
    PANEL_YEARS,
)


LOGGER = logging.getLogger(__name__)

HOMOLOGATION_CONFIG = (
    Path("command-files")
    / "config"
    / "eaae_industria_subramas_rev4_homologacion.csv"
)
SOURCE_OUTPUT = (
    DATA_ANALYSIS_DIR
    / f"{PANEL_DATE_PREFIX}_panel_eaae_industria_subramas_fuente.csv"
)
HOMOLOGATED_OUTPUT = (
    DATA_ANALYSIS_DIR
    / f"{PANEL_DATE_PREFIX}_panel_eaae_industria_subramas_rev4_homologado.csv"
)
VALIDATION_OUTPUT = (
    DATA_ANALYSIS_DIR
    / f"{PANEL_DATE_PREFIX}_validacion_panel_eaae_industria_subramas_rev4.csv"
)

# DECISION: For the sub-branch panel, 2001 uses the official two-digit file
# for enterprises with 5+ persons occupied. The letter-level main panel uses
# "Total del Pais", so 2001 reconciliation against the main panel is expected
# to be partial and is reported as a validation warning.
YEAR_2001_2DIG_MEMBER = "2 Digitos/EAE_cu1afe2_01.xls"
NUMERIC_COLUMNS = [
    "vbp_pp",
    "vbp_pb",
    "vab_pp",
    "vab_pb",
    "remuneraciones",
    "puestos_trabajo",
]
MONETARY_COLUMNS_2001 = {"vbp_pp", "vab_pp", "remuneraciones"}

SOURCE_COLUMNS = [
    "anno",
    "seccion",
    "seccion_fuente",
    "ciiu_version",
    "epoca",
    "archivo_fuente",
    "division_publicada",
    "codigos_componentes",
    "codigos_base_2dig",
    "nivel_agregacion",
    "usar_para_homologacion",
    "descripcion_fuente",
    *NUMERIC_COLUMNS,
]

HOMOLOGATED_COLUMNS = [
    "anno",
    "seccion",
    "grupo_rev4_homologado",
    "descripcion_grupo_rev4_homologado",
    "seccion_rev4_homologada",
    "incluir_sector_industrial_rev4",
    "ciiu_version_fuente",
    "seccion_fuente",
    "epoca",
    "codigos_fuente_incluidos",
    "divisiones_publicadas_incluidas",
    "n_filas_fuente",
    "tipo_homologacion",
    "calidad_homologacion",
    "notas_homologacion",
    *NUMERIC_COLUMNS,
]

VALIDATION_COLUMNS = [
    "anno",
    "nivel_validacion",
    "grupo_o_division",
    "variable",
    "test",
    "estado",
    "valor_observado",
    "valor_referencia",
    "diferencia",
    "diferencia_pct",
    "mensaje",
]

QUALITY_ORDER = {"baja": 0, "media": 1, "alta": 2}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Build EAAE 2001-2024 manufacturing sub-branch source, "
            "Rev.4-compatible and validation CSVs."
        )
    )
    parser.add_argument(
        "--years",
        nargs="*",
        type=int,
        default=PANEL_YEARS,
        help="Years to include. Defaults to the configured EAAE panel years.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite today's existing sub-branch outputs.",
    )
    return parser.parse_args()


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )


def normalize_code(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    text = str(value).strip()
    if not text:
        return ""
    if re.fullmatch(r"\d+\.0", text):
        return text[:-2]
    text = re.sub(r"\s+", " ", text)
    text = text.replace(" Y ", " y ")
    return text


def component_codes(code: str) -> list[str]:
    normalized = normalize_code(code)
    if not normalized:
        return []
    return re.findall(r"\d{2,4}", normalized)


def base_2dig_codes(code: str, ciiu_version: str) -> list[str]:
    bases: list[str] = []
    for component in component_codes(code):
        base = component[:2] if ciiu_version == "Rev.3" else component
        if base not in bases:
            bases.append(base)
    return bases


def classify_level(code: str) -> str:
    normalized = normalize_code(code)
    if not normalized:
        return "seccion_total"
    if re.search(r"[-,]|\by\b", normalized):
        return "grupo_codigos_publicado"
    if re.fullmatch(r"\d{2}", normalized):
        return "division_2_digitos"
    if re.fullmatch(r"\d{3}", normalized):
        return "grupo_3_digitos"
    if re.fullmatch(r"\d{4}", normalized):
        return "clase_4_digitos"
    return "codigo_publicado"


def expected_source_section(year: int) -> str:
    return "D" if ciiu_version_for_year(year) == "Rev.3" else "C"


def bool_text(value: bool) -> str:
    return "si" if value else "no"


def should_use_for_homologation(year: int, row: dict[str, object]) -> bool:
    code = str(row.get("division_publicada") or "")
    level = str(row.get("nivel_agregacion") or "")
    if not has_any_numeric(row_numeric_values(row)):
        return False
    if level == "seccion_total":
        return False
    if year == 2001:
        return True
    if ciiu_version_for_year(year) == "Rev.3" and year <= 2005:
        # DECISION: For 2002-2005 the C1 files publish section totals,
        # divisions, groups and classes. Use only division totals to avoid
        # double counting while keeping lower-level rows in the source panel.
        return level == "division_2_digitos"
    return bool(component_codes(code))


def row_numeric_values(row: dict[str, object]) -> dict[str, object]:
    return {column: row.get(column) for column in NUMERIC_COLUMNS}


def clean_description(parts: list[object]) -> str:
    strings = [str(part).strip() for part in parts if str(part).strip()]
    return re.sub(r"\s+", " ", " ".join(strings))


def has_any_numeric(values: dict[str, object]) -> bool:
    return any(value not in (None, "") for value in values.values())


def scale_2001_value(column: str, value: object) -> object:
    if value in (None, ""):
        return None
    if column in MONETARY_COLUMNS_2001:
        return float(value) * 1000
    return value


def read_2001_2dig_rows(xls_path: Path) -> list[dict[str, object]]:
    workbook = xlrd.open_workbook(str(xls_path))
    sheet = workbook.sheet_by_index(0)
    rows: list[dict[str, object]] = []
    current: dict[str, object] | None = None
    desc_parts: list[object] = []

    def flush_current() -> None:
        nonlocal current, desc_parts
        if current is None:
            return
        current["descripcion"] = clean_description(desc_parts)
        for column in NUMERIC_COLUMNS:
            current[column] = scale_2001_value(column, current.get(column))
        rows.append(current)
        current = None
        desc_parts = []

    for row_idx in range(sheet.nrows):
        section = str(sheet.cell_value(row_idx, 0)).strip()
        division = normalize_code(sheet.cell_value(row_idx, 1))
        description = sheet.cell_value(row_idx, 2)
        numeric = {
            "vbp_pp": to_number(sheet.cell_value(row_idx, 3)),
            "vbp_pb": None,
            "vab_pp": to_number(sheet.cell_value(row_idx, 4)),
            "vab_pb": None,
            "remuneraciones": to_number(sheet.cell_value(row_idx, 5)),
            "puestos_trabajo": to_number(sheet.cell_value(row_idx, 6)),
        }

        if re.fullmatch(r"[A-Z]", section):
            flush_current()
            current = {
                "seccion_fuente": section,
                "division": division,
                **numeric,
            }
            desc_parts = [description]
            continue

        if current is None:
            continue

        if str(description).strip():
            desc_parts.append(description)
        if has_any_numeric(numeric):
            for column, value in numeric.items():
                if value is not None:
                    current[column] = value

    flush_current()
    return rows


def read_year_source_rows(year: int, xls_path: Path) -> list[dict[str, object]]:
    if year == 2001:
        return read_2001_2dig_rows(xls_path)
    return read_source_rows(year, xls_path)


def extract_year_member(year: int, unrar_bin: str, tmpdir: Path) -> tuple[str, Path]:
    config = EAAE_CONFIG[year]
    rar_path = PROJECT_ROOT / DATA_INPUT_EAAE_DIR / config["rar_name"]
    if not rar_path.exists():
        raise FileNotFoundError(f"Year {year}: missing RAR file {rar_path}")

    members = list_archive_members(rar_path, unrar_bin)
    if year == 2001:
        member = YEAR_2001_2DIG_MEMBER
        if member not in members:
            raise RuntimeError(f"Year 2001: missing expected member {member}")
    else:
        member = find_member(year, members)
    return member, extract_member(rar_path, member, tmpdir, unrar_bin)


def build_source_panel(years: list[int]) -> list[dict[str, object]]:
    unrar = find_unrar()
    records: list[dict[str, object]] = []
    for year in years:
        config = EAAE_CONFIG[year]
        version = ciiu_version_for_year(year)
        expected_section = expected_source_section(year)
        with tempfile.TemporaryDirectory(prefix=f"eaae-industria-{year}-") as tmp:
            member, xls_path = extract_year_member(year, unrar, Path(tmp))
            source_rows = read_year_source_rows(year, xls_path)

        for source_row in source_rows:
            source_section = str(source_row.get("seccion_fuente", "")).strip()
            if source_section != expected_section:
                continue

            division = normalize_code(source_row.get("division"))
            level = classify_level(division)
            bases = base_2dig_codes(division, version)
            record: dict[str, object] = {
                "anno": year,
                "seccion": "C",
                "seccion_fuente": source_section,
                "ciiu_version": version,
                "epoca": config["epoca"],
                "archivo_fuente": member,
                "division_publicada": division,
                "codigos_componentes": "|".join(component_codes(division)),
                "codigos_base_2dig": "|".join(bases),
                "nivel_agregacion": level,
                "descripcion_fuente": str(source_row.get("descripcion", "")).strip(),
                **row_numeric_values(source_row),
            }
            record["usar_para_homologacion"] = bool_text(
                should_use_for_homologation(year, record)
            )
            records.append(record)

    records.sort(
        key=lambda row: (
            int(row["anno"]),
            str(row["ciiu_version"]),
            str(row["seccion_fuente"]),
            str(row["division_publicada"]),
            str(row["descripcion_fuente"]),
        )
    )
    return records


def read_homologation_config() -> dict[tuple[str, str], dict[str, str]]:
    path = PROJECT_ROOT / HOMOLOGATION_CONFIG
    with path.open(newline="", encoding="utf-8") as file:
        reader = csv.DictReader(file)
        mapping: dict[tuple[str, str], dict[str, str]] = {}
        for row in reader:
            key = (row["ciiu_version_fuente"], row["codigo_fuente_2dig"])
            if key in mapping:
                raise RuntimeError(f"Duplicate homologation key: {key}")
            mapping[key] = row
    return mapping


def mapping_for_source_row(
    row: dict[str, object],
    mapping: dict[tuple[str, str], dict[str, str]],
) -> dict[str, str] | None:
    version = str(row["ciiu_version"])
    bases = [
        code
        for code in str(row.get("codigos_base_2dig", "")).split("|")
        if code
    ]
    mapped = [mapping.get((version, base)) for base in bases]
    if not mapped or any(item is None for item in mapped):
        return None

    groups = {item["grupo_rev4_homologado"] for item in mapped if item is not None}
    if len(groups) != 1:
        return None

    selected = dict(mapped[0])
    notes = sorted(
        {
            item["notas_homologacion"]
            for item in mapped
            if item is not None and item.get("notas_homologacion")
        }
    )
    selected["notas_homologacion"] = " | ".join(notes)
    selected["calidad_homologacion"] = worst_quality(
        [item["calidad_homologacion"] for item in mapped if item is not None]
    )
    selected["tipo_homologacion"] = "|".join(
        sorted(
            {
                item["tipo_homologacion"]
                for item in mapped
                if item is not None and item.get("tipo_homologacion")
            }
        )
    )
    return selected


def worst_quality(values: list[str]) -> str:
    if not values:
        return ""
    return max(values, key=lambda value: QUALITY_ORDER.get(value, -1))


def sum_present(rows: list[dict[str, object]], column: str) -> float | None:
    values = [row.get(column) for row in rows]
    present = [float(value) for value in values if value not in (None, "")]
    if not present:
        return None
    return sum(present)


def unique_join(values: list[object]) -> str:
    cleaned = sorted({str(value).strip() for value in values if str(value).strip()})
    return "|".join(cleaned)


def build_homologated_panel(
    source_rows: list[dict[str, object]],
    mapping: dict[tuple[str, str], dict[str, str]],
) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    mapped_rows: list[dict[str, object]] = []
    mapping_issues: list[dict[str, object]] = []
    for row in source_rows:
        if row.get("usar_para_homologacion") != "si":
            continue
        match = mapping_for_source_row(row, mapping)
        if match is None:
            mapping_issues.append(row)
            continue
        mapped_rows.append({**row, **match})

    grouped: dict[tuple[int, str], list[dict[str, object]]] = defaultdict(list)
    for row in mapped_rows:
        grouped[(int(row["anno"]), str(row["grupo_rev4_homologado"]))].append(row)

    output: list[dict[str, object]] = []
    for (year, group), rows in sorted(grouped.items()):
        first = rows[0]
        record: dict[str, object] = {
            "anno": year,
            "seccion": "C",
            "grupo_rev4_homologado": group,
            "descripcion_grupo_rev4_homologado": first[
                "descripcion_grupo_rev4_homologado"
            ],
            "seccion_rev4_homologada": first["seccion_rev4_homologada"],
            "incluir_sector_industrial_rev4": bool_text(
                all(row["incluir_sector_industrial_rev4"] == "si" for row in rows)
            ),
            "ciiu_version_fuente": unique_join([row["ciiu_version"] for row in rows]),
            "seccion_fuente": unique_join([row["seccion_fuente"] for row in rows]),
            "epoca": unique_join([row["epoca"] for row in rows]),
            "codigos_fuente_incluidos": unique_join(
                code
                for row in rows
                for code in str(row.get("codigos_base_2dig", "")).split("|")
            ),
            "divisiones_publicadas_incluidas": unique_join(
                [row["division_publicada"] for row in rows]
            ),
            "n_filas_fuente": len(rows),
            "tipo_homologacion": unique_join(
                [row["tipo_homologacion"] for row in rows]
            ),
            "calidad_homologacion": worst_quality(
                [row["calidad_homologacion"] for row in rows]
            ),
            "notas_homologacion": unique_join(
                [row["notas_homologacion"] for row in rows]
            ),
        }
        for column in NUMERIC_COLUMNS:
            record[column] = sum_present(rows, column)
        output.append(record)

    return output, mapping_issues


def latest_main_panel_path() -> Path | None:
    candidates = sorted((PROJECT_ROOT / DATA_ANALYSIS_DIR).glob("*_panel_eaae.csv"))
    return candidates[-1] if candidates else None


def read_main_panel_branch_c() -> dict[int, dict[str, object]]:
    path = latest_main_panel_path()
    if path is None:
        return {}
    rows: dict[int, dict[str, object]] = {}
    with path.open(newline="", encoding="utf-8") as file:
        reader = csv.DictReader(file)
        for row in reader:
            if row.get("seccion") == "C":
                rows[int(row["anno"])] = row
    return rows


def as_float(value: object) -> float | None:
    if value in (None, ""):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def validation_row(
    year: int | str,
    level: str,
    group: str,
    variable: str,
    test: str,
    state: str,
    observed: object = "",
    reference: object = "",
    message: str = "",
) -> dict[str, object]:
    observed_number = as_float(observed)
    reference_number = as_float(reference)
    difference = ""
    difference_pct = ""
    if observed_number is not None and reference_number is not None:
        difference = observed_number - reference_number
        if reference_number != 0:
            difference_pct = (difference / reference_number) * 100
    return {
        "anno": year,
        "nivel_validacion": level,
        "grupo_o_division": group,
        "variable": variable,
        "test": test,
        "estado": state,
        "valor_observado": observed,
        "valor_referencia": reference,
        "diferencia": difference,
        "diferencia_pct": difference_pct,
        "mensaje": message,
    }


def ok_with_tolerance(observed: float | None, reference: float | None) -> bool:
    if observed is None or reference is None:
        return False
    return abs(observed - reference) <= max(1.0, abs(reference) * 1e-6)


def build_validation_rows(
    source_rows: list[dict[str, object]],
    homologated_rows: list[dict[str, object]],
    mapping_issues: list[dict[str, object]],
    years: list[int],
) -> list[dict[str, object]]:
    checks: list[dict[str, object]] = []
    source_by_year: dict[int, list[dict[str, object]]] = defaultdict(list)
    additive_by_year: dict[int, list[dict[str, object]]] = defaultdict(list)
    hom_by_year: dict[int, list[dict[str, object]]] = defaultdict(list)
    for row in source_rows:
        source_by_year[int(row["anno"])].append(row)
        if row.get("usar_para_homologacion") == "si":
            additive_by_year[int(row["anno"])].append(row)
    for row in homologated_rows:
        hom_by_year[int(row["anno"])].append(row)

    main_branch_c = read_main_panel_branch_c()
    main_panel = latest_main_panel_path()
    panel_message = (
        f"Referencia: {main_panel.relative_to(PROJECT_ROOT)}"
        if main_panel is not None
        else "No se encontro panel EAAE principal para reconciliar."
    )

    for year in years:
        expected_section = expected_source_section(year)
        year_source = source_by_year.get(year, [])
        additive = additive_by_year.get(year, [])
        hom = hom_by_year.get(year, [])
        sections = sorted({row["seccion_fuente"] for row in year_source})
        checks.append(
            validation_row(
                year,
                "cobertura",
                "industria",
                "filas_fuente",
                "existe_fuente_anual",
                "ok" if year_source else "fail",
                len(year_source),
                1,
                f"Seccion fuente esperada: {expected_section}; observadas: {'|'.join(sections)}",
            )
        )
        checks.append(
            validation_row(
                year,
                "cobertura",
                "industria",
                "filas_aditivas",
                "existe_base_para_homologacion",
                "ok" if additive else "fail",
                len(additive),
                1,
            )
        )
        checks.append(
            validation_row(
                year,
                "cobertura",
                "industria",
                "grupos_homologados",
                "existe_panel_homologado",
                "ok" if hom else "fail",
                len(hom),
                1,
            )
        )

        duplicate_keys: set[tuple[str, str]] = set()
        repeated: set[tuple[str, str]] = set()
        for row in additive:
            key = (str(row["division_publicada"]), str(row["descripcion_fuente"]))
            if key in duplicate_keys:
                repeated.add(key)
            duplicate_keys.add(key)
        checks.append(
            validation_row(
                year,
                "estructura",
                "fuente_aditiva",
                "clave",
                "sin_duplicados_division_descripcion",
                "ok" if not repeated else "fail",
                len(repeated),
                0,
                "Duplicados: " + "|".join(f"{a}:{b[:30]}" for a, b in repeated)
                if repeated
                else "",
            )
        )

        for row in additive:
            group = str(row.get("division_publicada") or "")
            for column in ["vab_pp", "remuneraciones"]:
                state = "ok" if row.get(column) not in (None, "") else "fail"
                checks.append(
                    validation_row(
                        year,
                        "consistencia",
                        group,
                        column,
                        "no_nulo_en_fila_aditiva",
                        state,
                        row.get(column, ""),
                        "no_nulo",
                    )
                )
            vbp = as_float(row.get("vbp_pp"))
            vab = as_float(row.get("vab_pp"))
            rem = as_float(row.get("remuneraciones"))
            puestos = as_float(row.get("puestos_trabajo"))
            checks.append(
                validation_row(
                    year,
                    "consistencia",
                    group,
                    "vbp_pp_vab_pp",
                    "vbp_pp_mayor_igual_vab_pp",
                    "ok" if vbp is not None and vab is not None and vbp >= vab else "fail",
                    vbp,
                    vab,
                )
            )
            checks.append(
                validation_row(
                    year,
                    "consistencia",
                    group,
                    "vab_pp_remuneraciones",
                    "vab_pp_mayor_igual_remuneraciones",
                    "ok" if vab is not None and rem is not None and vab >= rem else "warning",
                    vab,
                    rem,
                )
            )
            checks.append(
                validation_row(
                    year,
                    "consistencia",
                    group,
                    "puestos_trabajo",
                    "puestos_trabajo_positivo",
                    "ok" if puestos is not None and puestos > 0 else "warning",
                    puestos,
                    0,
                )
            )

        for column in ["vbp_pp", "vab_pp", "remuneraciones", "puestos_trabajo"]:
            source_total = sum_present(additive, column)
            main_row = main_branch_c.get(year, {})
            reference = as_float(main_row.get(column))
            state = "ok" if ok_with_tolerance(source_total, reference) else "warning"
            checks.append(
                validation_row(
                    year,
                    "reconciliacion",
                    "fuente_aditiva_vs_panel_c",
                    column,
                    "suma_fuente_reconcilia_panel_principal",
                    state,
                    source_total,
                    reference if reference is not None else "",
                    panel_message,
                )
            )

        for column in NUMERIC_COLUMNS:
            hom_total = sum_present(hom, column)
            source_total = sum_present(additive, column)
            if hom_total is None and source_total is None:
                state = "ok"
            else:
                state = (
                    "ok"
                    if ok_with_tolerance(hom_total, source_total)
                    else "warning"
                )
            checks.append(
                validation_row(
                    year,
                    "reconciliacion",
                    "homologado_total_vs_fuente_aditiva",
                    column,
                    "suma_homologada_reconcilia_fuente",
                    state,
                    hom_total if hom_total is not None else "",
                    source_total if source_total is not None else "",
                )
            )

        for column in ["vbp_pb", "vab_pb"]:
            values = [row.get(column) for row in hom]
            has_values = any(value not in (None, "") for value in values)
            expected_values = year >= 2017
            checks.append(
                validation_row(
                    year,
                    "cobertura",
                    "homologado",
                    column,
                    "disponibilidad_pb_segun_periodo",
                    "ok" if has_values == expected_values else "fail",
                    bool_text(has_values),
                    bool_text(expected_values),
                )
            )

    for row in mapping_issues:
        checks.append(
            validation_row(
                int(row["anno"]),
                "homologacion",
                str(row.get("division_publicada") or ""),
                "grupo_rev4_homologado",
                "fila_aditiva_con_mapeo_unico",
                "fail",
                "",
                "mapeo_unico",
                str(row.get("descripcion_fuente") or ""),
            )
        )

    return checks


def write_csv(rows: list[dict[str, object]], columns: list[str], output: Path) -> None:
    output_path = PROJECT_ROOT / output
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(
            file,
            fieldnames=columns,
            extrasaction="ignore",
            lineterminator="\n",
        )
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def outputs_exist() -> bool:
    return all((PROJECT_ROOT / path).exists() for path in [
        SOURCE_OUTPUT,
        HOMOLOGATED_OUTPUT,
        VALIDATION_OUTPUT,
    ])


def main() -> int:
    configure_logging()
    args = parse_args()
    if outputs_exist() and not args.force:
        LOGGER.info("Sub-branch outputs already exist; use --force to rebuild.")
        return 0

    source_rows = build_source_panel(args.years)
    mapping = read_homologation_config()
    homologated_rows, mapping_issues = build_homologated_panel(source_rows, mapping)
    validation_rows = build_validation_rows(
        source_rows,
        homologated_rows,
        mapping_issues,
        args.years,
    )

    write_csv(source_rows, SOURCE_COLUMNS, SOURCE_OUTPUT)
    write_csv(homologated_rows, HOMOLOGATED_COLUMNS, HOMOLOGATED_OUTPUT)
    write_csv(validation_rows, VALIDATION_COLUMNS, VALIDATION_OUTPUT)

    fail_count = sum(1 for row in validation_rows if row.get("estado") == "fail")
    warning_count = sum(1 for row in validation_rows if row.get("estado") == "warning")
    LOGGER.info("Wrote %s source rows to %s", len(source_rows), SOURCE_OUTPUT)
    LOGGER.info(
        "Wrote %s homologated rows to %s",
        len(homologated_rows),
        HOMOLOGATED_OUTPUT,
    )
    LOGGER.info(
        "Wrote %s validation rows to %s (%s warnings, %s fails)",
        len(validation_rows),
        VALIDATION_OUTPUT,
        warning_count,
        fail_count,
    )
    return 1 if fail_count else 0


if __name__ == "__main__":
    raise SystemExit(main())
