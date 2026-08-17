#!/usr/bin/env Rscript

# Correct derived aggregate BCU deflators in the latest integrated EAAE-BCU panel.
#
# Run from the project root:
#   Rscript command-files/processing-command-files/27_fix_panel_eaae_bcu_deflactores_base2005.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

analysis_dir <- file.path("data", "analysis-data")
panel_date <- Sys.getenv("EAAE_PANEL_DATE", unset = format(Sys.Date(), "%Y%m%d"))
panel_path <- file.path(
  analysis_dir,
  paste0(panel_date, "_panel_eeae_bcu_total_industria_subrama.csv")
)

target_level <- "industria_sin_papel_coque_refinacion"
excluded_industry_groups <- c(
  "17_18_papel_impresion",
  "19_refinacion"
)

safe_divide <- function(numerator, denominator) {
  result <- numerator / denominator
  result[is.na(numerator) | is.na(denominator) | denominator == 0] <- NA_real_
  result
}

sum_present <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) {
    return(NA_real_)
  }
  sum(x)
}

rebuild_depurada_deflator <- function(panel) {
  component_deflators <- panel %>%
    filter(
      nivel_panel == "subrama_industrial",
      !grupo_rev4_homologado %in% excluded_industry_groups
    ) %>%
    mutate(
      # DECISION: The aggregate deflator must be built from component-level
      # constant-2005 BCU values before aggregation. This mirrors the corrected
      # logic in script 13 and guarantees that the derived aggregate has
      # deflactor_2005 == 1 in the 2005 base year.
      vab_bcu_constante_2005_componente =
        safe_divide(vab_bcu_corriente, deflactor_2005)
    ) %>%
    group_by(anno) %>%
    summarise(
      vab_bcu_corriente_depurada = sum_present(vab_bcu_corriente),
      vab_bcu_constante_2005_depurada =
        sum_present(vab_bcu_constante_2005_componente),
      deflactor_depurada = safe_divide(
        vab_bcu_corriente_depurada,
        vab_bcu_constante_2005_depurada
      ),
      .groups = "drop"
    )

  panel %>%
    left_join(component_deflators, by = "anno") %>%
    mutate(
      deflactor_2005 = if_else(
        nivel_panel == target_level,
        deflactor_depurada,
        deflactor_2005
      ),
      deflactor_vab_bcu_2005 = if_else(
        nivel_panel == target_level,
        deflactor_depurada,
        deflactor_vab_bcu_2005
      ),
      nota_deflactor_bcu = if_else(
        nivel_panel == target_level,
        paste(
          nota_deflactor_bcu,
          "Deflactor agregado normalizado a base 2005=1 desde componentes subramales."
        ),
        nota_deflactor_bcu
      )
    ) %>%
    select(
      -vab_bcu_corriente_depurada,
      -vab_bcu_constante_2005_depurada,
      -deflactor_depurada
    )
}

recalculate_constant_columns <- function(panel) {
  constant_cols <- grep("_constante_2005$", names(panel), value = TRUE)
  for (constant_col in constant_cols) {
    source_col <- sub("_constante_2005$", "", constant_col)
    if (source_col %in% names(panel)) {
      panel[[constant_col]] <- safe_divide(panel[[source_col]], panel$deflactor_2005)
    }
  }
  panel
}

validate_output <- function(output, input) {
  if (nrow(output) != nrow(input)) {
    stop("La correccion cambio la cantidad de filas del panel.")
  }
  if (ncol(output) != ncol(input)) {
    stop("La correccion cambio la cantidad de columnas del panel.")
  }
  if (anyDuplicated(output[c("anno", "nivel_panel", "grupo_rev4_homologado")]) > 0) {
    stop("La clave anno + nivel_panel + grupo_rev4_homologado no es unica.")
  }
  if (any(is.na(output$deflactor_2005))) {
    stop("Hay filas sin deflactor_2005.")
  }

  base_errors <- output %>%
    filter(anno == 2005L, abs(deflactor_2005 - 1) > 1e-10)
  if (nrow(base_errors) > 0) {
    stop(
      "Todos los deflactor_2005 deben valer 1 en 2005. Errores: ",
      paste(
        capture.output(
          print(base_errors %>%
            select(anno, nivel_panel, grupo_rev4_homologado, deflactor_2005))
        ),
        collapse = " "
      )
    )
  }
}

main <- function() {
  panel <- readr::read_csv(panel_path, show_col_types = FALSE)

  output <- panel %>%
    rebuild_depurada_deflator() %>%
    recalculate_constant_columns()

  validate_output(output, panel)
  readr::write_csv(output, panel_path, na = "")

  message("Panel corregido en ", panel_path)
  message("Filas: ", nrow(output), "; columnas: ", ncol(output))
  message("Validacion: deflactor_2005 == 1 en 2005 para todos los niveles.")
}

if (identical(environment(), globalenv())) {
  main()
}
