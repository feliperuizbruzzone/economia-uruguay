# Efecto de devaluación sobre industria manufacturera

Fuente de trabajo: `data/analysis-data/20260817_resultados_eaae_bcu_total_industria_subrama.xlsx`.

Esta minuta documenta la hoja `efecto-devaluacion-corrientes`, incorporada al libro de resultados EAAE-BCU. La hoja cuantifica, en pesos corrientes, un escenario contable de devaluación para la industria manufacturera total. El ejercicio compara el tipo de cambio comercial con el tipo de cambio de paridad y estima impactos diferenciados sobre ingresos exportadores, costos por consumo intermedio importado, intereses pagados en dólares, ganancias y salarios.

## Alcance

La unidad de análisis es `industria-total`, con una observación anual para 2001-2024. El ejercicio no modifica cantidades producidas, estructura de exportaciones, precios domésticos ni volumen físico de insumos. Por lo tanto, debe leerse como una simulación parcial de revalorización cambiaria, no como un modelo macroeconómico de equilibrio general.

La hoja utiliza valores corrientes porque el objetivo es medir impactos monetarios directos ante distintos tipos de cambio. Los resultados constantes del libro permanecen en hojas separadas.

## Insumos

| Insumo | Fuente en el libro | Tratamiento |
|---|---|---|
| `tipo_cambio_comercial_pesos_usd` | hoja `eaae` | valor anual común incorporado desde Mussi |
| `tipo_cambio_paridad_pesos_usd` | hoja `eaae` | valor anual común incorporado desde Mussi |
| `exportaciones_manufactura_eaae_95_miles_usd` | hoja `eaae` | exportaciones manufactureras ajustadas a cobertura EAAE |
| `prop_importado_consumo_intermedio` | hoja `eaae`, fila industria total | proporción importada del consumo intermedio manufacturero |
| `intereses_industria_eaae_ajuste_90_mill_usd` | hoja `eaae`, filas subrama industrial | valor anual único replicado en subramas; se toma una vez por año |
| `prop_consumo_obrero_importado` | hoja `eaae`, filas subrama industrial | promedio Mussi replicado en subramas; se toma una vez por año |
| `ganancia_pb`, `ganancia_pp`, `capital_total_adelantado`, `remuneraciones`, `consumo_intermedio` | hoja `resultados-corrientes` | magnitudes base para industria total |

Los intereses quedan como `NA` en 2001-2005 porque la fuente no provee dato para esos años. En consecuencia, las variables de ganancia y tasa de ganancia que incorporan intereses también quedan como `NA` en 2001-2005.

## Fórmulas

El factor de devaluación se define como:

```text
factor_devaluacion =
  tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd
```

Exportaciones:

```text
exportaciones_tcc_pesos =
  exportaciones_manufactura_eaae_95_miles_usd *
  tipo_cambio_comercial_pesos_usd * 1000

exportaciones_tcp_pesos =
  exportaciones_manufactura_eaae_95_miles_usd *
  tipo_cambio_paridad_pesos_usd * 1000

efecto_exportaciones_pesos =
  exportaciones_tcp_pesos - exportaciones_tcc_pesos
```

Consumo intermedio:

```text
consumo_intermedio_importado_pesos =
  consumo_intermedio * prop_importado_consumo_intermedio

efecto_consumo_intermedio_pesos =
  consumo_intermedio_importado_pesos * (factor_devaluacion - 1)
```

Intereses:

```text
intereses_tcc_pesos =
  intereses_industria_eaae_ajuste_90_mill_usd *
  tipo_cambio_comercial_pesos_usd * 1000000

intereses_tcp_pesos =
  intereses_industria_eaae_ajuste_90_mill_usd *
  tipo_cambio_paridad_pesos_usd * 1000000

efecto_intereses_pesos =
  intereses_tcp_pesos - intereses_tcc_pesos
```

Salarios:

```text
factor_canasta_obrera =
  (1 - prop_consumo_obrero_importado) +
  prop_consumo_obrero_importado * factor_devaluacion
```

En el escenario de salario nominal fijo:

```text
remuneraciones_reales_post_devaluacion =
  remuneraciones / factor_canasta_obrera

perdida_salarial_real_pesos =
  remuneraciones - remuneraciones_reales_post_devaluacion
```

En el escenario de salario compensado:

```text
remuneraciones_compensadas_devaluacion =
  remuneraciones * factor_canasta_obrera

efecto_salario_compensado_pesos =
  remuneraciones_compensadas_devaluacion - remuneraciones
```

Ganancia y tasa de ganancia:

```text
efecto_neto_capital_salario_fijo_pesos =
  efecto_exportaciones_pesos -
  efecto_consumo_intermedio_pesos -
  efecto_intereses_pesos

ganancia_pb_devaluacion_salario_fijo =
  ganancia_pb + efecto_neto_capital_salario_fijo_pesos

ganancia_pb_devaluacion_salario_compensado =
  ganancia_pb_devaluacion_salario_fijo -
  efecto_salario_compensado_pesos
```

Para la tasa de ganancia se recalcula el capital circulante adelantado porque la devaluación modifica el consumo intermedio y, en el escenario compensado, también el costo laboral:

```text
capital_circulante_devaluacion_salario_fijo =
  (costo_laboral + consumo_intermedio_devaluacion_pesos) /
  rotacion_calibrada_sobre_6_6

capital_total_devaluacion_salario_fijo =
  stock_capital_imputado + capital_circulante_devaluacion_salario_fijo

tasa_ganancia_pb_devaluacion_salario_fijo =
  ganancia_pb_devaluacion_salario_fijo /
  capital_total_devaluacion_salario_fijo
```

La misma lógica se replica para `ganancia_pp` y para el escenario de salario compensado.

## Calidad del resultado

| Control | Resultado |
|---|---:|
| Filas de la hoja | 24 |
| Cobertura anual | 2001-2024 |
| Faltantes en tipo de cambio | 0 |
| Faltantes en exportaciones | 0 |
| Faltantes en proporción importada del consumo intermedio | 0 |
| Faltantes en proporción importada del consumo obrero | 0 |
| Faltantes en intereses | 5 |
| Años sin intereses | 2001, 2002, 2003, 2004, 2005 |
| Años completos con intereses | 19 |
| Años parciales sin intereses | 5 |

Para 2006-2024, el factor de devaluación varía entre 1,24 y 1,79. En ese período, el efecto promedio anual sobre exportaciones industriales es positivo, cerca de 79.397 millones de pesos corrientes; el efecto promedio sobre consumo intermedio importado es un aumento de costos de 40.508 millones; el efecto promedio sobre intereses es un aumento de 1.457 millones. La pérdida salarial real promedio bajo salario nominal fijo es de 2.644 millones de pesos, mientras que la recomposición salarial necesaria para preservar poder de compra asciende en promedio a 2.773 millones.

En el escenario con salario nominal fijo, la tasa de ganancia a precios básicos aumenta en promedio 11,9 puntos porcentuales para los años con información completa de intereses. En el escenario con salario compensado, el aumento promedio baja a 10,9 puntos porcentuales. La diferencia entre ambos escenarios cuantifica el conflicto distributivo directo asociado al traslado de la devaluación sobre la canasta obrera.

## Limitaciones

- El ejercicio supone cantidades constantes y no modela cambios de producción, ventas, productividad ni sustitución de insumos.
- El efecto exportador asume que la diferencia cambiaria se apropia como mayor ingreso en pesos por el sector exportador.
- La proporción importada del consumo intermedio corresponde a manufactura total y se aplica al agregado industrial.
- La proporción importada del consumo obrero es un promedio construido desde fuentes Mussi y se aplica como coeficiente común.
- Los intereses son un insumo industrial agregado replicado en subramas; no se distribuyen por subrama en esta hoja.
- Las tasas de ganancia resultantes deben leerse como escenario contable comparativo, no como tasa observada.
