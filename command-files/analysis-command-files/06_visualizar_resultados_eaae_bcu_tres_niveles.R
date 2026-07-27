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
report_date <- Sys.getenv("EAAE_REPORT_DATE", unset = "20260727")
workbook_date <- Sys.getenv("EAAE_WORKBOOK_DATE", unset = "20260727")

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
      caption = "Fuente: elaboración propia con panel integrado EAAE-BCU."
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

if (!file.exists(workbook_path)) {
  stop("No existe el libro de resultados: ", workbook_path)
}

corrientes <- clean_result_sheet("resultados-corrientes")
constantes <- clean_result_sheet("resultados-constantes")
indices_2005 <- clean_result_sheet("resultados-ind-2005")

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
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Representatividad y peso manufacturero: EAAE y BCU",
    subtitle = "Tres lecturas complementarias del peso industrial y la cobertura de la encuesta",
    y = "Porcentaje",
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU."
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

fig_02 <- ggplot(tasas_ganancia, aes(anno, valor, color = ambito_label)) +
  geom_hline(yintercept = 0, linewidth = 0.25, color = "grey75") +
  geom_line(linewidth = 0.95, na.rm = TRUE) +
  geom_point(size = 1.5, na.rm = TRUE) +
  facet_wrap(~ serie, ncol = 1) +
  scale_color_manual(values = scope_palette) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Tasa de ganancia en tres niveles",
    subtitle = "Economía total, industria manufacturera agregada e industria depurada de papel/impresión y coque/refinación",
    y = "Porcentaje",
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU."
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
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU y deflactores BCU."
  ) +
  theme_eaae()

inversion_industrial <- constantes %>%
  filter(seccion == "industria-total") %>%
  mutate(inversion_vab = safe_divide(fbcf, vab_pp))

paper_investment <- constantes %>%
  filter(seccion == "17_18_papel_impresion") %>%
  select(anno, fbcf_papel = fbcf)

inversion_note_data <- inversion_industrial %>%
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
      indicador = "Inversión / VAB manufacturero",
      valor = inversion_vab * 100
    ),
  inversion_industrial %>%
    transmute(
      anno,
      indicador = "Inversiones a precios constantes",
      valor = fbcf / 1e9
    )
)

peak_label <- tibble(
  anno = peak_year,
  indicador = "Inversión / VAB manufacturero",
  valor = investment_peak * 100,
  etiqueta = paste0(peak_year, ": ", percent(investment_peak, accuracy = 1))
)

fig_06 <- ggplot(inversion_plot, aes(anno, valor, color = indicador)) +
  geom_line(linewidth = 0.95, na.rm = TRUE) +
  geom_point(size = 1.6, na.rm = TRUE) +
  geom_label(
    data = peak_label,
    aes(label = etiqueta),
    nudge_y = 0.04,
    size = 3,
    show.legend = FALSE
  ) +
  facet_wrap(~ indicador, ncol = 1, scales = "free_y") +
  scale_color_manual(values = series_palette) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Inversión manufacturera",
    subtitle = "Panel superior: porcentaje del VAB manufacturero. Panel inferior: FBCF en miles de millones de pesos de 2005",
    y = "Valor según panel",
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU y deflactores BCU."
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
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU y deflactores BCU."
  ) +
  theme_eaae()

productividad <- three_indices %>%
  select(anno, ambito_label, productividad_trabajo_ind_2005) %>%
  transmute(
    anno,
    ambito_label = factor(
      ambito_label,
      levels = c("Economía total", "Industria manufacturera", "Industria depurada")
    ),
    valor = productividad_trabajo_ind_2005
  ) %>%
  filter(!is.na(valor))

fig_08 <- ggplot(productividad, aes(anno, valor, color = ambito_label)) +
  geom_hline(yintercept = 1, linewidth = 0.25, color = "grey75") +
  geom_line(linewidth = 0.95) +
  geom_point(size = 1.5) +
  scale_color_manual(values = scope_palette) +
  scale_y_continuous(labels = label_number(accuracy = 0.1, decimal.mark = ",")) +
  scale_x_continuous(breaks = pretty_breaks(n = 8)) +
  labs(
    title = "Productividad del trabajo en índice",
    subtitle = "VAB a precios constantes por puesto de trabajo; base 2005=1",
    y = "Índice 2005=1",
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU y deflactores BCU."
  ) +
  theme_eaae()

ganancias_indice <- three_indices %>%
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
      levels = c("Economía total", "Industria manufacturera", "Industria depurada")
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
    title = "Ganancia en índice de volumen",
    subtitle = "Índices encadenados con base 2005=1, construidos desde resultados en precios de 2005",
    y = "Índice 2005=1",
    caption = "Fuente: elaboración propia con panel integrado EAAE-BCU y deflactores BCU."
  ) +
  theme_eaae()

subrama_tasa <- corrientes %>%
  filter(nivel_panel == "subrama_industrial", !is.na(tasa_ganancia_pp)) %>%
  mutate(
    subrama_label = vapply(
      descripcion_nivel,
      function(value) paste(strwrap(value, width = 28), collapse = "\n"),
      character(1)
    )
  )

fig_10 <- ggplot(subrama_tasa, aes(anno, tasa_ganancia_pp)) +
  geom_hline(yintercept = 0, linewidth = 0.25, color = "grey75") +
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

figure_files <- c(
  "01_representatividad_peso_manufacturero.png",
  "02_tasa_ganancia_tres_niveles.png",
  "03_descomposicion_vab_total_corrientes.png",
  "04_descomposicion_vab_industria_corrientes.png",
  "05_capital_vab_ganancia_base_2004.png",
  "06_inversion_manufacturera.png",
  "07_indices_industria_depurada.png",
  "08_productividad_tres_niveles.png",
  "09_ganancia_indice_2005.png",
  "10_tasa_ganancia_subramas_corrientes.png"
)

figures <- c(
  save_plot(fig_01, figure_files[[1]], width = 10, height = 7),
  save_plot(fig_02, figure_files[[2]], width = 10, height = 7),
  save_plot(fig_03, figure_files[[3]], width = 10.5, height = 6),
  save_plot(fig_04, figure_files[[4]], width = 10.5, height = 6),
  save_plot(fig_05, figure_files[[5]], width = 11, height = 8),
  save_plot(fig_06, figure_files[[6]], width = 10, height = 7),
  save_plot(fig_07, figure_files[[7]], width = 10, height = 8),
  save_plot(fig_08, figure_files[[8]], width = 10, height = 6),
  save_plot(fig_09, figure_files[[9]], width = 10, height = 7),
  save_plot(fig_10, figure_files[[10]], width = 12, height = 12)
)

report_lines <- c(
  "# Resultados EAAE-BCU: tasa de ganancia en tres niveles",
  "",
  paste0("Fuente de datos: `", workbook_path, "`."),
  "",
  "Esta minuta actualiza el informe `docs/20260706_resultados_eaae_bcu_total_industria_subrama.md` incorporando un tercer nivel agregado: industria manufacturera depurada de `17_18_papel_impresion` y `19_refinacion`. La tasa de ganancia de ese nivel se calcula desde sumas agregadas de ganancia y capital adelantado, no como promedio de tasas subramales.",
  "",
  "## Criterios de lectura",
  "",
  "- Los tres niveles agregados son `economia_total`, `industria-total` e `industria-sin-papel-coque-refinacion`.",
  "- Las tasas de ganancia se muestran a precios básicos y a precios productor.",
  "- Las descomposiciones del VAB usan valores corrientes para conservar cobertura anual completa.",
  "- Las comparaciones de volumen usan resultados deflactados con índices BCU empalmados a base 2005=1.",
  "- La manufactura depurada excluye el grupo papel/impresión/reproducción y coque/refinación de petróleo; por la homologación disponible no separa papel de impresión.",
  "",
  "## Resultados agregados",
  "",
  "### 1. Representatividad y peso manufacturero",
  "",
  "La primera lectura compara el peso de la manufactura en BCU, el peso de la manufactura en EAAE y la cobertura de la manufactura EAAE respecto de la manufactura BCU. Se presentan como paneles separados para evitar mezclar lecturas de composición y representatividad.",
  "",
  fig_md("Representatividad y peso manufacturero", figure_files[[1]]),
  "",
  "### 2. Tasa de ganancia",
  "",
  "La comparación principal incorpora tres niveles: economía total, manufactura total y manufactura depurada. La manufactura depurada permite observar cuánto cambia la trayectoria al retirar los grupos con comportamiento más singular dentro de la rama industrial.",
  "",
  fig_md("Tasa de ganancia en tres niveles", figure_files[[2]]),
  "",
  "### 3. Descomposición del VAB: economía total",
  "",
  "La descomposición distribuye el VAB a precios productor entre costo laboral, consumo de capital fijo y ganancia a precios productor. Las etiquetas marcan años extremos, años de referencia y el último punto disponible.",
  "",
  fig_md("Descomposición del VAB total", figure_files[[3]]),
  "",
  "### 4. Descomposición del VAB: industria",
  "",
  "La misma descomposición se replica para la manufactura agregada. Esta figura ayuda a distinguir si los cambios de tasa de ganancia provienen de la ganancia, del costo laboral o del consumo de capital fijo.",
  "",
  fig_md("Descomposición del VAB industrial", figure_files[[4]]),
  "",
  "### 5. Capital adelantado, VAB y ganancia",
  "",
  "Este gráfico deja las variables en base 100 en 2004. Se excluye el capital total adelantado para evitar duplicar sus componentes y se agregan VAB y ganancia a precios constantes como referencia de desempeño.",
  "",
  fig_md("Capital adelantado, VAB y ganancia", figure_files[[5]]),
  "",
  "### 6. Inversión manufacturera",
  "",
  "La inversión manufacturera se separa en dos paneles para que el pico de inversión sobre VAB no quede oculto por la escala de la FBCF constante.",
  "",
  investment_note,
  "",
  fig_md("Inversión manufacturera", figure_files[[6]]),
  "",
  "### 7. Resultados manufactureros en índices",
  "",
  "La comparación se focaliza en manufactura total y manufactura depurada para VAB, ganancia y capital adelantado. Esto permite evaluar si la depuración cambia sólo niveles o también la dinámica relativa.",
  "",
  fig_md("Resultados manufactureros en índices", figure_files[[7]]),
  "",
  "### 8. Productividad del trabajo",
  "",
  "La productividad se calcula como VAB a precios constantes por puesto de trabajo. Se mantienen las tres líneas agregadas para comparar economía total, manufactura total y manufactura depurada.",
  "",
  fig_md("Productividad del trabajo", figure_files[[8]]),
  "",
  "### 9. Ganancia en índice de volumen",
  "",
  "Se desplaza esta figura hacia el cierre de la sección agregada porque funciona mejor como síntesis de la dinámica real de la ganancia una vez revisados composición, capital adelantado, inversión y productividad.",
  "",
  fig_md("Ganancia en índice de volumen", figure_files[[9]]),
  "",
  "## Referencia por subrama",
  "",
  "La lectura por subrama se conserva como referencia para interpretar la heterogeneidad interna de la manufactura. La tasa se muestra a precios productor.",
  "",
  fig_md("Tasa de ganancia por subrama industrial", figure_files[[10]]),
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
