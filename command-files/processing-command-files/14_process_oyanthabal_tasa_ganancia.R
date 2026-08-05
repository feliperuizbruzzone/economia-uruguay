#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(readxl)
})

SOURCE_URL <- paste0(
  "https://docs.google.com/spreadsheets/d/",
  "1wl2v6myW1Rl0dHAnZBnkSc42yM6wZHOv",
  "/export?format=xlsx"
)

INPUT_DATE <- Sys.getenv("OYANTHABAL_TG_INPUT_DATE", unset = "20260805")
INPUT_DIR <- file.path("data", "input-data", "oyanthabal")
INPUT_FILE <- file.path(
  INPUT_DIR,
  paste0(INPUT_DATE, "_tasa_ganancia_uruguay_oyanthabal.xlsx")
)
OUTPUT_FILE <- file.path(
  "data",
  "analysis-data",
  "oyanthabal_tasa_ganancia_uruguay.csv"
)

download_source <- function() {
  dir.create(INPUT_DIR, recursive = TRUE, showWarnings = FALSE)

  force_download <- identical(Sys.getenv("OYANTHABAL_TG_FORCE_DOWNLOAD"), "1")
  if (file.exists(INPUT_FILE) && !force_download) {
    message("Fuente ya disponible: ", INPUT_FILE)
    return(invisible(INPUT_FILE))
  }

  message("Descargando fuente Oyanthabal: ", SOURCE_URL)
  utils::download.file(
    SOURCE_URL,
    INPUT_FILE,
    mode = "wb",
    quiet = FALSE
  )

  invisible(INPUT_FILE)
}

as_numeric_column <- function(x) {
  suppressWarnings(as.numeric(x))
}

build_tasa_ganancia_uruguay <- function(input_file = INPUT_FILE) {
  required_columns <- c("anio", "tg_total_b", "tg_no_agrario_b")

  raw <- read_excel(
    input_file,
    sheet = "Uruguay",
    .name_repair = "unique_quiet"
  )

  missing_columns <- setdiff(required_columns, names(raw))
  if (length(missing_columns) > 0) {
    stop(
      "Faltan columnas requeridas en hoja Uruguay: ",
      paste(missing_columns, collapse = ", ")
    )
  }

  raw %>%
    transmute(
      anio = as.integer(parse_number(as.character(.data$anio))),
      tg_total_b = as_numeric_column(.data$tg_total_b),
      tg_no_agrario_b = as_numeric_column(.data$tg_no_agrario_b)
    ) %>%
    filter(!is.na(.data$anio), .data$anio >= 2000L) %>%
    arrange(.data$anio)
}

main <- function() {
  download_source()

  output <- build_tasa_ganancia_uruguay()

  # DECISION: The reusable CSV keeps only the Uruguay yearly profit-rate series
  # requested by the researcher, preserving Oyanthabal variable names and
  # filtering the usable panel to 2000 onward.
  dir.create(dirname(OUTPUT_FILE), recursive = TRUE, showWarnings = FALSE)
  write_csv(output, OUTPUT_FILE, na = "")

  message("CSV escrito en ", OUTPUT_FILE)
  message(
    "Filas: ", nrow(output),
    "; rango: ", min(output$anio, na.rm = TRUE),
    "-", max(output$anio, na.rm = TRUE),
    "; NA tg_total_b: ", sum(is.na(output$tg_total_b)),
    "; NA tg_no_agrario_b: ", sum(is.na(output$tg_no_agrario_b))
  )
}

if (identical(environment(), globalenv())) {
  main()
}
