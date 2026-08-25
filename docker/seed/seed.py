#!/usr/bin/env python3
"""Seed the local paperless-ngx dev instance with a realistic fixture.

See docs/superpowers/specs/2026-08-09-docker-seed-data-design.md for the design.
"""

import argparse
import base64
import hashlib
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_URL = "http://localhost:8000"
USERNAME = "admin"
PASSWORD = "T0PS3CR3T!!123"

SEED_DIR = Path(__file__).resolve().parent
CONFIG_PATH = SEED_DIR / "seed.json"
CONSUME_DIR = SEED_DIR.parent / "consume" / "dev"

ENTITY_PATHS = {
    "correspondents": "/api/correspondents/",
    "document_types": "/api/document_types/",
    "tags": "/api/tags/",
    "storage_paths": "/api/storage_paths/",
}


class SeedError(Exception):
    """Raised when the seed cannot complete."""


class Api:
    """Minimal paperless-ngx REST client using HTTP Basic auth."""

    def __init__(self, base_url):
        self.base_url = base_url.rstrip("/")
        credentials = base64.b64encode(f"{USERNAME}:{PASSWORD}".encode()).decode()
        self.authorization = f"Basic {credentials}"

    def request(self, method, path, body=None):
        url = path if path.startswith("http") else self.base_url + path
        data = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(url, data=data, method=method)
        request.add_header("Accept", "application/json")
        request.add_header("Authorization", self.authorization)
        if data is not None:
            request.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                payload = response.read()
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            raise SeedError(f"{method} {url} failed with HTTP {error.code}: {detail}") from None
        except urllib.error.URLError as error:
            raise SeedError(f"{method} {url} failed: {error.reason}. Is `mise docker:start` running?") from None
        return json.loads(payload) if payload else None

    def list_all(self, path):
        results = []
        url = f"{self.base_url}{path}?page_size=200"
        while url:
            page = self.request("GET", url)
            results.extend(page["results"])
            url = page.get("next")
        return results


def load_config():
    with CONFIG_PATH.open(encoding="utf-8") as handle:
        return json.load(handle)


def build_pdf(title, body):
    """Build a minimal one-page PDF containing the given ASCII title and body."""

    def escape(text):
        return text.replace("\\", r"\\").replace("(", r"\(").replace(")", r"\)")

    content = (
        f"BT /F1 24 Tf 72 760 Td ({escape(title)}) Tj ET\n"
        f"BT /F1 12 Tf 72 720 Td ({escape(body)}) Tj ET\n"
    ).encode("ascii")

    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] "
        b"/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>",
        b"<< /Length " + str(len(content)).encode() + b" >>\nstream\n" + content + b"endstream",
    ]

    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for number, obj in enumerate(objects, start=1):
        offsets.append(len(out))
        out += f"{number} 0 obj\n".encode("ascii") + obj + b"\nendobj\n"

    xref_offset = len(out)
    out += f"xref\n0 {len(objects) + 1}\n".encode("ascii")
    out += b"0000000000 65535 f \n"
    for offset in offsets:
        out += f"{offset:010d} 00000 n \n".encode("ascii")
    out += (
        f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\n"
        f"startxref\n{xref_offset}\n%%EOF\n"
    ).encode("ascii")
    return bytes(out)


def generate_fillers(api, config):
    """Write filler PDFs for any titles paperless does not have yet.

    Returns the number of files written. Bytes are deterministic, so a title
    that already exists is skipped and never consumed a second time.
    """
    existing = {document["title"] for document in api.list_all("/api/documents/")}
    CONSUME_DIR.mkdir(parents=True, exist_ok=True)
    written = 0
    for title in config["filler_titles"]:
        if title in existing:
            continue
        token = hashlib.sha1(title.encode("utf-8")).hexdigest()[:12]
        body = f"Less Paper dev fixture - {title} - {token}"
        destination = CONSUME_DIR / f"{title}.pdf"
        destination.write_bytes(build_pdf(title, body))
        written += 1
        print(f"  generated filler: {title}")
    return written


def wait_for_documents(api, config, timeout=600):
    """Block until every configured title has been consumed.

    Returns {title: document_id}. Raises SeedError naming the stragglers if the
    timeout elapses first.
    """
    wanted = {document["title"] for document in config["documents"]}
    deadline = time.monotonic() + timeout
    while True:
        found = {
            document["title"]: document["id"]
            for document in api.list_all("/api/documents/")
            if document["title"] in wanted
        }
        missing = wanted - found.keys()
        if not missing:
            return found
        if time.monotonic() >= deadline:
            raise SeedError(
                f"timed out after {timeout}s waiting for consumption; "
                f"still missing: {sorted(missing)}"
            )
        print(f"  waiting for {len(missing)} document(s) to be consumed…")
        time.sleep(5)


def ensure_entities(api, config):
    """Create the correspondents, document types, tags and storage paths.

    Returns {kind: {name: id}} for every entity in the config, whether it was
    created now or already existed.
    """
    ids = {}
    for kind, path in ENTITY_PATHS.items():
        existing = {item["name"]: item["id"] for item in api.list_all(path)}
        ids[kind] = {}
        for entry in config[kind]:
            payload = {"name": entry} if isinstance(entry, str) else dict(entry)
            name = payload["name"]
            if name in existing:
                ids[kind][name] = existing[name]
                continue
            created = api.request("POST", path, payload)
            ids[kind][name] = created["id"]
            print(f"  created {kind[:-1]}: {name}")
    return ids


def patch_documents(api, config, entity_ids, document_ids):
    """Apply the configured metadata to every document, keyed by title."""
    for expected in config["documents"]:
        title = expected["title"]
        payload = {
            "archive_serial_number": expected["archive_serial_number"],
            "correspondent": entity_ids["correspondents"].get(expected["correspondent"]),
            "created": expected["created"],
            "document_type": entity_ids["document_types"].get(expected["document_type"]),
            "storage_path": entity_ids["storage_paths"].get(expected["storage_path"]),
            "tags": [entity_ids["tags"][tag] for tag in expected["tags"]],
        }
        api.request("PATCH", f"/api/documents/{document_ids[title]}/", payload)
        print(f"  patched: {title}")


RULE_REFERENCES = {
    "correspondent": "correspondents",
    "document_type": "document_types",
    "storage_path": "storage_paths",
    "tag": "tags",
}


def ensure_saved_views(api, config, entity_ids):
    """Create the saved views, resolving entity names in their filter rules."""
    existing = {view["name"] for view in api.list_all("/api/saved_views/")}
    for view in config["saved_views"]:
        if view["name"] in existing:
            continue
        rules = []
        for rule in view["filter_rules"]:
            value = rule.get("value")
            for key, kind in RULE_REFERENCES.items():
                if key in rule:
                    value = str(entity_ids[kind][rule[key]])
            rules.append({"rule_type": rule["rule_type"], "value": value})
        api.request("POST", "/api/saved_views/", {
            "name": view["name"],
            "sort_field": view["sort_field"],
            "sort_reverse": view["sort_reverse"],
            "filter_rules": rules,
        })
        print(f"  created saved view: {view['name']}")


def saved_view_visibility(api):
    """Read the dashboard/sidebar visible saved-view ids from the UI settings."""
    settings = api.request("GET", "/api/ui_settings/")["settings"]
    saved_views = settings.get("saved_views") or {}
    return (
        set(saved_views.get("dashboard_views_visible_ids") or []),
        set(saved_views.get("sidebar_views_visible_ids") or []),
    )


def set_saved_view_visibility(api, config):
    """Publish saved views to the dashboard and sidebar.

    Paperless 3.0 dropped `show_on_dashboard` / `show_in_sidebar` from the
    saved-view resource; visibility now lives in `/api/ui_settings/` under
    `saved_views`, which is what SetSavedViewVisibilityUseCase drives.
    """
    ids = {view["name"]: view["id"] for view in api.list_all("/api/saved_views/")}
    dashboard = sorted(ids[view["name"]] for view in config["saved_views"] if view["show_on_dashboard"])
    sidebar = sorted(ids[view["name"]] for view in config["saved_views"] if view["show_in_sidebar"])

    if (set(dashboard), set(sidebar)) == saved_view_visibility(api):
        return

    settings = api.request("GET", "/api/ui_settings/")["settings"]
    settings["saved_views"] = {
        "dashboard_views_visible_ids": dashboard,
        "sidebar_views_visible_ids": sidebar,
    }
    api.request("POST", "/api/ui_settings/", {"settings": settings})
    print(f"  set saved view visibility: dashboard={dashboard} sidebar={sidebar}")


def verify(api, config):
    """Check the instance matches the fixture. Returns a list of problems."""
    problems = []

    titles = {document["title"] for document in config["documents"]}
    actual = {document["title"]: document for document in api.list_all("/api/documents/")}
    missing_documents = sorted(titles - actual.keys())
    if missing_documents:
        problems.append(f"documents: missing {missing_documents}")

    names = {
        kind: {item["id"]: item["name"] for item in api.list_all(path)}
        for kind, path in ENTITY_PATHS.items()
    }
    for expected in config["documents"]:
        document = actual.get(expected["title"])
        if document is None:
            continue
        checks = [
            ("correspondent", names["correspondents"].get(document["correspondent"]), expected["correspondent"]),
            ("document_type", names["document_types"].get(document["document_type"]), expected["document_type"]),
            ("storage_path", names["storage_paths"].get(document["storage_path"]), expected["storage_path"]),
            ("created", document["created"], expected["created"]),
            ("archive_serial_number", document["archive_serial_number"], expected["archive_serial_number"]),
            ("tags", sorted(names["tags"].get(tag) for tag in document["tags"]), sorted(expected["tags"])),
        ]
        for field, got, want in checks:
            if got != want:
                problems.append(f"{expected['title']}: {field} is {got!r}, expected {want!r}")

    for kind, path in ENTITY_PATHS.items():
        items = {item["name"]: item for item in api.list_all(path)}
        for entry in config[kind]:
            expected = {"name": entry} if isinstance(entry, str) else entry
            item = items.get(expected["name"])
            if item is None:
                problems.append(f"{kind}: missing {expected['name']!r}")
                continue
            for field, want in expected.items():
                if field != "name" and item.get(field) != want:
                    problems.append(
                        f"{kind[:-1]} {expected['name']!r}: {field} is {item.get(field)!r}, expected {want!r}"
                    )

    views = {view["name"]: view for view in api.list_all("/api/saved_views/")}
    missing_views = sorted({view["name"] for view in config["saved_views"]} - views.keys())
    if missing_views:
        problems.append(f"saved_views: missing {missing_views}")
    else:
        dashboard, sidebar = saved_view_visibility(api)
        for view in config["saved_views"]:
            identifier = views[view["name"]]["id"]
            checks = [
                ("show_on_dashboard", identifier in dashboard, view["show_on_dashboard"]),
                ("show_in_sidebar", identifier in sidebar, view["show_in_sidebar"]),
                ("sort_field", views[view["name"]]["sort_field"], view["sort_field"]),
                ("sort_reverse", views[view["name"]]["sort_reverse"], view["sort_reverse"]),
            ]
            for field, got, want in checks:
                if got != want:
                    problems.append(f"saved view {view['name']!r}: {field} is {got!r}, expected {want!r}")

    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default=DEFAULT_URL, help=f"paperless base URL (default: {DEFAULT_URL})")
    parser.add_argument("--verify", action="store_true", help="check the fixture without changing anything")
    args = parser.parse_args()

    api = Api(args.url)
    config = load_config()

    try:
        if not args.verify:
            print(f"Seeding {args.url}")
            generate_fillers(api, config)
            document_ids = wait_for_documents(api, config)
            entity_ids = ensure_entities(api, config)
            patch_documents(api, config, entity_ids, document_ids)
            ensure_saved_views(api, config, entity_ids)
            set_saved_view_visibility(api, config)

        problems = verify(api, config)
    except SeedError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    if problems:
        print("fixture does not match seed.json:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1

    print("Fixture OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
