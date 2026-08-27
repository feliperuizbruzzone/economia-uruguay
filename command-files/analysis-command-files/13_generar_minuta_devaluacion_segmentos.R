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

if (!file.exists(input_xlsx)) {
  stop("Missing input workbook: ", input_xlsx)
}
if (!file.exists(clasificacion_path)) {
  stop("Missing classification file: ", clasificacion_path)
}

dir.create(docs_dir, recursive = TRUE, showWarnings = FALSE)

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

read_mussi_classification <- function(path) {
  lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
  rows <- lapply(lines[-1], function(line) {
    parts <- strsplit(line, ";", fixed = TRUE)[[1]]
    tibble(
      division_publicada = str_squish(parts[[1]]),
      descripcion_fuente = str_squish(str_remove(parts[[3]], "\\.$")),
      clasificacion = str_squish(parts[[length(parts)]])
    )
  }) %>%
    bind_rows()

  rows
}

section_labels <- c(
  "industria-total" = "Industria total",
  "exportadora" = "Segmento exportador",
  "mercado-interno" = "Mercado interno"
)

scenario_specs <- tibble::tribble(
  ~sheet, ~slug, ~titulo, ~intro, ~vbp_label,
  "Escenario 1 - Comercio Exterior",
  "escenario_1_comercio_exterior",
  "Escenario 1: incidencia directa del comercio exterior",
  paste(
    "Este escenario modela la apropiación de riqueza vía sobrevaluación de la",
    "moneda sólo sobre los componentes importados de costos y capital y sobre",
    "la parte exportada de la producción. Por tanto, mide la incidencia directa",
    "de importaciones y exportaciones sobre la tasa de ganancia industrial."
  ),
  "VBP/exportador",
  "Escenario 2 - Bienes Transables",
  "escenario_2_bienes_transables",
  "Escenario 2: incidencia de bienes transables",
  paste(
    "Este escenario modela la apropiación de riqueza vía sobrevaluación sobre",
    "el conjunto de mercancías cuyos precios internos se rigen por precios",
    "internacionales, aunque sean producidas localmente y vendidas en el mercado",
    "interno. Por eso incorpora también la revaluación de producción local",
    "transable y su efecto sobre la tasa de ganancia."
  ),
  "VBP/transable"
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

clasificacion_segmentos <- read_mussi_classification(clasificacion_path)

segmento_items <- function(clasificacion) {
  clasificacion_segmentos %>%
    filter(.data$clasificacion == !!clasificacion) %>%
    arrange(.data$division_publicada) %>%
    transmute(item = paste0(.data$division_publicada, ": ", .data$descripcion_fuente)) %>%
    pull(.data$item)
}

ramas_exportadoras <- segmento_items("Exportadora")
ramas_mercado_interno <- segmento_items("Mercado interno")

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
if (!setequal(unique(escenario_inicial$seccion), required_sections)) {
  stop("Unexpected sections in escenario-inicial.")
}

fig_rel <- function(path) {
  paste0("../", path)
}

value_for <- function(data, seccion, variable) {
  data %>%
    filter(.data$seccion == !!seccion) %>%
    pull({{ variable }})
}

write_scenario_minute <- function(spec) {
  figures_dir <- file.path(
    "output",
    "figures",
    paste0("devaluacion_industria_segmentos_", date_prefix, "_", spec$slug)
  )
  dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

  output_md <- file.path(
    docs_dir,
    paste0(date_prefix, "_resultados_devaluacion_", spec$slug, ".md")
  )

  component_labels <- c(
    delta_vbp_pp = spec$vbp_label,
    delta_consumo_intermedio_estimado = "Consumo intermedio",
    delta_remuneraciones = "Remuneraciones",
    delta_consumo_capital_fijo = "Consumo capital fijo",
    delta_stock_capital_imputado = "Stock imputado",
    delta_intereses_industria_pesos = "Intereses pagados"
  )

  devaluacion <- read_excel(input_xlsx, sheet = spec$sheet) %>%
    filter(!is.na(.data$anno), !is.na(.data$seccion)) %>%
    mutate(
      seccion_label = recode(.data$seccion, !!!section_labels),
      seccion_label = factor(.data$seccion_label, levels = unname(section_labels))
    )

  if (!setequal(unique(devaluacion$seccion), required_sections)) {
    stop("Unexpected sections in scenario sheet: ", spec$sheet)
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
        incidencia_vbp_pp = spec$vbp_label,
        incidencia_consumo_intermedio_estimado = "Consumo intermedio",
        incidencia_remuneraciones = "Masa salarial",
        incidencia_consumo_capital_fijo = "Consumo capital fijo",
        incidencia_stock_capital_imputado = "Stock imputado",
        incidencia_intereses_industria_pesos = "Intereses pagados"
      ),
      variable = factor(
        .data$variable,
        levels = c(
          spec$vbp_label,
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
      # DECISION: the VBP channel is the positive channel when closing the
      # exchange-rate gap. The remaining deltas are displayed as additional
      # costs or capital requirements to clarify the economic direction.
      signo_grafico = if_else(.data$componente == spec$vbp_label, .data$valor, -.data$valor),
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
  fig3_path <- file.path(figures_dir, "03_tasa_ganancia_base_escenario.png")
  fig4_path <- file.path(figures_dir, "04_variacion_tasa_ganancia_pp.png")
  fig5_path <- file.path(figures_dir, "05_descomposicion_efecto_2024.png")
  fig6_path <- file.path(figures_dir, "06_participacion_segmentos_deltas_2024.png")

  ggplot(tipo_cambio, aes(x = .data$anio, y = .data$factor_devaluacion)) +
    geom_line(linewidth = 0.8, color = "#2D6A4F") +
    geom_point(size = 2.2, color = "#2D6A4F") +
    geom_text(
      aes(label = percent(.data$factor_devaluacion, accuracy = 0.1, decimal.mark = ",")),
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
      subtitle = spec$sheet,
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
        tasa_devaluacion = "Cierre de brecha"
      )
    )

  ggplot(tg_long, aes(x = .data$anno, y = .data$tasa, color = .data$escenario)) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 1.8) +
    facet_wrap(vars(.data$seccion_label), nrow = 1) +
    scale_x_continuous(breaks = sort(unique(tg_long$anno))) +
    scale_y_continuous(labels = percent_format(accuracy = 1, decimal.mark = ",")) +
    scale_color_manual(values = c("Escenario inicial" = "#457B9D", "Cierre de brecha" = "#E63946")) +
    labs(
      title = "Tasa de ganancia a precios básicos",
      x = NULL,
      y = NULL,
      color = NULL,
      caption = caption_fuente
    ) +
    theme_report
  ggsave(fig3_path, width = 10.5, height = 4.8, dpi = 160)

  ggplot(devaluacion, aes(
    x = factor(.data$anno),
    y = .data$variacion_tasa_ganancia_pb_pp,
    fill = .data$seccion_label
  )) +
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

  ggplot(descomposicion_2024, aes(
    x = .data$componente,
    y = .data$signo_grafico / 1e9,
    fill = .data$seccion_label
  )) +
    geom_hline(yintercept = 0, color = "grey40", linewidth = 0.35) +
    geom_col(position = position_dodge(width = 0.75), width = 0.7) +
    scale_fill_manual(values = c(
      "Industria total" = "#457B9D",
      "Segmento exportador" = "#2D6A4F",
      "Mercado interno" = "#E76F51"
    )) +
    labs(
      title = "Canales monetarios del cierre de brecha cambiaria en 2024",
      subtitle = paste(spec$vbp_label, "se muestra como impulso positivo; costos, stock e intereses pagados como cargas adicionales"),
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
        .data$variable == spec$vbp_label ~ "Positivo para la ganancia",
        .data$variable == "Stock imputado" ~ "Negativo: eleva capital adelantado",
        TRUE ~ "Negativo: eleva costos o gastos"
      )
    ) %>%
    select(
      `Sección` = seccion_label,
      `Variable afectada` = variable,
      `Incidencia` = incidencia,
      `Efecto contable ante cierre de brecha` = efecto_contable
    ) %>%
    arrange(.data$`Sección`, .data$`Variable afectada`)

  resumen_table <- resumen %>%
    transmute(
      `Sección` = as.character(.data$seccion_label),
      `TG base prom.` = fmt_pct(.data$tg_base_prom_pct),
      `TG cierre prom.` = fmt_pct(.data$tg_dev_prom_pct),
      `Cambio prom.` = fmt_pp(.data$cambio_pp_prom),
      `TG base 2024` = fmt_pct(.data$tg_base_2024_pct),
      `TG cierre 2024` = fmt_pct(.data$tg_dev_2024_pct),
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
    paste0("# ", spec$titulo),
    "",
    paste0(
      "Fuente de trabajo: `",
      input_xlsx,
      "`, hojas `escenario-inicial`, `tipo-cambio` y `",
      spec$sheet,
      "`."
    ),
    "",
    "## Introducción",
    "",
    spec$intro,
    "",
    paste(
      "La minuta interpreta el cierre anual de la brecha entre tipo de cambio",
      "comercial y tipo de cambio de paridad como forma de dimensionar la",
      "apropiación de riqueza asociada a sostener un tipo de cambio sobrevaluado.",
      "El ejercicio se realiza año a año, sin efectos acumulados ni respuestas",
      "dinámicas de cantidades, productividad o estructura productiva."
    ),
    "",
    "## Síntesis",
    "",
    paste(
      "Las fuentes usadas son: EAAE para VBP, VAB, remuneraciones, consumo",
      "intermedio estimado, consumo de capital fijo, stock de capital y capital",
      "adelantado; Oyanthabal, con base en la metodología de Iñigo Carrera (2007),",
      "para los tipos de cambio comercial/paridad y los coeficientes de incidencia",
      "del ejercicio; microdatos del CIU para distribuir los intereses industriales",
      "entre ramas exportadoras y ramas orientadas al mercado interno; y la",
      "clasificación operativa de subramas industriales 2020-2024 usada para",
      "separar industria exportadora, mercado interno y combustible."
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
      "Bajo este escenario, la industria total pasa en 2024 de una tasa de",
      " ganancia a precios básicos de ",
      fmt_pct(value_for(summary_2024, "industria-total", tg_base_2024_pct)),
      " a ",
      fmt_pct(value_for(summary_2024, "industria-total", tg_dev_2024_pct)),
      ". El segmento exportador pasa de ",
      fmt_pct(value_for(summary_2024, "exportadora", tg_base_2024_pct)),
      " a ",
      fmt_pct(value_for(summary_2024, "exportadora", tg_dev_2024_pct)),
      ", mientras que el segmento mercado interno pasa de ",
      fmt_pct(value_for(summary_2024, "mercado-interno", tg_base_2024_pct)),
      " a ",
      fmt_pct(value_for(summary_2024, "mercado-interno", tg_dev_2024_pct)),
      "."
    ),
    "",
    "## Supuestos y escenarios",
    "",
    "- `escenario-inicial` contiene los valores corrientes observados para industria total, segmento exportador y segmento mercado interno.",
    paste0("- `", spec$sheet, "` contiene el contrafactual del escenario modelado."),
    "- El cálculo se realiza año a año mediante `factor_devaluacion = tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1`; no contempla efectos acumulados ni respuestas dinámicas de cantidades, precios relativos o productividad.",
    "- El canal positivo se modela sobre `vbp_pp`; los canales negativos se modelan sobre consumo intermedio, remuneraciones, consumo de capital fijo, stock imputado e intereses pagados.",
    "- Los intereses industriales son una serie agregada de manufactura y se distribuyen por segmento según microdatos del CIU: 65,6% para ramas exportadoras y 34,4% para ramas orientadas al mercado interno.",
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
      "cierre de la brecha cambiaria. Desde el punto de vista del contrafactual",
      "de paridad, el componente de VBP tiene signo positivo para la ganancia,",
      "porque eleva la valorización de ventas asociadas al tipo de cambio.",
      "En cambio, consumo intermedio, masa salarial, consumo de capital fijo e",
      "intereses pagados operan como gastos o costos; el stock imputado afecta",
      "negativamente la tasa porque eleva el capital adelantado."
    ),
    "",
    paste0("![Coeficientes de incidencia por segmento](", fig_rel(fig2_path), ")"),
    "",
    md_table(coef_table),
    "",
    "## Resultados principales",
    "",
    paste0(
      "La tasa de ganancia a precios básicos de la industria total cambia en",
      " promedio ",
      fmt_pp(value_for(resumen, "industria-total", cambio_pp_prom)),
      " entre 2020 y 2024. En el segmento exportador el cambio promedio es ",
      fmt_pp(value_for(resumen, "exportadora", cambio_pp_prom)),
      ". En el segmento mercado interno el cambio promedio es ",
      fmt_pp(value_for(resumen, "mercado-interno", cambio_pp_prom)),
      "."
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
      " Para la industria total equivale a ",
      fmt_num(delta_industria_2024),
      " miles de millones de pesos corrientes. Ese impulso se compensa parcialmente ",
      "por el aumento de consumo intermedio, remuneraciones, consumo de capital ",
      "fijo, stock imputado e intereses pagados."
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
      fmt_pct(participacion_deltas_2024$exportadora_pct[
        participacion_deltas_2024$componente == spec$vbp_label
      ]),
      " del delta de VBP de la industria total, frente a ",
      fmt_pct(participacion_deltas_2024$mercado_interno_pct[
        participacion_deltas_2024$componente == spec$vbp_label
      ]),
      " del segmento mercado interno."
    ),
    "",
    paste0(
      "En magnitudes de 2024, el VBP de la industria total aumenta ",
      fmt_num(delta_value("industria-total", vbp_miles_mill)),
      " miles de millones de pesos corrientes, mientras los gastos modelados",
      " aumentan ",
      fmt_num(delta_value("industria-total", gastos_miles_mill)),
      " y el stock imputado aumenta ",
      fmt_num(delta_value("industria-total", stock_miles_mill)),
      ". En el segmento exportador, el aumento de VBP es ",
      fmt_num(delta_value("exportadora", vbp_miles_mill)),
      " frente a gastos por ",
      fmt_num(delta_value("exportadora", gastos_miles_mill)),
      " y stock por ",
      fmt_num(delta_value("exportadora", stock_miles_mill)),
      ". En mercado interno, el VBP aumenta ",
      fmt_num(delta_value("mercado-interno", vbp_miles_mill)),
      ", los gastos aumentan ",
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
      "condiciones de rentabilidad dentro de la industria. La lectura agregada",
      "de la industria total debe interpretarse con cautela porque sintetiza",
      "estructuras de exposición distintas. La separación entre segmento",
      "exportador y segmento mercado interno permite observar qué parte del",
      "resultado responde al canal de valorización del producto y qué parte queda",
      "condicionada por el encarecimiento de costos, capital adelantado e",
      "intereses pagados al cerrar la brecha cambiaria."
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

  tibble(
    escenario = spec$sheet,
    minuta = output_md,
    figuras = figures_dir,
    filas = nrow(devaluacion)
  )
}

created <- bind_rows(lapply(seq_len(nrow(scenario_specs)), function(i) {
  write_scenario_minute(scenario_specs[i, ])
}))

print(created)
