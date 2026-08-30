# Prompt para construir sitio GitHub Pages del entregable EAAE

## Objetivo

Implementar dentro del repositorio un sitio estático simple, estilo Quarto,
para empaquetar el entregable de contraparte. El sitio debe construirse en una
carpeta nueva, sin intervenir el flujo documental preexistente en `docs/`.
Debe quedar listo para publicación por GitHub Pages mediante GitHub Actions; el
único paso manual pendiente será activar Pages con fuente `GitHub Actions` en
la configuración del repositorio.

El sitio debe funcionar como puerta de entrada del proyecto: presentar el
problema de investigación, explicar la sistematización de datos y ofrecer
acceso directo a los resultados, bases procesadas, minutas y repositorio
reproducible.

## Prompt operativo

Actúa como un desarrollador senior que trabaja dentro del repositorio
`economia-uruguay`. Necesito crear un sitio estático de entrega para la
contraparte, usando Quarto como plantilla visual y manteniendo reproducibilidad
tipo Project TIER.

### Decisión de publicación

Usa como alternativa principal la opción más estable sin tocar `docs/`:

- crear un proyecto Quarto fuente en `site/`;
- renderizar HTML estático hacia `site/_site/`;
- no requerir servidor, Shiny ni ejecución R/Python del lado del usuario;
- publicar `site/_site/` con GitHub Actions como artefacto de GitHub Pages;
- dejar como único paso manual pendiente: en GitHub, ir a `Settings > Pages` y
  seleccionar `GitHub Actions` como fuente de publicación.

No uses `docs/` como carpeta de salida del sitio porque ya contiene documentos
metodológicos y minutas del flujo del proyecto. No borres ni muevas archivos
existentes en `docs/`.

### Estructura esperada

Crea la siguiente estructura:

```text
site/
  _quarto.yml
  styles.scss
  index.qmd
  01-sistematizacion.qmd
  02-resultados-eaae-bcu.qmd
  04-resultados-devaluacion-escenarios-integrados.qmd
  05-modulos-interactivos-devaluacion.qmd
  assets/
  data/
  _site/
.github/
  workflows/
    pages.yml
```

Si Quarto genera carpetas auxiliares como `site_libs/`, `search.json` o
`assets/` dentro de `site/_site/`, consérvalas.

### Configuración Quarto

En `site/_quarto.yml`, configura un sitio HTML sencillo:

- `project.type: website`;
- `project.output-dir: _site`;
- navbar con estas secciones:
  - `Inicio`;
  - `Sistematización`;
  - `Resultados EAAE-BCU`;
  - `Resultados devaluación`;
  - `Simulador devaluación`;
- tema claro, sobrio y legible, usando un tema base estable como `cosmo` más
  una hoja propia `styles.scss`;
- tabla de contenidos activada;
- búsqueda activada si no introduce dependencias problemáticas;
- no usar recursos remotos obligatorios.

El sitio debe poder renderizarse localmente con:

```bash
quarto render site
```

### Estilo visual e institucional

El sitio debe verse como un entregable de consultoría de análisis económico
para una contraparte tripartita de Uruguay: Estado, empresas y sindicatos. El
tono visual debe ser serio, neutral, legible y técnicamente confiable. No debe
parecer una landing page comercial ni una presentación partidaria.

El estilo debe ser coherente con los gráficos de la minuta integrada de
devaluación: fondo blanco, grilla muy suave, títulos en azul oscuro, paleta
sobria de azules y textos secundarios en gris. Usar como referencia visual el
formato de `theme_minimal` aplicado en
`docs/20260830_resultados_devaluacion_escenarios_integrados.md`.

Usar esta paleta como contrato visual del sitio:

```text
navy  = #0B1F3A
deep  = #173B63
main  = #2F5F8F
steel = #5F86AD
soft  = #9DB8D2
pale  = #DCE8F3
grey  = #6C7785
grid  = #D9E1E8
white = #FFFFFF
```

Configurar `site/styles.scss` con variables equivalentes, por ejemplo:

```scss
:root {
  --uy-navy: #0B1F3A;
  --uy-deep: #173B63;
  --uy-main: #2F5F8F;
  --uy-steel: #5F86AD;
  --uy-soft: #9DB8D2;
  --uy-pale: #DCE8F3;
  --uy-grey: #6C7785;
  --uy-grid: #D9E1E8;
  --uy-white: #FFFFFF;
}
```

Lineamientos de composición:

- usar fondo blanco y secciones sin efectos decorativos;
- limitar el ancho de lectura a aproximadamente `1100px`;
- usar tipografía sans-serif de sistema, con interlineado amplio y jerarquía
  clara;
- usar títulos en `navy`, subtítulos y bajadas en `grey`;
- reservar énfasis visual para hallazgos, supuestos y advertencias
  metodológicas;
- evitar gradientes, ilustraciones, fotografías genéricas, sombras fuertes,
  orbes, colores partidarios o estética promocional;
- no usar tarjetas decorativas en exceso; cuando hagan falta, que sean bloques
  técnicos simples con borde `grid` y radio pequeño;
- mantener las tablas con encabezado `navy`, líneas suaves y buena separación
  horizontal;
- presentar las figuras en tamaño amplio, con fuente visible y márgenes
  consistentes;
- usar botones o enlaces de descarga discretos, en azul oscuro o azul medio,
  sin animaciones llamativas.

Lineamientos para los módulos interactivos:

- organizar los controles en un bloque compacto superior o en una columna
  lateral sobria;
- usar sliders en la misma paleta azul;
- mostrar primero los indicadores principales y luego los gráficos;
- mantener etiquetas breves y lenguaje técnico claro;
- distinguir escenarios y secciones con los mismos colores de la minuta:
  - escenario 1: `deep`;
  - escenario 2: `steel`;
  - industria total: `navy`;
  - segmento exportador: `main`;
  - mercado interno: `soft`.

Evitar cualquier diseño que sugiera una posición institucional de parte. El
objetivo es que una misma página pueda ser leída por representantes del Estado,
empresas y sindicatos como un informe económico navegable, transparente y
reproducible.

### Workflow GitHub Actions

Crear `.github/workflows/pages.yml` para publicar el sitio desde `site/_site/`.
Usar acciones oficiales y una configuración simple:

- trigger en `push` a `main`;
- permisos `contents: read`, `pages: write`, `id-token: write`;
- setup de Quarto;
- render de `site`;
- upload de `site/_site`;
- deploy a GitHub Pages.

El workflow debe ser autocontenido y no debe modificar datos. Si el sitio no
requiere ejecutar R porque todo está preprocesado, evitar instalar paquetes
innecesarios. Si se necesita R para preparar JSON/CSV livianos, ejecutar antes
el script reproducible indicado más abajo.

## Homepage

Crear `site/index.qmd` como página de presentación del proyecto.

Debe incluir:

- título claro del proyecto;
- resumen sintético del trabajo: sistematización de fuentes económicas de
  Uruguay, construcción de paneles EAAE-BCU, resultados industriales y
  modelamiento de apropiación de riqueza por sobrevaluación cambiaria;
- una explicación breve de que el repositorio sigue una organización inspirada
  en Project TIER:
  - datos primarios en `data/input-data/`;
  - scripts reproducibles en `command-files/`;
  - bases procesadas en `data/analysis-data/`;
  - documentos y minutas en `docs/`;
  - figuras en `output/figures/`;
- enlaces principales de descarga a las bases y resultados más recientes;
- enlace al repositorio completo de GitHub como respaldo reproducible del
  proyecto.

Usar enlaces relativos cuando el archivo se copie dentro de `site/`, y enlaces
al repositorio cuando se apunte a archivos que permanecerán fuera de `site/`.
Para máxima estabilidad, copiar a `site/data/` los archivos livianos que deban
descargarse directamente desde el sitio.

Enlaces mínimos sugeridos para la homepage:

```text
Repositorio:
https://github.com/feliperuizbruzzone/economia-uruguay

Resultados devaluación:
data/analysis-data/20260830_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx
docs/20260830_resultados_devaluacion_escenarios_integrados.md
output/figures/devaluacion_escenarios_integrados_20260830/

Paneles y resultados integrados:
data/analysis-data/20260826_panel_eaae_2020_2024_industria.csv
data/analysis-data/20260819_panel_eeae_bcu_total_industria_subrama.csv
data/analysis-data/20260819_resultados_eaae_bcu_total_industria_subrama.xlsx
docs/20260819_resultados_eaae_bcu_tres_niveles.md
```

Si se implementan botones o tarjetas de descarga, mantener una estética sobria:
no construir una landing page de marketing. La homepage debe ser una portada de
entregable académico/técnico, orientada a lectura y descarga.

## Sección 1: sistematización y antecedentes

Crear `site/01-sistematizacion.qmd`.

Contenido esperado:

- presentación general del trabajo de sistematización de datos;
- antecedentes del estudio;
- explicación sintética del uso de una organización tipo Project TIER;
- fuentes principales trabajadas:
  - EAAE;
  - BCU;
  - CIU;
  - Oyanthabal;
  - Mussi;
- productos principales:
  - panel EAAE principal;
  - panel EAAE-BCU integrado;
  - resultados a tres niveles;
  - modelamiento de devaluación diferenciada;
- decisiones metodológicas relevantes:
  - homologación CIIU;
  - deflactores BCU;
  - rotaciones;
  - imputaciones;
  - validaciones;
  - trazabilidad de FBKF/adquisiciones;
  - distribución de intereses industriales por microdatos CIU.

Incluir enlaces relativos o de repositorio a los archivos más recientes
listados en `README.md`.

## Sección 2: resultados EAAE-BCU

Crear `site/02-resultados-eaae-bcu.qmd`.

Usar como fuente narrativa:

```text
docs/20260819_resultados_eaae_bcu_tres_niveles.md
```

Incorporar su lógica argumental y las figuras de:

```text
output/figures/eaae_bcu_tres_niveles_20260819/
```

No hace falta copiar literalmente todo si queda demasiado largo, pero sí deben
quedar presentes:

- criterios de lectura;
- representatividad EAAE-BCU;
- tasa de ganancia en tres niveles;
- descomposición del VAB;
- capital adelantado;
- inversión manufacturera;
- productividad del trabajo;
- anexos principales si aportan lectura sustantiva.

Todas las rutas de imágenes deben funcionar desde el HTML renderizado en
`site/_site/`. Para máxima estabilidad, copia las figuras necesarias a
`site/assets/` y referencia esas copias desde los `.qmd`.

## Sección 4: resultados devaluación escenarios integrados

Crear `site/04-resultados-devaluacion-escenarios-integrados.qmd`.

Esta sección reemplaza las páginas separadas por escenario. Debe presentar una
lectura narrativa unificada a partir de la última minuta integrada:

```text
docs/20260830_resultados_devaluacion_escenarios_integrados.md
```

Usar como fuente analítica:

```text
data/analysis-data/20260830_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx
```

Leer las hojas:

```text
escenario-inicial
tipo-cambio
Escenario 1 - Comercio Exterior
Escenario 2 - Bienes Transables
```

Usar figuras de:

```text
output/figures/devaluacion_escenarios_integrados_20260830/
```

Para máxima estabilidad, copiar esas figuras a `site/assets/` y referenciarlas
desde los `.qmd`.

Contenido esperado:

- síntesis del enfoque de apropiación de riqueza por sobrevaluación cambiaria;
- fuentes utilizadas: EAAE, Oyanthabal, CIU y coeficientes documentados en el
  XLSX de trabajo;
- definición del factor de devaluación TCC-TCP;
- coeficientes de incidencia por escenario y sección;
- lectura agregada de industria total comparando los dos escenarios;
- lectura específica del escenario 1, comercio exterior;
- lectura específica del escenario 2, bienes transables;
- gráficos de saldo neto de ganancia;
- gráficos de componentes del saldo expresados como porcentaje de la ganancia
  inicial, incluyendo stock imputado;
- interpretación económica y anexo técnico.

No incluir controles interactivos en esta sección. La lectura debe ser estable,
reproducible y equivalente a la minuta integrada vigente.

## Sección 5: módulos interactivos de simulación de devaluación

Crear `site/05-modulos-interactivos-devaluacion.qmd`.

La sección debe incluir dos módulos interactivos independientes:

- `Módulo escenario 1 - Comercio exterior`;
- `Módulo escenario 2 - Bienes transables`.

Cada módulo debe ser 100% estático, ejecutado del lado del navegador con
JavaScript simple. No usar Shiny ni dependencias remotas obligatorias.

### Rango del slider de devaluación

Usar un slider de intensidad cambiaria con este rango:

```text
0% a 150% del cierre de la brecha TCC-TCP
```

Interpretación:

- `0%`: reproduce el escenario observado con tipo de cambio comercial;
- `100%`: reproduce el escenario de paridad usado en el XLSX;
- `150%`: permite explorar un sobreajuste de 50% por encima del cierre de
  brecha hasta paridad.

Este rango es coherente con el análisis general porque mantiene a la paridad
como referencia central del proyecto, pero permite evaluar sensibilidad por
encima de ese umbral sin abrir una escala excesivamente especulativa.

La fórmula debe ser:

```text
lambda_devaluacion = valor_slider_devaluacion / 100
factor_base = tipo_cambio_paridad_pesos_usd / tipo_cambio_comercial_pesos_usd - 1
factor_efectivo = lambda_devaluacion * factor_base
```

### Sliders de incidencia por variable

Agregar sliders para la intensidad del efecto de cada incidencia. Cada slider
de incidencia debe ir de `0%` a `100%`, con marcas visuales en `0%`, `50%` y
`100%`.

Interpretación:

- `0%`: la devaluación no impacta esa variable;
- `50%`: se aplica la mitad del coeficiente de incidencia estimado;
- `100%`: se aplica completo el coeficiente de incidencia del escenario.

Variables con slider propio:

```text
vbp_pp
consumo_intermedio_estimado
remuneraciones
consumo_capital_fijo
stock_capital_imputado
intereses_industria_pesos
```

La incidencia efectiva por variable debe calcularse así:

```text
incidencia_efectiva_variable =
  incidencia_variable_seccion * intensidad_variable / 100

delta_variable =
  variable_base * incidencia_efectiva_variable * factor_efectivo
```

Por defecto, todos los sliders de incidencia deben iniciar en `100%`, de modo
que `lambda_devaluacion = 100` reproduzca la hoja del escenario en el XLSX.

### Insumo para los módulos interactivos

Preparar un JSON liviano:

```text
site/data/devaluacion_segmentos_20260830.json
```

Debe contener filas de las dos hojas de escenario, con una columna `escenario`
que permita filtrar:

```text
Escenario 1 - Comercio Exterior
Escenario 2 - Bienes Transables
```

El JSON debe contener, al menos:

```text
escenario
anno
seccion
descripcion_nivel
tipo_cambio_comercial_pesos_usd
tipo_cambio_paridad_pesos_usd
factor_devaluacion
rotacion_calibrada_sobre_6_6
vbp_pp
consumo_intermedio_estimado
remuneraciones
consumo_capital_fijo
stock_capital_imputado
capital_total_adelantado
ganancia_pb
tasa_ganancia_pb
incidencia_vbp_pp
incidencia_consumo_intermedio_estimado
incidencia_remuneraciones
incidencia_consumo_capital_fijo
incidencia_stock_capital_imputado
incidencia_intereses_industria_pesos
intereses_industria_pesos
ganancia_pb_devaluacion
ganancia_pb_desp_intereses
ganancia_pb_desp_intereses_devaluacion
saldo_sobrevaluacion_ganancia_pb
delta_ganancia_momento2_pct
```

La interfaz sugerida para cada módulo:

- selector de año: 2020-2024;
- selector de sección: industria total, segmento exportador y segmento mercado
  interno;
- slider de magnitud de devaluación: 0% a 150%;
- sliders de intensidad por incidencia: 0% a 100%;
- botón o control rápido para volver a `Escenario XLSX`:
  - devaluación = 100%;
  - todas las incidencias = 100%;
- gráfico de barras con la tasa de ganancia a precios básicos: escenario
  inicial y simulación;
- gráfico de saldo de ganancia: saldo monetario y variación porcentual respecto
  de la ganancia inicial;
- gráfico de componentes del saldo como porcentaje de la ganancia inicial:
  VBP, consumo intermedio, remuneraciones, consumo de capital fijo, stock
  imputado e intereses;
- tabla resumen con:
  - tasa base;
  - tasa simulada;
  - cambio en puntos porcentuales;
  - ganancia base;
  - ganancia simulada;
  - variación porcentual de ganancia;
  - saldo de sobrevaluación;
  - capital total adelantado base;
  - capital total adelantado simulado.

### Fórmulas del simulador

Recalcular:

```text
delta_vbp_pp
delta_consumo_intermedio_estimado
delta_remuneraciones
delta_consumo_capital_fijo
delta_stock_capital_imputado
delta_intereses_industria_pesos

ganancia_pb_simulada =
  ganancia_pb + delta_vbp_pp -
  delta_consumo_intermedio_estimado -
  delta_remuneraciones -
  delta_consumo_capital_fijo

capital_total_adelantado_simulado =
  capital_total_adelantado +
  delta_stock_capital_imputado +
  (delta_remuneraciones + delta_consumo_intermedio_estimado) /
    rotacion_calibrada_sobre_6_6

tasa_ganancia_pb_simulada =
  ganancia_pb_simulada / capital_total_adelantado_simulado

saldo_sobrevaluacion_ganancia_pb_simulado =
  ganancia_pb - ganancia_pb_simulada

delta_ganancia_momento2_pct_simulado =
  (ganancia_pb_simulada - ganancia_pb) / ganancia_pb * 100
```

Para intereses:

```text
intereses_simulados =
  intereses_industria_pesos + delta_intereses_industria_pesos

ganancia_pb_desp_intereses_simulada =
  ganancia_pb_simulada - intereses_simulados

tasa_ganancia_pb_desp_intereses_simulada =
  ganancia_pb_desp_intereses_simulada / capital_total_adelantado_simulado

saldo_sobrevaluacion_ganancia_pb_desp_intereses_simulado =
  ganancia_pb_desp_intereses - ganancia_pb_desp_intereses_simulada
```

### Alternativa estable si el JavaScript completo queda frágil

Si implementar todos los sliders con JavaScript puro en Quarto queda frágil en
uno o ambos módulos, usar una alternativa estable:

- mantener el slider principal de devaluación;
- reemplazar los sliders de incidencia por tres presets:
  - `sin incidencia`: 0%;
  - `incidencia media`: 50%;
  - `incidencia completa`: 100%;
- precalcular escenarios discretos con:
  - `lambda_devaluacion = 0, 0.25, 0.50, 0.75, 1.00, 1.25, 1.50`;
  - `intensidad_incidencia = 0, 0.50, 1.00`;
- mostrar gráficos estáticos comparativos y dejar documentado que el slider
  completo puede incorporarse en una segunda iteración.

## Script reproducible para preparar datos del sitio

Crear un script específico si hace falta:

```text
command-files/analysis-command-files/15_preparar_sitio_entregable_quarto.R
```

Ese script debe:

- leer el XLSX de devaluación 20260830;
- exportar `site/data/devaluacion_segmentos_20260830.json` para los módulos
  interactivos;
- copiar o verificar figuras necesarias hacia `site/assets/`, incluyendo las
  figuras de `output/figures/devaluacion_escenarios_integrados_20260830/`;
- copiar a `site/data/` los archivos de descarga que deban estar disponibles
  directamente desde el sitio;
- validar que existan todos los insumos del sitio;
- dejar mensajes claros de salida.

## Verificaciones obligatorias

Antes de terminar:

1. Ejecutar:

```bash
quarto render site
```

2. Verificar que exista:

```text
site/_site/index.html
site/_site/01-sistematizacion.html
site/_site/02-resultados-eaae-bcu.html
site/_site/04-resultados-devaluacion-escenarios-integrados.html
site/_site/05-modulos-interactivos-devaluacion.html
```

3. Verificar que las imágenes carguen con rutas relativas desde `site/_site/`.

4. Si se implementa el módulo interactivo, verificar manualmente en el HTML que:

- el selector de año cambia resultados;
- el slider de devaluación cambia resultados;
- los sliders de incidencia cambian resultados;
- `lambda_devaluacion = 0` reproduce el escenario inicial;
- `lambda_devaluacion = 100` y todas las incidencias en `100%` reproducen la
  hoja correspondiente del XLSX;
- `lambda_devaluacion = 150` funciona como escenario exploratorio por encima de
  la paridad;
- no hay dependencias externas necesarias para visualizar la página.

5. No modificar archivos de datos fuente en `data/input-data/`.

6. No borrar minutas ni figuras previas.

7. No usar `docs/` como carpeta de salida del sitio.

## Resultado esperado

Al finalizar deben quedar listos:

```text
site/
site/_site/index.html
site/_site/01-sistematizacion.html
site/_site/02-resultados-eaae-bcu.html
site/_site/04-resultados-devaluacion-escenarios-integrados.html
site/_site/05-modulos-interactivos-devaluacion.html
.github/workflows/pages.yml
```

Y, si corresponde:

```text
site/data/devaluacion_segmentos_20260830.json
command-files/analysis-command-files/15_preparar_sitio_entregable_quarto.R
```

La respuesta final debe explicar:

- qué archivos se crearon;
- cómo regenerar el sitio localmente con `quarto render site`;
- cómo publicar desde GitHub Pages:
  `Settings > Pages > Source: GitHub Actions`;
- si quedó o no implementado el slider interactivo;
- qué validaciones se realizaron.
