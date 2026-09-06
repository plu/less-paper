# Object-level permissions — what we already know

Notes for the third and last permissions project, written while finishing the second. Not a design:
a design has to decide things, and this decides nothing. It exists so the next person does not
re-derive facts that cost live-server probing to establish.

The two shipped projects gated **global** permissions — Django model permissions of the form
`<action>_<type>`, which answer "may this account ever do this, anywhere". Object-level permissions
answer a different question: "may this account do this **to this row**". That difference is what
makes this project unlike the two before it, and the notes below are organised around it.

## The paperless model, as verified against a live 3.0.5 instance

- **An object with no owner is accessible to everyone.** This is the default state and the reason
  the seed fixture works at all: `docker/seed/seed.py` explicitly sends `owner: null` and
  `verify()` fails if anything acquires one. An owned object is invisible to every user but its
  owner and those granted access, and an empty list looks exactly like successful gating — which is
  why that invariant is enforced rather than documented.
- **An owner bypasses object permissions entirely**, and `change` implies `view`.
- **List responses carry a computed `user_can_change` boolean** by default. The full structure —
  the view/change × users/groups matrix — requires `full_perms=true`.
- **`Permissions` in `ApiInterface` already models that structure.** It was built during the
  acquisition project and currently has no consumer.
- **The document endpoint does not request `full_perms` yet.** That was deliberate: see
  `docs/superpowers/specs/2026-08-21-document-edit-content-design.md:184`, "until there is a
  `permissions` field to decode". Decoding it is this project's first task.
- **Custom fields have no object-level permissions at all** — no `owner`, no `permissions`, no
  `user_can_change` (`docs/superpowers/specs/2026-08-22-custom-fields-design.md:25`). They are
  global-only, so this project does not touch them.

## Things that surprised us, and cost time to find

- **A superuser's `ui_settings` lists every permission explicitly.** All 162 of them. So the
  `is_superuser` bypass in `ServerPermissions.can` is never exercised by a real server — only by
  unit tests. Do not build an object-level equivalent expecting to test it against paperless.
- **paperless repeats codenames.** `/api/ui_settings/` returns 166 entries and 162 unique ones:
  `add_logentry`, `change_logentry`, `delete_logentry` and `view_logentry` each appear twice. Any
  new grouping or de-duplication over permissions must expect that.
- **Two codenames carry a second underscore** — `view_global_statistics` and
  `view_system_monitoring` — and the app's `Permission` enum models neither. Anything parsing
  `<action>_<type>` must split at the first underscore only.
- **The trash endpoints enforce nothing.** `/api/trash/` answers 200 for an account without
  `delete_document`, and a restore of a non-existent id answers 400, not 403. The app gates trash
  on `delete_document` by intent, not because the server backs it up. Do not read that 200 as
  evidence a gate is wrong.
- **Notes ride on their own type** — `view_note`, `add_note`, `change_note`, `delete_note` — not on
  `change_document`. An account with full rights over documents has none over notes.

## The problem this project has and the last two did not

A global permission is one answer for the whole screen, so a gate is a property on State that the
view reads. An object permission varies per row, which breaks that shape in two places:

- **A bulk selection can be partly permitted.** Selecting twenty documents where the account may
  change twelve of them has no obvious right answer: disable the action, apply it to the twelve, or
  refuse and say why. The two shipped projects never had to decide anything like this, because a
  global permission is the same for every row in the list.
- **The answer arrives with the row, not with the server.** `ServerPermissions` is built once from
  two `@Shared` caches; `user_can_change` comes down inside each document payload. Whatever holds
  it is not `ServerPermissions`, and the per-row gates cannot be computed from a server-scoped
  value.

Neither is decided here. Both are the first things a design has to settle.

## What the fixture cannot express yet

`docker/seed/seed.json` seeds thirteen scenario users covering the global matrix and **no
object-level scenarios at all** — that exclusion is recorded in
`docs/superpowers/specs/2026-08-09-docker-seed-data-design.md:238`. Two specific gaps:

- Every seeded entity and document is deliberately **unowned**, so no fixture produces a document
  the current user may see but not change. That is exactly the state this project needs to test.
- The 25 documents on the dev instance are owned by user `apple` (id 3), which is why every
  `perm-*` user sees an empty document list there. A scenario user for this project needs documents
  it can see, some of which it may not change.

`permissions_for` in `docker/seed/permissions.py` grew an `extra` key for codenames the
`actions × entities` cross product cannot reach; object-level scenarios will need something
similar for ownership, which is per-object rather than per-user.

## One method note, worth more than any single fact above

The gaps in the second project were not found by reading the spec's list of screens. Four separate
times an affordance turned out to exist somewhere the spec did not name — Import and Scan also in
Settings, the note composer in the document form rather than the notes view, the notes entrance in
a viewer menu, three more create buttons in the share sheet — and each was caught by accident.

What finally worked was sweeping **backwards from the API**: for each permission, find every call
site of the action it governs, then check each one is gated. That is how the last two gaps were
found, including a `view_note` gate that covered one of four entrances to the same section. Start
this project that way rather than from a list of screens.
