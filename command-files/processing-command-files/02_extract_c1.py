"""Extract and validate EAAE C1/C1.1 data in memory."""

from __future__ import annotations

import argparse
import logging
import sys
from collections import Counter
from pathlib import Path

from eaae_c1 import extract_c1_year, validate_extracted_year


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CONFIG_DIR = PROJECT_ROOT / "command-files" / "config"
sys.path.insert(0, str(CONFIG_DIR))

from eaae_config import PANEL_YEARS  # noqa: E402


LOGGER = logging.getLogger(__name__)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract EAAE C1/C1.1 by year.")
    parser.add_argument(
        "--years",
        nargs="*",
        type=int,
        default=PANEL_YEARS,
        help="Years to extract. Defaults to configured panel years.",
    )
    return parser.parse_args()


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )


def main() -> int:
    configure_logging()
    args = parse_args()

    counter: Counter[int] = Counter()
    for year in args.years:
        rows = extract_c1_year(year)
        validate_extracted_year(year, rows)
        counter[year] = len(rows)
        LOGGER.info("Year %s: extracted %s homologated sections", year, len(rows))

    LOGGER.info("Extraction completed: %s", dict(counter))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
