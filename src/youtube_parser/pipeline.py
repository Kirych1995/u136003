"""High level orchestration for collecting YouTube analytics."""

from __future__ import annotations

from typing import Optional

from .analytics import build_channel_summary, build_videos_dataframe, compute_video_insights
from .client import YouTubeAPIClient
from .config import PipelineConfig
from .exporters import CSVExporter, ExportPayload, GoogleSheetsExporter, JSONExporter


def run_pipeline(config: PipelineConfig, *, progress: Optional[callable] = None) -> ExportPayload:
    """Execute the pipeline and export the results."""

    config.validate()

    def notify(message: str) -> None:
        if progress is not None:
            progress(message)

    notify("Initializing YouTube client")
    client = YouTubeAPIClient(config.api_key)

    notify("Fetching channel overview")
    channel_payload = client.get_channel_overview(config.channel_id)

    playlist_id = channel_payload.get("contentDetails", {}).get("relatedPlaylists", {}).get("uploads")
    if not playlist_id:
        raise RuntimeError("Uploads playlist not found for the channel")

    notify("Collecting video ids")
    video_ids = client.list_videos(playlist_id, config.max_videos)

    notify(f"Fetching metadata for {len(video_ids)} videos")
    videos = client.get_videos(video_ids)

    notify("Building analytics tables")
    videos_df = build_videos_dataframe(videos)
    summary = build_channel_summary(channel_payload, videos_df)
    insights = compute_video_insights(videos_df)

    payload = ExportPayload(summary=summary, videos=videos_df, insights=insights)

    notify(f"Exporting results via {config.export}")
    if config.export == "csv":
        exporter = CSVExporter(config.output_path)
    elif config.export == "json":
        exporter = JSONExporter(config.output_path)
    else:
        exporter = GoogleSheetsExporter(
            config.google_sheets.service_account_key or "",
            config.google_sheets.spreadsheet_id or "",
            config.google_sheets.worksheet_overview,
            config.google_sheets.worksheet_videos,
        )
    exporter.export(payload)

    notify("Pipeline finished")
    return payload


__all__ = ["run_pipeline"]
