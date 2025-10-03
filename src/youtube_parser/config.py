"""Configuration helpers for the YouTube analytics pipeline."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional


def _get_env(name: str, default: Optional[str] = None) -> Optional[str]:
    """Safely pull environment variable.

    Parameters
    ----------
    name:
        Environment variable name.
    default:
        Default value if the variable is not set.
    """

    import os

    return os.environ.get(name, default)


@dataclass(slots=True)
class GoogleSheetsConfig:
    """Configuration for Google Sheets export."""

    service_account_key: Optional[str] = None
    spreadsheet_id: Optional[str] = None
    worksheet_overview: str = "Channel Overview"
    worksheet_videos: str = "Videos"

    def is_configured(self) -> bool:
        return bool(self.service_account_key and self.spreadsheet_id)


@dataclass(slots=True)
class PipelineConfig:
    """Configuration for running the analytics pipeline."""

    api_key: str = field(default_factory=lambda: _get_env("YOUTUBE_API_KEY", ""))
    channel_id: str = "UCdwN2l9VmZpK5x6tEN84ImA"
    max_videos: int = 200
    export: str = "csv"  # csv | json | google-sheets
    output_path: str = "analytics.csv"
    google_sheets: GoogleSheetsConfig = field(default_factory=GoogleSheetsConfig)

    def validate(self) -> None:
        if not self.api_key:
            raise ValueError(
                "YouTube API key is not configured. Set YOUTUBE_API_KEY env variable or pass via --api-key."
            )
        if self.max_videos <= 0:
            raise ValueError("max_videos must be positive")
        if self.export not in {"csv", "json", "google-sheets"}:
            raise ValueError("Unsupported export format. Use csv, json or google-sheets.")
        if self.export == "google-sheets" and not self.google_sheets.is_configured():
            raise ValueError(
                "Google Sheets export selected but service account key or spreadsheet id is missing."
            )


__all__ = [
    "PipelineConfig",
    "GoogleSheetsConfig",
]
