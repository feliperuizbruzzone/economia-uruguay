#!/usr/bin/env Rscript

# Add Mussi export/devaluation inputs to the current dated EAAE-BCU panel.
#
# Run from the project root after script 20:
#   Rscript command-files/processing-command-files/21_update_panel_eaae_bcu_exportaciones_mussi.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

analysis_dir <- file.path("data", "analysis-data")
panel_date <- Sys.getenv("EAAE_PANEL_DATE", unset = "20260814")
panel_path <- file.path(
  analysis_dir,
  paste0(panel_date, "_panel_eeae_bcu_total_industria_subrama.csv")
)
exportaciones_path <- file.path(
  analysis_dir,
  "20260812-exportaciones-manufactura-uruguay.csv"
)

panel_export_input_cols <- c(
  "exportaciones_manufactura_eaae_95_miles_usd",
  "tipo_cambio_comercial_pesos_usd",
  "tipo_cambio_paridad_pesos_usd"
)

read_export_inputs <- function() {
  readr::read_csv(exportaciones_path, show_col_types = FALSE) %>%
    transmute(
      anno = as.integer(anio),
      exportaciones_manufactura_eaae_95_miles_usd =
        as.numeric(exportaciones_manufactura_eaae_95_miles_usd),
      tipo_cambio_comercial_pesos_usd =
        as.numeric(tipo_cambio_comercial_pesos_usd),
      tipo_cambio_paridad_pesos_usd =
        as.numeric(tipo_cambio_paridad_pesos_usd)
    ) %>%
    filter(!is.na(anno))
}

validate_panel_update <- function(panel, original_rows, original_cols) {
  if (nrow(panel) != original_rows) {
    stop("La actualizacion cambio filas del panel.")
  }
  if (ncol(panel) != original_cols + length(panel_export_input_cols)) {
    stop("La actualizacion no agrego la cantidad esperada de columnas.")
  }
  if (anyDuplicated(panel[c("anno", "nivel_panel", "grupo_rev4_homologado")]) > 0) {
    stop("La clave anno + nivel_panel + grupo_rev4_homologado no es unica.")
  }
  if (any(is.na(panel[panel_export_input_cols]))) {
    stop("Hay faltantes en los insumos de exportaciones/tipo de cambio anexados.")
  }
  if ("exportaciones_manufactura_miles_usd" %in% names(panel)) {
    stop("No debe incorporarse al panel la exportacion fuente sin correccion EAAE.")
  }
}

main <- function() {
  if (!file.exists(exportaciones_path)) {
    stop(
      "No existe la base de exportaciones: ",
      exportaciones_path,
      ". Ejecute primero 20_process_mussi_exportaciones_manufactura.R."
    )
  }

  panel <- readr::read_csv(panel_path, show_col_types = FALSE)
  original_rows <- nrow(panel)
  original_cols <- ncol(panel)
  export_inputs <- read_export_inputs()

  duplicated_new_cols <- intersect(names(panel), panel_export_input_cols)
  if (length(duplicated_new_cols) > 0) {
    panel <- panel %>% select(-all_of(duplicated_new_cols))
    original_cols <- ncol(panel)
  }

  output <- panel %>%
    left_join(export_inputs, by = "anno")

  # DECISION: The integrated panel receives only inputs needed for later
  # devaluation scenarios: EAAE-adjusted manufacturing exports and the two
  # exchange-rate levels. The source unadjusted export series and downstream
  # scenario calculations remain in the standalone export CSV.
  validate_panel_update(output, original_rows, original_cols)
  readr::write_csv(output, panel_path, na = "")

  message("Panel actualizado en ", panel_path)
  message("Filas: ", nrow(output), "; columnas: ", ncol(output))
  message("Columnas agregadas: ", paste(panel_export_input_cols, collapse = ", "))
}

if (identical(environment(), globalenv())) {
  main()
}
