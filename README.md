# economia-uruguay

Repositorio de procesamiento, documentación y análisis de fuentes económicas de
Uruguay, con foco en la Encuesta Anual de Actividad Económica (EAAE),
resultados industriales, deflactores BCU y fuentes complementarias. El trabajo
sigue una organización inspirada en el protocolo Project TIER: los datos
primarios se conservan en `data/input-data/`, los scripts reproducibles en
`command-files/`, las bases procesadas en `data/analysis-data/` y la
documentación metodológica en `docs/`.

## Resultados Principales

### Panel EAAE 2001-2024

- [20260605_panel_eaae.csv](data/analysis-data/20260605_panel_eaae.csv): panel EAAE principal por año y sección CIIU homologada.
- [20260605_panel_eaae.xlsx](data/analysis-data/20260605_panel_eaae.xlsx): libro de revisión con hojas base, validaciones, economía total, rama C y resultados propios.

### Panel Integrado EAAE-BCU

- [20260629_panel_eeae_bcu_total_industria_subrama.csv](data/analysis-data/20260629_panel_eeae_bcu_total_industria_subrama.csv): panel integrado para economía total, industria manufacturera y subramas industriales homologadas, con deflactores BCU, capital directo subrama e insumos para tasa de ganancia.
- [20260629_minuta_panel_eeae_bcu_total_industria_subrama.md](docs/methodology/20260629_minuta_panel_eeae_bcu_total_industria_subrama.md): minuta metodológica del panel integrado, incluyendo homologación CIIU, empalme de deflactores, imputaciones y validaciones de calidad.

## Otros Resultados Fechados

- [20260617_panel_eaae_industria_subramas_fuente.csv](data/analysis-data/20260617_panel_eaae_industria_subramas_fuente.csv): panel fuente de subramas industriales EAAE.
- [20260617_panel_eaae_industria_subramas_rev4_homologado.csv](data/analysis-data/20260617_panel_eaae_industria_subramas_rev4_homologado.csv): panel de subramas industriales homologadas a grupos compatibles con CIIU Rev.4.
- [20260617_validacion_panel_eaae_industria_subramas_rev4.csv](data/analysis-data/20260617_validacion_panel_eaae_industria_subramas_rev4.csv): validaciones del panel de subramas industriales.
- [20260623_panel_eia_1989_1997_2dig.csv](data/analysis-data/20260623_panel_eia_1989_1997_2dig.csv): panel EIA 1989-1997 a dos dígitos.
- [20260623_panel_eia_1989_1997_2dig.xlsx](data/analysis-data/20260623_panel_eia_1989_1997_2dig.xlsx): libro de revisión del panel EIA 1989-1997.

## Fuentes Procesadas No Fechadas

- [oyanthabal_indices_precios.csv](data/analysis-data/oyanthabal_indices_precios.csv): índices de precios y PIB de Oyanthabal/BCU.
- [bcu_pib_corriente_industrias_2005_2019.csv](data/analysis-data/bcu_pib_corriente_industrias_2005_2019.csv): PIB corriente por industrias BCU.
- [eaae_1998_2001_2dig_panel.csv](data/analysis-data/eaae_1998_2001_2dig_panel.csv): panel EAAE/EAE histórico 1998-2001 a dos dígitos.
- [ciu_encuesta_industrial_ipoi_ivfvi.csv](data/analysis-data/ciu_encuesta_industrial_ipoi_ivfvi.csv): indicadores CIU de personal ocupado e índice de volumen físico de ventas industriales.
- [ciu_indicadores_produccion_industrial_ivf_rama.csv](data/analysis-data/ciu_indicadores_produccion_industrial_ivf_rama.csv): producción industrial CIU por rama.
- [ciu_indicadores_inversion.csv](data/analysis-data/ciu_indicadores_inversion.csv): indicadores CIU de inversión.
- [ciu_inversion_maquinaria_equipos_imeq.csv](data/analysis-data/ciu_inversion_maquinaria_equipos_imeq.csv): inversión en maquinaria y equipos.
- [ciu_stock_capital.csv](data/analysis-data/ciu_stock_capital.csv): stock de capital CIU.

## Documentación Metodológica

- [20260520-datos-eaae.md](docs/methodology/20260520-datos-eaae.md): documentación inicial de datos EAAE.
- [20260604_nota_plantilla_homologacion_ciiu_industria.md](docs/methodology/20260604_nota_plantilla_homologacion_ciiu_industria.md): nota sobre plantilla de homologación CIIU industrial.
- [20260617_confiabilidad-datos-eaae-1998-2001.md](docs/methodology/20260617_confiabilidad-datos-eaae-1998-2001.md): evaluación de confiabilidad de datos históricos EAAE 1998-2001.
- [20260617_desagregacion-subrama-eaae-2001-2024.md](docs/methodology/20260617_desagregacion-subrama-eaae-2001-2024.md): análisis de desagregación posible por subrama EAAE.
- [20260623_minuta_deflactores_bcu_eaae_subramas_industria_2001_2024.md](docs/methodology/20260623_minuta_deflactores_bcu_eaae_subramas_industria_2001_2024.md): minuta sobre deflactores BCU para subramas industriales.
- [20260629_minuta_panel_eeae_bcu_total_industria_subrama.md](docs/methodology/20260629_minuta_panel_eeae_bcu_total_industria_subrama.md): minuta del panel integrado EAAE-BCU.
- [eaae_resultados_visuales.md](docs/eaae_resultados_visuales.md): informe visual de resultados EAAE.

## Estructura Del Repositorio

- `command-files/`: scripts reproducibles de descarga, extracción, procesamiento, validación y análisis.
- `data/input-data/`: datos primarios originales, tratados como solo lectura.
- `data/analysis-data/`: bases procesadas listas para análisis.
- `docs/`: minutas, documentos metodológicos e informes visibles desde GitHub.
- `output/figures/`: gráficos generados para informes.
- `CONTEXT.md`: bitácora técnica y decisiones metodológicas del proyecto.

## Reproducción

Instalar dependencias de Python:

```bash
pip install -r requirements.txt
```

Construir y validar el panel EAAE principal:

```bash
python3 command-files/processing-command-files/03_extract_otros.py
python3 command-files/processing-command-files/05_build_panel.py --force
python3 command-files/processing-command-files/06_validate_panel.py
```

Construir el panel integrado EAAE-BCU:

```bash
Rscript command-files/processing-command-files/13_build_panel_eaae_bcu_total_industria_subrama.R
```

Nota: la extracción desde archivos RAR requiere `unrar` o una alternativa
compatible. En algunas corridas se usó `bsdtar` vía Flatpak para abrir RAR5.
