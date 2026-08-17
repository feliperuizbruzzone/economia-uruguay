---
title: "minuta-fuente-eaae-microdatos"
date: "2026-08-07"
lang: es-UY
---

# Minuta fuente EAAE microdatos

## Objetivo

Documentar una evaluacion preliminar de la carpeta
`data/input-data/eaae-microdatos`, con subcarpetas anuales para 1998-2019. La
revision busca establecer que informacion contiene la fuente, si existe un
formato homogeneo entre anos, y si los microdatos permiten identificar
exportaciones, insumos importados e inventarios relevantes para estimar
rotacion de capital.

Esta minuta registra observaciones metodologicas. No implementa extraccion, no
crea bases derivadas y no modifica datos primarios.

## Resumen ejecutivo

La fuente EAAE microdatos contiene informacion rica y potencialmente util para
abrir dimensiones no disponibles en los paneles publicados, especialmente
ventas por destino, compras de insumos por origen, inventarios por categoria y
datos de empresa/UCA con ponderadores. Sin embargo, no es una fuente homogenea
1998-2019: existen varios regimenes de archivo y formulario, por lo que una
base longitudinal requiere parsers y diccionarios por periodo.

La factibilidad es alta para construir indicadores de exportaciones, salvo el
ano 2011, que no muestra una fuente equivalente directa de ventas por
producto/destino en la revision realizada. Para insumos importados la
factibilidad es mas desigual: 2006-2012 contiene campos claros de compras de
materias primas e insumos por origen; 1998-2005 parece recuperable con mapeo
de variables codificadas; desde 2013-2019 no se observa una variable directa
equivalente de compras de materias primas por origen, aunque si existen costos
de materias primas consumidas, servicios adquiridos por origen y adquisiciones
de bienes de uso por origen.

Para inventarios, la disponibilidad es buena en general. La fuente permite
identificar existencias de materias primas, productos en proceso, productos
terminados, mercaderias para revender y otras categorias. El ano 2011 vuelve a
ser una excepcion parcial porque agrupa productos terminados y en proceso. Para
calcular rotacion, la definicion del numerador debe decidirse explicitamente:
compras de materias primas cuando existan o costo de materias primas
consumidas como alternativa mas continua.

## Estructura de la fuente por periodo

| Periodo | Estructura observada | Lectura metodologica |
|---|---|---|
| 1998-2001 | Tres Excel por ano: `FORMEMPRE`, `FORMINSU`, `FORMPROD`. | Variables economicas codificadas; productos e insumos tienen columnas explicitas como `TOTAL`, `PLAZA`, `EXTERIOR`. |
| 2002-2005 | Bases finales `.sav` y archivos `EAE_FORMPROD*.xls`. | Los `.sav` conservan variables codificadas; requieren mapeo con formularios posteriores. |
| 2006 | Modulos Excel separados: empresa, productos, insumos, FBC, bienes de uso y formulario. | Primer ano con nombres mas legibles para varios bloques clave. |
| 2007-2010 | Estructura modular en `.sav`: productos, insumos, destino de ventas, FBC, macrovariables, microdatos por empresa/UCA, ponderadores y diccionarios. | Periodo muy util para estudiar destino de ventas, compras de insumos, inventarios y ponderacion. |
| 2011 | Estructura de transicion con microdatos, macrovariables, clases de actividad, productos y ponderadores. | Menor apertura para destino de ventas y compras de insumos; inventarios disponibles con agregacion parcial. |
| 2012 | Estructura por capitulos con formulario codificado. | Alto detalle: capitulo `L` para ingresos por producto/destino, `N` para compras de insumos, `P` para existencias y `R` para bienes de uso. |
| 2013-2019 | Estructura moderna por capitulos, macrovariables y ponderadores. | Bastante estable internamente, pero cambia nombres de archivos y desaparece el bloque directo de compras de materias primas por origen observado en 2012. |

## Homogeneidad

No existe un formato unico para todo el periodo 1998-2019. La fuente debe
tratarse como una coleccion de regimenes documentales. La construccion de un
panel longitudinal exigiria:

- detectar archivos por nombre y por contenido, no solo por posicion;
- mapear codigos de formulario a nombres canonicos por periodo;
- distinguir unidad de observacion: empresa, UCA, producto, insumo o clase de
  actividad;
- incorporar ponderadores antes de agregar;
- resolver el cambio CIIU Rev.3 / Rev.4 si se requiere comparar industria y
  subramas.

La estructura 2013-2019 es la mas estable, pero no debe extrapolarse hacia
atras. Los anos 2011 y 2012 son puntos de quiebre especificos: 2011 por menor
disponibilidad de modulos y 2012 por mayor detalle y codificacion propia.

## Exportaciones

Las exportaciones pueden aproximarse como ventas al exterior reportadas por la
EAAE. La disponibilidad observada es la siguiente:

- 1998-2006: archivos de productos con `TOTAL`, `PLAZA` y `EXTERIOR`.
- 2007-2010: `Productos.sav` contiene `Total`, `Plaza`, `Exterior` y
  `Misma_Empresa`; ademas existe `Destino de ventas.sav` para mayor detalle.
- 2012-2019: el capitulo `L` reporta ingresos por producto y destino:
  `L.1` total, `L.2` plaza, `L.3` exterior y `L.4` misma empresa.
- 2011: no se observo una fuente equivalente directa de ventas por producto y
  destino; debe tratarse como ano problematico para una serie de exportaciones.

La agregacion puede hacerse para economia total y para industria. En industria
debe filtrarse por clase de actividad manufacturera, cuidando el quiebre CIIU:
Rev.3 en los anos antiguos y Rev.4 en los modernos.

## Insumos importados

La fuente distingue conceptos que no deben mezclarse:

- insumos comprados fuera de Uruguay;
- insumos comprados en Uruguay de origen extranjero;
- adquisiciones importadas de bienes de uso o FBCF, que no son insumos
  corrientes;
- servicios adquiridos en el exterior, disponibles en algunos formularios
  modernos pero conceptualmente distintos de materias primas.

La disponibilidad preliminar es:

- 1998-2001: `FORMINSU` contiene `TOTAL`, `PLAZA` y `EXTERIOR`; permite una
  medida gruesa de compras de insumos en plaza versus exterior, sin separar
  origen nacional/extranjero dentro de plaza.
- 2002-2005: la informacion parece recuperable desde variables codificadas,
  pero requiere mapeo formal contra los formularios posteriores.
- 2006-2010: alta disponibilidad; aparecen campos como compras en Uruguay de
  origen nacional, compras en Uruguay de origen extranjero, compras fuera de
  Uruguay y propia empresa.
- 2012: el capitulo `N` registra compras de materias primas e insumos con
  columnas de total, Uruguay, fuera de Uruguay y propia empresa.
- 2013-2019: no se observo un equivalente directo del capitulo `N` para
  compras de materias primas por origen. Si se requiere continuidad, habria que
  decidir un proxy o restringir el analisis a los anos con variable directa.
- 2011: ano de disponibilidad limitada para esta dimension.

## Inventarios y rotacion de capital

La fuente contiene informacion relevante sobre existencias/inventarios. La
apertura mas util para rotacion identifica:

- materias primas y materiales;
- productos en proceso;
- productos terminados;
- mercaderias compradas para revender;
- envases y embalajes;
- repuestos y accesorios;
- otras existencias;
- total de existencias.

En 2006-2010 y 2012-2019 se observan existencias de ano anterior y ano de
referencia. En 2012-2019, el capitulo `P` usa `P.1.*` para el ano anterior y
`P.2.*` para el ano de referencia. En 1998-2005 la informacion parece estar en
variables codificadas, con una estructura comparable por posicion, pero debe
mapearse cuidadosamente. En 2011 existen inventarios, aunque productos
terminados y en proceso aparecen agrupados, lo que reduce comparabilidad si se
necesita aislar productos en proceso.

Una formula operativa defendible para evaluar rotacion seria:

```text
rotacion = flujo_anual / stock_promedio_de_inventarios
```

con:

```text
stock_promedio =
((materias_primas_ant + productos_en_proceso_ant) +
 (materias_primas_ref + productos_en_proceso_ref)) / 2
```

El punto metodologico critico es el numerador. Donde existan compras de
materias primas e insumos, puede calcularse una rotacion estricta con compras.
Donde esa variable no exista, especialmente 2013-2019, puede evaluarse una
rotacion alternativa con costo de materias primas y materiales consumidos. Esta
segunda opcion seria mas continua, pero no es conceptualmente identica a usar
compras.

## Ponderacion

Si el calculo se hace desde microdatos, los resultados deben ponderarse antes
de agregarse. No corresponde calcular tasas por empresa y luego promediar
tasas. La regla recomendada es ratio de sumas ponderadas:

```text
rotacion_agregada =
sum(flujo_anual * ponderador) / sum(stock_promedio * ponderador)
```

El nombre del ponderador cambia por periodo y archivo. Se observaron variables
o archivos con nombres como `Ponderador`, `peso`, `weight`, `w_mean`, `POND` y
`Expansor`. Para 1998-2005 no se observo una columna obvia de ponderacion en
el barrido inicial; debe verificarse si esos archivos estan preexpandidos,
corresponden a otro universo o requieren una fuente auxiliar.

## Recomendacion operativa

Antes de implementar una base derivada desde estos microdatos conviene definir
tres decisiones:

1. Si la serie de rotacion usara compras de materias primas, costo de materias
   primas consumidas, o ambas como indicadores alternativos.
2. Si el ano 2011 se excluye, se mantiene como categoria parcial o se ajusta
   con una regla especifica por la agregacion de inventarios.
3. Si los indicadores se construiran para economia total, industria total y/o
   subramas, porque eso define la unidad de union con ponderadores y clases de
   actividad.

La recomendacion tecnica es construir primero una base de auditoria en memoria
o reproducible, por periodo, que exponga identificadores, ponderador, clase de
actividad, flujo usado como numerador, inventarios usados como denominador y
banderas de calidad. Luego, con esa auditoria validada, generar indicadores
agregados por economia total, industria y subrama.
