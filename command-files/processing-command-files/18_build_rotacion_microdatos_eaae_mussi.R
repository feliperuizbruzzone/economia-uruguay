#!/usr/bin/env Rscript

# Build a reusable rotation workbook from Mussi's EAAE microdata revision.
#
# Run from the project root:
#   Rscript command-files/processing-command-files/18_build_rotacion_microdatos_eaae_mussi.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(readxl)
  library(stringr)
  library(tibble)
  library(tidyr)
})

input_path <- file.path(
  "data",
  "input-data",
  "mussi",
  "20260812-Revision_Rotacion_Capital_Microdatos_EAAE.xlsx"
)
homologation_path <- file.path(
  "command-files",
  "config",
  "eaae_industria_subramas_rev4_homologacion.csv"
)
panel_reference_path <- file.path(
  "data",
  "analysis-data",
  "20260727_panel_eeae_bcu_total_industria_subrama.csv"
)
output_path <- file.path(
  "data",
  "analysis-data",
  "20260812-rotacion-microdatos-eaae-mussi.xlsx"
)
source_sheet <- "Rotacion por subrama y año"
trim_fraction <- as.numeric(Sys.getenv("MUSSI_ROTACION_TRIM", unset = "0.10"))

if (is.na(trim_fraction) || trim_fraction < 0 || trim_fraction >= 0.5) {
  stop("MUSSI_ROTACION_TRIM debe estar en el intervalo [0, 0.5).")
}

safe_parse_number <- function(x) {
  suppressWarnings(
    readr::parse_number(
      as.character(x),
      locale = readr::locale(decimal_mark = ".", grouping_mark = ",")
    )
  )
}

xml_escape <- function(x) {
  x <- as.character(x)
  x <- str_replace_all(x, "&", "&amp;")
  x <- str_replace_all(x, "<", "&lt;")
  x <- str_replace_all(x, ">", "&gt;")
  x <- str_replace_all(x, "\"", "&quot;")
  x <- str_replace_all(x, "'", "&apos;")
  x
}

excel_col <- function(n) {
  out <- character(length(n))
  for (i in seq_along(n)) {
    value <- n[[i]]
    label <- ""
    while (value > 0) {
      rem <- (value - 1) %% 26
      label <- paste0(LETTERS[[rem + 1]], label)
      value <- (value - 1) %/% 26
    }
    out[[i]] <- label
  }
  out
}

cell_xml <- function(value, row, col, numeric_cell = FALSE) {
  if (length(value) == 0 || is.na(value)) {
    return("")
  }
  ref <- paste0(excel_col(col), row)
  if (numeric_cell && is.finite(as.numeric(value))) {
    return(paste0(
      '<c r="', ref, '"><v>',
      format(as.numeric(value), digits = 15, scientific = FALSE, trim = TRUE),
      "</v></c>"
    ))
  }
  paste0(
    '<c r="', ref, '" t="inlineStr"><is><t>',
    xml_escape(value),
    "</t></is></c>"
  )
}

worksheet_xml <- function(df) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  names(df) <- as.character(names(df))
  numeric_cols <- vapply(df, is.numeric, logical(1))

  row_xml <- character(nrow(df) + 1)
  header_cells <- vapply(
    seq_along(df),
    function(j) cell_xml(names(df)[[j]], 1L, j, FALSE),
    character(1)
  )
  row_xml[[1]] <- paste0('<row r="1">', paste(header_cells, collapse = ""), "</row>")

  if (nrow(df) > 0) {
    for (i in seq_len(nrow(df))) {
      cells <- vapply(
        seq_along(df),
        function(j) cell_xml(df[[j]][[i]], i + 1L, j, numeric_cols[[j]]),
        character(1)
      )
      row_xml[[i + 1L]] <- paste0(
        '<row r="', i + 1L, '">',
        paste(cells, collapse = ""),
        "</row>"
      )
    }
  }

  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    "<sheetData>",
    paste(row_xml, collapse = ""),
    "</sheetData>",
    "</worksheet>"
  )
}

content_types_xml <- function(n_sheets) {
  sheet_overrides <- paste0(
    '<Override PartName="/xl/worksheets/sheet',
    seq_len(n_sheets),
    '.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
    collapse = ""
  )
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
    '<Default Extension="xml" ContentType="application/xml"/>',
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>',
    '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>',
    sheet_overrides,
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

workbook_xml <- function(sheet_names) {
  sheets <- paste0(
    '<sheet name="',
    xml_escape(sheet_names),
    '" sheetId="',
    seq_along(sheet_names),
    '" r:id="rId',
    seq_along(sheet_names),
    '"/>',
    collapse = ""
  )
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ',
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
    "<sheets>",
    sheets,
    "</sheets>",
    "</workbook>"
  )
}

workbook_rels_xml <- function(sheet_names) {
  rels <- paste0(
    '<Relationship Id="rId',
    seq_along(sheet_names),
    '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet',
    seq_along(sheet_names),
    '.xml"/>',
    collapse = ""
  )
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    rels,
    "</Relationships>"
  )
}

app_xml <- function(sheet_names) {
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" ',
    'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">',
    "<Application>economia-uruguay</Application>",
    "<TitlesOfParts><vt:vector size=\"",
    length(sheet_names),
    "\" baseType=\"lpstr\">",
    paste0("<vt:lpstr>", xml_escape(sheet_names), "</vt:lpstr>", collapse = ""),
    "</vt:vector></TitlesOfParts>",
    "</Properties>"
  )
}

core_xml <- function() {
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" ',
    'xmlns:dc="http://purl.org/dc/elements/1.1/" ',
    'xmlns:dcterms="http://purl.org/dc/terms/" ',
    'xmlns:dcmitype="http://purl.org/dc/terms/" ',
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">',
    "<dc:title>Rotacion microdatos EAAE Mussi</dc:title>",
    "<dc:creator>economia-uruguay R processing script</dc:creator>",
    "</cp:coreProperties>"
  )
}

write_xlsx_workbook <- function(path, sheets) {
  if (Sys.which("zip") == "") {
    stop("No se encontro el comando del sistema `zip`, necesario para escribir XLSX.")
  }

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  sheet_names <- names(sheets)
  output_file <- file.path(normalizePath(dirname(path)), basename(path))
  tmpdir <- tempfile("rotacion-mussi-xlsx-")
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

  for (i in seq_along(sheets)) {
    writeLines(
      worksheet_xml(sheets[[i]]),
      file.path(tmpdir, "xl", "worksheets", paste0("sheet", i, ".xml"))
    )
  }

  oldwd <- setwd(tmpdir)
  on.exit(setwd(oldwd), add = TRUE)
  if (file.exists(output_file)) {
    file.remove(output_file)
  }
  files <- list.files(".", all.files = TRUE, recursive = TRUE, no.. = TRUE)
  utils::zip(zipfile = output_file, files = files, flags = "-r9Xq")
}

read_mussi_rotation <- function() {
  raw <- readxl::read_excel(
    input_path,
    sheet = source_sheet,
    skip = 2,
    .name_repair = "minimal"
  )
  names(raw)[1:3] <- c("clase_ciiu", "nombre_subrama", "grupo_mussi")

  raw %>%
    filter(!is.na(clase_ciiu)) %>%
    mutate(
      clase_ciiu = as.integer(safe_parse_number(clase_ciiu)),
      division_rev4 = as.integer(substr(sprintf("%04d", clase_ciiu), 1, 2))
    ) %>%
    filter(!is.na(clase_ciiu), !is.na(division_rev4)) %>%
    pivot_longer(
      cols = -c(clase_ciiu, nombre_subrama, grupo_mussi, division_rev4),
      names_to = "columna_fuente",
      values_to = "rotacion_raw"
    ) %>%
    mutate(
      columna_fuente = str_squish(as.character(columna_fuente)),
      anno = as.integer(str_extract(columna_fuente, "^[0-9]{4}")),
      indicador = str_squish(str_remove(columna_fuente, "^[0-9]{4}")),
      indicador = recode(indicador, "Cap.P" = "cap_p", "Balance" = "balance"),
      rotacion = safe_parse_number(rotacion_raw)
    ) %>%
    filter(!is.na(anno), !is.na(rotacion), rotacion > 0)
}

build_results <- function() {
  rotation_raw <- read_mussi_rotation()

  homologation <- readr::read_csv(homologation_path, show_col_types = FALSE) %>%
    filter(
      ciiu_version_fuente == "Rev.4",
      incluir_sector_industrial_rev4 == "si"
    ) %>%
    transmute(
      division_rev4 = as.integer(codigo_fuente_2dig),
      grupo_rev4_homologado,
      descripcion_grupo_rev4_homologado
    ) %>%
    distinct()

  panel_groups <- readr::read_csv(panel_reference_path, show_col_types = FALSE) %>%
    filter(nivel_panel == "subrama_industrial") %>%
    distinct(grupo_rev4_homologado, descripcion_nivel) %>%
    arrange(grupo_rev4_homologado)

  mapped <- rotation_raw %>%
    left_join(homologation, by = "division_rev4")

  missing_map <- mapped %>%
    filter(is.na(grupo_rev4_homologado)) %>%
    distinct(clase_ciiu, division_rev4, nombre_subrama)

  if (nrow(missing_map) > 0) {
    stop(
      "Hay clases CIIU sin homologacion industrial Rev.4: ",
      paste(capture.output(print(missing_map)), collapse = " ")
    )
  }

  selected <- mapped %>%
    group_by(grupo_rev4_homologado) %>%
    mutate(
      n_balance_disponible = sum(indicador == "balance", na.rm = TRUE),
      indicador_usado = if_else(
        n_balance_disponible > 2L,
        "balance",
        "todos_los_indicadores_disponibles"
      ),
      usar = if_else(n_balance_disponible > 2L, indicador == "balance", TRUE)
    ) %>%
    ungroup() %>%
    filter(usar)

  results <- selected %>%
    group_by(grupo_rev4_homologado, indicador_usado) %>%
    summarise(
      rotacion_microdatos_eaae_mussi = mean(rotacion, trim = trim_fraction, na.rm = TRUE),
      rotacion_media_simple = mean(rotacion, na.rm = TRUE),
      rotacion_mediana = median(rotacion, na.rm = TRUE),
      rotacion_p10 = as.numeric(quantile(rotacion, 0.10, na.rm = TRUE, names = FALSE)),
      rotacion_p90 = as.numeric(quantile(rotacion, 0.90, na.rm = TRUE, names = FALSE)),
      rotacion_min = min(rotacion, na.rm = TRUE),
      rotacion_max = max(rotacion, na.rm = TRUE),
      n_observaciones_usadas = n(),
      n_anios_usados = n_distinct(anno),
      anios_usados = paste(sort(unique(anno)), collapse = "|"),
      n_clases_ciiu4_usadas = n_distinct(clase_ciiu),
      clases_ciiu4_usadas = paste(sort(unique(clase_ciiu)), collapse = "|"),
      divisiones_rev4_incluidas = paste(sort(unique(division_rev4)), collapse = "|"),
      grupos_mussi_incluidos = paste(sort(unique(na.omit(grupo_mussi))), collapse = "|"),
      trim_por_cola = trim_fraction,
      .groups = "drop"
    ) %>%
    left_join(panel_groups, by = "grupo_rev4_homologado") %>%
    arrange(grupo_rev4_homologado) %>%
    transmute(
      nivel_panel = "subrama_industrial",
      seccion = "C",
      grupo_rev4_homologado,
      descripcion_nivel,
      rotacion_calibrada_sobre_6_6 = rotacion_microdatos_eaae_mussi,
      rotacion_microdatos_eaae_mussi,
      indicador_usado,
      metodo_rotacion = paste0(
        "promedio_recortado_",
        trim_por_cola * 100,
        "pct_por_cola_prioriza_balance"
      ),
      trim_por_cola,
      rotacion_media_simple,
      rotacion_mediana,
      rotacion_p10,
      rotacion_p90,
      rotacion_min,
      rotacion_max,
      n_observaciones_usadas,
      n_anios_usados,
      anios_usados,
      n_clases_ciiu4_usadas,
      clases_ciiu4_usadas,
      divisiones_rev4_incluidas,
      grupos_mussi_incluidos,
      fuente = "mussi_microdatos_eaae",
      archivo_fuente = basename(input_path),
      hoja_fuente = source_sheet
    )

  missing_panel_groups <- anti_join(panel_groups, results, by = "grupo_rev4_homologado")
  if (nrow(missing_panel_groups) > 0) {
    stop(
      "Hay subramas del panel sin rotacion Mussi: ",
      paste(capture.output(print(missing_panel_groups)), collapse = " ")
    )
  }

  list(results = results, raw = mapped)
}

build_methodology <- function(results, raw) {
  tibble::tribble(
    ~seccion, ~item, ~detalle,
    "fuente", "archivo", input_path,
    "fuente", "hoja", source_sheet,
    "cobertura", "anios con datos", paste(sort(unique(raw$anno)), collapse = ", "),
    "cobertura", "clases CIIU 4 digitos", as.character(n_distinct(raw$clase_ciiu)),
    "compatibilidad", "homologacion", "La clase CIIU Rev.4 a 4 digitos se reduce a division Rev.4 de dos digitos y se une con command-files/config/eaae_industria_subramas_rev4_homologacion.csv.",
    "compatibilidad", "panel de referencia", panel_reference_path,
    "criterio", "indicador", "Si una subrama homologada tiene mas de dos observaciones validas de Balance, se usa Balance. En caso contrario se promedian todos los indicadores disponibles.",
    "criterio", "promedio recortado", paste0("La rotacion operativa es mean(rotacion, trim = ", trim_fraction, ") sobre las observaciones seleccionadas."),
    "criterio", "valores extremos", "El promedio recortado evita que observaciones puntuales muy altas dominen la rotacion unica de subrama; se conservan media simple, mediana, p10, p90, minimo y maximo para auditoria.",
    "salida", "hoja resultados", "Una fila por grupo Rev.4 homologado compatible con el panel EAAE-BCU. La columna rotacion_calibrada_sobre_6_6 se expone con el nombre esperado por el panel.",
    "variable", "rotacion_microdatos_eaae_mussi", "Promedio recortado de la rotacion seleccionada para cada subrama homologada.",
    "variable", "rotacion_calibrada_sobre_6_6", "Alias operativo usado para reemplazar la columna del panel integrado manteniendo compatibilidad con scripts existentes.",
    "variable", "indicador_usado", "Indica si se uso Balance o todos los indicadores disponibles.",
    "variable", "n_observaciones_usadas", "Cantidad de observaciones clase-anio-indicador usadas en el promedio recortado.",
    "variable", "n_anios_usados", "Cantidad de anios con datos validos usados en la subrama."
  )
}

main <- function() {
  built <- build_results()
  methodology <- build_methodology(built$results, built$raw)

  # DECISION: The user selected a trimmed mean to avoid extreme microdata
  # rotations. Balance is privileged where it has enough observations because
  # it uses inventories from the balance sheet/bienes de cambio definition.
  write_xlsx_workbook(
    output_path,
    list(
      "metodología" = methodology,
      "resultados" = built$results
    )
  )

  message("XLSX escrito en ", output_path)
  message("Subramas: ", nrow(built$results), "; trim por cola: ", trim_fraction)
}

if (identical(environment(), globalenv())) {
  main()
}
