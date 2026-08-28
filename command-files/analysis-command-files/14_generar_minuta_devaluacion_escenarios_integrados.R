#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
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

safe_divide <- function(numerator, denominator) {
  result <- numerator / denominator
  result[is.na(numerator) | is.na(denominator) | denominator == 0] <- NA_real_
  result
}

fmt_pct <- function(x, digits = 1) {
  ifelse(
    is.na(x),
    "",
    paste0(trimws(format(round(x, digits), big.mark = ".", decimal.mark = ",")), "%")
  )
}

fmt_pp <- function(x, digits = 1) {
  ifelse(
    is.na(x),
    "",
    paste0(
      ifelse(x > 0, "+", ""),
      trimws(format(round(x, digits), big.mark = ".", decimal.mark = ",")),
      " pp"
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

md_table <- function(data) {
  data <- as.data.frame(data, stringsAsFactors = FALSE)
  if (ncol(data) == 0) {
    return("")
  }

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

value_for <- function(data, scenario, variable) {
  data %>%
    filter(.data$escenario == !!scenario) %>%
    pull({{ variable }})
}

section_value <- function(data, seccion, variable) {
  data %>%
    filter(.data$seccion == !!seccion) %>%
    pull({{ variable }})
}

input_xlsx <- latest_file(file.path(
  analysis_dir,
  "*_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx"
))

output_md <- file.path(
  docs_dir,
  paste0(date_prefix, "_resultados_devaluacion_escenarios_integrados.md")
)

dir.create(docs_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

scenario_specs <- tibble::tribble(
  ~sheet, ~escenario, ~titulo, ~descripcion, ~vbp_label,
  "Escenario 1 - Comercio Exterior",
  "comercio_exterior",
  "Escenario 1 - Comercio exterior",
  paste(
    "La apropiación de riqueza vía sobrevaluación de la moneda se aplica a",
    "los componentes importados de costos y capital y a la parte exportada de",
    "la producción. Por tanto, recoge el efecto directo de importaciones y",
    "exportaciones sobre la tasa de ganancia."
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
    "sobre la tasa de ganancia."
  ),
  "VBP/transable"
)

required_sheets <- c("escenario-inicial", scenario_specs$sheet)
missing_sheets <- setdiff(required_sheets, excel_sheets(input_xlsx))
if (length(missing_sheets) > 0) {
  stop("Missing sheets in workbook: ", paste(missing_sheets, collapse = ", "))
}

section_labels <- c(
  "industria-total" = "Industria total",
  "exportadora" = "Segmento exportador",
  "mercado-interno" = "Mercado interno"
)

caption_fuente <- paste(
  "Fuente: elaboración propia en base a EAAE, microdatos CIU y Oyanthabal,",
  "con base en metodología de Iñigo Carrera (2007)."
)

theme_report <- theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title.position = "plot",
    plot.caption.position = "plot",
    legend.position = "bottom"
  )

escenario_inicial <- read_excel(input_xlsx, sheet = "escenario-inicial") %>%
  filter(!is.na(.data$anno), !is.na(.data$seccion)) %>%
  mutate(
    seccion_label = recode(.data$seccion, !!!section_labels),
    seccion_label = factor(.data$seccion_label, levels = unname(section_labels))
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
      seccion_label = factor(.data$seccion_label, levels = unname(section_labels))
    )
}

escenarios <- bind_rows(lapply(scenario_specs$sheet, read_scenario))

if (nrow(escenarios) != 30L) {
  stop("Se esperaban 30 filas de escenarios: 2 escenarios x 5 años x 3 secciones.")
}
if (any(is.na(escenarios$factor_devaluacion))) {
  stop("Hay escenarios sin factor de devaluación.")
}

component_labels_generic <- c(
  delta_vbp_pp = "VBP afectado",
  delta_consumo_intermedio_estimado = "Consumo intermedio",
  delta_remuneraciones = "Remuneraciones",
  delta_consumo_capital_fijo = "Consumo capital fijo",
  delta_stock_capital_imputado = "Stock imputado",
  delta_intereses_industria_pesos = "Intereses pagados"
)

summary_by_scenario_section <- escenarios %>%
  group_by(.data$escenario, .data$escenario_label, .data$seccion, .data$seccion_label) %>%
  summarise(
    tg_base_prom_pct = mean(.data$tasa_ganancia_pb, na.rm = TRUE) * 100,
    tg_escenario_prom_pct = mean(.data$tasa_ganancia_pb_devaluacion, na.rm = TRUE) * 100,
    cambio_prom_pp = mean(.data$variacion_tasa_ganancia_pb_pp, na.rm = TRUE),
    tg_base_2024_pct = .data$tasa_ganancia_pb[.data$anno == 2024] * 100,
    tg_escenario_2024_pct = .data$tasa_ganancia_pb_devaluacion[.data$anno == 2024] * 100,
    cambio_2024_pp = .data$variacion_tasa_ganancia_pb_pp[.data$anno == 2024],
    var_ganancia_2024_pct = .data$variacion_ganancia_pb_pct[.data$anno == 2024],
    .groups = "drop"
  )

industry_summary <- summary_by_scenario_section %>%
  filter(.data$seccion == "industria-total")

industry_tg_long <- bind_rows(
  escenarios %>%
    filter(.data$seccion == "industria-total") %>%
    distinct(.data$anno, .data$tasa_ganancia_pb) %>%
    transmute(
      anno = .data$anno,
      serie = "Escenario inicial",
      tasa = .data$tasa_ganancia_pb
    ),
  escenarios %>%
    filter(.data$seccion == "industria-total") %>%
    transmute(
      anno = .data$anno,
      serie = .data$escenario_label,
      tasa = .data$tasa_ganancia_pb_devaluacion
    )
) %>%
  distinct()

fig1_path <- file.path(figures_dir, "01_industria_total_tasa_ganancia_escenarios.png")
fig2_path <- file.path(figures_dir, "02_industria_total_cambio_tasa_ganancia.png")
fig3_path <- file.path(figures_dir, "03_industria_total_componentes_2024.png")

ggplot(industry_tg_long, aes(x = .data$anno, y = .data$tasa, color = .data$serie)) +
  geom_line(linewidth = 0.85) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = sort(unique(industry_tg_long$anno))) +
  scale_y_continuous(labels = percent_format(accuracy = 1, decimal.mark = ",")) +
  scale_color_manual(values = c(
    "Escenario inicial" = "#457B9D",
    "Escenario 1 - Comercio exterior" = "#2D6A4F",
    "Escenario 2 - Bienes transables" = "#E76F51"
  )) +
  labs(
    title = "Industria total: tasa de ganancia según escenario",
    x = NULL,
    y = NULL,
    color = NULL,
    caption = caption_fuente
  ) +
  theme_report
ggsave(fig1_path, width = 9, height = 5, dpi = 160)

ggplot(
  escenarios %>% filter(.data$seccion == "industria-total"),
  aes(x = factor(.data$anno), y = .data$variacion_tasa_ganancia_pb_pp, fill = .data$escenario_label)
) +
  geom_hline(yintercept = 0, color = "grey35", linewidth = 0.35) +
  geom_col(position = position_dodge(width = 0.75), width = 0.68) +
  scale_fill_manual(values = c(
    "Escenario 1 - Comercio exterior" = "#2D6A4F",
    "Escenario 2 - Bienes transables" = "#E76F51"
  )) +
  labs(
    title = "Industria total: cambio en la tasa de ganancia",
    x = NULL,
    y = "Puntos porcentuales",
    fill = NULL,
    caption = caption_fuente
  ) +
  theme_report
ggsave(fig2_path, width = 8.5, height = 5, dpi = 160)

industry_components_2024 <- escenarios %>%
  filter(.data$anno == 2024, .data$seccion == "industria-total") %>%
  select("escenario_label", all_of(names(component_labels_generic))) %>%
  pivot_longer(
    cols = all_of(names(component_labels_generic)),
    names_to = "componente",
    values_to = "valor"
  ) %>%
  mutate(
    componente = recode(.data$componente, !!!component_labels_generic),
    componente = factor(.data$componente, levels = unname(component_labels_generic)),
    # DECISION: the VBP channel is plotted as a positive impulse; the remaining
    # channels are plotted as costs or capital requirements.
    signo_grafico = if_else(.data$componente == "VBP afectado", .data$valor, -.data$valor)
  )

ggplot(industry_components_2024, aes(
  x = .data$componente,
  y = .data$signo_grafico / 1e9,
  fill = .data$escenario_label
)) +
  geom_hline(yintercept = 0, color = "grey35", linewidth = 0.35) +
  geom_col(position = position_dodge(width = 0.75), width = 0.68) +
  scale_fill_manual(values = c(
    "Escenario 1 - Comercio exterior" = "#2D6A4F",
    "Escenario 2 - Bienes transables" = "#E76F51"
  )) +
  labs(
    title = "Industria total: canales monetarios del cierre de brecha en 2024",
    subtitle = "VBP afectado se muestra como impulso positivo; costos, stock e intereses pagados como cargas adicionales",
    x = NULL,
    y = "Miles de millones de pesos corrientes",
    fill = NULL,
    caption = caption_fuente
  ) +
  theme_report +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
ggsave(fig3_path, width = 10, height = 5.2, dpi = 160)

scenario_section <- function(scenario_id) {
  spec <- scenario_specs %>%
    filter(.data$escenario == !!scenario_id)
  data <- escenarios %>%
    filter(.data$escenario == !!scenario_id)

  tg_long <- data %>%
    select(
      anno,
      seccion_label,
      tasa_base = tasa_ganancia_pb,
      tasa_escenario = tasa_ganancia_pb_devaluacion
    ) %>%
    pivot_longer(
      cols = c("tasa_base", "tasa_escenario"),
      names_to = "serie",
      values_to = "tasa"
    ) %>%
    mutate(
      serie = recode(
        .data$serie,
        tasa_base = "Escenario inicial",
        tasa_escenario = "Cierre de brecha"
      )
    )

  fig_tg <- file.path(figures_dir, paste0("04_", scenario_id, "_tasa_ganancia_segmentos.png"))
  fig_change <- file.path(figures_dir, paste0("05_", scenario_id, "_cambio_tasa_segmentos.png"))
  fig_components <- file.path(figures_dir, paste0("06_", scenario_id, "_componentes_2024_segmentos.png"))

  ggplot(tg_long, aes(x = .data$anno, y = .data$tasa, color = .data$serie)) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 1.8) +
    facet_wrap(vars(.data$seccion_label), nrow = 1) +
    scale_x_continuous(breaks = sort(unique(tg_long$anno))) +
    scale_y_continuous(labels = percent_format(accuracy = 1, decimal.mark = ",")) +
    scale_color_manual(values = c("Escenario inicial" = "#457B9D", "Cierre de brecha" = "#E63946")) +
    labs(
      title = paste(spec$titulo, "- tasa de ganancia a precios básicos"),
      x = NULL,
      y = NULL,
      color = NULL,
      caption = caption_fuente
    ) +
    theme_report
  ggsave(fig_tg, width = 10.5, height = 4.8, dpi = 160)

  ggplot(data, aes(
    x = factor(.data$anno),
    y = .data$variacion_tasa_ganancia_pb_pp,
    fill = .data$seccion_label
  )) +
    geom_hline(yintercept = 0, color = "grey35", linewidth = 0.35) +
    geom_col(position = position_dodge(width = 0.75), width = 0.68) +
    scale_fill_manual(values = c(
      "Industria total" = "#457B9D",
      "Segmento exportador" = "#2D6A4F",
      "Mercado interno" = "#E76F51"
    )) +
    labs(
      title = paste(spec$titulo, "- cambio en tasa de ganancia"),
      x = NULL,
      y = "Puntos porcentuales",
      fill = NULL,
      caption = caption_fuente
    ) +
    theme_report
  ggsave(fig_change, width = 9, height = 5, dpi = 160)

  components_2024 <- data %>%
    filter(.data$anno == 2024) %>%
    select("seccion", "seccion_label", all_of(names(component_labels_generic))) %>%
    pivot_longer(
      cols = all_of(names(component_labels_generic)),
      names_to = "componente",
      values_to = "valor"
    ) %>%
    mutate(
      componente = recode(.data$componente, !!!component_labels_generic),
      componente = if_else(.data$componente == "VBP afectado", spec$vbp_label, as.character(.data$componente)),
      componente = factor(.data$componente, levels = c(
        spec$vbp_label,
        "Consumo intermedio",
        "Remuneraciones",
        "Consumo capital fijo",
        "Stock imputado",
        "Intereses pagados"
      )),
      signo_grafico = if_else(.data$componente == spec$vbp_label, .data$valor, -.data$valor)
    )

  ggplot(components_2024, aes(
    x = .data$componente,
    y = .data$signo_grafico / 1e9,
    fill = .data$seccion_label
  )) +
    geom_hline(yintercept = 0, color = "grey35", linewidth = 0.35) +
    geom_col(position = position_dodge(width = 0.75), width = 0.68) +
    scale_fill_manual(values = c(
      "Industria total" = "#457B9D",
      "Segmento exportador" = "#2D6A4F",
      "Mercado interno" = "#E76F51"
    )) +
    labs(
      title = paste(spec$titulo, "- canales monetarios en 2024"),
      subtitle = paste(spec$vbp_label, "se muestra como impulso positivo; costos, stock e intereses pagados como cargas adicionales"),
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
      `TG base prom.` = fmt_pct(.data$tg_base_prom_pct),
      `TG escenario prom.` = fmt_pct(.data$tg_escenario_prom_pct),
      `Cambio prom.` = fmt_pp(.data$cambio_prom_pp),
      `TG base 2024` = fmt_pct(.data$tg_base_2024_pct),
      `TG escenario 2024` = fmt_pct(.data$tg_escenario_2024_pct),
      `Cambio 2024` = fmt_pp(.data$cambio_2024_pp),
      `Var. ganancia 2024` = fmt_pct(.data$var_ganancia_2024_pct)
    )

  coef_table <- data %>%
    distinct(
      seccion_label,
      incidencia_vbp_pp,
      incidencia_consumo_intermedio_estimado,
      incidencia_remuneraciones,
      incidencia_consumo_capital_fijo,
      incidencia_stock_capital_imputado,
      incidencia_intereses_industria_pesos
    ) %>%
    pivot_longer(
      cols = starts_with("incidencia_"),
      names_to = "variable",
      values_to = "incidencia"
    ) %>%
    mutate(
      variable = recode(
        .data$variable,
        incidencia_vbp_pp = spec$vbp_label,
        incidencia_consumo_intermedio_estimado = "Consumo intermedio",
        incidencia_remuneraciones = "Masa salarial",
        incidencia_consumo_capital_fijo = "Consumo capital fijo",
        incidencia_stock_capital_imputado = "Stock imputado",
        incidencia_intereses_industria_pesos = "Intereses pagados"
      )
    ) %>%
    transmute(
      `Sección` = as.character(.data$seccion_label),
      `Variable afectada` = .data$variable,
      `Incidencia` = fmt_pct(.data$incidencia * 100)
    ) %>%
    arrange(.data$`Sección`, .data$`Variable afectada`)

  summary_2024 <- summary_by_scenario_section %>%
    filter(.data$escenario == !!scenario_id)

  list(
    spec = spec,
    table = summary_table,
    coef_table = coef_table,
    figures = c(fig_tg, fig_change, fig_components),
    text = c(
      paste0(
        "En 2024, la industria total pasa de ",
        fmt_pct(section_value(summary_2024, "industria-total", tg_base_2024_pct)),
        " a ",
        fmt_pct(section_value(summary_2024, "industria-total", tg_escenario_2024_pct)),
        ", con un cambio de ",
        fmt_pp(section_value(summary_2024, "industria-total", cambio_2024_pp)),
        "."
      ),
      paste0(
        "El segmento exportador registra un cambio de ",
        fmt_pp(section_value(summary_2024, "exportadora", cambio_2024_pp)),
        " en 2024, mientras que el segmento mercado interno registra ",
        fmt_pp(section_value(summary_2024, "mercado-interno", cambio_2024_pp)),
        "."
      )
    )
  )
}

scenario_sections <- lapply(scenario_specs$escenario, scenario_section)
names(scenario_sections) <- scenario_specs$escenario

industry_table <- industry_summary %>%
  transmute(
    `Escenario` = .data$escenario_label,
    `TG base prom.` = fmt_pct(.data$tg_base_prom_pct),
    `TG escenario prom.` = fmt_pct(.data$tg_escenario_prom_pct),
    `Cambio prom.` = fmt_pp(.data$cambio_prom_pp),
    `TG base 2024` = fmt_pct(.data$tg_base_2024_pct),
    `TG escenario 2024` = fmt_pct(.data$tg_escenario_2024_pct),
    `Cambio 2024` = fmt_pp(.data$cambio_2024_pp),
    `Var. ganancia 2024` = fmt_pct(.data$var_ganancia_2024_pct)
  )

component_table <- industry_components_2024 %>%
  mutate(
    valor_miles_mill = .data$valor / 1e9,
    escenario_label = as.character(.data$escenario_label)
  ) %>%
  select("escenario_label", "componente", "valor_miles_mill") %>%
  pivot_wider(names_from = "escenario_label", values_from = "valor_miles_mill") %>%
  transmute(
    `Componente` = as.character(.data$componente),
    `Escenario 1` = fmt_num(.data$`Escenario 1 - Comercio exterior`),
    `Escenario 2` = fmt_num(.data$`Escenario 2 - Bienes transables`)
  )

md <- c(
  "# Análisis integrado de escenarios de devaluación industrial, 2020-2024",
  "",
  paste0(
    "Fuente de trabajo: `",
    input_xlsx,
    "`, hojas `escenario-inicial`, `Escenario 1 - Comercio Exterior` y ",
    "`Escenario 2 - Bienes Transables`."
  ),
  "",
  paste(
    "Esta minuta integra los dos ejercicios de cierre de brecha cambiaria",
    "construidos para la industria manufacturera uruguaya. El objetivo es",
    "comparar, primero a nivel de industria general, cómo cambia la tasa de",
    "ganancia bajo dos supuestos de incidencia; luego se presenta una lectura",
    "separada de cada escenario para industria total, segmento exportador y",
    "segmento orientado al mercado interno."
  ),
  "",
  paste(
    "El ejercicio debe leerse como una forma de dimensionar la apropiación de",
    "riqueza asociada a sostener un tipo de cambio comercial por debajo del",
    "tipo de cambio de paridad. En todos los casos se trabaja año a año, sin",
    "efectos acumulados ni cambios en cantidades, productividad o estructura",
    "productiva."
  ),
  "",
  "## 1. Industria general: lectura comparada de los dos escenarios",
  "",
  paste(
    "La comparación agregada muestra dos resultados claramente distintos. En el",
    "escenario de comercio exterior, el canal positivo asociado al VBP afectado",
    "por comercio exterior domina sobre los aumentos de costos, capital e",
    "intereses. En el escenario de bienes transables, el aumento modelado de",
    "costos y componentes transables del capital pesa más que el impulso sobre",
    "el VBP, llevando la tasa agregada a un resultado negativo en el tramo final."
  ),
  "",
  paste0("![Industria total: tasa de ganancia según escenario](", fig_rel(fig1_path), ")"),
  "",
  paste0("![Industria total: cambio en tasa de ganancia](", fig_rel(fig2_path), ")"),
  "",
  md_table(industry_table),
  "",
  paste(
    "El contraste de componentes en 2024 permite ver el mecanismo: el escenario",
    "1 tiene un delta de VBP mayor que los costos modelados; el escenario 2",
    "incorpora una incidencia mucho más alta sobre consumo intermedio y masa",
    "salarial, por lo que el cierre de brecha deteriora la rentabilidad agregada."
  ),
  "",
  paste0("![Industria total: canales monetarios 2024](", fig_rel(fig3_path), ")"),
  "",
  md_table(component_table),
  "",
  "## 2. Escenario 1 - Comercio Exterior",
  "",
  scenario_sections$comercio_exterior$spec$descripcion,
  "",
  paste(
    "En este escenario, el efecto positivo opera sobre la parte de la producción",
    "directamente asociada al comercio exterior, mientras los efectos negativos",
    "se aplican sobre componentes importados de costos, capital fijo, stock e",
    "intereses. Por eso, el resultado favorece especialmente al segmento",
    "exportador."
  ),
  "",
  scenario_sections$comercio_exterior$text,
  "",
  paste0("![Escenario 1: tasa de ganancia por segmento](", fig_rel(scenario_sections$comercio_exterior$figures[[1]]), ")"),
  "",
  paste0("![Escenario 1: cambio en tasa de ganancia](", fig_rel(scenario_sections$comercio_exterior$figures[[2]]), ")"),
  "",
  md_table(scenario_sections$comercio_exterior$table),
  "",
  paste0("![Escenario 1: componentes 2024](", fig_rel(scenario_sections$comercio_exterior$figures[[3]]), ")"),
  "",
  "Coeficientes usados:",
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
    "precios internos se rigen por precios internacionales. Esto amplía el peso",
    "de los componentes afectados, en particular consumo intermedio y masa",
    "salarial, y modifica de manera sustantiva el resultado de rentabilidad."
  ),
  "",
  scenario_sections$bienes_transables$text,
  "",
  paste0("![Escenario 2: tasa de ganancia por segmento](", fig_rel(scenario_sections$bienes_transables$figures[[1]]), ")"),
  "",
  paste0("![Escenario 2: cambio en tasa de ganancia](", fig_rel(scenario_sections$bienes_transables$figures[[2]]), ")"),
  "",
  md_table(scenario_sections$bienes_transables$table),
  "",
  paste0("![Escenario 2: componentes 2024](", fig_rel(scenario_sections$bienes_transables$figures[[3]]), ")"),
  "",
  "Coeficientes usados:",
  "",
  md_table(scenario_sections$bienes_transables$coef_table),
  "",
  "La fórmula común aplicada en ambos escenarios es:",
  "",
  "```text",
  "factor_devaluacion = tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1",
  "delta_variable = variable_base * incidencia_seccion_variable * factor_devaluacion",
  "ganancia_pb_devaluacion = ganancia_pb + delta_vbp_pp - delta_consumo_intermedio_estimado - delta_remuneraciones - delta_consumo_capital_fijo",
  "capital_total_adelantado_devaluacion = capital_total_adelantado + delta_stock_capital_imputado + (delta_remuneraciones + delta_consumo_intermedio_estimado) / rotacion_calibrada_sobre_6_6",
  "tasa_ganancia_pb_devaluacion = ganancia_pb_devaluacion / capital_total_adelantado_devaluacion",
  "```"
)

writeLines(md, output_md, useBytes = TRUE)

cat("Minuta integrada creada: ", output_md, "\n", sep = "")
cat("Figuras creadas en: ", figures_dir, "\n", sep = "")
cat("Fuente XLSX: ", input_xlsx, "\n", sep = "")
