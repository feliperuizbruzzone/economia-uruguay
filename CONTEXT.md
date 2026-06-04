# CONTEXT.md — Pipeline EAAE Uruguay 2001–2024
## Documento de contexto para agente de código (Claude Code / Codex / Cursor)
### Protocolo Project TIER 4.0 · Linux · Positron · Versión 1.0 · Mayo 2026

---

> **Instrucción al agente:** este archivo es la fuente de verdad del proyecto.
> Léelo completo antes de escribir cualquier código. Ante cualquier ambigüedad,
> consulta §7 (Decisiones pendientes) y §8 (Anomalías conocidas) antes de
> asumir cualquier comportamiento por defecto. No inventes rutas, nombres de
> archivo ni valores de configuración: todos están documentados aquí o deben
> ser consultados explícitamente al investigador.

---

## §1. RESUMEN DEL PROYECTO

### Objetivo
Construir un pipeline de extracción, procesamiento y validación de datos de la
**Encuesta Anual de Actividad Económica (EAAE)** del Instituto Nacional de
Estadística (INE) de Uruguay, cubriendo la serie completa **2001–2024**.

Los productos finales son **dos archivos fechados**, un CSV completo y un
libro Excel de revisión (`YYYYMMDD_panel_eaae.csv` y
`YYYYMMDD_panel_eaae.xlsx`), con estructura de panel sección CIIU × año y las
variables prioritarias para calcular indicadores de tasa de ganancia, costo
laboral y acumulación sectorial de capital en Uruguay.

### Variables objetivo del panel final

| Variable | Fuente en EAAE | Tipo | Disponibilidad en la serie |
|---|---|---|---|
| `vbp_pp` | 2001 cuadro 1 letra / C1/C1.1 | directa | 2001–2024 |
| `vbp_pb` | C1.1, columna VBP(pb) | directa | 2017–2024 solamente |
| `vab_pp` | 2001 cuadro 1 letra / C1/C1.1 | directa | 2001–2024 |
| `vab_pb` | C1.1, columna VAB(pb) | directa | 2017–2024 solamente |
| `vab_pb_estimado` | `vab_pb` observado 2017–2024 y retroproyección con variación interanual de `vab_pp` | derivada provisoria | 2001–2024 |
| `consumo_intermedio_estimado` | `vbp_pp - vab_pb_estimado` | derivada provisoria | 2001–2024 |
| `capital_circulante_constante_adelantado` | `consumo_intermedio_estimado / factor_rotacion` | derivada provisoria | C y economía total; otros sectores NA |
| `remuneraciones` | 2001 cuadro 1 letra / C1/C1.1 | directa | 2001–2024 |
| `capital_variable_adelantado` | `remuneraciones / factor_rotacion` | derivada provisoria | C y economía total; otros sectores NA |
| `puestos_trabajo` | 2001 cuadro 1 letra / C1/C1.1 | directa | 2001–2024 |
| `n_empresas` | PDF de metodología/diseño muestral EAAE, marco muestral por sección | directa de fuente auxiliar | 2001–2005, 2011 y 2020; otros años NA |
| `fbcf` | 2001 C8 / 2003–2005 C10 / 2006–2024 C6 | directa | 2001, 2003–2010, 2012–2024 |
| `adquisiciones_importadas` | subcomponente Importadas en cuadros FBCF | directa | 2001, 2003–2010, 2012–2024 |
| `consumo_capital_fijo` | 2001–2011 C2 / 2012–2024 C2.1 | directa | 2001–2024 |
| `impuestos_netos` | 2001–2011 C2 / 2012–2024 C2.1 | directa | 2001–2024 |
| `stock_capital` | 2001 C9 / 2003–2005 C11 / 2006–2024 C7 | directa | 2001, 2003–2010, 2012–2024 |
| `capital_total_adelantado` | `stock_capital + capital_variable_adelantado + capital_circulante_constante_adelantado` | derivada provisoria | C y economía total donde existe `stock_capital`; otros sectores NA |
| `variacion_existencias` | 2001 C10 / 2003–2005 C12 | directa identificada, pendiente de extracción | 2001, 2003–2005 |
| `deuda_industrial` | no encontrada en EAAE | requiere fuente externa | — |
| `amortizaciones` | derivada / fuente externa | **pendiente — ver §7.1** | — |

### Decisiones provisorias vigentes — Junio 2026

Las siguientes variables derivadas forman parte del panel actual como decisión
provisoria del equipo:

- `vab_pb_estimado`: usa `vab_pb` observado en 2017–2024 y retroproyección por
  variación interanual de `vab_pp` para años anteriores.
- `consumo_intermedio_estimado`: se calcula como `vbp_pp - vab_pb_estimado`.
- `consumo_capital_fijo`: nombre público de la variable directa de consumo de
  capital fijo extraída de C2/C2.1; no usar `consumo_capital` como columna final
  del panel.
- `capital_variable_adelantado`: se calcula como `remuneraciones /
  factor_rotacion`.
- `capital_circulante_constante_adelantado`: se calcula como
  `consumo_intermedio_estimado / factor_rotacion`.
- `capital_total_adelantado`: se calcula como `stock_capital +
  capital_variable_adelantado + capital_circulante_constante_adelantado`.

Los factores de rotación definidos hasta ahora son `6,6` para la rama `C` y
`4,2` para `economia_total`. Para otros sectores, las variables de capital
adelantado deben quedar como NA hasta que el equipo defina factores. Si falta
`stock_capital`, como ocurre en 2002 y 2011, `capital_total_adelantado` queda
como NA.

Notas validadas:
- `remuneraciones` incluye aportes patronales. En los cuadros de detalle, el
  valor usado por C1/C1.1 coincide con el Total que suma remuneraciones
  salariales y `Aportes Patronales`, no con `Sueldos y Salarios` puros.
- `variacion_existencias` corresponde al flujo de variación de existencias; no
  es un stock de inventarios. No está integrada todavía al panel final.
- No se encontró en la EAAE una variable de deuda, pasivos, préstamos, crédito
  o endeudamiento sectorial/industrial. Cualquier `deuda_industrial` requiere
  fuente externa.
- `n_empresas` proviene de los PDF locales de metodología/diseño muestral en
  `data/input-data/eaae/metodologia`. Solo se integra cuando el PDF permite
  obtener un desglose exacto por sección compatible con el panel: anexos
  tabulares 2001–2005, gráfico etiquetado 2011 y gráfico vectorial 2020 cuya
  suma reconstruida reproduce exactamente el total publicado. 2022 queda como
  NA porque el gráfico no tiene etiquetas y la reconstrucción vectorial no
  reproduce el total del marco publicado; 2021 queda NA porque el PDF local está
  incompleto y no trae el desglose por sección.
- La hoja inicial `metodología` del XLSX se genera en el post-proceso R. Resume
  la estructura del libro y contiene un diccionario de variables que distingue
  identificadores, variables originales, auxiliares, validaciones, deflactores y
  variables calculadas.
- Las hojas `resultados-total-corrientes` y `resultados-industrial-corrientes`
  del XLSX se agregan como post-proceso en R mediante
  `command-files/analysis-command-files/02_add_calculos_propios_eaae.R`. No
  cambian el CSV ni la hoja base `eaae`. Usan tasas de rotación diferenciadas:
  `4,2` para `economia_total` y `6,6` para la rama industrial `C`. Como
  `remuneraciones` ya incluye aportes patronales en C1/C1.1, el costo laboral
  operativo se expone directamente como `costo_laboral = remuneraciones`; no se
  agrega una columna separada `cargas_patronales` para evitar columnas vacías.
  Estas hojas contienen niveles corrientes: insumos usados en los cálculos y
  variables calculadas, sin columnas interanuales ni duplicados propios de la
  economía total.
- Las hojas `resultados-total-constante` y `resultados-industrial-constante`
  replican esos cálculos en precios de 2005. `costo_laboral` se deflacta con
  `ipc_index_2005`. El resto de las variables monetarias se deflacta con
  `gdp_price_index_base_2005`; `puestos_trabajo` se mantiene como cantidad. Como
  la fuente Oyanthabal solo trae `gdp_price_index_base_2005` hasta 2019, las
  variables reales que dependen de ese deflactor quedan como NA desde 2020 en
  esas hojas. `productividad_trabajo` se calcula en las hojas constantes como
  `vab_pp / puestos_trabajo`.
- Las hojas `resultados-total-var-pct` y `resultados-industrial-var-pct`
  expresan las columnas analíticas de los resultados constantes como variación
  porcentual interanual: `(x[t] / x[t-1] - 1) * 100`. Las hojas
  `resultados-total-ind-2005` y `resultados-industrial-ind-2005` encadenan esas
  variaciones con base 2005=1. Se excluyen identificadores, `rotacion` y
  deflactores; se transforman los insumos y variables calculadas presentes en
  la hoja constante correspondiente.

### Granularidad de la base de datos final
- **Unidad de observación:** sector CIIU homologado × año
- **Identificadores únicos:** `seccion` (str, código homologado) + `anno` (int)
- **Clasificación de referencia:** CIIU Rev. 4 homologada hacia atrás
- **Cobertura sectorial mínima común observada:** sectores C, D_E, G, H_J, I.
  El año 2001 se incorpora desde el cuadro 1 por letra, Total del País. La
  sección F (Construcción) no aparece en los C1/C1.1 reales verificados para
  2008–2024, y la sección B falta en 2009–2011; no deben exigirse en la
  validación preliminar del panel C1.

### Entorno de trabajo
- **Sistema operativo:** Linux (local)
- **IDE:** Positron (IDE de Posit, basado en VS Code; soporta Python y R)
- **Lenguaje del pipeline ETL:** Python 3.10+
- **Lenguaje del análisis estadístico:** R (scripts separados, no parte de este pipeline)
- **Gestor de entorno Python:** ninguno definido; instalar dependencias con `pip`
- **Formato de salida final:** CSV completo y Excel de revisión, ambos con
  prefijo `YYYYMMDD`

---

## §2. ESTRUCTURA DE CARPETAS — PROJECT TIER 4.0

La estructura sigue estrictamente el protocolo Project TIER 4.0
(Teaching Integrity in Empirical Research, Haverford College).

```
economia-uruguay/                        ← raíz del proyecto
│
├── CONTEXT.md                           ← ESTE ARCHIVO (fuente de verdad)
├── README.md                            ← descripción pública del proyecto
├── requirements.txt                     ← dependencias Python del pipeline
│
├── data/
│   ├── input-data/                      ← TIER: datos originales, SOLO LECTURA
│   │   ├── eaae/
│   │   │   └── [archivos .rar descargados del INE, uno por año]
│   │   └── metadata/
│   │       ├── eaae_codebook.md         ← descripción de variables y cuadros
│   │       └── ciiu_equivalencias.csv   ← mapeo Rev.3 ↔ Rev.4 (cuando se defina)
│   │
│   └── analysis-data/                   ← TIER: datos procesados
│       ├── YYYYMMDD_panel_eaae.csv      ← BASE COMPLETA FECHADA
│       └── YYYYMMDD_panel_eaae.xlsx     ← LIBRO DE REVISIÓN FECHADO
│
├── command-files/                       ← TIER: todos los scripts
│   ├── config/
│   │   └── eaae_config.py               ← diccionario EAAE_CONFIG (ver §4)
│   │
│   ├── processing-command-files/        ← TIER: ETL (descarga → panel limpio)
│   │   ├── 01_download.py               ← descarga RAR desde portal INE
│   │   ├── 02_extract_c1.py             ← extracción cuadro C1/C1.1
│   │   ├── 03_extract_otros.py          ← extracción cuadros adicionales (FBCF, etc.)
│   │   ├── 04_validate_extraction.py    ← validación post-extracción (checkpoint 1)
│   │   ├── 05_build_panel.py            ← ensamble del panel y variables derivadas
│   │   └── 06_validate_panel.py         ← validación del panel final (checkpoint 2)
│   │
│   └── analysis-command-files/          ← TIER: análisis (R o Python, fuera del ETL)
│       └── [scripts de análisis — a definir por el investigador]
│
└── output/
    ├── figures/
    └── tables/
```

### Reglas TIER que el agente debe respetar sin excepción

1. **`data/input-data/` es de solo lectura.** Ningún script escribe allí.
   Los RAR se descargan directamente a esa carpeta y nunca se modifican.

2. **Los archivos finales de cada versión** son
   `data/analysis-data/YYYYMMDD_panel_eaae.csv` y
   `data/analysis-data/YYYYMMDD_panel_eaae.xlsx`. Los archivos intermedios
   (DataFrames parciales por año) no se persisten en disco salvo que el
   investigador lo indique; el pipeline los procesa en memoria.

3. **Numeración de scripts:** los scripts de `processing-command-files/`
   tienen prefijo numérico (`01_`, `02_`, …) que indica el orden de ejecución.
   Deben poder ejecutarse en ese orden desde la raíz con:
   ```bash
   python command-files/processing-command-files/01_download.py
   python command-files/processing-command-files/02_extract_c1.py
   # etc.
   ```

4. **Reproducibilidad:** cada script produce el mismo resultado dado el mismo
   input. No usar seeds aleatorios ni rutas absolutas. Todas las rutas son
   relativas a la raíz del proyecto.

5. **Sin hardcoding:** ningún valor de configuración (rutas, nombres de
   archivo, número de filas de encabezado, etc.) va dentro de los scripts.
   Todo se lee desde `command-files/config/eaae_config.py`.

6. **Decisiones de diseño:** documentar en el código con el prefijo
   `# DECISION:` toda elección no trivial de implementación.

---

## §3. FUENTE DE DATOS: EAAE INE URUGUAY

### Acceso
```
URL del portal:
https://www.gub.uy/instituto-nacional-estadistica/datos-y-estadisticas/
estadisticas/series-encuesta-anual-actividad-economica-eaae

Formato de los archivos: .rar (uno por año calendario)
Contenido de cada RAR: archivos .xls (Excel 97-2003, formato BIFF8)
Destino local de descarga: data/input-data/eaae/
```

### Cinco épocas estructurales

La serie 2001–2024 no es homogénea. El pipeline aplica lógica condicional
según época; no es un loop genérico.

```
ÉPOCA I   : 2001        78 XLS, 3 subcarpetas, CIIU Rev.3, cuadro 1 por letra
ÉPOCA II  : 2002–2005   4–13 XLS, raíz, CIIU Rev.3, cuadro C1, 7 columnas
ÉPOCA III : 2006–2007   10–20 XLS, 0–1 subcarpeta, CIIU Rev.3, cuadro C1, 7 columnas
ÉPOCA IV  : 2008–2016   2–18 XLS, 0–1 subcarpeta, CIIU Rev.4, C1/C1.1, 7 columnas
ÉPOCA V   : 2017–2024   11 XLS (fijo), 0–1 subcarpeta, CIIU Rev.4, C1.1, 9 columnas
```

### Quiebre de clasificación CIIU

El cambio de CIIU Rev.3 a Rev.4 ocurre entre 2007 y 2008.
La sección Manufactura pasa de letra **D** (Rev.3) a letra **C** (Rev.4).
**DECISIÓN METODOLÓGICA — Mayo 2026:** el panel final usa la opción B:
serie histórica homologada **2001–2024** con sectores agregados comparables.

Para ahorrar columnas innecesarias en el proceso de equivalencia, el panel final
no agrega columnas auxiliares como `seccion_original`, `homologacion_calidad` ni
`homologacion_nota`. La columna `seccion` contiene directamente el código
homologado. La columna `ciiu_version` se conserva como metadato de fuente
("Rev.3" para 2001–2007, "Rev.4" para 2008–2024).

Equivalencia operativa mínima para el panel:

| Sector homologado en `seccion` | CIIU Rev.3 | CIIU Rev.4 | Comentario |
|---|---|---|---|
| `B` | C | B | Minería y canteras |
| `C` | D | C | Manufactura |
| `D_E` | E | D + E | Energía, agua, saneamiento y residuos |
| `F` | F | F | Construcción |
| `G` | G | G | Comercio |
| `H_J` | I | H + J | Transporte, almacenamiento, información y comunicaciones |
| `I` | H | I | Alojamiento y comidas |

Si aparecen sectores de servicios fuera de la cobertura mínima, usar la misma
lógica de agregación documentada en `command-files/config/eaae_config.py`.

### Disponibilidad de variables por época

```
Variable                   Ép.I  Ép.II  Ép.III  Ép.IV  Ép.V
─────────────────────────────────────────────────────────────
VBP a precios productor      ~      ●      ●       ●      ●
VAB a precios productor      ~      ●      ●       ●      ●
VAB a precios básicos        ✗      ✗      ✗       ✗      ●   ← solo desde 2017
Remuneraciones               ~      ●      ●       ●      ●
Puestos de trabajo           ●      ●      ●       ●      ●   ← más consistente
FBCF                         ●      ~      ●       ~      ●
Adquisiciones importadas     ●      ~      ●       ~      ●
Stock de capital             ●      ~      ●       ~      ●
Variación de existencias     ●      ~      ✗       ✗      ✗
Excedente de explotación     ✗      ~      ~       ~      ●
Consumo intermedio           ✗      ~      ~       ~      ●

●  disponible sistemáticamente
~  disponible con discontinuidades o años faltantes
✗  no disponible
```

### Cuadros relevantes por época

```
Variable              Ép. I       Ép. II–III    Ép. IV    Ép. V
────────────────────────────────────────────────────────────────
VBP/VAB/Rem/Puestos   C1 letra    C1            C1/C1.1   C1.1
Consumo intermedio    C2 letra    C3            C3        C3
Consumo capital fijo  C2 letra    C2            C2/C2.1   C2.1
Impuestos netos       C2 letra    C2            C2/C2.1   C2.1
FBCF                  C8 letra    C10/C6        C6        C6
Adq. importadas       C8 letra    C10/C6        C6        C6
Stock capital         C9 letra    C11/C7        C7        C7
Variación existencias C10 letra   C12/—         —         —
Excedente explot.     C2 letra    C6            C2/C2.1   C2.1
Remuner. detalle      —           C7            C4        C4
Puestos detalle       —           C7/C8         —         —
```

ATENCIÓN: los números de cuadro difieren entre épocas. En los XLS verificados,
`C4` no es FBCF en 2008–2024 sino remuneraciones; la FBCF está en `C6`.
El pipeline resuelve esto desde `EAAE_FBCF_CONFIG` en `eaae_config.py`.
También se verificó que FBCF y `adquisiciones_importadas` usan C10 en
2003–2005, C6-F en 2006, y C6 desde 2007 en adelante. 2002 y 2011 no tienen
cuadro FBCF/adquisiciones en los RAR publicados.
También se verificó que `C5` en 2006–2024 corresponde a impuestos y que `C8`
en 2017–2024 corresponde a FBCF por componentes, no a variación de
existencias. Un escaneo completo de encabezados y celdas de todos los XLS de
2006–2024 no encontró variables de existencias/inventarios.

---

## §4. CONFIGURACIÓN TÉCNICA VALIDADA

Los valores de `header_row` y `data_start_row` fueron verificados contra
los 24 archivos reales. El `file_pattern` fue probado con regex sobre
cada RAR. Este es el archivo `command-files/config/eaae_config.py`.

```python
# command-files/config/eaae_config.py
# ─────────────────────────────────────────────────────────────────────────────
# Diccionario central de configuración de la serie EAAE 2001-2024.
# VALORES VALIDADOS CONTRA ARCHIVOS REALES — no modificar sin reverificar.
#
# Convenciones:
#   header_row     : índice 0-based de la ÚLTIMA fila del encabezado de columnas
#   data_start_row : índice 0-based de la PRIMERA fila con código de sección CIIU
#                    (puede autodetectarse con detect_data_start(); ver §4.3)
#   file_pattern   : expresión regular para localizar el XLS dentro del RAR
#   rar_name       : nombre exacto del archivo RAR publicado por el INE
# ─────────────────────────────────────────────────────────────────────────────

ESQUEMA_7COL = [
    "seccion",         # col 0 — letra CIIU (ej: "C")
    "division",        # col 1 — código numérico (ej: "10")
    "descripcion",     # col 2 — texto
    "vbp_pp",          # Valor Bruto de Producción a precios de productor
    "vab_pp",          # Valor Agregado Bruto a precios de productor
    "remuneraciones",
    "puestos_trabajo",
]

ESQUEMA_9COL = [
    "seccion",
    "division",
    "descripcion",
    "vbp_pp",
    "vbp_pb",          # VBP a precios básicos — NUEVO desde 2017
    "vab_pp",
    "vab_pb",          # VAB a precios básicos — NUEVO desde 2017
    "remuneraciones",
    "puestos_trabajo",
]

EAAE_CONFIG = {

    # ── ÉPOCA I — 2001 ────────────────────────────────────────────────────────
    2001: {
        "epoca": 1,
        "subfolder": None,
        "file_pattern": None,        # sin cuadro equivalente a C1.1
        "header_row": None,
        "data_start_row": None,
        "columns": None,
        "cuadros": ["C1","C2","C3","C4","C5","C6","C7","C8","C9","C10","C11"],
        "rar_name": "Encuesta_de_Actividad_Económica_2001.rar",
        "notes": (
            "CASO ESPECIAL. Sin equivalente a C1.1. 78 archivos en 3 subcarpetas: "
            "Letra/, 2 Digitos/, 4 Digitos/. Segmenta por tamaño de empresa. "
            "CIIU Rev.3. Requiere lógica de extracción propia. "
            "Tratar como fuente auxiliar — ver §7.3."
        ),
    },

    # ── ÉPOCA II — 2002–2005 ──────────────────────────────────────────────────
    2002: {
        "epoca": 2, "subfolder": None,
        "file_pattern": r"EAE_C1_2002\.xls",
        "header_row": 6, "data_start_row": 8,  # solo 1 fila vacía tras encabezado
        "columns": ESQUEMA_7COL,
        "cuadros": ["C1", "C2", "C3", "C9"],   # solo 4 cuadros disponibles
        "rar_name": "Encuesta_de_Actividad_Económica_2002.rar",
        "notes": "Solo 4 cuadros disponibles. CIIU Rev.3.",
    },
    2003: {
        "epoca": 2, "subfolder": None,
        "file_pattern": r"EAE_C1_2003\.xls",
        "header_row": 6, "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 14)],
        "rar_name": "Encuesta_de_Actividad_Económica_2003.rar",
        "notes": "CIIU Rev.3.",
    },
    2004: {
        "epoca": 2, "subfolder": None,
        "file_pattern": r"EAE_C1_2004\.xls",
        "header_row": 7, "data_start_row": 9,  # fila 4 vacía adicional
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 14)],
        "rar_name": "Encuesta_de_Actividad_Económica_2004.rar",
        "notes": "Fila 4 vacía extra → header_row=7 (vs. 6 en 2003/2005). CIIU Rev.3.",
    },
    2005: {
        "epoca": 2, "subfolder": None,
        "file_pattern": r"EAE_C1_2005\.xls",
        "header_row": 6, "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 14)],
        "rar_name": "Encuesta_de_Actividad_Económica_2005.rar",
        "notes": "CIIU Rev.3.",
    },

    # ── ÉPOCA III — 2006–2007 ─────────────────────────────────────────────────
    2006: {
        "epoca": 3, "subfolder": None,
        "file_pattern": r"EAE_C1-F_2006\.xls",  # sufijo -F (empresas forzosas)
        "header_row": 7, "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 11)],
        "rar_name": "Encuesta_de_Actividad_Económica_2006.rar",
        "notes": "Archivos con sufijo -F. CIIU Rev.3.",
    },
    2007: {
        "epoca": 3,
        "subfolder": "Forzosas y aleatorias",  # subcarpeta donde están los XLS
        "file_pattern": r"EAE_C1_2007\.xls",
        "header_row": 7, "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 11)],
        "rar_name": "Encuesta_de_Actividad_Económica_2007.rar",
        "notes": (
            "Cuadros duplicados: forzosas y aleatorias. "
            "Usar versión dentro de subcarpeta 'Forzosas y aleatorias/'. "
            "CIIU Rev.3."
        ),
    },

    # ── ÉPOCA IV-a — 2008–2012 ────────────────────────────────────────────────
    2008: {
        "epoca": 4, "subfolder": None,
        "file_pattern": r"EAE_C1_2008\.xls",
        "header_row": 7, "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 9)],
        "rar_name": "Encuesta_de_Actividad_Económica_2008.rar",
        "notes": "PRIMER AÑO con CIIU Rev.4. Manufactura = sección C.",
    },
    2009: {
        "epoca": 4, "subfolder": None,
        "file_pattern": r"EAE_C1_2009\.xls",
        "header_row": 7, "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 9)],
        "rar_name": "Encuesta_de_Actividad_Económica_2009.rar", "notes": "",
    },
    2010: {
        "epoca": 4, "subfolder": None,
        "file_pattern": r"EAE_C1_2010\.xls",
        "header_row": 7, "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": [f"C{n}" for n in range(1, 9)],
        "rar_name": "Encuesta_de_Actividad_Económica_2010.rar", "notes": "",
    },
    2011: {
        "epoca": 4, "subfolder": None,
        "file_pattern": r"EAE_C1_2011\.xls",
        "header_row": 7, "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": ["C1", "C2"],               # edición incompleta en la fuente
        "rar_name": "Encuesta_de_Actividad_Económica_2011.rar",
        "notes": "SOLO 2 cuadros disponibles. Edición incompleta publicada por INE.",
    },
    2012: {
        "epoca": 4, "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2012\.xls",
        "header_row": 7, "data_start_row": 10,
        "columns": ESQUEMA_7COL,
        "cuadros": (
            [f"C1.{n}" for n in range(1, 7)] +
            [f"C2.{n}" for n in range(1, 7)] +
            [f"C{n}"   for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2012.rar",
        "notes": "Primera aparición de subíndice decimal en nombre de cuadro (C1.1).",
    },

    # ── ÉPOCA IV-b — 2013–2016 ────────────────────────────────────────────────
    # Fila 3 agrega texto "Valorado a precios de productor..."
    # → header_row=6 y data_start_row=9 (un índice menos que en 2012)
    2013: {
        "epoca": 4, "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2013\.xls",
        "header_row": 6, "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": (
            [f"C1.{n}" for n in range(1, 7)] +
            [f"C2.{n}" for n in range(1, 7)] +
            [f"C{n}"   for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2013.rar",
        "notes": "Fila 3 agrega 'Valorado a pp...' vs. 2012 → data_start=9.",
    },
    2014: {
        "epoca": 4, "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2014\.xls",
        "header_row": 6, "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": (
            [f"C1.{n}" for n in range(1, 7)] +
            [f"C2.{n}" for n in range(1, 7)] +
            [f"C{n}"   for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2014.rar", "notes": "",
    },
    2015: {
        "epoca": 4, "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2015\.xls",
        "header_row": 6, "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": (
            [f"C1.{n}" for n in range(1, 7)] +
            [f"C2.{n}" for n in range(1, 7)] +
            [f"C{n}"   for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2015.rar", "notes": "",
    },
    2016: {
        "epoca": 4,
        "subfolder": "Encuesta de Actividad Económica 2016",
        "file_pattern": r"EAE_C1\.1_2016\.xls",
        "header_row": 6, "data_start_row": 9,
        "columns": ESQUEMA_7COL,
        "cuadros": (
            [f"C1.{n}" for n in range(1, 7)] +
            [f"C2.{n}" for n in range(1, 7)] +
            [f"C{n}"   for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2016.rar",
        "notes": "Archivos dentro de subcarpeta con nombre completo del año.",
    },

    # ── ÉPOCA V — 2017–2024 ───────────────────────────────────────────────────
    2017: {
        "epoca": 5,
        "subfolder": "Encuesta de Actividad Económica 2017",
        "file_pattern": r"EAE_C1\.1_?\s?2017\.xls",  # hay un espacio antes del año
        "header_row": 7, "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": (
            ["C1.1", "C1.2", "C1.3", "C2.1", "C2.2"] +
            [f"C{n}" for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2017.rar",
        "notes": (
            "PRIMER AÑO con 9 columnas (agrega vbp_pb, vab_pb). "
            "Nombre real del XLS: 'EAE_C1.1_ 2017.xls' (espacio antes del año). "
            "El file_pattern ya incorpora \\s? para tolerarlo."
        ),
    },
    2018: {
        "epoca": 5,
        "subfolder": "Encuesta de Actividad Económica 2018",
        "file_pattern": r"EAE_C1\.1_2018\.xls",
        "header_row": 7, "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": (
            ["C1.1", "C1.2", "C1.3", "C2.1", "C2.2"] +
            [f"C{n}" for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2018.rar", "notes": "",
    },
    2019: {
        "epoca": 5,
        "subfolder": "Encuesta de Actividad Económica 2019",
        "file_pattern": r"EAE_C1\.1_2019\.xls",
        "header_row": 7, "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": (
            ["C1.1", "C1.2", "C1.3", "C2.1", "C2.2"] +
            [f"C{n}" for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2019.rar", "notes": "",
    },
    2020: {
        "epoca": 5, "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2020\.xls",
        "header_row": 7, "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": (
            ["C1.1", "C1.2", "C1.3", "C2.1", "C2.2"] +
            [f"C{n}" for n in range(3, 9)]
        ),
        # ANOMALÍA: nombre de RAR completamente distinto al patrón de la serie
        "rar_name": "Principales_indicadores_y_desagregaciones_2020.rar",
        "notes": "ANOMALÍA: nombre del RAR distinto al patrón general de la serie.",
    },
    2021: {
        "epoca": 5, "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2021\.xls",
        "header_row": 7, "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": (
            ["C1.1", "C1.2", "C1.3", "C2.1", "C2.2"] +
            [f"C{n}" for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2021.rar", "notes": "",
    },
    2022: {
        "epoca": 5, "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2022\.xls",
        "header_row": 7, "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": (
            ["C1.1", "C1.2", "C1.3", "C2.1", "C2.2"] +
            [f"C{n}" for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2022.rar", "notes": "",
    },
    2023: {
        "epoca": 5, "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2023\.xls",
        "header_row": 7, "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": (
            ["C1.1", "C1.2", "C1.3", "C2.1", "C2.2"] +
            [f"C{n}" for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2023.rar", "notes": "",
    },
    2024: {
        "epoca": 5, "subfolder": None,
        "file_pattern": r"EAE_C1\.1_2024\.xls",
        "header_row": 7, "data_start_row": 9,
        "columns": ESQUEMA_9COL,
        "cuadros": (
            ["C1.1", "C1.2", "C1.3", "C2.1", "C2.2"] +
            [f"C{n}" for n in range(3, 9)]
        ),
        "rar_name": "Encuesta_de_Actividad_Económica_2024.rar",
        "notes": "Último año disponible al momento de documentar (mayo 2026).",
    },
}
```

### Detección automática de data_start_row

Usar esta función como valor primario; `EAAE_CONFIG[year]["data_start_row"]`
solo como fallback y para validación cruzada.

```python
import re

def detect_data_start(ws) -> int:
    """
    Retorna el índice 0-based de la primera fila donde la columna 0
    contiene exactamente una letra mayúscula (código de sección CIIU).
    Válido para épocas I–V. En 2001 detecta la primera sección posterior
    a la fila de Total.
    Lanza ValueError si no encuentra la fila.
    """
    for i in range(ws.nrows):
        val = str(ws.cell_value(i, 0)).strip()
        if re.match(r'^[A-Z]$', val):
            return i
    raise ValueError(
        f"No se encontró fila de inicio de datos (sección CIIU) "
        f"en las primeras {ws.nrows} filas."
    )
```

---

## §5. FASES DEL PIPELINE

El pipeline tiene seis fases secuenciales. Cada fase produce un artefacto
verificable. **No avanzar a la siguiente fase sin superar la validación de
la anterior.**

```
FASE 0 → Setup del entorno y estructura de carpetas
FASE 1 → Descarga de archivos RAR desde portal INE
FASE 2 → Extracción del cuadro C1/C1.1 por año
FASE 3 → Extracción de cuadros adicionales (FBCF, excedente, etc.)
FASE 4 → CHECKPOINT 1: Validación de la extracción
FASE 5 → Ensamble del panel y construcción de variables derivadas
FASE 6 → CHECKPOINT 2: Validación y exportación del panel final → YYYYMMDD_panel_eaae.csv + YYYYMMDD_panel_eaae.xlsx
```

### Orden de implementación recomendado dentro de Fases 2–3

Implementar y validar en este orden antes de continuar:

```
1. Época V (2017–2024)   → 8 años, 11 archivos c/u, 9 columnas, estructura
                            idéntica. Tramo más limpio. Implementar aquí primero.
2. Época IV (2008–2016)  → mismas variables, 7 columnas, dos sub-épocas
                            (2008–2012 vs. 2013–2016, data_start diferente).
3. Épocas II–III (2002–2007) → CIIU Rev.3, patrón de nombre diferente en 2006.
4. Época I (2001)        → caso especial incluido: cuadro 1 por letra, Total del País.
```

---

## §6. ESPECIFICACIÓN DEL PANEL FINAL

### Estructura de `data/analysis-data/YYYYMMDD_panel_eaae.csv`

El CSV contiene la base completa `panel_eaae`.

### Estructura de `data/analysis-data/YYYYMMDD_panel_eaae.xlsx`

El libro contiene cinco hojas base y ocho hojas de resultados propios:

- `eaae`: base completa.
- `rama-C`: registros de la rama de actividad `C`.
- `check-calidad-C`: controles anuales para la rama `C`: `vab_vbp`,
  `consumo_intermedio_estimado`, `remuneraciones_vab` y `stock_vab`.
- `economia_total`: agregacion anual de todas las variables del panel.
- `check-calidad-total`: controles anuales para `economia_total`: `vab_vbp`,
  `consumo_intermedio_estimado`, `remuneraciones_vab` y `stock_vab`.
- `resultados-total-corrientes`: cálculos propios del equipo para la economía total,
  en pesos corrientes.
- `resultados-industrial-corrientes`: cálculos propios del equipo para la rama
  industrial `C`.
- `resultados-total-constante`: cálculos propios del equipo para la economía total,
  en precios de 2005.
- `resultados-industrial-constante`: cálculos propios del equipo para la rama
  industrial `C`, en precios de 2005.
- `resultados-total-var-pct`: variaciones interanuales porcentuales de la hoja
  `resultados-total-constante`.
- `resultados-industrial-var-pct`: variaciones interanuales porcentuales de la
  hoja `resultados-industrial-constante`.
- `resultados-total-ind-2005`: índices encadenados con 2005=1 a partir de
  `resultados-total-var-pct`.
- `resultados-industrial-ind-2005`: índices encadenados con 2005=1 a partir de
  `resultados-industrial-var-pct`.

```
Columnas de identificación:
  anno          int     Año calendario (2001–2024)
  seccion       str     Sector CIIU homologado (ej: "C", "D_E", "H_J")
  epoca         int     Época estructural de la fuente (1–5)
  ciiu_version  str     "Rev.3" para 2001–2007, "Rev.4" para 2008–2024

Columnas de variables (pesos uruguayos corrientes):
  vbp_pp        float   Valor Bruto de Producción, precios de productor
  vbp_pb        float   Valor Bruto de Producción, precios básicos (NaN antes de 2017)
  vab_pp        float   Valor Agregado Bruto, precios de productor
  vab_pb        float   VAB, precios básicos (NaN antes de 2017)
  vab_pb_estimado float VAB a precios básicos observado desde 2017 y retroproyectado antes de 2017
  consumo_intermedio_estimado float Consumo intermedio estimado como vbp_pp - vab_pb_estimado
  capital_circulante_constante_adelantado float Consumo intermedio estimado dividido por factor de rotación
  remuneraciones float  Remuneraciones al trabajo asalariado
  capital_variable_adelantado float Remuneraciones divididas por factor de rotación
  puestos_trabajo float Puestos de trabajo ocupados
  n_empresas   float   Cantidad de empresas representadas en el marco muestral, por sección homologada
  fbcf          float   Formación Bruta de Capital Fijo (NaN donde no disponible)
  adquisiciones_importadas float Adquisiciones importadas dentro de FBCF
  consumo_capital_fijo float Consumo de capital fijo
  impuestos_netos float Impuestos sobre la producción y productos netos de subsidios
  stock_capital float Valor de activos fijos al 31/12 (NaN donde no disponible)
  capital_total_adelantado float Stock fijo + capital variable adelantado + capital circulante constante adelantado

Columnas derivadas calculadas en pipeline:
  capital_circulante_constante_adelantado float = consumo_intermedio_estimado / factor_rotacion
  capital_variable_adelantado float = remuneraciones / factor_rotacion
  capital_total_adelantado float = stock_capital + capital_variable_adelantado + capital_circulante_constante_adelantado
  excedente_bruto  float  = vab_pp - remuneraciones
  part_salarial    float  = remuneraciones / vab_pp
  productividad    float  = vab_pp / puestos_trabajo

Columnas derivadas PENDIENTES (no incluir hasta decisión del investigador):
  amortizaciones   float  ver §7.1
```

Variables directas identificadas pero aún no integradas al panel:
  variacion_existencias float  2001 C10 / 2003-2005 C12; sin fuente detectada en 2006-2024

### Clave única del panel
```python
# (anno, seccion) es clave única. Cero duplicados tolerados.
assert df.duplicated(subset=["anno", "seccion"]).sum() == 0
```

---

## §7. VALIDACIÓN — CHECKPOINTS OBLIGATORIOS

### CHECKPOINT 1 — Validación de extracción (Fase 4)

Ejecutar después de extraer todos los años, antes del ensamble.

```python
# CHECK 1 — Completitud de secciones por año
# Mínimo común observado para Ép. IV–V en C1/C1.1: C, D, E, G, H, I
# Construcción (F) no aparece en C1/C1.1 y minería (B) falta en 2009–2011.
secciones_minimas_rev4 = {"C", "D", "E", "G", "H", "I"}
assert set(df_year["seccion"]).issuperset(secciones_minimas_rev4), \
    f"Año {year}: secciones faltantes"

# CHECK 2 — Sin nulos en columnas clave (excluir filas de totales)
cols_clave = ["seccion", "anno", "vab_pp", "remuneraciones"]
assert df_year[cols_clave].notna().all().all(), \
    f"Año {year}: valores nulos en columnas clave"

# CHECK 3 — Coherencia de magnitudes (filas de sección, no totales)
filas_datos = df_year[df_year["seccion"].str.match(r'^[A-Z]$')]
assert (filas_datos["vbp_pp"] >= filas_datos["vab_pp"]).all(), \
    f"Año {year}: VBP < VAB en alguna sección (inconsistente)"
if not (filas_datos["vab_pp"] >= filas_datos["remuneraciones"]).all():
    logging.warning(
        f"Año {year}: VAB < Remuneraciones en alguna sección. "
        f"Tratar como alerta metodológica, no error fatal automático."
    )
assert (filas_datos["puestos_trabajo"] > 0).all(), \
    f"Año {year}: puestos_trabajo <= 0"

# CHECK 4 — Columnas según época
if year >= 2017:
    assert "vab_pb" in df_year.columns and df_year["vab_pb"].notna().any(), \
        f"Año {year}: vab_pb ausente o nulo (esperado en Ép. V)"
else:
    assert "vab_pb" not in df_year.columns or df_year["vab_pb"].isna().all(), \
        f"Año {year}: vab_pb presente antes de 2017 (inesperado)"
```

### CHECKPOINT 2 — Validación del panel final (Fase 6)

```python
# CHECK A — Cobertura temporal sin huecos
annos_presentes = sorted(df_panel["anno"].unique())
annos_esperados = list(range(2001, 2025))
assert annos_presentes == annos_esperados, "Panel con años faltantes"

# CHECK B — Cobertura sectorial mínima por año
for anno, grupo in df_panel.groupby("anno"):
    n_secciones = grupo["seccion"].nunique()
    assert n_secciones >= 6, \
        f"Año {anno}: solo {n_secciones} secciones (mínimo esperado: 6)"

# CHECK C — Clave única
assert df_panel.duplicated(subset=["anno", "seccion"]).sum() == 0, \
    "Panel con filas duplicadas en (anno, seccion)"

# CHECK D — Continuidad del total (alerta, no error fatal)
total_por_anno = df_panel.groupby("anno")["vab_pp"].sum()
variacion = total_por_anno.pct_change().abs()
annos_salto = variacion[variacion > 0.5].index.tolist()
if annos_salto:
    logging.warning(
        f"Variación interanual del VAB total > 50% en: {annos_salto}. "
        f"Revisar si es metodológico o un error de extracción."
    )
```

---

## §8. DECISIONES PENDIENTES DEL INVESTIGADOR

El agente **no debe implementar** las siguientes funcionalidades hasta recibir
instrucción explícita con la opción elegida.

### §7.1 — Stock de capital, consumo de capital, amortizaciones

La EAAE provee el **flujo** de inversión (FBCF/FBKF, extraído desde C8 en 2001,
C10 en 2003–2005 y C6 en 2006–2024) y también una fuente directa para
`stock_capital`: valor de activos fijos al 31/12. La extracción directa usa C9
en 2001, C11 en 2003–2005 y C7 desde 2006 en adelante. Los años 2002 y 2011
quedan sin `stock_capital`: en 2002 el RAR contiene `EAE_C9_2002.xls`, pero es
un cuadro de impuestos, no de activos fijos; en 2011 el RAR publicado solo
contiene C1 y C2.

La variable `amortizaciones` sigue pendiente. No construirla ni inferirla hasta
que el investigador defina fuente o método.
- [ ] ¿Cuál es el año base para K₀?
- [ ] ¿Tasas de depreciación diferenciadas por clase de activo o tasa única?

### §7.1.a — VAB a precios básicos estimado

**DECISIÓN PROVISORIA DEL EQUIPO — Junio 2026:** crear `vab_pb_estimado` como
serie completa 2001–2024. Para 2017–2024, `vab_pb_estimado` replica el
`vab_pb` observado en C1.1. Para años anteriores se retroproyecta por sección
homologada usando la variación interanual de `vab_pp`:

`vab_pb_estimado[t-1] = vab_pb_estimado[t] / (vab_pp[t] / vab_pp[t-1])`.

La implementación usa la forma equivalente `vab_pb_estimado[t] =
vab_pp[t] * (vab_pb/vab_pp)` del primer año observado por sección, para cubrir
secciones con años intermedios faltantes.

Esta variable es una imputación provisoria para análisis, no reemplaza la
variable directa `vab_pb`, que debe permanecer vacía antes de 2017.

### §7.1.b — Consumo intermedio estimado

**DECISIÓN PROVISORIA DEL EQUIPO — Junio 2026:** crear
`consumo_intermedio_estimado` como serie completa 2001–2024, calculada como:

`consumo_intermedio_estimado = vbp_pp - vab_pb_estimado`.

La variable busca aproximar el consumo intermedio/capital circulante constante
del panel. No es una variable observada directa de la EAAE y depende de
`vab_pb_estimado` antes de 2017. Dado que combina `vbp_pp` con VAB a precios
básicos observado o retroproyectado, debe tratarse como cálculo provisorio.

Para evitar confusiones, la variable directa que antes se exponía como
`consumo_capital` pasa a denominarse `consumo_capital_fijo` en el panel final.
La extracción puede mantener nombres internos asociados a la configuración de
C2/C2.1, pero el artefacto final debe usar el nombre explícito con sufijo
`_fijo`.

### §7.1.c — Capital adelantado

**DECISIÓN PROVISORIA DEL EQUIPO — Junio 2026:** crear variables de capital
adelantado usando factores fijos de rotación provistos por el equipo:

- `C`: 6,6.
- `economia_total`: 4,2.

El capital variable adelantado se calcula como:

`capital_variable_adelantado = remuneraciones / factor_rotacion`.

El capital circulante constante adelantado se calcula de forma análoga a partir
del consumo intermedio estimado:

`capital_circulante_constante_adelantado = consumo_intermedio_estimado / factor_rotacion`.

El capital total adelantado se calcula como:

`capital_total_adelantado = stock_capital + capital_variable_adelantado + capital_circulante_constante_adelantado`.

En el panel por sección solo se calcula para la rama `C`. En la hoja
`economia_total` se calcula para la economía agregada anual. Para sectores sin
factor de rotación definido, las tres variables quedan como NA. Si falta alguno
de los componentes necesarios, por ejemplo `stock_capital` en 2002 y 2011, el
capital total adelantado queda como NA.

### §7.1.d — Variación de existencias / inventarios

**VERIFICADO — Mayo 2026:** la EAAE usa la denominación `Variación de
existencias`, no `inventarios`. La fuente directa existe en:

- 2001: `Letra/EAE_cu10tpel_01.xls`, Cuadro 10, Total del País por sección.
- 2003–2005: `EAE_C12_<año>.xls`, Cuadro 12.

No se encontró fuente equivalente para 2006–2024. Se realizó un escaneo
completo de todos los XLS publicados para esos años, priorizando encabezados y
buscando términos asociados (`existencias`, `inventarios`, `stock`,
`mercaderías`, `materias primas`, `productos en proceso`, `productos
terminados`, etc.). Los únicos hallazgos no nucleares fueron falsos positivos
en descripciones de actividades, no variables.

Pendiente si se decide integrarla:
- [ ] Crear configuración `EAAE_EXISTENCIAS_CONFIG`.
- [ ] Extraer `variacion_existencias` para 2001 y 2003–2005.
- [ ] Dejar valores vacíos para 2002 y 2006–2024.

### §7.1.c — Deuda industrial / pasivos financieros

**VERIFICADO — Mayo 2026:** no se encontró una variable equivalente a `deuda`,
`pasivos`, `préstamos`, `crédito`, `endeudamiento`, `acreedores`,
`obligaciones`, `intereses`, `financiamiento bancario` o `deuda industrial` en
los archivos EAAE 2001–2024.

Se escanearon todos los RAR y XLS disponibles para 2001–2024. Los únicos
matches fueron falsos positivos:

- `contribución al financiamiento de la seguridad social`, que pertenece a
  impuestos/contribuciones, no a deuda.
- `servicios financieros` o actividades auxiliares, que son descripciones
  sectoriales CIIU, no variables de deuda.

Conclusión: no implementar `deuda_industrial` desde EAAE. Si se necesita esta
dimensión, debe incorporarse desde una fuente externa, por ejemplo crédito
bancario sectorial, balances empresariales, estadísticas del BCU, registros
tributarios o cuentas financieras sectoriales.

### §7.2 — Tratamiento del quiebre CIIU Rev.3 → Rev.4 (2007→2008)

**DECIDIDO — Mayo 2026:** el panel final será la opción B:
serie histórica homologada 2001–2024 con sectores agregados comparables.

- [x] Usar `seccion` como código homologado final.
- [x] No agregar columnas auxiliares de equivalencia al panel final.
- [x] Conservar `ciiu_version` como metadato de fuente.
- [x] Agregar D+E y H+J en Rev.4 para comparabilidad con Rev.3.

### §7.3 — Tratamiento del año 2001

**DECIDIDO — Mayo 2026:** incluir 2001 en la serie principal.

- [x] Usar `Letra/EAE_cu1tpel_01.xls`, cuadro 1, Total del País por sección.
- [x] Homologar secciones Rev.3 hacia `seccion` final sin columnas auxiliares.
- [x] Escalar variables monetarias por 1000 porque el cuadro publica miles de
  pesos corrientes; `puestos_trabajo` no se escala.
- [x] No crear tabla auxiliar `panel_eaae_2001.csv`; mantener la salida final
  fechada en `data/analysis-data/YYYYMMDD_panel_eaae.csv` y
  `data/analysis-data/YYYYMMDD_panel_eaae.xlsx`.

---

## §9. ANOMALÍAS CONOCIDAS

| Año | Tipo | Descripción | Solución en config |
|-----|------|-------------|-------------------|
| 2001 | Estructura | 78 archivos, 3 subcarpetas, sin C1.1; usar cuadro 1 por letra | `subfolder: "Letra"`, `file_pattern: EAE_cu1tpel_01\.xls`, `value_scale` monetario ×1000 |
| 2002 | FBCF | RAR publicado sin cuadro de Formación Bruta de Capital Fijo | `EAAE_FBCF_CONFIG[2002]["file_pattern"] = None` |
| 2002 | Stock | `EAE_C9_2002.xls` es cuadro de impuestos, no de activos fijos | `EAAE_STOCK_CONFIG[2002]["file_pattern"] = None` |
| 2002 | `data_start` | Solo 1 fila vacía → dato en fila 8, no 9 | `data_start_row: 8` |
| 2004 | `header_row` | Fila 4 vacía extra → encabezado en fila 7 | `header_row: 7` |
| 2006 | Nombre XLS | Sufijo `-F` en todos los archivos | `file_pattern` con `-F` |
| 2006 | Cuentas C2 | Layout verificado: impuestos netos col. 5, consumo capital fijo col. 6; col. 7 es VAB y no debe usarse como consumo | `EAAE_ACCOUNTS_CONFIG[2006]` + validación puente C 2005/2008 |
| 2007 | Subcarpeta | Cuadros duplicados; usar `Forzosas y aleatorias/` | `subfolder` definida |
| 2007 | Cuentas C2 | Layout verificado: impuestos netos col. 5, consumo capital fijo col. 6; col. 7 es VAB y no debe usarse como consumo | `EAAE_ACCOUNTS_CONFIG[2007]` + validación puente C 2005/2008 |
| 2011 | Datos | Solo C1 y C2 disponibles (incompleto) | `cuadros: ["C1","C2"]` |
| 2011 | FBCF | RAR publicado sin cuadro de Formación Bruta de Capital Fijo | `EAAE_FBCF_CONFIG[2011]["file_pattern"] = None` |
| 2011 | Cuentas C2 | Layout verificado: VAB col. 5, remuneraciones col. 6, impuestos netos col. 7, consumo capital col. 8 | `EAAE_ACCOUNTS_CONFIG[2011]` |
| 2012 | Nombre XLS | Primera aparición de subíndice decimal `C1.1` | `file_pattern` con `\.1` |
| 2013–2016 | `data_start` | Fila 3 extra "Valorado a pp..." → dato en fila 9 | `data_start_row: 9` |
| 2016 | Subcarpeta | Archivos dentro de carpeta con nombre largo | `subfolder` definida |
| 2017 | Nombre XLS | Espacio antes del año: `EAE_C1.1_ 2017.xls` | `\s?` en `file_pattern` |
| 2017 | Columnas | Primer año con 9 columnas (`vbp_pb`, `vab_pb`) | `ESQUEMA_9COL` |
| 2020 | Nombre RAR | Nombre completamente distinto al patrón | `rar_name` explícito |

---

## §10. DEPENDENCIAS Y ENTORNO

```
# requirements.txt
rarfile>=4.0        # lectura de archivos RAR5; requiere 'unrar' instalado a nivel sistema
xlrd>=2.0           # lectura de .xls legado (BIFF8, Excel 97-2003); no usar openpyxl para .xls
pandas>=2.0
requests>=2.28      # descarga HTTP de los RAR
beautifulsoup4>=4.0 # parsing del HTML del portal INE para obtener URLs de descarga
lxml>=4.9           # parser HTML requerido por beautifulsoup4
pytest>=7.0         # tests de validación automática
```

**Verificación previa al inicio:**
```bash
# Confirmar que unrar está instalado (requerido por rarfile)
which unrar || sudo apt install unrar

# Instalar dependencias Python
pip install -r requirements.txt

# Crear estructura de carpetas (si no existe)
mkdir -p data/input-data/eaae \
         data/input-data/metadata \
         data/analysis-data \
         command-files/config \
         command-files/processing-command-files \
         command-files/analysis-command-files \
         output/figures \
         output/tables \
         docs/minutes \
         docs/methodology
```

---

## §11. CONVENCIONES DE CÓDIGO

1. **Python 3.10+.** Sin f-strings con backslash anidado (incompatible < 3.12).
2. **Rutas relativas** desde la raíz del proyecto. Sin rutas absolutas.
3. **Logging** con el módulo estándar `logging`, no `print()`.
   INFO para operaciones normales, WARNING para anomalías esperadas,
   ERROR para fallos que detienen el pipeline.
4. **Idempotencia:** todos los scripts producen el mismo resultado si se
   re-ejecutan. Si el archivo de salida ya existe y es válido, saltear el
   procesamiento con un mensaje INFO.
5. **Sin silenciar errores:** ningún bloque `except: pass`.
   Toda excepción loggea el año y el archivo que la causó antes de relanzarse.
6. **Prefijo `# DECISION:`** para documentar en el código toda elección de
   implementación no trivial.
7. **Tests mínimos en `tests/`:** verificar al menos que el año 2020 (nombre
   de RAR anómalo) y el año 2017 (espacio en nombre de XLS) se extraen
   correctamente y devuelven un DataFrame con 9 columnas.

---

## §12. LOG DE SESIONES

| Fecha | Actividad | Estado |
|-------|-----------|--------|
| Mar 2026 | Evaluación estructural de archivos 2001–2014 | ✓ |
| Mar 2026 | Evaluación estructural de archivos 2015–2024 | ✓ |
| Mar 2026 | Construcción y validación de `EAAE_CONFIG` | ✓ |
| Mar 2026 | Diagrama de estructura por época y mapa de variables | ✓ |
| Mar 2026 | Definición de estructura TIER y fases del pipeline | ✓ |
| May 2026 | Redacción de `CONTEXT.md` (este documento) | ✓ |
| May 2026 | Decisión §8.2: panel final opción B, serie histórica homologada 2001–2024 | ✓ |
| May 2026 | Implementación `01_download.py` y descarga RAR 2001–2024 | ✓ |
| May 2026 | Implementación C1/C1.1 y creación preliminar de `panel_eaae.csv` 2002–2024 | ✓ |
| May 2026 | Creación inicial de minuta Quarto/revealjs, luego consolidada en archivo fechado único | ✓ |
| May 2026 | Integración de 2001 al panel principal desde cuadro 1 por letra con escalado monetario ×1000 | ✓ |
| May 2026 | Creación de minuta actualizada `docs/minutes/20260507_minuta_eaae_pipeline.qmd` | ✓ |
| May 2026 | Implementación de `03_extract_otros.py` y extracción de FBCF/FBKF al panel principal | ✓ |
| May 2026 | Extracción de consumo de capital fijo e `impuestos_netos` desde C2/C2.1 e integración al panel | ✓ |
| May 2026 | Extracción de `stock_capital` desde cuadros de valor de activos fijos al 31/12 e integración al panel | ✓ |
| May 2026 | Integración de `vbp_pb` desde C1.1 para 2017–2024 | ✓ |
| May 2026 | Integración de `adquisiciones_importadas` desde la columna Importadas de cuadros FBCF | ✓ |
| May 2026 | Corrección de fuente FBCF 2006–2007 hacia C6/C6-F tras verificación de encabezados | ✓ |
| May 2026 | Verificación de que `remuneraciones` incluye aportes patronales | ✓ |
| May 2026 | Escaneo completo 2006–2024: no se encontró fuente de inventarios/variación de existencias | ✓ |
| May 2026 | Escaneo completo 2001–2024: no se encontró variable de deuda/pasivos industriales en EAAE | ✓ |
| May 2026 | Consolidación de minuta: único QMD editable `docs/minutes/20260507_minuta_eaae_pipeline.qmd` | ✓ |
| May 2026 | Actualización de formato de tablas en la minuta Quarto y renderizado de HTML actualizado | ✓ |
| May 2026 | Creación de `command-files/analysis-command-files/01_load_panel.R` para cargar `panel_eaae.csv` en R como `panel_eaae` | ✓ |
| May 2026 | Reemplazo del CSV final por `20260528_panel_eaae.xlsx` con hojas `eaae`, `rama-C`, `check-calidad-C`, `economia_total` y `check-calidad-total` para revisión en GitHub | ✓ |
| May 2026 | Salidas fechadas automáticas para CSV completo y XLSX de revisión: `YYYYMMDD_panel_eaae.csv` y `YYYYMMDD_panel_eaae.xlsx` | ✓ |
| Jun 2026 | Decisión provisoria del equipo: creación de `vab_pb_estimado` con `vab_pb` observado desde 2017 y retroproyección por variación interanual de `vab_pp` | ✓ |
| Jun 2026 | Decisión provisoria del equipo: creación de `consumo_intermedio_estimado = vbp_pp - vab_pb_estimado` y renombre público de `consumo_capital` a `consumo_capital_fijo` | ✓ |
| Jun 2026 | Decisión provisoria del equipo: creación de `capital_variable_adelantado`, `capital_circulante_constante_adelantado` y `capital_total_adelantado` con factores 6,6 para C y 4,2 para economía total | ✓ |
| Jun 2026 | Validación específica para manufactura C en 2006–2007: `consumo_capital_fijo/vab_pp` se compara contra la envolvente 2005/2008 para detectar desalineación de columnas C2 | ✓ |
| Jun 2026 | Integración de `n_empresas` desde PDF de metodología/diseño muestral para años con desglose exacto verificable: 2001–2005, 2011 y 2020 | ✓ |
| Jun 2026 | Creación del post-proceso R `02_add_calculos_propios_eaae.R` y agregado de hojas de resultados corrientes, constantes, variaciones porcentuales e índices 2005=1 al XLSX | ✓ |
| Pendiente | Decisiones §8.1 (equipo de investigación) | ⏳ |
| Pendiente | Decidir método para `amortizaciones` y tratamiento de faltantes FBCF/stock 2002/2011 | ⏳ |

---

*Autores: Felipe Ruiz Bruzzone y Claude (Anthropic). Mayo 2026.*
