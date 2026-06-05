# Load EAAE analysis panel into the R working environment.

find_project_root <- function(start_dir = getwd()) {
  current_dir <- normalizePath(start_dir, mustWork = TRUE)

  repeat {
    context_path <- file.path(current_dir, "CONTEXT.md")
    analysis_dir <- file.path(current_dir, "data", "analysis-data")
    panel_paths <- if (dir.exists(analysis_dir)) {
      list.files(
        analysis_dir,
        pattern = "^[0-9]{8}_panel_eaae\\.xlsx$",
        full.names = TRUE
      )
    } else {
      character()
    }

    if (file.exists(context_path) && length(panel_paths) > 0) {
      return(current_dir)
    }

    parent_dir <- dirname(current_dir)
    if (identical(parent_dir, current_dir)) {
      stop(
        "No se encontro la raiz del proyecto con CONTEXT.md y ",
        "un archivo data/analysis-data/YYYYMMDD_panel_eaae.xlsx.",
        call. = FALSE
      )
    }

    current_dir <- parent_dir
  }
}

project_root <- find_project_root()
panel_candidates <- list.files(
  file.path(project_root, "data", "analysis-data"),
  pattern = "^[0-9]{8}_panel_eaae\\.xlsx$",
  full.names = TRUE
)
panel_path <- sort(panel_candidates, decreasing = TRUE)[1]

if (!requireNamespace("readxl", quietly = TRUE)) {
  stop("Instale el paquete R `readxl` para cargar el panel Excel.", call. = FALSE)
}

panel_eaae <- readxl::read_excel(panel_path, sheet = "eaae")
panel_eaae <- as.data.frame(panel_eaae, stringsAsFactors = FALSE)

panel_eaae$anno <- as.integer(panel_eaae$anno)

numeric_columns <- c(
  "epoca",
  "vbp_pp",
  "vbp_pb",
  "vab_pp",
  "vab_pb",
  "vab_pb_estimado",
  "consumo_intermedio_estimado",
  "capital_circulante_constante_adelantado",
  "remuneraciones",
  "capital_variable_adelantado",
  "puestos_trabajo",
  "n_empresas",
  "fbcf",
  "fbkf_maq_eq",
  "adquisiciones_importadas",
  "adquisiciones_origen_importado",
  "importaciones_maquinaria",
  "consumo_capital_fijo",
  "impuestos_netos",
  "stock_capital",
  "capital_total_adelantado",
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
  " columnas desde ",
  basename(panel_path),
  "."
)
