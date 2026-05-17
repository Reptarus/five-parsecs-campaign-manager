# Phase 1 Prep — TaloAnalyticsAdapter Design + Skeleton

**Owner**: Engineering (Elijah)
**Created**: 2026-05-01 (Phase 0.5 of workback)
**For**: P1.T3 + P1.T4 tasks — implement Mon May 4 → Tue May 5
**Target file**: `src/core/analytics/TaloAnalyticsAdapter.gd` (new)
**Depends on**: P1.T1 (Talo plugin installed), P1.T3 (`CampaignAnalytics` autoloaded), `LegalConsentManager` (already autoloaded)

**Purpose**: Captured design + reference skeleton for the adapter that bridges in-memory `CampaignAnalytics` events to the Talo SDK, gated on user consent. Pre-staged so Mon May 4 engineering work starts from a designed shape, not a blank file.

---

## Design

### Component diagram

```
                                           ┌─────────────────────────┐
                                           │  Talo dashboard         │
                                           │  (trytalo.com)          │
                                           └────────────▲────────────┘
                                                        │  HTTPS batched
                                                        │
                                           ┌────────────┴────────────┐
                                           │   Talo plugin           │
                                           │   (autoloaded by plugin)│
                                           │   API: Talo.events.track│
                                           └────────────▲────────────┘
                                                        │
                                                        │  forward (only if consent)
                                                        │
┌─────────────────┐ phase_start          ┌──────────────┴────────────┐
│ Game systems    │─────────────────────▶│ CampaignAnalytics         │
│ (campaign,      │ feature_used         │ (autoloaded, in-memory)   │
│ battles, ui,    │─────────────────────▶│ - phase_times             │
│ etc.)           │ validation_error     │ - validation_errors       │
│                 │─────────────────────▶│ - feature_usage           │
└─────────────────┘                      │ - user_interactions       │
                                         │ signal:                   │
                                         │   analytics_event_recorded│──┐
                                         └───────────────────────────┘  │
                                                                        │
                              ┌─────────────────────────────────────────┘
                              ▼
                  ┌───────────────────────┐
                  │ TaloAnalyticsAdapter  │  reads consent from:
                  │ (autoloaded, NEW)     │
                  │ - listens to signal   │     ┌─────────────────────────────┐
                  │ - gates on consent    │────▶│ LegalConsentManager         │
                  │ - flattens payload    │     │ analytics_consent: bool     │
                  │ - forwards to Talo    │     │ signal: consent_updated     │
                  └───────────────────────┘     └─────────────────────────────┘
```

### Responsibilities (single-purpose adapter)

The adapter does ONLY these things:

1. Subscribes to `CampaignAnalytics.analytics_event_recorded(event_type, data)` at `_ready()`
2. On each event, checks `LegalConsentManager.get_analytics_consent()` — if false, drops the event
3. If true, calls `Talo.events.track(event_type, _flatten_payload(data))`
4. Listens to `LegalConsentManager.consent_updated` signal — when consent toggles OFF mid-session, no special action (gate naturally drops future events); when ON, future events flow
5. Calls `Talo.events.flush()` on `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` to ensure final batch flushes (Talo plugin auto-flushes on focus loss/close, but explicit flush is safer)

The adapter does NOT:

- Add new tracking events (CampaignAnalytics owns event sources)
- Modify event names or schemas (forwards as-is, except payload flattening)
- Persist events locally (Talo handles that internally; if needed, fallback queueing is a separate component)
- Send PII (CampaignAnalytics doesn't track PII; adapter doesn't add any)
- Track user identity (anonymous-by-default per Talo + per privacy policy)

### Why this shape

- **Single Responsibility**: adapter is the consent gate + transport bridge, nothing else
- **Replaceable**: if Talo is replaced (GameAnalytics, custom HTTPS endpoint, JSON file dump), only this file changes
- **Testable**: can be tested by mocking `LegalConsentManager.get_analytics_consent` + spying on `Talo.events.track` calls
- **Disable-fast**: if anything goes wrong with telemetry, removing this autoload from `project.godot` disables all Talo traffic without removing the in-memory analytics layer (CampaignAnalytics keeps working)

### Consent gate semantics

| `analytics_consent` state | Behavior |
|---|---|
| `false` (default) | Adapter receives events but drops them silently. CampaignAnalytics keeps tracking in-memory (game-internal use unaffected). Talo dashboard receives nothing. |
| `true` | Adapter forwards every event to Talo with anonymous session UUID + auto-metadata (OS, version, window mode, resolution). |
| Toggle false → true mid-session | Future events flow. **Past events from before toggle do NOT flow** (no retroactive send). |
| Toggle true → false mid-session | Future events drop. Past events already sent to Talo cannot be recalled (per Talo terms — but no PII is in them anyway). |

This semantics matches alpha-1 requirement Scenario 12 acceptance.

### Payload flattening

Talo docs explicitly show string keys + scalar values. Some `CampaignAnalytics` events emit nested Dictionaries (e.g., phase data with `{phase, attempt}`). To be safe, flatten nested dicts to dot-notation keys:

```
{
  "phase": "campaign_creation",
  "details": {"step": 3, "attempts": 1}
}
```

→

```
{
  "phase": "campaign_creation",
  "details.step": 3,
  "details.attempts": 1
}
```

If Talo accepts nested dicts (un-tested in docs), flattening is a no-op at the adapter level — safe to keep.

### Anonymous session UUID

CampaignAnalytics already generates `session_id` on `_init()`:

```gdscript
func _generate_session_id() -> String:
    var timestamp = Time.get_unix_time_from_system()
    var random_suffix = randi() % 10000
    return "session_%d_%04d" % [timestamp, random_suffix]
```

This is anonymous (no machine ID, no user ID, no PII). The adapter passes this through to Talo as one of the event properties.

**Improvement opportunity (not blocking)**: replace with a more entropic UUID4 to reduce collision risk in long-running cohorts. CampaignAnalytics is the canonical source of session ID — adapter doesn't generate its own.

---

## Skeleton (paste-ready, ~80 lines)

```gdscript
extends Node

## TaloAnalyticsAdapter - bridges CampaignAnalytics to Talo SDK with consent gating.
##
## Listens to CampaignAnalytics.analytics_event_recorded and forwards to Talo
## ONLY when LegalConsentManager.analytics_consent is true.
##
## See docs/testing/phase-1-prep/TALO_ADAPTER_DESIGN.md for full design rationale.
## See docs/testing/QA_INTEGRATION_SCENARIOS.md S12 for verification scenarios.

const FORCE_FLUSH_ON_QUIT := true

## Set to true during dev/QA to log every forwarded event to console.
const DEBUG_LOG_EVENTS := false


func _ready() -> void:
    var ca = get_node_or_null("/root/CampaignAnalytics")
    if not ca:
        push_warning("TaloAnalyticsAdapter: CampaignAnalytics autoload not found; adapter inactive")
        return

    if not ca.has_signal("analytics_event_recorded"):
        push_warning("TaloAnalyticsAdapter: CampaignAnalytics missing 'analytics_event_recorded' signal")
        return

    ca.analytics_event_recorded.connect(_on_analytics_event)

    if DEBUG_LOG_EVENTS:
        print("TaloAnalyticsAdapter: connected to CampaignAnalytics.analytics_event_recorded")


func _notification(what: int) -> void:
    if not FORCE_FLUSH_ON_QUIT:
        return
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
        if Engine.has_singleton("Talo"):
            var talo = Engine.get_singleton("Talo")
            if talo and talo.has_method("events") and talo.events.has_method("flush"):
                talo.events.flush()


func _on_analytics_event(event_type: String, data: Dictionary) -> void:
    # Privacy gate — drop event silently if user has not opted in
    if not _consent_granted():
        return

    if not _talo_ready():
        if DEBUG_LOG_EVENTS:
            push_warning("TaloAnalyticsAdapter: Talo not ready; event dropped: %s" % event_type)
        return

    var payload := _flatten_payload(data)
    var ca = get_node_or_null("/root/CampaignAnalytics")
    if ca and ca.session_data.has("session_id"):
        payload["session_id"] = ca.session_data["session_id"]

    Talo.events.track(event_type, payload)

    if DEBUG_LOG_EVENTS:
        print("TaloAnalyticsAdapter: forwarded event '%s' with %d properties" % [event_type, payload.size()])


# --- Internal helpers ---

func _consent_granted() -> bool:
    var lcm = get_node_or_null("/root/LegalConsentManager")
    if not lcm:
        return false
    if not lcm.has_method("get_analytics_consent"):
        return false
    return lcm.get_analytics_consent()


func _talo_ready() -> bool:
    if not Engine.has_singleton("Talo"):
        return false
    return Talo != null and Talo.events != null


func _flatten_payload(data: Dictionary, prefix: String = "") -> Dictionary:
    var out := {}
    for key in data.keys():
        var k = str(key)
        var k_full = prefix + k if prefix.is_empty() else prefix + "." + k
        var value = data[key]
        if value is Dictionary:
            var sub = _flatten_payload(value, k_full)
            for sk in sub.keys():
                out[sk] = sub[sk]
        elif value is Array:
            # Talo accepts scalars; arrays serialized to comma-joined string
            out[k_full] = ", ".join(value.map(func(v): return str(v)))
        else:
            out[k_full] = value
    return out
```

### What's NOT in the skeleton (deliberate omissions)

- **No retry / backoff logic**: Talo SDK handles batching internally. If we hit rate limits or Talo is down, events queue locally per Talo's design, not ours.
- **No event filtering by name**: Adapter forwards every event CampaignAnalytics emits. Filtering happens upstream (CampaignAnalytics), not at the bridge.
- **No PII scrubbing**: CampaignAnalytics is the trust boundary — it must not emit PII. Adapter assumes upstream is correct. (S12 acceptance verifies the assumption.)
- **No fallback queue to disk**: If we want resilience for offline sessions, that's a separate `OfflineEventQueue.gd` — out of scope for alpha-1 first cut.
- **No identify() call**: Talo supports `Talo.players.identify()` for known users — alpha-1 uses anonymous sessions only. Add later if/when we want returning-tester analytics across sessions.

---

## Test plan (S12 from QA_INTEGRATION_SCENARIOS.md)

| Test | Verification | Linked TC |
|---|---|---|
| Default-OFF gate enforcement | Trigger 5 events with consent=false → Talo dashboard shows zero | TC-TELEMETRY-001 |
| Opt-in via Settings | Toggle ON → trigger events → Talo receives them within 60s | TC-TELEMETRY-002 |
| Mid-session opt-out | Toggle OFF mid-play → no further events reach Talo for that session_id | TC-TELEMETRY-003 |
| Anonymous session UUID | Inspect 10 events on Talo → no PII (no name/email/IP/save-content) | TC-TELEMETRY-004 |
| Session ID consistency | All events from one game session share the same session_id property | TC-TELEMETRY-005 |
| Force-flush on close | Close app → Talo dashboard receives final batched events within ~10s | TC-TELEMETRY-006 |

---

## Integration into project.godot autoload (per workback P1.T4)

After installing Talo plugin (P1.T1) and promoting CampaignAnalytics to autoload (P1.T3), append the adapter to the autoload list. **Order matters**:

```ini
[autoload]
# ... (existing autoloads, including LegalConsentManager) ...
LegalConsentManager="*res://src/core/legal/LegalConsentManager.gd"
TweenFX="*uid://d2n10rw2dnx8o"

# NEW for alpha-1 — order: CampaignAnalytics BEFORE TaloAnalyticsAdapter
CampaignAnalytics="*res://src/core/analytics/CampaignAnalytics.gd"
TaloAnalyticsAdapter="*res://src/core/analytics/TaloAnalyticsAdapter.gd"
```

`Talo` itself is registered automatically by the Talo plugin's `plugin.cfg`, so it parses before user autoloads.

---

## Headless verification (Mon-Tue May 4-5)

```bash
"C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" --headless --quit --path "c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager" 2>&1
```

**Pass criteria** (P1.T4 acceptance):

- 0 compile errors
- No "TaloAnalyticsAdapter: CampaignAnalytics autoload not found" warnings
- No "Class hides an autoload singleton" warnings (would indicate name collision)
- No `Talo not ready` warnings on first run (means Talo plugin loaded before adapter)

**Smoke test**: in editor, set `DEBUG_LOG_EVENTS = true` temporarily, run a campaign turn → console shows "forwarded event" lines IF analytics_consent is on. Revert constant before commit.

---

## Risk register (adapter-specific)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Adapter loads before CampaignAnalytics (init order bug) | Low | Med | Defensive `get_node_or_null` + warning; autoload order is explicit |
| Adapter loads before LegalConsentManager | Low | High (consent gate fails open) | Same defensive check; LegalConsentManager is registered first in autoload list |
| Talo singleton not present when adapter tries to forward | Low | Low | `Engine.has_singleton("Talo")` check before each forward; fail-silent |
| Nested-dict payload causes Talo to reject event | Low | Low | `_flatten_payload` always converts to flat key/value |
| Consent gate fail-open due to LegalConsentManager bug | Low | High (PII risk) | S12 test scenario explicitly verifies Talo receives nothing when consent OFF |
| `Talo.events.flush()` API changes between plugin versions | Low | Low | Defensive `has_method("flush")` check before call; pinned to v0.45.0 anyway |

---

## Future scope (post-alpha-1 — NOT in P1.T4)

- **Returning-tester identification**: `Talo.players.identify()` for cross-session retention metrics in beta
- **Event filtering / sampling**: if event volume gets noisy, downsample at adapter (e.g., only forward 10% of phase_started events)
- **Offline queue**: persistent backup queue if Talo is unreachable; flush on next online launch
- **Custom session metadata**: build version, OS locale, accessibility settings (already auto-attached by Talo per docs)

These are explicitly OUT of scope for alpha-1 to keep the adapter minimal.

---

*Doc v1, 2026-05-01. Move to `docs/technical/TALO_ADAPTER.md` (long-lived reference) after P1.T4 is verified, OR archive entire `phase-1-prep/` folder if these notes are no longer needed post-implementation.*
