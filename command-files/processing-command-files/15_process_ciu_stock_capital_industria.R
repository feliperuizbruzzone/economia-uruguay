# Process CIU stock of fixed capital in machinery and equipment for industry.
#
# Run from the project root:
#   Rscript command-files/processing-command-files/15_process_ciu_stock_capital_industria.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(readxl)
  library(tibble)
})

input_dir <- file.path("data", "input-data", "ciu-stock-capital")
analysis_dir <- file.path("data", "analysis-data")

source_url <- "https://docs.google.com/spreadsheets/d/1T-z2fXt1xTAwd3c7bCSu8WYov96Dam9YTI0jQWzsysQ/export?format=xlsx"
input_path <- file.path(input_dir, "ciu_stock_capital_1988_2025.xlsx")
output_path <- file.path(analysis_dir, "ciu_stock_capital_industria_1988_2025.csv")

dir.create(input_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(input_path)) {
  download.file(source_url, input_path, mode = "wb", quiet = FALSE)
}

parse_num <- function(x) {
  suppressWarnings(
    readr::parse_number(
      as.character(x),
      locale = readr::locale(decimal_mark = ".", grouping_mark = ",")
    )
  )
}

parse_quarter_label <- function(value) {
  if (is.na(value)) {
    return(list(anno = NA_integer_, trimestre = NA_integer_))
  }
  clean <- tolower(trimws(as.character(value)))
  clean <- gsub("\\.", "", clean)
  parts <- strsplit(clean, "-", fixed = TRUE)[[1]]
  if (length(parts) != 2) {
    return(list(anno = NA_integer_, trimestre = NA_integer_))
  }

  quarter_map <- c(mar = 1L, jun = 2L, set = 3L, sep = 3L, dic = 4L)
  trimestre <- unname(quarter_map[parts[[1]]])
  year_suffix <- suppressWarnings(as.integer(parts[[2]]))
  if (is.na(trimestre) || is.na(year_suffix)) {
    return(list(anno = NA_integer_, trimestre = NA_integer_))
  }

  anno <- if (year_suffix <= 30L) 2000L + year_suffix else 1900L + year_suffix
  list(anno = anno, trimestre = trimestre)
}

parse_quarter_vector <- function(values) {
  parsed <- lapply(values, parse_quarter_label)
  tibble(
    anno = vapply(parsed, function(x) x$anno, integer(1)),
    trimestre = vapply(parsed, function(x) x$trimestre, integer(1))
  )
}

annual_raw <- readxl::read_excel(
  input_path,
  sheet = "Serie Anual",
  col_names = c("raw_anno", "stock_mill_usd", "indice", "fuente_dato_raw"),
  col_types = "text"
)

annual_series <- annual_raw %>%
  transmute(
    anno = as.integer(parse_num(raw_anno)),
    stock_capital_fijo_maquinaria_equipos_mill_usd = parse_num(stock_mill_usd),
    stock_capital_fijo_maquinaria_equipos_indice_dic_2008_100 = parse_num(indice),
    fuente_dato = fuente_dato_raw
  ) %>%
  filter(!is.na(anno), anno >= 1988L, anno <= 2011L) %>%
  mutate(
    fuente = "ciu",
    archivo = basename(input_path),
    hoja_fuente = "Serie Anual",
    fuente_serie = "serie_anual",
    periodo_referencia = "anio",
    trimestre_referencia = NA_integer_
  )

quarterly_raw <- readxl::read_excel(
  input_path,
  sheet = "Serie Trimestral",
  col_names = c("raw_trimestre", "indice", "stock_mill_usd", "variacion_aa", "fuente_dato_raw"),
  col_types = "text"
)

quarterly_series <- bind_cols(
  quarterly_raw,
  parse_quarter_vector(quarterly_raw$raw_trimestre)
) %>%
  transmute(
    anno,
    trimestre,
    stock_capital_fijo_maquinaria_equipos_indice_dic_2008_100 = parse_num(indice),
    stock_capital_fijo_maquinaria_equipos_mill_usd = parse_num(stock_mill_usd),
    fuente_dato = fuente_dato_raw
  ) %>%
  # DECISION: desde 2012 se usa diciembre de la serie trimestral, tal como
  # solicita el equipo. La hoja anual se conserva solo hasta 2011.
  filter(!is.na(anno), anno >= 2012L, anno <= 2025L, trimestre == 4L) %>%
  mutate(
    fuente = "ciu",
    archivo = basename(input_path),
    hoja_fuente = "Serie Trimestral",
    fuente_serie = "serie_trimestral_diciembre",
    periodo_referencia = "diciembre",
    trimestre_referencia = trimestre
  ) %>%
  select(-trimestre)

output <- bind_rows(annual_series, quarterly_series) %>%
  transmute(
    fuente,
    archivo,
    hoja_fuente,
    fuente_serie,
    anno,
    periodo_referencia,
    trimestre_referencia,
    stock_capital_fijo_maquinaria_equipos_indice_dic_2008_100 =
      round(stock_capital_fijo_maquinaria_equipos_indice_dic_2008_100, 1),
    stock_capital_fijo_maquinaria_equipos_mill_usd =
      round(stock_capital_fijo_maquinaria_equipos_mill_usd, 2),
    unidad_indice = "indice_dic_2008_100",
    unidad_stock = "millones_usd_corrientes",
    cobertura = "industria_sin_refineria_ancap_ni_zonas_francas",
    fuente_dato
  ) %>%
  arrange(anno)

expected_years <- 1988:2025
missing_years <- setdiff(expected_years, output$anno)
extra_years <- setdiff(output$anno, expected_years)

if (length(missing_years) > 0 || length(extra_years) > 0) {
  stop(
    "Cobertura anual inesperada. Faltan: ",
    paste(missing_years, collapse = ", "),
    "; sobran: ",
    paste(extra_years, collapse = ", ")
  )
}

if (anyDuplicated(output$anno) > 0) {
  stop("La salida tiene años duplicados.")
}

if (any(is.na(output$stock_capital_fijo_maquinaria_equipos_indice_dic_2008_100)) ||
    any(is.na(output$stock_capital_fijo_maquinaria_equipos_mill_usd))) {
  stop("La salida tiene valores faltantes en índice o stock.")
}

readr::write_csv(output, output_path, na = "")

message("CSV escrito en ", output_path)
message("Filas: ", nrow(output), "; rango: ", min(output$anno), "-", max(output$anno))
message(
  "Fuente serie: ",
  paste(names(table(output$fuente_serie)), as.integer(table(output$fuente_serie)), collapse = "; ")
)
