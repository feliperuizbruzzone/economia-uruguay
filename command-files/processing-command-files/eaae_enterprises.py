"""Extract EAAE represented enterprise counts from methodology PDFs."""

from __future__ import annotations

import logging
import re
import shutil
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CONFIG_DIR = PROJECT_ROOT / "command-files" / "config"
sys.path.insert(0, str(CONFIG_DIR))

from eaae_config import (  # noqa: E402
    DATA_INPUT_EAAE_METHODOLOGY_DIR,
    EAAE_ENTERPRISE_METHODOLOGY_SOURCES,
    homologate_ciiu_section,
)


LOGGER = logging.getLogger(__name__)


def source_section_from_activity_code(code: str) -> str:
    """Map a CIIU Rev.3 activity code or grouped code to its source section."""
    normalized_code = code.replace(".", "").replace(" ", "")
    first_group = re.findall(r"\d+", normalized_code)
    if not first_group:
        raise ValueError(f"Cannot map activity code without digits: {code!r}")
    first_code = first_group[0]
    division = int(first_code[:2])
    if 15 <= division <= 37:
        return "D"
    if 40 <= division <= 41:
        return "E"
    if 50 <= division <= 52:
        return "G"
    if division == 55:
        return "H"
    if 60 <= division <= 64:
        return "I"
    if 70 <= division <= 74:
        return "K"
    if division == 80:
        return "M"
    if division == 85:
        return "N"
    raise ValueError(f"Cannot map Rev.3 activity code to EAAE section: {code!r}")


def run_pdftotext(pdf_path: Path) -> str:
    if shutil.which("pdftotext") is None:
        raise RuntimeError("pdftotext is required to extract EAAE methodology PDFs")
    completed = subprocess.run(
        ["pdftotext", "-layout", str(pdf_path), "-"],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return completed.stdout.decode("utf-8", errors="replace")


def text_between(text: str, start: str, end: str) -> str:
    try:
        start_index = text.index(start)
        end_index = text.index(end, start_index)
    except ValueError as exc:
        raise ValueError(
            f"Could not find expected PDF text block from {start!r} to {end!r}"
        ) from exc
    return text[start_index:end_index]


def add_activity_code_count(
    counts: Counter[str],
    activity_code: str,
    value: int,
) -> None:
    counts[source_section_from_activity_code(activity_code)] += value


def parse_2001_counts(text: str) -> dict[str, int]:
    counts: Counter[str] = Counter()

    forced_block = text_between(
        text,
        "Unidades de inclusión forzosa en la muestra de la EAE 2001",
        "Unidades del marco de la EAE 2001 para el estrato de 20 a 49",
    )
    for activity_code, value in re.findall(r"\b(\d{3})\s+(\d+)\b", forced_block):
        add_activity_code_count(counts, activity_code, int(value))

    frame_20_49 = text_between(
        text,
        "Unidades del marco de la EAE 2001 para el estrato de 20 a 49",
        "Unidades aleatorias para el estrato de 20 a 49",
    )
    add_division_table_counts(counts, frame_20_49)

    frame_5_19 = text_between(
        text,
        "Unidades del marco de la EAE 2001 para el estrato de 5 a 19",
        "Unidades aleatorias para el estrato de 5 a 19",
    )
    add_division_table_counts(counts, frame_5_19)

    frame_under_5 = text_between(
        text,
        "Unidades del marco de la EAE 2001 para el estrato de menos de 5",
        "Unidades aleatorias para el estrato de menos de 5",
    )
    for section, value in re.findall(r"^\s*([DGHIKMN])\s+(\d+)\s*$", frame_under_5, re.M):
        counts[section] += int(value)

    return dict(counts)


def add_division_table_counts(counts: Counter[str], block: str) -> None:
    for line in block.splitlines():
        match = re.match(r"^\s*([0-9][0-9\-\s]+)\s+(\d+)\s*$", line)
        if not match:
            continue
        add_activity_code_count(counts, match.group(1), int(match.group(2)))


def parse_2002_2003_counts(text: str) -> dict[str, int]:
    counts: Counter[str] = Counter()
    for line in text.splitlines():
        if not line.strip().startswith("Total "):
            continue
        for part in re.split(r"(?=Total\s+)", line):
            part = part.strip()
            if not part.startswith("Total ") or "general" in part.lower():
                continue
            match = re.match(r"Total\s+(.+?)\s+(\d+)\s+(\d+)\s+(\d+)\s*$", part)
            if not match:
                continue
            activity_code = match.group(1)
            forced_frame = int(match.group(2))
            random_frame = int(match.group(3))
            add_activity_code_count(counts, activity_code, forced_frame + random_frame)
    return dict(counts)


def parse_single_frame_table_counts(text: str) -> dict[str, int]:
    counts: Counter[str] = Counter()
    normalized = text.replace(",", ".")
    pattern = re.compile(
        r"(?<![A-Za-z])([0-9][0-9.]*\s*(?:-\s*[0-9][0-9.]*)?)"
        r"\s+([0-9]+(?:\.00)?)\s+([0-9]+(?:\.00)?)"
    )
    for line in normalized.splitlines():
        for activity_code, frame_value, _sample_value in pattern.findall(line):
            try:
                add_activity_code_count(
                    counts,
                    activity_code,
                    int(float(frame_value)),
                )
            except ValueError:
                # DECISION: OCR/text extraction may pick up questionnaire codes
                # outside the frame table. They are ignored and the published
                # total check below guards against silent contamination.
                continue
    return dict(counts)


def parse_vector_bar_graph_counts(pdf_path: Path, source: dict[str, object]) -> dict[str, int]:
    if shutil.which("pdftocairo") is None:
        raise RuntimeError("pdftocairo is required to extract vector bar charts")

    page = int(source["page"])
    axis_max = int(source["axis_max"])
    with tempfile.TemporaryDirectory() as tmpdir:
        svg_base = Path(tmpdir) / "page"
        subprocess.run(
            [
                "pdftocairo",
                "-f",
                str(page),
                "-l",
                str(page),
                "-svg",
                str(pdf_path),
                str(svg_base),
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        svg = svg_base.read_text(encoding="utf-8", errors="replace")

    bar_pattern = re.compile(
        r'<path[^>]+fill="rgb\(11\.372375%, 43\.136597%, 93\.72406%\)"'
        r'[^>]+d="M ([0-9.]+) ([0-9.]+) L ([0-9.]+) ([0-9.]+) '
        r'L ([0-9.]+) ([0-9.]+) L ([0-9.]+) ([0-9.]+) Z'
    )
    bars: list[tuple[float, float, float]] = []
    for match in bar_pattern.finditer(svg):
        coordinates = list(map(float, match.groups()))
        xs = coordinates[0::2]
        ys = coordinates[1::2]
        bars.append((min(xs), min(ys), max(ys)))
    bars.sort(key=lambda value: value[0])

    source_sections = list(source["source_sections"])
    if len(bars) != len(source_sections):
        raise ValueError(
            f"Expected {len(source_sections)} vector bars in {pdf_path.name}, "
            f"got {len(bars)}"
        )

    tick_ys = [
        float(match.group(1))
        for match in re.finditer(
            r'd="M 85\.[0-9]+ ([0-9.]+) L 82\.[0-9]+ [0-9.]+ "', svg
        )
    ]
    if len(tick_ys) < 2:
        raise ValueError(f"Could not extract y-axis ticks from {pdf_path.name}")
    baseline = max(tick_ys)
    top_tick = min(tick_ys)
    value_scale = (baseline - top_tick) / axis_max
    values = {
        section: round((baseline - top_y) / value_scale)
        for section, (_left_x, top_y, _bottom_y) in zip(source_sections, bars)
    }
    return values


def source_counts_for_year(year: int) -> dict[str, int]:
    source = EAAE_ENTERPRISE_METHODOLOGY_SOURCES.get(year)
    if source is None:
        return {}

    pdf_path = PROJECT_ROOT / DATA_INPUT_EAAE_METHODOLOGY_DIR / str(source["pdf"])
    if not pdf_path.exists():
        raise FileNotFoundError(f"Missing EAAE methodology PDF: {pdf_path}")

    method = str(source["method"])
    if method == "manual_labeled_graph":
        counts = dict(source["source_counts"])
    elif method == "vector_bar_graph":
        counts = parse_vector_bar_graph_counts(pdf_path, source)
    else:
        text = run_pdftotext(pdf_path)
        if method == "text_tables_2001":
            counts = parse_2001_counts(text)
        elif method == "text_table_forced_random":
            counts = parse_2002_2003_counts(text)
        elif method == "text_table_single_frame":
            counts = parse_single_frame_table_counts(text)
        else:
            raise ValueError(f"Unknown EAAE enterprise extraction method: {method}")

    expected_total = int(source["expected_total"])
    actual_total = sum(counts.values())
    if actual_total != expected_total:
        raise AssertionError(
            f"Year {year}: enterprise count total mismatch from {pdf_path.name}; "
            f"expected {expected_total}, got {actual_total}"
        )
    return {str(section): int(value) for section, value in counts.items()}


def expected_enterprise_counts_for_year(year: int) -> dict[str, int]:
    source = EAAE_ENTERPRISE_METHODOLOGY_SOURCES.get(year)
    if source is None:
        return {}

    ciiu_version = str(source["ciiu_version"])
    homologated: Counter[str] = Counter()
    for source_section, value in source_counts_for_year(year).items():
        section = homologate_ciiu_section(source_section, ciiu_version)
        homologated[section] += value
    return dict(homologated)


def extract_enterprise_counts_year(year: int) -> list[dict[str, object]]:
    return [
        {
            "anno": year,
            "seccion": section,
            "n_empresas": n_empresas,
        }
        for section, n_empresas in sorted(
            expected_enterprise_counts_for_year(year).items()
        )
    ]


def extract_enterprise_counts_panel(
    years: list[int] | None = None,
) -> list[dict[str, object]]:
    selected_years = years or sorted(EAAE_ENTERPRISE_METHODOLOGY_SOURCES)
    rows: list[dict[str, object]] = []
    for year in selected_years:
        year_rows = extract_enterprise_counts_year(year)
        if year_rows:
            LOGGER.info("Year %s: extracted enterprise counts", year)
        rows.extend(year_rows)
    return rows
