---
title: "Minuta: deflactores BCU para análisis EAAE por subrama industrial"
date: "2026-06-23"
updated: "2026-06-27"
lang: es-UY
---

# Minuta: deflactores BCU para análisis EAAE por subrama industrial

## Objetivo

Evaluar si la información disponible en `data/input-data/bcu/indices-precios-1988-2024`
permite construir índices de precios para convertir los valores corrientes de
la EAAE 2001-2024 a valores constantes a nivel de subrama industrial, usando
como referencia la homologación de subramas definida en
`docs/methodology/20260623_grilla_equivalencias_subramas_manufactura_rev3_rev4.xlsx`.

## Síntesis ejecutiva

Para el objetivo específico de analizar la EAAE 2001-2024 por subrama
industrial, la fuente BCU es útil como insumo de deflactores, pero no permite
una equivalencia perfecta para todos los grupos de subrama homologados. La
opción técnicamente más defendible es construir índices implícitos de precios
por subrama BCU, empalmarlos a una base común y asignarlos a los grupos EAAE
con una marca explícita de calidad metodológica.

La variable más robusta para una serie larga es el deflactor implícito del
VAB/PIB industrial:

```text
indice_precio_vab = vab_corriente_bcu / vab_constante_bcu
```

Luego ese índice debería expresarse con una base común, por ejemplo 2005=1, y
usarse para deflactar los valores corrientes EAAE:

```text
vab_pp_constante_2005 = vab_pp_corriente_eaae / indice_precio_vab_bcu_2005
```

Para producción, consumo intermedio y otras variables monetarias de la EAAE, la
fuente BCU sólo ofrece deflactores específicos de forma clara desde 2016-2024.
Para 2001-2015, si se deflactan esas variables a nivel de subrama, habría que
usar el deflactor de VAB como proxy sectorial y documentarlo como supuesto
provisorio.

## Diagnóstico de la fuente BCU

La carpeta BCU combina cuatro tramos de información:

| Tramo | Base | Información observada | Uso recomendado |
|---|---:|---|---|
| 1988-1996 | 1983 | PIB por industrias en precios corrientes y constantes | Útil como antecedente, pero demasiado agregado para la grilla EAAE completa. |
| 1997-2005 | 1997 | PIB por industrias en precios corrientes y constantes | Útil para deflactores de VAB, con algunos grupos agregados. |
| 2005-2019* | 2005 | PIB por industrias en precios corrientes y constantes | Tramo central recomendado para empalmar deflactores 2001-2024. |
| 2016-2024** | 2016 | Producción, consumo intermedio y VAB en corrientes y constantes | Tramo más rico; permite deflactores específicos de producción, CI y VAB. |

La fuente sirve mejor para construir índices implícitos de precios que para
replicar exactamente la clasificación EAAE. En varios años BCU publica grupos
más agregados que los grupos EAAE homologados.

## Estrategia recomendada

Mantener el panel EAAE de subramas industriales con los 10 grupos Rev.4
compatibles ya definidos. Agregar una tabla auxiliar de deflactores BCU con
clave:

```text
anno + grupo_rev4_homologado
```

Esa tabla debería incluir, al menos:

- `indice_precio_vab_bcu_2005`
- `metodo_empalme`
- `calidad_deflactor`
- `tipo_deflactor`
- `nota_deflactor`

Las categorías sugeridas para `calidad_deflactor` son:

| Valor | Definición |
|---|---|
| `directo` | La categoría BCU coincide razonablemente con el grupo EAAE. |
| `reconstruido_por_suma` | El grupo EAAE se obtiene sumando varias categorías BCU compatibles. |
| `proxy_grupo_amplio` | BCU publica un agregado más amplio o con fronteras no equivalentes. |

## Método de empalme de deflactores

Antes de empalmar, el deflactor debe calcularse luego de agregar las categorías
BCU al grupo compatible con EAAE. Esto es preferible a promediar índices, porque
preserva la ponderación implícita de cada actividad:

```text
indice_precio_vab_grupo =
  sum(vab_corriente_bcu_grupo) / sum(vab_constante_bcu_grupo)
```

Luego se debe llevar cada tramo a una base común. Para el análisis EAAE
2001-2024, la base recomendada es 2005=1, porque existe como año de empalme
entre la serie base 1997 y la serie base 2005, y porque es la base ya usada en
otros resultados del proyecto.

### Opción 1: empalme por año común

Esta es la opción más simple y auditable. Para EAAE 2001-2024 implicaría usar:

```text
1997-base: 2001-2005
2005-base: 2005-2016 o 2005-2019
2016-base: 2016-2024
```

Con base final 2005=1:

```text
indice_1997_empalmado[t] =
  indice_1997[t] / indice_1997[2005]

indice_2005_empalmado[t] =
  indice_2005[t] / indice_2005[2005]

indice_2016_empalmado[t] =
  indice_2005_empalmado[2016] *
  (indice_2016[t] / indice_2016[2016])
```

La ventaja es que el procedimiento es transparente y fácil de reproducir. La
desventaja es que el empalme queda muy sensible al año elegido. Si 2016 tiene
un cambio metodológico fuerte, el nivel de toda la cola 2016-2024 puede quedar
afectado.

### Opción 2: empalme por promedio de años solapados

Para el salto entre la serie base 2005 y la serie base 2016 existe solapamiento
en 2016-2019. En vez de empalmar sólo en 2016, se puede calcular un factor
promedio:

```text
factor_empalme_2016 =
  promedio(indice_2005_empalmado[t] / indice_2016[t])
  para t = 2016, 2017, 2018, 2019

indice_2016_empalmado[t] =
  indice_2016[t] * factor_empalme_2016
```

La ventaja es que reduce la dependencia de un único año. La desventaja es que,
si los años 2017-2019 tienen carácter preliminar o diferencias de clasificación,
el promedio puede mezclar cambios de precios con diferencias metodológicas.

### Opción 3: empalme por variaciones interanuales

Esta opción prioriza la dinámica de cada fuente y evita forzar niveles entre
bases distintas. Se fija 2005=1 y se proyecta hacia atrás o hacia adelante con
las variaciones de la fuente correspondiente:

```text
indice_empalmado[t] =
  indice_empalmado[t-1] *
  (indice_fuente[t] / indice_fuente[t-1])
```

Operativamente:

- fijar `indice_empalmado[2005] = 1`;
- proyectar 2001-2004 hacia atrás con variaciones de la serie base 1997;
- proyectar 2006-2016 con variaciones de la serie base 2005;
- proyectar 2017-2024 con variaciones de la serie base 2016.

La ventaja es que cada tramo conserva su propia dinámica interanual. La
desventaja es que no resuelve por sí solo los problemas de equivalencia de
clasificación; por eso debe combinarse con la marca de calidad del deflactor.

### Opción 4: empalme sobre grupos BCU-compatibles más agregados

Cuando la equivalencia BCU-EAAE sea débil, conviene crear una versión de
sensibilidad más agregada. Algunos candidatos son:

```text
16_madera + 17_18_papel_impresion
23_24_minerales_metales + 25_26_27_28_33_metal_equipos_reparacion
31_32_muebles_otras_manufacturas, según compatibilidad del tramo
```

La ventaja es que mejora la calidad estadística del deflactor. La desventaja es
que se pierde detalle de subrama en la presentación final.

### Recomendación de empalme

Para la serie principal se recomienda usar el **empalme por variaciones
interanuales**, con base 2005=1, porque es el método más robusto frente a
cambios de nivel entre bases y clasificaciones. Como control de sensibilidad,
conviene comparar los resultados contra el empalme por promedio de años
solapados en 2016-2019.

La tabla final de deflactores debería conservar la trazabilidad del empalme con
campos como:

- `fuente_base`: `1997`, `2005` o `2016`;
- `metodo_empalme`: por ejemplo `variacion_interanual` o `promedio_solape`;
- `anno_base_indice`: `2005`;
- `factor_empalme`, cuando corresponda;
- `calidad_deflactor`;
- `nota_deflactor`.

## Factibilidad por grupo EAAE

| Grupo EAAE homologado | Descripción | Factibilidad para deflactor 2001-2024 | Observación |
|---|---|---|---|
| `10_11_12_alimentos_bebidas_tabaco` | Alimentos, bebidas y tabaco | Alta | Directo o reconstruible por suma en los tramos BCU. |
| `13_14_15_textiles_prendas_cuero` | Textiles, prendas y cuero | Alta | Mantiene correspondencia razonable durante la serie. |
| `16_madera` | Madera y productos de madera | Media | En algunos tramos BCU aparece unido a papel, impresión o muebles. |
| `17_18_papel_impresion` | Papel, impresión y reproducción | Media | En 1997-2005 aparece unido a madera y productos de madera; requiere proxy o agregado. |
| `19_refinacion` | Coque y refinación de petróleo | Alta | Correspondencia razonablemente directa. |
| `20_21_22_quimicos_farma_caucho_plastico` | Químicos, farmacéuticos, caucho y plástico | Alta/media | Generalmente reconstruible, aunque con agregaciones internas. |
| `23_24_minerales_metales` | Minerales no metálicos y metales comunes | Media/baja | Desde 2016 BCU combina parte de metales con productos metálicos. |
| `25_26_27_28_33_metal_equipos_reparacion` | Productos de metal, equipos y reparación | Media/baja | Grupo amplio; BCU no separa de forma perfectamente equivalente todas sus fronteras. |
| `29_30_vehiculos_transporte` | Vehículos y otros equipos de transporte | Alta | Correspondencia razonable desde 1997. |
| `31_32_muebles_otras_manufacturas` | Muebles y otras manufacturas | Media/baja | En BCU se mezcla con reparación, instalación o reciclado según el tramo. |

El grupo `38_recuperacion_materiales_fuera_c` no debería incorporarse al
análisis manufacturero Rev.4 salvo como trazabilidad histórica, porque no
integra manufactura en la homologación final.

## Propuesta operativa

1. Construir una tabla de deflactores BCU por subrama compatible, tomando como
   variable principal el índice implícito del VAB.
2. Empalmar los tramos de distinta base a un índice común 2005=1. Para la
   serie principal se recomienda el empalme por variaciones interanuales.
3. Asignar cada deflactor BCU al grupo EAAE homologado y registrar la calidad
   del empalme.
4. Deflactar `vab_pp` de EAAE por subrama como resultado principal.
5. Deflactar `vbp_pp`, `vbp_pb` y consumo intermedio sólo si el equipo acepta
   usar el deflactor de VAB como proxy para 2001-2015.
6. Construir una prueba de sensibilidad con empalme por promedio de años
   solapados en 2016-2019.
7. Mantener una versión alternativa BCU-compatible, más agregada, para pruebas
   de sensibilidad en los grupos de menor equivalencia.

## Recomendación al equipo

La recomendación es avanzar con una base de resultados constantes por subrama
EAAE, pero con marcas de calidad de deflactor. Esto permite analizar la dinámica
real de la industria con la mejor información disponible sin ocultar los
problemas de equivalencia entre clasificaciones.

Para el informe principal, conviene priorizar resultados con deflactores
`directo` o `reconstruido_por_suma`. Los grupos marcados como
`proxy_grupo_amplio` deberían presentarse con nota metodológica o, en análisis
de sensibilidad, agregarse a grupos BCU-compatibles más amplios.

## Conclusión

La fuente BCU no reproduce exactamente toda la homologación EAAE de subramas,
pero sí alcanza para construir deflactores operativos para un análisis EAAE
2001-2024. La salida más sólida es un panel EAAE de subramas con valores
corrientes, valores constantes del VAB y una metadata explícita sobre la calidad
del deflactor aplicado y el método de empalme usado.
