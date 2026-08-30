suppressPackageStartupMessages({
  library(dplyr)
  library(jsonlite)
  library(purrr)
  library(readxl)
})

today <- "20260830"

paths <- list(
  devaluation_xlsx = file.path(
    "data", "analysis-data",
    paste0(today, "_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx")
  ),
  devaluation_md = file.path(
    "docs",
    paste0(today, "_resultados_devaluacion_escenarios_integrados.md")
  ),
  eaae_bcu_md = file.path("docs", "20260819_resultados_eaae_bcu_tres_niveles.md"),
  eaae_bcu_xlsx = file.path(
    "data", "analysis-data",
    "20260819_resultados_eaae_bcu_total_industria_subrama.xlsx"
  ),
  eaae_bcu_csv = file.path(
    "data", "analysis-data",
    "20260819_panel_eeae_bcu_total_industria_subrama.csv"
  ),
  industry_panel_csv = file.path(
    "data", "analysis-data",
    "20260826_panel_eaae_2020_2024_industria.csv"
  ),
  devaluation_figures = file.path(
    "output", "figures",
    paste0("devaluacion_escenarios_integrados_", today)
  ),
  eaae_bcu_figures = file.path(
    "output", "figures",
    "eaae_bcu_tres_niveles_20260819"
  )
)

required_paths <- unlist(paths, use.names = FALSE)
missing_paths <- required_paths[!file.exists(required_paths)]
if (length(missing_paths) > 0) {
  stop(
    "Faltan insumos requeridos para preparar el sitio:\n",
    paste(missing_paths, collapse = "\n")
  )
}

dir.create(file.path("site", "data", "analysis-data"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("site", "data", "docs"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("site", "assets", "figures"), recursive = TRUE, showWarnings = FALSE)

copy_file <- function(from, to_dir) {
  dir.create(to_dir, recursive = TRUE, showWarnings = FALSE)
  to <- file.path(to_dir, basename(from))
  ok <- file.copy(from, to, overwrite = TRUE)
  if (!ok) {
    stop("No se pudo copiar ", from, " hacia ", to)
  }
  to
}

copy_figure_dir <- function(from, to) {
  if (dir.exists(to)) {
    unlink(to, recursive = TRUE)
  }
  dir.create(to, recursive = TRUE, showWarnings = FALSE)
  figure_files <- list.files(from, full.names = TRUE, recursive = FALSE)
  if (length(figure_files) == 0) {
    stop("No hay figuras para copiar en ", from)
  }
  ok <- file.copy(figure_files, to, overwrite = TRUE, recursive = FALSE)
  if (!all(ok)) {
    stop("No se pudieron copiar todas las figuras desde ", from)
  }
  to
}

# DECISION: el sitio GitHub Pages se publica desde site/_site; por eso los
# insumos que deben funcionar como descargas o imágenes del HTML se copian a
# site/data y site/assets. Esto deja el sitio autocontenido y fácil de
# regenerar si cambian los artefactos fuente.
download_sources <- c(
  paths$devaluation_xlsx,
  paths$eaae_bcu_xlsx,
  paths$eaae_bcu_csv,
  paths$industry_panel_csv
)
walk(download_sources, copy_file, to_dir = file.path("site", "data", "analysis-data"))
walk(
  c(paths$devaluation_md, paths$eaae_bcu_md),
  copy_file,
  to_dir = file.path("site", "data", "docs")
)

invisible(copy_figure_dir(
  paths$devaluation_figures,
  file.path("site", "assets", "figures", basename(paths$devaluation_figures))
))
invisible(copy_figure_dir(
  paths$eaae_bcu_figures,
  file.path("site", "assets", "figures", basename(paths$eaae_bcu_figures))
))

scenario_sheets <- c(
  "Escenario 1 - Comercio Exterior",
  "Escenario 2 - Bienes Transables"
)

json_cols <- c(
  "escenario",
  "anno",
  "nivel_panel",
  "seccion",
  "grupo_clasificacion",
  "descripcion_nivel",
  "tipo_cambio_comercial_pesos_usd",
  "tipo_cambio_paridad_pesos_usd",
  "factor_devaluacion",
  "rotacion_calibrada_sobre_6_6",
  "incidencia_consumo_intermedio_estimado",
  "incidencia_remuneraciones",
  "incidencia_intereses_industria_pesos",
  "incidencia_vbp_pp",
  "incidencia_consumo_capital_fijo",
  "incidencia_stock_capital_imputado",
  "vbp_pp",
  "consumo_intermedio_estimado",
  "remuneraciones",
  "consumo_capital_fijo",
  "stock_capital_imputado",
  "capital_total_adelantado",
  "ganancia_pb",
  "ganancia_pb_devaluacion",
  "delta_ganancia_pb_escenario",
  "saldo_sobrevaluacion_ganancia_pb",
  "delta_ganancia_momento2_pct",
  "tasa_ganancia_pb",
  "tasa_ganancia_pb_devaluacion",
  "intereses_industria_pesos",
  "intereses_industria_pesos_devaluacion",
  "delta_intereses_industria_pesos",
  "saldo_vbp",
  "saldo_consumo_intermedio",
  "saldo_remuneraciones",
  "saldo_consumo_capital_fijo",
  "saldo_intereses",
  "ganancia_pb_desp_intereses",
  "ganancia_pb_desp_intereses_devaluacion",
  "saldo_sobrevaluacion_ganancia_pb_desp_intereses",
  "delta_ganancia_desp_intereses_momento2_pct"
)

scenario_data <- map_dfr(scenario_sheets, function(sheet) {
  read_excel(paths$devaluation_xlsx, sheet = sheet) |>
    mutate(escenario = sheet, .before = 1) |>
    select(any_of(json_cols))
})

required_json_cols <- c(
  "escenario",
  "anno",
  "seccion",
  "descripcion_nivel",
  "factor_devaluacion",
  "rotacion_calibrada_sobre_6_6",
  "ganancia_pb",
  "tasa_ganancia_pb"
)
missing_json_cols <- setdiff(required_json_cols, names(scenario_data))
if (length(missing_json_cols) > 0) {
  stop(
    "Faltan columnas requeridas para el JSON interactivo:\n",
    paste(missing_json_cols, collapse = "\n")
  )
}

expected_sections <- c("industria-total", "exportadora", "mercado-interno")
missing_sections <- setdiff(expected_sections, unique(scenario_data$seccion))
if (length(missing_sections) > 0) {
  stop(
    "Faltan secciones esperadas en los escenarios:\n",
    paste(missing_sections, collapse = "\n")
  )
}

json_path <- file.path("site", "data", paste0("devaluacion_segmentos_", today, ".json"))
write_json(
  scenario_data,
  path = json_path,
  dataframe = "rows",
  na = "null",
  pretty = TRUE,
  auto_unbox = TRUE,
  digits = NA
)

message("Sitio preparado con insumos actualizados.")
message("JSON interactivo: ", json_path)
message("Figuras de devaluación: site/assets/figures/", basename(paths$devaluation_figures))
message("Figuras EAAE-BCU: site/assets/figures/", basename(paths$eaae_bcu_figures))
