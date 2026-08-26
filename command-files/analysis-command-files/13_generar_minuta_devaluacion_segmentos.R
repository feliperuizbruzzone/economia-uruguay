#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readxl)
  library(scales)
  library(stringr)
  library(tidyr)
})

date_prefix <- Sys.getenv("EAAE_OUTPUT_DATE", unset = format(Sys.Date(), "%Y%m%d"))

analysis_dir <- file.path("data", "analysis-data")
figures_dir <- file.path("output", "figures", paste0("devaluacion_industria_segmentos_", date_prefix))
minutes_dir <- file.path("docs", "minutes")

input_xlsx <- file.path(
  analysis_dir,
  paste0(date_prefix, "_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx")
)

output_md <- file.path(
  minutes_dir,
  paste0(date_prefix, "_resultados_devaluacion_industria_segmentos.md")
)

if (!file.exists(input_xlsx)) {
  stop("Missing input workbook: ", input_xlsx)
}

dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(minutes_dir, recursive = TRUE, showWarnings = FALSE)

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

fmt_num <- function(x, digits = 1) {
  ifelse(
    is.na(x),
    "",
    trimws(format(round(x, digits), big.mark = ".", decimal.mark = ","))
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

section_labels <- c(
  "industria-total" = "Industria total",
  "exportadora" = "Segmento exportador",
  "mercado-interno" = "Mercado interno"
)

component_labels <- c(
  delta_vbp_pp = "VBP",
  delta_consumo_intermedio_estimado = "Consumo intermedio",
  delta_remuneraciones = "Remuneraciones",
  delta_consumo_capital_fijo = "Consumo capital fijo",
  delta_stock_capital_imputado = "Stock imputado",
  delta_intereses_industria_pesos = "Intereses"
)

devaluacion <- read_excel(input_xlsx, sheet = "devaluación-1") %>%
  filter(!is.na(.data$anno), !is.na(.data$seccion)) %>%
  mutate(
    seccion_label = recode(.data$seccion, !!!section_labels),
    seccion_label = factor(.data$seccion_label, levels = unname(section_labels))
  )

escenario_inicial <- read_excel(input_xlsx, sheet = "escenario-inicial") %>%
  filter(!is.na(.data$anno), !is.na(.data$seccion)) %>%
  mutate(
    seccion_label = recode(.data$seccion, !!!section_labels),
    seccion_label = factor(.data$seccion_label, levels = unname(section_labels))
  )

tipo_cambio <- read_excel(input_xlsx, sheet = "tipo-cambio") %>%
  mutate(
    factor_devaluacion =
      safe_divide(.data$tipo_cambio_paridad_pesos_usd, .data$tipo_cambio_comercial_pesos_usd) - 1
  )

required_sections <- names(section_labels)
if (!setequal(unique(devaluacion$seccion), required_sections)) {
  stop("Unexpected sections in devaluación-1.")
}

coeficientes <- devaluacion %>%
  distinct(
    seccion,
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
      incidencia_vbp_pp = "VBP",
      incidencia_consumo_intermedio_estimado = "Consumo intermedio",
      incidencia_remuneraciones = "Masa salarial",
      incidencia_consumo_capital_fijo = "Consumo capital fijo",
      incidencia_stock_capital_imputado = "Stock imputado",
      incidencia_intereses_industria_pesos = "Intereses"
    ),
    variable = factor(
      .data$variable,
      levels = c(
        "VBP",
        "Consumo intermedio",
        "Masa salarial",
        "Consumo capital fijo",
        "Stock imputado",
        "Intereses"
      )
    )
  )

resumen <- devaluacion %>%
  group_by(.data$seccion, .data$seccion_label) %>%
  summarise(
    tg_base_prom_pct = mean(.data$tasa_ganancia_pb, na.rm = TRUE) * 100,
    tg_dev_prom_pct = mean(.data$tasa_ganancia_pb_devaluacion, na.rm = TRUE) * 100,
    cambio_pp_prom = mean(.data$variacion_tasa_ganancia_pb_pp, na.rm = TRUE),
    tg_base_2024_pct = .data$tasa_ganancia_pb[.data$anno == 2024] * 100,
    tg_dev_2024_pct = .data$tasa_ganancia_pb_devaluacion[.data$anno == 2024] * 100,
    cambio_pp_2024 = .data$variacion_tasa_ganancia_pb_pp[.data$anno == 2024],
    ganancia_base_2024_miles_mill = .data$ganancia_pb[.data$anno == 2024] / 1e9,
    ganancia_dev_2024_miles_mill = .data$ganancia_pb_devaluacion[.data$anno == 2024] / 1e9,
    var_ganancia_2024_pct = .data$variacion_ganancia_pb_pct[.data$anno == 2024],
    .groups = "drop"
  )

descomposicion_2024 <- devaluacion %>%
  filter(.data$anno == 2024) %>%
  select("seccion", "seccion_label", all_of(names(component_labels))) %>%
  pivot_longer(
    cols = all_of(names(component_labels)),
    names_to = "componente",
    values_to = "valor"
  ) %>%
  mutate(
    componente = recode(.data$componente, !!!component_labels),
    componente = factor(.data$componente, levels = unname(component_labels)),
    # DECISION: VBP is the positive channel of devaluation. The other deltas
    # are displayed as additional costs or capital requirements to clarify
    # the economic direction of the effect.
    signo_grafico = if_else(.data$componente == "VBP", .data$valor, -.data$valor),
    valor_miles_mill = .data$valor / 1e9
  )

participacion_deltas_2024 <- descomposicion_2024 %>%
  select("seccion", "componente", "valor") %>%
  pivot_wider(names_from = "seccion", values_from = "valor") %>%
  mutate(
    exportadora_pct = safe_divide(.data$exportadora, .data$`industria-total`) * 100,
    mercado_interno_pct = safe_divide(.data$`mercado-interno`, .data$`industria-total`) * 100
  ) %>%
  select("componente", "exportadora_pct", "mercado_interno_pct")

fig1_path <- file.path(figures_dir, "01_factor_devaluacion_2020_2024.png")
fig2_path <- file.path(figures_dir, "02_coeficientes_incidencia_segmentos.png")
fig3_path <- file.path(figures_dir, "03_tasa_ganancia_base_devaluacion.png")
fig4_path <- file.path(figures_dir, "04_variacion_tasa_ganancia_pp.png")
fig5_path <- file.path(figures_dir, "05_descomposicion_efecto_2024.png")
fig6_path <- file.path(figures_dir, "06_participacion_segmentos_deltas_2024.png")

theme_report <- theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title.position = "plot",
    plot.caption.position = "plot",
    legend.position = "bottom"
  )

ggplot(tipo_cambio, aes(x = .data$anio, y = .data$factor_devaluacion)) +
  geom_line(linewidth = 0.8, color = "#2D6A4F") +
  geom_point(size = 2.2, color = "#2D6A4F") +
  geom_text(aes(label = percent(.data$factor_devaluacion, accuracy = 0.1, decimal.mark = ",")),
    vjust = -0.7,
    size = 3
  ) +
  scale_x_continuous(breaks = sort(unique(tipo_cambio$anio))) +
  scale_y_continuous(labels = percent_format(accuracy = 1, decimal.mark = ",")) +
  labs(
    title = "Factor de devaluación modelado",
    x = NULL,
    y = "TCP / TCC - 1",
    caption = "Fuente: elaboración propia en base a EAAE y supuestos Mussi de tipo de cambio."
  ) +
  theme_report
ggsave(fig1_path, width = 8, height = 4.6, dpi = 160)

ggplot(coeficientes, aes(x = .data$variable, y = .data$seccion_label, fill = .data$incidencia)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = percent(.data$incidencia, accuracy = 0.1, decimal.mark = ",")), size = 3) +
  scale_fill_gradient(low = "#F1FAEE", high = "#1D3557", labels = percent_format(decimal.mark = ",")) +
  labs(
    title = "Coeficientes de incidencia de la devaluación",
    x = NULL,
    y = NULL,
    fill = "Incidencia",
    caption = "Fuente: elaboración propia en base a EAAE y coeficientes Mussi."
  ) +
  theme_report +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
ggsave(fig2_path, width = 9, height = 4.8, dpi = 160)

tg_long <- devaluacion %>%
  select(
    anno,
    seccion_label,
    tasa_base = tasa_ganancia_pb,
    tasa_devaluacion = tasa_ganancia_pb_devaluacion
  ) %>%
  pivot_longer(
    cols = c("tasa_base", "tasa_devaluacion"),
    names_to = "escenario",
    values_to = "tasa"
  ) %>%
  mutate(
    escenario = recode(
      .data$escenario,
      tasa_base = "Escenario inicial",
      tasa_devaluacion = "Devaluación"
    )
  )

ggplot(tg_long, aes(x = .data$anno, y = .data$tasa, color = .data$escenario)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.8) +
  facet_wrap(vars(.data$seccion_label), nrow = 1) +
  scale_x_continuous(breaks = sort(unique(tg_long$anno))) +
  scale_y_continuous(labels = percent_format(accuracy = 1, decimal.mark = ",")) +
  scale_color_manual(values = c("Escenario inicial" = "#457B9D", "Devaluación" = "#E63946")) +
  labs(
    title = "Tasa de ganancia a precios básicos",
    x = NULL,
    y = NULL,
    color = NULL,
    caption = "Fuente: elaboración propia en base a EAAE y coeficientes Mussi."
  ) +
  theme_report
ggsave(fig3_path, width = 10.5, height = 4.8, dpi = 160)

ggplot(devaluacion, aes(x = factor(.data$anno), y = .data$variacion_tasa_ganancia_pb_pp, fill = .data$seccion_label)) +
  geom_hline(yintercept = 0, color = "grey40", linewidth = 0.35) +
  geom_col(position = position_dodge(width = 0.75), width = 0.7) +
  scale_fill_manual(values = c(
    "Industria total" = "#457B9D",
    "Segmento exportador" = "#2D6A4F",
    "Mercado interno" = "#E76F51"
  )) +
  labs(
    title = "Cambio en la tasa de ganancia ante la devaluación",
    x = NULL,
    y = "Puntos porcentuales",
    fill = NULL,
    caption = "Fuente: elaboración propia en base a EAAE y coeficientes Mussi."
  ) +
  theme_report
ggsave(fig4_path, width = 9, height = 5, dpi = 160)

ggplot(descomposicion_2024, aes(x = .data$componente, y = .data$signo_grafico / 1e9, fill = .data$seccion_label)) +
  geom_hline(yintercept = 0, color = "grey40", linewidth = 0.35) +
  geom_col(position = position_dodge(width = 0.75), width = 0.7) +
  scale_fill_manual(values = c(
    "Industria total" = "#457B9D",
    "Segmento exportador" = "#2D6A4F",
    "Mercado interno" = "#E76F51"
  )) +
  labs(
    title = "Canales monetarios del efecto devaluación en 2024",
    subtitle = "VBP se muestra como impulso positivo; costos, stock e intereses como cargas adicionales",
    x = NULL,
    y = "Miles de millones de pesos corrientes",
    fill = NULL,
    caption = "Fuente: elaboración propia en base a EAAE y coeficientes Mussi."
  ) +
  theme_report +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
ggsave(fig5_path, width = 10.5, height = 5.2, dpi = 160)

participacion_long <- participacion_deltas_2024 %>%
  pivot_longer(
    cols = c("exportadora_pct", "mercado_interno_pct"),
    names_to = "segmento",
    values_to = "participacion"
  ) %>%
  mutate(
    segmento = recode(
      .data$segmento,
      exportadora_pct = "Segmento exportador",
      mercado_interno_pct = "Mercado interno"
    )
  )

ggplot(participacion_long, aes(x = .data$componente, y = .data$participacion, fill = .data$segmento)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.7) +
  scale_y_continuous(labels = percent_format(scale = 1, accuracy = 1, decimal.mark = ",")) +
  scale_fill_manual(values = c("Segmento exportador" = "#2D6A4F", "Mercado interno" = "#E76F51")) +
  labs(
    title = "Participación de los segmentos en los deltas de la industria total, 2024",
    x = NULL,
    y = "Porcentaje del delta industrial total",
    fill = NULL,
    caption = "Fuente: elaboración propia en base a EAAE y coeficientes Mussi."
  ) +
  theme_report +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
ggsave(fig6_path, width = 10.5, height = 5.2, dpi = 160)

coef_table <- coeficientes %>%
  mutate(
    incidencia = fmt_pct(.data$incidencia * 100),
    seccion_label = as.character(.data$seccion_label),
    variable = as.character(.data$variable)
  ) %>%
  select(
    `Sección` = seccion_label,
    `Variable afectada` = variable,
    `Incidencia` = incidencia
  ) %>%
  arrange(.data$`Sección`, .data$`Variable afectada`)

resumen_table <- resumen %>%
  transmute(
    `Sección` = as.character(.data$seccion_label),
    `TG base prom.` = fmt_pct(.data$tg_base_prom_pct),
    `TG devaluada prom.` = fmt_pct(.data$tg_dev_prom_pct),
    `Cambio prom.` = fmt_pp(.data$cambio_pp_prom),
    `TG base 2024` = fmt_pct(.data$tg_base_2024_pct),
    `TG devaluada 2024` = fmt_pct(.data$tg_dev_2024_pct),
    `Cambio 2024` = fmt_pp(.data$cambio_pp_2024),
    `Var. ganancia 2024` = fmt_pct(.data$var_ganancia_2024_pct)
  )

descomp_table <- devaluacion %>%
  filter(.data$anno == 2024) %>%
  transmute(
    `Sección` = as.character(.data$seccion_label),
    `Delta VBP` = fmt_num(.data$delta_vbp_pp / 1e9),
    `Delta CI` = fmt_num(.data$delta_consumo_intermedio_estimado / 1e9),
    `Delta remuneraciones` = fmt_num(.data$delta_remuneraciones / 1e9),
    `Delta CCF` = fmt_num(.data$delta_consumo_capital_fijo / 1e9, 2),
    `Delta stock` = fmt_num(.data$delta_stock_capital_imputado / 1e9),
    `Delta intereses` = fmt_num(.data$delta_intereses_industria_pesos / 1e9, 2)
  )

participacion_table <- participacion_deltas_2024 %>%
  transmute(
    `Componente` = as.character(componente),
    `Exportador / industria total` = fmt_pct(exportadora_pct),
    `Mercado interno / industria total` = fmt_pct(mercado_interno_pct)
  )

summary_2024 <- resumen %>%
  filter(.data$seccion %in% c("industria-total", "exportadora", "mercado-interno")) %>%
  select(
    seccion,
    tg_base_2024_pct,
    tg_dev_2024_pct,
    cambio_pp_2024,
    var_ganancia_2024_pct
  )

value_for <- function(data, seccion, variable) {
  data %>%
    filter(.data$seccion == !!seccion) %>%
    pull({{ variable }})
}

fig_rel <- function(path) {
  paste0("../../", path)
}

delta_industria_2024 <- devaluacion %>%
  filter(.data$anno == 2024, .data$seccion == "industria-total") %>%
  pull(.data$delta_vbp_pp) %>%
  `/`(1e9)

md <- c(
  "# Efectos diferenciados de una devaluación sobre la industria manufacturera uruguaya, 2020-2024",
  "",
  paste0(
    "Fuente de trabajo: `",
    input_xlsx,
    "`, hojas `escenario-inicial`, `tipo-cambio` y `devaluación-1`."
  ),
  "",
  "## Síntesis",
  "",
  paste(
    "El ejercicio compara los resultados corrientes observados de la industria",
    "manufacturera con un escenario en el que el tipo de cambio pasa desde el",
    "nivel comercial al nivel de paridad. La simulación no modifica cantidades,",
    "productividad ni estructura productiva; aplica coeficientes de incidencia",
    "sobre componentes monetarios para estimar un impacto contable de corto",
    "plazo."
  ),
  "",
  paste0(
    "Con coeficientes diferenciados por sección, el resultado central es una",
    " fractura interna dentro de la manufactura. La industria total aumenta su",
    " tasa de ganancia a precios básicos, pero ese resultado es arrastrado por",
    " el segmento exportador. En 2024, el segmento exportador pasa de ",
    fmt_pct(value_for(summary_2024, "exportadora", tg_base_2024_pct)),
    " a ",
    fmt_pct(value_for(summary_2024, "exportadora", tg_dev_2024_pct)),
    ", mientras que el segmento mercado interno cae de ",
    fmt_pct(value_for(summary_2024, "mercado-interno", tg_base_2024_pct)),
    " a ",
    fmt_pct(value_for(summary_2024, "mercado-interno", tg_dev_2024_pct)),
    "."
  ),
  "",
  "## Supuestos y escenarios",
  "",
  "- `escenario-inicial` contiene los valores corrientes observados para industria total, segmento exportador y segmento mercado interno.",
  "- `devaluación-1` recalcula los componentes mediante `factor_devaluacion = tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1`.",
  "- El canal positivo se modela sobre `vbp_pp`; los canales de costo o requerimiento adicional se modelan sobre consumo intermedio, remuneraciones, consumo de capital fijo, stock imputado e intereses.",
  "- Los intereses industriales son una serie agregada de manufactura y se distribuyen por segmento según participación en `vbp_pp`.",
  "- El grupo `combustible` queda fuera del libro de resultados y de esta minuta; se conserva sólo en el panel CSV para trazabilidad contable.",
  "",
  paste0("![Factor de devaluación modelado](", fig_rel(fig1_path), ")"),
  "",
  "## Coeficientes de incidencia",
  "",
  paste(
    "La diferencia principal frente a ejercicios anteriores es que los",
    "coeficientes ya no son únicos para toda la manufactura. La industria total",
    "conserva los coeficientes previos, mientras que los segmentos exportador y",
    "mercado interno toman coeficientes específicos. Esto permite que el mismo",
    "shock cambiario tenga efectos distintos según orientación comercial y",
    "estructura de costos."
  ),
  "",
  paste0("![Coeficientes de incidencia por segmento](", fig_rel(fig2_path), ")"),
  "",
  md_table(coef_table),
  "",
  "## Resultados principales",
  "",
  paste0(
    "La tasa de ganancia a precios básicos de la industria total aumenta en",
    " promedio ",
    fmt_pp(value_for(resumen, "industria-total", cambio_pp_prom)),
    " entre 2020 y 2024. En el segmento exportador el aumento promedio es ",
    fmt_pp(value_for(resumen, "exportadora", cambio_pp_prom)),
    ". En cambio, el segmento mercado interno muestra una variación promedio de ",
    fmt_pp(value_for(resumen, "mercado-interno", cambio_pp_prom)),
    ", lo que indica que el encarecimiento de costos supera el impulso positivo ",
    "sobre el VBP."
  ),
  "",
  paste0("![Tasa de ganancia a precios básicos](", fig_rel(fig3_path), ")"),
  "",
  paste0("![Cambio en tasa de ganancia](", fig_rel(fig4_path), ")"),
  "",
  md_table(resumen_table),
  "",
  "## Mecanismo de transmisión en 2024",
  "",
  paste0(
    "En 2024, el aumento de `vbp_pp` es el principal canal positivo. Para la",
    " industria total equivale a ",
    fmt_num(delta_industria_2024),
    " miles de millones de pesos corrientes. Ese impulso se compensa parcialmente ",
    "por el aumento de consumo intermedio, remuneraciones, consumo de capital ",
    "fijo, stock imputado e intereses. La asimetría por segmento es clara: el ",
    "segmento exportador capta la mayor parte del impulso por VBP, mientras que ",
    "en mercado interno el aumento de costos queda por encima del impulso de ",
    "ventas."
  ),
  "",
  paste0("![Descomposición del efecto en 2024](", fig_rel(fig5_path), ")"),
  "",
  md_table(descomp_table),
  "",
  "## Contribución relativa de los segmentos",
  "",
  paste0(
    "La lectura por participaciones muestra que, en 2024, el segmento exportador",
    " explica ",
    fmt_pct(participacion_deltas_2024$exportadora_pct[participacion_deltas_2024$componente == "VBP"]),
    " del delta de VBP de la industria total, frente a ",
    fmt_pct(participacion_deltas_2024$mercado_interno_pct[participacion_deltas_2024$componente == "VBP"]),
    " del segmento mercado interno. Esta concentración explica por qué la mejora",
    " agregada de la industria total no debe leerse como un efecto homogéneo para",
    " toda la manufactura."
  ),
  "",
  paste0("![Participación de segmentos en los deltas 2024](", fig_rel(fig6_path), ")"),
  "",
  md_table(participacion_table),
  "",
  "## Interpretación",
  "",
  paste(
    "La simulación sugiere que una devaluación de esta magnitud redistribuye",
    "condiciones de rentabilidad dentro de la industria. Para el segmento",
    "exportador, el aumento del VBP en pesos domina el encarecimiento de costos",
    "y eleva con fuerza la tasa de ganancia. Para el segmento mercado interno,",
    "la menor incidencia del canal VBP y la mayor presión relativa de costos",
    "producen una caída de la rentabilidad."
  ),
  "",
  paste(
    "Por lo tanto, el resultado agregado de la industria total debe interpretarse",
    "con cautela: expresa una mejora promedio, pero esa mejora proviene de una",
    "composición sectorial desigual. La devaluación no opera como estímulo",
    "general equivalente para toda la manufactura, sino como un shock que",
    "beneficia principalmente a los grupos con mayor capacidad de valorización",
    "en moneda extranjera."
  ),
  "",
  "## Anexo técnico",
  "",
  "La fórmula general aplicada es:",
  "",
  "```text",
  "delta_variable = variable_base * incidencia_seccion_variable * factor_devaluacion",
  "variable_devaluacion = variable_base + delta_variable",
  "factor_devaluacion = tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1",
  "```",
  "",
  "La ganancia a precios básicos bajo devaluación se calcula como:",
  "",
  "```text",
  "ganancia_pb_devaluacion =",
  "  ganancia_pb + delta_vbp_pp - delta_consumo_intermedio_estimado -",
  "  delta_remuneraciones - delta_consumo_capital_fijo",
  "```",
  "",
  "El capital total adelantado bajo devaluación incorpora el cambio en stock imputado y en capital circulante:",
  "",
  "```text",
  "capital_total_adelantado_devaluacion =",
  "  capital_total_adelantado + delta_stock_capital_imputado +",
  "  (delta_remuneraciones + delta_consumo_intermedio_estimado) / rotacion_calibrada_sobre_6_6",
  "```",
  "",
  "La tasa de ganancia a precios básicos bajo devaluación se calcula como:",
  "",
  "```text",
  "tasa_ganancia_pb_devaluacion =",
  "  ganancia_pb_devaluacion / capital_total_adelantado_devaluacion",
  "```"
)

writeLines(md, output_md, useBytes = TRUE)

cat("Minuta creada: ", output_md, "\n", sep = "")
cat("Figuras creadas en: ", figures_dir, "\n", sep = "")
