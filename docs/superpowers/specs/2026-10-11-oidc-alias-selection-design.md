# OIDC selection makes the missing alias visible

The server form shows "Sign in with …" buttons after the URL is entered, but they arrive
disabled until the alias field is filled, with nothing saying the alias is the missing
piece. People paste a URL, see greyed-out buttons, and stall.

## Intent

Make the alias requirement discoverable through selection itself: let the user pick an
OIDC provider first, then show them that the alias is what is still needed, rather than
blocking the pick behind a requirement they cannot see.

This builds on the OIDC login design (`2026-08-27-oidc-login-design.md`), which put the
provider buttons above the username and password fields. It changes only the selection
interaction on that form, not how the login itself is obtained.

## Goals

- The OIDC buttons are tappable even when the alias is still empty. Selection is never
  blocked by the missing alias; completing the alias is what stays blocked until it is
  filled.
- Tapping an OIDC button selects it: it takes the `.primary` style and gains a checkmark,
  so the choice reads as chosen, not just pressed.
- Selecting a provider hides the username and password fields, since they do not apply to
  that path.
- If the alias is still empty at selection time, focus moves to the alias field. If it is
  already filled, focus is left alone.
- Tapping a different provider moves the selection to it.
- Tapping the selected provider a second time clears the OIDC selection entirely: the
  primary style and checkmark go away, and the username and password fields come back.
- Whatever alias text was typed is preserved across select, switch, and deselect. Selection
  never clears what the user wrote.
- Username and password text is likewise preserved while hidden. Hiding is presentation only;
  deselecting restores exactly what was typed.
- Validation follows the selected path: while an OIDC provider is selected, empty username and
  password are not errors; while nothing is selected, the normal password validation applies.

## Non-goals

- Auto-filling or suggesting the alias from the URL. The field stays user-entered; only
  focus moves.
- Changing what the alias is for, or when a server can be saved. The alias stays required
  for login by either path.
- Changing the OIDC login flow itself: `OIDCClient`, PKCE, the callback scheme, second
  factor, and error messages are untouched.
- Visual redesign of the form beyond the selected button state and the hide/show of the
  credential fields.

## Anti-goals

- A form that looks ready when it is not: the selected provider must not make the login
  action enabled while the alias is still empty.
- Stealing focus from a filled alias. Moving the cursor when there is nothing to fix is
  worse than not moving it.
- A selection that traps the user on the OIDC path with no visible way back to password.

## Constraints

- This is `ServerForm` in `ServersFeature`. The existing username and password path is the
  fallback and stays working exactly as today, including when there are no providers.
- At most one provider is selected at a time, or none. There is no multi-select.
- The actual login still requires a non-empty alias (and URL) regardless of selection.
  Selection changes the form; it does not bypass validation.
- Existing behavior when the URL changes (refetching providers) is preserved. If the
  provider list is refetched, a selection for a provider that is no longer offered does
  not survive; this falls out of validating against the fresh config, not a new rule.

## Decided

- Selected appearance is `.primary` plus a checkmark. No new button variant.
- Hide, not disable, the username and password fields while an OIDC provider is selected.
  Disabled credential fields under a selected SSO option read as broken rather than
  inapplicable.
- Focus moves to alias only on the transition from no selection to a selection while the
  alias is empty. Switching providers or re-selecting after deselect does not refocus if
  the user has already been pointed there once; the condition (empty alias) covers this
  without a separate flag.
- Second tap on the selected provider is a full deselect, not a no-op. Username and
  password return, selection visuals clear.
- The login action uses whichever path is currently selected at tap time: OIDC provider
  when one is selected, username and password when none is.
- Tapping a provider only ever selects; it never starts the login, even when alias and URL are
  already filled. Login is always the separate login action.
- No additional helper text or validation copy is added: focus moving to the empty alias, the
  credential fields hiding, and login staying disabled until the alias is filled together are
  the signal. This keeps the change free of new strings.
- Selection identity is the provider `id` from `OIDCProvider`, matched against the freshly
  fetched config. If the selected id is no longer offered after a URL refetch, the selection
  clears, the credential fields return with their preserved text, focus is left alone, and no
  error is shown.

## Left to the builder

- Reducer action and state names for the selection, following the existing `ServerForm`
  conventions.
- Whether focus is driven by `@FocusState` or an equivalent, and whether the hide/show of
  the credential fields animates.
- Accessibility labels for the selected versus unselected provider buttons, including the
  checkmark.
- Snapshot and reducer test coverage for: select with empty alias (focus + hidden
  credentials), select with filled alias (no focus steal), switch providers, deselect by
  second tap (credentials return, alias text kept).
