#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(readxl)
  library(stringr)
})

root_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

mussi_dir <- file.path(root_dir, "data", "input-data", "mussi")

total_path <- file.path(
  mussi_dir,
  "20260819-coeficientes-efecto-devaluacion.csv"
)

segmentos_path <- file.path(
  mussi_dir,
  "20260825-Uruguay. Modelo de impacto de devaluación-segmentos.xlsx"
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

for (path in c(total_path, segmentos_path)) {
  if (!file.exists(path)) {
    stop("Missing input file: ", path)
  }
}

empty_to_na <- function(x) {
  x <- str_squish(as.character(x))
  na_if(x, "")
}

normalise_segment_block <- function(raw, block_label, seccion, segmento_label) {
  start_row <- which(str_squish(as.character(raw[[1]])) == block_label)

  if (length(start_row) != 1) {
    stop("Expected one block named '", block_label, "', found: ", length(start_row))
  }

  data_start <- start_row + 2
  block <- raw[data_start:nrow(raw), 1:5]

  blank_rows <- apply(block, 1, function(row_i) {
    row_i <- str_squish(as.character(row_i))
    all(is.na(row_i) | row_i == "")
  })

  first_blank <- which(blank_rows)[1]

  if (!is.na(first_blank)) {
    block <- block[seq_len(first_blank - 1), , drop = FALSE]
  }

  names(block) <- c("Variable", "Incidencia", "Efecto", "Formula", "Comentario")

  block <- block %>%
    mutate(across(everything(), empty_to_na)) %>%
    filter(!is.na(.data$Variable))

  formula_base <- block$Formula[!is.na(block$Formula)]

  if (length(formula_base) == 0) {
    stop("No formula found in block: ", block_label)
  }

  block %>%
    mutate(
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
      Formula = if_else(is.na(.data$Formula), formula_base[[1]], .data$Formula),
      Fuente = paste0(
        basename(segmentos_path),
        "; hoja Expo - Mercado Interno; bloque ",
        block_label
      )
    ) %>%
    select(
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

total <- read_csv(total_path, show_col_types = FALSE)

missing_total_cols <- setdiff(required_total_cols, names(total))

if (length(missing_total_cols) > 0) {
  stop("Missing columns in total coefficient CSV: ", paste(missing_total_cols, collapse = ", "))
}

total <- total %>%
  mutate(
    seccion = "industria-total",
    segmento = "Industria total",
    variable_fuente = .data$Variable
  ) %>%
  select(
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

raw_segmentos <- read_excel(
  segmentos_path,
  sheet = "Expo - Mercado Interno",
  col_names = FALSE,
  .name_repair = "minimal"
)

exportadora <- normalise_segment_block(
  raw = raw_segmentos,
  block_label = "Exportadores",
  seccion = "exportadora",
  segmento_label = "Exportadores"
)

mercado_interno <- normalise_segment_block(
  raw = raw_segmentos,
  block_label = "Mercado interno",
  seccion = "mercado-interno",
  segmento_label = "Mercado interno"
)

coeficientes <- bind_rows(total, exportadora, mercado_interno)

expected_variables <- total %>%
  distinct(.data$Variable) %>%
  pull(.data$Variable) %>%
  sort()

quality <- coeficientes %>%
  group_by(.data$seccion) %>%
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

for (seccion_i in unique(coeficientes$seccion)) {
  vars_i <- coeficientes %>%
    filter(.data$seccion == seccion_i) %>%
    distinct(.data$Variable) %>%
    pull(.data$Variable) %>%
    sort()

  if (!identical(vars_i, expected_variables)) {
    stop("Variable set differs in section: ", seccion_i)
  }
}

if (any(quality$missing_incidencia > 0) || any(quality$missing_formula > 0)) {
  stop("Missing incidence or formula in coefficient table.")
}

duplicated_keys <- coeficientes %>%
  count(.data$seccion, .data$Variable) %>%
  filter(.data$n > 1)

if (nrow(duplicated_keys) > 0) {
  stop("Duplicated seccion-variable keys in coefficient table.")
}

write_csv(coeficientes, output_path, na = "")

cat("Archivo creado: ", output_path, "\n", sep = "")
cat("Fuente industria total: ", total_path, "\n", sep = "")
cat("Fuente segmentos: ", segmentos_path, " | hoja Expo - Mercado Interno\n", sep = "")
cat("Filas: ", nrow(coeficientes), "\n", sep = "")
print(quality)
