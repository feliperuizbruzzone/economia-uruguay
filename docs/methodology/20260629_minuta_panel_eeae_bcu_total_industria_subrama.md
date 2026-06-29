---
title: "Minuta: panel integrado EAAE-BCU total, industria y subramas"
date: "2026-06-27"
updated: "2026-06-29"
lang: es-UY
---

# Minuta: panel integrado EAAE-BCU total, industria y subramas

## Objetivo

Se construyó un panel único en formato CSV para integrar información EAAE y
BCU en tres niveles de análisis:

- economía total;
- rama industrial manufacturera agregada;
- subramas industriales homologadas a grupos compatibles con CIIU Rev.4.

El archivo resultante es:

```text
data/analysis-data/20260629_panel_eeae_bcu_total_industria_subrama.csv
```

El script reproducible específico es:

```text
command-files/processing-command-files/13_build_panel_eaae_bcu_total_industria_subrama.R
```

La extracción directa de capital subrama queda encapsulada en:

```text
command-files/processing-command-files/eaae_subrama_capital_direct.py
```

## Estructura del panel

La base queda en formato largo con la clave:

```text
anno + nivel_panel + grupo_rev4_homologado
```

Para `economia_total` e `industria_total`, `grupo_rev4_homologado` queda vacío
porque el nivel ya identifica el agregado. Para subramas industriales, esa
columna identifica el grupo Rev.4 compatible.

La salida tiene 288 observaciones:

| Nivel | Filas |
|---|---:|
| `economia_total` | 24 |
| `industria_total` | 24 |
| `subrama_industrial` | 240 |

El nivel subrama incluye 10 grupos industriales por año entre 2001 y 2024. Se
excluye `38_recuperacion_materiales_fuera_c`, porque corresponde a una salida
de manufactura en la homologación Rev.4.

## Criterio de homologación CIIU

La homologación de subramas industriales sigue la grilla ya validada por el
equipo en:

```text
docs/methodology/20260623_grilla_equivalencias_subramas_manufactura_rev3_rev4.xlsx
```

El criterio no convierte la serie histórica en divisiones Rev.4 puras. En su
lugar, trabaja con **grupos Rev.4 compatibles**, porque varias divisiones Rev.3
se abren en más de una división Rev.4 o cambian de frontera sectorial.

Los grupos usados son:

| Grupo | Descripción |
|---|---|
| `10_11_12_alimentos_bebidas_tabaco` | Alimentos, bebidas y tabaco |
| `13_14_15_textiles_prendas_cuero` | Textiles, prendas y cuero |
| `16_madera` | Madera y productos de madera |
| `17_18_papel_impresion` | Papel, impresión y reproducción |
| `19_refinacion` | Coque y refinación de petróleo |
| `20_21_22_quimicos_farma_caucho_plastico` | Químicos, farmacéuticos, caucho y plástico |
| `23_24_minerales_metales` | Minerales no metálicos y metales comunes |
| `25_26_27_28_33_metal_equipos_reparacion` | Productos de metal, equipos y reparación |
| `29_30_vehiculos_transporte` | Vehículos y otros equipos de transporte |
| `31_32_muebles_otras_manufacturas` | Muebles y otras manufacturas |

## Variables EAAE

Para economía total se agregan las secciones del panel EAAE principal. Para la
rama industrial agregada se usa la fila `C` del panel EAAE. Para subramas se
usa el panel industrial homologado existente, construido desde los cuadros
primarios C1/C1.1.

Las variables de tasa de ganancia se calculan con el mismo criterio usado en el
libro EAAE:

```text
costo_laboral = remuneraciones
ganancia_pb = vab_pb_estimado - consumo_capital_fijo - costo_laboral
ganancia_pp = vab_pp - consumo_capital_fijo - costo_laboral
consumo_intermedio = vbp_pp - vab_pp
capital_circulante_adelantado = (costo_laboral + consumo_intermedio) / rotacion
capital_total_adelantado = stock_capital_imputado + capital_circulante_adelantado
tasa_ganancia_pb = ganancia_pb / capital_total_adelantado
tasa_ganancia_pp = ganancia_pp / capital_total_adelantado
```

Las rotaciones usadas son:

| Nivel | Rotación |
|---|---:|
| economía total | 4,2 |
| industria total y subramas industriales | 6,6 |

## Consumo de capital fijo y stock de capital

Para economía total y rama industrial, `consumo_capital_fijo`,
`stock_capital` y `stock_capital_imputado` se toman del panel EAAE principal.
En 2002 y 2011, `stock_capital` permanece vacío y `stock_capital_imputado`
usa la regla ya aprobada por el equipo: imputar a partir del ratio histórico
`stock_capital / consumo_capital_fijo`.

Para subramas industriales se extrae directamente `consumo_capital_fijo` desde
los cuadros C2/C2.1 y `stock_capital` desde los cuadros de activos fijos,
preservando la división publicada antes de aplicar la homologación Rev.4
compatible.

Las fuentes directas usadas son:

| Período | Consumo de capital fijo | Stock de capital |
|---|---|---|
| 2001 | `2 Digitos/EAE_cu2afe2_01.xls`, Cuadro 2 | `2 Digitos/EAE_cu15afe2_01.xls`, Cuadro 15 |
| 2002 | C2 | sin cuadro de stock directo |
| 2003-2005 | C2 | C11 |
| 2006-2010 | C2 | C7 |
| 2011 | C2 | sin cuadro de stock directo |
| 2012-2024 | C2.1 | C7 |

El caso 2001 requiere una excepción explícita: a nivel de dos dígitos el
Cuadro 9 no corresponde a stock de capital, sino a horas trabajadas. El stock
directo subrama 2001 se toma del Cuadro 15, que publica el valor de activos
fijos al 31/12/2001. Ese año mantiene el universo de empresas de 5 y más
personas ocupadas, igual que el panel subrama industrial construido desde C1.

Para subramas, `stock_capital` queda vacío sólo en 2002 y 2011, porque la
fuente publicada no trae cuadro de activos fijos para esos años. En esos casos
se completa `stock_capital_imputado` con la misma regla definida por el equipo:

- para 2002, promedio del ratio `stock_capital / consumo_capital_fijo` de
  2003-2005 dentro de cada subrama homologada;
- para 2011, promedio del ratio `stock_capital / consumo_capital_fijo` de
  2012-2024 dentro de cada subrama homologada.

El panel conserva trazabilidad con las columnas `metodo_stock_capital`,
`metodo_consumo_capital_fijo`, `calidad_capital_eaae`,
`codigos_capital_fuente` y `archivos_capital_fuente`.

## Deflactores BCU y empalme

Actualización del 2026-06-29: los tres niveles del panel integrado usan
deflactores implícitos BCU del VAB. Por lo tanto, la economía total ya no se
deflacta con el índice procesado de Oyanthabal. La razón es mantener una regla
homogénea dentro de este artefacto: economía total, industria total y subramas
industriales pasan por el mismo criterio de deflactor BCU empalmado a
2005=1.

El deflactor se calcula como:

```text
deflactor_vab_bcu = vab_corriente_bcu / vab_constante_bcu
```

Para economía total, el agregado elegido es el VAB de sectores de actividad,
consistente con la economía total EAAE construida por suma sectorial. No se usa
la fila de PIB total porque incorpora impuestos netos sobre productos y no
replica la misma frontera contable del agregado EAAE por sectores.

Las filas BCU usadas para economía total son:

| Base BCU | Fila usada | Código operativo en el panel |
|---|---|---|
| 1997 | `Subtotal` | `__TOTAL_VAB_SECTORES__` |
| 2005 | `VALOR AGREGADO BRUTO DE LOS SECTORES DE ACTIVIDAD` | `__TOTAL_VAB_SECTORES__` |
| 2016 | `Total VAB` | `__TOTAL_VAB_SECTORES__` |

Para industria y subramas se conserva el criterio ya documentado: usar las
filas BCU compatibles con la industria manufacturera y con cada grupo
homologado Rev.4. Cuando BCU no publica una frontera exacta, el panel marca la
calidad del deflactor como `reconstruido_por_suma` o `proxy_grupo_amplio`.

### Unificación de clasificaciones BCU-EAAE

El empalme de precios requiere que cada serie BCU dialogue con la misma unidad
analítica del panel EAAE. Por eso, antes de encadenar los índices, se construye
un mapa común para tres niveles:

- `economia_total`: agregado de VAB de sectores de actividad BCU, compatible
  con la economía total EAAE construida por suma sectorial.
- `industria_total`: industria manufacturera agregada; en las bases Rev.3 de
  BCU se identifica como `D`, y en la base 2016 se reconstruye desde las filas
  manufactureras `C.*`.
- `subrama_industrial`: grupos industriales Rev.4 compatibles definidos para
  la homologación EAAE. No son divisiones Rev.4 puras, sino agrupamientos
  comparables que resuelven correspondencias Rev.3 -> Rev.4 uno-a-muchos o
  fronteras publicadas más agregadas.

En las bases BCU 1997 y 2005 predominan códigos compatibles con CIIU Rev.3,
por ejemplo `D.15-D.16`, `D.17 a D.19` o `D.24 - D.25`. En la base BCU 2016
se usan códigos Rev.4, por ejemplo `C.101T.0`, `C.13TT.0`, `C.20TV.0` o
`C.3PTT.0`. El script no fuerza una equivalencia atomizada cuando la fuente no
la permite: si la categoría BCU coincide razonablemente con el grupo EAAE se
marca como `directo`; si debe sumarse más de una fila BCU se marca como
`reconstruido_por_suma`; y si BCU solo publica una frontera más amplia o
cruzada se marca como `proxy_grupo_amplio`. Los códigos efectivamente usados
quedan registrados en `codigos_bcu_deflactor`.

### Encadenamiento temporal de bases BCU

Todos los deflactores se empalman a base 2005=1. El criterio aplicado es:

- 2001-2005: serie BCU base 1997 normalizada en 2005;
- 2005-2016: serie BCU base 2005;
- 2017-2024: serie BCU base 2016 encadenada desde 2016 por variaciones
  interanuales.

Operativamente, para cada nivel o grupo homologado se calcula primero el índice
implícito dentro de cada base:

```text
indice_precio_vab_fuente = vab_corriente_bcu / vab_constante_bcu
```

Luego se transforma cada tramo a una métrica común con base 2005=1:

```text
2001-2005:
deflactor_vab_bcu_2005[t] =
  indice_precio_vab_1997[t] / indice_precio_vab_1997[2005]

2005-2016:
deflactor_vab_bcu_2005[t] =
  indice_precio_vab_2005[t] / indice_precio_vab_2005[2005]

2017-2024:
deflactor_vab_bcu_2005[t] =
  deflactor_vab_bcu_2005[2016] *
  (indice_precio_vab_2016[t] / indice_precio_vab_2016[2016])
```

La serie base 1997 se usa solo para proyectar hacia atrás hasta 2001,
normalizada en 2005. La serie base 2005 fija el tramo central y entrega el
nivel de 2016 expresado en base 2005. Desde 2017 se aplican las variaciones de
la base 2016 sobre ese nivel 2016. Así se evita mezclar niveles absolutos de
bases distintas y se aprovecha cada base en el tramo donde ofrece la
clasificación y cobertura más pertinentes.

En la salida actual, `deflactor_2005` replica el deflactor BCU empalmado
`deflactor_vab_bcu_2005`, y `fuente_deflactor` queda como
`bcu_indice_implicito_vab` para todas las filas. La columna
`gdp_price_index_base_2005` ya no se incluye en este panel integrado.

El panel conserva las siguientes columnas de trazabilidad:

- `deflactor_vab_bcu_2005`;
- `deflactor_2005`;
- `fuente_deflactor`;
- `fuente_base_bcu`;
- `metodo_empalme_bcu`;
- `calidad_deflactor_bcu`;
- `codigos_bcu_deflactor`;
- `nota_deflactor_bcu`.

La calidad del deflactor puede ser:

| Valor | Interpretación |
|---|---|
| `directo` | BCU publica una categoría razonablemente coincidente. |
| `reconstruido_por_suma` | Se suma más de una fila BCU compatible. |
| `proxy_grupo_amplio` | BCU publica una frontera más amplia o cruzada. |
| `directo_total_economia` | BCU publica o permite leer directamente el VAB agregado de sectores de actividad usado para economía total. |

## Validaciones aplicadas

El script detiene la ejecución si:

- la salida no tiene 288 filas;
- hay duplicados en la clave `anno + nivel_panel + grupo_rev4_homologado`;
- queda alguna fila sin `deflactor_2005`;
- falta algún insumo básico para tasa de ganancia:
  `vab_pp`, `remuneraciones`, `consumo_capital_fijo` o
  `stock_capital_imputado`.

La corrida del 2026-06-29 produjo:

| Control | Resultado |
|---|---:|
| filas | 288 |
| columnas | 78 |
| filas sin deflactor | 0 |
| filas sin insumos básicos de tasa de ganancia | 0 |

Controles específicos del cambio de deflactor:

| Control | Resultado |
|---|---|
| `fuente_deflactor` | `bcu_indice_implicito_vab` en todas las filas |
| `deflactor_vab_bcu_2005` | sin valores faltantes |
| `deflactor_2005` | sin valores faltantes |
| `gdp_price_index_base_2005` | no incluido en el panel integrado |
| código BCU de economía total | `__TOTAL_VAB_SECTORES__` |

### Validaciones de calidad tipo 20260605

Además de las validaciones estructurales del script, se replicaron las
validaciones disponibles en el libro EAAE del 2026-06-05 para tres niveles:
economía total, industria manufacturera agregada y subramas industriales. Las
métricas son:

```text
vab_vbp = vab_pp / vbp_pp
consumo_intermedio_estimado
remuneraciones_vab = remuneraciones / vab_pp
stock_vab = stock_capital_imputado / vab_pp
```

Se marcaron como fallas duras los siguientes casos:

- `vab_vbp` fuera del intervalo `[0, 1]`;
- `consumo_intermedio_estimado < 0`;
- `remuneraciones_vab > 1`;
- `stock_vab <= 0`.

La aplicación de estos controles no detectó fallas duras:

| Nivel | Filas | Fallas duras |
|---|---:|---:|
| economía total | 24 | 0 |
| industria total | 24 | 0 |
| subrama industrial | 240 | 0 |

Los rangos observados fueron:

| Nivel | `vab_vbp` | `remuneraciones_vab` | `stock_vab` | `ccf_vab` |
|---|---|---|---|---|
| economía total | 0,368-0,483; mediana 0,441 | 0,350-0,554; mediana 0,511 | 1,097-1,764; mediana 1,240 | 0,069-0,131; mediana 0,089 |
| industria total | 0,271-0,375; mediana 0,301 | 0,231-0,449; mediana 0,382 | 0,894-1,677; mediana 1,250 | 0,079-0,114; mediana 0,097 |
| subrama industrial | 0,121-0,615; mediana 0,325 | 0,021-0,870; mediana 0,476 | 0,207-10,701; mediana 1,035 | 0,008-0,345; mediana 0,096 |

La lectura general es positiva: las validaciones básicas no muestran valores
imposibles, el consumo intermedio estimado no toma valores negativos y no hay
casos donde las remuneraciones superen el VAB. Para economía total e industria
total, los rangos son consistentes con las hojas `check-calidad-total` y
`check-calidad-C` del libro EAAE 20260605.

En subramas aparecen valores extremos que no invalidan el panel, pero sí deben
tratarse como alertas interpretativas:

- `stock_vab` alto en `16_madera` en 2008;
- `stock_vab` alto en `17_18_papel_impresion` en 2007, 2014, 2016 y 2020-2024;
- `remuneraciones_vab` alto en `13_14_15_textiles_prendas_cuero` en 2012,
  2017, 2019 y 2022-2024;
- `vab_vbp` bajo en `19_refinacion` en 2008, `16_madera` en 2008 y 2020, y
  `29_30_vehiculos_transporte` en 2024.

Estos casos se consideran alertas de revisión sustantiva, no errores
automáticos de extracción. Deben mirarse especialmente si se calculan tasas de
ganancia, productividad o comparaciones entre subramas.

Distribución de calidad de capital EAAE:

| Nivel | Calidad | Filas |
|---|---|---:|
| economía total | `directo_agregado` | 24 |
| industria total | `directo` | 22 |
| industria total | `imputado` | 2 |
| subrama industrial | `directo` | 220 |
| subrama industrial | `directo_con_stock_imputado` | 20 |

Distribución de calidad de deflactores:

| Nivel | Calidad | Filas |
|---|---|---:|
| economía total | `directo_total_economia` | 24 |
| industria total | `directo` | 16 |
| industria total | `reconstruido_por_suma` | 8 |
| subrama industrial | `directo` | 140 |
| subrama industrial | `reconstruido_por_suma` | 44 |
| subrama industrial | `proxy_grupo_amplio` | 56 |

## Criterio de uso

El panel es adecuado para pruebas integradas de tasa de ganancia y valores
constantes por economía total, industria y subramas. Para análisis sustantivo
de subramas, se recomienda distinguir resultados con deflactores `directo` o
`reconstruido_por_suma` de los casos `proxy_grupo_amplio`.

La principal limitación remanente no es una asignación proporcional, sino la
ausencia de stock original en 2002 y 2011. En esos años la serie operativa usa
`stock_capital_imputado`, mientras `stock_capital` queda vacío para preservar
la diferencia entre dato directo e imputación.

En términos de calidad de datos, la economía total y la industria agregada se
pueden usar con alta confianza dentro de las decisiones metodológicas
documentadas. Las subramas también quedan operativas para análisis, pero los
resultados deben leerse junto con `calidad_capital_eaae`,
`calidad_deflactor_bcu` y las alertas interpretativas de `stock_vab`,
`remuneraciones_vab` y `vab_vbp`.
