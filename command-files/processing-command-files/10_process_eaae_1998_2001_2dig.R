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

INPUT_DIR <- "data/input-data/eaae-1998-2001"
OUTPUT_PANEL <- "data/analysis-data/eaae_1998_2001_2dig_panel.csv"

TARGET_YEARS <- 1998:2001
TARGET_CUADROS <- c(1L, 2L, 14L, 15L, 16L, 17L)
TARGET_UNIVERSE <- "empresas_5_mas"
MONETARY_SCALE <- 1000
TOLERANCE_PESOS <- 1000

SECTION_HOMOLOGATION_REV3 <- c(
  A = "A",
  B = "A",
  C = "B",
  D = "C",
  E = "D_E",
  F = "F",
  G = "G",
  H = "I",
  I = "H_J",
  J = "K",
  K = "L_M_N",
  L = "O",
  M = "P",
  N = "Q",
  O = "R_S",
  P = "T",
  Q = "U"
)

normalize_text <- function(x) {
  x <- as.character(x)
  x <- ifelse(is.na(x), NA_character_, x)
  str_squish(x)
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
      sheet = as.character(sheet),
      col_names = FALSE,
      col_types = "text",
      .name_repair = "minimal",
      n_max = n_max
    )
  )
  names(out) <- paste0("col_", seq_along(out))
  out %>% mutate(across(everything(), normalize_text))
}

ensure_cols <- function(df, n) {
  for (i in seq_len(n)) {
    col <- paste0("col_", i)
    if (!col %in% names(df)) {
      df[[col]] <- NA_character_
    }
  }
  df
}

detect_sheet_year <- function(sheet_data) {
  values <- unlist(sheet_data[seq_len(min(8L, nrow(sheet_data))), ], use.names = FALSE)
  values <- values[!is.na(values) & str_length(str_trim(values)) > 0]
  years <- str_extract_all(paste(values, collapse = " | "), "(19|20)\\d{2}")[[1]]
  if (length(years) == 0L) {
    return(NA_integer_)
  }
  as.integer(years[[1]])
}

detect_cuadro_number <- function(sheet_data) {
  values <- unlist(sheet_data[seq_len(min(8L, nrow(sheet_data))), ], use.names = FALSE)
  values <- values[!is.na(values) & str_length(str_trim(values)) > 0]
  found <- str_match_all(
    str_to_upper(paste(values, collapse = " | ")),
    "CUADRO\\s*(N\\s*[°º])?\\s*[:.]?\\s*0*([0-9]{1,2})"
  )[[1]]
  if (nrow(found) == 0L) {
    return(NA_integer_)
  }
  as.integer(found[1, 3])
}

detect_index_sheet <- function(path) {
  sheets <- excel_sheets(path)
  idx <- sheets[str_detect(sheets, "INDICE|ÍNDICE")]
  if (length(idx) != 1L) {
    stop("No se encontro una hoja indice unica en ", basename(path))
  }
  idx[[1]]
}

build_sheet_index <- function(path) {
  raw <- read_sheet_text(path, detect_index_sheet(path)) %>%
    ensure_cols(2) %>%
    mutate(col_1_upper = str_to_upper(.data$col_1))

  universe <- NA_character_
  cuadro <- 0L
  out <- list()

  for (i in seq_len(nrow(raw))) {
    label <- raw$col_1_upper[[i]]

    if (!is.na(label) && str_detect(label, "5 Y M")) {
      universe <- "empresas_5_mas"
      cuadro <- 0L
      next
    }

    if (!is.na(label) && str_detect(label, "5 A 49")) {
      universe <- "empresas_5_49"
      cuadro <- 0L
      next
    }

    sheet_number <- as_number(raw$col_1[[i]])
    if (!is.na(sheet_number) && !is.na(universe)) {
      cuadro <- cuadro + 1L
      out[[length(out) + 1L]] <- tibble(
        sheet = as.character(as.integer(sheet_number)),
        universo = universe,
        cuadro = cuadro,
        titulo_indice = raw$col_2[[i]]
      )
    }
  }

  bind_rows(out)
}

variable_map <- function(cuadro) {
  out <- switch(
    as.character(cuadro),
    "1" = tibble(
      pos = 1:4,
      variable = c("vbp_pp", "vab_pp", "remuneraciones", "puestos_trabajo"),
      monetary = c(TRUE, TRUE, TRUE, FALSE)
    ),
    "2" = tibble(
      pos = 1:7,
      variable = c(
        "vbp_pp_c2",
        "consumo_intermedio",
        "vab_pp_c2",
        "impuestos_netos",
        "consumo_capital_fijo",
        "remuneraciones_c2",
        "excedente_explotacion"
      ),
      monetary = TRUE
    ),
    "14" = tibble(
      pos = 1:7,
      variable = c(
        "fbcf",
        "adquisiciones_activo_fijo_total",
        "construccion_cuenta_propia",
        "adquisiciones_total",
        "adquisiciones_importadas",
        "adquisiciones_en_plaza",
        "disposiciones_activo_fijo"
      ),
      monetary = TRUE
    ),
    "15" = tibble(
      pos = 1:5,
      variable = c(
        "stock_capital",
        "stock_edificios_construcciones",
        "stock_maquinaria_equipos",
        "stock_otros",
        "stock_activos_intangibles"
      ),
      monetary = TRUE
    ),
    "16" = tibble(
      pos = 1:7,
      variable = c(
        "variacion_existencias",
        "variacion_existencias_mercaderias_reventa",
        "variacion_existencias_materias_primas",
        "variacion_existencias_productos_en_proceso",
        "variacion_existencias_productos_terminados",
        "variacion_existencias_envases_embalajes",
        "variacion_existencias_repuestos_accesorios"
      ),
      monetary = TRUE
    ),
    "17" = tibble(
      pos = 1:5,
      variable = c(
        "fbcf_componentes_total",
        "fbkf_edificios_construcciones",
        "fbkf_maq_eq",
        "fbkf_otros",
        "fbkf_activos_intangibles"
      ),
      monetary = TRUE
    ),
    stop("No hay mapa de variables para cuadro ", cuadro)
  )

  out %>% mutate(col = 3L + .data$pos)
}

extract_sheet_data <- function(path, anno, sheet_info) {
  raw_head <- read_sheet_text(path, sheet_info$sheet, n_max = 12)
  detected_year <- detect_sheet_year(raw_head)
  detected_cuadro <- detect_cuadro_number(raw_head)

  if (!is.na(detected_cuadro) && detected_cuadro != sheet_info$cuadro) {
    stop(
      "Cuadro inesperado en ", basename(path), " hoja ", sheet_info$sheet,
      ": indice=", sheet_info$cuadro, ", hoja=", detected_cuadro
    )
  }

  # DECISION: the 1999 workbook includes several target sheets that are exact
  # copies of year 2000 sheets. When the sheet title year disagrees with the
  # file year, skip that sheet instead of importing data under the wrong year.
  if (!is.na(detected_year) && detected_year != anno) {
    return(tibble(
      skipped = TRUE,
      anno = anno,
      archivo = basename(path),
      sheet = sheet_info$sheet,
      cuadro = sheet_info$cuadro,
      detected_year = detected_year,
      universo = sheet_info$universo,
      seccion_fuente = NA_character_,
      division_publicada = NA_character_,
      descripcion = NA_character_,
      variable = NA_character_,
      value = NA_real_,
      fila_excel = NA_integer_
    ))
  }

  vars <- variable_map(sheet_info$cuadro)
  raw <- read_sheet_text(path, sheet_info$sheet) %>%
    ensure_cols(max(vars$col)) %>%
    mutate(fila_excel = row_number())

  numeric_cols <- paste0("col_", vars$col)
  data_rows <- raw %>%
    mutate(
      n_numeric = rowSums(across(all_of(numeric_cols), ~ !is.na(as_number(.x))))
    ) %>%
    filter(
      !is.na(.data$col_3),
      .data$col_3 != "",
      .data$n_numeric > 0L,
      !coalesce(str_detect(str_to_upper(.data$col_1), "^SECCI"), FALSE),
      !coalesce(str_detect(str_to_upper(.data$col_2), "^DIVISI"), FALSE),
      !coalesce(str_detect(str_to_upper(.data$col_3), "^DESCRIPCI"), FALSE)
    )

  if (nrow(data_rows) == 0L) {
    stop(
      "No se detectaron filas de datos en ", basename(path),
      " hoja ", sheet_info$sheet
    )
  }

  base_rows <- data_rows %>%
    transmute(
      skipped = FALSE,
      anno = anno,
      archivo = basename(path),
      sheet = sheet_info$sheet,
      cuadro = sheet_info$cuadro,
      detected_year = detected_year,
      universo = sheet_info$universo,
      seccion_fuente = case_when(
        str_to_upper(.data$col_3) == "TOTAL" ~ "TOTAL",
        TRUE ~ .data$col_1
      ),
      division_publicada = case_when(
        str_to_upper(.data$col_3) == "TOTAL" ~ "TOTAL",
        is.na(.data$col_2) | .data$col_2 == "" ~ NA_character_,
        TRUE ~ .data$col_2
      ),
      descripcion = str_replace_all(.data$col_3, "\\s+", " "),
      fila_excel = .data$fila_excel
    )

  map_dfr(seq_len(nrow(vars)), function(i) {
    col_name <- paste0("col_", vars$col[[i]])
    raw_value <- as_number(data_rows[[col_name]])
    value <- if (isTRUE(vars$monetary[[i]])) raw_value * MONETARY_SCALE else raw_value

    base_rows %>%
      mutate(
        variable = vars$variable[[i]],
        value = value
      )
  }) %>%
    filter(!is.na(.data$value))
}

homologate_section <- function(section) {
  case_when(
    section == "TOTAL" ~ "TOTAL",
    section %in% names(SECTION_HOMOLOGATION_REV3) ~
      unname(SECTION_HOMOLOGATION_REV3[section]),
    TRUE ~ NA_character_
  )
}

classify_level <- function(section, division) {
  case_when(
    section == "TOTAL" ~ "economia_total",
    is.na(division) | division == "" ~ "seccion",
    str_detect(division, "-") ~ "grupo_divisiones_publicado",
    str_detect(division, "^\\d{2}$") ~ "division_2_digitos",
    TRUE ~ "division_publicada"
  )
}

build_panel <- function(long_data) {
  data <- long_data %>% filter(!.data$skipped)

  meta <- data %>%
    group_by(
      .data$anno,
      .data$universo,
      .data$seccion_fuente,
      .data$division_publicada
    ) %>%
    summarise(descripcion = first(.data$descripcion), .groups = "drop") %>%
    mutate(
      fuente = "EAE 1998-2001 2 digitos",
      ciiu_version = "Rev.3",
      seccion = homologate_section(.data$seccion_fuente),
      nivel_agregacion = classify_level(.data$seccion_fuente, .data$division_publicada)
    )

  values <- data %>%
    select(
      "anno",
      "universo",
      "seccion_fuente",
      "division_publicada",
      "variable",
      "value"
    ) %>%
    distinct() %>%
    pivot_wider(names_from = "variable", values_from = "value")

  meta %>%
    left_join(
      values,
      by = c("anno", "universo", "seccion_fuente", "division_publicada")
    ) %>%
    arrange(
      .data$anno,
      match(
        .data$nivel_agregacion,
        c(
          "economia_total",
          "seccion",
          "division_2_digitos",
          "grupo_divisiones_publicado",
          "division_publicada"
        )
      ),
      .data$seccion_fuente,
      .data$division_publicada
    )
}

validate_panel <- function(panel, skipped_sheets) {
  dupes <- panel %>%
    count(.data$anno, .data$seccion_fuente, .data$division_publicada, name = "n") %>%
    filter(.data$n > 1L)
  if (nrow(dupes) > 0L) {
    print(dupes)
    stop("El panel tiene claves duplicadas")
  }

  bad_sections <- panel %>% filter(is.na(.data$seccion))
  if (nrow(bad_sections) > 0L) {
    print(bad_sections %>% select("anno", "seccion_fuente", "descripcion"))
    stop("Hay secciones Rev.3 sin homologacion")
  }

  c2_checks <- panel %>%
    filter(!is.na(.data$vbp_pp_c2)) %>%
    transmute(
      anno = .data$anno,
      seccion_fuente = .data$seccion_fuente,
      division_publicada = .data$division_publicada,
      descripcion = .data$descripcion,
      diff_vbp_c1_c2 = abs(.data$vbp_pp - .data$vbp_pp_c2),
      diff_vab_c1_c2 = abs(.data$vab_pp - .data$vab_pp_c2),
      diff_rem_c1_c2 = abs(.data$remuneraciones - .data$remuneraciones_c2),
      diff_vbp_identidad = abs(.data$vbp_pp_c2 - .data$consumo_intermedio - .data$vab_pp_c2),
      diff_vab_identidad = abs(
        .data$vab_pp_c2 -
          .data$impuestos_netos -
          .data$consumo_capital_fijo -
          .data$remuneraciones_c2 -
          .data$excedente_explotacion
      )
    )

  c2_large_diff <- c2_checks %>%
    filter(
      .data$diff_vbp_c1_c2 > TOLERANCE_PESOS |
        .data$diff_vab_c1_c2 > TOLERANCE_PESOS |
        .data$diff_rem_c1_c2 > TOLERANCE_PESOS
    )
  if (nrow(c2_large_diff) > 0L) {
    print(c2_large_diff)
    stop("C1 y C2 difieren por encima de la tolerancia")
  }

  c2_identity_fail <- c2_checks %>%
    filter(
      .data$diff_vbp_identidad > TOLERANCE_PESOS |
        .data$diff_vab_identidad > TOLERANCE_PESOS
    )
  if (nrow(c2_identity_fail) > 0L) {
    print(c2_identity_fail)
    stop("Fallo una identidad contable del cuadro 2")
  }

  fbcf_checks <- panel %>%
    filter(!is.na(.data$fbcf)) %>%
    transmute(
      anno = .data$anno,
      seccion_fuente = .data$seccion_fuente,
      division_publicada = .data$division_publicada,
      descripcion = .data$descripcion,
      diff_fbcf_componentes = abs(.data$fbcf - .data$fbcf_componentes_total),
      diff_fbcf_adq_disp = abs(
        .data$fbcf -
          (.data$adquisiciones_activo_fijo_total + .data$disposiciones_activo_fijo)
      ),
      diff_adq_total = abs(
        .data$adquisiciones_total -
          .data$adquisiciones_importadas -
          .data$adquisiciones_en_plaza
      ),
      diff_adq_componentes = abs(
        .data$adquisiciones_activo_fijo_total -
          .data$construccion_cuenta_propia -
          .data$adquisiciones_total
      )
    )

  fbcf_fail <- fbcf_checks %>%
    filter(if_any(starts_with("diff_"), ~ .x > TOLERANCE_PESOS))
  if (nrow(fbcf_fail) > 0L) {
    print(fbcf_fail)
    stop("Fallo una identidad de FBCF")
  }

  if (nrow(skipped_sheets) > 0L) {
    message("Hojas omitidas por anio inconsistente en el encabezado:")
    skipped_sheets %>%
      select(
        "anno",
        "archivo",
        "sheet",
        "cuadro",
        "detected_year"
      ) %>%
      distinct() %>%
      arrange(.data$anno, .data$cuadro) %>%
      print(n = Inf)
  }
}

drop_check_columns <- function(panel) {
  panel %>%
    select(
      -any_of(c(
        "vbp_pp_c2",
        "vab_pp_c2",
        "remuneraciones_c2",
        "fbcf_componentes_total"
      ))
    )
}

main <- function() {
  files <- tibble(
    path = sort(list.files(INPUT_DIR, pattern = "\\.xls$", full.names = TRUE))
  ) %>%
    mutate(anno = as.integer(str_extract(basename(.data$path), "\\d{4}"))) %>%
    filter(.data$anno %in% TARGET_YEARS)

  if (nrow(files) != length(TARGET_YEARS)) {
    stop(
      "Se esperaban ", length(TARGET_YEARS), " archivos EAE 1998-2001 y se encontraron ",
      nrow(files)
    )
  }

  sheet_index <- files %>%
    pmap_dfr(function(path, anno) {
      build_sheet_index(path) %>%
        filter(
          .data$universo == TARGET_UNIVERSE,
          .data$cuadro %in% TARGET_CUADROS
        ) %>%
        mutate(anno = anno, path = path, archivo = basename(path))
    })

  expected <- expand_grid(anno = TARGET_YEARS, cuadro = TARGET_CUADROS)
  missing <- expected %>%
    anti_join(sheet_index, by = c("anno", "cuadro"))
  duplicated_sheets <- sheet_index %>%
    count(.data$anno, .data$cuadro, name = "n") %>%
    filter(.data$n != 1L)

  if (nrow(missing) > 0L || nrow(duplicated_sheets) > 0L) {
    print(missing)
    print(duplicated_sheets)
    stop("Fallo la deteccion unica de cuadros objetivo")
  }

  long_data <- sheet_index %>%
    arrange(.data$anno, .data$cuadro) %>%
    pmap_dfr(function(sheet, universo, cuadro, titulo_indice, anno, path, archivo) {
      extract_sheet_data(
        path = path,
        anno = anno,
        sheet_info = tibble(
          sheet = sheet,
          universo = universo,
          cuadro = cuadro,
          titulo_indice = titulo_indice
        )
      )
    })

  skipped_sheets <- long_data %>% filter(.data$skipped)
  panel <- build_panel(long_data)
  validate_panel(panel, skipped_sheets)
  panel_output <- drop_check_columns(panel)

  dir.create(dirname(OUTPUT_PANEL), recursive = TRUE, showWarnings = FALSE)
  write_csv(panel_output, OUTPUT_PANEL, na = "")

  message("Escrito: ", OUTPUT_PANEL, " (", nrow(panel_output), " filas)")
}

main()
