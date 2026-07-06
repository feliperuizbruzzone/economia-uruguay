# Build a long-format results workbook from the integrated EAAE-BCU panel.
#
# Run from the project root:
#   Rscript command-files/analysis-command-files/04_build_resultados_eaae_bcu_workbook.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(tidyr)
})

analysis_dir <- file.path("data", "analysis-data")
input_panel_path <- file.path(
  analysis_dir,
  "20260706_panel_eeae_bcu_total_industria_subrama.csv"
)
output_workbook_path <- file.path(
  analysis_dir,
  "20260706_resultados_eaae_bcu_total_industria_subrama.xlsx"
)

safe_divide <- function(numerator, denominator) {
  result <- numerator / denominator
  result[is.na(numerator) | is.na(denominator) | denominator == 0] <- NA_real_
  result
}

prepare_eaae_sheet <- function(panel) {
  panel %>%
    mutate(
      seccion_fuente_panel = seccion,
      # DECISION: In the integrated source CSV, every industrial subbranch keeps
      # `seccion == "C"` and is identified by `grupo_rev4_homologado`. For the
      # workbook requested on 2026-07-06, `seccion` is the operational filter:
      # economy total, aggregate industry, or the harmonized Rev.4-compatible
      # group.
      seccion = case_when(
        nivel_panel == "industria_total" ~ "industria-total",
        nivel_panel == "subrama_industrial" ~ grupo_rev4_homologado,
        TRUE ~ seccion
      )
    ) %>%
    relocate(seccion_fuente_panel, .after = seccion)
}

build_quality_checks <- function(eaae) {
  eaae %>%
    transmute(
      anno,
      seccion,
      nivel_panel,
      grupo_rev4_homologado,
      descripcion_nivel,
      vab_vbp = safe_divide(vab_pp, vbp_pp),
      consumo_intermedio_estimado,
      consumo_intermedio = vbp_pp - vab_pp,
      remuneraciones_vab = safe_divide(remuneraciones, vab_pp),
      stock_vab = safe_divide(stock_capital_imputado, vab_pp),
      check_vbp_mayor_igual_vab = if_else(
        !is.na(vbp_pp) & !is.na(vab_pp),
        vbp_pp >= vab_pp,
        NA
      ),
      check_vab_mayor_igual_remuneraciones = if_else(
        !is.na(vab_pp) & !is.na(remuneraciones),
        vab_pp >= remuneraciones,
        NA
      ),
      check_puestos_trabajo_positivos = if_else(
        !is.na(puestos_trabajo),
        puestos_trabajo > 0,
        NA
      ),
      check_stock_operativo_disponible = !is.na(stock_capital_imputado)
    ) %>%
    arrange(seccion, anno)
}

add_context_totals <- function(eaae) {
  total_economia <- eaae %>%
    filter(nivel_panel == "economia_total") %>%
    transmute(anno, vab_total_economia = vab_pp)

  total_industria <- eaae %>%
    filter(nivel_panel == "industria_total") %>%
    transmute(anno, vab_total_industria = vab_pp)

  eaae %>%
    left_join(total_economia, by = "anno") %>%
    left_join(total_industria, by = "anno")
}

build_current_results <- function(eaae) {
  add_context_totals(eaae) %>%
    mutate(
      costo_laboral = remuneraciones,
      ganancia_pb = vab_pb_estimado - consumo_capital_fijo - costo_laboral,
      ganancia_pp = vab_pp - consumo_capital_fijo - costo_laboral,
      consumo_intermedio = vbp_pp - vab_pp,
      capital_variable_adelantado =
        remuneraciones / rotacion_calibrada_sobre_6_6,
      capital_circulante_constante_adelantado =
        consumo_intermedio_estimado / rotacion_calibrada_sobre_6_6,
      capital_circulante_adelantado =
        (costo_laboral + consumo_intermedio) / rotacion_calibrada_sobre_6_6,
      capital_total_adelantado =
        stock_capital_imputado + capital_circulante_adelantado,
      tasa_ganancia_pb = safe_divide(ganancia_pb, capital_total_adelantado),
      tasa_ganancia_pp = safe_divide(ganancia_pp, capital_total_adelantado),
      vab_eaae_bcu_pct = safe_divide(vab_pp, vab_bcu_corriente) * 100,
      vab_pp_participacion_total =
        safe_divide(vab_pp, vab_total_economia),
      vab_pp_participacion_industria = if_else(
        nivel_panel == "subrama_industrial",
        safe_divide(vab_pp, vab_total_industria),
        NA_real_
      ),
      part_salarial = safe_divide(remuneraciones, vab_pp)
    ) %>%
    select(
      anno,
      seccion,
      nivel_panel,
      grupo_rev4_homologado,
      descripcion_nivel,
      rotacion_calibrada_sobre_6_6,
      deflactor_2005,
      fuente_deflactor,
      fuente_base_bcu,
      calidad_deflactor_bcu,
      dato_preliminar_bcu,
      vbp_pp,
      vab_pp,
      vab_pb_estimado,
      vab_bcu_corriente,
      vab_eaae_bcu_pct,
      vab_total_economia,
      vab_total_industria,
      consumo_capital_fijo,
      remuneraciones,
      costo_laboral,
      stock_capital,
      stock_capital_imputado,
      fbcf,
      fbkf_maq_eq,
      adquisiciones_importadas,
      adquisiciones_origen_importado,
      importaciones_maquinaria,
      puestos_trabajo,
      consumo_intermedio_estimado,
      consumo_intermedio,
      capital_variable_adelantado,
      capital_circulante_constante_adelantado,
      capital_circulante_adelantado,
      capital_total_adelantado,
      ganancia_pb,
      ganancia_pp,
      tasa_ganancia_pb,
      tasa_ganancia_pp,
      vab_pp_participacion_total,
      vab_pp_participacion_industria,
      part_salarial
    ) %>%
    arrange(seccion, anno)
}

deflate_current_results <- function(current_results) {
  current_results %>%
    mutate(
      vbp_pp = safe_divide(vbp_pp, deflactor_2005),
      vab_pp = safe_divide(vab_pp, deflactor_2005),
      vab_pb_estimado = safe_divide(vab_pb_estimado, deflactor_2005),
      vab_bcu_constante_2005 = safe_divide(vab_bcu_corriente, deflactor_2005),
      vab_total_economia = safe_divide(vab_total_economia, deflactor_2005),
      vab_total_industria = safe_divide(vab_total_industria, deflactor_2005),
      consumo_capital_fijo =
        safe_divide(consumo_capital_fijo, deflactor_2005),
      remuneraciones = safe_divide(remuneraciones, deflactor_2005),
      costo_laboral = safe_divide(costo_laboral, deflactor_2005),
      stock_capital = safe_divide(stock_capital, deflactor_2005),
      stock_capital_imputado =
        safe_divide(stock_capital_imputado, deflactor_2005),
      fbcf = safe_divide(fbcf, deflactor_2005),
      fbkf_maq_eq = safe_divide(fbkf_maq_eq, deflactor_2005),
      adquisiciones_importadas =
        safe_divide(adquisiciones_importadas, deflactor_2005),
      adquisiciones_origen_importado =
        safe_divide(adquisiciones_origen_importado, deflactor_2005),
      importaciones_maquinaria =
        safe_divide(importaciones_maquinaria, deflactor_2005),
      consumo_intermedio_estimado =
        safe_divide(consumo_intermedio_estimado, deflactor_2005),
      consumo_intermedio = vbp_pp - vab_pp,
      capital_variable_adelantado =
        remuneraciones / rotacion_calibrada_sobre_6_6,
      capital_circulante_constante_adelantado =
        consumo_intermedio_estimado / rotacion_calibrada_sobre_6_6,
      capital_circulante_adelantado =
        (costo_laboral + consumo_intermedio) / rotacion_calibrada_sobre_6_6,
      capital_total_adelantado =
        stock_capital_imputado + capital_circulante_adelantado,
      ganancia_pb = vab_pb_estimado - consumo_capital_fijo - costo_laboral,
      ganancia_pp = vab_pp - consumo_capital_fijo - costo_laboral,
      tasa_ganancia_pb = safe_divide(ganancia_pb, capital_total_adelantado),
      tasa_ganancia_pp = safe_divide(ganancia_pp, capital_total_adelantado),
      vab_eaae_bcu_pct = safe_divide(vab_pp, vab_bcu_constante_2005) * 100,
      vab_pp_participacion_total =
        safe_divide(vab_pp, vab_total_economia),
      vab_pp_participacion_industria = if_else(
        nivel_panel == "subrama_industrial",
        safe_divide(vab_pp, vab_total_industria),
        NA_real_
      ),
      productividad_trabajo = safe_divide(vab_pp, puestos_trabajo)
    ) %>%
    select(
      anno,
      seccion,
      nivel_panel,
      grupo_rev4_homologado,
      descripcion_nivel,
      rotacion_calibrada_sobre_6_6,
      deflactor_2005,
      fuente_deflactor,
      fuente_base_bcu,
      calidad_deflactor_bcu,
      dato_preliminar_bcu,
      vbp_pp,
      vab_pp,
      vab_pb_estimado,
      vab_bcu_constante_2005,
      vab_eaae_bcu_pct,
      vab_total_economia,
      vab_total_industria,
      consumo_capital_fijo,
      remuneraciones,
      costo_laboral,
      stock_capital,
      stock_capital_imputado,
      fbcf,
      fbkf_maq_eq,
      adquisiciones_importadas,
      adquisiciones_origen_importado,
      importaciones_maquinaria,
      puestos_trabajo,
      consumo_intermedio_estimado,
      consumo_intermedio,
      capital_variable_adelantado,
      capital_circulante_constante_adelantado,
      capital_circulante_adelantado,
      capital_total_adelantado,
      ganancia_pb,
      ganancia_pp,
      tasa_ganancia_pb,
      tasa_ganancia_pp,
      vab_pp_participacion_total,
      vab_pp_participacion_industria,
      part_salarial,
      productividad_trabajo
    ) %>%
    arrange(seccion, anno)
}

build_yearly_variations <- function(constant_results) {
  id_cols <- c(
    "anno",
    "seccion",
    "nivel_panel",
    "grupo_rev4_homologado",
    "descripcion_nivel"
  )
  exclude_cols <- c(
    id_cols,
    "rotacion_calibrada_sobre_6_6",
    "deflactor_2005",
    "fuente_deflactor",
    "fuente_base_bcu",
    "calidad_deflactor_bcu",
    "dato_preliminar_bcu"
  )
  transform_cols <- setdiff(names(constant_results), exclude_cols)

  constant_results %>%
    arrange(seccion, anno) %>%
    group_by(seccion) %>%
    mutate(
      across(
        all_of(transform_cols),
        ~ (safe_divide(.x, lag(.x)) - 1) * 100,
        .names = "{.col}_var_pct"
      )
    ) %>%
    ungroup() %>%
    select(all_of(id_cols), ends_with("_var_pct"))
}

build_indices_2005 <- function(variation_results, base_year = 2005) {
  id_cols <- c(
    "anno",
    "seccion",
    "nivel_panel",
    "grupo_rev4_homologado",
    "descripcion_nivel"
  )
  variation_cols <- setdiff(names(variation_results), id_cols)
  pieces <- split(variation_results, variation_results$seccion)

  indexed <- lapply(pieces, function(group_data) {
    group_data <- group_data %>% arrange(anno)
    base_position <- which(group_data$anno == base_year)
    if (length(base_position) != 1) {
      stop(
        "No se encontro exactamente un ano base ",
        base_year,
        " para seccion ",
        unique(group_data$seccion)
      )
    }

    index_data <- group_data %>% select(all_of(id_cols))
    for (variation_col in variation_cols) {
      index_values <- rep(NA_real_, nrow(group_data))
      index_values[base_position] <- 1

      if (base_position < nrow(group_data)) {
        for (row_index in seq(base_position + 1, nrow(group_data))) {
          growth <- group_data[[variation_col]][[row_index]]
          previous_index <- index_values[[row_index - 1]]
          if (!is.na(growth) && !is.na(previous_index)) {
            index_values[[row_index]] <- previous_index * (1 + growth / 100)
          }
        }
      }

      if (base_position > 1) {
        for (row_index in seq(base_position - 1, 1)) {
          next_growth <- group_data[[variation_col]][[row_index + 1]]
          next_index <- index_values[[row_index + 1]]
          denominator <- 1 + next_growth / 100
          if (!is.na(next_growth) && !is.na(next_index) && denominator != 0) {
            index_values[[row_index]] <- next_index / denominator
          }
        }
      }

      index_col <- sub("_var_pct$", "_ind_2005", variation_col)
      index_data[[index_col]] <- index_values
    }
    index_data
  })

  bind_rows(indexed) %>% arrange(seccion, anno)
}

build_methodology_sheet <- function(eaae, results_cols, constant_cols, var_cols, index_cols) {
  sheet_rows <- tibble::tribble(
    ~seccion_contenido, ~nombre, ~tipo, ~aplica_en, ~definicion, ~fuente_formula,
    "estructura_libro", "metodología", "hoja", "Libro completo", "Describe cada hoja y contiene el diccionario de variables.", "Construida por este script.",
    "estructura_libro", "eaae", "hoja", "Panel base", "Panel integrado EAAE-BCU completo: economía total, industria agregada y subramas industriales en formato largo.", "data/analysis-data/20260706_panel_eeae_bcu_total_industria_subrama.csv.",
    "estructura_libro", "check-calidad", "hoja", "Validación", "Controles tipo libro EAAE 20260605 para cada año y sección operativa.", "vab/vbp, remuneraciones/vab, stock/vab y banderas de consistencia.",
    "estructura_libro", "resultados-corrientes", "hoja", "Resultados", "Insumos y cálculos propios en valores corrientes para todos los niveles.", "Cálculos desde la hoja eaae.",
    "estructura_libro", "resultados-constantes", "hoja", "Resultados", "Resultados corrientes expresados en precios constantes de 2005.", "Deflactación con deflactor BCU empalmado base 2005.",
    "estructura_libro", "resultados-var-pct", "hoja", "Resultados", "Variación porcentual interanual de los resultados constantes.", "(x[t] / x[t-1] - 1) * 100 por seccion.",
    "estructura_libro", "resultados-ind-2005", "hoja", "Resultados", "Índices encadenados con base 2005=1.", "Encadenamiento por seccion desde las variaciones interanuales.",
    "diccionario_variables", "anno", "identificador", "Todas las hojas", "Año de referencia.", "EAAE/BCU.",
    "diccionario_variables", "seccion", "identificador", "Todas las hojas", "Filtro operativo del libro: economia_total, industria-total o grupo industrial homologado Rev.4 compatible.", "Para industria agregada se usa industria-total; para subramas se toma grupo_rev4_homologado.",
    "diccionario_variables", "nivel_panel", "identificador", "Todas las hojas", "Nivel analítico: economia_total, industria_total o subrama_industrial.", "Panel integrado.",
    "diccionario_variables", "grupo_rev4_homologado", "identificador", "Todas las hojas", "Grupo industrial homologado Rev.4 compatible para subramas.", "Codiguera de homologación EAAE.",
    "diccionario_variables", "descripcion_nivel", "identificador", "Todas las hojas", "Etiqueta legible del nivel o subrama.", "Panel integrado.",
    "diccionario_variables", "seccion_fuente_panel", "trazabilidad", "eaae", "Sección tal como viene en el CSV integrado antes de crear el filtro operativo del libro.", "En subramas conserva C.",
    "diccionario_variables", "rotacion_calibrada_sobre_6_6", "parámetro", "eaae y resultados", "Rotación operativa usada para capital adelantado y tasas de ganancia.", "Archivo Damodaran/EAAE, hoja Resumen; constante por nivel/subrama.",
    "diccionario_variables", "deflactor_2005", "deflactor", "eaae y resultados", "Deflactor BCU empalmado base 2005=1.", "Índice implícito de VAB BCU compatible por nivel/subrama.",
    "diccionario_variables", "vbp_pp", "original_transformada", "Resultados", "Valor bruto de producción a precios productor.", "EAAE; en constantes se divide por deflactor_2005.",
    "diccionario_variables", "vab_pp", "original_transformada", "Resultados", "Valor agregado bruto a precios productor.", "EAAE; en constantes se divide por deflactor_2005.",
    "diccionario_variables", "vab_pb_estimado", "calculada_panel", "Resultados", "VAB a precios básicos completo: observado desde 2017 y retroproyectado antes de 2017.", "Panel integrado.",
    "diccionario_variables", "vab_bcu_corriente", "auxiliar_externa", "resultados-corrientes", "VAB corriente BCU compatible con el nivel o subrama.", "BCU, incluye datos disponibles preliminares.",
    "diccionario_variables", "vab_bcu_constante_2005", "auxiliar_externa", "resultados-constantes", "VAB BCU en precios de 2005 construido con el deflactor empalmado.", "vab_bcu_corriente / deflactor_2005.",
    "diccionario_variables", "vab_eaae_bcu_pct", "validación_externa", "Resultados", "Comparación EAAE/BCU del VAB.", "vab_pp / vab_bcu * 100 en la escala de cada hoja.",
    "diccionario_variables", "consumo_capital_fijo", "original_transformada", "Resultados", "Consumo de capital fijo.", "EAAE; en constantes se divide por deflactor_2005.",
    "diccionario_variables", "remuneraciones", "original_transformada", "Resultados", "Remuneraciones totales, incluyendo aportes patronales según validación del equipo.", "EAAE; en constantes se divide por deflactor_2005.",
    "diccionario_variables", "costo_laboral", "calculada_resultados", "Resultados", "Costo laboral operativo.", "Igual a remuneraciones.",
    "diccionario_variables", "stock_capital", "original_transformada", "Resultados", "Stock de capital fijo original cuando la fuente lo publica.", "EAAE; en constantes se divide por deflactor_2005.",
    "diccionario_variables", "stock_capital_imputado", "calculada_panel", "Resultados", "Stock operativo: original cuando existe e imputado sólo cuando la regla aprobada lo permite.", "Panel integrado.",
    "diccionario_variables", "fbcf", "original_transformada", "Resultados", "Formación bruta de capital fijo.", "EAAE; en constantes se divide por deflactor_2005.",
    "diccionario_variables", "fbkf_maq_eq", "original_transformada", "Resultados", "FBKF en maquinaria y equipos.", "EAAE; en constantes se divide por deflactor_2005.",
    "diccionario_variables", "importaciones_maquinaria", "calculada_panel", "Resultados", "Adquisiciones importadas más adquisiciones en plaza de origen importado.", "Panel integrado.",
    "diccionario_variables", "puestos_trabajo", "original", "Resultados", "Puestos de trabajo u ocupados.", "EAAE; se mantiene como cantidad.",
    "diccionario_variables", "ganancia_pb", "calculada_resultados", "Resultados", "Ganancia a precios básicos.", "vab_pb_estimado - consumo_capital_fijo - costo_laboral.",
    "diccionario_variables", "ganancia_pp", "calculada_resultados", "Resultados", "Ganancia a precios productor.", "vab_pp - consumo_capital_fijo - costo_laboral.",
    "diccionario_variables", "consumo_intermedio", "calculada_resultados", "Resultados", "Consumo intermedio usado en resultados propios.", "vbp_pp - vab_pp.",
    "diccionario_variables", "capital_variable_adelantado", "calculada_resultados", "Resultados", "Capital variable adelantado.", "remuneraciones / rotacion_calibrada_sobre_6_6.",
    "diccionario_variables", "capital_circulante_constante_adelantado", "calculada_resultados", "Resultados", "Capital circulante constante adelantado.", "consumo_intermedio_estimado / rotacion_calibrada_sobre_6_6.",
    "diccionario_variables", "capital_circulante_adelantado", "calculada_resultados", "Resultados", "Capital circulante adelantado usado en tasa de ganancia.", "(costo_laboral + consumo_intermedio) / rotacion_calibrada_sobre_6_6.",
    "diccionario_variables", "capital_total_adelantado", "calculada_resultados", "Resultados", "Capital total adelantado.", "stock_capital_imputado + capital_circulante_adelantado.",
    "diccionario_variables", "tasa_ganancia_pb", "calculada_resultados", "Resultados", "Tasa de ganancia a precios básicos.", "ganancia_pb / capital_total_adelantado.",
    "diccionario_variables", "tasa_ganancia_pp", "calculada_resultados", "Resultados", "Tasa de ganancia a precios productor.", "ganancia_pp / capital_total_adelantado.",
    "diccionario_variables", "productividad_trabajo", "calculada_resultados", "resultados-constantes y derivados", "Productividad del trabajo en precios constantes.", "vab_pp constante / puestos_trabajo.",
    "diccionario_variables", "vab_pp_participacion_total", "calculada_resultados", "Resultados", "Participación del VAB de la sección en la economía total.", "vab_pp / vab_total_economia.",
    "diccionario_variables", "vab_pp_participacion_industria", "calculada_resultados", "Resultados", "Participación del VAB de cada subrama en la industria manufacturera.", "vab_pp / vab_total_industria para subramas.",
    "diccionario_variables", "*_var_pct", "transformación", "resultados-var-pct", "Sufijo de variables expresadas como variación interanual porcentual.", "Derivado de resultados-constantes.",
    "diccionario_variables", "*_ind_2005", "transformación", "resultados-ind-2005", "Sufijo de variables expresadas como índice con base 2005=1.", "Encadenamiento desde resultados-var-pct."
  )

  source_columns <- tibble(
    seccion_contenido = "columnas_fuente_eaae",
    nombre = names(eaae),
    tipo = "columna",
    aplica_en = "eaae",
    definicion = "Columna preservada desde el panel integrado o creada como filtro operativo del libro.",
    fuente_formula = "20260706_panel_eeae_bcu_total_industria_subrama.csv"
  )
  result_columns <- tibble(
    seccion_contenido = "columnas_resultados",
    nombre = unique(c(results_cols, constant_cols, var_cols, index_cols)),
    tipo = "columna",
    aplica_en = "Hojas resultados",
    definicion = "Columna disponible en las hojas de resultados del libro.",
    fuente_formula = "Ver diccionario canónico de variables calculadas."
  )

  bind_rows(sheet_rows, source_columns, result_columns) %>%
    distinct(seccion_contenido, nombre, aplica_en, .keep_all = TRUE)
}

xml_escape <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}

column_letter <- function(index) {
  letters <- character()
  while (index > 0) {
    index <- index - 1
    letters <- c(LETTERS[(index %% 26) + 1], letters)
    index <- index %/% 26
  }
  paste0(letters, collapse = "")
}

cell_reference <- function(row_index, column_index) {
  paste0(column_letter(column_index), row_index)
}

format_number <- function(value) {
  if (!is.finite(value)) {
    return("")
  }
  format(value, digits = 15, scientific = FALSE, trim = TRUE)
}

write_cell_xml <- function(row_index, column_index, value) {
  reference <- cell_reference(row_index, column_index)
  if (length(value) == 0 || is.na(value)) {
    return(sprintf(
      '<c r="%s" t="inlineStr"><is><t></t></is></c>',
      reference
    ))
  }
  if (is.numeric(value)) {
    formatted <- format_number(value)
    if (formatted == "") {
      return(sprintf(
        '<c r="%s" t="inlineStr"><is><t></t></is></c>',
        reference
      ))
    }
    return(sprintf('<c r="%s"><v>%s</v></c>', reference, formatted))
  }
  sprintf(
    '<c r="%s" t="inlineStr"><is><t>%s</t></is></c>',
    reference,
    xml_escape(value)
  )
}

worksheet_xml <- function(sheet_data) {
  sheet_data <- as.data.frame(sheet_data, stringsAsFactors = FALSE)
  rows <- vector("list", nrow(sheet_data) + 1)
  header <- names(sheet_data)

  header_cells <- vapply(
    seq_along(header),
    function(column_index) write_cell_xml(1, column_index, header[[column_index]]),
    character(1)
  )
  rows[[1]] <- sprintf('<row r="1">%s</row>', paste0(header_cells, collapse = ""))

  if (nrow(sheet_data) > 0) {
    for (data_row_index in seq_len(nrow(sheet_data))) {
      row_index <- data_row_index + 1
      cells <- vapply(
        seq_along(sheet_data),
        function(column_index) {
          write_cell_xml(
            row_index,
            column_index,
            sheet_data[[column_index]][[data_row_index]]
          )
        },
        character(1)
      )
      rows[[row_index]] <- sprintf(
        '<row r="%s">%s</row>',
        row_index,
        paste0(cells, collapse = "")
      )
    }
  }

  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ',
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
    '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" ',
    'topLeftCell="A2" activePane="bottomLeft" state="frozen"/>',
    '<selection pane="bottomLeft"/></sheetView></sheetViews>',
    "<sheetData>",
    paste0(rows, collapse = ""),
    "</sheetData></worksheet>"
  )
}

workbook_xml <- function(sheet_names) {
  sheets <- vapply(
    seq_along(sheet_names),
    function(i) {
      sprintf(
        '<sheet name="%s" sheetId="%s" r:id="rId%s"/>',
        xml_escape(sheet_names[[i]]),
        i,
        i
      )
    },
    character(1)
  )
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ',
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
    "<sheets>",
    paste0(sheets, collapse = ""),
    "</sheets></workbook>"
  )
}

workbook_rels_xml <- function(sheet_names) {
  relationships <- vapply(
    seq_along(sheet_names),
    function(i) {
      sprintf(
        '<Relationship Id="rId%s" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet%s.xml"/>',
        i,
        i
      )
    },
    character(1)
  )
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    paste0(relationships, collapse = ""),
    sprintf(
      '<Relationship Id="rId%s" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>',
      length(sheet_names) + 1
    ),
    "</Relationships>"
  )
}

content_types_xml <- function(sheet_count) {
  sheets <- vapply(
    seq_len(sheet_count),
    function(i) {
      sprintf(
        '<Override PartName="/xl/worksheets/sheet%s.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
        i
      )
    },
    character(1)
  )
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
    '<Default Extension="xml" ContentType="application/xml"/>',
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>',
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>',
    '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>',
    paste0(sheets, collapse = ""),
    "</Types>"
  )
}

root_rels_xml <- function() {
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>',
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>',
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>',
    "</Relationships>"
  )
}

styles_xml <- function() {
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>',
    '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>',
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>',
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>',
    '<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>',
    "</styleSheet>"
  )
}

app_xml <- function(sheet_names) {
  titles <- paste0("<vt:lpstr>", xml_escape(sheet_names), "</vt:lpstr>", collapse = "")
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" ',
    'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">',
    "<Application>R</Application>",
    '<HeadingPairs><vt:vector size="2" baseType="variant">',
    "<vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant>",
    sprintf("<vt:variant><vt:i4>%s</vt:i4></vt:variant>", length(sheet_names)),
    "</vt:vector></HeadingPairs>",
    sprintf(
      '<TitlesOfParts><vt:vector size="%s" baseType="lpstr">%s</vt:vector></TitlesOfParts>',
      length(sheet_names),
      titles
    ),
    "</Properties>"
  )
}

core_xml <- function() {
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" ',
    'xmlns:dc="http://purl.org/dc/elements/1.1/" ',
    'xmlns:dcterms="http://purl.org/dc/terms/" ',
    'xmlns:dcmitype="http://purl.org/dc/dcmitype/" ',
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">',
    "<dc:title>Resultados EAAE-BCU total industria subrama</dc:title>",
    "<dc:creator>economia-uruguay R analysis script</dc:creator>",
    "</cp:coreProperties>"
  )
}

write_xlsx_workbook <- function(path, sheets) {
  if (Sys.which("zip") == "") {
    stop("No se encontro el comando del sistema `zip`, necesario para escribir XLSX.")
  }

  sheet_names <- names(sheets)
  output_path <- file.path(normalizePath(dirname(path)), basename(path))
  tmpdir <- tempfile("eaae-bcu-xlsx-")
  dir.create(file.path(tmpdir, "_rels"), recursive = TRUE)
  dir.create(file.path(tmpdir, "docProps"), recursive = TRUE)
  dir.create(file.path(tmpdir, "xl", "_rels"), recursive = TRUE)
  dir.create(file.path(tmpdir, "xl", "worksheets"), recursive = TRUE)
  on.exit(unlink(tmpdir, recursive = TRUE), add = TRUE)

  writeLines(content_types_xml(length(sheet_names)), file.path(tmpdir, "[Content_Types].xml"))
  writeLines(root_rels_xml(), file.path(tmpdir, "_rels", ".rels"))
  writeLines(core_xml(), file.path(tmpdir, "docProps", "core.xml"))
  writeLines(app_xml(sheet_names), file.path(tmpdir, "docProps", "app.xml"))
  writeLines(workbook_xml(sheet_names), file.path(tmpdir, "xl", "workbook.xml"))
  writeLines(workbook_rels_xml(sheet_names), file.path(tmpdir, "xl", "_rels", "workbook.xml.rels"))
  writeLines(styles_xml(), file.path(tmpdir, "xl", "styles.xml"))

  for (i in seq_along(sheets)) {
    writeLines(
      worksheet_xml(sheets[[i]]),
      file.path(tmpdir, "xl", "worksheets", paste0("sheet", i, ".xml"))
    )
  }

  oldwd <- setwd(tmpdir)
  on.exit(setwd(oldwd), add = TRUE)
  if (file.exists(output_path)) {
    file.remove(output_path)
  }
  files <- list.files(".", all.files = TRUE, recursive = TRUE, no.. = TRUE)
  utils::zip(zipfile = output_path, files = files, flags = "-r9Xq")
}

validate_workbook_inputs <- function(eaae, current_results, constant_results) {
  if (nrow(eaae) != 288) {
    stop("La hoja eaae debe tener 288 filas.")
  }
  if (anyDuplicated(eaae[c("anno", "seccion")]) > 0) {
    stop("La clave anno + seccion no es unica en la hoja eaae.")
  }
  if ("rotacion" %in% names(eaae)) {
    stop("La hoja eaae no debe incluir la columna generica rotacion.")
  }
  if (any(is.na(eaae$rotacion_calibrada_sobre_6_6))) {
    stop("Hay filas sin rotacion_calibrada_sobre_6_6.")
  }
  if (any(is.na(eaae$deflactor_2005))) {
    stop("Hay filas sin deflactor_2005.")
  }
  if (nrow(current_results) != 288 || nrow(constant_results) != 288) {
    stop("Las hojas de resultados deben tener 288 filas.")
  }
}

main <- function() {
  source_panel <- readr::read_csv(input_panel_path, show_col_types = FALSE)
  eaae <- prepare_eaae_sheet(source_panel)
  check_calidad <- build_quality_checks(eaae)
  resultados_corrientes <- build_current_results(eaae)
  resultados_constantes <- deflate_current_results(resultados_corrientes)
  resultados_var_pct <- build_yearly_variations(resultados_constantes)
  resultados_ind_2005 <- build_indices_2005(resultados_var_pct)
  metodologia <- build_methodology_sheet(
    eaae,
    names(resultados_corrientes),
    names(resultados_constantes),
    names(resultados_var_pct),
    names(resultados_ind_2005)
  )

  validate_workbook_inputs(eaae, resultados_corrientes, resultados_constantes)

  sheets <- list(
    "metodología" = metodologia,
    "eaae" = eaae,
    "check-calidad" = check_calidad,
    "resultados-corrientes" = resultados_corrientes,
    "resultados-constantes" = resultados_constantes,
    "resultados-var-pct" = resultados_var_pct,
    "resultados-ind-2005" = resultados_ind_2005
  )
  write_xlsx_workbook(output_workbook_path, sheets)

  message("Escrito: ", output_workbook_path)
  for (sheet_name in names(sheets)) {
    message(" - ", sheet_name, ": ", nrow(sheets[[sheet_name]]), " filas x ", ncol(sheets[[sheet_name]]), " columnas")
  }
}

main()
