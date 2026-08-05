# Process INE Uruguay exchange-rate source for annual December USD rates.
#
# Run from the project root:
#   Rscript command-files/processing-command-files/16_process_ine_tipo_cambio.R

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(readr)
  library(readxl)
  library(tibble)
})

input_dir <- file.path("data", "input-data", "INE-UY")
analysis_dir <- file.path("data", "analysis-data")

source_url <- paste0(
  "https://www5.ine.gub.uy/documents/Estad%C3%ADsticasecon%C3%B3micas/",
  "SERIES%20Y%20OTROS/Cotizaci%C3%B3n%20monedas/",
  "Cotizaci%C3%B3n%20monedas.xlsx"
)
input_path <- file.path(input_dir, "20260805_cotizacion_monedas_ine_uy.xlsx")
output_path <- file.path(
  analysis_dir,
  "20260805_ine_uy_tipo_cambio_dolar_diciembre.csv"
)

dir.create(input_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(input_path)) {
  # DECISION: the INE HTTPS endpoint can fail local certificate validation in
  # this workstation. Use curl with --insecure only to preserve the original
  # XLSX source file when it is not already present.
  status <- system2(
    "curl",
    args = c("-k", "-L", "--fail", "--retry", "3", "--output", input_path, source_url)
  )
  if (!identical(status, 0L)) {
    stop("No se pudo descargar la fuente INE de cotizacion de monedas.")
  }
}

parse_num <- function(x) {
  readr::parse_number(
    as.character(x),
    locale = readr::locale(decimal_mark = ".", grouping_mark = ","),
    na = c("", "..", "NA", "N/A")
  )
}

sheet_name <- "Fuente BROU"
headers <- readxl::read_excel(
  input_path,
  sheet = sheet_name,
  col_names = FALSE,
  n_max = 1,
  col_types = "text"
) |>
  unlist(use.names = FALSE) |>
  as.character()

raw <- readxl::read_excel(
  input_path,
  sheet = sheet_name,
  skip = 1,
  col_names = headers,
  col_types = "text"
)

required_columns <- c("Fecha", "Dólar.USA.Compra", "Dólar.USA.Venta")
missing_columns <- setdiff(required_columns, names(raw))
if (length(missing_columns) > 0) {
  stop("Faltan columnas esperadas en la fuente INE: ", paste(missing_columns, collapse = ", "))
}

output <- raw |>
  transmute(
    fecha = lubridate::dmy(Fecha),
    dolar_usa_compra = parse_num(`Dólar.USA.Compra`),
    dolar_usa_venta = parse_num(`Dólar.USA.Venta`)
  ) |>
  filter(
    !is.na(fecha),
    lubridate::month(fecha) == 12L,
    !is.na(dolar_usa_compra),
    !is.na(dolar_usa_venta)
  ) |>
  mutate(anno = lubridate::year(fecha)) |>
  arrange(anno, fecha) |>
  group_by(anno) |>
  slice_tail(n = 1) |>
  ungroup() |>
  transmute(
    fuente = "ine_uy",
    archivo = basename(input_path),
    hoja_fuente = sheet_name,
    anno,
    fecha_referencia = as.character(fecha),
    dolar_usa_compra = round(dolar_usa_compra, 6),
    dolar_usa_venta = round(dolar_usa_venta, 6),
    unidad = "pesos_uruguayos_por_dolar",
    criterio = "ultimo_valor_disponible_en_diciembre"
  ) |>
  arrange(anno)

if (nrow(output) == 0) {
  stop("No se extrajeron observaciones de diciembre para dolar USA.")
}

if (anyDuplicated(output$anno) > 0) {
  stop("La salida INE tiene anos duplicados.")
}

readr::write_csv(output, output_path, na = "")

message("CSV escrito en ", output_path)
message("Filas: ", nrow(output), "; rango: ", min(output$anno), "-", max(output$anno))
