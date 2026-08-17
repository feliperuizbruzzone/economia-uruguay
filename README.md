# economia-uruguay

Repositorio de procesamiento, documentación y análisis de fuentes económicas de
Uruguay, con foco en la Encuesta Anual de Actividad Económica (EAAE),
resultados industriales, deflactores BCU y fuentes complementarias. El trabajo
sigue una organización inspirada en el protocolo Project TIER: los datos
primarios se conservan en `data/input-data/`, los scripts reproducibles en
`command-files/`, las bases procesadas en `data/analysis-data/` y la
documentación metodológica en `docs/`.

## Resultados EAAE-BCU: Tres Niveles Y Subramas

- [20260817_panel_eeae_bcu_total_industria_subrama.csv](data/analysis-data/20260817_panel_eeae_bcu_total_industria_subrama.csv): panel integrado en formato largo para economía total, industria manufacturera agregada, industria depurada de papel/impresión y coque/refinación, y subramas industriales homologadas. Incorpora rotaciones Mussi, proporciones importadas, exportaciones, tipos de cambio e intereses industriales para escenarios de devaluación.
- [20260817_resultados_eaae_bcu_total_industria_subrama.xlsx](data/analysis-data/20260817_resultados_eaae_bcu_total_industria_subrama.xlsx): libro de resultados en formato largo derivado del panel integrado, con hojas de metodología, base EAAE-BCU, controles de calidad, resultados corrientes, constantes, variaciones interanuales, índices 2005=1 y `efecto-devaluacion-corrientes`.
- [20260817_resultados_eaae_bcu_tres_niveles.md](docs/20260817_resultados_eaae_bcu_tres_niveles.md): minuta visual de resultados centrada en tasa de ganancia para economía total, industria total e industria depurada, con comparación contra la tasa de ganancia de Oyanthabal y anexo de stock EAAE-CIU.
- [20260817_resultados_devaluación_sector_industrial.md](docs/minutes/20260817_resultados_devaluación_sector_industrial.md): minuta de resultados sobre efectos de devaluación en la industria manufacturera, comparando escenario base, devaluación con salario nominal fijo y devaluación con salario compensado.
- [Figuras EAAE-BCU 20260817](output/figures/eaae_bcu_tres_niveles_20260817/): gráficos respaldados para la minuta de resultados EAAE-BCU.
- [Figuras devaluación industrial 20260817](output/figures/devaluacion_sector_industrial_20260817/): gráficos respaldados para la minuta de efectos de devaluación.

## Resultados Principales

### Panel Integrado EAAE-BCU

- [20260817_panel_eeae_bcu_total_industria_subrama.csv](data/analysis-data/20260817_panel_eeae_bcu_total_industria_subrama.csv): última versión del panel integrado para economía total, industria manufacturera, industria depurada y subramas industriales homologadas, con deflactores BCU, rotación Mussi, capital directo subrama e insumos para tasa de ganancia y escenarios de devaluación.
- [20260817_resultados_eaae_bcu_total_industria_subrama.xlsx](data/analysis-data/20260817_resultados_eaae_bcu_total_industria_subrama.xlsx): última versión del libro de resultados del panel integrado.
- [20260706_minuta_panel_eeae_bcu_total_industria_subrama.md](docs/methodology/20260706_minuta_panel_eeae_bcu_total_industria_subrama.md): minuta metodológica del panel integrado, incluyendo homologación CIIU, empalme de deflactores, rotaciones, imputaciones y validaciones de calidad.

### Panel EAAE 2001-2024

- [20260605_panel_eaae.csv](data/analysis-data/20260605_panel_eaae.csv): panel EAAE principal por año y sección CIIU homologada.
- [20260605_panel_eaae.xlsx](data/analysis-data/20260605_panel_eaae.xlsx): libro de revisión con hojas base, validaciones, economía total, rama C y resultados propios.

## Otros Resultados Fechados

- [20260706_panel_eeae_bcu_total_industria_subrama.csv](data/analysis-data/20260706_panel_eeae_bcu_total_industria_subrama.csv): versión previa del panel integrado EAAE-BCU.
- [20260706_resultados_eaae_bcu_total_industria_subrama.xlsx](data/analysis-data/20260706_resultados_eaae_bcu_total_industria_subrama.xlsx): versión previa del libro de resultados EAAE-BCU.
- [20260706_resultados_eaae_bcu_total_industria_subrama.md](docs/20260706_resultados_eaae_bcu_total_industria_subrama.md): informe visual previo con economía total, industria manufacturera y subramas industriales.
- [20260617_panel_eaae_industria_subramas_fuente.csv](data/analysis-data/20260617_panel_eaae_industria_subramas_fuente.csv): panel fuente de subramas industriales EAAE.
- [20260617_panel_eaae_industria_subramas_rev4_homologado.csv](data/analysis-data/20260617_panel_eaae_industria_subramas_rev4_homologado.csv): panel de subramas industriales homologadas a grupos compatibles con CIIU Rev.4.
- [20260617_validacion_panel_eaae_industria_subramas_rev4.csv](data/analysis-data/20260617_validacion_panel_eaae_industria_subramas_rev4.csv): validaciones del panel de subramas industriales.
- [20260623_panel_eia_1989_1997_2dig.csv](data/analysis-data/20260623_panel_eia_1989_1997_2dig.csv): panel EIA 1989-1997 a dos dígitos.
- [20260623_panel_eia_1989_1997_2dig.xlsx](data/analysis-data/20260623_panel_eia_1989_1997_2dig.xlsx): libro de revisión del panel EIA 1989-1997.

## Fuentes Procesadas No Fechadas

- [oyanthabal_indices_precios.csv](data/analysis-data/oyanthabal_indices_precios.csv): índices de precios y PIB de Oyanthabal/BCU.
- [oyanthabal_tasa_ganancia_uruguay.csv](data/analysis-data/oyanthabal_tasa_ganancia_uruguay.csv): tasas de ganancia de Uruguay procesadas desde Oyanthabal para total y no agrario desde 2000.
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
- [20260706_minuta_panel_eeae_bcu_total_industria_subrama.md](docs/methodology/20260706_minuta_panel_eeae_bcu_total_industria_subrama.md): minuta del panel integrado EAAE-BCU.
- [20260817_minuta_efecto_devaluacion_industria.md](docs/methodology/20260817_minuta_efecto_devaluacion_industria.md): minuta metodológica sobre la hoja `efecto-devaluacion-corrientes`, sus supuestos, fórmulas, cobertura y calidad de resultados.
- [20260605_eaae_resultados_eaae_oyanthaabal_total_industria.md](docs/20260605_eaae_resultados_eaae_oyanthaabal_total_industria.md): informe visual de resultados EAAE/Oyanthabal para economía total e industria.

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

Construir la minuta de efectos de devaluación industrial:

```bash
Rscript command-files/analysis-command-files/07_generar_minuta_devaluacion_sector_industrial.R
```

Nota: la extracción desde archivos RAR requiere `unrar` o una alternativa
compatible. En algunas corridas se usó `bsdtar` vía Flatpak para abrir RAR5.
