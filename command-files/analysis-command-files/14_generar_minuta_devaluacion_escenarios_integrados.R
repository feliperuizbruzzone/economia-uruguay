#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(readxl)
  library(scales)
  library(stringr)
  library(tibble)
  library(tidyr)
})

date_prefix <- Sys.getenv("EAAE_OUTPUT_DATE", unset = format(Sys.Date(), "%Y%m%d"))

analysis_dir <- file.path("data", "analysis-data")
docs_dir <- "docs"
figures_dir <- file.path("output", "figures", paste0("devaluacion_escenarios_integrados_", date_prefix))

latest_file <- function(pattern) {
  files <- Sys.glob(pattern)
  if (length(files) == 0) {
    stop("No files found for pattern: ", pattern)
  }
  sort(files)[[length(files)]]
}

latest_file_optional <- function(pattern) {
  files <- Sys.glob(pattern)
  if (length(files) == 0) {
    return(NA_character_)
  }
  sort(files)[[length(files)]]
}

fmt_pct <- function(x, digits = 1) {
  ifelse(
    is.na(x),
    "",
    paste0(trimws(format(round(x, digits), big.mark = ".", decimal.mark = ",")), "%")
  )
}

fmt_delta <- function(x, digits = 1) {
  ifelse(
    is.na(x),
    "",
    paste0(
      ifelse(x > 0, "+", ""),
      trimws(format(round(x, digits), big.mark = ".", decimal.mark = ","))
    )
  )
}

fmt_num <- function(x, digits = 1) {
  ifelse(
    is.na(x),
    "",
    trimws(format(round(x, digits), big.mark = ".", decimal.mark = ","))
  )
}

safe_pct_ratio <- function(numerator, denominator) {
  ifelse(
    is.na(numerator) | is.na(denominator) | denominator == 0,
    NA_real_,
    numerator / denominator * 100
  )
}

md_table <- function(data) {
  data <- as.data.frame(data, stringsAsFactors = FALSE)
  if (ncol(data) == 0) {
    return("")
  }
  data[] <- lapply(data, function(col_i) {
    col_i <- as.character(col_i)
    col_i <- str_replace_all(col_i, "\\|", "\\\\|")
    str_replace_all(col_i, "[\r\n]+", " ")
  })

  header <- paste0("| ", paste(names(data), collapse = " | "), " |")
  separator <- paste0("| ", paste(rep("---", ncol(data)), collapse = " | "), " |")
  rows <- apply(data, 1, function(row_i) {
    paste0("| ", paste(row_i, collapse = " | "), " |")
  })
  paste(c(header, separator, rows), collapse = "\n")
}

fig_rel <- function(path) {
  paste0("../", path)
}

section_value <- function(data, seccion, variable) {
  data %>%
    filter(.data$seccion == !!seccion) %>%
    pull({{ variable }})
}

scenario_value <- function(data, escenario, variable) {
  data %>%
    filter(.data$escenario == !!escenario) %>%
    pull({{ variable }})
}

input_xlsx <- latest_file(file.path(
  analysis_dir,
  "*_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx"
))
coef_source_xlsx <- latest_file_optional(file.path(
  "data",
  "input-data",
  "mussi",
  "*segmentos-dos-escenarios.xlsx"
))
coeficientes_path <- latest_file(file.path(
  "data",
  "input-data",
  "mussi",
  "*-coeficientes-efecto-devaluacion.csv"
))
tipo_cambio_source_csv <- file.path(
  analysis_dir,
  "20260812-exportaciones-manufactura-uruguay.csv"
)

output_md <- file.path(
  docs_dir,
  paste0(date_prefix, "_resultados_devaluacion_escenarios_integrados.md")
)

dir.create(docs_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)
unlink(Sys.glob(file.path(figures_dir, "*.png")))

scenario_specs <- tibble::tribble(
  ~sheet, ~escenario, ~titulo, ~descripcion, ~vbp_label,
  "Escenario 1 - Comercio Exterior",
  "comercio_exterior",
  "Escenario 1 - Comercio exterior",
  paste(
    "La apropiación de riqueza vía sobrevaluación de la moneda se aplica a",
    "los componentes importados de costos y capital y a la parte exportada de",
    "la producción. Por tanto, recoge el efecto directo de importaciones y",
    "exportaciones sobre la masa de ganancia."
  ),
  "VBP/exportador",
  "Escenario 2 - Bienes Transables",
  "bienes_transables",
  "Escenario 2 - Bienes transables",
  paste(
    "La apropiación de riqueza vía sobrevaluación alcanza al conjunto de",
    "mercancías cuyos precios internos se rigen por precios internacionales,",
    "aunque sean producidas localmente y vendidas en el mercado interno.",
    "Así, incorpora la revaluación de producción local transable y su efecto",
    "sobre la masa de ganancia."
  ),
  "VBP/transable"
)

required_sheets <- c("escenario-inicial", scenario_specs$sheet)
missing_sheets <- setdiff(required_sheets, excel_sheets(input_xlsx))
if (length(missing_sheets) > 0) {
  stop("Missing sheets in workbook: ", paste(missing_sheets, collapse = ", "))
}

metodologia_xlsx <- read_excel(input_xlsx, sheet = "metodología")
tipo_cambio_xlsx <- read_excel(input_xlsx, sheet = "tipo-cambio")
coeficientes_xlsx <- read_csv(coeficientes_path, show_col_types = FALSE)

section_labels <- c(
  "industria-total" = "Industria total",
  "exportadora" = "Segmento exportador",
  "mercado-interno" = "Mercado interno"
)

ramas_exportadoras <- c(
  "10: Elaboración de productos alimenticios",
  "11 y 12: Elaboración de bebidas y elaboración de productos de tabaco",
  "13: Fabricación de productos textiles",
  "15: Fabricación de cueros y productos conexos",
  "16: Producción de madera y fabricación de productos de madera y corcho, excepto muebles",
  "17: Fabricación de papel y de los productos de papel",
  "22: Fabricación de productos de caucho y plástico"
)

ramas_mercado_interno <- c(
  "14: Fabricación de prendas de vestir",
  "18: Actividades de impresión y reproducción de grabaciones",
  "20: Fabricación de sustancias y productos químicos",
  "21: Fabricación de productos farmacéuticos, sustancias químicas medicinales y de productos botánicos",
  "23: Fabricación de otros productos minerales no metálicos",
  "24: Fabricación de metales comunes",
  "25: Fabricación de productos derivados del metal, excepto maquinaria y equipo",
  "26 y 27: Fabricación de los productos informáticos, electrónicos y ópticos. Fabricación de equipo eléctrico",
  "28: Fabricación de maquinaria y equipo n.c.p",
  "29 y 30: Fabricación de vehículos automotores, remolques y semirremolques. Fabricación de otros tipos de equipo de transporte",
  "31: Fabricación de muebles",
  "32: Otras industrias manufactureras",
  "33: Reparación e instalación de la maquinaria y equipo"
)

caption_fuente <- paste(
  "Fuente: elaboración propia en base a EAAE, microdatos CIU y Oyanthabal,",
  "con base en metodología de Iñigo Carrera (2007)."
)

blue_palette <- c(
  navy = "#0B1F3A",
  deep = "#173B63",
  main = "#2F5F8F",
  steel = "#5F86AD",
  soft = "#9DB8D2",
  pale = "#DCE8F3",
  grey = "#6C7785",
  grid = "#D9E1E8"
)

scenario_colors <- c(
  "Escenario 1 - Comercio exterior" = blue_palette[["deep"]],
  "Escenario 2 - Bienes transables" = blue_palette[["steel"]]
)

section_colors <- c(
  "Industria total" = blue_palette[["navy"]],
  "Segmento exportador" = blue_palette[["main"]],
  "Mercado interno" = blue_palette[["soft"]]
)

concept_colors <- c(
  Cesión = blue_palette[["soft"]],
  Apropiación = blue_palette[["deep"]]
)

theme_report <- theme_minimal(base_size = 11) +
  theme(
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA),
    panel.grid.major = element_line(color = blue_palette[["grid"]], linewidth = 0.28),
    panel.grid.minor = element_blank(),
    plot.title.position = "plot",
    plot.title = element_text(color = blue_palette[["navy"]], face = "bold", size = 13),
    plot.subtitle = element_text(color = blue_palette[["grey"]], size = 10.5),
    plot.caption = element_text(color = blue_palette[["grey"]], size = 8.5, hjust = 0),
    plot.caption.position = "plot",
    axis.title = element_text(color = blue_palette[["grey"]], size = 9.5),
    axis.text = element_text(color = blue_palette[["navy"]], size = 9),
    strip.text = element_text(color = blue_palette[["navy"]], face = "bold"),
    legend.position = "bottom",
    legend.title = element_text(color = blue_palette[["grey"]], size = 9),
    legend.text = element_text(color = blue_palette[["navy"]], size = 9)
  )

read_scenario <- function(sheet_name) {
  spec <- scenario_specs %>%
    filter(.data$sheet == !!sheet_name)

  read_excel(input_xlsx, sheet = sheet_name) %>%
    filter(!is.na(.data$anno), !is.na(.data$seccion)) %>%
    mutate(
      escenario = spec$escenario,
      escenario_label = spec$titulo,
      escenario_sheet = spec$sheet,
      descripcion_escenario = spec$descripcion,
      vbp_label = spec$vbp_label,
      seccion_label = recode(.data$seccion, !!!section_labels),
      seccion_label = factor(.data$seccion_label, levels = unname(section_labels)),
      # DECISION: the analytical sign is inverted relative to the devaluation
      # workbook. Positive values mean the initial overvalued exchange-rate
      # setting over-perceives profit relative to parity; negative values mean
      # profit left unperceived under overvaluation.
      saldo_sobrevaluacion_ganancia_pb =
        .data$ganancia_pb - .data$ganancia_pb_devaluacion,
      saldo_sobrevaluacion_ganancia_pb_desp_intereses =
        .data$ganancia_pb_desp_intereses - .data$ganancia_pb_desp_intereses_devaluacion,
      # DECISION: the relative chart normalizes the overvaluation balance by
      # the initial profit mass, not by the counterfactual moment-2 profit.
      # This reads the balance as a share of observed profit and avoids
      # unstable ratios if the counterfactual profit gets close to zero.
      saldo_sobrevaluacion_ganancia_pb_pct = safe_pct_ratio(
        .data$ganancia_pb - .data$ganancia_pb_devaluacion,
        .data$ganancia_pb
      ),
      delta_ganancia_pb_escenario =
        .data$ganancia_pb_devaluacion - .data$ganancia_pb,
      delta_ganancia_pb_desp_intereses_escenario =
        .data$ganancia_pb_desp_intereses_devaluacion - .data$ganancia_pb_desp_intereses,
      saldo_vbp = -.data$delta_vbp_pp,
      saldo_consumo_intermedio = .data$delta_consumo_intermedio_estimado,
      saldo_remuneraciones = .data$delta_remuneraciones,
      saldo_consumo_capital_fijo = .data$delta_consumo_capital_fijo,
      saldo_intereses = .data$delta_intereses_industria_pesos
    )
}

escenarios <- bind_rows(lapply(scenario_specs$sheet, read_scenario))

clean_coef_source <- function(source) {
  source <- str_squish(as.character(source))
  source <- str_replace(source, "^[^;]+;\\s*", "")
  parts <- str_split(source, ";\\s*", simplify = FALSE)

  vapply(parts, function(parts_i) {
    parts_i <- parts_i[!is.na(parts_i) & parts_i != ""]
    if (length(parts_i) >= 3) {
      paste(parts_i[3:length(parts_i)], collapse = "; ")
    } else if (length(parts_i) > 0) {
      paste0(
        paste(str_to_sentence(parts_i), collapse = "; "),
        "; fuente específica no explicitada en celda."
      )
    } else {
      "Fuente específica no explicitada en celda."
    }
  }, character(1))
}

coeficientes_sources <- coeficientes_xlsx %>%
  transmute(
    escenario_sheet = .data$escenario_nombre,
    seccion = .data$seccion,
    variable_join = .data$Variable,
    comentario_coeficiente = .data$Comentario,
    fuente_coeficiente = clean_coef_source(.data$Fuente)
  )

if (nrow(escenarios) != 30L) {
  stop("Se esperaban 30 filas de escenarios: 2 escenarios x 5 años x 3 secciones.")
}

required_profit_cols <- c(
  "ganancia_pb",
  "ganancia_pb_devaluacion",
  "ganancia_pb_desp_intereses",
  "ganancia_pb_desp_intereses_devaluacion"
)
if (any(escenarios %>% select(all_of(required_profit_cols)) %>% is.na())) {
  stop("Hay faltantes en las variables de masa de ganancia requeridas.")
}

source_assumptions_table <- metodologia_xlsx %>%
  filter(.data$seccion %in% c("fuentes", "decision", "formula", "devaluacion")) %>%
  filter(!str_detect(.data$item, "^Escenario ")) %>%
  mutate(
    detalle = str_replace_all(.data$detalle, " \\.", "."),
    detalle = str_replace_all(.data$detalle, "parametros", "parámetros")
  ) %>%
  transmute(
    `Bloque` = recode(
      .data$seccion,
      fuentes = "Fuente",
      decision = "Decisión",
      formula = "Fórmula",
      devaluacion = "Devaluación"
    ),
    `Ítem` = .data$item,
    `Criterio documentado` = .data$detalle
  ) %>%
  bind_rows(tibble::tibble(
    `Bloque` = c("Fuente", "Fuente"),
    `Ítem` = c("archivo de trabajo de coeficientes", "tipo de cambio comercial/paridad"),
    `Criterio documentado` = c(
      ifelse(
        is.na(coef_source_xlsx),
        "Archivo de trabajo de dos escenarios no localizado en data/input-data/mussi al momento de regenerar la minuta.",
        paste0(
          "Archivo de trabajo: `",
          coef_source_xlsx,
          "`. Las fuentes sustantivas de cada coeficiente se toman de su columna `Fuente` y se reportan en las tablas por escenario."
        )
      ),
      paste0(
        "La hoja `tipo-cambio` del XLSX se construye desde `",
        tipo_cambio_source_csv,
        "`, con tipo de cambio comercial y tipo de cambio de paridad."
      )
    )
  ))

factor_table <- tipo_cambio_xlsx %>%
  transmute(
    `Año` = .data$anio,
    `Tipo de cambio comercial` = fmt_num(.data$tipo_cambio_comercial_pesos_usd, 2),
    `Tipo de cambio paridad` = fmt_num(.data$tipo_cambio_paridad_pesos_usd, 2),
    `Factor de devaluación` = fmt_pct(
      ((.data$tipo_cambio_paridad_pesos_usd / .data$tipo_cambio_comercial_pesos_usd) - 1) * 100,
      1
    )
  )

factor_summary <- tipo_cambio_xlsx %>%
  summarise(
    promedio = mean((.data$tipo_cambio_paridad_pesos_usd / .data$tipo_cambio_comercial_pesos_usd) - 1, na.rm = TRUE),
    minimo = min((.data$tipo_cambio_paridad_pesos_usd / .data$tipo_cambio_comercial_pesos_usd) - 1, na.rm = TRUE),
    maximo = max((.data$tipo_cambio_paridad_pesos_usd / .data$tipo_cambio_comercial_pesos_usd) - 1, na.rm = TRUE)
  )

read_effect_demo <- function(source_path) {
  if (is.na(source_path) || !"Efecto TCC - TCP" %in% excel_sheets(source_path)) {
    return(tibble())
  }

  raw <- read_excel(
    source_path,
    sheet = "Efecto TCC - TCP",
    range = "A2:K5",
    col_names = FALSE,
    .name_repair = "minimal"
  )
  names(raw) <- paste0("col", seq_along(raw))

  raw[-1, , drop = FALSE] %>%
    transmute(
      anio = as.numeric(.data$col1),
      variable = as.character(.data$col2),
      monto_base = as.numeric(.data$col3),
      tcc = as.numeric(.data$col4),
      tcp = as.numeric(.data$col5),
      factor_devaluacion = as.numeric(.data$col6),
      delta_monto = as.numeric(.data$col7),
      concepto = as.character(.data$col8),
      ganancia_inicial = as.numeric(.data$col10),
      pct_sobre_ganancia = as.numeric(.data$col11)
    ) %>%
    filter(!is.na(.data$variable))
}

effect_demo <- read_effect_demo(coef_source_xlsx)
effect_demo_table <- effect_demo %>%
  transmute(
    `Año` = .data$anio,
    `Variable ejemplo` = recode(.data$variable, Expo = "VBP/exportaciones"),
    `Monto base` = fmt_num(.data$monto_base, 1),
    `Factor devaluación` = fmt_pct(.data$factor_devaluacion * 100, 1),
    `Concepto` = .data$concepto,
    `Delta monetario` = fmt_delta(.data$delta_monto, 1),
    `% sobre ganancia inicial` = paste0(fmt_delta(.data$pct_sobre_ganancia * 100, 1), "%")
  )

saldo_labels <- c(
  saldo_sobrevaluacion_ganancia_pb = "Ganancia pb",
  saldo_sobrevaluacion_ganancia_pb_desp_intereses = "Ganancia pb post intereses"
)

component_labels <- c(
  saldo_vbp = "Menor valorización del VBP",
  saldo_consumo_intermedio = "Ahorro en consumo intermedio",
  saldo_remuneraciones = "Ahorro en remuneraciones",
  saldo_consumo_capital_fijo = "Ahorro en consumo capital fijo",
  saldo_intereses = "Ahorro en intereses pagados"
)

summary_by_scenario_section <- escenarios %>%
  group_by(.data$escenario, .data$escenario_label, .data$seccion, .data$seccion_label) %>%
  summarise(
    ganancia_pb_base_prom_miles_mill = mean(.data$ganancia_pb, na.rm = TRUE) / 1e9,
    ganancia_pb_escenario_prom_miles_mill = mean(.data$ganancia_pb_devaluacion, na.rm = TRUE) / 1e9,
    saldo_pb_prom_miles_mill = mean(.data$saldo_sobrevaluacion_ganancia_pb, na.rm = TRUE) / 1e9,
    saldo_post_intereses_prom_miles_mill =
      mean(.data$saldo_sobrevaluacion_ganancia_pb_desp_intereses, na.rm = TRUE) / 1e9,
    ganancia_pb_base_2024_miles_mill = .data$ganancia_pb[.data$anno == 2024] / 1e9,
    ganancia_pb_escenario_2024_miles_mill = .data$ganancia_pb_devaluacion[.data$anno == 2024] / 1e9,
    saldo_pb_2024_miles_mill = .data$saldo_sobrevaluacion_ganancia_pb[.data$anno == 2024] / 1e9,
    saldo_post_intereses_2024_miles_mill =
      .data$saldo_sobrevaluacion_ganancia_pb_desp_intereses[.data$anno == 2024] / 1e9,
    .groups = "drop"
  )

industry_summary <- summary_by_scenario_section %>%
  filter(.data$seccion == "industria-total")

industry_saldo_long <- escenarios %>%
  filter(.data$seccion == "industria-total") %>%
  select(
    "anno",
    "escenario_label",
    all_of(names(saldo_labels))
  ) %>%
  pivot_longer(
    cols = all_of(names(saldo_labels)),
    names_to = "medida",
    values_to = "saldo"
  ) %>%
  mutate(
    medida = recode(.data$medida, !!!saldo_labels),
    saldo_miles_mill = .data$saldo / 1e9
  )

factor_plot_data <- tipo_cambio_xlsx %>%
  transmute(
    anio = .data$anio,
    factor_devaluacion_pct =
      ((.data$tipo_cambio_paridad_pesos_usd / .data$tipo_cambio_comercial_pesos_usd) - 1) * 100
  )

coeficientes_plot_data <- escenarios %>%
  distinct(
    .data$escenario,
    .data$escenario_label,
    .data$seccion_label,
    .data$incidencia_vbp_pp,
    .data$incidencia_consumo_intermedio_estimado,
    .data$incidencia_remuneraciones,
    .data$incidencia_consumo_capital_fijo,
    .data$incidencia_intereses_industria_pesos,
    .data$incidencia_stock_capital_imputado
  ) %>%
  pivot_longer(
    cols = starts_with("incidencia_"),
    names_to = "variable_codigo",
    values_to = "incidencia"
  ) %>%
  mutate(
    variable = case_when(
      .data$variable_codigo == "incidencia_vbp_pp" &
        .data$escenario == "comercio_exterior" ~ "VBP/exportador",
      .data$variable_codigo == "incidencia_vbp_pp" &
        .data$escenario == "bienes_transables" ~ "VBP/transable",
      .data$variable_codigo == "incidencia_consumo_intermedio_estimado" ~
        "Consumo intermedio",
      .data$variable_codigo == "incidencia_remuneraciones" ~ "Masa salarial",
      .data$variable_codigo == "incidencia_consumo_capital_fijo" ~
        "Consumo capital fijo",
      .data$variable_codigo == "incidencia_intereses_industria_pesos" ~
        "Intereses pagados",
      .data$variable_codigo == "incidencia_stock_capital_imputado" ~
        "Stock imputado",
      TRUE ~ .data$variable_codigo
    ),
    variable = factor(.data$variable, levels = c(
      "VBP/exportador",
      "VBP/transable",
      "Consumo intermedio",
      "Masa salarial",
      "Consumo capital fijo",
      "Stock imputado",
      "Intereses pagados"
    )),
    incidencia_pct = .data$incidencia * 100
  )

fig_factor_path <- file.path(figures_dir, "00_factor_devaluacion_2020_2024.png")
fig_coef_path <- file.path(figures_dir, "00_coeficientes_incidencia_escenarios.png")
fig0_path <- file.path(figures_dir, "00_esquema_efecto_tcc_tcp.png")
fig1_path <- file.path(figures_dir, "01_industria_total_saldo_sobrevaluacion_ganancia.png")
fig1_pct_path <- file.path(figures_dir, "01b_saldo_pct_ganancia_inicial_por_seccion.png")
fig2_path <- file.path(figures_dir, "02_industria_total_componentes_saldo_2024.png")

ggplot(factor_plot_data, aes(
  x = .data$anio,
  y = .data$factor_devaluacion_pct
)) +
  geom_line(color = blue_palette[["main"]], linewidth = 0.9) +
  geom_point(color = blue_palette[["main"]], size = 2.2) +
  geom_text(
    aes(label = fmt_pct(.data$factor_devaluacion_pct, 1)),
    vjust = -0.75,
    size = 3.2,
    color = blue_palette[["navy"]]
  ) +
  scale_x_continuous(breaks = sort(unique(factor_plot_data$anio))) +
  scale_y_continuous(labels = label_percent(scale = 1), expand = expansion(mult = c(0.05, 0.18))) +
  labs(
    title = "Brecha cambiaria modelada",
    subtitle = "Factor anual de cierre entre tipo de cambio comercial y tipo de cambio de paridad",
    x = NULL,
    y = "Factor de devaluación",
    caption = caption_fuente
  ) +
  theme_report
ggsave(fig_factor_path, width = 8.5, height = 4.8, dpi = 160)

ggplot(coeficientes_plot_data, aes(
  x = .data$variable,
  y = .data$seccion_label,
  fill = .data$incidencia_pct
)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = fmt_pct(.data$incidencia_pct, 1)), size = 2.8) +
  facet_wrap(vars(.data$escenario_label), nrow = 1) +
  scale_fill_gradient(
    low = blue_palette[["pale"]],
    high = blue_palette[["deep"]],
    labels = label_percent(scale = 1)
  ) +
  labs(
    title = "Coeficientes de incidencia por escenario y segmento",
    subtitle = "Proporción de cada variable expuesta al cierre de brecha TCC-TCP",
    x = NULL,
    y = NULL,
    fill = "Incidencia",
    caption = caption_fuente
  ) +
  theme_report +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
ggsave(fig_coef_path, width = 12, height = 5.6, dpi = 160)

if (nrow(effect_demo) > 0) {
  effect_demo_plot <- effect_demo %>%
    mutate(
      variable = recode(.data$variable, Expo = "VBP/exportaciones"),
      pct_sobre_ganancia = .data$pct_sobre_ganancia * 100
    )

  ggplot(effect_demo_plot, aes(
    x = .data$variable,
    y = .data$pct_sobre_ganancia,
    fill = .data$concepto
  )) +
    geom_hline(yintercept = 0, color = "grey35", linewidth = 0.35) +
    geom_col(width = 0.62) +
    geom_text(
      aes(label = paste0(fmt_delta(.data$pct_sobre_ganancia, 1), "%")),
      vjust = ifelse(effect_demo_plot$pct_sobre_ganancia >= 0, -0.35, 1.25),
      size = 3.3
    ) +
    scale_fill_manual(values = concept_colors) +
    labs(
      title = "Esquema de lectura TCC-TCP: cesión y apropiación",
      subtitle = "Ejemplo de la hoja Efecto TCC - TCP: efecto relativo a una ganancia inicial",
      x = NULL,
      y = "% sobre ganancia inicial",
      fill = NULL,
      caption = "Fuente: hoja Efecto TCC - TCP del archivo de trabajo de coeficientes."
    ) +
    theme_report
  ggsave(fig0_path, width = 8.5, height = 4.8, dpi = 160)
}

ggplot(industry_saldo_long, aes(
  x = .data$anno,
  y = .data$saldo_miles_mill,
  color = .data$escenario_label
)) +
  geom_hline(yintercept = 0, color = "grey35", linewidth = 0.35) +
  geom_line(linewidth = 0.85) +
  geom_point(size = 2) +
  facet_wrap(vars(.data$medida), nrow = 1, scales = "free_y") +
  scale_x_continuous(breaks = sort(unique(industry_saldo_long$anno))) +
  scale_color_manual(values = scenario_colors) +
  labs(
    title = "Industria total: saldo de ganancia asociado a la sobrevaluación",
    subtitle = "Saldo = ganancia observada inicial - ganancia contrafactual con cierre de brecha",
    x = NULL,
    y = "Miles de millones de pesos corrientes",
    color = NULL,
    caption = caption_fuente
  ) +
  theme_report
ggsave(fig1_path, width = 10, height = 5.2, dpi = 160)

saldo_pct_integrated <- escenarios %>%
  transmute(
    anno = .data$anno,
    escenario_label = .data$escenario_label,
    seccion_label = .data$seccion_label,
    saldo_pct = .data$saldo_sobrevaluacion_ganancia_pb_pct
  )

saldo_pct_integrated_last <- saldo_pct_integrated %>%
  group_by(.data$escenario_label, .data$seccion_label) %>%
  filter(.data$anno == max(.data$anno, na.rm = TRUE)) %>%
  ungroup()

ggplot(saldo_pct_integrated, aes(
  x = .data$anno,
  y = .data$saldo_pct,
  color = .data$escenario_label
)) +
  geom_hline(yintercept = 0, color = "grey35", linewidth = 0.35) +
  geom_line(linewidth = 0.85) +
  geom_point(size = 1.8) +
  geom_text(
    data = saldo_pct_integrated_last,
    aes(label = paste0(fmt_delta(.data$saldo_pct, 1), "%")),
    hjust = -0.08,
    size = 2.9,
    show.legend = FALSE
  ) +
  facet_wrap(vars(.data$seccion_label), nrow = 1) +
  scale_x_continuous(
    breaks = sort(unique(saldo_pct_integrated$anno)),
    expand = expansion(mult = c(0.02, 0.2))
  ) +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  scale_color_manual(values = scenario_colors) +
  labs(
    title = "Saldo de sobrevaluación como proporción de la ganancia inicial",
    subtitle = "Saldo relativo = (ganancia inicial - ganancia momento 2) / ganancia inicial",
    x = NULL,
    y = "Porcentaje de la ganancia inicial",
    color = NULL,
    caption = caption_fuente
  ) +
  theme_report
ggsave(fig1_pct_path, width = 11.5, height = 5.4, dpi = 160)

industry_components_2024 <- escenarios %>%
  filter(.data$anno == 2024, .data$seccion == "industria-total") %>%
  select("escenario_label", all_of(names(component_labels))) %>%
  pivot_longer(
    cols = all_of(names(component_labels)),
    names_to = "componente",
    values_to = "valor"
  ) %>%
  mutate(
    componente = recode(.data$componente, !!!component_labels),
    componente = factor(.data$componente, levels = unname(component_labels)),
    valor_miles_mill = .data$valor / 1e9
  )

ggplot(industry_components_2024, aes(
  x = .data$componente,
  y = .data$valor_miles_mill,
  fill = .data$escenario_label
)) +
  geom_hline(yintercept = 0, color = "grey35", linewidth = 0.35) +
  geom_col(position = position_dodge(width = 0.75), width = 0.68) +
  scale_fill_manual(values = scenario_colors) +
  labs(
    title = "Industria total: componentes del saldo de sobrevaluación en 2024",
    subtitle = "VBP negativo indica ganancia dejada de percibir; costos positivos indican ahorro bajo sobrevaluación",
    x = NULL,
    y = "Miles de millones de pesos corrientes",
    fill = NULL,
    caption = caption_fuente
  ) +
  theme_report +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
ggsave(fig2_path, width = 10.5, height = 5.2, dpi = 160)

scenario_section <- function(scenario_id) {
  spec <- scenario_specs %>%
    filter(.data$escenario == !!scenario_id)
  data <- escenarios %>%
    filter(.data$escenario == !!scenario_id)

  saldo_long <- data %>%
    select(
      "anno",
      "seccion",
      "seccion_label",
      all_of(names(saldo_labels))
    ) %>%
    pivot_longer(
      cols = all_of(names(saldo_labels)),
      names_to = "medida",
      values_to = "saldo"
    ) %>%
    mutate(
      medida = recode(.data$medida, !!!saldo_labels),
      saldo_miles_mill = .data$saldo / 1e9
    )

  fig_saldo <- file.path(figures_dir, paste0("03_", scenario_id, "_saldo_ganancia_segmentos.png"))
  fig_saldo_pct <- file.path(figures_dir, paste0("03b_", scenario_id, "_saldo_pct_ganancia_inicial_segmentos.png"))
  fig_components <- file.path(figures_dir, paste0("04_", scenario_id, "_componentes_saldo_2024_segmentos.png"))

  ggplot(saldo_long, aes(x = .data$anno, y = .data$saldo_miles_mill, color = .data$seccion_label)) +
    geom_hline(yintercept = 0, color = "grey35", linewidth = 0.35) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 1.8) +
    facet_wrap(vars(.data$medida), nrow = 1, scales = "free_y") +
    scale_x_continuous(breaks = sort(unique(saldo_long$anno))) +
    scale_color_manual(values = section_colors) +
    labs(
      title = paste(spec$titulo, "- saldo de ganancia asociado a la sobrevaluación"),
      subtitle = "Saldo = ganancia observada inicial - ganancia contrafactual con cierre de brecha",
      x = NULL,
      y = "Miles de millones de pesos corrientes",
      color = NULL,
      caption = caption_fuente
    ) +
    theme_report
  ggsave(fig_saldo, width = 10.5, height = 5.2, dpi = 160)

  saldo_pct <- data %>%
    transmute(
      anno = .data$anno,
      seccion_label = .data$seccion_label,
      saldo_pct = .data$saldo_sobrevaluacion_ganancia_pb_pct
    )

  saldo_pct_last <- saldo_pct %>%
    group_by(.data$seccion_label) %>%
    filter(.data$anno == max(.data$anno, na.rm = TRUE)) %>%
    ungroup()

  ggplot(saldo_pct, aes(
    x = .data$anno,
    y = .data$saldo_pct,
    color = .data$seccion_label
  )) +
    geom_hline(yintercept = 0, color = "grey35", linewidth = 0.35) +
    geom_line(linewidth = 0.85) +
    geom_point(size = 1.9) +
    geom_text(
      data = saldo_pct_last,
      aes(label = paste0(fmt_delta(.data$saldo_pct, 1), "%")),
      hjust = -0.08,
      size = 3.1,
      show.legend = FALSE
    ) +
    scale_x_continuous(
      breaks = sort(unique(saldo_pct$anno)),
      expand = expansion(mult = c(0.02, 0.17))
    ) +
    scale_y_continuous(labels = label_percent(scale = 1)) +
    scale_color_manual(values = section_colors) +
    labs(
      title = paste(spec$titulo, "- saldo relativo sobre la ganancia inicial"),
      subtitle = "Saldo relativo = (ganancia inicial - ganancia momento 2) / ganancia inicial",
      x = NULL,
      y = "Porcentaje de la ganancia inicial",
      color = NULL,
      caption = caption_fuente
    ) +
    theme_report
  ggsave(fig_saldo_pct, width = 10.5, height = 5.2, dpi = 160)

  components_2024 <- data %>%
    filter(.data$anno == 2024) %>%
    select("seccion_label", all_of(names(component_labels))) %>%
    pivot_longer(
      cols = all_of(names(component_labels)),
      names_to = "componente",
      values_to = "valor"
    ) %>%
    mutate(
      componente = recode(.data$componente, !!!component_labels),
      componente = if_else(
        .data$componente == "Menor valorización del VBP",
        paste("Menor valorización", spec$vbp_label),
        as.character(.data$componente)
      ),
      componente = factor(.data$componente, levels = c(
        paste("Menor valorización", spec$vbp_label),
        "Ahorro en consumo intermedio",
        "Ahorro en remuneraciones",
        "Ahorro en consumo capital fijo",
        "Ahorro en intereses pagados"
      )),
      valor_miles_mill = .data$valor / 1e9
    )

  ggplot(components_2024, aes(
    x = .data$componente,
    y = .data$valor_miles_mill,
    fill = .data$seccion_label
  )) +
    geom_hline(yintercept = 0, color = "grey35", linewidth = 0.35) +
    geom_col(position = position_dodge(width = 0.75), width = 0.68) +
    scale_fill_manual(values = section_colors) +
    labs(
      title = paste(spec$titulo, "- componentes del saldo en 2024"),
      subtitle = "Valores positivos: sobrepercepción o ahorro bajo sobrevaluación; valores negativos: ganancia dejada de percibir",
      x = NULL,
      y = "Miles de millones de pesos corrientes",
      fill = NULL,
      caption = caption_fuente
    ) +
    theme_report +
    theme(axis.text.x = element_text(angle = 30, hjust = 1))
  ggsave(fig_components, width = 10.5, height = 5.2, dpi = 160)

  summary_table <- summary_by_scenario_section %>%
    filter(.data$escenario == !!scenario_id) %>%
    transmute(
      `Sección` = as.character(.data$seccion_label),
      `Ganancia base prom.` = fmt_num(.data$ganancia_pb_base_prom_miles_mill),
      `Ganancia escenario prom.` = fmt_num(.data$ganancia_pb_escenario_prom_miles_mill),
      `Saldo sobrevaluación prom.` = fmt_delta(.data$saldo_pb_prom_miles_mill),
      `Saldo post intereses prom.` = fmt_delta(.data$saldo_post_intereses_prom_miles_mill),
      `Ganancia base 2024` = fmt_num(.data$ganancia_pb_base_2024_miles_mill),
      `Ganancia escenario 2024` = fmt_num(.data$ganancia_pb_escenario_2024_miles_mill),
      `Saldo 2024` = fmt_delta(.data$saldo_pb_2024_miles_mill),
      `Saldo post intereses 2024` = fmt_delta(.data$saldo_post_intereses_2024_miles_mill)
    )

  coef_table <- data %>%
    distinct(
      seccion,
      seccion_label,
      incidencia_vbp_pp,
      incidencia_consumo_intermedio_estimado,
      incidencia_remuneraciones,
      incidencia_consumo_capital_fijo,
      incidencia_intereses_industria_pesos,
      incidencia_stock_capital_imputado
    ) %>%
    pivot_longer(
      cols = starts_with("incidencia_"),
      names_to = "variable_codigo",
      values_to = "incidencia"
    ) %>%
    mutate(
      variable_join = recode(
        .data$variable_codigo,
        incidencia_vbp_pp = "VBP",
        incidencia_consumo_intermedio_estimado = "Consumo intermedio",
        incidencia_remuneraciones = "Masa salarial",
        incidencia_consumo_capital_fijo = "Consumo de capital fijo",
        incidencia_intereses_industria_pesos = "Intereses",
        incidencia_stock_capital_imputado = "Stock capital imputado"
      ),
      efecto = case_when(
        .data$variable_codigo == "incidencia_vbp_pp" ~
          "Positivo: eleva el VBP valorizado al tipo de cambio de paridad",
        .data$variable_codigo == "incidencia_intereses_industria_pesos" ~
          "Negativo: aumenta intereses pagados y reduce la ganancia post intereses",
        .data$variable_codigo == "incidencia_stock_capital_imputado" ~
          "Negativo: aumenta capital adelantado; no entra en la masa de ganancia presentada",
        TRUE ~
          "Negativo: aumenta costos y reduce la masa de ganancia"
      ),
      variable = recode(
        .data$variable_join,
        VBP = spec$vbp_label,
        `Intereses` = "Intereses pagados",
        `Consumo de capital fijo` = "Consumo capital fijo"
      ),
      escenario_sheet = spec$sheet[[1]]
    ) %>%
    left_join(
      coeficientes_sources,
      by = c(
        "seccion",
        "variable_join",
        "escenario_sheet"
      )
    ) %>%
    transmute(
      `Sección` = as.character(.data$seccion_label),
      `Variable afectada` = .data$variable,
      `Incidencia` = fmt_pct(.data$incidencia * 100),
      `Efecto ante devaluación` = .data$efecto,
      `Fuente del coeficiente` = coalesce(
        .data$fuente_coeficiente,
        "Fuente del coeficiente no localizada en la tabla procesada."
      )
    ) %>%
    arrange(.data$`Sección`, .data$`Variable afectada`)

  summary_2024 <- summary_by_scenario_section %>%
    filter(.data$escenario == !!scenario_id)

  list(
    spec = spec,
    table = summary_table,
    coef_table = coef_table,
    figures = c(
      saldo = fig_saldo,
      saldo_pct = fig_saldo_pct,
      components = fig_components
    ),
    text = c(
      paste0(
        "En 2024, la industria total registra un saldo de sobrevaluación de ",
        fmt_delta(section_value(summary_2024, "industria-total", saldo_pb_2024_miles_mill)),
        " miles de millones de pesos corrientes en ganancia a precios básicos."
      ),
      paste0(
        "En el mismo año, el segmento exportador registra ",
        fmt_delta(section_value(summary_2024, "exportadora", saldo_pb_2024_miles_mill)),
        " y el segmento mercado interno registra ",
        fmt_delta(section_value(summary_2024, "mercado-interno", saldo_pb_2024_miles_mill)),
        " miles de millones."
      )
    )
  )
}

scenario_sections <- lapply(scenario_specs$escenario, scenario_section)
names(scenario_sections) <- scenario_specs$escenario

industry_table <- industry_summary %>%
  transmute(
    `Escenario` = .data$escenario_label,
    `Ganancia base prom.` = fmt_num(.data$ganancia_pb_base_prom_miles_mill),
    `Ganancia escenario prom.` = fmt_num(.data$ganancia_pb_escenario_prom_miles_mill),
    `Saldo sobrevaluación prom.` = fmt_delta(.data$saldo_pb_prom_miles_mill),
    `Saldo post intereses prom.` = fmt_delta(.data$saldo_post_intereses_prom_miles_mill),
    `Ganancia base 2024` = fmt_num(.data$ganancia_pb_base_2024_miles_mill),
    `Ganancia escenario 2024` = fmt_num(.data$ganancia_pb_escenario_2024_miles_mill),
    `Saldo 2024` = fmt_delta(.data$saldo_pb_2024_miles_mill),
    `Saldo post intereses 2024` = fmt_delta(.data$saldo_post_intereses_2024_miles_mill)
  )

component_table <- industry_components_2024 %>%
  mutate(
    escenario_label = as.character(.data$escenario_label)
  ) %>%
  select("escenario_label", "componente", "valor_miles_mill") %>%
  pivot_wider(names_from = "escenario_label", values_from = "valor_miles_mill") %>%
  transmute(
    `Componente` = as.character(.data$componente),
    `Escenario 1` = fmt_delta(.data$`Escenario 1 - Comercio exterior`),
    `Escenario 2` = fmt_delta(.data$`Escenario 2 - Bienes transables`)
  )

md <- c(
  "# Escenarios integrados: saldos de ganancia asociados a la sobrevaluación cambiaria industrial",
  "",
  paste0(
    "Fuente de trabajo: `",
    input_xlsx,
    "`, hojas `escenario-inicial`, `tipo-cambio`, ",
    "`Escenario 1 - Comercio Exterior` y `Escenario 2 - Bienes Transables`."
  ),
  "",
  "## Introducción",
  "",
  paste(
    "Esta minuta integra los dos ejercicios de cierre de brecha cambiaria",
    "construidos para la industria manufacturera uruguaya. El primer escenario",
    "mide la incidencia directa del comercio exterior; el segundo amplía el",
    "ejercicio hacia bienes transables cuyos precios internos se rigen por",
    "precios internacionales."
  ),
  "",
  paste(
    "La lectura se realiza desde el escenario inicial de sobrevaluación. Por",
    "eso, el resultado principal se expresa como saldo monetario y no como",
    "tasa de ganancia:",
    "`ganancia inicial - ganancia contrafactual con cierre de brecha`. Un valor",
    "negativo indica ganancia dejada de percibir bajo sobrevaluación; un valor",
    "positivo indica ganancia sobrepercibida bajo sobrevaluación. El cálculo se",
    "realiza año a año, sin efectos acumulados ni respuestas dinámicas de",
    "cantidades, productividad o estructura productiva."
  ),
  "",
  "## Síntesis",
  "",
  paste(
    "Las fuentes usadas son: EAAE para VBP, VAB, remuneraciones, consumo",
    "intermedio estimado, consumo de capital fijo, stock de capital y capital",
    "adelantado; Oyanthabal, con base en la metodología de Iñigo Carrera",
    "(2007), para los tipos de cambio comercial/paridad; microdatos del CIU",
    "para distribuir los intereses industriales entre ramas exportadoras y",
    "ramas orientadas al mercado interno; y la clasificación operativa de",
    "subramas industriales 2020-2024 usada para separar industria exportadora,",
    "mercado interno y combustible. Las fuentes sustantivas de los coeficientes",
    "se toman de la columna `Fuente` del XLSX de coeficientes y se reportan en",
    "las tablas correspondientes."
  ),
  "",
  paste(
    "Se trabaja desde 2020 porque en ese tramo la fuente opera con ramas",
    "homogéneas. Extender el ejercicio al panel completo exigiría procesar",
    "distintas versiones CIIU, lo que vuelve incompatible diferenciar con",
    "criterio uniforme el segmento industrial exportador y el segmento orientado",
    "al mercado interno. Complementariamente, el período 2020-2024 es razonable",
    "para una lectura en valores corrientes porque evita grandes saltos de nivel",
    "asociados a cambios clasificatorios."
  ),
  "",
  paste0(
    "En 2024, el escenario de comercio exterior registra para la industria total",
    " un saldo de ",
    fmt_delta(scenario_value(industry_summary, "comercio_exterior", saldo_pb_2024_miles_mill)),
    " miles de millones de pesos corrientes en ganancia a precios básicos. El",
    " escenario de bienes transables registra ",
    fmt_delta(scenario_value(industry_summary, "bienes_transables", saldo_pb_2024_miles_mill)),
    " miles de millones. La comparación muestra que el signo del saldo depende",
    " del balance entre valorización del VBP y encarecimiento de costos."
  ),
  "",
  "## Supuestos y escenarios",
  "",
  "- `escenario-inicial` contiene los valores corrientes observados para industria total, segmento exportador y segmento mercado interno.",
  "- `Escenario 1 - Comercio Exterior` contiene el contrafactual que recoge la incidencia directa de importaciones y exportaciones.",
  "- `Escenario 2 - Bienes Transables` contiene el contrafactual que incorpora bienes transables producidos localmente y vendidos en el mercado interno.",
  "- El cálculo se realiza año a año mediante `factor_devaluacion = tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1`; no contempla efectos acumulados ni respuestas dinámicas de cantidades, precios relativos o productividad.",
  "- El canal positivo se modela sobre `vbp_pp`; los canales negativos se modelan sobre consumo intermedio, remuneraciones, consumo de capital fijo, stock imputado e intereses pagados.",
  "- La medida principal de esta minuta es `ganancia_pb`; como complemento se reporta `ganancia_pb_desp_intereses`.",
  "- La medida relativa complementaria normaliza el saldo de sobrevaluación como `saldo_sobrevaluacion_ganancia_pb / ganancia_pb_inicial * 100`; debe leerse como saldo neto sobre la masa de ganancia inicial, no como tasa de ganancia.",
  "- Los intereses industriales son una serie agregada de manufactura y se distribuyen por segmento según microdatos del CIU: 65,6% para ramas exportadoras y 34,4% para ramas orientadas al mercado interno.",
  "- El grupo `combustible` no se presenta como segmento autónomo en el libro de resultados ni en esta minuta; queda incorporado en la industria total y se conserva en el panel CSV para trazabilidad contable.",
  "",
  "Ramas incluidas en el segmento exportador:",
  paste0("- ", ramas_exportadoras),
  "",
  "Ramas incluidas en el segmento mercado interno:",
  paste0("- ", ramas_mercado_interno),
  "",
  paste0("![Brecha cambiaria modelada](", fig_rel(fig_factor_path), ")"),
  "",
  paste0(
    "El factor de devaluación considerado se calcula año a año como",
    " `tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1`. ",
    "En el período 2020-2024, el factor promedio es ",
    fmt_pct(factor_summary$promedio * 100),
    ", con un mínimo de ",
    fmt_pct(factor_summary$minimo * 100),
    " y un máximo de ",
    fmt_pct(factor_summary$maximo * 100),
    "."
  ),
  "",
  md_table(factor_table),
  "",
  md_table(source_assumptions_table),
  "",
  "## Coeficientes de incidencia",
  "",
  paste(
    "Los coeficientes indican qué proporción de cada variable queda expuesta al",
    "cierre de la brecha cambiaria. Desde el punto de vista del contrafactual",
    "de paridad, el componente de VBP tiene signo positivo para la ganancia",
    "porque eleva la valorización de ventas asociadas al tipo de cambio. En",
    "cambio, consumo intermedio, masa salarial, consumo de capital fijo e",
    "intereses pagados operan como gastos o costos; el stock imputado afecta",
    "negativamente el capital adelantado y se mantiene como supuesto del modelo,",
    "aunque la minuta no presenta tasas de ganancia."
  ),
  "",
  paste0("![Coeficientes de incidencia por escenario y segmento](", fig_rel(fig_coef_path), ")"),
  "",
  if (nrow(effect_demo) > 0) c(
    paste(
      "La hoja `Efecto TCC - TCP` del archivo de trabajo propone leer el",
      "ejercicio como una combinación de cesión y apropiación respecto de una",
      "ganancia inicial. El VBP/exportaciones aparece como cesión bajo",
      "sobrevaluación cuando el cierre de la brecha lo valoriza al alza; los",
      "costos aparecen como apropiación bajo sobrevaluación cuando el cierre de",
      "la brecha los encarece. La tabla y el gráfico siguientes reproducen ese",
      "esquema de lectura como ejemplo conceptual, no como resultado empírico de",
      "la serie EAAE."
    ),
    "",
    md_table(effect_demo_table),
    "",
    paste0("![Esquema TCC-TCP: cesión y apropiación](", fig_rel(fig0_path), ")"),
    ""
  ) else character(0),
  "## 1. Industria general: saldos comparados entre escenarios",
  "",
  paste(
    "A nivel de industria total, los dos escenarios producen saldos opuestos.",
    "En el escenario de comercio exterior, el cierre de la brecha elevaría la",
    "ganancia industrial; por tanto, desde la posición inicial de sobrevaluación",
    "aparece un saldo negativo: ganancia dejada de percibir. En el escenario de",
    "bienes transables, el cierre de la brecha reduce la ganancia agregada por",
    "el mayor peso de consumo intermedio y masa salarial; desde la posición",
    "inicial, eso aparece como saldo positivo: ganancia sobrepercibida bajo",
    "sobrevaluación."
  ),
  "",
  paste0("![Industria total: saldo de ganancia asociado a la sobrevaluación](", fig_rel(fig1_path), ")"),
  "",
  paste(
    "La figura siguiente expresa el saldo de sobrevaluación como proporción de",
    "la ganancia inicial. Esta medida no reemplaza el saldo monetario: permite",
    "leer cuánto pesa la apropiación o cesión neta sobre la masa de ganancia",
    "observada en cada sección."
  ),
  "",
  paste0("![Saldo de sobrevaluación como proporción de la ganancia inicial por sección](", fig_rel(fig1_pct_path), ")"),
  "",
  md_table(industry_table),
  "",
  "## 2. Escenario 1 - Comercio Exterior",
  "",
  scenario_sections$comercio_exterior$spec$descripcion,
  "",
  paste(
    "En este escenario, la sobrevaluación comprime la valorización en pesos del",
    "VBP asociado al comercio exterior y, al mismo tiempo, abarata componentes",
    "importados de costos y capital. El balance de esos canales se expresa como",
    "saldo de masa de ganancia observado desde el escenario inicial."
  ),
  "",
  scenario_sections$comercio_exterior$text,
  "",
  paste0("![Escenario 1: saldo de ganancia por segmento](", fig_rel(scenario_sections$comercio_exterior$figures[["saldo"]]), ")"),
  "",
  paste(
    "Para dimensionar el peso relativo del saldo, la figura siguiente divide",
    "la diferencia entre la ganancia inicial y la ganancia del momento 2 por la",
    "masa de ganancia inicial de cada sección. Esto muestra qué proporción de",
    "la ganancia observada representa la apropiación o cesión asociada a la",
    "sobrevaluación."
  ),
  "",
  paste0("![Escenario 1: saldo relativo sobre la ganancia inicial](", fig_rel(scenario_sections$comercio_exterior$figures[["saldo_pct"]]), ")"),
  "",
  md_table(scenario_sections$comercio_exterior$table),
  "",
  paste0("![Escenario 1: componentes del saldo 2024](", fig_rel(scenario_sections$comercio_exterior$figures[["components"]]), ")"),
  "",
  "Coeficientes del modelo utilizados en este escenario:",
  "",
  md_table(scenario_sections$comercio_exterior$coef_table),
  "",
  "## 3. Escenario 2 - Bienes Transables",
  "",
  scenario_sections$bienes_transables$spec$descripcion,
  "",
  paste(
    "En este escenario, la incidencia no queda limitada al comercio exterior",
    "directo. También se consideran mercancías producidas localmente cuyos",
    "precios internos se rigen por precios internacionales. Esto amplía tanto",
    "los canales positivos del VBP como los canales de costos, por lo que la",
    "lectura debe concentrarse en el saldo neto de masa de ganancia."
  ),
  "",
  scenario_sections$bienes_transables$text,
  "",
  paste0("![Escenario 2: saldo de ganancia por segmento](", fig_rel(scenario_sections$bienes_transables$figures[["saldo"]]), ")"),
  "",
  paste(
    "La lectura relativa permite comparar secciones de tamaño distinto sin",
    "perder el signo económico del ejercicio: valores positivos indican una",
    "sobrepercepción de ganancia bajo sobrevaluación y valores negativos",
    "indican ganancia dejada de percibir."
  ),
  "",
  paste0("![Escenario 2: saldo relativo sobre la ganancia inicial](", fig_rel(scenario_sections$bienes_transables$figures[["saldo_pct"]]), ")"),
  "",
  md_table(scenario_sections$bienes_transables$table),
  "",
  paste0("![Escenario 2: componentes del saldo 2024](", fig_rel(scenario_sections$bienes_transables$figures[["components"]]), ")"),
  "",
  "Coeficientes del modelo utilizados en este escenario:",
  "",
  md_table(scenario_sections$bienes_transables$coef_table),
  "",
  "## Interpretación",
  "",
  paste(
    "La simulación sugiere que la sobrevaluación cambiaria redistribuye",
    "condiciones de rentabilidad dentro de la industria. La lectura agregada",
    "de la industria total debe interpretarse con cautela porque sintetiza",
    "estructuras de exposición distintas. La separación entre segmento",
    "exportador y segmento mercado interno permite observar qué parte del",
    "resultado responde al canal de valorización del producto y qué parte queda",
    "condicionada por el encarecimiento de costos, capital adelantado e",
    "intereses pagados al cerrar la brecha cambiaria."
  ),
  "",
  paste(
    "Dado que esta versión expresa saldos absolutos desde el escenario inicial,",
    "la comparación privilegia magnitudes monetarias antes que variaciones de",
    "tasas. Esto facilita leer la apropiación o cesión de riqueza asociada a la",
    "sobrevaluación como diferencia entre la situación observada y el",
    "contrafactual de paridad."
  ),
  "",
  "## Anexo técnico",
  "",
  "La fórmula común aplicada en ambos escenarios es:",
  "",
  "```text",
  "factor_devaluacion = tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1",
  "delta_variable = variable_base * incidencia_seccion_variable * factor_devaluacion",
  "variable_devaluacion = variable_base + delta_variable",
  "ganancia_pb_escenario = ganancia_pb + delta_vbp_pp - delta_consumo_intermedio_estimado - delta_remuneraciones - delta_consumo_capital_fijo",
  "saldo_sobrevaluacion_ganancia_pb = ganancia_pb - ganancia_pb_escenario",
  "saldo_sobrevaluacion_ganancia_pb_pct = saldo_sobrevaluacion_ganancia_pb / ganancia_pb * 100",
  "ganancia_pb_desp_intereses_escenario = ganancia_pb_escenario - intereses_industria_pesos_escenario",
  "saldo_sobrevaluacion_ganancia_pb_desp_intereses = ganancia_pb_desp_intereses - ganancia_pb_desp_intereses_escenario",
  "```",
  "",
  paste(
    "El coeficiente de stock de capital imputado se mantiene en el XLSX porque",
    "afecta cálculos de tasa de ganancia, pero no se presenta en esta minuta",
    "porque la medida solicitada es masa absoluta de ganancia. Por esa razón,",
    "las figuras y tablas de componentes de esta versión usan VBP, consumo",
    "intermedio, remuneraciones, consumo de capital fijo e intereses."
  )
)

writeLines(md, output_md, useBytes = TRUE)

cat("Minuta integrada actualizada: ", output_md, "\n", sep = "")
cat("Figuras creadas en: ", figures_dir, "\n", sep = "")
cat("Fuente XLSX: ", input_xlsx, "\n", sep = "")
