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
figures_dir <- file.path("output", "figures", paste0("devaluacion_escenarios_integrados_", date_prefix))

latest_file <- function(pattern) {
  files <- Sys.glob(pattern)
  if (length(files) == 0) {
    stop("No files found for pattern: ", pattern)
  }
  sort(files)[[length(files)]]
}

safe_pct_ratio <- function(numerator, denominator) {
  ifelse(
    is.na(numerator) | is.na(denominator) | denominator == 0,
    NA_real_,
    numerator / denominator * 100
  )
}

fmt_num <- function(x, digits = 1) {
  ifelse(
    is.na(x),
    "",
    trimws(format(round(x, digits), big.mark = ".", decimal.mark = ","))
  )
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

md_table <- function(data) {
  data <- as.data.frame(data, stringsAsFactors = FALSE)
  if (ncol(data) == 0 || nrow(data) == 0) {
    return("")
  }
  data[] <- lapply(data, function(col_i) {
    col_i <- as.character(col_i)
    col_i <- str_replace_all(col_i, "\\|", "\\\\|")
    str_replace_all(col_i, "[\r\n]+", " ")
  })

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

dated_xlsx <- file.path(
  analysis_dir,
  paste0(date_prefix, "_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx")
)
input_xlsx <- if (file.exists(dated_xlsx)) {
  dated_xlsx
} else {
  latest_file(file.path(analysis_dir, "*_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx"))
}

coeficientes_path <- latest_file(file.path(
  "data",
  "input-data",
  "mussi",
  "*-coeficientes-efecto-devaluacion.csv"
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
  "Escenario 1 - Comercio Exterior",
  paste(
    "La apropiación de riqueza vía sobrevaluación de la moneda se aplica a",
    "los componentes importados de costos y capital y a la parte exportada de",
    "la producción. Por tanto, recoge el efecto directo de importaciones y",
    "exportaciones sobre la masa de ganancia."
  ),
  "VBP/exportador",
  "Escenario 2 - Bienes Transables",
  "bienes_transables",
  "Escenario 2 - Bienes Transables",
  paste(
    "La apropiación de riqueza vía sobrevaluación alcanza al conjunto de",
    "mercancías cuyos precios internos se rigen por precios internacionales,",
    "aunque sean producidas localmente y vendidas en el mercado interno.",
    "Así, incorpora la revaluación de producción local transable y su efecto",
    "sobre la masa de ganancia."
  ),
  "VBP/transable"
)

section_labels <- c(
  "industria-total" = "Industria total",
  "exportadora" = "Segmento exportador",
  "mercado-interno" = "Mercado interno"
)

ramas_exportadoras <- c(
  "10: Elaboración de productos alimenticios",
  "11 y 12: Elaboración de bebidas y elaboración de productos de tabaco",
  "13: Fabricación de productos textiles",
  "15: Fabricación de cueros y productos conexos",
  "16: Producción de madera y fabricación de productos de madera y corcho, excepto muebles",
  "17: Fabricación de papel y de los productos de papel",
  "22: Fabricación de productos de caucho y plástico"
)

ramas_mercado_interno <- c(
  "14: Fabricación de prendas de vestir",
  "18: Actividades de impresión y reproducción de grabaciones",
  "20: Fabricación de sustancias y productos químicos",
  "21: Fabricación de productos farmacéuticos, sustancias químicas medicinales y de productos botánicos",
  "23: Fabricación de otros productos minerales no metálicos",
  "24: Fabricación de metales comunes",
  "25: Fabricación de productos derivados del metal, excepto maquinaria y equipo",
  "26 y 27: Fabricación de productos informáticos, electrónicos y ópticos; fabricación de equipo eléctrico",
  "28: Fabricación de maquinaria y equipo n.c.p",
  "29 y 30: Fabricación de vehículos automotores, remolques y semirremolques; fabricación de otros tipos de equipo de transporte",
  "31: Fabricación de muebles",
  "32: Otras industrias manufactureras",
  "33: Reparación e instalación de la maquinaria y equipo"
)

blue_palette <- c(
  navy = "#0B1F3A",
  deep = "#173B63",
  main = "#2F5F8F",
  steel = "#5F86AD",
  soft = "#9DB8D2",
  pale = "#DCE8F3",
  grey = "#6C7785",
  grid = "#D9E1E8"
)

section_colors <- c(
  "Industria total" = blue_palette[["navy"]],
  "Segmento exportador" = blue_palette[["main"]],
  "Mercado interno" = blue_palette[["steel"]]
)

component_colors <- c(
  "Apropiación/ahorro" = blue_palette[["deep"]],
  "Cesión/menor valorización" = blue_palette[["soft"]]
)

caption_fuente <- paste(
  "Fuente: elaboración propia en base a EAAE, microdatos CIU y Oyanthabal,",
  "con base en metodología de Iñigo Carrera (2007)."
)

theme_report <- theme_minimal(base_size = 11) +
  theme(
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA),
    panel.grid.major = element_line(color = blue_palette[["grid"]], linewidth = 0.28),
    panel.grid.minor = element_blank(),
    plot.title.position = "plot",
    plot.title = element_text(color = blue_palette[["navy"]], face = "bold", size = 13),
    plot.subtitle = element_text(color = blue_palette[["grey"]], size = 10.5),
    plot.caption = element_text(color = blue_palette[["grey"]], size = 8.5, hjust = 0),
    plot.caption.position = "plot",
    axis.title = element_text(color = blue_palette[["grey"]], size = 9.5),
    axis.text = element_text(color = blue_palette[["navy"]], size = 9),
    strip.text = element_text(color = blue_palette[["navy"]], face = "bold"),
    legend.position = "bottom",
    legend.title = element_text(color = blue_palette[["grey"]], size = 9),
    legend.text = element_text(color = blue_palette[["navy"]], size = 9)
  )

required_sheets <- c("escenario-inicial", "tipo-cambio", scenario_specs$sheet)
missing_sheets <- setdiff(required_sheets, excel_sheets(input_xlsx))
if (length(missing_sheets) > 0) {
  stop("Missing sheets in workbook: ", paste(missing_sheets, collapse = ", "))
}

required_scenario_cols <- c(
  "anno",
  "seccion",
  "descripcion_nivel",
  "tipo_cambio_comercial_pesos_usd",
  "tipo_cambio_paridad_pesos_usd",
  "factor_devaluacion",
  "ganancia_pb",
  "ganancia_pb_devaluacion",
  "delta_vbp_pp",
  "delta_consumo_intermedio_estimado",
  "delta_remuneraciones",
  "delta_consumo_capital_fijo",
  "incidencia_vbp_pp",
  "incidencia_consumo_intermedio_estimado",
  "incidencia_remuneraciones",
  "incidencia_consumo_capital_fijo"
)

check_no_rate_cols <- function(data, sheet) {
  rate_cols <- grep("(^tasa_|variacion_tasa)", names(data), value = TRUE)
  if (length(rate_cols) > 0) {
    stop("Rate columns should not be present in ", sheet, ": ", paste(rate_cols, collapse = ", "))
  }
}

read_scenario <- function(sheet_name) {
  data <- read_excel(input_xlsx, sheet = sheet_name)
  missing_cols <- setdiff(required_scenario_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Missing columns in ", sheet_name, ": ", paste(missing_cols, collapse = ", "))
  }
  check_no_rate_cols(data, sheet_name)

  spec <- scenario_specs %>%
    filter(.data$sheet == !!sheet_name)

  data <- data %>%
    filter(!is.na(.data$anno), !is.na(.data$seccion)) %>%
    mutate(
      # DECISION: the 2026-08-31 minute focuses on mass of profit. VBP is
      # plotted with negative sign; cost deltas are positive. This exactly
      # matches the updated ganancia_pb_devaluacion formula in the XLSX flow.
      delta_total_ganancia_pb =
        -.data$delta_vbp_pp +
        .data$delta_consumo_intermedio_estimado +
        .data$delta_remuneraciones +
        .data$delta_consumo_capital_fijo,
      delta_total_ganancia_pb_pct =
        safe_pct_ratio(.data$delta_total_ganancia_pb, .data$ganancia_pb),
      ganancia_pb_devaluacion_calc =
        .data$ganancia_pb + .data$delta_total_ganancia_pb,
      seccion_label = recode(.data$seccion, !!!section_labels),
      seccion_label = factor(.data$seccion_label, levels = unname(section_labels)),
      escenario = spec$escenario,
      escenario_label = spec$titulo,
      escenario_sheet = spec$sheet,
      descripcion_escenario = spec$descripcion,
      vbp_label = spec$vbp_label
    )

  formula_diff <- max(
    abs(data$ganancia_pb_devaluacion - data$ganancia_pb_devaluacion_calc),
    na.rm = TRUE
  )
  if (is.na(formula_diff) || formula_diff > 1e-2) {
    stop("ganancia_pb_devaluacion no cierra en ", sheet_name, ". Max error: ", formula_diff)
  }

  data
}

escenario_inicial <- read_excel(input_xlsx, sheet = "escenario-inicial")
check_no_rate_cols(escenario_inicial, "escenario-inicial")

tipo_cambio <- read_excel(input_xlsx, sheet = "tipo-cambio")
coeficientes <- read_csv(coeficientes_path, show_col_types = FALSE)
escenarios <- bind_rows(lapply(scenario_specs$sheet, read_scenario))

if (nrow(escenarios) != 30L) {
  stop("Se esperaban 30 filas de escenarios: 2 escenarios x 5 años x 3 secciones.")
}

if (any(is.na(escenarios$delta_total_ganancia_pb_pct))) {
  stop("Hay faltantes en el delta total sobre ganancia inicial.")
}

factor_table <- tipo_cambio %>%
  transmute(
    `Año` = .data$anio,
    `Tipo de cambio comercial` = fmt_num(.data$tipo_cambio_comercial_pesos_usd, 2),
    `Tipo de cambio paridad` = fmt_num(.data$tipo_cambio_paridad_pesos_usd, 2),
    `Factor de devaluación` = fmt_pct(
      ((.data$tipo_cambio_paridad_pesos_usd / .data$tipo_cambio_comercial_pesos_usd) - 1) * 100,
      1
    )
  )

factor_summary <- tipo_cambio %>%
  summarise(
    promedio = mean((.data$tipo_cambio_paridad_pesos_usd / .data$tipo_cambio_comercial_pesos_usd) - 1, na.rm = TRUE),
    minimo = min((.data$tipo_cambio_paridad_pesos_usd / .data$tipo_cambio_comercial_pesos_usd) - 1, na.rm = TRUE),
    maximo = max((.data$tipo_cambio_paridad_pesos_usd / .data$tipo_cambio_comercial_pesos_usd) - 1, na.rm = TRUE)
  )

factor_plot_data <- tipo_cambio %>%
  transmute(
    anio = .data$anio,
    factor_devaluacion_pct =
      ((.data$tipo_cambio_paridad_pesos_usd / .data$tipo_cambio_comercial_pesos_usd) - 1) * 100
  )

coeficientes_plot_data <- escenarios %>%
  distinct(
    .data$escenario_label,
    .data$seccion_label,
    .data$incidencia_vbp_pp,
    .data$incidencia_consumo_intermedio_estimado,
    .data$incidencia_remuneraciones,
    .data$incidencia_consumo_capital_fijo
  ) %>%
  pivot_longer(
    cols = starts_with("incidencia_"),
    names_to = "variable_codigo",
    values_to = "incidencia"
  ) %>%
  mutate(
    variable = recode(
      .data$variable_codigo,
      incidencia_vbp_pp = "VBP",
      incidencia_consumo_intermedio_estimado = "Consumo intermedio",
      incidencia_remuneraciones = "Masa salarial",
      incidencia_consumo_capital_fijo = "Consumo capital fijo"
    ),
    variable = factor(
      .data$variable,
      levels = c("VBP", "Consumo intermedio", "Masa salarial", "Consumo capital fijo")
    ),
    incidencia_pct = .data$incidencia * 100
  )

coeficientes_table <- coeficientes %>%
  filter(.data$Variable %in% c("VBP", "Consumo intermedio", "Masa salarial", "Consumo de capital fijo")) %>%
  mutate(
    Escenario = coalesce(.data$escenario_nombre, .data$escenario),
    Sección = recode(.data$seccion, !!!section_labels),
    Variable = recode(.data$Variable, `Consumo de capital fijo` = "Consumo capital fijo"),
    Fuente = str_squish(as.character(.data$Fuente)),
    Fuente = str_replace(.data$Fuente, "^[^;]+;\\s*", ""),
    Fuente = str_trunc(.data$Fuente, width = 135)
  ) %>%
  transmute(
    `Escenario` = .data$Escenario,
    `Sección` = .data$Sección,
    `Variable` = .data$Variable,
    `Incidencia` = fmt_pct(.data$Incidencia * 100, 1),
    `Efecto` = .data$Efecto,
    `Fuente` = .data$Fuente
  ) %>%
  arrange(.data$Escenario, .data$Sección, .data$Variable)

fig_factor_path <- file.path(figures_dir, "00_factor_devaluacion_2020_2024.png")
fig_coef_path <- file.path(figures_dir, "00_coeficientes_incidencia_masa_ganancia.png")

ggplot(factor_plot_data, aes(x = .data$anio, y = .data$factor_devaluacion_pct)) +
  geom_line(color = blue_palette[["main"]], linewidth = 0.9) +
  geom_point(color = blue_palette[["main"]], size = 2.2) +
  geom_text(
    aes(label = fmt_pct(.data$factor_devaluacion_pct, 1)),
    vjust = -0.75,
    size = 3.2,
    color = blue_palette[["navy"]]
  ) +
  scale_x_continuous(breaks = sort(unique(factor_plot_data$anio))) +
  scale_y_continuous(labels = label_percent(scale = 1), expand = expansion(mult = c(0.05, 0.18))) +
  labs(
    title = "Brecha cambiaria modelada",
    subtitle = "Factor anual de cierre entre tipo de cambio comercial y tipo de cambio de paridad",
    x = NULL,
    y = "Factor de devaluación",
    caption = caption_fuente
  ) +
  theme_report
ggsave(fig_factor_path, width = 8.5, height = 4.8, dpi = 160)

ggplot(coeficientes_plot_data, aes(
  x = .data$variable,
  y = .data$seccion_label,
  fill = .data$incidencia_pct
)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = fmt_pct(.data$incidencia_pct, 1)), size = 2.9) +
  facet_wrap(vars(.data$escenario_label), nrow = 1) +
  scale_fill_gradient(
    low = blue_palette[["pale"]],
    high = blue_palette[["deep"]],
    labels = label_percent(scale = 1)
  ) +
  labs(
    title = "Coeficientes de incidencia sobre la masa de ganancia",
    subtitle = "Proporción de cada variable expuesta al cierre de brecha TCC-TCP",
    x = NULL,
    y = NULL,
    fill = "Incidencia",
    caption = caption_fuente
  ) +
  theme_report +
  theme(axis.text.x = element_text(angle = 25, hjust = 1))
ggsave(fig_coef_path, width = 11.5, height = 5.2, dpi = 160)

make_component_plot <- function(data, spec, last_year) {
  component_data <- data %>%
    filter(.data$anno == !!last_year, .data$escenario == !!spec$escenario) %>%
    transmute(
      seccion_label = .data$seccion_label,
      `VBP` = -.data$delta_vbp_pp,
      `Consumo intermedio` = .data$delta_consumo_intermedio_estimado,
      `Remuneraciones` = .data$delta_remuneraciones,
      `Consumo capital fijo` = .data$delta_consumo_capital_fijo
    ) %>%
    pivot_longer(
      cols = -all_of("seccion_label"),
      names_to = "componente",
      values_to = "valor"
    ) %>%
    mutate(
      componente = factor(
        .data$componente,
        levels = c("VBP", "Consumo intermedio", "Remuneraciones", "Consumo capital fijo")
      ),
      valor_miles_mill = .data$valor / 1e9,
      sentido = if_else(.data$valor >= 0, "Apropiación/ahorro", "Cesión/menor valorización")
    )

  fig_path <- file.path(
    figures_dir,
    paste0("01_", spec$escenario, "_monto_apropiado_cedido_componentes_", last_year, ".png")
  )

  ggplot(component_data, aes(
    x = .data$valor_miles_mill,
    y = .data$componente,
    fill = .data$sentido
  )) +
    geom_vline(xintercept = 0, color = "grey35", linewidth = 0.35) +
    geom_col(width = 0.62) +
    geom_text(
      aes(
        label = fmt_delta(.data$valor_miles_mill, 1),
        hjust = if_else(.data$valor_miles_mill >= 0, -0.08, 1.08)
      ),
      size = 3,
      color = blue_palette[["navy"]],
      show.legend = FALSE
    ) +
    facet_wrap(vars(.data$seccion_label), nrow = 1, scales = "free_x") +
    scale_fill_manual(values = component_colors) +
    scale_x_continuous(expand = expansion(mult = c(0.18, 0.18))) +
    labs(
      title = "Monto apropiado/cedido según componente",
      subtitle = paste0(spec$titulo, ". Año ", last_year, ". VBP se expresa con signo negativo."),
      x = "Miles de millones de pesos corrientes",
      y = NULL,
      fill = NULL,
      caption = caption_fuente
    ) +
    theme_report
  ggsave(fig_path, width = 12, height = 5.4, dpi = 160)

  fig_path
}

make_delta_total_plot <- function(data, spec) {
  delta_data <- data %>%
    filter(.data$escenario == !!spec$escenario) %>%
    transmute(
      anno = .data$anno,
      seccion_label = .data$seccion_label,
      delta_total_pct = .data$delta_total_ganancia_pb_pct
    )

  last_labels <- delta_data %>%
    group_by(.data$seccion_label) %>%
    filter(.data$anno == max(.data$anno, na.rm = TRUE)) %>%
    ungroup()

  fig_path <- file.path(
    figures_dir,
    paste0("02_", spec$escenario, "_delta_total_ganancia_inicial.png")
  )

  ggplot(delta_data, aes(
    x = .data$anno,
    y = .data$delta_total_pct,
    color = .data$seccion_label
  )) +
    geom_hline(yintercept = 0, color = "grey35", linewidth = 0.35) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 2) +
    geom_text(
      data = last_labels,
      aes(label = paste0(fmt_delta(.data$delta_total_pct, 1), "%")),
      hjust = -0.08,
      size = 3,
      show.legend = FALSE
    ) +
    scale_x_continuous(
      breaks = sort(unique(delta_data$anno)),
      expand = expansion(mult = c(0.02, 0.17))
    ) +
    scale_y_continuous(labels = label_percent(scale = 1)) +
    scale_color_manual(values = section_colors) +
    labs(
      title = "Delta total sobre ganancia escenario inicial",
      subtitle = paste(
        "(-delta VBP + delta consumo intermedio + delta remuneraciones +",
        "delta consumo capital fijo) / ganancia_pb inicial"
      ),
      x = NULL,
      y = "% de la ganancia inicial",
      color = NULL,
      caption = caption_fuente
    ) +
    theme_report
  ggsave(fig_path, width = 10.5, height = 5.2, dpi = 160)

  fig_path
}

last_year <- max(escenarios$anno, na.rm = TRUE)
scenario_outputs <- lapply(seq_len(nrow(scenario_specs)), function(i) {
  spec <- scenario_specs[i, ]
  list(
    spec = spec,
    component_plot = make_component_plot(escenarios, spec, last_year),
    delta_total_plot = make_delta_total_plot(escenarios, spec)
  )
})
names(scenario_outputs) <- scenario_specs$escenario

delta_summary_table <- escenarios %>%
  filter(.data$anno == !!last_year) %>%
  transmute(
    `Escenario` = .data$escenario_label,
    `Sección` = as.character(.data$seccion_label),
    `Delta total / ganancia inicial` = fmt_pct(.data$delta_total_ganancia_pb_pct, 1),
    `Delta total` = fmt_delta(.data$delta_total_ganancia_pb / 1e9, 1),
    `Ganancia inicial` = fmt_num(.data$ganancia_pb / 1e9, 1),
    `Ganancia escenario` = fmt_num(.data$ganancia_pb_devaluacion / 1e9, 1)
  ) %>%
  arrange(.data$Escenario, .data$Sección)

md <- c(
  "# Escenarios integrados: deltas de masa de ganancia asociados a la sobrevaluación cambiaria industrial",
  "",
  paste0(
    "Fuente de trabajo: `",
    input_xlsx,
    "`, hojas `escenario-inicial`, `tipo-cambio`, ",
    "`Escenario 1 - Comercio Exterior` y `Escenario 2 - Bienes Transables`."
  ),
  "",
  "## Introducción",
  "",
  paste(
    "Esta minuta actualiza la lectura de los escenarios de cierre de brecha",
    "cambiaria para la industria manufacturera uruguaya a partir del XLSX",
    "regenerado con prefijo 20260831. La unidad de análisis son tres secciones:",
    "industria total, segmento exportador y segmento orientado al mercado",
    "interno. El ejercicio se expresa en valores corrientes y se concentra en",
    "la masa de ganancia a precios básicos, no en tasas de ganancia."
  ),
  "",
  paste(
    "El primer escenario recoge la incidencia directa del comercio exterior.",
    "El segundo amplía el ejercicio hacia bienes transables cuyos precios",
    "internos se rigen por precios internacionales. En ambos casos, el cálculo",
    "se realiza año a año, sin efectos acumulados ni respuestas dinámicas de",
    "cantidades, productividad o estructura productiva."
  ),
  "",
  "## Supuestos y fuentes",
  "",
  paste(
    "Las fuentes usadas son: EAAE para VBP, VAB, remuneraciones, consumo",
    "intermedio estimado y consumo de capital fijo; Oyanthabal, con base en la",
    "metodología de Iñigo Carrera (2007), para los tipos de cambio comercial y",
    "de paridad; microdatos del CIU para distribuir intereses industriales en el",
    "XLSX fuente; y la clasificación operativa de subramas industriales",
    "2020-2024 para separar industria exportadora, mercado interno y combustible.",
    "Esta minuta no reporta tasas de ganancia ni efectos sobre stock o intereses."
  ),
  "",
  paste(
    "Se trabaja desde 2020 porque en ese tramo la fuente opera con ramas",
    "homogéneas. Extender el ejercicio al panel completo exigiría procesar",
    "distintas versiones CIIU, lo que vuelve incompatible diferenciar con",
    "criterio uniforme el segmento industrial exportador y el segmento orientado",
    "al mercado interno."
  ),
  "",
  "Ramas incluidas en el segmento exportador:",
  paste0("- ", ramas_exportadoras),
  "",
  "Ramas incluidas en el segmento mercado interno:",
  paste0("- ", ramas_mercado_interno),
  "",
  paste0("![Brecha cambiaria modelada](", fig_rel(fig_factor_path), ")"),
  "",
  paste0(
    "El factor de devaluación considerado se calcula como ",
    "`tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1`. ",
    "En 2020-2024, el promedio es ",
    fmt_pct(factor_summary$promedio * 100),
    ", con mínimo de ",
    fmt_pct(factor_summary$minimo * 100),
    " y máximo de ",
    fmt_pct(factor_summary$maximo * 100),
    "."
  ),
  "",
  md_table(factor_table),
  "",
  "## Coeficientes de incidencia",
  "",
  paste(
    "La minuta usa cuatro coeficientes de incidencia para construir la masa de",
    "ganancia: VBP, consumo intermedio, remuneraciones y consumo de capital",
    "fijo. Para los gráficos de componentes, VBP se expresa con signo negativo;",
    "los demás deltas se expresan con signo positivo. Por tanto, el delta total",
    "es `-delta_vbp_pp + delta_consumo_intermedio_estimado +",
    "delta_remuneraciones + delta_consumo_capital_fijo`."
  ),
  "",
  paste0("![Coeficientes de incidencia sobre la masa de ganancia](", fig_rel(fig_coef_path), ")"),
  "",
  md_table(coeficientes_table),
  "",
  "## 1. Escenario 1 - Comercio Exterior",
  "",
  scenario_outputs$comercio_exterior$spec$descripcion,
  "",
  paste(
    "El primer gráfico muestra, para el último año disponible, el monto",
    "apropiado o cedido por componente en cada sección. El segundo resume el",
    "efecto neto anual como porcentaje de la ganancia a precios básicos del",
    "escenario inicial."
  ),
  "",
  paste0(
    "![Gráfico 1. Monto apropiado/cedido según componente](",
    fig_rel(scenario_outputs$comercio_exterior$component_plot),
    ")"
  ),
  "",
  paste0(
    "![Gráfico 2. Delta total sobre ganancia escenario inicial](",
    fig_rel(scenario_outputs$comercio_exterior$delta_total_plot),
    ")"
  ),
  "",
  "## 2. Escenario 2 - Bienes Transables",
  "",
  scenario_outputs$bienes_transables$spec$descripcion,
  "",
  paste(
    "El primer gráfico muestra, para el último año disponible, el monto",
    "apropiado o cedido por componente en cada sección. El segundo resume el",
    "efecto neto anual como porcentaje de la ganancia a precios básicos del",
    "escenario inicial."
  ),
  "",
  paste0(
    "![Gráfico 1. Monto apropiado/cedido según componente](",
    fig_rel(scenario_outputs$bienes_transables$component_plot),
    ")"
  ),
  "",
  paste0(
    "![Gráfico 2. Delta total sobre ganancia escenario inicial](",
    fig_rel(scenario_outputs$bienes_transables$delta_total_plot),
    ")"
  ),
  "",
  "## Síntesis cuantitativa",
  "",
  paste0(
    "La tabla resume el último año disponible (",
    last_year,
    "). Los montos están expresados en miles de millones de pesos corrientes."
  ),
  "",
  md_table(delta_summary_table),
  "",
  "## Anexo técnico",
  "",
  "La fórmula común aplicada en ambos escenarios es:",
  "",
  "```text",
  "factor_devaluacion = tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1",
  "delta_variable = variable_base * incidencia_seccion_variable * factor_devaluacion",
  "delta_total_ganancia_pb = -delta_vbp_pp + delta_consumo_intermedio_estimado + delta_remuneraciones + delta_consumo_capital_fijo",
  "ganancia_pb_devaluacion = ganancia_pb + delta_total_ganancia_pb",
  "delta_total_sobre_ganancia_inicial = delta_total_ganancia_pb / ganancia_pb * 100",
  "```",
  "",
  paste(
    "El XLSX fuente mantiene otros campos para trazabilidad del modelo, pero",
    "esta minuta se restringe a la masa de ganancia a precios básicos y a los",
    "cuatro deltas solicitados. No se calculan ni reportan tasas de ganancia."
  )
)

writeLines(md, output_md, useBytes = TRUE)

cat("Minuta integrada actualizada: ", output_md, "\n", sep = "")
cat("Figuras creadas en: ", figures_dir, "\n", sep = "")
cat("Fuente XLSX: ", input_xlsx, "\n", sep = "")
