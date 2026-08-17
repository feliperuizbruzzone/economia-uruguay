#!/usr/bin/env Rscript

# Add imported wage-basket share to industrial subbranch rows in EAAE-BCU panel.
#
# Run from the project root after script 25:
#   Rscript command-files/processing-command-files/26_update_panel_eaae_bcu_consumo_obrero_mussi.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

analysis_dir <- file.path("data", "analysis-data")
panel_date <- Sys.getenv("EAAE_PANEL_DATE", unset = "20260817")
series_date <- Sys.getenv("EAAE_SERIES_DATE", unset = panel_date)

panel_path <- file.path(
  analysis_dir,
  paste0(panel_date, "_panel_eeae_bcu_total_industria_subrama.csv")
)
series_path <- file.path(
  analysis_dir,
  paste0(series_date, "_prop_consumo_obrero_importado_mussi.csv")
)
new_column <- "prop_consumo_obrero_importado"

read_average_value <- function() {
  readr::read_csv(series_path, show_col_types = FALSE) %>%
    filter(tipo_registro == "promedio") %>%
    pull(prop_consumo_obrero_importado)
}

validate_output <- function(output, input_rows, input_cols, average_value) {
  if (nrow(output) != input_rows) {
    stop("La actualizacion cambio la cantidad de filas del panel.")
  }
  if (ncol(output) != input_cols + 1L) {
    stop("La actualizacion no agrego exactamente una columna.")
  }
  if (anyDuplicated(output[c("anno", "nivel_panel", "grupo_rev4_homologado")]) > 0) {
    stop("La clave anno + nivel_panel + grupo_rev4_homologado no es unica.")
  }

  subramas <- output %>% filter(nivel_panel == "subrama_industrial")
  if (any(is.na(subramas[[new_column]]))) {
    stop("Hay subramas sin prop_consumo_obrero_importado.")
  }
  if (any(abs(subramas[[new_column]] - average_value) > 1e-12)) {
    stop("La proporcion anexada no coincide con el promedio fuente.")
  }

  non_subrama <- output %>%
    filter(nivel_panel != "subrama_industrial", !is.na(.data[[new_column]]))
  if (nrow(non_subrama) > 0) {
    stop("La proporcion de consumo obrero importado solo debe asignarse a subramas.")
  }
}

main <- function() {
  if (!file.exists(series_path)) {
    stop(
      "No existe la serie procesada: ",
      series_path,
      ". Ejecute primero 25_process_mussi_consumo_obrero_importado.R."
    )
  }

  average_value <- read_average_value()
  if (length(average_value) != 1L || is.na(average_value)) {
    stop("No se encontro un promedio unico de prop_consumo_obrero_importado.")
  }

  panel <- readr::read_csv(panel_path, show_col_types = FALSE)
  if (new_column %in% names(panel)) {
    panel <- panel %>% select(-all_of(new_column))
  }
  input_rows <- nrow(panel)
  input_cols <- ncol(panel)

  output <- panel %>%
    mutate(
      # DECISION: The source is an aggregate manufacturing wage-basket share.
      # It is replicated as a common non-additive scenario coefficient only for
      # subbranch rows, as requested by the researcher.
      prop_consumo_obrero_importado = if_else(
        nivel_panel == "subrama_industrial",
        average_value,
        NA_real_
      )
    )

  validate_output(output, input_rows, input_cols, average_value)
  readr::write_csv(output, panel_path, na = "")

  message("Panel actualizado en ", panel_path)
  message("Filas: ", nrow(output), "; columnas: ", ncol(output))
  message("Columna agregada: ", new_column, "; valor: ", format(average_value, digits = 8))
}

if (identical(environment(), globalenv())) {
  main()
}
