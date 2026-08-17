#!/usr/bin/env Rscript

# Add Mussi interest-payments input from "TG PN" to industrial subbranch rows.
#
# Run from the project root:
#   Rscript command-files/processing-command-files/22_update_panel_eaae_bcu_intereses_mussi.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(readxl)
})

analysis_dir <- file.path("data", "analysis-data")
input_panel_date <- Sys.getenv("EAAE_INPUT_PANEL_DATE", unset = "20260814")
output_date <- Sys.getenv("EAAE_OUTPUT_DATE", unset = format(Sys.Date(), "%Y%m%d"))

input_panel_path <- file.path(
  analysis_dir,
  paste0(input_panel_date, "_panel_eeae_bcu_total_industria_subrama.csv")
)
output_panel_path <- file.path(
  analysis_dir,
  paste0(output_date, "_panel_eeae_bcu_total_industria_subrama.csv")
)
input_tg_pn_path <- file.path(
  "data",
  "input-data",
  "mussi",
  "20260812-TG PN. Uruguay.xlsx"
)
source_sheet <- "TG PN"
new_column <- "intereses_industria_eaae_ajuste_90_mill_usd"

parse_num <- function(x) {
  suppressWarnings(
    readr::parse_number(
      as.character(x),
      locale = readr::locale(decimal_mark = ".", grouping_mark = ",")
    )
  )
}

read_intereses_mussi <- function() {
  raw <- readxl::read_excel(
    input_tg_pn_path,
    sheet = source_sheet,
    col_names = FALSE,
    .name_repair = "minimal"
  )
  names(raw) <- paste0("col", seq_along(raw))

  raw %>%
    slice(3:n()) %>%
    transmute(
      anno = as.integer(parse_num(col1)),
      intereses_industria_eaae_ajuste_90_mill_usd = parse_num(col9)
    ) %>%
    filter(!is.na(anno)) %>%
    arrange(anno)
}

validate_intereses <- function(intereses) {
  expected_years <- 2001:2025
  if (!identical(intereses$anno, expected_years)) {
    stop(
      "Cobertura inesperada en columna I de TG PN. Observado: ",
      paste(intereses$anno, collapse = ", ")
    )
  }

  observed_panel_years <- 2001:2024
  missing_panel_values <- intereses %>%
    filter(anno %in% observed_panel_years, is.na(.data[[new_column]]))
  if (nrow(missing_panel_values) > 0) {
    message(
      "Columna I sin dato para anios del panel; se conservaran como NA: ",
      paste(missing_panel_values$anno, collapse = ", ")
    )
  }
}

validate_output <- function(output, input_panel, input_cols, intereses) {
  if (nrow(output) != nrow(input_panel)) {
    stop("La actualizacion cambio la cantidad de filas del panel.")
  }
  if (ncol(output) != input_cols + 1L) {
    stop("La actualizacion no agrego exactamente una columna.")
  }
  if (anyDuplicated(output[c("anno", "nivel_panel", "grupo_rev4_homologado")]) > 0) {
    stop("La clave anno + nivel_panel + grupo_rev4_homologado no es unica.")
  }

  source_available_years <- intereses %>%
    filter(anno <= 2024L, !is.na(.data[[new_column]])) %>%
    pull(anno)

  subrama_missing <- output %>%
    filter(
      nivel_panel == "subrama_industrial",
      anno %in% source_available_years,
      is.na(.data[[new_column]])
    )
  if (nrow(subrama_missing) > 0) {
    stop("Hay subramas sin intereses Mussi en anios con dato fuente.")
  }

  aggregate_non_missing <- output %>%
    filter(nivel_panel != "subrama_industrial", !is.na(.data[[new_column]]))
  if (nrow(aggregate_non_missing) > 0) {
    stop("La columna nueva debe quedar vacia fuera de subrama_industrial.")
  }
}

main <- function() {
  panel <- readr::read_csv(input_panel_path, show_col_types = FALSE)
  original_cols <- ncol(panel)

  if (new_column %in% names(panel)) {
    panel <- panel %>% select(-all_of(new_column))
    original_cols <- ncol(panel)
  }

  intereses <- read_intereses_mussi()
  validate_intereses(intereses)

  output <- panel %>%
    left_join(
      intereses %>% filter(anno <= 2024L),
      by = "anno"
    ) %>%
    mutate(
      # DECISION: Column I in TG PN is an annual industry-level input adjusted
      # to EAAE coverage. It is replicated only across subbranch rows as a
      # common non-additive input; aggregate rows are left as NA.
      intereses_industria_eaae_ajuste_90_mill_usd = if_else(
        nivel_panel == "subrama_industrial",
        intereses_industria_eaae_ajuste_90_mill_usd,
        NA_real_
      )
    )

  validate_output(output, panel, original_cols, intereses)

  readr::write_csv(output, output_panel_path, na = "")
  message("Panel escrito en ", output_panel_path)
  message("Filas: ", nrow(output), "; columnas: ", ncol(output))
  message("Columna agregada: ", new_column)
}

if (identical(environment(), globalenv())) {
  main()
}
