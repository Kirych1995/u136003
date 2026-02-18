# CLAUDE.md

## Project Overview

YouTube Channel Analytics Pipeline — a Python CLI tool that collects statistics from a YouTube channel via the YouTube Data API v3 and generates analytical reports. Results can be exported to CSV, JSON, or Google Sheets for use with BI tools like Google Looker Studio.

## Quick Reference

```bash
# Install (editable mode)
pip install -e .

# Run the pipeline (CSV export)
youtube-parser --channel-id UCdwN2l9VmZpK5x6tEN84ImA --export csv --output-path analytics.csv

# Run as module
python -m youtube_parser.cli --channel-id UCdwN2l9VmZpK5x6tEN84ImA --export csv

# Google Sheets export
youtube-parser --channel-id UCdwN2l9VmZpK5x6tEN84ImA \
  --export google-sheets \
  --service-account-key path/to/key.json \
  --spreadsheet-id SPREADSHEET_ID
```

**Required environment variable:** `YOUTUBE_API_KEY` (or pass `--api-key` on the CLI).

## Project Structure

```
src/youtube_parser/
├── __init__.py        # Package root; exports run_pipeline
├── cli.py             # argparse-based CLI entry point
├── config.py          # PipelineConfig and GoogleSheetsConfig dataclasses
├── client.py          # YouTubeAPIClient — HTTP wrapper for YouTube Data API v3
├── analytics.py       # DataFrame construction and metric computation
├── exporters.py       # Exporter base class + CSV, JSON, Google Sheets implementations
└── pipeline.py        # run_pipeline() orchestrator
```

## Architecture

The codebase follows a linear pipeline pattern:

```
CLI (cli.py)
 └─> PipelineConfig (config.py)
      └─> run_pipeline (pipeline.py)
           ├─> YouTubeAPIClient (client.py)   — fetch channel + video data
           ├─> analytics (analytics.py)        — build DataFrames and insights
           └─> Exporter (exporters.py)         — write output (CSV/JSON/Sheets)
```

Key design patterns:
- **Dataclasses with `slots=True`** for all data containers (`PipelineConfig`, `GoogleSheetsConfig`, `Video`, `ChannelSummary`, `ExportPayload`)
- **Strategy pattern** for exporters: base `Exporter` class with `CSVExporter`, `JSONExporter`, `GoogleSheetsExporter`
- **Explicit `__all__`** in every module to control public API surface

## Code Conventions

- **Python 3.10+** required
- **`from __future__ import annotations`** in all modules (deferred annotation evaluation)
- **Type hints** on all function signatures and class attributes
- **Docstrings** on modules, classes, and public functions (NumPy-style parameter docs in `config.py`)
- **No linter or formatter configured** — when adding code, follow the existing style: 4-space indentation, double quotes for strings, type-annotated signatures
- **Module-level `__all__`** exports in every file — update when adding public symbols

## Dependencies

| Package | Purpose |
|---------|---------|
| `requests>=2.31` | HTTP calls to YouTube Data API v3 |
| `pandas>=2.0` | DataFrame construction and data manipulation |
| `python-dateutil>=2.8` | ISO 8601 date parsing |
| `gspread>=5.11` | Google Sheets API client |
| `google-auth>=2.23` | Google service account authentication |

Build system: **setuptools** via `pyproject.toml` (src-layout).

## Testing

No test suite exists yet. There are no test directories, no pytest configuration, and no testing dependencies declared. When adding tests:
- Place them under a `tests/` directory at the project root
- Use `pytest` as the test runner
- Mock external API calls (YouTube, Google Sheets) rather than hitting live services

## CI/CD

No CI/CD pipelines are configured. No GitHub Actions, GitLab CI, or similar workflows exist.

## Common Pitfalls

- The YouTube Data API has quota limits (default 10,000 units/day). Large `--max-videos` values with many API calls can exhaust quota quickly.
- Google Sheets export requires both `--service-account-key` and `--spreadsheet-id`; the target spreadsheet must be shared with the service account email.
- The `PipelineConfig.channel_id` defaults to `UCdwN2l9VmZpK5x6tEN84ImA` — always pass `--channel-id` explicitly when targeting a different channel.
- Video statistics keys from the API (`viewCount`, `likeCount`, etc.) are mapped to lowercase DataFrame columns (`views`, `likes`, `comments`, `favorites`) in `analytics.py`.
