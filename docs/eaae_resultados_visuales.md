# Resultados visuales EAAE

Fuente de datos: `data/analysis-data/20260603_panel_eaae.xlsx`.

Este informe resume visualmente los resultados propios calculados para la economía total y la rama industrial. Las figuras se generan con `command-files/analysis-command-files/03_visualizar_resultados_eaae.R` y se guardan como PNG para que GitHub las muestre directamente.

## Criterios de lectura

- Las tasas de ganancia, la descomposición del VAB, el capital adelantado y la participación industrial se muestran en valores corrientes para conservar la cobertura hasta 2024.
- Las ganancias indexadas usan las hojas de resultados en precios constantes y se expresan con base 2005=1.
- Las series en precios constantes e índices dependen del `gdp_price_index_base_2005`, disponible hasta 2019; por eso esas figuras no fuerzan continuidad después de ese año.
- Las interrupciones en capital adelantado reflejan años sin `stock_capital` en el panel.

## Figuras

### 1. Tasa de ganancia

La tasa se calcula como ganancia sobre `stock_capital + capital_circulante_adelantado`. Se presentan las variantes a precios básicos y a precios productor.

![Tasa de ganancia](../output/figures/eaae/01_tasa_ganancia_corrientes.png)

### 2. Ganancia en índice 2005=1

Compara la dinámica real de la ganancia a precios básicos y productor. La base común facilita comparar economía total e industria aunque sus niveles difieran.

![Ganancia en índice 2005=1](../output/figures/eaae/02_ganancia_indice_2005.png)

### 3. Descomposición del VAB: economía total

Distribuye el VAB a precios productor entre costo laboral, consumo de capital fijo y ganancia a precios productor.

![Descomposición del VAB total](../output/figures/eaae/03_descomposicion_vab_total_corrientes.png)

### 4. Descomposición del VAB: industria

Replica la misma descomposición para la rama industrial, permitiendo evaluar si su estructura difiere de la economía total.

![Descomposición del VAB industrial](../output/figures/eaae/04_descomposicion_vab_industria_corrientes.png)

### 5. Capital adelantado y componentes

Muestra el stock de capital, el capital circulante adelantado y el capital total adelantado. Las escalas se separan por ámbito para no ocultar la dinámica industrial.

![Capital adelantado y componentes](../output/figures/eaae/05_capital_adelantado_corrientes.png)

### 6. Participación industrial en el VAB total

Mide el peso de la industria manufacturera dentro del VAB total de la economía.

![Participación industrial](../output/figures/eaae/06_participacion_industria_vab_corrientes.png)

## Reproducción

Desde la raíz del repositorio:

```bash
Rscript command-files/analysis-command-files/03_visualizar_resultados_eaae.R
```
