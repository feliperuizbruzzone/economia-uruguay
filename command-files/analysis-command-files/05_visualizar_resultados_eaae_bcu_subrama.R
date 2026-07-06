# Build a GitHub-readable Markdown report and PNG figures from the long
# EAAE-BCU total/industry/subbranch results workbook.
#
# Run from the project root:
#   Rscript command-files/analysis-command-files/05_visualizar_resultados_eaae_bcu_subrama.R

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readxl)
  library(scales)
  library(tidyr)
})

analysis_dir <- file.path("data", "analysis-data")
fig_dir <- file.path("output", "figures", "eaae_bcu_total_industria_subrama")
docs_dir <- "docs"
workbook_path <- file.path(
  analysis_dir,
  "20260706_resultados_eaae_bcu_total_industria_subrama.xlsx"
)
report_path <- file.path(
  docs_dir,
  "20260706_resultados_eaae_bcu_total_industria_subrama.md"
)

dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(docs_dir, recursive = TRUE, showWarnings = FALSE)

safe_divide <- function(numerator, denominator) {
  result <- numerator / denominator
  result[is.na(numerator) | is.na(denominator) | denominator == 0] <- NA_real_
  result
}

wrap_label <- function(x, width = 28) {
  vapply(
    x,
    function(value) {
      if (is.na(value) || value == "") {
        return("")
      }
      paste(strwrap(value, width = width), collapse = "\n")
    },
    character(1)
  )
}

clean_result_sheet <- function(sheet_name) {
  readxl::read_excel(
    workbook_path,
    sheet = sheet_name,
    .name_repair = "minimal"
  ) %>%
    mutate(
      anno = as.integer(anno),
      across(where(is.logical), as.numeric),
      ambito_label = case_when(
        seccion == "economia_total" ~ "Economía total",
        seccion == "industria-total" ~ "Industria manufacturera",
        TRUE ~ descripcion_nivel
      ),
      subrama_label = wrap_label(descripcion_nivel)
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
      strip.text = element_text(face = "bold", size = 8.5),
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
  file.path("..", "output", "figures", "eaae_bcu_total_industria_subrama", filename)
}

fig_md <- function(alt, filename) {
  paste0("![", alt, "](", relative_fig(filename), ")")
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
  "Capital adelantado" = "#B23A48",
  "Economía total" = "#1B4E89",
  "Industria manufacturera" = "#B23A48"
)

corrientes <- clean_result_sheet("resultados-corrientes")
constantes <- clean_result_sheet("resultados-constantes")
indices_2005 <- clean_result_sheet("resultados-ind-2005")

main_sections <- c("economia_total", "industria-total")

main_corrientes <- corrientes %>% filter(seccion %in% main_sections)
main_constantes <- constantes %>% filter(seccion %in% main_sections)
main_indices <- indices_2005 %>% filter(seccion %in% main_sections)
subrama_corrientes <- corrientes %>% filter(nivel_panel == "subrama_industrial")
subrama_constantes <- constantes %>% filter(nivel_panel == "subrama_industrial")
subrama_indices <- indices_2005 %>% filter(nivel_panel == "subrama_industrial")

subrama_order <- subrama_corrientes %>%
  distinct(seccion, descripcion_nivel, subrama_label) %>%
  arrange(seccion)

subrama_labels <- setNames(subrama_order$subrama_label, subrama_order$seccion)
subrama_palette <- setNames(
  hcl.colors(nrow(subrama_order), palette = "Dark 3"),
  subrama_order$subrama_label
)

representatividad_bcu <- main_corrientes %>%
  select(anno, ambito_label, vab_eaae_bcu_pct) %>%
  filter(!is.na(vab_eaae_bcu_pct))

fig_01 <- ggplot(representatividad_bcu, aes(anno, vab_eaae_bcu_pct)) +
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
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU."
  ) +
  theme_eaae()

tasas_ganancia <- main_corrientes %>%
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

fig_02 <- ggplot(tasas_ganancia, aes(anno, valor, color = serie)) +
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
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU."
  ) +
  theme_eaae()

ganancias_indice <- main_indices %>%
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

fig_03 <- ggplot(ganancias_indice, aes(anno, valor, color = serie)) +
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
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU y deflactores BCU."
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
      caption = "Fuente: elaboración propia con panel integrado EAAE-BCU."
    ) +
    theme_eaae()
}

fig_04 <- build_decomposition_plot(
  main_corrientes %>% filter(seccion == "economia_total"),
  "Descomposición del VAB: economía total"
)

fig_05 <- build_decomposition_plot(
  main_corrientes %>% filter(seccion == "industria-total"),
  "Descomposición del VAB: industria"
)

capital_componentes <- main_constantes %>%
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

fig_06 <- ggplot(capital_componentes, aes(anno, valor, color = serie)) +
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
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU y deflactores BCU."
  ) +
  theme_eaae()

participacion_industria <- main_corrientes %>%
  filter(seccion == "industria-total") %>%
  select(anno, vab_pp_participacion_total)

fig_07 <- ggplot(participacion_industria, aes(anno, vab_pp_participacion_total)) +
  geom_line(color = "#1B4E89", linewidth = 0.95) +
  geom_point(color = "#1B4E89", size = 1.7) +
  scale_y_continuous(labels = percent_format(accuracy = 0.1)) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Participación industrial en el VAB total",
    subtitle = "VAB industrial a precios productor sobre VAB total de la economía",
    y = "Participación",
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU."
  ) +
  theme_eaae()

inversion_industrial <- main_constantes %>%
  filter(seccion == "industria-total") %>%
  mutate(inversion_vab = safe_divide(fbcf, vab_pp))

dual_axis_factor <- max(inversion_industrial$inversion_vab, na.rm = TRUE) /
  max(inversion_industrial$fbcf, na.rm = TRUE)

fig_08 <- ggplot(inversion_industrial, aes(anno)) +
  geom_line(
    aes(y = inversion_vab, color = "Inversión / VAB manufacturero"),
    linewidth = 0.95,
    na.rm = TRUE
  ) +
  geom_point(
    aes(y = inversion_vab, color = "Inversión / VAB manufacturero"),
    size = 1.7,
    na.rm = TRUE
  ) +
  geom_line(
    aes(y = fbcf * dual_axis_factor, color = "Inversión constante"),
    linewidth = 0.95,
    na.rm = TRUE
  ) +
  geom_point(
    aes(y = fbcf * dual_axis_factor, color = "Inversión constante"),
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
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU y deflactores BCU."
  ) +
  theme_eaae()

indices_resultados <- main_indices %>%
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

fig_09 <- ggplot(indices_resultados, aes(anno, valor, color = serie)) +
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
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU y deflactores BCU."
  ) +
  theme_eaae()

productividad_indice <- main_indices %>%
  select(anno, ambito_label, productividad_trabajo_ind_2005) %>%
  transmute(
    anno,
    ambito_label,
    valor = productividad_trabajo_ind_2005
  ) %>%
  filter(!is.na(valor))

fig_10 <- ggplot(productividad_indice, aes(anno, valor, color = ambito_label)) +
  geom_hline(yintercept = 1, linewidth = 0.3, color = "grey70") +
  geom_line(linewidth = 0.95) +
  geom_point(size = 1.7) +
  scale_color_manual(values = series_palette) +
  scale_y_continuous(labels = label_number(accuracy = 0.1, decimal.mark = ",")) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Productividad del trabajo en índice",
    subtitle = "VAB a precios constantes por puesto de trabajo; base 2005=1",
    y = "Índice 2005=1",
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU y deflactores BCU."
  ) +
  theme_eaae()

subrama_participacion <- subrama_corrientes %>%
  mutate(
    subrama_label = factor(subrama_label, levels = subrama_labels)
  ) %>%
  filter(!is.na(vab_pp_participacion_industria))

fig_11 <- ggplot(
  subrama_participacion,
  aes(anno, vab_pp_participacion_industria, fill = subrama_label)
) +
  geom_area(alpha = 0.95, color = "white", linewidth = 0.08) +
  scale_fill_manual(values = subrama_palette) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Composición del VAB industrial por subrama",
    subtitle = "Participación de cada subrama homologada en el VAB manufacturero corriente",
    y = "Participación en industria",
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU."
  ) +
  theme_eaae() +
  theme(legend.text = element_text(size = 7))

subrama_tasa <- subrama_corrientes %>%
  mutate(
    subrama_label = factor(subrama_label, levels = subrama_labels)
  ) %>%
  filter(!is.na(tasa_ganancia_pp))

fig_12 <- ggplot(subrama_tasa, aes(anno, tasa_ganancia_pp)) +
  geom_hline(yintercept = 0, linewidth = 0.25, color = "grey70") +
  geom_line(color = "#B23A48", linewidth = 0.75) +
  facet_wrap(~ subrama_label, ncol = 2, scales = "free_y") +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  scale_x_continuous(breaks = pretty_breaks(n = 5)) +
  labs(
    title = "Tasa de ganancia por subrama industrial",
    subtitle = "Ganancia a precios productor sobre capital total adelantado, en valores corrientes",
    y = "Porcentaje",
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU."
  ) +
  theme_eaae()

subrama_indices_resultados <- subrama_indices %>%
  select(
    anno,
    seccion,
    subrama_label,
    vab_pp_ind_2005,
    costo_laboral_ind_2005,
    ganancia_pp_ind_2005,
    capital_total_adelantado_ind_2005
  ) %>%
  pivot_longer(
    cols = ends_with("_ind_2005"),
    names_to = "serie",
    values_to = "valor"
  ) %>%
  mutate(
    subrama_label = factor(subrama_label, levels = subrama_labels),
    serie = recode(
      serie,
      vab_pp_ind_2005 = "VAB",
      costo_laboral_ind_2005 = "Masa salarial",
      ganancia_pp_ind_2005 = "Ganancia",
      capital_total_adelantado_ind_2005 = "Capital adelantado"
    )
  ) %>%
  filter(!is.na(valor))

fig_13 <- ggplot(subrama_indices_resultados, aes(anno, valor, color = serie)) +
  geom_hline(yintercept = 1, linewidth = 0.25, color = "grey70") +
  geom_line(linewidth = 0.7) +
  facet_wrap(~ subrama_label, ncol = 2, scales = "free_y") +
  scale_color_manual(values = series_palette) +
  scale_y_continuous(labels = label_number(accuracy = 0.1, decimal.mark = ",")) +
  scale_x_continuous(breaks = pretty_breaks(n = 5)) +
  labs(
    title = "Resultados por subrama en índices de volumen",
    subtitle = "VAB, masa salarial, ganancia y capital adelantado; base 2005=1",
    y = "Índice 2005=1",
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU y deflactores BCU."
  ) +
  theme_eaae()

subrama_productividad <- subrama_indices %>%
  mutate(
    subrama_label = factor(subrama_label, levels = subrama_labels)
  ) %>%
  filter(!is.na(productividad_trabajo_ind_2005))

fig_14 <- ggplot(
  subrama_productividad,
  aes(anno, productividad_trabajo_ind_2005)
) +
  geom_hline(yintercept = 1, linewidth = 0.25, color = "grey70") +
  geom_line(color = "#1B4E89", linewidth = 0.75) +
  facet_wrap(~ subrama_label, ncol = 2, scales = "free_y") +
  scale_y_continuous(labels = label_number(accuracy = 0.1, decimal.mark = ",")) +
  scale_x_continuous(breaks = pretty_breaks(n = 5)) +
  labs(
    title = "Productividad del trabajo por subrama",
    subtitle = "VAB a precios constantes por puesto de trabajo; base 2005=1",
    y = "Índice 2005=1",
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU y deflactores BCU."
  ) +
  theme_eaae()

figure_files <- c(
  "01_representatividad_eaae_bcu_corrientes.png",
  "02_tasa_ganancia_corrientes.png",
  "03_ganancia_indice_2005.png",
  "04_descomposicion_vab_total_corrientes.png",
  "05_descomposicion_vab_industria_corrientes.png",
  "06_capital_adelantado_constante.png",
  "07_participacion_industria_vab_corrientes.png",
  "08_inversion_manufacturera_constante.png",
  "09_indices_resultados_total_industria.png",
  "10_productividad_trabajo_indice_2005.png",
  "11_composicion_vab_industrial_subramas.png",
  "12_tasa_ganancia_subramas_corrientes.png",
  "13_indices_resultados_subramas.png",
  "14_productividad_subramas_indice_2005.png"
)

figures <- c(
  save_plot(fig_01, figure_files[[1]]),
  save_plot(fig_02, figure_files[[2]]),
  save_plot(fig_03, figure_files[[3]]),
  save_plot(fig_04, figure_files[[4]]),
  save_plot(fig_05, figure_files[[5]]),
  save_plot(fig_06, figure_files[[6]]),
  save_plot(fig_07, figure_files[[7]]),
  save_plot(fig_08, figure_files[[8]]),
  save_plot(fig_09, figure_files[[9]], height = 7),
  save_plot(fig_10, figure_files[[10]]),
  save_plot(fig_11, figure_files[[11]], width = 12, height = 7),
  save_plot(fig_12, figure_files[[12]], width = 12, height = 12),
  save_plot(fig_13, figure_files[[13]], width = 12, height = 12),
  save_plot(fig_14, figure_files[[14]], width = 12, height = 12)
)

report_lines <- c(
  "# Resultados visuales EAAE-BCU: total, industria y subramas",
  "",
  paste0("Fuente de datos: `", workbook_path, "`."),
  "",
  "Este informe replica la lógica argumental del informe `docs/20260605_eaae_resultados_eaae_oyanthaabal_total_industria.md`, pero usa el libro largo de resultados EAAE-BCU para comparar economía total, industria manufacturera agregada y subramas industriales homologadas. Las figuras se generan con `command-files/analysis-command-files/05_visualizar_resultados_eaae_bcu_subrama.R` y se guardan como PNG para visualización directa en GitHub.",
  "",
  "## Criterios de lectura",
  "",
  "- La columna `seccion` funciona como filtro: `economia_total`, `industria-total` o grupo de subrama industrial homologado.",
  "- La representatividad EAAE/BCU compara el VAB EAAE contra el VAB BCU disponible en la misma escala de la hoja usada.",
  "- Las tasas de ganancia, la descomposición del VAB y la participación industrial se muestran en valores corrientes para conservar la cobertura 2001-2024.",
  "- Las ganancias indexadas, el capital adelantado y la productividad usan resultados en precios constantes, deflactados con índices BCU empalmados a base 2005=1.",
  "- El capital adelantado usa `stock_capital_imputado` y `capital_circulante_adelantado`; la rotación operativa es `rotacion_calibrada_sobre_6_6`.",
  "- Las subramas industriales se leen como grupos CIIU Rev.4 compatibles, no como divisiones Rev.4 puras.",
  "",
  "## Resultados agregados",
  "",
  "### 1. Representatividad de la serie EAAE en relación a PBI BCU",
  "",
  "Compara el VAB corriente EAAE con el VAB corriente de referencia de BCU para economía total e industria.",
  "",
  fig_md("Representatividad EAAE/BCU", figure_files[[1]]),
  "",
  "### 2. Tasa de ganancia",
  "",
  "La tasa se calcula como ganancia sobre `stock_capital_imputado + capital_circulante_adelantado`. Se presentan las variantes a precios básicos y a precios productor.",
  "",
  fig_md("Tasa de ganancia", figure_files[[2]]),
  "",
  "### 3. Ganancia en índice 2005=1",
  "",
  "Compara la dinámica real de la ganancia a precios básicos y productor. La base común facilita comparar economía total e industria aunque sus niveles difieran.",
  "",
  fig_md("Ganancia en índice 2005=1", figure_files[[3]]),
  "",
  "### 4. Descomposición del VAB: economía total",
  "",
  "Distribuye el VAB a precios productor entre costo laboral, consumo de capital fijo y ganancia a precios productor.",
  "",
  fig_md("Descomposición del VAB total", figure_files[[4]]),
  "",
  "### 5. Descomposición del VAB: industria",
  "",
  "Replica la misma descomposición para la rama industrial agregada, permitiendo evaluar si su estructura difiere de la economía total.",
  "",
  fig_md("Descomposición del VAB industrial", figure_files[[5]]),
  "",
  "### 6. Capital adelantado y componentes",
  "",
  "Muestra el stock de capital, el capital circulante adelantado y el capital total adelantado en precios de 2005. Las escalas se separan por ámbito para no ocultar la dinámica industrial.",
  "",
  fig_md("Capital adelantado y componentes", figure_files[[6]]),
  "",
  "### 7. Participación industrial en el VAB total",
  "",
  "Mide el peso de la industria manufacturera dentro del VAB total de la economía.",
  "",
  fig_md("Participación industrial", figure_files[[7]]),
  "",
  "### 8. Inversión manufacturera",
  "",
  "Muestra la FBCF industrial en precios de 2005 en el eje derecho y la misma inversión como porcentaje del VAB manufacturero en el eje izquierdo.",
  "",
  fig_md("Inversión manufacturera", figure_files[[8]]),
  "",
  "### 9. Resultados en índices",
  "",
  "Compara en dos paneles, economía total e industria, la evolución del VAB, la masa salarial, la ganancia y el capital adelantado en índices con base 2005=1.",
  "",
  fig_md("Resultados en índices", figure_files[[9]]),
  "",
  "### 10. Productividad del trabajo en índice",
  "",
  "Compara la evolución de la productividad del trabajo, medida como VAB a precios constantes por puesto de trabajo, para economía total y rama manufacturera.",
  "",
  fig_md("Productividad del trabajo en índice", figure_files[[10]]),
  "",
  "## Resultados por subrama industrial",
  "",
  "La desagregación por subrama permite observar si la evolución manufacturera agregada se explica por un patrón común o por trayectorias sectoriales diferenciadas. Las subramas se presentan con la homologación CIIU Rev.4 compatible usada en el panel integrado.",
  "",
  "### 11. Composición del VAB industrial por subrama",
  "",
  "Muestra cómo se distribuye el VAB manufacturero corriente entre las subramas industriales homologadas.",
  "",
  fig_md("Composición del VAB industrial por subrama", figure_files[[11]]),
  "",
  "### 12. Tasa de ganancia por subrama industrial",
  "",
  "Replica la tasa de ganancia a precios productor para cada subrama, usando la rotación calibrada sectorial y el stock de capital imputado cuando corresponde.",
  "",
  fig_md("Tasa de ganancia por subrama industrial", figure_files[[12]]),
  "",
  "### 13. Resultados por subrama en índices",
  "",
  "Compara VAB, masa salarial, ganancia y capital adelantado en índices base 2005=1 dentro de cada subrama.",
  "",
  fig_md("Resultados por subrama en índices", figure_files[[13]]),
  "",
  "### 14. Productividad del trabajo por subrama",
  "",
  "Mide la productividad como VAB a precios constantes por puesto de trabajo, expresada como índice con base 2005=1.",
  "",
  fig_md("Productividad por subrama", figure_files[[14]]),
  "",
  "## Reproducción",
  "",
  "Desde la raíz del repositorio:",
  "",
  "```bash",
  "Rscript command-files/analysis-command-files/05_visualizar_resultados_eaae_bcu_subrama.R",
  "```"
)

writeLines(report_lines, report_path, useBytes = TRUE)

message("Informe escrito en ", report_path)
message("Figuras escritas en ", fig_dir, ":")
for (figure_path in figures) {
  message(" - ", figure_path)
}
