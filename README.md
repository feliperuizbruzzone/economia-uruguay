# economia-uruguay

Repositorio de procesamiento, documentación y análisis de fuentes económicas de
Uruguay, con foco en la Encuesta Anual de Actividad Económica (EAAE),
resultados industriales, deflactores BCU y fuentes complementarias. El trabajo
sigue una organización inspirada en el protocolo Project TIER: los datos
primarios se conservan en `data/input-data/`, los scripts reproducibles en
`command-files/`, las bases procesadas en `data/analysis-data/`, la
documentación en `docs/` y las figuras en `output/figures/`.

## Resultados Brecha Cambiaria Industria 2020-2024

- [20260826_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx](data/analysis-data/20260826_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx): último libro de modelamiento del cierre de brecha cambiaria para industria total, segmento exportador y segmento mercado interno, con coeficientes diferenciados por sección.
- [20260826_panel_eaae_2020_2024_industria.csv](data/analysis-data/20260826_panel_eaae_2020_2024_industria.csv): panel base 2020-2024 de industria total y grupos de subramas industriales, actualizado con distribución de intereses por microdatos CIU.
- [20260826_resultados_devaluacion_industria_segmentos.md](docs/20260826_resultados_devaluacion_industria_segmentos.md): minuta de resultados para explicar supuestos, escenarios y resultados principales sobre apropiación de riqueza por sobrevaluación cambiaria.
- [Figuras devaluación industria segmentos 20260826](output/figures/devaluacion_industria_segmentos_20260826/): figuras respaldadas para la minuta anterior.
- [20260826-coeficientes-efecto-devaluacion.csv](data/input-data/mussi/20260826-coeficientes-efecto-devaluacion.csv): tabla consolidada de coeficientes de incidencia para industria total, segmento exportador y segmento mercado interno.

## Resultados Integrados EAAE-BCU

- [20260819_panel_eeae_bcu_total_industria_subrama.csv](data/analysis-data/20260819_panel_eeae_bcu_total_industria_subrama.csv): último panel integrado en formato largo para economía total, industria manufacturera, industria depurada y subramas industriales homologadas.
- [20260819_resultados_eaae_bcu_total_industria_subrama.xlsx](data/analysis-data/20260819_resultados_eaae_bcu_total_industria_subrama.xlsx): último libro de resultados del panel integrado, con hojas de metodología, base EAAE-BCU, controles de calidad, resultados corrientes, constantes, variaciones interanuales, índices 2005=1 y efecto de devaluación corriente.
- [20260819_resultados_eaae_bcu_tres_niveles.md](docs/20260819_resultados_eaae_bcu_tres_niveles.md): última minuta visual de resultados para economía total, industria total e industria depurada.
- [Figuras EAAE-BCU tres niveles 20260819](output/figures/eaae_bcu_tres_niveles_20260819/): gráficos respaldados para la minuta de tres niveles.
- [20260819_auditoria_fbkf_directa_subrama_eaae.csv](data/analysis-data/20260819_auditoria_fbkf_directa_subrama_eaae.csv): auditoría de trazabilidad de FBKF, maquinaria/equipos y adquisiciones a nivel de subrama industrial.

## Panel EAAE Principal

- [20260605_panel_eaae.csv](data/analysis-data/20260605_panel_eaae.csv): panel EAAE principal por año y sección CIIU homologada.
- [20260605_panel_eaae.xlsx](data/analysis-data/20260605_panel_eaae.xlsx): libro de revisión del panel EAAE principal, con hojas base, validaciones, economía total, rama C y resultados propios.
- [20260605_eaae_resultados_eaae_oyanthaabal_total_industria.md](docs/20260605_eaae_resultados_eaae_oyanthaabal_total_industria.md): informe visual EAAE/Oyanthabal para economía total e industria.

## Subramas Industriales EAAE

- [20260617_panel_eaae_industria_subramas_fuente.csv](data/analysis-data/20260617_panel_eaae_industria_subramas_fuente.csv): panel fuente de subramas industriales EAAE.
- [20260617_panel_eaae_industria_subramas_rev4_homologado.csv](data/analysis-data/20260617_panel_eaae_industria_subramas_rev4_homologado.csv): panel de subramas industriales homologadas a grupos compatibles con CIIU Rev.4.
- [20260617_validacion_panel_eaae_industria_subramas_rev4.csv](data/analysis-data/20260617_validacion_panel_eaae_industria_subramas_rev4.csv): validaciones del panel de subramas industriales homologado.
- [20260824_subramas_industriales_fuente_eaae_2020_2024.csv](docs/methodology/20260824_subramas_industriales_fuente_eaae_2020_2024.csv): clasificación de subramas industriales usada para los grupos 2020-2024.

## Series Históricas

- [20260623_panel_eia_1989_1997_2dig.csv](data/analysis-data/20260623_panel_eia_1989_1997_2dig.csv): panel EIA 1989-1997 a dos dígitos.
- [20260623_panel_eia_1989_1997_2dig.xlsx](data/analysis-data/20260623_panel_eia_1989_1997_2dig.xlsx): libro de revisión y validación del panel EIA 1989-1997.
- [eaae_1998_2001_2dig_panel.csv](data/analysis-data/eaae_1998_2001_2dig_panel.csv): panel EAAE/EAE histórico 1998-2001 a dos dígitos.

## Fuentes Complementarias Procesadas

- [oyanthabal_indices_precios.csv](data/analysis-data/oyanthabal_indices_precios.csv): índices de precios y PIB de Oyanthabal/BCU.
- [oyanthabal_tasa_ganancia_uruguay.csv](data/analysis-data/oyanthabal_tasa_ganancia_uruguay.csv): tasas de ganancia de Uruguay procesadas desde Oyanthabal para total y no agrario desde 2000.
- [bcu_pib_corriente_industrias_2005_2019.csv](data/analysis-data/bcu_pib_corriente_industrias_2005_2019.csv): PIB corriente por industrias BCU.
- [ciu_stock_capital_industria_1988_2025.csv](data/analysis-data/ciu_stock_capital_industria_1988_2025.csv): stock de capital fijo industrial CIU en maquinaria y equipos.
- [ciu_encuesta_industrial_ipoi_ivfvi.csv](data/analysis-data/ciu_encuesta_industrial_ipoi_ivfvi.csv): indicadores CIU de personal ocupado e índice de volumen físico de ventas industriales.
- [ciu_indicadores_produccion_industrial_ivf_rama.csv](data/analysis-data/ciu_indicadores_produccion_industrial_ivf_rama.csv): producción industrial CIU por rama.
- [ciu_indicadores_inversion.csv](data/analysis-data/ciu_indicadores_inversion.csv): indicadores CIU de inversión.
- [ciu_inversion_maquinaria_equipos_imeq.csv](data/analysis-data/ciu_inversion_maquinaria_equipos_imeq.csv): inversión en maquinaria y equipos.

## Metodología

- [20260706_minuta_panel_eeae_bcu_total_industria_subrama.md](docs/methodology/20260706_minuta_panel_eeae_bcu_total_industria_subrama.md): criterios del panel integrado EAAE-BCU, homologación CIIU, empalme de deflactores, rotaciones, imputaciones y validaciones.
- [20260820_minuta_modelamiento_devaluacion_1.md](docs/methodology/20260820_minuta_modelamiento_devaluacion_1.md): metodología del libro de modelamiento de devaluación.
- [20260817_minuta_efecto_devaluacion_industria.md](docs/methodology/20260817_minuta_efecto_devaluacion_industria.md): metodología de la hoja `efecto-devaluacion-corrientes`.
- [20260807_minuta_fuente_eaae_microdatos.md](docs/methodology/20260807_minuta_fuente_eaae_microdatos.md): evaluación de disponibilidad y límites de los microdatos EAAE.
- [20260623_minuta_deflactores_bcu_eaae_subramas_industria_2001_2024.md](docs/methodology/20260623_minuta_deflactores_bcu_eaae_subramas_industria_2001_2024.md): minuta sobre deflactores BCU para subramas industriales.
- [20260623_grilla_equivalencias_subramas_manufactura_rev3_rev4.xlsx](docs/methodology/20260623_grilla_equivalencias_subramas_manufactura_rev3_rev4.xlsx): grilla de equivalencias CIIU Rev.3-Rev.4 para manufactura.

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

Actualizar el modelamiento de devaluación diferenciada:

```bash
Rscript command-files/processing-command-files/30_process_mussi_coeficientes_devaluacion_segmentos.R
Rscript command-files/analysis-command-files/12_update_eaae_industria_devaluacion_segmentos.R
Rscript command-files/analysis-command-files/13_generar_minuta_devaluacion_segmentos.R
```

Nota: la extracción desde archivos RAR requiere `unrar` o una alternativa
compatible. En algunas corridas se usó `bsdtar` vía Flatpak para abrir RAR5.
