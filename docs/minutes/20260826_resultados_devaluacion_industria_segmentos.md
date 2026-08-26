# Efectos diferenciados de una devaluación sobre la industria manufacturera uruguaya, 2020-2024

Fuente de trabajo: `data/analysis-data/20260826_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx`, hojas `escenario-inicial`, `tipo-cambio` y `devaluación-1`.

## Síntesis

El ejercicio compara los resultados corrientes observados de la industria manufacturera con un escenario en el que el tipo de cambio pasa desde el nivel comercial al nivel de paridad. La simulación no modifica cantidades, productividad ni estructura productiva; aplica coeficientes de incidencia sobre componentes monetarios para estimar un impacto contable de corto plazo.

Con coeficientes diferenciados por sección, el resultado central es una fractura interna dentro de la manufactura. La industria total aumenta su tasa de ganancia a precios básicos, pero ese resultado es arrastrado por el segmento exportador. En 2024, el segmento exportador pasa de 14,4% a 32,6%, mientras que el segmento mercado interno cae de 17,4% a 11,5%.

## Supuestos y escenarios

- `escenario-inicial` contiene los valores corrientes observados para industria total, segmento exportador y segmento mercado interno.
- `devaluación-1` recalcula los componentes mediante `factor_devaluacion = tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1`.
- El canal positivo se modela sobre `vbp_pp`; los canales de costo o requerimiento adicional se modelan sobre consumo intermedio, remuneraciones, consumo de capital fijo, stock imputado e intereses.
- Los intereses industriales son una serie agregada de manufactura y se distribuyen por segmento según participación en `vbp_pp`.
- El grupo `combustible` queda fuera del libro de resultados y de esta minuta; se conserva sólo en el panel CSV para trazabilidad contable.

![Factor de devaluación modelado](../../output/figures/devaluacion_industria_segmentos_20260826/01_factor_devaluacion_2020_2024.png)

## Coeficientes de incidencia

La diferencia principal frente a ejercicios anteriores es que los coeficientes ya no son únicos para toda la manufactura. La industria total conserva los coeficientes previos, mientras que los segmentos exportador y mercado interno toman coeficientes específicos. Esto permite que el mismo shock cambiario tenga efectos distintos según orientación comercial y estructura de costos.

![Coeficientes de incidencia por segmento](../../output/figures/devaluacion_industria_segmentos_20260826/02_coeficientes_incidencia_segmentos.png)

| Sección | Variable afectada | Incidencia |
| --- | --- | --- |
| Industria total | Consumo capital fijo | 1,7% |
| Industria total | Consumo intermedio | 18,9% |
| Industria total | Intereses | 8,5% |
| Industria total | Masa salarial | 9,3% |
| Industria total | Stock imputado | 3,7% |
| Industria total | VBP | 33,3% |
| Mercado interno | Consumo capital fijo | 1,1% |
| Mercado interno | Consumo intermedio | 22,7% |
| Mercado interno | Intereses | 8,5% |
| Mercado interno | Masa salarial | 9,3% |
| Mercado interno | Stock imputado | 1,8% |
| Mercado interno | VBP | 10,7% |
| Segmento exportador | Consumo capital fijo | 0,8% |
| Segmento exportador | Consumo intermedio | 18,1% |
| Segmento exportador | Intereses | 8,5% |
| Segmento exportador | Masa salarial | 9,3% |
| Segmento exportador | Stock imputado | 0,9% |
| Segmento exportador | VBP | 42,0% |

## Resultados principales

La tasa de ganancia a precios básicos de la industria total aumenta en promedio +10,6 pp entre 2020 y 2024. En el segmento exportador el aumento promedio es +15,5 pp. En cambio, el segmento mercado interno muestra una variación promedio de -4,8 pp, lo que indica que el encarecimiento de costos supera el impulso positivo sobre el VBP.

![Tasa de ganancia a precios básicos](../../output/figures/devaluacion_industria_segmentos_20260826/03_tasa_ganancia_base_devaluacion.png)

![Cambio en tasa de ganancia](../../output/figures/devaluacion_industria_segmentos_20260826/04_variacion_tasa_ganancia_pp.png)

| Sección | TG base prom. | TG devaluada prom. | Cambio prom. | TG base 2024 | TG devaluada 2024 | Cambio 2024 | Var. ganancia 2024 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Segmento exportador | 14,8% | 30,3% | +15,5 pp | 14,4% | 32,6% | +18,2 pp | 131,9% |
| Industria total | 15,4% | 26,0% | +10,6 pp | 12,7% | 25,0% | +12,4 pp | 105,8% |
| Mercado interno | 19,3% | 14,5% | -4,8 pp | 17,4% | 11,5% | -5,9 pp | -30,3% |

## Mecanismo de transmisión en 2024

En 2024, el aumento de `vbp_pp` es el principal canal positivo. Para la industria total equivale a 153,5 miles de millones de pesos corrientes. Ese impulso se compensa parcialmente por el aumento de consumo intermedio, remuneraciones, consumo de capital fijo, stock imputado e intereses. La asimetría por segmento es clara: el segmento exportador capta la mayor parte del impulso por VBP, mientras que en mercado interno el aumento de costos queda por encima del impulso de ventas.

![Descomposición del efecto en 2024](../../output/figures/devaluacion_industria_segmentos_20260826/05_descomposicion_efecto_2024.png)

| Sección | Delta VBP | Delta CI | Delta remuneraciones | Delta CCF | Delta stock | Delta intereses |
| --- | --- | --- | --- | --- | --- | --- |
| Industria total | 153,5 | 64,9 | 5,6 | 0,25 | 8,7 | 0,26 |
| Segmento exportador | 132,8 | 41,8 | 3,6 | 0,09 | 1,6 | 0,18 |
| Mercado interno | 10,5 | 14,9 | 1,8 | 0,03 | 0,6 | 0,06 |

## Contribución relativa de los segmentos

La lectura por participaciones muestra que, en 2024, el segmento exportador explica 86,5% del delta de VBP de la industria total, frente a 6,9% del segmento mercado interno. Esta concentración explica por qué la mejora agregada de la industria total no debe leerse como un efecto homogéneo para toda la manufactura.

![Participación de segmentos en los deltas 2024](../../output/figures/devaluacion_industria_segmentos_20260826/06_participacion_segmentos_deltas_2024.png)

| Componente | Exportador / industria total | Mercado interno / industria total |
| --- | --- | --- |
| VBP | 86,5% | 6,9% |
| Consumo intermedio | 64,4% | 22,9% |
| Remuneraciones | 63,2% | 31,8% |
| Consumo capital fijo | 35,1% | 11,4% |
| Stock imputado | 19,0% | 6,7% |
| Intereses | 68,6% | 21,3% |

## Interpretación

La simulación sugiere que una devaluación de esta magnitud redistribuye condiciones de rentabilidad dentro de la industria. Para el segmento exportador, el aumento del VBP en pesos domina el encarecimiento de costos y eleva con fuerza la tasa de ganancia. Para el segmento mercado interno, la menor incidencia del canal VBP y la mayor presión relativa de costos producen una caída de la rentabilidad.

Por lo tanto, el resultado agregado de la industria total debe interpretarse con cautela: expresa una mejora promedio, pero esa mejora proviene de una composición sectorial desigual. La devaluación no opera como estímulo general equivalente para toda la manufactura, sino como un shock que beneficia principalmente a los grupos con mayor capacidad de valorización en moneda extranjera.

## Anexo técnico

La fórmula general aplicada es:

```text
delta_variable = variable_base * incidencia_seccion_variable * factor_devaluacion
variable_devaluacion = variable_base + delta_variable
factor_devaluacion = tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1
```

La ganancia a precios básicos bajo devaluación se calcula como:

```text
ganancia_pb_devaluacion =
  ganancia_pb + delta_vbp_pp - delta_consumo_intermedio_estimado -
  delta_remuneraciones - delta_consumo_capital_fijo
```

El capital total adelantado bajo devaluación incorpora el cambio en stock imputado y en capital circulante:

```text
capital_total_adelantado_devaluacion =
  capital_total_adelantado + delta_stock_capital_imputado +
  (delta_remuneraciones + delta_consumo_intermedio_estimado) / rotacion_calibrada_sobre_6_6
```

La tasa de ganancia a precios básicos bajo devaluación se calcula como:

```text
tasa_ganancia_pb_devaluacion =
  ganancia_pb_devaluacion / capital_total_adelantado_devaluacion
```
