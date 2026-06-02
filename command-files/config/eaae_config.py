"""Central configuration for the EAAE Uruguay 2001-2024 pipeline."""

from __future__ import annotations

from datetime import date
from pathlib import Path


INE_EAAE_SERIES_URL = (
    "https://www.gub.uy/instituto-nacional-estadistica/datos-y-estadisticas/"
    "estadisticas/series-encuesta-anual-actividad-economica-eaae"
)

DATA_INPUT_EAAE_DIR = Path("data/input-data/eaae")
DATA_INPUT_EAAE_METHODOLOGY_DIR = DATA_INPUT_EAAE_DIR / "metodologia"
DATA_ANALYSIS_DIR = Path("data/analysis-data")
PANEL_BASENAME = "panel_eaae"
# DECISION: Each created database version carries the local creation date as a
# prefix so GitHub reviewers can compare dated CSV/XLSX artifacts explicitly.
PANEL_DATE_PREFIX = date.today().strftime("%Y%m%d")
PANEL_CSV_OUTPUT = DATA_ANALYSIS_DIR / f"{PANEL_DATE_PREFIX}_{PANEL_BASENAME}.csv"
PANEL_XLSX_OUTPUT = DATA_ANALYSIS_DIR / f"{PANEL_DATE_PREFIX}_{PANEL_BASENAME}.xlsx"
PANEL_OUTPUTS = (PANEL_CSV_OUTPUT, PANEL_XLSX_OUTPUT)
PANEL_OUTPUT = PANEL_XLSX_OUTPUT

# DECISION: Final panel option B, decided in May 2026. Use a historical
# 2001-2024 panel with comparable homologated sectors. The final `seccion`
# column stores the homologated code directly; do not add auxiliary columns such
# as source section, homologation quality, or per-row notes during panel build.
CIIU_HOMOLOGATION_DECISION = "option_b_historical_homologated"
# DECISION: 2001 is included in the main preliminary panel from its special
# letter-level Total del País cuadro. It has no C1/C1.1 equivalent but supplies
# the same core variables used in this iteration.
EAAE_2001_PANEL_SOURCE = "Letra/EAE_cu1tpel_01.xls"
# DECISION: C1/C1.1 files verified for 2008-2024 do not contain construction
# (Rev.4 F), and mining (Rev.4 B) is absent in 2009-2011. Preliminary C1
# validation requires only the common observed homologated sectors.
CIIU_HOMOLOGATED_MINIMUM_SECTIONS = {"C", "D_E", "G", "H_J", "I"}
PANEL_YEARS = list(range(2001, 2025))
# DECISION: Provisional team rule, June 2026. Advance annual circulating flows
# by fixed turnover factors where the team provided values. Leave sectors with
# no configured factor as missing in the final panel.
CAPITAL_ADVANCE_TURNOVER_FACTORS = {
    "C": 6.6,
    "economia_total": 4.2,
}
PANEL_COLUMNS = [
    "anno",
    "seccion",
    "epoca",
    "ciiu_version",
    "vbp_pp",
    "vbp_pb",
    "vab_pp",
    "vab_pb",
    "vab_pb_estimado",
    "consumo_intermedio_estimado",
    "capital_circulante_constante_adelantado",
    "remuneraciones",
    "capital_variable_adelantado",
    "puestos_trabajo",
    "n_empresas",
    "fbcf",
    "adquisiciones_importadas",
    "consumo_capital_fijo",
    "impuestos_netos",
    "stock_capital",
    "capital_total_adelantado",
    "excedente_bruto",
    "part_salarial",
    "productividad",
]

CIIU_SECTION_HOMOLOGATION = {
    "Rev.3": {
        "A": "A",
        "B": "A",
        "C": "B",
        "D": "C",
        "E": "D_E",
        "F": "F",
        "G": "G",
        "H": "I",
        "I": "H_J",
        "J": "K",
        "K": "L_M_N",
        "L": "O",
        "M": "P",
        "N": "Q",
        "O": "R_S",
        "P": "T",
        "Q": "U",
    },
    "Rev.4": {
        "A": "A",
        "B": "B",
        "C": "C",
        "D": "D_E",
        "E": "D_E",
        "F": "F",
        "G": "G",
        "H": "H_J",
        "I": "I",
        "J": "H_J",
        "K": "K",
        "L": "L_M_N",
        "M": "L_M_N",
        "N": "L_M_N",
        "O": "O",
        "P": "P",
        "Q": "Q",
        "R": "R_S",
        "S": "R_S",
        "T": "T",
        "U": "U",
    },
}

EAAE_ENTERPRISE_METHODOLOGY_SOURCES = {
    2001: {
        "pdf": "METODOLOGÍA_EAE-2001.pdf",
        "method": "text_tables_2001",
        "ciiu_version": "Rev.3",
        "expected_total": 93366,
        "notes": (
            "Anexo 6: suma de unidades forzosas, marco 20-49, marco 5-19 "
            "y marco de menos de 5 puestos."
        ),
    },
    2002: {
        "pdf": "METODOLOGIA_EAE-2002-2003.pdf",
        "method": "text_table_forced_random",
        "ciiu_version": "Rev.3",
        "expected_total": 12298,
        "notes": "Anexo comun 2002-2003: marco forzoso + marco aleatorio.",
    },
    2003: {
        "pdf": "METODOLOGIA_EAE-2002-2003.pdf",
        "method": "text_table_forced_random",
        "ciiu_version": "Rev.3",
        "expected_total": 12298,
        "notes": "Anexo comun 2002-2003: marco forzoso + marco aleatorio.",
    },
    2004: {
        "pdf": "METODOLOGÍA_EAE-2004.pdf",
        "method": "text_table_single_frame",
        "ciiu_version": "Rev.3",
        "expected_total": 13993,
        "notes": "Anexo 2: unidades en el marco por clase o grupo de clases.",
    },
    2005: {
        "pdf": "METODOLOGÍA_EAE-2005.pdf",
        "method": "text_table_single_frame",
        "ciiu_version": "Rev.3",
        "expected_total": 14338,
        "notes": "Anexo 2: unidades en el marco por clase o grupo de clases.",
    },
    2011: {
        "pdf": "METODOLOGÍA_EAE-2011.pdf",
        "method": "manual_labeled_graph",
        "ciiu_version": "Rev.4",
        "expected_total": 11396,
        "source_counts": {
            "B": 28,
            "C": 2202,
            "D": 12,
            "E": 123,
            "G": 3512,
            "H": 928,
            "I": 817,
            "J": 399,
            "K": 211,
            "L": 109,
            "M": 500,
            "N": 735,
            "P": 457,
            "Q": 740,
            "R": 244,
            "S": 379,
        },
        "notes": (
            "Grafico 1 con etiquetas numericas; la suma transcripta coincide "
            "con el total del marco muestral publicado."
        ),
    },
    2020: {
        "pdf": "METODOLOGÍA_EAE-2020.pdf",
        "method": "vector_bar_graph",
        "ciiu_version": "Rev.4",
        "expected_total": 11776,
        "page": 3,
        "axis_max": 3000,
        "source_sections": [
            "B",
            "C",
            "D",
            "E",
            "G",
            "H",
            "I",
            "J",
            "K",
            "L",
            "M",
            "N",
            "P",
            "Q",
            "R",
            "S",
        ],
        "notes": (
            "Grafico 1 sin etiquetas; se extrae de la geometria vectorial y "
            "se acepta solo porque los enteros reproducen el total publicado."
        ),
    },
}

EAAE_ENTERPRISE_UNAVAILABLE_YEARS = {
    2006: "No hay PDF de metodologia en data/input-data/eaae/metodologia.",
    2007: "El PDF trae muestra teorica/efectiva, no marco por seccion.",
    2008: "El PDF no trae cantidad de empresas del marco por seccion.",
    2009: "El PDF no trae cantidad de empresas del marco por seccion.",
    2010: "El grafico disponible cruza marco y muestra por estrato de tamano, no por seccion.",
    2012: "El PDF no trae cantidad de empresas del marco por seccion.",
    2013: "El PDF no trae cantidad de empresas del marco por seccion.",
    2014: "El PDF no trae cantidad de empresas del marco por seccion.",
    2015: "El PDF no trae cantidad de empresas del marco por seccion.",
    2016: "El PDF no trae cantidad de empresas del marco por seccion.",
    2017: "El PDF no trae cantidad de empresas del marco por seccion.",
    2018: "El PDF no trae cantidad de empresas del marco por seccion.",
    2019: "El PDF no trae cantidad de empresas del marco por seccion.",
    2021: "El PDF local esta incompleto: solo llega al titulo Marco muestral.",
    2022: (
        "El grafico no tiene etiquetas y la reconstruccion vectorial no reproduce "
        "el total publicado; se deja sin dato exacto."
    ),
    2023: "No hay PDF de metodologia en data/input-data/eaae/metodologia.",
    2024: "No hay PDF de metodologia en data/input-data/eaae/metodologia.",
}


def homologate_ciiu_section(section: str, ciiu_version: str) -> str:
    """Return the final homologated `seccion` code for the panel."""
    normalized_section = section.strip().upper()
    try:
        return CIIU_SECTION_HOMOLOGATION[ciiu_version][normalized_section]
    except KeyError as exc:
        raise ValueError(
            f"No CIIU homologation for section={section!r}, "
            f"ciiu_version={ciiu_version!r}"
        ) from exc


ESQUEMA_7COL = [
    "seccion",
    "division",
    "descripcion",
    "vbp_pp",
    "vab_pp",
    "remuneraciones",
    "puestos_trabajo",
]

ESQUEMA_2001_LETRA = [
    "seccion",
    "descripcion",
    "vbp_pp",
    "vab_pp",
    "remuneraciones",
    "puestos_trabajo",
]

ESQUEMA_9COL = [
    "seccion",
    "division",
    "descripcion",
    "vbp_pp",
    "vbp_pb",
    "vab_pp",
    "vab_pb",
    "remuneraciones",
    "puestos_trabajo",
]


def _cuadros_decimal() -> list[str]:
    return (
        [f"C1.{n}" for n in range(1, 7)]
        + [f"C2.{n}" for n in range(1, 7)]
        + [f"C{n}" for n in range(3, 9)]
    )


def _cuadros_epoca_v() -> list[str]:
    return ["C1.1", "C1.2", "C1.3", "C2.1", "C2.2"] + [
        f"C{n}" for n in range(3, 9)
    ]


EAAE_CONFIG = {
    2001: {
        "epoca": 1,
        "subfolder": "Letra",
        "file_pattern": r"EAE_cu1tpel_01\.xls",
        "header_row": 7,
        "data_start_row": 11,
        "columns": ESQUEMA_2001_LETRA,
        "value_scale": {
            "vbp_pp": 1000,
            "vab_pp": 1000,
            "remuneraciones": 1000,
        },
        "cuadros": [f"C{n}" for n in range(1, 12)],
        "rar_name": "Encuesta_de_Actividad_Económica_2001.rar",
        "notes": (
            "Caso especial: usar Letra/EAE_cu1tpel_01.xls, cuadro 1 Total del País "
            "por sección CIIU Rev.3; no existe equivalente C1/C1.1. Variables "
            "monetarias publicadas en miles de pesos, escalar por 1000."
        ),
    },
    2002: {
        "epoca": 2,
        "subfolder": None,
        "file_pattern": r"EAE_C1_2002\.xls",
        "header_row": 6,
        "data_start_row": 8,
        "columns": ESQUEMA_7COL,
        "cuadros": ["C1", "C2", "C3", "C9"],
        "rar_name": "Encuesta_de_Actividad_Económica_2002.rar",
        "notes": "Solo 4 cuadros disponibles. CIIU Rev.3.",
    },
    2003: {
        "epoca": 2,
        "subfolder": None,
        "file_pattern": r"EAE_C1_2003\.xls",
        "header_row": 6,
        "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 14)],
        "rar_name": "Encuesta_de_Actividad_Económica_2003.rar",
        "notes": "CIIU Rev.3.",
    },
    2004: {
        "epoca": 2,
        "subfolder": None,
        "file_pattern": r"EAE_C1_2004\.xls",
        "header_row": 7,
        "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 14)],
        "rar_name": "Encuesta_de_Actividad_Económica_2004.rar",
        "notes": "Fila 4 vacia extra. CIIU Rev.3.",
    },
    2005: {
        "epoca": 2,
        "subfolder": None,
        "file_pattern": r"EAE_C1_2005\.xls",
        "header_row": 6,
        "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 14)],
        "rar_name": "Encuesta_de_Actividad_Económica_2005.rar",
        "notes": "CIIU Rev.3.",
    },
    2006: {
        "epoca": 3,
        "subfolder": None,
        "file_pattern": r"EAE_C1-F_2006\.xls",
        "header_row": 7,
        "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 11)],
        "rar_name": "Encuesta_de_Actividad_Económica_2006.rar",
        "notes": "Archivos con sufijo -F. CIIU Rev.3.",
    },
    2007: {
        "epoca": 3,
        "subfolder": "Forzosas y aleatorias",
        "file_pattern": r"EAE_C1_2007\.xls",
        "header_row": 7,
        "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 11)],
        "rar_name": "Encuesta_de_Actividad_Económica_2007.rar",
        "notes": "Cuadros duplicados; usar subcarpeta Forzosas y aleatorias.",
    },
    2008: {
        "epoca": 4,
        "subfolder": None,
        "file_pattern": r"EAE_C1_2008\.xls",
        "header_row": 7,
        "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 9)],
        "rar_name": "Encuesta_de_Actividad_Económica_2008.rar",
        "notes": "Primer ano con CIIU Rev.4.",
    },
    2009: {
        "epoca": 4,
        "subfolder": None,
        "file_pattern": r"EAE_C1_2009\.xls",
        "header_row": 7,
        "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 9)],
        "rar_name": "Encuesta_de_Actividad_Económica_2009.rar",
        "notes": "",
    },
    2010: {
        "epoca": 4,
        "subfolder": None,
        "file_pattern": r"EAE_C1_2010\.xls",
        "header_row": 7,
        "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 9)],
        "rar_name": "Encuesta_de_Actividad_Económica_2010.rar",
        "notes": "",
    },
    2011: {
        "epoca": 4,
        "subfolder": None,
        "file_pattern": r"EAE_C1_2011\.xls",
        "header_row": 7,
        "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": ["C1", "C2"],
        "rar_name": "Encuesta_de_Actividad_Económica_2011.rar",
        "notes": "Solo C1 y C2 disponibles.",
    },
    2012: {
        "epoca": 4,
        "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2012\.xls",
        "header_row": 7,
        "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": _cuadros_decimal(),
        "rar_name": "Encuesta_de_Actividad_Económica_2012.rar",
        "notes": "Primera aparicion de C1.1.",
    },
    2013: {
        "epoca": 4,
        "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2013\.xls",
        "header_row": 6,
        "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": _cuadros_decimal(),
        "rar_name": "Encuesta_de_Actividad_Económica_2013.rar",
        "notes": "Fila 3 agrega texto Valorado a pp.",
    },
    2014: {
        "epoca": 4,
        "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2014\.xls",
        "header_row": 6,
        "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": _cuadros_decimal(),
        "rar_name": "Encuesta_de_Actividad_Económica_2014.rar",
        "notes": "",
    },
    2015: {
        "epoca": 4,
        "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2015\.xls",
        "header_row": 6,
        "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": _cuadros_decimal(),
        "rar_name": "Encuesta_de_Actividad_Económica_2015.rar",
        "notes": "",
    },
    2016: {
        "epoca": 4,
        "subfolder": "Encuesta de Actividad Económica 2016",
        "file_pattern": r"EAE_C1\.1_2016\.xls",
        "header_row": 6,
        "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": _cuadros_decimal(),
        "rar_name": "Encuesta_de_Actividad_Económica_2016.rar",
        "notes": "Archivos dentro de subcarpeta con nombre completo.",
    },
    2017: {
        "epoca": 5,
        "subfolder": "Encuesta de Actividad Económica 2017",
        "file_pattern": r"EAE_C1\.1_?\s?2017\.xls",
        "header_row": 7,
        "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": _cuadros_epoca_v(),
        "rar_name": "Encuesta_de_Actividad_Económica_2017.rar",
        "notes": "Primer ano con 9 columnas; nombre XLS tiene espacio antes del ano.",
    },
    2018: {
        "epoca": 5,
        "subfolder": "Encuesta de Actividad Económica 2018",
        "file_pattern": r"EAE_C1\.1_2018\.xls",
        "header_row": 7,
        "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": _cuadros_epoca_v(),
        "rar_name": "Encuesta_de_Actividad_Económica_2018.rar",
        "notes": "",
    },
    2019: {
        "epoca": 5,
        "subfolder": "Encuesta de Actividad Económica 2019",
        "file_pattern": r"EAE_C1\.1_2019\.xls",
        "header_row": 7,
        "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": _cuadros_epoca_v(),
        "rar_name": "Encuesta_de_Actividad_Económica_2019.rar",
        "notes": "",
    },
    2020: {
        "epoca": 5,
        "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2020\.xls",
        "header_row": 7,
        "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": _cuadros_epoca_v(),
        "rar_name": "Principales_indicadores_y_desagregaciones_2020.rar",
        "notes": "Nombre de RAR distinto al patron general.",
    },
    2021: {
        "epoca": 5,
        "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2021\.xls",
        "header_row": 7,
        "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": _cuadros_epoca_v(),
        "rar_name": "Encuesta_de_Actividad_Económica_2021.rar",
        "notes": "",
    },
    2022: {
        "epoca": 5,
        "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2022\.xls",
        "header_row": 7,
        "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": _cuadros_epoca_v(),
        "rar_name": "Encuesta_de_Actividad_Económica_2022.rar",
        "notes": "",
    },
    2023: {
        "epoca": 5,
        "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2023\.xls",
        "header_row": 7,
        "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": _cuadros_epoca_v(),
        "rar_name": "Encuesta_de_Actividad_Económica_2023.rar",
        "notes": "",
    },
    2024: {
        "epoca": 5,
        "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2024\.xls",
        "header_row": 7,
        "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": _cuadros_epoca_v(),
        "rar_name": "Encuesta_de_Actividad_Económica_2024.rar",
        "notes": "Ultimo ano disponible al documentar el proyecto.",
    },
}


def _fbcf_config_for_year(year: int) -> dict[str, object]:
    if year == 2001:
        return {
            "subfolder": "Letra",
            "file_pattern": r"EAE_cu8tpel_01\.xls",
            "data_start_row": 11,
            "section_col": 0,
            "division_col": None,
            "fbcf_col": 2,
            "adquisiciones_importadas_col": 9,
            "value_scale": 1000,
            "notes": (
                "Cuadro 8 Total del País por sección; valores monetarios en "
                "miles de pesos corrientes."
            ),
        }
    if year == 2002:
        return {
            "subfolder": None,
            "file_pattern": None,
            "data_start_row": None,
            "section_col": None,
            "division_col": None,
            "fbcf_col": None,
            "adquisiciones_importadas_col": None,
            "value_scale": 1,
            "notes": "Sin cuadro de FBKF/FBCF identificado en los 4 XLS publicados.",
        }
    if 2003 <= year <= 2005:
        return {
            "subfolder": None,
            "file_pattern": rf"EAE_C10_{year}\.xls",
            "data_start_row": 10,
            "section_col": 0,
            "division_col": 1,
            "fbcf_col": 3,
            "adquisiciones_importadas_col": 7,
            "value_scale": 1,
            "notes": "Cuadro 10, Formación Bruta de Capital Fijo.",
        }
    if year == 2006:
        return {
            "subfolder": None,
            "file_pattern": r"EAE_C6-F_2006\.xls",
            "data_start_row": 10,
            "section_col": 0,
            "division_col": 1,
            "fbcf_col": 3,
            "adquisiciones_importadas_col": 7,
            "value_scale": 1,
            "notes": "Cuadro 6-F, Formación Bruta de Capital Fijo.",
        }
    if year == 2007:
        return {
            "subfolder": "Forzosas y aleatorias",
            "file_pattern": r"EAE_C6_2007\.xls",
            "data_start_row": 10,
            "section_col": 0,
            "division_col": 1,
            "fbcf_col": 3,
            "adquisiciones_importadas_col": 7,
            "value_scale": 1,
            "notes": "Cuadro 6 en subcarpeta Forzosas y aleatorias.",
        }
    if 2008 <= year <= 2010:
        return {
            "subfolder": None,
            "file_pattern": rf"EAE_C6_{year}\.xls",
            "data_start_row": 10,
            "section_col": 0,
            "division_col": 1,
            "fbcf_col": 3,
            "adquisiciones_importadas_col": 7,
            "value_scale": 1,
            "notes": "Cuadro 6, Formación Bruta de Capital Fijo.",
        }
    if year == 2011:
        return {
            "subfolder": None,
            "file_pattern": None,
            "data_start_row": None,
            "section_col": None,
            "division_col": None,
            "fbcf_col": None,
            "adquisiciones_importadas_col": None,
            "value_scale": 1,
            "notes": "Sin cuadro de FBKF/FBCF; el RAR publicado contiene solo C1 y C2.",
        }
    if 2012 <= year <= 2015:
        return {
            "subfolder": None,
            "file_pattern": rf"EAE_C6_{year}\.xls",
            "data_start_row": 10,
            "section_col": 0,
            "division_col": 1,
            "fbcf_col": 3,
            "adquisiciones_importadas_col": 7,
            "value_scale": 1,
            "notes": "Cuadro 6, Formación Bruta de Capital Fijo.",
        }
    if year == 2016:
        return {
            "subfolder": "Encuesta de Actividad Económica 2016",
            "file_pattern": r"EAE_C6_2016\.xls",
            "data_start_row": 10,
            "section_col": 0,
            "division_col": 1,
            "fbcf_col": 3,
            "adquisiciones_importadas_col": 7,
            "value_scale": 1,
            "notes": "Cuadro 6 en subcarpeta 2016.",
        }
    if 2017 <= year <= 2019:
        return {
            "subfolder": f"Encuesta de Actividad Económica {year}",
            "file_pattern": rf"EAE_C6_{year}\.xls",
            "data_start_row": 9,
            "section_col": 0,
            "division_col": 1,
            "fbcf_col": 3,
            "adquisiciones_importadas_col": 7,
            "value_scale": 1,
            "notes": "Cuadro 6, Formación Bruta de Capital Fijo.",
        }
    if 2020 <= year <= 2024:
        return {
            "subfolder": None,
            "file_pattern": rf"EAE_C6_{year}\.xls",
            "data_start_row": 9,
            "section_col": 0,
            "division_col": 1,
            "fbcf_col": 3,
            "adquisiciones_importadas_col": 7,
            "value_scale": 1,
            "notes": "Cuadro 6, Formación Bruta de Capital Fijo.",
        }
    raise ValueError(f"No FBCF configuration for year {year}")


# DECISION: FBKF/FBCF is not in C4 for the verified 2008-2024 files; C4 is
# remunerations. Use the first Total column in the FBCF tables: 2001 Cuadro 8,
# 2003-2005 Cuadro 10, and 2006-2024 Cuadro 6 (2006 has suffix -F). Leave
# 2002 and 2011 empty because no FBCF table is present in the published RAR.
EAAE_FBCF_CONFIG = {year: _fbcf_config_for_year(year) for year in PANEL_YEARS}


def _accounts_config_for_year(year: int) -> dict[str, object]:
    if year == 2001:
        return {
            "subfolder": "Letra",
            "file_pattern": r"EAE_cu2tpel_01\.xls",
            "data_start_row": 12,
            "section_col": 0,
            "division_col": None,
            "impuestos_netos_col": 5,
            "consumo_capital_col": 6,
            "value_scale": 1000,
            "notes": (
                "Cuadro 2 Total del País por sección; valores monetarios en "
                "miles de pesos corrientes."
            ),
        }
    if year == 2002:
        return {
            "subfolder": None,
            "file_pattern": r"EAE_C2_2002\.xls",
            "data_start_row": 11,
            "section_col": 0,
            "division_col": 1,
            "impuestos_netos_col": 6,
            "consumo_capital_col": 7,
            "value_scale": 1,
            "notes": "Cuadro 2, cuentas de producción.",
        }
    if year == 2003:
        return {
            "subfolder": None,
            "file_pattern": r"EAE_C2_2003\.xls",
            "data_start_row": 10,
            "section_col": 0,
            "division_col": 1,
            "impuestos_netos_col": 6,
            "consumo_capital_col": 7,
            "value_scale": 1,
            "notes": "Cuadro 2, cuentas de producción.",
        }
    if year == 2004:
        return {
            "subfolder": None,
            "file_pattern": r"EAE_C2_2004\.xls",
            "data_start_row": 9,
            "section_col": 0,
            "division_col": 1,
            "impuestos_netos_col": 6,
            "consumo_capital_col": 7,
            "value_scale": 1,
            "notes": "Cuadro 2, cuentas de producción.",
        }
    if year == 2005:
        return {
            "subfolder": None,
            "file_pattern": r"EAE_C2_2005\.xls",
            "data_start_row": 10,
            "section_col": 0,
            "division_col": 1,
            "impuestos_netos_col": 6,
            "consumo_capital_col": 7,
            "value_scale": 1,
            "notes": "Cuadro 2, cuentas de producción.",
        }
    if year == 2006:
        return {
            "subfolder": None,
            "file_pattern": r"EAE_C2-F_2006\.xls",
            "data_start_row": 11,
            "section_col": 0,
            "division_col": 1,
            "impuestos_netos_col": 5,
            "consumo_capital_col": 6,
            "value_scale": 1,
            "notes": (
                "Cuadro 2 con sufijo -F, cuentas de producción. Layout verificado: "
                "impuestos netos en columna 5 y consumo de capital fijo en columna 6."
            ),
        }
    if year == 2007:
        return {
            "subfolder": "Forzosas y aleatorias",
            "file_pattern": r"EAE_C2_2007\.xls",
            "data_start_row": 11,
            "section_col": 0,
            "division_col": 1,
            "impuestos_netos_col": 5,
            "consumo_capital_col": 6,
            "value_scale": 1,
            "notes": (
                "Cuadro 2 en subcarpeta Forzosas y aleatorias. Layout verificado: "
                "impuestos netos en columna 5 y consumo de capital fijo en columna 6."
            ),
        }
    if 2008 <= year <= 2010:
        return {
            "subfolder": None,
            "file_pattern": rf"EAE_C2_{year}\.xls",
            "data_start_row": 11,
            "section_col": 0,
            "division_col": 1,
            "impuestos_netos_col": 5,
            "consumo_capital_col": 6,
            "value_scale": 1,
            "notes": "Cuadro 2, cuentas de producción.",
        }
    if year == 2011:
        return {
            "subfolder": None,
            "file_pattern": r"EAE_C2_2011\.xls",
            "data_start_row": 11,
            "section_col": 0,
            "division_col": 1,
            "impuestos_netos_col": 7,
            "consumo_capital_col": 8,
            "value_scale": 1,
            "notes": (
                "Cuadro 2, cuentas de producción. Layout incompleto 2011 verificado: "
                "VAB en columna 5, remuneraciones en 6, impuestos netos en 7 y "
                "consumo de capital fijo en 8."
            ),
        }
    if year == 2012:
        return {
            "subfolder": None,
            "file_pattern": r"EAE_C2\.1_2012\.xls",
            "data_start_row": 13,
            "section_col": 0,
            "division_col": 1,
            "impuestos_netos_col": 7,
            "consumo_capital_col": 8,
            "value_scale": 1,
            "notes": "Cuadro 2.1, cuentas de producción por actividad principal.",
        }
    if year == 2013:
        return {
            "subfolder": None,
            "file_pattern": r"EAE_C2\.1_2013\.xls",
            "data_start_row": 13,
            "section_col": 0,
            "division_col": 1,
            "impuestos_netos_col": 7,
            "consumo_capital_col": 8,
            "value_scale": 1,
            "notes": "Cuadro 2.1, cuentas de producción por actividad principal.",
        }
    if 2014 <= year <= 2015:
        return {
            "subfolder": None,
            "file_pattern": rf"EAE_C2\.1_{year}\.xls",
            "data_start_row": 11,
            "section_col": 0,
            "division_col": 1,
            "impuestos_netos_col": 7,
            "consumo_capital_col": 8,
            "value_scale": 1,
            "notes": "Cuadro 2.1, cuentas de producción por actividad principal.",
        }
    if year == 2016:
        return {
            "subfolder": "Encuesta de Actividad Económica 2016",
            "file_pattern": r"EAE_C2\.1_2016\.xls",
            "data_start_row": 11,
            "section_col": 0,
            "division_col": 1,
            "impuestos_netos_col": 7,
            "consumo_capital_col": 8,
            "value_scale": 1,
            "notes": "Cuadro 2.1 en subcarpeta 2016.",
        }
    if 2017 <= year <= 2019:
        return {
            "subfolder": f"Encuesta de Actividad Económica {year}",
            "file_pattern": rf"EAE_C2\.1_{year}\.xls",
            "data_start_row": 10,
            "section_col": 0,
            "division_col": 1,
            "impuestos_netos_col": 7,
            "consumo_capital_col": 8,
            "value_scale": 1,
            "notes": "Cuadro 2.1, cuentas de producción por actividad principal.",
        }
    if 2020 <= year <= 2024:
        return {
            "subfolder": None,
            "file_pattern": rf"EAE_C2\.1_{year}\.xls",
            "data_start_row": 10,
            "section_col": 0,
            "division_col": 1,
            "impuestos_netos_col": 7,
            "consumo_capital_col": 8,
            "value_scale": 1,
            "notes": "Cuadro 2.1, cuentas de producción por actividad principal.",
        }
    raise ValueError(f"No accounts configuration for year {year}")


# DECISION: For requested taxes and consumption of fixed capital, use the
# production-account table closest to the panel concept: Cuadro 2 in 2001-2011
# and Cuadro 2.1 in 2012-2024. `consumo_capital` is the internal extraction
# key; the public panel column is `consumo_capital_fijo`.
EAAE_ACCOUNTS_CONFIG = {
    year: _accounts_config_for_year(year) for year in PANEL_YEARS
}


def _stock_config_for_year(year: int) -> dict[str, object]:
    if year == 2001:
        return {
            "subfolder": "Letra",
            "file_pattern": r"EAE_cu9tpel_01\.xls",
            "data_start_row": 13,
            "section_col": 0,
            "division_col": None,
            "stock_capital_col": 2,
            "value_scale": 1000,
            "notes": (
                "Cuadro 9 Total del País por sección; valor de activos fijos "
                "al 31/12/2001 en miles de pesos corrientes."
            ),
        }
    if year == 2002:
        return {
            "subfolder": None,
            "file_pattern": None,
            "data_start_row": None,
            "section_col": None,
            "division_col": None,
            "stock_capital_col": None,
            "value_scale": 1,
            "notes": (
                "Sin cuadro de valor de activos fijos identificado. El RAR contiene "
                "EAE_C9_2002.xls, pero ese cuadro corresponde a impuestos, no a stock."
            ),
        }
    if 2003 <= year <= 2005:
        return {
            "subfolder": None,
            "file_pattern": rf"EAE_C11_{year}\.xls",
            "data_start_row": 10,
            "section_col": 0,
            "division_col": 1,
            "stock_capital_col": 3,
            "value_scale": 1,
            "notes": "Cuadro 11, valor de activos fijos al 31/12.",
        }
    if year == 2006:
        return {
            "subfolder": None,
            "file_pattern": r"EAE_C7-F_2006\.xls",
            "data_start_row": 11,
            "section_col": 0,
            "division_col": 1,
            "stock_capital_col": 3,
            "value_scale": 1,
            "notes": "Cuadro 7-F, valor de activos fijos al 31/12/2006.",
        }
    if year == 2007:
        return {
            "subfolder": "Forzosas y aleatorias",
            "file_pattern": r"EAE_C7_2007\.xls",
            "data_start_row": 11,
            "section_col": 0,
            "division_col": 1,
            "stock_capital_col": 3,
            "value_scale": 1,
            "notes": "Cuadro 7, valor de activos fijos al 31/12/2007.",
        }
    if 2008 <= year <= 2010:
        return {
            "subfolder": None,
            "file_pattern": rf"EAE_C7_{year}\.xls",
            "data_start_row": 11,
            "section_col": 0,
            "division_col": 1,
            "stock_capital_col": 3,
            "value_scale": 1,
            "notes": "Cuadro 7, valor de activos fijos al 31/12.",
        }
    if year == 2011:
        return {
            "subfolder": None,
            "file_pattern": None,
            "data_start_row": None,
            "section_col": None,
            "division_col": None,
            "stock_capital_col": None,
            "value_scale": 1,
            "notes": "RAR publicado solo contiene C1 y C2; sin cuadro de activos fijos.",
        }
    if 2012 <= year <= 2015:
        return {
            "subfolder": None,
            "file_pattern": rf"EAE_C7_{year}\.xls",
            "data_start_row": 11,
            "section_col": 0,
            "division_col": 1,
            "stock_capital_col": 3,
            "value_scale": 1,
            "notes": "Cuadro 7, valor de activos fijos al 31/12.",
        }
    if year == 2016:
        return {
            "subfolder": "Encuesta de Actividad Económica 2016",
            "file_pattern": r"EAE_C7_2016\.xls",
            "data_start_row": 11,
            "section_col": 0,
            "division_col": 1,
            "stock_capital_col": 3,
            "value_scale": 1,
            "notes": "Cuadro 7 en subcarpeta 2016.",
        }
    if 2017 <= year <= 2019:
        return {
            "subfolder": f"Encuesta de Actividad Económica {year}",
            "file_pattern": rf"EAE_C7_{year}\.xls",
            "data_start_row": 10,
            "section_col": 0,
            "division_col": 1,
            "stock_capital_col": 3,
            "value_scale": 1,
            "notes": "Cuadro 7, valor de activos fijos al 31/12.",
        }
    if 2020 <= year <= 2024:
        return {
            "subfolder": None,
            "file_pattern": rf"EAE_C7_{year}\.xls",
            "data_start_row": 10,
            "section_col": 0,
            "division_col": 1,
            "stock_capital_col": 3,
            "value_scale": 1,
            "notes": "Cuadro 7, valor de activos fijos al 31/12.",
        }
    raise ValueError(f"No stock configuration for year {year}")


# DECISION: The capital stock variable is taken directly from published EAAE
# fixed-asset tables, not computed with PIM. The source is Cuadro 9 in 2001,
# Cuadro 11 in 2003-2005, and Cuadro 7 from 2006 onward. Leave 2002 and 2011
# empty because no fixed-asset table is present in the published RAR files.
EAAE_STOCK_CONFIG = {year: _stock_config_for_year(year) for year in PANEL_YEARS}
