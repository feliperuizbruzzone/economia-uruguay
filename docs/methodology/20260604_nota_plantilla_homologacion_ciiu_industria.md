# Plantilla de homologacion de subramas industriales CIIU Rev.3/3.1 a Rev.4

## Objetivo

Este insumo acompana la construccion de una futura subbase de subramas de la
rama industrial de la EAAE. No define una homologacion final. Su funcion es
ordenar el trabajo experto del equipo en torno a los cambios de clasificacion
entre las divisiones manufactureras usadas antes de 2008 y las divisiones de
CIIU/ISIC Rev.4 usadas desde 2008.

Archivo de trabajo:

`docs/methodology/20260604_plantilla_homologacion_ciiu_industria_rev3_rev4.csv`

## Fuentes usadas

- UNSD, estructura ISIC Rev.3 en ingles, descargada desde el portal de
  clasificaciones economicas de Naciones Unidas.
- UNSD, estructura ISIC Rev.3.1 en espanol, descargada desde el mismo portal.
- UNSD, estructura ISIC Rev.4 en espanol, descargada desde el mismo portal.
- Manual ISIC Rev.4, en particular las notas sobre tablas de correspondencia y
  cambios principales en manufactura.

La EAAE 2002-2007 esta documentada en el proyecto como CIIU Rev.3. La plantilla
incluye titulos Rev.3 en ingles y, como ayuda de lectura, titulos Rev.3.1 en
espanol. Antes de usar la homologacion en una serie final, conviene contrastar
las descripciones efectivamente publicadas en los XLS EAAE 2002-2007.

## Como usar la plantilla

Cada fila propone una relacion candidata entre una division industrial
pre-2008 y una division Rev.4. Las columnas `relacion_preliminar`,
`prioridad_revision` y `comentario_preliminar` sirven solo para orientar la
discusion.

El equipo deberia completar:

- `grupo_homologado_equipo`: nombre canonico del grupo final que se usara en la
  subbase.
- `decision_equipo`: por ejemplo `aceptar`, `agregar_con_otra_division`,
  `excluir`, `mantener_segmentada`, `requiere_revision`.
- `notas_equipo`: justificacion sustantiva o advertencias para futuras
  validaciones.

## Criterios sugeridos de decision

1. Priorizar series comparables antes que granularidad aparente.
2. Agregar divisiones cuando Rev.4 separa una division Rev.3 que no puede
   separarse hacia atras, por ejemplo alimentos/bebidas o quimicos/farmaceuticos.
3. Marcar como no comparable o fuera de manufactura los componentes que cambian
   de seccion, como edicion/publicacion y reciclado.
4. Tratar la division Rev.4 33, reparacion e instalacion de maquinaria y equipo,
   con especial cuidado: puede reunir partes antes distribuidas en varias
   divisiones manufactureras.
5. Validar cualquier decision contra los datos EAAE: la suma de subramas
   homologadas deberia reconciliar con el total industrial disponible para cada
   ano, salvo exclusiones documentadas.

## Resultado esperado

Una vez completadas las columnas del equipo, la tabla puede convertirse en una
codiguera operativa para construir:

- una subbase fuente, sin homologar, con `ciiu_version`, `seccion_fuente` y
  `division_fuente`;
- una subbase homologada, usando `grupo_homologado_equipo` como identificador
  de subrama comparable.

