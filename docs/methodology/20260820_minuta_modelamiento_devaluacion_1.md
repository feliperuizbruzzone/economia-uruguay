# Modelamiento de devaluación 1

Fuente de trabajo: `data/analysis-data/20260820_modalamiento-devaluacion.xlsx`.

Esta minuta documenta la hoja `devaluación-1`, incorporada al libro de modelamiento de devaluación de la industria manufacturera agregada. La hoja simula un escenario contable en el que el tipo de cambio pasa desde el nivel comercial (`tipo_cambio_comercial_pesos_usd`) al nivel de paridad (`tipo_cambio_paridad_pesos_usd`). El ejercicio se construye en valores corrientes y no modifica cantidades, productividad, estructura sectorial ni decisiones de inversión.

## Insumos

| Insumo | Fuente | Uso |
|---|---|---|
| `resultados-corrientes` | mismo libro de modelamiento | base monetaria de VBP, VAB, consumo intermedio, remuneraciones, consumo de capital fijo, stock imputado, ganancia y tasa de ganancia |
| `tipo-cambio` | mismo libro de modelamiento | tipo de cambio comercial y tipo de cambio de paridad por año |
| `coeficientes-devaluacion` | mismo libro de modelamiento | variables afectadas, incidencia de la devaluación, dirección del efecto y fórmula |
| `rotacion_calibrada_sobre_6_6` | último panel `*_panel_eeae_bcu_total_industria_subrama.csv` | rotación operativa explícita de la industria manufacturera total |

La rotación se recupera desde el panel integrado para la fila `nivel_panel == "industria_total"` y `seccion == "C"`. No se usa una rotación fija ni una rotación reconstruida por supuesto. El script valida que la rotación explícita coincida con la rotación implícita del libro compacto:

```text
consumo_intermedio_estimado / capital_circulante_constante_adelantado
remuneraciones / capital_variable_adelantado
```

## Factor de devaluación

El factor aplicado en la hoja es:

```text
factor_devaluacion =
  tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1
```

Cada variable afectada se recalcula siguiendo la fórmula de la hoja `coeficientes-devaluacion`:

```text
variable_devaluacion =
  variable_base + variable_base * incidencia * factor_devaluacion
```

La columna `Efecto` se usa como interpretación económica sobre la ganancia. El `VBP` tiene efecto positivo; consumo intermedio, masa salarial, consumo de capital fijo, stock imputado e intereses tienen efecto negativo sobre la ganancia o sobre su denominador.

## Variables afectadas

| Variable en coeficientes | Variable operativa | Tratamiento |
|---|---|---|
| `VBP` | `vbp_pp` | aumenta ingresos/producto en pesos; incide positivamente sobre VAB y ganancia |
| `Consumo intermedio` | `consumo_intermedio_estimado` | aumenta costos; reduce VAB y ganancia |
| `Masa salarial` | `remuneraciones` | aumenta costos laborales; reduce ganancia y eleva capital variable adelantado |
| `Consumo de capital fijo` | `consumo_capital_fijo` | aumenta deducción de la ganancia |
| `Stock capital imputado` | `stock_capital_imputado` | aumenta el denominador de la tasa de ganancia |
| `Intereses` | `intereses_industria_pesos` | afecta sólo las variables de ganancia y tasa post intereses |

## Ganancia y tasa de ganancia

La ganancia se recalcula por diferencias respecto del escenario base:

```text
ganancia_pb_devaluacion =
  ganancia_pb
  + delta_vbp_pp
  - delta_consumo_intermedio_estimado
  - delta_remuneraciones
  - delta_consumo_capital_fijo

ganancia_pp_devaluacion =
  ganancia_pp
  + delta_vbp_pp
  - delta_consumo_intermedio_estimado
  - delta_remuneraciones
  - delta_consumo_capital_fijo
```

Los intereses se incorporan exclusivamente en la ganancia post intereses:

```text
intereses_industria_pesos_devaluacion =
  intereses_industria_pesos + delta_intereses_industria_pesos

ganancia_pb_desp_intereses_devaluacion =
  ganancia_pb_devaluacion - intereses_industria_pesos_devaluacion
```

La tasa de ganancia se calcula como ganancia sobre capital total adelantado. Dado que el libro compacto no expone `capital_circulante_adelantado` ni `costo_laboral`, se conserva el denominador base observado y se agregan los cambios atribuibles a las variables afectadas disponibles:

```text
capital_total_adelantado_devaluacion =
  capital_total_adelantado
  + delta_stock_capital_imputado
  + (delta_remuneraciones + delta_consumo_intermedio_estimado) /
    rotacion_calibrada_sobre_6_6

tasa_ganancia_pb_devaluacion =
  ganancia_pb_devaluacion / capital_total_adelantado_devaluacion
```

La misma lógica se replica para precios productor y para las variantes post intereses.

## Calidad del resultado

| Control | Resultado |
|---|---:|
| Filas de la hoja `devaluación-1` | 24 |
| Columnas de la hoja `devaluación-1` | 66 |
| Cobertura anual | 2001-2024 |
| Faltantes en tipo de cambio | 0 |
| Faltantes en rotación explícita | 0 |
| Faltantes en tasas post intereses | 5 |
| Años sin intereses | 2001-2005 |
| Rango del factor de devaluación | -0,071 a 0,794 |
| Rango de la rotación industrial explícita | 3,85 a 4,22 |

El factor de devaluación es negativo en 2003 porque, para ese año, el tipo de cambio de paridad disponible queda por debajo del tipo de cambio comercial. En consecuencia, la hoja no impone que todos los años sean devaluatorios: aplica mecánicamente la relación entre ambas series de tipo de cambio.

## Script reproducible

La hoja se genera con:

```bash
Rscript command-files/analysis-command-files/10_build_modalamiento_devaluacion.R
```

El script lee el último libro `*_resultados_eaae_bcu_total_industria_subrama.xlsx`, el último panel `*_panel_eeae_bcu_total_industria_subrama.csv`, la serie de tipo de cambio y el CSV de coeficientes regenerado desde el archivo Mussi. Luego reescribe el libro `20260820_modalamiento-devaluacion.xlsx` con las hojas `resultados-corrientes`, `tipo-cambio`, `coeficientes-devaluacion` y `devaluación-1`.

## Supuestos y límites

- El ejercicio mide un escenario contable, no una predicción macroeconómica.
- Las cantidades producidas y vendidas se mantienen constantes.
- La incidencia de cada variable proviene exclusivamente de la hoja `coeficientes-devaluacion`.
- Los intereses sólo modifican la ganancia y tasa post intereses.
- La rotación usada es la rotación operativa vigente del panel EAAE integrado.
- La hoja trabaja en precios corrientes; no deflacta los resultados del escenario.
