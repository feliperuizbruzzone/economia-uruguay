#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(tibble)
  library(tidyr)
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

normalise_incidence <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  # DECISION: coefficient workbooks may store incidences either as proportions
  # or as percentages. Values greater than one are interpreted as percentages.
  if_else(!is.na(x) & abs(x) > 1, x / 100, x)
}

build_scenario_sheet <- function(
  scenario_name,
  escenario_inicial,
  tipo_cambio,
  coeficientes_modelo,
  coeficientes_variables_requeridas,
  section_order
) {
  coeficientes_scenario <- coeficientes_modelo %>%
    filter(.data$escenario_nombre == !!scenario_name)

  coeficientes_requeridos <- expand_grid(
    seccion = section_order,
    Variable = coeficientes_variables_requeridas
  ) %>%
    left_join(coeficientes_scenario, by = c("seccion", "Variable"))

  if (any(is.na(coeficientes_requeridos$incidencia_devaluacion))) {
    missing_coeficientes <- coeficientes_requeridos %>%
      filter(is.na(.data$incidencia_devaluacion)) %>%
      transmute(key = paste(.data$seccion, .data$Variable, sep = " / ")) %>%
      pull(.data$key)
    stop("Faltan coeficientes requeridos para ", scenario_name, ": ",
         paste(missing_coeficientes, collapse = "; "))
  }

  coeficientes_incidencias <- coeficientes_scenario %>%
    mutate(variable_col = coeficiente_variable_col(.data$Variable)) %>%
    filter(!is.na(.data$variable_col)) %>%
    select("seccion", "variable_col", "incidencia_devaluacion") %>%
    pivot_wider(
      names_from = "variable_col",
      values_from = "incidencia_devaluacion"
    )

  devaluacion <- escenario_inicial %>%
    left_join(tipo_cambio, by = c("anno" = "anio")) %>%
    left_join(coeficientes_incidencias, by = "seccion") %>%
    mutate(
      escenario = scenario_name,
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
      # DECISION: from 2026-08-31 the scenario columns are expressed from the
      # overvaluation reading requested by the research team. Positive deltas
      # are subtracted from VBP/capital components and added back to costs when
      # reconstructing the counterfactual mass of profit.
      vbp_pp_devaluacion =
        .data$vbp_pp - .data$delta_vbp_pp,
      consumo_intermedio_estimado_devaluacion =
        .data$consumo_intermedio_estimado - .data$delta_consumo_intermedio_estimado,
      vab_pp_devaluacion =
        .data$vab_pp - .data$delta_vbp_pp + .data$delta_consumo_intermedio_estimado,
      vab_pb_estimado_devaluacion =
        .data$vab_pb_estimado - .data$delta_vbp_pp + .data$delta_consumo_intermedio_estimado,
      remuneraciones_devaluacion =
        .data$remuneraciones - .data$delta_remuneraciones,
      consumo_capital_fijo_devaluacion =
        .data$consumo_capital_fijo - .data$delta_consumo_capital_fijo,
      stock_capital_imputado_devaluacion =
        .data$stock_capital_imputado - .data$delta_stock_capital_imputado,
      intereses_industria_pesos_devaluacion =
        .data$intereses_industria_pesos - .data$delta_intereses_industria_pesos,
      capital_variable_adelantado_devaluacion =
        .data$capital_variable_adelantado -
        safe_divide(.data$delta_remuneraciones, .data$rotacion_calibrada_sobre_6_6),
      capital_circulante_constante_adelantado_devaluacion =
        .data$capital_circulante_constante_adelantado -
        safe_divide(.data$delta_consumo_intermedio_estimado, .data$rotacion_calibrada_sobre_6_6),
      capital_total_adelantado_devaluacion =
        .data$capital_total_adelantado -
        .data$delta_stock_capital_imputado -
        safe_divide(
          .data$delta_remuneraciones + .data$delta_consumo_intermedio_estimado,
          .data$rotacion_calibrada_sobre_6_6
        ),
      ganancia_pb_devaluacion =
        .data$ganancia_pb -
        .data$delta_vbp_pp +
        .data$delta_consumo_intermedio_estimado +
        .data$delta_remuneraciones +
        .data$delta_consumo_capital_fijo,
      ganancia_pp_devaluacion =
        .data$ganancia_pp -
        .data$delta_vbp_pp +
        .data$delta_consumo_intermedio_estimado +
        .data$delta_remuneraciones +
        .data$delta_consumo_capital_fijo,
      ganancia_pb_desp_intereses_devaluacion =
        .data$ganancia_pb_devaluacion - .data$intereses_industria_pesos_devaluacion,
      ganancia_pp_desp_intereses_devaluacion =
        .data$ganancia_pp_devaluacion - .data$intereses_industria_pesos_devaluacion,
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
      # DECISION: expose the same analytical deltas used in the integrated
      # minute. The monetary saldo is read from the initial overvalued
      # exchange-rate setting: positive means over-perceived profit and
      # negative means profit left unperceived relative to the parity scenario.
      delta_ganancia_pb_escenario =
        .data$ganancia_pb_devaluacion - .data$ganancia_pb,
      delta_ganancia_pb_desp_intereses_escenario =
        .data$ganancia_pb_desp_intereses_devaluacion -
        .data$ganancia_pb_desp_intereses,
      saldo_sobrevaluacion_ganancia_pb =
        .data$ganancia_pb - .data$ganancia_pb_devaluacion,
      saldo_sobrevaluacion_ganancia_pb_desp_intereses =
        .data$ganancia_pb_desp_intereses -
        .data$ganancia_pb_desp_intereses_devaluacion,
      delta_ganancia_momento2_pct =
        safe_divide(.data$delta_ganancia_pb_escenario, .data$ganancia_pb) * 100,
      delta_ganancia_desp_intereses_momento2_pct =
        safe_divide(
          .data$delta_ganancia_pb_desp_intereses_escenario,
          .data$ganancia_pb_desp_intereses
        ) * 100,
      saldo_vbp = .data$delta_vbp_pp,
      saldo_consumo_intermedio = -.data$delta_consumo_intermedio_estimado,
      saldo_remuneraciones = -.data$delta_remuneraciones,
      saldo_consumo_capital_fijo = -.data$delta_consumo_capital_fijo,
      saldo_intereses = -.data$delta_intereses_industria_pesos
    ) %>%
    select(
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
      "delta_ganancia_pb_escenario",
      "saldo_sobrevaluacion_ganancia_pb",
      "delta_ganancia_momento2_pct",
      "ganancia_pp",
      "ganancia_pp_devaluacion",
      "variacion_ganancia_pp_pct",
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
      "variacion_ganancia_pb_desp_intereses_pct",
      "delta_ganancia_pb_desp_intereses_escenario",
      "saldo_sobrevaluacion_ganancia_pb_desp_intereses",
      "delta_ganancia_desp_intereses_momento2_pct",
      "ganancia_pp_desp_intereses",
      "ganancia_pp_desp_intereses_devaluacion",
      "variacion_ganancia_pp_desp_intereses_pct"
    ) %>%
    arrange(.data$anno, factor(.data$seccion, levels = section_order))

  required_devaluation_cols <- c(
    "factor_devaluacion",
    "incidencia_vbp_pp",
    "incidencia_consumo_intermedio_estimado",
    "incidencia_remuneraciones",
    "incidencia_consumo_capital_fijo",
    "incidencia_stock_capital_imputado",
    "incidencia_intereses_industria_pesos"
  )

  if (any(devaluacion %>% select(all_of(required_devaluation_cols)) %>% is.na())) {
    stop("Hay faltantes en factores o incidencias para ", scenario_name, ".")
  }

  devaluacion
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
  distinct(.data$anio, .keep_all = TRUE) %>%
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
  mutate(
    escenario = if ("escenario" %in% names(coeficientes_devaluacion)) {
      as.character(.data$escenario)
    } else {
      "escenario_1_comercio_exterior"
    },
    escenario_nombre = if ("escenario_nombre" %in% names(coeficientes_devaluacion)) {
      as.character(.data$escenario_nombre)
    } else {
      "Escenario 1 - Comercio Exterior"
    },
    descripcion_escenario = if ("descripcion_escenario" %in% names(coeficientes_devaluacion)) {
      as.character(.data$descripcion_escenario)
    } else {
      NA_character_
    },
    seccion = as.character(.data$seccion),
    Variable = as.character(.data$Variable),
    variable_fuente = if ("variable_fuente" %in% names(coeficientes_devaluacion)) {
      as.character(.data$variable_fuente)
    } else {
      .data$Variable
    },
    incidencia_devaluacion = normalise_incidence(.data[[incidencia_col]]),
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
  ) %>%
  select(
    "escenario",
    "escenario_nombre",
    "descripcion_escenario",
    "seccion",
    "Variable",
    "variable_fuente",
    "incidencia_devaluacion",
    "Efecto",
    "Formula",
    "Comentario",
    "Fuente"
  )

assert_unique_key(
  coeficientes_modelo,
  c("escenario", "seccion", "Variable"),
  "coeficientes-devaluacion"
)

scenario_names <- c(
  "Escenario 1 - Comercio Exterior",
  "Escenario 2 - Bienes Transables"
)
missing_scenarios <- setdiff(scenario_names, unique(coeficientes_modelo$escenario_nombre))
if (length(missing_scenarios) > 0) {
  stop("Faltan escenarios en coeficientes: ", paste(missing_scenarios, collapse = ", "))
}

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
  "intereses_industria_eaae_ajuste_90_mill_usd",
  "participacion_intereses_industria",
  "intereses_industria_pesos",
  "metodo_intereses",
  "ganancia_pb_desp_intereses",
  "ganancia_pp_desp_intereses"
)

assert_columns(panel, panel_required, "panel EAAE industria 2020-2024")
assert_unique_key(panel, c("anno", "seccion"), "panel EAAE industria 2020-2024")
assert_unique_key(tipo_cambio, "anio", "tipo-cambio")

escenario_inicial <- panel %>%
  filter(.data$seccion != "combustible") %>%
  select(all_of(panel_required)) %>%
  arrange(.data$anno, factor(.data$seccion, levels = coeficientes_secciones_requeridas))

if (!setequal(unique(escenario_inicial$seccion), coeficientes_secciones_requeridas)) {
  stop("Las secciones del escenario inicial no coinciden con las secciones de coeficientes requeridas.")
}

expected_interest_shares <- tibble(
  seccion = c("industria-total", "exportadora", "mercado-interno"),
  participacion_intereses_industria_esperada = c(1, 0.656, 0.344)
)
interest_share_check <- escenario_inicial %>%
  distinct(.data$seccion, .data$participacion_intereses_industria) %>%
  left_join(expected_interest_shares, by = "seccion") %>%
  mutate(
    diff = abs(.data$participacion_intereses_industria -
      .data$participacion_intereses_industria_esperada)
  )
if (any(is.na(interest_share_check$diff) | interest_share_check$diff > 1e-12)) {
  stop("El panel no contiene la distribución de intereses CIU esperada.")
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

scenario_sheets <- lapply(
  scenario_names,
  build_scenario_sheet,
  escenario_inicial = escenario_inicial,
  tipo_cambio = tipo_cambio,
  coeficientes_modelo = coeficientes_modelo,
  coeficientes_variables_requeridas = coeficientes_variables_requeridas,
  section_order = coeficientes_secciones_requeridas
)
names(scenario_sheets) <- scenario_names

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
    ". La hoja Modelo del archivo fuente entrega los coeficientes para",
    "industria total en dos escenarios; las hojas Impo_Expo - Mercado Interno",
    "y Transable_Expo - MI entregan coeficientes específicos para exportadora",
    "y mercado-interno."
  ),
  "fuentes", "intereses industriales",
  paste(
    "La serie de intereses disponible es anual y corresponde a la industria",
    "manufacturera agregada. La apertura entre grupos exportadora y mercado",
    "interno se toma de microdatos del CIU."
  ),
  "decision", "criterio de asignación de intereses",
  paste(
    "Para los grupos de subramas, los intereses industriales se asignan",
    "según microdatos del CIU: 65,6% para ramas exportadoras y 34,4% para",
    "ramas orientadas al mercado interno. La industria total conserva el 100%",
    "de la serie agregada."
  ),
  "formula", "intereses por grupo",
  paste(
    "intereses_grupo = intereses_industria_total * participacion_CIU;",
    "participacion_CIU exportadora = 0,656;",
    "participacion_CIU mercado-interno = 0,344."
  ),
  "devaluacion", "factor de devaluación",
  paste(
    "factor_devaluacion = tipo_cambio_paridad_pesos_usd /",
    "tipo_cambio_comercial_pesos_usd - 1."
  ),
  "resultados", "delta de ganancia momento 2",
  paste(
    "delta_ganancia_pb_escenario = ganancia_pb_devaluacion - ganancia_pb;",
    "delta_ganancia_momento2_pct expresa ese delta como porcentaje de la",
    "ganancia_pb inicial observada."
  ),
  "resultados", "saldo de sobrevaluación",
  paste(
    "saldo_sobrevaluacion_ganancia_pb = ganancia_pb -",
    "ganancia_pb_devaluacion. Un valor positivo indica ganancia",
    "sobrepercibida bajo sobrevaluación; un valor negativo indica ganancia",
    "dejada de percibir bajo sobrevaluación."
  ),
  "resultados", "fórmula de ganancia pb devaluación",
  paste(
    "ganancia_pb_devaluacion = ganancia_pb - delta_vbp_pp +",
    "delta_consumo_intermedio_estimado + delta_remuneraciones +",
    "delta_consumo_capital_fijo. Por decisión metodológica de 2026-08-31,",
    "el libro no calcula ni exporta tasas de ganancia en las hojas de",
    "escenarios."
  ),
  "resultados", "saldos por componente",
  paste(
    "saldo_vbp = delta_vbp_pp; los saldos de consumo intermedio,",
    "remuneraciones, consumo de capital fijo e intereses se registran con",
    "signo negativo para que los componentes sumen al saldo de",
    "sobrevaluación de la ganancia."
  ),
  "devaluacion", "Escenario 1 - Comercio Exterior",
  paste(
    "La apropiación de riqueza vía sobrevaluación se aplica a los componentes",
    "importados de costos y capital y a la parte exportada de la producción.",
    "El escenario recoge sólo la incidencia directa de importaciones y",
    "exportaciones sobre la masa de ganancia."
  ),
  "devaluacion", "Escenario 2 - Bienes Transables",
  paste(
    "La apropiación de riqueza vía sobrevaluación alcanza mercancías cuyos",
    "precios internos se rigen por precios internacionales, aunque sean",
    "producidas localmente y vendidas en el mercado interno. Incorpora la",
    "revaluación de esa producción local y su incidencia sobre la masa de",
    "ganancia."
  )
)

coeficientes_metodologia <- coeficientes_modelo %>%
  transmute(
    seccion = paste("coeficientes-devaluacion", .data$escenario_nombre, .data$seccion, sep = " - "),
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
  tibble(
    seccion = "estructura",
    item = "hojas integradas en metodologia",
    detalle = paste(
      "Las hojas coeficientes-devaluacion y rotaciones se integran en esta",
      "hoja para concentrar los supuestos del modelo en un unico lugar."
    )
  ),
  coeficientes_metodologia,
  rotaciones_metodologia
)

write_xlsx_workbook(
  output_workbook_path,
  c(
    list(
      `metodología` = metodologia,
      `escenario-inicial` = escenario_inicial,
      `tipo-cambio` = tipo_cambio
    ),
    scenario_sheets
  ),
  title = "Resultados corrientes grupos industria Mussi"
)

cat("Panel CSV usado: ", panel_path, "\n", sep = "")
cat("Coeficientes usados: ", coeficientes_path, "\n", sep = "")
cat("XLSX creado: ", output_workbook_path, "\n", sep = "")
cat("Escenario inicial filas: ", nrow(escenario_inicial), "\n", sep = "")
for (sheet_name in names(scenario_sheets)) {
  cat(sheet_name, " filas: ", nrow(scenario_sheets[[sheet_name]]), "\n", sep = "")
}
