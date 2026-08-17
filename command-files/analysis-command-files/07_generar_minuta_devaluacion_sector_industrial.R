# Build a GitHub-readable Markdown minute and PNG figures for the
# industrial devaluation scenario.
#
# Run from the project root:
#   Rscript command-files/analysis-command-files/07_generar_minuta_devaluacion_sector_industrial.R

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(glue)
  library(knitr)
  library(readxl)
  library(scales)
  library(stringr)
  library(tidyr)
})

analysis_dir <- file.path("data", "analysis-data")
docs_dir <- file.path("docs", "minutes")
workbook_date <- Sys.getenv("EAAE_WORKBOOK_DATE", unset = "20260817")
report_date <- Sys.getenv("EAAE_REPORT_DATE", unset = "20260817")

workbook_path <- file.path(
  analysis_dir,
  paste0(workbook_date, "_resultados_eaae_bcu_total_industria_subrama.xlsx")
)
fig_dir <- file.path(
  "output",
  "figures",
  paste0("devaluacion_sector_industrial_", report_date)
)
report_path <- file.path(
  docs_dir,
  paste0(report_date, "_resultados_devaluación_sector_industrial.md")
)

source_caption <- paste(
  "Fuente: elaboración propia en base a EAAE y coeficientes/tipos de cambio",
  "provistos en insumos Mussi."
)

dir.create(docs_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
unlink(list.files(fig_dir, pattern = "\\.png$", full.names = TRUE))

required_columns <- c(
  "anno",
  "calidad_resultado_devaluacion",
  "factor_devaluacion",
  "efecto_exportaciones_pesos",
  "efecto_exportaciones_pct",
  "consumo_intermedio",
  "efecto_consumo_intermedio_pesos",
  "efecto_consumo_intermedio_sobre_total_pct",
  "efecto_intereses_pesos",
  "efecto_intereses_pct",
  "remuneraciones",
  "perdida_salarial_real_pesos",
  "perdida_salarial_real_pct",
  "efecto_salario_compensado_pesos",
  "efecto_salario_compensado_pct",
  "ganancia_pb",
  "ganancia_pb_devaluacion_salario_fijo",
  "ganancia_pb_devaluacion_salario_compensado",
  "efecto_ganancia_pb_salario_fijo_pct",
  "efecto_ganancia_pb_salario_compensado_pct",
  "capital_total_adelantado",
  "capital_total_devaluacion_salario_fijo",
  "capital_total_devaluacion_salario_compensado",
  "tasa_ganancia_pb",
  "tasa_ganancia_pb_devaluacion_salario_fijo",
  "tasa_ganancia_pb_devaluacion_salario_compensado",
  "variacion_tasa_ganancia_pb_salario_fijo_pp",
  "variacion_tasa_ganancia_pb_salario_compensado_pp",
  "tipo_cambio_comercial_pesos_usd",
  "tipo_cambio_paridad_pesos_usd",
  "prop_importado_consumo_intermedio",
  "prop_consumo_obrero_importado",
  "rotacion_calibrada_sobre_6_6"
)

safe_divide <- function(numerator, denominator) {
  result <- numerator / denominator
  result[is.na(numerator) | is.na(denominator) | denominator == 0] <- NA_real_
  result
}

format_pct_value <- function(x, accuracy = 0.1) {
  percent(x / 100, accuracy = accuracy, decimal.mark = ",")
}

format_rate <- function(x, accuracy = 0.1) {
  percent(x, accuracy = accuracy, decimal.mark = ",")
}

format_pp <- function(x) {
  paste0(formatC(round(x, 1), format = "f", digits = 1, decimal.mark = ","), " p.p.")
}

format_pp_text <- function(x) {
  paste0(
    formatC(round(x, 1), format = "f", digits = 1, decimal.mark = ","),
    " puntos porcentuales"
  )
}

format_billion <- function(x, digits = 1) {
  paste0(formatC(round(x / 1e9, digits), format = "f", digits = digits, decimal.mark = ","), " mil millones")
}

format_number <- function(x, digits = 1) {
  formatC(round(x, digits), format = "f", digits = digits, decimal.mark = ",")
}

theme_devaluation <- function() {
  theme_minimal(base_size = 11) +
    theme(
      plot.title = element_text(face = "bold", size = 13),
      plot.subtitle = element_text(size = 10, margin = margin(b = 8)),
      plot.caption = element_text(size = 8, hjust = 0),
      legend.position = "bottom",
      legend.title = element_blank(),
      panel.grid.minor = element_blank(),
      strip.text = element_text(face = "bold", size = 9),
      axis.title.x = element_blank()
    )
}

save_plot <- function(plot, filename, width = 10, height = 6) {
  output_path <- file.path(fig_dir, filename)
  ggsave(
    output_path,
    plot,
    width = width,
    height = height,
    dpi = 180,
    bg = "white"
  )
  output_path
}

relative_fig <- function(filename) {
  file.path("..", "..", "output", "figures", basename(fig_dir), filename)
}

fig_md <- function(alt, filename) {
  paste0("![", alt, "](", relative_fig(filename), ")")
}

if (!file.exists(workbook_path)) {
  stop("No existe el libro de resultados esperado: ", workbook_path)
}

effect <- readxl::read_excel(
  workbook_path,
  sheet = "efecto-devaluacion-corrientes",
  .name_repair = "minimal"
) %>%
  mutate(anno = as.integer(anno))

missing_columns <- setdiff(required_columns, names(effect))
if (length(missing_columns) > 0) {
  stop(
    "La hoja efecto-devaluacion-corrientes no contiene columnas requeridas: ",
    paste(missing_columns, collapse = ", ")
  )
}

complete_effect <- effect %>%
  filter(calidad_resultado_devaluacion == "completo_con_intereses") %>%
  mutate(
    tasa_ganancia_pb_salario_fijo_rel_pct =
      (tasa_ganancia_pb_devaluacion_salario_fijo / tasa_ganancia_pb - 1) * 100,
    tasa_ganancia_pb_salario_compensado_rel_pct =
      (tasa_ganancia_pb_devaluacion_salario_compensado / tasa_ganancia_pb - 1) * 100
  )

if (nrow(complete_effect) == 0) {
  stop("No hay años completos con intereses para construir la minuta.")
}

reference_year <- max(complete_effect$anno, na.rm = TRUE)
reference <- complete_effect %>%
  filter(anno == reference_year) %>%
  slice(1)

summary_stats <- complete_effect %>%
  summarise(
    periodo = paste0(min(anno), "-", max(anno)),
    factor_devaluacion = mean(factor_devaluacion, na.rm = TRUE),
    efecto_exportaciones_pct = mean(efecto_exportaciones_pct, na.rm = TRUE),
    efecto_consumo_intermedio_sobre_total_pct =
      mean(efecto_consumo_intermedio_sobre_total_pct, na.rm = TRUE),
    efecto_intereses_pct = mean(efecto_intereses_pct, na.rm = TRUE),
    perdida_salarial_real_pct = mean(perdida_salarial_real_pct, na.rm = TRUE),
    efecto_salario_compensado_pct =
      mean(efecto_salario_compensado_pct, na.rm = TRUE),
    efecto_ganancia_pb_salario_fijo_pct =
      mean(efecto_ganancia_pb_salario_fijo_pct, na.rm = TRUE),
    efecto_ganancia_pb_salario_compensado_pct =
      mean(efecto_ganancia_pb_salario_compensado_pct, na.rm = TRUE),
    variacion_tasa_ganancia_pb_salario_fijo_pp =
      mean(variacion_tasa_ganancia_pb_salario_fijo_pp, na.rm = TRUE),
    variacion_tasa_ganancia_pb_salario_compensado_pp =
      mean(variacion_tasa_ganancia_pb_salario_compensado_pp, na.rm = TRUE),
    tasa_ganancia_pb = mean(tasa_ganancia_pb, na.rm = TRUE),
    tasa_ganancia_pb_devaluacion_salario_fijo =
      mean(tasa_ganancia_pb_devaluacion_salario_fijo, na.rm = TRUE),
    tasa_ganancia_pb_devaluacion_salario_compensado =
      mean(tasa_ganancia_pb_devaluacion_salario_compensado, na.rm = TRUE),
    tasa_ganancia_pb_salario_fijo_rel_pct =
      mean(tasa_ganancia_pb_salario_fijo_rel_pct, na.rm = TRUE),
    tasa_ganancia_pb_salario_compensado_rel_pct =
      mean(tasa_ganancia_pb_salario_compensado_rel_pct, na.rm = TRUE),
    .groups = "drop"
  )

reference_stats <- reference %>%
  transmute(
    periodo = as.character(anno),
    factor_devaluacion,
    efecto_exportaciones_pct,
    efecto_consumo_intermedio_sobre_total_pct,
    efecto_intereses_pct,
    perdida_salarial_real_pct,
    efecto_salario_compensado_pct,
    efecto_ganancia_pb_salario_fijo_pct,
    efecto_ganancia_pb_salario_compensado_pct,
    variacion_tasa_ganancia_pb_salario_fijo_pp,
    variacion_tasa_ganancia_pb_salario_compensado_pp,
    tasa_ganancia_pb,
    tasa_ganancia_pb_devaluacion_salario_fijo,
    tasa_ganancia_pb_devaluacion_salario_compensado
  ) %>%
  mutate(
    tasa_ganancia_pb_salario_fijo_rel_pct =
      (tasa_ganancia_pb_devaluacion_salario_fijo / tasa_ganancia_pb - 1) * 100,
    tasa_ganancia_pb_salario_compensado_rel_pct =
      (tasa_ganancia_pb_devaluacion_salario_compensado / tasa_ganancia_pb - 1) * 100
  )

summary_table <- bind_rows(summary_stats, reference_stats) %>%
  transmute(
    `Período` = periodo,
    `TC paridad vs comercial` = format_pct_value((factor_devaluacion - 1) * 100),
    `Exportaciones en pesos` = format_pct_value(efecto_exportaciones_pct),
    `Consumo intermedio total` =
      format_pct_value(efecto_consumo_intermedio_sobre_total_pct),
    `Intereses en pesos` = format_pct_value(efecto_intereses_pct),
    `Salario real con salario fijo` =
      paste0("-", format_pct_value(perdida_salarial_real_pct)),
    `Ganancia pb, salario fijo` =
      format_pct_value(efecto_ganancia_pb_salario_fijo_pct),
    `Ganancia pb, salario compensado` =
      format_pct_value(efecto_ganancia_pb_salario_compensado_pct),
    `Tasa ganancia pb, salario fijo` =
      paste0(
        "+",
        format_pp(variacion_tasa_ganancia_pb_salario_fijo_pp),
        " / +",
        format_pct_value(tasa_ganancia_pb_salario_fijo_rel_pct)
      ),
    `Tasa ganancia pb, salario compensado` =
      paste0(
        "+",
        format_pp(variacion_tasa_ganancia_pb_salario_compensado_pp),
        " / +",
        format_pct_value(tasa_ganancia_pb_salario_compensado_rel_pct)
      )
  )

# DECISION: the public-facing waterfall uses the latest complete year because
# it is easier to read than a multi-year average and preserves the accounting
# bridge from base profit to the two devaluation scenarios.
waterfall <- tibble(
  etapa = factor(
    c(
      "Ganancia base",
      "+ exportaciones",
      "- insumos importados",
      "- intereses en USD",
      "Ganancia\nsalario fijo",
      "- compensación salarial",
      "Ganancia\nsalario compensado"
    ),
    levels = c(
      "Ganancia base",
      "+ exportaciones",
      "- insumos importados",
      "- intereses en USD",
      "Ganancia\nsalario fijo",
      "- compensación salarial",
      "Ganancia\nsalario compensado"
    )
  ),
  tipo = c("Total", "Aumenta ganancia", "Reduce ganancia", "Reduce ganancia",
           "Total", "Reduce ganancia", "Total"),
  ymin = c(
    0,
    reference$ganancia_pb,
    reference$ganancia_pb + reference$efecto_exportaciones_pesos -
      reference$efecto_consumo_intermedio_pesos,
    reference$ganancia_pb + reference$efecto_exportaciones_pesos -
      reference$efecto_consumo_intermedio_pesos -
      reference$efecto_intereses_pesos,
    0,
    reference$ganancia_pb_devaluacion_salario_fijo -
      reference$efecto_salario_compensado_pesos,
    0
  ),
  ymax = c(
    reference$ganancia_pb,
    reference$ganancia_pb + reference$efecto_exportaciones_pesos,
    reference$ganancia_pb + reference$efecto_exportaciones_pesos,
    reference$ganancia_pb + reference$efecto_exportaciones_pesos -
      reference$efecto_consumo_intermedio_pesos,
    reference$ganancia_pb_devaluacion_salario_fijo,
    reference$ganancia_pb_devaluacion_salario_fijo,
    reference$ganancia_pb_devaluacion_salario_compensado
  )
) %>%
  mutate(
    x = row_number(),
    label = case_when(
      etapa == "Ganancia base" ~ format_billion(ymax),
      etapa == "Ganancia\nsalario fijo" ~ paste0(
        format_billion(ymax),
        "\n+",
        format_pct_value(reference$efecto_ganancia_pb_salario_fijo_pct)
      ),
      etapa == "Ganancia\nsalario compensado" ~ paste0(
        format_billion(ymax),
        "\n+",
        format_pct_value(reference$efecto_ganancia_pb_salario_compensado_pct)
      ),
      tipo == "Reduce ganancia" ~ paste0("-", format_billion(abs(ymax - ymin))),
      ymax - ymin >= 0 ~ paste0("+", format_billion(abs(ymax - ymin))),
      TRUE ~ paste0("-", format_billion(abs(ymax - ymin)))
    ),
    label_y = pmax(ymin, ymax) / 1e9 + max(ymax, na.rm = TRUE) / 1e9 * 0.045
  )

waterfall_plot <- ggplot(waterfall) +
  geom_rect(
    aes(
      xmin = x - 0.38,
      xmax = x + 0.38,
      ymin = pmin(ymin, ymax) / 1e9,
      ymax = pmax(ymin, ymax) / 1e9,
      fill = tipo
    ),
    color = "white",
    linewidth = 0.3
  ) +
  geom_text(
    aes(x = x, y = label_y, label = label),
    size = 3.1,
    lineheight = 0.95
  ) +
  scale_fill_manual(
    values = c(
      "Total" = "#39568C",
      "Aumenta ganancia" = "#1B9E77",
      "Reduce ganancia" = "#D95F02"
    )
  ) +
  scale_x_continuous(
    breaks = waterfall$x,
    labels = levels(waterfall$etapa)
  ) +
  scale_y_continuous(labels = label_number(decimal.mark = ",")) +
  coord_cartesian(clip = "off") +
  labs(
    title = paste0("Devaluación y ganancia industrial: puente contable ", reference_year),
    subtitle = "Ganancia a precios básicos. Barras en miles de millones de pesos corrientes.",
    y = "Miles de millones de pesos corrientes",
    caption = source_caption
  ) +
  theme_devaluation() +
  theme(axis.text.x = element_text(size = 8.5))

fig1 <- "01_puente_ganancia_devaluacion_2024.png"
save_plot(waterfall_plot, fig1, width = 11, height = 6.4)

tg_long <- complete_effect %>%
  select(
    anno,
    Base = tasa_ganancia_pb,
    `Devaluación con salario fijo` =
      tasa_ganancia_pb_devaluacion_salario_fijo,
    `Devaluación con salario compensado` =
      tasa_ganancia_pb_devaluacion_salario_compensado
  ) %>%
  pivot_longer(-anno, names_to = "escenario", values_to = "tasa")

tg_labels <- tg_long %>%
  filter(anno == reference_year) %>%
  mutate(
    label = case_when(
      escenario == "Base" ~ paste0("Base: ", format_rate(tasa)),
      escenario == "Devaluación con salario fijo" ~
        paste0("Salario fijo: ", format_rate(tasa)),
      escenario == "Devaluación con salario compensado" ~
        paste0("Salario compensado: ", format_rate(tasa)),
      TRUE ~ paste0(escenario, ": ", format_rate(tasa))
    )
  )

tg_plot <- ggplot(tg_long, aes(anno, tasa, color = escenario)) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.5) +
  geom_text(
    data = tg_labels,
    aes(label = label),
    hjust = 0,
    nudge_x = 0.25,
    size = 3,
    show.legend = FALSE
  ) +
  scale_color_manual(
    values = c(
      "Base" = "#333333",
      "Devaluación con salario fijo" = "#1B9E77",
      "Devaluación con salario compensado" = "#7570B3"
    )
  ) +
  scale_y_continuous(labels = percent_format(accuracy = 1, decimal.mark = ",")) +
  scale_x_continuous(
    breaks = pretty_breaks(n = 8),
    limits = c(min(tg_long$anno), reference_year + 4)
  ) +
  labs(
    title = "Tasa de ganancia industrial bajo dos escenarios de devaluación",
    subtitle = "Tasa a precios básicos. Años con información completa de intereses.",
    y = "Tasa de ganancia",
    caption = source_caption
  ) +
  theme_devaluation()

fig2 <- "02_tasa_ganancia_escenarios_devaluacion.png"
save_plot(tg_plot, fig2, width = 10.5, height = 6)

impact_summary <- bind_rows(
  complete_effect %>%
    summarise(
      periodo = paste0("Promedio ", min(anno), "-", max(anno)),
      `Exportaciones en pesos` = mean(efecto_exportaciones_pct, na.rm = TRUE),
      `Consumo intermedio total` =
        mean(efecto_consumo_intermedio_sobre_total_pct, na.rm = TRUE),
      `Intereses en pesos` = mean(efecto_intereses_pct, na.rm = TRUE),
      `Ganancia pb, salario fijo` =
        mean(efecto_ganancia_pb_salario_fijo_pct, na.rm = TRUE),
      `Ganancia pb, salario compensado` =
        mean(efecto_ganancia_pb_salario_compensado_pct, na.rm = TRUE),
      `Salario real, salario fijo` =
        -mean(perdida_salarial_real_pct, na.rm = TRUE),
      `Ajuste salarial compensatorio` =
        mean(efecto_salario_compensado_pct, na.rm = TRUE),
      .groups = "drop"
    ),
  reference %>%
    transmute(
      periodo = as.character(reference_year),
      `Exportaciones en pesos` = efecto_exportaciones_pct,
      `Consumo intermedio total` =
        efecto_consumo_intermedio_sobre_total_pct,
      `Intereses en pesos` = efecto_intereses_pct,
      `Ganancia pb, salario fijo` =
        efecto_ganancia_pb_salario_fijo_pct,
      `Ganancia pb, salario compensado` =
        efecto_ganancia_pb_salario_compensado_pct,
      `Salario real, salario fijo` =
        -perdida_salarial_real_pct,
      `Ajuste salarial compensatorio` =
        efecto_salario_compensado_pct
    )
) %>%
  pivot_longer(-periodo, names_to = "indicador", values_to = "valor_pct") %>%
  mutate(
    indicador = factor(
      indicador,
      levels = rev(c(
        "Exportaciones en pesos",
        "Consumo intermedio total",
        "Intereses en pesos",
        "Ganancia pb, salario fijo",
        "Ganancia pb, salario compensado",
        "Salario real, salario fijo",
        "Ajuste salarial compensatorio"
      ))
    ),
    signo = if_else(valor_pct >= 0, "Incremento", "Disminución"),
    label = if_else(
      valor_pct >= 0,
      paste0("+", format_pct_value(valor_pct)),
      paste0("-", format_pct_value(abs(valor_pct)))
    )
  )

impact_plot <- ggplot(impact_summary, aes(indicador, valor_pct / 100, fill = signo)) +
  geom_col(width = 0.68) +
  geom_hline(yintercept = 0, linewidth = 0.35, color = "grey35") +
  geom_text(
    aes(label = label, hjust = if_else(valor_pct >= 0, -0.08, 1.08)),
    size = 3
  ) +
  coord_flip(clip = "off") +
  facet_wrap(vars(periodo), ncol = 1) +
  scale_fill_manual(
    values = c("Incremento" = "#1B9E77", "Disminución" = "#D95F02")
  ) +
  scale_y_continuous(labels = percent_format(accuracy = 1, decimal.mark = ",")) +
  labs(
    title = "Efectos porcentuales de la devaluación",
    subtitle = "Variación respecto del escenario base con tipo de cambio comercial.",
    y = "Variación porcentual",
    caption = source_caption
  ) +
  theme_devaluation()

fig3 <- "03_impactos_porcentuales_devaluacion.png"
save_plot(impact_plot, fig3, width = 11, height = 7.2)

quality_table <- effect %>%
  summarise(
    `Filas de la hoja` = n(),
    `Cobertura` = paste0(min(anno), "-", max(anno)),
    `Años completos con intereses` =
      sum(calidad_resultado_devaluacion == "completo_con_intereses"),
    `Años parciales sin intereses` =
      sum(calidad_resultado_devaluacion != "completo_con_intereses"),
    `Faltantes en TC comercial` = sum(is.na(tipo_cambio_comercial_pesos_usd)),
    `Faltantes en TC paridad` = sum(is.na(tipo_cambio_paridad_pesos_usd)),
    `Faltantes en exportaciones` =
      sum(is.na(efecto_exportaciones_pesos)),
    `Faltantes en proporción importada CI` =
      sum(is.na(prop_importado_consumo_intermedio)),
    `Faltantes en proporción consumo obrero importado` =
      sum(is.na(prop_consumo_obrero_importado))
  ) %>%
  mutate(across(everything(), as.character))

summary_table_md <- knitr::kable(summary_table, format = "markdown")
quality_table_md <- knitr::kable(t(quality_table), format = "markdown", col.names = c("Control", "Resultado"))

md <- c(
  "# Resultados de devaluación para el sector industrial",
  "",
  glue("Fuente de trabajo: `data/analysis-data/{workbook_date}_resultados_eaae_bcu_total_industria_subrama.xlsx`, hoja `efecto-devaluacion-corrientes`."),
  "",
  "Esta minuta presenta una lectura sintética de las consecuencias contables de aplicar una devaluación sobre la industria manufacturera total. El ejercicio compara el tipo de cambio comercial con el tipo de cambio de paridad y mantiene constantes las cantidades producidas, la estructura exportadora y los coeficientes técnicos. Por lo tanto, no debe leerse como una predicción macroeconómica, sino como una simulación parcial de redistribución de ingresos y costos ante un cambio cambiario.",
  "",
  "La idea central es simple: la devaluación no impacta igual a quienes venden en dólares, compran insumos importados, pagan intereses en dólares o viven de un salario en pesos. En el sector industrial, el capital exportador recibe más pesos por sus ventas externas; al mismo tiempo, suben los costos de la parte importada del consumo intermedio y los intereses denominados en dólares. Para los trabajadores, el resultado depende de la política salarial: si los salarios nominales quedan fijos, cae el poder de compra; si se compensan, se protege el salario real y se reduce parte de la mejora de la ganancia capitalista.",
  "",
  "## Escenarios evaluados",
  "",
  "- **Escenario base:** valores corrientes observados con tipo de cambio comercial.",
  "- **Devaluación con salario nominal fijo:** las exportaciones, los insumos importados y los intereses en dólares se reexpresan al tipo de cambio de paridad, pero las remuneraciones nominales no se ajustan. Este escenario maximiza el traslado distributivo hacia la ganancia industrial.",
  "- **Devaluación con salario compensado:** se aplica el mismo cambio de tipo de cambio, pero las remuneraciones aumentan según la proporción importada del consumo obrero. Este escenario preserva el poder de compra asociado a esa canasta importada y reduce la ganancia adicional del capital.",
  "",
  "## Resultados principales",
  "",
  summary_table_md,
  "",
  glue("En {reference_year}, el tipo de cambio de paridad queda {format_pct_value((reference$factor_devaluacion - 1) * 100)} por encima del tipo de cambio comercial. Esto eleva las exportaciones industriales en pesos en la misma proporción. El efecto positivo no se traslada íntegro a la ganancia, porque el consumo intermedio total aumenta {format_pct_value(reference$efecto_consumo_intermedio_sobre_total_pct)} y los intereses en pesos aumentan {format_pct_value(reference$efecto_intereses_pct)}."),
  "",
  glue("Aun descontando esos costos, la ganancia a precios básicos sube {format_pct_value(reference$efecto_ganancia_pb_salario_fijo_pct)} si el salario nominal queda fijo. En ese caso, la tasa de ganancia pasa de {format_rate(reference$tasa_ganancia_pb)} a {format_rate(reference$tasa_ganancia_pb_devaluacion_salario_fijo)}, un incremento de {format_pp_text(reference$variacion_tasa_ganancia_pb_salario_fijo_pp)}. Para los trabajadores, la contracara es una pérdida de salario real de {format_pct_value(reference$perdida_salarial_real_pct)}."),
  "",
  glue("Si las remuneraciones se compensan para sostener el poder de compra de la canasta obrera importada, la ganancia industrial igualmente aumenta, pero menos: {format_pct_value(reference$efecto_ganancia_pb_salario_compensado_pct)}. La tasa de ganancia queda en {format_rate(reference$tasa_ganancia_pb_devaluacion_salario_compensado)}, equivalente a un aumento de {format_pp_text(reference$variacion_tasa_ganancia_pb_salario_compensado_pp)} frente al escenario base. Esta diferencia entre escenarios resume el conflicto distributivo directo del ejercicio: cuanto más absorbe el salario la devaluación, mayor es la mejora de la ganancia; cuanto más se compensa el salario, menor es esa transferencia."),
  "",
  "## 1. Puente contable de la ganancia",
  "",
  "El primer gráfico muestra cómo se pasa desde la ganancia base hasta la ganancia bajo devaluación. La barra positiva de exportaciones representa el ingreso adicional en pesos. Luego se descuentan el encarecimiento de insumos importados y de intereses en dólares. El escenario de salario compensado incorpora un descuento adicional: la recomposición salarial necesaria para preservar el poder de compra de la parte importada de la canasta obrera.",
  "",
  fig_md("Puente contable de ganancia industrial bajo devaluación", fig1),
  "",
  "## 2. Tasa de ganancia en los dos escenarios",
  "",
  "La tasa de ganancia se calcula a precios básicos. La comparación muestra que ambos escenarios elevan la tasa respecto del escenario base, pero el escenario de salario fijo genera una tasa superior porque la pérdida real del salario queda capturada como mayor excedente capitalista.",
  "",
  fig_md("Tasa de ganancia industrial bajo escenarios de devaluación", fig2),
  "",
  "## 3. Impactos porcentuales",
  "",
  "El tercer gráfico resume las variaciones porcentuales. Para facilitar la lectura, el salario real bajo salario nominal fijo se grafica como disminución, mientras que la compensación salarial aparece como el aumento nominal necesario para neutralizar esa pérdida sobre la canasta importada.",
  "",
  fig_md("Impactos porcentuales de la devaluación", fig3),
  "",
  "## Calidad y cobertura",
  "",
  quality_table_md,
  "",
  "Los años 2001-2005 quedan disponibles sólo para componentes no financieros, porque la fuente de intereses industriales comienza en 2006. Por esa razón, la interpretación principal de esta minuta se concentra en 2006-2024, período con información completa de intereses.",
  "",
  "## Anexo técnico",
  "",
  "### Tipo de cambio",
  "",
  "El factor de devaluación compara el tipo de cambio de paridad contra el tipo de cambio comercial:",
  "",
  "```text",
  "factor_devaluacion = tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd",
  "```",
  "",
  "### Exportaciones",
  "",
  "Las exportaciones industriales se toman en miles de dólares, corregidas al 95% para aproximar el universo EAAE. Se convierten a pesos con ambos tipos de cambio. El efecto de devaluación es la diferencia entre el valor a tipo de cambio de paridad y el valor a tipo de cambio comercial:",
  "",
  "```text",
  "exportaciones_tcc_pesos = exportaciones_manufactura_eaae_95_miles_usd * tipo_cambio_comercial_pesos_usd * 1000",
  "exportaciones_tcp_pesos = exportaciones_manufactura_eaae_95_miles_usd * tipo_cambio_paridad_pesos_usd * 1000",
  "efecto_exportaciones_pesos = exportaciones_tcp_pesos - exportaciones_tcc_pesos",
  "```",
  "",
  "### Consumo intermedio",
  "",
  "El consumo intermedio no se revaloriza completo, sino sólo en la proporción estimada como importada. La parte nacional se mantiene sin cambio en esta simulación:",
  "",
  "```text",
  "consumo_intermedio_importado_pesos = consumo_intermedio * prop_importado_consumo_intermedio",
  "consumo_intermedio_devaluacion_pesos =",
  "  consumo_intermedio_no_importado + consumo_intermedio_importado_pesos * factor_devaluacion",
  "efecto_consumo_intermedio_pesos = consumo_intermedio_devaluacion_pesos - consumo_intermedio",
  "```",
  "",
  "### Intereses pagados",
  "",
  "Los intereses industriales se toman en millones de dólares. La simulación compara su costo en pesos al tipo de cambio comercial y al tipo de cambio de paridad:",
  "",
  "```text",
  "intereses_tcc_pesos = intereses_industria_eaae_ajuste_90_mill_usd * tipo_cambio_comercial_pesos_usd * 1000000",
  "intereses_tcp_pesos = intereses_industria_eaae_ajuste_90_mill_usd * tipo_cambio_paridad_pesos_usd * 1000000",
  "efecto_intereses_pesos = intereses_tcp_pesos - intereses_tcc_pesos",
  "```",
  "",
  "### Remuneraciones",
  "",
  "Para el escenario de salario fijo, las remuneraciones nominales no cambian y la pérdida se expresa como caída del poder de compra sobre la parte importada de la canasta obrera. Para el escenario compensado, las remuneraciones suben según el factor de encarecimiento de esa canasta:",
  "",
  "```text",
  "factor_canasta_obrera =",
  "  (1 - prop_consumo_obrero_importado) +",
  "  prop_consumo_obrero_importado * factor_devaluacion",
  "",
  "remuneraciones_reales_post_devaluacion = remuneraciones / factor_canasta_obrera",
  "perdida_salarial_real_pesos = remuneraciones - remuneraciones_reales_post_devaluacion",
  "",
  "remuneraciones_compensadas_devaluacion = remuneraciones * factor_canasta_obrera",
  "efecto_salario_compensado_pesos = remuneraciones_compensadas_devaluacion - remuneraciones",
  "```",
  "",
  "### Ganancia y tasa de ganancia",
  "",
  "La ganancia con salario fijo suma el efecto neto de la devaluación sobre exportaciones y resta el mayor costo de insumos importados e intereses. La ganancia con salario compensado resta, además, la recomposición salarial:",
  "",
  "```text",
  "efecto_neto_capital_salario_fijo_pesos =",
  "  efecto_exportaciones_pesos -",
  "  efecto_consumo_intermedio_pesos -",
  "  efecto_intereses_pesos",
  "",
  "ganancia_pb_devaluacion_salario_fijo =",
  "  ganancia_pb + efecto_neto_capital_salario_fijo_pesos",
  "",
  "ganancia_pb_devaluacion_salario_compensado =",
  "  ganancia_pb_devaluacion_salario_fijo - efecto_salario_compensado_pesos",
  "```",
  "",
  "Para recalcular la tasa de ganancia se actualiza el capital circulante adelantado, porque el consumo intermedio cambia y, en el escenario compensado, también cambia el costo laboral:",
  "",
  "```text",
  "capital_circulante_devaluacion_salario_fijo =",
  "  (costo_laboral + consumo_intermedio_devaluacion_pesos) / rotacion_calibrada_sobre_6_6",
  "",
  "capital_total_devaluacion_salario_fijo =",
  "  stock_capital_imputado + capital_circulante_devaluacion_salario_fijo",
  "",
  "tasa_ganancia_pb_devaluacion_salario_fijo =",
  "  ganancia_pb_devaluacion_salario_fijo / capital_total_devaluacion_salario_fijo",
  "```",
  "",
  "La misma lógica se aplica al escenario de salario compensado. En todos los casos, las tasas resultantes deben leerse como escenarios contables comparativos y no como tasas observadas."
)

writeLines(md, report_path)

message("Minuta creada: ", report_path)
message("Figuras creadas en: ", fig_dir)
