"""Extract and validate additional EAAE tables in memory."""

from __future__ import annotations

import argparse
import logging
import sys
from collections import Counter
from pathlib import Path

from eaae_accounts import extract_accounts_year, validate_accounts_year
from eaae_fbcf import extract_fbcf_year, validate_fbcf_year
from eaae_stock import extract_stock_year, validate_stock_year


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CONFIG_DIR = PROJECT_ROOT / "command-files" / "config"
sys.path.insert(0, str(CONFIG_DIR))

from eaae_config import PANEL_YEARS  # noqa: E402


LOGGER = logging.getLogger(__name__)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract additional EAAE tables.")
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

    fbcf_counter: Counter[int] = Counter()
    accounts_counter: Counter[int] = Counter()
    stock_counter: Counter[int] = Counter()
    for year in args.years:
        fbcf_rows = extract_fbcf_year(year)
        validate_fbcf_year(year, fbcf_rows)
        fbcf_counter[year] = len(fbcf_rows)
        LOGGER.info("Year %s: extracted %s FBCF sections", year, len(fbcf_rows))

        accounts_rows = extract_accounts_year(year)
        validate_accounts_year(year, accounts_rows)
        accounts_counter[year] = len(accounts_rows)
        LOGGER.info(
            "Year %s: extracted %s production-account sections",
            year,
            len(accounts_rows),
        )

        stock_rows = extract_stock_year(year)
        validate_stock_year(year, stock_rows)
        stock_counter[year] = len(stock_rows)
        LOGGER.info(
            "Year %s: extracted %s fixed-asset stock sections",
            year,
            len(stock_rows),
        )

    LOGGER.info(
        "Additional-table extraction completed: fbcf=%s accounts=%s stock=%s",
        dict(fbcf_counter),
        dict(accounts_counter),
        dict(stock_counter),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
