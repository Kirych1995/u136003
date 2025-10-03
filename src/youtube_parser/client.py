"""Thin wrapper around the YouTube Data API."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Iterable, List, Optional

import requests

API_URL = "https://www.googleapis.com/youtube/v3"


class YouTubeAPIError(RuntimeError):
    """Raised when the YouTube API returns an error."""


@dataclass(slots=True)
class Video:
    """Container for video metadata and statistics."""

    video_id: str
    title: str
    published_at: str
    description: str
    duration: Optional[str]
    tags: List[str]
    statistics: Dict[str, int]
    thumbnails: Dict[str, Dict[str, str]]


class YouTubeAPIClient:
    """Simple client for the YouTube Data API v3."""

    def __init__(self, api_key: str) -> None:
        self.api_key = api_key

    def _request(self, path: str, params: Dict[str, str]) -> Dict:
        params_with_key = {"key": self.api_key, **params}
        response = requests.get(f"{API_URL}/{path}", params=params_with_key, timeout=30)
        if response.status_code != 200:
            raise YouTubeAPIError(f"YouTube API error: {response.status_code} - {response.text}")
        payload = response.json()
        if "error" in payload:
            raise YouTubeAPIError(str(payload["error"]))
        return payload

    def get_channel_overview(self, channel_id: str) -> Dict:
        """Retrieve statistics and basic info for the channel."""

        payload = self._request(
            "channels",
            {
                "part": "snippet,statistics,contentDetails",
                "id": channel_id,
            },
        )
        items = payload.get("items", [])
        if not items:
            raise YouTubeAPIError(f"Channel {channel_id} not found")
        return items[0]

    def get_upload_playlist_id(self, channel_id: str) -> str:
        overview = self.get_channel_overview(channel_id)
        uploads = overview.get("contentDetails", {}).get("relatedPlaylists", {}).get("uploads")
        if not uploads:
            raise YouTubeAPIError("Channel does not expose uploads playlist")
        return uploads

    def list_videos(self, playlist_id: str, limit: int) -> List[str]:
        """Return a list of video IDs from the uploads playlist."""

        collected: List[str] = []
        page_token: Optional[str] = None
        while len(collected) < limit:
            params = {
                "part": "contentDetails",
                "playlistId": playlist_id,
                "maxResults": "50",
            }
            if page_token:
                params["pageToken"] = page_token
            payload = self._request("playlistItems", params)
            for item in payload.get("items", []):
                video_id = item.get("contentDetails", {}).get("videoId")
                if video_id:
                    collected.append(video_id)
                if len(collected) >= limit:
                    break
            page_token = payload.get("nextPageToken")
            if not page_token:
                break
        return collected

    def get_videos(self, video_ids: Iterable[str]) -> List[Video]:
        ids = list(video_ids)
        if not ids:
            return []
        chunk_size = 50
        videos: List[Video] = []
        for start in range(0, len(ids), chunk_size):
            chunk = ids[start : start + chunk_size]
            payload = self._request(
                "videos",
                {
                    "part": "snippet,contentDetails,statistics",
                    "id": ",".join(chunk),
                    "maxResults": str(len(chunk)),
                },
            )
            for item in payload.get("items", []):
                snippet = item.get("snippet", {})
                content_details = item.get("contentDetails", {})
                stats = item.get("statistics", {})
                statistics = {k: int(v) for k, v in stats.items() if v is not None}
                videos.append(
                    Video(
                        video_id=item.get("id", ""),
                        title=snippet.get("title", ""),
                        description=snippet.get("description", ""),
                        published_at=snippet.get("publishedAt", ""),
                        duration=content_details.get("duration"),
                        tags=snippet.get("tags", []) or [],
                        statistics=statistics,
                        thumbnails=snippet.get("thumbnails", {}),
                    )
                )
        return videos


__all__ = ["YouTubeAPIClient", "YouTubeAPIError", "Video"]
