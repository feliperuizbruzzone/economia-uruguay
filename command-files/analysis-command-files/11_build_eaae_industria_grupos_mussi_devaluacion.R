#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(readxl)
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

source_panel_path <- file.path(
  analysis_dir,
  "20260617_panel_eaae_industria_subramas_fuente.csv"
)
classification_path <- file.path(
  input_mussi_dir,
  "20260824_subramas_industriales_fuente_eaae_2020_2024.csv"
)
tipo_cambio_path <- file.path(
  analysis_dir,
  "20260812-exportaciones-manufactura-uruguay.csv"
)
coeficientes_path <- file.path(
  input_mussi_dir,
  "20260819-coeficientes-efecto-devaluacion.csv"
)
direct_helper_path <- file.path(
  "command-files",
  "processing-command-files",
  "29_extract_eaae_industria_source_direct_2020_2024.py"
)

output_panel_path <- file.path(
  analysis_dir,
  paste0(date_prefix, "_panel_eaae_2020_2024_industria.csv")
)
output_workbook_path <- file.path(
  analysis_dir,
  paste0(date_prefix, "_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx")
)

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

sum_present <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) {
    return(NA_real_)
  }
  sum(x)
}

collapse_present <- function(x) {
  x <- unique(x[!is.na(x) & x != ""])
  if (length(x) == 0) {
    return(NA_character_)
  }
  paste(x, collapse = "|")
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

read_mussi_classification <- function(path) {
  lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
  if (length(lines) < 2) {
    stop("La clasificación Mussi no contiene filas de datos: ", path)
  }

  # DECISION: The CSV received from Mussi is semicolon separated but contains
  # unquoted semicolons inside textual descriptions and a mojibake header for
  # `Clasificación`. For this task only the first two fields and last field are
  # contractual, so parse those positions directly.
  rows <- lapply(lines[-1], function(line) {
    parts <- strsplit(line, ";", fixed = TRUE)[[1]]
    if (length(parts) < 3) {
      stop("Fila inválida en clasificación Mussi: ", line)
    }
    tibble(
      division_publicada = str_squish(parts[[1]]),
      codigos_base_2dig = str_squish(parts[[2]]),
      clasificacion_mussi = str_squish(parts[[length(parts)]])
    )
  }) %>%
    bind_rows() %>%
    mutate(
      grupo_clasificacion = case_when(
        clasificacion_mussi == "Exportadora" ~ "exportadora",
        clasificacion_mussi == "Mercado interno" ~ "mercado_interno",
        clasificacion_mussi == "Combustible" ~ "combustible",
        TRUE ~ NA_character_
      )
    )

  if (any(is.na(rows$grupo_clasificacion))) {
    stop("Hay clasificaciones Mussi no reconocidas.")
  }
  assert_unique_key(rows, c("division_publicada", "codigos_base_2dig"), "clasificación Mussi")
  rows
}

run_direct_source_extraction <- function() {
  python_bin <- Sys.which("python3")
  if (python_bin == "") {
    python_bin <- Sys.which("python")
  }
  if (python_bin == "") {
    stop("No se encontró python3/python para ejecutar el extractor directo.")
  }

  output <- tempfile(pattern = "eaae_source_direct_", fileext = ".csv")
  args <- c(
    direct_helper_path,
    "--output",
    output,
    "--years",
    as.character(2020:2024)
  )
  status <- system2(python_bin, args = args)
  if (!identical(status, 0L)) {
    stop("Falló la extracción directa fuente con estado: ", status)
  }
  output
}

add_results_calculations <- function(data) {
  data %>%
    mutate(
      vab_pb_estimado = .data$vab_pb,
      consumo_intermedio_estimado = .data$vbp_pp - .data$vab_pb_estimado,
      consumo_intermedio = .data$vbp_pp - .data$vab_pp,
      costo_laboral = .data$remuneraciones,
      capital_variable_adelantado =
        safe_divide(.data$remuneraciones, .data$rotacion_calibrada_sobre_6_6),
      capital_circulante_constante_adelantado =
        safe_divide(.data$consumo_intermedio_estimado, .data$rotacion_calibrada_sobre_6_6),
      capital_circulante_adelantado =
        safe_divide(.data$costo_laboral + .data$consumo_intermedio, .data$rotacion_calibrada_sobre_6_6),
      capital_total_adelantado =
        .data$stock_capital_imputado +
        .data$capital_variable_adelantado +
        .data$capital_circulante_constante_adelantado,
      ganancia_pb =
        .data$vab_pb_estimado - .data$consumo_capital_fijo - .data$costo_laboral,
      ganancia_pp =
        .data$vab_pp - .data$consumo_capital_fijo - .data$costo_laboral,
      tasa_ganancia_pb =
        safe_divide(.data$ganancia_pb, .data$capital_total_adelantado),
      tasa_ganancia_pp =
        safe_divide(.data$ganancia_pp, .data$capital_total_adelantado)
    )
}

coeficiente_de <- function(coeficientes, variable) {
  value <- coeficientes %>%
    filter(.data$Variable == variable) %>%
    pull(.data$incidencia_devaluacion)
  if (length(value) != 1 || is.na(value)) {
    stop("No se encontró coeficiente único para: ", variable)
  }
  value
}

for (path in c(
  source_panel_path,
  classification_path,
  tipo_cambio_path,
  coeficientes_path,
  direct_helper_path
)) {
  if (!file.exists(path)) {
    stop("Missing required input: ", path)
  }
}

panel_integrado_path <- latest_file(file.path(
  analysis_dir,
  "*_panel_eeae_bcu_total_industria_subrama.csv"
))

source_panel <- read_csv(source_panel_path, show_col_types = FALSE)
classification <- read_mussi_classification(classification_path)
direct_source <- read_csv(run_direct_source_extraction(), show_col_types = FALSE)
panel_integrado <- read_csv(panel_integrado_path, show_col_types = FALSE)

tipo_cambio <- read_csv(tipo_cambio_path, show_col_types = FALSE) %>%
  select(
    anio,
    tipo_cambio_comercial_pesos_usd,
    tipo_cambio_paridad_pesos_usd
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

coeficientes_requeridos <- tibble(
  Variable = c(
    "Consumo intermedio",
    "Masa salarial",
    "Intereses",
    "VBP",
    "Consumo de capital fijo",
    "Stock capital imputado"
  )
) %>%
  left_join(coeficientes_modelo, by = "Variable")

if (any(is.na(coeficientes_requeridos$incidencia_devaluacion))) {
  stop("Faltan coeficientes requeridos para devaluación-1.")
}

assert_columns(
  source_panel,
  c(
    "anno",
    "seccion_fuente",
    "division_publicada",
    "codigos_base_2dig",
    "descripcion_fuente",
    "vbp_pp",
    "vbp_pb",
    "vab_pp",
    "vab_pb",
    "remuneraciones",
    "puestos_trabajo"
  ),
  "panel fuente de subramas"
)
assert_columns(
  direct_source,
  c(
    "anno",
    "seccion_fuente",
    "division_publicada",
    "codigos_base_2dig",
    "consumo_capital_fijo",
    "impuestos_netos",
    "stock_capital",
    "stock_capital_imputado",
    "fbcf",
    "fbkf_maq_eq",
    "adquisiciones_importadas",
    "adquisiciones_origen_importado",
    "importaciones_maquinaria"
  ),
  "extracción directa fuente"
)
assert_columns(
  panel_integrado,
  c(
    "anno",
    "nivel_panel",
    "grupo_rev4_homologado",
    "rotacion_calibrada_sobre_6_6",
    "intereses_industria_eaae_ajuste_90_mill_usd"
  ),
  "panel integrado EAAE-BCU"
)
assert_unique_key(tipo_cambio, "anio", "tipo-cambio")

subramas_base <- source_panel %>%
  filter(
    .data$anno >= 2020,
    .data$anno <= 2024,
    .data$seccion_fuente == "C"
  ) %>%
  select(
    anno,
    seccion_fuente,
    division_publicada,
    codigos_base_2dig,
    descripcion_fuente,
    vbp_pp,
    vbp_pb,
    vab_pp,
    vab_pb,
    remuneraciones,
    puestos_trabajo
  ) %>%
  left_join(
    classification,
    by = c("division_publicada", "codigos_base_2dig")
  ) %>%
  left_join(
    direct_source,
    by = c("anno", "seccion_fuente", "division_publicada", "codigos_base_2dig")
  )

if (nrow(subramas_base) != 21L * 5L) {
  stop("Se esperaban 105 filas fuente C para 2020-2024; se obtuvieron ", nrow(subramas_base))
}
if (any(is.na(subramas_base$grupo_clasificacion))) {
  stop("Hay subramas fuente sin clasificación Mussi.")
}

essential_source_cols <- c(
  "vbp_pp",
  "vab_pp",
  "vab_pb",
  "remuneraciones",
  "puestos_trabajo",
  "consumo_capital_fijo",
  "stock_capital_imputado"
)
missing_source <- subramas_base %>%
  filter(if_any(all_of(essential_source_cols), is.na))
if (nrow(missing_source) > 0) {
  stop("Hay filas fuente con faltantes en variables esenciales.")
}

additive_cols <- c(
  "vbp_pp",
  "vbp_pb",
  "vab_pp",
  "vab_pb",
  "remuneraciones",
  "puestos_trabajo",
  "consumo_capital_fijo",
  "impuestos_netos",
  "stock_capital",
  "stock_capital_imputado",
  "fbcf",
  "fbkf_maq_eq",
  "adquisiciones_importadas",
  "adquisiciones_origen_importado",
  "importaciones_maquinaria"
)

class_groups <- subramas_base %>%
  group_by(anno, grupo_clasificacion, clasificacion_mussi) %>%
  summarise(
    across(all_of(additive_cols), sum_present),
    componentes_divisiones = collapse_present(division_publicada),
    componentes_codigos_2dig = collapse_present(codigos_base_2dig),
    componentes_descripciones = collapse_present(descripcion_fuente),
    n_subramas_fuente = n(),
    .groups = "drop"
  ) %>%
  mutate(
    nivel_panel = "grupo_subramas_industriales",
    seccion = case_when(
      .data$grupo_clasificacion == "exportadora" ~ "exportadora",
      .data$grupo_clasificacion == "mercado_interno" ~ "mercado-interno",
      .data$grupo_clasificacion == "combustible" ~ "combustible",
      TRUE ~ .data$grupo_clasificacion
    ),
    descripcion_nivel = case_when(
      .data$grupo_clasificacion == "exportadora" ~ "Subramas industriales exportadoras",
      .data$grupo_clasificacion == "mercado_interno" ~ "Subramas industriales de mercado interno",
      .data$grupo_clasificacion == "combustible" ~ "Subramas industriales de combustible",
      TRUE ~ .data$clasificacion_mussi
    )
  )

industry_total <- subramas_base %>%
  group_by(anno) %>%
  summarise(
    across(all_of(additive_cols), sum_present),
    componentes_divisiones = collapse_present(division_publicada),
    componentes_codigos_2dig = collapse_present(codigos_base_2dig),
    componentes_descripciones = collapse_present(descripcion_fuente),
    n_subramas_fuente = n(),
    .groups = "drop"
  ) %>%
  mutate(
    grupo_clasificacion = "industria_total",
    clasificacion_mussi = "Industria total",
    nivel_panel = "industria_total",
    seccion = "industria-total",
    descripcion_nivel = "Industria manufacturera EAAE"
  )

panel <- bind_rows(industry_total, class_groups) %>%
  select(
    anno,
    nivel_panel,
    seccion,
    grupo_clasificacion,
    clasificacion_mussi,
    descripcion_nivel,
    n_subramas_fuente,
    componentes_divisiones,
    componentes_codigos_2dig,
    componentes_descripciones,
    all_of(additive_cols)
  )

industry_rotations <- panel_integrado %>%
  filter(.data$anno >= 2020, .data$anno <= 2024, .data$nivel_panel == "industria_total") %>%
  select(anno, rotacion_industria_total = rotacion_calibrada_sobre_6_6)
assert_unique_key(industry_rotations, "anno", "rotación industria total")

combustible_rotation <- panel_integrado %>%
  filter(
    .data$anno >= 2020,
    .data$anno <= 2024,
    .data$nivel_panel == "subrama_industrial",
    .data$grupo_rev4_homologado == "19_refinacion"
  ) %>%
  select(anno, rotacion_combustible = rotacion_calibrada_sobre_6_6)
assert_unique_key(combustible_rotation, "anno", "rotación combustible")

panel <- panel %>%
  left_join(industry_rotations, by = "anno") %>%
  left_join(combustible_rotation, by = "anno") %>%
  mutate(
    # DECISION: rotations by classification follow the team's latest explicit
    # values. The industry aggregate uses the current integrated-panel rotation
    # recalculated from Mussi microdata. Combustible is retained in the panel
    # for accounting transparency but excluded from the results workbook.
    rotacion_calibrada_sobre_6_6 = case_when(
      .data$seccion == "industria-total" ~ .data$rotacion_industria_total,
      .data$seccion == "exportadora" ~ 5.05,
      .data$seccion == "mercado-interno" ~ 2.76,
      .data$seccion == "combustible" ~ .data$rotacion_combustible,
      TRUE ~ NA_real_
    )
  ) %>%
  select(-rotacion_industria_total, -rotacion_combustible) %>%
  add_results_calculations() %>%
  arrange(.data$anno, factor(.data$seccion, levels = c(
    "industria-total",
    "exportadora",
    "mercado-interno",
    "combustible"
  )))

assert_unique_key(panel, c("anno", "seccion"), "panel grupos Mussi")
if (any(is.na(panel$rotacion_calibrada_sobre_6_6))) {
  stop("Hay filas del panel sin rotación.")
}

intereses_industria <- panel_integrado %>%
  filter(.data$anno >= 2020, .data$anno <= 2024) %>%
  filter(!is.na(.data$intereses_industria_eaae_ajuste_90_mill_usd)) %>%
  distinct(anno, intereses_industria_eaae_ajuste_90_mill_usd) %>%
  left_join(tipo_cambio, by = c("anno" = "anio")) %>%
  mutate(
    intereses_industria_pesos_total =
      .data$intereses_industria_eaae_ajuste_90_mill_usd *
      1000000 *
      .data$tipo_cambio_comercial_pesos_usd
  )
assert_unique_key(intereses_industria, "anno", "intereses industria")

industry_vbp <- panel %>%
  filter(.data$seccion == "industria-total") %>%
  select(anno, vbp_pp_industria_total = vbp_pp)

panel <- panel %>%
  left_join(industry_vbp, by = "anno") %>%
  left_join(
    intereses_industria %>%
      select(anno, intereses_industria_eaae_ajuste_90_mill_usd, intereses_industria_pesos_total),
    by = "anno"
  ) %>%
  mutate(
    participacion_vbp_pp_industria = safe_divide(.data$vbp_pp, .data$vbp_pp_industria_total),
    # DECISION: the interest source is an annual manufacturing aggregate. For
    # classification groups, allocate it by each group's VBP share in total
    # manufacturing, so the allocation is additive and stays in current pesos.
    intereses_industria_pesos = if_else(
      .data$seccion == "industria-total",
      .data$intereses_industria_pesos_total,
      .data$intereses_industria_pesos_total * .data$participacion_vbp_pp_industria
    ),
    metodo_intereses = if_else(
      .data$seccion == "industria-total",
      "intereses_industria_total_convertidos_a_pesos_con_tcc",
      "asignacion_intereses_industria_por_participacion_vbp_pp"
    ),
    ganancia_pb_desp_intereses = .data$ganancia_pb - .data$intereses_industria_pesos,
    ganancia_pp_desp_intereses = .data$ganancia_pp - .data$intereses_industria_pesos,
    tasa_ganancia_pb_desp_intereses =
      safe_divide(.data$ganancia_pb_desp_intereses, .data$capital_total_adelantado),
    tasa_ganancia_pp_desp_intereses =
      safe_divide(.data$ganancia_pp_desp_intereses, .data$capital_total_adelantado)
  ) %>%
  select(-vbp_pp_industria_total, -intereses_industria_pesos_total)

write_csv(panel, output_panel_path, na = "")

escenario_inicial <- panel %>%
  filter(.data$seccion != "combustible") %>%
  select(
    anno,
    nivel_panel,
    seccion,
    grupo_clasificacion,
    descripcion_nivel,
    rotacion_calibrada_sobre_6_6,
    n_subramas_fuente,
    componentes_divisiones,
    vbp_pp,
    consumo_intermedio_estimado,
    vab_pp,
    vab_pb_estimado,
    consumo_capital_fijo,
    remuneraciones,
    costo_laboral,
    stock_capital,
    stock_capital_imputado,
    capital_variable_adelantado,
    capital_circulante_constante_adelantado,
    capital_circulante_adelantado,
    capital_total_adelantado,
    ganancia_pb,
    ganancia_pp,
    tasa_ganancia_pb,
    tasa_ganancia_pp,
    intereses_industria_eaae_ajuste_90_mill_usd,
    intereses_industria_pesos,
    metodo_intereses,
    ganancia_pb_desp_intereses,
    ganancia_pp_desp_intereses,
    tasa_ganancia_pb_desp_intereses,
    tasa_ganancia_pp_desp_intereses
  ) %>%
  arrange(.data$anno, factor(.data$seccion, levels = c(
    "industria-total",
    "exportadora",
    "mercado-interno"
  )))

rotaciones <- escenario_inicial %>%
  select(
    anno,
    nivel_panel,
    seccion,
    descripcion_nivel,
    rotacion_calibrada_sobre_6_6
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
  mutate(
    factor_devaluacion =
      safe_divide(.data$tipo_cambio_paridad_pesos_usd, .data$tipo_cambio_comercial_pesos_usd) - 1,
    incidencia_vbp_pp = coeficiente_de(coeficientes_modelo, "VBP"),
    incidencia_consumo_intermedio_estimado =
      coeficiente_de(coeficientes_modelo, "Consumo intermedio"),
    incidencia_remuneraciones = coeficiente_de(coeficientes_modelo, "Masa salarial"),
    incidencia_consumo_capital_fijo =
      coeficiente_de(coeficientes_modelo, "Consumo de capital fijo"),
    incidencia_stock_capital_imputado =
      coeficiente_de(coeficientes_modelo, "Stock capital imputado"),
    incidencia_intereses_industria_pesos =
      coeficiente_de(coeficientes_modelo, "Intereses"),
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
    anno,
    nivel_panel,
    seccion,
    grupo_clasificacion,
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
  arrange(.data$anno, factor(.data$seccion, levels = c(
    "industria-total",
    "exportadora",
    "mercado-interno"
  )))

if (any(is.na(devaluacion_1$factor_devaluacion))) {
  stop("Hay filas sin factor de devaluación.")
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
  "fuentes", "base EAAE",
  paste(
    "Los agregados 2020-2024 se construyen desde resultados originales EAAE",
    "por división publicada de la industria manufacturera. Las variables de",
    "capital y FBKF/adquisiciones se extraen directamente de los cuadros fuente",
    "EAAE correspondientes."
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
  "justificacion", "criterio económico",
  paste(
    "El vbp_pp se usa como proxy de escala económica del grupo dentro de la",
    "manufactura. La asignación es aditiva: la suma de intereses asignados a",
    "exportadora, mercado interno y combustible reproduce el total industrial."
  ),
  "interpretacion", "advertencia",
  paste(
    "La asignación proporcional es una imputación contable, no evidencia directa",
    "de endeudamiento, pasivos o pago efectivo de intereses por grupo. Para",
    "mejorarla sería necesaria una fuente con intereses o deuda por subrama",
    "industrial."
  ),
  "devaluacion", "uso en devaluación-1",
  paste(
    "En la hoja devaluación-1, los intereses asignados se actualizan con el",
    "coeficiente definido en coeficientes-devaluación y con el factor de",
    "devaluación calculado como tipo_cambio_paridad_pesos_usd /",
    "tipo_cambio_comercial_pesos_usd - 1."
  )
)

coeficientes_metodologia <- coeficientes_devaluacion %>%
  mutate(
    Variable = as.character(.data$Variable),
    Incidencia = suppressWarnings(as.numeric(.data[[incidencia_col]])),
    Efecto = as.character(.data$Efecto),
    Formula = as.character(.data$Formula),
    Comentario = if ("Comentario" %in% names(.)) as.character(.data$Comentario) else NA_character_,
    Fuente = if ("Fuente" %in% names(.)) as.character(.data$Fuente) else NA_character_
  ) %>%
  transmute(
    seccion = "coeficientes-devaluacion",
    item = .data$Variable,
    detalle = paste(
      "Incidencia:", .data$Incidencia,
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
  list(
    `metodología` = metodologia,
    `escenario-inicial` = escenario_inicial,
    `tipo-cambio` = tipo_cambio,
    `devaluación-1` = devaluacion_1
  ),
  title = "Resultados corrientes grupos industria Mussi"
)

cat("Panel creado: ", output_panel_path, "\n", sep = "")
cat("XLSX creado: ", output_workbook_path, "\n", sep = "")
cat("Panel filas: ", nrow(panel), "\n", sep = "")
cat("Escenario inicial filas: ", nrow(escenario_inicial), "\n", sep = "")
cat("Devaluación-1 filas: ", nrow(devaluacion_1), "\n", sep = "")
cat("Panel integrado usado: ", panel_integrado_path, "\n", sep = "")
