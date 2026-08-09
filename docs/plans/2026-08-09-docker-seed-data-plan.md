# Docker Seed Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the local paperless-dev container a realistic fixture — 25 documents carrying correspondents, document types, tags, storage paths, varied created dates, ASNs and saved views — plus a configurable page size so pagination is reachable without a 100-document corpus.

**Architecture:** A declarative `docker/seed/seed.json` describes every entity and per-document assignment; `docker/seed/seed.py` (Python 3 stdlib only) drives paperless-ngx's REST API to realise it, idempotently. A new `mise docker:seed` task runs it, and `mise docker:start` calls that task for the dev instance only. Separately, `PAPERLESS_PAGE_SIZE` becomes a Tuist/Info.plist knob read by `DocumentsRepository`, mirroring how `PAPERLESS_TEST_URL` already works.

**Tech Stack:** Python 3 (system, stdlib only — no pip installs, no `Brewfile`/`mise.toml [tools]` additions), bash mise tasks, Docker Compose, paperless-ngx 3.0.5, Swift, Swift Testing, Tuist.

**Full design context:** See `docs/plans/2026-08-09-docker-seed-data.md`. This plan implements that design directly.

## Global Constraints

- **Dev instance only.** Seeding targets `http://localhost:8000` (compose project `paperless-dev`). The `paperless-ci` instance on `:9000` must keep exactly 13 documents and zero tags/correspondents/document types/storage paths/saved views — its entity tables are owned and wiped by the test suites (`repository.deleteAll()` in `ApiImplementationTests`, `deleteAllTags()` in `TagsAppTests.setUp`).
- **Credentials:** HTTP Basic `admin` / `T0PS3CR3T!!123`, as set in `docker/docker-compose.yml`.
- **Python 3 stdlib only.** No third-party imports. `urllib.request`, `json`, `base64`, `hashlib`, `argparse`, `pathlib`, `time`, `sys`.
- **Idempotent.** Every entity is looked up by name and only created when absent; document PATCHes are keyed by title; filler PDFs are only written for titles that do not already exist. Re-running `mise docker:seed` leaves ids stable.
- **Filler titles are ASCII-only** — they become filenames, and umlauts risk NFC/NFD mismatch across the Docker bind mount. Entity names travel as JSON and keep their umlauts (`Stadtwerke München`, `Finanzamt München`).
- **Filler PDF bytes are deterministic** — the uniqueness token is `hashlib.sha1(title.encode()).hexdigest()[:12]`, so a regenerated file is byte-identical and never consumed twice.
- **`PAPERLESS_PAGE_SIZE` defaults to `100`** so release behaviour is unchanged, and must **not** be added to `mise.toml`'s `[env]` block — `mise ci:build` runs `tuist` under mise, so a value there would leak into release builds.
- Swift doc comments follow `.claude/CLAUDE.md`: `///` for single-line, `/** */` for multiline with parameters.
- Swift test command: `tuist test <scheme> --no-selective-testing`. **The `--no-selective-testing` flag is required** — plain `tuist test` can silently report "no tests to run, finishing early" due to Tuist's test-impact cache, giving false confidence that a new test ran.
- Shell tasks start with `#!/usr/bin/env bash`, a `#MISE description="…"` line, and `set -euo pipefail`, matching `mise/tasks/docker/start`.

## File Structure

| File | Responsibility |
|---|---|
| `docker/docker-compose.yml` *(modify)* | Per-instance consume mount via `${PAPERLESS_INSTANCE}` |
| `docker/consume/dev/.gitkeep`, `docker/consume/ci/.gitkeep` *(create)* | Keep the two consume directories in git |
| `mise/tasks/docker/start` *(modify)* | Pass `PAPERLESS_INSTANCE`, copy into the right dir, call `docker:seed` |
| `mise/tasks/docker/seed` *(create)* | Thin bash wrapper around `seed.py` |
| `docker/seed/seed.json` *(create)* | All fixture data — entities, documents, saved views |
| `docker/seed/seed.py` *(create)* | API client, PDF generation, consumption wait, entity/document/saved-view seeding, `--verify` |
| `Modules/ApiInterface/Shared/PageSize.swift` *(create)* | Page-size resolution and parsing |
| `Modules/ApiInterfaceTests/Shared/PageSizeTests.swift` *(create)* | Unit tests for the parser |
| `Tuist/ProjectDescriptionHelpers/Module+InfoPlists.swift` *(modify)* | Emit `PAPERLESS_PAGE_SIZE` |
| `Modules/ApiImplementation/Documents/DocumentsRepository.swift` *(modify)* | Use `PageSize.configured` |

---

## Task 1: Per-instance consume directories

The two compose projects currently share `docker/consume`, so generated filler PDFs would be raced over by both instances. Split the mount before anything writes to it.

**Files:**
- Modify: `docker/docker-compose.yml`
- Modify: `mise/tasks/docker/start`
- Create: `docker/consume/dev/.gitkeep`
- Create: `docker/consume/ci/.gitkeep`

**Interfaces:**
- Produces: consume directories `docker/consume/dev` and `docker/consume/ci`; the compose variable `PAPERLESS_INSTANCE`. Task 4 writes filler PDFs into `docker/consume/dev`.

- [ ] **Step 1: Create the two consume directories**

```bash
mkdir -p docker/consume/dev docker/consume/ci
touch docker/consume/dev/.gitkeep docker/consume/ci/.gitkeep
```

The existing `docker/consume/.gitignore` contains `*.pdf`, and gitignore patterns apply recursively, so generated PDFs in the subdirectories stay untracked.

- [ ] **Step 2: Point the compose mount at the per-instance directory**

In `docker/docker-compose.yml`, in the `paperless` service's `volumes:` list, replace:

```yaml
      - ./consume:/usr/src/paperless/consume
```

with:

```yaml
      - ./consume/${PAPERLESS_INSTANCE}:/usr/src/paperless/consume
```

Leave everything else — including the `./healthcheck/paperless:/healthcheck` mount on the next line — untouched.

- [ ] **Step 3: Update `mise/tasks/docker/start`**

Replace the body below the `cd` line so each instance copies into its own directory and gets `PAPERLESS_INSTANCE`:

```bash
#!/usr/bin/env bash
#MISE description="Start paperless-ngx"
set -euo pipefail

cd $MISE_PROJECT_ROOT/docker

cp data/*.pdf consume/dev
PAPERLESS_INSTANCE=dev CADDY_PORT=8010 PAPERLESS_PORT=8000 docker-compose -p paperless-dev up -d --wait

cp data/*.pdf consume/ci
PAPERLESS_INSTANCE=ci CADDY_PORT=9010 PAPERLESS_PORT=9000 docker-compose -p paperless-ci up -d --wait
```

`mise/tasks/docker/stop` is deliberately left alone — it already omits `CADDY_PORT`/`PAPERLESS_PORT`, and compose interpolating `PAPERLESS_INSTANCE` to empty is harmless for `down`.

- [ ] **Step 4: Verify a clean restart gives each instance its own 13 documents**

```bash
mise docker:stop
mise docker:start
sleep 60
for port in 8000 9000; do
  echo -n "$port: "
  curl -s -u 'admin:T0PS3CR3T!!123' "http://localhost:$port/api/documents/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])'
done
```

Expected: `8000: 13` and `9000: 13`. If a count is short, consumption is still running — re-run the loop. Also confirm both consume directories drained: `ls docker/consume/dev docker/consume/ci` shows only `.gitkeep`.

- [ ] **Step 5: Commit**

```bash
git add docker/docker-compose.yml docker/consume/dev/.gitkeep docker/consume/ci/.gitkeep mise/tasks/docker/start
git commit -m "fix: give each paperless instance its own consume directory"
```

---

## Task 2: Configurable page size

**Files:**
- Create: `Modules/ApiInterface/Shared/PageSize.swift`
- Create: `Modules/ApiInterfaceTests/Shared/PageSizeTests.swift`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+InfoPlists.swift`
- Modify: `Modules/ApiImplementation/Documents/DocumentsRepository.swift:222`

**Interfaces:**
- Produces: `public enum PageSize` in `ApiInterface` with `public static let `default`: Int` (= 100), `public static var configured: Int`, and internal `static func value(from string: String?) -> Int`. `DocumentsRepository` consumes `PageSize.configured`.

- [ ] **Step 1: Write the failing test**

Create `Modules/ApiInterfaceTests/Shared/PageSizeTests.swift`:

```swift
@testable import ApiInterface

import Foundation
import Testing

@Suite
struct PageSizeTests {

    @Test
    func valueFromValidString() async throws {
        #expect(PageSize.value(from: "10") == 10)
    }

    @Test
    func valueFromNil() async throws {
        #expect(PageSize.value(from: nil) == PageSize.default)
    }

    @Test
    func valueFromNonNumericString() async throws {
        #expect(PageSize.value(from: "not a number") == PageSize.default)
    }

    @Test
    func valueFromZero() async throws {
        #expect(PageSize.value(from: "0") == PageSize.default)
    }

    @Test
    func valueFromNegativeNumber() async throws {
        #expect(PageSize.value(from: "-5") == PageSize.default)
    }

    @Test
    func defaultIsOneHundred() async throws {
        #expect(PageSize.default == 100)
    }
}
```

Note there is deliberately no test asserting `PageSize.configured == 100` — `configured` reads the framework's Info.plist, so such a test would fail for anyone who generated the project with `TUIST_PAPERLESS_PAGE_SIZE` set.

- [ ] **Step 2: Run the test to verify it fails**

Run: `tuist test ApiInterface --no-selective-testing`
Expected: FAIL — `cannot find 'PageSize' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Modules/ApiInterface/Shared/PageSize.swift`:

```swift
import Foundation

/// The number of documents requested per page when listing documents
public enum PageSize {

    /// The page size used unless `PAPERLESS_PAGE_SIZE` overrides it
    public static let `default` = 100

    /// The configured page size, read from the `PAPERLESS_PAGE_SIZE` Info.plist key
    public static var configured: Int {
        value(from: #bundle.infoDictionary?["PAPERLESS_PAGE_SIZE"] as? String)
    }

    static func value(from string: String?) -> Int {
        guard
            let string,
            let value = Int(string),
            value > 0
        else {
            return `default`
        }
        return value
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `tuist test ApiInterface --no-selective-testing`
Expected: PASS — all six `PageSizeTests` cases green.

- [ ] **Step 5: Emit the Info.plist key**

In `Tuist/ProjectDescriptionHelpers/Module+InfoPlists.swift`, add a `PAPERLESS_PAGE_SIZE` entry immediately after **each** of the three existing `PAPERLESS_TEST_URL` lines (in the `.app` case, the `*App` playground case, and the `default` case). Keys in these dictionaries are alphabetical, and `PAPERLESS_PAGE_SIZE` sorts before `PAPERLESS_TEST_URL`, so insert it on the line *above* each one:

```swift
                "PAPERLESS_PAGE_SIZE": .string(Environment.paperlessPageSize.getString(default: "100")),
                "PAPERLESS_TEST_URL": .string(Environment.paperlessTestUrl.getString(default: "http://localhost:9000")),
```

Do not touch the `.shareExtension` case — it has no `PAPERLESS_TEST_URL`. Do not add anything to `mise.toml`.

- [ ] **Step 6: Use it in the documents request**

In `Modules/ApiImplementation/Documents/DocumentsRepository.swift`, in `extension Request where Response == GetDocumentsOutput`, change:

```swift
                "page_size": "100",
```

to:

```swift
                "page_size": "\(PageSize.configured)",
```

Leave the `page_size: "1000000"` in the `GetAllDocumentIdsOutput` extension exactly as it is — it is a different request and unrelated to list paging.

- [ ] **Step 7: Verify the project still generates and builds**

```bash
tuist generate --no-open
tuist test ApiInterface --no-selective-testing
tuist test ApiImplementation --no-selective-testing
```

Expected: generation succeeds, both suites pass. Then confirm the key landed with the default:

```bash
/usr/libexec/PlistBuddy -c 'Print :PAPERLESS_PAGE_SIZE' Derived/InfoPlists/ApiInterface-Info.plist
```

Expected: `100`. (If the derived path differs, `grep -rl PAPERLESS_PAGE_SIZE Derived/InfoPlists` finds it.)

- [ ] **Step 8: Commit**

```bash
git add Modules/ApiInterface/Shared/PageSize.swift Modules/ApiInterfaceTests/Shared/PageSizeTests.swift Tuist/ProjectDescriptionHelpers/Module+InfoPlists.swift Modules/ApiImplementation/Documents/DocumentsRepository.swift
git commit -m "feat: make the documents page size configurable via PAPERLESS_PAGE_SIZE"
```

---

## Task 3: Seed data file, API client and entity creation

**Files:**
- Create: `docker/seed/seed.json`
- Create: `docker/seed/seed.py`
- Create: `mise/tasks/docker/seed`

**Interfaces:**
- Produces: `seed.py` with `class SeedError(Exception)`, `class Api` (methods `request(method, path, body=None)`, `list_all(path)`), `load_config() -> dict`, `ensure_entities(api, config) -> dict`, and an `argparse` CLI accepting `--url` (default `http://localhost:8000`) and `--verify`. Tasks 4–6 add `generate_fillers`, `wait_for_documents`, `patch_documents` and `ensure_saved_views` to this same file, and extend `verify`.
- `ensure_entities` returns `{"correspondents": {name: id}, "document_types": {name: id}, "tags": {name: id}, "storage_paths": {name: id}}`. Tasks 5 and 6 consume that dictionary.

- [ ] **Step 1: Write the seed data file**

Create `docker/seed/seed.json`. This is the complete fixture — Tasks 4–6 read from it but do not change it.

```json
{
  "correspondents": [
    "Deutsche Telekom",
    "Finanzamt München",
    "IKEA",
    "Internal Revenue Service",
    "LEGO",
    "N26",
    "PUKY",
    "Sonos",
    "Stadtwerke München",
    "tonies"
  ],
  "document_types": [
    "Assembly Instructions",
    "Bank Statement",
    "Invoice",
    "Manual",
    "Tax Form",
    "Tax Return"
  ],
  "tags": [
    { "name": "Audio", "color": "#33a02c", "is_inbox_tag": false },
    { "name": "Furniture", "color": "#b2df8a", "is_inbox_tag": false },
    { "name": "Important", "color": "#cab2d6", "is_inbox_tag": false },
    { "name": "Inbox", "color": "#a6cee3", "is_inbox_tag": true },
    { "name": "Kids", "color": "#fb9a99", "is_inbox_tag": false },
    { "name": "Locked", "color": "#ffff99", "is_inbox_tag": false },
    { "name": "Manual", "color": "#1f78b4", "is_inbox_tag": false },
    { "name": "Needs Review", "color": "#6a3d9a", "is_inbox_tag": false },
    { "name": "Tax", "color": "#fdbf6f", "is_inbox_tag": false },
    { "name": "Toys", "color": "#e31a1c", "is_inbox_tag": false },
    { "name": "Warranty", "color": "#ff7f00", "is_inbox_tag": false }
  ],
  "storage_paths": [
    { "name": "Archive", "path": "Archive/{created_year}/{title}" },
    { "name": "Furniture", "path": "Home/Furniture/{correspondent}/{title}" },
    { "name": "Manuals", "path": "Manuals/{correspondent}/{title}" },
    { "name": "Taxes", "path": "Taxes/{created_year}/{correspondent}/{title}" }
  ],
  "filler_titles": [
    "Stromabrechnung 2024",
    "Stromabrechnung 2025",
    "Gasabrechnung 2025",
    "Wasserabrechnung 2026",
    "Telekom Rechnung 2026-01",
    "Telekom Rechnung 2026-02",
    "Telekom Rechnung 2026-03",
    "Telekom Rechnung 2026-04",
    "Kontoauszug Q1 2026",
    "Kontoauszug Q2 2026",
    "Unsortiertes Dokument #1",
    "Unsortiertes Dokument #2"
  ],
  "documents": [
    { "title": "Sonos One", "correspondent": "Sonos", "document_type": "Manual", "tags": ["Manual", "Audio"], "storage_path": "Manuals", "created": "2019-03-11", "archive_serial_number": 1 },
    { "title": "Sonos Sub", "correspondent": "Sonos", "document_type": "Manual", "tags": ["Manual", "Audio"], "storage_path": "Manuals", "created": "2020-09-27", "archive_serial_number": 2 },
    { "title": "Sonos Era 300", "correspondent": "Sonos", "document_type": "Manual", "tags": ["Manual", "Audio", "Warranty"], "storage_path": "Manuals", "created": "2023-06-18", "archive_serial_number": 3 },
    { "title": "Ikea Danderyd", "correspondent": "IKEA", "document_type": "Assembly Instructions", "tags": ["Furniture"], "storage_path": "Furniture", "created": "2021-08-07", "archive_serial_number": null },
    { "title": "Ikea Vimle #1", "correspondent": "IKEA", "document_type": "Assembly Instructions", "tags": ["Furniture", "Manual", "Warranty", "Important", "Inbox"], "storage_path": "Furniture", "created": "2022-02-19", "archive_serial_number": 4 },
    { "title": "Ikea Vimle #2", "correspondent": "IKEA", "document_type": "Assembly Instructions", "tags": ["Furniture"], "storage_path": "Furniture", "created": "2022-02-19", "archive_serial_number": null },
    { "title": "Puky", "correspondent": "PUKY", "document_type": "Manual", "tags": ["Manual", "Kids"], "storage_path": "Manuals", "created": "2022-04-23", "archive_serial_number": 5 },
    { "title": "Puky-Locked", "correspondent": "PUKY", "document_type": "Manual", "tags": ["Locked", "Needs Review"], "storage_path": "Manuals", "created": "2024-01-15", "archive_serial_number": null },
    { "title": "TonieBox", "correspondent": "tonies", "document_type": "Manual", "tags": ["Manual", "Kids", "Toys"], "storage_path": "Manuals", "created": "2023-12-24", "archive_serial_number": null },
    { "title": "Lego Duplo", "correspondent": "LEGO", "document_type": "Assembly Instructions", "tags": ["Kids", "Toys"], "storage_path": null, "created": "2023-12-24", "archive_serial_number": null },
    { "title": "Lego Friends", "correspondent": "LEGO", "document_type": "Assembly Instructions", "tags": ["Kids", "Toys"], "storage_path": null, "created": "2024-12-24", "archive_serial_number": null },
    { "title": "ESt1A", "correspondent": "Finanzamt München", "document_type": "Tax Return", "tags": ["Tax", "Important"], "storage_path": "Taxes", "created": "2023-05-14", "archive_serial_number": 10 },
    { "title": "W-8BEN", "correspondent": "Internal Revenue Service", "document_type": "Tax Form", "tags": ["Tax"], "storage_path": "Taxes", "created": "2021-11-02", "archive_serial_number": 11 },
    { "title": "Stromabrechnung 2024", "correspondent": "Stadtwerke München", "document_type": "Invoice", "tags": ["Inbox"], "storage_path": "Archive", "created": "2024-03-05", "archive_serial_number": null },
    { "title": "Stromabrechnung 2025", "correspondent": "Stadtwerke München", "document_type": "Invoice", "tags": ["Inbox", "Needs Review"], "storage_path": "Archive", "created": "2025-03-04", "archive_serial_number": null },
    { "title": "Gasabrechnung 2025", "correspondent": "Stadtwerke München", "document_type": "Invoice", "tags": [], "storage_path": "Archive", "created": "2025-04-10", "archive_serial_number": null },
    { "title": "Wasserabrechnung 2026", "correspondent": "Stadtwerke München", "document_type": "Invoice", "tags": ["Important"], "storage_path": "Archive", "created": "2026-02-18", "archive_serial_number": null },
    { "title": "Telekom Rechnung 2026-01", "correspondent": "Deutsche Telekom", "document_type": "Invoice", "tags": ["Inbox"], "storage_path": "Archive", "created": "2026-01-08", "archive_serial_number": null },
    { "title": "Telekom Rechnung 2026-02", "correspondent": "Deutsche Telekom", "document_type": "Invoice", "tags": [], "storage_path": "Archive", "created": "2026-02-08", "archive_serial_number": null },
    { "title": "Telekom Rechnung 2026-03", "correspondent": "Deutsche Telekom", "document_type": "Invoice", "tags": [], "storage_path": "Archive", "created": "2026-03-09", "archive_serial_number": null },
    { "title": "Telekom Rechnung 2026-04", "correspondent": "Deutsche Telekom", "document_type": "Invoice", "tags": ["Needs Review"], "storage_path": "Archive", "created": "2026-04-08", "archive_serial_number": null },
    { "title": "Kontoauszug Q1 2026", "correspondent": "N26", "document_type": "Bank Statement", "tags": ["Important"], "storage_path": "Archive", "created": "2026-03-31", "archive_serial_number": 20 },
    { "title": "Kontoauszug Q2 2026", "correspondent": "N26", "document_type": "Bank Statement", "tags": [], "storage_path": "Archive", "created": "2026-06-30", "archive_serial_number": 21 },
    { "title": "Unsortiertes Dokument #1", "correspondent": null, "document_type": null, "tags": [], "storage_path": null, "created": "2025-07-21", "archive_serial_number": null },
    { "title": "Unsortiertes Dokument #2", "correspondent": null, "document_type": null, "tags": [], "storage_path": null, "created": "2026-05-02", "archive_serial_number": null }
  ],
  "saved_views": [
    {
      "name": "Inbox",
      "show_in_sidebar": true,
      "show_on_dashboard": true,
      "sort_field": "created",
      "sort_reverse": true,
      "filter_rules": [{ "rule_type": 22, "tag": "Inbox" }]
    },
    {
      "name": "Manuals",
      "show_in_sidebar": true,
      "show_on_dashboard": false,
      "sort_field": "title",
      "sort_reverse": false,
      "filter_rules": [{ "rule_type": 28, "document_type": "Manual" }]
    },
    {
      "name": "Taxes",
      "show_in_sidebar": false,
      "show_on_dashboard": true,
      "sort_field": "created",
      "sort_reverse": true,
      "filter_rules": [{ "rule_type": 22, "tag": "Tax" }]
    },
    {
      "name": "Invoices 2026",
      "show_in_sidebar": false,
      "show_on_dashboard": false,
      "sort_field": "created",
      "sort_reverse": false,
      "filter_rules": [
        { "rule_type": 28, "document_type": "Invoice" },
        { "rule_type": 9, "value": "2026-01-01" }
      ]
    }
  ]
}
```

Rule types are `FilterRuleType` raw values from `Modules/ApiInterface/Shared/FilterRuleType.swift`: `22` = `hasTagsAny`, `28` = `hasDocumentTypeAny`, `9` = `createdAfter`. Sort fields are `SortField` raw values; `sort_reverse: true` means descending, per `SavedView`'s custom `encode(to:)`.

- [ ] **Step 2: Write the script foundation and entity creation**

Create `docker/seed/seed.py`:

```python
#!/usr/bin/env python3
"""Seed the local paperless-ngx dev instance with a realistic fixture.

See docs/plans/2026-08-09-docker-seed-data.md for the design.
"""

import argparse
import base64
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_URL = "http://localhost:8000"
USERNAME = "admin"
PASSWORD = "T0PS3CR3T!!123"

SEED_DIR = Path(__file__).resolve().parent
CONFIG_PATH = SEED_DIR / "seed.json"

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


def verify(api, config):
    """Check the instance matches the fixture. Returns a list of problems."""
    problems = []
    for kind, path in ENTITY_PATHS.items():
        actual = {item["name"] for item in api.list_all(path)}
        missing = sorted({
            entry if isinstance(entry, str) else entry["name"]
            for entry in config[kind]
        } - actual)
        if missing:
            problems.append(f"{kind}: missing {missing}")
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
            ensure_entities(api, config)

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
```

- [ ] **Step 3: Write the mise task**

Create `mise/tasks/docker/seed`:

```bash
#!/usr/bin/env bash
#MISE description="Seed paperless-ngx dev data"
set -euo pipefail

python3 "$MISE_PROJECT_ROOT/docker/seed/seed.py" "$@"
```

Then make it executable:

```bash
chmod +x mise/tasks/docker/seed
```

- [ ] **Step 4: Run verify first and watch it fail**

Run: `mise docker:seed --verify`
Expected: exit code 1, listing missing correspondents, document types, tags and storage paths — the entity tables are empty.

- [ ] **Step 5: Seed, then verify passes**

```bash
mise docker:seed
mise docker:seed --verify
```

Expected: the first run prints `created correspondent: …` lines and ends with `Fixture OK`; the second prints only `Fixture OK` (nothing re-created — this is the idempotency check).

- [ ] **Step 6: Confirm the CI instance is untouched**

```bash
curl -s -u 'admin:T0PS3CR3T!!123' 'http://localhost:9000/api/tags/?page_size=1' | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])'
```

Expected: `0`.

- [ ] **Step 7: Commit**

```bash
git add docker/seed/seed.json docker/seed/seed.py mise/tasks/docker/seed
git commit -m "feat: seed correspondents, document types, tags and storage paths"
```

---

## Task 4: Filler documents

**Files:**
- Modify: `docker/seed/seed.py`

**Interfaces:**
- Consumes: `Api`, `SeedError`, `load_config`, `verify` from Task 3; the consume directory `docker/consume/dev` from Task 1.
- Produces: `build_pdf(title, body) -> bytes`, `generate_fillers(config) -> int`, `wait_for_documents(api, config, timeout=600) -> dict` returning `{title: document_id}` for all 25 documents. Task 5 consumes that mapping.

- [ ] **Step 1: Extend verify to require all 25 documents**

In `docker/seed/seed.py`, add to the top of `verify`'s body, before the entity loop:

```python
    titles = {document["title"] for document in config["documents"]}
    actual_titles = {document["title"] for document in api.list_all("/api/documents/")}
    missing_documents = sorted(titles - actual_titles)
    if missing_documents:
        problems.append(f"documents: missing {missing_documents}")
```

- [ ] **Step 2: Run verify and watch it fail on the fillers**

Run: `mise docker:seed --verify`
Expected: exit code 1, `documents: missing ['Gasabrechnung 2025', 'Kontoauszug Q1 2026', …]` — the 12 filler titles, since only the 13 real PDFs have been consumed.

- [ ] **Step 3: Add the PDF generator**

Add to `docker/seed/seed.py`, after the `load_config` function. Also add `import hashlib` and `import time` to the imports, and this constant next to `CONFIG_PATH`:

```python
CONSUME_DIR = SEED_DIR.parent / "consume" / "dev"
```

```python
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
```

- [ ] **Step 4: Call them from `main`**

In `main`, replace the seeding block:

```python
        if not args.verify:
            print(f"Seeding {args.url}")
            ensure_entities(api, config)
```

with:

```python
        if not args.verify:
            print(f"Seeding {args.url}")
            generate_fillers(api, config)
            wait_for_documents(api, config)
            ensure_entities(api, config)
```

- [ ] **Step 5: Run the seed and verify**

```bash
mise docker:seed
mise docker:seed --verify
```

Expected: 12 `generated filler:` lines, some `waiting for N document(s)…` lines, then `Fixture OK` from both commands. Confirm the count and that the consume directory drained:

```bash
curl -s -u 'admin:T0PS3CR3T!!123' 'http://localhost:8000/api/documents/?page_size=1' | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])'
ls docker/consume/dev
```

Expected: `25`, and only `.gitkeep` left in the directory.

- [ ] **Step 6: Confirm re-running generates nothing**

Run: `mise docker:seed`
Expected: no `generated filler:` lines, no waiting, `Fixture OK`. The document count is still `25` — this proves the deterministic bytes plus the existence check prevent duplicates.

- [ ] **Step 7: Commit**

```bash
git add docker/seed/seed.py
git commit -m "feat: generate filler documents for the dev fixture"
```

---

## Task 5: Document metadata

**Files:**
- Modify: `docker/seed/seed.py`

**Interfaces:**
- Consumes: `ensure_entities`'s `{kind: {name: id}}` return value and `wait_for_documents`'s `{title: id}` mapping.
- Produces: `patch_documents(api, config, entity_ids, document_ids) -> None`.

- [ ] **Step 1: Extend verify to check the assignments**

In `docker/seed/seed.py`, add to `verify` after the existing document-titles check. Replace the block added in Task 4 Step 1 with this fuller version:

```python
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
```

- [ ] **Step 2: Run verify and watch it fail**

Run: `mise docker:seed --verify`
Expected: exit code 1, with lines like `Sonos One: correspondent is None, expected 'Sonos'` and `Sonos One: created is '2026-08-09', expected '2019-03-11'` for all 25 documents.

- [ ] **Step 3: Write the patcher**

Add to `docker/seed/seed.py`, after `wait_for_documents`:

```python
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
```

`entity_ids[...].get(None)` returns `None`, which is exactly the payload needed to clear a field — that is what gives the two `Unsortiertes Dokument` entries and the LEGO documents their unset fields.

- [ ] **Step 4: Call it from `main`**

In `main`, change the seeding block to capture the return values and patch:

```python
        if not args.verify:
            print(f"Seeding {args.url}")
            generate_fillers(api, config)
            document_ids = wait_for_documents(api, config)
            entity_ids = ensure_entities(api, config)
            patch_documents(api, config, entity_ids, document_ids)
```

- [ ] **Step 5: Run the seed and verify**

```bash
mise docker:seed
mise docker:seed --verify
```

Expected: 25 `patched:` lines, then `Fixture OK` from both. Spot-check the counts the design predicts:

```bash
curl -s -u 'admin:T0PS3CR3T!!123' 'http://localhost:8000/api/tags/?page_size=50' \
  | python3 -c 'import json,sys; [print(t["name"], t["document_count"]) for t in sorted(json.load(sys.stdin)["results"], key=lambda t: t["name"])]'
```

Expected: `Audio 3`, `Furniture 3`, `Important 4`, `Inbox 3`, `Kids 4`, `Locked 1`, `Manual 6`, `Needs Review 3`, `Tax 2`, `Toys 3`, `Warranty 2`.

- [ ] **Step 6: Commit**

```bash
git add docker/seed/seed.py
git commit -m "feat: assign metadata, dates and ASNs to seeded documents"
```

---

## Task 6: Saved views

**Files:**
- Modify: `docker/seed/seed.py`

**Interfaces:**
- Consumes: `ensure_entities`'s `{kind: {name: id}}` return value.
- Produces: `ensure_saved_views(api, config, entity_ids) -> None`.

- [ ] **Step 1: Extend verify to require the saved views**

Add to `verify`, just before `return problems`:

```python
    expected_views = {view["name"] for view in config["saved_views"]}
    actual_views = {view["name"] for view in api.list_all("/api/saved_views/")}
    missing_views = sorted(expected_views - actual_views)
    if missing_views:
        problems.append(f"saved_views: missing {missing_views}")
```

- [ ] **Step 2: Run verify and watch it fail**

Run: `mise docker:seed --verify`
Expected: exit code 1, `saved_views: missing ['Inbox', 'Invoices 2026', 'Manuals', 'Taxes']`.

- [ ] **Step 3: Write the saved-view creator**

Add to `docker/seed/seed.py`, after `patch_documents`:

```python
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
            "show_on_dashboard": view["show_on_dashboard"],
            "show_in_sidebar": view["show_in_sidebar"],
            "sort_field": view["sort_field"],
            "sort_reverse": view["sort_reverse"],
            "filter_rules": rules,
        })
        print(f"  created saved view: {view['name']}")
```

- [ ] **Step 4: Call it from `main`**

Add one line to the seeding block, after `patch_documents`:

```python
            ensure_saved_views(api, config, entity_ids)
```

- [ ] **Step 5: Run the seed and verify**

```bash
mise docker:seed
mise docker:seed --verify
```

Expected: 4 `created saved view:` lines then `Fixture OK`; the second command prints only `Fixture OK`, and re-running `mise docker:seed` creates no duplicates.

- [ ] **Step 6: Confirm the views resolve to the right documents**

```bash
curl -s -u 'admin:T0PS3CR3T!!123' 'http://localhost:8000/api/saved_views/?page_size=10' \
  | python3 -c 'import json,sys; [print(v["name"], v["show_in_sidebar"], v["show_on_dashboard"], v["filter_rules"]) for v in json.load(sys.stdin)["results"]]'
```

Expected: four views covering all four sidebar/dashboard combinations — `Inbox True True`, `Manuals True False`, `Taxes False True`, `Invoices 2026 False False`.

- [ ] **Step 7: Commit**

```bash
git add docker/seed/seed.py
git commit -m "feat: seed saved views covering every visibility combination"
```

---

## Task 7: Wire the seed into `docker:start`

**Files:**
- Modify: `mise/tasks/docker/start`

**Interfaces:**
- Consumes: the `docker:seed` task from Task 3.

- [ ] **Step 1: Call the seed task after both instances are up**

Append to `mise/tasks/docker/start` so the file reads in full:

```bash
#!/usr/bin/env bash
#MISE description="Start paperless-ngx"
set -euo pipefail

cd $MISE_PROJECT_ROOT/docker

cp data/*.pdf consume/dev
PAPERLESS_INSTANCE=dev CADDY_PORT=8010 PAPERLESS_PORT=8000 docker-compose -p paperless-dev up -d --wait

cp data/*.pdf consume/ci
PAPERLESS_INSTANCE=ci CADDY_PORT=9010 PAPERLESS_PORT=9000 docker-compose -p paperless-ci up -d --wait

mise run docker:seed
```

The seed goes last so it does not delay the ci instance coming up, and its own `wait_for_documents` handles the fact that dev consumption is still in flight.

- [ ] **Step 2: Full clean-slate run**

```bash
mise docker:stop
mise docker:start
```

Expected: both stacks come up, then the seed generates fillers, waits, and ends with `Fixture OK`. The task must exit 0.

- [ ] **Step 3: Verify the end state on both instances**

```bash
for endpoint in documents correspondents document_types tags storage_paths saved_views; do
  echo -n "dev $endpoint: "
  curl -s -u 'admin:T0PS3CR3T!!123' "http://localhost:8000/api/$endpoint/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])'
done
for endpoint in documents tags correspondents; do
  echo -n "ci $endpoint: "
  curl -s -u 'admin:T0PS3CR3T!!123' "http://localhost:9000/api/$endpoint/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])'
done
```

Expected: dev `25 / 10 / 6 / 11 / 4 / 4`; ci `13 / 0 / 0`.

- [ ] **Step 4: Confirm the Swift test suites still pass against ci**

```bash
tuist generate --no-open
tuist test ApiImplementation --no-selective-testing
```

Expected: PASS — in particular `test_getDocuments` and `test_getAllDocumentIds`, which assert exactly two `"Lego"` matches on the unseeded ci instance.

- [ ] **Step 5: Confirm the seeded corpus renders in the app**

```bash
TUIST_PAPERLESS_TEST_URL=http://localhost:8000 TUIST_PAPERLESS_PAGE_SIZE=10 tuist generate --no-open
```

Build and run the `DocumentsApp` scheme in the simulator. Confirm: the list pages through 25 documents across 3 pages, tag chips appear with both black text (`Locked`, `Inbox`) and white text (`Needs Review`, `Toys`), `Ikea Vimle #1` shows five tags, and the two `Unsortiertes Dokument` entries show empty correspondent/type state.

Then restore the normal project generation:

```bash
tuist generate --no-open
```

- [ ] **Step 6: Commit**

```bash
git add mise/tasks/docker/start
git commit -m "feat: seed the dev instance from mise docker:start"
```

---

## Self-Review Notes

Checked against `docs/plans/2026-08-09-docker-seed-data.md`:

- **Every spec section has a task.** Per-instance consume dirs → Task 1. Configurable page size → Task 2. Entities (10 correspondents, 6 document types, 11 tags, 4 storage paths) → Task 3. Filler generation and the consumption wait → Task 4. Document assignments, created dates, ASNs → Task 5. Saved views → Task 6. `docker:start` wiring → Task 7. Idempotency and error handling are exercised by the repeated `--verify` steps in Tasks 3–6.
- **Naming is consistent across tasks.** `ensure_entities` returns `{kind: {name: id}}` keyed by the `ENTITY_PATHS` keys (`correspondents`, `document_types`, `tags`, `storage_paths`), and Tasks 5 and 6 index it with exactly those keys. `wait_for_documents` returns `{title: id}`, which is what `patch_documents` indexes by title. `PageSize.default` / `PageSize.configured` / `PageSize.value(from:)` are used identically in the test, the implementation and `DocumentsRepository`.
- **The `verify` function grows across Tasks 4–6**, so Task 5 Step 1 explicitly replaces the block Task 4 added rather than appending a second copy.
- **Out of scope, unchanged:** `PAPERLESS_TASK_WORKERS`, the `PAPERLESS_TEST_URL` default, `mise.toml`, `mise/tasks/docker/stop`, custom fields, notes, users/groups/permissions.
