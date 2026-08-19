# Resultados EAAE-BCU: tasa de ganancia en tres niveles

Fuente de datos: `data/analysis-data/20260819_resultados_eaae_bcu_total_industria_subrama.xlsx`.

Esta minuta actualiza el informe `docs/20260706_resultados_eaae_bcu_total_industria_subrama.md` incorporando un tercer nivel agregado: industria manufacturera depurada de `17_18_papel_impresion` y `19_refinacion`. La tasa de ganancia de ese nivel se calcula desde sumas agregadas de ganancia y capital adelantado, no como promedio de tasas subramales.

## Criterios de lectura

- Todos los resultados construidos provienen de la EAAE. Se usan índices de precios del BCU para deflactar valores corrientes.
- Los tres niveles agregados son `economia_total`, `industria-total` e `industria-sin-papel-coque-refinacion`.
- El libro `20260819_resultados_eaae_bcu_total_industria_subrama.xlsx` recalcula capital adelantado y tasas de ganancia con la rotación operativa vigente, actualizada desde la revisión Mussi de microdatos EAAE.
- Las tasas de ganancia se muestran a precios básicos y a precios productor.
- Las descomposiciones del VAB usan valores corrientes para conservar cobertura anual completa.
- Las comparaciones de volumen usan resultados deflactados con índices BCU empalmados a base 2005=1.
- Todos los `deflactor_2005` quedan normalizados con valor 1 en 2005, incluyendo el agregado de industria depurada construido desde subramas.
- La manufactura depurada excluye el grupo papel/impresión/reproducción y coque/refinación de petróleo; por la homologación disponible no separa papel de impresión.

## Resultados agregados

### 1. Representatividad y peso manufacturero

La primera lectura compara el peso de la manufactura en BCU, el peso de la manufactura en EAAE y la cobertura de la manufactura EAAE respecto de la manufactura BCU. Se presentan como paneles separados para evitar mezclar lecturas de composición y representatividad.
Puede observarse cómo el peso de la manufactura está sobre representado en la EAAE (panel 1 vs panel 2) mientras que en general esta fuente representa entre el 80% y 90% del VAB reportado a nivel de cuentas nacionales, a lo largo de todo el período.

![Representatividad y peso manufacturero](../output/figures/eaae_bcu_tres_niveles_20260819/01_representatividad_peso_manufacturero.png)

La segunda lectura compara el peso de la manufactura depurada dentro de la manufactura total, usando tanto el VAB como el stock de capital operativo. Esta depuración permite dimensionar el peso de los grupos excluidos antes de interpretar las tasas de ganancia.

![Representatividad de la manufactura depurada](../output/figures/eaae_bcu_tres_niveles_20260819/01b_representatividad_manufactura_depurada.png)

A continuación se presenta una comparación entre la tasa de ganancia calculada a partir de EAAE y aquella calculada a partir de cuentas nacionales por Gabriel Oyanthabal. Las tasas se muestran en escala porcentual, sin dividir una serie por la otra, con el fin de complementar la evaluación de representatividad de los cálculos hechos a partir de EAAE.

![Tasa de ganancia EAAE frente a Oyanthabal](../output/figures/eaae_bcu_tres_niveles_20260819/01c_comparacion_tasa_ganancia_oyanthabal.png)

### 2. Tasa de ganancia

La comparación principal incorpora tres niveles: economía total, manufactura total y manufactura depurada. La línea punteada marca, en cada panel, el promedio temporal de la industria manufacturera total. La manufactura depurada permite observar cuánto cambia la trayectoria al retirar los grupos con comportamiento más singular dentro de la rama industrial.

![Tasa de ganancia en tres niveles](../output/figures/eaae_bcu_tres_niveles_20260819/02_tasa_ganancia_tres_niveles.png)

### 3. Descomposición del VAB: economía total

La descomposición distribuye el VAB a precios productor entre costo laboral, consumo de capital fijo y ganancia a precios productor. Las etiquetas marcan años extremos, años de referencia y el último punto disponible.

![Descomposición del VAB total](../output/figures/eaae_bcu_tres_niveles_20260819/03_descomposicion_vab_total_corrientes.png)

### 4. Descomposición del VAB: industria

La misma descomposición se replica para la manufactura agregada. Esta figura ayuda a distinguir si los cambios de tasa de ganancia provienen de la ganancia, del costo laboral o del consumo de capital fijo.

![Descomposición del VAB industrial](../output/figures/eaae_bcu_tres_niveles_20260819/04_descomposicion_vab_industria_corrientes.png)

### 5. Capital adelantado, VAB y ganancia

Este gráfico deja las variables en base 100 en 2004. Se excluye el capital total adelantado para evitar duplicar sus componentes y se agregan VAB y ganancia a precios constantes como referencia de desempeño.

![Capital adelantado, VAB y ganancia](../output/figures/eaae_bcu_tres_niveles_20260819/05_capital_vab_ganancia_base_2004.png)

### 6. Inversión manufacturera

La inversión manufacturera se separa en dos paneles y en cada uno se diferencia entre industria manufacturera total e industria depurada. Esto permite revisar si la depuración cambia la lectura del esfuerzo inversor.

En el primer panel la industria depurada está incorporada, pero queda prácticamente superpuesta con la manufactura total porque la FBCF subramal se distribuye proporcionalmente al VAB; por eso el cociente FBCF/VAB es casi idéntico para ambos agregados. Para facilitar la lectura, la manufactura total se muestra con línea punteada y punto hueco.

El máximo de inversión/VAB ocurre en 2014; papel, impresión y reproducción representa 133.1% de la FBCF manufacturera constante en ese año.

![Inversión manufacturera](../output/figures/eaae_bcu_tres_niveles_20260819/06_inversion_manufacturera.png)

### 7. Resultados manufactureros en índices

La comparación se focaliza en manufactura total y manufactura depurada para VAB, ganancia y capital adelantado. Esto permite evaluar si la depuración cambia sólo niveles o también la dinámica relativa.

![Resultados manufactureros en índices](../output/figures/eaae_bcu_tres_niveles_20260819/07_indices_industria_depurada.png)

### 8. Productividad del trabajo

La productividad se calcula como VAB a precios constantes por puesto de trabajo. Se muestran dos paneles comparables: uno usa VAB a precios básicos estimado y el otro VAB a precios productor. En ambos casos se mantienen las tres líneas agregadas para comparar economía total, manufactura total y manufactura depurada.

![Productividad del trabajo](../output/figures/eaae_bcu_tres_niveles_20260819/08_productividad_tres_niveles.png)

## Anexos

### 9. Ganancia industrial en índice de volumen

Se desplaza esta figura al anexo porque funciona como síntesis de la dinámica real de la ganancia industrial, luego de revisar composición, capital adelantado, inversión y productividad.

![Ganancia industrial en índice de volumen](../output/figures/eaae_bcu_tres_niveles_20260819/09_ganancia_indice_2005.png)

### 10. Tasa de ganancia a diferentes niveles de desagregación: exploración inicial

Referencia por subrama: se comparan economía total, industria manufacturera total, industria manufacturera depurada y los dos grupos excluidos de la depuración. La figura muestra tasas a precios básicos y a precios productor, con etiquetas en puntos de quiebre relevantes.

En el panel de papel, impresión y reproducción, la serie a precios básicos también está incluida. Su trayectoria se superpone casi exactamente con la de precios productor, por lo que el gráfico distingue ambas mediante tipo de línea: precios básicos en línea continua y precios productor en línea punteada.

![Tasa de ganancia a diferentes niveles de desagregación](../output/figures/eaae_bcu_tres_niveles_20260819/10_tasa_ganancia_niveles_desagregacion.png)

### 11. Comparación del stock de capital industrial EAAE-CIU

La comparación toma como referencia el stock de capital fijo en maquinaria y equipos de la industria publicado por CIU, cuya cobertura excluye refinería ANCAP y empresas de zonas francas. Para aproximar una frontera comparable desde EAAE, se extrae directamente la columna de maquinaria y equipos de los cuadros originales de activos fijos y se resta la maquinaria y equipos de la actividad de refinación (`23` en CIIU Rev.3 y `19_refinacion` en CIIU Rev.4). No se utiliza la operación `stock total - construcciones`, porque esa alternativa conservaría dentro del agregado otros activos e intangibles. La serie EAAE en pesos corrientes se convierte a dólares con el tipo de cambio venta de INE-BROU correspondiente al último valor disponible de diciembre de cada año. Luego se deflacta con un proxy BCU construido como deflactor implícito del VAB de subramas industriales excluyendo refinación, base 2005=1, y se expresa como índice 2008=100. El equipo debe leer esta deflactación como aproximación sectorial, no como deflactor específico de bienes de capital. Los años 2002 y 2011 quedan sin dato EAAE porque no existe cuadro de activos fijos por tipo y no se imputa la composición maquinaria/equipos para este ejercicio.

| año | CIU USD corr. | CIU ind. | EAAE USD corr. | EAAE USD const. proxy | EAAE ind. | EAAE/CIU USD % |
|---:|---:|---:|---:|---:|---:|---:|
| 2001 | 836.0 | 48.3 | 921.7 | 824.5 | 49.5 | 110.3 |
| 2002 | 731.0 | 42.2 | NA | NA | NA | NA |
| 2003 | 707.0 | 40.8 | 683.6 | 847.6 | 50.9 | 96.7 |
| 2004 | 742.0 | 42.9 | 808.2 | 864.0 | 51.9 | 108.9 |
| 2005 | 900.0 | 52.0 | 945.8 | 945.8 | 56.8 | 105.1 |
| 2006 | 1019.0 | 58.9 | 1036.5 | 976.2 | 58.6 | 101.7 |
| 2007 | 1292.0 | 74.6 | 1471.6 | 1163.1 | 69.8 | 113.9 |
| 2008 | 1731.0 | 100.0 | 2186.6 | 1666.0 | 100.0 | 126.3 |
| 2009 | 1928.0 | 111.4 | 2432.7 | 1475.8 | 88.6 | 126.2 |
| 2010 | 2574.0 | 148.7 | 2527.3 | 1472.7 | 88.4 | 98.2 |
| 2011 | 3271.0 | 189.0 | NA | NA | NA | NA |
| 2012 | 2371.5 | 137.0 | 2602.4 | 1253.9 | 75.3 | 109.7 |
| 2013 | 2579.2 | 149.0 | 2551.7 | 1296.2 | 77.8 | 98.9 |
| 2014 | 2838.8 | 164.0 | 4167.5 | 2089.8 | 125.4 | 146.8 |
| 2015 | 2890.8 | 167.0 | 3731.8 | 2136.2 | 128.2 | 129.1 |
| 2016 | 2994.6 | 173.0 | 3941.4 | 2135.7 | 128.2 | 131.6 |
| 2017 | 2890.8 | 167.0 | 3829.5 | 2287.5 | 137.3 | 132.5 |
| 2018 | 2890.8 | 167.0 | 3726.8 | 2196.3 | 131.8 | 128.9 |
| 2019 | 2873.5 | 166.0 | 3483.6 | 2169.7 | 130.2 | 121.2 |
| 2020 | 2856.2 | 165.0 | 3164.7 | 2163.7 | 129.9 | 110.8 |
| 2021 | 2890.8 | 167.0 | 3225.5 | 1906.8 | 114.5 | 111.6 |
| 2022 | 2786.9 | 161.0 | 3378.5 | 1676.8 | 100.6 | 121.2 |
| 2023 | 2717.7 | 157.0 | 6282.3 | 3157.0 | 189.5 | 231.2 |
| 2024 | 2717.7 | 157.0 | 4783.2 | 2621.3 | 157.3 | 176.0 |

## Reproducción

Desde la raíz del repositorio:

```bash
Rscript command-files/analysis-command-files/06_visualizar_resultados_eaae_bcu_tres_niveles.R
```
