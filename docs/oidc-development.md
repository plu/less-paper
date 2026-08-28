# Testing the OIDC login against Authentik

The development instance has no identity provider, so the OIDC flow cannot be exercised without
standing one up. This is the shortest path to a paperless server that offers single sign-on.

These containers run on the **host**, through the Docker socket the host forwards into the VM — see
the Docker section of `AGENTS.md`. They share the host's colima with both paperless stacks, which is
why the memory below matters and why this uses its own project and port.

## The one thing to get right

**Authentik needs a single URL that both the paperless container and the iOS simulator can reach.**

The app does not decide where the identity provider lives. It asks paperless, through
`api/auth/headless/app/v1/config`, and paperless answers with whatever `openid_configuration_url` it
was configured with. Point paperless at `http://authentik:9000` and the simulator is handed a
hostname only Docker can resolve — the browser step then fails with a DNS error that looks nothing
like the actual mistake.

Use the address the simulator already uses for paperless. If `TUIST_PAPERLESS_TEST_URL` is
`http://192.168.64.1:8000`, then Authentik is `http://192.168.64.1:9100`, and the paperless container
must be able to reach that too.

## 0. Give colima enough memory first

**This decides whether any of the rest works.** colima here is a 1.9 GiB VM already running both
paperless stacks, and Authentik does not fit beside them:

```
Mem:  total 1959   used 1643   free 37   available 205    Swap: 0
```

Authentik's gunicorn workers get killed — *"Worker (pid:1754) was sent SIGKILL! Perhaps out of
memory?"* — and its Go frontend answers `502 failed to connect to authentik backend`. It reads as
Authentik being broken. It is not; the machine is full.

On the **host**. This restarts every container, both paperless stacks included:

```sh
colima stop
colima start --memory 6 --cpu 4
```

Capping the worker pools is already done in the compose file and is not sufficient on its own.

## 1. Start it

```sh
cd docker
docker-compose -f docker-compose.oidc.yml -p less-paper-oidc up -d
```

Its own project, on port 9100 — 8000, 8010, 9000 and 9010 belong to the paperless stacks, and this
must not restart them. Note `docker-compose`, not `docker compose`: there is no compose plugin here.

First boot takes several minutes. It is ready when `http://192.168.64.1:9100/-/health/ready/` returns
204 **and** an API call answers — the health endpoint comes up well before the backend does, which is
worth knowing before concluding something has failed.

## 2. Set up Authentik

Already done once, and persisted in the `authentik-db` volume — provider `paperless`, application
slug `paperless`, public client, both redirect URIs, with
`client_id=MkTqw6gmZVccFQhFCGEtpMusEcnyqAycYIAHNfeq`. Recreate it only if that volume is destroyed.

The compose file bootstraps an admin (`akadmin` / `development-only`) and an API token
(`development-only-token`), so this can be done through the API rather than by clicking. Note that
the default blueprints do **not** apply themselves on a first boot this slow; the flows have to be
applied by hand before a provider can reference one:

```sh
docker exec less-paper-oidc-authentik-1 sh -c 'for f in /blueprints/default/*.yaml; do ak apply_blueprint "$f"; done'
```

`ak shell -c` runs an interactive console, so a multi-line `if` block silently fails with a
`SyntaxError` and the statements after it never run — which produced a provider with no
authorization flow that reported itself as created. Put the script in a file and
`exec(open(...).read())` it instead, then read the object back and check.

To do it through the UI instead — **Applications → Providers → Create → OAuth2/OpenID Provider**:

| Field | Value | Why |
|---|---|---|
| Name | `paperless` | |
| Authorization flow | implicit consent | no consent screen while developing |
| **Client type** | **Public** | the app exchanges its code with PKCE and **no secret**, which is what a native client should do. A confidential client rejects that exchange. |
| Redirect URIs | see below | |
| Signing key | any | needed so paperless can verify the `id_token` |

Two redirect URIs, one per consumer:

```
atlp://oidc-callback
http://192.168.64.1:8000/accounts/oidc/authentik/login/callback/
```

The first is the app — `atlp` is the scheme it already registers. The second is paperless's own
browser flow. **Omitting the first is the failure you are most likely to hit**, and it surfaces as an
error from Authentik rather than from the app.

Then **Applications → Applications → Create**, name `paperless`, slug **`paperless`**, and select the
provider above. The slug has to be `paperless` because it is in the discovery URL the compose file
sets.

Copy the provider's **Client ID**.

## 3. A paperless that offers it

`docker-compose.oidc.yml` brings up its own paperless on **8100**, already configured, rather than
reconfiguring `paperless-dev` — that is what every local test targets, and its stack bind-mounts
paths that only exist on the host, so it cannot be driven from the agent's VM at all.

**`PAPERLESS_APPS` is the part that is easy to miss.** Setting
`PAPERLESS_SOCIALACCOUNT_PROVIDERS` alone is not enough: allauth needs the provider app installed
too, and without it `socialaccount.providers` stays `[]` while Django happily reports
`SOCIALACCOUNT_PROVIDERS` as populated. The app then correctly shows no buttons, and everything looks
configured.

```yaml
PAPERLESS_APPS: allauth.socialaccount.providers.openid_connect
```

To check what Django actually installed rather than what it was told:

```sh
docker exec less-paper-oidc-paperless-1 python3 -c "
import os, django; os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'paperless.settings'); django.setup()
from django.conf import settings
print([a for a in settings.INSTALLED_APPS if 'allauth' in a])"
```

## 3b. Pointing another paperless at it

paperless-dev is not ours to restart casually — it is what every local test targets — so this is a
deliberate step, not part of bringing Authentik up. Add to that stack's environment:

```yaml
PAPERLESS_URL: http://192.168.64.1:8000
PAPERLESS_SOCIALACCOUNT_PROVIDERS: >-
  {"openid_connect": {"APPS": [{
    "provider_id": "authentik",
    "name": "Authentik",
    "client_id": "MkTqw6gmZVccFQhFCGEtpMusEcnyqAycYIAHNfeq",
    "secret": "",
    "settings": {"server_url": "http://192.168.64.1:9100/application/o/paperless/.well-known/openid-configuration"}
  }]}}
```

No secret: the app exchanges its code as a public client with PKCE, and paperless only needs to
verify the `id_token` against the published JWKS.

Then confirm the paperless container can actually reach Authentik at that address — container to
host is the step most likely to fail silently:

```sh
docker exec paperless-dev-paperless-1 \
  python3 -c "import urllib.request; print(urllib.request.urlopen('http://192.168.64.1:9100/application/o/paperless/.well-known/openid-configuration').status)"
```

## 4. Check paperless is offering it

```sh
curl -s http://192.168.64.1:8100/api/auth/headless/app/v1/config | python3 -m json.tool
```

`socialaccount.providers` should now hold one entry with `"id": "authentik"` and the client ID. While
it is still `[]`, the app will show only username and password — correctly, because that is all the
server is offering.

## 5. A user that can log in

Authentik's `akadmin` is not a paperless user. Either create a user in Authentik whose email matches
an existing paperless user, or set `PAPERLESS_SOCIAL_AUTO_SIGNUP: "true"` so the first successful
login creates one.

## Second factor

The dev instance advertises `totp`, so the MFA branch is reachable: enable TOTP for the paperless
user (Django admin → MFA), and the login stops after the provider and asks for a code. That path is
worth exercising by hand at least once — it is the one part of the flow that stubs model rather than
prove.

## When it goes wrong

| What you see | Almost always |
|---|---|
| Browser shows an Authentik error about the redirect URI | `atlp://oidc-callback` is not on the provider |
| App shows only username and password | `providers` is still `[]` — the client ID never reached paperless |
| Browser step fails to resolve a host | paperless was configured with a URL only Docker can resolve |
| Token exchange rejected | the provider is a confidential client; it has to be Public |
| Login succeeds, paperless refuses | no paperless user matches — see step 5 |
