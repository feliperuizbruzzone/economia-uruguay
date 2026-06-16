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
OUTPUT_TIDY <- "data/analysis-data/eia_1989_1997_cuadros_tidy.csv"
OUTPUT_PANEL <- "data/analysis-data/eia_1989_1997_panel.csv"
OUTPUT_VALIDACIONES <- "data/analysis-data/eia_1989_1997_validaciones.csv"

TARGET_CUADROS <- c(2L, 5L, 9L, 16L, 17L, 19L)

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

detect_target_sheets <- function(path, anno) {
  excel_sheets(path) %>%
    discard(~ .x == "ÍNDICE") %>%
    map_dfr(function(sheet) {
      head_data <- read_sheet_text(path, sheet, n_max = 15)
      tibble(
        anno = anno,
        archivo = basename(path),
        sheet = sheet,
        cuadro = detect_cuadro_number(head_data),
        cuadro_titulo = extract_title(head_data)
      )
    }) %>%
    filter(cuadro %in% TARGET_CUADROS)
}

var_map <- function(anno, cuadro) {
  if (cuadro == 2L && anno <= 1990L) {
    return(tibble(
      pos = 1:7,
      variable_original = c("vbp", "ci", "vab", "ii_s", "d", "r", "ee"),
      variable_canonica = c(
        "vbp_corriente",
        "consumo_intermedio",
        "vab_corriente",
        "impuestos_netos",
        "consumo_capital_fijo",
        "remuneraciones",
        "excedente_explotacion"
      )
    ))
  }

  if (cuadro == 2L && anno %in% 1991:1996) {
    return(tibble(
      pos = 1:7,
      variable_original = c(
        "vbp_total",
        "consumo_intermedio",
        "valor_agregado_bruto",
        "remuneraciones",
        "impuestos_indirectos",
        "depreciacion",
        "excedentes_explotacion"
      ),
      variable_canonica = c(
        "vbp_corriente",
        "consumo_intermedio",
        "vab_corriente",
        "remuneraciones",
        "impuestos_netos",
        "consumo_capital_fijo",
        "excedente_explotacion"
      )
    ))
  }

  if (cuadro == 2L && anno == 1997L) {
    return(tibble(
      pos = 1:7,
      variable_original = c(
        "valor_bruto_produccion",
        "consumo_intermedio",
        "valor_agregado_bruto",
        "impuestos_netos_subsidios",
        "consumo_capital_fijo",
        "remuneraciones",
        "excedente_explotacion"
      ),
      variable_canonica = c(
        "vbp_corriente",
        "consumo_intermedio",
        "vab_corriente",
        "impuestos_netos",
        "consumo_capital_fijo",
        "remuneraciones",
        "excedente_explotacion"
      )
    ))
  }

  if (cuadro == 5L && anno <= 1990L) {
    return(tibble(
      pos = 1:6,
      variable_original = c(
        "total",
        "mayorista",
        "minorista",
        "gobierno",
        "otras",
        "publico"
      ),
      variable_canonica = c(
        "ventas_pais_total",
        "ventas_pais_mayorista",
        "ventas_pais_minorista",
        "ventas_pais_gobierno",
        "ventas_pais_otras_empresas",
        "ventas_pais_publico_general"
      )
    ))
  }

  if (cuadro == 5L && anno %in% 1991:1996) {
    return(tibble(
      pos = 1:6,
      variable_original = c(
        "ventas_en_el_pais",
        "mayoristas",
        "minoristas",
        "gobierno",
        "otras_empresas",
        "publico_en_general"
      ),
      variable_canonica = c(
        "ventas_pais_total",
        "ventas_pais_mayorista",
        "ventas_pais_minorista",
        "ventas_pais_gobierno",
        "ventas_pais_otras_empresas",
        "ventas_pais_publico_general"
      )
    ))
  }

  if (cuadro == 5L && anno == 1997L) {
    return(tibble(
      pos = 1:7,
      variable_original = c(
        "total",
        "empresas_publicas",
        "gobiernos",
        "empresas_privadas_zonas_francas",
        "otras_empresas_privadas",
        "publico_general",
        "otros"
      ),
      variable_canonica = c(
        "ventas_pais_total",
        "ventas_pais_empresas_publicas",
        "ventas_pais_gobiernos",
        "ventas_pais_empresas_zonas_francas",
        "ventas_pais_otras_empresas_privadas",
        "ventas_pais_publico_general",
        "ventas_pais_otros"
      )
    ))
  }

  if (cuadro == 9L && anno <= 1990L) {
    return(tibble(
      pos = 1:7,
      variable_original = c(
        "total",
        "fueloil",
        "lenia",
        "gasoil",
        "nafta",
        "dieseloil",
        "resto"
      ),
      variable_canonica = c(
        "consumo_combustibles_total",
        "consumo_combustibles_fuel_oil",
        "consumo_combustibles_lenia",
        "consumo_combustibles_gas_oil",
        "consumo_combustibles_nafta",
        "consumo_combustibles_diesel_oil",
        "consumo_combustibles_resto"
      )
    ))
  }

  if (cuadro == 9L && anno %in% 1991:1996) {
    return(tibble(
      pos = 1:7,
      variable_original = c(
        "total_consumo_combustible",
        "diesel_oil",
        "fuel_oil",
        "nafta",
        "gas_oil",
        "lenia",
        "resto"
      ),
      variable_canonica = c(
        "consumo_combustibles_total",
        "consumo_combustibles_diesel_oil",
        "consumo_combustibles_fuel_oil",
        "consumo_combustibles_nafta",
        "consumo_combustibles_gas_oil",
        "consumo_combustibles_lenia",
        "consumo_combustibles_resto"
      )
    ))
  }

  if (cuadro == 9L && anno == 1997L) {
    return(tibble(
      pos = 1:3,
      variable_original = c("total", "en_plaza", "importadas"),
      variable_canonica = c(
        "compras_materias_primas_total",
        "compras_materias_primas_en_plaza",
        "compras_materias_primas_importadas"
      )
    ))
  }

  if (cuadro == 16L && anno <= 1996L) {
    return(tibble(
      pos = 1:7,
      variable_original = c(
        "impuestos_indirectos_netos",
        "total_impuestos_indirectos",
        "impuesto_sueldos",
        "iva_neto",
        "imesi",
        "otros_impuestos",
        "devolucion_impuestos"
      ),
      variable_canonica = c(
        "impuestos_netos",
        "impuestos_indirectos_total",
        "impuesto_sueldos",
        "iva_neto",
        "imesi",
        "otros_impuestos",
        "devolucion_impuestos"
      )
    ))
  }

  if (cuadro == 16L && anno == 1997L) {
    return(tibble(
      pos = 1:5,
      variable_original = c(
        "impuesto_sueldos",
        "devolucion_impuestos",
        "iva_neto",
        "imesi",
        "otros_impuestos"
      ),
      variable_canonica = c(
        "impuesto_sueldos",
        "devolucion_impuestos",
        "iva_neto",
        "imesi",
        "otros_impuestos"
      )
    ))
  }

  if (cuadro == 17L && anno <= 1996L) {
    return(tibble(
      pos = 1:7,
      variable_original = c(
        "iva_neto",
        "iva_sobre_ventas",
        "iva_compras_total",
        "iva_compras_deducibles",
        "iva_compras_no_deducibles",
        "iva_compras_plaza",
        "iva_compras_importado"
      ),
      variable_canonica = c(
        "iva_neto",
        "iva_sobre_ventas",
        "iva_compras_total",
        "iva_compras_deducibles",
        "iva_compras_no_deducibles",
        "iva_compras_plaza",
        "iva_compras_importado"
      )
    ))
  }

  if (cuadro == 17L && anno == 1997L) {
    return(tibble(
      pos = 1:7,
      variable_original = c(
        "formacion_bruta_capital_fijo",
        "adquisiciones_activo_fijo_total",
        "construccion_cuenta_propia",
        "adquisiciones_total",
        "adquisiciones_importadas",
        "adquisiciones_en_plaza",
        "disposiciones_activo_fijo"
      ),
      variable_canonica = c(
        "fbcf",
        "adquisiciones_activo_fijo_total",
        "construccion_cuenta_propia",
        "adquisiciones_total",
        "adquisiciones_importadas",
        "adquisiciones_en_plaza",
        "disposiciones_activo_fijo"
      )
    ))
  }

  if (cuadro == 19L && anno <= 1996L) {
    return(tibble(
      pos = 1:7,
      variable_original = c(
        "formacion_bruta_capital_fijo",
        "edificios_construcciones",
        "maquinas_y_equipos",
        "vehiculos_transporte",
        "muebles_enseres",
        "herramientas",
        "otros"
      ),
      variable_canonica = c(
        "fbcf",
        "fbkf_edificios_construcciones",
        "fbkf_maq_eq",
        "fbkf_vehiculos_transporte",
        "fbkf_muebles_enseres",
        "fbkf_herramientas",
        "fbkf_otros"
      )
    ))
  }

  if (cuadro == 19L && anno == 1997L) {
    return(tibble(
      pos = 1:7,
      variable_original = c(
        "total",
        "mercaderias_compradas_reventa",
        "materias_primas_materiales",
        "productos_en_proceso",
        "productos_terminados",
        "envases_embalajes",
        "repuestos_accesorios"
      ),
      variable_canonica = c(
        "variacion_existencias",
        "variacion_existencias_mercaderias_reventa",
        "variacion_existencias_materias_primas",
        "variacion_existencias_productos_en_proceso",
        "variacion_existencias_productos_terminados",
        "variacion_existencias_envases_embalajes",
        "variacion_existencias_repuestos_accesorios"
      )
    ))
  }

  stop("No hay mapa de variables para anno=", anno, " cuadro=", cuadro)
}

infer_scale <- function(anno, cuadro, titulo) {
  # DECISION: algunos cuadros de ventas/combustibles 1989-1990 no declaran
  # "miles" en el titulo, pero su escala solo queda consistente con los
  # macroagregados si se interpretan como miles de pesos corrientes.
  overrides <- tibble(
    anno = c(1989L, 1990L, 1990L),
    cuadro = c(5L, 5L, 9L),
    unidad_original = "miles_pesos_corrientes_inferido",
    multiplicador = 1000
  )

  hit <- overrides %>% filter(.data$anno == !!anno, .data$cuadro == !!cuadro)
  if (nrow(hit) == 1) {
    return(hit)
  }

  if (str_detect(str_to_upper(titulo), "MILES")) {
    tibble(
      anno = anno,
      cuadro = cuadro,
      unidad_original = "miles_pesos_corrientes",
      multiplicador = 1000
    )
  } else {
    tibble(
      anno = anno,
      cuadro = cuadro,
      unidad_original = "pesos_corrientes",
      multiplicador = 1
    )
  }
}

extract_sheet_data <- function(path, anno, sheet_info) {
  raw <- read_sheet_text(path, sheet_info$sheet)
  if (ncol(raw) == 0) {
    return(tibble())
  }

  raw <- raw %>% mutate(fila_excel = row_number())
  code_col <- raw$col_1
  data_rows <- raw %>% filter(is_code(.data$col_1))

  if (nrow(data_rows) == 0) {
    stop("No se detectaron filas de datos en ", basename(path), " hoja ", sheet_info$sheet)
  }

  first_row <- data_rows %>% slice(1)
  second_value <- if ("col_2" %in% names(first_row)) first_row$col_2 else NA_character_
  has_description <- !is.na(second_value) && is.na(as_number(second_value))
  variable_start_col <- if (has_description) 3L else 2L

  vars <- var_map(anno, sheet_info$cuadro) %>%
    mutate(col = variable_start_col + .data$pos - 1L)

  scale <- infer_scale(anno, sheet_info$cuadro, sheet_info$cuadro_titulo)

  map_dfr(seq_len(nrow(vars)), function(i) {
    col_name <- paste0("col_", vars$col[[i]])
    if (!col_name %in% names(data_rows)) {
      return(tibble())
    }

    data_rows %>%
      transmute(
        anno = anno,
        fuente = "Encuesta Industrial Anual 1989-1997",
        archivo = basename(path),
        sheet = sheet_info$sheet,
        cuadro = sheet_info$cuadro,
        cuadro_titulo = sheet_info$cuadro_titulo,
        ciiu_version = "Rev.2",
        seccion_homologada = "C",
        codigo_rama_original = str_trim(.data$col_1),
        nivel_codigo = str_length(.data$codigo_rama_original),
        nivel_agregacion = case_when(
          .data$codigo_rama_original == "3" ~ "industria_total",
          .data$nivel_codigo == 2L ~ "division_2_digitos",
          .data$nivel_codigo == 3L ~ "grupo_3_digitos",
          .data$nivel_codigo == 4L ~ "clase_4_digitos",
          .data$nivel_codigo == 5L ~ "subclase_5_digitos",
          TRUE ~ "otro"
        ),
        descripcion_original = if (has_description) .data$col_2 else NA_character_,
        variable_original = vars$variable_original[[i]],
        variable_canonica = vars$variable_canonica[[i]],
        valor_original = as_number(.data[[col_name]]),
        unidad_original = scale$unidad_original[[1]],
        multiplicador_pesos_corrientes = scale$multiplicador[[1]],
        valor_pesos_corrientes = .data$valor_original * .data$multiplicador_pesos_corrientes,
        fila_excel = .data$fila_excel
      ) %>%
      filter(!is.na(.data$valor_original))
  })
}

choose_panel_values <- function(tidy_data) {
  # DECISION: para el panel ancho se prefiere el cuadro mas detallado cuando
  # una misma variable canonica aparece duplicada en cuadros diferentes.
  priority <- tidy_data %>%
    mutate(
      prioridad_panel = case_when(
        .data$variable_canonica == "impuestos_netos" & .data$cuadro == 2L ~ 1L,
        .data$variable_canonica == "impuestos_netos" & .data$cuadro == 16L ~ 2L,
        .data$variable_canonica == "iva_neto" & .data$cuadro == 17L ~ 1L,
        .data$variable_canonica == "iva_neto" & .data$cuadro == 16L ~ 2L,
        .data$variable_canonica == "fbcf" & .data$cuadro == 19L ~ 1L,
        .data$variable_canonica == "fbcf" & .data$cuadro == 17L ~ 2L,
        TRUE ~ 1L
      )
    )

  chosen <- priority %>%
    arrange(
      .data$anno,
      .data$codigo_rama_original,
      .data$variable_canonica,
      .data$prioridad_panel,
      .data$cuadro
    ) %>%
    group_by(.data$anno, .data$codigo_rama_original, .data$variable_canonica) %>%
    slice(1) %>%
    ungroup()

  meta <- tidy_data %>%
    group_by(
      .data$anno,
      .data$seccion_homologada,
      .data$ciiu_version,
      .data$codigo_rama_original,
      .data$nivel_codigo,
      .data$nivel_agregacion
    ) %>%
    summarise(
      descripcion_rama = first(na.omit(.data$descripcion_original)),
      .groups = "drop"
    )

  desc_reference <- tidy_data %>%
    filter(!is.na(.data$descripcion_original), .data$descripcion_original != "") %>%
    group_by(.data$codigo_rama_original) %>%
    summarise(descripcion_referencia = first(.data$descripcion_original), .groups = "drop")

  panel_values <- chosen %>%
    select(anno, codigo_rama_original, variable_canonica, valor_pesos_corrientes) %>%
    pivot_wider(names_from = variable_canonica, values_from = valor_pesos_corrientes)

  meta %>%
    left_join(desc_reference, by = "codigo_rama_original") %>%
    mutate(descripcion_rama = coalesce(.data$descripcion_rama, .data$descripcion_referencia)) %>%
    select(-descripcion_referencia) %>%
    left_join(panel_values, by = c("anno", "codigo_rama_original")) %>%
    arrange(.data$anno, .data$codigo_rama_original)
}

build_validations <- function(tidy_data, panel, sheet_index) {
  coverage <- expand_grid(
    anno = sort(unique(sheet_index$anno)),
    cuadro = TARGET_CUADROS
  ) %>%
    left_join(
      sheet_index %>%
        count(.data$anno, .data$cuadro, name = "n_sheets"),
      by = c("anno", "cuadro")
    ) %>%
    mutate(
      n_sheets = replace_na(.data$n_sheets, 0L),
      validacion = "cobertura_cuadros",
      estado = if_else(.data$n_sheets == 1L, "ok", "revisar"),
      detalle = paste0("hojas_detectadas=", .data$n_sheets),
      codigo_rama_original = NA_character_,
      variable_canonica = NA_character_,
      diferencia_abs = NA_real_,
      diferencia_rel = NA_real_
    ) %>%
    select(
      validacion,
      estado,
      anno,
      cuadro,
      codigo_rama_original,
      variable_canonica,
      detalle,
      diferencia_abs,
      diferencia_rel
    )

  duplicate_checks <- tidy_data %>%
    group_by(.data$anno, .data$codigo_rama_original, .data$variable_canonica) %>%
    summarise(
      n_fuentes = n_distinct(.data$cuadro),
      min_valor = min(.data$valor_pesos_corrientes, na.rm = TRUE),
      max_valor = max(.data$valor_pesos_corrientes, na.rm = TRUE),
      cuadros = paste(sort(unique(.data$cuadro)), collapse = "+"),
      .groups = "drop"
    ) %>%
    filter(.data$n_fuentes > 1L) %>%
    mutate(
      validacion = "duplicados_variable_canonica",
      cuadro = NA_integer_,
      diferencia_abs = abs(.data$max_valor - .data$min_valor),
      diferencia_rel = if_else(
        .data$max_valor == 0,
        0,
        .data$diferencia_abs / abs(.data$max_valor)
      ),
      estado = if_else(.data$diferencia_abs <= 1000 | .data$diferencia_rel <= 1e-8, "ok", "revisar"),
      detalle = paste0("cuadros=", .data$cuadros, "; n_fuentes=", .data$n_fuentes)
    ) %>%
    select(
      validacion,
      estado,
      anno,
      cuadro,
      codigo_rama_original,
      variable_canonica,
      detalle,
      diferencia_abs,
      diferencia_rel
    )

  identidad_vbp <- panel %>%
    filter(
      !is.na(.data$vbp_corriente),
      !is.na(.data$consumo_intermedio),
      !is.na(.data$vab_corriente)
    ) %>%
    transmute(
      validacion = "vbp_igual_ci_mas_vab",
      estado = if_else(
        abs(.data$vbp_corriente - .data$consumo_intermedio - .data$vab_corriente) <= 1000,
        "ok",
        "revisar"
      ),
      anno = .data$anno,
      cuadro = 2L,
      codigo_rama_original = .data$codigo_rama_original,
      variable_canonica = NA_character_,
      detalle = "vbp_corriente - consumo_intermedio - vab_corriente",
      diferencia_abs = abs(.data$vbp_corriente - .data$consumo_intermedio - .data$vab_corriente),
      diferencia_rel = .data$diferencia_abs / pmax(abs(.data$vbp_corriente), 1)
    )

  identidad_vab <- panel %>%
    filter(
      !is.na(.data$vab_corriente),
      !is.na(.data$remuneraciones),
      !is.na(.data$impuestos_netos),
      !is.na(.data$consumo_capital_fijo),
      !is.na(.data$excedente_explotacion)
    ) %>%
    transmute(
      validacion = "vab_igual_componentes",
      estado = if_else(
        abs(
          .data$vab_corriente -
            .data$remuneraciones -
            .data$impuestos_netos -
            .data$consumo_capital_fijo -
            .data$excedente_explotacion
        ) <= 1000,
        "ok",
        "revisar"
      ),
      anno = .data$anno,
      cuadro = 2L,
      codigo_rama_original = .data$codigo_rama_original,
      variable_canonica = NA_character_,
      detalle = "vab_corriente - remuneraciones - impuestos_netos - consumo_capital_fijo - excedente_explotacion",
      diferencia_abs = abs(
        .data$vab_corriente -
          .data$remuneraciones -
          .data$impuestos_netos -
          .data$consumo_capital_fijo -
          .data$excedente_explotacion
      ),
      diferencia_rel = .data$diferencia_abs / pmax(abs(.data$vab_corriente), 1)
    )

  bind_rows(coverage, duplicate_checks, identidad_vbp, identidad_vab) %>%
    arrange(.data$validacion, .data$anno, .data$cuadro, .data$codigo_rama_original, .data$variable_canonica)
}

main <- function() {
  files <- tibble(path = sort(list.files(INPUT_DIR, pattern = "\\.xlsx?$", full.names = TRUE))) %>%
    mutate(anno = as.integer(str_extract(basename(.data$path), "\\d{4}"))) %>%
    filter(.data$anno %in% 1989:1997)

  if (nrow(files) != 9L) {
    stop("Se esperaban 9 archivos EIA 1989-1997 y se encontraron ", nrow(files))
  }

  sheet_index <- files %>%
    pmap_dfr(function(path, anno) detect_target_sheets(path, anno))

  expected <- expand_grid(anno = 1989:1997, cuadro = TARGET_CUADROS)
  missing <- expected %>%
    anti_join(sheet_index, by = c("anno", "cuadro"))
  duplicated_sheets <- sheet_index %>%
    count(.data$anno, .data$cuadro, name = "n") %>%
    filter(.data$n != 1L)

  if (nrow(missing) > 0 || nrow(duplicated_sheets) > 0) {
    print(missing)
    print(duplicated_sheets)
    stop("Fallo la deteccion unica de cuadros objetivo")
  }

  tidy_data <- sheet_index %>%
    left_join(files, by = "anno") %>%
    arrange(.data$anno, .data$cuadro) %>%
    pmap_dfr(function(anno, archivo, sheet, cuadro, cuadro_titulo, path) {
      extract_sheet_data(
        path = path,
        anno = anno,
        sheet_info = tibble(
          archivo = archivo,
          sheet = sheet,
          cuadro = cuadro,
          cuadro_titulo = cuadro_titulo
        )
      )
    }) %>%
    arrange(.data$anno, .data$cuadro, .data$codigo_rama_original, .data$variable_canonica)

  panel <- choose_panel_values(tidy_data)
  validations <- build_validations(tidy_data, panel, sheet_index)

  dir.create(dirname(OUTPUT_TIDY), recursive = TRUE, showWarnings = FALSE)
  write_csv(tidy_data, OUTPUT_TIDY, na = "")
  write_csv(panel, OUTPUT_PANEL, na = "")
  write_csv(validations, OUTPUT_VALIDACIONES, na = "")

  n_review <- validations %>% filter(.data$estado != "ok") %>% nrow()

  message("Escrito: ", OUTPUT_TIDY, " (", nrow(tidy_data), " filas)")
  message("Escrito: ", OUTPUT_PANEL, " (", nrow(panel), " filas)")
  message("Escrito: ", OUTPUT_VALIDACIONES, " (", nrow(validations), " filas; revisar=", n_review, ")")
}

main()
