# Escenario 2: incidencia de bienes transables

Fuente de trabajo: `data/analysis-data/20260827_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx`, hojas `escenario-inicial`, `tipo-cambio` y `Escenario 2 - Bienes Transables`.

## Introducción

Este escenario modela la apropiación de riqueza vía sobrevaluación sobre el conjunto de mercancías cuyos precios internos se rigen por precios internacionales, aunque sean producidas localmente y vendidas en el mercado interno. Por eso incorpora también la revaluación de producción local transable y su efecto sobre la tasa de ganancia.

La minuta interpreta el cierre anual de la brecha entre tipo de cambio comercial y tipo de cambio de paridad como forma de dimensionar la apropiación de riqueza asociada a sostener un tipo de cambio sobrevaluado. El ejercicio se realiza año a año, sin efectos acumulados ni respuestas dinámicas de cantidades, productividad o estructura productiva.

## Síntesis

Las fuentes usadas son: EAAE para VBP, VAB, remuneraciones, consumo intermedio estimado, consumo de capital fijo, stock de capital y capital adelantado; Oyanthabal, con base en la metodología de Iñigo Carrera (2007), para los tipos de cambio comercial/paridad y los coeficientes de incidencia del ejercicio; microdatos del CIU para distribuir los intereses industriales entre ramas exportadoras y ramas orientadas al mercado interno; y la clasificación operativa de subramas industriales 2020-2024 usada para separar industria exportadora, mercado interno y combustible.

Se trabaja desde 2020 porque en ese tramo la fuente opera con ramas homogéneas. Extender el ejercicio al panel completo exigiría procesar distintas versiones CIIU, lo que vuelve incompatible diferenciar con criterio uniforme el segmento industrial exportador y el segmento orientado al mercado interno. Complementariamente, el período 2020-2024 es razonable para una lectura en valores corrientes porque evita grandes saltos de nivel asociados a cambios clasificatorios.

Bajo este escenario, la industria total pasa en 2024 de una tasa de ganancia a precios básicos de 12,7% a -10,8%. El segmento exportador pasa de 14,4% a 0,9%, mientras que el segmento mercado interno pasa de 17,4% a -15,2%.

## Supuestos y escenarios

- `escenario-inicial` contiene los valores corrientes observados para industria total, segmento exportador y segmento mercado interno.
- `Escenario 2 - Bienes Transables` contiene el contrafactual del escenario modelado.
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

![Brecha cambiaria modelada](../output/figures/devaluacion_industria_segmentos_20260827_escenario_2_bienes_transables/01_factor_devaluacion_2020_2024.png)

## Coeficientes de incidencia

Los coeficientes indican qué proporción de cada variable queda expuesta al cierre de la brecha cambiaria. Desde el punto de vista del contrafactual de paridad, el componente de VBP tiene signo positivo para la ganancia, porque eleva la valorización de ventas asociadas al tipo de cambio. En cambio, consumo intermedio, masa salarial, consumo de capital fijo e intereses pagados operan como gastos o costos; el stock imputado afecta negativamente la tasa porque eleva el capital adelantado.

![Coeficientes de incidencia por segmento](../output/figures/devaluacion_industria_segmentos_20260827_escenario_2_bienes_transables/02_coeficientes_incidencia_segmentos.png)

| Sección | Variable afectada | Incidencia | Efecto contable ante cierre de brecha |
| --- | --- | --- | --- |
| Industria total | Consumo capital fijo | 1,7% | Negativo: eleva costos o gastos |
| Industria total | Consumo intermedio | 81,2% | Negativo: eleva costos o gastos |
| Industria total | Intereses pagados | 8,5% | Negativo: eleva costos o gastos |
| Industria total | Masa salarial | 45,3% | Negativo: eleva costos o gastos |
| Industria total | Stock imputado | 2,5% | Negativo: eleva capital adelantado |
| Industria total | VBP/transable | 33,3% | Positivo para la ganancia |
| Mercado interno | Consumo capital fijo | 1,1% | Negativo: eleva costos o gastos |
| Mercado interno | Consumo intermedio | 76,4% | Negativo: eleva costos o gastos |
| Mercado interno | Intereses pagados | 8,5% | Negativo: eleva costos o gastos |
| Mercado interno | Masa salarial | 8,3% | Negativo: eleva costos o gastos |
| Mercado interno | Stock imputado | 1,8% | Negativo: eleva capital adelantado |
| Mercado interno | VBP/transable | 10,7% | Positivo para la ganancia |
| Segmento exportador | Consumo capital fijo | 0,8% | Negativo: eleva costos o gastos |
| Segmento exportador | Consumo intermedio | 82,0% | Negativo: eleva costos o gastos |
| Segmento exportador | Intereses pagados | 8,5% | Negativo: eleva costos o gastos |
| Segmento exportador | Masa salarial | 13,3% | Negativo: eleva costos o gastos |
| Segmento exportador | Stock imputado | 0,9% | Negativo: eleva capital adelantado |
| Segmento exportador | VBP/transable | 42,0% | Positivo para la ganancia |

## Resultados principales

La tasa de ganancia a precios básicos de la industria total cambia en promedio -20,2 pp entre 2020 y 2024. En el segmento exportador el cambio promedio es -12,2 pp. En el segmento mercado interno el cambio promedio es -27,2 pp.

![Tasa de ganancia a precios básicos](../output/figures/devaluacion_industria_segmentos_20260827_escenario_2_bienes_transables/03_tasa_ganancia_base_escenario.png)

![Cambio en tasa de ganancia](../output/figures/devaluacion_industria_segmentos_20260827_escenario_2_bienes_transables/04_variacion_tasa_ganancia_pp.png)

| Sección | TG base prom. | TG cierre prom. | Cambio prom. | TG base 2024 | TG cierre 2024 | Cambio 2024 | Var. ganancia 2024 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Segmento exportador | 14,8% | 2,7% | -12,2 pp | 14,4% | 0,9% | -13,5 pp | -93,2% |
| Industria total | 15,4% | -4,8% | -20,2 pp | 12,7% | -10,8% | -23,5 pp | -196,0% |
| Mercado interno | 19,3% | -7,9% | -27,2 pp | 17,4% | -15,2% | -32,6 pp | -202,3% |

## Mecanismo de transmisión en 2024

En 2024, el aumento de `vbp_pp` es el principal canal positivo. El gráfico y el cuadro expresan los deltas en miles de millones de pesos corrientes. Para la industria total equivale a 153,5 miles de millones de pesos corrientes. Ese impulso se compensa parcialmente por el aumento de consumo intermedio, remuneraciones, consumo de capital fijo, stock imputado e intereses pagados.

![Descomposición del efecto en 2024](../output/figures/devaluacion_industria_segmentos_20260827_escenario_2_bienes_transables/05_descomposicion_efecto_2024.png)

| Sección | Delta VBP | Delta CI | Delta remuneraciones | Delta CCF | Delta stock | Delta intereses pagados |
| --- | --- | --- | --- | --- | --- | --- |
| Industria total | 153,5 | 278,9 | 27,5 | 0,25 | 5,9 | 0,26 |
| Segmento exportador | 132,8 | 189,3 | 5,1 | 0,09 | 1,6 | 0,17 |
| Mercado interno | 10,5 | 50,0 | 1,6 | 0,03 | 0,6 | 0,09 |

## Contribución relativa de los segmentos

La lectura por participaciones muestra que, en 2024, el segmento exportador explica 86,5% del delta de VBP de la industria total, frente a 6,9% del segmento mercado interno.

En magnitudes de 2024, el VBP de la industria total aumenta 153,5 miles de millones de pesos corrientes, mientras los gastos modelados aumentan 306,9 y el stock imputado aumenta 5,9. En el segmento exportador, el aumento de VBP es 132,8 frente a gastos por 194,6 y stock por 1,6. En mercado interno, el VBP aumenta 10,5, los gastos aumentan 51,8 y el stock 0,6.

![Participación de segmentos en los deltas 2024](../output/figures/devaluacion_industria_segmentos_20260827_escenario_2_bienes_transables/06_participacion_segmentos_deltas_2024.png)

| Componente | Exportador / industria total | Mercado interno / industria total |
| --- | --- | --- |
| VBP/transable | 86,5% | 6,9% |
| Consumo intermedio | 67,9% | 17,9% |
| Remuneraciones | 18,5% | 5,8% |
| Consumo capital fijo | 35,1% | 11,4% |
| Stock imputado | 28,1% | 9,9% |
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
