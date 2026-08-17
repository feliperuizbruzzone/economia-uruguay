#!/usr/bin/env Rscript

# Process Mussi's imported-input share of intermediate consumption.
#
# Run from the project root:
#   Rscript command-files/processing-command-files/23_process_mussi_importado_consumo_intermedio.R

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
  "Comparacion_COU_MIP_Microdatos_Importado_Transable_Combustible_Alimentos.xlsx"
)
analysis_dir <- file.path("data", "analysis-data")
output_date <- Sys.getenv("EAAE_OUTPUT_DATE", unset = format(Sys.Date(), "%Y%m%d"))
output_path <- file.path(
  analysis_dir,
  paste0(output_date, "_prop_importado_consumo_intermedio_manufactura.csv")
)
source_sheet <- "Importado sobre CI"

parse_num <- function(x) {
  suppressWarnings(
    readr::parse_number(
      as.character(x),
      locale = readr::locale(decimal_mark = ".", grouping_mark = ",")
    )
  )
}

read_total_manufactura_raw <- function() {
  raw <- readxl::read_excel(
    input_path,
    sheet = source_sheet,
    col_names = FALSE,
    .name_repair = "minimal"
  )
  names(raw) <- paste0("col", seq_along(raw))

  raw %>%
    slice(5:n()) %>%
    transmute(
      fuente = str_squish(as.character(col1)),
      detalle = str_squish(as.character(col2)),
      anno = as.integer(str_extract(detalle, "\\d{4}")),
      valor_total_manufactura = parse_num(col6),
      es_expandido = str_detect(str_to_lower(detalle), "expandido"),
      es_muestra = str_detect(str_to_lower(detalle), "muestra")
    ) %>%
    filter(!is.na(anno), !is.na(valor_total_manufactura))
}

build_series <- function() {
  raw_values <- read_total_manufactura_raw()

  selected_by_source <- raw_values %>%
    group_by(anno, fuente) %>%
    mutate(
      # DECISION: when microdata report both sample and expanded values for the
      # same year/source, use the expanded value as requested by the researcher.
      usar_valor = if (any(es_expandido)) es_expandido else rep(TRUE, n())
    ) %>%
    filter(usar_valor) %>%
    summarise(
      valor_fuente = mean(valor_total_manufactura, na.rm = TRUE),
      detalles_usados = paste(sort(unique(detalle)), collapse = " | "),
      .groups = "drop"
    )

  final_observed <- selected_by_source %>%
    group_by(anno) %>%
    summarise(
      # DECISION: when more than one independent source remains for the same
      # year, use the simple average of source-specific values.
      prop_importado_consumo_intermedio_observada =
        mean(valor_fuente, na.rm = TRUE),
      fuentes_usadas = paste(sort(unique(fuente)), collapse = " | "),
      detalles_usados = paste(sort(unique(detalles_usados)), collapse = " | "),
      n_fuentes_usadas = n(),
      .groups = "drop"
    )

  fill_average <- mean(
    final_observed$prop_importado_consumo_intermedio_observada,
    na.rm = TRUE
  )

  tibble(anio = 2000:2025) %>%
    left_join(final_observed, by = c("anio" = "anno")) %>%
    mutate(
      prop_importado_consumo_intermedio = coalesce(
        prop_importado_consumo_intermedio_observada,
        fill_average
      ),
      metodo_valor = if_else(
        is.na(prop_importado_consumo_intermedio_observada),
        "imputado_promedio_valores_finales_disponibles",
        "observado_fuentes_disponibles"
      ),
      fuentes_usadas = if_else(
        is.na(fuentes_usadas),
        "promedio_observados_2009_2010_2016_2017",
        fuentes_usadas
      ),
      detalles_usados = if_else(
        is.na(detalles_usados),
        NA_character_,
        detalles_usados
      ),
      n_fuentes_usadas = coalesce(n_fuentes_usadas, 0L),
      promedio_imputacion = fill_average
    ) %>%
    select(
      anio,
      prop_importado_consumo_intermedio,
      metodo_valor,
      fuentes_usadas,
      detalles_usados,
      n_fuentes_usadas,
      prop_importado_consumo_intermedio_observada,
      promedio_imputacion
    )
}

validate_series <- function(output) {
  if (!identical(output$anio, 2000:2025)) {
    stop("La serie no cubre exactamente 2000-2025.")
  }
  if (any(is.na(output$prop_importado_consumo_intermedio))) {
    stop("La serie final tiene valores faltantes.")
  }
  if (any(output$prop_importado_consumo_intermedio < 0 |
          output$prop_importado_consumo_intermedio > 1)) {
    stop("La proporcion importada queda fuera del rango [0, 1].")
  }

  observed_years <- output %>%
    filter(metodo_valor == "observado_fuentes_disponibles") %>%
    pull(anio)
  if (!identical(observed_years, c(2009L, 2010L, 2016L, 2017L))) {
    stop(
      "Anios observados inesperados: ",
      paste(observed_years, collapse = ", ")
    )
  }
}

main <- function() {
  output <- build_series()
  validate_series(output)

  dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(output, output_path, na = "")

  observed <- output %>%
    filter(metodo_valor == "observado_fuentes_disponibles")

  message("CSV escrito en ", output_path)
  message(
    "Filas: ", nrow(output),
    "; anios observados: ", paste(observed$anio, collapse = ", "),
    "; promedio imputacion: ",
    format(unique(output$promedio_imputacion), digits = 8)
  )
}

if (identical(environment(), globalenv())) {
  main()
}
