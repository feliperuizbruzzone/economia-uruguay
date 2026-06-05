# Add team-defined own calculations to the dated EAAE workbook.
#
# Run from the project root:
#   Rscript command-files/analysis-command-files/02_add_calculos_propios_eaae.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(readxl)
  library(tibble)
})

analysis_dir <- file.path("data", "analysis-data")
methodology_sheet <- "metodología"
industrial_sheet <- "resultados-industrial-corrientes"
total_sheet <- "resultados-total-corrientes"
industrial_constant_sheet <- "resultados-industrial-constante"
total_constant_sheet <- "resultados-total-constante"
industrial_variation_sheet <- "resultados-industrial-var-pct"
total_variation_sheet <- "resultados-total-var-pct"
industrial_index_sheet <- "resultados-industrial-ind-2005"
total_index_sheet <- "resultados-total-ind-2005"
legacy_result_sheets <- c(
  "calculos-propios-industrial",
  "calculos-propios-total"
)
rotacion_industria <- 6.6
rotacion_economia_total <- 4.2

latest_analysis_file <- function(pattern) {
  paths <- list.files(
    analysis_dir,
    pattern = pattern,
    full.names = TRUE
  )
  if (length(paths) == 0) {
    stop("No se encontro ningun archivo en ", analysis_dir, " con patron ", pattern)
  }
  sort(paths, decreasing = TRUE)[1]
}

panel_csv_path <- latest_analysis_file("^[0-9]{8}_panel_eaae\\.csv$")
panel_xlsx_path <- latest_analysis_file("^[0-9]{8}_panel_eaae\\.xlsx$")
price_index_path <- file.path(analysis_dir, "oyanthabal_indices_precios.csv")
bcu_current_vab_path <- file.path(
  analysis_dir,
  "bcu_pib_corriente_industrias_2005_2019.csv"
)

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

numeric_panel_cols <- c(
  "vbp_pp",
  "vbp_pb",
  "vab_pp",
  "vab_pb",
  "vab_pb_estimado",
  "consumo_intermedio_estimado",
  "capital_circulante_constante_adelantado",
  "remuneraciones",
  "capital_variable_adelantado",
  "puestos_trabajo",
  "n_empresas",
  "fbcf",
  "fbkf_maq_eq",
  "adquisiciones_importadas",
  "adquisiciones_origen_importado",
  "importaciones_maquinaria",
  "consumo_capital_fijo",
  "impuestos_netos",
  "stock_capital",
  "stock_capital_imputado",
  "capital_total_adelantado",
  "excedente_bruto",
  "part_salarial",
  "productividad"
)

result_transform_exclude_cols <- c(
  "anno",
  "ambito",
  "seccion",
  "rotacion",
  "gdp_price_index_base_2005",
  "ipc_index_2005"
)

panel <- readr::read_csv(panel_csv_path, show_col_types = FALSE) %>%
  mutate(
    anno = as.integer(anno),
    across(any_of(numeric_panel_cols), as.numeric)
  )

price_indexes_long <- readr::read_csv(price_index_path, show_col_types = FALSE) %>%
  transmute(
    anno = as.integer(anno),
    variable,
    valor = as.numeric(valor)
  )

gdp_price_indexes <- price_indexes_long %>%
  filter(variable == "gdp_price_index_base_2005") %>%
  transmute(
    anno,
    gdp_price_index_base_2005 = valor
  )

ipc_price_indexes <- price_indexes_long %>%
  filter(variable == "ipc_index_2005") %>%
  transmute(
    anno,
    ipc_index_2005 = valor
  )

price_indexes <- full_join(
  gdp_price_indexes,
  ipc_price_indexes,
  by = "anno"
)

bcu_current_vab <- readr::read_csv(
  bcu_current_vab_path,
  show_col_types = FALSE
) %>%
  mutate(
    anno = as.integer(anno),
    valor = as.numeric(valor),
    dato_preliminar = as.logical(dato_preliminar)
  )

bcu_vab_total <- bcu_current_vab %>%
  filter(
    is.na(codigo_normalizado),
    descripcion == "VALOR AGREGADO BRUTO DE LOS SECTORES DE ACTIVIDAD",
    !is.na(valor)
  ) %>%
  transmute(
    anno,
    vab_bcu_corriente = valor * 1000
  )

bcu_vab_industrial <- bcu_current_vab %>%
  filter(
    codigo_normalizado == "D",
    descripcion == "INDUSTRIAS MANUFACTURERAS",
    !is.na(valor)
  ) %>%
  transmute(
    anno,
    vab_bcu_corriente = valor * 1000
  )

economia_total <- readxl::read_excel(
  panel_xlsx_path,
  sheet = "economia_total",
  .name_repair = "minimal"
) %>%
  mutate(
    anno = as.integer(anno),
    across(any_of(numeric_panel_cols), as.numeric)
  )

vab_total <- economia_total %>%
  transmute(
    anno,
    vab_pp_total = vab_pp
  )

build_resultados_niveles <- function(
    data,
    ambito,
    total_vab,
    rotacion_valor,
    include_total_context = FALSE,
    include_price_indexes = FALSE,
    include_productividad = FALSE,
    bcu_vab = NULL) {
  identifier_cols <- c("anno", "ambito", "seccion", "rotacion")
  price_index_cols <- if (include_price_indexes) {
    c("gdp_price_index_base_2005", "ipc_index_2005")
  } else {
    character()
  }
  bcu_cols <- if (!is.null(bcu_vab)) {
    c("vab_bcu_corriente", "vab_eaae_bcu_pct")
  } else {
    character()
  }
  input_cols <- c(
    "vbp_pp",
    "vab_pp",
    if (include_total_context) "vab_pp_total",
    "vab_pb_estimado",
    bcu_cols,
    "consumo_capital_fijo",
    "costo_laboral",
    "stock_capital",
    "stock_capital_imputado",
    "fbcf",
    "fbkf_maq_eq",
    "adquisiciones_importadas",
    "adquisiciones_origen_importado",
    "importaciones_maquinaria",
    "puestos_trabajo"
  )
  calculated_cols <- c(
    "ganancia_pb",
    "ganancia_pp",
    "consumo_intermedio",
    "capital_circulante_adelantado",
    "capital_total_adelantado",
    "tasa_ganancia_pb",
    "tasa_ganancia_pp",
    if (include_total_context) "vab_pp_participacion_total",
    if (include_productividad) "productividad_trabajo"
  )
  output_cols <- c(
    identifier_cols,
    price_index_cols,
    input_cols,
    calculated_cols
  )

  result <- data %>%
    arrange(anno) %>%
    left_join(total_vab, by = "anno")
  if (!is.null(bcu_vab)) {
    result <- result %>%
      left_join(bcu_vab, by = "anno")
  } else {
    result <- result %>%
      mutate(
        vab_bcu_corriente = NA_real_
      )
  }

  result %>%
    mutate(
      ambito = ambito,
      rotacion = rotacion_valor,
      # DECISION: `remuneraciones` already includes employer contributions in
      # C1/C1.1, so `costo_laboral` uses that total directly. The source does
      # not expose `cargas_patronales` as a separate panel variable. To keep
      # result sheets readable, only `costo_laboral` is exposed.
      costo_laboral = remuneraciones,
      ganancia_pb = vab_pb_estimado - consumo_capital_fijo - costo_laboral,
      ganancia_pp = vab_pp - consumo_capital_fijo - costo_laboral,
      # DECISION: The requested identity is VBP - VAB_bruto. In the current
      # panel, the complete observed VBP/VAB pair is at producer prices.
      consumo_intermedio = vbp_pp - vab_pp,
      # DECISION: The BCU source is in thousands of current pesos, converted
      # above to current pesos. Preliminary BCU years are integrated in the same
      # `vab_bcu_corriente` column to keep result sheets simple. The comparison
      # uses `vab_pp` because it is the observed EAAE VAB series available
      # throughout the current-price panel.
      vab_eaae_bcu_pct = safe_divide(vab_pp, vab_bcu_corriente) * 100,
      capital_circulante_adelantado = (
        costo_laboral + consumo_intermedio
      ) / rotacion,
      capital_total_adelantado = (
        stock_capital_imputado + capital_circulante_adelantado
      ),
      tasa_ganancia_pb = safe_divide(
        ganancia_pb,
        stock_capital_imputado + capital_circulante_adelantado
      ),
      tasa_ganancia_pp = safe_divide(
        ganancia_pp,
        stock_capital_imputado + capital_circulante_adelantado
      ),
      vab_pp_participacion_total = safe_divide(vab_pp, vab_pp_total),
      productividad_trabajo = safe_divide(vab_pp, puestos_trabajo)
    ) %>%
    select(any_of(output_cols))
}

deflate_to_2005_prices <- function(data, price_indexes) {
  data %>%
    left_join(price_indexes, by = "anno") %>%
    mutate(
      # DECISION: For constant-price result sheets, labor flows are deflated
      # with the 2005-fixed CPI. The remaining monetary variables use the GDP
      # price index base 2005. Years without GDP price index remain NA.
      vbp_pp = safe_divide(vbp_pp, gdp_price_index_base_2005),
      vbp_pb = safe_divide(vbp_pb, gdp_price_index_base_2005),
      vab_pp = safe_divide(vab_pp, gdp_price_index_base_2005),
      vab_pb = safe_divide(vab_pb, gdp_price_index_base_2005),
      vab_pb_estimado = safe_divide(vab_pb_estimado, gdp_price_index_base_2005),
      consumo_intermedio_estimado = safe_divide(
        consumo_intermedio_estimado,
        gdp_price_index_base_2005
      ),
      capital_circulante_constante_adelantado = safe_divide(
        capital_circulante_constante_adelantado,
        gdp_price_index_base_2005
      ),
      remuneraciones = safe_divide(remuneraciones, ipc_index_2005),
      capital_variable_adelantado = safe_divide(
        capital_variable_adelantado,
        ipc_index_2005
      ),
      fbcf = safe_divide(fbcf, gdp_price_index_base_2005),
      fbkf_maq_eq = safe_divide(fbkf_maq_eq, gdp_price_index_base_2005),
      adquisiciones_importadas = safe_divide(
        adquisiciones_importadas,
        gdp_price_index_base_2005
      ),
      adquisiciones_origen_importado = safe_divide(
        adquisiciones_origen_importado,
        gdp_price_index_base_2005
      ),
      importaciones_maquinaria = safe_divide(
        importaciones_maquinaria,
        gdp_price_index_base_2005
      ),
      consumo_capital_fijo = safe_divide(
        consumo_capital_fijo,
        gdp_price_index_base_2005
      ),
      impuestos_netos = safe_divide(impuestos_netos, gdp_price_index_base_2005),
      stock_capital = safe_divide(stock_capital, gdp_price_index_base_2005),
      stock_capital_imputado = safe_divide(
        stock_capital_imputado,
        gdp_price_index_base_2005
      ),
      capital_total_adelantado = safe_divide(
        capital_total_adelantado,
        gdp_price_index_base_2005
      ),
      excedente_bruto = safe_divide(excedente_bruto, gdp_price_index_base_2005)
    )
}

build_variaciones_interanuales <- function(data) {
  transform_cols <- setdiff(names(data), result_transform_exclude_cols)
  data %>%
    arrange(anno) %>%
    transmute(
      anno,
      ambito,
      seccion,
      across(
        all_of(transform_cols),
        ~ (safe_divide(.x, lag(.x)) - 1) * 100,
        .names = "{.col}_var_pct"
      )
    )
}

build_indices_2005 <- function(variation_data, base_year = 2005) {
  variation_data <- variation_data %>% arrange(anno)
  years <- variation_data$anno
  base_position <- which(years == base_year)
  index_data <- variation_data %>%
    transmute(
      anno,
      ambito,
      seccion
    )

  if (length(base_position) != 1) {
    stop("No se encontro exactamente un ano base ", base_year, " en variaciones.")
  }

  variation_cols <- setdiff(names(variation_data), c("anno", "ambito", "seccion"))
  for (variation_col in variation_cols) {
    index_values <- rep(NA_real_, nrow(variation_data))
    index_values[base_position] <- 1

    if (base_position < nrow(variation_data)) {
      for (row_index in seq(base_position + 1, nrow(variation_data))) {
        growth <- variation_data[[variation_col]][[row_index]]
        previous_index <- index_values[[row_index - 1]]
        if (!is.na(growth) && !is.na(previous_index)) {
          index_values[[row_index]] <- previous_index * (1 + growth / 100)
        }
      }
    }

    if (base_position > 1) {
      for (row_index in seq(base_position - 1, 1)) {
        next_growth <- variation_data[[variation_col]][[row_index + 1]]
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
}

build_metodologia_sheet <- function() {
  tibble::tribble(
    ~seccion_contenido, ~nombre, ~tipo, ~aplica_en, ~definicion, ~fuente_formula,
    "estructura_libro", "metodología", "hoja", "Libro completo", "Referencia de lectura del archivo: describe las hojas y el diccionario de variables.", "Construida por el postproceso R.",
    "estructura_libro", "eaae", "hoja", "Panel base", "Panel completo con unidad año por sección CIIU homologada.", "CSV fechado del panel EAAE.",
    "estructura_libro", "rama-C", "hoja", "Panel base", "Subconjunto del panel para la rama industrial, sección C.", "Filtro seccion == C.",
    "estructura_libro", "check-calidad-C", "hoja", "Validación", "Indicadores anuales de control para la rama industrial.", "Derivada del panel rama-C.",
    "estructura_libro", "economia_total", "hoja", "Panel base", "Agregado anual de todas las secciones del panel.", "Suma de variables aditivas por año.",
    "estructura_libro", "check-calidad-total", "hoja", "Validación", "Indicadores anuales de control para la economía total.", "Derivada de economia_total.",
    "estructura_libro", "resultados-total-corrientes", "hoja", "Resultados", "Insumos y variables calculadas para economía total en valores corrientes.", "Cálculos propios desde economia_total.",
    "estructura_libro", "resultados-industrial-corrientes", "hoja", "Resultados", "Insumos y variables calculadas para la rama industrial en valores corrientes.", "Cálculos propios desde rama-C.",
    "estructura_libro", "resultados-total-constante", "hoja", "Resultados", "Insumos y variables calculadas para economía total en precios de 2005.", "Deflacta corrientes con índices Oyanthabal.",
    "estructura_libro", "resultados-industrial-constante", "hoja", "Resultados", "Insumos y variables calculadas para industria en precios de 2005.", "Deflacta corrientes con índices Oyanthabal.",
    "estructura_libro", "resultados-total-var-pct", "hoja", "Resultados", "Variación porcentual interanual de los resultados constantes de economía total.", "(x[t] / x[t-1] - 1) * 100.",
    "estructura_libro", "resultados-industrial-var-pct", "hoja", "Resultados", "Variación porcentual interanual de los resultados constantes de industria.", "(x[t] / x[t-1] - 1) * 100.",
    "estructura_libro", "resultados-total-ind-2005", "hoja", "Resultados", "Índices encadenados de economía total con base 2005=1.", "Base 2005=1 y encadenamiento por variaciones interanuales.",
    "estructura_libro", "resultados-industrial-ind-2005", "hoja", "Resultados", "Índices encadenados de industria con base 2005=1.", "Base 2005=1 y encadenamiento por variaciones interanuales.",
    "diccionario_variables", "anno", "identificador", "Todas las hojas", "Año de referencia.", "Fuente EAAE; entero anual.",
    "diccionario_variables", "seccion", "identificador", "Panel base y resultados", "Sección CIIU homologada; C identifica industria y economia_total identifica el agregado anual.", "Homologación del panel.",
    "diccionario_variables", "ambito", "identificador", "Hojas resultados-*", "Ámbito analítico de la hoja: economia_total o rama_industrial.", "Asignado por el postproceso R.",
    "diccionario_variables", "epoca", "metadato", "Panel base", "Período o etapa de formato de la fuente EAAE usada para extraer el dato.", "Pipeline EAAE.",
    "diccionario_variables", "ciiu_version", "metadato", "Panel base", "Versión CIIU de referencia de los datos originales u homologados.", "Pipeline EAAE.",
    "diccionario_variables", "rotacion", "parámetro", "Hojas resultados-*", "Factor de rotación usado para adelantar capital circulante.", "4,2 en economía total; 6,6 en industria.",
    "diccionario_variables", "vbp_pp", "original", "Panel base y resultados", "Valor bruto de producción a precios productor.", "EAAE C1/C1.1; en constantes se deflacta con gdp_price_index_base_2005.",
    "diccionario_variables", "vbp_pb", "original", "Panel base", "Valor bruto de producción a precios básicos.", "EAAE C1.1; disponible desde 2017.",
    "diccionario_variables", "vab_pp", "original", "Panel base y resultados", "Valor agregado bruto a precios productor.", "EAAE C1/C1.1; en constantes se deflacta con gdp_price_index_base_2005.",
    "diccionario_variables", "vab_pb", "original", "Panel base", "Valor agregado bruto a precios básicos observado.", "EAAE C1.1; disponible desde 2017.",
    "diccionario_variables", "remuneraciones", "original", "Panel base", "Remuneraciones totales registradas en C1/C1.1, incluyendo aportes patronales según validación del equipo.", "EAAE C1/C1.1.",
    "diccionario_variables", "puestos_trabajo", "original", "Panel base y resultados", "Cantidad de puestos de trabajo u ocupados reportados.", "EAAE C1/C1.1; se mantiene como cantidad en hojas constantes.",
    "diccionario_variables", "n_empresas", "auxiliar", "Panel base", "Cantidad total de empresas representadas cuando el diseño muestral permite extraerla al nivel del panel.", "PDF de metodología/diseño muestral EAAE.",
    "diccionario_variables", "fbcf", "original", "Panel base", "Formación bruta de capital fijo.", "Cuadros FBCF EAAE.",
    "diccionario_variables", "fbkf_maq_eq", "original", "Panel base y resultados", "Subtotal de formación bruta de capital fijo en maquinaria y equipos.", "Cuadros de componentes de FBKF: 2001 C11; 2003-2005 C13; 2006-2024 C8. Sin fuente en 2002 y 2011.",
    "diccionario_variables", "adquisiciones_importadas", "original", "Panel base", "Subcomponente importado de las adquisiciones de capital.", "Cuadros FBCF EAAE.",
    "diccionario_variables", "adquisiciones_origen_importado", "original", "Panel base y resultados", "Adquisiciones en plaza de origen importado.", "Columna K, Origen Imp., dentro de En plaza en cuadros FBCF cuando existe: 2004-2010 y 2012-2024.",
    "diccionario_variables", "importaciones_maquinaria", "calculada_panel", "Panel base y resultados", "Medida amplia de adquisiciones de maquinaria importada.", "adquisiciones_importadas + adquisiciones_origen_importado; queda vacía cuando falta alguno de los dos componentes.",
    "diccionario_variables", "consumo_capital_fijo", "original", "Panel base y resultados", "Consumo del stock de capital fijo.", "EAAE C2/C2.1; en constantes se deflacta con gdp_price_index_base_2005.",
    "diccionario_variables", "impuestos_netos", "original", "Panel base", "Impuestos netos asociados a las cuentas del sector.", "EAAE C2/C2.1.",
    "diccionario_variables", "stock_capital", "original", "Panel base y resultados", "Stock de capital fijo original.", "Cuadros de stock EAAE; en constantes se deflacta con gdp_price_index_base_2005.",
    "diccionario_variables", "stock_capital_imputado", "calculada_panel", "Panel base y resultados", "Serie operativa de stock de capital: replica el stock original cuando existe e imputa faltantes definidos.", "Si stock_capital existe, stock_capital_imputado = stock_capital. Para 2002 usa consumo_capital_fijo * factor_2003_2005 / 100; para 2011 usa consumo_capital_fijo * factor_2012_2024 / 100. Cada factor es el promedio porcentual de stock_capital / consumo_capital_fijo en la misma sección o total.",
    "diccionario_variables", "vab_pb_estimado", "calculada_panel", "Panel base y resultados", "Serie completa de VAB a precios básicos: usa VAB(pb) observado desde 2017 y retroproyección previa por VAB(pp).", "Antes de 2017 preserva la variación interanual de vab_pp.",
    "diccionario_variables", "vab_bcu_corriente", "auxiliar_externa", "Hojas resultados-*-corrientes", "VAB corriente de referencia publicado por BCU.", "BCU PIB-corriente-industrias-2006-2019; convertido de miles de pesos corrientes a pesos corrientes. Integra todos los años disponibles, incluyendo preliminares. Total: VALOR AGREGADO BRUTO DE LOS SECTORES DE ACTIVIDAD. Industria: codigo D, INDUSTRIAS MANUFACTURERAS.",
    "diccionario_variables", "vab_eaae_bcu_pct", "validación_externa", "Hojas resultados-*-corrientes", "Comparación del VAB corriente EAAE contra el VAB corriente BCU.", "vab_pp / vab_bcu_corriente * 100. Usa vab_pp como serie observada EAAE disponible para todo el panel.",
    "diccionario_variables", "consumo_intermedio_estimado", "calculada_panel", "Panel base", "Consumo intermedio estimado del panel.", "vbp_pp - vab_pb_estimado.",
    "diccionario_variables", "capital_variable_adelantado", "calculada_panel", "Panel base", "Capital variable adelantado del panel.", "remuneraciones / factor_rotacion.",
    "diccionario_variables", "capital_circulante_constante_adelantado", "calculada_panel", "Panel base", "Capital circulante constante adelantado del panel.", "consumo_intermedio_estimado / factor_rotacion.",
    "diccionario_variables", "capital_total_adelantado", "calculada_panel", "Panel base y resultados", "Capital total adelantado.", "En panel: stock_capital_imputado + capital_variable_adelantado + capital_circulante_constante_adelantado. En resultados: stock_capital_imputado + capital_circulante_adelantado.",
    "diccionario_variables", "excedente_bruto", "calculada_panel", "Panel base", "Excedente bruto aproximado a precios productor.", "vab_pp - remuneraciones.",
    "diccionario_variables", "part_salarial", "calculada_panel", "Panel base", "Participación salarial en el VAB a precios productor.", "remuneraciones / vab_pp.",
    "diccionario_variables", "productividad", "calculada_panel", "Panel base", "Productividad media a precios productor corrientes.", "vab_pp / puestos_trabajo.",
    "diccionario_variables", "vab_vbp", "validación", "check-calidad-*", "Relación entre VAB y VBP a precios productor.", "vab_pp / vbp_pp.",
    "diccionario_variables", "remuneraciones_vab", "validación", "check-calidad-*", "Peso de remuneraciones sobre VAB a precios productor.", "remuneraciones / vab_pp.",
    "diccionario_variables", "stock_vab", "validación", "check-calidad-*", "Relación entre stock de capital operativo y VAB a precios productor.", "stock_capital_imputado / vab_pp.",
    "diccionario_variables", "gdp_price_index_base_2005", "deflactor", "Hojas constantes", "Índice de precios implícito del PIB con base 2005.", "Oyanthabal; usado para variables monetarias no laborales.",
    "diccionario_variables", "ipc_index_2005", "deflactor", "Hojas constantes", "Índice de precios al consumo con base 2005.", "Oyanthabal; usado para costo_laboral. Si la planilla no lo trae explícito, se deriva desde ipc_index_1983_1989 normalizando 2005=1.",
    "diccionario_variables", "costo_laboral", "calculada_resultados", "Hojas resultados-*", "Costo laboral operativo usado en ganancias.", "Igual a remuneraciones; no se separan cargas patronales para evitar doble conteo.",
    "diccionario_variables", "ganancia_pb", "calculada_resultados", "Hojas resultados-*", "Ganancia calculada a precios básicos.", "vab_pb_estimado - consumo_capital_fijo - costo_laboral.",
    "diccionario_variables", "ganancia_pp", "calculada_resultados", "Hojas resultados-*", "Ganancia calculada a precios productor.", "vab_pp - consumo_capital_fijo - costo_laboral.",
    "diccionario_variables", "consumo_intermedio", "calculada_resultados", "Hojas resultados-*", "Consumo intermedio usado en resultados propios.", "vbp_pp - vab_pp.",
    "diccionario_variables", "capital_circulante_adelantado", "calculada_resultados", "Hojas resultados-*", "Capital circulante adelantado para el cálculo de tasa de ganancia.", "(costo_laboral + consumo_intermedio) / rotacion.",
    "diccionario_variables", "tasa_ganancia_pb", "calculada_resultados", "Hojas resultados-*", "Tasa de ganancia a precios básicos.", "ganancia_pb / (stock_capital_imputado + capital_circulante_adelantado).",
    "diccionario_variables", "tasa_ganancia_pp", "calculada_resultados", "Hojas resultados-*", "Tasa de ganancia a precios productor.", "ganancia_pp / (stock_capital_imputado + capital_circulante_adelantado).",
    "diccionario_variables", "vab_pp_total", "contexto_sectorial", "Resultados industriales", "VAB total de la economía usado como denominador de participación sectorial.", "Economía total por año.",
    "diccionario_variables", "vab_pp_participacion_total", "calculada_resultados", "Resultados industriales", "Participación del VAB industrial en el VAB total.", "vab_pp / vab_pp_total.",
    "diccionario_variables", "productividad_trabajo", "calculada_resultados", "Hojas constantes y transformaciones", "Productividad del trabajo calculada en precios constantes.", "vab_pp constante / puestos_trabajo.",
    "diccionario_variables", "*_var_pct", "transformación", "Hojas resultados-*-var-pct", "Sufijo de variables expresadas como variación porcentual interanual.", "(x[t] / x[t-1] - 1) * 100 desde resultados constantes.",
    "diccionario_variables", "*_ind_2005", "transformación", "Hojas resultados-*-ind-2005", "Sufijo de variables expresadas como índice con base 2005=1.", "Encadenamiento desde variaciones interanuales."
  )
}

calculos_total <- build_resultados_niveles(
  economia_total,
  "economia_total",
  vab_total,
  rotacion_economia_total,
  bcu_vab = bcu_vab_total
)

calculos_industrial <- panel %>%
  filter(seccion == "C") %>%
  build_resultados_niveles(
    "rama_industrial",
    vab_total,
    rotacion_industria,
    include_total_context = TRUE,
    bcu_vab = bcu_vab_industrial
  )

economia_total_constante <- economia_total %>%
  deflate_to_2005_prices(price_indexes)

panel_constante <- panel %>%
  deflate_to_2005_prices(price_indexes)

vab_total_constante <- economia_total_constante %>%
  transmute(
    anno,
    vab_pp_total = vab_pp
  )

resultados_total_constante <- build_resultados_niveles(
  economia_total_constante,
  "economia_total",
  vab_total_constante,
  rotacion_economia_total,
  include_price_indexes = TRUE,
  include_productividad = TRUE
)

resultados_industrial_constante <- panel_constante %>%
  filter(seccion == "C") %>%
  build_resultados_niveles(
    "rama_industrial",
    vab_total_constante,
    rotacion_industria,
    include_total_context = TRUE,
    include_price_indexes = TRUE,
    include_productividad = TRUE
  )

variaciones_total_constante <- build_variaciones_interanuales(
  resultados_total_constante
)

variaciones_industrial_constante <- build_variaciones_interanuales(
  resultados_industrial_constante
)

indices_total_constante <- build_indices_2005(
  variaciones_total_constante
)

indices_industrial_constante <- build_indices_2005(
  variaciones_industrial_constante
)

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
    function(column_index) {
      write_cell_xml(1, column_index, header[[column_index]])
    },
    character(1)
  )
  rows[[1]] <- sprintf(
    '<row r="1">%s</row>',
    paste0(header_cells, collapse = "")
  )

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

  rows <- rows[!vapply(rows, is.null, logical(1))]
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
    "<dc:title>Panel EAAE Uruguay</dc:title>",
    "<dc:creator>economia-uruguay R postprocess</dc:creator>",
    "</cp:coreProperties>"
  )
}

write_xlsx_workbook <- function(path, sheets) {
  if (Sys.which("zip") == "") {
    stop("No se encontro el comando del sistema `zip`, necesario para escribir XLSX.")
  }

  sheet_names <- names(sheets)
  output_path <- file.path(normalizePath(dirname(path)), basename(path))
  tmpdir <- tempfile("eaae-xlsx-")
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

existing_sheet_names <- readxl::excel_sheets(panel_xlsx_path)
existing_sheet_names <- setdiff(
  existing_sheet_names,
  c(
    methodology_sheet,
    total_sheet,
    industrial_sheet,
    total_constant_sheet,
    industrial_constant_sheet,
    total_variation_sheet,
    industrial_variation_sheet,
    total_index_sheet,
    industrial_index_sheet,
    legacy_result_sheets
  )
)

existing_sheets <- lapply(
  existing_sheet_names,
  function(sheet_name) {
    readxl::read_excel(
      panel_xlsx_path,
      sheet = sheet_name,
      .name_repair = "minimal"
    )
  }
)
names(existing_sheets) <- existing_sheet_names

metodologia <- build_metodologia_sheet()

output_sheets <- c(
  setNames(list(metodologia), methodology_sheet),
  existing_sheets,
  setNames(list(calculos_total), total_sheet),
  setNames(list(calculos_industrial), industrial_sheet),
  setNames(list(resultados_total_constante), total_constant_sheet),
  setNames(list(resultados_industrial_constante), industrial_constant_sheet),
  setNames(list(variaciones_total_constante), total_variation_sheet),
  setNames(list(variaciones_industrial_constante), industrial_variation_sheet),
  setNames(list(indices_total_constante), total_index_sheet),
  setNames(list(indices_industrial_constante), industrial_index_sheet)
)

write_xlsx_workbook(panel_xlsx_path, output_sheets)

message("Hojas actualizadas en ", panel_xlsx_path, ":")
message(" - ", methodology_sheet)
message(" - ", total_sheet)
message(" - ", industrial_sheet)
message(" - ", total_constant_sheet)
message(" - ", industrial_constant_sheet)
message(" - ", total_variation_sheet)
message(" - ", industrial_variation_sheet)
message(" - ", total_index_sheet)
message(" - ", industrial_index_sheet)
