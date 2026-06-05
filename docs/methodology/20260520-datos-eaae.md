---
title: "Reporte ejecutivo: variables EAAE sistematizadas"
date: "20 de mayo de 2026"
lang: es-UY
geometry: margin=1.6cm
fontsize: 9pt
---

## Objetivo y estado general

Este reporte resume la disponibilidad de las variables solicitadas por el
equipo de investigación en el panel construido a partir de la Encuesta Anual de
Actividad Económica (EAAE) de Uruguay. Los archivos vigentes siguen el patrón
`data/analysis-data/YYYYMMDD_panel_eaae.csv` y
`data/analysis-data/YYYYMMDD_panel_eaae.xlsx`, con 236 observaciones, 18
columnas y cobertura anual 2001-2024 por sección CIIU homologada. El CSV
contiene la base completa. El libro incluye la hoja `eaae` con la base
completa, `rama-C` con manufactura y `check-calidad-C` con controles anuales
para esa rama.

El panel ya integra variables de producción, valor agregado, trabajo,
remuneraciones, inversión, adquisiciones importadas, consumo de capital y stock
de capital. Algunas variables fueron identificadas en la fuente pero no tienen
cobertura suficiente para integrarse como serie completa; otras no aparecen en
la EAAE y requerirían fuentes externas.

## Resumen de variables

| Variable solicitada | Variable en panel | Cobertura | Cuadros fuente / estado |
|---|---|---|---|
| Inventarios | No integrada. Fuente identificada como `variacion_existencias` | 2001, 2003-2005 si se extrae | 2001 C10; 2003-2005 C12. No se encontró fuente 2006-2024 tras escaneo completo. |
| Stock de capital | `stock_capital` | 2001, 2003-2010, 2012-2024 | 2001 C9; 2003-2005 C11; 2006-2024 C7. Sin fuente en 2002 y 2011. |
| Valor bruto de la producción, precios básicos | `vbp_pb` | 2017-2024 | C1.1, columna VBP(pb). |
| Valor bruto de la producción, precios de productor | `vbp_pp` | 2001-2024 | 2001 C1 letra; 2002-2016 C1; 2017-2024 C1.1. |
| Ocupados | `puestos_trabajo` | 2001-2024 | 2001 C1 letra; 2002-2016 C1; 2017-2024 C1.1. |
| Valor agregado, precios básicos | `vab_pb` | 2017-2024 | C1.1, columna VAB(pb). |
| Valor agregado, precios de productor | `vab_pp` | 2001-2024 | 2001 C1 letra; 2002-2016 C1; 2017-2024 C1.1. |
| Consumo de capital fijo | `consumo_capital` | 2001-2024 | 2001-2011 C2; 2012-2024 C2.1. |
| FBKF / FBCF | `fbcf` | 2001, 2003-2010, 2012-2024 | 2001 C8; 2003-2005 C10; 2006-2024 C6. Sin fuente en 2002 y 2011. |
| FBKF en maquinaria y equipos | `fbkf_maq_eq` | 2001, 2003-2010, 2012-2024 | Componente de maquinaria y equipos de la FBKF: 2001 C11; 2003-2005 C13; 2006-2024 C8. Sin fuente en 2002 y 2011. |
| Adquisiciones importadas | `adquisiciones_importadas` | 2001, 2003-2010, 2012-2024 | Subcomponente `Importadas` dentro de adquisiciones de activo fijo en cuadros FBCF: 2001 C8; 2003-2005 C10; 2006-2024 C6. |
| Adquisiciones en plaza de origen importado | `adquisiciones_origen_importado` | 2004-2010, 2012-2024 | Subcomponente `En plaza / Origen Imp.` dentro de adquisiciones de activo fijo en cuadros FBCF; columna K cuando existe. |
| Importaciones de maquinaria | `importaciones_maquinaria` | 2004-2010, 2012-2024 | `adquisiciones_importadas + adquisiciones_origen_importado`; queda vacía cuando falta alguno de los componentes. |
| Remuneraciones | `remuneraciones` | 2001-2024 | 2001 C1 letra; 2002-2016 C1; 2017-2024 C1.1. Incluye aportes patronales. |

## Puntos metodológicos relevantes

- `remuneraciones` debe interpretarse como costo laboral total: incluye
  salarios y aportes patronales. No equivale a sueldos y salarios puros.
- `stock_capital` es una variable directa de la EAAE: valor de activos fijos al
  31/12. No fue construido con método de inventario permanente.
- `fbkf_maq_eq` mide el componente de maquinaria y equipos dentro de la FBKF,
  manteniendo separada la variable `fbcf` total.
- `adquisiciones_importadas` mide la columna `Importadas` de las adquisiciones
  de activo fijo. `adquisiciones_origen_importado` mide `En plaza: Origen Imp.`
  cuando la fuente trae esa apertura. `importaciones_maquinaria` suma ambos
  componentes y queda vacía en años sin apertura de origen.
- `inventarios` no está integrado al panel. La EAAE usa la denominación
  `Variación de existencias`; solo se identificó para 2001 y 2003-2005.
- No se encontró una variable de deuda industrial, pasivos, préstamos o crédito
  sectorial en la EAAE 2001-2024.

## Recomendaciones para el equipo

1. Usar el panel actual para indicadores de producción, valor agregado,
   costo laboral, inversión, adquisiciones importadas y capital fijo.
2. Decidir si vale la pena integrar `variacion_existencias` pese a su cobertura
   limitada.
3. Definir si se necesita una medida adicional de importaciones de bienes de
   capital que sume `Importadas + En plaza Origen Imp.` desde 2006.
4. Buscar fuentes externas para deuda industrial y amortizaciones, ya que no
   están disponibles como variables sistemáticas en la EAAE.
5. Mantener como advertencia de validación el caso 2008, sección `D_E`, donde
   `vab_pp < remuneraciones`; el pipeline lo reporta como warning, no como
   error estructural.
