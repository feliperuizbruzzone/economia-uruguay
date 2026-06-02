# Add team-defined own calculations to the dated EAAE workbook.
#
# Run from the project root:
#   Rscript command-files/analysis-command-files/02_add_calculos_propios_eaae.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(readxl)
  library(tibble)
})

analysis_dir <- file.path("data", "analysis-data")
industrial_sheet <- "calculos-propios-industrial"
total_sheet <- "calculos-propios-total"
rotacion_industria <- 6.6
rotacion_economia_total <- 4.2

latest_analysis_file <- function(pattern) {
  paths <- list.files(
    analysis_dir,
    pattern = pattern,
    full.names = TRUE
  )
  if (length(paths) == 0) {
    stop("No se encontro ningun archivo en ", analysis_dir, " con patron ", pattern)
  }
  sort(paths, decreasing = TRUE)[1]
}

panel_csv_path <- latest_analysis_file("^[0-9]{8}_panel_eaae\\.csv$")
panel_xlsx_path <- latest_analysis_file("^[0-9]{8}_panel_eaae\\.xlsx$")

safe_divide <- function(numerator, denominator) {
  result <- numerator / denominator
  result[is.na(numerator) | is.na(denominator) | denominator == 0] <- NA_real_
  result
}

sum_present <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) {
    return(NA_real_)
  }
  sum(x)
}

numeric_panel_cols <- c(
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
  "productividad"
)

panel <- readr::read_csv(panel_csv_path, show_col_types = FALSE) %>%
  mutate(
    anno = as.integer(anno),
    across(any_of(numeric_panel_cols), as.numeric)
  )

economia_total <- panel %>%
  group_by(anno) %>%
  summarise(
    seccion = "economia_total",
    epoca = paste(sort(unique(epoca[!is.na(epoca)])), collapse = "|"),
    ciiu_version = paste(sort(unique(ciiu_version[!is.na(ciiu_version)])), collapse = "|"),
    across(any_of(numeric_panel_cols), sum_present),
    .groups = "drop"
  ) %>%
  select(any_of(names(panel)))

vab_total <- economia_total %>%
  transmute(
    anno,
    vab_pp_total = vab_pp
  )

build_calculos_propios <- function(data, ambito, total_vab, rotacion_valor) {
  data %>%
    arrange(anno) %>%
    left_join(total_vab, by = "anno") %>%
    mutate(
      ambito = ambito,
      rotacion = rotacion_valor,
      # DECISION: `remuneraciones` already includes employer contributions in
      # C1/C1.1, so `costo_laboral` uses that total directly. The source does
      # not expose `cargas_patronales` as a separate panel variable.
      cargas_patronales = NA_real_,
      costo_laboral = remuneraciones,
      vab_pb_calculo = vab_pb_estimado,
      ocupados = puestos_trabajo,
      vab_precios_constantes = NA_real_,
      ganancia_pb = vab_pb_calculo - consumo_capital_fijo - costo_laboral,
      ganancia_pp = vab_pp - consumo_capital_fijo - costo_laboral,
      # DECISION: The requested identity is VBP - VAB_bruto. In the current
      # panel, the complete observed VBP/VAB pair is at producer prices.
      consumo_intermedio = vbp_pp - vab_pp,
      capital_circulante_adelantado = (
        costo_laboral + consumo_intermedio
      ) / rotacion,
      capital_total_adelantado = stock_capital + capital_circulante_adelantado,
      tasa_ganancia_pb = safe_divide(
        ganancia_pb,
        stock_capital + capital_circulante_adelantado
      ),
      tasa_ganancia_pp = safe_divide(
        ganancia_pp,
        stock_capital + capital_circulante_adelantado
      ),
      productividad_trabajo = safe_divide(vab_precios_constantes, ocupados),
      vab_pp_participacion_total = safe_divide(vab_pp, vab_pp_total),
      vbp_pp_indice_interanual = safe_divide(vbp_pp, lag(vbp_pp)) * 100,
      vab_pp_indice_interanual = safe_divide(vab_pp, lag(vab_pp)) * 100,
      costo_laboral_indice_interanual = safe_divide(
        costo_laboral,
        lag(costo_laboral)
      ) * 100,
      stock_capital_indice_interanual = safe_divide(
        stock_capital,
        lag(stock_capital)
      ) * 100,
      consumo_capital_fijo_indice_interanual = safe_divide(
        consumo_capital_fijo,
        lag(consumo_capital_fijo)
      ) * 100
    ) %>%
    transmute(
      anno,
      ambito,
      seccion,
      rotacion,
      vbp_pp,
      vab_pp,
      vab_pb_calculo,
      consumo_capital_fijo,
      remuneraciones,
      cargas_patronales,
      costo_laboral,
      stock_capital,
      ocupados,
      ganancia_pb,
      ganancia_pp,
      consumo_intermedio,
      capital_circulante_adelantado,
      capital_total_adelantado,
      tasa_ganancia_pb,
      tasa_ganancia_pp,
      vab_precios_constantes,
      productividad_trabajo,
      vab_pp_total,
      vab_pp_participacion_total,
      vbp_pp_indice_interanual,
      vab_pp_indice_interanual,
      costo_laboral_indice_interanual,
      stock_capital_indice_interanual,
      consumo_capital_fijo_indice_interanual
    )
}

calculos_total <- build_calculos_propios(
  economia_total,
  "economia_total",
  vab_total,
  rotacion_economia_total
)

calculos_industrial <- panel %>%
  filter(seccion == "C") %>%
  build_calculos_propios("rama_industrial", vab_total, rotacion_industria)

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
    return(sprintf(
      '<c r="%s" t="inlineStr"><is><t></t></is></c>',
      reference
    ))
  }
  if (is.numeric(value)) {
    formatted <- format_number(value)
    if (formatted == "") {
      return(sprintf(
        '<c r="%s" t="inlineStr"><is><t></t></is></c>',
        reference
      ))
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
    function(column_index) {
      write_cell_xml(1, column_index, header[[column_index]])
    },
    character(1)
  )
  rows[[1]] <- sprintf(
    '<row r="1">%s</row>',
    paste0(header_cells, collapse = "")
  )

  if (nrow(sheet_data) > 0) {
    for (data_row_index in seq_len(nrow(sheet_data))) {
      row_index <- data_row_index + 1
      cells <- vapply(
        seq_along(sheet_data),
        function(column_index) {
          write_cell_xml(
            row_index,
            column_index,
            sheet_data[[column_index]][[data_row_index]]
          )
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

  rows <- rows[!vapply(rows, is.null, logical(1))]
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

core_xml <- function() {
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" ',
    'xmlns:dc="http://purl.org/dc/elements/1.1/" ',
    'xmlns:dcterms="http://purl.org/dc/terms/" ',
    'xmlns:dcmitype="http://purl.org/dc/dcmitype/" ',
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">',
    "<dc:title>Panel EAAE Uruguay</dc:title>",
    "<dc:creator>economia-uruguay R postprocess</dc:creator>",
    "</cp:coreProperties>"
  )
}

write_xlsx_workbook <- function(path, sheets) {
  if (Sys.which("zip") == "") {
    stop("No se encontro el comando del sistema `zip`, necesario para escribir XLSX.")
  }

  sheet_names <- names(sheets)
  output_path <- file.path(normalizePath(dirname(path)), basename(path))
  tmpdir <- tempfile("eaae-xlsx-")
  dir.create(file.path(tmpdir, "_rels"), recursive = TRUE)
  dir.create(file.path(tmpdir, "docProps"), recursive = TRUE)
  dir.create(file.path(tmpdir, "xl", "_rels"), recursive = TRUE)
  dir.create(file.path(tmpdir, "xl", "worksheets"), recursive = TRUE)
  on.exit(unlink(tmpdir, recursive = TRUE), add = TRUE)

  writeLines(content_types_xml(length(sheet_names)), file.path(tmpdir, "[Content_Types].xml"))
  writeLines(root_rels_xml(), file.path(tmpdir, "_rels", ".rels"))
  writeLines(core_xml(), file.path(tmpdir, "docProps", "core.xml"))
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

existing_sheet_names <- readxl::excel_sheets(panel_xlsx_path)
existing_sheet_names <- setdiff(
  existing_sheet_names,
  c(total_sheet, industrial_sheet)
)

existing_sheets <- lapply(
  existing_sheet_names,
  function(sheet_name) {
    readxl::read_excel(
      panel_xlsx_path,
      sheet = sheet_name,
      .name_repair = "minimal"
    )
  }
)
names(existing_sheets) <- existing_sheet_names

output_sheets <- c(
  existing_sheets,
  setNames(list(calculos_total), total_sheet),
  setNames(list(calculos_industrial), industrial_sheet)
)

write_xlsx_workbook(panel_xlsx_path, output_sheets)

message("Hojas actualizadas en ", panel_xlsx_path, ":")
message(" - ", total_sheet)
message(" - ", industrial_sheet)
