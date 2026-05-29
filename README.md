# economia-uruguay

Proyecto de procesamiento y sistematizacion de datos economicos de Uruguay.

El flujo principal actual construye un panel EAAE 2001-2024 por seccion CIIU
homologada, integrando variables de produccion, valor agregado, trabajo,
remuneraciones, inversion, adquisiciones importadas, consumo de capital fijo y
stock de capital.

Paneles de datos producidos: `data/analysis-data/YYYYMMDD_panel_eaae.csv` y
`data/analysis-data/YYYYMMDD_panel_eaae.xlsx`.

## Estructura

- `command-files/`: scripts de descarga, extraccion, construccion y validacion.
- `data/input-data/eaae/`: archivos originales EAAE descargados desde INE.
- `data/analysis-data/YYYYMMDD_panel_eaae.csv`: base completa `panel_eaae`.
- `data/analysis-data/YYYYMMDD_panel_eaae.xlsx`: libro de revision con hojas `eaae`, `rama-C`, `check-calidad-C`, `economia_total` y `check-calidad-total`.
- `docs/`: minutas e informes metodologicos.
  - [`20260520-datos-eaae.pdf`](docs/methodology/20260520-datos-eaae.pdf)
- `tests/`: pruebas de regresion y validacion.
- `CONTEXT.md`: bitacora tecnica y decisiones de trabajo.

## Reproduccion

Instalar dependencias de Python:

```bash
pip install -r requirements.txt
```

Construir y validar el panel:

```bash
python3 command-files/processing-command-files/03_extract_otros.py
python3 command-files/processing-command-files/05_build_panel.py --force
python3 command-files/processing-command-files/06_validate_panel.py
```

Nota: la extraccion desde archivos RAR requiere `unrar` o una ruta compatible
detectada por los scripts del proyecto.
