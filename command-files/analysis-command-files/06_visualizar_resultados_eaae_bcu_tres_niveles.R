# Build a GitHub-readable Markdown report and PNG figures for EAAE-BCU
# aggregate profit-rate results at three levels.
#
# Run from the project root:
#   Rscript command-files/analysis-command-files/06_visualizar_resultados_eaae_bcu_tres_niveles.R

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readxl)
  library(scales)
  library(tidyr)
})

analysis_dir <- file.path("data", "analysis-data")
docs_dir <- "docs"
report_date <- Sys.getenv("EAAE_REPORT_DATE", unset = "20260806")
workbook_date <- Sys.getenv("EAAE_WORKBOOK_DATE", unset = "20260727")
source_caption <- "Fuente: Elaboración propia en base a EAAE. Índices de precios extraídos de BCU."
oyanthabal_tg_path <- file.path(analysis_dir, "oyanthabal_tasa_ganancia_uruguay.csv")
stock_comparison_path <- file.path(
  analysis_dir,
  "20260805_comparacion_stock_capital_eaae_ciu.csv"
)

workbook_path <- file.path(
  analysis_dir,
  paste0(workbook_date, "_resultados_eaae_bcu_total_industria_subrama.xlsx")
)
fig_dir <- file.path("output", "figures", paste0("eaae_bcu_tres_niveles_", report_date))
report_path <- file.path(
  docs_dir,
  paste0(report_date, "_resultados_eaae_bcu_tres_niveles.md")
)

dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(docs_dir, recursive = TRUE, showWarnings = FALSE)
unlink(list.files(fig_dir, pattern = "\\.png$", full.names = TRUE))

safe_divide <- function(numerator, denominator) {
  result <- numerator / denominator
  result[is.na(numerator) | is.na(denominator) | denominator == 0] <- NA_real_
  result
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
      strip.text = element_text(face = "bold", size = 9),
      axis.title.x = element_blank()
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
        seccion == "industria-sin-papel-coque-refinacion" ~
          "Industria depurada",
        TRUE ~ descripcion_nivel
      )
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
  file.path("..", "output", "figures", basename(fig_dir), filename)
}

fig_md <- function(alt, filename) {
  paste0("![", alt, "](", relative_fig(filename), ")")
}

format_one_decimal <- function(x) {
  ifelse(is.na(x), "NA", formatC(round(x, 1), format = "f", digits = 1))
}

markdown_table <- function(data) {
  header <- paste0("| ", paste(names(data), collapse = " | "), " |")
  separator <- paste0(
    "|",
    paste(rep("---:", ncol(data)), collapse = "|"),
    "|"
  )
  rows <- apply(
    data,
    1,
    function(row) paste0("| ", paste(row, collapse = " | "), " |")
  )
  c(header, separator, rows)
}

base_index <- function(data, group_cols, value_col, base_year = 2004) {
  data %>%
    group_by(across(all_of(group_cols))) %>%
    mutate(
      .base_value = .data[[value_col]][anno == base_year][1],
      valor_indice = safe_divide(.data[[value_col]], .base_value) * 100
    ) %>%
    ungroup() %>%
    select(-.base_value)
}

label_decomposition_points <- function(data) {
  data %>%
    group_by(componente) %>%
    filter(
      anno == min(anno, na.rm = TRUE) |
        anno == max(anno, na.rm = TRUE) |
        anno == 2005L |
        anno == 2014L |
        participacion == max(participacion, na.rm = TRUE) |
        participacion == min(participacion, na.rm = TRUE)
    ) %>%
    ungroup() %>%
    distinct(anno, componente, .keep_all = TRUE) %>%
    mutate(etiqueta = percent(participacion, accuracy = 1))
}

label_break_points <- function(
    data,
    group_cols,
    value_col = "valor",
    label_accuracy = 1,
    n_changes = 2) {
  data %>%
    filter(!is.na(.data[[value_col]])) %>%
    group_by(across(all_of(group_cols))) %>%
    arrange(anno, .by_group = TRUE) %>%
    mutate(.delta = abs(.data[[value_col]] - lag(.data[[value_col]]))) %>%
    filter(
      anno == max(anno, na.rm = TRUE) |
        .data[[value_col]] == max(.data[[value_col]], na.rm = TRUE) |
        .data[[value_col]] == min(.data[[value_col]], na.rm = TRUE) |
        min_rank(desc(.delta)) <= n_changes
    ) %>%
    ungroup() %>%
    distinct(across(all_of(c(group_cols, "anno"))), .keep_all = TRUE) %>%
    mutate(etiqueta = paste0(anno, ": ", percent(.data[[value_col]], accuracy = label_accuracy)))
}

build_decomposition_plot <- function(data, title) {
  decomposition <- data %>%
    transmute(
      anno,
      `Costo laboral` = safe_divide(costo_laboral, vab_pp),
      `Consumo capital fijo` = safe_divide(consumo_capital_fijo, vab_pp),
      `Ganancia pp` = safe_divide(ganancia_pp, vab_pp)
    ) %>%
    pivot_longer(
      cols = -anno,
      names_to = "componente",
      values_to = "participacion"
    ) %>%
    filter(!is.na(participacion))

  label_data <- label_decomposition_points(decomposition)
  final_data <- decomposition %>%
    group_by(componente) %>%
    filter(anno == max(anno, na.rm = TRUE)) %>%
    ungroup() %>%
    mutate(etiqueta = paste0(componente, " ", percent(participacion, accuracy = 1)))

  ggplot(decomposition, aes(anno, participacion, color = componente)) +
    geom_hline(yintercept = 0, linewidth = 0.25, color = "grey75") +
    geom_line(linewidth = 0.95) +
    geom_point(size = 1.5) +
    geom_text(
      data = label_data,
      aes(label = etiqueta),
      size = 2.8,
      vjust = -0.8,
      show.legend = FALSE,
      check_overlap = TRUE
    ) +
    geom_text(
      data = final_data,
      aes(label = etiqueta),
      hjust = 0,
      nudge_x = 0.25,
      size = 3,
      show.legend = FALSE
    ) +
    scale_color_manual(values = component_palette) +
    scale_y_continuous(labels = percent_format(accuracy = 1)) +
    scale_x_continuous(
      breaks = pretty_breaks(n = 8),
      limits = c(min(decomposition$anno), max(decomposition$anno) + 3)
    ) +
    labs(
      title = title,
      subtitle = "Participación en el VAB a precios productor, en valores corrientes",
      y = "Participación del VAB",
      caption = source_caption
    ) +
    theme_eaae()
}

component_palette <- c(
  "Costo laboral" = "#2E7D32",
  "Consumo capital fijo" = "#E07A5F",
  "Ganancia pp" = "#6A4C93"
)

scope_palette <- c(
  "Economía total" = "#1B4E89",
  "Industria manufacturera" = "#B23A48",
  "Industria depurada" = "#2E7D32"
)

scope_linetype <- c(
  "Economía total" = "solid",
  "Industria manufacturera" = "longdash",
  "Industria depurada" = "solid"
)

scope_shape <- c(
  "Economía total" = 16,
  "Industria manufacturera" = 1,
  "Industria depurada" = 16
)

series_palette <- c(
  "Precios básicos" = "#1B4E89",
  "Precios productor" = "#B23A48",
  "Stock capital operativo" = "#1B4E89",
  "Capital circulante adelantado" = "#2E7D32",
  "VAB pp" = "#4D908E",
  "Ganancia pp" = "#6A4C93",
  "Inversión / VAB manufacturero" = "#B23A48",
  "Inversiones a precios constantes" = "#1B4E89"
)

series_linetype <- c(
  "Precios básicos" = "solid",
  "Precios productor" = "longdash"
)

if (!file.exists(workbook_path)) {
  stop("No existe el libro de resultados: ", workbook_path)
}

if (!file.exists(oyanthabal_tg_path)) {
  stop("No existe la base de tasa de ganancia Oyanthabal: ", oyanthabal_tg_path)
}

if (!file.exists(stock_comparison_path)) {
  stop("No existe la base de comparacion de stock EAAE-CIU: ", stock_comparison_path)
}

corrientes <- clean_result_sheet("resultados-corrientes")
constantes <- clean_result_sheet("resultados-constantes")
indices_2005 <- clean_result_sheet("resultados-ind-2005")
oyanthabal_tg <- readr::read_csv(
  oyanthabal_tg_path,
  show_col_types = FALSE
)
stock_comparison <- readr::read_csv(
  stock_comparison_path,
  show_col_types = FALSE
)

three_sections <- c(
  "economia_total",
  "industria-total",
  "industria-sin-papel-coque-refinacion"
)

if (!all(three_sections %in% unique(corrientes$seccion))) {
  stop("Falta al menos uno de los tres niveles requeridos en resultados-corrientes.")
}

three_corrientes <- corrientes %>% filter(seccion %in% three_sections)
three_constantes <- constantes %>% filter(seccion %in% three_sections)
three_indices <- indices_2005 %>% filter(seccion %in% three_sections)

representatividad <- corrientes %>%
  filter(seccion %in% c("economia_total", "industria-total")) %>%
  mutate(
    ambito_key = recode(
      seccion,
      economia_total = "total",
      `industria-total` = "industria"
    )
  ) %>%
  select(anno, ambito_key, vab_pp, vab_bcu_corriente) %>%
  pivot_wider(
    names_from = ambito_key,
    values_from = c(vab_pp, vab_bcu_corriente)
  ) %>%
  transmute(
    anno,
    `Manufactura BCU / VAB total BCU` =
      safe_divide(vab_bcu_corriente_industria, vab_bcu_corriente_total),
    `Manufactura EAAE / VAB total EAAE` =
      safe_divide(vab_pp_industria, vab_pp_total),
    `Manufactura EAAE / manufactura BCU` =
      safe_divide(vab_pp_industria, vab_bcu_corriente_industria)
  ) %>%
  pivot_longer(
    cols = -anno,
    names_to = "indicador",
    values_to = "valor"
  ) %>%
  mutate(
    indicador = factor(
      indicador,
      levels = c(
        "Manufactura BCU / VAB total BCU",
        "Manufactura EAAE / VAB total EAAE",
        "Manufactura EAAE / manufactura BCU"
      )
    )
  )

fig_01 <- ggplot(representatividad, aes(anno, valor)) +
  geom_line(color = "#1B4E89", linewidth = 0.95, na.rm = TRUE) +
  geom_point(color = "#1B4E89", size = 1.6, na.rm = TRUE) +
  facet_wrap(~ indicador, ncol = 1, scales = "free_y") +
  scale_y_continuous(
    labels = percent_format(accuracy = 1),
    expand = expansion(mult = c(0.08, 0.18))
  ) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Representatividad y peso manufacturero: EAAE y BCU",
    subtitle = "Tres lecturas complementarias del peso industrial y la cobertura de la encuesta",
    y = "Porcentaje",
    caption = source_caption
  ) +
  theme_eaae()

representatividad_depurada <- corrientes %>%
  filter(seccion %in% c("industria-total", "industria-sin-papel-coque-refinacion")) %>%
  select(anno, seccion, vab_pp, stock_capital_imputado) %>%
  pivot_wider(
    names_from = seccion,
    values_from = c(vab_pp, stock_capital_imputado)
  ) %>%
  transmute(
    anno,
    `VAB manufactura depurada / VAB manufactura total` =
      safe_divide(
        `vab_pp_industria-sin-papel-coque-refinacion`,
        `vab_pp_industria-total`
      ),
    `Stock manufactura depurada / stock manufactura total` =
      safe_divide(
        `stock_capital_imputado_industria-sin-papel-coque-refinacion`,
        `stock_capital_imputado_industria-total`
      )
  ) %>%
  pivot_longer(
    cols = -anno,
    names_to = "indicador",
    values_to = "valor"
  ) %>%
  mutate(
    indicador = factor(
      indicador,
      levels = c(
        "VAB manufactura depurada / VAB manufactura total",
        "Stock manufactura depurada / stock manufactura total"
      )
    )
  )

fig_01b <- ggplot(representatividad_depurada, aes(anno, valor)) +
  geom_line(color = "#2E7D32", linewidth = 0.95, na.rm = TRUE) +
  geom_point(color = "#2E7D32", size = 1.6, na.rm = TRUE) +
  facet_wrap(~ indicador, ncol = 1, scales = "free_y") +
  scale_y_continuous(
    labels = percent_format(accuracy = 1),
    expand = expansion(mult = c(0.08, 0.16))
  ) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Representatividad de la manufactura depurada",
    subtitle = "Peso de la industria depurada respecto de la manufactura total EAAE",
    y = "Porcentaje",
    caption = source_caption
  ) +
  theme_eaae()

comparacion_tg_oyanthabal <- bind_rows(
  corrientes %>%
    filter(seccion == "economia_total") %>%
    select(anno, tasa_ganancia_pb) %>%
    left_join(oyanthabal_tg, by = c("anno" = "anio")) %>%
    filter(!is.na(tasa_ganancia_pb), !is.na(tg_total_b)) %>%
    transmute(
      anno,
      indicador = "Economía total",
      `EAAE precios básicos` = tasa_ganancia_pb,
      `Oyanthabal total` = tg_total_b
    ) %>%
    pivot_longer(
      cols = c(`EAAE precios básicos`, `Oyanthabal total`),
      names_to = "serie",
      values_to = "valor"
    ),
  corrientes %>%
    filter(seccion == "industria-total") %>%
    select(anno, tasa_ganancia_pb) %>%
    left_join(oyanthabal_tg, by = c("anno" = "anio")) %>%
    filter(!is.na(tasa_ganancia_pb), !is.na(tg_no_agrario_b)) %>%
    transmute(
      anno,
      indicador = "Manufactura",
      `EAAE precios básicos` = tasa_ganancia_pb,
      `Oyanthabal no agrario` = tg_no_agrario_b
    ) %>%
    pivot_longer(
      cols = c(`EAAE precios básicos`, `Oyanthabal no agrario`),
      names_to = "serie",
      values_to = "valor"
    )
) %>%
  filter(!is.na(valor)) %>%
  mutate(
    indicador = factor(
      indicador,
      levels = c("Economía total", "Manufactura")
    )
  )

tg_compare_palette <- c(
  "EAAE precios básicos" = "#1B4E89",
  "Oyanthabal total" = "#6A4C93",
  "Oyanthabal no agrario" = "#6A4C93"
)

tg_compare_linetype <- c(
  "EAAE precios básicos" = "solid",
  "Oyanthabal total" = "longdash",
  "Oyanthabal no agrario" = "longdash"
)

fig_01c <- ggplot(comparacion_tg_oyanthabal, aes(anno, valor, color = serie, linetype = serie)) +
  geom_hline(yintercept = 0, linewidth = 0.3, color = "grey65") +
  geom_line(linewidth = 0.95, na.rm = TRUE) +
  geom_point(size = 1.6, na.rm = TRUE) +
  facet_wrap(~ indicador, ncol = 1, scales = "free_y") +
  scale_color_manual(values = tg_compare_palette) +
  scale_linetype_manual(values = tg_compare_linetype) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  scale_x_continuous(
    breaks = pretty_breaks(n = 8),
    limits = range(comparacion_tg_oyanthabal$anno, na.rm = TRUE)
  ) +
  labs(
    title = "Tasa de ganancia EAAE frente a Oyanthabal",
    subtitle = "Tasas en escala porcentual; EAAE usa precios básicos y Oyanthabal cuentas nacionales",
    y = "Tasa de ganancia",
    caption = "Fuente: Elaboración propia en base a EAAE y Oyanthabal. Índices de precios extraídos de BCU."
  ) +
  theme_eaae()

tasas_ganancia <- three_corrientes %>%
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
    ),
    ambito_label = factor(
      ambito_label,
      levels = c("Economía total", "Industria manufacturera", "Industria depurada")
    )
  )

tasas_ganancia_labels <- label_break_points(
  tasas_ganancia,
  group_cols = c("serie", "ambito_label"),
  value_col = "valor",
  label_accuracy = 1,
  n_changes = 1
)

tasas_ganancia_promedio_industria <- tasas_ganancia %>%
  filter(ambito_label == "Industria manufacturera") %>%
  group_by(serie) %>%
  summarise(promedio = mean(valor, na.rm = TRUE), .groups = "drop")

fig_02 <- ggplot(tasas_ganancia, aes(anno, valor, color = ambito_label)) +
  geom_hline(yintercept = 0, linewidth = 0.25, color = "grey75") +
  geom_hline(
    data = tasas_ganancia_promedio_industria,
    aes(yintercept = promedio),
    inherit.aes = FALSE,
    color = scope_palette[["Industria manufacturera"]],
    linetype = "dotted",
    linewidth = 0.55
  ) +
  geom_line(linewidth = 0.95, na.rm = TRUE) +
  geom_point(size = 1.5, na.rm = TRUE) +
  geom_text(
    data = tasas_ganancia_labels,
    aes(label = etiqueta),
    size = 2.55,
    vjust = -0.75,
    show.legend = FALSE,
    check_overlap = TRUE
  ) +
  facet_wrap(~ serie, ncol = 1) +
  scale_color_manual(values = scope_palette) +
  scale_y_continuous(
    labels = percent_format(accuracy = 1),
    expand = expansion(mult = c(0.08, 0.18))
  ) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Tasa de ganancia en tres niveles",
    subtitle = "La línea punteada marca el promedio de la industria manufacturera en cada panel",
    y = "Porcentaje",
    caption = source_caption
  ) +
  theme_eaae()

fig_03 <- build_decomposition_plot(
  three_corrientes %>% filter(seccion == "economia_total"),
  "Descomposición del VAB: economía total"
)

fig_04 <- build_decomposition_plot(
  three_corrientes %>% filter(seccion == "industria-total"),
  "Descomposición del VAB: industria"
)

capital_resultados_base_2004 <- three_constantes %>%
  select(
    anno,
    seccion,
    ambito_label,
    stock_capital_imputado,
    capital_circulante_adelantado,
    vab_pp,
    ganancia_pp
  ) %>%
  pivot_longer(
    cols = c(
      stock_capital_imputado,
      capital_circulante_adelantado,
      vab_pp,
      ganancia_pp
    ),
    names_to = "serie",
    values_to = "valor"
  ) %>%
  mutate(
    serie = recode(
      serie,
      stock_capital_imputado = "Stock capital operativo",
      capital_circulante_adelantado = "Capital circulante adelantado",
      vab_pp = "VAB pp",
      ganancia_pp = "Ganancia pp"
    )
  ) %>%
  base_index(c("seccion", "serie"), "valor", base_year = 2004) %>%
  filter(!is.na(valor_indice))

fig_05 <- ggplot(
  capital_resultados_base_2004,
  aes(anno, valor_indice, color = serie)
) +
  geom_hline(yintercept = 100, linewidth = 0.25, color = "grey75") +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.35) +
  facet_wrap(
    ~ factor(
      ambito_label,
      levels = c("Economía total", "Industria manufacturera", "Industria depurada")
    ),
    ncol = 1,
    scales = "free_y"
  ) +
  scale_color_manual(values = series_palette) +
  scale_y_continuous(labels = label_number(accuracy = 1, decimal.mark = ",")) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Capital adelantado, VAB y ganancia",
    subtitle = "Variables en precios constantes, expresadas como índice base 2004=100",
    y = "Índice 2004=100",
    caption = source_caption
  ) +
  theme_eaae()

inversion_industrial <- constantes %>%
  filter(seccion %in% c("industria-total", "industria-sin-papel-coque-refinacion")) %>%
  mutate(inversion_vab = safe_divide(fbcf, vab_pp))

inversion_industria_total <- inversion_industrial %>%
  filter(seccion == "industria-total")

paper_investment <- constantes %>%
  filter(seccion == "17_18_papel_impresion") %>%
  select(anno, fbcf_papel = fbcf)

inversion_note_data <- inversion_industria_total %>%
  left_join(paper_investment, by = "anno") %>%
  mutate(papel_pct = safe_divide(fbcf_papel, fbcf)) %>%
  slice_max(inversion_vab, n = 1, with_ties = FALSE)

peak_year <- inversion_note_data$anno[[1]]
paper_share_peak <- inversion_note_data$papel_pct[[1]]
investment_peak <- inversion_note_data$inversion_vab[[1]]
investment_note <- paste0(
  "El máximo de inversión/VAB ocurre en ",
  peak_year,
  "; papel, impresión y reproducción representa ",
  percent(paper_share_peak, accuracy = 0.1),
  " de la FBCF manufacturera constante en ese año."
)

inversion_plot <- bind_rows(
  inversion_industrial %>%
    transmute(
      anno,
      ambito_label,
      indicador = "Inversión / VAB manufacturero",
      valor = inversion_vab * 100
    ),
  inversion_industrial %>%
    transmute(
      anno,
      ambito_label,
      indicador = "Inversiones a precios constantes",
      valor = fbcf / 1e9
    )
)

peak_label <- tibble(
  anno = peak_year,
  ambito_label = "Industria manufacturera",
  indicador = "Inversión / VAB manufacturero",
  valor = investment_peak * 100,
  etiqueta = paste0(peak_year, ": ", percent(investment_peak, accuracy = 1))
)

fig_06 <- ggplot(
  inversion_plot,
  aes(anno, valor, color = ambito_label, linetype = ambito_label, shape = ambito_label)
) +
  geom_line(linewidth = 0.95, na.rm = TRUE) +
  geom_point(size = 1.6, na.rm = TRUE) +
  geom_label(
    data = peak_label,
    aes(anno, valor, label = etiqueta),
    inherit.aes = FALSE,
    nudge_y = 3,
    size = 3,
    color = scope_palette[["Industria manufacturera"]],
    show.legend = FALSE
  ) +
  facet_wrap(~ indicador, ncol = 1, scales = "free_y") +
  scale_color_manual(values = scope_palette) +
  scale_linetype_manual(values = scope_linetype) +
  scale_shape_manual(values = scope_shape) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Inversión manufacturera",
    subtitle = "Comparación entre industria manufacturera total e industria depurada",
    y = "Valor según panel",
    caption = source_caption
  ) +
  theme_eaae()

indices_industria <- indices_2005 %>%
  filter(seccion %in% c("industria-total", "industria-sin-papel-coque-refinacion")) %>%
  select(
    anno,
    ambito_label,
    vab_pp_ind_2005,
    ganancia_pp_ind_2005,
    capital_total_adelantado_ind_2005
  ) %>%
  pivot_longer(
    cols = ends_with("_ind_2005"),
    names_to = "variable",
    values_to = "valor"
  ) %>%
  mutate(
    variable = recode(
      variable,
      vab_pp_ind_2005 = "VAB",
      ganancia_pp_ind_2005 = "Ganancia",
      capital_total_adelantado_ind_2005 = "Capital adelantado"
    ),
    ambito_label = factor(
      ambito_label,
      levels = c("Industria manufacturera", "Industria depurada")
    )
  ) %>%
  filter(!is.na(valor))

fig_07 <- ggplot(indices_industria, aes(anno, valor, color = ambito_label)) +
  geom_hline(yintercept = 1, linewidth = 0.25, color = "grey75") +
  geom_line(linewidth = 0.95) +
  geom_point(size = 1.4) +
  facet_wrap(~ variable, ncol = 1, scales = "free_y") +
  scale_color_manual(values = scope_palette) +
  scale_y_continuous(labels = label_number(accuracy = 0.1, decimal.mark = ",")) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Resultados manufactureros en índices",
    subtitle = "Comparación entre manufactura total y manufactura depurada; base 2005=1",
    y = "Índice 2005=1",
    caption = source_caption
  ) +
  theme_eaae()

productividad <- three_constantes %>%
  transmute(
    anno,
    ambito_label,
    `VAB precios básicos estimado` = safe_divide(vab_pb_estimado, puestos_trabajo),
    `VAB precios productor` = safe_divide(vab_pp, puestos_trabajo)
  ) %>%
  pivot_longer(
    cols = c(`VAB precios básicos estimado`, `VAB precios productor`),
    names_to = "medida",
    values_to = "productividad"
  ) %>%
  group_by(ambito_label, medida) %>%
  mutate(
    base_2005 = productividad[anno == 2005L][1],
    valor = safe_divide(productividad, base_2005)
  ) %>%
  ungroup() %>%
  transmute(
    anno,
    ambito_label = factor(
      ambito_label,
      levels = c("Economía total", "Industria manufacturera", "Industria depurada")
    ),
    medida = factor(
      medida,
      levels = c("VAB precios básicos estimado", "VAB precios productor")
    ),
    valor
  ) %>%
  filter(!is.na(valor))

fig_08 <- ggplot(productividad, aes(anno, valor, color = ambito_label)) +
  geom_hline(yintercept = 1, linewidth = 0.25, color = "grey75") +
  geom_line(linewidth = 0.95) +
  geom_point(size = 1.5) +
  facet_wrap(~ medida, ncol = 1) +
  scale_color_manual(values = scope_palette) +
  scale_y_continuous(labels = label_number(accuracy = 0.1, decimal.mark = ",")) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Productividad del trabajo en índice",
    subtitle = "VAB a precios constantes por puesto de trabajo; comparación entre precios básicos estimados y precios productor",
    y = "Índice 2005=1",
    caption = source_caption
  ) +
  theme_eaae()

ganancias_indice <- indices_2005 %>%
  filter(seccion %in% c("industria-total", "industria-sin-papel-coque-refinacion")) %>%
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
    ),
    ambito_label = factor(
      ambito_label,
      levels = c("Industria manufacturera", "Industria depurada")
    )
  ) %>%
  filter(!is.na(valor))

fig_09 <- ggplot(ganancias_indice, aes(anno, valor, color = ambito_label)) +
  geom_hline(yintercept = 1, linewidth = 0.25, color = "grey75") +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.35) +
  facet_wrap(~ serie, ncol = 1, scales = "free_y") +
  scale_color_manual(values = scope_palette) +
  scale_y_continuous(labels = label_number(accuracy = 0.1, decimal.mark = ",")) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Ganancia industrial en índice de volumen",
    subtitle = "Índices encadenados con base 2005=1, construidos desde resultados en precios de 2005",
    y = "Índice 2005=1",
    caption = source_caption
  ) +
  theme_eaae()

referencia_tasa <- corrientes %>%
  filter(
    seccion %in% c(
      "economia_total",
      "industria-total",
      "industria-sin-papel-coque-refinacion",
      "19_refinacion",
      "17_18_papel_impresion"
    )
  ) %>%
  select(anno, seccion, tasa_ganancia_pb, tasa_ganancia_pp) %>%
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
    ),
    ambito_label = case_when(
      seccion == "economia_total" ~ "Economía total",
      seccion == "industria-total" ~ "Industria manufacturera total",
      seccion == "industria-sin-papel-coque-refinacion" ~
        "Industria manufacturera depurada",
      seccion == "19_refinacion" ~ "Coque y refinación de petróleo",
      seccion == "17_18_papel_impresion" ~ "Papel impresión y reproducción",
      TRUE ~ seccion
    ),
    ambito_label = factor(
      ambito_label,
      levels = c(
        "Economía total",
        "Industria manufacturera total",
        "Industria manufacturera depurada",
        "Coque y refinación de petróleo",
        "Papel impresión y reproducción"
      )
    )
  ) %>%
  filter(!is.na(valor))

referencia_tasa_labels <- label_break_points(
  referencia_tasa,
  group_cols = c("ambito_label", "serie"),
  value_col = "valor",
  label_accuracy = 1,
  n_changes = 1
)

fig_10 <- ggplot(referencia_tasa, aes(anno, valor, color = serie, linetype = serie)) +
  geom_hline(yintercept = 0, linewidth = 0.25, color = "grey75") +
  geom_line(linewidth = 0.85, na.rm = TRUE) +
  geom_point(size = 1.3, na.rm = TRUE) +
  geom_text(
    data = referencia_tasa_labels,
    aes(anno, valor, label = etiqueta, color = serie),
    inherit.aes = FALSE,
    size = 2.45,
    vjust = -0.7,
    show.legend = FALSE,
    check_overlap = TRUE
  ) +
  facet_wrap(~ ambito_label, ncol = 1, scales = "free_y") +
  scale_color_manual(values = series_palette) +
  scale_linetype_manual(values = series_linetype) +
  scale_y_continuous(
    labels = percent_format(accuracy = 1),
    expand = expansion(mult = c(0.08, 0.18))
  ) +
  scale_x_continuous(breaks = pretty_breaks(n = 7)) +
  labs(
    title = "Tasa de ganancia a diferentes niveles de desagregación: exploración inicial",
    subtitle = "Ganancia a precios básicos y productor sobre capital total adelantado, en valores corrientes",
    y = "Porcentaje",
    caption = source_caption
  ) +
  theme_eaae()

figure_files <- c(
  "01_representatividad_peso_manufacturero.png",
  "01b_representatividad_manufactura_depurada.png",
  "01c_comparacion_tasa_ganancia_oyanthabal.png",
  "02_tasa_ganancia_tres_niveles.png",
  "03_descomposicion_vab_total_corrientes.png",
  "04_descomposicion_vab_industria_corrientes.png",
  "05_capital_vab_ganancia_base_2004.png",
  "06_inversion_manufacturera.png",
  "07_indices_industria_depurada.png",
  "08_productividad_tres_niveles.png",
  "09_ganancia_indice_2005.png",
  "10_tasa_ganancia_niveles_desagregacion.png"
)

figures <- c(
  save_plot(fig_01, figure_files[[1]], width = 10, height = 7),
  save_plot(fig_01b, figure_files[[2]], width = 10, height = 6),
  save_plot(fig_01c, figure_files[[3]], width = 10, height = 6),
  save_plot(fig_02, figure_files[[4]], width = 10, height = 7),
  save_plot(fig_03, figure_files[[5]], width = 10.5, height = 6),
  save_plot(fig_04, figure_files[[6]], width = 10.5, height = 6),
  save_plot(fig_05, figure_files[[7]], width = 11, height = 8),
  save_plot(fig_06, figure_files[[8]], width = 10, height = 7),
  save_plot(fig_07, figure_files[[9]], width = 10, height = 8),
  save_plot(fig_08, figure_files[[10]], width = 10, height = 7),
  save_plot(fig_09, figure_files[[11]], width = 10, height = 7),
  save_plot(fig_10, figure_files[[12]], width = 12, height = 13)
)

stock_table <- stock_comparison %>%
  transmute(
    `año` = as.character(anno),
    `CIU USD corr.` = format_one_decimal(stock_ciu_mill_usd_corriente),
    `CIU ind.` = format_one_decimal(stock_ciu_indice_dic_2008_100),
    `EAAE USD corr.` =
      format_one_decimal(stock_eaae_maquinaria_equipos_sin_refinacion_mill_usd_corriente),
    `EAAE USD const. proxy` =
      format_one_decimal(stock_eaae_maquinaria_equipos_sin_refinacion_mill_usd_constante_2005_proxy),
    `EAAE ind.` =
      format_one_decimal(stock_eaae_maquinaria_equipos_sin_refinacion_indice_2008_100),
    `EAAE/CIU USD %` =
      format_one_decimal(ratio_eaae_ciu_stock_usd_corriente_pct)
  ) %>%
  markdown_table()

report_lines <- c(
  "# Resultados EAAE-BCU: tasa de ganancia en tres niveles",
  "",
  paste0("Fuente de datos: `", workbook_path, "`."),
  "",
  "Esta minuta actualiza el informe `docs/20260706_resultados_eaae_bcu_total_industria_subrama.md` incorporando un tercer nivel agregado: industria manufacturera depurada de `17_18_papel_impresion` y `19_refinacion`. La tasa de ganancia de ese nivel se calcula desde sumas agregadas de ganancia y capital adelantado, no como promedio de tasas subramales.",
  "",
  "## Criterios de lectura",
  "",
  "- Todos los resultados construidos provienen de la EAAE. Se usan índices de precios del BCU para deflactar valores corrientes.",
  "- Los tres niveles agregados son `economia_total`, `industria-total` e `industria-sin-papel-coque-refinacion`.",
  paste0("- El libro `", basename(workbook_path), "` recalcula capital adelantado y tasas de ganancia con la rotación operativa vigente, actualizada desde la revisión Mussi de microdatos EAAE."),
  "- Las tasas de ganancia se muestran a precios básicos y a precios productor.",
  "- Las descomposiciones del VAB usan valores corrientes para conservar cobertura anual completa.",
  "- Las comparaciones de volumen usan resultados deflactados con índices BCU empalmados a base 2005=1.",
  "- Todos los `deflactor_2005` quedan normalizados con valor 1 en 2005, incluyendo el agregado de industria depurada construido desde subramas.",
  "- La manufactura depurada excluye el grupo papel/impresión/reproducción y coque/refinación de petróleo; por la homologación disponible no separa papel de impresión.",
  "",
  "## Resultados agregados",
  "",
  "### 1. Representatividad y peso manufacturero",
  "",
  "La primera lectura compara el peso de la manufactura en BCU, el peso de la manufactura en EAAE y la cobertura de la manufactura EAAE respecto de la manufactura BCU. Se presentan como paneles separados para evitar mezclar lecturas de composición y representatividad.",
  "Puede observarse cómo el peso de la manufactura está sobre representado en la EAAE (panel 1 vs panel 2) mientras que en general esta fuente representa entre el 80% y 90% del VAB reportado a nivel de cuentas nacionales, a lo largo de todo el período.",
  "",
  fig_md("Representatividad y peso manufacturero", figure_files[[1]]),
  "",
  "La segunda lectura compara el peso de la manufactura depurada dentro de la manufactura total, usando tanto el VAB como el stock de capital operativo. Esta depuración permite dimensionar el peso de los grupos excluidos antes de interpretar las tasas de ganancia.",
  "",
  fig_md("Representatividad de la manufactura depurada", figure_files[[2]]),
  "",
  "A continuación se presenta una comparación entre la tasa de ganancia calculada a partir de EAAE y aquella calculada a partir de cuentas nacionales por Gabriel Oyanthabal. Las tasas se muestran en escala porcentual, sin dividir una serie por la otra, con el fin de complementar la evaluación de representatividad de los cálculos hechos a partir de EAAE.",
  "",
  fig_md("Tasa de ganancia EAAE frente a Oyanthabal", figure_files[[3]]),
  "",
  "### 2. Tasa de ganancia",
  "",
  "La comparación principal incorpora tres niveles: economía total, manufactura total y manufactura depurada. La línea punteada marca, en cada panel, el promedio temporal de la industria manufacturera total. La manufactura depurada permite observar cuánto cambia la trayectoria al retirar los grupos con comportamiento más singular dentro de la rama industrial.",
  "",
  fig_md("Tasa de ganancia en tres niveles", figure_files[[4]]),
  "",
  "### 3. Descomposición del VAB: economía total",
  "",
  "La descomposición distribuye el VAB a precios productor entre costo laboral, consumo de capital fijo y ganancia a precios productor. Las etiquetas marcan años extremos, años de referencia y el último punto disponible.",
  "",
  fig_md("Descomposición del VAB total", figure_files[[5]]),
  "",
  "### 4. Descomposición del VAB: industria",
  "",
  "La misma descomposición se replica para la manufactura agregada. Esta figura ayuda a distinguir si los cambios de tasa de ganancia provienen de la ganancia, del costo laboral o del consumo de capital fijo.",
  "",
  fig_md("Descomposición del VAB industrial", figure_files[[6]]),
  "",
  "### 5. Capital adelantado, VAB y ganancia",
  "",
  "Este gráfico deja las variables en base 100 en 2004. Se excluye el capital total adelantado para evitar duplicar sus componentes y se agregan VAB y ganancia a precios constantes como referencia de desempeño.",
  "",
  fig_md("Capital adelantado, VAB y ganancia", figure_files[[7]]),
  "",
  "### 6. Inversión manufacturera",
  "",
  "La inversión manufacturera se separa en dos paneles y en cada uno se diferencia entre industria manufacturera total e industria depurada. Esto permite revisar si la depuración cambia la lectura del esfuerzo inversor.",
  "",
  "En el primer panel la industria depurada está incorporada, pero queda prácticamente superpuesta con la manufactura total porque la FBCF subramal se distribuye proporcionalmente al VAB; por eso el cociente FBCF/VAB es casi idéntico para ambos agregados. Para facilitar la lectura, la manufactura total se muestra con línea punteada y punto hueco.",
  "",
  investment_note,
  "",
  fig_md("Inversión manufacturera", figure_files[[8]]),
  "",
  "### 7. Resultados manufactureros en índices",
  "",
  "La comparación se focaliza en manufactura total y manufactura depurada para VAB, ganancia y capital adelantado. Esto permite evaluar si la depuración cambia sólo niveles o también la dinámica relativa.",
  "",
  fig_md("Resultados manufactureros en índices", figure_files[[9]]),
  "",
  "### 8. Productividad del trabajo",
  "",
  "La productividad se calcula como VAB a precios constantes por puesto de trabajo. Se muestran dos paneles comparables: uno usa VAB a precios básicos estimado y el otro VAB a precios productor. En ambos casos se mantienen las tres líneas agregadas para comparar economía total, manufactura total y manufactura depurada.",
  "",
  fig_md("Productividad del trabajo", figure_files[[10]]),
  "",
  "## Anexos",
  "",
  "### 9. Ganancia industrial en índice de volumen",
  "",
  "Se desplaza esta figura al anexo porque funciona como síntesis de la dinámica real de la ganancia industrial, luego de revisar composición, capital adelantado, inversión y productividad.",
  "",
  fig_md("Ganancia industrial en índice de volumen", figure_files[[11]]),
  "",
  "### 10. Tasa de ganancia a diferentes niveles de desagregación: exploración inicial",
  "",
  "Referencia por subrama: se comparan economía total, industria manufacturera total, industria manufacturera depurada y los dos grupos excluidos de la depuración. La figura muestra tasas a precios básicos y a precios productor, con etiquetas en puntos de quiebre relevantes.",
  "",
  "En el panel de papel, impresión y reproducción, la serie a precios básicos también está incluida. Su trayectoria se superpone casi exactamente con la de precios productor, por lo que el gráfico distingue ambas mediante tipo de línea: precios básicos en línea continua y precios productor en línea punteada.",
  "",
  fig_md("Tasa de ganancia a diferentes niveles de desagregación", figure_files[[12]]),
  "",
  "### 11. Comparación del stock de capital industrial EAAE-CIU",
  "",
  "La comparación toma como referencia el stock de capital fijo en maquinaria y equipos de la industria publicado por CIU, cuya cobertura excluye refinería ANCAP y empresas de zonas francas. Para aproximar una frontera comparable desde EAAE, se extrae directamente la columna de maquinaria y equipos de los cuadros originales de activos fijos y se resta la maquinaria y equipos de la actividad de refinación (`23` en CIIU Rev.3 y `19_refinacion` en CIIU Rev.4). No se utiliza la operación `stock total - construcciones`, porque esa alternativa conservaría dentro del agregado otros activos e intangibles. La serie EAAE en pesos corrientes se convierte a dólares con el tipo de cambio venta de INE-BROU correspondiente al último valor disponible de diciembre de cada año. Luego se deflacta con un proxy BCU construido como deflactor implícito del VAB de subramas industriales excluyendo refinación, base 2005=1, y se expresa como índice 2008=100. El equipo debe leer esta deflactación como aproximación sectorial, no como deflactor específico de bienes de capital. Los años 2002 y 2011 quedan sin dato EAAE porque no existe cuadro de activos fijos por tipo y no se imputa la composición maquinaria/equipos para este ejercicio.",
  "",
  stock_table,
  "",
  "## Reproducción",
  "",
  "Desde la raíz del repositorio:",
  "",
  "```bash",
  "Rscript command-files/analysis-command-files/06_visualizar_resultados_eaae_bcu_tres_niveles.R",
  "```"
)

writeLines(report_lines, report_path, useBytes = TRUE)

message("Informe escrito en ", report_path)
message("Figuras escritas en ", fig_dir, ":")
for (figure_path in figures) {
  message(" - ", figure_path)
}
