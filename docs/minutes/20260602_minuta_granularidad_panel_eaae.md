---
title: "Minuta: granularidad del panel EAAE y datos crudos"
date: "2026-06-02"
lang: es-UY
---

## Objetivo

Documentar el nivel de desagregacion del panel EAAE vigente y contrastarlo con
la granularidad disponible en los archivos originales de la EAAE.

## Sintesis

El panel EAAE vigente esta construido a nivel anual por seccion/rama CIIU
homologada. La clave unica del panel es:

```text
anno + seccion
```

La columna `seccion` no corresponde siempre a una letra original pura: contiene
codigos homologados para hacer comparable la serie historica 2001-2024, con el
cambio de CIIU Rev.3 a Rev.4 entre 2007 y 2008. Por eso aparecen sectores
agregados como `D_E`, `H_J`, `L_M_N` y `R_S`.

El panel final no conserva columnas de mayor detalle como `division`, `grupo`,
`clase` o `descripcion`. Esas columnas existen en muchos XLS originales, pero
hoy se usan solo como insumo para agregar las variables al nivel final
`anno` x `seccion`.

## Evidencia del panel vigente

Archivo revisado:

```text
data/analysis-data/20260602_panel_eaae.csv
```

Resumen observado:

| Elemento | Resultado |
|---|---:|
| Filas | 236 |
| Clave unica | `anno` + `seccion` |
| Duplicados en clave | 0 |
| Columnas de detalle CIIU | No hay `division`, `grupo`, `clase` ni `descripcion` |

Secciones homologadas presentes en algun año del panel:

```text
B, C, D_E, G, H_J, I, K, L_M_N, P, Q, R_S
```

Cobertura sectorial por periodo:

| Periodo | Secciones por año en el panel |
|---|---:|
| 2001-2007 | 8 |
| 2008 | 10 |
| 2009-2011 | 9 |
| 2012-2024 | 11 |

## Evidencia de los datos crudos

Los archivos originales si contienen mayor desagregacion, pero no de forma
homogenea durante toda la serie.

| Años | Granularidad observada en crudos | Tratamiento actual en el panel |
|---|---|---|
| 2001 | Archivos separados por `Letra`, `2 Digitos` y `4 Digitos` | El panel usa los cuadros por letra |
| 2002-2005 | Filas jerarquicas por seccion, division de 2 digitos, grupo de 3 digitos y clase de 4 digitos | Se toman las filas de total por seccion para evitar doble conteo |
| 2006-2007 | Filas desagregadas, mayormente 4 digitos y algunos codigos agrupados | Se agregan las filas a seccion homologada |
| 2008-2011 | Mayormente divisiones CIIU Rev.4 de 2 digitos, con algunos grupos publicados como combinaciones | Se agregan las filas a seccion homologada |
| 2012-2024 | Mayormente divisiones CIIU Rev.4 de 2 digitos, tambien con grupos combinados | Se agregan las filas a seccion homologada |

Ejemplos de codigos agrupados presentes en los XLS:

```text
11 y 12
26 y 27
29 y 30
36, 37 y 38
08 y 09
```

Estos grupos muestran que la desagregacion cruda no siempre equivale a
divisiones atomicas estrictamente comparables.

## Implicacion metodologica

El panel actual debe interpretarse como una base sectorial anual, no como una
base de divisiones o clases CIIU. Sirve para analisis por rama homologada, por
ejemplo manufactura `C`, comercio `G` o energia/agua/residuos `D_E`.

Si el equipo necesita explotar la informacion mas desagregada de los XLS, lo
conveniente seria crear una salida separada, por ejemplo:

```text
data/analysis-data/YYYYMMDD_panel_eaae_divisiones.csv
```

Una clave tentativa para esa base podria ser:

```text
anno + ciiu_version + seccion_fuente + division
```

Esa base deberia documentarse como un panel de divisiones/grupos publicados, no
como una serie completamente armonizada de divisiones atomicas. Para la rama
manufacturera, especialmente desde 2008, esta salida podria ser util porque hay
detalle relativamente estable por divisiones CIIU Rev.4.
