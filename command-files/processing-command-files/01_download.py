"""Download raw EAAE RAR files from the INE Uruguay series page."""

from __future__ import annotations

import argparse
import logging
import re
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import unquote, urljoin, urlparse

import requests
from bs4 import BeautifulSoup
from urllib3.exceptions import InsecureRequestWarning


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CONFIG_DIR = PROJECT_ROOT / "command-files" / "config"
sys.path.insert(0, str(CONFIG_DIR))

from eaae_config import DATA_INPUT_EAAE_DIR, EAAE_CONFIG, INE_EAAE_SERIES_URL  # noqa: E402


LOGGER = logging.getLogger(__name__)
RAR_SIGNATURES = (b"Rar!\x1a\x07\x00", b"Rar!\x1a\x07\x01\x00")


@dataclass(frozen=True)
class DownloadCandidate:
    year: int
    url: str
    source_name: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download original INE EAAE RAR archives for 2001-2024."
    )
    parser.add_argument(
        "--years",
        nargs="*",
        type=int,
        default=sorted(EAAE_CONFIG),
        help="Specific years to download. Defaults to every configured year.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Resolve and log download URLs without writing files.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Re-download files even when a valid local RAR already exists.",
    )
    parser.add_argument(
        "--portal-url",
        default=INE_EAAE_SERIES_URL,
        help="INE series page URL. Defaults to the configured official page.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=60.0,
        help="HTTP timeout in seconds for page and file requests.",
    )
    parser.add_argument(
        "--allow-insecure-ssl",
        action="store_true",
        help=(
            "Disable TLS certificate verification. Use only when the official "
            "INE file host has an incomplete certificate chain in the local "
            "Python environment."
        ),
    )
    return parser.parse_args()


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )


def normalize_name(value: str) -> str:
    decoded = unquote(value)
    without_accents = unicodedata.normalize("NFKD", decoded).encode(
        "ascii", "ignore"
    )
    return re.sub(r"[^a-z0-9]+", "", without_accents.decode("ascii").lower())


def extract_year(*values: str) -> int | None:
    for value in values:
        match = re.search(r"\b(20[0-2][0-9])\b", unquote(value))
        if match:
            return int(match.group(1))
    return None


def basename_from_url(url: str) -> str:
    return Path(unquote(urlparse(url).path)).name


def fetch_series_page(session: requests.Session, portal_url: str, timeout: float) -> str:
    LOGGER.info("Fetching INE EAAE series page: %s", portal_url)
    response = session.get(portal_url, timeout=timeout)
    response.raise_for_status()
    return response.text


def discover_candidates(html: str, portal_url: str) -> dict[int, DownloadCandidate]:
    soup = BeautifulSoup(html, "lxml")
    candidates: dict[int, DownloadCandidate] = {}

    for anchor in soup.find_all("a", href=True):
        href = anchor["href"]
        url = urljoin(portal_url, href)
        source_name = basename_from_url(url)
        if ".rar" not in unquote(url).lower():
            continue

        year = extract_year(anchor.get_text(" ", strip=True), source_name, url)
        if year is None:
            LOGGER.warning("Ignoring RAR link without year: %s", url)
            continue

        if year in candidates:
            LOGGER.warning(
                "Duplicate RAR link for %s; keeping first candidate %s and ignoring %s",
                year,
                candidates[year].url,
                url,
            )
            continue

        candidates[year] = DownloadCandidate(year=year, url=url, source_name=source_name)

    return candidates


def expected_years(years: list[int]) -> list[int]:
    unknown = sorted(set(years) - set(EAAE_CONFIG))
    if unknown:
        raise ValueError(f"Years not present in EAAE_CONFIG: {unknown}")
    return sorted(dict.fromkeys(years))


def resolve_downloads(
    candidates: dict[int, DownloadCandidate], years: list[int]
) -> dict[int, DownloadCandidate]:
    resolved: dict[int, DownloadCandidate] = {}

    for year in years:
        expected_name = EAAE_CONFIG[year]["rar_name"]
        candidate = candidates.get(year)
        if candidate is None:
            raise RuntimeError(f"Year {year}: no RAR link found on the INE page")

        expected_normalized = normalize_name(expected_name)
        source_normalized = normalize_name(candidate.source_name)

        # DECISION: Compare normalized names because the INE page uses URL-encoded
        # spaces while project config stores reproducible underscore filenames.
        if expected_normalized != source_normalized:
            raise RuntimeError(
                f"Year {year}: INE RAR name mismatch. Expected {expected_name!r}, "
                f"found {candidate.source_name!r} at {candidate.url}"
            )

        resolved[year] = candidate

    return resolved


def looks_like_rar(path: Path) -> bool:
    if not path.exists() or path.stat().st_size == 0:
        return False
    with path.open("rb") as file:
        header = file.read(8)
    return any(header.startswith(signature) for signature in RAR_SIGNATURES)


def download_file(
    session: requests.Session,
    url: str,
    destination: Path,
    timeout: float,
) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temp_path = destination.with_suffix(destination.suffix + ".part")

    LOGGER.info("Downloading %s -> %s", url, destination)
    with session.get(url, stream=True, timeout=timeout) as response:
        response.raise_for_status()
        with temp_path.open("wb") as file:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    file.write(chunk)

    if not looks_like_rar(temp_path):
        raise RuntimeError(f"Downloaded file is not a valid RAR: {temp_path}")

    temp_path.replace(destination)


def main() -> int:
    configure_logging()
    args = parse_args()
    years = expected_years(args.years)
    output_dir = PROJECT_ROOT / DATA_INPUT_EAAE_DIR

    with requests.Session() as session:
        session.headers.update(
            {"User-Agent": "economia-uruguay-eaae-pipeline/1.0"}
        )
        if args.allow_insecure_ssl:
            # DECISION: Keep strict TLS verification as the default, but allow a
            # documented escape hatch for the INE static file host when local CA
            # resolution fails before any source archive can be downloaded.
            LOGGER.warning("TLS certificate verification disabled by request")
            requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)
            session.verify = False
        html = fetch_series_page(session, args.portal_url, args.timeout)
        candidates = discover_candidates(html, args.portal_url)
        downloads = resolve_downloads(candidates, years)

        for year in years:
            expected_name = EAAE_CONFIG[year]["rar_name"]
            destination = output_dir / expected_name
            candidate = downloads[year]

            if args.dry_run:
                LOGGER.info(
                    "DRY RUN year %s: %s -> %s",
                    year,
                    candidate.url,
                    destination.relative_to(PROJECT_ROOT),
                )
                continue

            if destination.exists() and not args.force:
                if looks_like_rar(destination):
                    LOGGER.info("Year %s: valid local RAR exists; skipping", year)
                    continue
                raise RuntimeError(
                    f"Year {year}: local file exists but is not a valid RAR: "
                    f"{destination}. Re-run with --force after checking the file."
                )

            download_file(session, candidate.url, destination, args.timeout)
            LOGGER.info("Year %s: saved %s", year, destination)

    LOGGER.info("Download phase completed for %s years", len(years))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
