"""
Privacy lint: the Talo plugin must not make network calls before the user has
granted analytics consent.

WHY THIS LINT EXISTS AT ALL

`addons/talo/settings.cfg` is gitignored (it carries the access key), but
`addons/talo/talo_export.gd:7-8` FORCE-INCLUDES it into every export via
add_file(). So the file that controls boot-time network behaviour is untracked
yet always shipped: whatever happens to be on the packaging machine is what
reaches testers, with nothing in version control recording the decision. A
correct value on one dev's disk is not a fix, it is a coincidence. This lint is
the tracked half.

WHAT IT ENFORCES

  auto_connect_socket = false
      talo_socket.open_connection() does an HTTPS POST to create a socket ticket
      (authenticated with the access key) and then a WSS connect, unconditionally,
      from Talo._ready(). No player identity is attached, but the tester's IP
      reaches a third-party analytics host before the consent screen. Nothing in
      src/ uses the socket: the project touches only Talo.events and Talo.players,
      and events_api.track() is HTTP-queued, not socket-borne. So this is pure
      cost with no feature behind it.

  auto_start_session = false
      player_auth.start_session() calls Talo.players.identify("talo", ...) on a
      restored session. TaloAnalyticsAdapter owns identity in this project via its
      own anonymous-ID scheme (identify(IDENTIFY_SERVICE, anon_id), granted only
      on consent). Leaving auto_start_session on gives Talo a SECOND, competing
      identity path that bypasses the adapter's consent gate.

The event path itself is already correctly gated and is not this lint's concern:
TaloAnalyticsAdapter._on_analytics_event() checks LegalConsentManager, and
events_api.track() early-returns unless identity_check() == OK.

A missing settings.cfg is CLEAN, not a failure: a fresh checkout legitimately has
no config, and the plugin is inert without one.

Mirrors scripts/lint_data_ownership.py conventions (stdlib-only, exit 0/1).

Run: py scripts/lint_talo_config.py
"""

import os
import re
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_PATH = os.path.join(PROJECT_ROOT, "addons", "talo", "settings.cfg")
EXPORT_PLUGIN = os.path.join(PROJECT_ROOT, "addons", "talo", "talo_export.gd")

# key -> (required value, why)
REQUIRED = {
    "auto_connect_socket": (
        "false",
        "opens an authenticated HTTPS + WSS connection to the Talo host from "
        "Talo._ready(), before the consent screen. Nothing in src/ uses the socket.",
    ),
    "auto_start_session": (
        "false",
        "start_session() calls Talo.players.identify() directly, a second identity "
        "path that bypasses TaloAnalyticsAdapter's consent gate.",
    ),
}


def read_settings(path):
    """Return {key: raw_value} for top-level and sectioned keys alike.

    Deliberately does not use configparser: the value we care about may live under
    a [section] and we only ever compare against literal true/false, so a flat
    key scan is both sufficient and immune to Godot's ConfigFile quirks.
    """
    found = {}
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for lineno, line in enumerate(fh, 1):
            stripped = line.strip()
            if not stripped or stripped.startswith((";", "#", "[")):
                continue
            match = re.match(r'^([A-Za-z0-9_]+)\s*=\s*(.+?)\s*$', stripped)
            if match:
                found[match.group(1)] = (match.group(2).strip('"'), lineno)
    return found


EXPORT_PRESETS = os.path.join(PROJECT_ROOT, "export_presets.cfg")

# Files under addons/talo/ that must NEVER reach a build, with the reason.
# settings.cfg itself is exempt: the runtime needs it and talo_export.gd
# force-includes it regardless of any filter.
MUST_NOT_SHIP = {
    "settings.example.cfg":
        "its header comments are a written index of this build's own weak points — "
        "they name the plaintext JWT, state that it is extractable from the APK, and "
        "point at the Discord webhook in support_config.cfg. Shipping it hands a "
        "reader the map.",
    "samples/":
        "144 files of Talo demo scenes (chat, friends list, leaderboards, playground) "
        "that no game code references. Pure weight and extra surface.",
}


def check_export_filters():
    """Flag export filters that sweep more of addons/talo/ than the runtime needs.

    THE BUG THIS EXISTS TO PREVENT (Jul 27 2026): include_filter was
    "data/*, addons/talo/*.cfg". The `*.cfg` glob is wider than it looks — it packed
    settings.example.cfg and plugin.cfg alongside the one file the runtime reads.
    Verified by unzipping the AAB. Narrow it to the exact file.
    """
    out = []
    if not os.path.exists(EXPORT_PRESETS):
        return out
    with open(EXPORT_PRESETS, "r", encoding="utf-8", errors="replace") as fh:
        lines = fh.readlines()

    for lineno, line in enumerate(lines, 1):
        stripped = line.strip()
        if not stripped.startswith("include_filter="):
            continue
        if "addons/talo/*" in stripped or "addons/talo/*.cfg" in stripped:
            out.append((
                lineno,
                "export_presets.cfg include_filter uses a WILDCARD over addons/talo/. "
                "That sweeps settings.example.cfg and plugin.cfg into the build along "
                "with the one file the runtime needs. Use 'addons/talo/settings.cfg'.",
            ))
    return out


def main():
    findings = []

    if not os.path.exists(CONFIG_PATH):
        # A clean checkout has no settings.cfg. The plugin is inert; nothing ships.
        print("lint_talo_config: CLEAN (no addons/talo/settings.cfg present)")
        return 0

    settings = read_settings(CONFIG_PATH)

    for key, (required_value, why) in REQUIRED.items():
        if key not in settings:
            # Absent means the plugin default applies. Talo defaults both to true,
            # so absence is as unsafe as an explicit true.
            findings.append(
                (0, f"'{key}' is not set. The plugin default is true, which {why} "
                    f"Set '{key}={required_value}' explicitly.")
            )
            continue
        actual, lineno = settings[key]
        if actual.lower() != required_value:
            findings.append(
                (lineno, f"'{key}={actual}' must be '{required_value}'. It {why}")
            )

    # The force-include is what makes a local-only value ship. If that ever stops
    # being true this lint's premise changes, so surface it rather than assume it.
    if os.path.exists(EXPORT_PLUGIN):
        with open(EXPORT_PLUGIN, "r", encoding="utf-8", errors="replace") as fh:
            if "settings.cfg" not in fh.read():
                print("lint_talo_config: NOTE — talo_export.gd no longer force-includes "
                      "settings.cfg; re-check whether this lint is still needed.")

    findings.extend(check_export_filters())

    if not findings:
        print("lint_talo_config: CLEAN (0 findings)")
        return 0

    print(f"lint_talo_config: {len(findings)} finding(s)\n")
    for lineno, message in findings:
        location = f"addons/talo/settings.cfg:{lineno}" if lineno else "addons/talo/settings.cfg"
        print(f"  {location}: {message}")
    print("\n  Note: settings.cfg is gitignored but force-included in every export "
          "(talo_export.gd:7-8), so this value ships exactly as it sits on disk.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
