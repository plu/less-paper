# Testing forward auth against Authelia

The development instance has no reverse proxy in front of it, so the forward-auth flow cannot be
exercised without standing one up. This is the shortest path to a paperless server behind Authelia
that both remote-user and gate-only modes can be tested against.

These containers run on the **host**, through the Docker socket the host forwards into the VM — see
the Docker section of `AGENTS.md`. They share the host's colima with the two paperless stacks and
the OIDC stack, which is why they use their own project and port.

## The one thing to get right

**The Authelia session cookie must cover both the portal and paperless.** Cookies bind to a
registrable domain, so both hostnames sit under one — here `auth.local.plunien.com` and
`paperless.local.plunien.com`. Get the cookie domain wrong and every request from paperless is a
fresh 401 that looks like a bug in the app.

**Both hostnames must resolve to the Docker host from the simulator.** The simulator inherits
resolution from the host, so add the two names to `/etc/hosts` on the host once:

```
192.168.64.1 auth.local.plunien.com
192.168.64.1 paperless.local.plunien.com
```

Use the address the simulator uses for paperless (`TUIST_PAPERLESS_TEST_URL`) here too. If the
Docker host is somewhere else, adjust — the name has to point at the same place the browser inside
the simulator ends up.

**The simulator must trust Caddy's internal CA.** Caddy generates one on first boot and signs the
per-hostname certificates with it. Without the CA in the simulator's trust store, `WKWebView`
refuses the login page and `URLSession` refuses the API — either way the flow never completes.

## 1. Start the stack

```sh
cd docker
docker-compose -f docker-compose.authelia.yml -p less-paper-authelia up -d
```

Its own project, on port 8200 — 8000/8010, 9000/9010 and 8100/9100 belong to the other stacks and
this must not restart them. Note `docker-compose`, not `docker compose`: there is no compose plugin
here.

First boot takes a minute or two. It is ready when
`https://paperless.local.plunien.com:8200/api/` answers 302 pointing at
`https://auth.local.plunien.com:8200/`.

## 2. Trust Caddy's internal CA in the simulator

Caddy writes the CA cert to the `caddy-data` volume on first boot. Copy it out and install into the
booted simulator:

```sh
docker cp less-paper-authelia-caddy-1:/data/caddy/pki/authorities/local/root.crt /tmp/caddy-root.crt
xcrun simctl keychain booted add-root-cert /tmp/caddy-root.crt
```

The simulator has to be booted; do this from within Xcode's Simulator app or after
`xcrun simctl boot <UDID>`.

## 3. Sign in through the browser once

Open `https://paperless.local.plunien.com:8200/` in the host's browser. Authelia's portal appears.
Sign in as `admin` with password `secret`. Paperless comes up.

That proves both the certificate is trusted and the cookie domain works. The app run below only
needs the certificate step done in the simulator's own trust store.

## 4. Add the server in Less Paper

Run the app in the simulator. Add a server:

- URL: `https://paperless.local.plunien.com:8200`
- Alias: anything
- Username / password: anything (see below)

The app makes an unauthenticated `GET /api/ui_settings/`, is bounced by Authelia, presents the
confirmation popup naming `auth.local.plunien.com`, and on confirm shows the login sheet. Sign in
as `admin` / `secret`. The sheet dismisses; the server saves.

**In remote-user mode** (the default here — `PAPERLESS_ENABLE_HTTP_REMOTE_USER_API` is `true` in
`docker-compose.authelia.yml`), the probe returns the username Authelia injected and no token or
password is stored — the server appears in the switcher as `admin`. The username you typed in the
form is discarded.

**In gate-only mode**, edit `docker-compose.authelia.yml` to remove both `PAPERLESS_ENABLE_HTTP_REMOTE_USER*`
lines and restart:

```sh
docker-compose -f docker-compose.authelia.yml -p less-paper-authelia up -d --force-recreate paperless
```

Now after the SSO login the app finds a 401 (the cookie got past the proxy, paperless still wants
its own auth) and runs the ordinary password login — enter `admin` / `password` (paperless's admin,
`PAPERLESS_ADMIN_PASSWORD` in the compose file, currently `development-only`).

## 5. Exercise expiry

Once a server is added and working, sign out of Authelia in the host's browser (or clear the
`authelia_session` cookie in Safari). Reload a document list in the app: the confirmation popup
appears, the login sheet appears, the login completes, and the list refreshes **without an error
toast**. That's the rendezvous — `shouldRetry` parked the request and replayed it once cookies were
back in app-group storage.

## What each piece is doing

- **Authelia (`docker/authelia/`)** — the identity provider and the forward-auth endpoint. Users in
  `users_database.yml`; secrets are development-only, regenerate for anything that leaves the
  machine (`openssl rand -hex 32` for the two hex secrets, `authelia crypto hash generate argon2` for
  the password).
- **Caddy (`docker/caddy/Caddyfile.authelia`)** — terminates TLS with the internal CA and calls
  Authelia's `/api/authz/forward-auth` on every request. Copies four `Remote-*` headers through to
  paperless, which is what makes remote-user mode work.
- **paperless** — its own instance so `paperless-dev` keeps running for ordinary work. Named
  volumes only, no bind mounts, so it can be brought up and reconfigured from either side of the
  Docker socket.

## Regenerating secrets

The two hex secrets in `docker/authelia/configuration.yml` and the argon2 hash in
`users_database.yml` are development-only and committed. If anything about this stack is going
somewhere that is not this developer's machine, regenerate all three:

```sh
openssl rand -hex 32   # jwt_secret
openssl rand -hex 32   # encryption_key
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password '<new password>'
```
