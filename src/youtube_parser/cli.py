"""Command line interface for running the analytics pipeline."""

from __future__ import annotations

import argparse
from typing import List, Optional

from .config import GoogleSheetsConfig, PipelineConfig
from .pipeline import run_pipeline


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="YouTube analytics pipeline")
    parser.add_argument("--api-key", dest="api_key", help="YouTube Data API key", default=None)
    parser.add_argument("--channel-id", dest="channel_id", required=True, help="Target channel identifier")
    parser.add_argument("--max-videos", dest="max_videos", type=int, default=200, help="Limit number of videos to fetch")
    parser.add_argument(
        "--export",
        choices=["csv", "json", "google-sheets"],
        default="csv",
        help="Export destination",
    )
    parser.add_argument("--output-path", dest="output_path", default="analytics.csv", help="Path to export file")
    parser.add_argument("--service-account-key", dest="service_account_key", default=None, help="Path to Google service account JSON key")
    parser.add_argument("--spreadsheet-id", dest="spreadsheet_id", default=None, help="Target Google Sheets spreadsheet id")
    parser.add_argument("--worksheet-overview", dest="worksheet_overview", default="Channel Overview")
    parser.add_argument("--worksheet-videos", dest="worksheet_videos", default="Videos")
    parser.add_argument("--verbose", action="store_true", help="Print pipeline progress")
    return parser.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> None:
    args = parse_args(argv)

    google_config = GoogleSheetsConfig(
        service_account_key=args.service_account_key,
        spreadsheet_id=args.spreadsheet_id,
        worksheet_overview=args.worksheet_overview,
        worksheet_videos=args.worksheet_videos,
    )
    config = PipelineConfig(
        api_key=args.api_key or PipelineConfig().api_key,
        channel_id=args.channel_id,
        max_videos=args.max_videos,
        export=args.export,
        output_path=args.output_path,
        google_sheets=google_config,
    )

    progress = print if args.verbose else None
    run_pipeline(config, progress=progress)


if __name__ == "__main__":
    main()
