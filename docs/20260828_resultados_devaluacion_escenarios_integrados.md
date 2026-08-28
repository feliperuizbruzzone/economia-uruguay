# Saldos de ganancia asociados a la sobrevaluación cambiaria industrial, 2020-2024

Fuente de trabajo: `data/analysis-data/20260828_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx`, hojas `escenario-inicial`, `Escenario 1 - Comercio Exterior` y `Escenario 2 - Bienes Transables`.

Esta minuta integra los dos ejercicios de cierre de brecha cambiaria construidos para la industria manufacturera uruguaya. A diferencia de la lectura centrada en el resultado contrafactual de devaluación, aquí el foco está puesto en el saldo monetario que se observa desde el escenario inicial de sobrevaluación.

La convención de signo es `ganancia inicial - ganancia contrafactual con cierre de brecha`. Por eso, un valor negativo indica ganancia dejada de percibir bajo sobrevaluación: si se cerrara la brecha cambiaria, la masa de ganancia sería mayor. Un valor positivo indica ganancia sobrepercibida bajo sobrevaluación: si se cerrara la brecha, la masa de ganancia sería menor. Las magnitudes se presentan en miles de millones de pesos corrientes.

La medida principal es la masa de ganancia a precios básicos `ganancia_pb`. Como complemento se reporta `ganancia_pb_desp_intereses`, que descuenta intereses pagados y permite observar si el saldo se mantiene una vez considerado el canal financiero. No se presentan tasas de ganancia en esta versión de la minuta.

## Supuestos, fuentes y factor de devaluación

El ejercicio utiliza resultados corrientes de la EAAE para 2020-2024 y aplica coeficientes de incidencia diferenciados por escenario y sección. La industria total conserva los coeficientes agregados; los segmentos exportador y mercado interno usan coeficientes específicos construidos para cada escenario. La serie de intereses corresponde a la industria manufacturera agregada y su apertura entre segmentos se asigna según microdatos del CIU.

| Bloque | Ítem | Criterio documentado |
| --- | --- | --- |
| Fuente | panel EAAE 2020-2024 | El escenario se actualiza desde el panel CSV ya validado: 20260826_panel_eaae_2020_2024_industria.csv. No se recalcula el panel porque los nuevos coeficientes son parámetros de modelamiento de devaluación y no modifican variables base EAAE. |
| Fuente | coeficientes de devaluación | Los coeficientes se toman desde 20260828-coeficientes-efecto-devaluacion.csv. La hoja Modelo del archivo fuente entrega los coeficientes para industria total en dos escenarios; las hojas Impo_Expo - Mercado Interno y Transable_Expo - MI entregan coeficientes específicos para exportadora y mercado-interno. |
| Fuente | intereses industriales | La serie de intereses disponible es anual y corresponde a la industria manufacturera agregada. La apertura entre grupos exportadora y mercado interno se toma de microdatos del CIU. |
| Decisión | criterio de asignación de intereses | Para los grupos de subramas, los intereses industriales se asignan según microdatos del CIU: 65,6% para ramas exportadoras y 34,4% para ramas orientadas al mercado interno. La industria total conserva el 100% de la serie agregada. |
| Fórmula | intereses por grupo | intereses_grupo = intereses_industria_total * participacion_CIU; participacion_CIU exportadora = 0,656; participacion_CIU mercado-interno = 0,344. |
| Devaluación | factor de devaluación | factor_devaluacion = tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1. |
| Fuente | archivo de trabajo de coeficientes | Archivo de trabajo: `data/input-data/mussi/20260828-Uruguay. Modelo de impacto de devaluación-segmentos-dos-escenarios.xlsx`. Las fuentes sustantivas de cada coeficiente se toman de su columna `Fuente` y se reportan en las tablas por escenario. |
| Fuente | tipo de cambio comercial/paridad | La hoja `tipo-cambio` del XLSX se construye desde `data/analysis-data/20260812-exportaciones-manufactura-uruguay.csv`, con tipo de cambio comercial y tipo de cambio de paridad. |

El factor de devaluación considerado se calcula año a año como `tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1`. No se trata de un shock acumulado entre años, sino de un cierre contrafactual de la brecha cambiaria en cada año observado. En el período 2020-2024, el factor promedio es 44,4%, con un mínimo de 35,4% y un máximo de 55,1%.

| Año | Tipo de cambio comercial | Tipo de cambio paridad | Factor de devaluación |
| --- | --- | --- | --- |
| 2020 | 42,00 | 57,61 | 37,2% |
| 2021 | 43,56 | 58,98 | 35,4% |
| 2022 | 41,30 | 58,13 | 40,8% |
| 2023 | 38,70 | 60,01 | 55,1% |
| 2024 | 40,24 | 61,85 | 53,7% |

La hoja `Efecto TCC - TCP` del archivo de trabajo propone leer el ejercicio como una combinación de cesión y apropiación respecto de una ganancia inicial. El VBP/exportaciones aparece como cesión bajo sobrevaluación cuando el cierre de la brecha lo valoriza al alza; los costos aparecen como apropiación bajo sobrevaluación cuando el cierre de la brecha los encarece. La tabla y el gráfico siguientes reproducen ese esquema de lectura como ejemplo conceptual, no como resultado empírico de la serie EAAE.

| Año | Variable ejemplo | Monto base | Factor devaluación | Concepto | Delta monetario | % sobre ganancia inicial |
| --- | --- | --- | --- | --- | --- | --- |
| 2024 | VBP/exportaciones | 200 | 53,7% | Cesión | -107,4 | -10,7% |
| 2024 | Insumos | 100 | 53,7% | Apropiación | +53,7 | +5,4% |
| 2024 | Masa salarial | 30 | 53,7% | Apropiación | +16,1 | +1,6% |

![Esquema TCC-TCP: cesión y apropiación](../output/figures/devaluacion_escenarios_integrados_20260828/00_esquema_efecto_tcc_tcp.png)

Los coeficientes de incidencia se reportan en las secciones de cada escenario. En todos los casos indican qué proporción de cada variable se ve afectada por el cierre de la brecha cambiaria; la columna de efecto explicita si esa incidencia eleva la valorización del VBP o aumenta costos, intereses y componentes que reducen la masa de ganancia. La fuente del coeficiente se toma de la columna `Fuente` del XLSX de coeficientes cuando está disponible; si una celda de fuente está vacía, se conserva la trazabilidad a la hoja y bloque desde donde fue extraído el coeficiente.

## 1. Industria general: saldos comparados entre escenarios

A nivel de industria total, los dos escenarios producen saldos opuestos. En el escenario de comercio exterior, el cierre de la brecha elevaría la ganancia industrial; por tanto, desde la posición inicial de sobrevaluación aparece un saldo negativo: ganancia dejada de percibir. En el escenario de bienes transables, el cierre de la brecha reduce la ganancia agregada por el mayor peso de consumo intermedio y masa salarial; desde la posición inicial, eso aparece como saldo positivo: ganancia sobrepercibida bajo sobrevaluación.

![Industria total: saldo de ganancia asociado a la sobrevaluación](../output/figures/devaluacion_escenarios_integrados_20260828/01_industria_total_saldo_sobrevaluacion_ganancia.png)

| Escenario | Ganancia base prom. | Ganancia escenario prom. | Saldo sobrevaluación prom. | Saldo post intereses prom. | Ganancia base 2024 | Ganancia escenario 2024 | Saldo 2024 | Saldo post intereses 2024 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Escenario 2 - Bienes transables | 83,4 | -31,2 | +114,6 | +114,8 | 78,2 | -75,0 | +153,2 | +153,4 |
| Escenario 1 - Comercio exterior | 83,4 | 168,5 | -85,1 | -84,9 | 78,2 | 189,4 | -111,3 | -111,0 |

La descomposición de 2024 muestra el mecanismo. La menor valorización del VBP aparece con signo negativo porque representa ganancia dejada de percibir bajo sobrevaluación. Los menores costos observados bajo sobrevaluación aparecen con signo positivo porque elevan la ganancia inicial respecto del contrafactual de paridad.

![Industria total: componentes del saldo 2024](../output/figures/devaluacion_escenarios_integrados_20260828/02_industria_total_componentes_saldo_2024.png)

| Componente | Escenario 1 | Escenario 2 |
| --- | --- | --- |
| Menor valorización del VBP | -182,1 | -153,5 |
| Ahorro en consumo intermedio | +64,9 | +278,9 |
| Ahorro en remuneraciones | +5,6 | +27,5 |
| Ahorro en consumo capital fijo | +0,3 | +0,3 |
| Ahorro en intereses pagados | +0,3 | +0,3 |

## 2. Escenario 1 - Comercio Exterior

La apropiación de riqueza vía sobrevaluación de la moneda se aplica a los componentes importados de costos y capital y a la parte exportada de la producción. Por tanto, recoge el efecto directo de importaciones y exportaciones sobre la masa de ganancia.

En este escenario, la sobrevaluación comprime la valorización en pesos del VBP asociado al comercio exterior y, al mismo tiempo, abarata componentes importados de costos y capital. El balance de esos canales se expresa como saldo de masa de ganancia observado desde el escenario inicial.

En 2024, la industria total registra un saldo de sobrevaluación de -111,3 miles de millones de pesos corrientes en ganancia a precios básicos.
En el mismo año, el segmento exportador registra -87,4 y el segmento mercado interno registra +6,2 miles de millones.

![Escenario 1: saldo de ganancia por segmento](../output/figures/devaluacion_escenarios_integrados_20260828/03_comercio_exterior_saldo_ganancia_segmentos.png)

| Sección | Ganancia base prom. | Ganancia escenario prom. | Saldo sobrevaluación prom. | Saldo post intereses prom. | Ganancia base 2024 | Ganancia escenario 2024 | Saldo 2024 | Saldo post intereses 2024 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Segmento exportador | 59,8 | 125,0 | -65,2 | -65,1 | 66,2 | 153,6 | -87,4 | -87,2 |
| Industria total | 83,4 | 168,5 | -85,1 | -84,9 | 78,2 | 189,4 | -111,3 | -111,0 |
| Mercado interno | 20,2 | 15,6 | +4,6 | +4,7 | 20,3 | 14,2 | +6,2 | +6,2 |

![Escenario 1: componentes del saldo 2024](../output/figures/devaluacion_escenarios_integrados_20260828/04_comercio_exterior_componentes_saldo_2024_segmentos.png)

Coeficientes del modelo utilizados en este escenario:

| Sección | Variable afectada | Incidencia | Efecto ante devaluación | Fuente del coeficiente |
| --- | --- | --- | --- | --- |
| Industria total | Consumo capital fijo | 1,7% | Negativo: aumenta costos y reduce la masa de ganancia | Efecto de inversión importada, prorrateada por depreciación lineal estimación a 20 años a partir de EAAE |
| Industria total | Consumo intermedio | 18,9% | Negativo: aumenta costos y reduce la masa de ganancia | Se toma COU porque incluye impuestos y márgenes de comercio y transporte, promedio 2015/2016 |
| Industria total | Intereses pagados | 8,5% | Negativo: aumenta intereses pagados y reduce la ganancia post intereses | CIU 2006/2024 |
| Industria total | Masa salarial | 9,3% | Negativo: aumenta costos y reduce la masa de ganancia | Se toma COU porque incluye impuestos y márgenes de comercio y transporte, promedio 2015/2016 |
| Industria total | Stock capital imputado | 3,7% | Negativo: aumenta capital adelantado; no entra en la masa de ganancia presentada | Efecto de inversión importada en stock de capital a partir de EAAE |
| Industria total | VBP/exportador | 39,5% | Positivo: eleva el VBP valorizado al tipo de cambio de paridad | Exportaciones CCNN, con factor de microdatos, respecto de VBP EAAE, promedio 2001/2024 |
| Mercado interno | Consumo capital fijo | 1,1% | Negativo: aumenta costos y reduce la masa de ganancia | Hoja impo_expo - mercado interno; Bloque mercado interno; fuente específica no explicitada en celda. |
| Mercado interno | Consumo intermedio | 22,7% | Negativo: aumenta costos y reduce la masa de ganancia | Hoja impo_expo - mercado interno; Bloque mercado interno; fuente específica no explicitada en celda. |
| Mercado interno | Intereses pagados | 8,5% | Negativo: aumenta intereses pagados y reduce la ganancia post intereses | Hoja impo_expo - mercado interno; Bloque mercado interno; fuente específica no explicitada en celda. |
| Mercado interno | Masa salarial | 9,3% | Negativo: aumenta costos y reduce la masa de ganancia | Hoja impo_expo - mercado interno; Bloque mercado interno; fuente específica no explicitada en celda. |
| Mercado interno | Stock capital imputado | 1,8% | Negativo: aumenta capital adelantado; no entra en la masa de ganancia presentada | Hoja impo_expo - mercado interno; Bloque mercado interno; fuente específica no explicitada en celda. |
| Mercado interno | VBP/exportador | 10,7% | Positivo: eleva el VBP valorizado al tipo de cambio de paridad | Hoja impo_expo - mercado interno; Bloque mercado interno; fuente específica no explicitada en celda. |
| Segmento exportador | Consumo capital fijo | 0,8% | Negativo: aumenta costos y reduce la masa de ganancia | Hoja impo_expo - mercado interno; Bloque exportadores; fuente específica no explicitada en celda. |
| Segmento exportador | Consumo intermedio | 18,1% | Negativo: aumenta costos y reduce la masa de ganancia | Hoja impo_expo - mercado interno; Bloque exportadores; fuente específica no explicitada en celda. |
| Segmento exportador | Intereses pagados | 8,5% | Negativo: aumenta intereses pagados y reduce la ganancia post intereses | Hoja impo_expo - mercado interno; Bloque exportadores; fuente específica no explicitada en celda. |
| Segmento exportador | Masa salarial | 9,3% | Negativo: aumenta costos y reduce la masa de ganancia | Hoja impo_expo - mercado interno; Bloque exportadores; fuente específica no explicitada en celda. |
| Segmento exportador | Stock capital imputado | 0,9% | Negativo: aumenta capital adelantado; no entra en la masa de ganancia presentada | Hoja impo_expo - mercado interno; Bloque exportadores; fuente específica no explicitada en celda. |
| Segmento exportador | VBP/exportador | 42,0% | Positivo: eleva el VBP valorizado al tipo de cambio de paridad | Hoja impo_expo - mercado interno; Bloque exportadores; fuente específica no explicitada en celda. |

## 3. Escenario 2 - Bienes Transables

La apropiación de riqueza vía sobrevaluación alcanza al conjunto de mercancías cuyos precios internos se rigen por precios internacionales, aunque sean producidas localmente y vendidas en el mercado interno. Así, incorpora la revaluación de producción local transable y su efecto sobre la masa de ganancia.

En este escenario, la incidencia no queda limitada al comercio exterior directo. También se consideran mercancías producidas localmente cuyos precios internos se rigen por precios internacionales. Esto amplía tanto los canales positivos del VBP como los canales de costos, por lo que la lectura debe concentrarse en el saldo neto de masa de ganancia.

En 2024, la industria total registra un saldo de sobrevaluación de +153,2 miles de millones de pesos corrientes en ganancia a precios básicos.
En el mismo año, el segmento exportador registra -112,8 y el segmento mercado interno registra -39,3 miles de millones.

![Escenario 2: saldo de ganancia por segmento](../output/figures/devaluacion_escenarios_integrados_20260828/03_bienes_transables_saldo_ganancia_segmentos.png)

| Sección | Ganancia base prom. | Ganancia escenario prom. | Saldo sobrevaluación prom. | Saldo post intereses prom. | Ganancia base 2024 | Ganancia escenario 2024 | Saldo 2024 | Saldo post intereses 2024 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Segmento exportador | 59,8 | 142,3 | -82,5 | -82,4 | 66,2 | 179,0 | -112,8 | -112,7 |
| Industria total | 83,4 | -31,2 | +114,6 | +114,8 | 78,2 | -75,0 | +153,2 | +153,4 |
| Mercado interno | 20,2 | 50,1 | -29,9 | -29,8 | 20,3 | 59,6 | -39,3 | -39,2 |

![Escenario 2: componentes del saldo 2024](../output/figures/devaluacion_escenarios_integrados_20260828/04_bienes_transables_componentes_saldo_2024_segmentos.png)

Coeficientes del modelo utilizados en este escenario:

| Sección | Variable afectada | Incidencia | Efecto ante devaluación | Fuente del coeficiente |
| --- | --- | --- | --- | --- |
| Industria total | Consumo capital fijo | 1,7% | Negativo: aumenta costos y reduce la masa de ganancia | Hoja modelo; Bloque v.2 \| cantidades fijas \| transable; fuente específica no explicitada en celda. |
| Industria total | Consumo intermedio | 81,2% | Negativo: aumenta costos y reduce la masa de ganancia | Se toma COU porque incluye impuestos y márgenes de comercio y transporte, promedio 2015/2016 |
| Industria total | Intereses pagados | 8,5% | Negativo: aumenta intereses pagados y reduce la ganancia post intereses | CIU 2006/2024 |
| Industria total | Masa salarial | 45,3% | Negativo: aumenta costos y reduce la masa de ganancia | Se toma COU porque incluye impuestos y márgenes de comercio y transporte, promedio 2015/2016 |
| Industria total | Stock capital imputado | 2,5% | Negativo: aumenta capital adelantado; no entra en la masa de ganancia presentada | Hoja modelo; Bloque v.2 \| cantidades fijas \| transable; fuente específica no explicitada en celda. |
| Industria total | VBP/transable | 33,3% | Positivo: eleva el VBP valorizado al tipo de cambio de paridad | Exportaciones CCNN, con factor de microdatos, respecto de VBP EAAE, promedio 2001/2024 |
| Mercado interno | Consumo capital fijo | 1,1% | Negativo: aumenta costos y reduce la masa de ganancia | Hoja transable_expo - mi; Bloque mercado interno; fuente específica no explicitada en celda. |
| Mercado interno | Consumo intermedio | 76,4% | Negativo: aumenta costos y reduce la masa de ganancia | Hoja transable_expo - mi; Bloque mercado interno; fuente específica no explicitada en celda. |
| Mercado interno | Intereses pagados | 8,5% | Negativo: aumenta intereses pagados y reduce la ganancia post intereses | Hoja transable_expo - mi; Bloque mercado interno; fuente específica no explicitada en celda. |
| Mercado interno | Masa salarial | 8,3% | Negativo: aumenta costos y reduce la masa de ganancia | Hoja transable_expo - mi; Bloque mercado interno; fuente específica no explicitada en celda. |
| Mercado interno | Stock capital imputado | 1,8% | Negativo: aumenta capital adelantado; no entra en la masa de ganancia presentada | Hoja transable_expo - mi; Bloque mercado interno; fuente específica no explicitada en celda. |
| Mercado interno | VBP/transable | 92,4% | Positivo: eleva el VBP valorizado al tipo de cambio de paridad | Hoja transable_expo - mi; Bloque mercado interno; fuente específica no explicitada en celda. |
| Segmento exportador | Consumo capital fijo | 0,8% | Negativo: aumenta costos y reduce la masa de ganancia | Hoja transable_expo - mi; Bloque exportadores; fuente específica no explicitada en celda. |
| Segmento exportador | Consumo intermedio | 82,0% | Negativo: aumenta costos y reduce la masa de ganancia | Hoja transable_expo - mi; Bloque exportadores; fuente específica no explicitada en celda. |
| Segmento exportador | Intereses pagados | 8,5% | Negativo: aumenta intereses pagados y reduce la ganancia post intereses | Hoja transable_expo - mi; Bloque exportadores; fuente específica no explicitada en celda. |
| Segmento exportador | Masa salarial | 13,3% | Negativo: aumenta costos y reduce la masa de ganancia | Hoja transable_expo - mi; Bloque exportadores; fuente específica no explicitada en celda. |
| Segmento exportador | Stock capital imputado | 0,9% | Negativo: aumenta capital adelantado; no entra en la masa de ganancia presentada | Hoja transable_expo - mi; Bloque exportadores; fuente específica no explicitada en celda. |
| Segmento exportador | VBP/transable | 97,2% | Positivo: eleva el VBP valorizado al tipo de cambio de paridad | Hoja transable_expo - mi; Bloque exportadores; fuente específica no explicitada en celda. |

## Nota técnica

La fórmula común aplicada en ambos escenarios es:

```text
factor_devaluacion = tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1
delta_variable = variable_base * incidencia_seccion_variable * factor_devaluacion
ganancia_pb_escenario = ganancia_pb + delta_vbp_pp - delta_consumo_intermedio_estimado - delta_remuneraciones - delta_consumo_capital_fijo
saldo_sobrevaluacion_ganancia_pb = ganancia_pb - ganancia_pb_escenario
ganancia_pb_desp_intereses_escenario = ganancia_pb_escenario - intereses_industria_pesos_escenario
saldo_sobrevaluacion_ganancia_pb_desp_intereses = ganancia_pb_desp_intereses - ganancia_pb_desp_intereses_escenario
```

El coeficiente de stock de capital imputado se mantiene en el XLSX porque afecta cálculos de tasa de ganancia, pero no se presenta en esta minuta porque la medida solicitada es masa absoluta de ganancia. Por esa razón, las figuras y tablas de componentes de esta versión usan VBP, consumo intermedio, remuneraciones, consumo de capital fijo e intereses.
