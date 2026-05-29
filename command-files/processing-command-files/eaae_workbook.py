"""Small XLSX helpers for the EAAE panel workbook."""

from __future__ import annotations

import math
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET
from xml.sax.saxutils import escape


MAIN_SHEET = "eaae"
BRANCH_C_SHEET = "rama-C"
CHECK_C_SHEET = "check-calidad-C"
TOTAL_ECONOMY_SHEET = "economia_total"
CHECK_TOTAL_SHEET = "check-calidad-total"

XML_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
REL_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
PACKAGE_REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"


def column_letter(index: int) -> str:
    letters = ""
    while index:
        index, remainder = divmod(index - 1, 26)
        letters = chr(65 + remainder) + letters
    return letters


def cell_reference(row_index: int, column_index: int) -> str:
    return f"{column_letter(column_index)}{row_index}"


def is_number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def format_number(value: int | float) -> str:
    if isinstance(value, float):
        if not math.isfinite(value):
            return ""
        return format(value, ".15g")
    return str(value)


def write_cell(row_index: int, column_index: int, value: object) -> str:
    reference = cell_reference(row_index, column_index)
    if value is None:
        return f'<c r="{reference}" t="inlineStr"><is><t></t></is></c>'
    if is_number(value):
        formatted = format_number(value)
        if formatted:
            return f'<c r="{reference}"><v>{formatted}</v></c>'
        return f'<c r="{reference}" t="inlineStr"><is><t></t></is></c>'
    text = escape(str(value), {'"': "&quot;"})
    return f'<c r="{reference}" t="inlineStr"><is><t>{text}</t></is></c>'


def worksheet_xml(rows: list[list[object]]) -> str:
    body_rows = []
    for row_index, row in enumerate(rows, start=1):
        cells = [
            write_cell(row_index, column_index, value)
            for column_index, value in enumerate(row, start=1)
        ]
        body_rows.append(f'<row r="{row_index}">{"".join(cells)}</row>')
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<worksheet xmlns="{XML_NS}" xmlns:r="{REL_NS}">'
        "<sheetViews><sheetView workbookViewId=\"0\"><pane ySplit=\"1\" "
        'topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
        '<selection pane="bottomLeft"/></sheetView></sheetViews>'
        f"<sheetData>{''.join(body_rows)}</sheetData>"
        "</worksheet>"
    )


def table_from_dicts(
    rows: list[dict[str, object]],
    columns: list[str],
) -> list[list[object]]:
    return [columns] + [[row.get(column) for column in columns] for row in rows]


def workbook_xml(sheet_names: list[str]) -> str:
    sheets = []
    for sheet_id, name in enumerate(sheet_names, start=1):
        sheets.append(
            f'<sheet name="{escape(name, {"\"": "&quot;"})}" sheetId="{sheet_id}" '
            f'r:id="rId{sheet_id}"/>'
        )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<workbook xmlns="{XML_NS}" xmlns:r="{REL_NS}">'
        "<sheets>"
        f"{''.join(sheets)}"
        "</sheets>"
        "</workbook>"
    )


def workbook_rels_xml(sheet_names: list[str]) -> str:
    relationships = []
    for sheet_id in range(1, len(sheet_names) + 1):
        relationships.append(
            f'<Relationship Id="rId{sheet_id}" Type="{REL_NS}/worksheet" '
            f'Target="worksheets/sheet{sheet_id}.xml"/>'
        )
    relationships.append(
        f'<Relationship Id="rId{len(sheet_names) + 1}" Type="{REL_NS}/styles" '
        'Target="styles.xml"/>'
    )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<Relationships xmlns="{PACKAGE_REL_NS}">'
        f"{''.join(relationships)}"
        "</Relationships>"
    )


def content_types_xml(sheet_count: int) -> str:
    sheets = "".join(
        '<Override PartName="/xl/worksheets/sheet'
        f'{sheet_id}.xml" ContentType="application/vnd.openxmlformats-officedocument.'
        'spreadsheetml.worksheet+xml"/>'
        for sheet_id in range(1, sheet_count + 1)
    )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
        '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
        f"{sheets}"
        "</Types>"
    )


def root_rels_xml() -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<Relationships xmlns="{PACKAGE_REL_NS}">'
        f'<Relationship Id="rId1" Type="{REL_NS}/officeDocument" Target="xl/workbook.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
        f'<Relationship Id="rId3" Type="{REL_NS}/extended-properties" Target="docProps/app.xml"/>'
        "</Relationships>"
    )


def styles_xml() -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<styleSheet xmlns="{XML_NS}">'
        '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>'
        '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>'
        '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>'
        "</styleSheet>"
    )


def app_xml(sheet_names: list[str]) -> str:
    heading_pairs = (
        '<HeadingPairs xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
        '<vt:vector size="2" baseType="variant"><vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant>'
        f'<vt:variant><vt:i4>{len(sheet_names)}</vt:i4></vt:variant></vt:vector></HeadingPairs>'
    )
    titles = "".join(f"<vt:lpstr>{escape(name)}</vt:lpstr>" for name in sheet_names)
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
        'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
        "<Application>Python</Application>"
        f"{heading_pairs}"
        f'<TitlesOfParts><vt:vector size="{len(sheet_names)}" baseType="lpstr">{titles}</vt:vector></TitlesOfParts>'
        "</Properties>"
    )


def core_xml() -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:dcmitype="http://purl.org/dc/dcmitype/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        "<dc:title>Panel EAAE Uruguay</dc:title>"
        "<dc:creator>economia-uruguay pipeline</dc:creator>"
        "</cp:coreProperties>"
    )


def write_workbook(path: Path, sheets: dict[str, list[list[object]]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet_names = list(sheets)
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("[Content_Types].xml", content_types_xml(len(sheet_names)))
        archive.writestr("_rels/.rels", root_rels_xml())
        archive.writestr("docProps/core.xml", core_xml())
        archive.writestr("docProps/app.xml", app_xml(sheet_names))
        archive.writestr("xl/workbook.xml", workbook_xml(sheet_names))
        archive.writestr("xl/_rels/workbook.xml.rels", workbook_rels_xml(sheet_names))
        archive.writestr("xl/styles.xml", styles_xml())
        for sheet_id, rows in enumerate(sheets.values(), start=1):
            archive.writestr(f"xl/worksheets/sheet{sheet_id}.xml", worksheet_xml(rows))


def sheet_id_by_name(workbook: zipfile.ZipFile, sheet_name: str) -> int:
    root = ET.fromstring(workbook.read("xl/workbook.xml"))
    namespace = {"main": XML_NS}
    for index, sheet in enumerate(root.findall("main:sheets/main:sheet", namespace), start=1):
        if sheet.attrib.get("name") == sheet_name:
            return index
    raise ValueError(f"Sheet {sheet_name!r} not found in workbook")


def read_cell(cell: ET.Element) -> str:
    cell_type = cell.attrib.get("t")
    if cell_type == "inlineStr":
        texts = [
            text.text or ""
            for text in cell.findall(f".//{{{XML_NS}}}t")
        ]
        return "".join(texts)
    value = cell.find(f"{{{XML_NS}}}v")
    return "" if value is None or value.text is None else value.text


def cell_column_index(reference: str) -> int:
    letters = "".join(char for char in reference if char.isalpha())
    index = 0
    for char in letters:
        index = index * 26 + (ord(char.upper()) - 64)
    return index


def read_sheet_rows(path: Path, sheet_name: str) -> list[list[str]]:
    with zipfile.ZipFile(path) as workbook:
        sheet_id = sheet_id_by_name(workbook, sheet_name)
        root = ET.fromstring(workbook.read(f"xl/worksheets/sheet{sheet_id}.xml"))
    rows: list[list[str]] = []
    for row in root.findall(f".//{{{XML_NS}}}row"):
        values_by_column = {
            cell_column_index(cell.attrib["r"]): read_cell(cell)
            for cell in row.findall(f"{{{XML_NS}}}c")
        }
        max_column = max(values_by_column, default=0)
        rows.append([values_by_column.get(index, "") for index in range(1, max_column + 1)])
    return rows


def read_sheet_as_dicts(path: Path, sheet_name: str) -> list[dict[str, str]]:
    rows = read_sheet_rows(path, sheet_name)
    if not rows:
        return []
    header = rows[0]
    return [
        {
            column: values[index] if index < len(values) else ""
            for index, column in enumerate(header)
        }
        for values in rows[1:]
    ]
