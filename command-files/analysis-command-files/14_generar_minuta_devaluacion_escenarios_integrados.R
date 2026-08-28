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

fig1_path <- file.path(figures_dir, "01_industria_total_saldo_sobrevaluacion_ganancia.png")
fig2_path <- file.path(figures_dir, "02_industria_total_componentes_saldo_2024.png")

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
  scale_color_manual(values = c(
    "Escenario 1 - Comercio exterior" = "#2D6A4F",
    "Escenario 2 - Bienes transables" = "#E76F51"
  )) +
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
  scale_fill_manual(values = c(
    "Escenario 1 - Comercio exterior" = "#2D6A4F",
    "Escenario 2 - Bienes transables" = "#E76F51"
  )) +
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
  fig_components <- file.path(figures_dir, paste0("04_", scenario_id, "_componentes_saldo_2024_segmentos.png"))

  ggplot(saldo_long, aes(x = .data$anno, y = .data$saldo_miles_mill, color = .data$seccion_label)) +
    geom_hline(yintercept = 0, color = "grey35", linewidth = 0.35) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 1.8) +
    facet_wrap(vars(.data$medida), nrow = 1, scales = "free_y") +
    scale_x_continuous(breaks = sort(unique(saldo_long$anno))) +
    scale_color_manual(values = c(
      "Industria total" = "#457B9D",
      "Segmento exportador" = "#2D6A4F",
      "Mercado interno" = "#E76F51"
    )) +
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
    scale_fill_manual(values = c(
      "Industria total" = "#457B9D",
      "Segmento exportador" = "#2D6A4F",
      "Mercado interno" = "#E76F51"
    )) +
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
      seccion_label,
      incidencia_vbp_pp,
      incidencia_consumo_intermedio_estimado,
      incidencia_remuneraciones,
      incidencia_consumo_capital_fijo,
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
    figures = c(fig_saldo, fig_components),
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
  "# Saldos de ganancia asociados a la sobrevaluación cambiaria industrial, 2020-2024",
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
    "construidos para la industria manufacturera uruguaya. A diferencia de la",
    "lectura centrada en el resultado contrafactual de devaluación, aquí el",
    "foco está puesto en el saldo monetario que se observa desde el escenario",
    "inicial de sobrevaluación."
  ),
  "",
  paste(
    "La convención de signo es `ganancia inicial - ganancia contrafactual con",
    "cierre de brecha`. Por eso, un valor negativo indica ganancia dejada de",
    "percibir bajo sobrevaluación: si se cerrara la brecha cambiaria, la masa",
    "de ganancia sería mayor. Un valor positivo indica ganancia sobrepercibida",
    "bajo sobrevaluación: si se cerrara la brecha, la masa de ganancia sería",
    "menor. Las magnitudes se presentan en miles de millones de pesos",
    "corrientes."
  ),
  "",
  paste(
    "La medida principal es la masa de ganancia a precios básicos",
    "`ganancia_pb`. Como complemento se reporta `ganancia_pb_desp_intereses`,",
    "que descuenta intereses pagados y permite observar si el saldo se mantiene",
    "una vez considerado el canal financiero. No se presentan tasas de ganancia",
    "en esta versión de la minuta."
  ),
  "",
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
  md_table(industry_table),
  "",
  paste(
    "La descomposición de 2024 muestra el mecanismo. La menor valorización del",
    "VBP aparece con signo negativo porque representa ganancia dejada de",
    "percibir bajo sobrevaluación. Los menores costos observados bajo",
    "sobrevaluación aparecen con signo positivo porque elevan la ganancia",
    "inicial respecto del contrafactual de paridad."
  ),
  "",
  paste0("![Industria total: componentes del saldo 2024](", fig_rel(fig2_path), ")"),
  "",
  md_table(component_table),
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
  paste0("![Escenario 1: saldo de ganancia por segmento](", fig_rel(scenario_sections$comercio_exterior$figures[[1]]), ")"),
  "",
  md_table(scenario_sections$comercio_exterior$table),
  "",
  paste0("![Escenario 1: componentes del saldo 2024](", fig_rel(scenario_sections$comercio_exterior$figures[[2]]), ")"),
  "",
  "Coeficientes que inciden en la masa de ganancia:",
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
  paste0("![Escenario 2: saldo de ganancia por segmento](", fig_rel(scenario_sections$bienes_transables$figures[[1]]), ")"),
  "",
  md_table(scenario_sections$bienes_transables$table),
  "",
  paste0("![Escenario 2: componentes del saldo 2024](", fig_rel(scenario_sections$bienes_transables$figures[[2]]), ")"),
  "",
  "Coeficientes que inciden en la masa de ganancia:",
  "",
  md_table(scenario_sections$bienes_transables$coef_table),
  "",
  "## Nota técnica",
  "",
  "La fórmula común aplicada en ambos escenarios es:",
  "",
  "```text",
  "factor_devaluacion = tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1",
  "delta_variable = variable_base * incidencia_seccion_variable * factor_devaluacion",
  "ganancia_pb_escenario = ganancia_pb + delta_vbp_pp - delta_consumo_intermedio_estimado - delta_remuneraciones - delta_consumo_capital_fijo",
  "saldo_sobrevaluacion_ganancia_pb = ganancia_pb - ganancia_pb_escenario",
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
