"""Derive analytics from raw YouTube API responses."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List, Tuple

import pandas as pd
from dateutil import parser as date_parser

from .client import Video


@dataclass(slots=True)
class ChannelSummary:
    """Key metrics for the channel."""

    title: str
    description: str
    subscribers: int
    views: int
    videos: int
    last_video_published_at: str


def build_videos_dataframe(videos: List[Video]) -> pd.DataFrame:
    """Convert a list of :class:`Video` into a pandas DataFrame."""

    records = []
    for video in videos:
        statistics = video.statistics
        record = {
            "video_id": video.video_id,
            "title": video.title,
            "published_at": date_parser.isoparse(video.published_at) if video.published_at else None,
            "views": statistics.get("viewCount", 0),
            "likes": statistics.get("likeCount", 0),
            "comments": statistics.get("commentCount", 0),
            "favorites": statistics.get("favoriteCount", 0),
            "duration": video.duration,
            "tags": ",".join(video.tags),
        }
        records.append(record)
    if not records:
        return pd.DataFrame(
            columns=[
                "video_id",
                "title",
                "published_at",
                "views",
                "likes",
                "comments",
                "favorites",
                "duration",
                "tags",
            ]
        )
    df = pd.DataFrame.from_records(records)
    df.sort_values("published_at", ascending=False, inplace=True)
    return df


def build_channel_summary(channel_payload: Dict, videos_df: pd.DataFrame) -> ChannelSummary:
    """Construct channel level metrics."""

    snippet = channel_payload.get("snippet", {})
    statistics = channel_payload.get("statistics", {})
    last_video = videos_df["published_at"].max() if not videos_df.empty else None
    return ChannelSummary(
        title=snippet.get("title", ""),
        description=snippet.get("description", ""),
        subscribers=int(statistics.get("subscriberCount", 0)),
        views=int(statistics.get("viewCount", 0)),
        videos=int(statistics.get("videoCount", 0)),
        last_video_published_at=last_video.isoformat() if last_video is not None else "",
    )


def compute_video_insights(videos_df: pd.DataFrame, top_n: int = 5) -> Dict[str, List[Tuple[str, int]]]:
    """Return top lists for the dataset."""

    if videos_df.empty:
        return {"top_views": [], "top_likes": [], "top_comments": []}
    insights: Dict[str, List[Tuple[str, int]]] = {}
    for metric in ["views", "likes", "comments"]:
        ranked = (
            videos_df[["title", metric]]
            .sort_values(metric, ascending=False)
            .head(top_n)
            .reset_index(drop=True)
        )
        insights[f"top_{metric}"] = list(zip(ranked["title"], ranked[metric].astype(int)))
    return insights


__all__ = [
    "build_videos_dataframe",
    "build_channel_summary",
    "compute_video_insights",
    "ChannelSummary",
]
