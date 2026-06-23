#!/usr/bin/env python3

from __future__ import annotations

import csv
import math
import re
import zipfile
from pathlib import Path
from typing import Iterable
from xml.sax.saxutils import escape


INPUT_PANEL = Path("data/analysis-data/20260623_panel_eia_1989_1997_2dig.csv")
OUTPUT_WORKBOOK = Path("data/analysis-data/20260623_panel_eia_1989_1997_2dig.xlsx")


EIA_COLUMNS = [
    "anno",
    "seccion",
    "seccion_etiqueta",
    "epoca",
    "ciiu_version",
    "vbp_pp",
    "vab_pp",
    "consumo_intermedio",
    "remuneraciones",
    "consumo_capital_fijo",
    "stock_capital",
    "stock_capital_imputado",
]

CHECK_COLUMNS = [
    "anno",
    "seccion",
    "seccion_etiqueta",
    "vab_vbp",
    "consumo_intermedio",
    "remuneraciones_vab",
    "stock_vab",
]


def parse_number(value: str | None) -> float | None:
    if value is None or value == "":
        return None
    try:
        number = float(value)
    except ValueError:
        return None
    if not math.isfinite(number):
        return None
    return number


def safe_divide(numerator: float | None, denominator: float | None) -> float | None:
    if numerator is None or denominator in (None, 0):
        return None
    return numerator / denominator


def read_panel() -> list[dict[str, str]]:
    with INPUT_PANEL.open(newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        rows = list(reader)

    missing = set(EIA_COLUMNS) - set(reader.fieldnames or [])
    if missing:
        raise ValueError(f"Missing columns in {INPUT_PANEL}: {sorted(missing)}")

    return rows


def build_check_rows(rows: Iterable[dict[str, str]]) -> list[dict[str, object]]:
    check_rows: list[dict[str, object]] = []
    for row in rows:
        vbp_pp = parse_number(row["vbp_pp"])
        vab_pp = parse_number(row["vab_pp"])
        remuneraciones = parse_number(row["remuneraciones"])
        stock_capital_imputado = parse_number(row["stock_capital_imputado"])

        # DECISION: this sheet mirrors the EAAE check-calidad indicators. EIA
        # has direct `consumo_intermedio`, so the check uses that column rather
        # than the EAAE-specific `consumo_intermedio_estimado` name.
        check_rows.append(
            {
                "anno": parse_number(row["anno"]),
                "seccion": parse_number(row["seccion"]),
                "seccion_etiqueta": row["seccion_etiqueta"],
                "vab_vbp": safe_divide(vab_pp, vbp_pp),
                "consumo_intermedio": parse_number(row["consumo_intermedio"]),
                "remuneraciones_vab": safe_divide(remuneraciones, vab_pp),
                "stock_vab": safe_divide(stock_capital_imputado, vab_pp),
            }
        )

    return check_rows


def column_letter(index: int) -> str:
    letters = ""
    while index:
        index, remainder = divmod(index - 1, 26)
        letters = chr(65 + remainder) + letters
    return letters


def is_numeric_cell(value: object) -> bool:
    return isinstance(value, int | float) and math.isfinite(float(value))


def cell_xml(row_number: int, col_number: int, value: object) -> str:
    cell_ref = f"{column_letter(col_number)}{row_number}"
    if value is None or value == "":
        return f'<c r="{cell_ref}"/>'
    if is_numeric_cell(value):
        return f'<c r="{cell_ref}"><v>{float(value):.15g}</v></c>'
    escaped_value = escape(str(value))
    return f'<c r="{cell_ref}" t="inlineStr"><is><t>{escaped_value}</t></is></c>'


def sheet_xml(headers: list[str], rows: list[dict[str, object]]) -> str:
    all_rows = [dict(zip(headers, headers, strict=True)), *rows]
    row_xml = []
    for row_idx, row in enumerate(all_rows, start=1):
        cells = [
            cell_xml(row_idx, col_idx, row.get(header))
            for col_idx, header in enumerate(headers, start=1)
        ]
        row_xml.append(f'<row r="{row_idx}">{"".join(cells)}</row>')

    max_col = column_letter(len(headers))
    max_row = len(all_rows)
    widths = "".join(
        f'<col min="{idx}" max="{idx}" width="{min(max(len(header) + 2, 12), 42)}" customWidth="1"/>'
        for idx, header in enumerate(headers, start=1)
    )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        f'<dimension ref="A1:{max_col}{max_row}"/>'
        f"<cols>{widths}</cols>"
        f"<sheetData>{''.join(row_xml)}</sheetData>"
        "</worksheet>"
    )


def workbook_xml() -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        "<sheets>"
        '<sheet name="eia" sheetId="1" r:id="rId1"/>'
        '<sheet name="check-calidad" sheetId="2" r:id="rId2"/>'
        "</sheets>"
        "</workbook>"
    )


def workbook_rels_xml() -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>'
        '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        "</Relationships>"
    )


def root_rels_xml() -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        "</Relationships>"
    )


def content_types_xml() -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '<Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        "</Types>"
    )


def styles_xml() -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>'
        '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>'
        '<borders count="1"><border/></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>'
        '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
        "</styleSheet>"
    )


def normalise_panel_rows(rows: list[dict[str, str]]) -> list[dict[str, object]]:
    numeric_columns = {
        "anno",
        "seccion",
        "vbp_pp",
        "vab_pp",
        "consumo_intermedio",
        "remuneraciones",
        "consumo_capital_fijo",
        "stock_capital",
        "stock_capital_imputado",
    }
    output: list[dict[str, object]] = []
    for row in rows:
        output.append(
            {
                column: parse_number(row[column]) if column in numeric_columns else row[column]
                for column in EIA_COLUMNS
            }
        )
    return output


def validate_rows(panel_rows: list[dict[str, str]], check_rows: list[dict[str, object]]) -> None:
    if len(panel_rows) != 90:
        raise ValueError(f"Expected 90 EIA panel rows, found {len(panel_rows)}")
    if len(check_rows) != len(panel_rows):
        raise ValueError("check-calidad row count differs from eia sheet")

    keys = {(row["anno"], row["seccion"]) for row in panel_rows}
    if len(keys) != len(panel_rows):
        raise ValueError("Duplicate anno + seccion keys in EIA panel")

    expected_sections = {"3", *{str(code) for code in range(31, 40)}}
    for year in range(1989, 1998):
        actual_sections = {row["seccion"] for row in panel_rows if row["anno"] == str(year)}
        if actual_sections != expected_sections:
            raise ValueError(f"Year {year}: invalid section coverage {sorted(actual_sections)}")


def write_workbook(panel_rows: list[dict[str, str]], check_rows: list[dict[str, object]]) -> None:
    OUTPUT_WORKBOOK.parent.mkdir(parents=True, exist_ok=True)
    panel_sheet_rows = normalise_panel_rows(panel_rows)
    with zipfile.ZipFile(OUTPUT_WORKBOOK, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("[Content_Types].xml", content_types_xml())
        archive.writestr("_rels/.rels", root_rels_xml())
        archive.writestr("xl/workbook.xml", workbook_xml())
        archive.writestr("xl/_rels/workbook.xml.rels", workbook_rels_xml())
        archive.writestr("xl/styles.xml", styles_xml())
        archive.writestr("xl/worksheets/sheet1.xml", sheet_xml(EIA_COLUMNS, panel_sheet_rows))
        archive.writestr("xl/worksheets/sheet2.xml", sheet_xml(CHECK_COLUMNS, check_rows))


def main() -> None:
    panel_rows = read_panel()
    check_rows = build_check_rows(panel_rows)
    validate_rows(panel_rows, check_rows)
    write_workbook(panel_rows, check_rows)
    print(f"Escrito: {OUTPUT_WORKBOOK} ({len(panel_rows)} filas eia; {len(check_rows)} filas check-calidad)")


if __name__ == "__main__":
    main()
