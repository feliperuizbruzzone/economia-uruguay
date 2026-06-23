#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(readr)
  library(readxl)
  library(stringr)
  library(tibble)
  library(tidyr)
})

INPUT_DIR <- "data/input-data/EIA 1989-1997"
OUTPUT_PANEL <- "data/analysis-data/20260623_panel_eia_1989_1997_2dig.csv"

YEARS <- 1989:1997
INDUSTRY_CODES_REV2 <- c("3", as.character(31:39))

section_labels_rev2 <- tibble(
  seccion = INDUSTRY_CODES_REV2,
  seccion_etiqueta = c(
    "Industrias manufactureras",
    "Productos alimenticios, bebidas y tabaco",
    "Textiles, prendas de vestir e industrias del cuero",
    "Industria de la madera y productos de madera, incluidos muebles",
    "Fabricacion de papel y productos de papel; imprentas y editoriales",
    "Fabricacion de sustancias quimicas y productos quimicos; derivados del petroleo y carbon; caucho y plastico",
    "Fabricacion de productos minerales no metalicos, excepto derivados del petroleo y carbon",
    "Industrias metalicas basicas",
    "Fabricacion de productos metalicos, maquinaria y equipo",
    "Otras industrias manufactureras"
  )
)

normalize_text <- function(x) {
  x <- as.character(x)
  x <- ifelse(is.na(x), NA_character_, x)
  str_squish(x)
}

is_code <- function(x) {
  str_detect(str_trim(as.character(x)), "^\\d{1,6}$")
}

as_number <- function(x) {
  suppressWarnings(
    parse_number(
      as.character(x),
      locale = locale(decimal_mark = ".", grouping_mark = ","),
      na = c("", "NA", "N/A")
    )
  )
}

read_sheet_text <- function(path, sheet, n_max = Inf) {
  out <- suppressMessages(
    read_excel(
      path,
      sheet = sheet,
      col_names = FALSE,
      col_types = "text",
      .name_repair = "minimal",
      n_max = n_max
    )
  )
  names(out) <- paste0("col_", seq_along(out))
  out %>% mutate(across(everything(), normalize_text))
}

detect_cuadro_number <- function(sheet_data) {
  vals <- unlist(sheet_data, use.names = FALSE)
  vals <- vals[!is.na(vals) & str_length(str_trim(vals)) > 0]
  txt <- str_to_upper(paste(vals, collapse = " | "))
  found <- str_match_all(
    txt,
    "CUADRO\\s*(N\\s*[°º])?\\s*[:.]?\\s*0*([0-9]{1,2})"
  )[[1]]
  if (nrow(found) == 0) {
    return(NA_integer_)
  }
  as.integer(found[1, 3])
}

extract_title <- function(sheet_data) {
  vals <- unlist(sheet_data, use.names = FALSE)
  vals <- normalize_text(vals)
  vals <- vals[!is.na(vals) & str_length(vals) > 0]
  vals <- vals[!str_detect(str_to_upper(vals), "^RAMA\\s*\\d+")]
  vals <- vals[!is_code(vals)]
  str_c(head(vals, 4), collapse = " | ")
}

infer_scale <- function(title) {
  if (str_detect(str_to_upper(title), "MILES")) {
    return(1000)
  }
  1
}

files_index <- function() {
  files <- tibble(path = sort(list.files(INPUT_DIR, pattern = "\\.xlsx?$", full.names = TRUE))) %>%
    mutate(anno = as.integer(str_extract(basename(.data$path), "\\d{4}"))) %>%
    filter(.data$anno %in% YEARS)

  if (nrow(files) != length(YEARS)) {
    stop("Se esperaban ", length(YEARS), " archivos EIA y se encontraron ", nrow(files))
  }

  files
}

detect_sheet_index <- function(path, anno) {
  excel_sheets(path) %>%
    discard(~ .x == "ÍNDICE") %>%
    map_dfr(function(sheet) {
      head_data <- read_sheet_text(path, sheet, n_max = 15)
      vals <- unlist(head_data, use.names = FALSE)
      vals <- vals[!is.na(vals) & str_length(vals) > 0]
      title <- extract_title(head_data)
      tibble(
        anno = anno,
        archivo = basename(path),
        sheet = sheet,
        cuadro = detect_cuadro_number(head_data),
        cuadro_titulo = title,
        es_stock_capital = str_detect(
          str_to_upper(paste(vals, collapse = " | ")),
          "VALOR\\s+DE\\s+LOS\\s+ACTIVOS\\s+FIJOS\\s+AL\\s+31/12"
        )
      )
    })
}

require_unique_sheet <- function(sheet_index, anno, predicate, label) {
  hits <- sheet_index %>% filter(.data$anno == !!anno) %>% filter({{ predicate }})
  if (nrow(hits) != 1L) {
    print(hits)
    stop("No se detecto una unica hoja para ", label, " en ", anno)
  }
  hits %>% slice(1)
}

account_var_map <- function(anno) {
  if (anno <= 1990L) {
    return(tibble(
      pos = c(1L, 2L, 3L, 5L, 6L),
      variable = c(
        "vbp_pp",
        "consumo_intermedio",
        "vab_pp",
        "consumo_capital_fijo",
        "remuneraciones"
      )
    ))
  }

  if (anno %in% 1991:1996) {
    return(tibble(
      pos = c(1L, 2L, 3L, 6L, 4L),
      variable = c(
        "vbp_pp",
        "consumo_intermedio",
        "vab_pp",
        "consumo_capital_fijo",
        "remuneraciones"
      )
    ))
  }

  if (anno == 1997L) {
    return(tibble(
      pos = c(1L, 2L, 3L, 5L, 6L),
      variable = c(
        "vbp_pp",
        "consumo_intermedio",
        "vab_pp",
        "consumo_capital_fijo",
        "remuneraciones"
      )
    ))
  }

  stop("Anno fuera de rango EIA: ", anno)
}

extract_accounts <- function(path, sheet_info) {
  anno <- sheet_info$anno[[1]]
  raw <- read_sheet_text(path, sheet_info$sheet[[1]]) %>%
    mutate(fila_excel = row_number())

  data_rows <- raw %>%
    filter(
      is_code(.data$col_1),
      str_trim(.data$col_1) %in% INDUSTRY_CODES_REV2
    )

  if (nrow(data_rows) != length(INDUSTRY_CODES_REV2)) {
    stop(
      "Cuadro 2 ", anno, ": se esperaban ",
      length(INDUSTRY_CODES_REV2), " filas industriales y se detectaron ",
      nrow(data_rows)
    )
  }

  first_row <- data_rows %>% slice(1)
  second_value <- if ("col_2" %in% names(first_row)) first_row$col_2 else NA_character_
  has_description <- !is.na(second_value) && is.na(as_number(second_value))
  variable_start_col <- if (has_description) 3L else 2L

  vars <- account_var_map(anno) %>%
    mutate(col = .data$pos + variable_start_col - 1L)
  scale <- infer_scale(sheet_info$cuadro_titulo[[1]])

  vars %>%
    pmap_dfr(function(pos, variable, col) {
      col_name <- paste0("col_", col)
      if (!col_name %in% names(data_rows)) {
        stop("No existe ", col_name, " en Cuadro 2 ", anno)
      }

      data_rows %>%
        transmute(
          anno = anno,
          seccion = str_trim(.data$col_1),
          variable = variable,
          valor = as_number(.data[[col_name]]) * scale
        )
    }) %>%
    pivot_wider(names_from = variable, values_from = valor)
}

extract_stock_capital <- function(path, sheet_info) {
  anno <- sheet_info$anno[[1]]
  raw <- read_sheet_text(path, sheet_info$sheet[[1]]) %>%
    mutate(fila_excel = row_number())

  data_rows <- raw %>%
    filter(
      is_code(.data$col_1),
      str_trim(.data$col_1) %in% INDUSTRY_CODES_REV2
    )

  if (nrow(data_rows) != length(INDUSTRY_CODES_REV2)) {
    stop(
      "Stock ", anno, ": se esperaban ",
      length(INDUSTRY_CODES_REV2), " filas industriales y se detectaron ",
      nrow(data_rows)
    )
  }

  # DECISION: en EIA solo se considera `stock_capital` original si el cuadro
  # declara valor de activos fijos al 31/12. En la serie disponible esto ocurre
  # solamente en 1997, Cuadro 18; los cuadros 18 de 1989-1996 son flujos de
  # capital y no se cargan como stock.
  data_rows %>%
    transmute(
      anno = anno,
      seccion = str_trim(.data$col_1),
      stock_capital = as_number(.data$col_2)
    )
}

add_stock_imputation <- function(panel) {
  ratios <- panel %>%
    filter(.data$anno == 1997L) %>%
    transmute(
      seccion,
      stock_consumo_ratio_1997 = .data$stock_capital / .data$consumo_capital_fijo
    )

  if (any(is.na(ratios$stock_consumo_ratio_1997))) {
    print(ratios)
    stop("No se pudo calcular el ratio stock/consumo de capital fijo 1997 para todas las divisiones")
  }

  panel %>%
    left_join(ratios, by = "seccion") %>%
    mutate(
      # DECISION: `stock_capital` preserva solo el dato original valido de 1997.
      # `stock_capital_imputado` replica ese dato cuando existe y para 1989-1996
      # imputa por division Rev.2 usando consumo_capital_fijo_t *
      # (stock_capital_1997 / consumo_capital_fijo_1997).
      stock_capital_imputado = if_else(
        !is.na(.data$stock_capital),
        .data$stock_capital,
        .data$consumo_capital_fijo * .data$stock_consumo_ratio_1997
      )
    ) %>%
    select(-stock_consumo_ratio_1997)
}

validate_panel <- function(panel) {
  expected <- expand_grid(anno = YEARS, seccion = INDUSTRY_CODES_REV2)
  missing_keys <- expected %>%
    anti_join(panel, by = c("anno", "seccion"))
  duplicate_keys <- panel %>%
    count(.data$anno, .data$seccion) %>%
    filter(.data$n != 1L)

  if (nrow(missing_keys) > 0 || nrow(duplicate_keys) > 0) {
    print(missing_keys)
    print(duplicate_keys)
    stop("Falla de cobertura o unicidad anno + seccion")
  }

  missing_labels <- panel %>%
    filter(is.na(.data$seccion_etiqueta) | .data$seccion_etiqueta == "")

  if (nrow(missing_labels) > 0) {
    print(missing_labels)
    stop("Hay secciones sin etiqueta")
  }

  required_complete <- c(
    "vbp_pp",
    "vab_pp",
    "consumo_intermedio",
    "remuneraciones",
    "consumo_capital_fijo",
    "stock_capital_imputado"
  )

  missing_values <- panel %>%
    summarise(across(all_of(required_complete), ~ sum(is.na(.x)))) %>%
    pivot_longer(everything(), names_to = "variable", values_to = "n_na") %>%
    filter(.data$n_na > 0)

  if (nrow(missing_values) > 0) {
    print(missing_values)
    stop("Hay valores faltantes en variables requeridas para tasa de ganancia")
  }

  invalid_stock <- panel %>%
    filter((.data$anno == 1997L & is.na(.data$stock_capital)) |
      (.data$anno != 1997L & !is.na(.data$stock_capital)))

  if (nrow(invalid_stock) > 0) {
    print(invalid_stock)
    stop("`stock_capital` debe existir solo como dato original 1997")
  }

  accounting_gap <- panel %>%
    mutate(
      gap = abs(.data$vbp_pp - .data$consumo_intermedio - .data$vab_pp),
      tol = pmax(1, abs(.data$vbp_pp) * 1e-8)
    ) %>%
    filter(.data$gap > .data$tol)

  if (nrow(accounting_gap) > 0) {
    print(accounting_gap)
    stop("Falla identidad VBP = consumo intermedio + VAB")
  }

  total_consistency <- c(
    "vbp_pp",
    "vab_pp",
    "consumo_intermedio",
    "remuneraciones",
    "consumo_capital_fijo"
  ) %>%
    map_dfr(function(variable_name) {
      panel %>%
        group_by(.data$anno) %>%
        summarise(
          total = first(.data[[variable_name]][.data$seccion == "3"]),
          suma_divisiones = sum(.data[[variable_name]][.data$seccion != "3"], na.rm = TRUE),
          .groups = "drop"
        ) %>%
        mutate(
          variable = variable_name,
          diferencia_abs = abs(.data$total - .data$suma_divisiones),
          diferencia_rel = .data$diferencia_abs / pmax(1, abs(.data$total))
        )
    }) %>%
    filter(.data$diferencia_rel > 1e-5)

  if (nrow(total_consistency) > 0) {
    print(total_consistency)
    stop("El total industrial 3 no coincide con la suma de divisiones 31-39")
  }

  invisible(TRUE)
}

main <- function() {
  files <- files_index()
  sheet_index <- files %>%
    pmap_dfr(function(path, anno) detect_sheet_index(path, anno))

  accounts <- files %>%
    mutate(sheet_info = map2(.data$path, .data$anno, function(path, anno) {
      require_unique_sheet(sheet_index, anno, .data$cuadro == 2L, "Cuadro 2")
    })) %>%
    mutate(data = map2(.data$path, .data$sheet_info, extract_accounts)) %>%
    select(data) %>%
    unnest(cols = c(data))

  stock_sheet <- sheet_index %>%
    filter(.data$es_stock_capital)

  if (nrow(stock_sheet) != 1L || stock_sheet$anno[[1]] != 1997L) {
    print(stock_sheet)
    stop("Se esperaba una unica fuente de stock original en 1997")
  }

  stock <- files %>%
    filter(.data$anno == 1997L) %>%
    mutate(data = map(.data$path, ~ extract_stock_capital(.x, stock_sheet))) %>%
    select(data) %>%
    unnest(cols = c(data))

  panel <- accounts %>%
    left_join(stock, by = c("anno", "seccion")) %>%
    left_join(section_labels_rev2, by = "seccion") %>%
    mutate(
      epoca = "EIA_1989_1997",
      ciiu_version = "Rev.2"
    ) %>%
    add_stock_imputation() %>%
    arrange(.data$anno, .data$seccion) %>%
    select(
      anno,
      seccion,
      seccion_etiqueta,
      epoca,
      ciiu_version,
      vbp_pp,
      vab_pp,
      consumo_intermedio,
      remuneraciones,
      consumo_capital_fijo,
      stock_capital,
      stock_capital_imputado
    )

  validate_panel(panel)

  dir.create(dirname(OUTPUT_PANEL), recursive = TRUE, showWarnings = FALSE)
  write_csv(panel, OUTPUT_PANEL, na = "")

  message("Escrito: ", OUTPUT_PANEL, " (", nrow(panel), " filas)")
}

main()
