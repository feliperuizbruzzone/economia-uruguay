#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(readxl)
  library(stringr)
})

root_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

mussi_dir <- file.path(root_dir, "data", "input-data", "mussi")

source_workbook_path <- file.path(
  mussi_dir,
  "20260827-Uruguay. Modelo de impacto de devaluación-segmentos-dos-escenarios.xlsx"
)

output_path <- file.path(
  mussi_dir,
  paste0(format(Sys.Date(), "%Y%m%d"), "-coeficientes-efecto-devaluacion.csv")
)

required_total_cols <- c(
  "Variable",
  "Incidencia",
  "Efecto",
  "Formula",
  "Comentario",
  "Fuente"
)

if (!file.exists(source_workbook_path)) {
  stop("Missing input file: ", source_workbook_path)
}

empty_to_na <- function(x) {
  x <- str_squish(as.character(x))
  na_if(x, "")
}

read_model_sheet <- function(sheet) {
  raw <- read_excel(
    source_workbook_path,
    sheet = sheet,
    col_names = FALSE,
    .name_repair = "minimal"
  )
  names(raw) <- paste0("col", seq_along(raw))
  raw <- raw %>%
    mutate(across(everything(), empty_to_na))

  non_empty_cols <- vapply(raw, function(col_i) any(!is.na(col_i)), logical(1))
  raw <- raw[, non_empty_cols, drop = FALSE]

  if (ncol(raw) < 5) {
    stop("La hoja no tiene columnas suficientes para coeficientes: ", sheet)
  }

  raw
}

is_blank_row <- function(data) {
  apply(data, 1, function(row_i) all(is.na(row_i) | row_i == ""))
}

normalise_block <- function(
  raw,
  block_label,
  seccion,
  segmento_label,
  scenario_id,
  scenario_nombre,
  descripcion_escenario,
  source_sheet
) {
  start_row <- which(str_squish(as.character(raw[[1]])) == block_label)

  if (length(start_row) != 1) {
    stop("Expected one block named '", block_label, "', found: ", length(start_row))
  }

  header_candidates <- which(
    seq_len(nrow(raw)) > start_row &
      str_squish(as.character(raw[[1]])) == "Variable"
  )

  if (length(header_candidates) == 0) {
    stop("No se encontró encabezado Variable para bloque: ", block_label)
  }

  header_row <- header_candidates[[1]]
  block <- raw[(header_row + 1):nrow(raw), seq_len(min(6, ncol(raw))), drop = FALSE]

  blank_rows <- is_blank_row(block)
  while (nrow(block) > 0 && blank_rows[[1]]) {
    block <- block[-1, , drop = FALSE]
    blank_rows <- is_blank_row(block)
  }

  if (nrow(block) == 0) {
    stop("Bloque sin filas de datos: ", block_label)
  }

  first_blank <- which(is_blank_row(block))[1]
  if (!is.na(first_blank) && first_blank > 1) {
    block <- block[seq_len(first_blank - 1), , drop = FALSE]
  }

  if (ncol(block) == 5) {
    names(block) <- c("Variable", "Incidencia", "Efecto", "Formula", "Comentario")
    block$Fuente <- NA_character_
  } else {
    names(block) <- c("Variable", "Incidencia", "Efecto", "Formula", "Comentario", "Fuente")
  }

  block <- block %>%
    mutate(across(everything(), empty_to_na)) %>%
    filter(!is.na(.data$Variable))

  formula_base <- block$Formula[!is.na(block$Formula)]

  if (length(formula_base) == 0) {
    stop("No formula found in block: ", block_label)
  }

  block %>%
    mutate(
      escenario = scenario_id,
      escenario_nombre = scenario_nombre,
      descripcion_escenario = descripcion_escenario,
      seccion = seccion,
      segmento = segmento_label,
      variable_fuente = .data$Variable,
      # DECISION: the segment workbook names this coefficient as machinery
      # fixed capital, but the devaluation model applies it to the same
      # stock-capital-imputed variable used by the previous total-industry
      # coefficient table.
      Variable = recode(
        .data$Variable,
        "Capital fijo de maquinaria" = "Stock capital imputado"
      ),
      Incidencia = parse_number(.data$Incidencia),
      # DECISION: in the 20260827 workbook, the effect cell for total-industry
      # machinery fixed capital in scenario 2 is blank. The variable increases
      # advanced capital and therefore has the same negative interpretation as
      # stock-capital coefficients in the rest of the workbook.
      Efecto = if_else(
        is.na(.data$Efecto) & .data$Variable == "Stock capital imputado",
        "Negativo",
        .data$Efecto
      ),
      Formula = if_else(is.na(.data$Formula), formula_base[[1]], .data$Formula),
      Fuente = if_else(
        is.na(.data$Fuente),
        paste0(
          basename(source_workbook_path),
          "; hoja ",
          source_sheet,
          "; bloque ",
          block_label
        ),
        paste0(
          basename(source_workbook_path),
          "; hoja ",
          source_sheet,
          "; bloque ",
          block_label,
          "; ",
          .data$Fuente
        )
      )
    ) %>%
    select(
      "escenario",
      "escenario_nombre",
      "descripcion_escenario",
      "seccion",
      "segmento",
      "Variable",
      "variable_fuente",
      "Incidencia",
      "Efecto",
      "Formula",
      "Comentario",
      "Fuente"
    )
}

scenarios <- tibble::tribble(
  ~escenario, ~escenario_nombre, ~descripcion_escenario, ~total_sheet, ~total_block, ~segment_sheet,
  "escenario_1_comercio_exterior",
  "Escenario 1 - Comercio Exterior",
  paste(
    "Incidencia directa del comercio exterior: la apropiación de riqueza vía",
    "sobrevaluación se aplica a componentes importados de costos y capital y a",
    "la parte exportada de la producción."
  ),
  "Modelo",
  "V.1 | Cantidades fijas | Importado",
  "Impo_Expo - Mercado Interno",
  "escenario_2_bienes_transables",
  "Escenario 2 - Bienes Transables",
  paste(
    "Incidencia de bienes transables: la apropiación de riqueza vía",
    "sobrevaluación alcanza mercancías cuyos precios internos se rigen por",
    "precios internacionales, aunque se produzcan localmente y se vendan en el",
    "mercado interno."
  ),
  "Modelo",
  "V.2 | Cantidades fijas | Transable",
  "Transable_Expo - MI"
)

coeficientes <- bind_rows(lapply(seq_len(nrow(scenarios)), function(i) {
  scenario_i <- scenarios[i, ]
  raw_total <- read_model_sheet(scenario_i$total_sheet)
  raw_segment <- read_model_sheet(scenario_i$segment_sheet)

  bind_rows(
    normalise_block(
      raw = raw_total,
      block_label = scenario_i$total_block,
      seccion = "industria-total",
      segmento_label = "Industria total",
      scenario_id = scenario_i$escenario,
      scenario_nombre = scenario_i$escenario_nombre,
      descripcion_escenario = scenario_i$descripcion_escenario,
      source_sheet = scenario_i$total_sheet
    ),
    normalise_block(
      raw = raw_segment,
      block_label = "Exportadores",
      seccion = "exportadora",
      segmento_label = "Exportadores",
      scenario_id = scenario_i$escenario,
      scenario_nombre = scenario_i$escenario_nombre,
      descripcion_escenario = scenario_i$descripcion_escenario,
      source_sheet = scenario_i$segment_sheet
    ),
    normalise_block(
      raw = raw_segment,
      block_label = "Mercado interno",
      seccion = "mercado-interno",
      segmento_label = "Mercado interno",
      scenario_id = scenario_i$escenario,
      scenario_nombre = scenario_i$escenario_nombre,
      descripcion_escenario = scenario_i$descripcion_escenario,
      source_sheet = scenario_i$segment_sheet
    )
  )
}))

expected_variables <- coeficientes %>%
  filter(.data$escenario == scenarios$escenario[[1]], .data$seccion == "industria-total") %>%
  distinct(.data$Variable) %>%
  pull(.data$Variable) %>%
  sort()

quality <- coeficientes %>%
  group_by(.data$escenario, .data$seccion) %>%
  summarise(
    n_variables = n_distinct(.data$Variable),
    variables = paste(sort(unique(.data$Variable)), collapse = " | "),
    missing_incidencia = sum(is.na(.data$Incidencia)),
    missing_formula = sum(is.na(.data$Formula)),
    .groups = "drop"
  )

if (any(quality$n_variables != length(expected_variables))) {
  stop("Unexpected number of variables by section.")
}

for (escenario_i in unique(coeficientes$escenario)) {
  for (seccion_i in unique(coeficientes$seccion)) {
  vars_i <- coeficientes %>%
    filter(.data$escenario == escenario_i) %>%
    filter(.data$seccion == seccion_i) %>%
    distinct(.data$Variable) %>%
    pull(.data$Variable) %>%
    sort()

  if (!identical(vars_i, expected_variables)) {
      stop("Variable set differs in scenario/section: ", escenario_i, " / ", seccion_i)
    }
  }
}

if (
  any(quality$missing_incidencia > 0) ||
    any(quality$missing_formula > 0) ||
    any(is.na(coeficientes$Efecto))
) {
  stop("Missing incidence, effect or formula in coefficient table.")
}

duplicated_keys <- coeficientes %>%
  count(.data$escenario, .data$seccion, .data$Variable) %>%
  filter(.data$n > 1)

if (nrow(duplicated_keys) > 0) {
  stop("Duplicated scenario-section-variable keys in coefficient table.")
}

write_csv(coeficientes, output_path, na = "")

cat("Archivo creado: ", output_path, "\n", sep = "")
cat("Fuente: ", source_workbook_path, "\n", sep = "")
cat("Filas: ", nrow(coeficientes), "\n", sep = "")
print(quality)
