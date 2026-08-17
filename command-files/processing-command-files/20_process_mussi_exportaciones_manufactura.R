#!/usr/bin/env Rscript

# Process Mussi's manufacturing export/devaluation scenario workbook.
#
# Run from the project root:
#   Rscript command-files/processing-command-files/20_process_mussi_exportaciones_manufactura.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(readxl)
})

input_path <- file.path(
  "data",
  "input-data",
  "mussi",
  "20260812-Exportaciones.Uruguay.xlsx"
)
output_path <- file.path(
  "data",
  "analysis-data",
  "20260812-exportaciones-manufactura-uruguay.csv"
)
source_sheet <- "Eventual devaluación"

parse_num <- function(x) {
  suppressWarnings(
    readr::parse_number(
      as.character(x),
      locale = readr::locale(decimal_mark = ".", grouping_mark = ",")
    )
  )
}

build_exportaciones_manufactura <- function() {
  raw <- readxl::read_excel(
    input_path,
    sheet = source_sheet,
    col_names = FALSE,
    .name_repair = "minimal"
  )
  names(raw) <- paste0("col", seq_along(raw))

  output <- raw %>%
    slice(5:n()) %>%
    transmute(
      anio = as.integer(parse_num(col1)),
      exportaciones_manufactura_miles_usd = parse_num(col2),
      exportaciones_manufactura_eaae_95_miles_usd = parse_num(col3),
      tipo_cambio_comercial_pesos_usd = parse_num(col4),
      tipo_cambio_paridad_pesos_usd = parse_num(col5),
      tipo_cambio_paridad_sobre_comercial = parse_num(col6),
      exportaciones_manufactura_tcc_miles_pesos = parse_num(col7),
      exportaciones_manufactura_tcp_miles_pesos = parse_num(col8),
      incremento_exportador_miles_pesos = parse_num(col9),
      incremento_exportador_sobre_exportaciones_tcc = parse_num(col10)
    ) %>%
    filter(!is.na(anio)) %>%
    arrange(anio)

  # DECISION: Keep both the source manufacturing exports and the EAAE-adjusted
  # 95% series in this reusable CSV. Downstream panel integration uses only the
  # corrected EAAE-compatible exports plus exchange-rate inputs.
  output
}

validate_output <- function(output) {
  expected_years <- 2000:2024
  if (!identical(output$anio, expected_years)) {
    stop(
      "Cobertura anual inesperada. Esperado 2000-2024; observado: ",
      paste(output$anio, collapse = ", ")
    )
  }

  checks <- tibble::tibble(
    identidad = c(
      "exportaciones_manufactura_eaae_95_miles_usd = exportaciones_manufactura_miles_usd * 0.95",
      "tipo_cambio_paridad_sobre_comercial = tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd",
      "exportaciones_manufactura_tcc_miles_pesos = exportaciones_manufactura_eaae_95_miles_usd * tipo_cambio_comercial_pesos_usd",
      "exportaciones_manufactura_tcp_miles_pesos = exportaciones_manufactura_eaae_95_miles_usd * tipo_cambio_paridad_pesos_usd",
      "incremento_exportador_miles_pesos = exportaciones_manufactura_tcp_miles_pesos - exportaciones_manufactura_tcc_miles_pesos",
      "incremento_exportador_sobre_exportaciones_tcc = incremento_exportador_miles_pesos / exportaciones_manufactura_tcc_miles_pesos"
    ),
    max_abs_diff = c(
      max(abs(
        output$exportaciones_manufactura_eaae_95_miles_usd -
          output$exportaciones_manufactura_miles_usd * 0.95
      ), na.rm = TRUE),
      max(abs(
        output$tipo_cambio_paridad_sobre_comercial -
          output$tipo_cambio_paridad_pesos_usd /
            output$tipo_cambio_comercial_pesos_usd
      ), na.rm = TRUE),
      max(abs(
        output$exportaciones_manufactura_tcc_miles_pesos -
          output$exportaciones_manufactura_eaae_95_miles_usd *
            output$tipo_cambio_comercial_pesos_usd
      ), na.rm = TRUE),
      max(abs(
        output$exportaciones_manufactura_tcp_miles_pesos -
          output$exportaciones_manufactura_eaae_95_miles_usd *
            output$tipo_cambio_paridad_pesos_usd
      ), na.rm = TRUE),
      max(abs(
        output$incremento_exportador_miles_pesos -
          (
            output$exportaciones_manufactura_tcp_miles_pesos -
              output$exportaciones_manufactura_tcc_miles_pesos
          )
      ), na.rm = TRUE),
      max(abs(
        output$incremento_exportador_sobre_exportaciones_tcc -
          output$incremento_exportador_miles_pesos /
            output$exportaciones_manufactura_tcc_miles_pesos
      ), na.rm = TRUE)
    )
  )

  bad_checks <- checks %>% filter(max_abs_diff > 1e-4)
  if (nrow(bad_checks) > 0) {
    stop(
      "No cierran identidades de exportaciones: ",
      paste(capture.output(print(bad_checks)), collapse = " ")
    )
  }
}

main <- function() {
  output <- build_exportaciones_manufactura()
  validate_output(output)

  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(output, output_path, na = "")

  message("CSV escrito en ", output_path)
  message(
    "Filas: ", nrow(output),
    "; rango: ", min(output$anio), "-", max(output$anio)
  )
}

if (identical(environment(), globalenv())) {
  main()
}
