# Build a GitHub-readable Markdown report and PNG figures for EAAE results.
#
# Run from the project root:
#   Rscript command-files/analysis-command-files/03_visualizar_resultados_eaae.R

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readxl)
  library(scales)
  library(tidyr)
})

analysis_dir <- file.path("data", "analysis-data")
fig_dir <- file.path("output", "figures", "eaae")
docs_dir <- "docs"
report_path <- file.path(docs_dir, "eaae_resultados_visuales.md")

latest_analysis_file <- function(pattern) {
  paths <- list.files(
    analysis_dir,
    pattern = pattern,
    full.names = TRUE
  )
  if (length(paths) == 0) {
    stop("No se encontro ningun archivo en ", analysis_dir, " con patron ", pattern)
  }
  sort(paths, decreasing = TRUE)[[1]]
}

read_result_sheet <- function(workbook_path, sheet_name, ambito_label) {
  readxl::read_excel(workbook_path, sheet = sheet_name) %>%
    mutate(
      anno = as.integer(anno),
      ambito_label = ambito_label
    )
}

read_panel_sheet <- function(workbook_path, sheet_name) {
  readxl::read_excel(workbook_path, sheet = sheet_name) %>%
    mutate(
      anno = as.integer(anno),
      across(any_of(c("fbcf", "vab_pp")), as.numeric)
    )
}

theme_eaae <- function() {
  theme_minimal(base_size = 11) +
    theme(
      plot.title = element_text(face = "bold", size = 13),
      plot.subtitle = element_text(size = 10, margin = margin(b = 8)),
      plot.caption = element_text(size = 8, hjust = 0),
      legend.position = "bottom",
      legend.title = element_blank(),
      panel.grid.minor = element_blank(),
      strip.text = element_text(face = "bold"),
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
  file.path("..", "output", "figures", "eaae", filename)
}

series_palette <- c(
  "Precios básicos" = "#1B4E89",
  "Precios productor" = "#B23A48",
  "Costo laboral" = "#2E7D32",
  "Consumo capital fijo" = "#E07A5F",
  "Ganancia pp" = "#6A4C93",
  "Stock capital" = "#1B4E89",
  "Capital circulante adelantado" = "#2E7D32",
  "Capital total adelantado" = "#B23A48",
  "Inversión / VAB manufacturero" = "#B23A48",
  "Inversión constante" = "#1B4E89",
  "VAB" = "#1B4E89",
  "Masa salarial" = "#2E7D32",
  "Ganancia" = "#6A4C93",
  "Capital adelantado" = "#B23A48"
)

panel_xlsx_path <- latest_analysis_file("^[0-9]{8}_panel_eaae\\.xlsx$")
panel_file <- basename(panel_xlsx_path)

dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(docs_dir, recursive = TRUE, showWarnings = FALSE)

total_corrientes <- read_result_sheet(
  panel_xlsx_path,
  "resultados-total-corrientes",
  "Economía total"
)
industrial_corrientes <- read_result_sheet(
  panel_xlsx_path,
  "resultados-industrial-corrientes",
  "Industria"
)
total_constante <- read_result_sheet(
  panel_xlsx_path,
  "resultados-total-constante",
  "Economía total"
)
total_indice <- read_result_sheet(
  panel_xlsx_path,
  "resultados-total-ind-2005",
  "Economía total"
)
industrial_indice <- read_result_sheet(
  panel_xlsx_path,
  "resultados-industrial-ind-2005",
  "Industria"
)
industrial_constante <- read_result_sheet(
  panel_xlsx_path,
  "resultados-industrial-constante",
  "Industria"
)
rama_c <- read_panel_sheet(panel_xlsx_path, "rama-C")

corrientes <- bind_rows(total_corrientes, industrial_corrientes)
constantes <- bind_rows(total_constante, industrial_constante)
indices_2005 <- bind_rows(total_indice, industrial_indice)

representatividad_bcu <- corrientes %>%
  select(anno, ambito_label, vab_eaae_bcu_pct) %>%
  filter(!is.na(vab_eaae_bcu_pct))

fig_00 <- ggplot(representatividad_bcu, aes(anno, vab_eaae_bcu_pct)) +
  geom_hline(yintercept = 100, linewidth = 0.3, color = "grey70") +
  geom_line(color = "#1B4E89", linewidth = 0.95) +
  geom_point(color = "#1B4E89", size = 1.7) +
  facet_wrap(~ ambito_label, ncol = 1) +
  scale_y_continuous(labels = label_percent(scale = 1, accuracy = 1)) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Representatividad de la serie EAAE en relación a PBI BCU",
    subtitle = "VAB corriente EAAE sobre VAB corriente BCU, multiplicado por 100",
    y = "EAAE / BCU",
    caption = "Fuente: elaboración propia con panel EAAE y BCU."
  ) +
  theme_eaae()

tasas_ganancia <- corrientes %>%
  select(anno, ambito_label, tasa_ganancia_pb, tasa_ganancia_pp) %>%
  pivot_longer(
    cols = starts_with("tasa_ganancia"),
    names_to = "serie",
    values_to = "valor"
  ) %>%
  mutate(
    serie = recode(
      serie,
      tasa_ganancia_pb = "Precios básicos",
      tasa_ganancia_pp = "Precios productor"
    )
  )

fig_01 <- ggplot(tasas_ganancia, aes(anno, valor, color = serie)) +
  geom_hline(yintercept = 0, linewidth = 0.3, color = "grey70") +
  geom_line(linewidth = 0.9, na.rm = TRUE) +
  geom_point(size = 1.6, na.rm = TRUE) +
  facet_wrap(~ ambito_label, ncol = 1) +
  scale_color_manual(values = series_palette) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Tasa de ganancia",
    subtitle = "Ganancia sobre stock de capital más capital circulante adelantado, en valores corrientes",
    y = "Porcentaje",
    caption = "Fuente: elaboración propia con panel EAAE."
  ) +
  theme_eaae()

ganancias_indice <- indices_2005 %>%
  select(anno, ambito_label, ganancia_pb_ind_2005, ganancia_pp_ind_2005) %>%
  pivot_longer(
    cols = starts_with("ganancia"),
    names_to = "serie",
    values_to = "valor"
  ) %>%
  mutate(
    serie = recode(
      serie,
      ganancia_pb_ind_2005 = "Precios básicos",
      ganancia_pp_ind_2005 = "Precios productor"
    )
  ) %>%
  filter(!is.na(valor))

fig_02 <- ggplot(ganancias_indice, aes(anno, valor, color = serie)) +
  geom_hline(yintercept = 1, linewidth = 0.3, color = "grey70") +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.6) +
  facet_wrap(~ ambito_label, ncol = 1) +
  scale_color_manual(values = series_palette) +
  scale_y_continuous(labels = label_number(accuracy = 0.1, decimal.mark = ",")) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Ganancia en índice de volumen",
    subtitle = "Índices encadenados con base 2005=1, construidos desde resultados en precios de 2005",
    y = "Índice 2005=1",
    caption = "Fuente: elaboración propia con panel EAAE y deflactores Oyanthabal."
  ) +
  theme_eaae()

build_decomposition_plot <- function(data, title) {
  decomposition <- data %>%
    transmute(
      anno,
      `Costo laboral` = costo_laboral / vab_pp,
      `Consumo capital fijo` = consumo_capital_fijo / vab_pp,
      `Ganancia pp` = ganancia_pp / vab_pp
    ) %>%
    pivot_longer(
      cols = -anno,
      names_to = "componente",
      values_to = "participacion"
    )

  ggplot(decomposition, aes(anno, participacion, fill = componente)) +
    geom_area(alpha = 0.9, color = "white", linewidth = 0.15) +
    scale_fill_manual(values = series_palette) +
    scale_y_continuous(labels = percent_format(accuracy = 1)) +
    scale_x_continuous(breaks = pretty_breaks(n = 8)) +
    labs(
      title = title,
      subtitle = "Participación en el VAB a precios productor, en valores corrientes",
      y = "Participación del VAB",
      caption = "Fuente: elaboración propia con panel EAAE."
    ) +
    theme_eaae()
}

fig_03 <- build_decomposition_plot(
  total_corrientes,
  "Descomposición del VAB: economía total"
)

fig_04 <- build_decomposition_plot(
  industrial_corrientes,
  "Descomposición del VAB: industria"
)

capital_componentes <- constantes %>%
  select(
    anno,
    ambito_label,
    stock_capital_imputado,
    capital_circulante_adelantado,
    capital_total_adelantado
  ) %>%
  pivot_longer(
    cols = c(
      stock_capital_imputado,
      capital_circulante_adelantado,
      capital_total_adelantado
    ),
    names_to = "serie",
    values_to = "valor"
  ) %>%
  mutate(
    serie = recode(
      serie,
      stock_capital_imputado = "Stock capital",
      capital_circulante_adelantado = "Capital circulante adelantado",
      capital_total_adelantado = "Capital total adelantado"
    )
  )

fig_05 <- ggplot(capital_componentes, aes(anno, valor, color = serie)) +
  geom_line(linewidth = 0.9, na.rm = TRUE) +
  geom_point(size = 1.5, na.rm = TRUE) +
  facet_wrap(~ ambito_label, ncol = 1, scales = "free_y") +
  scale_color_manual(values = series_palette) +
  scale_y_continuous(
    labels = label_number(
      accuracy = 1,
      scale = 1e-9,
      big.mark = ".",
      decimal.mark = ","
    )
  ) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Capital adelantado y componentes",
    subtitle = "Niveles en precios de 2005; usa stock observado o imputado según disponibilidad",
    y = "Miles de millones de pesos de 2005",
    caption = "Fuente: elaboración propia con panel EAAE y deflactores Oyanthabal."
  ) +
  theme_eaae()

participacion_industria <- industrial_corrientes %>%
  select(anno, vab_pp_participacion_total)

fig_06 <- ggplot(participacion_industria, aes(anno, vab_pp_participacion_total)) +
  geom_line(color = "#1B4E89", linewidth = 0.95) +
  geom_point(color = "#1B4E89", size = 1.7) +
  scale_y_continuous(labels = percent_format(accuracy = 0.1)) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Participación industrial en el VAB total",
    subtitle = "VAB industrial a precios productor sobre VAB total de la economía",
    y = "Participación",
    caption = "Fuente: elaboración propia con panel EAAE."
  ) +
  theme_eaae()

inversion_industrial <- rama_c %>%
  select(anno, fbcf) %>%
  left_join(
    industrial_constante %>%
      select(anno, gdp_price_index_base_2005, vab_pp),
    by = "anno"
  ) %>%
  mutate(
    inversion_constante = fbcf / gdp_price_index_base_2005,
    inversion_vab = inversion_constante / vab_pp
  )

dual_axis_factor <- max(inversion_industrial$inversion_vab, na.rm = TRUE) /
  max(inversion_industrial$inversion_constante, na.rm = TRUE)

fig_07 <- ggplot(inversion_industrial, aes(anno)) +
  geom_line(
    aes(
      y = inversion_vab,
      color = "Inversión / VAB manufacturero"
    ),
    linewidth = 0.95,
    na.rm = TRUE
  ) +
  geom_point(
    aes(
      y = inversion_vab,
      color = "Inversión / VAB manufacturero"
    ),
    size = 1.7,
    na.rm = TRUE
  ) +
  geom_line(
    aes(
      y = inversion_constante * dual_axis_factor,
      color = "Inversión constante"
    ),
    linewidth = 0.95,
    na.rm = TRUE
  ) +
  geom_point(
    aes(
      y = inversion_constante * dual_axis_factor,
      color = "Inversión constante"
    ),
    size = 1.7,
    na.rm = TRUE
  ) +
  scale_color_manual(values = series_palette) +
  scale_y_continuous(
    labels = percent_format(accuracy = 1),
    sec.axis = sec_axis(
      ~ . / dual_axis_factor,
      labels = label_number(
        accuracy = 1,
        scale = 1e-9,
        big.mark = ".",
        decimal.mark = ","
      ),
      name = "Inversión a precios constantes UYU 2005"
    )
  ) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Inversión manufacturera",
    subtitle = "FBCF industrial en precios de 2005 (eje der., miles de millones) y como porcentaje del VAB manufacturero",
    y = "Inversión / VAB manufacturero",
    caption = "Fuente: elaboración propia con panel EAAE y deflactores Oyanthabal."
  ) +
  theme_eaae()

indices_resultados <- indices_2005 %>%
  select(
    anno,
    ambito_label,
    vab_pp_ind_2005,
    costo_laboral_ind_2005,
    ganancia_pp_ind_2005,
    capital_total_adelantado_ind_2005
  ) %>%
  pivot_longer(
    cols = -c(anno, ambito_label),
    names_to = "serie",
    values_to = "valor"
  ) %>%
  mutate(
    serie = recode(
      serie,
      vab_pp_ind_2005 = "VAB",
      costo_laboral_ind_2005 = "Masa salarial",
      ganancia_pp_ind_2005 = "Ganancia",
      capital_total_adelantado_ind_2005 = "Capital adelantado"
    )
  ) %>%
  filter(!is.na(valor))

fig_08 <- ggplot(indices_resultados, aes(anno, valor, color = serie)) +
  geom_hline(yintercept = 1, linewidth = 0.3, color = "grey70") +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.4) +
  facet_wrap(~ ambito_label, ncol = 1) +
  scale_color_manual(values = series_palette) +
  scale_y_continuous(labels = label_number(accuracy = 0.1, decimal.mark = ",")) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Resultados en índices de volumen",
    subtitle = "VAB, masa salarial, ganancia y capital adelantado; base 2005=1",
    y = "Índice 2005=1",
    caption = "Fuente: elaboración propia con panel EAAE y deflactores Oyanthabal."
  ) +
  theme_eaae()

figures <- c(
  "01_representatividad_eaae_bcu_corrientes.png" = save_plot(fig_00, "01_representatividad_eaae_bcu_corrientes.png"),
  "01_tasa_ganancia_corrientes.png" = save_plot(fig_01, "01_tasa_ganancia_corrientes.png"),
  "02_ganancia_indice_2005.png" = save_plot(fig_02, "02_ganancia_indice_2005.png"),
  "03_descomposicion_vab_total_corrientes.png" = save_plot(fig_03, "03_descomposicion_vab_total_corrientes.png"),
  "04_descomposicion_vab_industria_corrientes.png" = save_plot(fig_04, "04_descomposicion_vab_industria_corrientes.png"),
  "05_capital_adelantado_corrientes.png" = save_plot(fig_05, "05_capital_adelantado_corrientes.png"),
  "06_participacion_industria_vab_corrientes.png" = save_plot(fig_06, "06_participacion_industria_vab_corrientes.png"),
  "07_inversion_manufacturera_constante.png" = save_plot(fig_07, "07_inversion_manufacturera_constante.png"),
  "08_indices_resultados_total_industria.png" = save_plot(fig_08, "08_indices_resultados_total_industria.png", height = 7)
)

report_lines <- c(
  "# Resultados visuales EAAE",
  "",
  paste0("Fuente de datos: `", file.path("data", "analysis-data", panel_file), "`."),
  "",
  "Este informe resume visualmente los resultados propios calculados para la economía total y la rama industrial. Las figuras se generan con `command-files/analysis-command-files/03_visualizar_resultados_eaae.R` y se guardan como PNG para que GitHub las muestre directamente.",
  "",
  "## Criterios de lectura",
  "",
  "- La representatividad EAAE/BCU compara el VAB corriente EAAE contra el VAB corriente BCU disponible en las hojas de resultados corrientes.",
  "- Las tasas de ganancia, la descomposición del VAB y la participación industrial se muestran en valores corrientes para conservar la cobertura hasta 2024.",
  "- Las ganancias indexadas y el capital adelantado usan las hojas de resultados en precios constantes.",
  "- La inversión manufacturera usa `fbcf` de la rama C y se deflacta con `gdp_price_index_base_2005`; la relación de inversión sobre VAB usa el VAB industrial constante.",
  "- Las series en precios constantes e índices dependen del `gdp_price_index_base_2005`, disponible hasta 2019; por eso esas figuras no fuerzan continuidad después de ese año.",
  "- El capital adelantado usa `stock_capital_imputado`, que replica `stock_capital` cuando existe e imputa 2002 y 2011 con factores históricos de `stock_capital / consumo_capital_fijo`.",
  "",
  "## Figuras",
  "",
  "### 1. Representatividad de la serie EAAE en relación a PBI BCU",
  "",
  "Compara el VAB corriente EAAE con el VAB corriente de referencia de BCU para economía total e industria.",
  "",
  paste0("![Representatividad EAAE/BCU](", relative_fig("01_representatividad_eaae_bcu_corrientes.png"), ")"),
  "",
  "### 2. Tasa de ganancia",
  "",
  "La tasa se calcula como ganancia sobre `stock_capital_imputado + capital_circulante_adelantado`. Se presentan las variantes a precios básicos y a precios productor.",
  "",
  paste0("![Tasa de ganancia](", relative_fig("01_tasa_ganancia_corrientes.png"), ")"),
  "",
  "### 3. Ganancia en índice 2005=1",
  "",
  "Compara la dinámica real de la ganancia a precios básicos y productor. La base común facilita comparar economía total e industria aunque sus niveles difieran.",
  "",
  paste0("![Ganancia en índice 2005=1](", relative_fig("02_ganancia_indice_2005.png"), ")"),
  "",
  "### 4. Descomposición del VAB: economía total",
  "",
  "Distribuye el VAB a precios productor entre costo laboral, consumo de capital fijo y ganancia a precios productor.",
  "",
  paste0("![Descomposición del VAB total](", relative_fig("03_descomposicion_vab_total_corrientes.png"), ")"),
  "",
  "### 5. Descomposición del VAB: industria",
  "",
  "Replica la misma descomposición para la rama industrial, permitiendo evaluar si su estructura difiere de la economía total.",
  "",
  paste0("![Descomposición del VAB industrial](", relative_fig("04_descomposicion_vab_industria_corrientes.png"), ")"),
  "",
  "### 6. Capital adelantado y componentes",
  "",
  "Muestra el stock de capital, el capital circulante adelantado y el capital total adelantado en precios de 2005. Las escalas se separan por ámbito para no ocultar la dinámica industrial.",
  "",
  paste0("![Capital adelantado y componentes](", relative_fig("05_capital_adelantado_corrientes.png"), ")"),
  "",
  "### 7. Participación industrial en el VAB total",
  "",
  "Mide el peso de la industria manufacturera dentro del VAB total de la economía.",
  "",
  paste0("![Participación industrial](", relative_fig("06_participacion_industria_vab_corrientes.png"), ")"),
  "",
  "### 8. Inversión manufacturera",
  "",
  "Muestra la FBCF industrial en precios de 2005 en el eje derecho y la misma inversión como porcentaje del VAB manufacturero en el eje izquierdo.",
  "",
  paste0("![Inversión manufacturera](", relative_fig("07_inversion_manufacturera_constante.png"), ")"),
  "",
  "### 9. Resultados en índices",
  "",
  "Compara en dos paneles, economía total e industria, la evolución del VAB, la masa salarial, la ganancia y el capital adelantado en índices con base 2005=1.",
  "",
  paste0("![Resultados en índices](", relative_fig("08_indices_resultados_total_industria.png"), ")"),
  "",
  "## Reproducción",
  "",
  "Desde la raíz del repositorio:",
  "",
  "```bash",
  "Rscript command-files/analysis-command-files/03_visualizar_resultados_eaae.R",
  "```"
)

writeLines(report_lines, report_path, useBytes = TRUE)

message("Informe escrito en ", report_path)
message("Figuras escritas en ", fig_dir, ":")
for (figure_path in figures) {
  message(" - ", figure_path)
}
