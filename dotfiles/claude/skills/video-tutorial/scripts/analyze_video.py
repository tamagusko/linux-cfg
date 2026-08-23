#!/usr/bin/env python3
"""Extract a structured, replicable tutorial from a video using Gemini.

Claude cannot watch video. Gemini can, including the *visual* track, which is
where a tutorial actually keeps its information: the code on screen, the menu
being clicked, the version in the title bar. This script is the eyes; Claude
does the reasoning afterwards.

Usage:
    analyze_video.py <youtube-url|path/to/video.mp4> [--model M] [--focus TEXT]
"""

from __future__ import annotations

import argparse
import json
import logging
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

API_ROOT = "https://generativelanguage.googleapis.com/v1beta"

# Long-context (1M) so a 40-minute screencast is not truncated in the middle.
# Deliberately a pinned id rather than an alias such as `gemini-flash-latest`:
# this script transcribes code off a screen, and a silently swapped model would
# change that accuracy with no signal. Note that `gemini-2.5-pro` is returned by
# the models endpoint but 404s for new users — appearing in the listing is not
# proof a model is callable, so verify before changing this.
DEFAULT_MODEL = "gemini-3.5-flash"

# Files uploaded to the Files API are processed asynchronously. A long video can
# sit in PROCESSING for a while, so poll rather than assume.
UPLOAD_POLL_SECONDS = 3
UPLOAD_TIMEOUT_SECONDS = 900

EXTRACTION_PROMPT = """\
You are transcribing a technical tutorial so that an engineer who has NOT seen
it can reproduce the result exactly. Watch the VISUAL track carefully — most of
the real information in a tutorial is on the screen, not in the narration.

Produce Markdown with these sections, and nothing else:

## What this builds
One paragraph: the end result, and who it is for.

## Environment
Every tool, language, library, and VERSION visible anywhere on screen — title
bars, terminal output, package files, browser tabs. Mark anything you inferred
rather than saw as (inferred). If a version is never shown, say so explicitly
rather than guessing.

## Steps
Numbered. Each step:
- `[mm:ss]` timestamp where it begins
- What is done, in the imperative
- **Exact** code, commands, or config shown on screen, in a fenced code block
  with a language tag. Transcribe character by character from the screen. If
  the screen is blurry or truncated, write `# ILLEGIBLE: <what you can tell>`
  rather than inventing plausible code.
- UI actions as: menu path, button label, or keyboard shortcut

## Gotchas
Anything the presenter warns about, works around, or hits as an error — plus
mistakes they make silently and correct later.

## Final state
What the working result looks like, and how the presenter verifies it.

## Weaknesses
Where this tutorial is outdated, insecure, fragile, or simply bad practice.
Be specific and technical. This section is critical: it is the input to
improving on the tutorial rather than blindly copying it.
"""


def _post(url: str, payload: dict[str, Any], api_key: str) -> dict[str, Any]:
    """POST JSON to the Gemini API and return the decoded response."""
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": api_key},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=900) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")[:500]
        raise RuntimeError(f"Gemini API {exc.code}: {detail}") from exc


def upload_file(path: Path, api_key: str) -> str:
    """Upload a local video via the Files API and return its file_uri."""
    mime = mimetypes.guess_type(path.name)[0] or "video/mp4"
    size = path.stat().st_size
    logger.info("uploading %s (%.1f MB)", path.name, size / 1e6)

    start = urllib.request.Request(
        f"{API_ROOT}/files",
        data=json.dumps({"file": {"display_name": path.name}}).encode(),
        headers={
            "x-goog-api-key": api_key,
            "X-Goog-Upload-Protocol": "resumable",
            "X-Goog-Upload-Command": "start",
            "X-Goog-Upload-Header-Content-Length": str(size),
            "X-Goog-Upload-Header-Content-Type": mime,
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(start, timeout=120) as resp:
        upload_url = resp.headers.get("X-Goog-Upload-URL")
    if not upload_url:
        raise RuntimeError("Files API did not return an upload URL")

    finish = urllib.request.Request(
        upload_url,
        data=path.read_bytes(),
        headers={
            "Content-Length": str(size),
            "X-Goog-Upload-Offset": "0",
            "X-Goog-Upload-Command": "upload, finalize",
        },
        method="POST",
    )
    with urllib.request.urlopen(finish, timeout=UPLOAD_TIMEOUT_SECONDS) as resp:
        info = json.loads(resp.read())["file"]

    # A video is not queryable the moment the bytes land.
    deadline = time.monotonic() + UPLOAD_TIMEOUT_SECONDS
    while info.get("state") == "PROCESSING":
        if time.monotonic() > deadline:
            raise RuntimeError(f"{path.name} still PROCESSING after timeout")
        time.sleep(UPLOAD_POLL_SECONDS)
        poll = urllib.request.Request(
            f"{API_ROOT}/files/{info['name'].split('/')[-1]}",
            headers={"x-goog-api-key": api_key},
        )
        with urllib.request.urlopen(poll, timeout=60) as resp:
            info = json.loads(resp.read())

    if info.get("state") != "ACTIVE":
        raise RuntimeError(f"upload ended in state {info.get('state')}")
    logger.info("upload active")
    return info["uri"]


def _report_usage(usage: dict[str, Any]) -> None:
    """Log what the call cost, and whether it was billed.

    A whole video goes up in ONE request, so the limit that bites first is
    tokens-per-minute rather than requests-per-day: roughly 89 tokens per second
    of video, so a 40-minute screencast is a single ~212k-token call.

    `serviceTier` is the only in-band signal of which tier answered. Anything
    other than the free tier means the project behind GEMINI_API_KEY has a
    billing account attached, and there is no request-level flag to opt out of
    that — free-only means using a key whose project has no billing, where
    exceeding quota returns 429 instead of a charge.
    """
    if not usage:
        return
    total = usage.get("totalTokenCount", 0)
    by_mode = {
        d.get("modality", "?"): d.get("tokenCount", 0)
        for d in usage.get("promptTokensDetails") or []
    }
    detail = ", ".join(f"{k.lower()}={v:,}" for k, v in sorted(by_mode.items()))
    logger.info("tokens: %s total%s", f"{total:,}", f" ({detail})" if detail else "")

    tier = usage.get("serviceTier")
    if tier and "free" not in tier.lower():
        logger.warning(
            "serviceTier=%s — this call was BILLED, not free tier. Free-only "
            "requires an API key whose Google Cloud project has no billing "
            "account attached.",
            tier,
        )


def analyse(source: str, model: str, focus: str | None, api_key: str) -> str:
    """Return the extracted tutorial as Markdown."""
    prompt = EXTRACTION_PROMPT
    if focus:
        prompt += f"\n\nPay particular attention to: {focus}\n"

    if source.startswith(("http://", "https://")):
        file_uri = source
    else:
        path = Path(source).expanduser()
        if not path.is_file():
            raise FileNotFoundError(f"no such video: {path}")
        file_uri = upload_file(path, api_key)

    logger.info("analysing with %s", model)
    data = _post(
        f"{API_ROOT}/models/{model}:generateContent",
        {
            "contents": [
                {"parts": [{"text": prompt}, {"file_data": {"file_uri": file_uri}}]}
            ],
            # Near-zero temperature: transcribing code off a screen is a recall
            # task, and creativity here shows up as invented APIs.
            "generationConfig": {"temperature": 0.1},
        },
        api_key,
    )

    _report_usage(data.get("usageMetadata") or {})

    candidates = data.get("candidates") or []
    if not candidates:
        raise RuntimeError(f"no candidates returned: {json.dumps(data)[:400]}")
    parts = candidates[0].get("content", {}).get("parts") or []
    text = "".join(p.get("text", "") for p in parts).strip()
    if not text:
        reason = candidates[0].get("finishReason", "unknown")
        raise RuntimeError(f"empty response (finishReason={reason})")
    return text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", help="YouTube URL or local video file")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--focus", help="steer extraction, e.g. 'the webpack config'")
    parser.add_argument("--output", type=Path, help="also write Markdown here")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO, format="[%(levelname)s] %(message)s", stream=sys.stderr
    )

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        logger.error("GEMINI_API_KEY is not set (see ~/.config/linux-cfg/secrets.env)")
        return 1

    try:
        markdown = analyse(args.source, args.model, args.focus, api_key)
    except (RuntimeError, FileNotFoundError, urllib.error.URLError) as exc:
        logger.error("%s", exc)
        return 1

    if args.output:
        args.output.write_text(markdown)
        logger.info("wrote %s", args.output)
    print(markdown)
    return 0


if __name__ == "__main__":
    sys.exit(main())
