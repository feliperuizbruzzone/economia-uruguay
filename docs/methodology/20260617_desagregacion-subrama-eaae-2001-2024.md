---
title: "desagregación-subrama-eaae-2001-2024"
date: "2026-06-17"
lang: es-UY
---

# desagregación-subrama-eaae-2001-2024

## Objetivo

Definir hasta que nivel de subrama puede trabajarse con la informacion original
de la Encuesta Anual de Actividad Economica (EAAE) 2001-2024, distinguiendo
entre el panel final vigente y la granularidad potencial de los archivos
originales.

## Resumen Ejecutivo

Para una subbase EAAE comparable en el largo plazo, el nivel recomendado es
**division CIIU, equivalente a dos digitos**. Una base a cuatro digitos no es
recomendable como serie 2001-2024 porque la disponibilidad no es sistematica ni
homogenea.

El caso 2001 es excepcional: el RAR original contiene carpetas separadas
`Letra`, `2 Digitos` y `4 Digitos`. Desde 2002 en adelante, la fuente regular
usada por el pipeline (`C1`/`C1.1`) trabaja con columnas `seccion`, `division`
y `descripcion`, sin una columna estable de clase a cuatro digitos comparable
para toda la serie.

## Decision Operativa

Si se construye una subbase industrial para dialogar con el panel EAAE, la clave
tentativa deberia ser:

```text
anno + ciiu_version + seccion_fuente + division
```

Para manufactura:

- 2001-2007: CIIU Rev.3, manufactura corresponde a seccion `D`.
- 2008-2024: CIIU Rev.4, manufactura corresponde a seccion `C`.

La homologacion de divisiones Rev.3 a Rev.4 debe resolverse con una tabla de
equivalencias experta. No conviene aplicar una equivalencia automatica sin
revision porque algunas actividades cambian de frontera entre revisiones.

## Muestra Estructural Por Periodo

| Periodo | Fuente principal observada | CIIU | Desagregacion potencial | Evaluacion |
|---|---|---|---|---|
| 2001 | RAR con carpetas `Letra`, `2 Digitos` y `4 Digitos` | Rev.3 | Hasta 4 digitos solo para ese ano | Excepcional; no define la granularidad de la serie |
| 2002-2005 | Archivos `EAE_C1_<anno>.xls` | Rev.3 | Division publicada en columna `division` | Usable para subbase a dos digitos |
| 2006-2007 | Archivos `EAE_C1-F_2006.xls` y `EAE_C1_2007.xls` | Rev.3 | Division publicada en columna `division` | Usable, con atencion a duplicados/subcarpeta 2007 |
| 2008-2011 | Archivos `EAE_C1_<anno>.xls` | Rev.4 | Division publicada en columna `division` | Usable a dos digitos; 2011 tiene fuente incompleta |
| 2012-2016 | Archivos `EAE_C1.1_<anno>.xls` | Rev.4 | Division publicada en columna `division` | Usable a dos digitos |
| 2017-2024 | Archivos `EAE_C1.1_<anno>.xls` con 9 columnas | Rev.4 | Division publicada en columna `division` | Usable a dos digitos; agrega `vbp_pb` y `vab_pb` |

## Relacion Con El Panel Actual

El panel EAAE vigente esta agregado a:

```text
anno + seccion
```

Ese panel no conserva `division`, `descripcion` ni otras columnas de detalle.
La columna `seccion` ya esta homologada para producir una serie comparable
2001-2024.

Una subbase de divisiones deberia ser un artefacto separado, por ejemplo:

```text
data/analysis-data/YYYYMMDD_panel_eaae_divisiones.csv
```

No deberia reemplazar el panel principal, porque tendria problemas propios de
homologacion entre CIIU Rev.3 y Rev.4.

## Por Que No Cuatro Digitos

Una serie a cuatro digitos exigiria tres condiciones:

1. Que todos los anos publiquen clases CIIU atomicas a cuatro digitos.
2. Que las variables principales esten disponibles a ese nivel.
3. Que exista una homologacion Rev.3-Rev.4 robusta para clases.

La fuente EAAE 2001-2024 no cumple esas condiciones de forma sistematica. En
particular, 2001 trae una carpeta de `4 Digitos`, pero ese nivel no aparece como
contrato estable en los cuadros `C1`/`C1.1` de toda la serie.

## Recomendacion

Construir, si se necesita, una base complementaria a **dos digitos/division
CIIU**, preservando:

- `anno`
- `ciiu_version`
- `seccion_fuente`
- `division`
- `descripcion`
- variables economicas originales del cuadro `C1`/`C1.1`
- una marca de calidad/homologacion cuando se defina la equivalencia Rev.3-Rev.4

Para cuatro digitos, usar 2001 solamente como evidencia historica puntual o
como insumo auxiliar, no como panel comparable 2001-2024.
