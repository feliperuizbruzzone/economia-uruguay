#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(readxl)
})

root_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

source(file.path(
  root_dir,
  "command-files",
  "analysis-command-files",
  "xlsx_minimal_writer.R"
))

latest_file <- function(pattern) {
  files <- Sys.glob(pattern)
  if (length(files) == 0) {
    stop("No files found for pattern: ", pattern)
  }
  sort(files)[[length(files)]]
}

assert_columns <- function(data, columns, label) {
  missing <- setdiff(columns, names(data))
  if (length(missing) > 0) {
    stop(label, " is missing required columns: ", paste(missing, collapse = ", "))
  }
}

assert_unique_key <- function(data, key, label) {
  duplicated_rows <- data %>%
    count(across(all_of(key)), name = "n") %>%
    filter(.data$n > 1)

  if (nrow(duplicated_rows) > 0) {
    stop(label, " has duplicated keys for: ", paste(key, collapse = " + "))
  }
}

safe_divide <- function(numerator, denominator) {
  ifelse(is.na(denominator) | denominator == 0, NA_real_, numerator / denominator)
}

analysis_dir <- file.path(root_dir, "data", "analysis-data")
input_dir <- file.path(root_dir, "data", "input-data")

resultados_path <- latest_file(file.path(
  analysis_dir,
  "*_resultados_eaae_bcu_total_industria_subrama.xlsx"
))
panel_path <- latest_file(file.path(
  analysis_dir,
  "*_panel_eeae_bcu_total_industria_subrama.csv"
))
tipo_cambio_path <- file.path(
  analysis_dir,
  "20260812-exportaciones-manufactura-uruguay.csv"
)
coeficientes_path <- file.path(
  input_dir,
  "mussi",
  "20260819-coeficientes-efecto-devaluacion.csv"
)

output_path <- file.path(
  analysis_dir,
  paste0(format(Sys.Date(), "%Y%m%d"), "_modalamiento-devaluacion.xlsx")
)

for (path in c(resultados_path, panel_path, tipo_cambio_path, coeficientes_path)) {
  if (!file.exists(path)) {
    stop("Missing required input file: ", path)
  }
}

resultados_corrientes_raw <- read_excel(
  resultados_path,
  sheet = "resultados-corrientes"
)
eaae_raw <- read_excel(
  resultados_path,
  sheet = "eaae"
)
panel_integrado <- read_csv(panel_path, show_col_types = FALSE)
tipo_cambio <- read_csv(tipo_cambio_path, show_col_types = FALSE) %>%
  select(
    anio,
    tipo_cambio_comercial_pesos_usd,
    tipo_cambio_paridad_pesos_usd
  ) %>%
  arrange(.data$anio)
coeficientes_devaluacion <- read_csv(coeficientes_path, show_col_types = FALSE)

id_cols <- c(
  "anno",
  "nivel_panel",
  "seccion",
  "descripcion_nivel"
)
join_cols <- c(
  "anno",
  "nivel_panel",
  "seccion"
)
resultados_cols <- c(
  "vbp_pp",
  "consumo_intermedio_estimado",
  "vab_pp",
  "vab_pb_estimado",
  "capital_circulante_constante_adelantado",
  "remuneraciones",
  "capital_variable_adelantado",
  "importaciones_maquinaria",
  "fbcf",
  "consumo_capital_fijo",
  "stock_capital",
  "stock_capital_imputado",
  "capital_total_adelantado",
  # DECISION: no existe una columna literal "ganancia despues de impuestos"
  # en la hoja corriente. Se preservan las dos variantes existentes.
  "ganancia_pb",
  "ganancia_pp",
  "tasa_ganancia_pb",
  "tasa_ganancia_pp"
)
eaae_cols <- c("intereses_industria_eaae_ajuste_90_mill_usd")
panel_cols <- c(
  "anno",
  "nivel_panel",
  "seccion",
  "rotacion_calibrada_sobre_6_6"
)

assert_columns(
  resultados_corrientes_raw,
  c(id_cols, resultados_cols),
  "resultados-corrientes"
)
assert_columns(eaae_raw, c(join_cols, eaae_cols), "eaae")
assert_columns(panel_integrado, panel_cols, "panel integrado")
assert_columns(
  tipo_cambio,
  c("anio", "tipo_cambio_comercial_pesos_usd", "tipo_cambio_paridad_pesos_usd"),
  "tipo-cambio"
)

assert_unique_key(resultados_corrientes_raw, join_cols, "resultados-corrientes")
assert_unique_key(eaae_raw, join_cols, "eaae")
assert_unique_key(tipo_cambio, "anio", "tipo-cambio")

rotacion_industria_total <- panel_integrado %>%
  filter(.data$nivel_panel == "industria_total", .data$seccion == "C") %>%
  select(
    anno,
    rotacion_calibrada_sobre_6_6
  )

assert_unique_key(rotacion_industria_total, "anno", "rotacion industria total")

if (nrow(rotacion_industria_total) != 24) {
  stop("La rotacion de industria total debe cubrir 24 años.")
}

incidencia_col <- if ("Incidencia devaluación" %in% names(coeficientes_devaluacion)) {
  "Incidencia devaluación"
} else {
  "Incidencia"
}

assert_columns(
  coeficientes_devaluacion,
  c("Variable", incidencia_col, "Efecto", "Formula"),
  "coeficientes-devaluacion"
)

coeficientes_modelo <- coeficientes_devaluacion %>%
  transmute(
    Variable = as.character(.data$Variable),
    incidencia_devaluacion = suppressWarnings(as.numeric(.data[[incidencia_col]])),
    Efecto = as.character(.data$Efecto),
    Formula = as.character(.data$Formula)
  )

coeficientes_requeridos <- tibble::tribble(
  ~Variable, ~variable_canonica,
  "Consumo intermedio", "consumo_intermedio_estimado",
  "Masa salarial", "remuneraciones",
  "Intereses", "intereses_industria_pesos",
  "VBP", "vbp_pp",
  "Consumo de capital fijo", "consumo_capital_fijo",
  "Stock capital imputado", "stock_capital_imputado"
) %>%
  left_join(coeficientes_modelo, by = "Variable")

if (
  any(is.na(coeficientes_requeridos$incidencia_devaluacion)) ||
    any(is.na(coeficientes_requeridos$Efecto)) ||
    any(is.na(coeficientes_requeridos$Formula))
) {
  stop("Faltan coeficientes requeridos para construir devaluacion-1.")
}

coeficiente_de <- function(variable) {
  coeficientes_requeridos %>%
    filter(.data$Variable == variable) %>%
    pull(.data$incidencia_devaluacion)
}

# DECISION: el libro se limita a manufactura agregada. Los intereses son una
# serie anual agregada de industria que en `eaae` esta replicada solo en filas
# de subrama como insumo comun no aditivo; por eso se toma un unico valor anual
# distinto y no se suman subramas.
intereses_industria_total <- eaae_raw %>%
  filter(!is.na(.data$intereses_industria_eaae_ajuste_90_mill_usd)) %>%
  distinct(
    .data$anno,
    .data$intereses_industria_eaae_ajuste_90_mill_usd
  )

intereses_duplicados <- intereses_industria_total %>%
  count(.data$anno, name = "n_valores") %>%
  filter(.data$n_valores > 1)

if (nrow(intereses_duplicados) > 0) {
  stop("La hoja eaae tiene mas de un valor anual distinto de intereses.")
}

resultados_corrientes <- resultados_corrientes_raw %>%
  filter(.data$seccion == "industria-total") %>%
  select(all_of(c(id_cols, resultados_cols))) %>%
  left_join(intereses_industria_total, by = "anno") %>%
  left_join(tipo_cambio, by = c("anno" = "anio")) %>%
  mutate(
    # DECISION: los intereses fuente estan en millones de USD. Para mantener
    # las ganancias en la misma unidad que los resultados corrientes EAAE, se
    # convierten a pesos corrientes con el tipo de cambio comercial anual.
    intereses_industria_pesos =
      .data$intereses_industria_eaae_ajuste_90_mill_usd *
      1000000 *
      .data$tipo_cambio_comercial_pesos_usd,
    ganancia_pb_desp_intereses =
      .data$ganancia_pb - .data$intereses_industria_pesos,
    ganancia_pp_desp_intereses =
      .data$ganancia_pp - .data$intereses_industria_pesos,
    tasa_ganancia_pb_desp_intereses =
      safe_divide(.data$ganancia_pb_desp_intereses, .data$capital_total_adelantado),
    tasa_ganancia_pp_desp_intereses =
      safe_divide(.data$ganancia_pp_desp_intereses, .data$capital_total_adelantado)
  ) %>%
  select(
    -tipo_cambio_comercial_pesos_usd,
    -tipo_cambio_paridad_pesos_usd
  ) %>%
  arrange(.data$anno)

rotacion_validacion <- resultados_corrientes %>%
  left_join(rotacion_industria_total, by = "anno") %>%
  mutate(
    rotacion_implicita_consumo_intermedio =
      safe_divide(
        .data$consumo_intermedio_estimado,
        .data$capital_circulante_constante_adelantado
      ),
    rotacion_implicita_remuneraciones =
      safe_divide(.data$remuneraciones, .data$capital_variable_adelantado),
    diferencia_rotacion_consumo_intermedio =
      abs(.data$rotacion_implicita_consumo_intermedio -
        .data$rotacion_calibrada_sobre_6_6),
    diferencia_rotacion_remuneraciones =
      abs(.data$rotacion_implicita_remuneraciones -
        .data$rotacion_calibrada_sobre_6_6)
  )

if (any(is.na(rotacion_validacion$rotacion_calibrada_sobre_6_6))) {
  stop("Hay años de industria total sin rotacion explicita del panel.")
}

if (
  max(rotacion_validacion$diferencia_rotacion_consumo_intermedio, na.rm = TRUE) > 1e-8 ||
    max(rotacion_validacion$diferencia_rotacion_remuneraciones, na.rm = TRUE) > 1e-8
) {
  stop("La rotacion explicita del panel no coincide con la rotacion implicita del libro.")
}

# DECISION: `devaluacion-1` modela el salto completo del tipo de cambio
# comercial al tipo de cambio de paridad. Las variables afectadas se actualizan
# con la formula fuente: valor + valor * incidencia * ((tcp / tcc) - 1). La
# columna `Efecto` se usa como interpretacion sobre ganancia: VBP suma; costos,
# stock e intereses reducen ganancia o elevan el denominador.
devaluacion_1 <- resultados_corrientes %>%
  left_join(tipo_cambio, by = c("anno" = "anio")) %>%
  left_join(rotacion_industria_total, by = "anno") %>%
  mutate(
    factor_devaluacion =
      safe_divide(
        .data$tipo_cambio_paridad_pesos_usd,
        .data$tipo_cambio_comercial_pesos_usd
      ) - 1,
    incidencia_vbp_pp = coeficiente_de("VBP"),
    incidencia_consumo_intermedio_estimado = coeficiente_de("Consumo intermedio"),
    incidencia_remuneraciones = coeficiente_de("Masa salarial"),
    incidencia_consumo_capital_fijo = coeficiente_de("Consumo de capital fijo"),
    incidencia_stock_capital_imputado = coeficiente_de("Stock capital imputado"),
    incidencia_intereses_industria_pesos = coeficiente_de("Intereses"),
    delta_vbp_pp =
      .data$vbp_pp * .data$incidencia_vbp_pp * .data$factor_devaluacion,
    delta_consumo_intermedio_estimado =
      .data$consumo_intermedio_estimado *
      .data$incidencia_consumo_intermedio_estimado *
      .data$factor_devaluacion,
    delta_remuneraciones =
      .data$remuneraciones *
      .data$incidencia_remuneraciones *
      .data$factor_devaluacion,
    delta_consumo_capital_fijo =
      .data$consumo_capital_fijo *
      .data$incidencia_consumo_capital_fijo *
      .data$factor_devaluacion,
    delta_stock_capital_imputado =
      .data$stock_capital_imputado *
      .data$incidencia_stock_capital_imputado *
      .data$factor_devaluacion,
    delta_intereses_industria_pesos =
      .data$intereses_industria_pesos *
      .data$incidencia_intereses_industria_pesos *
      .data$factor_devaluacion,
    vbp_pp_devaluacion =
      .data$vbp_pp + .data$delta_vbp_pp,
    consumo_intermedio_estimado_devaluacion =
      .data$consumo_intermedio_estimado +
      .data$delta_consumo_intermedio_estimado,
    vab_pp_devaluacion =
      .data$vab_pp +
      .data$delta_vbp_pp -
      .data$delta_consumo_intermedio_estimado,
    vab_pb_estimado_devaluacion =
      .data$vab_pb_estimado +
      .data$delta_vbp_pp -
      .data$delta_consumo_intermedio_estimado,
    remuneraciones_devaluacion =
      .data$remuneraciones + .data$delta_remuneraciones,
    consumo_capital_fijo_devaluacion =
      .data$consumo_capital_fijo + .data$delta_consumo_capital_fijo,
    stock_capital_imputado_devaluacion =
      .data$stock_capital_imputado + .data$delta_stock_capital_imputado,
    intereses_industria_pesos_devaluacion =
      .data$intereses_industria_pesos + .data$delta_intereses_industria_pesos,
    capital_variable_adelantado_devaluacion =
      .data$capital_variable_adelantado +
      safe_divide(.data$delta_remuneraciones, .data$rotacion_calibrada_sobre_6_6),
    capital_circulante_constante_adelantado_devaluacion =
      .data$capital_circulante_constante_adelantado +
      safe_divide(
        .data$delta_consumo_intermedio_estimado,
        .data$rotacion_calibrada_sobre_6_6
      ),
    # DECISION: el libro compacto no expone `capital_circulante_adelantado` ni
    # `costo_laboral`. Por eso se conserva el denominador base observado y se
    # agregan solo los cambios atribuibles a las variables afectadas disponibles.
    capital_total_adelantado_devaluacion =
      .data$capital_total_adelantado +
      .data$delta_stock_capital_imputado +
      safe_divide(
        .data$delta_remuneraciones + .data$delta_consumo_intermedio_estimado,
        .data$rotacion_calibrada_sobre_6_6
      ),
    ganancia_pb_devaluacion =
      .data$ganancia_pb +
      .data$delta_vbp_pp -
      .data$delta_consumo_intermedio_estimado -
      .data$delta_remuneraciones -
      .data$delta_consumo_capital_fijo,
    ganancia_pp_devaluacion =
      .data$ganancia_pp +
      .data$delta_vbp_pp -
      .data$delta_consumo_intermedio_estimado -
      .data$delta_remuneraciones -
      .data$delta_consumo_capital_fijo,
    ganancia_pb_desp_intereses_devaluacion =
      .data$ganancia_pb_devaluacion - .data$intereses_industria_pesos_devaluacion,
    ganancia_pp_desp_intereses_devaluacion =
      .data$ganancia_pp_devaluacion - .data$intereses_industria_pesos_devaluacion,
    tasa_ganancia_pb_devaluacion =
      safe_divide(.data$ganancia_pb_devaluacion, .data$capital_total_adelantado_devaluacion),
    tasa_ganancia_pp_devaluacion =
      safe_divide(.data$ganancia_pp_devaluacion, .data$capital_total_adelantado_devaluacion),
    tasa_ganancia_pb_desp_intereses_devaluacion =
      safe_divide(
        .data$ganancia_pb_desp_intereses_devaluacion,
        .data$capital_total_adelantado_devaluacion
      ),
    tasa_ganancia_pp_desp_intereses_devaluacion =
      safe_divide(
        .data$ganancia_pp_desp_intereses_devaluacion,
        .data$capital_total_adelantado_devaluacion
      ),
    variacion_ganancia_pb_pct =
      (safe_divide(.data$ganancia_pb_devaluacion, .data$ganancia_pb) - 1) * 100,
    variacion_ganancia_pp_pct =
      (safe_divide(.data$ganancia_pp_devaluacion, .data$ganancia_pp) - 1) * 100,
    variacion_ganancia_pb_desp_intereses_pct =
      (safe_divide(
        .data$ganancia_pb_desp_intereses_devaluacion,
        .data$ganancia_pb_desp_intereses
      ) - 1) * 100,
    variacion_ganancia_pp_desp_intereses_pct =
      (safe_divide(
        .data$ganancia_pp_desp_intereses_devaluacion,
        .data$ganancia_pp_desp_intereses
      ) - 1) * 100,
    variacion_tasa_ganancia_pb_pp =
      (.data$tasa_ganancia_pb_devaluacion - .data$tasa_ganancia_pb) * 100,
    variacion_tasa_ganancia_pp_pp =
      (.data$tasa_ganancia_pp_devaluacion - .data$tasa_ganancia_pp) * 100,
    variacion_tasa_ganancia_pb_desp_intereses_pp =
      (.data$tasa_ganancia_pb_desp_intereses_devaluacion -
        .data$tasa_ganancia_pb_desp_intereses) * 100,
    variacion_tasa_ganancia_pp_desp_intereses_pp =
      (.data$tasa_ganancia_pp_desp_intereses_devaluacion -
        .data$tasa_ganancia_pp_desp_intereses) * 100
  ) %>%
  select(
    anno,
    nivel_panel,
    seccion,
    descripcion_nivel,
    tipo_cambio_comercial_pesos_usd,
    tipo_cambio_paridad_pesos_usd,
    factor_devaluacion,
    rotacion_calibrada_sobre_6_6,
    starts_with("incidencia_"),
    vbp_pp,
    vbp_pp_devaluacion,
    delta_vbp_pp,
    consumo_intermedio_estimado,
    consumo_intermedio_estimado_devaluacion,
    delta_consumo_intermedio_estimado,
    vab_pp,
    vab_pp_devaluacion,
    vab_pb_estimado,
    vab_pb_estimado_devaluacion,
    remuneraciones,
    remuneraciones_devaluacion,
    delta_remuneraciones,
    consumo_capital_fijo,
    consumo_capital_fijo_devaluacion,
    delta_consumo_capital_fijo,
    stock_capital_imputado,
    stock_capital_imputado_devaluacion,
    delta_stock_capital_imputado,
    capital_variable_adelantado,
    capital_variable_adelantado_devaluacion,
    capital_circulante_constante_adelantado,
    capital_circulante_constante_adelantado_devaluacion,
    capital_total_adelantado,
    capital_total_adelantado_devaluacion,
    ganancia_pb,
    ganancia_pb_devaluacion,
    variacion_ganancia_pb_pct,
    ganancia_pp,
    ganancia_pp_devaluacion,
    variacion_ganancia_pp_pct,
    tasa_ganancia_pb,
    tasa_ganancia_pb_devaluacion,
    variacion_tasa_ganancia_pb_pp,
    tasa_ganancia_pp,
    tasa_ganancia_pp_devaluacion,
    variacion_tasa_ganancia_pp_pp,
    intereses_industria_pesos,
    intereses_industria_pesos_devaluacion,
    delta_intereses_industria_pesos,
    ganancia_pb_desp_intereses,
    ganancia_pb_desp_intereses_devaluacion,
    variacion_ganancia_pb_desp_intereses_pct,
    ganancia_pp_desp_intereses,
    ganancia_pp_desp_intereses_devaluacion,
    variacion_ganancia_pp_desp_intereses_pct,
    tasa_ganancia_pb_desp_intereses,
    tasa_ganancia_pb_desp_intereses_devaluacion,
    variacion_tasa_ganancia_pb_desp_intereses_pp,
    tasa_ganancia_pp_desp_intereses,
    tasa_ganancia_pp_desp_intereses_devaluacion,
    variacion_tasa_ganancia_pp_desp_intereses_pp
  ) %>%
  arrange(.data$anno)

if (nrow(devaluacion_1) != 24) {
  stop("La hoja devaluacion-1 debe tener 24 filas.")
}

if (any(is.na(devaluacion_1$factor_devaluacion))) {
  stop("Hay años sin factor de devaluacion.")
}

write_xlsx_workbook(
  output_path,
  list(
    `resultados-corrientes` = resultados_corrientes,
    `tipo-cambio` = tipo_cambio,
    `coeficientes-devaluacion` = coeficientes_devaluacion,
    `devaluación-1` = devaluacion_1
  ),
  title = "Modelamiento devaluacion"
)

cat("Archivo creado: ", output_path, "\n", sep = "")
cat("Fuente resultados: ", resultados_path, "\n", sep = "")
cat("Fuente panel: ", panel_path, "\n", sep = "")
cat("Filas resultados-corrientes: ", nrow(resultados_corrientes), "\n", sep = "")
cat("Filas tipo-cambio: ", nrow(tipo_cambio), "\n", sep = "")
cat("Filas coeficientes-devaluacion: ", nrow(coeficientes_devaluacion), "\n", sep = "")
cat("Filas devaluacion-1: ", nrow(devaluacion_1), "\n", sep = "")
cat(
  "No faltantes intereses: ",
  sum(!is.na(resultados_corrientes$intereses_industria_eaae_ajuste_90_mill_usd)),
  "\n",
  sep = ""
)
cat(
  "No faltantes intereses_industria_pesos: ",
  sum(!is.na(resultados_corrientes$intereses_industria_pesos)),
  "\n",
  sep = ""
)
