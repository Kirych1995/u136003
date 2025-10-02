"""Export analytics results to various destinations."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List

import pandas as pd

from .analytics import ChannelSummary


@dataclass(slots=True)
class ExportPayload:
    """Container with all computed artefacts."""

    summary: ChannelSummary
    videos: pd.DataFrame
    insights: Dict[str, List]


class Exporter:
    """Base exporter interface."""

    def export(self, payload: ExportPayload) -> None:  # pragma: no cover - interface
        raise NotImplementedError


class CSVExporter(Exporter):
    def __init__(self, output_path: str) -> None:
        self.output_path = Path(output_path)

    def export(self, payload: ExportPayload) -> None:
        self.output_path.parent.mkdir(parents=True, exist_ok=True)
        payload.videos.to_csv(self.output_path, index=False)
        meta_path = self.output_path.with_name(self.output_path.stem + "_summary.json")
        summary_dict = {
            "title": payload.summary.title,
            "description": payload.summary.description,
            "subscribers": payload.summary.subscribers,
            "views": payload.summary.views,
            "videos": payload.summary.videos,
            "last_video_published_at": payload.summary.last_video_published_at,
            "insights": payload.insights,
        }
        meta_path.write_text(json.dumps(summary_dict, ensure_ascii=False, indent=2), encoding="utf-8")


class JSONExporter(Exporter):
    def __init__(self, output_path: str) -> None:
        self.output_path = Path(output_path)

    def export(self, payload: ExportPayload) -> None:
        self.output_path.parent.mkdir(parents=True, exist_ok=True)
        data = {
            "summary": {
                "title": payload.summary.title,
                "description": payload.summary.description,
                "subscribers": payload.summary.subscribers,
                "views": payload.summary.views,
                "videos": payload.summary.videos,
                "last_video_published_at": payload.summary.last_video_published_at,
            },
            "insights": payload.insights,
            "videos": payload.videos.to_dict(orient="records"),
        }
        self.output_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


class GoogleSheetsExporter(Exporter):
    """Push analytics into Google Sheets."""

    def __init__(self, service_account_key: str, spreadsheet_id: str, worksheet_overview: str, worksheet_videos: str) -> None:
        self.service_account_key = service_account_key
        self.spreadsheet_id = spreadsheet_id
        self.worksheet_overview = worksheet_overview
        self.worksheet_videos = worksheet_videos

    def export(self, payload: ExportPayload) -> None:
        from google.oauth2 import service_account
        import gspread

        credentials = service_account.Credentials.from_service_account_file(
            self.service_account_key,
            scopes=[
                "https://www.googleapis.com/auth/spreadsheets",
                "https://www.googleapis.com/auth/drive.file",
            ],
        )
        client = gspread.authorize(credentials)
        spreadsheet = client.open_by_key(self.spreadsheet_id)

        overview_sheet = self._get_or_create(spreadsheet, self.worksheet_overview)
        overview_values = [
            ["Channel", payload.summary.title],
            ["Description", payload.summary.description],
            ["Subscribers", payload.summary.subscribers],
            ["Views", payload.summary.views],
            ["Videos", payload.summary.videos],
            ["Last upload", payload.summary.last_video_published_at],
        ]
        overview_sheet.clear()
        overview_sheet.update("A1", overview_values)

        insight_rows: List[List[str]] = []
        for key, top_items in payload.insights.items():
            insight_rows.append([key.replace("_", " ").title(), ""])
            insight_rows.append(["Video", "Metric"])
            for title, value in top_items:
                insight_rows.append([title, str(value)])
            insight_rows.append(["", ""])
        if insight_rows:
            start_row = len(overview_values) + 2
            overview_sheet.update(f"A{start_row}", insight_rows)

        videos_sheet = self._get_or_create(spreadsheet, self.worksheet_videos)
        header = list(payload.videos.columns)
        values = [header] + payload.videos.fillna("").values.tolist()
        videos_sheet.clear()
        videos_sheet.update("A1", values)

    @staticmethod
    def _get_or_create(spreadsheet, worksheet_name: str):
        try:
            return spreadsheet.worksheet(worksheet_name)
        except Exception:  # gspread raises WorksheetNotFound
            return spreadsheet.add_worksheet(title=worksheet_name, rows=1000, cols=26)


__all__ = [
    "ExportPayload",
    "Exporter",
    "CSVExporter",
    "JSONExporter",
    "GoogleSheetsExporter",
]
