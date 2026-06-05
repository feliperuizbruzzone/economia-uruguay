# Resultados visuales EAAE

Fuente de datos: `data/analysis-data/20260605_panel_eaae.xlsx`.

Este informe resume visualmente los resultados propios calculados para la economía total y la rama industrial. Las figuras se generan con `command-files/analysis-command-files/03_visualizar_resultados_eaae.R` y se guardan como PNG para que GitHub las muestre directamente.

## Criterios de lectura

- La representatividad EAAE/BCU compara el VAB corriente EAAE contra el VAB corriente BCU disponible en las hojas de resultados corrientes.
- Las tasas de ganancia, la descomposición del VAB y la participación industrial se muestran en valores corrientes para conservar la cobertura hasta 2024.
- Las ganancias indexadas y el capital adelantado usan las hojas de resultados en precios constantes.
- La inversión manufacturera usa `fbcf` de la rama C y se deflacta con `gdp_price_index_base_2005`; la relación de inversión sobre VAB usa el VAB industrial constante.
- Las series en precios constantes e índices dependen del `gdp_price_index_base_2005`, disponible hasta 2019; por eso esas figuras no fuerzan continuidad después de ese año.
- El capital adelantado usa `stock_capital_imputado`, que replica `stock_capital` cuando existe e imputa 2002 y 2011 con factores históricos de `stock_capital / consumo_capital_fijo`.

## Figuras

### 1. Representatividad de la serie EAAE en relación a PBI BCU

Compara el VAB corriente EAAE con el VAB corriente de referencia de BCU para economía total e industria.

![Representatividad EAAE/BCU](../output/figures/eaae/01_representatividad_eaae_bcu_corrientes.png)

### 2. Tasa de ganancia

La tasa se calcula como ganancia sobre `stock_capital_imputado + capital_circulante_adelantado`. Se presentan las variantes a precios básicos y a precios productor.

![Tasa de ganancia](../output/figures/eaae/01_tasa_ganancia_corrientes.png)

### 3. Ganancia en índice 2005=1

Compara la dinámica real de la ganancia a precios básicos y productor. La base común facilita comparar economía total e industria aunque sus niveles difieran.

![Ganancia en índice 2005=1](../output/figures/eaae/02_ganancia_indice_2005.png)

### 4. Descomposición del VAB: economía total

Distribuye el VAB a precios productor entre costo laboral, consumo de capital fijo y ganancia a precios productor.

![Descomposición del VAB total](../output/figures/eaae/03_descomposicion_vab_total_corrientes.png)

### 5. Descomposición del VAB: industria

Replica la misma descomposición para la rama industrial, permitiendo evaluar si su estructura difiere de la economía total.

![Descomposición del VAB industrial](../output/figures/eaae/04_descomposicion_vab_industria_corrientes.png)

### 6. Capital adelantado y componentes

Muestra el stock de capital, el capital circulante adelantado y el capital total adelantado en precios de 2005. Las escalas se separan por ámbito para no ocultar la dinámica industrial.

![Capital adelantado y componentes](../output/figures/eaae/05_capital_adelantado_corrientes.png)

### 7. Participación industrial en el VAB total

Mide el peso de la industria manufacturera dentro del VAB total de la economía.

![Participación industrial](../output/figures/eaae/06_participacion_industria_vab_corrientes.png)

### 8. Inversión manufacturera

Muestra la FBCF industrial en precios de 2005 en el eje derecho y la misma inversión como porcentaje del VAB manufacturero en el eje izquierdo.

![Inversión manufacturera](../output/figures/eaae/07_inversion_manufacturera_constante.png)

### 9. Resultados en índices

Compara en dos paneles, economía total e industria, la evolución del VAB, la masa salarial, la ganancia y el capital adelantado en índices con base 2005=1.

![Resultados en índices](../output/figures/eaae/08_indices_resultados_total_industria.png)

### 10. Productividad del trabajo en índice

Compara la evolución de la productividad del trabajo, medida como VAB a precios constantes por puesto de trabajo, para economía total y rama manufacturera.

![Productividad del trabajo en índice](../output/figures/eaae/09_productividad_trabajo_indice_2005.png)

## Reproducción

Desde la raíz del repositorio:

```bash
Rscript command-files/analysis-command-files/03_visualizar_resultados_eaae.R
```
