# Build an integrated EAAE-BCU panel for total economy, manufacturing, and
# Rev.4-compatible manufacturing sub-branches.
#
# Run from the project root:
#   Rscript command-files/processing-command-files/13_build_panel_eaae_bcu_total_industria_subrama.R

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(readr)
  library(readxl)
  library(stringr)
  library(tibble)
  library(tidyr)
})

analysis_dir <- file.path("data", "analysis-data")
input_bcu_dir <- file.path("data", "input-data", "bcu", "indices-precios-1988-2024")
input_damodaran_dir <- file.path("data", "input-data", "damodaran")

date_prefix <- Sys.getenv("EAAE_OUTPUT_DATE", unset = format(Sys.Date(), "%Y%m%d"))
output_path <- file.path(
  analysis_dir,
  paste0(date_prefix, "_panel_eeae_bcu_total_industria_subrama.csv")
)

panel_eaae_path <- file.path(analysis_dir, "20260605_panel_eaae.csv")
subrama_eaae_path <- file.path(
  analysis_dir,
  "20260617_panel_eaae_industria_subramas_rev4_homologado.csv"
)
direct_capital_helper <- file.path(
  "command-files",
  "processing-command-files",
  "eaae_subrama_capital_direct.py"
)
rotation_calibration_path <- file.path(
  input_damodaran_dir,
  "20260630_rotacion_damodaran_eaae.xlsx"
)

bcu_1997_current_path <- file.path(input_bcu_dir, "1997-2005", "cuadro_9a97.xls")
bcu_1997_constant_path <- file.path(input_bcu_dir, "1997-2005", "cuadro_10a97.xls")
bcu_2005_current_path <- file.path(input_bcu_dir, "2005-2018", "cuadro_13a (1).xls")
bcu_2005_constant_path <- file.path(input_bcu_dir, "2005-2018", "cuadro_14a (1).xls")
bcu_2016_current_path <- file.path(
  input_bcu_dir,
  "2016 - 2024",
  "11_2016_2024_Cuenta Produccion Industrias_C (1).xlsx"
)
bcu_2016_constant_path <- file.path(
  input_bcu_dir,
  "2016 - 2024",
  "12_2016_2024_Cuenta Produccion Industrias_K.xlsx"
)

panel_numeric_cols <- c(
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

eaae_value_cols <- c(
  "vbp_pp",
  "vbp_pb",
  "vab_pp",
  "vab_pb",
  "vab_pb_estimado",
  "consumo_intermedio_estimado",
  "consumo_intermedio",
  "remuneraciones",
  "costo_laboral",
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
  "capital_variable_adelantado",
  "capital_circulante_constante_adelantado",
  "capital_circulante_adelantado",
  "capital_total_adelantado",
  "ganancia_pb",
  "ganancia_pp",
  "tasa_ganancia_pb",
  "tasa_ganancia_pp",
  "part_salarial",
  "productividad"
)

excluded_industry_groups <- c(
  "17_18_papel_impresion",
  "19_refinacion"
)

industry_excluding_level <- "industria_sin_papel_coque_refinacion"
industry_excluding_section <- "industria-sin-papel-coque-refinacion"
industry_excluding_description <-
  "Industria manufacturera EAAE sin papel, coque y refinacion de petroleo"

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

collapse_present <- function(x) {
  values <- sort(unique(na.omit(as.character(x))))
  values <- values[values != ""]
  if (length(values) == 0) {
    return(NA_character_)
  }
  paste(values, collapse = "|")
}

clean_code <- function(x) {
  x %>%
    as.character() %>%
    str_replace_all("\\s*\\(1\\)", "") %>%
    str_squish()
}

parse_year_label <- function(x) {
  clean <- str_squish(as.character(x))
  parsed <- str_match(clean, "^(\\d{4})(\\*{1,2})?$")
  suppressWarnings(as.integer(parsed[, 2]))
}

read_bcu_wide <- function(
    path,
    sheet,
    fuente_base,
    tipo_valor,
    code_col,
    desc_col,
    unit_multiplier) {
  raw <- readxl::read_excel(
    path,
    sheet = sheet,
    col_names = FALSE,
    .name_repair = "minimal"
  )
  names(raw) <- paste0("col", seq_along(raw))
  raw_char <- raw %>%
    mutate(across(everything(), as.character))

  year_counts <- raw_char %>%
    mutate(.row = row_number()) %>%
    rowwise() %>%
    mutate(.n_years = sum(!is.na(parse_year_label(c_across(starts_with("col")))))) %>%
    ungroup()

  header_row <- year_counts %>%
    filter(.n_years >= 5) %>%
    slice(1) %>%
    pull(.row)

  if (length(header_row) != 1 || is.na(header_row)) {
    stop("No se encontro fila de anos en ", path)
  }

  header_values <- as.character(unlist(raw_char[header_row, ], use.names = FALSE))
  year_cols <- tibble(
    col_index = seq_along(header_values),
    anno = parse_year_label(header_values),
    dato_preliminar = str_detect(str_squish(header_values), "\\*")
  ) %>%
    filter(!is.na(anno))

  raw %>%
    mutate(.row = row_number()) %>%
    filter(.row > header_row) %>%
    transmute(
      codigo_bcu_raw = clean_code(.data[[paste0("col", code_col)]]),
      descripcion_bcu_raw = str_squish(as.character(.data[[paste0("col", desc_col)]])),
      across(
        all_of(paste0("col", year_cols$col_index)),
        ~ suppressWarnings(as.numeric(.x))
      )
    ) %>%
    mutate(
      # DECISION: In the BCU 2016 VAB current-price workbook, the aggregate
      # "Total VAB" label appears in the code column instead of the description
      # column. Normalize that layout so the total-economy deflator can be read
      # from BCU directly and not from the Oyanthabal processed index.
      descripcion_bcu = case_when(
        (is.na(descripcion_bcu_raw) | descripcion_bcu_raw == "") &
          str_to_upper(coalesce(codigo_bcu_raw, "")) == "TOTAL VAB" ~ "Total VAB",
        TRUE ~ descripcion_bcu_raw
      ),
      codigo_bcu = case_when(
        str_to_upper(coalesce(codigo_bcu_raw, "")) == "TOTAL VAB" ~ NA_character_,
        TRUE ~ codigo_bcu_raw
      )
    ) %>%
    select(-codigo_bcu_raw, -descripcion_bcu_raw) %>%
    filter(!is.na(descripcion_bcu), descripcion_bcu != "") %>%
    pivot_longer(
      cols = all_of(paste0("col", year_cols$col_index)),
      names_to = "col_name",
      values_to = "valor_publicado"
    ) %>%
    left_join(
      year_cols %>%
        mutate(col_name = paste0("col", col_index)) %>%
        select(col_name, anno, dato_preliminar),
      by = "col_name"
    ) %>%
    filter(!is.na(valor_publicado)) %>%
    transmute(
      fuente = "bcu",
      fuente_base,
      tipo_valor,
      codigo_bcu,
      descripcion_bcu,
      anno = as.integer(anno),
      valor_pesos = valor_publicado * unit_multiplier,
      dato_preliminar = as.logical(dato_preliminar)
    )
}

bcu_group_map <- tribble(
  ~nivel_panel, ~grupo_rev4_homologado, ~descripcion_nivel, ~fuente_base, ~codigos_bcu, ~calidad_deflactor_bcu, ~nota_deflactor_bcu,
  "economia_total", NA_character_, "Economia total BCU - VAB sectores", "1997", "__TOTAL_VAB_SECTORES__", "directo_total_economia", "VAB de sectores de actividad BCU; en base 1997 figura como Subtotal.",
  "economia_total", NA_character_, "Economia total BCU - VAB sectores", "2005", "__TOTAL_VAB_SECTORES__", "directo_total_economia", "VAB de sectores de actividad BCU.",
  "economia_total", NA_character_, "Economia total BCU - VAB sectores", "2016", "__TOTAL_VAB_SECTORES__", "directo_total_economia", "Total VAB de sectores de actividad BCU.",
  "industria_total", NA_character_, "Industria manufacturera", "1997", "D", "directo", "Total industria manufacturera BCU Rev.3.",
  "industria_total", NA_character_, "Industria manufacturera", "2005", "D", "directo", "Total industria manufacturera BCU Rev.3.",
  "industria_total", NA_character_, "Industria manufacturera", "2016", "__ALL_C__", "reconstruido_por_suma", "Total manufacturero reconstruido por suma de filas C publicadas en el libro BCU 2016.",
  "subrama_industrial", "10_11_12_alimentos_bebidas_tabaco", "Alimentos bebidas y tabaco", "1997", "D.15-D.16", "directo", "Agregado BCU compatible con el grupo EAAE.",
  "subrama_industrial", "10_11_12_alimentos_bebidas_tabaco", "Alimentos bebidas y tabaco", "2005", "D.15-D.16", "directo", "Agregado BCU compatible con el grupo EAAE.",
  "subrama_industrial", "10_11_12_alimentos_bebidas_tabaco", "Alimentos bebidas y tabaco", "2016", "C.101T.0|C.1020.0|C.1030.0|C.1040.0|C.1050.0|C.10RT.0|C.107V.0|C.107X.1 C.107X.9|C.1PTT.0", "reconstruido_por_suma", "Suma de filas BCU Rev.4 de alimentos, bebidas y tabaco.",
  "subrama_industrial", "13_14_15_textiles_prendas_cuero", "Textiles prendas y cuero", "1997", "D.17 a D.19", "directo", "Agregado BCU compatible con el grupo EAAE.",
  "subrama_industrial", "13_14_15_textiles_prendas_cuero", "Textiles prendas y cuero", "2005", "D.17 a D.19", "directo", "Agregado BCU compatible con el grupo EAAE.",
  "subrama_industrial", "13_14_15_textiles_prendas_cuero", "Textiles prendas y cuero", "2016", "C.13TT.0|C.14TT.0|C.15TT.0", "reconstruido_por_suma", "Suma de textiles, prendas y cuero.",
  "subrama_industrial", "16_madera", "Madera y productos de madera", "1997", "D.20 a D.22", "proxy_grupo_amplio", "BCU 1997 agrega madera, papel e impresion; se usa proxy amplio.",
  "subrama_industrial", "16_madera", "Madera y productos de madera", "2005", "D.20TT.0", "directo", "Fila BCU especifica de madera.",
  "subrama_industrial", "16_madera", "Madera y productos de madera", "2016", "C.16TT.0", "directo", "Fila BCU especifica de madera.",
  "subrama_industrial", "17_18_papel_impresion", "Papel impresion y reproduccion", "1997", "D.20 a D.22", "proxy_grupo_amplio", "BCU 1997 agrega madera, papel e impresion; se usa proxy amplio.",
  "subrama_industrial", "17_18_papel_impresion", "Papel impresion y reproduccion", "2005", "D.210T.0|D.22TT.0", "reconstruido_por_suma", "Suma de papel e impresion.",
  "subrama_industrial", "17_18_papel_impresion", "Papel impresion y reproduccion", "2016", "C.170V.1 C.170V.9|C.18TT.0", "reconstruido_por_suma", "Suma de papel e impresion.",
  "subrama_industrial", "19_refinacion", "Coque y refinacion de petroleo", "1997", "D.23", "directo", "Fila BCU compatible.",
  "subrama_industrial", "19_refinacion", "Coque y refinacion de petroleo", "2005", "D.23", "directo", "Fila BCU compatible.",
  "subrama_industrial", "19_refinacion", "Coque y refinacion de petroleo", "2016", "C.19TT.0", "directo", "Fila BCU compatible.",
  "subrama_industrial", "20_21_22_quimicos_farma_caucho_plastico", "Quimicos farmaceuticos caucho y plastico", "1997", "D.24 - D.25", "directo", "Agregado BCU compatible con el grupo EAAE.",
  "subrama_industrial", "20_21_22_quimicos_farma_caucho_plastico", "Quimicos farmaceuticos caucho y plastico", "2005", "D.24 - D.25", "directo", "Agregado BCU compatible con el grupo EAAE.",
  "subrama_industrial", "20_21_22_quimicos_farma_caucho_plastico", "Quimicos farmaceuticos caucho y plastico", "2016", "C.20TV.0|C.20TX.0|C.2100.0|C.22TT.0", "reconstruido_por_suma", "Suma de quimicos, farmaceuticos, caucho y plastico.",
  "subrama_industrial", "23_24_minerales_metales", "Minerales no metalicos y metales comunes", "1997", "D.26 - D.27", "directo", "Agregado BCU compatible con el grupo EAAE Rev.3.",
  "subrama_industrial", "23_24_minerales_metales", "Minerales no metalicos y metales comunes", "2005", "D.26", "proxy_grupo_amplio", "BCU 2005 no separa completamente metales comunes del grupo metal/equipos; se usa minerales no metalicos como proxy parcial.",
  "subrama_industrial", "23_24_minerales_metales", "Minerales no metalicos y metales comunes", "2016", "C.23TT.0|C.2PTT.0", "proxy_grupo_amplio", "C.2PTT.0 cruza metales comunes con productos elaborados de metal.",
  "subrama_industrial", "25_26_27_28_33_metal_equipos_reparacion", "Productos de metal equipos y reparacion", "1997", "D.RR a D.33", "directo", "Agregado BCU compatible con maquinaria y equipo Rev.3.",
  "subrama_industrial", "25_26_27_28_33_metal_equipos_reparacion", "Productos de metal equipos y reparacion", "2005", "D.RR", "proxy_grupo_amplio", "BCU 2005 agrupa metales basicos, productos de metal y equipos; proxy compatible amplio.",
  "subrama_industrial", "25_26_27_28_33_metal_equipos_reparacion", "Productos de metal equipos y reparacion", "2016", "C.2PTT.0|C.2QTT.0", "proxy_grupo_amplio", "C.2PTT.0 cruza metales comunes y productos de metal; reparacion queda parcialmente en C.PPTT.0.",
  "subrama_industrial", "29_30_vehiculos_transporte", "Vehiculos y otros equipos de transporte", "1997", "D.34 - D.35", "directo", "Agregado BCU compatible con material de transporte.",
  "subrama_industrial", "29_30_vehiculos_transporte", "Vehiculos y otros equipos de transporte", "2005", "D.SS", "directo", "Fila BCU de material de transporte.",
  "subrama_industrial", "29_30_vehiculos_transporte", "Vehiculos y otros equipos de transporte", "2016", "C.3PTT.0", "directo", "Fila BCU de vehiculos y otros equipos de transporte.",
  "subrama_industrial", "31_32_muebles_otras_manufacturas", "Muebles y otras manufacturas", "1997", "D.UU", "directo", "Fila BCU de otras industrias manufactureras.",
  "subrama_industrial", "31_32_muebles_otras_manufacturas", "Muebles y otras manufacturas", "2005", "D.UU", "directo", "Fila BCU de otras industrias manufactureras.",
  "subrama_industrial", "31_32_muebles_otras_manufacturas", "Muebles y otras manufacturas", "2016", "C.PPTT.0", "proxy_grupo_amplio", "BCU 2016 agrupa muebles, otras manufacturas y reparacion/instalacion."
) %>%
  mutate(
    fuente_base = as.character(fuente_base),
    codigo_bcu = str_split(codigos_bcu, fixed("|"))
  ) %>%
  unnest(codigo_bcu) %>%
  mutate(codigo_bcu = clean_code(codigo_bcu))

read_all_bcu_vab <- function() {
  bind_rows(
    read_bcu_wide(
      bcu_1997_current_path, 1, "1997", "corriente", 1, 2, 1000
    ),
    read_bcu_wide(
      bcu_1997_constant_path, 1, "1997", "constante", 1, 2, 1000
    ),
    read_bcu_wide(
      bcu_2005_current_path, 1, "2005", "corriente", 1, 2, 1000
    ),
    read_bcu_wide(
      bcu_2005_constant_path, 1, "2005", "constante", 1, 2, 1000
    ),
    read_bcu_wide(
      bcu_2016_current_path, "VAB_C", "2016", "corriente", 2, 3, 1000000
    ),
    read_bcu_wide(
      bcu_2016_constant_path, "VAB_K", "2016", "constante", 2, 3, 1000000
    )
  ) %>%
    mutate(
      codigo_bcu = case_when(
        fuente_base == "1997" & descripcion_bcu == "Subtotal" ~ "__TOTAL_VAB_SECTORES__",
        fuente_base == "2005" &
          descripcion_bcu == "VALOR AGREGADO BRUTO DE LOS SECTORES DE ACTIVIDAD" ~
          "__TOTAL_VAB_SECTORES__",
        fuente_base == "2016" & descripcion_bcu == "Total VAB" ~ "__TOTAL_VAB_SECTORES__",
        TRUE ~ codigo_bcu
      )
  )
}

read_direct_subrama_capital <- function() {
  temp_output <- tempfile(fileext = ".csv")
  on.exit(unlink(temp_output), add = TRUE)

  result <- system2(
    "python3",
    c(direct_capital_helper, "--output", temp_output),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(result, "status")
  if (!is.null(status) && status != 0) {
    stop(
      "Fallo la extraccion directa de capital subrama:\n",
      paste(result, collapse = "\n")
    )
  }
  readr::read_csv(temp_output, show_col_types = FALSE) %>%
    mutate(
      anno = as.integer(anno),
      across(
        any_of(c(
          "consumo_capital_fijo",
          "impuestos_netos",
          "stock_capital",
          "stock_capital_imputado"
        )),
        as.numeric
      )
    )
}

read_rotation_calibration <- function() {
  readxl::read_excel(rotation_calibration_path, sheet = "Resumen") %>%
    transmute(
      descripcion_nivel = str_squish(as.character(rama)),
      rotacion_calibrada_sobre_6_6 =
        suppressWarnings(as.numeric(rotacion_calibrada_sobre_6_6))
    ) %>%
    filter(!is.na(descripcion_nivel), descripcion_nivel != "") %>%
    distinct(descripcion_nivel, .keep_all = TRUE)
}

build_bcu_deflators <- function() {
  bcu_vab <- read_all_bcu_vab()

  bcu_2016_all_c <- bcu_vab %>%
    filter(
      fuente_base == "2016",
      str_detect(codigo_bcu, "^C\\."),
      codigo_bcu != "Código"
    ) %>%
    mutate(codigo_bcu = "__ALL_C__")

  bcu_mapped <- bind_rows(bcu_vab, bcu_2016_all_c) %>%
    # DECISION: Some BCU codes are intentionally reused as broad proxies for
    # more than one EAAE-compatible group when BCU does not publish separable
    # two-digit boundaries. Keep the many-to-many join explicit and trace it
    # through `calidad_deflactor_bcu` and `nota_deflactor_bcu`.
    inner_join(
      bcu_group_map,
      by = c("fuente_base", "codigo_bcu"),
      relationship = "many-to-many"
    ) %>%
    group_by(
      nivel_panel,
      grupo_rev4_homologado,
      descripcion_nivel,
      fuente_base,
      anno,
      tipo_valor,
      calidad_deflactor_bcu,
      nota_deflactor_bcu
    ) %>%
    summarise(
      valor_pesos = sum(valor_pesos, na.rm = TRUE),
      codigos_bcu_deflactor = paste(sort(unique(codigo_bcu)), collapse = "|"),
      dato_preliminar_bcu = any(dato_preliminar, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    pivot_wider(
      names_from = tipo_valor,
      values_from = valor_pesos
    ) %>%
    mutate(
      indice_precio_vab_fuente = safe_divide(corriente, constante)
    )

  source_indexes <- bcu_mapped %>%
    mutate(
      id_deflactor = case_when(
        nivel_panel == "economia_total" ~ "economia_total",
        nivel_panel == "industria_total" ~ "industria_total",
        TRUE ~ grupo_rev4_homologado
      )
    ) %>%
    group_by(id_deflactor, fuente_base) %>%
    mutate(
      indice_2005_norm = indice_precio_vab_fuente /
        indice_precio_vab_fuente[anno == 2005][1],
      indice_2016_norm = indice_precio_vab_fuente /
        indice_precio_vab_fuente[anno == 2016][1]
    ) %>%
    ungroup()

  base2005_2016 <- source_indexes %>%
    filter(fuente_base == "2005", anno == 2016) %>%
    select(id_deflactor, indice_2005_2016 = indice_2005_norm)

  source_indexes %>%
    left_join(base2005_2016, by = "id_deflactor") %>%
    mutate(
      deflactor_vab_bcu_2005 = case_when(
        fuente_base == "1997" & between(anno, 2001L, 2005L) ~
          indice_precio_vab_fuente / indice_precio_vab_fuente[anno == 2005][1],
        fuente_base == "2005" & between(anno, 2005L, 2016L) ~
          indice_2005_norm,
        fuente_base == "2016" & between(anno, 2017L, 2024L) ~
          indice_2005_2016 * indice_2016_norm,
        TRUE ~ NA_real_
      ),
      metodo_empalme_bcu = case_when(
        fuente_base == "1997" & between(anno, 2001L, 2005L) ~
          "normalizacion_2005_desde_base_1997",
        fuente_base == "2005" & between(anno, 2005L, 2016L) ~
          "base_2005_directa",
        fuente_base == "2016" & between(anno, 2017L, 2024L) ~
          "variacion_interanual_encadenada_desde_2016",
        TRUE ~ NA_character_
      )
    ) %>%
    filter(!is.na(deflactor_vab_bcu_2005), between(anno, 2001L, 2024L)) %>%
    arrange(id_deflactor, anno, fuente_base) %>%
    group_by(id_deflactor, anno) %>%
    slice_tail(n = 1) %>%
    ungroup() %>%
    transmute(
      anno,
      nivel_panel,
      grupo_rev4_homologado,
      descripcion_nivel_bcu = descripcion_nivel,
      vab_bcu_corriente = corriente,
      vab_bcu_constante_fuente = constante,
      deflactor_vab_bcu_2005,
      fuente_base_bcu = fuente_base,
      metodo_empalme_bcu,
      calidad_deflactor_bcu,
      codigos_bcu_deflactor,
      dato_preliminar_bcu,
      nota_deflactor_bcu
    )
}

build_eaae_rows <- function() {
  panel <- readr::read_csv(panel_eaae_path, show_col_types = FALSE) %>%
    mutate(
      anno = as.integer(anno),
      across(any_of(panel_numeric_cols), as.numeric)
    )

  panel_total <- panel %>%
    group_by(anno) %>%
    summarise(
      across(any_of(setdiff(panel_numeric_cols, c(
        "capital_circulante_constante_adelantado",
        "capital_variable_adelantado",
        "capital_total_adelantado",
        "excedente_bruto",
        "part_salarial",
        "productividad"
      ))), sum_present),
      epoca = paste(sort(unique(epoca)), collapse = "|"),
      ciiu_version = paste(sort(unique(ciiu_version)), collapse = "|"),
      .groups = "drop"
    ) %>%
    mutate(
      nivel_panel = "economia_total",
      seccion = "economia_total",
      grupo_rev4_homologado = NA_character_,
      descripcion_nivel = "Economia total EAAE",
      metodo_capital_eaae = "agregacion_secciones_eaae",
      metodo_stock_capital = "stock_original_e_imputado_agregado_desde_panel_eaae",
      metodo_consumo_capital_fijo = "suma_consumo_capital_fijo_original_eaae",
      calidad_capital_eaae = "directo_agregado"
    )

  industria_total <- panel %>%
    filter(seccion == "C") %>%
    mutate(
      nivel_panel = "industria_total",
      grupo_rev4_homologado = NA_character_,
      descripcion_nivel = "Industria manufacturera EAAE",
      epoca = as.character(epoca),
      ciiu_version = as.character(ciiu_version),
      metodo_capital_eaae = "rama_c_panel_eaae",
      metodo_stock_capital = if_else(
        anno %in% c(2002L, 2011L),
        "stock_imputado_ratio_stock_consumo_capital_fijo_rama_c",
        "stock_original_rama_c"
      ),
      metodo_consumo_capital_fijo = "consumo_capital_fijo_original_rama_c",
      calidad_capital_eaae = if_else(anno %in% c(2002L, 2011L), "imputado", "directo")
    )

  subramas_raw <- readr::read_csv(subrama_eaae_path, show_col_types = FALSE) %>%
    filter(incluir_sector_industrial_rev4 == "si") %>%
    mutate(
      anno = as.integer(anno),
      across(any_of(c("vbp_pp", "vbp_pb", "vab_pp", "vab_pb", "remuneraciones", "puestos_trabajo")), as.numeric)
    )

  industry_capital <- industria_total %>%
    select(
      anno,
      fbcf_c = fbcf,
      fbkf_maq_eq_c = fbkf_maq_eq,
      adquisiciones_importadas_c = adquisiciones_importadas,
      adquisiciones_origen_importado_c = adquisiciones_origen_importado,
      importaciones_maquinaria_c = importaciones_maquinaria
    )

  subrama_shares <- subramas_raw %>%
    group_by(anno) %>%
    mutate(
      vab_pp_subramas = sum(vab_pp, na.rm = TRUE),
      participacion_vab_pp_rama_c = safe_divide(vab_pp, vab_pp_subramas)
    ) %>%
    ungroup()

  subrama_capital_direct <- read_direct_subrama_capital()

  subramas <- subrama_shares %>%
    left_join(industry_capital, by = "anno") %>%
    left_join(
      subrama_capital_direct,
      by = c("anno", "grupo_rev4_homologado")
    ) %>%
    group_by(grupo_rev4_homologado) %>%
    mutate(
      ratio_vab_pb = vab_pb / vab_pp,
      ratio_base_vab_pb = ratio_vab_pb[!is.na(ratio_vab_pb)][1],
      vab_pb_estimado = if_else(
        !is.na(vab_pb),
        vab_pb,
        vab_pp * ratio_base_vab_pb
      )
    ) %>%
    ungroup() %>%
    mutate(
      nivel_panel = "subrama_industrial",
      descripcion_nivel = descripcion_grupo_rev4_homologado,
      consumo_intermedio_estimado = vbp_pp - vab_pb_estimado,
      fbcf = fbcf_c * participacion_vab_pp_rama_c,
      fbkf_maq_eq = fbkf_maq_eq_c * participacion_vab_pp_rama_c,
      adquisiciones_importadas = adquisiciones_importadas_c * participacion_vab_pp_rama_c,
      adquisiciones_origen_importado =
        adquisiciones_origen_importado_c * participacion_vab_pp_rama_c,
      importaciones_maquinaria = importaciones_maquinaria_c * participacion_vab_pp_rama_c,
      n_empresas = NA_real_,
      epoca = as.character(epoca),
      ciiu_version = ciiu_version_fuente
    )

  bind_rows(
    panel_total,
    industria_total,
    subramas
  ) %>%
    mutate(
      costo_laboral = remuneraciones,
      consumo_intermedio = vbp_pp - vab_pp,
      ganancia_pb = vab_pb_estimado - consumo_capital_fijo - costo_laboral,
      ganancia_pp = vab_pp - consumo_capital_fijo - costo_laboral,
      excedente_bruto = vab_pp - remuneraciones,
      part_salarial = safe_divide(remuneraciones, vab_pp),
      productividad = safe_divide(vab_pp, puestos_trabajo)
    )
}

add_deflators <- function(eaae_panel, bcu_deflators) {
  eaae_panel %>%
    left_join(
      bcu_deflators,
      by = c("anno", "nivel_panel", "grupo_rev4_homologado")
    ) %>%
    mutate(
      deflactor_2005 = deflactor_vab_bcu_2005,
      fuente_deflactor = "bcu_indice_implicito_vab"
    )
}

add_rotation_calibration <- function(panel) {
  rotation_calibration <- read_rotation_calibration()

  panel %>%
    left_join(rotation_calibration, by = "descripcion_nivel") %>%
    mutate(
      # DECISION: From 2026-07-06 onward, the integrated EAAE-BCU panel uses
      # the Damodaran-calibrated rotation for advanced-capital calculations.
      # The previous generic `rotacion` column is not exported.
      capital_variable_adelantado =
        remuneraciones / rotacion_calibrada_sobre_6_6,
      capital_circulante_constante_adelantado =
        consumo_intermedio_estimado / rotacion_calibrada_sobre_6_6,
      capital_circulante_adelantado =
        (costo_laboral + consumo_intermedio) / rotacion_calibrada_sobre_6_6,
      capital_total_adelantado =
        stock_capital_imputado + capital_circulante_adelantado,
      tasa_ganancia_pb = safe_divide(ganancia_pb, capital_total_adelantado),
      tasa_ganancia_pp = safe_divide(ganancia_pp, capital_total_adelantado)
    )
}

add_industry_excluding_groups <- function(panel) {
  included_groups <- setdiff(
    sort(unique(panel$grupo_rev4_homologado[panel$nivel_panel == "subrama_industrial"])),
    excluded_industry_groups
  )

  included_subramas <- panel %>%
    filter(
      nivel_panel == "subrama_industrial",
      grupo_rev4_homologado %in% included_groups
    )

  if (nrow(included_subramas) == 0) {
    stop("No hay subramas para construir el agregado industrial excluyente.")
  }

  additive_cols <- intersect(
    c(
      "vbp_pp",
      "vbp_pb",
      "vab_pp",
      "vab_pb",
      "vab_pb_estimado",
      "consumo_intermedio_estimado",
      "consumo_intermedio",
      "remuneraciones",
      "costo_laboral",
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
      "capital_variable_adelantado",
      "capital_circulante_constante_adelantado",
      "capital_circulante_adelantado",
      "capital_total_adelantado",
      "ganancia_pb",
      "ganancia_pp",
      "excedente_bruto",
      "vab_bcu_corriente",
      "vab_bcu_constante_fuente"
    ),
    names(panel)
  )

  aggregate <- included_subramas %>%
    group_by(anno) %>%
    summarise(
      across(all_of(additive_cols), sum_present),
      bcu_constante_2005_agregado = sum_present(vab_bcu_corriente / deflactor_2005),
      epoca = collapse_present(epoca),
      ciiu_version = collapse_present(ciiu_version),
      fuente_base_bcu = collapse_present(fuente_base_bcu),
      metodo_empalme_bcu = collapse_present(metodo_empalme_bcu),
      codigos_bcu_deflactor = collapse_present(codigos_bcu_deflactor),
      dato_preliminar_bcu = any(dato_preliminar_bcu, na.rm = TRUE),
      codigos_capital_fuente = collapse_present(codigos_capital_fuente),
      archivos_capital_fuente = collapse_present(archivos_capital_fuente),
      codigos_fuente_incluidos = collapse_present(codigos_fuente_incluidos),
      divisiones_publicadas_incluidas =
        collapse_present(divisiones_publicadas_incluidas),
      .groups = "drop"
    ) %>%
    mutate(
      nivel_panel = industry_excluding_level,
      seccion = industry_excluding_section,
      grupo_rev4_homologado = NA_character_,
      descripcion_nivel = industry_excluding_description,
      # DECISION: This level is not present as a source row. It is a derived
      # aggregate built from Rev.4-compatible manufacturing subbranches,
      # excluding paper/printing and coke/petroleum refining. Profit rates are
      # recalculated from aggregate profits and aggregate advanced capital,
      # never averaged from subbranch rates.
      deflactor_vab_bcu_2005 =
        safe_divide(vab_bcu_corriente, bcu_constante_2005_agregado),
      deflactor_2005 = deflactor_vab_bcu_2005,
      fuente_deflactor = "bcu_indice_implicito_vab_agregado_subramas",
      calidad_deflactor_bcu =
        "agregado_subramas_excluye_papel_coque_refinacion",
      nota_deflactor_bcu = paste(
        "Agregado desde subramas EAAE-BCU homologadas, excluyendo",
        paste(excluded_industry_groups, collapse = " y "),
        ". En tramos con proxies BCU amplios conserva las advertencias de",
        "las subramas componentes."
      ),
      metodo_capital_eaae =
        "agregado_subramas_industriales_excluye_papel_coque_refinacion",
      metodo_stock_capital = if_else(
        anno %in% c(2002L, 2011L),
        "suma_stock_imputado_subramas_incluidas",
        "suma_stock_original_subramas_incluidas"
      ),
      metodo_consumo_capital_fijo =
        "suma_consumo_capital_fijo_original_subramas_incluidas",
      calidad_capital_eaae = if_else(
        anno %in% c(2002L, 2011L),
        "agregado_con_stock_imputado",
        "directo_agregado"
      ),
      rotacion_calibrada_sobre_6_6 =
        safe_divide(costo_laboral + consumo_intermedio, capital_circulante_adelantado),
      part_salarial = safe_divide(remuneraciones, vab_pp),
      productividad = safe_divide(vab_pp, puestos_trabajo),
      tasa_ganancia_pb = safe_divide(ganancia_pb, capital_total_adelantado),
      tasa_ganancia_pp = safe_divide(ganancia_pp, capital_total_adelantado),
      participacion_vab_pp_rama_c = NA_real_,
      tipo_homologacion = "agregado_derivado_desde_subramas_rev4_compatibles",
      calidad_homologacion = "media",
      notas_homologacion = paste(
        "Agregado industrial derivado que suma subramas homologadas Rev.4",
        "compatibles y excluye 17_18_papel_impresion y 19_refinacion."
      )
    ) %>%
    select(-bcu_constante_2005_agregado)

  bind_rows(panel, aggregate)
}

add_constant_values <- function(panel) {
  monetary_cols <- intersect(
    eaae_value_cols,
    names(panel)
  )
  for (col in monetary_cols) {
    panel[[paste0(col, "_constante_2005")]] <- safe_divide(
      panel[[col]],
      panel$deflactor_2005
    )
  }
  panel
}

validate_output <- function(panel) {
  expected_rows <- 24 * (1 + 1 + 1 + 10)
  if (nrow(panel) != expected_rows) {
    stop("Cantidad inesperada de filas: ", nrow(panel), "; esperado: ", expected_rows)
  }
  duplicated_keys <- panel %>%
    count(anno, nivel_panel, grupo_rev4_homologado, name = "n") %>%
    filter(n > 1)
  if (nrow(duplicated_keys) > 0) {
    stop("Hay claves duplicadas en el panel integrado.")
  }
  if (any(is.na(panel$deflactor_2005))) {
    missing <- panel %>%
      filter(is.na(deflactor_2005)) %>%
      distinct(anno, nivel_panel, grupo_rev4_homologado)
    stop("Hay filas sin deflactor: ", paste(capture.output(print(missing)), collapse = " "))
  }
  missing_profit_inputs <- panel %>%
    filter(
      is.na(vab_pp) |
        is.na(remuneraciones) |
        is.na(consumo_capital_fijo) |
        is.na(stock_capital_imputado)
    )
  if (nrow(missing_profit_inputs) > 0) {
    stop("Hay filas sin insumos basicos para tasa de ganancia.")
  }
  if (any(is.na(panel$rotacion_calibrada_sobre_6_6))) {
    missing_rotation <- panel %>%
      filter(is.na(rotacion_calibrada_sobre_6_6)) %>%
      distinct(nivel_panel, grupo_rev4_homologado, descripcion_nivel)
    stop(
      "Hay filas sin rotacion calibrada Damodaran: ",
      paste(capture.output(print(missing_rotation)), collapse = " ")
    )
  }
  if ("rotacion" %in% names(panel)) {
    stop("La columna rotacion no debe exportarse en el panel integrado.")
  }
}

main <- function() {
  eaae_panel <- build_eaae_rows()
  bcu_deflators <- build_bcu_deflators()

  output <- eaae_panel %>%
    add_deflators(bcu_deflators) %>%
    add_rotation_calibration() %>%
    add_industry_excluding_groups() %>%
    add_constant_values() %>%
    arrange(
      anno,
      factor(
        nivel_panel,
        levels = c(
          "economia_total",
          "industria_total",
          "industria_sin_papel_coque_refinacion",
          "subrama_industrial"
        )
      ),
      grupo_rev4_homologado
    ) %>%
    select(
      anno,
      nivel_panel,
      seccion,
      grupo_rev4_homologado,
      descripcion_nivel,
      epoca,
      ciiu_version,
      rotacion_calibrada_sobre_6_6,
      any_of(eaae_value_cols),
      starts_with("vbp_pp_constante_2005"),
      starts_with("vbp_pb_constante_2005"),
      starts_with("vab_pp_constante_2005"),
      starts_with("vab_pb_constante_2005"),
      starts_with("vab_pb_estimado_constante_2005"),
      starts_with("consumo_intermedio_estimado_constante_2005"),
      starts_with("consumo_intermedio_constante_2005"),
      starts_with("remuneraciones_constante_2005"),
      starts_with("costo_laboral_constante_2005"),
      starts_with("consumo_capital_fijo_constante_2005"),
      starts_with("stock_capital_imputado_constante_2005"),
      starts_with("capital_total_adelantado_constante_2005"),
      starts_with("ganancia_pb_constante_2005"),
      starts_with("ganancia_pp_constante_2005"),
      starts_with("tasa_ganancia_pb_constante_2005"),
      starts_with("tasa_ganancia_pp_constante_2005"),
      starts_with("productividad_constante_2005"),
      deflactor_vab_bcu_2005,
      deflactor_2005,
      fuente_deflactor,
      fuente_base_bcu,
      metodo_empalme_bcu,
      calidad_deflactor_bcu,
      codigos_bcu_deflactor,
      dato_preliminar_bcu,
      nota_deflactor_bcu,
      vab_bcu_corriente,
      vab_bcu_constante_fuente,
      metodo_capital_eaae,
      metodo_stock_capital,
      metodo_consumo_capital_fijo,
      calidad_capital_eaae,
      codigos_capital_fuente,
      archivos_capital_fuente,
      participacion_vab_pp_rama_c,
      codigos_fuente_incluidos,
      divisiones_publicadas_incluidas,
      tipo_homologacion,
      calidad_homologacion,
      notas_homologacion
    )

  validate_output(output)
  readr::write_csv(output, output_path, na = "")
  message("Archivo generado: ", output_path)
  message("Filas: ", nrow(output), " | Columnas: ", ncol(output))
}

main()
