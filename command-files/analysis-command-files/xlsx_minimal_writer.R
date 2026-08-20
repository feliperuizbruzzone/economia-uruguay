xml_escape <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}

column_letter <- function(index) {
  letters <- character()
  while (index > 0) {
    index <- index - 1
    letters <- c(LETTERS[(index %% 26) + 1], letters)
    index <- index %/% 26
  }
  paste0(letters, collapse = "")
}

cell_reference <- function(row_index, column_index) {
  paste0(column_letter(column_index), row_index)
}

format_number <- function(value) {
  if (!is.finite(value)) {
    return("")
  }
  format(value, digits = 15, scientific = FALSE, trim = TRUE)
}

write_cell_xml <- function(row_index, column_index, value) {
  reference <- cell_reference(row_index, column_index)
  if (length(value) == 0 || is.na(value)) {
    return(sprintf('<c r="%s" t="inlineStr"><is><t></t></is></c>', reference))
  }
  if (is.numeric(value)) {
    formatted <- format_number(value)
    if (formatted == "") {
      return(sprintf('<c r="%s" t="inlineStr"><is><t></t></is></c>', reference))
    }
    return(sprintf('<c r="%s"><v>%s</v></c>', reference, formatted))
  }
  sprintf(
    '<c r="%s" t="inlineStr"><is><t>%s</t></is></c>',
    reference,
    xml_escape(value)
  )
}

worksheet_xml <- function(sheet_data) {
  sheet_data <- as.data.frame(sheet_data, stringsAsFactors = FALSE)
  rows <- vector("list", nrow(sheet_data) + 1)
  header <- names(sheet_data)

  header_cells <- vapply(
    seq_along(header),
    function(column_index) write_cell_xml(1, column_index, header[[column_index]]),
    character(1)
  )
  rows[[1]] <- sprintf('<row r="1">%s</row>', paste0(header_cells, collapse = ""))

  if (nrow(sheet_data) > 0) {
    for (data_row_index in seq_len(nrow(sheet_data))) {
      row_index <- data_row_index + 1
      cells <- vapply(
        seq_along(sheet_data),
        function(column_index) {
          write_cell_xml(row_index, column_index, sheet_data[[column_index]][[data_row_index]])
        },
        character(1)
      )
      rows[[row_index]] <- sprintf(
        '<row r="%s">%s</row>',
        row_index,
        paste0(cells, collapse = "")
      )
    }
  }

  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ',
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
    '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" ',
    'topLeftCell="A2" activePane="bottomLeft" state="frozen"/>',
    '<selection pane="bottomLeft"/></sheetView></sheetViews>',
    "<sheetData>",
    paste0(rows, collapse = ""),
    "</sheetData></worksheet>"
  )
}

workbook_xml <- function(sheet_names) {
  sheets <- vapply(
    seq_along(sheet_names),
    function(i) {
      sprintf(
        '<sheet name="%s" sheetId="%s" r:id="rId%s"/>',
        xml_escape(sheet_names[[i]]),
        i,
        i
      )
    },
    character(1)
  )
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ',
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
    "<sheets>",
    paste0(sheets, collapse = ""),
    "</sheets></workbook>"
  )
}

workbook_rels_xml <- function(sheet_names) {
  relationships <- vapply(
    seq_along(sheet_names),
    function(i) {
      sprintf(
        '<Relationship Id="rId%s" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet%s.xml"/>',
        i,
        i
      )
    },
    character(1)
  )
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    paste0(relationships, collapse = ""),
    sprintf(
      '<Relationship Id="rId%s" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>',
      length(sheet_names) + 1
    ),
    "</Relationships>"
  )
}

content_types_xml <- function(sheet_count) {
  sheets <- vapply(
    seq_len(sheet_count),
    function(i) {
      sprintf(
        '<Override PartName="/xl/worksheets/sheet%s.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
        i
      )
    },
    character(1)
  )
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
    '<Default Extension="xml" ContentType="application/xml"/>',
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>',
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>',
    '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>',
    paste0(sheets, collapse = ""),
    "</Types>"
  )
}

root_rels_xml <- function() {
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>',
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>',
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>',
    "</Relationships>"
  )
}

styles_xml <- function() {
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>',
    '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>',
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>',
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>',
    '<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>',
    "</styleSheet>"
  )
}

app_xml <- function(sheet_names) {
  titles <- paste0("<vt:lpstr>", xml_escape(sheet_names), "</vt:lpstr>", collapse = "")
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" ',
    'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">',
    "<Application>R</Application>",
    '<HeadingPairs><vt:vector size="2" baseType="variant">',
    "<vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant>",
    sprintf("<vt:variant><vt:i4>%s</vt:i4></vt:variant>", length(sheet_names)),
    "</vt:vector></HeadingPairs>",
    sprintf(
      '<TitlesOfParts><vt:vector size="%s" baseType="lpstr">%s</vt:vector></TitlesOfParts>',
      length(sheet_names),
      titles
    ),
    "</Properties>"
  )
}

core_xml <- function(title = "Workbook") {
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" ',
    'xmlns:dc="http://purl.org/dc/elements/1.1/" ',
    'xmlns:dcterms="http://purl.org/dc/terms/" ',
    'xmlns:dcmitype="http://purl.org/dc/dcmitype/" ',
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">',
    "<dc:title>", xml_escape(title), "</dc:title>",
    "<dc:creator>economia-uruguay R analysis script</dc:creator>",
    "</cp:coreProperties>"
  )
}

write_xlsx_workbook <- function(path, sheets, title = "Workbook") {
  if (Sys.which("zip") == "") {
    stop("System command `zip` is required to write XLSX.")
  }

  sheet_names <- names(sheets)
  if (any(nchar(sheet_names) > 31)) {
    stop("Excel sheet names must be 31 characters or fewer.")
  }

  output_path <- file.path(normalizePath(dirname(path)), basename(path))
  tmpdir <- tempfile("xlsx-minimal-")
  dir.create(file.path(tmpdir, "_rels"), recursive = TRUE)
  dir.create(file.path(tmpdir, "docProps"), recursive = TRUE)
  dir.create(file.path(tmpdir, "xl", "_rels"), recursive = TRUE)
  dir.create(file.path(tmpdir, "xl", "worksheets"), recursive = TRUE)
  on.exit(unlink(tmpdir, recursive = TRUE), add = TRUE)

  writeLines(content_types_xml(length(sheet_names)), file.path(tmpdir, "[Content_Types].xml"))
  writeLines(root_rels_xml(), file.path(tmpdir, "_rels", ".rels"))
  writeLines(core_xml(title), file.path(tmpdir, "docProps", "core.xml"))
  writeLines(app_xml(sheet_names), file.path(tmpdir, "docProps", "app.xml"))
  writeLines(workbook_xml(sheet_names), file.path(tmpdir, "xl", "workbook.xml"))
  writeLines(workbook_rels_xml(sheet_names), file.path(tmpdir, "xl", "_rels", "workbook.xml.rels"))
  writeLines(styles_xml(), file.path(tmpdir, "xl", "styles.xml"))

  for (i in seq_along(sheets)) {
    writeLines(
      worksheet_xml(sheets[[i]]),
      file.path(tmpdir, "xl", "worksheets", paste0("sheet", i, ".xml"))
    )
  }

  oldwd <- setwd(tmpdir)
  on.exit(setwd(oldwd), add = TRUE)
  if (file.exists(output_path)) {
    file.remove(output_path)
  }
  files <- list.files(".", all.files = TRUE, recursive = TRUE, no.. = TRUE)
  utils::zip(zipfile = output_path, files = files, flags = "-r9Xq")
}
