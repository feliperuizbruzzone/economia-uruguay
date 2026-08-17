#!/usr/bin/env Rscript

# Process Mussi's imported component of the wage basket.
#
# Run from the project root:
#   Rscript command-files/processing-command-files/25_process_mussi_consumo_obrero_importado.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(readxl)
  library(stringr)
  library(tidyr)
})

input_path <- file.path(
  "data",
  "input-data",
  "mussi",
  "20260812-Revision_Rotacion_Capital_Microdatos_EAAE.xlsx"
)
analysis_dir <- file.path("data", "analysis-data")
output_date <- Sys.getenv("EAAE_OUTPUT_DATE", unset = format(Sys.Date(), "%Y%m%d"))
output_path <- file.path(
  analysis_dir,
  paste0(output_date, "_prop_consumo_obrero_importado_mussi.csv")
)
source_sheet <- "cuadro % masa salarial"

parse_num <- function(x) {
  suppressWarnings(
    readr::parse_number(
      as.character(x),
      locale = readr::locale(decimal_mark = ".", grouping_mark = ",")
    )
  )
}

build_source_values <- function() {
  raw <- readxl::read_excel(
    input_path,
    sheet = source_sheet,
    col_names = FALSE,
    .name_repair = "minimal"
  )
  names(raw) <- paste0("col", seq_along(raw))

  rows <- raw %>%
    mutate(row_id = row_number()) %>%
    transmute(
      row_id,
      fuente = str_squish(as.character(col1)),
      rubro = str_squish(as.character(col2)),
      valor_pct = parse_num(col3)
    )

  source_headers <- rows %>%
    filter(!is.na(fuente), fuente %in% c("COU", "MIP")) %>%
    transmute(
      source_row = row_id,
      fuente,
      Observaciones = rubro,
      anio_fuente = as.integer(str_extract(rubro, "\\d{4}"))
    )

  import_rows <- rows %>%
    filter(rubro == "Importado en la masa salarial") %>%
    transmute(import_row = row_id, prop_consumo_obrero_importado = valor_pct)

  source_headers %>%
    rowwise() %>%
    mutate(
      import_row = min(import_rows$import_row[import_rows$import_row > source_row])
    ) %>%
    ungroup() %>%
    left_join(import_rows, by = "import_row") %>%
    filter(!is.na(prop_consumo_obrero_importado)) %>%
    transmute(
      tipo_registro = "fuente",
      fuente,
      anio_fuente,
      prop_consumo_obrero_importado,
      Observaciones
    )
}

build_output <- function() {
  source_values <- build_source_values()
  promedio <- mean(source_values$prop_consumo_obrero_importado, na.rm = TRUE)

  promedio_row <- tibble(
    tipo_registro = "promedio",
    fuente = "promedio_fuentes_disponibles",
    anio_fuente = NA_integer_,
    prop_consumo_obrero_importado = promedio,
    Observaciones = paste0(
      "Promedio simple de valores disponibles: ",
      paste(source_values$Observaciones, collapse = " | ")
    )
  )

  bind_rows(source_values, promedio_row)
}

validate_output <- function(output) {
  source_values <- output %>% filter(tipo_registro == "fuente")
  if (nrow(source_values) != 3L) {
    stop("Se esperaban 3 valores fuente: COU 2016, COU 2017 y MIP 2016.")
  }
  if (any(is.na(source_values$prop_consumo_obrero_importado))) {
    stop("Hay valores fuente faltantes.")
  }
  if (any(source_values$prop_consumo_obrero_importado < 0 |
          source_values$prop_consumo_obrero_importado > 1)) {
    stop("Hay proporciones fuera de rango [0, 1].")
  }

  promedio_row <- output %>% filter(tipo_registro == "promedio")
  if (nrow(promedio_row) != 1L) {
    stop("Debe existir exactamente una fila de promedio.")
  }

  expected_average <- mean(source_values$prop_consumo_obrero_importado)
  if (abs(promedio_row$prop_consumo_obrero_importado - expected_average) > 1e-12) {
    stop("El promedio calculado no coincide con los valores fuente.")
  }
}

main <- function() {
  output <- build_output()
  validate_output(output)

  # DECISION: The reusable CSV keeps the individual source values and one
  # simple average row. The downstream panel uses only the average.
  dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(output, output_path, na = "")

  promedio <- output %>%
    filter(tipo_registro == "promedio") %>%
    pull(prop_consumo_obrero_importado)

  message("CSV escrito en ", output_path)
  message("Filas: ", nrow(output), "; promedio: ", format(promedio, digits = 8))
}

if (identical(environment(), globalenv())) {
  main()
}
