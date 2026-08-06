# CONTEXT.md — Pipeline EAAE Uruguay 2001–2024
## Documento de contexto para agente de código (Claude Code / Codex / Cursor)
### Protocolo Project TIER 4.0 · Linux · Positron · Versión 1.0 · Mayo 2026

---

> **Instrucción al agente:** este archivo es la fuente de verdad del proyecto.
> Léelo completo antes de escribir cualquier código. Ante cualquier ambigüedad,
> consulta §7 (Decisiones pendientes) y §8 (Anomalías conocidas) antes de
> asumir cualquier comportamiento por defecto. No inventes rutas, nombres de
> archivo ni valores de configuración: todos están documentados aquí o deben
> ser consultados explícitamente al investigador.

---

## §1. RESUMEN DEL PROYECTO

### Objetivo
Construir un pipeline de extracción, procesamiento y validación de datos de la
**Encuesta Anual de Actividad Económica (EAAE)** del Instituto Nacional de
Estadística (INE) de Uruguay, cubriendo la serie completa **2001–2024**.

Los productos finales son **dos archivos fechados**, un CSV completo y un
libro Excel de revisión (`YYYYMMDD_panel_eaae.csv` y
`YYYYMMDD_panel_eaae.xlsx`), con estructura de panel sección CIIU × año y las
variables prioritarias para calcular indicadores de tasa de ganancia, costo
laboral y acumulación sectorial de capital en Uruguay.

### Variables objetivo del panel final

| Variable | Fuente en EAAE | Tipo | Disponibilidad en la serie |
|---|---|---|---|
| `vbp_pp` | 2001 cuadro 1 letra / C1/C1.1 | directa | 2001–2024 |
| `vbp_pb` | C1.1, columna VBP(pb) | directa | 2017–2024 solamente |
| `vab_pp` | 2001 cuadro 1 letra / C1/C1.1 | directa | 2001–2024 |
| `vab_pb` | C1.1, columna VAB(pb) | directa | 2017–2024 solamente |
| `vab_pb_estimado` | `vab_pb` observado 2017–2024 y retroproyección con variación interanual de `vab_pp` | derivada provisoria | 2001–2024 |
| `consumo_intermedio_estimado` | `vbp_pp - vab_pb_estimado` | derivada provisoria | 2001–2024 |
| `capital_circulante_constante_adelantado` | `consumo_intermedio_estimado / factor_rotacion` | derivada provisoria | C y economía total; otros sectores NA |
| `remuneraciones` | 2001 cuadro 1 letra / C1/C1.1 | directa | 2001–2024 |
| `capital_variable_adelantado` | `remuneraciones / factor_rotacion` | derivada provisoria | C y economía total; otros sectores NA |
| `puestos_trabajo` | 2001 cuadro 1 letra / C1/C1.1 | directa | 2001–2024 |
| `n_empresas` | PDF de metodología/diseño muestral EAAE, marco muestral por sección | directa de fuente auxiliar | 2001–2005, 2011 y 2020; otros años NA |
| `fbcf` | 2001 C8 / 2003–2005 C10 / 2006–2024 C6 | directa | 2001, 2003–2010, 2012–2024 |
| `fbkf_maq_eq` | componente maquinaria y equipos de la FBKF | directa | 2001, 2003–2010, 2012–2024 |
| `adquisiciones_importadas` | subcomponente Importadas en cuadros FBCF | directa | 2001, 2003–2010, 2012–2024 |
| `adquisiciones_origen_importado` | subcomponente En plaza / Origen Imp. en cuadros FBCF | directa | 2004–2010, 2012–2024 |
| `importaciones_maquinaria` | `adquisiciones_importadas + adquisiciones_origen_importado` | derivada | 2004–2010, 2012–2024 |
| `consumo_capital_fijo` | 2001–2011 C2 / 2012–2024 C2.1 | directa | 2001–2024 |
| `impuestos_netos` | 2001–2011 C2 / 2012–2024 C2.1 | directa | 2001–2024 |
| `stock_capital` | 2001 C9 / 2003–2005 C11 / 2006–2024 C7 | directa | 2001, 2003–2010, 2012–2024 |
| `stock_capital_imputado` | `stock_capital` si existe; si no, imputación con factor histórico `stock_capital / consumo_capital_fijo` | derivada provisoria | 2001–2024 donde exista stock original o imputación definida |
| `capital_total_adelantado` | `stock_capital_imputado + capital_variable_adelantado + capital_circulante_constante_adelantado` | derivada provisoria | C y economía total donde existe `stock_capital_imputado`; otros sectores NA |
| `variacion_existencias` | 2001 C10 / 2003–2005 C12 | directa identificada, pendiente de extracción | 2001, 2003–2005 |
| `deuda_industrial` | no encontrada en EAAE | requiere fuente externa | — |
| `amortizaciones` | derivada / fuente externa | **pendiente — ver §7.1** | — |

### Decisiones provisorias vigentes — Junio 2026

Las siguientes variables derivadas forman parte del panel actual como decisión
provisoria del equipo:

- `vab_pb_estimado`: usa `vab_pb` observado en 2017–2024 y retroproyección por
  variación interanual de `vab_pp` para años anteriores.
- `consumo_intermedio_estimado`: se calcula como `vbp_pp - vab_pb_estimado`.
- `consumo_capital_fijo`: nombre público de la variable directa de consumo de
  capital fijo extraída de C2/C2.1; no usar `consumo_capital` como columna final
  del panel.
- `capital_variable_adelantado`: se calcula como `remuneraciones /
  factor_rotacion`.
- `capital_circulante_constante_adelantado`: se calcula como
  `consumo_intermedio_estimado / factor_rotacion`.
- `stock_capital_imputado`: es la serie operativa de stock; replica
  `stock_capital` cuando existe y, cuando falta en 2002 o 2011, se imputa con
  el consumo de capital fijo disponible y un factor histórico calculado como el
  promedio porcentual de `stock_capital / consumo_capital_fijo` en la misma
  sección o total.
- `capital_total_adelantado`: se calcula como `stock_capital_imputado +
  capital_variable_adelantado + capital_circulante_constante_adelantado`.

Los factores de rotación definidos hasta ahora son `6,6` para la rama `C` y
`4,2` para `economia_total`. Para otros sectores, las variables de capital
adelantado deben quedar como NA hasta que el equipo defina factores. Si falta
`stock_capital`, como ocurre en 2002 y 2011, el panel conserva esa columna
original como NA, pero completa `stock_capital_imputado` mediante la regla de
imputación histórica cuando existe `consumo_capital_fijo` y observaciones de
referencia válidas.
No se registra una tercera variable auxiliar de stock.

En las hojas `resultados-total-corrientes` y
`resultados-industrial-corrientes`, se agrega una referencia externa simple con
BCU: `vab_bcu_corriente` replica el VAB corriente publicado por BCU convertido
de miles de pesos a pesos corrientes, y `vab_eaae_bcu_pct` compara el VAB
corriente EAAE contra BCU como `vab_pp / vab_bcu_corriente * 100`. Para economía
total se usa la fila BCU `VALOR AGREGADO BRUTO DE LOS SECTORES DE ACTIVIDAD`;
para industria se usa la sección BCU Rev.3 `D`, `INDUSTRIAS MANUFACTURERAS`. Se
integran todos los años BCU disponibles, incluyendo 2017–2019 marcados como
preliminares en la fuente, sin agregar una columna separada para la marca
preliminar.

Notas validadas:
- `remuneraciones` incluye aportes patronales. En los cuadros de detalle, el
  valor usado por C1/C1.1 coincide con el Total que suma remuneraciones
  salariales y `Aportes Patronales`, no con `Sueldos y Salarios` puros.
- `variacion_existencias` corresponde al flujo de variación de existencias; no
  es un stock de inventarios. No está integrada todavía al panel final.
- No se encontró en la EAAE una variable de deuda, pasivos, préstamos, crédito
  o endeudamiento sectorial/industrial. Cualquier `deuda_industrial` requiere
  fuente externa.
- `n_empresas` proviene de los PDF locales de metodología/diseño muestral en
  `data/input-data/eaae/metodologia`. Solo se integra cuando el PDF permite
  obtener un desglose exacto por sección compatible con el panel: anexos
  tabulares 2001–2005, gráfico etiquetado 2011 y gráfico vectorial 2020 cuya
  suma reconstruida reproduce exactamente el total publicado. 2022 queda como
  NA porque el gráfico no tiene etiquetas y la reconstrucción vectorial no
  reproduce el total del marco publicado; 2021 queda NA porque el PDF local está
  incompleto y no trae el desglose por sección.
- La hoja inicial `metodología` del XLSX se genera en el post-proceso R. Resume
  la estructura del libro y contiene un diccionario de variables que distingue
  identificadores, variables originales, auxiliares, validaciones, deflactores y
  variables calculadas.
- Las hojas `resultados-total-corrientes` y `resultados-industrial-corrientes`
  del XLSX se agregan como post-proceso en R mediante
  `command-files/analysis-command-files/02_add_calculos_propios_eaae.R`. No
  cambian el CSV ni la hoja base `eaae`. Usan tasas de rotación diferenciadas:
  `4,2` para `economia_total` y `6,6` para la rama industrial `C`. Como
  `remuneraciones` ya incluye aportes patronales en C1/C1.1, el costo laboral
  operativo se expone directamente como `costo_laboral = remuneraciones`; no se
  agrega una columna separada `cargas_patronales` para evitar columnas vacías.
  Estas hojas contienen niveles corrientes: insumos usados en los cálculos y
  variables calculadas, sin columnas interanuales ni duplicados propios de la
  economía total.
- Las hojas `resultados-total-constante` y `resultados-industrial-constante`
  replican esos cálculos en precios de 2005. `costo_laboral` se deflacta con
  `ipc_index_2005`. El resto de las variables monetarias se deflacta con
  `gdp_price_index_base_2005`; `puestos_trabajo` se mantiene como cantidad. La
  fuente Oyanthabal actualizada cubre `gdp_price_index_base_2005` e
  `ipc_index_2005` hasta 2024; cuando el XLSX no trae `ipc_index_2005` como
  columna explícita, el pipeline lo deriva desde `ipc_index_1983_1989`
  normalizando 2005=1. `productividad_trabajo` se calcula en las hojas
  constantes como `vab_pp / puestos_trabajo`.
- Las hojas `resultados-total-var-pct` y `resultados-industrial-var-pct`
  expresan las columnas analíticas de los resultados constantes como variación
  porcentual interanual: `(x[t] / x[t-1] - 1) * 100`. Las hojas
  `resultados-total-ind-2005` y `resultados-industrial-ind-2005` encadenan esas
  variaciones con base 2005=1. Se excluyen identificadores, `rotacion` y
  deflactores; se transforman los insumos y variables calculadas presentes en
  la hoja constante correspondiente.

**FUENTE OYANTHABAL — TASA DE GANANCIA URUGUAY — Agosto 2026:** se incorpora
una nueva fuente primaria online de Oyanthabal desde Google Sheets, preservada
como `data/input-data/oyanthabal/20260805_tasa_ganancia_uruguay_oyanthabal.xlsx`.
El procesamiento reproducible queda en
`command-files/processing-command-files/14_process_oyanthabal_tasa_ganancia.R`.
Ese script descarga la fuente si no existe localmente y exporta
`data/analysis-data/oyanthabal_tasa_ganancia_uruguay.csv` desde la hoja
`Uruguay`, conservando únicamente las columnas `anio`, `tg_total_b` y
`tg_no_agrario_b` para observaciones desde 2000 en adelante. La base procesada
contiene 25 filas para 2000-2024; `tg_total_b` queda faltante en 2024 y
`tg_no_agrario_b` queda faltante en 2022-2024, tal como figura en el XLSX
descargado. En la minuta visual de tres niveles se usa esta fuente para
comparar tasas en escala porcentual, no cocientes: `tasa_ganancia_pb` de EAAE
economía total frente a `tg_total_b`, y `tasa_ganancia_pb` de EAAE industria
manufacturera total frente a `tg_no_agrario_b`. El gráfico conserva sólo años
con ambos datos disponibles: 2001-2023 para economía total y 2001-2021 para
manufactura.

**FUENTE CIU — STOCK DE CAPITAL INDUSTRIAL — Agosto 2026:** se incorpora una
nueva fuente primaria online de la CIU sobre stock de capital fijo en maquinaria
y equipos de la industria, preservada como
`data/input-data/ciu-stock-capital/ciu_stock_capital_1988_2025.xlsx`. La
descarga debe hacerse desde la exportación completa del Google Sheets, sin
restringir por `gid`, porque la exportación de una sola hoja omite la hoja
`Serie Anual`. El libro completo contiene las hojas `Serie Anual`,
`Serie Trimestral` y `Metodología`.

El procesamiento reproducible queda en
`command-files/processing-command-files/15_process_ciu_stock_capital_industria.R`
y exporta
`data/analysis-data/ciu_stock_capital_industria_1988_2025.csv`. La base final
contiene una observación anual para 1988-2025. Para 1988-2011 usa la hoja
`Serie Anual`; para 2012-2025 usa la hoja `Serie Trimestral` filtrando el dato
de diciembre (`trimestre_referencia = 4`), según la instrucción del equipo. Las
variables principales son
`stock_capital_fijo_maquinaria_equipos_indice_dic_2008_100` y
`stock_capital_fijo_maquinaria_equipos_mill_usd`. La cobertura corresponde a
industria sin refinería ANCAP ni empresas de zonas francas. La columna
`fuente_serie` distingue `serie_anual` y `serie_trimestral_diciembre`, para
dejar trazable el cambio de fuente interna desde 2012. El script valida
cobertura completa 1988-2025, ausencia de años duplicados y ausencia de
faltantes en índice y stock.

**FUENTE INE-UY — TIPO DE CAMBIO — Agosto 2026:** se incorpora la fuente
primaria online del INE Uruguay `Cotización monedas.xlsx`, preservada como
`data/input-data/INE-UY/20260805_cotizacion_monedas_ine_uy.xlsx`. El
procesamiento reproducible queda en
`command-files/processing-command-files/16_process_ine_tipo_cambio.R` y exporta
`data/analysis-data/20260805_ine_uy_tipo_cambio_dolar_diciembre.csv`. La base
selecciona, para cada año con datos, el último valor disponible de diciembre de
`Dólar.USA.Compra` y `Dólar.USA.Venta` en la hoja `Fuente BROU`. Para la
conversión del stock EAAE a dólares se usa `Dólar.USA.Venta`, por tratarse de
la cotización relevante para expresar pesos corrientes en dólares.

**COMPARACIÓN STOCK EAAE-CIU — Agosto 2026:** se crea el script reproducible
`command-files/processing-command-files/17_compare_eaae_ciu_stock_capital.py`
y la salida
`data/analysis-data/20260805_comparacion_stock_capital_eaae_ciu.csv`. La
comparación toma el stock industrial EAAE desde los cuadros originales de
activos fijos por tipo: C15 a dos dígitos en 2001, C11 en 2003-2005 y C7 en
2006-2010 y 2012-2024. Para hacer la serie comparable con CIU se extrae
directamente la columna `maquinaria y equipos` de la industria manufacturera y
se resta la maquinaria y equipos de `19_refinacion` (Rev.4) o su equivalente
Rev.3 `23`. No se usa `stock total - construcciones` porque eso mantendría
`otros` e `intangibles`. En 2002 y 2011 la comparación EAAE queda como NA,
porque no hay cuadro de activos fijos por tipo y no se imputa la composición
maquinaria/equipos para este ejercicio. Para 2001 se usa el cuadro C15 a dos
dígitos para mantener el total industrial y la refinería en el mismo universo;
esto explica que el total de activos fijos extraído no coincida con el stock
por letra del panel principal. La serie EAAE corriente en pesos se convierte a
dólares con la venta INE de diciembre y se deflacta con un proxy BCU construido
como deflactor implícito del VAB de subramas industriales excluyendo
refinación, base 2005=1; la serie resultante se expresa también como índice
2008=100. Esta deflactación es un proxy de precios sectoriales, no un deflactor
específico de bienes de capital.

### Granularidad de la base de datos final
- **Unidad de observación:** sector CIIU homologado × año
- **Identificadores únicos:** `seccion` (str, código homologado) + `anno` (int)
- **Clasificación de referencia:** CIIU Rev. 4 homologada hacia atrás
- **Cobertura sectorial mínima común observada:** sectores C, D_E, G, H_J, I.
  El año 2001 se incorpora desde el cuadro 1 por letra, Total del País. La
  sección F (Construcción) no aparece en los C1/C1.1 reales verificados para
  2008–2024, y la sección B falta en 2009–2011; no deben exigirse en la
  validación preliminar del panel C1.

### Granularidad potencial de subramas EAAE

**DECISIÓN METODOLÓGICA — Junio 2026:** si se construye una base de subramas
desde los datos originales EAAE para dialogar con el panel 2001–2024, el nivel
práctico recomendado es **división CIIU / dos dígitos**, no cuatro dígitos.

El panel final vigente permanece a nivel `anno + seccion`. Los archivos fuente
`C1`/`C1.1` de 2002–2024 tienen columnas `seccion`, `division` y
`descripcion`, por lo que permiten construir un artefacto separado a nivel de
división publicada. La clave tentativa sería:

`anno + ciiu_version + seccion_fuente + division`.

El año 2001 es una excepción: el RAR original trae carpetas `Letra`,
`2 Digitos` y `4 Digitos`. Ese detalle a cuatro dígitos no define una
granularidad comparable para toda la serie, porque no aparece como contrato
estable en los cuadros `C1`/`C1.1` de 2002–2024. Por lo tanto, una base a cuatro
dígitos solo debe tratarse como ejercicio puntual para 2001 o como insumo
auxiliar, no como panel comparable 2001–2024.

La documentación visualizable en GitHub queda en
`docs/methodology/20260617_desagregacion-subrama-eaae-2001-2024.md`.

**DECISIÓN METODOLÓGICA — Junio 2026:** a pedido del equipo, se construye una
salida industrial de subramas homogenizada hacia CIIU Rev.4, pero como
**grupos Rev.4 compatibles**, no como divisiones Rev.4 puras. La razón es que
algunas correspondencias Rev.3 → Rev.4 son uno-a-muchos, cambian de sección o
aparecen agrupadas en las fuentes publicadas. El flujo conserva dos artefactos:

- `YYYYMMDD_panel_eaae_industria_subramas_fuente.csv`: panel fuente con filas
  publicadas para manufactura, preservando `ciiu_version`, `seccion_fuente`,
  `division_publicada`, `descripcion_fuente` y una marca
  `usar_para_homologacion`.
- `YYYYMMDD_panel_eaae_industria_subramas_rev4_homologado.csv`: panel derivado
  por grupos Rev.4 compatibles, generado desde la codiguera operativa
  `command-files/config/eaae_industria_subramas_rev4_homologacion.csv`.
- `YYYYMMDD_validacion_panel_eaae_industria_subramas_rev4.csv`: validaciones
  tidy de cobertura, consistencia, reconciliación y mapeo.

El script reproducible es
`command-files/processing-command-files/11_build_eaae_industria_subramas.py`.
Para 2001 se usa `2 Digitos/EAE_cu1afe2_01.xls`, que publica divisiones para
empresas de 5 y más personas ocupadas. Por eso la reconciliación 2001 contra el
panel principal por letra queda como advertencia esperada: el panel principal
usa el cuadro por letra `Total del País`.

**PROCESAMIENTO INTEGRADO EAAE-BCU — Junio 2026:** se creó un panel largo para
integrar economía total, rama industrial y subramas manufactureras homologadas
con deflactores BCU y variables necesarias para tasa de ganancia.

Artefactos:

| Archivo | Contenido |
|---|---|
| `command-files/processing-command-files/13_build_panel_eaae_bcu_total_industria_subrama.R` | Script reproducible específico para construir el panel integrado. |
| `command-files/processing-command-files/eaae_subrama_capital_direct.py` | Helper de extracción directa de `consumo_capital_fijo`, `impuestos_netos` y `stock_capital` a nivel de subrama industrial desde los RAR EAAE. |
| `command-files/analysis-command-files/04_build_resultados_eaae_bcu_workbook.R` | Script reproducible para construir el libro XLSX de resultados largos desde el panel integrado. |
| `command-files/analysis-command-files/05_visualizar_resultados_eaae_bcu_subrama.R` | Script reproducible para construir el informe visual largo EAAE-BCU con sección adicional de subramas industriales. |
| `command-files/analysis-command-files/06_visualizar_resultados_eaae_bcu_tres_niveles.R` | Script reproducible para construir la minuta visual de tres niveles agregados y sus figuras fuente. |
| `data/analysis-data/20260706_panel_eeae_bcu_total_industria_subrama.csv` | Panel integrado EAAE-BCU con 288 observaciones: 24 de economía total, 24 de industria total y 240 de subramas industriales. |
| `data/analysis-data/20260706_resultados_eaae_bcu_total_industria_subrama.xlsx` | Libro de resultados en formato largo con hojas `metodología`, `eaae`, `check-calidad`, `resultados-corrientes`, `resultados-constantes`, `resultados-var-pct` y `resultados-ind-2005`. |
| `data/analysis-data/20260727_panel_eeae_bcu_total_industria_subrama.csv` | Panel integrado EAAE-BCU con 312 observaciones: 24 de economía total, 24 de industria total, 24 de industria manufacturera excluyendo papel/impresión y coque/refinación, y 240 de subramas industriales. |
| `data/analysis-data/20260727_resultados_eaae_bcu_total_industria_subrama.xlsx` | Libro de resultados en formato largo derivado del panel 20260727; agrega el filtro operativo `industria-sin-papel-coque-refinacion` en todas las hojas. |
| `docs/20260706_resultados_eaae_bcu_total_industria_subrama.md` | Informe visual en Markdown basado en el libro largo EAAE-BCU, con figuras agregadas y sección específica de subramas industriales. |
| `docs/20260806_resultados_eaae_bcu_tres_niveles.md` | Minuta visual actualizada para economía total, industria total e industria manufacturera depurada, con anexos de ganancia industrial, tasas por niveles seleccionados, comparación contra Oyanthabal y comparación de stock EAAE-CIU. |
| `output/figures/eaae_bcu_tres_niveles_20260806/` | Carpeta de 12 figuras PNG respaldadas para la minuta visual 20260806. |
| `docs/20260605_eaae_resultados_eaae_oyanthaabal_total_industria.md` | Informe visual EAAE/Oyanthabal para economía total e industria, con prefijo de fecha de elaboración. |
| `docs/methodology/20260706_minuta_panel_eeae_bcu_total_industria_subrama.md` | Minuta metodológica sobre homologación CIIU, deflactores, empalmes, rotaciones e imputaciones. |

Decisiones del panel integrado:

- La clave es `anno + nivel_panel + grupo_rev4_homologado`. En economía total
  e industria total, `grupo_rev4_homologado` queda vacío porque el agregado se
  identifica por `nivel_panel`.
- Para economía total se agregan las secciones del panel EAAE principal y se
  usa un deflactor implícito BCU del VAB de sectores de actividad. Las filas
  BCU usadas son `Subtotal` en base 1997,
  `VALOR AGREGADO BRUTO DE LOS SECTORES DE ACTIVIDAD` en base 2005 y
  `Total VAB` en base 2016. No se usa la fila de PIB total BCU porque incluye
  impuestos netos sobre productos y no reproduce la misma frontera contable
  del agregado EAAE por sectores.
- Para industria total y subramas se construye un deflactor implícito BCU del
  VAB (`vab_corriente_bcu / vab_constante_bcu`) y se empalma a base 2005=1.
  La serie principal usa base 1997 normalizada en 2005 para 2001–2005, base
  2005 para 2005–2016 y base 2016 encadenada por variaciones interanuales para
  2017–2024.
- **DECISIÓN 2026-06-29:** en este artefacto integrado, `deflactor_2005`
  replica `deflactor_vab_bcu_2005` para todos los niveles y
  `fuente_deflactor` queda como `bcu_indice_implicito_vab` en todas las filas.
  La columna `gdp_price_index_base_2005` de Oyanthabal/BCU ya no se exporta en
  `YYYYMMDD_panel_eeae_bcu_total_industria_subrama.csv`; sigue siendo válida
  para otros productos donde esté documentada, pero no para este panel
  integrado.
- El panel conserva trazabilidad del deflactor con `fuente_base_bcu`,
  `metodo_empalme_bcu`, `calidad_deflactor_bcu`, `codigos_bcu_deflactor` y
  `nota_deflactor_bcu`. En economía total, `calidad_deflactor_bcu =
  "directo_total_economia"` indica que el deflactor procede directamente del
  VAB agregado de sectores publicado por BCU.
- **DECISIÓN 2026-07-06:** se incorpora la columna
  `rotacion_calibrada_sobre_6_6` desde
  `data/input-data/damodaran/20260630_rotacion_damodaran_eaae.xlsx`, hoja
  `Resumen`, usando las columnas `rama` y `rotacion_calibrada_sobre_6_6`. Las
  etiquetas de `rama` se armonizan contra `descripcion_nivel` del panel
  integrado. El valor es constante para todos los años dentro de cada nivel:
  `4,2` para `Economia total EAAE`, `6,6` para
  `Industria manufacturera EAAE` y valores específicos para cada subrama
  industrial. Desde esta actualización, esta es la rotación operativa usada
  para calcular `capital_variable_adelantado`,
  `capital_circulante_constante_adelantado`,
  `capital_circulante_adelantado`, `capital_total_adelantado` y las tasas de
  ganancia del panel integrado. La columna genérica `rotacion` deja de
  exportarse en `YYYYMMDD_panel_eeae_bcu_total_industria_subrama.csv`.
- Para economía total y rama industrial, `consumo_capital_fijo`,
  `stock_capital` y `stock_capital_imputado` se toman del panel EAAE principal.
- Para subramas industriales, `consumo_capital_fijo`, `impuestos_netos` y
  `stock_capital` se extraen directamente desde los RAR EAAE preservando la
  división publicada antes de homologar a grupos Rev.4 compatibles. Las fuentes
  son C2/C2.1 para consumo de capital fijo; C15 a dos dígitos para el stock de
  2001; C11 para 2003-2005; y C7 para 2006-2010 y 2012-2024.
- En subramas, `stock_capital` queda vacío sólo en 2002 y 2011 porque no hay
  cuadro de activos fijos publicado. `stock_capital_imputado` se completa con
  la regla histórica por subrama: promedio del ratio
  `stock_capital / consumo_capital_fijo` de 2003-2005 para imputar 2002 y de
  2012-2024 para imputar 2011.
- La salida incluye columnas metodológicas `metodo_capital_eaae`,
  `metodo_stock_capital`, `metodo_consumo_capital_fijo` y
  `calidad_capital_eaae`, además de `codigos_capital_fuente` y
  `archivos_capital_fuente` para trazabilidad de los cuadros usados.
- **DECISIÓN 2026-07-27:** se agrega el nivel derivado
  `industria_sin_papel_coque_refinacion`, identificado en el libro como
  `industria-sin-papel-coque-refinacion`. Se construye anualmente desde las
  subramas industriales homologadas, excluyendo
  `17_18_papel_impresion` y `19_refinacion`. Las tasas de ganancia de este
  nivel se recalculan como `sum(ganancia) / sum(capital_total_adelantado)`;
  no se promedian tasas subramales. Los insumos de capital adelantado se suman
  desde las subramas incluidas. Como no existe una fila Damodaran propia para
  este agregado, `rotacion_calibrada_sobre_6_6` se reporta como rotación
  implícita agregada:
  `(costo_laboral + consumo_intermedio) / capital_circulante_adelantado`.
  El deflactor BCU del agregado se deriva desde las subramas incluidas y
  conserva las advertencias de calidad de los proxies usados por cada
  componente.
- **DECISIÓN 2026-07-06:** el libro
  `20260706_resultados_eaae_bcu_total_industria_subrama.xlsx` replica la lógica
  de resultados del libro EAAE 20260605, pero en formato largo. La columna
  `seccion` opera como filtro: `economia_total` para el agregado de la economía,
  `industria-total` para industria manufacturera agregada y el código
  `grupo_rev4_homologado` para cada subrama industrial. La columna
  `seccion_fuente_panel` conserva la sección original del CSV integrado, que en
  subramas es `C`. Las hojas de resultados constantes deflactan las variables
  monetarias con `deflactor_2005`, que procede de los índices BCU empalmados.
- **DECISIÓN 2026-07-27:** el libro
  `20260727_resultados_eaae_bcu_total_industria_subrama.xlsx` mantiene las
  mismas siete hojas largas del libro 20260706, pero eleva la cobertura a 312
  filas por hoja de datos al incorporar el nivel
  `industria-sin-papel-coque-refinacion`.
- **NOTA OPERATIVA 2026-08-05:** en el panel integrado 20260727 y en el libro
  XLSX derivado existe descomposición explícita para manufactura total y
  manufactura depurada. En el CSV, los niveles se identifican como
  `industria_total` e `industria_sin_papel_coque_refinacion`; en el XLSX, la
  columna `seccion` usa `industria-total` e
  `industria-sin-papel-coque-refinacion`. Para ambos agregados, `vab_pp` y
  `vab_pb_estimado` cubren 2001-2024, mientras `vab_pb` directo sólo cubre
  2017-2024. `fbcf` y `fbkf_maq_eq` están disponibles para ambos agregados,
  con faltantes en 2002 y 2011 por ausencia de cuadro FBCF en las fuentes. A
  nivel de subrama existe `participacion_vab_pp_rama_c`; no se exporta una
  participación explícita de FBCF, pero puede calcularse como
  `fbcf_subrama / fbcf_industria_total` o contra la manufactura depurada según
  el denominador analítico.
- **DECISIÓN 2026-07-06:** el informe
  `docs/20260706_resultados_eaae_bcu_total_industria_subrama.md` replica la
  lógica argumental de
  `docs/20260605_eaae_resultados_eaae_oyanthaabal_total_industria.md`, pero usa
  el libro largo EAAE-BCU y agrega una sección específica para subramas
  industriales. Las figuras se guardan en
  `output/figures/eaae_bcu_total_industria_subrama/`.
- **ACTUALIZACIÓN 2026-08-06:** la minuta visual de tres niveles se renombra y
  actualiza como `docs/20260806_resultados_eaae_bcu_tres_niveles.md`, con
  figuras en `output/figures/eaae_bcu_tres_niveles_20260806/`. El informe
  declara que todos los resultados construidos provienen de EAAE y que los
  índices de precios de BCU se usan para deflactar valores corrientes. Todas
  las figuras reportan como fuente: "Elaboración propia en base a EAAE.
  Índices de precios extraídos de BCU.", salvo la comparación con Oyanthabal,
  que agrega esa fuente explícitamente. La comparación EAAE/Oyanthabal grafica
  tasas en escala porcentual, sin dividir las series. En el gráfico de tasa de
  ganancia en tres niveles se agrega una línea punteada con el promedio de la
  industria manufacturera en cada panel. El gráfico de productividad del
  trabajo se divide en dos paneles: `vab_pb_estimado / puestos_trabajo` y
  `vab_pp / puestos_trabajo`, ambos en precios constantes e índice 2005=1. La
  actualización mantiene el gráfico
  de representatividad de manufactura depurada, la comparación de tasas de
  ganancia EAAE/Oyanthabal, etiquetas de quiebres en tasas de ganancia,
  inversión diferenciada entre manufactura total y depurada, y un anexo con
  ganancia industrial en índice de volumen y tasas a precios básicos y
  productor para economía total, manufactura total, manufactura depurada,
  coque/refinación y papel/impresión/reproducción.

### Entorno de trabajo
- **Sistema operativo:** Linux (local)
- **IDE:** Positron (IDE de Posit, basado en VS Code; soporta Python y R)
- **Lenguaje del pipeline ETL:** Python 3.10+
- **Lenguaje del análisis estadístico:** R (scripts separados, no parte de este pipeline)
- **Gestor de entorno Python:** ninguno definido; instalar dependencias con `pip`
- **Formato de salida final:** CSV completo y Excel de revisión, ambos con
  prefijo `YYYYMMDD`

---

## §2. ESTRUCTURA DE CARPETAS — PROJECT TIER 4.0

La estructura sigue estrictamente el protocolo Project TIER 4.0
(Teaching Integrity in Empirical Research, Haverford College).

```
economia-uruguay/                        ← raíz del proyecto
│
├── CONTEXT.md                           ← ESTE ARCHIVO (fuente de verdad)
├── README.md                            ← descripción pública del proyecto
├── requirements.txt                     ← dependencias Python del pipeline
│
├── data/
│   ├── input-data/                      ← TIER: datos originales, SOLO LECTURA
│   │   ├── eaae/
│   │   │   └── [archivos .rar descargados del INE, uno por año]
│   │   └── metadata/
│   │       ├── eaae_codebook.md         ← descripción de variables y cuadros
│   │       └── ciiu_equivalencias.csv   ← mapeo Rev.3 ↔ Rev.4 (cuando se defina)
│   │
│   └── analysis-data/                   ← TIER: datos procesados
│       ├── YYYYMMDD_panel_eaae.csv      ← BASE COMPLETA FECHADA
│       └── YYYYMMDD_panel_eaae.xlsx     ← LIBRO DE REVISIÓN FECHADO
│
├── command-files/                       ← TIER: todos los scripts
│   ├── config/
│   │   └── eaae_config.py               ← diccionario EAAE_CONFIG (ver §4)
│   │
│   ├── processing-command-files/        ← TIER: ETL (descarga → panel limpio)
│   │   ├── 01_download.py               ← descarga RAR desde portal INE
│   │   ├── 02_extract_c1.py             ← extracción cuadro C1/C1.1
│   │   ├── 03_extract_otros.py          ← extracción cuadros adicionales (FBCF, etc.)
│   │   ├── 04_validate_extraction.py    ← validación post-extracción (checkpoint 1)
│   │   ├── 05_build_panel.py            ← ensamble del panel y variables derivadas
│   │   └── 06_validate_panel.py         ← validación del panel final (checkpoint 2)
│   │
│   └── analysis-command-files/          ← TIER: análisis (R o Python, fuera del ETL)
│       └── [scripts de análisis — a definir por el investigador]
│
└── output/
    ├── figures/
    └── tables/
```

### Reglas TIER que el agente debe respetar sin excepción

1. **`data/input-data/` es de solo lectura.** Ningún script escribe allí.
   Los RAR se descargan directamente a esa carpeta y nunca se modifican.

2. **Los archivos finales de cada versión** son
   `data/analysis-data/YYYYMMDD_panel_eaae.csv` y
   `data/analysis-data/YYYYMMDD_panel_eaae.xlsx`. Los archivos intermedios
   (DataFrames parciales por año) no se persisten en disco salvo que el
   investigador lo indique; el pipeline los procesa en memoria.

3. **Numeración de scripts:** los scripts de `processing-command-files/`
   tienen prefijo numérico (`01_`, `02_`, …) que indica el orden de ejecución.
   Deben poder ejecutarse en ese orden desde la raíz con:
   ```bash
   python command-files/processing-command-files/01_download.py
   python command-files/processing-command-files/02_extract_c1.py
   # etc.
   ```

4. **Reproducibilidad:** cada script produce el mismo resultado dado el mismo
   input. No usar seeds aleatorios ni rutas absolutas. Todas las rutas son
   relativas a la raíz del proyecto.

5. **Sin hardcoding:** ningún valor de configuración (rutas, nombres de
   archivo, número de filas de encabezado, etc.) va dentro de los scripts.
   Todo se lee desde `command-files/config/eaae_config.py`.

6. **Decisiones de diseño:** documentar en el código con el prefijo
   `# DECISION:` toda elección no trivial de implementación.

---

## §3. FUENTE DE DATOS: EAAE INE URUGUAY

### Acceso
```
URL del portal:
https://www.gub.uy/instituto-nacional-estadistica/datos-y-estadisticas/
estadisticas/series-encuesta-anual-actividad-economica-eaae

Formato de los archivos: .rar (uno por año calendario)
Contenido de cada RAR: archivos .xls (Excel 97-2003, formato BIFF8)
Destino local de descarga: data/input-data/eaae/
```

### Fuente primaria adicional: EAE 1998-2001 a 2 dígitos

**INCORPORADO — Junio 2026:** se descargaron cuatro libros Excel externos con
resultados de la Encuesta de Actividad Económica a **2 dígitos de actividad
económica** para los años 1998, 1999, 2000 y 2001. La fuente corresponde a
archivos publicados en la página de Series Económicas de la Unidad de Métodos y
Acceso a Datos, Facultad de Ciencias Sociales, Udelar.

Destino local de descarga:

`data/input-data/eaae-1998-2001/`

Archivos originales preservados:

| Año | Archivo local | URL de origen |
|---|---|---|
| 1998 | `EAE_1998_2DIG.xls` | `https://cienciassociales.edu.uy/wp-content/uploads/2019/12/1_EAE_1998_2DIG.xls` |
| 1999 | `EAE_1999_2DIG.xls` | `https://cienciassociales.edu.uy/wp-content/uploads/2019/12/1_EAE_1999_2DIG.xls` |
| 2000 | `EAE_2000_2DIG.xls` | `https://cienciassociales.edu.uy/wp-content/uploads/2019/12/1_EAE_2000_2DIG.xls` |
| 2001 | `EAE_2001_2DIG.xls` | `https://cienciassociales.edu.uy/wp-content/uploads/2019/12/1_EAE_2001_2DIG.xls` |

Verificación inicial: los cuatro archivos son libros Excel 97-2003 (`.xls`) y
`readxl` abre 37 hojas en cada uno.

**DECISIÓN:** estos archivos quedan como fuente primaria histórica separada de
los RAR oficiales EAAE 2001-2024 ya usados por el pipeline. No se transforman ni
se integran al panel EAAE vigente en esta etapa. Si se decide extender o
contrastar la serie a nivel de divisiones, cualquier derivado debe construirse
con un script reproducible bajo `command-files/` y escribirse en
`data/analysis-data/`.

**PROCESAMIENTO — Junio 2026:** se creó
`command-files/processing-command-files/10_process_eaae_1998_2001_2dig.R` para
producir un panel histórico reutilizable:

`data/analysis-data/eaae_1998_2001_2dig_panel.csv`

Decisiones de procesamiento:

- Se procesa únicamente el universo `empresas_5_mas` porque el bloque
  `empresas_5_49` es un subconjunto y no debe sumarse ni duplicarse.
- No se persiste una base larga de auditoría. Las validaciones quedan dentro
  del script reproducible.
- La clave operativa es `anno + seccion_fuente + division_publicada`. Se
  conserva `seccion_fuente` Rev.3 y se agrega `seccion` homologada con la misma
  regla del panel EAAE vigente.
- Se conserva `division_publicada` tal como aparece en la fuente. Varias filas
  son grupos publicados (`15-16`, `17-18-19`, etc.), no divisiones atómicas.
- Las variables monetarias se convierten desde miles de pesos corrientes a
  pesos corrientes. `puestos_trabajo` no se escala.
- El cuadro 1 alimenta `vbp_pp`, `vab_pp`, `remuneraciones` y
  `puestos_trabajo`. El cuadro 2 alimenta `consumo_intermedio`,
  `impuestos_netos`, `consumo_capital_fijo` y `excedente_explotacion`. Los
  cuadros 14, 15, 16 y 17 alimentan FBCF, stock de capital, variación de
  existencias y componentes de FBKF.
- Anomalía de fuente: en `EAE_1999_2DIG.xls`, las hojas 2, 14, 15, 16 y 17
  están encabezadas como año 2000 y coinciden con las hojas del archivo 2000.
  El script las omite. Por eso 1999 conserva sólo variables del cuadro 1
  confiable: total, manufactura y subramas manufactureras; las variables de
  consumo intermedio, cuentas, FBCF, stock y existencias quedan como NA para
  ese año.

Validaciones actuales: clave única sin duplicados; sin columnas completamente
vacías; identidades `vbp_pp = consumo_intermedio + vab_pp`,
`vab_pp = impuestos_netos + consumo_capital_fijo + remuneraciones +
excedente_explotacion` y chequeos de FBCF cierran para los años con cuadros
completos.

### Fuente primaria adicional: Encuesta Industrial Anual 1989-1997

**INCORPORADO — Junio 2026:** se descargó una serie histórica externa de la
Encuesta Industrial Anual desde la página "Series Económicas" de la Unidad de
Métodos y Acceso a Datos, Facultad de Ciencias Sociales, Udelar:

```
URL de referencia:
https://cienciassociales.edu.uy/servicios/unidad-de-metodos-y-acceso-a-datos/series-economicas/

Destino local de descarga:
data/input-data/EIA 1989-1997/
```

Archivos originales preservados:

| Año | Archivo local |
|---|---|
| 1989 | `Encuesta-industrial-anual-1989.xls` |
| 1990 | `Encuesta-industrial-anual-1990.xls` |
| 1991 | `Encuesta-industrial-anual-1991.xlsx` |
| 1992 | `Encuesta-industrial-anual-1992.xls` |
| 1993 | `Encuesta-industrial-anual-1993.xls` |
| 1994 | `Encuesta-industrial-anual-1994.xls` |
| 1995 | `Encuesta-industrial-anual-1995.xls` |
| 1996 | `Encuesta-industrial-anual-1996.xls` |
| 1997 | `Encuesta-industrial-anual-1997.xls` |

**DECISION:** estos archivos quedan como fuente primaria histórica en
`data/input-data/`. No se transforman ni se integran al panel EAAE 2001-2024 en
esta etapa. Cualquier base tidy derivada de esta serie debe construirse en un
script reproducible bajo `command-files/` y escribirse en `data/analysis-data/`.

**PROCESAMIENTO CONSOLIDADO — Junio 2026:** el script vigente para EIA es
`command-files/processing-command-files/09_process_eia_1989_1997.R`. El flujo
queda focalizado en construir un panel comparable con la hoja `rama-C` del
panel EAAE, a nivel de total industrial CIIU Rev.2 (`3`) y división industrial
CIIU Rev.2 (`31`–`39`). La extracción se hace desde los Excel originales,
detectando cuadros por encabezado real y no por número de hoja, porque la
posición de las hojas cambia entre archivos.

Artefactos derivados:

| Archivo | Contenido |
|---|---|
| `data/analysis-data/20260623_panel_eia_1989_1997_2dig.csv` | Panel EIA consolidado para tasa de ganancia: total industrial Rev.2 (`3`) y divisiones industriales Rev.2 (`31`–`39`), con nombres equivalentes a `rama-C` del panel EAAE. |
| `data/analysis-data/20260623_panel_eia_1989_1997_2dig.xlsx` | Libro Excel derivado del panel EIA consolidado. Contiene hoja `eia` con el panel y hoja `check-calidad` con validaciones equivalentes a las del libro EAAE para cada subrama y total industrial. |

Artefactos retirados:

| Archivo | Motivo |
|---|---|
| `data/analysis-data/eia_1989_1997_cuadros_tidy.csv` | Reemplazado por el panel focalizado; contenía variables y niveles no necesarios para la tasa de ganancia. |
| `data/analysis-data/eia_1989_1997_panel.csv` | Reemplazado por el panel consolidado a dos dígitos y vocabulario EAAE. |
| `data/analysis-data/eia_1989_1997_validaciones.csv` | Reemplazado por validaciones internas del script consolidado. |

Decisiones de procesamiento:

- La fuente queda identificada como `ciiu_version = "Rev.2"` y `seccion`
  conserva el código original: `3` para el total de industrias manufactureras y
  `31`–`39` para divisiones industriales. No se homologan subramas Rev.2 hacia
  Rev.3/Rev.4 en esta etapa.
- El panel incorpora `seccion_etiqueta` para conservar una descripción legible
  de cada código de sección/división.
- El panel conserva solo las variables primarias necesarias para calcular la
  tasa de ganancia a precios productor con la lógica EAAE: `vbp_pp`, `vab_pp`,
  `consumo_intermedio`, `remuneraciones`, `consumo_capital_fijo`,
  `stock_capital` y `stock_capital_imputado`, más identificadores (`anno`,
  `seccion`, `seccion_etiqueta`, `epoca`, `ciiu_version`).
- `consumo_intermedio` es una variable directa de la EIA extraída desde el
  Cuadro 2. No se usa el nombre `consumo_intermedio_estimado` en este panel,
  porque ese nombre queda reservado al panel EAAE donde la variable se calcula.
- Las variables de cuentas salen del Cuadro 2 de cada año. El script adapta la
  posición de columnas por período: en 1989–1990 la depreciación/consumo de
  capital aparece como `D`; en 1991–1996 aparece como `depreciación`; en 1997
  aparece explícitamente como `consumo de capital fijo`. En todos los casos se
  registra con el nombre canónico `consumo_capital_fijo`.
- `stock_capital` conserva solo el dato original válido de activos fijos al
  31/12 encontrado en 1997, Cuadro 18. Los cuadros 18 de 1989–1996 son flujos
  de formación/adiciones de capital, no stock, y no se cargan como
  `stock_capital`.
- Para 1989–1996, `stock_capital_imputado` se calcula por división Rev.2 como
  `consumo_capital_fijo_t * (stock_capital_1997 / consumo_capital_fijo_1997)`.
  En 1997 replica `stock_capital`.
- No se incorporan FBCF, impuestos, excedente, ventas, compras, combustibles ni
  otros componentes porque no son insumos necesarios bajo la fórmula vigente de
  tasa de ganancia a precios productor.
- Validaciones internas del script: cobertura completa `anno + seccion` para
  1989–1997, total `3` y divisiones `31`–`39`; clave única, variables
  requeridas no nulas,
  `stock_capital` solo en 1997, `stock_capital_imputado` completo, e identidad
  `vbp_pp = consumo_intermedio + vab_pp`.
- El libro Excel EIA se genera con
  `command-files/processing-command-files/12_build_eia_1989_1997_workbook.py`
  desde el CSV consolidado. La hoja `check-calidad` replica los indicadores del
  libro EAAE para cada `anno + seccion`: `vab_vbp = vab_pp / vbp_pp`,
  `consumo_intermedio` directo, `remuneraciones_vab = remuneraciones / vab_pp`
  y `stock_vab = stock_capital_imputado / vab_pp`.
- Validación interpretativa del libro EIA: el XLSX se abre correctamente con
  `readxl`, contiene exactamente las hojas `eia` y `check-calidad`, y ambas
  tienen 90 filas. No se detectan casos básicos problemáticos en
  `check-calidad`: `vab_vbp` está entre 0 y 1, `remuneraciones_vab` no supera
  1 y `stock_vab` es positivo en todas las filas. Para el total industrial
  `seccion = 3`, `vab_vbp` se ubica entre 0,390 y 0,483;
  `remuneraciones_vab`, entre 0,288 y 0,366; y `stock_vab`, entre 0,400 y
  0,655. A nivel subrama hay mayor dispersión; los `stock_vab` más altos
  aparecen en `36` en 1990, `37` en 1991 y `34` en 1997. Estos valores no
  invalidan la base, pero conviene revisarlos al interpretar tasas porque el
  stock 1989–1996 es imputado.

### Cinco épocas estructurales

La serie 2001–2024 no es homogénea. El pipeline aplica lógica condicional
según época; no es un loop genérico.

```
ÉPOCA I   : 2001        78 XLS, 3 subcarpetas, CIIU Rev.3, cuadro 1 por letra
ÉPOCA II  : 2002–2005   4–13 XLS, raíz, CIIU Rev.3, cuadro C1, 7 columnas
ÉPOCA III : 2006–2007   10–20 XLS, 0–1 subcarpeta, CIIU Rev.3, cuadro C1, 7 columnas
ÉPOCA IV  : 2008–2016   2–18 XLS, 0–1 subcarpeta, CIIU Rev.4, C1/C1.1, 7 columnas
ÉPOCA V   : 2017–2024   11 XLS (fijo), 0–1 subcarpeta, CIIU Rev.4, C1.1, 9 columnas
```

### Quiebre de clasificación CIIU

El cambio de CIIU Rev.3 a Rev.4 ocurre entre 2007 y 2008.
La sección Manufactura pasa de letra **D** (Rev.3) a letra **C** (Rev.4).
**DECISIÓN METODOLÓGICA — Mayo 2026:** el panel final usa la opción B:
serie histórica homologada **2001–2024** con sectores agregados comparables.

Para ahorrar columnas innecesarias en el proceso de equivalencia, el panel final
no agrega columnas auxiliares como `seccion_original`, `homologacion_calidad` ni
`homologacion_nota`. La columna `seccion` contiene directamente el código
homologado. La columna `ciiu_version` se conserva como metadato de fuente
("Rev.3" para 2001–2007, "Rev.4" para 2008–2024).

Equivalencia operativa mínima para el panel:

| Sector homologado en `seccion` | CIIU Rev.3 | CIIU Rev.4 | Comentario |
|---|---|---|---|
| `B` | C | B | Minería y canteras |
| `C` | D | C | Manufactura |
| `D_E` | E | D + E | Energía, agua, saneamiento y residuos |
| `F` | F | F | Construcción |
| `G` | G | G | Comercio |
| `H_J` | I | H + J | Transporte, almacenamiento, información y comunicaciones |
| `I` | H | I | Alojamiento y comidas |

Si aparecen sectores de servicios fuera de la cobertura mínima, usar la misma
lógica de agregación documentada en `command-files/config/eaae_config.py`.

### Disponibilidad de variables por época

```
Variable                   Ép.I  Ép.II  Ép.III  Ép.IV  Ép.V
─────────────────────────────────────────────────────────────
VBP a precios productor      ~      ●      ●       ●      ●
VAB a precios productor      ~      ●      ●       ●      ●
VAB a precios básicos        ✗      ✗      ✗       ✗      ●   ← solo desde 2017
Remuneraciones               ~      ●      ●       ●      ●
Puestos de trabajo           ●      ●      ●       ●      ●   ← más consistente
FBCF                         ●      ~      ●       ~      ●
Adquisiciones importadas     ●      ~      ●       ~      ●
Stock de capital             ●      ~      ●       ~      ●
Variación de existencias     ●      ~      ✗       ✗      ✗
Excedente de explotación     ✗      ~      ~       ~      ●
Consumo intermedio           ✗      ~      ~       ~      ●

●  disponible sistemáticamente
~  disponible con discontinuidades o años faltantes
✗  no disponible
```

### Cuadros relevantes por época

```
Variable              Ép. I       Ép. II–III    Ép. IV    Ép. V
────────────────────────────────────────────────────────────────
VBP/VAB/Rem/Puestos   C1 letra    C1            C1/C1.1   C1.1
Consumo intermedio    C2 letra    C3            C3        C3
Consumo capital fijo  C2 letra    C2            C2/C2.1   C2.1
Impuestos netos       C2 letra    C2            C2/C2.1   C2.1
FBCF                  C8 letra    C10/C6        C6        C6
FBKF maq. y eq.       C11 letra   C13/C8        C8        C8
Adq. importadas       C8 letra    C10/C6        C6        C6
Adq. plaza orig. imp. —           C10/C6        C6        C6
Stock capital         C9 letra    C11/C7        C7        C7
Variación existencias C10 letra   C12/—         —         —
Excedente explot.     C2 letra    C6            C2/C2.1   C2.1
Remuner. detalle      —           C7            C4        C4
Puestos detalle       —           C7/C8         —         —
```

ATENCIÓN: los números de cuadro difieren entre épocas. En los XLS verificados,
`C4` no es FBCF en 2008–2024 sino remuneraciones; la FBCF está en `C6`.
El pipeline resuelve esto desde `EAAE_FBCF_CONFIG` en `eaae_config.py`.
`fbkf_maq_eq` se extrae desde la tabla de componentes de la FBKF: C11 en 2001,
C13 en 2003–2005 y C8 en 2006–2024; queda vacía en 2002 y 2011 porque no se
identificó cuadro compatible.
También se verificó que FBCF y `adquisiciones_importadas` usan C10 en
2003–2005, C6-F en 2006, y C6 desde 2007 en adelante. 2002 y 2011 no tienen
cuadro FBCF/adquisiciones en los RAR publicados.
La columna `adquisiciones_origen_importado` usa la apertura `En plaza / Origen
Imp.` (columna K) cuando existe: 2004–2010 y 2012–2024. En 2001 y 2003 la
fuente trae `En plaza` pero no desagrega origen nacional/importado, por lo que
esa variable y `importaciones_maquinaria` quedan vacías para esos años.
También se verificó que `C5` en 2006–2024 corresponde a impuestos y que `C8`
en 2017–2024 corresponde a FBCF por componentes, no a variación de
existencias. Un escaneo completo de encabezados y celdas de todos los XLS de
2006–2024 no encontró variables de existencias/inventarios.

---

## §4. CONFIGURACIÓN TÉCNICA VALIDADA

Los valores de `header_row` y `data_start_row` fueron verificados contra
los 24 archivos reales. El `file_pattern` fue probado con regex sobre
cada RAR. Este es el archivo `command-files/config/eaae_config.py`.

```python
# command-files/config/eaae_config.py
# ─────────────────────────────────────────────────────────────────────────────
# Diccionario central de configuración de la serie EAAE 2001-2024.
# VALORES VALIDADOS CONTRA ARCHIVOS REALES — no modificar sin reverificar.
#
# Convenciones:
#   header_row     : índice 0-based de la ÚLTIMA fila del encabezado de columnas
#   data_start_row : índice 0-based de la PRIMERA fila con código de sección CIIU
#                    (puede autodetectarse con detect_data_start(); ver §4.3)
#   file_pattern   : expresión regular para localizar el XLS dentro del RAR
#   rar_name       : nombre exacto del archivo RAR publicado por el INE
# ─────────────────────────────────────────────────────────────────────────────

ESQUEMA_7COL = [
    "seccion",         # col 0 — letra CIIU (ej: "C")
    "division",        # col 1 — código numérico (ej: "10")
    "descripcion",     # col 2 — texto
    "vbp_pp",          # Valor Bruto de Producción a precios de productor
    "vab_pp",          # Valor Agregado Bruto a precios de productor
    "remuneraciones",
    "puestos_trabajo",
]

ESQUEMA_9COL = [
    "seccion",
    "division",
    "descripcion",
    "vbp_pp",
    "vbp_pb",          # VBP a precios básicos — NUEVO desde 2017
    "vab_pp",
    "vab_pb",          # VAB a precios básicos — NUEVO desde 2017
    "remuneraciones",
    "puestos_trabajo",
]

EAAE_CONFIG = {

    # ── ÉPOCA I — 2001 ────────────────────────────────────────────────────────
    2001: {
        "epoca": 1,
        "subfolder": None,
        "file_pattern": None,        # sin cuadro equivalente a C1.1
        "header_row": None,
        "data_start_row": None,
        "columns": None,
        "cuadros": ["C1","C2","C3","C4","C5","C6","C7","C8","C9","C10","C11"],
        "rar_name": "Encuesta_de_Actividad_Económica_2001.rar",
        "notes": (
            "CASO ESPECIAL. Sin equivalente a C1.1. 78 archivos en 3 subcarpetas: "
            "Letra/, 2 Digitos/, 4 Digitos/. Segmenta por tamaño de empresa. "
            "CIIU Rev.3. Requiere lógica de extracción propia. "
            "Tratar como fuente auxiliar — ver §7.3."
        ),
    },

    # ── ÉPOCA II — 2002–2005 ──────────────────────────────────────────────────
    2002: {
        "epoca": 2, "subfolder": None,
        "file_pattern": r"EAE_C1_2002\.xls",
        "header_row": 6, "data_start_row": 8,  # solo 1 fila vacía tras encabezado
        "columns": ESQUEMA_7COL,
        "cuadros": ["C1", "C2", "C3", "C9"],   # solo 4 cuadros disponibles
        "rar_name": "Encuesta_de_Actividad_Económica_2002.rar",
        "notes": "Solo 4 cuadros disponibles. CIIU Rev.3.",
    },
    2003: {
        "epoca": 2, "subfolder": None,
        "file_pattern": r"EAE_C1_2003\.xls",
        "header_row": 6, "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 14)],
        "rar_name": "Encuesta_de_Actividad_Económica_2003.rar",
        "notes": "CIIU Rev.3.",
    },
    2004: {
        "epoca": 2, "subfolder": None,
        "file_pattern": r"EAE_C1_2004\.xls",
        "header_row": 7, "data_start_row": 9,  # fila 4 vacía adicional
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 14)],
        "rar_name": "Encuesta_de_Actividad_Económica_2004.rar",
        "notes": "Fila 4 vacía extra → header_row=7 (vs. 6 en 2003/2005). CIIU Rev.3.",
    },
    2005: {
        "epoca": 2, "subfolder": None,
        "file_pattern": r"EAE_C1_2005\.xls",
        "header_row": 6, "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 14)],
        "rar_name": "Encuesta_de_Actividad_Económica_2005.rar",
        "notes": "CIIU Rev.3.",
    },

    # ── ÉPOCA III — 2006–2007 ─────────────────────────────────────────────────
    2006: {
        "epoca": 3, "subfolder": None,
        "file_pattern": r"EAE_C1-F_2006\.xls",  # sufijo -F (empresas forzosas)
        "header_row": 7, "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 11)],
        "rar_name": "Encuesta_de_Actividad_Económica_2006.rar",
        "notes": "Archivos con sufijo -F. CIIU Rev.3.",
    },
    2007: {
        "epoca": 3,
        "subfolder": "Forzosas y aleatorias",  # subcarpeta donde están los XLS
        "file_pattern": r"EAE_C1_2007\.xls",
        "header_row": 7, "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 11)],
        "rar_name": "Encuesta_de_Actividad_Económica_2007.rar",
        "notes": (
            "Cuadros duplicados: forzosas y aleatorias. "
            "Usar versión dentro de subcarpeta 'Forzosas y aleatorias/'. "
            "CIIU Rev.3."
        ),
    },

    # ── ÉPOCA IV-a — 2008–2012 ────────────────────────────────────────────────
    2008: {
        "epoca": 4, "subfolder": None,
        "file_pattern": r"EAE_C1_2008\.xls",
        "header_row": 7, "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 9)],
        "rar_name": "Encuesta_de_Actividad_Económica_2008.rar",
        "notes": "PRIMER AÑO con CIIU Rev.4. Manufactura = sección C.",
    },
    2009: {
        "epoca": 4, "subfolder": None,
        "file_pattern": r"EAE_C1_2009\.xls",
        "header_row": 7, "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 9)],
        "rar_name": "Encuesta_de_Actividad_Económica_2009.rar", "notes": "",
    },
    2010: {
        "epoca": 4, "subfolder": None,
        "file_pattern": r"EAE_C1_2010\.xls",
        "header_row": 7, "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 9)],
        "rar_name": "Encuesta_de_Actividad_Económica_2010.rar", "notes": "",
    },
    2011: {
        "epoca": 4, "subfolder": None,
        "file_pattern": r"EAE_C1_2011\.xls",
        "header_row": 7, "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": ["C1", "C2"],               # edición incompleta en la fuente
        "rar_name": "Encuesta_de_Actividad_Económica_2011.rar",
        "notes": "SOLO 2 cuadros disponibles. Edición incompleta publicada por INE.",
    },
    2012: {
        "epoca": 4, "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2012\.xls",
        "header_row": 7, "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": (
            [f"C1.{n}" for n in range(1, 7)] +
            [f"C2.{n}" for n in range(1, 7)] +
            [f"C{n}"   for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2012.rar",
        "notes": "Primera aparición de subíndice decimal en nombre de cuadro (C1.1).",
    },

    # ── ÉPOCA IV-b — 2013–2016 ────────────────────────────────────────────────
    # Fila 3 agrega texto "Valorado a precios de productor..."
    # → header_row=6 y data_start_row=9 (un índice menos que en 2012)
    2013: {
        "epoca": 4, "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2013\.xls",
        "header_row": 6, "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": (
            [f"C1.{n}" for n in range(1, 7)] +
            [f"C2.{n}" for n in range(1, 7)] +
            [f"C{n}"   for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2013.rar",
        "notes": "Fila 3 agrega 'Valorado a pp...' vs. 2012 → data_start=9.",
    },
    2014: {
        "epoca": 4, "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2014\.xls",
        "header_row": 6, "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": (
            [f"C1.{n}" for n in range(1, 7)] +
            [f"C2.{n}" for n in range(1, 7)] +
            [f"C{n}"   for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2014.rar", "notes": "",
    },
    2015: {
        "epoca": 4, "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2015\.xls",
        "header_row": 6, "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": (
            [f"C1.{n}" for n in range(1, 7)] +
            [f"C2.{n}" for n in range(1, 7)] +
            [f"C{n}"   for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2015.rar", "notes": "",
    },
    2016: {
        "epoca": 4,
        "subfolder": "Encuesta de Actividad Económica 2016",
        "file_pattern": r"EAE_C1\.1_2016\.xls",
        "header_row": 6, "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": (
            [f"C1.{n}" for n in range(1, 7)] +
            [f"C2.{n}" for n in range(1, 7)] +
            [f"C{n}"   for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2016.rar",
        "notes": "Archivos dentro de subcarpeta con nombre completo del año.",
    },

    # ── ÉPOCA V — 2017–2024 ───────────────────────────────────────────────────
    2017: {
        "epoca": 5,
        "subfolder": "Encuesta de Actividad Económica 2017",
        "file_pattern": r"EAE_C1\.1_?\s?2017\.xls",  # hay un espacio antes del año
        "header_row": 7, "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": (
            ["C1.1", "C1.2", "C1.3", "C2.1", "C2.2"] +
            [f"C{n}" for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2017.rar",
        "notes": (
            "PRIMER AÑO con 9 columnas (agrega vbp_pb, vab_pb). "
            "Nombre real del XLS: 'EAE_C1.1_ 2017.xls' (espacio antes del año). "
            "El file_pattern ya incorpora \\s? para tolerarlo."
        ),
    },
    2018: {
        "epoca": 5,
        "subfolder": "Encuesta de Actividad Económica 2018",
        "file_pattern": r"EAE_C1\.1_2018\.xls",
        "header_row": 7, "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": (
            ["C1.1", "C1.2", "C1.3", "C2.1", "C2.2"] +
            [f"C{n}" for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2018.rar", "notes": "",
    },
    2019: {
        "epoca": 5,
        "subfolder": "Encuesta de Actividad Económica 2019",
        "file_pattern": r"EAE_C1\.1_2019\.xls",
        "header_row": 7, "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": (
            ["C1.1", "C1.2", "C1.3", "C2.1", "C2.2"] +
            [f"C{n}" for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2019.rar", "notes": "",
    },
    2020: {
        "epoca": 5, "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2020\.xls",
        "header_row": 7, "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": (
            ["C1.1", "C1.2", "C1.3", "C2.1", "C2.2"] +
            [f"C{n}" for n in range(3, 9)]
        ),
        # ANOMALÍA: nombre de RAR completamente distinto al patrón de la serie
        "rar_name": "Principales_indicadores_y_desagregaciones_2020.rar",
        "notes": "ANOMALÍA: nombre del RAR distinto al patrón general de la serie.",
    },
    2021: {
        "epoca": 5, "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2021\.xls",
        "header_row": 7, "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": (
            ["C1.1", "C1.2", "C1.3", "C2.1", "C2.2"] +
            [f"C{n}" for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2021.rar", "notes": "",
    },
    2022: {
        "epoca": 5, "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2022\.xls",
        "header_row": 7, "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": (
            ["C1.1", "C1.2", "C1.3", "C2.1", "C2.2"] +
            [f"C{n}" for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2022.rar", "notes": "",
    },
    2023: {
        "epoca": 5, "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2023\.xls",
        "header_row": 7, "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": (
            ["C1.1", "C1.2", "C1.3", "C2.1", "C2.2"] +
            [f"C{n}" for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2023.rar", "notes": "",
    },
    2024: {
        "epoca": 5, "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2024\.xls",
        "header_row": 7, "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": (
            ["C1.1", "C1.2", "C1.3", "C2.1", "C2.2"] +
            [f"C{n}" for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2024.rar",
        "notes": "Último año disponible al momento de documentar (mayo 2026).",
    },
}
```

### Detección automática de data_start_row

Usar esta función como valor primario; `EAAE_CONFIG[year]["data_start_row"]`
solo como fallback y para validación cruzada.

```python
import re

def detect_data_start(ws) -> int:
    """
    Retorna el índice 0-based de la primera fila donde la columna 0
    contiene exactamente una letra mayúscula (código de sección CIIU).
    Válido para épocas I–V. En 2001 detecta la primera sección posterior
    a la fila de Total.
    Lanza ValueError si no encuentra la fila.
    """
    for i in range(ws.nrows):
        val = str(ws.cell_value(i, 0)).strip()
        if re.match(r'^[A-Z]$', val):
            return i
    raise ValueError(
        f"No se encontró fila de inicio de datos (sección CIIU) "
        f"en las primeras {ws.nrows} filas."
    )
```

---

## §5. FASES DEL PIPELINE

El pipeline tiene seis fases secuenciales. Cada fase produce un artefacto
verificable. **No avanzar a la siguiente fase sin superar la validación de
la anterior.**

```
FASE 0 → Setup del entorno y estructura de carpetas
FASE 1 → Descarga de archivos RAR desde portal INE
FASE 2 → Extracción del cuadro C1/C1.1 por año
FASE 3 → Extracción de cuadros adicionales (FBCF, excedente, etc.)
FASE 4 → CHECKPOINT 1: Validación de la extracción
FASE 5 → Ensamble del panel y construcción de variables derivadas
FASE 6 → CHECKPOINT 2: Validación y exportación del panel final → YYYYMMDD_panel_eaae.csv + YYYYMMDD_panel_eaae.xlsx
```

### Orden de implementación recomendado dentro de Fases 2–3

Implementar y validar en este orden antes de continuar:

```
1. Época V (2017–2024)   → 8 años, 11 archivos c/u, 9 columnas, estructura
                            idéntica. Tramo más limpio. Implementar aquí primero.
2. Época IV (2008–2016)  → mismas variables, 7 columnas, dos sub-épocas
                            (2008–2012 vs. 2013–2016, data_start diferente).
3. Épocas II–III (2002–2007) → CIIU Rev.3, patrón de nombre diferente en 2006.
4. Época I (2001)        → caso especial incluido: cuadro 1 por letra, Total del País.
```

---

## §6. ESPECIFICACIÓN DEL PANEL FINAL

### Estructura de `data/analysis-data/YYYYMMDD_panel_eaae.csv`

El CSV contiene la base completa `panel_eaae`.

### Estructura de `data/analysis-data/YYYYMMDD_panel_eaae.xlsx`

El libro contiene cinco hojas base y ocho hojas de resultados propios:

- `eaae`: base completa.
- `rama-C`: registros de la rama de actividad `C`.
- `check-calidad-C`: controles anuales para la rama `C`: `vab_vbp`,
  `consumo_intermedio_estimado`, `remuneraciones_vab` y `stock_vab`.
- `economia_total`: agregacion anual de todas las variables del panel.
- `check-calidad-total`: controles anuales para `economia_total`: `vab_vbp`,
  `consumo_intermedio_estimado`, `remuneraciones_vab` y `stock_vab`.
- `resultados-total-corrientes`: cálculos propios del equipo para la economía total,
  en pesos corrientes.
- `resultados-industrial-corrientes`: cálculos propios del equipo para la rama
  industrial `C`.
- `resultados-total-constante`: cálculos propios del equipo para la economía total,
  en precios de 2005.
- `resultados-industrial-constante`: cálculos propios del equipo para la rama
  industrial `C`, en precios de 2005.
- `resultados-total-var-pct`: variaciones interanuales porcentuales de la hoja
  `resultados-total-constante`.
- `resultados-industrial-var-pct`: variaciones interanuales porcentuales de la
  hoja `resultados-industrial-constante`.
- `resultados-total-ind-2005`: índices encadenados con 2005=1 a partir de
  `resultados-total-var-pct`.
- `resultados-industrial-ind-2005`: índices encadenados con 2005=1 a partir de
  `resultados-industrial-var-pct`.

```
Columnas de identificación:
  anno          int     Año calendario (2001–2024)
  seccion       str     Sector CIIU homologado (ej: "C", "D_E", "H_J")
  epoca         int     Época estructural de la fuente (1–5)
  ciiu_version  str     "Rev.3" para 2001–2007, "Rev.4" para 2008–2024

Columnas de variables (pesos uruguayos corrientes):
  vbp_pp        float   Valor Bruto de Producción, precios de productor
  vbp_pb        float   Valor Bruto de Producción, precios básicos (NaN antes de 2017)
  vab_pp        float   Valor Agregado Bruto, precios de productor
  vab_pb        float   VAB, precios básicos (NaN antes de 2017)
  vab_pb_estimado float VAB a precios básicos observado desde 2017 y retroproyectado antes de 2017
  consumo_intermedio_estimado float Consumo intermedio estimado como vbp_pp - vab_pb_estimado
  capital_circulante_constante_adelantado float Consumo intermedio estimado dividido por factor de rotación
  remuneraciones float  Remuneraciones al trabajo asalariado
  capital_variable_adelantado float Remuneraciones divididas por factor de rotación
  puestos_trabajo float Puestos de trabajo ocupados
  n_empresas   float   Cantidad de empresas representadas en el marco muestral, por sección homologada
  fbcf          float   Formación Bruta de Capital Fijo (NaN donde no disponible)
  fbkf_maq_eq   float   Subtotal de FBKF en maquinaria y equipos (NaN donde no disponible)
  adquisiciones_importadas float Adquisiciones importadas dentro de FBCF
  adquisiciones_origen_importado float Adquisiciones en plaza de origen importado dentro de FBCF
  importaciones_maquinaria float adquisiciones_importadas + adquisiciones_origen_importado
  consumo_capital_fijo float Consumo de capital fijo
  impuestos_netos float Impuestos sobre la producción y productos netos de subsidios
  stock_capital float Valor de activos fijos al 31/12 (NaN donde no disponible)
  stock_capital_imputado float Stock fijo operativo = stock_capital si existe; si no, imputación histórica definida
  capital_total_adelantado float Stock fijo + capital variable adelantado + capital circulante constante adelantado
  vab_bcu_corriente float VAB corriente BCU en pesos corrientes, solo en hojas resultados-*-corrientes
  vab_eaae_bcu_pct float Comparación EAAE/BCU del VAB corriente: vab_pp / vab_bcu_corriente * 100, solo en hojas resultados-*-corrientes

Columnas derivadas calculadas en pipeline:
  capital_circulante_constante_adelantado float = consumo_intermedio_estimado / factor_rotacion
  capital_variable_adelantado float = remuneraciones / factor_rotacion
  stock_capital_imputado float = stock_capital si existe; para 2002, consumo_capital_fijo * promedio_pct(stock_capital/consumo_capital_fijo, 2003-2005) / 100; para 2011, consumo_capital_fijo * promedio_pct(stock_capital/consumo_capital_fijo, 2012-2024) / 100
  capital_total_adelantado float = stock_capital_imputado + capital_variable_adelantado + capital_circulante_constante_adelantado
  excedente_bruto  float  = vab_pp - remuneraciones
  part_salarial    float  = remuneraciones / vab_pp
  productividad    float  = vab_pp / puestos_trabajo

Columnas derivadas PENDIENTES (no incluir hasta decisión del investigador):
  amortizaciones   float  ver §7.1
```

Variables directas identificadas pero aún no integradas al panel:
  variacion_existencias float  2001 C10 / 2003-2005 C12; sin fuente detectada en 2006-2024

### Clave única del panel
```python
# (anno, seccion) es clave única. Cero duplicados tolerados.
assert df.duplicated(subset=["anno", "seccion"]).sum() == 0
```

---

## §7. VALIDACIÓN — CHECKPOINTS OBLIGATORIOS

### CHECKPOINT 1 — Validación de extracción (Fase 4)

Ejecutar después de extraer todos los años, antes del ensamble.

```python
# CHECK 1 — Completitud de secciones por año
# Mínimo común observado para Ép. IV–V en C1/C1.1: C, D, E, G, H, I
# Construcción (F) no aparece en C1/C1.1 y minería (B) falta en 2009–2011.
secciones_minimas_rev4 = {"C", "D", "E", "G", "H", "I"}
assert set(df_year["seccion"]).issuperset(secciones_minimas_rev4), \
    f"Año {year}: secciones faltantes"

# CHECK 2 — Sin nulos en columnas clave (excluir filas de totales)
cols_clave = ["seccion", "anno", "vab_pp", "remuneraciones"]
assert df_year[cols_clave].notna().all().all(), \
    f"Año {year}: valores nulos en columnas clave"

# CHECK 3 — Coherencia de magnitudes (filas de sección, no totales)
filas_datos = df_year[df_year["seccion"].str.match(r'^[A-Z]$')]
assert (filas_datos["vbp_pp"] >= filas_datos["vab_pp"]).all(), \
    f"Año {year}: VBP < VAB en alguna sección (inconsistente)"
if not (filas_datos["vab_pp"] >= filas_datos["remuneraciones"]).all():
    logging.warning(
        f"Año {year}: VAB < Remuneraciones en alguna sección. "
        f"Tratar como alerta metodológica, no error fatal automático."
    )
assert (filas_datos["puestos_trabajo"] > 0).all(), \
    f"Año {year}: puestos_trabajo <= 0"

# CHECK 4 — Columnas según época
if year >= 2017:
    assert "vab_pb" in df_year.columns and df_year["vab_pb"].notna().any(), \
        f"Año {year}: vab_pb ausente o nulo (esperado en Ép. V)"
else:
    assert "vab_pb" not in df_year.columns or df_year["vab_pb"].isna().all(), \
        f"Año {year}: vab_pb presente antes de 2017 (inesperado)"
```

### CHECKPOINT 2 — Validación del panel final (Fase 6)

```python
# CHECK A — Cobertura temporal sin huecos
annos_presentes = sorted(df_panel["anno"].unique())
annos_esperados = list(range(2001, 2025))
assert annos_presentes == annos_esperados, "Panel con años faltantes"

# CHECK B — Cobertura sectorial mínima por año
for anno, grupo in df_panel.groupby("anno"):
    n_secciones = grupo["seccion"].nunique()
    assert n_secciones >= 6, \
        f"Año {anno}: solo {n_secciones} secciones (mínimo esperado: 6)"

# CHECK C — Clave única
assert df_panel.duplicated(subset=["anno", "seccion"]).sum() == 0, \
    "Panel con filas duplicadas en (anno, seccion)"

# CHECK D — Continuidad del total (alerta, no error fatal)
total_por_anno = df_panel.groupby("anno")["vab_pp"].sum()
variacion = total_por_anno.pct_change().abs()
annos_salto = variacion[variacion > 0.5].index.tolist()
if annos_salto:
    logging.warning(
        f"Variación interanual del VAB total > 50% en: {annos_salto}. "
        f"Revisar si es metodológico o un error de extracción."
    )
```

---

## §8. DECISIONES PENDIENTES DEL INVESTIGADOR

El agente **no debe implementar** las siguientes funcionalidades hasta recibir
instrucción explícita con la opción elegida.

### §7.1 — Stock de capital, consumo de capital, amortizaciones

La EAAE provee el **flujo** de inversión (FBCF/FBKF, extraído desde C8 en 2001,
C10 en 2003–2005 y C6 en 2006–2024) y también una fuente directa para
`stock_capital`: valor de activos fijos al 31/12. La extracción directa usa C9
en 2001, C11 en 2003–2005 y C7 desde 2006 en adelante. Los años 2002 y 2011
quedan sin `stock_capital`: en 2002 el RAR contiene `EAE_C9_2002.xls`, pero es
un cuadro de impuestos, no de activos fijos; en 2011 el RAR publicado solo
contiene C1 y C2.

La imputación provisoria de faltantes no modifica `stock_capital`. Para
mantener simple el panel, solo se registran dos variables de stock:
`stock_capital`, original, y `stock_capital_imputado`, operativa. Esta última
replica `stock_capital` cuando existe. Para 2002 y 2011, cuando falta
`stock_capital` pero existe `consumo_capital_fijo`, el equipo decidió imputar
con un factor histórico de relación stock/consumo de capital fijo, calculado en
la misma sección o en `economia_total`:

- Para 2002: `factor_pct = promedio(stock_capital / consumo_capital_fijo) * 100`
  en 2003–2005.
- Para 2011: `factor_pct = promedio(stock_capital / consumo_capital_fijo) * 100`
  en 2012–2024.
- Imputación: `stock_capital_imputado = consumo_capital_fijo * (factor_pct / 100)`.

Si no hay observaciones válidas de `stock_capital` y `consumo_capital_fijo` en
la ventana de referencia correspondiente, `stock_capital_imputado` queda como
NA. Esta regla reemplaza la imputación anterior basada en
`factor_rotacion / 100`; los factores de rotación `6,6` para `C` y `4,2` para
`economia_total` se mantienen solamente para adelantar capital variable y
capital circulante.

La variable `amortizaciones` sigue pendiente. No construirla ni inferirla hasta
que el investigador defina fuente o método.
- [ ] ¿Cuál es el año base para K₀?
- [ ] ¿Tasas de depreciación diferenciadas por clase de activo o tasa única?

### §7.1.a — VAB a precios básicos estimado

**DECISIÓN PROVISORIA DEL EQUIPO — Junio 2026:** crear `vab_pb_estimado` como
serie completa 2001–2024. Para 2017–2024, `vab_pb_estimado` replica el
`vab_pb` observado en C1.1. Para años anteriores se retroproyecta por sección
homologada usando la variación interanual de `vab_pp`:

`vab_pb_estimado[t-1] = vab_pb_estimado[t] / (vab_pp[t] / vab_pp[t-1])`.

La implementación usa la forma equivalente `vab_pb_estimado[t] =
vab_pp[t] * (vab_pb/vab_pp)` del primer año observado por sección, para cubrir
secciones con años intermedios faltantes.

Esta variable es una imputación provisoria para análisis, no reemplaza la
variable directa `vab_pb`, que debe permanecer vacía antes de 2017.

### §7.1.b — Consumo intermedio estimado

**DECISIÓN PROVISORIA DEL EQUIPO — Junio 2026:** crear
`consumo_intermedio_estimado` como serie completa 2001–2024, calculada como:

`consumo_intermedio_estimado = vbp_pp - vab_pb_estimado`.

La variable busca aproximar el consumo intermedio/capital circulante constante
del panel. No es una variable observada directa de la EAAE y depende de
`vab_pb_estimado` antes de 2017. Dado que combina `vbp_pp` con VAB a precios
básicos observado o retroproyectado, debe tratarse como cálculo provisorio.

Para evitar confusiones, la variable directa que antes se exponía como
`consumo_capital` pasa a denominarse `consumo_capital_fijo` en el panel final.
La extracción puede mantener nombres internos asociados a la configuración de
C2/C2.1, pero el artefacto final debe usar el nombre explícito con sufijo
`_fijo`.

### §7.1.c — Capital adelantado

**DECISIÓN PROVISORIA DEL EQUIPO — Junio 2026:** crear variables de capital
adelantado usando factores fijos de rotación provistos por el equipo:

- `C`: 6,6.
- `economia_total`: 4,2.

El capital variable adelantado se calcula como:

`capital_variable_adelantado = remuneraciones / factor_rotacion`.

El capital circulante constante adelantado se calcula de forma análoga a partir
del consumo intermedio estimado:

`capital_circulante_constante_adelantado = consumo_intermedio_estimado / factor_rotacion`.

El capital total adelantado se calcula como:

`capital_total_adelantado = stock_capital_imputado + capital_variable_adelantado + capital_circulante_constante_adelantado`.

En el panel por sección solo se calcula para la rama `C`. En la hoja
`economia_total` se calcula para la economía agregada anual. Para sectores sin
factor de rotación definido, las tres variables quedan como NA. Si falta el
stock original en 2002 o 2011 pero existe `consumo_capital_fijo`,
`capital_total_adelantado` usa `stock_capital_imputado` imputado con la regla
histórica de stock/consumo; si no existe stock original ni imputación posible,
queda como NA.

### §7.1.d — Variación de existencias / inventarios

**VERIFICADO — Mayo 2026:** la EAAE usa la denominación `Variación de
existencias`, no `inventarios`. La fuente directa existe en:

- 2001: `Letra/EAE_cu10tpel_01.xls`, Cuadro 10, Total del País por sección.
- 2003–2005: `EAE_C12_<año>.xls`, Cuadro 12.

No se encontró fuente equivalente para 2006–2024. Se realizó un escaneo
completo de todos los XLS publicados para esos años, priorizando encabezados y
buscando términos asociados (`existencias`, `inventarios`, `stock`,
`mercaderías`, `materias primas`, `productos en proceso`, `productos
terminados`, etc.). Los únicos hallazgos no nucleares fueron falsos positivos
en descripciones de actividades, no variables.

Pendiente si se decide integrarla:
- [ ] Crear configuración `EAAE_EXISTENCIAS_CONFIG`.
- [ ] Extraer `variacion_existencias` para 2001 y 2003–2005.
- [ ] Dejar valores vacíos para 2002 y 2006–2024.

### §7.1.c — Deuda industrial / pasivos financieros

**VERIFICADO — Mayo 2026:** no se encontró una variable equivalente a `deuda`,
`pasivos`, `préstamos`, `crédito`, `endeudamiento`, `acreedores`,
`obligaciones`, `intereses`, `financiamiento bancario` o `deuda industrial` en
los archivos EAAE 2001–2024.

Se escanearon todos los RAR y XLS disponibles para 2001–2024. Los únicos
matches fueron falsos positivos:

- `contribución al financiamiento de la seguridad social`, que pertenece a
  impuestos/contribuciones, no a deuda.
- `servicios financieros` o actividades auxiliares, que son descripciones
  sectoriales CIIU, no variables de deuda.

Conclusión: no implementar `deuda_industrial` desde EAAE. Si se necesita esta
dimensión, debe incorporarse desde una fuente externa, por ejemplo crédito
bancario sectorial, balances empresariales, estadísticas del BCU, registros
tributarios o cuentas financieras sectoriales.

### §7.2 — Tratamiento del quiebre CIIU Rev.3 → Rev.4 (2007→2008)

**DECIDIDO — Mayo 2026:** el panel final será la opción B:
serie histórica homologada 2001–2024 con sectores agregados comparables.

- [x] Usar `seccion` como código homologado final.
- [x] No agregar columnas auxiliares de equivalencia al panel final.
- [x] Conservar `ciiu_version` como metadato de fuente.
- [x] Agregar D+E y H+J en Rev.4 para comparabilidad con Rev.3.

### §7.3 — Tratamiento del año 2001

**DECIDIDO — Mayo 2026:** incluir 2001 en la serie principal.

- [x] Usar `Letra/EAE_cu1tpel_01.xls`, cuadro 1, Total del País por sección.
- [x] Homologar secciones Rev.3 hacia `seccion` final sin columnas auxiliares.
- [x] Escalar variables monetarias por 1000 porque el cuadro publica miles de
  pesos corrientes; `puestos_trabajo` no se escala.
- [x] No crear tabla auxiliar `panel_eaae_2001.csv`; mantener la salida final
  fechada en `data/analysis-data/YYYYMMDD_panel_eaae.csv` y
  `data/analysis-data/YYYYMMDD_panel_eaae.xlsx`.

---

## §9. ANOMALÍAS CONOCIDAS

| Año | Tipo | Descripción | Solución en config |
|-----|------|-------------|-------------------|
| 2001 | Estructura | 78 archivos, 3 subcarpetas, sin C1.1; usar cuadro 1 por letra | `subfolder: "Letra"`, `file_pattern: EAE_cu1tpel_01\.xls`, `value_scale` monetario ×1000 |
| 2002 | FBCF | RAR publicado sin cuadro de Formación Bruta de Capital Fijo | `EAAE_FBCF_CONFIG[2002]["file_pattern"] = None` |
| 2002 | Stock | `EAE_C9_2002.xls` es cuadro de impuestos, no de activos fijos | `EAAE_STOCK_CONFIG[2002]["file_pattern"] = None` |
| 2002 | `data_start` | Solo 1 fila vacía → dato en fila 8, no 9 | `data_start_row: 8` |
| 2004 | `header_row` | Fila 4 vacía extra → encabezado en fila 7 | `header_row: 7` |
| 2006 | Nombre XLS | Sufijo `-F` en todos los archivos | `file_pattern` con `-F` |
| 2006 | Cuentas C2 | Layout verificado: impuestos netos col. 5, consumo capital fijo col. 6; col. 7 es VAB y no debe usarse como consumo | `EAAE_ACCOUNTS_CONFIG[2006]` + validación puente C 2005/2008 |
| 2007 | Subcarpeta | Cuadros duplicados; usar `Forzosas y aleatorias/` | `subfolder` definida |
| 2007 | Cuentas C2 | Layout verificado: impuestos netos col. 5, consumo capital fijo col. 6; col. 7 es VAB y no debe usarse como consumo | `EAAE_ACCOUNTS_CONFIG[2007]` + validación puente C 2005/2008 |
| 2011 | Datos | Solo C1 y C2 disponibles (incompleto) | `cuadros: ["C1","C2"]` |
| 2011 | FBCF | RAR publicado sin cuadro de Formación Bruta de Capital Fijo | `EAAE_FBCF_CONFIG[2011]["file_pattern"] = None` |
| 2011 | Cuentas C2 | Layout verificado: VAB col. 5, remuneraciones col. 6, impuestos netos col. 7, consumo capital col. 8 | `EAAE_ACCOUNTS_CONFIG[2011]` |
| 2012 | Nombre XLS | Primera aparición de subíndice decimal `C1.1` | `file_pattern` con `\.1` |
| 2013–2016 | `data_start` | Fila 3 extra "Valorado a pp..." → dato en fila 9 | `data_start_row: 9` |
| 2016 | Subcarpeta | Archivos dentro de carpeta con nombre largo | `subfolder` definida |
| 2017 | Nombre XLS | Espacio antes del año: `EAE_C1.1_ 2017.xls` | `\s?` en `file_pattern` |
| 2017 | Columnas | Primer año con 9 columnas (`vbp_pb`, `vab_pb`) | `ESQUEMA_9COL` |
| 2020 | Nombre RAR | Nombre completamente distinto al patrón | `rar_name` explícito |

---

## §10. DEPENDENCIAS Y ENTORNO

```
# requirements.txt
rarfile>=4.0        # lectura de archivos RAR5; requiere 'unrar' instalado a nivel sistema
xlrd>=2.0           # lectura de .xls legado (BIFF8, Excel 97-2003); no usar openpyxl para .xls
pandas>=2.0
requests>=2.28      # descarga HTTP de los RAR
beautifulsoup4>=4.0 # parsing del HTML del portal INE para obtener URLs de descarga
lxml>=4.9           # parser HTML requerido por beautifulsoup4
pytest>=7.0         # tests de validación automática
```

**Verificación previa al inicio:**
```bash
# Confirmar que unrar está instalado (requerido por rarfile)
which unrar || sudo apt install unrar

# Instalar dependencias Python
pip install -r requirements.txt

# Crear estructura de carpetas (si no existe)
mkdir -p data/input-data/eaae \
         data/input-data/metadata \
         data/analysis-data \
         command-files/config \
         command-files/processing-command-files \
         command-files/analysis-command-files \
         output/figures \
         output/tables \
         docs/minutes \
         docs/methodology
```

---

## §11. CONVENCIONES DE CÓDIGO

1. **Python 3.10+.** Sin f-strings con backslash anidado (incompatible < 3.12).
2. **Rutas relativas** desde la raíz del proyecto. Sin rutas absolutas.
3. **Logging** con el módulo estándar `logging`, no `print()`.
   INFO para operaciones normales, WARNING para anomalías esperadas,
   ERROR para fallos que detienen el pipeline.
4. **Idempotencia:** todos los scripts producen el mismo resultado si se
   re-ejecutan. Si el archivo de salida ya existe y es válido, saltear el
   procesamiento con un mensaje INFO.
5. **Sin silenciar errores:** ningún bloque `except: pass`.
   Toda excepción loggea el año y el archivo que la causó antes de relanzarse.
6. **Prefijo `# DECISION:`** para documentar en el código toda elección de
   implementación no trivial.
7. **Tests mínimos en `tests/`:** verificar al menos que el año 2020 (nombre
   de RAR anómalo) y el año 2017 (espacio en nombre de XLS) se extraen
   correctamente y devuelven un DataFrame con 9 columnas.

---

## §12. LOG DE SESIONES

| Fecha | Actividad | Estado |
|-------|-----------|--------|
| Mar 2026 | Evaluación estructural de archivos 2001–2014 | ✓ |
| Mar 2026 | Evaluación estructural de archivos 2015–2024 | ✓ |
| Mar 2026 | Construcción y validación de `EAAE_CONFIG` | ✓ |
| Mar 2026 | Diagrama de estructura por época y mapa de variables | ✓ |
| Mar 2026 | Definición de estructura TIER y fases del pipeline | ✓ |
| May 2026 | Redacción de `CONTEXT.md` (este documento) | ✓ |
| May 2026 | Decisión §8.2: panel final opción B, serie histórica homologada 2001–2024 | ✓ |
| May 2026 | Implementación `01_download.py` y descarga RAR 2001–2024 | ✓ |
| May 2026 | Implementación C1/C1.1 y creación preliminar de `panel_eaae.csv` 2002–2024 | ✓ |
| May 2026 | Creación inicial de minuta Quarto/revealjs, luego consolidada en archivo fechado único | ✓ |
| May 2026 | Integración de 2001 al panel principal desde cuadro 1 por letra con escalado monetario ×1000 | ✓ |
| May 2026 | Creación de minuta actualizada `docs/minutes/20260507_minuta_eaae_pipeline.qmd` | ✓ |
| May 2026 | Implementación de `03_extract_otros.py` y extracción de FBCF/FBKF al panel principal | ✓ |
| May 2026 | Extracción de consumo de capital fijo e `impuestos_netos` desde C2/C2.1 e integración al panel | ✓ |
| May 2026 | Extracción de `stock_capital` desde cuadros de valor de activos fijos al 31/12 e integración al panel | ✓ |
| May 2026 | Integración de `vbp_pb` desde C1.1 para 2017–2024 | ✓ |
| May 2026 | Integración de `adquisiciones_importadas` desde la columna Importadas de cuadros FBCF | ✓ |
| May 2026 | Corrección de fuente FBCF 2006–2007 hacia C6/C6-F tras verificación de encabezados | ✓ |
| May 2026 | Verificación de que `remuneraciones` incluye aportes patronales | ✓ |
| May 2026 | Escaneo completo 2006–2024: no se encontró fuente de inventarios/variación de existencias | ✓ |
| May 2026 | Escaneo completo 2001–2024: no se encontró variable de deuda/pasivos industriales en EAAE | ✓ |
| May 2026 | Consolidación de minuta: único QMD editable `docs/minutes/20260507_minuta_eaae_pipeline.qmd` | ✓ |
| May 2026 | Actualización de formato de tablas en la minuta Quarto y renderizado de HTML actualizado | ✓ |
| May 2026 | Creación de `command-files/analysis-command-files/01_load_panel.R` para cargar `panel_eaae.csv` en R como `panel_eaae` | ✓ |
| May 2026 | Reemplazo del CSV final por `20260528_panel_eaae.xlsx` con hojas `eaae`, `rama-C`, `check-calidad-C`, `economia_total` y `check-calidad-total` para revisión en GitHub | ✓ |
| May 2026 | Salidas fechadas automáticas para CSV completo y XLSX de revisión: `YYYYMMDD_panel_eaae.csv` y `YYYYMMDD_panel_eaae.xlsx` | ✓ |
| Jun 2026 | Decisión provisoria del equipo: creación de `vab_pb_estimado` con `vab_pb` observado desde 2017 y retroproyección por variación interanual de `vab_pp` | ✓ |
| Jun 2026 | Decisión provisoria del equipo: creación de `consumo_intermedio_estimado = vbp_pp - vab_pb_estimado` y renombre público de `consumo_capital` a `consumo_capital_fijo` | ✓ |
| Jun 2026 | Decisión provisoria del equipo: creación de `capital_variable_adelantado`, `capital_circulante_constante_adelantado` y `capital_total_adelantado` con factores 6,6 para C y 4,2 para economía total | ✓ |
| Jun 2026 | Decisión provisoria del equipo: simplificación a dos variables de stock; `stock_capital_imputado` replica el stock original cuando existe e imputa 2002 y 2011 con factores históricos de `stock_capital / consumo_capital_fijo` | ✓ |
| Jun 2026 | Incorporación en resultados corrientes de `vab_bcu_corriente` como referencia externa simple de BCU y `vab_eaae_bcu_pct` como comparación EAAE/BCU, integrando datos preliminares disponibles | ✓ |
| Jun 2026 | Validación específica para manufactura C en 2006–2007: `consumo_capital_fijo/vab_pp` se compara contra la envolvente 2005/2008 para detectar desalineación de columnas C2 | ✓ |
| Jun 2026 | Integración de `n_empresas` desde PDF de metodología/diseño muestral para años con desglose exacto verificable: 2001–2005, 2011 y 2020 | ✓ |
| Jun 2026 | Creación del post-proceso R `02_add_calculos_propios_eaae.R` y agregado de hojas de resultados corrientes, constantes, variaciones porcentuales e índices 2005=1 al XLSX | ✓ |
| Jun 2026 | Incorporación de fuente primaria externa `EIA 1989-1997` desde Series Económicas FCS/Udelar en `data/input-data/`, preservando archivos Excel originales | ✓ |
| Jun 2026 | Consolidación del procesamiento EIA 1989–1997 en un panel a dos dígitos Rev.2 con vocabulario equivalente a `rama-C` del panel EAAE; retiro de la base larga, panel ancho y validaciones amplias previas | ✓ |
| Jun 2026 | Decisión provisoria del equipo: para EIA 1989–1997, `stock_capital` conserva solo el dato original de activos fijos al 31/12 de 1997; `stock_capital_imputado` usa por división el ratio `stock_capital_1997 / consumo_capital_fijo_1997` | ✓ |
| Jun 2026 | Creación del libro `20260623_panel_eia_1989_1997_2dig.xlsx` con hojas `eia` y `check-calidad` para revisar el panel EIA y sus indicadores de validación tipo EAAE | ✓ |
| Jun 2026 | Documentación de granularidad potencial de subramas EAAE: dos dígitos/división como nivel recomendado para serie comparable 2001–2024; cuatro dígitos solo como excepción 2001 | ✓ |
| Jun 2026 | Incorporación de fuente primaria externa `eaae-1998-2001` con resultados EAE a 2 dígitos para 1998, 1999, 2000 y 2001 | ✓ |
| Jun 2026 | Procesamiento reproducible de `eaae-1998-2001`: panel ancho a división publicada, sólo universo empresas de 5 y más, con omisión documentada de hojas 1999 duplicadas del año 2000 | ✓ |
| Jun 2026 | Creación del panel EAAE industrial de subramas 2001–2024 en dos capas: fuente publicada y homologada a grupos CIIU Rev.4 compatibles, con validaciones tidy | ✓ |
| Jun 2026 | Creación del panel integrado EAAE-BCU para economía total, industria total y subramas industriales homologadas, con deflactores empalmados base 2005, extracción directa de consumo/stock de capital subrama e imputación de stock solo en 2002 y 2011 | ✓ |
| Jun 2026 | Actualización del panel integrado EAAE-BCU para usar deflactores BCU también en economía total, reemplazando el índice procesado de Oyanthabal en ese artefacto | ✓ |
| Jul 2026 | Incorporación de `rotacion_calibrada_sobre_6_6` desde Damodaran/EAAE al panel integrado EAAE-BCU, con valores constantes por nivel y subrama | ✓ |
| Jul 2026 | Creación del libro `20260706_resultados_eaae_bcu_total_industria_subrama.xlsx` con resultados largos para economía total, industria total y subramas industriales | ✓ |
| Jul 2026 | Creación del informe visual `20260706_resultados_eaae_bcu_total_industria_subrama.md` con sección adicional para subramas industriales | ✓ |
| Jul 2026 | Creación de versiones `20260727` del panel y libro EAAE-BCU con tasa de ganancia para industria manufacturera excluyendo papel/impresión y coque/refinación | ✓ |
| Aug 2026 | Actualización de contexto sobre disponibilidad de VAB/FBCF para manufactura total y depurada; creación de la minuta visual `20260805_resultados_eaae_bcu_tres_niveles.md` y figuras asociadas | ✓ |
| Aug 2026 | Importación de fuente online Oyanthabal `20260805_tasa_ganancia_uruguay_oyanthabal.xlsx` y creación de `oyanthabal_tasa_ganancia_uruguay.csv` con `anio`, `tg_total_b` y `tg_no_agrario_b` desde 2000 | ✓ |
| Aug 2026 | Incorporación en la minuta 20260805 de una comparación EAAE/Oyanthabal de tasa de ganancia: economía total EAAE pb sobre total Oyanthabal y manufactura EAAE pb sobre no agrario Oyanthabal, sólo para años con datos disponibles | ✓ |
| Aug 2026 | Importación de fuente online CIU `ciu_stock_capital_1988_2025.xlsx` y creación de `ciu_stock_capital_industria_1988_2025.csv` con stock industrial anual 1988-2025, usando serie anual hasta 2011 y diciembre de la serie trimestral desde 2012 | ✓ |
| Aug 2026 | Importación de fuente INE-UY `Cotización monedas.xlsx` y creación de `20260805_ine_uy_tipo_cambio_dolar_diciembre.csv` con último valor disponible de diciembre para `Dólar.USA.Compra` y `Dólar.USA.Venta` | ✓ |
| Aug 2026 | Creación de `20260805_comparacion_stock_capital_eaae_ciu.csv`: comparación EAAE-CIU de stock industrial de maquinaria/equipos sin refinería, convertido con dólar venta INE, deflactado con proxy BCU e indexado 2008=100 | ✓ |
| Aug 2026 | Actualización de minuta visual `20260806_resultados_eaae_bcu_tres_niveles.md`: comparación EAAE/Oyanthabal en tasas porcentuales, promedio manufacturero punteado en tasa de ganancia y productividad con VAB pb estimado y VAB pp | ✓ |
| Pendiente | Decisiones §8.1 (equipo de investigación) | ⏳ |
| Pendiente | Decidir método para `amortizaciones` y tratamiento de faltantes FBCF/stock 2002/2011 | ⏳ |

---

*Autores: Felipe Ruiz Bruzzone y Claude (Anthropic). Mayo 2026.*
