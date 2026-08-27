# Escenario 1: incidencia directa del comercio exterior

Fuente de trabajo: `data/analysis-data/20260827_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx`, hojas `escenario-inicial`, `tipo-cambio` y `Escenario 1 - Comercio Exterior`.

## Introducción

Este escenario modela la apropiación de riqueza vía sobrevaluación de la moneda sólo sobre los componentes importados de costos y capital y sobre la parte exportada de la producción. Por tanto, mide la incidencia directa de importaciones y exportaciones sobre la tasa de ganancia industrial.

La minuta interpreta el cierre anual de la brecha entre tipo de cambio comercial y tipo de cambio de paridad como forma de dimensionar la apropiación de riqueza asociada a sostener un tipo de cambio sobrevaluado. El ejercicio se realiza año a año, sin efectos acumulados ni respuestas dinámicas de cantidades, productividad o estructura productiva.

## Síntesis

Las fuentes usadas son: EAAE para VBP, VAB, remuneraciones, consumo intermedio estimado, consumo de capital fijo, stock de capital y capital adelantado; Oyanthabal, con base en la metodología de Iñigo Carrera (2007), para los tipos de cambio comercial/paridad y los coeficientes de incidencia del ejercicio; microdatos del CIU para distribuir los intereses industriales entre ramas exportadoras y ramas orientadas al mercado interno; y la clasificación operativa de subramas industriales 2020-2024 usada para separar industria exportadora, mercado interno y combustible.

Se trabaja desde 2020 porque en ese tramo la fuente opera con ramas homogéneas. Extender el ejercicio al panel completo exigiría procesar distintas versiones CIIU, lo que vuelve incompatible diferenciar con criterio uniforme el segmento industrial exportador y el segmento orientado al mercado interno. Complementariamente, el período 2020-2024 es razonable para una lectura en valores corrientes porque evita grandes saltos de nivel asociados a cambios clasificatorios.

Bajo este escenario, la industria total pasa en 2024 de una tasa de ganancia a precios básicos de 12,7% a 29,5%. El segmento exportador pasa de 14,4% a 32,6%, mientras que el segmento mercado interno pasa de 17,4% a 11,5%.

## Supuestos y escenarios

- `escenario-inicial` contiene los valores corrientes observados para industria total, segmento exportador y segmento mercado interno.
- `Escenario 1 - Comercio Exterior` contiene el contrafactual del escenario modelado.
- El cálculo se realiza año a año mediante `factor_devaluacion = tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1`; no contempla efectos acumulados ni respuestas dinámicas de cantidades, precios relativos o productividad.
- El canal positivo se modela sobre `vbp_pp`; los canales negativos se modelan sobre consumo intermedio, remuneraciones, consumo de capital fijo, stock imputado e intereses pagados.
- Los intereses industriales son una serie agregada de manufactura y se distribuyen por segmento según microdatos del CIU: 65,6% para ramas exportadoras y 34,4% para ramas orientadas al mercado interno.
- El grupo `combustible` no se presenta como segmento autónomo en el libro de resultados ni en esta minuta; queda incorporado en la industria total y se conserva en el panel CSV para trazabilidad contable.

Ramas incluidas en el segmento exportador:
- 10: Elaboración de productos alimenticios
- 11 y 12: Elaboración de bebidas y elaboración de productos de tabaco
- 13: Fabricación de productos textiles
- 15: Fabricación de cueros y productos conexos
- 16: Producción de madera y fabricación de productos de madera y corcho, excepto muebles
- 17: Fabricación de papel y de los productos de papel
- 22: Fabricación de productos de caucho y plástico

Ramas incluidas en el segmento mercado interno:
- 14: Fabricación de prendas de vestir
- 18: Actividades de impresión y reproducción de grabaciones
- 20: Fabricación de sustancias y productos químicos
- 21: Fabricación de productos farmacéuticos, sustancias químicas medicinales y de productos botánicos
- 23: Fabricación de otros productos minerales no metálicos
- 24: Fabricación de metales comunes
- 25: Fabricación de productos derivados del metal, excepto maquinaria y equipo
- 26 y 27: Fabricación de los productos informáticos, electrónicos y ópticos. Fabricación de equipo eléctrico
- 28: Fabricación de maquinaria y equipo n.c.p
- 29 y 30: Fabricación de vehículos automotores, remolques y semirremolques. Fabricación de otros tipos de equipo de transporte
- 31: Fabricación de muebles
- 32: Otras industrias manufactureras
- 33: Reparación e instalación de la maquinaria y equipo

![Brecha cambiaria modelada](../output/figures/devaluacion_industria_segmentos_20260827_escenario_1_comercio_exterior/01_factor_devaluacion_2020_2024.png)

## Coeficientes de incidencia

Los coeficientes indican qué proporción de cada variable queda expuesta al cierre de la brecha cambiaria. Desde el punto de vista del contrafactual de paridad, el componente de VBP tiene signo positivo para la ganancia, porque eleva la valorización de ventas asociadas al tipo de cambio. En cambio, consumo intermedio, masa salarial, consumo de capital fijo e intereses pagados operan como gastos o costos; el stock imputado afecta negativamente la tasa porque eleva el capital adelantado.

![Coeficientes de incidencia por segmento](../output/figures/devaluacion_industria_segmentos_20260827_escenario_1_comercio_exterior/02_coeficientes_incidencia_segmentos.png)

| Sección | Variable afectada | Incidencia | Efecto contable ante cierre de brecha |
| --- | --- | --- | --- |
| Industria total | Consumo capital fijo | 1,7% | Negativo: eleva costos o gastos |
| Industria total | Consumo intermedio | 18,9% | Negativo: eleva costos o gastos |
| Industria total | Intereses pagados | 8,5% | Negativo: eleva costos o gastos |
| Industria total | Masa salarial | 9,3% | Negativo: eleva costos o gastos |
| Industria total | Stock imputado | 3,7% | Negativo: eleva capital adelantado |
| Industria total | VBP/exportador | 39,5% | Positivo para la ganancia |
| Mercado interno | Consumo capital fijo | 1,1% | Negativo: eleva costos o gastos |
| Mercado interno | Consumo intermedio | 22,7% | Negativo: eleva costos o gastos |
| Mercado interno | Intereses pagados | 8,5% | Negativo: eleva costos o gastos |
| Mercado interno | Masa salarial | 9,3% | Negativo: eleva costos o gastos |
| Mercado interno | Stock imputado | 1,8% | Negativo: eleva capital adelantado |
| Mercado interno | VBP/exportador | 10,7% | Positivo para la ganancia |
| Segmento exportador | Consumo capital fijo | 0,8% | Negativo: eleva costos o gastos |
| Segmento exportador | Consumo intermedio | 18,1% | Negativo: eleva costos o gastos |
| Segmento exportador | Intereses pagados | 8,5% | Negativo: eleva costos o gastos |
| Segmento exportador | Masa salarial | 9,3% | Negativo: eleva costos o gastos |
| Segmento exportador | Stock imputado | 0,9% | Negativo: eleva capital adelantado |
| Segmento exportador | VBP/exportador | 42,0% | Positivo para la ganancia |

## Resultados principales

La tasa de ganancia a precios básicos de la industria total cambia en promedio +14,4 pp entre 2020 y 2024. En el segmento exportador el cambio promedio es +15,5 pp. En el segmento mercado interno el cambio promedio es -4,8 pp.

![Tasa de ganancia a precios básicos](../output/figures/devaluacion_industria_segmentos_20260827_escenario_1_comercio_exterior/03_tasa_ganancia_base_escenario.png)

![Cambio en tasa de ganancia](../output/figures/devaluacion_industria_segmentos_20260827_escenario_1_comercio_exterior/04_variacion_tasa_ganancia_pp.png)

| Sección | TG base prom. | TG cierre prom. | Cambio prom. | TG base 2024 | TG cierre 2024 | Cambio 2024 | Var. ganancia 2024 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Segmento exportador | 14,8% | 30,3% | +15,5 pp | 14,4% | 32,6% | +18,2 pp | 131,9% |
| Industria total | 15,4% | 29,8% | +14,4 pp | 12,7% | 29,5% | +16,8 pp | 142,3% |
| Mercado interno | 19,3% | 14,5% | -4,8 pp | 17,4% | 11,5% | -5,9 pp | -30,3% |

## Mecanismo de transmisión en 2024

En 2024, el aumento de `vbp_pp` es el principal canal positivo. El gráfico y el cuadro expresan los deltas en miles de millones de pesos corrientes. Para la industria total equivale a 182,1 miles de millones de pesos corrientes. Ese impulso se compensa parcialmente por el aumento de consumo intermedio, remuneraciones, consumo de capital fijo, stock imputado e intereses pagados.

![Descomposición del efecto en 2024](../output/figures/devaluacion_industria_segmentos_20260827_escenario_1_comercio_exterior/05_descomposicion_efecto_2024.png)

| Sección | Delta VBP | Delta CI | Delta remuneraciones | Delta CCF | Delta stock | Delta intereses pagados |
| --- | --- | --- | --- | --- | --- | --- |
| Industria total | 182,1 | 64,9 | 5,6 | 0,25 | 8,7 | 0,26 |
| Segmento exportador | 132,8 | 41,8 | 3,6 | 0,09 | 1,6 | 0,17 |
| Mercado interno | 10,5 | 14,9 | 1,8 | 0,03 | 0,6 | 0,09 |

## Contribución relativa de los segmentos

La lectura por participaciones muestra que, en 2024, el segmento exportador explica 72,9% del delta de VBP de la industria total, frente a 5,8% del segmento mercado interno.

En magnitudes de 2024, el VBP de la industria total aumenta 182,1 miles de millones de pesos corrientes, mientras los gastos modelados aumentan 71,1 y el stock imputado aumenta 8,7. En el segmento exportador, el aumento de VBP es 132,8 frente a gastos por 45,6 y stock por 1,6. En mercado interno, el VBP aumenta 10,5, los gastos aumentan 16,8 y el stock 0,6.

![Participación de segmentos en los deltas 2024](../output/figures/devaluacion_industria_segmentos_20260827_escenario_1_comercio_exterior/06_participacion_segmentos_deltas_2024.png)

| Componente | Exportador / industria total | Mercado interno / industria total |
| --- | --- | --- |
| VBP/exportador | 72,9% | 5,8% |
| Consumo intermedio | 64,4% | 22,9% |
| Remuneraciones | 63,2% | 31,8% |
| Consumo capital fijo | 35,1% | 11,4% |
| Stock imputado | 19,0% | 6,7% |
| Intereses pagados | 65,6% | 34,4% |

## Interpretación

La simulación sugiere que la sobrevaluación cambiaria redistribuye condiciones de rentabilidad dentro de la industria. La lectura agregada de la industria total debe interpretarse con cautela porque sintetiza estructuras de exposición distintas. La separación entre segmento exportador y segmento mercado interno permite observar qué parte del resultado responde al canal de valorización del producto y qué parte queda condicionada por el encarecimiento de costos, capital adelantado e intereses pagados al cerrar la brecha cambiaria.

## Anexo técnico

La fórmula general aplicada es:

```text
delta_variable = variable_base * incidencia_seccion_variable * factor_devaluacion
variable_devaluacion = variable_base + delta_variable
factor_devaluacion = tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1
```

La ganancia a precios básicos bajo cierre de brecha/paridad se calcula como:

```text
ganancia_pb_devaluacion =
  ganancia_pb + delta_vbp_pp - delta_consumo_intermedio_estimado -
  delta_remuneraciones - delta_consumo_capital_fijo
```

El capital total adelantado bajo cierre de brecha/paridad incorpora el cambio en stock imputado y en capital circulante:

```text
capital_total_adelantado_devaluacion =
  capital_total_adelantado + delta_stock_capital_imputado +
  (delta_remuneraciones + delta_consumo_intermedio_estimado) / rotacion_calibrada_sobre_6_6
```

La tasa de ganancia a precios básicos bajo cierre de brecha/paridad se calcula como:

```text
tasa_ganancia_pb_devaluacion =
  ganancia_pb_devaluacion / capital_total_adelantado_devaluacion
```
