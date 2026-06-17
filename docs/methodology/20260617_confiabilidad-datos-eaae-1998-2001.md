---
title: "confiabilidad-datos-eaae-1998-2001"
date: "2026-06-17"
lang: es-UY
---

# confiabilidad-datos-eaae-1998-2001

## Objetivo

Documentar la confiabilidad de los archivos primarios `EAE_1998_2DIG.xls`,
`EAE_1999_2DIG.xls`, `EAE_2000_2DIG.xls` y `EAE_2001_2DIG.xls`, descargados
para construir el panel historico `eaae_1998_2001_2dig_panel.csv`.

La revision se concentra en detectar errores de rotulo anual, hojas duplicadas
entre archivos y disponibilidad efectiva de variables para un empalme posterior
con una base EAAE a dos digitos.

## Resumen Ejecutivo

La fuente es util para 1998, 2000 y 2001, con cobertura amplia de cuadros
economicos y de capital. El archivo 1999 presenta una falla importante: de sus
36 hojas de cuadros, 35 estan encabezadas como ano 2000 y son copias exactas de
las hojas equivalentes del archivo 2000. Solo la hoja 1 del archivo 1999 parece
corresponder efectivamente a 1999.

Por esta razon, el panel generado conserva 1999 solo para las variables basicas
del cuadro 1:

- `vbp_pp`
- `vab_pp`
- `remuneraciones`
- `puestos_trabajo`

Las variables de cuentas, FBCF, stock de capital, variacion de existencias y
componentes de FBKF quedan como `NA` en 1999.

## Fuentes Revisadas

| Ano de archivo | Archivo local | Estado general |
|---|---|---|
| 1998 | `data/input-data/eaae-1998-2001/EAE_1998_2DIG.xls` | Usable |
| 1999 | `data/input-data/eaae-1998-2001/EAE_1999_2DIG.xls` | Parcial; falla estructural por hojas copiadas de 2000 |
| 2000 | `data/input-data/eaae-1998-2001/EAE_2000_2DIG.xls` | Usable |
| 2001 | `data/input-data/eaae-1998-2001/EAE_2001_2DIG.xls` | Usable para los cuadros procesados |

Los cuatro libros tienen 37 hojas: 36 cuadros y una hoja indice. Los cuadros
estan duplicados por universo de tamano. Para el panel se usa solo el universo
`empresas_5_mas`.

## Diagnostico De Confiabilidad

### Archivo 1999

El problema principal esta en `EAE_1999_2DIG.xls`. El escaneo completo de hojas
detecto:

| Condicion | Cantidad de hojas |
|---|---:|
| Hojas con encabezado anual consistente con 1999 | 1 |
| Hojas con encabezado principal ano 2000 | 35 |
| Hojas que son copias exactas del archivo 2000 | 35 |

Las hojas copiadas corresponden a las hojas 2 a 36. Esto incluye los cuadros que
habrian permitido extraer:

- cuentas de produccion y valor agregado;
- consumo intermedio;
- impuestos netos;
- consumo de capital fijo;
- excedente de explotacion;
- FBCF;
- stock de capital;
- variacion de existencias;
- componentes de FBKF.

La hoja 1 del archivo 1999 no es copia del archivo 2000 y conserva datos
propios del ano 1999 para valor bruto de produccion, valor agregado,
remuneraciones y puestos de trabajo.

### Archivo 2001

El archivo `EAE_2001_2DIG.xls` presenta una alerta aislada: la hoja 6 esta
encabezada como ano 2000. Esa hoja corresponde a consumo de combustibles y no
fue usada en el panel generado. Por lo tanto, no afecta el panel actual.

Si en una etapa posterior se quisiera usar consumo de combustibles desde esta
fuente, esa hoja deberia revisarse manualmente antes de incorporarse.

## Disponibilidad Efectiva En El Panel

| Ano | Filas | Total economia | Secciones | Divisiones simples | Grupos de divisiones publicados | Variables disponibles |
|---|---:|---:|---:|---:|---:|---|
| 1998 | 29 | 1 | 7 | 11 | 10 | C1, C2, FBCF, stock, existencias, componentes FBKF |
| 1999 | 13 | 1 | 1 | 3 | 8 | Solo C1: VBP, VAB, remuneraciones y puestos |
| 2000 | 29 | 1 | 7 | 11 | 10 | C1, C2, FBCF, stock, existencias, componentes FBKF |
| 2001 | 32 | 1 | 8 | 13 | 10 | C1, C2, FBCF, stock, existencias, componentes FBKF |

## Variables Con Disponibilidad Parcial En 1999

Para 1999 quedan disponibles:

| Variable | Estado 1999 |
|---|---|
| `vbp_pp` | Disponible |
| `vab_pp` | Disponible |
| `remuneraciones` | Disponible |
| `puestos_trabajo` | Disponible |
| `consumo_intermedio` | No disponible |
| `impuestos_netos` | No disponible |
| `consumo_capital_fijo` | No disponible |
| `excedente_explotacion` | No disponible |
| `fbcf` | No disponible |
| `adquisiciones_importadas` | No disponible |
| `adquisiciones_en_plaza` | No disponible |
| `stock_capital` | No disponible |
| `variacion_existencias` | No disponible |
| `fbkf_maq_eq` | No disponible |

## Implicancias Para El Empalme

El ano 1999 no debe tratarse como un ano plenamente comparable para variables
de capital o cuentas de produccion detalladas. Si se usa en una serie larga,
conviene distinguir dos niveles de disponibilidad:

1. Serie basica 1998-2001: puede incluir VBP, VAB, remuneraciones y puestos de
   trabajo.
2. Serie ampliada 1998, 2000 y 2001: puede incluir consumo intermedio,
   impuestos netos, consumo de capital fijo, excedente, FBCF, stock,
   existencias y componentes de FBKF.

Para el empalme con una futura base EAAE a dos digitos, la unidad recomendada
sigue siendo la `division_publicada`, preservando los grupos originales
publicados. No conviene abrir grupos como `15-16` o `17-18-19` sin una regla de
homologacion experta.

## Decision De Procesamiento Vigente

El script `command-files/processing-command-files/10_process_eaae_1998_2001_2dig.R`
aplica las siguientes reglas:

- procesa solo el universo `empresas_5_mas`;
- detecta el bloque de hojas desde el indice, no desde posiciones fijas;
- omite hojas cuyo encabezado anual principal no coincide con el ano del
  archivo;
- conserva 1999 solo con la informacion confiable del cuadro 1;
- convierte variables monetarias desde miles de pesos corrientes a pesos
  corrientes;
- deja como `NA` las variables sin fuente confiable.

## Recomendacion

Mantener el panel `eaae_1998_2001_2dig_panel.csv` como artefacto util, pero
documentar a 1999 como ano de disponibilidad parcial. En paralelo, conviene
intentar conseguir otra copia del archivo 1999, porque la copia descargada
contiene una falla estructural clara.

Hasta contar con una fuente corregida, no deberian imputarse FBCF, stock,
consumo intermedio ni existencias para 1999 desde las hojas copiadas de 2000.
