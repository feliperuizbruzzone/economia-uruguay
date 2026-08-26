#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(tibble)
})

source(file.path(
  "command-files",
  "analysis-command-files",
  "xlsx_minimal_writer.R"
))

date_prefix <- Sys.getenv("EAAE_OUTPUT_DATE", unset = format(Sys.Date(), "%Y%m%d"))

analysis_dir <- file.path("data", "analysis-data")
input_mussi_dir <- file.path("data", "input-data", "mussi")

latest_file <- function(pattern) {
  files <- Sys.glob(pattern)
  if (length(files) == 0) {
    stop("No files found for pattern: ", pattern)
  }
  sort(files)[[length(files)]]
}

safe_divide <- function(numerator, denominator) {
  result <- numerator / denominator
  result[is.na(numerator) | is.na(denominator) | denominator == 0] <- NA_real_
  result
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

coeficiente_variable_col <- function(variable) {
  recode(
    variable,
    "VBP" = "incidencia_vbp_pp",
    "Consumo intermedio" = "incidencia_consumo_intermedio_estimado",
    "Masa salarial" = "incidencia_remuneraciones",
    "Consumo de capital fijo" = "incidencia_consumo_capital_fijo",
    "Stock capital imputado" = "incidencia_stock_capital_imputado",
    "Intereses" = "incidencia_intereses_industria_pesos",
    .default = NA_character_
  )
}

panel_path <- latest_file(file.path(analysis_dir, "*_panel_eaae_2020_2024_industria.csv"))
tipo_cambio_path <- file.path(analysis_dir, "20260812-exportaciones-manufactura-uruguay.csv")
coeficientes_path <- latest_file(file.path(input_mussi_dir, "*-coeficientes-efecto-devaluacion.csv"))

output_workbook_path <- file.path(
  analysis_dir,
  paste0(date_prefix, "_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx")
)

for (path in c(panel_path, tipo_cambio_path, coeficientes_path)) {
  if (!file.exists(path)) {
    stop("Missing required input: ", path)
  }
}

panel <- read_csv(panel_path, show_col_types = FALSE)

tipo_cambio <- read_csv(tipo_cambio_path, show_col_types = FALSE) %>%
  select(
    "anio",
    "tipo_cambio_comercial_pesos_usd",
    "tipo_cambio_paridad_pesos_usd"
  ) %>%
  filter(.data$anio >= 2020, .data$anio <= 2024) %>%
  arrange(.data$anio)

coeficientes_devaluacion <- read_csv(coeficientes_path, show_col_types = FALSE)
incidencia_col <- if ("Incidencia devaluación" %in% names(coeficientes_devaluacion)) {
  "Incidencia devaluación"
} else {
  "Incidencia"
}

assert_columns(
  coeficientes_devaluacion,
  c("seccion", "Variable", incidencia_col, "Efecto", "Formula"),
  "coeficientes-devaluacion"
)

coeficientes_modelo <- coeficientes_devaluacion %>%
  transmute(
    seccion = as.character(.data$seccion),
    Variable = as.character(.data$Variable),
    variable_fuente = if ("variable_fuente" %in% names(coeficientes_devaluacion)) {
      as.character(.data$variable_fuente)
    } else {
      as.character(.data$Variable)
    },
    incidencia_devaluacion = suppressWarnings(as.numeric(.data[[incidencia_col]])),
    Efecto = as.character(.data$Efecto),
    Formula = as.character(.data$Formula),
    Comentario = if ("Comentario" %in% names(coeficientes_devaluacion)) {
      as.character(.data$Comentario)
    } else {
      NA_character_
    },
    Fuente = if ("Fuente" %in% names(coeficientes_devaluacion)) {
      as.character(.data$Fuente)
    } else {
      NA_character_
    }
  )

assert_unique_key(coeficientes_modelo, c("seccion", "Variable"), "coeficientes-devaluacion")

coeficientes_secciones_requeridas <- c(
  "industria-total",
  "exportadora",
  "mercado-interno"
)

coeficientes_variables_requeridas <- c(
  "Consumo intermedio",
  "Masa salarial",
  "Intereses",
  "VBP",
  "Consumo de capital fijo",
  "Stock capital imputado"
)

coeficientes_requeridos <- tibble(
  seccion = rep(coeficientes_secciones_requeridas, each = length(coeficientes_variables_requeridas)),
  Variable = rep(coeficientes_variables_requeridas, times = length(coeficientes_secciones_requeridas))
) %>%
  left_join(coeficientes_modelo, by = c("seccion", "Variable"))

if (any(is.na(coeficientes_requeridos$incidencia_devaluacion))) {
  missing_coeficientes <- coeficientes_requeridos %>%
    filter(is.na(.data$incidencia_devaluacion)) %>%
    transmute(key = paste(.data$seccion, .data$Variable, sep = " / ")) %>%
    pull(.data$key)
  stop("Faltan coeficientes requeridos para devaluación-1: ", paste(missing_coeficientes, collapse = "; "))
}

coeficientes_incidencias <- coeficientes_modelo %>%
  mutate(variable_col = coeficiente_variable_col(.data$Variable)) %>%
  filter(!is.na(.data$variable_col)) %>%
  select("seccion", "variable_col", "incidencia_devaluacion") %>%
  tidyr::pivot_wider(
    names_from = "variable_col",
    values_from = "incidencia_devaluacion"
  )

panel_required <- c(
  "anno",
  "nivel_panel",
  "seccion",
  "grupo_clasificacion",
  "descripcion_nivel",
  "rotacion_calibrada_sobre_6_6",
  "n_subramas_fuente",
  "componentes_divisiones",
  "vbp_pp",
  "consumo_intermedio_estimado",
  "vab_pp",
  "vab_pb_estimado",
  "consumo_capital_fijo",
  "remuneraciones",
  "costo_laboral",
  "stock_capital",
  "stock_capital_imputado",
  "capital_variable_adelantado",
  "capital_circulante_constante_adelantado",
  "capital_circulante_adelantado",
  "capital_total_adelantado",
  "ganancia_pb",
  "ganancia_pp",
  "tasa_ganancia_pb",
  "tasa_ganancia_pp",
  "intereses_industria_eaae_ajuste_90_mill_usd",
  "intereses_industria_pesos",
  "metodo_intereses",
  "ganancia_pb_desp_intereses",
  "ganancia_pp_desp_intereses",
  "tasa_ganancia_pb_desp_intereses",
  "tasa_ganancia_pp_desp_intereses"
)

assert_columns(panel, panel_required, "panel EAAE industria 2020-2024")
assert_unique_key(panel, c("anno", "seccion"), "panel EAAE industria 2020-2024")
assert_unique_key(tipo_cambio, "anio", "tipo-cambio")

escenario_inicial <- panel %>%
  filter(.data$seccion != "combustible") %>%
  select(all_of(panel_required)) %>%
  arrange(.data$anno, factor(.data$seccion, levels = c(
    "industria-total",
    "exportadora",
    "mercado-interno"
  )))

if (!setequal(unique(escenario_inicial$seccion), coeficientes_secciones_requeridas)) {
  stop("Las secciones del escenario inicial no coinciden con las secciones de coeficientes requeridas.")
}

rotaciones <- escenario_inicial %>%
  select(
    "anno",
    "nivel_panel",
    "seccion",
    "descripcion_nivel",
    "rotacion_calibrada_sobre_6_6"
  ) %>%
  mutate(
    fuente_rotacion = case_when(
      .data$seccion == "industria-total" ~ "panel_integrado_eaae_bcu_rotacion_mussi",
      .data$seccion == "exportadora" ~ "definicion_equipo_sector_exportador",
      .data$seccion == "mercado-interno" ~ "definicion_equipo_sector_mercado_interno",
      TRUE ~ NA_character_
    )
  )

devaluacion_1 <- escenario_inicial %>%
  left_join(tipo_cambio, by = c("anno" = "anio")) %>%
  left_join(coeficientes_incidencias, by = "seccion") %>%
  mutate(
    factor_devaluacion =
      safe_divide(.data$tipo_cambio_paridad_pesos_usd, .data$tipo_cambio_comercial_pesos_usd) - 1,
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
      .data$consumo_intermedio_estimado + .data$delta_consumo_intermedio_estimado,
    vab_pp_devaluacion =
      .data$vab_pp + .data$delta_vbp_pp - .data$delta_consumo_intermedio_estimado,
    vab_pb_estimado_devaluacion =
      .data$vab_pb_estimado + .data$delta_vbp_pp - .data$delta_consumo_intermedio_estimado,
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
      safe_divide(.data$delta_consumo_intermedio_estimado, .data$rotacion_calibrada_sobre_6_6),
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
      safe_divide(.data$ganancia_pb_desp_intereses_devaluacion, .data$capital_total_adelantado_devaluacion),
    tasa_ganancia_pp_desp_intereses_devaluacion =
      safe_divide(.data$ganancia_pp_desp_intereses_devaluacion, .data$capital_total_adelantado_devaluacion),
    variacion_ganancia_pb_pct =
      (safe_divide(.data$ganancia_pb_devaluacion, .data$ganancia_pb) - 1) * 100,
    variacion_ganancia_pp_pct =
      (safe_divide(.data$ganancia_pp_devaluacion, .data$ganancia_pp) - 1) * 100,
    variacion_tasa_ganancia_pb_pp =
      (.data$tasa_ganancia_pb_devaluacion - .data$tasa_ganancia_pb) * 100,
    variacion_tasa_ganancia_pp_pp =
      (.data$tasa_ganancia_pp_devaluacion - .data$tasa_ganancia_pp) * 100,
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
    variacion_tasa_ganancia_pb_desp_intereses_pp =
      (.data$tasa_ganancia_pb_desp_intereses_devaluacion -
        .data$tasa_ganancia_pb_desp_intereses) * 100,
    variacion_tasa_ganancia_pp_desp_intereses_pp =
      (.data$tasa_ganancia_pp_desp_intereses_devaluacion -
        .data$tasa_ganancia_pp_desp_intereses) * 100
  ) %>%
  select(
    "anno",
    "nivel_panel",
    "seccion",
    "grupo_clasificacion",
    "descripcion_nivel",
    "tipo_cambio_comercial_pesos_usd",
    "tipo_cambio_paridad_pesos_usd",
    "factor_devaluacion",
    "rotacion_calibrada_sobre_6_6",
    starts_with("incidencia_"),
    "vbp_pp",
    "vbp_pp_devaluacion",
    "delta_vbp_pp",
    "consumo_intermedio_estimado",
    "consumo_intermedio_estimado_devaluacion",
    "delta_consumo_intermedio_estimado",
    "vab_pp",
    "vab_pp_devaluacion",
    "vab_pb_estimado",
    "vab_pb_estimado_devaluacion",
    "remuneraciones",
    "remuneraciones_devaluacion",
    "delta_remuneraciones",
    "consumo_capital_fijo",
    "consumo_capital_fijo_devaluacion",
    "delta_consumo_capital_fijo",
    "stock_capital_imputado",
    "stock_capital_imputado_devaluacion",
    "delta_stock_capital_imputado",
    "capital_variable_adelantado",
    "capital_variable_adelantado_devaluacion",
    "capital_circulante_constante_adelantado",
    "capital_circulante_constante_adelantado_devaluacion",
    "capital_total_adelantado",
    "capital_total_adelantado_devaluacion",
    "ganancia_pb",
    "ganancia_pb_devaluacion",
    "variacion_ganancia_pb_pct",
    "ganancia_pp",
    "ganancia_pp_devaluacion",
    "variacion_ganancia_pp_pct",
    "tasa_ganancia_pb",
    "tasa_ganancia_pb_devaluacion",
    "variacion_tasa_ganancia_pb_pp",
    "tasa_ganancia_pp",
    "tasa_ganancia_pp_devaluacion",
    "variacion_tasa_ganancia_pp_pp",
    "intereses_industria_pesos",
    "intereses_industria_pesos_devaluacion",
    "delta_intereses_industria_pesos",
    "ganancia_pb_desp_intereses",
    "ganancia_pb_desp_intereses_devaluacion",
    "variacion_ganancia_pb_desp_intereses_pct",
    "ganancia_pp_desp_intereses",
    "ganancia_pp_desp_intereses_devaluacion",
    "variacion_ganancia_pp_desp_intereses_pct",
    "tasa_ganancia_pb_desp_intereses",
    "tasa_ganancia_pb_desp_intereses_devaluacion",
    "variacion_tasa_ganancia_pb_desp_intereses_pp",
    "tasa_ganancia_pp_desp_intereses",
    "tasa_ganancia_pp_desp_intereses_devaluacion",
    "variacion_tasa_ganancia_pp_desp_intereses_pp"
  ) %>%
  arrange(.data$anno, factor(.data$seccion, levels = coeficientes_secciones_requeridas))

required_devaluation_cols <- c(
  "factor_devaluacion",
  "incidencia_vbp_pp",
  "incidencia_consumo_intermedio_estimado",
  "incidencia_remuneraciones",
  "incidencia_consumo_capital_fijo",
  "incidencia_stock_capital_imputado",
  "incidencia_intereses_industria_pesos"
)

if (any(devaluacion_1 %>% select(all_of(required_devaluation_cols)) %>% is.na())) {
  stop("Hay faltantes en factores o incidencias de devaluación.")
}

metodologia <- tibble::tribble(
  ~seccion, ~item, ~detalle,
  "estructura", "alcance del libro",
  paste(
    "El libro presenta resultados corrientes para industria manufacturera",
    "agregada y para los grupos de subramas industriales definidos desde la",
    "clasificación Mussi: exportadora y mercado interno. El grupo combustible",
    "se conserva en el panel CSV para trazabilidad contable, pero se excluye",
    "del XLSX de resultados."
  ),
  "fuentes", "panel EAAE 2020-2024",
  paste(
    "El escenario se actualiza desde el panel CSV ya validado:",
    basename(panel_path),
    ". No se recalcula el panel porque los nuevos coeficientes son parametros",
    "de modelamiento de devaluación y no modifican variables base EAAE."
  ),
  "fuentes", "coeficientes de devaluación",
  paste(
    "Los coeficientes se toman desde",
    basename(coeficientes_path),
    ". Industria total conserva los coeficientes originales y los segmentos",
    "exportadora y mercado-interno usan coeficientes diferenciados por sección."
  ),
  "fuentes", "intereses industriales",
  paste(
    "La serie de intereses disponible es anual y corresponde a la industria",
    "manufacturera agregada. No existe en la fuente disponible una apertura",
    "directa por subrama ni por los grupos exportadora y mercado interno."
  ),
  "decision", "criterio de asignación de intereses",
  paste(
    "Para los grupos de subramas, los intereses industriales se asignan",
    "proporcionalmente por participación en el valor bruto de producción a",
    "precios productor de cada grupo dentro del total industrial del mismo año."
  ),
  "formula", "intereses por grupo",
  paste(
    "intereses_grupo = intereses_industria_total *",
    "(vbp_pp_grupo / vbp_pp_industria_total)"
  ),
  "devaluacion", "factor de devaluación",
  paste(
    "factor_devaluacion = tipo_cambio_paridad_pesos_usd /",
    "tipo_cambio_comercial_pesos_usd - 1."
  ),
  "devaluacion", "aplicación por sección",
  paste(
    "La hoja devaluación-1 recalcula VBP, consumo intermedio, remuneraciones,",
    "consumo de capital fijo, stock imputado e intereses con el coeficiente",
    "especifico de la sección correspondiente."
  )
)

coeficientes_metodologia <- coeficientes_modelo %>%
  transmute(
    seccion = paste("coeficientes-devaluacion", .data$seccion, sep = " - "),
    item = .data$Variable,
    detalle = paste(
      "Variable fuente:", .data$variable_fuente,
      "| Incidencia:", .data$incidencia_devaluacion,
      "| Efecto:", .data$Efecto,
      "| Formula:", .data$Formula,
      "| Comentario:", if_else(is.na(.data$Comentario), "", .data$Comentario),
      "| Fuente:", if_else(is.na(.data$Fuente), "", .data$Fuente)
    )
  )

rotaciones_metodologia <- rotaciones %>%
  transmute(
    seccion = "rotaciones",
    item = paste(.data$anno, .data$seccion, sep = " - "),
    detalle = paste(
      "Nivel:", .data$nivel_panel,
      "| Descripcion:", .data$descripcion_nivel,
      "| Rotacion:", .data$rotacion_calibrada_sobre_6_6,
      "| Fuente:", .data$fuente_rotacion
    )
  )

metodologia <- bind_rows(
  metodologia,
  coeficientes_metodologia,
  rotaciones_metodologia
)

write_xlsx_workbook(
  output_workbook_path,
  list(
    `metodología` = metodologia,
    `escenario-inicial` = escenario_inicial,
    `tipo-cambio` = tipo_cambio,
    `devaluación-1` = devaluacion_1
  ),
  title = "Resultados corrientes grupos industria Mussi"
)

cat("Panel CSV usado: ", panel_path, "\n", sep = "")
cat("Coeficientes usados: ", coeficientes_path, "\n", sep = "")
cat("XLSX creado: ", output_workbook_path, "\n", sep = "")
cat("Escenario inicial filas: ", nrow(escenario_inicial), "\n", sep = "")
cat("Devaluación-1 filas: ", nrow(devaluacion_1), "\n", sep = "")
