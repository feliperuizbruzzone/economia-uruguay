#!/usr/bin/env Rscript

# Add manufacturing imported-input share to the latest EAAE-BCU panel.
#
# Run from the project root after script 23:
#   Rscript command-files/processing-command-files/24_update_panel_eaae_bcu_importado_ci_mussi.R

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
  paste0(series_date, "_prop_importado_consumo_intermedio_manufactura.csv")
)
new_column <- "prop_importado_consumo_intermedio"
industrial_levels <- c(
  "industria_total",
  "industria_sin_papel_coque_refinacion",
  "subrama_industrial"
)

validate_output <- function(output, input_rows, input_cols) {
  if (nrow(output) != input_rows) {
    stop("La actualizacion cambio la cantidad de filas del panel.")
  }
  if (ncol(output) != input_cols + 1L) {
    stop("La actualizacion no agrego exactamente una columna.")
  }
  if (anyDuplicated(output[c("anno", "nivel_panel", "grupo_rev4_homologado")]) > 0) {
    stop("La clave anno + nivel_panel + grupo_rev4_homologado no es unica.")
  }

  industrial_missing <- output %>%
    filter(nivel_panel %in% industrial_levels, is.na(.data[[new_column]]))
  if (nrow(industrial_missing) > 0) {
    stop("Hay filas industriales sin prop_importado_consumo_intermedio.")
  }

  economy_non_missing <- output %>%
    filter(nivel_panel == "economia_total", !is.na(.data[[new_column]]))
  if (nrow(economy_non_missing) > 0) {
    stop("La proporcion manufacturera no debe asignarse a economia_total.")
  }
}

main <- function() {
  if (!file.exists(series_path)) {
    stop(
      "No existe la serie procesada: ",
      series_path,
      ". Ejecute primero 23_process_mussi_importado_consumo_intermedio.R."
    )
  }

  panel <- readr::read_csv(panel_path, show_col_types = FALSE)
  if (new_column %in% names(panel)) {
    panel <- panel %>% select(-all_of(new_column))
  }
  input_rows <- nrow(panel)
  input_cols <- ncol(panel)

  series <- readr::read_csv(series_path, show_col_types = FALSE) %>%
    transmute(
      anno = as.integer(anio),
      prop_importado_consumo_intermedio = as.numeric(prop_importado_consumo_intermedio)
    ) %>%
    filter(anno >= 2001L, anno <= 2024L)

  output <- panel %>%
    left_join(series, by = "anno") %>%
    mutate(
      # DECISION: the source variable is Total manufactura, so it is assigned
      # as a common non-additive manufacturing coefficient to all industrial
      # panel levels and left blank for economy_total.
      prop_importado_consumo_intermedio = if_else(
        nivel_panel %in% industrial_levels,
        prop_importado_consumo_intermedio,
        NA_real_
      )
    )

  validate_output(output, input_rows, input_cols)
  readr::write_csv(output, panel_path, na = "")

  message("Panel actualizado en ", panel_path)
  message("Filas: ", nrow(output), "; columnas: ", ncol(output))
  message("Columna agregada: ", new_column)
}

if (identical(environment(), globalenv())) {
  main()
}
