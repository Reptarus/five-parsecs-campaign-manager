# Phase 1 Prep — Talo Godot Plugin Install Notes

**Owner**: Engineering (Elijah)
**Created**: 2026-05-01 (Phase 0.5 of workback)
**For**: P1.T1 task — execute Mon May 4 morning
**Source of truth**: `https://docs.trytalo.com/docs/godot/install` + `https://docs.trytalo.com/docs/godot/events`

**Purpose**: Pre-staged install notes so Mon May 4 engineering work doesn't burn time on research. Verified install steps + quirks + integration design captured here.

---

## What Talo provides (re-confirmation)

- **Native Godot 4 plugin** (no NativeLib dependency, unlike GameAnalytics)
- **Anonymous-by-default** — no PII required to track events
- **Open-source** — `TaloDev/godot` on GitHub
- **Latest version (Apr 4, 2026)**: 0.45.0
- **Auto-metadata appended to every event**: OS, game version, window mode, resolution
- **Batched event sending** (auto-flushes on focus loss / pause / close; manual flush via `Talo.events.flush()`)

---

## Pre-install checklist (do BEFORE Mon May 4)

| # | Task | Status |
|---|---|---|
| 1 | Create Talo account at trytalo.com | ⏳ Mon May 4 |
| 2 | Create new game in Talo dashboard: name "5PFH Digital Alpha", platform "Windows" | ⏳ Mon May 4 |
| 3 | Generate access key with scopes `read:players` + `write:players` | ⏳ Mon May 4 |
| 4 | Save access key securely (1Password / `.env.local` — DO NOT commit) | ⏳ Mon May 4 |
| 5 | Note Talo dashboard URL for the alpha project for reference in execution reports | ⏳ Mon May 4 |

---

## Install steps (Mon May 4 morning, ~15 min)

### Step 1 — Download the plugin

**Option A (recommended)**: From Godot Editor

1. Open project in Godot 4.6
2. AssetLib tab → search "Talo"
3. Download + install — places files in `addons/talo/`

**Option B (manual)**: From itch.io or GitHub

1. `https://trytalodev.itch.io/talo` or `https://github.com/TaloDev/godot/releases/tag/0.45.0`
2. Download .zip, extract `addons/talo/` into project root

**Option C (manual git)**:

```bash
cd "c:/Users/admin/SynologyDrive/Godot/five-parsecs-campaign-manager"
# Talo plugin .zip extraction; do not git submodule (we vendor it)
```

### Step 2 — Enable the plugin

1. Project → Project Settings → Plugins tab
2. Find "Talo" — enable
3. Restart editor (recommended; some users report autoload registration requires restart)

### Step 3 — Configure access key (DO NOT commit)

The plugin auto-creates `addons/talo/settings.cfg` on first run. Edit it manually:

```ini
access_key="<paste-key-from-step-3-above>"
api_url="https://api.trytalo.com"
socket_url="wss://api.trytalo.com"

[logging]
requests=true
responses=true
```

**CRITICAL**: add to `.gitignore`:

```
# Talo plugin local config (contains access key)
addons/talo/settings.cfg
```

Then commit a `.env.example` (or `addons/talo/settings.cfg.example`) that documents the schema without the real key:

```ini
access_key=""
api_url="https://api.trytalo.com"
socket_url="wss://api.trytalo.com"

[logging]
requests=true
responses=true
```

### Step 4 — Headless verify

```bash
"C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" --headless --quit --path "c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager" 2>&1
```

**Pass**: 0 errors, 0 new warnings beyond pre-Talo baseline.
**Fail action**: capture stderr; check addons/talo/plugin.cfg loaded; ensure plugin is enabled in `[editor_plugins]` section of project.godot.

### Step 5 — Smoke test API

In a debug build, attach to any button or run via `run_script`:

```gdscript
# Verify Talo client is reachable
Talo.events.track("alpha_install_smoke_test", {
    "test": 1,
    "build": "v0.9.7-alpha1.A0-prep"
})
```

Wait ~30 seconds for batched flush, then check Talo dashboard → Events tab. If the event appears, install is verified.

---

## API used by `TaloAnalyticsAdapter.gd` (per `TALO_ADAPTER_DESIGN.md`)

```gdscript
# Send a custom event (batched, auto-flush on app close/pause)
Talo.events.track(event_name: String, properties: Dictionary)

# Force flush (only used for critical events near app shutdown)
Talo.events.flush()
```

**Constraints observed in docs**:

- Property keys + values: strings + numbers documented; nested dicts NOT confirmed → flatten if needed
- No explicit naming conventions — we'll snake_case event names by convention
- Auto-metadata is appended (OS, game version, window mode, resolution) — we don't need to add these manually

---

## .gitignore additions required

Add these lines to `.gitignore` Mon May 4:

```
# Talo plugin
addons/talo/settings.cfg

# Project-local secrets
.env.local
```

Commit `.env.example` (template) but never `.env.local` (real values).

---

## Project.godot autoload changes (Mon May 4)

After install + enable + config, two autoload entries are added (per workback P1.T3 + P1.T4):

```ini
[autoload]
# ... existing autoloads ...
LegalConsentManager="*res://src/core/legal/LegalConsentManager.gd"
TweenFX="*uid://d2n10rw2dnx8o"

# NEW for alpha-1
CampaignAnalytics="*res://src/core/analytics/CampaignAnalytics.gd"
TaloAnalyticsAdapter="*res://src/core/analytics/TaloAnalyticsAdapter.gd"
```

**Order matters**: TaloAnalyticsAdapter MUST be after `LegalConsentManager` AND `CampaignAnalytics` because it depends on both. Talo's own autoload (`Talo`) is registered automatically by the plugin enable step and parses before custom autoloads.

---

## Privacy / consent integration (covered in adapter design doc)

Talo's plugin does NOT have built-in consent gating — by design, it tracks events when called. The privacy gate lives in our adapter:

```gdscript
# Pseudocode (full design in TALO_ADAPTER_DESIGN.md)
func _on_analytics_event(event_type: String, data: Dictionary) -> void:
    if not LegalConsentManager.get_analytics_consent():
        return  # gate enforced here
    Talo.events.track(event_type, _flatten_payload(data))
```

This means `analytics_consent == false` → Talo never receives events for that session.

---

## Risk register (Talo-specific)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Plugin registration fails after enable (Godot 4.6 quirk) | Low | Low | Editor restart; verify project.godot `[editor_plugins]` section |
| Access key accidentally committed | Low | High | `.gitignore` addition + pre-commit check; rotate key if leaked |
| Talo API rate limit during heavy alpha activity | Low | Low | Auto-batching handles this; monitor Talo dashboard for 429s |
| Talo service downtime | Low | Low | Events queue locally + batch on reconnect; offline play unaffected |
| Plugin update during cycle introduces breaking changes | Low | Low | Pin to v0.45.0; do not auto-update during alpha cycle |

---

## Post-install reporting

After P1.T1 + P1.T2 + P1.T3 + P1.T4 land, append to `docs/testing/DEFECTS_LOG.md` per-build trend table that telemetry pipeline is operational, and to `docs/MEETING_FOLLOWUPS_2026-04-29.md` §5 ("What I'm Sending Separately") that telemetry is wired.

---

## API Drift (May 2026 — verified post-install on 2026-05-06)

Recorded per Phase 0.6 C.T1 acceptance criterion ("verify current API surface matches adapter assumptions OR document drift"). Plugin installed at v0.45.0 via Godot AssetLib. These are the deltas vs the April 2026 research captured above.

### Settings.cfg schema — additions (no breaking changes)

The plugin's auto-generated `addons/talo/settings.cfg` includes these top-level keys that the April notes did not capture:

| Key | Default | Purpose |
|---|---|---|
| `auto_connect_socket` | `true` | If true, Talo connects to its WebSocket on game start (only matters for realtime features — not used in alpha-1) |
| `handle_tree_quit` | `true` | If true, Talo intercepts quit-request to flush events before exit (good for us — keep default) |
| `cache_player_on_identify` | `true` | If true, cached player data persists for offline-mode use cases (irrelevant for alpha-1) |
| `debounce_timer_seconds` | `1.0` | Network request debounce window (per-second batching; keep default) |
| `[continuity] enabled` | `true` | If true, Talo auto-replays failed network requests (use this — replaces hand-rolled retry) |
| `[player_auth] auto_start_session` | `true` | Auto-resume session if a valid session token is found (irrelevant — we don't use player_auth) |

**Action**: leave all defaults as the plugin generates them. Only `access_key` needs manual fill-in.

### `[logging]` section — clarification

April notes said `[logging] requests=true responses=true`. This is **opt-in**, not default — the plugin doesn't auto-create the `[logging]` section. Add it manually if you want HTTP request/response noise in the Godot console for debugging.

### Events API — the identity-check gap (NOT in April notes — IMPORTANT)

`addons/talo/apis/events_api.gd:43` does an early-return identity check on every `Talo.events.track()` call:

```gdscript
func track(name: String, props: Dictionary[String, String] = {}) -> void:
    if Talo.identity_check() != OK:
        return  # events drop SILENTLY here if no player identified
```

This means: **events.track() does NOT auto-identify; it silently drops events when no player is identified**. The April research did not capture this requirement.

**Implication for our adapter**: TaloAnalyticsAdapter must call `Talo.players.identify(service, identifier)` before forwarding events, OR events fire into the void with no error indication.

**Resolution baked into adapter** (Phase 0.6 C.T4 update, 2026-05-06):

- Adapter generates a stable per-install anonymous identifier on first consent grant
- Identifier persisted to `user://talo_anonymous_id.cfg`
- `Talo.players.identify("username", anon_id)` called lazily on first event after consent
- Identity cleared + identifier file deleted on consent revocation (full GDPR teardown)
- See `src/core/analytics/TaloAnalyticsAdapter.gd` `_identify_async()` and `_clear_identity_and_delete_id()` methods

### Required scopes for the access key — corrected from April notes

April notes said: `read:players + write:players`. Verified on the dashboard (2026-05-06) that this is correct AND insufficient — also need `write:events` (and optionally `read:events`).

Final scope set for alpha-1 access key:

- ✅ `read:players` (required by identity_check)
- ✅ `write:players` (required to create the anonymous player on first identify)
- ✅ `write:events` (required by events.track to actually POST events)
- ✅ `read:events` (optional — useful for dashboard query / verification)
- ❌ All others (Player Presence, Player Groups, Channels, Game Stats, Game Saves, Leaderboards, Game Feedback, Game Config, Player Relationships, Player Broadcasts, Continuity Requests) — not needed for alpha-1; principle of least privilege

### Identifier service choice

`Talo.players.identify(service, identifier)` requires both. Options seen in `addons/talo/apis/players_api.gd`:

- `"username"` — generic, accepts any string identifier (this is what we use)
- `"steam"` — Steam ticket-based (alpha-1 doesn't use Steam)
- `"google_play_games"` — Google Play auth code (mobile-only, irrelevant)

The `"username"` service paired with our random hex identifier gives Talo an opaque per-install player record with no PII linkage.

### No breaking changes detected

The core API surfaces our adapter touches (`Talo.events.track`, `Talo.players.identify`, `Talo.players.clear_identity`) all match the April research signatures. The drift is additive (new config options) plus one critical-but-implicit semantic (identity_check requirement) that the April notes glossed over. Adapter design verified compatible.

---

*Doc v1, 2026-05-01. API Drift section appended 2026-05-06. To be archived after P1.T1 verification, or moved to `docs/technical/TALO_INTEGRATION.md` if it becomes long-lived reference material.*
