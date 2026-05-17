# Defects Log — 5PFH Digital

**Owner**: QA (Elijah Rhyne)
**Created**: 2026-05-01
**Last Updated**: 2026-05-08 (numbering anchor added 2026-05-05; pre-cohort baseline; refresh for polished-version send)

**Purpose**: Single canonical source of truth for all defects (bugs) across 5PFH Digital test cycles. Lives at `docs/testing/DEFECTS_LOG.md` and updated in real-time as bugs are filed, triaged, fixed, and verified.

**Companion**: `docs/testing/templates/BUG_REPORT_TEMPLATE.md` (full formal report format for high-severity bugs).

**Next available bug ID**: **BUG-107** (BUG-100..BUG-106 filed 2026-05-16, pre-alpha battle-UI sweep).

**Numbering history** (for reference when interpreting historical references):

- **BUG-001 through BUG-035** were assigned during pre-alpha QA sprints (Sessions 30-45). Some IDs (notably BUG-035) collided across separate sprint logs; canonical references in `docs/testing/DEMO_QA_SCRIPT.md` win for the historical numbering.
- **BUG-036 through BUG-098** are reserved for any further pre-alpha entries that surface as we audit historical logs.
- **BUG-099** was renumbered from a colliding BUG-035 entry in `UIUX_TEST_RESULTS.md` (Bug Hunt Cancel button, 2026-05-05).
- **BUG-100 onward** is alpha cycle and beyond — file new entries starting here.

---

## How to use this log

### When a bug is filed

1. **Discord intake** (lightweight) → tester posts in `#5pfh-alpha-bugs` using the pinned template
2. **Promote to formal entry** within 24h (P0/P1) or 1 week (P2/P3): add a row to the appropriate severity table below
3. **Complex bugs** (multi-stakeholder, partner-shareable, need extended triage notes) → also create a standalone file at `docs/testing/bug-reports/BUG-<NNN>-<slug>.md` using the full template

### When a bug is triaged

- Set Status → Triaged
- Assign owner
- Set Priority (Immediate / This Build / Next Build / Backlog)

### When a bug is fixed

- Set Status → Fixed
- Fill "Fixed in Build" + "Fix Description" columns
- Hand to QA for verification

### When a bug is verified

- Set Status → Verified
- Fill "Verified Date" + "Verified Build"

### When a bug is closed for other reasons

- **Won't Fix** → fill Resolution column with rationale
- **Duplicate** → set "Duplicate Of" → BUG-NNN; archive entry

---

## Status Glossary

| Status | Meaning |
|---|---|
| New | Just filed; not yet triaged |
| Triaged | Severity + priority + owner assigned |
| In Progress | Engineer actively fixing |
| Fixed | Code change in latest build; pending QA verification |
| Verified | QA confirmed fix |
| Reopened | Verification failed or regression discovered |
| Won't Fix | Decision: not worth fixing this cycle |
| Duplicate | Same root cause as another bug — archive |

## Severity Glossary

| Tier | Definition |
|---|---|
| P0 | Game-breaking — crash, data loss, save corruption, complete inability to continue |
| P1 | Major UX — feature does not work as documented; major visual bug; blocks an action |
| P2 | Annoying — minor visual glitch, awkward flow, typo in important text |
| P3 | Cosmetic — typo elsewhere, polish suggestion, nice-to-have |

---

## Active Defects

### P0 — Game-Breaking

`<no active P0 — last cleared YYYY-MM-DD>`

| Bug ID | Title | Build Found | Status | Priority | Assigned | Fixed in Build | Verified Date | Notes |
|---|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | — | — |

### P1 — Major UX

| Bug ID | Title | Build Found | Status | Priority | Assigned | Fixed in Build | Verified Date | Notes |
|---|---|---|---|---|---|---|---|---|
| BUG-100 | Window does not fill a 4K display; launches windowed 1920x1080 (display mode never applied at boot) | v0.9.7-dev | Verified | This Build | engineer | v0.9.7-dev | 2026-05-16 | project.godot mode=2 default + GameState boot restore. MCP: project setting=2, saved window.ini mode=0 restored live at boot (never restored at launch before) |
| BUG-101 | Terrain shapes bleed outside the map (SVS draws body centered on rotated `offset`, not `position` — clamp protected the wrong point) | v0.9.7-dev | Verified | This Build | engineer | v0.9.7-dev | 2026-05-17 | RE-FIXED (05-16 verify was premature; user re-reported 3-10px residual bleed). True cause empirically isolated: back-solve `position = center - offset.rotated(rot)` + stroke envelope. MCP: 0 offenders / 316 shapes / 10 distinct seeds; objective-tracker 14/14 PASS |
| BUG-102 | First battle render clusters terrain top-left until Regenerate | v0.9.7-dev | Verified | This Build | engineer | v0.9.7-dev | 2026-05-16 | **Two causes. Reopened during cross-mode smoke when user spotted residual cluster — initial fix was incomplete.** (1) transform computed before layout → self-heal added. (2) **TRUE root cause:** `BattlefieldGridPanel._update_map_cell_size()` mutated `BattlefieldMapView.cell_size` (16→48) on resize AFTER terrain placement was baked in the old cell_size, so `_update_terrain_transform` `effective_cs/cell_size` scale was wrong → all terrain in top-left quadrant ("Regenerate fixed it" = re-bake at settled value). Fix: stopped mutating cell_size (it is the stable placement base; on-screen size is `_get_effective_cell_size()`). MCP re-verified: quadrant histogram TL28/TR0/BL0/BR0 → TL8/TR6/BL6/BR7, x/y span ~full, 0 OOB; screenshot D4 corner now populated |

### P2 — Annoying

| Bug ID | Title | Build Found | Status | Priority | Assigned | Fixed in Build | Verified Date | Notes |
|---|---|---|---|---|---|---|---|---|
| BUG-103 | Battlefield legend always shows all 12 terrain categories, not the mission's actual terrain | v0.9.7-dev | Verified | This Build | engineer | v0.9.7-dev | 2026-05-16 | Data-driven via populate(). MCP: 4 keys scatter-off / 5 scatter-on; screenshot legend = Building/Rock/Trees/Scatter/Notable only |
| BUG-104 | Battle Tools panel: 5 tools in an all-collapsed, unlabeled exclusive accordion (illegible) | v0.9.7-dev | Verified | This Build | engineer | v0.9.7-dev | 2026-05-16 | Subtitles + hint + open_section(0). Wiring check found+fixed 2 unwired tools (see BUG-106 list). gdUnit 18/18 no regression |
| BUG-105 | Hover tooltip + click popover list raw features that do not match shapes drawn in the cell | v0.9.7-dev | Verified | This Build | engineer | v0.9.7-dev | 2026-05-16 | Render-equivalent label source. MCP: scatter excluded (["LARGE: Rock"]) when hidden, included (["LARGE: Rock","Crates"]) when shown |

### P3 — Cosmetic

| Bug ID | Title | Build Found | Status | Priority | Assigned | Fixed in Build | Verified Date | Notes |
|---|---|---|---|---|---|---|---|---|
| BUG-106 | Tracking umbrella: battle-UI "lots of small things not fully wired" | v0.9.7-dev | Triaged | Backlog | qa-specialist | — | — | Not a single defect; sweep checklist below — promote each confirmed item to its own BUG-1xx |

---

## Detailed Entries — Pre-Alpha Battle-UI Sweep (2026-05-16)

Filed from a live 4K-monitor battle-mode session. Root causes code-verified (CLAUDE.md Agent
Search Accuracy Protocol). Plan: `C:\Users\admin\.claude\plans\i-want-you-to-eager-pebble.md`.

### BUG-100 — Window does not fill a 4K display; launches windowed 1920x1080

| Field | Value |
|---|---|
| Bug ID | BUG-100 |
| Title | Game launches windowed at 1920x1080 and does not fill a 4K monitor; saved display mode never applied at boot |
| Reported Date | 2026-05-16 |
| Build | v0.9.7-dev |
| Platform | Windows 11 (4K display) |
| Game Mode | All (boot-level; observed in battle) |
| Severity | P1 |
| Priority | This Build |
| Component / Area | Display / Window / Boot |
| Status | Verified (MCP runtime, 2026-05-16) |
| Assigned | engineer |
| Description | `project.godot` has no `window/size/mode`; viewport 1920x1080 with stretch `canvas_items`/`expand` (scaling config is correct). The live settings screen `SettingsScreen.gd` already has Godot-docs-blessed window restore in `_enter_tree()` (L95-121) replaying `user://window.ini`, but that is bound to the Settings screen's tree lifecycle and never runs at game boot (boot scene is MainMenu). `GameState` (autoload) loads `user://options.cfg` at boot but applies no display mode. So a first-run player on a 4K monitor gets a small windowed 1920x1080 frame. |
| Repro | (1) Fresh profile (no `user://window.ini`). (2) Launch on a 4K monitor. (3) Window is 1920x1080 windowed, does not fill the screen. (4) Even after setting Fullscreen in Settings and relaunching, boot does not restore it. |
| Expected | First run comes up Maximized/fills the display; a saved Fullscreen/window preference is restored at boot before MainMenu shows. |
| Actual | Always windowed 1920x1080 at boot regardless of monitor or saved preference. |
| Repro Rate | Always |
| Impact | Every screen on every high-DPI display; first impression for the alpha cohort. |
| Suspected root cause | No boot-time display-mode application; window-restore logic exists but only on the Settings screen lifecycle. |
| Fix description | (a) `project.godot` `[display] window/size/mode=3` (Maximized) first-run default. (b) Replay the `user://window.ini` block (screen/mode/position/size) in `GameState._ready()` (autoload boot hook; `_ready` so root `get_window()` exists), guarded `OS.has_feature("pc")` + `not Engine.is_editor_hint()`. Reuse `SettingsScreen._enter_tree()` restore as the reference. AppOptions.gd NOT modified (dead/conflicting schema on the same options.cfg — separate follow-up). |
| Files modified | `project.godot`, `src/core/state/GameState.gd` |
| Follow-up note | `AppOptions.gd` writes `graphics.fullscreen` into the same `user://options.cfg` that SettingsScreen uses with `[display] fullscreen` — a latent schema collision. Not fixed here; flag for a future cleanup bug. |

### BUG-101 — Terrain shapes bleed outside the map

| Field | Value |
|---|---|
| Bug ID | BUG-101 |
| Title | Battlefield terrain shapes generate outside the grid (bleed into the numbered axis margin) |
| Reported Date | 2026-05-16 |
| Build | v0.9.7-dev |
| Platform | Windows 11 (4K display) |
| Game Mode | Standard 5PFH battle (shared `BattlefieldMapView`, all modes) |
| Severity | P1 |
| Priority | This Build |
| Component / Area | Battlefield / Terrain Placement |
| Status | Verified (re-fixed; MCP runtime 2026-05-17). NOTE: first marked Verified 2026-05-16 prematurely — the rotated-AABB clamp was correct in concept but used the wrong position basis; user re-reported residual bleed, reopened, true root cause found by empirical measurement. |
| Assigned | engineer |
| Description | `_rebuild_terrain_shapes()` clamps the UNROTATED w x h rect to sector bounds, then applies random rotation. A first fix (2026-05-16) added a rotation-aware center clamp to the grid rect. It reduced gross overflow but residual 3-10px edge bleed remained on 3/31 shapes. Reopened on user report. |
| Repro | (1) Enter a battle. (2) Observe terrain near the corner/edge sectors. (3) Rotated shapes (esp. circles/ellipses) cross the numbered axis border by a few px. |
| Expected | All terrain (body + stroke) stays within the grid rectangle regardless of rotation. |
| Actual | Edge-sector rotated shapes bled 3-10px past the grid rect. |
| Repro Rate | Frequent (depends on RNG rotation + edge placement) |
| Impact | Misleads tabletop setup (terrain reads as off-table); visual-correctness defect on the core artifact. |
| TRUE root cause (empirically isolated 2026-05-17) | `ScalableVectorShape2D` draws the body centered on `offset` in LOCAL space, and `offset` is rotated by the node rotation. So the on-screen center is `position + offset.rotated(rot)`, NOT `position`. The 2026-05-16 fix set `svs.position = clamped_center` assuming `offset=(-w/2,-h/2)` cancelled out — true only at rotation 0. For a rotated shape the drawn center was displaced by `(-w/2,-h/2).rotated(rot)` (up to ~34px for a 48px shape), so the clamp protected the wrong point. Confirmed to the pixel by measuring `get_bounding_rect()` transformed by node transform vs the grid rect (offender @741, rot≈1°: predicted AABB == measured `[-9,305,56,39]` exactly). |
| Fix description | Back-solve `svs.position = clamped_center - offset.rotated(rot)` so the DRAWN center lands on the clamped point; add `stroke_width/2` to the clamp half-extent (the visible line width — "accommodate the width of the circle"). Geometry-only, zero new game values. |
| Verification | MCP empirical: same offender diagnostic that found 3 bleeders now reports 0; stress test across 10 genuinely-distinct seeds (distinct_fingerprints=10) = 0 offenders / 316 shapes / worst 0.0px; 3 fresh-seed screenshots show all terrain in-grid; `tests/unit/test_battle_objective_tracker.gd` 14/14 PASS (shared TacticalBattleUI, no regression). |
| Files modified | `src/ui/components/battle/BattlefieldMapView.gd` |

### BUG-106 — Battle-UI wiring sweep checklist

Tracking umbrella (P3). Not a single defect. Drive via `qa-specialist`; promote each confirmed
item to its own BUG-1xx entry:

- [x] Per-tool signal wiring at `TacticalBattleUI._connect_component_signals()` — **FOUND + FIXED 2026-05-16**: `CharacterQuickRollPanel.roll_completed` and `BrawlResolverPanel.brawl_resolved` were shown in the Tools accordion but never echoed to the unified log (the other 3 tools were wired). Wired both to `unified_log.log_action()` matching the existing pattern.
- [ ] Tier-gated component instantiation (BUG-044 follow-through) across LOG_ONLY / ASSISTED / FULL_ORACLE
- [ ] Accordion section liveness (no dead/empty sections shipped)
- [ ] Objective panel vs Regenerate parity (objective tracker survives terrain regenerate)
- [ ] Reference tab data population (cheat sheet + weapon table actually load)
- [ ] Quick dice bar always-visible behavior across tabs
- [ ] Cross-mode: same checks under Bug Hunt + Planetfall battle entry

### CLR-101 — Objective marker "stuck dead center" (Working As Intended + UX cite)

**Status**: WAI / Clarified + UX enhancement shipped 2026-05-17. **Not a defect** — does
not consume a BUG number.

| Field | Value |
|---|---|
| Reported as | User flagged the objective marker "still stuck in the dead center" alongside BUG-101 (same 4K battle screenshot). |
| Finding | **Rules-correct, verbatim.** Core Rules "Types of Objective" (p.90, verified against the rulebook PDF, not just the code comment): Access = "computer console in the **exact center of the battlefield**"; Acquire = "item...placed at the **center of the table**"; Secure = "within 2\" of the **center of the table**"; Deliver = "delivered to the **exact center of the table**". `BattlefieldGenerator.compute_objective_positions()` returns `Vector2(12,8)` (grid center) for these — exactly the tabletop rule. Non-center objectives (Patrol/Search/Eliminate/Fight Off/Defend/Move Through) correctly return no center marker. |
| Why not "fixed" | Moving the marker off-center would (a) violate the project data-integrity rule (inventing positions the book does not specify) and (b) make the companion app rules-INCORRECT. The whole purpose of the app is to mirror physical play accurately. |
| Resolution (user-chosen) | Keep position unchanged; make the marker *read* as deliberate. Added a `rule` provenance field at the data source (`_center_objective_rule()`, verbatim-faithful Core Rules p.90 wording per objective) + a 2-line marker render in `BattlefieldMapView._draw_objective_marker()` (`OBJECTIVE: [name]` + muted `Center of table (Core Rules p.90)`). Word-boundary truncation for long mission objective strings. Zero game-data change (grid_pos still `Vector2(12,8)` for all center types — MCP-verified across all 14 objective types). |
| Files modified | `src/core/battle/BattlefieldGenerator.gd`, `src/ui/components/battle/BattlefieldMapView.gd` |
| Verification | MCP: data layer — all 14 objective types return correct rule cite, grid_pos unchanged at center. Render layer — 2-line label + ellipsis screenshot-confirmed on 2 fresh seeds; `rule` propagates end-to-end through the live `TacticalBattleUI → GridPanel → MapView` wiring. |

---

## Closed / Archived Defects

(Bugs in Verified, Won't Fix, or Duplicate state — kept for audit + historical reference.)

| Bug ID | Title | Severity | Build Found | Build Fixed | Disposition | Verified Date |
|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — |

---

## Seed Entries (synthetic — for schema demonstration only, marked as such)

These three example entries demonstrate the schema. Mark them `SEED — DO NOT COUNT` and remove or repurpose once real bugs are filed.

### SEED-001 — `[SEED]` Pricing-perception modal questions appear in fixed order on Windows

**Status**: SEED (synthetic example — not a real defect)
**Use**: demonstrates the formal report format for a P1 instrumentation defect

| Field | Value |
|---|---|
| Bug ID | SEED-001 |
| Title | Pricing-perception modal questions appear in fixed order (not randomized) on Windows builds |
| Reported By | (synthetic) |
| Reported Date | 2026-05-26 |
| Build | v0.9.7-alpha1.A1 |
| Platform | Windows 11 |
| Game Mode | n/a (modal-level defect) |
| Severity | P1 |
| Priority | This Build |
| Component / Area | Pricing Survey |
| Status | (would be Triaged → Fixed → Verified for a real bug) |
| Assigned | engineer |
| Test Case | TC-PRICING-002 |
| Related Scenario | S13 |
| Description | Across 3 separate test sessions on the same build, the 4 Van Westendorp price questions render in identical order. Per `PRICING_RESEARCH_PLAN.md` §2 ("Pitfalls + controls — Anchoring"), the order MUST randomize per session to dampen anchoring bias. Fixed-order presentation invalidates the resulting OPP/IPP/range data. |
| Repro | (1) Open Settings → Privacy → enable analytics. (2) Play 1 turn, return to MainMenu. (3) Pricing modal triggers. (4) Note question order. (5) Restart app. (6) Repeat 1-3. (7) **Defect**: question order matches step 4 exactly. |
| Expected | Question order randomizes per session per `PRICING_RESEARCH_PLAN.md` §4. |
| Actual | Question order is identical across sessions. |
| Repro Rate | Always (3/3 attempts) |
| Impact | Pricing data validity compromised; ALL VW outputs from this build are tainted. Cannot ship A2 without fix. |
| Workaround | None — this is data-validity defect, no user workaround possible |
| Suspected root cause | RNG seed in PricingPerceptionSurvey._ready() may be deterministic (Time.get_unix_time_from_system() truncated to integer minute) |
| Fix description | Use unique session UUID + secondary RNG seed |
| Files modified | `src/ui/screens/survey/PricingPerceptionSurvey.gd` |

---

### SEED-002 — `[SEED]` Compendium DLC mid-campaign disable corrupts active save

**Status**: SEED (synthetic — demonstrates a P0 defect format)

| Field | Value |
|---|---|
| Bug ID | SEED-002 |
| Title | Disabling Fixer's Guidebook mid-campaign causes save reload to fail with "missing field 'street_fight_state'" error |
| Reported By | (synthetic) |
| Reported Date | 2026-06-02 |
| Build | v0.9.7-alpha1.A2 |
| Platform | Windows 10 |
| Game Mode | Standard 5PFH |
| Severity | P0 |
| Priority | Immediate |
| Component / Area | DLC Toggle + Save/Load |
| Status | (would be Triaged → In Progress → Fixed → Verified) |
| Assigned | engineer |
| Test Case | TC-DLC-005 (mid-campaign disable) |
| Related Scenario | S11 step 5 |
| Description | While playing a Standard 5PFH campaign with FG enabled (street fights generated), opening Settings and disabling FG mid-campaign appears to succeed (no immediate error), but on next save → reload, the load fails with `missing field 'street_fight_state'` error. Save file is corrupted. |
| Repro | (1) New Standard 5PFH campaign with FG enabled. (2) Play to World Phase. (3) Generate at least 1 street fight job. (4) Settings → DLC → toggle FG OFF. (5) Save campaign. (6) Quit. (7) Reload save. **Crash on reload**: `missing field 'street_fight_state'`. |
| Expected | Disabling FG mid-campaign hides FG-gated content but preserves existing save data. Reload should succeed. |
| Actual | Reload fails; save is corrupted. |
| Repro Rate | Always (3/3 attempts) |
| Impact | Data loss for any tester who toggles FG OFF mid-campaign with FG content already in save. Affects Scenario 11 step 5 directly. |
| Workaround | Do not toggle DLC OFF during active campaigns; toggle only between campaigns. |
| Suspected root cause | DLC toggle handler clears `street_fight_state` from active campaign before serialization, but loader expects it to exist |
| Fix description | DLC toggle handler should preserve existing campaign state regardless of new toggle value; only filter generation of NEW content |
| Files modified | `src/core/systems/DLCManager.gd`, `src/core/state/GameState.gd` |
| Comm note | Once fixed, write to cohort: "if you toggled FG OFF mid-campaign, your save may be corrupted — fix shipping in A3 with backwards-compat migration" |

---

### SEED-003 — `[SEED]` "Get Physical Edition" CTA in main menu footer reads as too aggressive per 4/5 testers

**Status**: SEED (synthetic — demonstrates a P2 tone-perception defect)

| Field | Value |
|---|---|
| Bug ID | SEED-003 |
| Title | Main menu footer "Get Physical Edition" CTA — 4 of 5 testers in week-1 debrief described as "too prominent" / "salesy" |
| Reported By | (synthetic, aggregated debrief) |
| Reported Date | 2026-06-03 (after first weekly debrief) |
| Build | v0.9.7-alpha1.A1 |
| Platform | n/a (subjective UX feedback) |
| Game Mode | n/a (main menu surface) |
| Severity | P2 |
| Priority | Next Build |
| Component / Area | Conversion Mechanism — "Get Physical Edition" CTA |
| Status | Triaged |
| Assigned | UI |
| Test Case | TC-CONVERT-003 |
| Related Scenario | S14 step 2, step 6 (debrief tone) |
| Description | In the week-1 Discord debrief, 4 of 5 rotating testers described the main menu footer "Get the Physical Edition" CTA as "too prominent for a main menu", "salesy", or "feels like an ad". Per `CLOSED_ALPHA_PLAN.md` §6.5 acceptance, T4 mechanisms should read as "respectful / helpful / obvious" — this signal indicates the footer placement crosses the line into "salesy". |
| Repro | (1) Launch alpha build A1. (2) View MainMenu. (3) Note footer "Get Physical Edition" link. (4) Subjective: assess prominence vs other MainMenu elements. |
| Expected | Tester assessment: "respectful / helpful / obvious" (per Scenario 14 acceptance) |
| Actual | 4/5 testers say "too prominent / salesy / feels like an ad" |
| Repro Rate | 4/5 testers (debrief signal) |
| Impact | T4 thesis validation degraded if footer reads as pushy. Affects partnership-pitch credibility on T4 thesis ("active digital→physical conversion") if mechanism deployment reads as commercially aggressive rather than genuinely helpful. |
| Workaround | n/a (UX design decision) |
| Suggested fix | (a) Move from footer to Settings → "Get the Book" entry only, OR (b) Reduce visual weight (smaller font, less accent color), OR (c) Reframe copy from "Get the Physical Edition" to "Companion to the physical book — learn more" |
| Files modified | `src/ui/screens/mainmenu/MainMenu.tscn` (placement) and/or copy in MainMenu.gd |
| Note | This is the kind of signal that ONLY emerges from real cohort feedback. Pre-alpha self-smoke would not have caught it. Validates the alpha process — exactly the data Modiphius wants from T4. |

---

## Aggregate Metrics (auto-aggregate from above tables — update weekly)

| Metric | Value |
|---|---|
| Open P0 | 0 |
| Open P1 | 0 (BUG-100/101/102 Verified 2026-05-16) |
| Open P2 | 0 (BUG-103/104/105 Verified 2026-05-16) |
| Open P3 | 1 (BUG-106 tracking umbrella, ongoing) |
| Total open | 1 |
| Closed this cycle | 6 |
| Verified this cycle | 6 |
| Reopened (regression rate) | 0 |
| Avg time-to-fix (P0) | n/a |
| Avg time-to-fix (P1) | n/a |
| Avg time-to-verify | n/a |

(Seed entries are NOT counted in the metrics above — they're synthetic demonstrations.)

---

## Per-Build Bug Filing Trend

(Update after each weekly build's TEST_EXECUTION_REPORT.)

| Build | Date | New P0 | New P1 | New P2 | New P3 | Total New | Closed This Build | Open Rolling Total |
|---|---|---|---|---|---|---|---|---|
| pre-A0 (dev) | 2026-05-16 | 0 | 3 | 3 | 1 | 7 | 6 | 1 |
| A0 | 2026-05-20 | — | — | — | — | — | — | — |
| A1 | 2026-05-25 | — | — | — | — | — | — | — |
| A2 | 2026-06-01 | — | — | — | — | — | — | — |
| A3 | 2026-06-08 | — | — | — | — | — | — | — |
| A4 | 2026-06-15 | — | — | — | — | — | — | — |
| A5 | 2026-06-22 | — | — | — | — | — | — | — |
| A6 | 2026-06-29 | — | — | — | — | — | — | — |

End-of-cycle Gate 6 ("Bug discovery rate trending down") evaluates this trend.

---

## Cross-References

- **Bug report template**: `docs/testing/templates/BUG_REPORT_TEMPLATE.md`
- **Discord intake template**: pinned message in `#5pfh-alpha-bugs`
- **Test plan**: `docs/testing/ALPHA_1_TEST_PLAN.md`
- **Test scenarios**: `docs/testing/QA_INTEGRATION_SCENARIOS.md`
- **Traceability matrix**: `docs/testing/ALPHA_1_TRACEABILITY_MATRIX.md`

---

*Log v1, 2026-05-01. Owned by QA. Real-time updates expected during alpha cycle.*
