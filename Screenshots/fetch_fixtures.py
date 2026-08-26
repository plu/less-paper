#!/usr/bin/env python3
"""Download screenshot fixtures from a seeded paperless-ngx instance.

Screenshots must never talk to a server, so the app reads these files instead. They are the raw
API payloads rather than hand-written Swift, which keeps them in the exact shape the decoder
already expects and makes refreshing them a re-run rather than an edit.

    python3 Screenshots/fetch_fixtures.py --url http://192.168.64.1:8000
"""

import argparse
import base64
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

USERNAME = "admin"
PASSWORD = "T0PS3CR3T!!123"

ROOT = Path(__file__).resolve().parent
FIXTURES = ROOT / "Fixtures"
THUMBNAILS = ROOT / "Thumbnails"

# Endpoints whose full payload the app caches at launch through UpdateCacheUseCase.
COLLECTIONS = {
    "correspondents": "/api/correspondents/",
    "custom_fields": "/api/custom_fields/",
    "document_types": "/api/document_types/",
    "documents": "/api/documents/",
    "saved_views": "/api/saved_views/",
    "storage_paths": "/api/storage_paths/",
    "tags": "/api/tags/",
}


def request(url):
    credentials = base64.b64encode(f"{USERNAME}:{PASSWORD}".encode()).decode()
    req = urllib.request.Request(url)
    req.add_header("Authorization", f"Basic {credentials}")
    req.add_header("Accept", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return response.read()
    except urllib.error.URLError as error:
        raise SystemExit(f"error: GET {url} failed: {error}") from None


def fetch_collection(base_url, path):
    """Follow pagination and return every result as one list."""
    results = []
    url = f"{base_url}{path}?page_size=200"
    while url:
        page = json.loads(request(url))
        results.extend(page["results"])
        url = page.get("next")
    return results


def fetch_thumbnail(base_url, document_id):
    return request(f"{base_url}/api/documents/{document_id}/thumb/")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://localhost:8000")
    args = parser.parse_args()
    base_url = args.url.rstrip("/")

    FIXTURES.mkdir(parents=True, exist_ok=True)
    THUMBNAILS.mkdir(parents=True, exist_ok=True)

    documents = []
    for name, path in sorted(COLLECTIONS.items()):
        results = fetch_collection(base_url, path)
        if name == "documents":
            documents = results
        destination = FIXTURES / f"{name}.json"
        destination.write_text(json.dumps(results, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
        print(f"  {name}: {len(results)}")

    # Served as WebP at roughly 500x700 and a few kilobytes each. Kept exactly as served: it is what
    # the app would have received, and ImageIO decodes it without help.
    for document in documents:
        data = fetch_thumbnail(base_url, document["id"])
        (THUMBNAILS / f"{document['id']}.webp").write_bytes(data)
    print(f"  thumbnails: {len(documents)}")


if __name__ == "__main__":
    sys.exit(main())
