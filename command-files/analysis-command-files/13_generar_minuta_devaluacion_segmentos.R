#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
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

clasificacion_path <- file.path(
  "data",
  "input-data",
  "mussi",
  "20260824_subramas_industriales_fuente_eaae_2020_2024.csv"
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
  delta_vbp_pp = "VBP/exportador",
  delta_consumo_intermedio_estimado = "Consumo intermedio",
  delta_remuneraciones = "Remuneraciones",
  delta_consumo_capital_fijo = "Consumo capital fijo",
  delta_stock_capital_imputado = "Stock imputado",
  delta_intereses_industria_pesos = "Intereses pagados"
)

caption_fuente <- paste(
  "Fuente: elaboración propia en base a EAAE y Oyanthabal,",
  "con base en metodología de Iñigo Carrera (2007)."
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

clasificacion_segmentos <- read_delim(
  clasificacion_path,
  delim = ";",
  show_col_types = FALSE,
  locale = locale(encoding = "UTF-8")
)
names(clasificacion_segmentos)[10] <- "clasificacion"
clasificacion_segmentos <- clasificacion_segmentos %>%
  transmute(
    division_publicada = as.character(.data$division_publicada),
    descripcion_fuente = str_squish(str_remove(as.character(.data$descripcion_fuente), "\\.$")),
    clasificacion = str_squish(as.character(.data$clasificacion))
  )

segmento_items <- function(clasificacion) {
  clasificacion_segmentos %>%
    filter(.data$clasificacion == !!clasificacion) %>%
    arrange(.data$division_publicada) %>%
    transmute(item = paste0(.data$division_publicada, ": ", .data$descripcion_fuente)) %>%
    pull(.data$item)
}

ramas_exportadoras <- segmento_items("Exportadora")
ramas_mercado_interno <- segmento_items("Mercado interno")

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
      incidencia_vbp_pp = "VBP/exportador",
      incidencia_consumo_intermedio_estimado = "Consumo intermedio",
      incidencia_remuneraciones = "Masa salarial",
      incidencia_consumo_capital_fijo = "Consumo capital fijo",
      incidencia_stock_capital_imputado = "Stock imputado",
      incidencia_intereses_industria_pesos = "Intereses pagados"
    ),
    variable = factor(
      .data$variable,
      levels = c(
        "VBP/exportador",
        "Consumo intermedio",
        "Masa salarial",
        "Consumo capital fijo",
        "Stock imputado",
        "Intereses pagados"
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
    # DECISION: VBP/exportador is the positive channel when closing the
    # exchange-rate gap. The other deltas are displayed as additional costs or
    # capital requirements to clarify the economic direction of the effect.
    signo_grafico = if_else(.data$componente == "VBP/exportador", .data$valor, -.data$valor),
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
    title = "Brecha cambiaria modelada",
    x = NULL,
    y = "TCP / TCC - 1",
    caption = caption_fuente
  ) +
  theme_report
ggsave(fig1_path, width = 8, height = 4.6, dpi = 160)

ggplot(coeficientes, aes(x = .data$variable, y = .data$seccion_label, fill = .data$incidencia)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = percent(.data$incidencia, accuracy = 0.1, decimal.mark = ",")), size = 3) +
  scale_fill_gradient(low = "#F1FAEE", high = "#1D3557", labels = percent_format(decimal.mark = ",")) +
  labs(
    title = "Coeficientes de incidencia del cierre de brecha cambiaria",
    x = NULL,
    y = NULL,
    fill = "Incidencia",
    caption = caption_fuente
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
      tasa_devaluacion = "Paridad cambiaria"
    )
  )

ggplot(tg_long, aes(x = .data$anno, y = .data$tasa, color = .data$escenario)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.8) +
  facet_wrap(vars(.data$seccion_label), nrow = 1) +
  scale_x_continuous(breaks = sort(unique(tg_long$anno))) +
  scale_y_continuous(labels = percent_format(accuracy = 1, decimal.mark = ",")) +
  scale_color_manual(values = c("Escenario inicial" = "#457B9D", "Paridad cambiaria" = "#E63946")) +
  labs(
    title = "Tasa de ganancia a precios básicos",
    x = NULL,
    y = NULL,
    color = NULL,
    caption = caption_fuente
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
    title = "Cambio en la tasa de ganancia al cerrar la brecha cambiaria",
    x = NULL,
    y = "Puntos porcentuales",
    fill = NULL,
    caption = caption_fuente
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
    title = "Canales monetarios del cierre de brecha cambiaria en 2024",
    subtitle = "VBP/exportador se muestra como impulso positivo; costos, stock e intereses pagados como cargas adicionales",
    x = NULL,
    y = "Miles de millones de pesos corrientes",
    fill = NULL,
    caption = caption_fuente
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
    caption = caption_fuente
  ) +
  theme_report +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
ggsave(fig6_path, width = 10.5, height = 5.2, dpi = 160)

coef_table <- coeficientes %>%
  mutate(
    incidencia = fmt_pct(.data$incidencia * 100),
    seccion_label = as.character(.data$seccion_label),
    variable = as.character(.data$variable),
    efecto_contable = case_when(
      .data$variable == "VBP/exportador" ~ "Positivo para la ganancia",
      .data$variable == "Stock imputado" ~ "Negativo: eleva capital adelantado",
      TRUE ~ "Negativo: eleva costos o gastos"
    )
  ) %>%
  select(
    `Sección` = seccion_label,
    `Variable afectada` = variable,
    `Incidencia` = incidencia,
    `Efecto contable ante paridad` = efecto_contable
  ) %>%
  arrange(.data$`Sección`, .data$`Variable afectada`)

resumen_table <- resumen %>%
  transmute(
    `Sección` = as.character(.data$seccion_label),
    `TG base prom.` = fmt_pct(.data$tg_base_prom_pct),
    `TG paridad prom.` = fmt_pct(.data$tg_dev_prom_pct),
    `Cambio prom.` = fmt_pp(.data$cambio_pp_prom),
    `TG base 2024` = fmt_pct(.data$tg_base_2024_pct),
    `TG paridad 2024` = fmt_pct(.data$tg_dev_2024_pct),
    `Cambio 2024` = fmt_pp(.data$cambio_pp_2024),
    `Var. ganancia 2024` = fmt_pct(.data$var_ganancia_2024_pct)
  )

descomp_table <- devaluacion %>%
  filter(.data$anno == 2024) %>%
  transmute(
    `Sección` = as.character(.data$seccion_label),
    `Delta VBP/exportador` = fmt_num(.data$delta_vbp_pp / 1e9),
    `Delta CI` = fmt_num(.data$delta_consumo_intermedio_estimado / 1e9),
    `Delta remuneraciones` = fmt_num(.data$delta_remuneraciones / 1e9),
    `Delta CCF` = fmt_num(.data$delta_consumo_capital_fijo / 1e9, 2),
    `Delta stock` = fmt_num(.data$delta_stock_capital_imputado / 1e9),
    `Delta intereses pagados` = fmt_num(.data$delta_intereses_industria_pesos / 1e9, 2)
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

deltas_2024_resumen <- devaluacion %>%
  filter(.data$anno == 2024) %>%
  transmute(
    seccion,
    vbp_miles_mill = .data$delta_vbp_pp / 1e9,
    gastos_miles_mill = (
      .data$delta_consumo_intermedio_estimado +
        .data$delta_remuneraciones +
        .data$delta_consumo_capital_fijo +
        .data$delta_intereses_industria_pesos
    ) / 1e9,
    stock_miles_mill = .data$delta_stock_capital_imputado / 1e9
  )

delta_value <- function(seccion, variable) {
  deltas_2024_resumen %>%
    filter(.data$seccion == !!seccion) %>%
    pull({{ variable }})
}

md <- c(
  "# Apropiación de riqueza por sobrevaluación cambiaria en la industria manufacturera uruguaya, 2020-2024",
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
    "El ejercicio dimensiona la apropiación de riqueza asociada a sostener un",
    "tipo de cambio comercial por debajo del tipo de cambio de paridad. Para",
    "ello compara los resultados corrientes observados de la industria",
    "manufacturera con un contrafactual anual en el que las magnitudes sensibles",
    "al tipo de cambio se valoran con la paridad. La simulación no modifica",
    "cantidades, productividad ni estructura productiva; aplica coeficientes de",
    "incidencia sobre componentes monetarios para estimar un impacto contable",
    "de corto plazo."
  ),
  "",
  paste(
    "Las fuentes usadas son: EAAE para VBP, VAB, remuneraciones, consumo",
    "intermedio estimado, consumo de capital fijo, stock de capital y capital",
    "adelantado; Oyanthabal, con base en la metodología de Iñigo Carrera (2007),",
    "para los tipos de cambio comercial/paridad y los coeficientes de incidencia",
    "del ejercicio; y la clasificación operativa de subramas industriales",
    "2020-2024 usada para separar industria exportadora, mercado interno y",
    "combustible."
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
    "Con coeficientes diferenciados por sección, el resultado central es una",
    " fractura interna dentro de la manufactura. Bajo el contrafactual de",
    " paridad, la industria total aumenta su tasa de ganancia a precios básicos,",
    " pero ese resultado es arrastrado por el segmento exportador. En 2024, el",
    " segmento exportador pasa de ",
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
  "- `devaluación-1` mantiene el nombre técnico de la hoja, pero analíticamente se interpreta como cierre anual de la brecha entre tipo de cambio comercial y tipo de cambio de paridad.",
  "- El cálculo se realiza año a año mediante `factor_devaluacion = tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1`; no contempla efectos acumulados ni respuestas dinámicas de cantidades, precios relativos o productividad.",
  "- Desde otro punto de vista, el mismo ejercicio permite dimensionar el efecto que tiene sostener un tipo de cambio sobrevaluado sobre la apropiación de riqueza por parte de la industria.",
  "- El canal positivo se modela sobre `vbp_pp` como `VBP/exportador`; los canales negativos se modelan sobre consumo intermedio, remuneraciones, consumo de capital fijo, stock imputado e intereses pagados.",
  "- Los intereses industriales son una serie agregada de manufactura y se distribuyen por segmento según participación en `vbp_pp`.",
  "- El grupo `combustible` no se presenta como segmento autónomo en el libro de resultados ni en esta minuta; queda incorporado en la industria total y se conserva en el panel CSV para trazabilidad contable.",
  "",
  "Ramas incluidas en el segmento exportador:",
  paste0("- ", ramas_exportadoras),
  "",
  "Ramas incluidas en el segmento mercado interno:",
  paste0("- ", ramas_mercado_interno),
  "",
  paste0("![Brecha cambiaria modelada](", fig_rel(fig1_path), ")"),
  "",
  "## Coeficientes de incidencia",
  "",
  paste(
    "Los coeficientes indican qué proporción de cada variable queda expuesta al",
    "cierre de la brecha cambiaria. Desde el punto de vista del contrafactual de",
    "paridad, `VBP/exportador` tiene signo positivo para la ganancia, porque",
    "eleva la valorización de ventas asociadas al tipo de cambio. En cambio,",
    "consumo intermedio, masa salarial, consumo de capital fijo e intereses",
    "pagados operan como gastos o costos; el stock imputado afecta negativamente",
    "la tasa porque eleva el capital adelantado."
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
    "sobre el VBP/exportador."
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
    "En 2024, el aumento de `vbp_pp` es el principal canal positivo. El gráfico",
    " y el cuadro expresan los deltas en miles de millones de pesos corrientes.",
    " Para la",
    " industria total equivale a ",
    fmt_num(delta_industria_2024),
    " miles de millones de pesos corrientes. Ese impulso se compensa parcialmente ",
    "por el aumento de consumo intermedio, remuneraciones, consumo de capital ",
    "fijo, stock imputado e intereses pagados. La asimetría por segmento es clara: el ",
    "segmento exportador capta la mayor parte del impulso por VBP/exportador, mientras que ",
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
    fmt_pct(participacion_deltas_2024$exportadora_pct[participacion_deltas_2024$componente == "VBP/exportador"]),
    " del delta de VBP/exportador de la industria total, frente a ",
    fmt_pct(participacion_deltas_2024$mercado_interno_pct[participacion_deltas_2024$componente == "VBP/exportador"]),
    " del segmento mercado interno. Esta concentración explica por qué la mejora",
    " agregada de la industria total no debe leerse como un efecto homogéneo para",
    " toda la manufactura."
  ),
  "",
  paste0(
    "En magnitudes de 2024, el VBP/exportador de la industria total aumenta ",
    fmt_num(delta_value("industria-total", vbp_miles_mill)),
    " miles de millones de pesos corrientes, mientras los gastos modelados",
    " aumentan ",
    fmt_num(delta_value("industria-total", gastos_miles_mill)),
    " y el stock imputado aumenta ",
    fmt_num(delta_value("industria-total", stock_miles_mill)),
    ". En el segmento exportador, el aumento de VBP/exportador es ",
    fmt_num(delta_value("exportadora", vbp_miles_mill)),
    " frente a gastos por ",
    fmt_num(delta_value("exportadora", gastos_miles_mill)),
    " y stock por ",
    fmt_num(delta_value("exportadora", stock_miles_mill)),
    ". En mercado interno, el VBP/exportador aumenta ",
    fmt_num(delta_value("mercado-interno", vbp_miles_mill)),
    ", pero los gastos aumentan ",
    fmt_num(delta_value("mercado-interno", gastos_miles_mill)),
    " y el stock ",
    fmt_num(delta_value("mercado-interno", stock_miles_mill)),
    "."
  ),
  "",
  paste0("![Participación de segmentos en los deltas 2024](", fig_rel(fig6_path), ")"),
  "",
  md_table(participacion_table),
  "",
  "## Interpretación",
  "",
  paste(
    "La simulación sugiere que la sobrevaluación cambiaria redistribuye",
    "condiciones de rentabilidad dentro de la industria. Para el segmento",
    "exportador, cerrar la brecha con la paridad elevaría el VBP en pesos por",
    "encima del encarecimiento de costos y aumentaría con fuerza la tasa de",
    "ganancia. Desde la lectura inversa, sostener el tipo de cambio comercial",
    "sobrevaluado reduce esa apropiación potencial. Para el segmento mercado",
    "interno, la menor incidencia del canal VBP y la mayor presión relativa de",
    "costos implican que el cierre de la brecha deteriora la rentabilidad."
  ),
  "",
  paste(
    "Por lo tanto, el resultado agregado de la industria total debe interpretarse",
    "con cautela: expresa una mejora promedio bajo paridad, pero esa mejora",
    "proviene de una composición sectorial desigual. La sobrevaluación no afecta",
    "de manera equivalente a toda la manufactura: limita especialmente la",
    "valorización del segmento exportador y, al mismo tiempo, contiene costos",
    "para actividades más orientadas al mercado interno."
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
  "La ganancia a precios básicos bajo cierre de brecha/paridad se calcula como:",
  "",
  "```text",
  "ganancia_pb_devaluacion =",
  "  ganancia_pb + delta_vbp_pp - delta_consumo_intermedio_estimado -",
  "  delta_remuneraciones - delta_consumo_capital_fijo",
  "```",
  "",
  "El capital total adelantado bajo cierre de brecha/paridad incorpora el cambio en stock imputado y en capital circulante:",
  "",
  "```text",
  "capital_total_adelantado_devaluacion =",
  "  capital_total_adelantado + delta_stock_capital_imputado +",
  "  (delta_remuneraciones + delta_consumo_intermedio_estimado) / rotacion_calibrada_sobre_6_6",
  "```",
  "",
  "La tasa de ganancia a precios básicos bajo cierre de brecha/paridad se calcula como:",
  "",
  "```text",
  "tasa_ganancia_pb_devaluacion =",
  "  ganancia_pb_devaluacion / capital_total_adelantado_devaluacion",
  "```"
)

writeLines(md, output_md, useBytes = TRUE)

cat("Minuta creada: ", output_md, "\n", sep = "")
cat("Figuras creadas en: ", figures_dir, "\n", sep = "")
