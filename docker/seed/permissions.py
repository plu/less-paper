#!/usr/bin/env python3
"""The permission scenario users, seeded as part of seed.py.

One user per global-permission scenario the app has to get right, so a permission question can be
answered by logging in rather than by reading code. seed.py builds the corpus they look at; this
builds the people.

Imported by seed.py rather than run on its own, so it takes an Api and never constructs one - a
`from seed import Api` here would be a circular import.
"""

# Custom fields are deliberately absent from seed.json, and that absence is the fixture. The
# empty-list "Create ..." button is one of the gated affordances and is only reachable on an empty
# list, so one entity type has to stay empty for it to be testable at all. Custom fields draw the
# short straw because they are the one type the corpus has no other use for - and because the six
# entity screens are copies of each other, so what this one cannot show, the other five can.
EMPTY_BY_DESIGN_PATH = "/api/custom_fields/"


def permissions_for(user, config):
    """Expand a user's actions x entities into Django permission codenames.

    `extra` names codenames the cross product cannot reach. A user who may import documents but
    only read entities needs add_document beside view_<entity>, and actions x entities can only
    apply every action to every entity - asking for "add" there would grant add_correspondent too.
    """
    entities = user.get("entities", config["permission_entities"])
    granted = {f"{action}_{entity}" for action in user["actions"] for entity in entities}
    return sorted(granted | set(config["permission_baseline"]) | set(user.get("extra", [])))


def ensure_users(api, config):
    existing = {user["username"]: user for user in api.list_all("/api/users/")}

    for spec in config["permission_users"]:
        username = spec["username"]
        wanted = {
            "is_superuser": spec.get("is_superuser", False),
            "is_staff": False,
            "is_active": True,
            "user_permissions": permissions_for(spec, config),
        }
        current = existing.get(username)

        if current is None:
            # The password only goes over the wire on create. A PATCH carrying it would re-hash an
            # unchanged password on every run and make a no-op seed look like it did work.
            api.request(
                "POST",
                "/api/users/",
                {"username": username, "password": config["permission_password"], **wanted},
            )
            print(f"  created user {username} ({len(wanted['user_permissions'])} permissions)")
            continue

        drift = {}
        for field, value in wanted.items():
            got = current.get(field)
            if field == "user_permissions":
                got = sorted(got or [])
            if got != value:
                drift[field] = value

        if drift:
            api.request("PATCH", f"/api/users/{current['id']}/", drift)
            print(f"  updated user {username}: {sorted(drift)}")


def verify(api, config):
    """Check the scenario users match the fixture. Returns a list of problems."""
    problems = []

    users = {user["username"]: user for user in api.list_all("/api/users/")}
    for spec in config["permission_users"]:
        username = spec["username"]
        user = users.get(username)
        if user is None:
            problems.append(f"permission_users: missing {username!r}")
            continue

        wanted = permissions_for(spec, config)
        got = sorted(user.get("user_permissions") or [])
        if got != wanted:
            missing = sorted(set(wanted) - set(got))
            extra = sorted(set(got) - set(wanted))
            problems.append(f"{username}: permissions missing={missing} unexpected={extra}")

        if user.get("is_superuser") != spec.get("is_superuser", False):
            problems.append(
                f"{username}: is_superuser is {user.get('is_superuser')!r}, "
                f"expected {spec.get('is_superuser', False)!r}"
            )

        # A deactivated user still appears here but cannot log in, which from inside the app looks
        # like a permission bug rather than a fixture one.
        if not user.get("is_active"):
            problems.append(f"{username}: is_active is False, so the scenario cannot be logged in")

    # See EMPTY_BY_DESIGN_PATH: an invariant rather than a starting state, because a stray create
    # would remove the only place the empty-list create button can be seen.
    empty_by_design = api.list_all(EMPTY_BY_DESIGN_PATH)
    if empty_by_design:
        problems.append(
            f"{EMPTY_BY_DESIGN_PATH}: must stay empty so the empty-list create button is reachable, "
            f"but found {sorted(item['name'] for item in empty_by_design)}"
        )

    return problems


def print_scenarios(config):
    print("\nPermission scenarios (one password for all, see permission_password):\n")
    for spec in config["permission_users"]:
        print(f"  {spec['username']}")
        print(f"    {spec['expect']}")
