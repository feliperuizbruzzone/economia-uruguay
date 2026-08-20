#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(readxl)
  library(stringr)
})

root_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

input_path <- file.path(
  root_dir,
  "data",
  "input-data",
  "mussi",
  "20260819-Uruguay. Modelo de impacto de devaluación.xlsx"
)
output_path <- file.path(
  root_dir,
  "data",
  "input-data",
  "mussi",
  "20260819-coeficientes-efecto-devaluacion.csv"
)

if (!file.exists(input_path)) {
  stop("Missing input file: ", input_path)
}

empty_to_na <- function(x) {
  x <- str_squish(as.character(x))
  na_if(x, "")
}

raw <- read_excel(
  input_path,
  sheet = "Modelo",
  range = "B6:G13",
  col_names = FALSE,
  .name_repair = "minimal"
)

names(raw) <- c(
  "Variable",
  "Incidencia",
  "Efecto",
  "Formula",
  "Comentario",
  "Fuente"
)

coeficientes <- raw %>%
  slice(-1) %>%
  mutate(across(everything(), empty_to_na)) %>%
  filter(!is.na(.data$Variable))

formula_base <- coeficientes$Formula[!is.na(coeficientes$Formula)]

if (length(formula_base) == 0) {
  stop("No formula found in Modelo!B6:G13.")
}

coeficientes <- coeficientes %>%
  mutate(
    Incidencia = parse_number(.data$Incidencia),
    # DECISION: el libro fuente registra la formula solo en la primera variable.
    # Para dejar el CSV operativo, se replica a todas las filas del bloque.
    Formula = if_else(is.na(.data$Formula), formula_base[[1]], .data$Formula)
  ) %>%
  select(
    Variable,
    Incidencia,
    Efecto,
    Formula,
    Comentario,
    Fuente
  )

required_cols <- c("Variable", "Incidencia", "Efecto", "Formula", "Comentario", "Fuente")
missing_cols <- setdiff(required_cols, names(coeficientes))

if (length(missing_cols) > 0) {
  stop("Missing output columns: ", paste(missing_cols, collapse = ", "))
}

if (any(is.na(coeficientes$Variable)) || any(is.na(coeficientes$Incidencia))) {
  stop("Coefficient table has missing Variable or Incidencia values.")
}

write_csv(coeficientes, output_path, na = "")

cat("Archivo creado: ", output_path, "\n", sep = "")
cat("Fuente: ", input_path, "\n", sep = "")
cat("Filas: ", nrow(coeficientes), "\n", sep = "")
