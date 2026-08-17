#!/usr/bin/env Rscript

# Update the integrated EAAE-BCU panel with Mussi microdata rotations.
#
# Run from the project root after script 18:
#   Rscript command-files/processing-command-files/19_update_panel_eaae_bcu_rotacion_mussi.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(readxl)
})

analysis_dir <- file.path("data", "analysis-data")
input_panel_date <- Sys.getenv("EAAE_INPUT_PANEL_DATE", unset = "20260727")
date_prefix <- Sys.getenv("EAAE_OUTPUT_DATE", unset = format(Sys.Date(), "%Y%m%d"))

input_panel_path <- file.path(
  analysis_dir,
  paste0(input_panel_date, "_panel_eeae_bcu_total_industria_subrama.csv")
)
rotation_workbook_path <- file.path(
  analysis_dir,
  "20260812-rotacion-microdatos-eaae-mussi.xlsx"
)
output_panel_path <- file.path(
  analysis_dir,
  paste0(date_prefix, "_panel_eeae_bcu_total_industria_subrama.csv")
)

excluded_industry_groups <- c(
  "17_18_papel_impresion",
  "19_refinacion"
)

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

read_rotation_results <- function() {
  readxl::read_excel(rotation_workbook_path, sheet = "resultados") %>%
    transmute(
      grupo_rev4_homologado = as.character(grupo_rev4_homologado),
      rotacion_mussi = suppressWarnings(as.numeric(rotacion_microdatos_eaae_mussi)),
      metodo_rotacion_mussi = as.character(metodo_rotacion)
    ) %>%
    filter(!is.na(grupo_rev4_homologado), !is.na(rotacion_mussi)) %>%
    distinct(grupo_rev4_homologado, .keep_all = TRUE)
}

recalculate_with_own_rotation <- function(panel) {
  panel %>%
    mutate(
      capital_variable_adelantado = safe_divide(
        remuneraciones,
        rotacion_calibrada_sobre_6_6
      ),
      capital_circulante_constante_adelantado = safe_divide(
        consumo_intermedio_estimado,
        rotacion_calibrada_sobre_6_6
      ),
      capital_circulante_adelantado = safe_divide(
        costo_laboral + consumo_intermedio,
        rotacion_calibrada_sobre_6_6
      ),
      capital_total_adelantado =
        stock_capital_imputado + capital_circulante_adelantado,
      tasa_ganancia_pb = safe_divide(ganancia_pb, capital_total_adelantado),
      tasa_ganancia_pp = safe_divide(ganancia_pp, capital_total_adelantado)
    )
}

replace_aggregate_from_subramas <- function(panel, target_level, groups_to_include) {
  aggregate_advanced <- panel %>%
    filter(
      nivel_panel == "subrama_industrial",
      grupo_rev4_homologado %in% groups_to_include
    ) %>%
    group_by(anno) %>%
    summarise(
      capital_variable_adelantado_mussi =
        sum_present(capital_variable_adelantado),
      capital_circulante_constante_adelantado_mussi =
        sum_present(capital_circulante_constante_adelantado),
      capital_circulante_adelantado_mussi =
        sum_present(capital_circulante_adelantado),
      .groups = "drop"
    )

  panel %>%
    left_join(aggregate_advanced, by = "anno") %>%
    mutate(
      capital_variable_adelantado = if_else(
        nivel_panel == target_level,
        capital_variable_adelantado_mussi,
        capital_variable_adelantado
      ),
      capital_circulante_constante_adelantado = if_else(
        nivel_panel == target_level,
        capital_circulante_constante_adelantado_mussi,
        capital_circulante_constante_adelantado
      ),
      capital_circulante_adelantado = if_else(
        nivel_panel == target_level,
        capital_circulante_adelantado_mussi,
        capital_circulante_adelantado
      ),
      capital_total_adelantado = if_else(
        nivel_panel == target_level,
        stock_capital_imputado + capital_circulante_adelantado,
        capital_total_adelantado
      ),
      rotacion_calibrada_sobre_6_6 = if_else(
        nivel_panel == target_level,
        safe_divide(costo_laboral + consumo_intermedio, capital_circulante_adelantado),
        rotacion_calibrada_sobre_6_6
      ),
      tasa_ganancia_pb = if_else(
        nivel_panel == target_level,
        safe_divide(ganancia_pb, capital_total_adelantado),
        tasa_ganancia_pb
      ),
      tasa_ganancia_pp = if_else(
        nivel_panel == target_level,
        safe_divide(ganancia_pp, capital_total_adelantado),
        tasa_ganancia_pp
      )
    ) %>%
    select(
      -capital_variable_adelantado_mussi,
      -capital_circulante_constante_adelantado_mussi,
      -capital_circulante_adelantado_mussi
    )
}

update_constant_columns <- function(panel) {
  # DECISION: The integrated panel already stores constant-2005 versions for a
  # subset of calculated variables. Recalculate only those present in the file,
  # preserving the panel schema.
  source_cols <- c(
    "capital_total_adelantado",
    "tasa_ganancia_pb",
    "tasa_ganancia_pp"
  )

  for (source_col in source_cols) {
    constant_col <- paste0(source_col, "_constante_2005")
    if (constant_col %in% names(panel)) {
      panel[[constant_col]] <- safe_divide(panel[[source_col]], panel$deflactor_2005)
    }
  }

  panel
}

validate_output <- function(panel, rotations, original_rows) {
  if (nrow(panel) != original_rows) {
    stop("La cantidad de filas cambio: ", nrow(panel), "; original: ", original_rows)
  }

  expected_subrama_groups <- panel %>%
    filter(nivel_panel == "subrama_industrial") %>%
    distinct(grupo_rev4_homologado)

  missing_rotations <- anti_join(
    expected_subrama_groups,
    rotations,
    by = "grupo_rev4_homologado"
  )
  if (nrow(missing_rotations) > 0) {
    stop(
      "Hay subramas sin rotacion Mussi: ",
      paste(capture.output(print(missing_rotations)), collapse = " ")
    )
  }

  if (any(is.na(panel$rotacion_calibrada_sobre_6_6))) {
    stop("Hay filas sin rotacion_calibrada_sobre_6_6.")
  }

  if ("rotacion" %in% names(panel)) {
    stop("La columna generica rotacion no debe exportarse.")
  }

  inconsistent <- panel %>%
    filter(nivel_panel %in% c(
      "subrama_industrial",
      "industria_total",
      "industria_sin_papel_coque_refinacion"
    )) %>%
    mutate(
      capital_circulante_check =
        safe_divide(costo_laboral + consumo_intermedio, rotacion_calibrada_sobre_6_6),
      diferencia_abs = abs(capital_circulante_check - capital_circulante_adelantado)
    ) %>%
    filter(!is.na(diferencia_abs), diferencia_abs > 1e-4)

  if (nrow(inconsistent) > 0) {
    stop("Hay inconsistencias en capital circulante adelantado tras actualizar rotacion.")
  }
}

main <- function() {
  if (!file.exists(rotation_workbook_path)) {
    stop(
      "No existe el workbook de rotacion: ",
      rotation_workbook_path,
      ". Ejecute primero 18_build_rotacion_microdatos_eaae_mussi.R."
    )
  }

  panel <- readr::read_csv(input_panel_path, show_col_types = FALSE) %>%
    mutate(.orden_original = row_number())
  rotations <- read_rotation_results()

  panel_updated <- panel %>%
    left_join(rotations, by = "grupo_rev4_homologado") %>%
    mutate(
      # DECISION: Mussi rotations are available at homologated manufacturing
      # subbranch level. Economy total keeps the previous 4.2 value. Aggregate
      # industry levels are recalculated below as implied rotations from the
      # updated subbranch advanced circulating capital.
      rotacion_calibrada_sobre_6_6 = if_else(
        nivel_panel == "subrama_industrial",
        rotacion_mussi,
        rotacion_calibrada_sobre_6_6
      )
    ) %>%
    select(-rotacion_mussi, -metodo_rotacion_mussi)

  panel_updated <- bind_rows(
    panel_updated %>%
      filter(nivel_panel != "subrama_industrial"),
    panel_updated %>%
      filter(nivel_panel == "subrama_industrial") %>%
      recalculate_with_own_rotation()
  )

  all_subrama_groups <- panel_updated %>%
    filter(nivel_panel == "subrama_industrial") %>%
    distinct(grupo_rev4_homologado) %>%
    pull(grupo_rev4_homologado)

  included_depurada_groups <- setdiff(all_subrama_groups, excluded_industry_groups)

  panel_updated <- panel_updated %>%
    replace_aggregate_from_subramas("industria_total", all_subrama_groups) %>%
    replace_aggregate_from_subramas(
      "industria_sin_papel_coque_refinacion",
      included_depurada_groups
    ) %>%
    update_constant_columns() %>%
    arrange(.orden_original) %>%
    select(-.orden_original)

  validate_output(panel_updated, rotations, nrow(panel))

  # DECISION: Keep the historical 20260727 panel as input and write a new dated
  # version so the rotation update is auditable and reversible.
  readr::write_csv(panel_updated, output_panel_path, na = "")

  message("Panel actualizado escrito en ", output_panel_path)
  message("Filas: ", nrow(panel_updated), "; columnas: ", ncol(panel_updated))
}

if (identical(environment(), globalenv())) {
  main()
}
