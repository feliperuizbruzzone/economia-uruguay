# Load EAAE analysis panel into the R working environment.

find_project_root <- function(start_dir = getwd()) {
  current_dir <- normalizePath(start_dir, mustWork = TRUE)

  repeat {
    context_path <- file.path(current_dir, "CONTEXT.md")
    panel_path <- file.path(current_dir, "data", "analysis-data", "panel_eaae.csv")

    if (file.exists(context_path) && file.exists(panel_path)) {
      return(current_dir)
    }

    parent_dir <- dirname(current_dir)
    if (identical(parent_dir, current_dir)) {
      stop(
        "No se encontro la raiz del proyecto con CONTEXT.md y ",
        "data/analysis-data/panel_eaae.csv.",
        call. = FALSE
      )
    }

    current_dir <- parent_dir
  }
}

project_root <- find_project_root()
panel_path <- file.path(project_root, "data", "analysis-data", "panel_eaae.csv")

panel_eaae <- read.csv(
  panel_path,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

panel_eaae$anno <- as.integer(panel_eaae$anno)

numeric_columns <- c(
  "epoca",
  "vbp_pp",
  "vbp_pb",
  "vab_pp",
  "vab_pb",
  "remuneraciones",
  "puestos_trabajo",
  "fbcf",
  "adquisiciones_importadas",
  "consumo_capital",
  "impuestos_netos",
  "stock_capital",
  "excedente_bruto",
  "part_salarial",
  "productividad"
)

for (column in intersect(numeric_columns, names(panel_eaae))) {
  panel_eaae[[column]] <- suppressWarnings(as.numeric(panel_eaae[[column]]))
}

message(
  "Base cargada en `panel_eaae`: ",
  nrow(panel_eaae),
  " filas, ",
  ncol(panel_eaae),
  " columnas."
)
