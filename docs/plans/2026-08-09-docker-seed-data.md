# Docker seed data — correspondents, document types, tags, storage paths

## Context

`mise docker:start` brings up two paperless-ngx 3.0.5 stacks from `docker/docker-compose.yml`:

- **paperless-dev** — API on `:8000`, Caddy/TLS on `:8010`, compose project `paperless-dev`
- **paperless-ci** — API on `:9000`, Caddy/TLS on `:9010`, compose project `paperless-ci`

Seeding today is one line per instance: `cp data/*.pdf consume`. Paperless consumes the 13 PDFs in `docker/data/` and that is the entire fixture. Every document lands with **no correspondent, no document type, no tags, no storage path, no ASN, and `created` set to the day the container was started**. There are no saved views. As a result, large parts of the app — tag chips and their contrast handling, correspondent/type/storage-path pickers, date sorting and grouping, ASN display, saved views, and list pagination — have no meaningful data to render during development.

### What the 13 documents actually are

Read back out of the running dev instance's OCR content, they fall into two groups:

| Document | What it is |
|---|---|
| Sonos One, Sonos Sub, Sonos Era 300 | Speaker manuals (image-only PDFs, OCR yields just the model name) |
| Puky | `KINDERFAHRRAD MADE IN GERMANY — GEBRAUCHSANLEITUNG`, a kids' bike manual |
| Puky-Locked | The same bike manual, password-protected |
| TonieBox | `Welcome to tonies! Setup Guide` |
| Lego Duplo, Lego Friends | LEGO building instructions |
| Ikea Danderyd | `DANDERYD — Design and Quality — IKEA of Sweden` |
| Ikea Vimle #1, Ikea Vimle #2 | IKEA Vimle sofa assembly/product sheets |
| ESt1A | `2022 Hauptvordruck ESt 1 A — Einkommensteuererklärung`, German income tax return |
| W-8BEN | IRS `Form W-8BEN — Certificate of Foreign Status of Beneficial Owner` |

So: eleven product manuals / assembly instructions from six brands, plus two tax forms. The seed metadata below is derived from that, not invented.

### Why the CI instance is excluded

Seeding metadata into paperless-ci would be churn, not fixture. The test suites own that instance's entity tables and wipe them on every run:

- `Modules/ApiImplementationTests/**/*RepositoryTests.swift` call `repository.deleteAll()` in `init()` (tags, correspondents, document types, storage paths, saved views, users, groups).
- `Modules/TagsAppTests/TagsAppTests.swift` `setUp()` deletes every tag, then creates its own `Inbox` (`#aa0000`) and asserts on it; the other `*AppTests` follow the same pattern.

Documents, by contrast, *are* a shared fixture nothing deletes — `DocumentsRepositoryTests.test_getDocuments` asserts that filtering on title `"Lego"` returns exactly `Lego Duplo` and `Lego Friends`, and `DocumentsAppTests.testList` asserts the same two plus `"2 of 2 loaded"`.

Seeding dev only keeps CI's corpus exactly as those tests expect and avoids fixtures that vanish mid-suite.

### Reaching the seeded instance

`Tuist/ProjectDescriptionHelpers/Module+InfoPlists.swift` writes `PAPERLESS_TEST_URL` into each module's Info.plist from `Environment.paperlessTestUrl.getString(default: "http://localhost:9000")`, and `URL.testValue` (`Modules/ApiInterface/Extensions/URL+Extensions.swift:14`) reads it back. The default points at CI, so the seeded corpus is opt-in:

```
TUIST_PAPERLESS_TEST_URL=http://localhost:8000 TUIST_PAPERLESS_PAGE_SIZE=10 tuist generate
```

No default changes. Nothing about the normal `tuist generate` / `mise ci:test` path moves.

## Configurable page size

`Modules/ApiImplementation/Documents/DocumentsRepository.swift:222` hardcodes `"page_size": "100"` on the document-list request, so pagination would need 100+ documents to trigger. Rather than inflate the corpus, make the page size configurable the same way the test URL already is:

- Add `"PAPERLESS_PAGE_SIZE": .string(Environment.paperlessPageSize.getString(default: "100"))` to `Module+InfoPlists.swift`, in **all three** places `PAPERLESS_TEST_URL` appears — the `.app` case, the `*App` playground case, and `default`. The `.shareExtension` case has no `PAPERLESS_TEST_URL` and is left alone.
- Read it in `DocumentsRepository` from `#bundle.infoDictionary?["PAPERLESS_PAGE_SIZE"]`, falling back to `100`, mirroring `URL.testValue`'s lookup.

Constraints:

- The default stays `100`, so release behaviour is unchanged.
- **Do not** put `TUIST_PAPERLESS_PAGE_SIZE` in `mise.toml`'s `[env]` block — `mise ci:build` runs `tuist` under mise, so a value there would leak the low page size into release builds. It is set per-invocation only.
- `getAllDocumentIds` (`DocumentsRepository.swift:237`) keeps its `page_size=1000000`; it is a different request and unrelated to list paging.

At page size 10 against the 25-document corpus below, document lists span 3 pages — enough to exercise infinite scroll and the `"N of M loaded"` label.

## Corpus: 25 documents

The 13 existing PDFs plus 12 generated filler documents.

### Filler generation

`seed.py` writes 12 minimal single-page PDFs into the dev instance's consume directory. Each carries **unique body text** — paperless rejects duplicate content by checksum, so byte-identical copies would be silently dropped as duplicates rather than consumed. The generated bytes are deterministic (the uniqueness token is a hash of the title), so re-running the seed never produces a second copy of the same document.

Filler titles are ASCII-only. Paperless derives a document's title from its filename, and umlauts in filenames risk NFC/NFD normalisation differences across the Docker bind mount — hence `Telekom Rechnung 2026-03` rather than `Telekom Rechnung März 2026`. Entity names are unaffected (they travel as JSON, never as filenames) and keep their umlauts.

### Per-instance consume directories

`docker-compose.yml` currently mounts `./consume` for **both** compose projects, so the two instances share one host directory. That is why `mise/tasks/docker/start` runs `cp data/*.pdf consume` twice — the dev instance consumes and deletes the files, then they are copied again for ci. It is already a latent race (nothing waits for dev's consumption before the second copy), and dropping generated fillers into that shared directory would make both instances compete for them.

The mount therefore becomes per-instance:

```yaml
- ./consume/${PAPERLESS_INSTANCE}:/usr/src/paperless/consume
```

with `docker/consume/dev/` and `docker/consume/ci/` (each holding a `.gitkeep`; the existing `docker/consume/.gitignore` pattern `*.pdf` already applies recursively), and `start` passing `PAPERLESS_INSTANCE=dev` / `PAPERLESS_INSTANCE=ci` alongside the port variables it already sets. `stop` is left alone, matching how it already omits `CADDY_PORT`/`PAPERLESS_PORT` — compose interpolates the unset variable to empty, which is harmless for `down`.

Filler titles deliberately avoid every real product name, so the `"Lego"` title filters stay at exactly 2 hits. (This is belt-and-braces: CI is not seeded, so it never sees the fillers at all.)

### Real documents

| Title | Correspondent | Document type | Tags | Storage path | Created | ASN |
|---|---|---|---|---|---|---|
| Sonos One | Sonos | Manual | Manual, Audio | Manuals | 2019-03-11 | 1 |
| Sonos Sub | Sonos | Manual | Manual, Audio | Manuals | 2020-09-27 | 2 |
| Sonos Era 300 | Sonos | Manual | Manual, Audio, Warranty | Manuals | 2023-06-18 | 3 |
| Ikea Danderyd | IKEA | Assembly Instructions | Furniture | Furniture | 2021-08-07 | — |
| Ikea Vimle #1 | IKEA | Assembly Instructions | Furniture, Manual, Warranty, Important, Inbox | Furniture | 2022-02-19 | 4 |
| Ikea Vimle #2 | IKEA | Assembly Instructions | Furniture | Furniture | 2022-02-19 | — |
| Puky | PUKY | Manual | Manual, Kids | Manuals | 2022-04-23 | 5 |
| Puky-Locked | PUKY | Manual | Locked, Needs Review | Manuals | 2024-01-15 | — |
| TonieBox | tonies | Manual | Manual, Kids, Toys | Manuals | 2023-12-24 | — |
| Lego Duplo | LEGO | Assembly Instructions | Kids, Toys | — | 2023-12-24 | — |
| Lego Friends | LEGO | Assembly Instructions | Kids, Toys | — | 2024-12-24 | — |
| ESt1A | Finanzamt München | Tax Return | Tax, Important | Taxes | 2023-05-14 | 10 |
| W-8BEN | Internal Revenue Service | Tax Form | Tax | Taxes | 2021-11-02 | 11 |

*Ikea Vimle #1* carries five tags on purpose, to force tag-chip overflow in list rows. The two LEGO documents intentionally have no storage path, so the "unset storage path" state is reachable on a recognisable document.

### Filler documents

| Title | Correspondent | Document type | Tags | Storage path | Created | ASN |
|---|---|---|---|---|---|---|
| Stromabrechnung 2024 | Stadtwerke München | Invoice | Inbox | Archive | 2024-03-05 | — |
| Stromabrechnung 2025 | Stadtwerke München | Invoice | Inbox, Needs Review | Archive | 2025-03-04 | — |
| Gasabrechnung 2025 | Stadtwerke München | Invoice | — | Archive | 2025-04-10 | — |
| Wasserabrechnung 2026 | Stadtwerke München | Invoice | Important | Archive | 2026-02-18 | — |
| Telekom Rechnung 2026-01 | Deutsche Telekom | Invoice | Inbox | Archive | 2026-01-08 | — |
| Telekom Rechnung 2026-02 | Deutsche Telekom | Invoice | — | Archive | 2026-02-08 | — |
| Telekom Rechnung 2026-03 | Deutsche Telekom | Invoice | — | Archive | 2026-03-09 | — |
| Telekom Rechnung 2026-04 | Deutsche Telekom | Invoice | Needs Review | Archive | 2026-04-08 | — |
| Kontoauszug Q1 2026 | N26 | Bank Statement | Important | Archive | 2026-03-31 | 20 |
| Kontoauszug Q2 2026 | N26 | Bank Statement | — | Archive | 2026-06-30 | 21 |
| Unsortiertes Dokument #1 | — | — | — | — | 2025-07-21 | — |
| Unsortiertes Dokument #2 | — | — | — | — | 2026-05-02 | — |

The two `Unsortiertes Dokument` entries are deliberately bare — every metadata field unset — so empty states stay reachable everywhere. Nine of twenty-five documents carry an ASN; the rest are `nil`, so both branches of ASN display and the "next ASN" flow have data.

## Entities

### Correspondents (10)

IKEA, LEGO, Sonos, PUKY, tonies, Finanzamt München, Internal Revenue Service, Stadtwerke München, Deutsche Telekom, N26.

Resulting document counts: Stadtwerke München 4, Deutsche Telekom 4, Sonos 3, IKEA 3, LEGO 2, PUKY 2, N26 2, tonies 1, Finanzamt München 1, Internal Revenue Service 1.

### Document types (6)

Manual, Assembly Instructions, Tax Return, Tax Form, Invoice, Bank Statement.

### Tags (11)

Colours span the contrast range so paperless' computed `text_color` comes out black for some and white for others.

| Name | Colour | Notes |
|---|---|---|
| Inbox | `#a6cee3` | `is_inbox_tag: true` |
| Manual | `#1f78b4` | |
| Furniture | `#b2df8a` | |
| Audio | `#33a02c` | |
| Kids | `#fb9a99` | |
| Toys | `#e31a1c` | |
| Tax | `#fdbf6f` | |
| Warranty | `#ff7f00` | |
| Important | `#cab2d6` | |
| Needs Review | `#6a3d9a` | |
| Locked | `#ffff99` | Lightest colour in the set — forces black `text_color` |

Resulting document counts: Manual 6, Important 4, Inbox 4, Kids 4, Audio 3, Furniture 3, Needs Review 3, Toys 3, Tax 2, Warranty 2, Locked 1.

### Storage paths (4)

| Name | Path template |
|---|---|
| Manuals | `Manuals/{{ correspondent }}/{{ title }}` |
| Taxes | `Taxes/{{ created_year }}/{{ correspondent }}/{{ title }}` |
| Furniture | `Home/Furniture/{{ correspondent }}/{{ title }}` |
| Archive | `Archive/{{ created_year }}/{{ title }}` |

Paperless 3.0 stores storage-path templates in Jinja syntax and silently rewrites the legacy `{created_year}` form into `{{ created_year }}`. `seed.json` therefore holds the Jinja form directly, so the file matches what the API returns and `--verify` can compare templates without false positives.

Assigning a storage path makes paperless move the document's file on disk, which is expected and is itself worth exercising.

### Saved views (4)

`SavedView` (`Modules/ApiInterface/SavedViews/SavedView.swift`) carries `showInSidebar` / `showOnDashboard`, which is what `SetSavedViewVisibilityUseCase` (added in #117) toggles. The four views cover all four combinations of those two flags, so the visibility API has something to act on in every state.

Note that in paperless 3.0 those two flags are **not** part of the saved-view resource — `POST /api/saved_views/` silently ignores them and `GET` never returns them. Visibility lives in `/api/ui_settings/` under `settings.saved_views.dashboard_views_visible_ids` and `sidebar_views_visible_ids`, exactly as `SetSavedViewVisibilityUseCase` drives it. The seed therefore creates the views first, then does a single `POST /api/ui_settings/` to publish them.

| Name | Filter rules | Sort | Sidebar | Dashboard |
|---|---|---|---|---|
| Inbox | `hasTagsAny` (22) = Inbox | `created` desc | yes | yes |
| Manuals | `hasDocumentTypeAny` (28) = Manual | `title` asc | yes | no |
| Taxes | `hasTagsAny` (22) = Tax | `created` desc | no | yes |
| Invoices 2026 | `hasDocumentTypeAny` (28) = Invoice, `createdAfter` (9) = `2026-01-01` | `created` asc | no | no |

Rule type numbers are the `FilterRuleType` raw values in `Modules/ApiInterface/Shared/FilterRuleType.swift`; sort fields are `SortField` raw values (`Modules/ApiInterface/Shared/SortField.swift`). On the wire, `sort_reverse: true` means descending — see `SavedView`'s custom `encode(to:)`.

`Invoices 2026` returns 5 of the 8 invoices, so it also exercises a date-based rule that genuinely narrows the result set.

## Mechanism

### Files

- `docker/seed/seed.json` — all of the above as data: entities, per-document assignments, filler definitions, saved views.
- `docker/seed/seed.py` — the driver. Python 3 from the system toolchain; no third-party packages, no additions to `Brewfile` or `mise.toml [tools]`.
- `mise/tasks/docker/seed` — bash wrapper, `#MISE description="Seed paperless-ngx dev data"`, matching the style of `mise/tasks/docker/start`.

`seed.py` is chosen over bash+`curl`+`jq` because assembling this much JSON in shell is unpleasant and `jq` is not currently a dependency; and over a checked-in `document_exporter` archive imported with `document_importer` because that puts a multi-megabyte binary blob in git and couples the fixture to paperless 3.0.5's manifest format. A readable JSON file that diffs cleanly is worth the small runtime cost.

### Sequence

`mise docker:start` gains one step for the dev instance only:

1. `cp data/*.pdf consume` *(unchanged)*
2. `docker-compose -p paperless-dev up -d --wait` *(unchanged)*
3. `mise docker:seed` — new

The `paperless-ci` block is untouched.

`seed.py` itself:

1. Generate the 12 filler PDFs into `docker/consume`.
2. Poll `GET /api/documents/?page_size=1` until `count == 25`, with a timeout and a clear error message naming which documents are missing. Consumption is asynchronous, so this wait is required before anything can be assigned.
3. Create correspondents, document types, tags and storage paths.
4. `PATCH /api/documents/{id}/` per document, matched by title, setting `correspondent`, `document_type`, `storage_path`, `tags`, `created` and `archive_serial_number`.
5. Create the saved views, resolving tag/type names to the ids from step 3.

`created` (a plain `YYYY-MM-DD` date string in 3.0.5) and `archive_serial_number` are both directly PATCHable — verified against the running dev instance.

Credentials are the admin pair already in `docker-compose.yml` (`admin` / `T0PS3CR3T!!123`) over HTTP Basic on `http://localhost:8000`.

### Idempotency

Every entity is looked up by name first and only created if absent; document PATCHes are by title and overwrite whatever is there. Re-running `mise docker:seed` against an already-seeded instance is a no-op that leaves ids stable, so it is safe to run at any time — including to restore state by hand, or against paperless-ci if someone ever wants the rich corpus there temporarily.

Filler PDFs are only written for titles that do not already exist, so a re-run does not pile up duplicates.

### Error handling

- Any non-2xx API response aborts with the status code, the requested URL and the response body.
- The consumption wait has a bounded timeout and reports the titles that never arrived, rather than hanging or silently proceeding to patch a partial corpus.
- `mise docker:seed` fails loudly (`set -euo pipefail`) so a broken seed cannot be mistaken for a successful `docker:start`.

## Out of scope

- Custom fields (`/api/custom_fields/` is empty and the app has no support for them yet).
- Extra users, groups or object-level permissions — the permission test suites create their own.
- Notes on documents.
- Tuning `PAPERLESS_TASK_WORKERS` in `docker-compose.yml`. Twelve small PDFs do not justify it; the only compose change is the per-instance consume mount described above.
- Any change to the `PAPERLESS_TEST_URL` default, or to `mise.toml`.

## Verification

- `mise docker:stop && mise docker:start` from clean, then confirm the dev instance reports 25 documents, 10 correspondents, 6 document types, 11 tags, 4 storage paths and 4 saved views, with the tag/correspondent document counts listed above.
- Re-run `mise docker:seed` and confirm the same counts and unchanged entity ids.
- Confirm paperless-ci still reports 13 documents and zero tags/correspondents/types/paths.
- `TUIST_PAPERLESS_TEST_URL=http://localhost:8000 TUIST_PAPERLESS_PAGE_SIZE=10 tuist generate`, run `DocumentsApp`, and confirm paging across 3 pages plus tag chips with both black and white text.
- Plain `tuist generate` followed by `tuist test ApiImplementation --no-selective-testing` with docker up, to confirm the CI-facing path is unaffected.
