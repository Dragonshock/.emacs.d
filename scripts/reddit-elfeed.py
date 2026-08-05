#!/usr/bin/env python3

"""Refresh the private r/emacs Atom feed used by Elfeed.

Requires REDDIT_PRIVATE_RSS_TOKEN (set by Emacs from auth-source).
Optional REDDIT_PRIVATE_RSS_USER (defaults to Complex_Outcome697).

If the token is missing, exit 0 after a skip message so Hacker News
updates are not reported as a total local-feed failure.
"""

from __future__ import annotations

import os
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path


USER_AGENT = "elfeed-emacs-rss/1.0 (personal Elfeed reader)"
DEFAULT_USERNAME = "Complex_Outcome697"
OUTPUT = Path(__file__).resolve().parent.parent / "var" / "rss" / "reddit-emacs.atom"


def private_feed_url(token: str, username: str) -> str:
    query = urllib.parse.urlencode({"feed": token, "user": username})
    return f"https://www.reddit.com/r/emacs/new/.rss?{query}"


def fetch_feed(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=25) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            if error.code not in {429, 500, 502, 503, 504} or attempt == 2:
                raise
        except urllib.error.URLError:
            if attempt == 2:
                raise
        time.sleep(2**attempt)
    raise RuntimeError("Reddit request failed")


def validate_feed(body: bytes) -> None:
    root = ET.fromstring(body)
    if root.tag != "{http://www.w3.org/2005/Atom}feed":
        raise RuntimeError("Reddit response is not an Atom feed")
    if root.find("{http://www.w3.org/2005/Atom}entry") is None:
        raise RuntimeError("Reddit Atom feed contains no entries")


def write_feed(body: bytes) -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        "wb", dir=OUTPUT.parent, prefix=".reddit-emacs-", delete=False
    ) as output:
        temporary = output.name
        output.write(body)
    os.replace(temporary, OUTPUT)


def main() -> int:
    token = os.environ.get("REDDIT_PRIVATE_RSS_TOKEN")
    if not token:
        print(
            "skipping private Reddit feed: REDDIT_PRIVATE_RSS_TOKEN is missing",
            file=sys.stderr,
        )
        return 0

    username = os.environ.get("REDDIT_PRIVATE_RSS_USER") or DEFAULT_USERNAME
    body = fetch_feed(private_feed_url(token, username))
    validate_feed(body)
    write_feed(body)
    print(f"updated {OUTPUT}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:  # noqa: BLE001 — surface as non-zero for the shell wrapper
        print(f"reddit-elfeed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
