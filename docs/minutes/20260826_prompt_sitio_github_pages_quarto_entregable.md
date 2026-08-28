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
  index.qmd
  01-sistematizacion.qmd
  02-resultados-eaae-bcu.qmd
  03-escenario-comercio-exterior.qmd
  04-escenario-bienes-transables.qmd
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
  - `Escenario 1: comercio exterior`;
  - `Escenario 2: bienes transables`;
- tema claro, sobrio y legible;
- tabla de contenidos activada;
- búsqueda activada si no introduce dependencias problemáticas;
- no usar recursos remotos obligatorios.

El sitio debe poder renderizarse localmente con:

```bash
quarto render site
```

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
data/analysis-data/20260827_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx
docs/20260827_resultados_devaluacion_escenario_1_comercio_exterior.md
docs/20260827_resultados_devaluacion_escenario_2_bienes_transables.md

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

## Sección 3: Escenario 1 - Comercio exterior

Crear `site/03-escenario-comercio-exterior.qmd`.

Usar como fuente narrativa:

```text
docs/20260827_resultados_devaluacion_escenario_1_comercio_exterior.md
```

Usar como fuente analítica:

```text
data/analysis-data/20260827_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx
```

Leer la hoja:

```text
Escenario 1 - Comercio Exterior
```

Introducir el escenario con esta idea:

```text
La apropiación de riqueza vía sobrevaluación de la moneda se aplica a los
componentes importados de los costos y del capital, y a la parte exportada de
la producción. Por tanto, sólo recoge el efecto directo de importaciones y
exportaciones sobre la tasa de ganancia.
```

Incorporar:

- supuestos del ejercicio;
- coeficientes de incidencia por sección;
- resultados principales;
- mecanismo de transmisión en 2024;
- interpretación económica;
- módulo interactivo de simulación descrito más abajo.

Usar figuras de:

```text
output/figures/devaluacion_industria_segmentos_20260827_escenario_1_comercio_exterior/
```

Para máxima estabilidad, copia esas figuras a `site/assets/` y referencia las
copias desde los `.qmd`.

## Sección 4: Escenario 2 - Bienes transables

Crear `site/04-escenario-bienes-transables.qmd`.

Usar como fuente narrativa:

```text
docs/20260827_resultados_devaluacion_escenario_2_bienes_transables.md
```

Usar como fuente analítica:

```text
data/analysis-data/20260827_panel_eaae_2020_2024_industria_escenario_devaluacion.xlsx
```

Leer la hoja:

```text
Escenario 2 - Bienes Transables
```

Introducir el escenario con esta idea:

```text
La apropiación de riqueza vía sobrevaluación alcanza al conjunto de mercancías
cuyos precios internos se rigen por precios internacionales, aunque sean
producidas localmente y vendidas en el mercado interno. Así, incorpora también
la revaluación de esa producción local y su incidencia sobre la tasa de
ganancia.
```

Incorporar:

- supuestos del ejercicio;
- coeficientes de incidencia por sección;
- resultados principales;
- mecanismo de transmisión en 2024;
- interpretación económica;
- módulo interactivo de simulación descrito más abajo.

Usar figuras de:

```text
output/figures/devaluacion_industria_segmentos_20260827_escenario_2_bienes_transables/
```

Para máxima estabilidad, copia esas figuras a `site/assets/` y referencia las
copias desde los `.qmd`.

## Interactividad para gradiente de devaluación

Implementar, si es técnicamente simple y robusto, un módulo interactivo en cada
sección de escenario. El módulo debe ser 100% estático, del lado del navegador.
No usar Shiny.

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

### Insumo para el módulo interactivo

Preparar un JSON liviano:

```text
site/data/devaluacion_segmentos_20260827.json
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
```

La interfaz sugerida por escenario:

- selector de año: 2020-2024;
- slider de magnitud de devaluación: 0% a 150%;
- sliders de intensidad por incidencia: 0% a 100%;
- botón o control rápido para volver a `Escenario XLSX`:
  - devaluación = 100%;
  - todas las incidencias = 100%;
- gráfico de barras con la tasa de ganancia a precios básicos resultante para:
  - industria total;
  - segmento exportador;
  - segmento mercado interno;
- tabla resumen con:
  - tasa base;
  - tasa simulada;
  - cambio en puntos porcentuales;
  - ganancia base;
  - ganancia simulada;
  - variación porcentual de ganancia;
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
```

Para intereses:

```text
intereses_simulados =
  intereses_industria_pesos + delta_intereses_industria_pesos

ganancia_pb_desp_intereses_simulada =
  ganancia_pb_simulada - intereses_simulados

tasa_ganancia_pb_desp_intereses_simulada =
  ganancia_pb_desp_intereses_simulada / capital_total_adelantado_simulado
```

### Alternativa estable si el JavaScript completo queda frágil

Si implementar todos los sliders con JavaScript puro en Quarto queda frágil,
usar una alternativa estable:

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
command-files/analysis-command-files/14_preparar_sitio_entregable_quarto.R
```

Ese script debe:

- leer el XLSX de devaluación 20260827;
- exportar el JSON/CSV liviano para los módulos interactivos;
- copiar o verificar figuras necesarias hacia `site/assets/`;
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
site/_site/03-escenario-comercio-exterior.html
site/_site/04-escenario-bienes-transables.html
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
site/_site/03-escenario-comercio-exterior.html
site/_site/04-escenario-bienes-transables.html
.github/workflows/pages.yml
```

Y, si corresponde:

```text
site/data/devaluacion_segmentos_20260827.json
command-files/analysis-command-files/14_preparar_sitio_entregable_quarto.R
```

La respuesta final debe explicar:

- qué archivos se crearon;
- cómo regenerar el sitio localmente con `quarto render site`;
- cómo publicar desde GitHub Pages:
  `Settings > Pages > Source: GitHub Actions`;
- si quedó o no implementado el slider interactivo;
- qué validaciones se realizaron.
