# Resultados EAAE-BCU: tasa de ganancia en tres niveles

Fuente de datos: `data/analysis-data/20260727_resultados_eaae_bcu_total_industria_subrama.xlsx`.

Esta minuta actualiza el informe `docs/20260706_resultados_eaae_bcu_total_industria_subrama.md` incorporando un tercer nivel agregado: industria manufacturera depurada de `17_18_papel_impresion` y `19_refinacion`. La tasa de ganancia de ese nivel se calcula desde sumas agregadas de ganancia y capital adelantado, no como promedio de tasas subramales.

## Criterios de lectura

- Los tres niveles agregados son `economia_total`, `industria-total` e `industria-sin-papel-coque-refinacion`.
- Las tasas de ganancia se muestran a precios básicos y a precios productor.
- Las descomposiciones del VAB usan valores corrientes para conservar cobertura anual completa.
- Las comparaciones de volumen usan resultados deflactados con índices BCU empalmados a base 2005=1.
- La manufactura depurada excluye el grupo papel/impresión/reproducción y coque/refinación de petróleo; por la homologación disponible no separa papel de impresión.

## Resultados agregados

### 1. Representatividad y peso manufacturero

La primera lectura compara el peso de la manufactura en BCU, el peso de la manufactura en EAAE y la cobertura de la manufactura EAAE respecto de la manufactura BCU. Se presentan como paneles separados para evitar mezclar lecturas de composición y representatividad.

![Representatividad y peso manufacturero](../output/figures/eaae_bcu_tres_niveles_20260727/01_representatividad_peso_manufacturero.png)

### 2. Tasa de ganancia

La comparación principal incorpora tres niveles: economía total, manufactura total y manufactura depurada. La manufactura depurada permite observar cuánto cambia la trayectoria al retirar los grupos con comportamiento más singular dentro de la rama industrial.

![Tasa de ganancia en tres niveles](../output/figures/eaae_bcu_tres_niveles_20260727/02_tasa_ganancia_tres_niveles.png)

### 3. Descomposición del VAB: economía total

La descomposición distribuye el VAB a precios productor entre costo laboral, consumo de capital fijo y ganancia a precios productor. Las etiquetas marcan años extremos, años de referencia y el último punto disponible.

![Descomposición del VAB total](../output/figures/eaae_bcu_tres_niveles_20260727/03_descomposicion_vab_total_corrientes.png)

### 4. Descomposición del VAB: industria

La misma descomposición se replica para la manufactura agregada. Esta figura ayuda a distinguir si los cambios de tasa de ganancia provienen de la ganancia, del costo laboral o del consumo de capital fijo.

![Descomposición del VAB industrial](../output/figures/eaae_bcu_tres_niveles_20260727/04_descomposicion_vab_industria_corrientes.png)

### 5. Capital adelantado, VAB y ganancia

Este gráfico deja las variables en base 100 en 2004. Se excluye el capital total adelantado para evitar duplicar sus componentes y se agregan VAB y ganancia a precios constantes como referencia de desempeño.

![Capital adelantado, VAB y ganancia](../output/figures/eaae_bcu_tres_niveles_20260727/05_capital_vab_ganancia_base_2004.png)

### 6. Inversión manufacturera

La inversión manufacturera se separa en dos paneles para que el pico de inversión sobre VAB no quede oculto por la escala de la FBCF constante.

El máximo de inversión/VAB ocurre en 2014; papel, impresión y reproducción representa 13.8% de la FBCF manufacturera constante en ese año.

![Inversión manufacturera](../output/figures/eaae_bcu_tres_niveles_20260727/06_inversion_manufacturera.png)

### 7. Resultados manufactureros en índices

La comparación se focaliza en manufactura total y manufactura depurada para VAB, ganancia y capital adelantado. Esto permite evaluar si la depuración cambia sólo niveles o también la dinámica relativa.

![Resultados manufactureros en índices](../output/figures/eaae_bcu_tres_niveles_20260727/07_indices_industria_depurada.png)

### 8. Productividad del trabajo

La productividad se calcula como VAB a precios constantes por puesto de trabajo. Se mantienen las tres líneas agregadas para comparar economía total, manufactura total y manufactura depurada.

![Productividad del trabajo](../output/figures/eaae_bcu_tres_niveles_20260727/08_productividad_tres_niveles.png)

### 9. Ganancia en índice de volumen

Se desplaza esta figura hacia el cierre de la sección agregada porque funciona mejor como síntesis de la dinámica real de la ganancia una vez revisados composición, capital adelantado, inversión y productividad.

![Ganancia en índice de volumen](../output/figures/eaae_bcu_tres_niveles_20260727/09_ganancia_indice_2005.png)

## Referencia por subrama

La lectura por subrama se conserva como referencia para interpretar la heterogeneidad interna de la manufactura. La tasa se muestra a precios productor.

![Tasa de ganancia por subrama industrial](../output/figures/eaae_bcu_tres_niveles_20260727/10_tasa_ganancia_subramas_corrientes.png)

## Reproducción

Desde la raíz del repositorio:

```bash
Rscript command-files/analysis-command-files/06_visualizar_resultados_eaae_bcu_tres_niveles.R
```
