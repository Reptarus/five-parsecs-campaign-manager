# Five Parsecs Campaign Manager - Development Guide

**Last Updated**: 2026-09-07 (**✅ SELECT CREW IS CLOSED — the landscape half is fixed AND verified on deploy #27: four panes in one row, all six crew visible, `Deploying 5 / 5 max` legible, and a finger swipe now scrolls the page with `scroll_started` in the log**). 2026-09-07 (**deploy #26 walked — the item-removal row did NOT reproduce in three instrumented runs and is downgraded; Select Crew PASSES in portrait and is STILL BROKEN in landscape**). 2026-09-07 (**deploy #25 walked — T9-47 CLOSED and the Corporate Label verified on hardware; a new crew-task item-removal defect opened**. Earlier that day: **the T11 tail closed at the desk — T11-47, the Corporate Label and the Select Crew pane, all detection-proven; two pre-existing HARNESS defects found while verifying them**; uncommitted). 2026-09-06 (**deploy #24 walked on hardware — T11-48 and T11-40 both PASS; the p.91 Ambush crew reduction reached the table for the first time**; committed as `352190305`). Deploys #21/#22 gave every one of the 21 desk-fixed T11 findings a device verdict and closed T9-51; the Sep 6 desk pass fixed T11-41/42/43/44/45; **deploy #23 verified all five on the tablet**, closed **T9-48** (the p.91 Ambush prohibition, reachable all along by forcing the attack-type D10 on a snapshot that already had a rival battle armed) and **T11-46** (comment corrected; `GameState.advance_turn()` deliberately left alone). **T11-48 and T11-40 are FIXED and now VERIFIED ON HARDWARE by deploy #24** (detection-proven at the desk, 21 new unit cases between them). T11-48 restored the p.91 Ambush cap, the p.88 Small Encounter sit-out and the p.84 Small Squad ceiling, which had all been computed and discarded — measured **6/6 deployed under a cap of 5** on #23 and **5/5 with one crew member sitting out** on #24, from the same snapshot and the same forced roll, with `active_battle.crew` moving 6 -> 5 and every other input identical. T11-40's viewport budget no longer depends on where the nav is parented: re-measured with the finding's own instrument, the tall Crew Tasks step went h=**37** (9 px of page below) to h=**66** (122 px below), and the footer button now reports the same rect on every step instead of flowing with content height. **T11-47 is now CLOSED at the desk (2026-09-07)** — the harness docblocks were already corrected, so what remained was six sibling probes carrying the stale premise and the fact that **nothing anywhere asserted the formula that caused it**. `tests/unit/test_content_scale_formula.gd` now does. ⭐ It is testable only because `SettingsManager._dpi_scale()` prefers `ResponsiveManager.get_screen_scale()`, a plain member a test can write — which matters because T11-07 shipped precisely since desktop density is 1.0, making the offending term exactly 1.0 on every machine that ran the gates. It asserts the INVARIANT, not the constant, and instruments its own premise first so the density case cannot pass vacuously. Also closed: the **Corporate Label** 1px-wide value (⚠ `clip_text` ALONE was a trap — it bounds a Label's minimum to 1px, undocumented for `Label`, and `SIZE_SHRINK_BEGIN` would then have made the name VANISH across 49 call sites while a geometry sweep read clean) and the **Select Crew pane** rendering header-only. ⚠ Two HARNESS defects, both pre-existing: `verify_rotation.gd` lacked verify_layout's window-hijack guard and produced a FALSE FAILURE off `verify_layout`'s own leftover `window.ini` (one-variable proof: 1600x2560 → 22/1, 393x851 → 23/0); and `test_prebattle_responsive_layout.gd` still claimed "never --headless", superseded by `--ignoreHeadlessMode`. Detail: [docs/qa/TABLET_FINDINGS_2026-09-05.md](docs/qa/TABLET_FINDINGS_2026-09-05.md) § deploy #24. Deploys #14-#16 closed all eleven T10 findings on device; #17 opened six (T11-07..T11-12) and **all six are now resolved or parked**. The big one was **T11-07**: `SettingsManager` multiplied `content_scale_factor` by display density on top of a square-base stretch that already normalises physical size, so every 2.0-density Android device rendered at **2.32x instead of 1.16x**. An autoload-ordering accident (SettingsManager is #2, ResponsiveManager #24) made it boot correct and break on the FIRST RESIZE, which is why it looked like a rotation bug and why every rotation A/B measured 0 — both arms were downstream of the one-shot transition. Verified on #19 across a round trip: `dpi` moves **1.000 → 2.000** while `content_scale` holds at **0.7830**, and the landscape frames before/after are byte-identical. The #19 UI walk also passed T11-08/09/11/12 and opened two new, now-fixed findings — **T11-13** (a rules violation detected, correctly worded, and shown to nobody) and **T11-14** (the character editor displaying a background the character does not have). Billing is **parked by owner decision** pending the LOI on Modiphius letterhead — it is not a gap to chase. Detail: [docs/qa/TABLET_QA_SPRINT_2026-08.md](docs/qa/TABLET_QA_SPRINT_2026-08.md) § deploy #19, and [docs/QA_STATUS_DASHBOARD.md](docs/QA_STATUS_DASHBOARD.md). ✅ **T9-47 is CLOSED** — walked on **deploy #25** (versionCode 9, 2026-09-07): both rows forced from one armed queue, the 51-53 "Gambling problem" and 76-78 "A chance to unload some stuff" dialogs rendered the book text, and credits moved 18 → 17 (−3 upkeep +2 sale). ⚠ **That used to read "That closes the whole T9 family", and it does not.** Corrected 2026-09-08 by an audit of all 110 T-numbered findings: **T9-42 has never been exercised on hardware.** The sprint ledger records `### T9-42 — not exercised; stands desk-verified` and then "remains desk-verified (no 97-100 Explore roll came up in four attempts)" — it was parked as a 4% roll "not worth grinding". ⭐ **That reasoning EXPIRED on 2026-09-04**, when `DiceManager.queue_forced_result()` landed (`DiceManager.gd:78`): T9-42 is now forceable by exactly the route that closed T9-47 and T9-48, and nobody went back to it. Every OTHER T9 row is closed. ✅ **Deploy #26 (versionCode 10, 2026-09-07) answered the item-removal row: NOT REPRODUCED.** #25 recorded the discard and the sale as announced and PAID with the item never removed (`['Blade']` before and after). On #26 — HEAD plus the debug-only `[ITEM-REMOVE]` prints — the removal WORKS in **three runs**, including #25's exact pair (Explore 51 + Trade 76 resolved together): member found by `character_id`, correct `equip_before`, erase at index 0, and re-reading THROUGH THE MEMBER returns `[]`; the pulled save then shows both crew empty with credits +2 for the sale. ⭐ The prints cannot be the fix — `git show dfe398615` on that file is PURE ADDITIONS, zero deletions — so #25 and #26 genuinely differ. ⚠ **The #25 record has a known flaw**: two consecutive walk frames are BYTE-IDENTICAL (`T947_20_itemsel.png` == `T947_21_next_event.png`, md5 `fdd2020b…`), so a tap there did nothing and the frames do not show the steps they are labelled as — evidence flawed, not a proven explanation. The one differing variable (upkeep paid on #25, not on #26) is **disconfirmed at the desk**: `UpkeepPhaseComponent` keeps its own shallow copy and never writes members back. Row downgraded from "confirmed defect" to "not reproducible"; the prints are KEPT so a recurrence names its cause in one run. 🟡 **Select Crew was only HALF confirmed on #26** — PASS in **portrait** (the group drops to TABS, all 6 crew render and "Deploying 6 / 6 max" is legible), **landscape 2560x1600 still broken**: the pane got ~30 px so "Select Crew" was clipped mid-glyph, and the page would not scroll (swipes at five x-positions left the frame byte-identical). ⚠ That also corrects the plan's "TABS is structurally unreachable": it is unreachable in LANDSCAPE only. ✅ **FIXED AT THE DESK 2026-09-07, and it was TWO independent defects, either fatal alone.** (A) **The orphan row**: four panes against `max_columns = 3` leaves Crew alone on grid row 2, and row 1's height is the MISSION pane's content — **1042-1120 design px** for a real rival-attack briefing against a ~1222 px budget — so row 2 starts below the fold. ⭐ The Mission column's WIDTH turned out to be one Label: `mission_desc` had autowrap OFF, so it reported its whole text width (**measured 1134 px** for a 124-character briefing) as a minimum, and because GridContainer hands an oversize column exactly its minimum and splits only the REST equally, that one Label sized every column (1136/328/328/327) — and below the WIDE bucket dragged the page **103 / 299 / 281 px off BOTH side edges**, a pre-existing defect no sweep had seen. Fixed by `max_columns = 4` + autowrap: 528/528/528/527 and **0.0 overflow everywhere**. (B) **The swallowed swipe**: every surface under a finger is `MOUSE_FILTER_STOP` by CONSTRUCTION and `Viewport::_gui_call_input` stops Mouse/ScreenDrag/ScreenTouch there, excepting only WHEEL events — which is exactly why the scrollbar worked, the desktop wheel worked, and a finger did not. PreBattleUI now calls `TouchScrollOpener.open_subtree()` after each of its three populating entry points. ⭐ **Both halves are now reproducible HEADLESS** (`tests/tools/probe_prebattle_landscape.gd`, 6 new cases in `test_prebattle_responsive_layout.gd`), which the plan had assumed impossible — see the two new Gotchas below. Detection-proven three ways, one arm at a time. ✅ **VERIFIED ON HARDWARE, deploy #27 (versionCode 11, 2026-09-07)**, walked from the armed p.85 Rival attack: **LANDSCAPE 2560x1600 renders four panes in ONE ROW** (Mission | Enemy Forces | Battlefield Preview | Select Crew) with **all six crew buttons and `Deploying 5 / 5 max` legible**, and a **finger swipe over the Mission body SCROLLS THE PAGE** (frame md5 `03169a7a` -> `0d0300ac`, revealing the rest of the checklist; on #26 five swipe positions left the frame byte-identical). The log carries `[TouchChainProbe:PreBattle] scroll_started on ContentScroll — THE GESTURE ARRIVED` on every swipe — the discriminator, since that signal fires ONLY for a touch drag on the scrollable area. Portrait is unchanged (TABS, all six, counter). ⭐ Incidental: the p.91 Ambush cap is now VISIBLY bound (`5 / 5 max`, Nyx Ward deselected) — T11-48 was verified on #24 from the save because that counter could not be read at 2560x1600. Still owed — ⚠ **and this clause UNDERSTATED it until 2026-09-08, when it named only four boxes**: `docs/testing/TABLET_CHECKLIST_2026-08-02.md` has **29 unticked boxes across 7 sections**. §3 "Physical legibility and thumb reach" is the four it used to name (⚠ a DOCUMENT section, **not** the in-app "Before You Deploy" checklist, and not signable from screenshots — "only a hand says whether it is comfortable"; its desk half, the font rungs and the WCAG ratios, is computed in [docs/QA_STATUS_DASHBOARD.md](docs/QA_STATUS_DASHBOARD.md)). But **§1 safe-area insets and §4 ARM performance/thermals were never walked at all**: grepping the 407 KB sprint ledger returns **0 hits** for `safe.?area` and **0** for `thermal` (control-probed — "deploy #27" hits the same files, so the zeros are real). §5 Android plugins and §6 scoped storage are near-untouched (1 and 2 hits); §2 touch physics is partly covered by T11-26/27/28/36 and deploy #27 but was never ticked. ⭐ **The deploys were organised by FINDING FAMILY** (T9/T10/T11), so they covered everything someone had already written down and never went near a checklist section nobody had filed a finding against — the audit-axes blind spot again, on a new axis. ⚠ **This clause briefly listed `MissionSelectionUI` as a never-measured screen. That was WRONG and is retracted the same day (2026-09-08): it does not exist.** Deleted in **`a12a73fa1`** (2026-07-31), `find src tests -iname "*MissionSelection*"` returns **0 files**, the commit is an ancestor of HEAD, its `SceneRouter` key was removed with zero `navigate_to` callers, and **`JobOfferComponent`** superseded it. ⭐ **The mistake is the lesson: "0 ledger hits" is an AMBIGUITY, not a finding.** It reads as "nobody tested this" but equally means "there is nothing to test", and I resolved it the wrong way because `docs/testing/TABLET_CHECKLIST_2026-08-02.md` lists it as known-open — a doc dated **two days AFTER the deletion commit**. Before treating an absence of evidence as an open task, confirm the subject still exists; one `find` was the entire disproof. The *general* limitation that entry described is real and still applies: **no control hosted in a `Window` is measured by the geometry sweep** (it lays out against its own rect, not `root.get_visible_rect()`), which covers every runtime modal — see `tests/tools/verify_layout.gd:107-122`. — and the A5 `gl_compatibility` measurement (deploy #27 is its baseline arm; ⚠ its target quantity is GRAPHICS MEMORY, while `docs/sop/android-runtime-testing.md:256-267` only defines FPS/frame-time/draw-call thresholds, so the SOP gives a procedure for the wrong axis — use `Native Heap` or `RenderingDevice.get_driver_and_device_memory_report()`, never `GL mtrack`). The Aug 8-14 tablet QA remains PAUSED — [docs/qa/PICKUP_2026-08-14.md](docs/qa/PICKUP_2026-08-14.md) is still its pickup doc.
**Engine**: Godot 4.6-stable (non-mono, pure GDScript)

> ### The Sep 5 fixit sprint — 21 findings closed at the desk, none yet on hardware
>
> Deploy #19's walk left 19 open findings (T11-15..T11-34); the dry run found two more
> (T11-35, T11-36). All 21 are fixed and **every one is detection-proven by isolated
> revert**. Gates: `tests/unit` **3085 headless + 27 windowed = 3112 cases, 0 failures**
> (baseline 3016), all **8 lints** exit 0, `git diff -- data/` lists ONLY the two sheet
> manifests. Detail: [docs/qa/TABLET_FINDINGS_2026-09-05.md](docs/qa/TABLET_FINDINGS_2026-09-05.md).
>
> ⚠ **Desk-green says nothing about touch.** Godot does not deliver `InputEvent`s in
> headless mode, so the unit cases pin the STATE these fixes leave behind — mouse filters,
> tap-vs-drag discrimination, geometry — and not the gesture. The device is still the
> authority for T11-26/27/28/36.
>
> **Three findings changed shape under investigation**, and each correction is recorded at
> the row rather than silently applied: **T11-16**'s "`game_phase` is absent from the save"
> clause was wrong (it is `meta.game_phase`); **T11-20** was filed as a display nit and is a
> confirmed data defect; **T11-29** was filed as "Unknown everywhere" and is a
> fabricated-data PRODUCER — the screen loaded three JSON template files that **do not
> exist in the repo**, rendered its own invented fallback shape, and wrote it into
> `campaign.rivals`. It is now a read-only viewer (875 -> ~330 lines).
>
> **New shared components** (use these; do not re-implement):
> `src/ui/components/common/TapGesture.gd` (tap vs drag, mouse family only),
> `src/ui/components/common/DisplayText.gd` (whole floats, Title Case, pluralise),
> `SpeciesDataService.display_name()` (the ONE species/origin display name).

**Repository**: https://github.com/Reptarus/five-parsecs-campaign-manager
**Partnership / commercial**: see [docs/MODIPHIUS_PARTNERSHIP_STATUS.md](docs/MODIPHIUS_PARTNERSHIP_STATUS.md) — deal terms, the four agreed strategic theses (do NOT re-argue them), artifacts, and the ⚠ caveat that the correspondence journal stops at Jun 4 2026. None of it bears on writing code, so it is not loaded here.
**Legal placeholders are DELIBERATE**: the shipped EULA and privacy policy carry 7 bracketed placeholders (license grant scope, revenue share, governing law, contact email, release date). They mark terms the LOI settles and are visible to testers ON PURPOSE. Do NOT invent values. Master list: [docs/legal/POST_LOI_LEGAL_CHECKLIST.md](docs/legal/POST_LOI_LEGAL_CHECKLIST.md).
**Active plan**: none. (This line pointed at `5pfh-4219-dtrpg-jiggly-charm.md` until 2026-08-11; that file does not exist. Plans live in `C:\Users\admin\.claude\plans\` — check the directory rather than trusting a path here.)

> ✅ **Committed through `352190305`** on `campaign-editor-and-fixits`.
> `c4317b993` carried the Aug 8-14 tablet sprint, the Sep 3 battle sprint + page walk,
> and tablet deploys #14/#15. `352190305` adds the **T11-48 / T11-40 / T11-46** fixes,
> the 21 new unit cases pinning them, and the deploy #23 + #24 QA record.
> Nothing new is committed until the user asks.
>
> ⚠ **New debug-only tool**: `src/ui/components/common/TouchChainProbe.gd` names what
> is under the finger when a touch gesture goes nowhere. It ships behind
> `OS.is_debug_build()` because **a `--script` SceneTree probe cannot load screens that
> reference autoloads as bare identifiers** — `_ready()` never runs, so the probe
> measures a tree its own setup never touched. `tests/tools/probe_world_phase_drag.gd`
> is marked SUPERSEDED for exactly that reason; discard its numbers.

---

## Environment

```
PROJECT_ROOT: c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager
GODOT_CONSOLE: C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe
GODOT_VERSION: 4.6-stable (non-mono, pure GDScript)
MAIN_SCENE: res://src/ui/screens/mainmenu/MainMenu.tscn
```

Note: The Godot folder IS named `*.exe` (it's a directory containing executables inside).

---

## Project Status

Metrics snapshot moved to [docs/audits/PROJECT_STATUS_SNAPSHOT_2026-04.md](docs/audits/PROJECT_STATUS_SNAPSHOT_2026-04.md); the maintained status doc is `docs/PROJECT_STATUS_2026.md`.

> **⚠ Those are IMPLEMENTATION counts, and implementation is NOT delivery.** "100% mechanics compliance" was true at the same time as Quests being unplayable end to end, four Compendium chapters being unreachable in campaign play, and the p.137 salvage table having never rolled. A mechanic counts as present if the code exists — not if the player can reach it. Treat every row as a lead to verify, never as evidence a feature works.

## Architecture Overview

### Campaign Creation Flow (7 Phases)
```
MainMenu → CampaignCreationUI → CampaignDashboard
  Step 1: CONFIG (ExpandedConfigPanel)
  Step 2: CAPTAIN_CREATION (CaptainPanel + CharacterCreator)
  Step 3: CREW_SETUP (CrewPanel)
  Step 4: EQUIPMENT_GENERATION (EquipmentPanel)
  Step 5: SHIP_ASSIGNMENT (ShipPanel)
  Step 6: WORLD_GENERATION (WorldInfoPanel)
  Step 7: FINAL_REVIEW (FinalPanel)
```
Orchestrated by `CampaignCreationCoordinator` with `CampaignCreationStateManager`. CampaignCreationUI.gd is a thin shell (~161 lines) that wires panels to the coordinator.

#### Creation invariants (audit Aug 2 2026 — read before editing the wizard)

The creation tables were byte-correct against the book; the **wiring** was where it
broke. 8 commits (`adc9711e4`..`a2984719a`). Full detail in the memory entries
`reference_creation_wizard_invariants` / `project_session_aug02_creation_wizard_audit`;
deferred items with reasons in `docs/WIRING_CLEANUP_BACKLOG.md`.

- **One grant site per rule.** Credits (p.28) = `EquipmentPanel` total, consumed by
  `CampaignFinalizationService.compute_starting_credits()` — never added to. Motivation
  /background/class dice + WEALTH's 1D6 + FAME's +1SP are rolled ONCE into
  `Character.creation_bonuses`. Story points (p.66) = `roll_starting_story_points()`
  (`1D6+1`); difficulty modifiers stay in `DifficultyModifiers`. Per-character equipment
  is distributed by finalization only — the coordinator must not.
- **Shapes that destroy data.** `member["equipment"]` is `Array[String]` (from
  `to_dictionary()`); appending an item Dictionary is rejected and the item is LOST.
  Store names, or `.assign()`. One item, one home — stash XOR character sheet.
  `origin`/`motivation`/`background`/`character_class` are validated STRING props:
  convert enum ints at the caller with `GlobalEnums.to_string_value()`.
  Species stat keys exist in two spellings — resolve via
  `CharacterCreator._resolve_stat_property()`. `origin_bonuses` JSON keys are
  `GlobalEnums.Origin` ordinals (append to that enum, never insert).
- **Two navigation gates, in series.** `Coordinator.can_advance_to_next_phase()` reads
  `phase_completion_status` (must be written in BOTH directions or completion is
  monotonic); `StateManager.advance_to_next_phase()` reads only
  `_validate_phase_with_warnings()` — the strict `_validate_*_phase()` functions are NOT
  on that path, so a check added there alone blocks nothing.
- **Do NOT wire `get_validation_summary()["has_critical_errors"]`** to
  `_validate_final_phase()`. It is hard-coded false on purpose: the strict crew check
  compares members against the TOTAL crew size while the panel excludes the captain, so
  it reports legal campaigns as short by one (observed live: "Final validation failed.
  Total errors: 2"), and both consumers append to lists that BLOCK creation.
- **Crew size SSOT** = `campaign_config.campaign_crew_size`; `CrewPanel` consumes it via
  `apply_campaign_crew_size()`. Victory conditions are **single-select and optional**
  (p.64), all 17 map to real enum members, and Easy allows exactly `turns_20`/`battles_20`.

### Campaign Turn Flow (9 Phases)
```
STORY -> TRAVEL -> UPKEEP -> MISSION -> POST_MISSION -> ADVANCEMENT -> TRADING -> CHARACTER -> RETIREMENT
```
Each phase has a dedicated panel wired into `CampaignPhaseManager` -> `CampaignTurnController` with completion signals and data handoff.

### PostBattlePhase Subsystem Architecture (Phase 33)
```
PostBattlePhase.gd (296-line orchestrator, emits all 19 signals)
  └─ post_battle/
     ├─ PostBattleContext.gd      — DI hub (campaign, managers, battle result)
     ├─ RivalPatronResolver.gd    — Steps 1-3 (rival/patron/quest)
     ├─ PaymentProcessor.gd       — Steps 4-6 (pay, finds, invasion)
     ├─ LootProcessor.gd          — Step 7
     ├─ InjuryProcessor.gd        — Step 8
     ├─ ExperienceTrainingProcessor.gd — Steps 9-11
     ├─ CampaignEventEffects.gd   — Step 12 (80-case match)
     ├─ CharacterEventEffects.gd  — Step 13 (60-case match)
     ├─ GalacticWarProcessor.gd   — Step 14a
     ├─ StoryTrackProcessor.gd    — Step 3b (reward gates) + 14c (clock/event)
     └─ PostBattleCompletion.gd   — Step 14b (stats, journal, morale)
```
Subsystems are RefCounted (not Node), return data to orchestrator which emits signals. Zero `.emit()` calls in subsystems.

### WorldPhaseComponent Base Class (Phase 33)
All 9 world phase components extend `WorldPhaseComponent` with:
- Event bus auto-cleanup via `_subscribe()` + `_event_subscriptions` tracking
- `TOUCH_TARGET_MIN` constant (48px) for mobile UX
- `_help_dialog` + `_show_help_dialog()` shared utility
- Virtual hooks: `_subscribe_to_events()`, `_connect_ui_signals()`, `_setup_initial_state()`

### Bug Hunt Gamemode (Compendium)

Standalone military-themed variant with 3-stage turn, separate from the 9-phase campaign.

```
MainMenu → BugHuntCreationUI (4-step wizard) → BugHuntDashboard → BugHuntTurnController
  Stage 1: SPECIAL_ASSIGNMENTS (SpecialAssignmentsPanel)
  Stage 2: MISSION (BugHuntMissionPanel → TacticalBattleUI in bug_hunt mode)
  Stage 3: POST_BATTLE (BugHuntPostBattlePanel)
```

- **BugHuntCampaignCore** (Resource): Separate from FiveParsecsCampaignCore — no ship, no patrons/rivals
- **BugHuntPhaseManager**: 3-stage turn orchestration (vs 9-phase CampaignPhaseManager)
- **TacticalBattleUI** reused with `battle_mode: "bug_hunt"` (hides morale). ⚠ This line used to say "adds ContactMarkerPanel" — that file was DELETED in `5125a0e4` and nothing replaced it.
- **CharacterTransferService**: Bidirectional transfer (5PFH ↔ Bug Hunt) with enlistment rolls
- **GameState.load_campaign()**: Uses `_detect_campaign_type()` to peek at save file JSON `campaign_type` field, routing to `FiveParsecsCampaignCore` (default) or `BugHuntCampaignCore` loader. Legacy saves without the field default to standard 5PFH.
- **SceneRouter keys**: `bug_hunt_creation`, `bug_hunt_dashboard`, `bug_hunt_turn_controller`
- **15 JSON data files** in `data/bug_hunt/`, **23 GDScript/TSCN files** across `src/`

### Battle Simulator (Standalone Battles)

Standalone battle mode accessible from MainMenu — no campaign required. Ungated for demo (DLC gating planned).

```
MainMenu → "Battle Simulator" button
  └─ SceneRouter.navigate_to("battle_simulator")
       └─ BattleSimulatorUI (thin shell, code-built)
            ├─ BattleSimulatorSetupPanel (single-screen config)
            │   ├─ Crew Size (3-6), Enemy Category/Type, Mission, Difficulty
            ├─ TacticalBattleUI (instantiated on launch from .tscn)
            └─ BattleSimulatorResultsPanel (shown after battle)
```

- **BattleSimulatorSetup.gd** (RefCounted): Loads `enemy_types.json` + `mission_templates.json`, generates lightweight crew dicts + enemy squads
- **Crew uses minimal dicts** (not Character resources) — `TacticalBattleUI.TacticalUnit` handles both
- **Critical timing**: `initialize_battle()` must be called sync after `add_child()` — TacticalBattleUI `call_deferred("_check_standalone_mode")` fires otherwise
- **Results don't persist** — no campaign to save to, just Play Again / Main Menu
- **SceneRouter key**: `battle_simulator`

### Planetfall Gamemode (Compendium Expansion)

Colony-building campaign variant with 18-step turn flow, separate from the 9-phase standard campaign.

```
MainMenu → "Planetfall" button → PlanetfallCreationUI (6-step wizard) → PlanetfallDashboard
  └─ PlanetfallTurnController (18-step turn flow)
       PRE-BATTLE: Recovery → Repairs → Scout Reports → Enemy Activity → Colony Events → Mission Determination
       BATTLE: Lock and Load → Play Out Mission (delegates to TacticalBattleUI)
       POST-BATTLE: Injuries → Experience → Morale → Replacements
       COLONY: Research → Building → Integrity → Character Event → Update Colony Sheet
```

- **PlanetfallCampaignCore** (Resource): Separate from FiveParsecsCampaignCore — has `colony` dict (morale/integrity/grunts/story_points), `roster` array, `progression` dict
- **PlanetfallPhaseManager**: 18-phase turn orchestration, `Phase` enum (0-17), `complete_current_phase()` auto-advances
- **PlanetfallCreationCoordinator**: 6-step wizard (Expedition Type, Roster, Backgrounds, Map, Tutorials, Review)
- **PlanetfallScreenBase**: Extends CampaignScreenBase, adds `_create_pill()` method + Planetfall-specific constants
- **TacticalBattleUI** reused: `_on_phase_changed` intercepts `PLAY_OUT_MISSION` phase → `_launch_planetfall_battle()` → SceneRouter to tactical_battle
- **Battle return**: `_resume_after_battle(result)` called when TurnController reinitializes with temp_data `planetfall_battle_result`
- **Save/load**: `PlanetfallCampaignCore.save_to_file()` / `.load_from_file()` — JSON with `campaign_type: "planetfall"`, nested `config/colony/progression/meta` dicts
- **SceneRouter keys**: `planetfall_creation`, `planetfall_dashboard`, `planetfall_turn_controller`
- **15 JSON data files** in `data/planetfall/`, **63 GDScript files** across `src/`
- **Runtime verified**: Session 57d — full 18-step turn cycle, battle delegation, save/load round-trip, multi-turn (Turn 1→2)

### Tactics Gamemode (Standalone Expansion)

Points-based army building and operational campaign variant.

```
MainMenu → "Tactics" button → TacticsCreationUI (army builder) → TacticsDashboard
  └─ TacticsTurnController (operational campaign phases)
```

- **TacticsCampaignCore** (Resource): Army lists, units, vehicles, points budgets
- **TacticsSpeciesBookLoader**: Loads species army lists from `data/tactics/species_books/` JSON files
- **Data model**: TacticsUnitProfile, TacticsVehicleProfile, TacticsWeaponProfile, TacticsSpecialRule, TacticsUpgradeGroup/Option
- **108 weapon/vehicle/unit costs** verified against rulebook (Session 57b)
- **SceneRouter keys**: `tactics_creation`, `tactics_dashboard`, `tactics_turn_controller`
- **59 GDScript files** across `src/`, **18 JSON data files** in `data/tactics/`

### Cross-Mode Character Transfer Framework (Foundation + Planetfall P1 + Tactics SHIPPED, June 2026)

Move a single character between the 4 persistent gamemodes — Standard 5PFH (`"five_parsecs"`), Bug Hunt (`"bug_hunt"`), Planetfall (`"planetfall"`), Tactics (`"tactics"`). All 4 modes now interconnect any-to-any through the canonical hub. Battle Simulator is standalone (no persistence) and out of scope. **Authoring/extending a transfer leg? Read `docs/sop/cross-mode-transfer.md` first.**

```text
Source mode character
  └─ CharacterTransferService.export_to_canonical(char, source_mode)   ← SOURCE LEG (book rule)
       → full 5PFH-standard Character dict (the canonical interchange form)
            └─ import_from_canonical(canonical, target_mode)           ← TARGET LEG (book rule)
                 → target-mode shape + embedded lossless `snapshot`
                      └─ written to user://transfers/<id>.json (direct file-drop)
                           └─ CampaignScreenBase._check_pending_transfers()  ← mode-generic pickup
                                → apply_transfer_rewards() → _add_character_to_mode() dispatch
```

- **Canonical hub, single chokepoint**: `src/core/character/CharacterTransferService.gd` (`class_name CharacterTransferService`, RefCounted). The canonical interchange form is the full 5PFH-standard Character dict. Every mode `export_to_canonical()` / `import_from_canonical()`. Any-to-any transfer = composing the two book-defined legs through the 5PFH canonical. Mirrors the rulebooks, which document how a character returns to 5PFH play and how a standard character enters each mode.
- **Route matrix (12 directed routes among 4 modes)**: 9 are book-defined. 3 (Planetfall→Bug Hunt, Tactics→Bug Hunt, Tactics→Planetfall) have NO direct book rule and are offered ONLY by composing two book-defined legs through the 5PFH canonical, inventing zero values.
- **Reward-suppression rule**: 5PFH-specific exit rewards (Bug Hunt mustering credits / +1 Story Point / +Sector Government patron; Planetfall ending bonuses) attach ONLY when `target_mode == "five_parsecs"`. See `transfer_character()`.
- **Lossless snapshot**: each imported character embeds a `snapshot` key (its canonical form) so a later muster-out restores the original verbatim — `export_to_canonical()` short-circuits on the snapshot. `_layer_planetfall_ending()` applies ending bonuses on TOP of a snapshot-restored veteran (bonuses depend on the ending, not the stats).
- **Transfer mechanism**: direct file-drop via `user://transfers/<id>.json` (NOT a persistent barracks — deferred to P3). Envelope: `schema_version 2`, `direction`, `source_mode`, `target_mode`, `character`, `snapshot`, `stashed_equipment`, `mustering_credits`, `bonus_story_points`, `add_sector_government_patron`, `transferred_at`. Static `load_pending_transfers(target_mode)` filters by destination (v1 files predate `target_mode` and always target 5PFH). Static `apply_transfer_rewards(campaign, transfer_data)` applies rewards to the receiving campaign and DELETES the file (prevents double-import).
- **Mode-generic pickup** lives in `src/ui/screens/campaign/CampaignScreenBase.gd`: `_check_pending_transfers()`, `_apply_pending_transfers()`, `_add_character_to_mode()` dispatch (`five_parsecs`→`add_crew_member`, `bug_hunt`→`add_main_character`, `planetfall`→`add_roster_character`, `tactics`→`add_veteran_character`), `_notify_transfer_result()`, the `_on_transfers_applied()` virtual hook, and `_campaign_mode()`. Each dashboard calls `_check_pending_transfers.call_deferred()` in `_setup_screen()` and overrides `_on_transfers_applied()` to rebuild. Wired in CampaignDashboard (5PFH), BugHuntDashboard, PlanetfallDashboard, TacticsDashboard. `GameState.load_campaign()` emits `pending_character_transfers(count)` on a 5PFH load.
- **5PFH crew-addition chokepoint**: `FiveParsecsCampaignCore.add_crew_member(member_dict)` appends to `crew_data["members"]`, forces `is_captain=false`, rebuilds `_crew_id_index`, updates modified time. It is the mutation API for crew additions made after creation.
- **Planetfall import UI**: `src/ui/screens/planetfall/panels/PlanetfallCharacterImportPanel.gd` — select a source character from 5PFH/Bug Hunt saves → preview → Class Training D6 aptitude (1-2 fail, 3 random class, 4-6 player choice; max 3 trained, one per class) → embed snapshot → `add_roster_character`. 5PFH Luck → 1 Kill Point each; Bug Hunt Tech → Savvy; imported characters begin Loyal (Planetfall pp.26-27). Creation-wizard entry: the import button in `PlanetfallRosterPanel.gd`. Dashboard cards on PlanetfallDashboard: "Import Veterans" and "Muster Colonists Out".
- **Tactics import UI**: `src/ui/screens/tactics/panels/TacticsVeteranImportPanel.gd` — select a source character from 5PFH/Bug Hunt/Planetfall saves → preview the Tactics conversion → embed snapshot → `add_veteran_character`. A transferred character becomes a **NAMED VETERAN** (an "officer or hero" figure, Tactics p.185) stored in `TacticsCampaignCore.veteran_characters[]` (a serialized array) — NEVER `campaign_units[]`, so veterans stay out of points validation. TacticsDashboard hosts a "Commission Veteran" card (import) and a "Retire Veteran Out" card (3-target overlay → 5PFH / Bug Hunt / Planetfall). Conversion (`convert_to_tactics` / `convert_from_tactics`) is book-faithful (Tactics p.184): Combat cap +2, Toughness cap 5, "1 Kill Point per Luck point" on import, "each Kill Point after the first → 1 Luck" on export. The playability floor (veteran needs ≥1 KP) lives at the veteran layer (`add_veteran_character()`, tagged), so the conversion math stays book-exact.
- **Status**: Foundation (Bug Hunt ↔ 5PFH; also fixed the previously-broken muster-out pickup) SHIPPED. Planetfall P1 SHIPPED. Tactics named-veteran import/export SHIPPED (Jun 4) — all 4 modes now interconnect any-to-any. 24/24 gdUnit4 transfer tests pass (`tests/unit/test_character_transfer_hub.gd`, `tests/unit/test_planetfall_transfer.gd`, `tests/unit/test_tactics_transfer.gd`); editor parse clean. P3 persistent barracks deferred.

### Galaxy Log (June 2026, 5PFH only)

Hex-grid travel-history visualization. Full-screen sub-screen accessible from the Campaign Dashboard CAMPAIGN HISTORY block. Read-only history view — NOT a navigation interface (no movement mechanics, no spatial rules).

```text
MainMenu → CampaignDashboard "Galaxy Log" button
  └─ SceneRouter.navigate_to("galaxy_log")
       └─ GalaxyLogScreen (extends FiveParsecsCampaignPanel)
            ├─ HexStarMap (pan/zoom Control)
            │   ├─ HexCell × N (one per visited planet)
            │   └─ _draw(): breadcrumb polyline over travel_history
            └─ WorldDetailPopup (Window, opens on hex click)
                 └─ PlanetDetailBuilder.build_into(vbox, planet)
```

- **GalaxyHexLayout** (`src/core/world/GalaxyHexLayout.gd`): deterministic `(campaign_id, planet_id)` → axial coord, flat-top hex math, salt-overflow fallback via `next_free_outward()`. Pure static, no persisted positions.
- **PlanetDetailBuilder** (`src/core/world/PlanetDetailBuilder.gd`): shared planet-detail renderer. CampaignDashboard's PLANET INFO overlay AND the WorldDetailPopup both call `PlanetDetailBuilder.build_into(vbox, planet)` so they render identically.
- **Starting world anchor**: `min(planet.discovered_on_turn)` across `pdm.visited_planets`. The starting world is seeded with `discovered_on_turn=0` so this min reliably finds it. **This was false until Aug 2 2026** — `WorldInfoPanel._get_campaign_turn_safe()` defaulted to `1` against a creation state with no `campaign_turn` key, and `PlanetDataManager.upsert_current_world()` only substitutes its own turn argument when the stamped value is `<= 0`, so the 1 beat finalization's explicit 0 and every save on disk recorded the starting world as turn 1. The anchor survived on insertion order, not correctness. The panel now stamps 0 at creation.
- **Pan/zoom**: copied from BattlefieldMapView lines 1116-1231 (the canonical and only pan/zoom implementation in the codebase).
- **Setter-driven `queue_redraw()`**: per Godot 4 custom-drawing docs, `_show_breadcrumb`/`_pan_offset`/`_zoom_level` invalidate via `set:` blocks. Never `_process()` → `queue_redraw()`.
- **SceneRouter key**: `galaxy_log`
- **NEW JSON / data files**: zero. Reads exclusively from existing PlanetDataManager state.
- **Pre-Jun-1 journal entries** still have `location="Unknown"` (pre-Phase-0). No backfill migration in v1.

### Printable Sheets / PDF Export (May 2026; audited to the book Aug 9-11 2026)

Renders campaign data onto the three official Modiphius sheet PNGs and exports PNG/PDF.
**Read `docs/sop/sheet-export.md` before touching any of it.**

```text
MainMenu/CampaignDashboard → "Sheets" → PrintSheetScreen (tab bar + Save PNG/PDF)
  └─ _build_data_context()          ← FETCHES campaign / world / journal entries
       └─ SheetDataContext.build()  ← the VIEW-MODEL the manifests address
            └─ SheetRenderer (Control)
                 ├─ the official PNG + Labels placed per data/sheets/core/*_fields.json
                 ├─ export_to_png  → SubViewport 2764×1843 + await frame_post_draw
                 └─ export_to_pdf  → PdfExportRouter
                      ├─ "godotharu"  GDExtension — DESKTOP ONLY (no Android binary)
                      └─ "godotpdf"   vendored GDScript addon — the ANDROID path
```

- **Three sheets, all printed in the book**: Crew Log, Encounter Log, World Record Sheet —
  **Core Rules Appendix X, PDF pp.180-181**. That is the authority on what every box
  means; extract it with PyPDF2 before mapping a field. ⚠ Its TEXT LAYER is not a reading
  order (it emits the licensing octagons "No Obtained Yes"; the artwork reads
  **Yes | Obtained | No**) — crop the PNG for anything positional.
- **`SheetDataContext` is the single view-model.** Manifests address
  `campaign.crew[2].weapons[0].damage`; the raw campaign has `crew_data["members"]`.
  Keep the view-model matching the manifests, never drift the manifests toward storage.
- **BLANK IS A LEGITIMATE VALUE, null is a bug.** A print form is meant to have empty
  boxes. Anything genuinely unmodelled is listed in `_EMPTY_UNTIL_MODELLED` with a reason,
  and mirrored in the test's `blank_by_design` map. A non-null assertion therefore proves
  nothing — `test_every_addressed_box_prints_something_on_a_populated_campaign` asserts
  **non-blank**.
- ⚠ **The world is a `PlanetData` OBJECT, not a Dictionary** —
  `PlanetDataManager.get_current_planet()`. `_as_dictionary()` coerces via `serialize()`.
- ⚠ **The Encounter Log's data lives in the journal entry's `stats`.**
  `CampaignJournal.create_entry()` rebuilds every entry from a FIXED key set and DROPS
  everything else, so a scenario fact outside `stats` is deleted at the chokepoint. The
  producer chain is `mission_data` → `BattleResultNormalizer` → `auto_create_battle_entry`
  stats → the sheet.
- **Backends differ by platform, so a desktop probe is not a device test.** Make any probe
  PRINT its branch (`tests/tools/emit_sheet_pdf.gd` emits both).

### Tablet QA (real hardware, Aug 8-14 2026) — ⏸ PAUSED, see the pickup doc

**▶ [docs/qa/PICKUP_2026-08-14.md](docs/qa/PICKUP_2026-08-14.md) — read this first when resuming.**
Ledger: [docs/qa/TABLET_QA_SPRINT_2026-08.md](docs/qa/TABLET_QA_SPRINT_2026-08.md) (append-only,
one section per deploy). Procedure: `docs/sop/android-runtime-testing.md`.

First QA on a real device (Lenovo TB361FU). It found defect classes desktop testing is
structurally incapable of seeing — soft-keyboard occlusion, touch-scroll swallowed by
decorative chrome, legacy-save data loss — plus several that were simply never exercised
because no test drove the SCREEN rather than the function it calls. **Treat "the unit suite
is green" as saying nothing about device behaviour.**

**Hardware-verified:** T9-50 (checkpoint keeps the accepted job across process death), the
`_refresh_job_offers()` back-nav guard, T9-46b (journal records the generated enemy, not the
Rival's bogus type), T9-49 (a no-win-condition Rival battle moves neither W nor L, and the
journal says "Held The Field"), **T9-51** (character event D100 88-94 — deploys #21/#22)
and **T9-48**'s prohibition branch (Rival AMBUSH = D10 roll of 1 — deploy #23, forced
through the QA seam on a snapshot that already had the rival battle armed). The p.91 crew
reduction T9-48 implies then reached the table on **deploy #24** — see T11-48.

**Desk-verified only:** T9-47 (Explore 51-53 / Trade 76-78). ⚠ **This block used to say
"no in-app tool can force the roll", and that stopped being true on Sep 4 2026** when
`DiceManager.queue_forced_result()` landed behind `OS.is_debug_build()`. T9-47 is reachable
by exactly the route that closed T9-48; it simply has not been walked yet.

⭐ **T9-50 took THREE fixes and is the sprint's transferable lesson.**
`initialize_job_offers()` has three callers; ordering the restore against the first two both
passed every desk gate and failed on device. The cause was `initialize_world_phase()` — the
orchestrator entry point `CampaignTurnController` calls AFTER `_ready()`, because it **shows**
`WorldPhaseController` each turn rather than re-creating it. **A fix ordered against SOME
callers is not a fix: grep and COUNT, or make it order-independent. And when a screen is
reused rather than re-instantiated, `_ready()` is not the whole initialisation story.**

### Character Events System (Session 51, Core Rules pp.128-130)

Post-battle D100 Character Events with persistent multi-turn status effects.

```
PostBattleSequence (UI, Step 12)
  → _on_character_event_roll() → _interpret_character_event(roll)
      → Loads data/campaign_tables/character_events.json
      → Displays actual event name + description
      → Calls PostBattlePhase.apply_character_event_effect()
          → CharacterEventEffects.apply_effect() → ctx.apply_character_status_effect()
              → Character.status_effects.append(effect_dict)

CampaignPhaseManager._process_turn_rollover()
  → _process_character_event_effects(campaign)
      → For each crew member: decrement duration, remove expired
      → _on_character_event_expired(): Business Elsewhere XP return, item recovery roll
```

- **Status Effects**: `Character.status_effects: Array[Dictionary]` — each `{type, name, description, duration, source_event}`
- **9 effect types**: `skip_next_battle`, `unavailable`, `departed`, `skip_tasks`, `ignore_next_injury`, `item_damaged`, `item_lost_recovery`, `no_xp`, `extra_action`
- **6 enforcement gates, ALL LIVE**: deployment-time crew filter, CrewTaskComponent eligibility, ExperienceTrainingProcessor XP block, InjuryProcessor immunity, UpkeepPhaseComponent exemption, CampaignDashboard pill display. The deployment gate is `GameStateManager.filter_deployable()`, reached via `CampaignTurnController._deployable()` at **four** live call sites (`:1369`, `:1435`, `:2039`, `:2107`) — NOT via the deleted `BattlePhase.gd`. See the note two lines down for why this looked dead.
- **Serialization**: Round-trips via `to_dictionary()`/`from_dictionary()`
- **Turn countdown**: Follows sick bay recovery pattern (dual Resource + Dictionary path)
- **The deployment filter IS enforced — via `filter_deployable()`, not `get_deployable_crew()`.** ⚠ This entry previously read "UNCALLED (0 callers) … the deployment-time exclusion gate + the Character-Events `skip_next_battle` gate are UNENFORCED." **That was WRONG and it survived here for weeks** (corrected Aug 6 2026). `GameStateManager.get_deployable_crew()` genuinely has zero callers, which is what the note was grepping — but it is a one-line convenience wrapper around `filter_deployable(get_crew_members())`, and **`filter_deployable()` is the real filter authority and IS live**: `CampaignTurnController._deployable()` (`:1950`) routes four battle-path call sites through it (`:1369`, `:1435`, `:2039`, `:2107`). DEAD/MISSING/RETIRED, Sick Bay/recovering, and the `departed` / `skip_next_battle` status effects are all excluded at deployment. Wired in P1 `2df0949a`, which `docs/WIRING_CLEANUP_BACKLOG.md` recorded correctly while this file kept the pre-fix text.
  - **The transferable lesson**: grepping for the WRAPPER and finding zero callers says nothing about the rule. Follow the wrapper to what it delegates to and grep THAT. A zero-caller convenience function sitting on top of a live one is the most convincing false positive in this codebase.

### Crew Task Event Queue (Session 21)

Interactive dialog system for World Phase crew task results — every Trade/Explore outcome is a player-facing moment.

```
_on_resolve_all_pressed()
  → resolve tasks (D100 rolls — unchanged)
  → _build_event_queue() → classify each result into typed events
  → _process_event_queue() → serial dialog chain
      → CrewTaskEventDialog.show_event() → player interacts
      → _on_event_completed() → applies state mutation
      → next dialog...
  → _finalize_task_resolution() → publish completion event
```

- **CrewTaskEventDialog.gd** (~700 lines): Universal dialog for 26 EventType enum values. Deep Space theme, art placeholder ready
- **State mutations**: Credits, story points, XP, items, sick bay, rivals, rumors, patrons, discard/sell, military weapons, recruitment
- Dialog is purely presentational — ALL state mutation in `_on_event_completed()` callback
- Art placeholder (`ColorRect`) ready for `TextureRect` swap via `res://assets/event_art/{name}.png`

### Red & Black Zone Jobs (Core Rules Appendix III pp.148-151)

Endgame content for experienced crews — zone selection integrates into the World Phase wizard:

```
UpkeepPhaseComponent (Step 0, travel decision)
  ├─ "Stay" / "Travel" (normal)
  ├─ "Travel to Red Zone" (visible at 10+ turns, requires license)
  └─ "Accept Black Zone Mission" (visible when licensed + 10 RZ turns)
       → selected_zone stored: 0=normal, 1=red, 2=black
       → WorldPhaseController reads get_selected_zone()
       → Injects is_red_zone/is_black_zone into mission_dict
       → EnemyGenerator.generate_enemies_as_dicts() APPLIES them (p.150)
```

**Opposition is applied, not just displayed (Jul 31 2026).** Both flags were
rolled, stored and printed by MissionPrepComponent while the generator read
neither. Red Job Increased Opposition (p.150) REPLACES the rolled count —
"a base of 7 figures + any modifier from the enemy type... **no other modifiers
are applied up or down**", so the p.63 crew-size dice and the difficulty
adjustment are both discarded — plus 3 Specialists *including* the Lieutenant,
and +1 to the Unique Individual roll. Black Jobs always draw from Roving
Threats. Pinned by `tests/unit/test_zone_job_opposition.gd`.
(`BattlePhase.gd` was DELETED in 99fad30b2; the live path is
CampaignTurnController.)

- **Data files**: `data/red_zone_jobs.json`, `data/black_zone_jobs.json` — threat conditions, time constraints, opposition rules, mission types, rewards
- **Systems**: `RedZoneSystem.gd`, `BlackZoneSystem.gd` — RefCounted, static methods, JSON-backed
- **Persistence**: `FiveParsecsCampaignCore.red_zone_licensed` (bool), `.red_zone_turns_completed` (int) — serialized
- **Black Zone step skip**: JOB_OFFERS + RESOLVE_RUMORS auto-skipped, upkeep waived
- **The Black Job MISSION itself is wired (Aug 7 2026)** — pp.150-151, and it was the last big one. The rewards, the Roving Threats source and the D10 roll were all live while `BlackZoneSystem.get_setup_rules()` / `get_opposition_rules()` / `get_active_passive_rules()` / `get_ending_rules()` were byte-faithful and had **ZERO callers between them**. So a Black Job rolled a Deployment Condition and a Notable Sight the book forbids, forfeited its Seize the Initiative +1, fielded an ordinary 3-8 force, cost nothing to flee, and tracked an objective rolled off the p.89 Opportunity table while the briefing promised "kill 25 enemy". Now:
  - `BattleSetupRules._apply_black_zone()` runs **LAST** in `compute()` so p.151's absolutes overwrite anything earlier — sets `early_leave_is_casualty` (reusing the p.92 Invasion flag: same rule, same consumer, one enforcement site) and `hold_rounds` from the D10 row
  - `CampaignTurnController` suppresses the sight + condition, adds the +1, and `_stamp_black_zone_objective()` makes the "Your Day in Hell" row the tracked objective — stamped **BEFORE** the p.89 roll, whose `if not mission_data.has("objective_details")` guard then correctly leaves it alone
  - `EnemyGenerator` fields **4 teams of 4 = 16** (a REPLACEMENT like the Red Job base of 7) with one Specialist per team
  - `FPCM_BattleFlowGuide.build_black_job_round_prompts()` delivers the per-round reinforcement wave, the Passive-activation 1D6, and "evac'ed out at the end of the FOLLOWING round"
  - ⚠ The prep card **READS `get_opposition_rules()`** now. It used to hardcode `"4 teams of 4 (16 initial enemies)"` — the only place those numbers existed anywhere in the app, describing a battle that was never generated. Do not put a mechanic's numbers in a UI literal.
- **PostBattle**: `PaymentProcessor.process_black_zone_rewards()`, ExperienceTrainingProcessor BZ +1 XP, GalacticWarProcessor RZ -1 modifier
- **Journal**: Battle entries tagged `red_zone`/`black_zone`, enriched with threat/time/mission details, BZ victory/failure milestone entries, license purchase milestone
- **Broker discount**: License fee -2cr if crew has Broker training (checks `has_broker_training` property + `"Broker Training"` trait)

### Upkeep Failure System (Core Rules p.76, Session 52)

Full Core Rules p.76 compliance for upkeep payment:
- **Sick Bay exclusion**: Crew in Sick Bay (`in_sick_bay` or `recovery_turns > 0`) excluded from upkeep count (both UpkeepSystem and UpkeepPhaseComponent)
- **Sell for upkeep**: Interactive dialog lists stash items at 1 credit each via `EquipmentManager.sell_equipment()`. Deficit decrements per sale
- **Crew lockout**: `UpkeepSystem.handle_upkeep_failure()` locks out 1 crew per credit short. Sets `locked_out_this_turn` on both Resource (meta) and Dictionary (key). Enforced in `CrewTaskComponent._get_eligible_crew()`
- **Dismiss crew**: Dialog to kick out crew member, recover 1 item to stash. Available anytime during upkeep (not just failure)
- **Lockout clearing**: `CampaignPhaseManager._clear_upkeep_lockouts()` runs at turn rollover
- **Ship debt seizure**: `ShiplessSystem` uses `>=75` threshold (was `>75`)

### Story Point System (Core Rules pp.66-67, Session 43)

Meta-currency for narrative control. Fully integrated into campaign loop.

- **System**: `StoryPointSystem.gd` (RefCounted, JSON-config from `data/campaign_config.json`)
- **UI**: `StoryPointPopover.gd` (PopupPanel from dashboard SP badge), `StoryPointSpendingDialog.gd` (Window alternative)
- **Stars of the Story**: `StarsOfTheStorySystem.gd` — 4 emergency abilities (once per campaign), shown in same popover
- **Earning**: Turn rollover via `StoryPointSystem.check_turn_earning()` (+1 every 3rd turn), PostBattlePhase `_check_bitter_day_story_point()` (+1 for held field + character killed)
- **Spending**: 5 types (roll-twice, reroll, +3 credits, +3 XP to character, extra action). Per-turn limits on last 3
- **Dashboard sync**: `_sync_sp_system()` reloads `_sp_system` from `campaign.story_point_turn_state` on phase events and before popover open
- **Persistence**: `campaign.story_points` (int) + `campaign.story_point_turn_state` (Dict with balance + per-turn flags) + `campaign.stars_of_the_story` (Dict)
- **Insanity mode**: Story points disabled entirely (0 earned, cannot spend)
- **Battle-only stars**: Dramatic Escape + It's Time To Go disabled on dashboard popover (need battle context)

### Story Track System (Core Rules Appendix V, Session 36)
```
StoryTrackSystem (Resource, cached on CampaignPhaseManager.story_track)
  ├─ StoryMissionLoader → loads 7 event JSONs from data/story_track_missions/
  ├─ StoryEvent (Resource) → per-event data (turn mods, enemies, deployment, objectives)
  ├─ Story Clock: Won=−1 tick, Not-won=D6 (1:0, 2-5:1, 6:2)
  ├─ Evidence Mechanic (Events 5-6): 1D6+evidence >= 7
  └─ Event 7 Delay: up to 3 turns before "Losing the Story"
```
- **Signals**: `story_track_started`, `story_event_triggered(event)`, `story_clock_advanced(ticks)`, `evidence_discovered(total)`, `story_track_completed(won)` — all connected in `CampaignPhaseManager._init_story_track()` to CampaignJournal handlers
- **Integration points** (rewired Aug 1 2026 — the previous list named a file deleted two months earlier): CampaignPhaseManager (turn-start check + the `is_story_event_turn()` / `get_story_battle_config()` / `get_story_turn_mods()` bridge), **`post_battle/StoryTrackProcessor.gd`** (clock advancement, event completion, effects application), **`CampaignTurnController._stamp_narrative_battle_config()`** (story battle config injection — NOT BattlePhase, which was deleted in 99fad30b2), StoryPhasePanel (3-mode UI), CampaignDashboard (intel overview)
- **⚠ The drive shaft is a single call.** `PostBattlePhase._advance_narrative_progression()` is the only caller of `advance_clock_end_of_turn()` / `apply_post_battle()` / `intro_campaign.advance_turn()`. Delete it and the Story Clock stops ticking and the Introductory Campaign freezes on turn 0 — silently, with no error, which is exactly what happened between `e4373e137` (Apr 8) and Aug 1. Pinned by `tests/tools/verify_story_track.gd` (7 rows, detection-proven: reverting that one call fails 5 of them).
- **Story Event turns**: `start_new_turn()` routes to `FiveParsecsCampaignPhase.STORY` before UPKEEP so the briefing lands before the world phase; `_on_story_phase_completed()` then hands off to UPKEEP (not `complete_current_phase()`, which would stall on TRAVEL — a phase with no UI of its own)
- **Turn modifications are ENFORCED, not just displayed**: p.85 Rival check (`_story_rival_suppression_reason()`), Find-a-Patron and Track crew tasks, and forced travel (`UpkeepPhaseComponent._apply_story_forced_travel()`)
- **Event 5 Evidence** (p.157) is produced by `StoryMarkerPanel` + `core/story/StoryMarkerInvestigation.gd` and reaches the track via `mission_data["story_evidence_found"]` → BattleResultNormalizer → StoryTrackProcessor → `add_evidence()`
- **Event 7 delay** (p.159): the clock hitting zero on the final event OPENS a 3-turn window; letting it lapse **loses** the story (`pending_completion_effects`, drained by `CampaignPhaseManager._drain_story_completion_effects()`), it does not grant the battle
- **State persistence**: `campaign.progress_data["story_track"]` → serialize/deserialize
- **Journal logging**: Story events → `create_entry(type="story")`, milestones → `auto_create_milestone_entry("story_track")`, per-character → `auto_create_character_event(char_id, "story_event")`
- **Story points**: +3 on Story Track win, +1 on loss (Core Rules p.160)

### CharacterDetailsScreen QOL (Session 36)
- **Portrait upload**: "Change Portrait" → FileDialog → resize 256x256 → `user://portraits/{char_id}.png`
- **CharacterEventTimeline**: Filterable event log component at `src/ui/components/character/CharacterEventTimeline.gd` — merges CampaignJournal timeline + entries, toggle filter buttons (All/Battle/Injury/Adv/Story/Kill)
- **Status bar**: Colored chips (ACTIVE/SICK BAY/DEAD, battles, kills, XP)
- **Stat coloring**: Green at max, red at 0 (combat/savvy/luck), orange for toughness≤3

### Battle Phase Manager
The battle system is a **tabletop companion assistant** (NOT a tactical simulator). All output is TEXT INSTRUCTIONS for the player to execute on the physical tabletop. Three-tier tracking: LOG_ONLY / ASSISTED / FULL_ORACLE.

**Live path**: `CampaignTurnController` → `PreBattleUI` → `TacticalBattleUI` →
Record Result → `PostBattlePhase`. `BattlePhase.gd` was DELETED in 99fad30b2 —
any doc or comment naming it as live is stale.

#### Battle-phase DELIVERY audit (Aug 6 2026) — the rule was right, the CALL was missing

Full narrative: [docs/audits/BATTLE_PHASE_DELIVERY_AUDIT_2026-08-06.md](docs/audits/BATTLE_PHASE_DELIVERY_AUDIT_2026-08-06.md).

**The transferable rule, which held five times in one day: when a rule appears missing, check whether a function implementing it already exists with NO CALLER.** Early returns, calls made before their target exists, drawers with no opener, and zero-caller producers all present as "the feature was never built". No key census can see this class — both halves exist and are correct. Only tracing execution order on the path a real campaign takes finds it.

#### Battle-phase audit sprint (Jul 30-31 2026) — rules now APPLIED, not just displayed

Full table of 12 fixes: [docs/audits/BATTLE_PHASE_AUDIT_SPRINT_2026-07-31.md](docs/audits/BATTLE_PHASE_AUDIT_SPRINT_2026-07-31.md). All are test-pinned — do not "simplify" them back.

**The defect shape: a value rolled, stored, displayed, and consumed by nothing.** Two traps worth keeping in mind: `fled_early` means the **p.123 XP rule** ("flees in the first 2 rounds"), NOT the p.91 Rival item-loss window ("before 4 rounds") — conflating them denies XP the book pays. And "Enemy Morale +1" (p.88 Bitter Struggle) means the Panic range goes **DOWN**.

#### The campaign-wide data flow sweep (Aug 1 2026) — the rest of the funnel

Full findings: [docs/audits/CAMPAIGN_DATA_FLOW_SWEEP_2026-08-01.md](docs/audits/CAMPAIGN_DATA_FLOW_SWEEP_2026-08-01.md).

**Two rules survive from it.** (1) *Anything called a "dead file" is a liability, not a curiosity — check what its only callers were before shelving it.* `phases/TravelPhase.gd` and `phases/WorldPhase.gd` have zero instantiations and between them held the ONLY callers of `record_invaded_planet()`, `repair_hull()` and the `fuel_credits` consumer, so three real mechanics were silently dead. (2) *A component created with `.new()` cannot resolve `get_node_or_null("/root/X")`* — the call ERRORS and aborts the enclosing function, silently returning the default. Add it to the tree before asserting, or the probe measures the trap rather than the code.

#### The battle-phase data funnel (Aug 1 2026) — the mission carries its own identity

Full key-by-key table: [docs/audits/BATTLE_PHASE_DATA_FUNNEL_2026-08-01.md](docs/audits/BATTLE_PHASE_DATA_FUNNEL_2026-08-01.md).

**THE GOING-FORWARD RULE (this is a RULE, not history): anything the post-battle sequence needs to know about the scenario must be stamped onto `mission_data` BEFORE the battle**, and pass through `BattleResultNormalizer` — the one chokepoint every path crosses (played, LOG_ONLY, in-battle auto-resolve, map auto-resolve). Adding a consumer read without a producer write is the bug, not the feature. `.get(key, default)` on a missing key is a silent default, not a fault, so nothing errors when the producer is absent.

Also still live: **a `has_method()` guard on a method with ZERO definitions repo-wide is a permanently-false branch, not a safety net.** `grep "func <name>"` before trusting one.

### Battlefield Terrain Generator (Session 50; rules-verified sprint 2026-07-02/03)

```text
CampaignTurnController._initiate_battle_sequence  ← SINGLE generation point (seeded)
  └─ CampaignPhaseManager.generate_battlefield(theme, traits, condition, seed, table_ft)
       └─ FPCM_BattlefieldGenerator (RefCounted, Compendium 5-step pp.94-95)
            ├─ data/battlefield/themes/compendium_terrain.json (4 BOOK themes)
            ├─ 11 world trait modifications (Core Rules pp.73-75)
            └─ Returns: {sectors, combat_notes, seed, table_size_ft, ...}
  └─ active_battlefield contract → GameState.set_battlefield_data()
       (writes through to campaign.progress_data["active_battlefield"] —
        survives save/reload; cleared post-battle)
  └─ Consumers render the SAME persisted map:
       PreBattleUI preview (+ per-battle table-size override)
       TacticalBattleUI (consume-first; standalone modes generate + write back)
       PostBattleSummarySheet recap
  └─ BattlefieldMapView (graph-paper canvas, square book tables via configure_grid)
       ├─ FPCM_BattlefieldGrid (geometry SSOT: p.108 sizes at 1.5"/cell)
       ├─ BattlefieldShapeLibrary (keyword → shape/color + rules categories)
       ├─ SectorRulesPopover (tap-a-sector: features + pp.37-39 rules + re-roll)
       └─ TerrainLegendStrip + scatter/regenerate controls (intel DRAWER only)
```

- **4 themes (book only)**: industrial_zone, wilderness, alien_ruin, crash_site (Compendium pp.96-98). The 3 synthesized themes (urban_settlement/wasteland/ship_interior) were REMOVED 2026-07-02 — do not re-add; planet-type/name heuristics remap onto the 4 (statics on the generator).
- **Table sizes**: 2×2 / 2.5×2.5 / 3×3 ft (Core Rules p.108) — SettingsManager `gameplay/table_size_ft` + PreBattleUI per-battle override. Grid is SQUARE (16/20/24 cells at 1.5″/cell); the old fictional 30″×20″ table is gone. Standard Terrain Set counts per size are PDF-verified in the JSON (p.109).
- **11 world traits**: overgrown (1D6+2 plants), warzone (1D3 ruins/craters), crystals (2D6), barren (strips vegetation), flat (strips hills + suppresses elevated minimum), haze/gloom/fog (visibility notes), frozen/reflective_dust/null_zone (combat notes) — pp.73-75.
- **Rules-audit fixes (do not regress)**: hill conversion is INDUSTRIAL-ONLY (p.97); toxic_environment is a combat note, NEVER terrain (p.88); deployment-condition ids accepted as `id` OR `condition_id`, case-insensitive; enemy deploy markers are book-exact (p.110: Beast = pairs across thirds, Defensive = 3 teams with Tactical); p.109 minimums injections are labeled "(suggested — Core Rules p.109 guideline)".
- **Seeded + persisted**: every generation uses an explicit seed; per-sector re-rolls use `hash(base_seed|label|count)` (engine RNG has no avalanche effect). Full sectors persist — a generator code change never rewrites an in-progress physical table.
- **Notable Sight (p.89)**: rolled in CTC, placed 2D6+2″ from center (polar, seeded), rendered via the objective-marker overlay, persisted in the contract.
- **Battle journey guidance**: `FPCM_BattleFlowGuide` (static, tested) feeds the EXISTING surfaces — Battle Card atop the pre-battle checklist (objective win text p.90 + condition + sight + enemy + table), 3-step deployment card (p.110), end-of-round condition prompts (p.88). No new docked chrome; the map's only interaction is tap-a-sector.
- **Badges**: `[L]/[In]/[B]/[F]/[A]/[I]` — Interior=[In] vs Individual=[I] (collision fixed via `get_category_badge`).
- **BattlefieldGridPanel DELETED** (was dead since the map-primary redesign); its legend/popover live on as TerrainLegendStrip + SectorRulesPopover.
- **Tests**: 50 cases across 8 suites (`test_battlefield_*`, `test_enemy_deploy_markers`, `test_battle_flow_guide`, `test_terrain_theme_data_pinning`) pin the audit fixes, seed determinism, geometry, and persistence.

### Narrative System (Phase 1, May 22 2026; scene composition + motion May 27)

King-of-Dragon-Pass-style full-screen narrative window for campaign events. Phase 1 wired to Story Track; Phases 2-6 will extend to CharacterPhase, CrewTaskEvents, Travel, PostBattle, and polish. **Authoring a scene? Read `docs/sop/narrative-scene-authoring.md` first** (layer contract, manifest schema, character slots, ambient motion, verification).

```text
NarrativeScreen.gd (CanvasLayer L95)
  └─ _root: Control (PRESET_FULL_RECT)
       ├─ BackgroundDim (ColorRect, blocks input)
       ├─ IllustrationFrame (Control, top 55%)
       │    ├─ GradientFallback (ColorRect, always-renders fallback)
       │    └─ SceneStage (the only rendering path for layered/flat art)
       ├─ NarrativePanel (PanelContainer, bottom 45%)
       │    └─ Title / Text / AdvisorRow / Briefing / Restrictions / Bonus / Choices
       └─ SkipButton (top-right)
```

- **CanvasLayer L95** (not Control): MUST extend CanvasLayer to render above chrome (L80 PersistentResourceBar, L90 NotificationManager). Wrap UI in `_root: Control` child for layout
- **NarrativeTextGenerator** (RefCounted, static SSOT cache): `compose_full_text(event_data, context)` → opener (from category) + trait modifier + verbatim core_text. Core Rules text is sacred
- **AdvisorSystem** (RefCounted, static SSOT cache): `select_advisor(role, crew, art_tag)` with **training > class > species** priority. 6 roles: Broker / Medic / Fighter / Tech / Scout / Social. 18-quote scaffold (1 per role×mood)
- **NarrativeChoiceButton**: Button + hint label, fires `choice_pressed(int)` signal
- **Data files** (`data/narrative/`): `atmosphere_openers.json` (5 categories + 12 trait modifiers + art_tag map), `advisor_quotes.json` (6 roles × 3 moods), `species_personality.json` (10 species)
- **Settings toggle**: `SettingsManager.are_narrative_events_enabled()` defaults `true`. Off path falls through to existing card UI (StoryPhasePanel)
- **Integration pattern** (replicate for Phases 3-5): in the phase panel's render method, branch on `SettingsManager.are_narrative_events_enabled()`. If on, instantiate NarrativeScreen, add to `get_tree().root`, listen for `narrative_completed`, delegate completion back to existing flow trigger (e.g. `_on_action_pressed()`)
- **Art tag fallback**: `StoryEvent` has no `get_art_tag()` accessor — `StoryPhasePanel._event_to_narrative_dict()` uses `"story_event_%02d" % event.event_number` fallback. All 7 Story Track event JSONs gained an `art_tag` field for Phase 3+ when the accessor lands
- **Chrome restore**: `_exit_tree()` (NOT `tree_exited` — see Gotchas) restores PersistentResourceBar visibility
- **Character slots (May 27)**: a scene manifest may declare `character_slots` geometry; the player's ACTUAL crew is composited as full-figure art keyed by `species_id` via `SpeciesFigureRegistry` (mirrors SpeciesPortraitRegistry, existence-aware variant pick). Captain → `hero` slot; other slots filled by `AdvisorSystem.select_advisor(role, crew)`. Depth uses **tree order** (a `SlotLayer` inserted between bg and actor layers), NOT `z_index` — crew always render behind baked foreground actors. Figures are feet-anchored (bottom-center) at the slot's normalized `anchor`; uniform humanoid shapes only (height-based scaling). `SceneStage.set_character_slots(assignments)`
- **Ambient "living painting" motion (May 27)**: `SceneStage` gives every scene a TINY scene-wide motion — per-layer sine **drift** (foreground drifts more than backdrop = subtle parallax) + slow **breathe** (Ken Burns scale), applied to the layer CONTAINERS (never individual rects, so it never fights slot layout). An **overscan** baseline (1.04) hides the letterbox edge drift would expose. Data-driven via the manifest `ambient_motion` block (absent/`{}` = on with defaults). **Gated by Reduced Motion** (`ThemeManager.is_reduced_animation_enabled()`)
- **Dev viewer**: `src/ui/screens/dev/SceneViewer.tscn` previews a manifest in isolation (`-- scene_id=X test_crew=precursor,swift,k_erin autoshot`). Motion is verified by a headless transform-probe, NOT a screenshot (see SOP §6)

### Key Patterns (Phase 5 Consolidation)
- **CampaignDashboard** uses `FiveParsecsCampaignPhase` (14 values, aliased as `FPC`). The old `CampaignPhase` enum (10 values) is deprecated.
- **BattlePhase._simulate_battle_outcome()** delegates to `BattleResolver.resolve_battle()` for rules-accurate combat. Injects `battlefield_data["seize_initiative_modifier"]` for Hardcore(-2)/Insanity(-3).
- **VictoryChecker.gd** — centralized victory condition checking (18 types), used by EndPhasePanel.
- **character_events.gd** — character phase event data/logic, used by CharacterPhasePanel.
- **DeploymentManager** `infer_deployment_type()` / `infer_terrain_features()` were DELETED 2026-07-02 (zero callers; the old claim here was stale).
- **EquipmentManager** has `get_sell_value()` for condition-aware resale pricing.

### Two Enum Systems (CRITICAL - Must Stay In Sync)

1. `src/core/systems/GlobalEnums.gd` — autoloaded as `GlobalEnums`
2. `src/core/enums/GameEnums.gd` — class_name `GameEnums`

Note: A third enum file (`src/game/campaign/crew/FiveParsecsGameEnums.gd`) was deleted in Sprint A Bug 3 (2026-05-24) along with the entire legacy `FiveParsecsCampaign` / `FiveParsecsCrew*` class family. The project went from 3-enum to 2-enum sync. See `project_sprint_a_bug3_modernization` memory for the rationale and dependency map.

### Character Data Model
- Canonical: `src/core/character/Character.gd` (class_name `Character`, ~1,900 lines)
- ⚠ There is NO base class. `Character.gd` is `extends Resource` directly. `src/core/character/Base/Character.gd` (`BaseCharacterResource`) and the `character_base.gd` API stub were DELETED Sep 4 2026 — production-dead, reachable only from tests. Every `src/` mention of `BaseCharacterResource` that survives is a COMMENT.
- Thin redirects: `game/character/Character.gd` -> extend Character
- **Stats are flat properties**: `combat`, `reaction`, `toughness`, `speed`, `savvy`, `luck` (NO `stats` sub-object)
- `CharacterStats.gd` exists as a separate Resource but is NOT used as a property on characters
- Implants: 11 types (Core Rules p.55), species-dependent max via `get_max_implants()` (De-converted=3, default=2). `Character.create_implant_from_loot()` does name-match scan (no separate map constant)
- **Strange Character fields**: `species_id` (JSON lookup key), `special_rules` (Array[String] from JSON), `xp_discount_stat` (Minor Alien), `unity_agent_trait_lost` (bool, persisted)
- **Helper methods**: `can_receive_luck()`, `can_earn_xp()`, `get_bonus_xp()`, `can_perform_task(task_id)`, `get_task_bonus(task_id)` (Empath +1), `get_max_implants()` (species-dependent)
- **Strange Character gameplay**: All 18 types fully wired (Session 52; corrected 2026-07-02). Unity Agent per-turn 2D6 in `CampaignPhaseManager._process_unity_agent_favor()`. Feeler mental breakdown in `CharacterEventEffects`. Species combat flags live in `Character._apply_species_bonuses()` modifier sources (book-exact: Hulker shooting flags p.21, Primitive limits p.22, Traveler retreat +2" p.22, Swift multishot p.18, Stalker teleport p.20, Bot/Soulless 6+ armor p.15/17, Assault Bot 5+ p.21). `BattleCalculations.get_species_combat_abilities()` was a fabricated DEAD block, deleted 2026-07-02 — do NOT re-add. Savvy-frozen (De-converted p.19, Assault Bot p.21) is gated in `Character.spend_xp_on_stat()` + `CharacterAdvancementService.can_advance_stat()`. K'Erin brawl = reroll only (p.16/p.45); the +1 flat bonus and Hulker +2 melee damage were fabricated and removed
- **SpeciesDataService.gd** (`src/core/character/SpeciesDataService.gd`): static RefCounted, lazy-loads `character_species.json`, provides `get_species()`, `get_forced_motivation()`, `can_roll_creation_tables()`, etc. Character.gd does NOT import it (load order) — uses inline string checks instead

### DLC/Compendium System
- 33 ContentFlags across 3 DLC packs (Trailblazer's Toolkit=7, Freelancer's Handbook=17, Fixer's Guidebook=9)
- DLC gating pattern:
```gdscript
var dlc = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
if dlc and dlc.is_feature_enabled(dlc.ContentFlag.SOME_FLAG):
    # DLC-gated code
```

### Store/Paywall System (Phase 24+34)
Tri-platform DLC purchase system using adapter pattern:
```
StoreManager (autoload) → StoreAdapter (abstract base)
  ├─ SteamStoreAdapter    → Engine.get_singleton("Steam") + steamInitEx()
  ├─ AndroidStoreAdapter  → BillingClient.new() (official GodotGooglePlayBilling)
  ├─ IOSStoreAdapter      → ClassDB.instantiate("StoreKitManager")  ← NOT a singleton!
  └─ OfflineStoreAdapter  → Fallback for editor/dev mode
```
- **Product IDs**: All in `StoreManager.gd` `PRODUCT_IDS` const — placeholder, swap before release. Includes 3 packs + compendium_bundle + bug_hunt
- **Plugins installed**: GodotSteam (addons/godotsteam/), GodotApplePlugins (addons/GodotApplePlugins/), GodotGooglePlayBilling (official Godot plugin)
- **Purchase flow**: StoreManager.purchase_dlc() → Adapter.purchase() → purchase_completed signal → DLCManager.set_dlc_owned() → DLCActivationToast
- **Bundle purchase**: `compendium_bundle` product maps to all 3 packs owned via StoreManager
- **Autoload timing**: Adapters use `load()` not `preload()`, path-based `extends` (not class_name)
- **iOS quirk**: `purchase()` takes a `StoreProduct` object (cached from query), not a string ID
- **Android**: Uses official `BillingClient` class — `purchase(product_id)` takes single string, auto-acknowledges non-consumables
- **Steam quirk**: Opens store overlay for purchase, ownership via `isDLCInstalled(app_id: int)`

### Store UI (Phase 34)
```
MainMenu → "Expansions" button → SceneRouter "store" → StoreScreen
  ├─ BundleCard (if < 3 packs owned, amber accent)
  ├─ DLCPackCard x3 (rich cards with feature lists)
  ├─ BugHuntCard (game mode section)
  └─ Footer (Restore Purchases, Rate, Help link)
```
- **DLCContentCatalog.gd**: Single source of truth for all marketing copy
- **DLCPackCard.gd**: Pre/post-purchase states, collapsible feature list
- **ExpansionFeatureSection.gd**: Reusable toggle component (campaign creation + settings)
- **DLCFeatureToggleRow.gd**: Atomic owned/locked toggle row
- **DLCUpsellBanner.gd**: Contextual banner (`DLCUpsellBanner.create_for_flag()`)
- **DLCActivationToast.gd**: Purchase notification (`DLCActivationToast.show_for_dlc()`)

### Review System (Phase 25)

Cross-platform in-app review prompts via ReviewManager autoload:

- **Android/iOS**: InappReviewPlugin (`Engine.has_singleton("InappReviewPlugin")`) — 2-step flow: `generate_review_info()` → `launch_review_flow()`
- **Steam**: Opens store page via overlay (`activateGameOverlayToWebPage()`)
- **Offline**: No-op
- **Timing**: MIN_TURNS_BEFORE_REVIEW=5, REVIEW_COOLDOWN_DAYS=30, persisted to `user://review_prefs.cfg`
- **InappReviewPlugin file layout**: everything lives under `addons/InappReviewPlugin/` — `plugin.cfg`, the `.gd` files, and the AARs in `bin/{debug,release}/`. ⚠ **CORRECTED Sep 5 2026 (T11-10).** This line used to say the AARs belonged in a **root-level** `InappReviewPlugin/bin/`, describing that split as deliberate. It is the deprecated **v1** layout: Godot 4 resolves the paths `_get_android_libraries()` returns relative to `addons/`, so the root copy was never read and the Gradle build failed with *"Transform's input file does not exist"* the moment the plugin was actually enabled. The root `InappReviewPlugin/` directory still exists and is vestigial. ⚠ The plugin must ALSO be listed in `project.godot`'s `[editor_plugins] enabled`, or none of this runs and the export silently omits it. ⚠ The two AARs are the one `*.aar` exception in `.gitignore` (negations at `.gitignore:52-53`) because they are a build INPUT — without them a fresh clone cannot build the Android target.
- **class_name collision fix**: Root copy `InappReviewPlugin/InappReview.gd` has NO class_name; `addons/` copy retains it

---

## Key Autoloads (from project.godot)

| Autoload | Path | Purpose |
|----------|------|---------|
| GlobalEnums | src/core/systems/GlobalEnums.gd | Shared enum definitions |
| SettingsManager | src/autoload/SettingsManager.gd | Single owner of `user://options.cfg`; boot-time apply (audio/vsync/fullscreen/UI scale), live-apply on change, FPS overlay, haptic helper |
| GameState | src/core/state/GameState.gd | Campaign state singleton |
| GameStateManager | src/core/managers/GameStateManager.gd | State mutation helper |
| GameDataManager | src/core/managers/GameDataManager.gd | Data loading |
| DataManager | src/core/data/DataManager.gd | Data persistence |
| DLCManager | src/core/systems/DLCManager.gd | DLC feature flags |
| StoreManager | src/core/store/StoreManager.gd | Platform store adapter bridge |
| ReviewManager | src/core/store/ReviewManager.gd | Cross-platform in-app review prompts |
| DiceManager | src/core/managers/DiceManager.gd | Dice rolling |
| SceneRouter | src/ui/screens/SceneRouter.gd | Scene transitions |
| EquipmentManager | src/core/equipment/EquipmentManager.gd | Equipment operations |
| CampaignPhaseManager | src/core/campaign/CampaignPhaseManager.gd | Turn phase orchestration |
| CampaignJournal | src/core/campaign/CampaignJournal.gd | Auto-entries, timeline |
| TurnPhaseChecklist | src/core/campaign/TurnPhaseChecklist.gd | Phase completion tracking |
| LegacySystem | src/core/campaign/LegacySystem.gd | Campaign archival |
| NPCTracker | src/core/campaign/NPCTracker.gd | NPC tracking |
| KeywordDB | src/autoload/KeywordDB.gd | Keyword tooltips |
| PlanetDataManager | src/core/world/PlanetDataManager.gd | Planet persistence |
| PlanetCache | src/core/world/PlanetCache.gd | Planet data cache |
| WorldEconomyManager | src/core/world/WorldEconomyManager.gd | World economy |
| ResourceSystem | src/core/systems/ResourceSystem.gd | Resource management |
| TweenFX | addons/TweenFX/TweenFX.gd | Animation addon (70 animations, auto-lifecycle) |
| FactionSystem | src/core/systems/FactionSystem.gd | Faction/rival management + DLC expanded factions |
| LegalConsentManager | src/core/legal/LegalConsentManager.gd | EULA/privacy consent, analytics opt-in, data export/delete |
| CampaignAnalytics | src/core/analytics/CampaignAnalytics.gd | In-memory analytics (Phase 0.6 — promoted from RefCounted to Node autoload; class_name removed) |
| TaloAnalyticsAdapter | src/core/analytics/TaloAnalyticsAdapter.gd | Bridges CampaignAnalytics signal → Talo telemetry SDK, gates on consent, null-safe pre-Talo-install |

---

## UI Design System - Deep Space Theme

**Source**: `src/ui/screens/campaign/panels/BaseCampaignPanel.gd`
**Project Theme**: `src/ui/themes/sci_fi_theme.tres` (set in `project.godot` → `gui/theme/custom`)
**Fonts**: Montserrat-Regular (body), Montserrat-SemiBold (buttons), Montserrat-Bold (titles), CourierPrime-Regular (monospace)
**Max Form Width**: `BaseCampaignPanel.MAX_FORM_WIDTH := 800` (centered on wide screens via `_apply_content_max_width()`)
**Portrait Avatars**: `CharacterCard._update_portrait()` prefers `portrait_path`, falls back to colored initials (8 deterministic colors from name hash)

### Theme constants — ONE canonical copy, not here

Spacing (8px grid), touch targets, the typography scale, the colour palette and the BBCode colours
live in **`.claude/skills/ui-development/references/deep-space-theme.md`** and nowhere else.

They were previously maintained in four places at once — this file, that reference (byte-identical),
`.claude/agents/ui-panel-developer.md`, and its agent memory. Four copies of a number set is how a
design system drifts. Never hardcode a colour or size; prefer the `BaseCampaignPanel` factory
methods below.

### Helper Methods (panels extending FiveParsecsCampaignPanel)
- `_create_section_card(title, content, description)` - Styled card container
- `_create_labeled_input(label_text, input)` - Label + input pair
- `_create_stat_display(stat_name, value)` - Stat badge
- `_create_stats_grid(stats, columns)` - Grid of stat displays
- `_create_character_card(name, subtitle, stats)` - Character display
- `_style_line_edit(line_edit)` - Apply styling to LineEdit
- `_style_option_button(option_btn)` - Apply styling to OptionButton

### Reusable Widget Library (`src/ui/components/common/`, 14 files)

> **⚠ Liveness is NOT implied by this table (verified 2026-07-30).** Several rows
> describe components that exist and are documented but are referenced by nothing
> in `src/`: **`InlineRenameWidget`**.
> (`OverflowMenu`, `BookFrame` and `OrnamentPanel` were on this list and were all
> DELETED Sep 4 2026 — unreachable from product AND tests. Seven other
> built-but-unwired components went with them: `BattlefieldFindCard`,
> `QuickActionsFooter`, `CampaignTurnProgressTracker`, `MissionStatusCard`,
> `WorldStatusCard`, `PostBattleSummarySheet`, and the terrain passthrough that
> fed the last of those.) They are
> built and usable, but not currently wired into any screen — so
> "CLAUDE.md lists it" is not evidence a component is in use.
>
> ⚠ This warning also used to list `ContactMarkerPanel`, `DiceFeed` and
> `AttackResolutionOverlay` as "built and usable, not currently wired". All
> three were **DELETED** in `5125a0e4` ("delete 236 orphaned files found by a
> new reachability lint"). A note that describes a deleted file as merely
> unwired sends the next reader looking for it. Run
> `python scripts/lint_orphan_assets.py` for ground truth, and see
> `docs/WIRING_CLEANUP_BACKLOG.md` tier 7 for the wire-or-delete triage.

| Component | Class | API |
|-----------|-------|-----|
| `EmptyStateWidget` | VBoxContainer | `setup(title, flavor, action_text, callback)` → `signal action_pressed` |
| `LoadingScreen` | CanvasLayer L99 | `start_loading(tasks)`, `set_task_active(idx)`, `complete_task(idx)`, `run_sequence()` |
| `AcknowledgeDialog` | Window | Static: `AcknowledgeDialog.show_message(parent, text)` → `signal acknowledged` |
| `StepperControl` | HBoxContainer | `setup(initial, min, max, step)` → `signal value_changed(int)` |
| `InlineRenameWidget` | VBoxContainer | `setup(name, hint)` → `signal renamed(String)` |
| `PersistentResourceBar` | CanvasLayer L80 | `show_bar()`, `hide_bar()`, `refresh()` |
| `PreviewButton` | Button | `set_preview_data(dict)` → `signal preview_requested(Variant)` |
| `ItemPreviewPopup` | Window | Static: `ItemPreviewPopup.show_preview(parent, data)` |
| `HubFeatureCard` | PanelContainer | `setup(icon, title, desc)` → `signal card_pressed` |
| `DialogStyles` | RefCounted | Static: `style_confirm_button(btn)`, `style_danger_button(btn)`, `style_primary_button(btn)` |
| `RulesPopup` | Window | Static: `RulesPopup.show_rules(parent, title, body, requirements)` |
| `CalloutCard` | PanelContainer | Sharp-corner Elite-Ranks-style callout (StyleBoxFlat + colored stroke + title inline upper-left). `setup(title, content, color)`. 5 semantic colors |

### CanvasLayer Layering Convention
```
Layer 80  — PersistentResourceBar (campaign resources overlay)
Layer 90  — NotificationManager (toasts, battle events)
Layer 95  — NarrativeScreen (full-screen KoDP-style event overlay)
Layer 99  — LoadingScreen (itemized loading)
Layer 100 — TransitionManager (fade overlay), DLCActivationToast
```

---

## Testing

### Frameworks
- **gdUnit4** v6.0.3 — primary test framework
- GUT addon was **removed** (Feb 2026); ~20 test files still need migration

### Test Directories
```
tests/unit/          # Unit tests (~178 files)
tests/integration/   # Integration tests (~54 files)
tests/battle/        # Battle-specific tests
tests/performance/   # Performance benchmarks
tests/mobile/        # Mobile-specific tests
tests/fixtures/      # Test helpers and factories
```

### QA Scenarios (debug builds only — Aug 8 2026)

Campaign Dashboard → **QA** button (gated on `OS.is_debug_build()`, so a release export
cannot reach it). Jumps a loaded campaign to a state that is expensive to play to —
injuries/Sick Bay, Compendium mission types, rivals+patrons+an active Quest, or the
endgame/failure block. Built because two full turns on device produced zero injuries, zero
XP spent, no Rival attacks and no Compendium mission.

- `src/core/qa/QAScenarioLoader.gd` — ALL mutation. `src/ui/screens/dev/QAScenarioDialog.gd`
  is presentation only.
- Fixtures are **deltas, not save files**: `data/qa_scenarios/*.json`, applied through the
  same owner setters the Campaign Editor uses (note `story_points` → `set_story_progress`;
  salvage goes through `SalvageLedger` as a computed delta). They survive a `schema_version`
  bump because they never touch the serialized shape.
- **It deliberately does not jump the PHASE** — deep-linking builds states the real flow
  never produces, which generates false findings. Scenarios set campaign state and hand back.
- `apply()` returns a receipt (`applied` / `warnings`), never a bool: a scenario that
  silently skipped half its setup is worse than none.
- **Forcing a rare table roll (Sep 4 2026).** `DiceManager.queue_forced_result(context_key, value)`
  parks a value that the NEXT roll whose context contains `context_key` consumes, ONCE.
  Both ends gated on `OS.is_debug_build()`; surfaced in `QAScenarioDialog` as "Force the
  next roll". Matching is a case-insensitive SUBSTRING (so `"character event"` reaches a
  roll made as `"Character Event: Bryn Ito"`), and an out-of-range value is **DISCARDED,
  never clamped** — clamping would hand a tester a different row than they asked for.
  **No rules data is touched**, which is why this was chosen over widening `roll_range`.
  Built to unblock T9-47 / T9-48 / T9-51 (`docs/qa/PICKUP_2026-08-14.md` §3).
  ⚠ Two dead trails found while routing: **`DataManager.get_trade_result` /
  `get_exploration_result` are commented out in full** and their only callers are in the
  dead `phases/WorldPhase.gd` — the live Trade/Explore D100 is
  `CrewTaskComponent._resolve_table_task()`. And **`MissionTableManager` is RefCounted,
  always built with `.new()`**, so its `_roll_die()` reaches the autoload via
  `Engine.get_main_loop()`; a bare `get_node_or_null("/root/...")` there does not return
  null, it ERRORS and aborts the roll.
- `tests/unit/test_qa_scenarios.gd` (13 cases) loads the byte-identical fixtures, so device
  QA and CI cannot drift. Two guards are detection-proven: a fixture counter key with no
  `GameStateManager` setter, and a crew field outside `_CREW_FIELDS`. Add a fixture key
  without a consumer and they go red.

### Headless Verification (compile check)
```powershell
& "C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" --headless --quit --path "c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager" 2>&1
```

### Running Tests
```powershell
& "C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" `
  --path "c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager" `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_character_advancement_costs.gd `
  --quit-after 60
```

---

## Development Patterns

### Autoload Null-Guard
```gdscript
var system = get_node_or_null("/root/SystemName")
if system and system.has_method("some_method"):
    system.some_method()
```

### Resource Class Instantiation
Non-Node classes (extending Resource/RefCounted) must be instantiated with `.new()`:
```gdscript
var story_track = FPCM_StoryTrackSystem.new()
var battle_events = FPCM_BattleEventsSystem.new()
```

### Preload Pattern for UI Class References
```gdscript
const MyPanelClass = preload("res://src/ui/components/MyPanel.gd")
var panel = MyPanelClass.new()
```

### No Deferring Rule (MANDATORY)
If a task is listed in a sprint or work plan, it MUST be completed in that sprint. No deferring to "later sprints," "future work," or "backlog." Items marked deferred get lost and never return.
- If a task cannot be completed, explain WHY immediately — do not silently skip it
- If scope is too large, split it into smaller deliverable pieces and complete all pieces NOW
- "Deferred" is not a valid task status. Valid statuses: Done, Blocked (with reason), Cut (with user approval)
- The user must explicitly approve any item being cut from a sprint

### Signal Architecture
- Parent calls down to child (direct method calls)
- Child signals up to parent (`signal_name.emit()`)
- Phase panels emit `phase_completed` signal with completion data
- Campaign creation panels emit typed signals; CampaignCreationUI uses lambda adapters to convert to Dict format for coordinator

### Campaign Creation Coordinator Pattern
```gdscript
# CampaignCreationUI wires panels to coordinator:
coordinator.navigation_updated.connect(_on_navigation_updated)
coordinator.step_changed.connect(_on_step_changed)

# Panel signal adapters (Control-based panels → Dict format):
panel.captain_updated.connect(func(captain): coordinator.update_captain_state({"captain": captain}))
```

---

## Agent & Skill Architecture (Token Optimization)

**Six** specialized agents (consolidated from nine on 2026-08-06). Model tiers reflect cost/latency, not how much you can trust an agent's findings:

| Agent | Model | Domain |
| ----- | ----- | ------ |
| `character-data-engineer` | **sonnet** | Character model, **both enum files**, JSON data, equipment, world |
| `campaign-systems-engineer` | **sonnet** | Campaign creation/turns, save/load, state management |
| `battle-systems-engineer` | **opus** | Battle state machine, combat resolution, deployment, victory |
| `gamemode-specialist` | **sonnet** | Bug Hunt + Planetfall + Tactics, and all cross-mode safety review |
| `ui-panel-developer` | **sonnet** | UI components, Deep Space theme, responsive, narrative, sheet export |
| `qa-specialist` | **opus** | Testing, QA, gdUnit4, cross-system verification |

**Retired 2026-08-06.** `bug-hunt-specialist` / `planetfall-specialist` / `tactics-specialist` merged into `gamemode-specialist` (their bodies were structurally identical and two of their `cross-mode-safety.md` references were byte-identical). `fpcm-project-manager` was deleted — it wrote no code, had no spawn mechanism, and its roster/dependency-order content is this table plus `agent-roster.md`. Read those directly instead of paying an Opus spawn for routing advice.

### Agent Files

- **Definitions**: `.claude/agents/*.md` (6 files). Every one sets `tools`, `maxTurns`, `effort` and `memory: project`.
- **Memory**: `.claude/agent-memory/{agent-name}/MEMORY.md` — auto-loaded into the agent's system prompt, so **keep each under 200 lines**. Pre-consolidation session logs are archived in `docs/archive/agent-memory-logs/`.
- **Skills**: `.claude/skills/{skill-name}/SKILL.md` + `references/*.md` (10 skills). The three gamemode skills were kept separate — they are the on-demand detail behind the merged agent.
- **Guardrails**: `MAX_THINKING_TOKENS`, `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`, `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`, `CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION` in `.claude/settings.local.json`. **Never set `CLAUDE_CODE_SUBAGENT_MODEL`** — it outranks the per-invocation `model` parameter and would prevent bumping a model per task.

### Routing Rules

- Route by **file ownership** (`.claude/skills/fpcm-project-management/references/agent-roster.md`).
- `character-data-engineer` exclusively owns the **2** enum files (two-enum sync; `FiveParsecsGameEnums` was deleted 2026-05-24 — any note saying "three enums" is stale).
- `gamemode-specialist` owns all of `src/ui/screens/{bug_hunt,planetfall,tactics}/`, the three variant campaign cores, and `data/{bug_hunt,planetfall,tactics}/`; it reviews every shared-file change (`TacticalBattleUI`, `GameState`, `SceneRouter`, `GameStateManager`, `CampaignScreenBase`).
- **Never route a variant gamemode to `campaign-systems-engineer`** — incompatible data models.
- `qa-specialist` is always the final verification step.
- Dependency order: data → campaign → battle → gamemode → UI → QA.
- **Prefer the built-in `Explore` agent for read-only recon.** It skips CLAUDE.md and git status entirely (custom agents cannot), so it is far cheaper — but it therefore knows none of the rules in this file, so restate anything it needs in the delegation prompt. Pass a per-call `model`: `haiku` for mechanical retrieval, `sonnet` for anything requiring a liveness or wiring judgement.

---

## Dev Environment & Workflow

### Synology Drive Sync
Project lives in `SynologyDrive/` — background sync touches file timestamps, triggering phantom change events. Mitigated by Cursor `files.watcherExclude` and Godot `checkOnChange: false`.

### Godot Ports (from docs)

- **6005** — LSP (GDScript language server)
- **6006** — DAP (Debug Adapter Protocol)
- **6007** — Editor connection

### MCP Servers (`.mcp.json`)
Versions are **pinned** — do NOT change to `@latest` (causes npm downloads on every agent start). To update, run `npm view <package> version` and update the version string.

### Import Cache (`.godot/imported/`)
Godot never cleans orphaned cached imports. If the cache grows large (>600MB) or causes crashes, delete `.godot/imported/` — Godot regenerates it on next editor open.

### File Watcher Exclusions
Both `.vscode/settings.json` and Cursor user settings exclude: `.godot/`, `.mcp/`, `node_modules/`, `mcp-servers/`. The `.cursorignore` file additionally excludes `*.import` and `*.uid` from AI indexing.

### Python Tools

Python 3.14.2 is available via `py` launcher (NOT `python` — Windows app alias blocks that).

**ALL rules data MUST be extracted from the PDFs via PyPDF2.** This is the only PDF tool used in this project — do NOT install or reference PyMuPDF, fitz, pdfplumber, or any other library.

- **PyPDF2** 3.0.1 — the canonical and ONLY PDF extraction tool

Use for: extracting game data values from rulebook PDFs, verifying text extractions, batch PDF operations.
Example: `py -c "from PyPDF2 import PdfReader; r = PdfReader('docs/rules/Five Parsecs From Home-Compendium.pdf'); print(r.pages[5].extract_text())"`

---

## Data Ownership — Single Source of Truth (Phase 2.1+, Apr 2026)

**This is a TABLETOP COMPANION APP.** Data models mirror physical play: a character sheet, item cards, a ship stash box. Every concept has ONE canonical owner. All mutations go through the owner's setter. Direct writes to non-owned locations are banned and flagged by `scripts/lint_data_ownership.py`.

| Concept | Canonical Owner | Mutation API | NEVER write to |
|---|---|---|---|
| Credits / supplies / reputation / story_points | `FiveParsecsCampaignCore` top-level @vars | `GameStateManager.set_credits()` etc. (writes through to campaign) | `progress_data["credits"]` (deleted) |
| Per-character equipment | `Character.equipment` on each crew member | `EquipmentTransferService.transfer_to_character()`, `.transfer_to_stash()`, `.generate_starting_loadout()` | Direct `.equipment.append()` from outside the service |
| Ship stash | `campaign.equipment_data["equipment"]` | `EquipmentTransferService.add_loot_to_stash()`, `.transfer_to_stash()` | Direct stash array mutations |
| Crew members (incl. captain) | `campaign.crew_data["members"]` (captain has `is_captain: true`) | `campaign.add_crew_member(member_dict)` for additions after creation (forces `is_captain=false`, rebuilds `_crew_id_index`); `campaign.get_crew_member_by_id()` for reads (cached O(1)); captain MUST be in members array, not only in `captain_data` | Ad-hoc `for member in crew_data["members"]` loops (use the helper); direct `crew_data["members"].append()` from outside (use `add_crew_member`) |
| Turn number | `campaign.progress_data["turns_played"]` | `CampaignPhaseManager` reads/writes through campaign | Direct `progress_data["turns_played"] =` from outside |
| Campaign phase | `CampaignPhaseManager.current_phase` (runtime) | Persisted to `campaign.game_phase` on save only | Direct `campaign.game_phase =` from UI code |
| Campaign crew size (4/5/6) | `FiveParsecsCampaignCore.campaign_crew_size` @export | Set at creation via `CampaignFinalizationService`; read via `GameState.get_campaign_crew_size()` chain | `get_crew_size()` (that's roster count, not the fixed setting) |

### Key files
- `src/core/equipment/EquipmentTransferService.gd` — chokepoint for all equipment movement (RefCounted, instantiate per operation)
- `src/core/state/GameState.gd:verify_consistency()` — debug invariant checker, call at phase transitions
- `scripts/lint_data_ownership.py` — CI lint, run with `py scripts/lint_data_ownership.py`
- **Wiring-audit lints (Jul 10 2026, `py scripts/<name>`)**: `lint_signal_wiring.py` (signals declared but never emitted — flags "live dead-wires" where a listener can never fire), `lint_tscn_connections.py` (`.tscn [connection method=]` must resolve to a real `func` on the target's script — catches dead buttons), `lint_autoload_lookups.py` (`/root/Name` must be a project.godot autoload or an evidence-allowlisted runtime node; `# lint:ignore` marks intentional test seams like the MockDiceSystem `/root/DiceSystem` injection). **All three are CLEAN (exit 0) as of Aug 6 2026** — the legacy backlog they were introduced to track (67 signals / 6 tscn / 35 autoload) is CLOSED. They are now a regression guard: a new finding means you just introduced one.
- **`lint_data_ownership.py` is CLEAN (exit 0) as of Aug 6 2026.** It supports `# lint:ignore` as a TRAILING comment on the offending line (not the line above — it matches the same line). Use it only where the write is genuinely justified and say why at the site; the two current exemptions are in `TravelEventResolver` / `CampaignEventEffects`, which are parameterised by campaign and so cannot delegate to a singleton bound to a different one.
- **`lint_journal_vocabulary.py` (sixth lint, Aug 8 2026)**: every `type` / `tags` value in a journal `create_entry()` call must exist in `JournalEntryTypes.STRING_TO_TYPE` / `.TAGS`. `validate_entry()` only `push_warning()`s, so a typo is invisible except as log noise — but a non-canonical type falls to `EntryType.CUSTOM` and drops out of type-filtered journal views, and a non-canonical tag renders unlabelled and uncoloured. Found 17 type + 27 tag uses on introduction (the QA row that prompted it named 2). **⚠ Scope it to `create_entry()` calls only** — matching `"type": "..."` anywhere in `src/` reports ~200 false hits, because weapon/terrain/mission/world/enemy taxonomies all use the same key name. Never tag a runtime value (an item id, a character name): a tag is a fixed vocabulary.
- **`lint_multiline_statement_breaks.py` (seventh lint, Sep 3 2026)**: flags a top-level declaration (`const` / `func` / `var` / `signal` / `@onready` ...) sitting at column 0 **while a bracket is still open**, i.e. an edit that landed INSIDE a multi-line statement. It has bitten twice: once loudly (a new function inserted into `func _update_travel_button_text(`'s parameters) and once **silently and expensively** — a `const ... = preload(...)` inserted between the two halves of an existing `preload(` continuation in `CheatSheetPanel.gd`. That second one stopped the file parsing, so `TacticalBattleUI._instance_log_only_components()` failed on `_get_res("cheat_sheet").new()` and **ABORTED `_setup_ui()`** — the live battle screen stopped building partway through, with every lint green and the panel's own 14-case suite green. ⚠ It must carry an unterminated string ACROSS lines: GDScript (unlike Python) accepts a raw newline inside a `"..."` string and `test_persistent_injuries.gd:524` uses one on purpose, which produced 7 false findings off one line in the first version. CLEAN (902 scripts, 0 findings) and detection-proven.
- **`lint_dead_has_method_guards.py` (EIGHTH gating lint, promoted Sep 4 2026)**: a `has_method("X")` guard where `func X` has ZERO definitions repo-wide is a permanently-false branch, not a safety net. It replaces the old report-only `scan_dead_has_method_guards.py`. Like the other seven it is a **regression guard**: the 62 findings present at promotion are in an `ALLOWLIST` **with a reason each** (platform/GDExtension probes that genuinely must be runtime-checked — GodotSteam, Google Billing, StoreKit, libharu; sites inside production-dead files; comment text and dynamically built names; and guards with a working fallback branch), so **a new name means you just introduced one**. It also prints STALE entries whose guard is gone, so the allowlist cannot silently rot. This trap has now bitten five times: `damage_hull()` (Aug 1), `journal.get_entries()` (Aug 9 — the printable sheet had never received a single journal entry on any platform), `show_notification` (Sep 3), and on Sep 4 both `is_house_rule_enabled` (the entire house-rules feature, 8 call sites) and `mark_rival_defeated` / `register_patron_contact`. ⚠ **Its ground truth is project code only.** `ROOT.rglob("*.gd")` also walks `.mcp/` — an MCP server's vendored cache of ~2,800 unrelated GDScript files whose `func` definitions MASK real dead guards in `src/` and drift as that cache changes (two runs minutes apart reported 12,424 and 14,879 definitions). `_NON_PROJECT` excludes it; 198 names existed only there.
- **`lint_orphan_assets.py` reports THREE categories and exits 1 on `orphans` or `test_only`.** Measured 2026-09-07: `files=560 reachable_from_product=559 **test_only=0 orphans=0 unwired_rules=1**`, exit 0. ⚠ **This bullet was STALE and is corrected rather than deleted, because it was wrong in a way that would have cost the next reader real time**: it claimed `test_only` was **41** and a live "wire-or-delete backlog", and named **BookFrame** and **OrnamentPanel** as members — both of which were DELETED on 2026-09-04 and are absent from disk, as the two other entries in this same file already said. The production-dead backlog CLOSED that day (`test_only` 39 → 0); there is no list to preserve. ⚠ **CORRECTED 2026-09-10: all three categories are now ZERO** — measured `files=561 reachable_from_product=561 test_only=0 orphans=0 **unwired_rules=0**`. This bullet used to name **`src/data/tactics/TacticsOperationalMap.gd`** as the one `unwired_rules` entry, "complete and book-faithful with zero callers", and a wire-or-delete decision for the owner. **It has since been WIRED and that clause is stale**: `TacticsOperationalMapPanel.gd:25` preloads it and `TacticsTurnController.gd:63` loads that panel for Phase 7 (STRATEGIC). Deploy #35 watched it render on the tablet — Cohesion 5/5, Player Battle Points 1/3 after a victory, and the nine Operational Turn Steps cited to pp.96-99. ⭐ The correction is kept rather than deleted because the note pointed at a dead book chapter that is now alive, and a reader acting on it would go looking for a wiring job that is already done. The `unwired_rules` CATEGORY is still the right idea — it exists so a book chapter with no caller stays visible instead of being mistaken for an orphan and deleted — it simply has no members today.
- `tests/unit/test_equipment_persistence.gd` — 7 tests covering save/load round-trip, ownership rebuild, and tabletop invariants
- `tests/unit/test_equipment_transfer_service.gd` — 10 tests covering the transfer service API

### Tabletop invariant: one item, one home
An equipment item is like a physical card — it exists in exactly one location (a character's sheet OR the ship stash, never both, never neither). `EquipmentTransferService` enforces this via atomic remove-then-add transfers with rollback on failure. The invariant is verified at runtime by `GameState.verify_consistency()` CHECK 4.

---

## ⚠ The ledger closed Aug 7, and TWO page walks reopened it Sep 3 (+18 fixed, +2 corrected)

The Aug closure was accurate and it was not the end — its own caveat said why.
Eight auditors walked eight SUBSYSTEMS; nobody walked every PAGE. Walking what
was left found sixteen more rows and **three failure shapes no census in this
project can see**. Full section at the bottom of
`docs/RULES_WIRING_AUDIT_2026-08.md`; the three shapes are:

1. **The data file was a faithful extraction of the WRONG BOOK.**
   `data/RulesReference/EnemyAI.json` held the COMPENDIUM pp.42-43 "AI
   Variations" tables under a Core Rules label, and three consumers printed them
   with no DLC gate — so a player who owned nothing was told to roll 1D6 per
   enemy activation (Core Rules p.42: "The default AI is diceless"), while the
   seven core routines were in the app nowhere. Producer, consumer, key, flag
   and call site were all present and consistent. **Check a rules file's
   PROVENANCE, not only its contents.**
2. **The rule is right; the DESIGNER changed it.** Five rows matched the printed
   page exactly and are now wrong. `docs/gameplay/rules/5P_errata_and_tweaks106.pdf`
   and the designer FAQ overturn book-literal code, and **a page cite proves the
   code followed the book, not that the book still says that.**
3. **The write is undone before the read.** `MainMenu` set
   `temp_data["onboarding_mode"]` and then called a function whose first act is
   `clear_all_temp_data()`. Both halves correct; the ORDER erased the value.

### The SECOND walk (Core Rules pp.12-135) found the blind spot in our METHOD

The eight August audits were organised by SUBSYSTEM — `battle-resolution`,
`battle-setup`, `economy-trade-equipment`, `factions-world-compendium`,
`missions-elites-zones`, `patrons-rivals-quests`, `post-battle`,
`turn-upkeep-travel`. Every one names a CAMPAIGN or BATTLE concern, so together
they cover pp.63-135 well. **Nobody owned pp.12-62 — Character Creation and Main
Rules — and all three gaps were there.** pp.63-135 came back clean.

**A subsystem census cannot see a chapter that is nobody's subsystem.** When
choosing audit axes, check the ones nobody picked.

The three fixes: the p.14 Crew Type Tables (a FLAT `randi() %` pick where the
book weights 60/20/10/10, so randomised crews came out ~69% Strange Characters
against a book value of 10%); p.60 Getting a New Ship (complete resolver, ZERO
callers, so a crew that lost its ship could never get another); and the p.24
Leader exemption from random-event departure (quoted in a comment, enforced
nowhere). One row is REPORTED not fixed: the p.13 crew-composition methods are a
product decision, not a wiring gap. Full section at the bottom of
`docs/RULES_WIRING_AUDIT_2026-08.md`.

⚠ **Two CONFIRMED rows are recorded there so nobody "fixes" correct code:** the
75-credit ship-debt threshold (the BOOK contradicts itself between p.60 and p.76;
the code follows p.76, the procedural page) and the Cheat Sheet's
"covered within 6 inches: 5+" To Hit row (added by errata v1.06 p.4, absent from
p.44 alone).

### Previous standing, still true of what it measured

`docs/RULES_WIRING_AUDIT_2026-08.md`: **0 open / 0 partial / 136 fixed / 1 corrected.**
`verify_post_battle` 47/47 · `verify_battle_ui` 79/79 · all four lints CLEAN ·
headless `--import` parse-clean. Every fix detection-proven by isolated revert.

**Read the zero correctly.** It means every row someone WROTE DOWN has a call site
and a test. Eight auditors walked eight subsystems; nobody walked every page of
both books. The going-forward guard is the four `scripts/lint_*.py` plus the
per-row tests — never this count.

### ⭐ The shape of nearly every closing row: correct code, no call site

| Module | Accessors that were byte-faithful and had ZERO callers |
|---|---|
| `WorldTraitEffects` (SSOT for all 31 campaign-side traits) | **11** |
| `BlackZoneSystem` | **4** |
| `FactionSystem.attempt_faction_favor()` | complete — p.112 needs a crew task nobody built |
| `PatronJobEffects` | `blocks_rival_tracking()`, `offers_new_job_on_success()` |
| `SalvageMissionPanel.get_salvage_units()` | 1 — every salvage unit died with the battle screen |

**The check that finds the whole class in one pass:** for a resolver or service
module, enumerate its public accessors and grep each for an EXTERNAL caller.
`tests/unit/test_final_partial_rows.gd::test_every_world_trait_accessor_has_a_live_consumer`
does exactly that and now FAILS if a new accessor lands without one. Copy that
shape to any other rules-resolver module you add.

### Three traps to carry forward

1. **A displayed number that exists nowhere else is a lie waiting to be found.**
   Any UI literal describing a mechanic must READ the same data the mechanic does.
2. **Check the price you charge against the price you check.** A modifier landing
   on a cost must go through BOTH the affordability guard and the charge, or a
   player can add what they cannot pay for.
3. **A `contains()` assertion is not evidence a call runs.** Three times this audit
   a source scan survived `if false and TheCall(`. Anchor on the exact enabling
   form, and always RUN the mutation — a plausible revert that changes nothing is
   how a dead control survives. See [[reference_a_red_harness_row_is_a_lead_not_a_verdict]].

### New SSOT files from the closeout — use these, do not re-implement

| File | Owns |
|---|---|
| `src/core/campaign/SalvageLedger.gd` | Compendium p.147 salvage units, the Scrapper, and the ONLY three purchases salvage may pay for (ship repairs / modules / bot upgrades) |
| `src/core/campaign/InvasionFlight.gd` | Core Rules p.69 flee consequences — contact loss, sell-gear-at-a-loss, evacuation passage |
| `src/core/systems/FactionFavorService.gd` | Compendium p.112 — the six Faction favors and the once-per-turn gate |
| `src/core/world/InterdictionRule.gd` | Core Rules p.75 Interdiction (the only licence roll in live play besides p.72) |
| `src/core/equipment/OnboardItemService.gd` | Core Rules pp.57-58, all 19 On-board Items |
| `src/core/equipment/WeaponModService.gd` | Core Rules p.53 Gun Mods and Sights |

**Empty-container trap, learned the hard way while writing `SalvageLedger`:**
guarding on `pd.is_empty()` to mean "no campaign" silently disabled salvage for
every fresh campaign — an empty `progress_data` is a LEGAL state. Guard on the
OWNER (`campaign != null and "progress_data" in campaign and ... is Dictionary`),
never on the container's emptiness. A unit test that constructs the emptiest legal
object is worth writing for exactly this class.

**One suppression chokepoint, four rules.** `CampaignTurnController._story_rival_suppression_reason()`
now carries Story Events, Black Jobs (p.150), Private Transport (p.84) and Provide
Cover (Compendium p.112). Add the fifth there too — a second place that can
suppress the same roll is how the p.120 Rival payment rule ended up duplicated.

---

## Data Integrity Rules

- **THE CORE RULES AND COMPENDIUM ARE THE CANONICAL AUTHORITY FOR ALL GAME MECHANICS.** Every mechanic name, stat value, table range, cost, probability, weapon property, species trait, and game term in this project MUST match the Core Rules and Compendium PDFs exactly. These books are the **default dictionary** — if the code says one thing and the book says another, the book is right and the code is wrong. No exceptions. No "balancing." No "improvements." The books define the game.
- **NEVER invent game data values**: When adding or modifying any numeric game data (stats, costs, ranges, probabilities, D100 table boundaries), the value MUST come from the Core Rules book. AI agents must ask the user for book values rather than guessing. Tag intentional deviations as `GAME_BALANCE_ESTIMATE`.
- **CHECK `data/RulesReference/` FIRST**: 18 JSON files extracted from the rulebooks/Compendium PDFs exist at `data/RulesReference/`. ALWAYS check these before inventing values. They cover: Bestiary, Campaign rules, Difficulty, Elite Enemies, Enemy AI, Equipment, Expanded Missions, Factions, Name Tables, Psionics, Salvage, Species, Stealth/Street, Terrain. If the data you need isn't in RulesReference, extract it from the PDF using Python (see Dev Environment).
- **Core Rules PDFs available in repo — USE THEM**: Both the Core Rulebook and Compendium PDFs are at `docs/rules/`:
  - `docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf` — Core Rules 3e
  - `docs/rules/Five Parsecs From Home-Compendium.pdf` — Compendium
  - `docs/rules/bug_hunt_compendium_extract.txt` — partial Compendium text extraction (Bug Hunt section)
  - `docs/rules/planetfall_source.txt`, `docs/rules/tactics_source.txt` — expansion-book text extractions
  - NOTE: there is NO committed full-text extraction of the Core Rulebook or main Compendium. Extract pages on demand via PyPDF2 (see Dev Environment). Text extractions may have OCR artifacts — verify against the PDF when precision matters
- **NEVER "fix" data without the book**: Phase 30 changed ship hull from 20-35 to 6-14, documenting it as a "Core Rules correction." The Core Rules actually says 20-40. The "fix" made it WORSE. Never assume a value is wrong without checking the source material.
- **`GAME_BALANCE_ESTIMATE` = fabricated = REMOVE**: Sessions 22-23 purged 20+ fabricated mechanics that were tagged `GAME_BALANCE_ESTIMATE` and treated as "resolved." Deleted systems include: MoraleSystem (no campaign morale in Core Rules), equipment upgrade/pricing formulas, per-enemy loot generators, fabricated XP sources, and named bot upgrades. If the book doesn't have it, the code shouldn't either.
- **NEVER create duplicate data sources**: If a value already exists in a JSON file, load it from there. Do not create a parallel constant in GDScript. Single Source of Truth: JSON file is canonical for each data domain.
- **All data changes require book page citation**: Include the Core Rules page number in commit messages when modifying game data. Example: `"Fix Infantry Laser range to 30" (Core Rules p.50)"`
- **Data Source Authority Hierarchy (absolute, no exceptions)**:
  1. **Core Rules PDF + Compendium PDF** — Word of God. Always right. Extract with `py -c "from PyPDF2 import PdfReader; r = PdfReader('...'); print(r.pages[PAGE].extract_text())"` (PyPDF2 ONLY — no PyMuPDF/fitz)
  2. `data/RulesReference/*.json` — Direct extractions from the PDFs. Trust these, but verify against PDF if suspicious
  3. Dedicated JSON data file in `data/` — May have errors introduced by agents
  4. GDScript constants file — Lowest code authority
  5. Inline hardcoded values — Least trustworthy, often wrong
  When sources disagree, the higher-authority source wins. ALWAYS.
- **Verification checklist**: See `docs/QA_RULES_ACCURACY_AUDIT.md` for the master verification checklist (745+ values across 131 files).

---

## Gotchas

- **A cap can be computed, enforced, displayed — and then thrown away by the handler that starts the battle (Sep 6 2026, T11-48; FIXED and DEVICE-VERIFIED same day)**: `PreBattleUI.setup_crew_selection()` pre-selects up to `max_deploy` (`:922-925`) and `_on_character_selected()` refuses a toggle past it (`:937-943`); `CampaignTurnController._launch_pre_battle_directly()` computes `deploy_limit = campaign_crew_size + crew_cap_delta`, applies the p.84 `crew_cap_max` ceiling AFTER the deltas, and passes it in (`:1837-1847`). **Then `_on_deployment_confirmed()` rebuilds the crew from scratch** — `var crew_data = _deployable(game_state.get_active_crew())` (`:2777`), the whole roster. `get_selected_crew()` (`PreBattleUI:1151`) has **ZERO callers repo-wide** and the `crew_selected` signal is connected by nobody. So the p.91 Rival Ambush cap, the p.88 Small Encounter sit-out and the p.84 Small Squad ceiling of 4 **all fail to bind**, and any crew the player deselects still fights. Measured on the tablet: **6/6 deployed in an AMBUSH whose `crew_cap_delta` was -1**. ⚠ **The same handler reads `selected_tier` (`:2784`) and `selected_representation_mode` (`:2768`) off that very object two lines away** — so the boundary is crossed for the tier and not for the crew, which is why this reads as wired. ⚠ **The comment at `:1835-1836` already claims the fix**: *"The cap was previously always the full campaign crew size, so neither ever bit."* That fix landed on the COMPUTING half only. When a comment says a rule now bites, check the consumer of the value it computes. ✅ **FIXED**: the rule is now `BattleSetupRules.apply_crew_selection()` (a pure static beside `apply_enemy_delta()`, its enemy-side analogue), `_on_deployment_confirmed()` calls it, and `setup_crew_selection()` was made idempotent — it cleared neither the panel nor `selected_crew`, so a re-entry kept the OLD picks, which was cosmetic only for as long as nothing consumed them. Identity is `BattleCheckpoint.member_key()`, reused rather than re-implemented. ⚠ Every ambiguous input returns the roster UNTOUCHED: an empty selection means the selector never ran, not that the player chose to field nobody. Pinned by `tests/unit/test_deployment_selection.gd` (17 cases), whose call-site case exists because every other case would still pass with the handler ignoring the rule again. ✅ **VERIFIED ON HARDWARE (deploy #24)**: the same D1 snapshot and the same forced AMBUSH that measured 6/6 on #23 now field **5**, `progress.active_battle.crew` 6 -> 5, with `rival_attack_type`, `crew_cap_delta -1`, `can_seize false`, `campaign_crew_size 6` and the 6-member roster all identical across the two runs. ⚠ **The fixture is what makes that discriminating** — all six crew are ACTIVE with no Sick Bay and no `skip_next_battle`, so `_deployable()` filters nobody and `apply_crew_selection()` is the only thing that can turn 6 into 5. ⚠ The `Deploying N / M max` counter could NOT be read on screen at 2560x1600: the Select Crew pane is pane 4 of 4 against `max_columns = 3`, so it wraps to row 2 and gets header height only — **pre-existing, identical on the pre-fix build**, and it does not block the rule because the pre-select is programmatic.
## Gotchas

- **A NODE-PATH EXISTENCE GUARD THAT NAMES A GRANDCHILD IS PERMANENTLY FALSE — and it costs nothing until the guarded code runs twice (Sep 10 2026, deploy #35)**: `CharacterDetailsScreen.populate_ui()` guarded with `hero_card.get_node_or_null("__ChangePortraitBtn")`, but `_setup_portrait_upload()` adds that button to `__HeroOverlay`, a **child** of hero_card (the card is a `Container`, which would override the button's anchors — the reason the overlay exists is in its own docblock). **`get_node_or_null(name)` is a DIRECT-CHILD lookup, not a search**, so the guard asked for a grandchild by its bare name, got null every time, and never fired. Identical at the `__PrintSheetBtn` call site two lines below. ⭐ **The guards were written for the pre-overlay layout and never moved when the buttons did** — the writer relocated, the reader stayed; the same shape that broke `TacticsCampaignUnit` the same day, where deleted constants left their readers behind. ⚠ **A permanently-false guard is FREE until the guarded function becomes re-entrant.** `populate_ui()` ran once per screen entry for the life of the screen; the crew pager made it re-entrant and every page turn then leaked two buttons onto the card, surfacing as a stray clipped "Change Portrait" at the card's top edge. When you make a build function re-entrant, audit its idempotence guards — they were written under an assumption you just removed. ⚠ **AND THE FIRST TEST WAS GREEN AGAINST THE LIVE LEAK.** When an explicit `name` collides with a sibling, **Godot DISCARDS the requested name** and falls back to its default `@<ClassName>@<id>` form — measured: `["__ChangePortraitBtn", "__PrintSheetBtn", "@Button@128", "@Button@129", "@Button@210", ...]`. A substring count for `"ChangePortrait"` therefore reports exactly ONE however many leak. Count the container's **children by class**. The detection harness is the only reason this was caught: *assert where the damage lands*.
- **A CONSUMER READING TWO KEYS NO PRODUCER WRITES PRINTS A PLAUSIBLE LIE FOREVER (Sep 10 2026, deploy #35)**: `TacticsDashboard._build_battle_history()` renders `"Turn %d: %s — CP earned: %d"` from `entry.get("turn", 0)` and `entry.get("cp_earned", 0)`, while its producer — `TacticsCampaignCore.record_battle()` — appended `result.duplicate(true)` and the live caller (`TacticsTurnController` :365/:373) sets **only `won`**. Measured on the tablet: a **Turn-1 victory that awarded 12 CP** displayed as **"Turn 0: Victory — CP earned: 0"**. ⚠ `.get(key, default)` on a missing key is a **silent default, never a fault**, so nothing errors and no test that builds its own fixture can see it — this is the documented battle-phase funnel defect ("adding a consumer read without a producer write is the bug, not the feature") in a mode nobody had swept. ⚠ **Fix it at the chokepoint that owns BOTH facts.** `record_battle()` appends the entry *and* computes the CP award, so stamping `turn` and `cp_earned` there keeps them from drifting; teaching the VIEW to re-derive the turn would have put a second copy of "which turn is this" in the UI. ⚠ The stamp must ADD to the entry, never replace it — `won` still drives the Victory/Defeat label and its colour. ⓘ A suspicion checked and DISMISSED rather than reported: the save has no top-level `campaign_points`, which looked like the 12 CP was not persisted. It is — `state.campaign_points_earned`. Check before filing.
- **THE SPEND SIDE OF A CURRENCY IS A SEPARATE AUDIT FROM THE AWARD SIDE, and deleting dead code with a wrong value does not fix the live copy (Sep 10 2026, deploy #35)**: the Tactics Advancement phase offered three buttons — "Unit Upgrade (1 CP)", "Roster Change (1 CP)", "Battle Advantage (1 CP)" — and `_on_spend_cp()` charged a flat `_cp_spent += 1` for any of them. **Tactics pp.107-108 price ELEVEN distinct purchases at 1-4 CP**; the headline error is *"Unit Upgrade (1 CP): Acquire a veteran skill"* against p.107's **Gain Veteran Skill (4 CP)** (`tactics_source.txt` line 7099). ⭐ **This is the twin of the CP AWARD bug fixed 2026-09-04** — both are a fabricated flat number standing in for a book table — and it survived that fix because the auditor was reading what CP a player EARNS and never looked at what they PAY. **When you correct one half of a currency, sweep the other half in the same pass.** ⭐ **It is also the LIVE copy of a value deleted as dead hours earlier**: `TacticsCampaignUnit.add_veteran_skill(skill, cost := 1)` was removed that same session precisely because 1 CP contradicts p.107, on the reasoning that "an uncalled function carrying a wrong book value is the most expensive kind of dead code". The corpse was removed and the disease stayed in the UI. **When deleting dead code because a VALUE is wrong, grep the VALUE, not the function.** ⚠ The fix is `TacticsCampaignCore.CP_PURCHASES`, a page-cited SSOT of all 13 purchases that the panel's explanatory card AND its buttons both render from, so the prose a player reads is the CP they are charged — never put a mechanic's numbers in a UI literal. `_on_spend_cp()` charges the table's price behind an affordability guard, because *check the price you charge against the price you check*. ⚠ An unknown purchase id costs **0, and 0 means REFUSE, never free**. ⚠ The purchase EFFECTS remain deliberately unwired (no unit picker); this corrects what a purchase COSTS, which is a rules value the book states outright, and does not invent the feature.

- **A DOCBLOCK NAMED A MODE THE GUARD NEVER CHECKED, and the abort surfaced in an unrelated suite (Sep 10 2026)**: `TacticalBattleUI._setup_stars_battle_ui()`'s section comment says Stars of the Story are *"Disabled in non-5PFH battle modes (Bug Hunt / Planetfall / **Tactics**)"*, and the guard reads `_is_bug_hunt_mode or _is_planetfall_mode or _is_standalone_battle()` — **there is no Tactics flag anywhere**. Bug Hunt / Planetfall / Tactics cores all omit `stars_of_the_story` deliberately (Compendium p.214 forbids carry-over), so `campaign.stars_of_the_story` on one of them is `Invalid access to property`, which **ABORTS the enclosing function** — the class-(b) silent abort — taking the rest of the Stars setup with it. Seven reads and writes of that field exist in the file and **all seven route through one accessor**, `_get_campaign_for_stars()`, which returned `gs.get_current_campaign()` with no type test; the three write sites (`campaign.stars_of_the_story = stars.serialize()`) would also have CREATED the field on a core the book says must not carry Stars. ⚠ **Guard on the OWNER, not on mode flags**: `"stars_of_the_story" in campaign` is order-independent, needs no new flag, and covers a fourth gamemode the day it is added — the same shape as `CampaignEditorScreen._campaign_supports_crew_editing()` and as T11-49, where a screen shared between modes answered *"is this campaign mine?"* from the wrong signal. ⭐ **How it was found is the transferable part**: adding three test suites shifted the batch boundaries of the full run, moving `test_terrain_generation_gate.gd` out of the process that had just run the Tactics suites and into the NEXT one — where `GameState` auto-loads whatever campaign the previous batch last saved. Six of its eight cases then errored with `'stars_of_the_story' on a base object of type 'Resource (TacticsCampaignCore)'` while the suite still passed **8/8 in isolation**. ⚠ **Batch composition is a test variable.** A suite that builds real screens is measuring the disk state a previous PROCESS left behind, so a green full run is partly an accident of alphabetical ordering — and adding a suite can re-roll it. When a suite goes red only in a full run, read the error before assuming the new code caused it: here the new code was innocent and had merely changed where the boundary fell.
- **A DECLARED, PERSISTED SETTING WITH ZERO READERS IS NOT INERT — it is what makes an absence look like a fact (Sep 10 2026)**: `GameState.default_settings` declared `auto_load_last_campaign` (default **false**), `save_settings()` wrote it to `user://settings.cfg` on every save, and `_try_auto_load_last_campaign()` (`:150`) loaded a campaign at EVERY launch gating only on `last_campaign` being non-empty. The key had zero readers repo-wide, and it cost two real defects: **T11-49** (a Battle Simulator session erased the campaign's in-progress battle, because `TacticalBattleUI` answered *"is this campaign mine?"* from the ABSENCE of a campaign and a campaign was always present — measured on device, `active_battle` True → False, 81,221 → 63,641 bytes) and the cross-suite bleed that made `test_touch_scroll_sweep` fail only when it ran AFTER the Tactics suites. ⚠ **The rot mechanism is `load_settings()` + `save_settings()` as a pair**: the loader copies EVERY key it finds in the file, not only the known ones, and the saver writes the whole dict straight back — so a key that reaches disk once is **immortal** unless something erases it. `GameState.LEGACY_SETTINGS_KEYS` is that eraser; the same shape now guards Tactics unit records via `TacticsCampaignUnit.normalize()`. ⭐ **The key was DROPPED, not renamed carrying its value.** Every install that has ever run this app has `auto_load_last_campaign=false` on disk, and that `false` is not a player choice — it is a default nothing honoured. Migrating the value would have hidden the Continue button (`MainMenu.update_continue_button_visibility()` → `has_active_campaign()`) on every existing device, including the QA tablet, the first time the setting became live. The replacement `continue_last_campaign_on_launch` defaults **true**, so behaviour is unchanged until a player turns it off. ⚠ It lives in `GameState.game_settings` (`user://settings.cfg`), NOT in `SettingsManager`'s `options.cfg`, and the Settings row is the ONE row in that section not bound via `_bind_toggle()` — the value has to be readable from `GameState._init()`, where `get_node_or_null("/root/SettingsManager")` does not return null, it **ERRORS and aborts the enclosing function**.
- **A COLUMN THE BOOK HAS NO CONCEPT OF PRINTS 0 FOREVER, and "who fought?" already had an answer nobody read (Sep 10 2026)**: `TacticsDashboard._create_unit_card()` printed four stats per roster unit — Models / Battles / Wins / CP — and **three of the four were permanently 0**. `battles_fought` / `battles_won` were initialised at creation and displayed at `:414/:424` with no writer anywhere (their only producer, `TacticsCampaignUnit.record_battle()`, had zero callers). `campaign_points` was never per-unit at all: **Tactics p.106** — *"Players use Campaign Points (CP) to track their progression"* — and the chapter's own heading *"Are Points Tied to the Player or Army?"* offers exactly two answers, neither of them per-unit, so that column printed a hard 0 beside the header's REAL campaign CP. ⭐ **The product question dissolved on inspection.** "When has a unit fought?" looked like an owner call; the app already computes it and threw it away — `TacticsBattleSetupPanel._campaign_unit_ids()` (`:247-257`) lists every non-destroyed unit at DEPLOYMENT and `TacticsPhaseManager` stamps it onto `campaign.current_battle["deployed_units"]` (`:240-241`), where nothing read it. A producer with no consumer sitting one layer above a consumer with no producer. ⚠ p.106's *Weakened* result is what makes the record load-bearing rather than decorative: *"until the unit can sit out a campaign battle without being deployed, it must deploy with one figure fewer than normal."* ⚠ **An uncalled function carrying a WRONG book value is the most expensive kind of dead code** — `add_veteran_skill(skill, cost := 1)` priced a veteran skill at 1 CP against p.107's **4 CP**, and it reads as implemented, so the next person to need the rule wires it instead of reading the page. It is gone; the live store is `TacticsCampaignCore.veteran_skills`, keyed by unit_id. ⚠ `TacticsCampaignUnit` is now a **static helper over the unit `Dictionary`**, not a `Resource` — the Resource had ~15 `@export`s, `to_dict()` and `from_dict()`, and **nothing ever built one**; the Core stores plain Dictionaries in both directions. Two shapes for one concept is exactly what broke that file on Sep 10 (declarations deleted, their readers left behind, whole class failed to parse, Tactics creation dead in product).
- **`_unhandled_input` CANNOT SEE A GESTURE THE ScrollContainer WANTS — and no mouse filter can fix it (Sep 10 2026)**: `CharacterDetailsScreen`'s crew-swipe navigation lived in `_unhandled_input()`, which by definition only receives events **no Control claimed**. The sheet sits in a `ScrollContainer`, and `ScrollContainer::gui_input` takes `InputEventScreenTouch`/`ScreenDrag` for its own touch-drag scrolling and `accept_event()`s them, so on any touchscreen the swipe was consumed one layer above the handler — every time, since the feature shipped. ⚠ **This is NOT the §2 sweep's problem and the §2 remedy makes it no better**: that sweep converts `STOP` → `PASS` so a drag can REACH the ScrollContainer, and here the ScrollContainer is precisely the control that wants the event. `_input()` runs before GUI delivery and is the only place the whole gesture is visible. ⚠ **Split the families deliberately**: the KEYBOARD branch stays in `_unhandled_input()`, because this screen edits a name in a `LineEdit` that must keep Left/Right for its caret — moving that to `_input()` pages the roster mid-word. ⚠ **Do not `set_input_as_handled()` to suppress a tap**: `emulate_mouse_from_touch` pushes a SEPARATE `InputEventMouseButton` for the same finger, so consuming the touch does not suppress the click and only leaves the ScrollContainer holding a press whose release it never saw. The thresholds are the discrimination — 96 px, under 0.4 s, ≥2:1 horizontal — and a second pointer vetoes, as `TapGesture` does. ⭐ **It was dead at BOTH ends**: `_crew_list` is filled from `crew_list_for_swipe`, whose only producer is `CrewManagementScreen._store_crew_list_for_swipe()` — and that screen did not COMPILE until Sep 10. ⚠ And its one affordance was mis-parented: `_build_page_dots()` called `add_child()` on the screen ROOT, a bare `Control`, which does not lay out its children, so the dot row rendered at (0,0) over the header instead of under the sheet. **An invisible gesture that works is indistinguishable from one that does not** — the pager now carries ‹ › buttons and lives in `MarginContainer/PageColumn`.
- **`open(p, "w").write(f(p))` TRUNCATES BEFORE `f` READS — and in a revert harness every arm then reads as UNDETECTED (Sep 10 2026)**: Python evaluates `io.open(path, "w")` **first**, which truncates the file to zero bytes, and only then calls the argument expression — so `io.open(t, "w").write(isolate(t, case))` wrote an empty test suite. gdUnit4 then reported *"No test cases found, abort test run!"* for all six detection arms, which reads as "the fixes are not detectable" when it actually means "the harness deleted the tests". ⚠ **The tell is uniformity**: six unrelated reverts across three files cannot all fail to be detected; when every arm agrees, suspect the instrument. ⚠ The same line is SAFE when the source is read into a variable first (`body = open(p).read()` … `open(p,"w").write(body.replace(...))`), which is why the neighbouring fix scripts using the identical idiom worked — the trap is only live when the write target and the read source are the same file. Same family as the documented *"the write is undone before the read"* ordering defect, this time in the tooling rather than the app.
- **A PARSE ERROR IN A SCREEN IS INVISIBLE UNTIL IT SURFACES THREE SUITES AWAY — and no lint here could see it (Sep 10 2026)**: a full run reported **18 errors across three unrelated suites**; all of them were ONE line. `CrewManagementScreen.gd:171` called `_create_character_card()` with **five** arguments against the `CampaignScreenBase` copy that takes **four**. GDScript reports arity at PARSE time, so the whole screen failed to compile and **was dead in product**, not merely untested — and because `load()` on a parse-broken GDScript still returns a NON-NULL GDScript, the only symptom is `Invalid call. Nonexistent function 'new' in base 'GDScript'` at the first `.new()`, in whatever suite happens to touch it. That reads like a broken harness, not a broken screen. ⚠ **Every existing guard is structurally blind to this class**: `--headless --quit` validates only STARTUP scripts, `godot --check-only` EXITS 0 while printing the parse error, `lint_multiline_statement_breaks.py` looks for edits landing inside a statement (this call was well-formed, just wrong in arity), and a text-scanning suite reads the file with `FileAccess` and never compiles it. **`tests/unit/test_every_script_compiles.gd` is the guard**: it `load()`s all 483 scripts under `src/` and asserts `can_instantiate()`. ⚠ It MUST run under gdUnit4, never as a `--script` SceneTree probe — a bare probe does not register autoloads, so every script naming one as a bare identifier reports `Compile Error: Identifier not found: TweenFX/SceneRouter/GameStateManager` and 4 of 7 probes in one run were false positives from exactly that. ⭐ **The root shape is ONE helper with TWO copies**: T11-51 added `identity_name` to `BaseCampaignPanel._create_character_card()` only, and `CrewManagementScreen` extends the other base — so fixing the arity fixed the captain-avatar bug too, because they were the same omission. ⚠ On its FIRST run the new guard found a second dead script, `src/data/tactics/TacticsCampaignUnit.gd` (loaded by `TacticsCreationCoordinator.gd:55`, so **Tactics campaign creation was broken**): three fabricated CP constants were correctly deleted when the real p.106-107 rule was found, and **the deletion removed the DECLARATIONS and left the three lines that USED them**. Deleting a constant means deleting its readers in the same edit.
- **gdUnit4 is FAIL-FAST, and its case count means "executed", not "discovered" (Sep 10 2026)**: `GdUnitCmdTool` aborts a suite at the first failing case, and the summary line then reads `Statistics: 1 test cases | 0 errors | 1 failures`. ⚠ **That looks exactly like the documented parse-failure signature** ("No test cases found", exit 0) and means the OPPOSITE. The practical consequence is that a detection proof which reverts one fix can only ever see the FIRST case that fix breaks — every later case is silently never executed, so "one case failed" is not evidence the others still pass. **Run each case ALONE** by renaming the others `func off_*` (gdUnit4 discovers on the `test_` prefix); a harness that does this is worth keeping. It caught two of this session's own mistakes: a FALSE-GREEN case that passed under a reverted gate (`_build_terrain_controls()` returns early outside SETUP/DEPLOYMENT, so "no button found" was trivially true), and a detection proof aimed at the wrong arm of a belt-and-braces fix.
- **A suite that measures REAL SCREENS inherits whatever campaign a PREVIOUS suite happened to save (Sep 10 2026)**: `test_touch_scroll_sweep` builds 27 real screens and failed in two consecutive full runs while passing **4/4 in isolation**. `GameState.save_campaign()` writes `last_campaign` to **`user://settings.cfg`** (⚠ NOT `options.cfg` — two repro attempts were wasted on the wrong file), and `_try_auto_load_last_campaign()` loads it at EVERY launch. So the Tactics suites leave a **TacticsCampaignCore** loaded for every process that starts afterwards, and 5PFH-only screens abort against it — `Nonexistent function 'get_crew_members'`, which unwinds `_ready()` and leaves the screen half-built and silent. ⚠ **"It passes when I run it alone" was the wrong conclusion**: that is the T11-01 shape, where a layout sweep was green for a month because it measured four EMPTY panes, so the PASSING runs were the misleading ones. A test that measures a real screen must PIN its campaign context in `before_test()` — ⚠ but clear **only a non-5PFH core**, never unconditionally, or the pin hands back the very false green the suite exists to prevent. ⭐ **The root enabler is a dead setting**: `settings.cfg` contains `auto_load_last_campaign=false` and `_try_auto_load_last_campaign()` (`GameState.gd:150`) **never reads it** — zero readers repo-wide; it gates only on `last_campaign` being non-empty. ⚠ Related trap in test teardown: `DLCManager.set_dlc_owned(id, false)` disables **every** feature flag of that pack (`:146-148`) — thirteen for `freelancers_handbook` — so a teardown that restores one flag leaves twelve Compendium features off for the rest of the process, and on a dev machine where the pack is genuinely owned that switches REAL entitlements off.
- **A blank state that cannot explain itself is indistinguishable from a broken one (Sep 10 2026)**: an empty campaign battle map was filed as a rendering defect **four times** across the tablet walk. It was never a defect — `TERRAIN_GENERATION` is a `freelancers_handbook` ContentFlag, `_owned_dlcs` starts `{}`, and a base-game player correctly gets `CampaignPhaseManager._blank_table_contract()`: a labelled 4x4 grid with the random LAYOUT withheld and the grid, table size, deployment zones, objective/Sight markers and p.109 guidance all still owed. **What was broken is that the app could not SAY so.** The blank contract ships *"Terrain Generation is off — lay out the table as you like."* as summary **line 0**, and `TacticalBattleUI`'s Setup tab rendered **`lines[1]`**, because for the GENERATOR's contract line 2 is the Compendium theme description. The two contracts share a shape on purpose, so the blank one inherited a reader written for the other and its explanation was dropped. ⚠ **Do not "fix" it by rendering line 0 unconditionally** — the generator's line 0 is `"Theme: <name>"`, already printed in amber two lines above, so that ships a duplicate; the discriminator is `player_defined_terrain`, a key its producer had always written and **nothing had ever read**. ⚠ Separately, the gate had ONE enforcement site against THREE generator call sites: two "Regenerate Terrain" controls and a per-sector re-roll on the campaign battle screen called the generator directly, so the withheld content was one button press away. The Battle-Simulator demo exception belongs in ONE predicate (`_layout_generation_allowed()`), not repeated per caller.
- **T11-49's ownership confusion had a SIXTH consumer, and only real glass found it (Sep 10 2026)**: `TacticalBattleUI._build_battle_card()` called `gs.get_battlefield_data()` unconditionally, which reads THROUGH to `campaign.progress_data["active_battlefield"]`, so a **Battle Simulator** battle announced the CAMPAIGN's briefing verbatim — measured on deploy #34 two screens apart: the card said `Enemy: 7 x opponents` / `Condition: Caught Off Guard` / `Notable Sight: Loot Cache` / `Battlefield: Your Table — 3x3 ft` while the same screen's enemy list showed **5 Vent Crawlers** and its map showed a fully generated table. ⭐ **T11-49 audited five consumers of this predicate; those five were caught because TWO of them WROTE** (one `erase()`d the campaign's in-progress battle) and a write can be diffed out of a save file. This one only mis-DISPLAYS, so no assertion anywhere could see it — it took a card and an enemy list contradicting each other on screen. **The map was right throughout, which is precisely what hid it.** When auditing a predicate, enumerate the READ-ONLY consumers too; they fail silently and forever.
- **`project.godot` DISCARDS COMMENTS — you cannot document a setting where it lives (Sep 9 2026)**: it is a GENERATED file. Godot rewrites it on save (including during an export) and strips every `;` comment, then re-sorts keys alphabetically within a section. A 10-line block explaining **`input_devices/pointing/android/enable_pan_and_scale_gestures=true`** was written, survived a full test run, and was **gone after the next Android export** — leaving a bare line with no stated reason, which is precisely the kind of thing a later reader tidies away. ⚠ The diffstat is the tell: `project.godot | 10 ++++` became `project.godot | 1 +` with no edit in between. Put the reason in the CODE THAT DEPENDS ON THE SETTING (`BattlefieldMapView._gui_input` names this one explicitly), in the QA row, and here — never only in `project.godot`. Same family as the Gradle-daemon trap that leaves `export_format` flipped: an export is a WRITER of tracked config, not just a reader, so check `git diff` on `project.godot` and `export_presets.cfg` after every build.
- **A tap-vs-drag slop test cannot see a defect whose cause is POINTER COUNT (Sep 9 2026, deploy #30→#31)**: `emulate_mouse_from_touch` synthesises pointer 0 only, and a **second pointer CANCELS that emulated press**. The cancel arrives as a LEFT **release** still inside the 16 px slop, so `TapGesture`-style discrimination — which only ever watches ONE pointer travel — passes it through as a genuine tap. Measured: a two-finger pinch on the battlefield map zoomed correctly **and** opened the sector popover under finger one. ⚠ **Every headless case passed with this live**, because the handler logic is correct; the missing input is how many fingers are down, which the mouse family structurally cannot observe. The fix is to let the TOUCH family **veto** an armed tap (`InputEventScreenTouch` with `index > 0` disarms) while performing **no action of its own** — that is what keeps it clear of the T11-36 double-fire trap, where the defect came from *acting* in both pointer families. ⚠ `TapGesture` still has this exposure at all 52+ call sites; it is harmless on surfaces nobody pinches, which is why the two maps veto locally rather than the shared helper being changed underneath everything.
- **An ownership question answered by ABSENCE is one auto-load away from being wrong — and it cost a player their in-progress battle (Sep 8 2026, T11-49; FIXED in deploy #29)**: `TacticalBattleUI` is shared between the campaign and Battle Simulator, and `_is_standalone_battle()` (`:987`) decided "is this campaign mine?" from two absences — an empty `_battle_mode_id`, or a null `GameState.current_campaign`. **Both are silently false for Battle Simulator.** It is 5PFH-flavoured so it stamps no `battle_mode`, and `GameState._try_auto_load_last_campaign()` (`:150`) loads a campaign at EVERY launch, gating only on `last_campaign` being non-empty — it never reads the `auto_load_last_campaign` setting declared at `:79`, which has **zero readers repo-wide**. So once the player owns any save, the predicate returns FALSE for a standalone battle, and the docblock's own parenthetical — *"no current_campaign at all (Battle Simulator, MCP/demo, tier-select mode)"* — was wrong about all three. ⭐ **Five consumers read that false negative, and the worst one had no test at all**: `_clear_battle_checkpoint()` (`:5664`) calls `clear_active_battle()` → `progress_data.erase("active_battle")` → `save_campaign()`, and its callers are **Record Result** and **Return** — so merely opening the simulator and pressing Return **DELETED** the campaign's in-progress battle (measured on device: `active_battle` present True → False, 81,221 → 63,641 bytes). `_queue_checkpoint_save()` (`:5522`) overwrote it instead (measured twice, from two different entry points); `_persist_battlefield_contract()` (`:7915`) let the standalone battle CONSUME the campaign's saved table (its own FALLBACK branch names "Battle Simulator" as a case it could never reach); and the Stars popup (`:8879`) gated on `_is_bug_hunt_mode or _is_planetfall_mode` — a THIRD notion of ownership — so a standalone battle could spend a once-per-campaign Star (p.67). ⚠ **Writes reach DISK with no explicit save and no clean exit**: both checkpoint functions call `save_campaign()` on the same frame, so `force-stop` does not save you. ⚠ **The fix must be a POSITIVE signal** (`mission_data["standalone"]` → `_standalone_declared`), and it must NOT ride on `battle_mode`: that field is passed to `BattleResolverRouter.resolve()` and read by `CampaignTurnController._should_present_narrative_wrap()`, which vetoes the wrap for any non-empty non-`"standard"` value, so declaring ownership there would silently change auto-resolve routing. ⭐ **The scoping result is worth as much as the fix**: 18 other `current_campaign == null` sites exist and every one is a plain null-guard inside a screen only reachable WITH a campaign — `TacticalBattleUI` is the only screen shared with a standalone mode, hence the only place "is there a campaign?" and "is this campaign MINE?" can diverge. ⚠ Two fixtures encoded the old signal list: `test_battlefield_writeback_guard.gd` cleared the two signals that existed when it was written (its comment says why), so adding a third broke it — it now clears all three AND asserts its own premise so a fourth fails loudly; and `test_character_card.gd::test_card_tapped_signal_emits` was a FALSE GREEN whose only assertion sat inside `if has_method("_gui_input")`. Detail: [docs/qa/TABLET_BASELINE_2026-09-08.md](docs/qa/TABLET_BASELINE_2026-09-08.md) § T11-49.

- **`call_deferred` at the TOP of a function is equivalent to putting it last — UNLESS the function `await`s (Sep 8 2026, §2 touch sweep)**: deferred calls run when the frame's idle time comes, i.e. after a plain function has returned, which is why 20+ screens could be given `call_deferred("_open_touch_chain")` as the first statement of `_ready()` without hunting for each function's end. **A coroutine breaks that equivalence completely.** `UpkeepPhaseComponent._build_travel_section()` `queue_free()`s the old panel and then `await get_tree().process_frame`, so the deferred call fired at the end of the CURRENT frame — while the function was still suspended at its await and the rebuilt panel did not exist — and nothing swept afterwards. Measured with a one-line print: it reported **"opened 0" on every call**, while the sweep test simultaneously reported 6 STOP-filtered controls under that exact subtree. Moving the call below the attach reported **13** and **6**. ⚠ **The shortcut needs its precondition stated at the site** ("no `await` in this function"), or nobody can notice when it is violated — grepping the other 21 patched functions for `await` afterwards found one more (`SimpleCharacterCreator._ready()`, which awaits twice before `_initialize_ui_components()` builds anything). ⚠ **Three fixes were attempted before instrumenting**, and each looked reasonable (re-sweep on step change, widen the sweep to the whole screen, sweep from the shared base). The print that named it took one run and should have been first: when two plausible causes both survive a fix, stop fixing and measure which one is real.
- **A screen that skips `super._ready()` silently opts out of everything the base adds LATER (Sep 8 2026)**: `CompendiumScreen`, `CompendiumCategoryView`, `CampaignJournalScreen` and `CampaignEditorScreen` all carry an explicit `# Skip super._ready() panel structure — we build our own UI` and then hand-invoke the pieces they need (`_ensure_base_background()`, `_setup_responsive_layout()`, `SettingsOverlay.reserve_band_on()`). That is a **hand-maintained copy of the base's `_ready()`**, and nothing checks it: when `BaseCampaignPanel` gained a touch-scroll sweep, all four missed it and stayed broken while every other panel was fixed. ⚠ Before adding anything to a base class `_ready()`, `grep -L "super._ready" ` the subclasses — the ones that skip it need the new line by hand, and the omission is invisible because each screen still works in every other respect.
- **The base-class touch sweep was structurally unable to do its job, and it hid behind a plausible skip list (Sep 8 2026)**: `BaseCampaignPanel._apply_pass_filter_recursive()` and its byte-identical twin in `BasePhasePanel` opened STOP controls to PASS — but their skip clause was `return`, not `continue`, and the list included **`ScrollContainer`**. So the walk **stopped at the first ScrollContainer and never entered it**, which is the only place a swallowed drag can matter. They also encoded the "interactive controls must keep `MOUSE_FILTER_STOP`" rule that **T9-45 disproved** (CheckBox/SpinBox/OptionButton are exactly what a finger lands on). Both now delegate to `TouchScrollOpener`, which skips those classes and keeps descending — the same migration `WorldPhaseController._open_subtree()` made in Aug 2026, copies 2 and 3. ⚠ `CampaignScreenBase` had **no sweep at all**, so its subclasses (CampaignDashboard, HelpScreen, StoreScreen) shipped with the defect. ⚠ The safety this relies on is now MEASURED, not assumed: the Godot 4.6 class reference confirms the PASS/STOP propagation rule and documents `Control.NOTIFICATION_SCROLL_BEGIN`, but says **nothing** about `BaseButton` acting on it to cancel a press — so `tests/unit/test_touch_pass_is_safe_for_buttons.gd` drives real drags and taps and asserts both halves (a drag scrolls and does NOT press; a tap still presses).

- **A colour literal that is NOT the token it is named after, at 67 sites, failing WCAG AA (Sep 7 2026)**: the canonical secondary-text token is `UIColors.COLOR_TEXT_SECONDARY` = **`#9ca3af`** (6.99:1 on the `#111827` card). `#808080` was a hardcoded drift across **67 sites in 27 files** measuring **4.49** on that card, **4.32** on the accessibility themes' `#1A1A2E` base and **3.74** on their `#252542` elevated — all three below the 4.5 AA floor, and at 10-16 px none can claim the large-text exemption. ⭐ **Two things hid it.** (1) `TerrainLegendStrip.gd:12` declared `const COLOR_TEXT_SECONDARY := Color("#808080")` — **the token's own NAME bound to a different value** — so grepping the token returned two colours and neither looked wrong; `PreBattleUI.gd:822` wrote `Color("#808080")  # COLOR_TEXT_SECONDARY`, a comment asserting a token it was not using. (2) `AccessibilityThemes.gd` opens *"Complies with WCAG 2.1 Level AA"* and set `text_secondary` to the failing grey in all three colourblind palettes; it is live via `ThemeManager._apply_colorblind_variant()`, so it shipped — the T11-04 irony again, where the *accessibility* panel was what broke the settings page. ⚠ **A grep for `"#808080"` undercounts this class 2.6x**: the quoted-literal form finds 25 sites and is structurally blind to `[color=#808080]` **inside a longer string**, where the other 42 lived. Grep both shapes, and count OCCURRENCES not lines — `CharacterDetailsScreen.gd:727` carries four on one line. ⚠ **A compliance claim in a docblock is not a test**; `tests/unit/test_ui_color_tokens.gd` is (8 cases, detection-proven on two arms, asserting the invariant rather than the constant). ⚠ A **second** gap is recorded and deliberately unfixed: `COLOR_TEXT_MUTED` (`#6b7280`) is **3.67** on the card across **126 consumers**, most of them informational rather than disabled (`WeaponTableDisplay` damage values, `NotificationManager.gd:243`'s ACTIVE close button), so the WCAG inactive-component exemption does not cover it — raising it is an owner-level palette call.
- **A bloated `.godot/imported/` turns a TIMING test red, and it reads exactly like a code regression (Sep 7 2026)**: `test_character_card.gd::test_instantiation_performance` asserts `load(CharacterCard.tscn).instantiate()` + `set_character()` completes in **under 1 ms** of wall clock. It went red in a full-suite run while the recorded baseline (3,138 cases) had been clean earlier the same day, with the only intervening change being an unrelated Tactics/rival sprint. ⭐ **A three-arm A/B settled it in one pass, and the middle arm is the one that matters**: clean worktree at HEAD -> **PASS**; clean worktree **with the sprint's exact source changes copied in** -> **PASS**; the main working tree -> **FAIL**. Same machine, back to back. So the variable was neither the code nor the test but the WORKSPACE: the main tree's `.godot` had grown to **2.2 GB across 6,989 imported entries** against a fresh import's **146 MB / 3,790** — roughly 3,200 orphaned entries, and **3.6x the 600 MB threshold this file already documents** under "Import Cache". ⚠ **Do not chase a wall-clock assertion through the source.** A dependency-closure check had already shown zero overlap between the failing test and the changed files, and that was *suggestive but not proof* — the A/B is what proved it, and it is cheap: `git worktree add --detach <short-path> HEAD`, `--import`, run the one suite. ⚠ Use a SHORT worktree path (`C:/tmp/hc`): under the session scratchpad the checkout dies on `ios/plugins/InappReviewPlugin.release.xcframework/...` with "Filename too long", leaving a half-written worktree that needs `git worktree remove --force` plus `prune`. ⚠ The remedy (delete `.godot/imported/`) forces a long re-import and should not be run under a live editor — and note the test is a machine-speed assertion with no tolerance, so it will re-arm as the cache regrows.
- **A `max_columns` below the pane count is a wrapped orphan row, and GridContainer CANNOT be persuaded to shape it (Sep 7 2026, Select Crew landscape; second occurrence)**: from the engine source (`scene/gui/grid_container.cpp`, NOTIFICATION_SORT_CHILDREN) a row/column minimum is the MAX of its children's; expanded rows and columns split the leftover space **equally** (`remaining_space / expanded.size()`); one whose own minimum exceeds that share is **dropped from the expanded set and gets exactly its minimum**; and `size_flags_stretch_ratio` is **never read in that file**. So the orphan row receives the pane's own minimum plus an equal share of a surplus that is ZERO once `ShortScreenScroll` settles the column at its combined minimum. Set `max_columns` to the pane count — it is a CEILING, not a demand, because `_columns_that_fit()` still drops columns below 320 design px on a narrow screen. ⭐ **The corollary is the expensive half: ONE non-wrapping Label sizes every column.** A `Label` with `autowrap_mode = AUTOWRAP_OFF` reports its full TEXT WIDTH as its minimum, so it takes an oversize column and leaves the others to split what is left — measured on PreBattleUI with a mission pulled off the device, 1134 px of briefing produced columns of 1136/328/328/327 and pushed the whole page 103-299 px off BOTH side edges at every size below WIDE. Wrapped: 528×4 and zero overflow. Same family as T11-42 and T11-18 — **walk the min-width SPINE, and suspect prose first**. ⚠ Wrapping is safe in a VBox (children stretch to the container width) and is the T11 "Corporate Label" TRAP in an HBox with `SIZE_SHRINK_BEGIN`, where a 1 px minimum makes the text vanish. Occurrences: `ShipManager.gd:104-108`, `PreBattleUI.gd`.
- **A populated screen can still be UNDER-populated, and the sweep will report it green (Sep 7 2026)**: `tests/tools/screen_populator.gd` was added precisely so the layout sweep would stop measuring empty screens (T11-01) — and its PreBattle fixture, built from `BattleSimulatorSetup`, stamps **none** of the keys `CampaignTurnController` stamps on the way into a battle: no `initiative_context`, no `setup_rules` checklist, no `terrain_guide`, no `objective_details`, no deployment condition, and a one-line description instead of a p.85 Rival briefing. Measured on the tablet design space: with the generated mission the Mission pane is **679 px** tall and the shipped 3-column layout **FITS**; with a mission pulled off the device it is **1042-1120 px** and the Crew pane lands below the fold — the defect hardware reported and the sweep could not see, ~440 px of difference. The fix is a committed VERBATIM device product (`tests/fixtures/device/prebattle_rival_attack_mission_2026-09-06.json`, carrying `_source` / `_provenance_warning` like `data/RulesReference/`) that the populator prefers and `state_line()` names, so a run measuring the weak fixture says so. ⚠ **Prefer a real producer's output over a generated stand-in**, and when a fixture and hardware disagree, dump what the device actually stored.
- **`--headless` blocks the OS input path, NOT `Viewport.push_input()` — geometry AND gestures are testable headless (Sep 7 2026)**: two beliefs this repo held were both too strong. (1) A rendered COLUMN COUNT needs a window — no: `AdaptivePanelGroup._columns_that_fit()` reads `get_viewport().get_visible_rect().size.x`, so building the screen under a **SubViewport** sized to the design space reproduces a device's column arithmetic with no window at all (a screen added straight to the test root sees the square 1080 stretch base and can only ever resolve 3). (2) Touch cannot be tested at the desk — no: `push_input()` locally applies an event through `Control._gui_input()`, the exact chain `MOUSE_FILTER_STOP` interrupts, and `ScrollContainer` arms its touch drag off `DisplayServer.is_touchscreen_available()`, whose base implementation returns `Input.is_emulating_touch_from_mouse()` — which this project enables (`project.godot:109`). A synthetic mouse drag therefore takes the REAL touch path and `scroll_started` fires. ⚠ **Instrument that premise**: if touch emulation were off, every drag would read as blocked, which is indistinguishable from the defect. ⚠ Hold still ~14 frames before releasing or the residual drag speed starts INERTIA and the position moves past your assertion. ⚠ This does NOT retire the device: the real digitiser, `emulate_mouse_from_touch` and the physical deadzone are still only measurable on hardware. ⚠ And gdUnit4's `--ignoreHeadlessMode` must be passed AFTER the tool's own arguments — Godot silently swallows unknown flags, so putting it beside `--headless` looks like it worked and exits 103.
- **The Android export HANGS AFTER the APK is written, and the exit is held by an ORPHANED GRADLE DAEMON (Sep 6 2026, deploy #23)**: `Godot_v4.6-stable_win64_console.exe` is a thin forwarder that spawns the real binary; Godot's Android export shells out to `gradlew`, whose CLIENT exits while the DAEMON keeps running with `idleTimeout=10800000` (**3 hours**) and holds the forwarder's inherited stdout handle. So the real exporter exits, the APK lands on disk, and the wrapper sits at **0.0 CPU with no children** until the daemon times out — `subprocess.run` never returns and the build looks hung. Measured: artifact written 10:40, wrapper still alive minutes later, `Get-Process java` at **0.0 CPU-seconds delta over 8s wall**. ⚠ **Check the ARTIFACT before believing the process**: `ls build/*.apk` answers "did it build?" and the process table does not. ⚠ **The CPU delta is the discriminator that separates a slow build from a stall** — a real Gradle build burns whole cores; an idle daemon burns nothing, and its log shows only `daemon addresses registry` heartbeats every 10s. Read that log FORWARD too: a fresh daemon that never received a build request enumerates network interfaces and then only heartbeats. ⚠ Killing the daemon (`Get-Process java | Stop-Process -Force`) lets the wrapper exit and the script's `finally` restore the preset — **kill the DAEMON, not the wrapper**, or `export_format` is left flipped to APK and shows up in `git status` as an unexplained change. ⚠ Do not kill the long-lived `Godot_v4.6-stable_win64.exe ... -e` process: that is the user's EDITOR, and it coexists with headless exports fine (deploy #21 exported in 63s with it open).

- **Live code can name a ZERO-CALLER function as its authority, and no lint sees it (Sep 6 2026, T11-46)**: `CampaignTurnController.gd:816-820` justifies its `turns_played = max(current, turn_number - 1)` write by describing `GameState.advance_turn()` as "the MONOTONIC authority ... it does += 1 at each turn's RETIREMENT". `GameState.advance_turn()` ([GameState.gd:1665](src/core/state/GameState.gd#L1665)) has **one definition and zero callers in `src/`** — every `advance_turn()` call site resolves to a *different* class (`BugHuntCampaignCore:311`, `PlanetfallCampaignCore:555`, `TacticsCampaignCore:354`, `IntroductoryCampaignManager:91`), all reached through `campaign.has_method("advance_turn")` guards on the CAMPAIGN object. Its only caller repo-wide is its own test. So the `max()` is not a non-regressing *sync* beside a monotonic authority — **it is the only thing that writes `turns_played` in 5PFH at all**, which is what made T11-20's freeze total rather than partial. ⚠ **The dead-guard and orphan lints are both structurally blind to this**: the function is not orphaned (a test reaches it) and there is no `has_method` guard to flag — the only artefact is a COMMENT asserting a collaboration that does not happen. When a comment names a collaborator, grep the collaborator. ⚠ Do not "fix" it by deleting `advance_turn()`: it is correct, and its docblock records the self-referential `turns_played = _turn_number - 1` fixed point that once froze every loaded save at turn 2.
- **A non-wrapping prose Label can blank OTHER widgets' text without touching them (Sep 6 2026, T11-42)**: the Old Nemesis chooser showed three blue buttons with no labels at all, and the recorded cause — "the `ItemChoicePopup` presentation drops them" — was wrong: `btn.text` is set for every option and the colours are light-on-blue. The subtitle `Label` had autowrap OFF and was handed a ~100-character p.126 prompt, so it reported the WHOLE string as its minimum width (**measured 609 px** against a Window hard-fixed at **380** and `unresizable`). Being the widest child it set the `VBoxContainer` minimum; every `SIZE_EXPAND_FILL` button was stretched to **577 px**; and their CENTRED labels were pushed clean past the window's right clip. ⭐ **The buttons' own labels needed 363 px and always fitted** — T11-18 restated: an overflow figure names the outermost consequence, never the cause, so walk the min-width SPINE. ⚠ The clipped prose above the buttons was the SAME defect's visible half, and reads like a separate cosmetic nit. ⚠ Wrapping the Label makes its height content-dependent, so a hand-rolled `size.y` constant then clips the buttons off the BOTTOM — the exact trade the T11-22 correction made before it was caught; fit both axes after layout.
- **A paused SceneTree kills the scene transition, and the only trace is in LOGCAT (Sep 5 2026, T11-27)**: `SettingsOverlay` ends `_show_settings_overlay()` with `get_tree().paused = true` (`:203`) and sets its own `process_mode = PROCESS_MODE_ALWAYS` (`:49`) — so the overlay's controls kept responding while every navigation OUT of it was dead. `TransitionManager` declares no process_mode, so it INHERITS the pause; `Node.create_tween()` "automatically binds it to the current node" and the default `TWEEN_PAUSE_BOUND` makes the tween's pausing "dependent on the bound node" (Godot 4.6 docs), so `await _tween.finished` never returns and the `change_scene_to_file()` below it is never reached. ⚠ **`PROCESS_MODE_ALWAYS` on TransitionManager is NOT the fix**: `paused` is a property of the SceneTree, not of `current_scene`, so it survives the scene change and the player lands on a frozen destination instead of a dead button. ⚠ **The 5s safety timer DOES fire** (`create_timer`'s `process_always` defaults to true), so the only evidence was one lone "Safety timeout" line — and `push_warning`/`push_error` go to **Android logcat** — which is why the device log looked silent here. ⚠ **CORRECTED Sep 6 2026 (T11-44): this used to read "never to `user://logs/godot.log`", and "never" is too strong.** A `push_warning` from `JournalEntryTypes.validate_entry()` was read OUT of `godot.log` on the tablet with a full six-frame GDScript backtrace attached, and it is the only reason T11-44 was ever found. Check BOTH channels; a walk that skips `godot.log` because of this line can miss a finding, which is a worse failure than checking one channel twice. ⚠ **`kill()` never emits `finished`**, so a "just kill the tween" recovery hangs the same await. The fix is three-layered on purpose: the callers unpause first, `SettingsOverlay._on_scene_changed()` unpauses for ANY future navigating control (order-independent — `SceneRouter.navigate_to()` emits `scene_changed` synchronously on the line after it calls `fade_to_scene()`, i.e. before that coroutine resumes), and `fade_to_scene()` now `push_error`s if it is entered while paused. ⚠ `NotificationManager` has the same exposure (2 tweens, no process_mode) and is left as-is — noted so it is not rediscovered as a new finding.
- **One tap, two events: listening to both pointer families double-fires (Sep 5 2026, T11-36)**: `emulate_mouse_from_touch` defaults to true and makes the engine "send mouse input events when a user taps or swipes on a touchscreen", and this project ALSO sets `pointing/emulate_touch_from_mouse=true` (`project.godot:109`). `HubFeatureCard._on_gui_input` handled `InputEventMouseButton` **and** `InputEventScreenTouch`, so one physical tap emitted `card_pressed` twice — across 52 references on 6 screens. Handle the MOUSE family only; touch is already translated into it. ⚠ Separately, five hand-rolled row handlers acted on `event.pressed` — the press DOWN — so touching a list to SCROLL it opened whatever was under the finger (T11-28). Both are now `src/ui/components/common/TapGesture.gd`: press/release with a 16px slop (matching `gui/common/default_scroll_deadzone`), cancelled by motion beyond it or a release outside the control. ⚠ **A swallowed drag and a drag-that-taps are INDEPENDENT defects** — fixing either alone leaves the list unusable, and each is detection-proven separately.
- **A screen can be a fabricated-data PRODUCER wearing a display bug's clothes (Sep 5 2026, T11-29)**: every field on every Rival card read "Unknown". The screen displayed `threat_level` / `relationship` / `status` — three keys written by exactly ONE producer: its own `_create_rival_from_template()`, fed by `data/patrons/patron_templates.json`, `data/rivals/rival_templates.json` and `data/jobs/job_templates.json`. **All three files are ABSENT from the repo**, so every value came from `_create_*_templates_fallback()` ("Director Johnson", `job_multiplier 1.5`, invented `threat_levels` — in neither rulebook) and `_save_rivals_to_gamestate()` wrote the result INTO `campaign.rivals`. It was not a bad display of good data; it was rendering its own invented shape and calling every genuine Rival Unknown. ⚠ **`--headless --quit` reported CLEAN while the stripped file had a fatal parse error** (a leftover `_on_request_job` reference) — it only validates STARTUP scripts, exactly as this file warns. Only a test that actually *loads* the script caught it. ⚠ When two producers emit two shapes for one concept, the display cannot be right for both: `PostBattleContext.add_rival()` now emits the same shape as `RivalPatronResolver._append_rival()`, `threat_level` included, even though nothing reads it.
- **Two correct guards can lose a counter between them (Sep 5 2026, T11-20)**: `CampaignPhaseManager.bind_campaign()` resets `turn_number = 0` on a new campaign identity — correct, it stops campaign A's turn raising campaign B's count — and restores the PHASE but never the turn. `CampaignTurnController._on_campaign_turn_started()` writes `turns_played = max(current, turn_number - 1)` — also correct, it stops a stale LOW value lowering a real count. Together they FREEZE the campaign turn counter: after any reload `turn_number` restarts at 0, so the write is `max(8, -1) = 8`, then `max(8, 0) = 8`, and `turns_played` cannot move again until `turn_number` has climbed past 9. Measured: `turn_number 0 -> 1 -> 2` while `turns_played` sat at 8. ⚠ **Neither half is wrong on its own**, which is why it survived, and why a test of either in isolation passes. ⚠ The `+1` in the restore is load-bearing: `turns_played` is the COMPLETED count while `turn_number` identifies the turn IN PROGRESS, so a save written mid-turn (which is exactly what `_restore_phase_from_campaign()` has just detected by finding a real stored phase) is one ahead. ⚠ `tests/unit/test_turn_counter_advance.gd`'s docblock already ASSUMED this restore existed — a documented assumption is not an implementation.
- **The sheet baker took the FARTHEST rule in its window, so values were written on the next box's border (Sep 5 2026, T11-22)**: `scripts/bake_sheet_label_insets.py` searched `h-6 .. h+18` below each field and returned `spanning[-1]`. On a two-row layout that window reaches the NEXT structure down. Measured on `assets/sheets/core/crew_log.png`: `captain_name`'s box bottom is y=774, its own closing rule is at **777-778**, and the TOP border of the Weapon box below is at **790** — the baked offset pointed at 790. **128 of 184 crew-log fields** were affected, not the 40 the finding described; a before/after render shows the captain's name struck through by its own box border in the old build. The rule is now the bottom of the FIRST contiguous run (a printed rule is 2-3px thick, so `spanning[0]` alone would put the baseline inside the stroke). ⚠ **Correcting it exposed a second-order defect**: 24 fields' writable band (caption inset -> rule) became SHORTER than their own line height, and a Control cannot be shorter than its minimum — so the Label grew DOWNWARD and put the value back across the border the correction had just moved it off. `SheetRenderer._populate_fields()` now grows such a band UPWARD into the caption, which is the trade that file already declares ("better to overlap a caption than to silently drop the value"). ⚠ The guard in `test_sheet_field_mapping.gd` uses `rule_offset <= h + 12`, and **12 is measured, not chosen**: legitimate rules sit 2-9px below their box, the defect produced 16+.
- **The PDF text layer is not a column order — crop the artwork (Sep 5 2026, T11-24)**: the Encounter Log's enemy table has SEVEN columns and the manifest addressed two, so Panic/Speed/Combat/Toughness/AI printed blank. ⚠ **This was an ENHANCEMENT, not a defect** — there was no field entry for those columns, so blank is what the manifest asked for; it was nearly filed as a null-resolution bug. Appendix X's text layer interleaves this sheet with the crew log's weapon table and reads *"...AI Number Speed / Shots Panic / Ramge Combat / Damage Toughness"*, i.e. it implies a Number-**Speed**-Panic order. Cropping the PNG shows the real captions: **Name/Type | Number | Panic | Speed | Combat | Toughness | AI**. Column x-boundaries were measured from the artwork's own vertical separators (155/541/715/889/1063/1237/1411/1763), and the values print the way the book prints them (Core Rules p.94: Speed carries the inch mark, Combat Skill is a SIGNED modifier — a combat skill of 0 is a real value, so the emptiness test is on the RECORD, never on the number).
- **An overflow figure names the outermost consequence, never the cause (Sep 5 2026, T11-18)**: the Record Battle Result drawer clipped its right edge in landscape, and the obvious suspect — an `HBoxContainer` holding an OptionButton, a CheckBox and a SpinBox side by side in a 480px drawer — was only part of it. Walking the min-width SPINE named a prose `Label` with **autowrap OFF** demanding 422px, which propagated 422 -> card 454 -> form 502. Measured split: wrapping the hint Labels alone takes the form to **432** (already inside 480); switching the two rows to `HFlowContainer` takes it to **342**. Both were kept — 48px of headroom is thin against a longer string or a larger UI scale — but the comment claiming the row caused the clip was corrected, because a wrong causal note is worse than none. ⚠ Portrait was unaffected throughout (the drawer becomes a near-full-width sheet there), so a sweep at one orientation would not have found it.
- **The move-the-Window keyboard strategy has a hard ceiling, and it was reporting success (Sep 5 2026, T11-15)**: `KeyboardAvoidance._shift_window_up()` clamps with `maxi(0, _window_original_y - shift)` — correct — and then emitted the REQUESTED shift in `avoidance_applied`. Measured on device: the QA dialog asked for 511.3px and had **64px** to give (a window cannot move above the top of the screen), so the field stayed under the keyboard while everything listening was told the avoidance had worked. It now emits what was APPLIED and prints the shortfall in debug builds. ⚠ **The real reason it took that strategy at all** is that the dialog had no ScrollContainer — the headroom-and-scroll strategy has no ceiling. Both `QAScenarioDialog` and `CustomVictoryDialog` now have one. ⚠ Two independent causes again: the signal lied AND there was nothing to scroll.
- **Guard on the OWNER when the root cause will not come out (Sep 5 2026, T11-17)**: a mid-battle force-stop + Continue came back with a different terrain seed (4055150519 -> 341922859) — the table the player had physically laid out, regenerated and saved over. Every static guard checked out: `load_campaign()` restores `active_battlefield` (`GameState.gd:695-699`), the checkpoint was valid (schema_version 1, turn 8 = turns_played 8.0), and `clear_battlefield_data()`'s only caller is the post-battle cleanup. The runtime cache was empty at read time for a reason not visible in source. Rather than guess at the path, both fixes key on the SIGNATURE: `get_battlefield_data()` reads through to `campaign.progress_data["active_battlefield"]` whenever the cache misses (a miss with a populated owner IS the defect, whatever caused it), and `_persist_battlefield_contract()` refuses to overwrite a non-empty saved contract with a differently-seeded one unless the player pressed Regenerate. Either alone would have saved the table. `[T11-17]` prints on BOTH arms of the consume-first branch name the trigger on deploy #20 — **a log with no line at all is a different diagnosis from "it took the fallback"**.

- **A rule that is CHECKED but never SHOWN is indistinguishable from one that is not checked (Sep 5 2026, T11-13)**: `CampaignCreationStateManager.advance_to_next_phase()` sent every non-blocking warning to `push_warning()` **and nothing else**, then advanced. On the tablet a Standard-method crew with two Bots was detected perfectly — the device log carried `Standard Method: at most 1 Bot (p.13) - have 2`, right rule and right cite — while the player saw a clean Next and a wizard that appeared to agree the crew was legal. ⚠ **Blocking is NOT the fix**: the composition check is a warning *on purpose* because a half-finished crew passes through illegal-looking intermediate states as species are assigned slot by slot, and the reason is documented at the check itself. The missing piece was purely the display. ⚠ **Emit on EVERY advance, empty array included** — a listener has no other way to know a previous notice no longer applies, and "emitted only when dirty" cannot be told apart from "emitted always" by a test that only ever checks the dirty case. ⚠ Grep for other `push_warning(` calls that are a feature's ONLY user-facing output; this validator had **seven** phases' worth of warnings going nowhere, not just the crew's.
- **A lookup that matches a KEY against a LABEL breaks exactly where the label is not a transcription — and index 0 is a plausible wrong answer (Sep 5 2026, T11-14)**: `CharacterCreator._find_item_by_value()` compared a stored enum key (`"COMFORTABLE_MEGACITY"`) against `OptionButton.get_item_text()` and its uppercase/underscore normalisation, then `return 0` on no match. **3 of the 25** Core Rules backgrounds keep the book's wording while the enum member is abbreviated — `"Giant Overcrowded Dystopian City"`/`GIANT_OVERCROWDED_CITY`, `"War Torn Hell Hole"`/`WAR_TORN_HELLHOLE`, `"Comfortable Megacity Class"`/`COMFORTABLE_MEGACITY` — so those three silently showed *"Peaceful High Tech Colony"*. ⚠ **The fallback being a VALID index is what hid it**: a blank or a crash gets reported, a real-but-wrong background gets believed. ⚠ **Do not "fix" it by renaming the labels** — they are the book's names and the book's names are what the player must read; compare KEY TO KEY through the same `GlobalEnums.to_string_value()` the write path (`_on_background_changed`) already uses, so the two directions cannot drift. ⚠ Origin/Class/Motivation were checked and are clean, but the call sites are tagged with their enum name anyway so a future reworded label cannot reintroduce it. ⚠ Display-only here (`select()` does not emit `item_selected`, and `_on_confirm_pressed()` re-reads no dropdown) — **but verify that before downgrading a severity**, because the same helper feeds four properties.
- **A rotation control that never rotated looks exactly like a clean pass (Sep 5 2026)**: three device captures came back **byte-identical** across a portrait round trip, which reads as "the layout is stable". The rotation had not happened — `accelerometer_rotation` had reset itself to `1`, and **`user_rotation` writes are silently ignored while auto-rotate is on**. Write BOTH settings, read them BACK, and confirm `mCurrentRotation=ROTATION_n` in `dumpsys window` before capturing anything. Same shape as `reference_instrument_the_probes_own_premise`: the probe must prove it delivered its own stimulus. ⚠ Auto-rotate resets between runs — re-assert it every time, never once per session.
- **A responsive value computed at BUILD time is stale the moment the viewport changes — this is now THREE defects with one shape (Sep 4 2026)**: T11-01 (`ShortScreenScroll` gated on a viewport height sampled once), T11-04 (`SettingsScreen` fonts baked at the size it was built at), and T11-05 (`TacticalBattleUI._overlay_width()` — correct, called at all four sizing sites, and only ever at build time). In T11-05 the overlay is opened in landscape, where the clamp returns the full 560 cap; rotate to portrait (338.79 design px) and that 560 is a stale minimum on `OverlayCenter`, a full-rect `CenterContainer` with `grow_horizontal = GROW_DIRECTION_BOTH` — so it grows in BOTH directions and lands at **x = -114.6**, 114.6 px off the left edge and the same off the right, buttons unreachable on either side. ⚠ **A build-once measurement is structurally blind to all three**, which is why `verify_layout` (fresh instance per size) reported clean while `verify_rotation` (one instance, resized) did not. ⚠ **The helper was never the missing piece — the CALL was**: `_apply_responsive_layout()` already re-fit the side panels and the portrait rails on every resize and simply never included the overlay, so a test of the helper alone would have passed with the defect live. Test the wiring. ⚠ **Store a per-node cap rather than re-applying one value**: the caps are not uniform (the enemy-generation wizard uses 700, everything else 560), so a blanket re-fit trades a portrait bug for a desktop one.
- **A UI readability floor applied to non-UI text destroys geometry (Sep 4 2026, T11-06)**: `ScreenChrome.font_size()` delegates to `ResponsiveManager.get_responsive_font_size()`, which is `maxi(9, base * multiplier)` — a global 9 px floor AND a second scaling. Both are right for chrome and wrong for the printable sheets, whose field font is already derived from the sheet's own display scale, so the helper double-scaled it and then refused to go below 9. On a phone (preview scale ~0.265 for a 2764 px sheet) every field rendered at >= 9 px while its BOX shrank with the sheet; a Label clips text horizontally via `clip_text` but its minimum HEIGHT is the font line height and **cannot be clipped**, so fields grew past the rect the manifest reserved and painted over their neighbours — ~130 sweep findings at the two smallest configs, none at tablet or desktop. Fixing it took the count to 49. ⚠ **The manifests were innocent and that was worth proving before touching them**: all three have ZERO overlapping boxes in source coordinates. ⚠ **That floor was a symptom, not the cause — see the next gotcha.** It made the real defect bind more often; removing it took the count 134 -> 49 and no further.
- **A test that asserts a RESPONSIVE value against a raw constant is a coin flip on `user://window.ini` (Sep 5 2026)**: `test_stat_badge.gd::test_labels_have_correct_font_sizes` asserted `is_equal(11)` / `is_equal(14)`. `StatBadge.gd:129/137` sets those sizes with `ScreenChrome.font_size(FONT_SIZE_XS)`, which delegates to `ResponsiveManager.get_responsive_font_size()` = `maxi(9, round(base * mult))` — and the multiplier is **1.0 only at DESKTOP**. Measured by varying the persisted window size ALONE, with no code change: **900 px → DESKTOP x1.00 → PASS · 360 px → MOBILE x0.85 → 9, FAIL · 1920 px → WIDE x1.15 → 13, FAIL · headless (width 0 → MOBILE) → FAIL.** ⚠ **`tests/tools/verify_layout.gd` sweeps six sizes and leaves the LAST one in `user://window.ini`, which `GameState` restores at boot** — so running the layout sweep before the unit suite flips such a case red with nothing else changed, and it reads exactly like a regression from whatever you edited that day. It cost a full root-cause detour; three plausible causes (persisted window size, a mutated theme on disk, `get_theme_font_size`'s explicit theme-type argument bypassing the node override) were each disproved by measurement before the real one landed. ⚠ **The fix is to assert THROUGH the same transform** — `assert_int(size).is_equal(ScreenChrome.font_size(11))` — which is breakpoint-independent by construction and still fails if the widget stops using the XS rung. Pinning the configuration in `before_test()` is the weaker alternative. ⚠ The 9 px floor collapses adjacent small rungs at MOBILE, so a scaled assertion loses a little discrimination there; assert the rungs stay ORDERED as well.
- **gdUnit4 CAN run headless, and it is the fix for focus-stealing test runs (Sep 5 2026)**: gdUnit4 refuses `--headless` with *"Headless mode is not supported!"* and exits 103 — which is where this project's "never --headless" note came from — but it prints its own override, **`--ignoreHeadlessMode`**. The refusal exists because Godot does not deliver `InputEvents` without a display. ⚠ **It is NOT a free swap, and "byte-identical" was my own overstatement from a single-suite sample — the full run disproved it.** Headless runs 270 of 271 suites correctly and **crashes one with signal 11**: `test_sheet_source_paths_resolve.gd`, isolated by bisecting 38 → 19 → 10 → 1, and it crashes ALONE. It builds a real `SheetRenderer` that loads and draws the sheet PNGs, so it needs a rendering device — its own docblock already said *"never --headless (project rule)"*. Every OTHER geometry suite in that batch passes headless individually, so the rule is a one-suite exception, not a blanket ban. ⚠ The crash takes the whole batch with it and the runner reports `cases=PARSE_FAIL` rather than a failure — easy to skim past, so check for it. The working shape is: headless batches + a named `NEEDS_DISPLAY` list run windowed once. A windowed batch run creates a window per batch and **steals desktop focus eight times**. ⚠ It is not a free swap: headless makes `DisplayServer.window_get_size()` report **0**, so `ResponsiveManager` classifies **MOBILE** rather than inheriting whatever `window.ini` held. That is a *fixed, reproducible* configuration and therefore better — but any test written assuming DESKTOP type will flip. ⚠ `--headless` is still WRONG for `verify_layout` / `verify_rotation` and the geometry probes: DisplayServer returns dummy values there, so `window_set_size()` does nothing and every screen measures at the default rect. ⚠ Godot silently IGNORES unknown command-line arguments, so a guessed flag like `--no-focus` (which does not exist) would look like it worked; `--position`/`--screen`/`--resolution` exist, but none of them prevents focus theft — only having no window does.
- **The square-base stretch ALREADY normalises physical size — multiplying by display density double-counts it (Sep 5 2026, T11-07 root cause)**: `SettingsManager._apply_ui_scale()` computed `content_scale_factor = TARGET_EFFECTIVE * ui_scale * dpi_scale * stretch_cancel`. Because `stretch_cancel = 1080/short_axis` exactly cancels the engine's `canvas_items`+`expand` stretch (`short_axis/1080`), the algebra collapses to **`effective = TARGET_EFFECTIVE * ui_scale * dpi`** — and `TARGET_EFFECTIVE` (1.16) is already the FINAL effective scale, documented at the site as "verified layout-safe". So every 2.0-density Android device rendered at **2.32x instead of 1.16x**: text ~2x, content clipped off the top and bottom, button WIDTHS unchanged (container-driven) while their heights grew (content-driven). Measured on a TB361FU with the formula's inputs printed: `boot dpi=1.000 -> 0.7830` (main menu correct, all 10 buttons visible) vs `first resize dpi=2.000 -> 1.5660` ("Settings" pushed OFF-SCREEN, title wrapping, intro text clipped). Fix: drop the density term. Desktop is unaffected (dpi is 1.0 there). ⚠ **AN AUTOLOAD ORDERING ACCIDENT MASKED IT FOR MONTHS AND MADE IT LOOK LIKE A ROTATION BUG.** `SettingsManager` is autoload **#2** and `ResponsiveManager` is **#24**; autoloads ready in declaration order, so at `_ready()` the RM node does not exist AND Android has not yet reported its density — `_dpi_scale()` returned 1.0 and **the app booted correct by accident**, then broke on the first resize and stayed broken until relaunch. **A value read during autoload `_ready()` may be a placeholder that becomes truthful later; if a wrong read is only corrected on some later event, the bug presents as that event's fault.** ⚠ **This is why every rotation control measured 0 px**: the jump happens ONCE, on the first resize after launch, and each control rotated an app that had already taken it — the controls were sound, they all ran past the transition. A "no difference" A/B proves nothing if both arms are downstream of the one-shot transition you are hunting. ⚠ **Do NOT fix it by re-applying the scale once the density is knowable** — that was tried first and is BACKWARDS: it makes the broken 1.5660 state permanent. It was caught only because the reported symptom ("too large") contradicted the direction the formula's own comments implied. **When a formula and the observed symptom disagree about which value is correct, the device decides — take the screenshot.**
- **A whitelist that silently drops keys has now eaten FIVE features (Sep 5 2026, T11-09)**: `CampaignCreationCoordinator.update_campaign_config_state()` copies named keys out of the panel's dictionary into `unified_campaign_state.campaign_config`, and a key it does not name is dropped with no error. It has swallowed Progressive Difficulty, `narrative_wrap_override`, `difficulty_toggles`, `house_rules` and now **`crew_creation_method`** — the Core Rules p.13 crew-creation method, which meant a Standard crew rolled two Bots against a cap of one, no warning appeared, and Next advanced. ⚠ **ONE missing line killed BOTH halves**: the coercion (`CampaignCreationUI._push_campaign_crew_size()` → `CrewPanel`) and the gate (`state_manager.campaign_data["config"]` → `_validate_crew_with_warnings()`) both read `cfg.get("crew_creation_method", "miniatures")`, and "miniatures" permits any mix — so the default is INDISTINGUISHABLE from working. ⚠ **The function's own comment already warned about exactly this and did not prevent the fifth occurrence, because a comment is not a test.** Any new key on that path needs a case asserting it survives the whitelist; the four in `test_crew_creation_methods.gd` are the template. ⚠ **A default that is also a legal value is the dangerous kind** — had the fallback been an invalid method, this would have failed loudly on day one. ⚠ Its sibling trap: **`ExpandedConfigPanel.get_campaign_config_data()` is a SECOND fixed-key literal** on the same path, so a key must be named in BOTH. Note `campaign_crew_size` is absent from that literal yet propagates fine, which is a good reminder that finding a key in one chokepoint proves nothing about the other.
- **Every `Window` is its own `Viewport`, so viewport signals never reach a dialog (Sep 5 2026, T11-11)**: `gui_focus_changed` is a **Viewport** signal, and `KeyboardAvoidance._ready()` connected to `get_tree().root` alone — so soft-keyboard avoidance was structurally blind to **all 15 `extends Window` subclasses in `src/`**. Three take text input and **two are player-facing** (`BugReportDialog`, `CustomVictoryDialog`); it was found on the third, a debug screen, and filed as that screen's problem. ⚠ **Any autoload that listens on `get_tree().root` for a Viewport signal has this hole** — grep for `root.gui_focus_changed`, `root.gui_input`, and friends. The order-independent fix is to hook `get_tree().node_added` and connect each `Window` as it arrives; per-dialog registration is the shape that has already failed twice here (`initialize_job_offers`, T9-50). ⚠ Two independent causes, either fatal alone: the signal never arrived, AND two of the three dialogs have **no ScrollContainer**, so the scroll strategy had nothing to move even once it did. For a `Window` the better strategy is to **move the Window** — it needs no scene surgery and cannot silently no-op the way `scroll_vertical +=` does when the range is zero. Capture the original Y ONCE, or moving between two fields stacks shift onto shift.
- **Godot 4 Android plugins: `.gdap` is DEPRECATED, and an unenabled EditorPlugin fails SILENTLY (Sep 5 2026, T11-10)**: the v1 mechanism (an `android/plugins/*.gdap` file beside the AAR) is **deprecated in Godot 4** in favour of the `EditorExportPlugin` format — Context7, `tutorials/platform/android/android_plugin.html`. So "there is no `android/plugins/` directory" is **not** a finding on 4.x; there should not be one. A v2 plugin is an `EditorPlugin` in `addons/` that calls `add_export_plugin()` from `_enter_tree()` and returns its AAR from `_get_android_libraries()`. ⚠ **It must be listed in `project.godot`'s `[editor_plugins] enabled`** — an unenabled EditorPlugin never runs `_enter_tree()`, so nothing is contributed and **the export still succeeds**, just without the plugin. That is why `InappReview` was absent from the dex with no error anywhere. ⚠ `_get_android_libraries()` paths resolve relative to **`addons/`**, so the AARs belong in `addons/<Plugin>/bin/{debug,release}/` — a root-level `<Plugin>/bin/` is the v1 layout and makes Gradle fail with *"Transform's input file does not exist"*. ⚠ **Verify in the dex, never in the config**: unzip the APK and string-search `classes*.dex`, WITH control probes (`org/godotengine`, `GodotPlugin`) so a search that finds nothing is distinguishable from a search that is broken.
- **A theme font-size override does NOT refresh the minimum-size cache in the same frame (Sep 5 2026, T11-06 — root cause)**: `add_theme_font_size_override()` INVALIDATES a `Control`'s minimum-size cache and queues the recomputation for the NEXT frame, so `node.size = rect` on the following line is clamped up to the **previous font's** line height. Measured directly by `tests/tools/probe_label_min_cache.gd`, which reads one node three times: immediately after the override the minimum still reports `(64.0, 21.0)` — **byte-identical to a Label that never received an override** — and a frame later it reports `(20.0, 7.0)` while `size` still holds the clamped value, because nothing re-assigns it. ⚠ **Reordering does not fix it and neither does rebuilding**: a brand-new, never-laid-out Label clamps the same way, before OR after entering the tree, because a node's FIRST minimum is computed with the theme's DEFAULT font. That is why the "font before size" ordering change in `SheetRenderer` was correct on its own terms and moved the sweep count by exactly **zero** — and why its comment said so instead of implying a fix. ⚠ Consequence: every printable-sheet field Label was **a flat 21 px tall at every display scale** since the overlay was written, so on a phone the manifest boxes shrank with the sheet while the text boxes did not. ⚠ **The fix is to stop scaling per node**: build the overlay in SOURCE coordinates with the manifest's own font sizes and apply the display scale ONCE as a parent transform (`SheetRenderer._ensure_field_layer()` / `_content_fit()`). Nothing then changes a font after creation, the clamp can only bind where a manifest box is genuinely shorter than its own line height (measured: 0 of 211 fields), and the preview and the export become the SAME layout instead of two implementations of one decision. ⚠ Godot's own docs warn that a scaled `Control` blurs non-MSDF fonts and that `scale` is RESET to 1 if the node is a direct child of a `Container` — the field layer is a child of a plain `Control`, which is why it survives. ⚠ Moving nodes under a layer silently broke two subtree walks that assumed direct children (`_collect_text_layer`, the export re-adopt); a walk that finds nothing does not error, it ships an EMPTY searchable PDF layer. Verified after the change by round-tripping both backends through PyPDF2: **323 / 324 chars**, against the SOP's recorded 322-325.
- **Limits borrowed from a DIFFERENT organisation on the same page (Sep 4 2026, Tactics p.134)**: `TacticsCompositionValidator` enforced Leader 1 / Troops 2-5 / Supports 0-4 / Specialists flat 2. Those are not arbitrary and they are not Age-of-Fantasy leftovers as the file's own note guessed — they are **exactly the Armored Platoon optional rule from p.135** ("Leader (1): One vehicle. Troops (2-5)... Supports (0-4, must be fewer in number than troops)"), applied to the **Infantry Platoon** on p.134, which is Leaders **1-2**, Troops **2-4**, Supports **0-3**, Specialists **0-1 per 2 Troops**. So it accepted illegal armies AND rejected legal ones. ⚠ **When a book gives several organisations in one chapter, check WHICH ONE a constant came from before calling it wrong** — and assert both directions in the test, because a validator that only ever rejects is as broken as one that only ever accepts. ⚠ One claim in the old defect note was itself wrong and was corrected rather than deleted: the "must be fewer than Troops" clause WAS enforced; only the flat cap was wrong. ⚠ Express a rule as CAPS where the book states a reduced-size variant in cap terms — Standard's "3 are always Human" plus the p.63 reduced-crew clause is ONE rule when written as `<=2 aliens, <=1 bot`, and two special cases when written as slots.
- **"A product decision" can be a rules gap nobody re-read the page for (Sep 4 2026, Core Rules p.13)**: the audit ledger recorded the four crew-creation methods as **OPEN by choice**, reasoning that enforcing the Standard Method's limits "would remove player freedom the app currently grants, which is a design call for the owner". Re-reading p.13 dissolves the dilemma: the **Miniatures Method** allows "any combination of Primary Aliens, Bots, or Humans that matches your selected miniature figures" — so the app's free species choice was **already a book method** and nothing had to be taken away. What was actually missing was the CHOICE between the four, and the constraints the other three impose. ⚠ **Before deferring a row as a product decision, check whether the book already sanctions the current behaviour** — the deferral cost this row four months. ⚠ Strange Characters remain reachable ONLY by rolling 91-100 under the Random Method; that scarcity is the book's own, and ignoring it is what made randomised crews ~69% Strange.
- **A screen under test is not a passive subject — it can resize the WINDOW (Sep 4 2026, T11-04)**: `tests/tools/verify_layout.gd` measured SettingsScreen at six sizes and passed it six times **at a size it never achieved**. `SettingsScreen._enter_tree()` restores `user://window.ini` and applies its saved size (`SettingsScreen.gd:127-129`) while `_exit_tree()` writes the current size back, so a sweep that builds a fresh instance per size gets the screen snapping the window to whatever the PREVIOUS configuration saved — measured **one size behind**, every row. `verify_rotation.gd` builds once and re-applies a size per STEP, which overwrites the restore, and that alone is why the two sweeps disagreed about this screen for a day. ⚠ **The repair must REBUILD, not just re-resize**: font sizes come from `ResponsiveManager.get_responsive_font_size()` and are baked in at build time, so a screen built at 1920x1080 and shrunk to 360x640 carries desktop text — the re-resize-only version produced two "findings" (Labels needing 379/321 px) that **vanished** under a rebuild, and they were one step from being fixed as defects. ⚠ **Order matters**: re-apply the size BEFORE freeing the tainted instance, because `_exit_tree()` saves the current size and freeing first would persist the hijacked one. ⚠ **Both sweeps rewrite `user://window.ini`, and `GameState` restores it at boot** — so the gdUnit4 window size, the ambient ResponsiveManager breakpoint and every font size depend on what ran last. A unit test that measures a real screen must PIN its configuration in `before_test()` and restore it in `after_test()`.
- **A DISABLED ScrollContainer axis propagates the minimum on THAT axis (Sep 4 2026, T11-04)** — the horizontal twin of T11-01. Settings content sits in a ScrollContainer with `horizontal_scroll_mode = SCROLL_MODE_DISABLED` (correct — a settings page must not scroll sideways), so one hardcoded `custom_minimum_size.x = 600` inside `AccessibilitySettingsPanel` reached the screen root: 600 → ScrollContainer 608 → VBox 608 → root MarginContainer 636, against a 338.79 px viewport — **297.2 px of every settings row off the right edge of a phone**. An *accessibility* panel was what made the settings page unusable on a small screen. **Three width drivers stacked, each invisible until the one above it was gone** (297.2 → 24.7 → 3.7 → clean): the 600 floor; an `OptionButton` reporting its longest ITEM ("Deuteranopia (Red-Green Colorblind)", 297 px); and a row TITLE Label with autowrap OFF (184 px) whose own DESCRIPTION already wrapped, so it looked handled. Only the first is greppable — the other two get their width from a STRING. Fixes are the codebase's own: `clip_text` + `OVERRUN_TRIM_ELLIPSIS` (`CharacterCard.gd:231-241` documents the identical defect) or autowrap for prose; shortening the item names was rejected because they are the accessibility conditions themselves. ⚠ **To name the driver, walk a min-width SPINE** — descend into the widest-minimum child until a leaf, as `tests/tools/probe_settings_width.gd` does; an overflow figure names the outermost consequence, never the cause. ⚠ **Start at the first CONTAINER**: a plain `Control` does not aggregate its children's minimums, so a root Control reports `min.x 0.00` — which is exactly how a test asserting on the root became a FALSE GREEN that passed with the 600 px floor restored.
- **A layout harness can measure the right SIZE and the wrong SCREEN (Sep 4 2026, T11-01)**: `tests/tools/verify_layout.gd` already had **1280x800** in its `SIZES` list and was GREEN while the PreBattleUI footer was clipped to ~13px on a real tablet. It instantiated `PreBattle.tscn` and measured it — with **all four panes EMPTY**, because nothing had handed it a mission, a crew or a battlefield, and an empty pane is short. Screens that build from `GameState` (CampaignDashboard) self-populate in `_ready()` and were always measured with real content; screens whose data arrives from their **navigator** were measured empty on every run, at every size. **"A screen was instantiated" was being reported as "a screen was verified."** The sweep now has a `POPULATE` table plus `_populate_pre` / `_populate_post`, covering the three mechanisms the app itself uses — `SceneRouter.scene_contexts[key]` and `GameStateManager.set_temp_data()` (both read in `_ready()`, so they must land BEFORE `instantiate()`), and a setup method the navigator calls after `add_child()`. Populated, it reproduced T11-01 on the first run and immediately found a second real defect. ⚠ **The fixtures invent nothing**: crew from the loaded campaign, mission from `BattleSimulatorSetup` (which reads the shipped `mission_templates.json` / `enemy_types.json`), setup rules from `BattleSetupRules.compute()`, terrain from `CampaignPhaseManager.generate_battlefield()`, the post-battle result through `BattleResultNormalizer`; the compendium category and legal document are enumerated live and the LARGEST chosen, so a hardcoded id that stops existing cannot silently populate nothing and read as a pass. `-- populate=off` disables the layer so the A/B that proves a finding differs in exactly ONE variable.
- **"Is the screen short" and "does the content fit" are different questions (Sep 4 2026, T11-01)**: `ShortScreenScroll` enabled scrolling when `viewport.height < short_px` (620). A tablet in landscape has a **design** height of **689**, so on the device the gate could not fire, the ScrollContainer stayed `DISABLED` — and a DISABLED ScrollContainer **propagates its child's minimum**, which is exactly the wrong thing to do when the child does not fit. PreBattleUI's populated 4-pane group pushed the root `MarginContainer` **196.7px** past the viewport; `PreBattle.tscn` anchors it full-rect with `grow_vertical = 2`, so it grew in BOTH directions and took the footer off the bottom and the header off the top. The device report's three byte-identical swipes were correct and complete: the page did not scroll because the scroll was **disabled, not exhausted**. ⚠ **The tell was in the sweep's own numbers** — the config with the LEAST height (phone landscape, 338 design px) PASSED while the roomier tablet landscape FAILED, because only the short one turned scrolling on. ⚠ **The fit cannot be measured in the DISABLED state**: the scroll has already propagated the content's minimum, so its own rect has grown to fit and `content_min > scroll.size.y` is false *no matter how badly the screen overflows* — the check reports "fits" precisely when it does not (same shape as `reference_a_diagnostic_that_cannot_disagree`). Measure with scrolling ENABLED. ⚠ **The content usually arrives AFTER `_ready()`** — PreBattleUI is populated by `CampaignTurnController`, so a one-shot measure at `_ready()` measures an empty screen; the inner column's `minimum_size_changed` is connected for exactly that (Context7-verified: Godot 4.6 `class_control` emits it "when the node's minimum size changes"). Second, independent defect at the same site: `setup(_column, 0)` moved **every** child into the scroll including `FooterPanel`, silently undoing `_setup_adaptive_panels()`'s own promise that the footer "stays put". `setup()` now takes `pinned_trailing`. ⚠ **A footer that scrolls away is invisible to a geometry sweep** — content inside a scroll is *allowed* to exceed the viewport — so that half is pinned structurally by `tests/unit/test_short_screen_scroll.gd`. ⚠ `grep -l ShortScreenScroll` returns 12 files; the live consumer set is **7**, because two are comment-only, one is the component, and `ScreenChrome.apply_page_chrome()`'s branch is never reached (`scroll_column` defaults to `null` and no caller passes one) — *reachability is not usage*, again.
- **A wrong page cite hid a 4x rules error, and the cite cluster was FIVE files (Sep 4 2026)**: `TacticsOperationalMap.gd`, `TacticsPhaseManager.gd`, `TacticsCampaignCore.gd`, `TacticsCampaignUnit.gd` and three army-builder files all cited page ranges from the wrong chapter — `pp.155-168` is the **Lifeforms bestiary**, `pp.81-88` is **Scenario Types**. Correcting them exposed a live defect the cite had been covering: **Campaign Points**. `TacticsCampaignCore.record_battle()` awarded a flat 1, +1 win, +1 "secondary objective" — max **3 CP** — cited "(p.160)", a bestiary page. Tactics **pp.106-107** (index: "Campaign Points (CP) 106") says *"Roll three D6s and drop the lowest result. The sum of the two remaining dice is the base number of CP awarded"*, then either 1 CP per VP or **+3 victory / +2 draw / +1 defeat**, with a worked example totalling 11. So players earned about **a quarter** of the progression currency, and CP gates every unit upgrade, roster change and battle advantage. Fixed with the book's own example as a test. ⚠ **Still OPEN and recorded at the site**: `TacticsCompositionValidator` disagrees with p.134 on four values — Troops max 5 (book **4**), Supports max 4 (book **3**, and its *"must be fewer than Troops"* clause is written in the comment but never enforced — the check is a flat compare), Specialists a flat 2 (book **0-1 per 2 Troops**), Leaders 1 (book **1-2**). It accepts illegal armies and rejects legal ones; scoped as a Tactics rules-accuracy audit, not fixed.
- **Compendium p.21 Psi-hunters: four keys written, zero read (Sep 4 2026)**: `RivalPatronResolver._append_rival` stamped `is_psi_hunter`, `seize_initiative_modifier`, `extra_specialists` and `attack_bonus_vs_psionic` onto the Rival, and **nothing anywhere read any of them** — a band of Psi-hunters fought exactly like any other Rival. All three book adjustments are now wired: the **−2 Seize** rides the tag through `RivalEncounterCheck.check()` → `build_encounter_data()` → `mission_data`, where the D-c funnel already sums it; the **+1 Specialist** lands in `EnemyGenerator`'s chain AFTER the Red/Black Zone rows (those REPLACE the p.93 thresholds, while p.21 *adds*); the **+1 attack vs a Psionic** is read off the enemy dict by `BattleCalculations.psi_hunter_attack_bonus()`. ⚠ **Two traps worth keeping.** (1) The bonus must NEVER be folded into the die: `hit_roll == 6` is the p.51 natural-6 critical and `attacker_natural == 6/1` drive the brawl extra-hit and self-hit rules, so a +1 on the die would invent a critical. It goes into the COMPARISON and the TOTAL. (2) `generate_enemies_as_dicts()` has **three** `enemies.append()` sites — basic figures, the Red Zone Captain, and Unique Individuals — so a per-literal stamp caught only the first. My own test caught it; the flag is now stamped ONCE over the assembled force. *One rule, three sites* is the recurring shape.
- **The production-dead backlog is CLOSED — `test_only` 39 → 0 (Sep 4 2026)**: 39 files / 11,349 lines / 364 KB were reachable only from `tests/`, and `export_filter="all_resources"` meant every byte shipped in the APK/AAB. Android tooling does not strip them: R8 `isMinifyEnabled` / `isShrinkResources` act on Android code and resources, while Godot's PCK lives in `assets/`, a separate source set. **Nothing in the 39 qualified for KEEP.** Nine carried book page cites and all nine were duplicate-or-fabricated, including the only two candidates that looked unique: `CharacterCreationTables.roll_background_event` cites "p.14-15" for a d66 table, but Core Rules p.14 is **Crew Type Tables** and p.15 is **Human Characters** — the book routes to "the Background, Motivation, and Class Tables (**pp.24-27**)", which are **D100** — and its JSON grants "+1 to Leadership / Survival / Morale checks", none of which is a Five Parsecs stat; `FiveParsecsMissionGenerator.calculate_enemy_count` is superseded by `EnemyGenerator.gd:589-658`. ⚠ **Deleting them exposed 8 new permanently-false `has_method` guards** — every one named a method defined ONLY on a deleted class, and every one already fell through to the branch doing the real work (`EquipmentManager.gd:792`'s `else` is the live path; product never calls `Ship.add_component`, so that whole component subsystem is unpopulated). The dead-guard lint caught all 8 plus 8 stale allowlist entries, which is the regression guard working exactly as designed.
- **`uid://` is a SECOND reference form, and the deletion protocol does not grep it (Sep 4 2026)**: Godot's ResourceUID exists so references survive a rename or move (`uid://` scheme, Context7-verified against the 4.6 docs), so a `.tscn` can point at a script by UID with its path nowhere in the file. This repo has **106 `uid://` references** in `src/` scenes. `WIRING_CLEANUP_BACKLOG.md`'s protocol greps `res://` paths, `has_method("name")`, `.name(`, `Callable`, and `method=` — **not UIDs**. Extract each candidate's UID from its `.uid` sibling and grep that too; the Sep 4 sweep did and came back 0/39, but a path-only grep can pass while a live scene still resolves the file.
- **The PyPDF2-index-to-folio offset is PER BOOK (Sep 4 2026)**: Core Rules = index **+1** (idx 23 → p.24, verified at four points); Compendium = index **−1** (idx 22 → printed p.21, page tail reads `21Character Options`); `docs/rules/tactics_source.txt` markers = **−2** (raw 94 → p.92, raw 157 → p.155, raw 170 → p.168). Applying one book's offset to another lands ~2-3 pages off in the Compendium and **63 pages off** in Tactics — which is exactly how `TacticsOperationalMap.gd` came to cite pp.155-168 (the *Lifeforms bestiary*) for the Operational System, which is **pp.92-100**. Derive the offset from the page tail every time.
- **A test that asserts nothing is a false green, and there were eleven (Sep 4 2026)**: `test_edge_cases_negative.gd` had **7 of 12** cases whose bodies were comments — "This test documents expected behavior" — plus one that set `current_phase` twice and checked no result; `test_battle_ui_components.gd` had **10 of 13** guarded by `is_instance_valid(event_bus)` against an `event_bus` its own setup hard-sets to `null` (FPCM_BattleEventBus was removed Feb 2026). All reported PASS on every run. That is worse than absent coverage: it reads as a green edge-case suite that does not exist. **When trimming a suite, count the cases that actually assert** — the case count alone will not tell you.
- **Reachability proves a file is LOADED, never that its API is USED (Sep 4 2026)**: `CampaignTurnController` preloaded and `add_child`ed `ContactManager` and `RivalBattleGenerator` on every turn-controller load, so `lint_orphan_assets.py` reported both as "reachable from product" — while **every public method of both classes had zero external callers**. `ContactManager`'s one connected handler was `pass`; `RivalBattleGenerator`'s two signals are emitted only from inside `generate_rival_battle()` and `process_rival_defeat()`, neither of which is ever called, so both handlers were unreachable; neither node's state was ever serialized. They were pure allocation. Two further `has_method` guards there (`mark_rival_defeated`, `register_patron_contact`) named methods with **zero definitions repo-wide**. ⚠ The orphan lint structurally cannot see this class — an "instantiated but never invoked" check is a separate pass. Removed the wiring, **kept the files**: `RivalBattleGenerator` cites Core Rules p.91 ×5 and p.119 ×2, and deleting a zero-caller file that implements a book chapter is the mistake the `UNWIRED_RULES` category exists to prevent (the p.91 types *are* live elsewhere at `BattleSetupRules.gd:30-31`, so these are parallel duplicates — but that is a wire-or-delete triage call, not a wiring fix). `test_only` 50 → 52 as a result.
- **A detection proof is only as discriminating as its fixture (Sep 4 2026)**: proving the house-rules fix, my first revert left all 16 cases GREEN. The stub campaign exposed **both** `get_house_rules()` and a `house_rules` property, so weakening the method probe simply fell through to the property — a fallback the real defect never had. The faithful revert (reproduce the ORIGINAL body: probe `GameState.is_house_rule_enabled` / `GameStateManager.get_house_rules`, never touch the campaign) failed the right case immediately. **Reverting "something near the fix" is not reverting the fix** — reproduce the original defect, and if the suite stays green, suspect the fixture before believing the test.
- **Two independent causes, either fatal alone — house rules never applied (Sep 4 2026)**: (1) `HouseRulesHelper.is_enabled()` probed `GameState.is_house_rule_enabled` and `GameStateManager.get_house_rules`; **neither method exists anywhere in `src/`**, so it returned `false` unconditionally, leaving 8 guarded call sites across combat, enemy generation, crew generation, patron rewards and post-battle injuries permanently in their default branch. (2) the creation UI was a free-text `TextEdit` whose lines were stored verbatim into `campaign.house_rules`, so `"Brutal Combat"` could never equal the id `"brutal_combat"`. **Fixing either half alone changes nothing a player can see.** The owner was always the campaign (`FiveParsecsCampaignCore:307`) and `PostBattleContext.gd:66-70` already read it correctly — a ready-made bridge nothing used. Also: `get_campaign_config_data()` rebuilds from a **fixed key literal** that omitted `house_rules` entirely (same chokepoint shape as `CampaignJournal.create_entry()`). Six of the eight rules were tagged `"source": "Community"` — invented mechanics in `src/data/`, two with unsourced numeric values — and were removed; the two book rules stayed, and `wild_galaxy` had its cite corrected p.65 → **p.73**. A player's own house rules now live in `house_rules_notes` (prose, never matched), which is what p.65 step 5 actually describes.
- **The documented shape was the RAREST one (Sep 4 2026)**: this file recorded legacy crew `origin` as a **float**. A census of 21 real save files found **4 float, 69 int, 59 String** — numeric origins are **52% of all crew/captain records and `int` outnumbers `float` 17:1**. Godot's JSON parser returns both as float so the in-engine symptom is identical, but a migration written from the docs would have been tested against the rarest case. Only **2 of the 12** affected saves carry a `species_id` for the `str()` band-aids to fall back on; the other 10 resolve to `"8"`, `"4"`, `"0"` — matching no species, so every species rule silently did not apply. **Take the census before writing the fix.**
- **A framework can be complete, tested, and validate a shape the app has never produced (Sep 4 2026)**: `SaveFileMigration._validate_migrated_data()` required top-level `schema_version`, `current_phase`, `turn_number` and `battle_results`. Across 21 real saves, **0 of the last 3 were present in any of them** and `schema_version` was nested under `meta` in all of them — so wiring it in would have rejected every save. `CURRENT_SCHEMA_VERSION` was also 1 while the only step was `_migrate_v1_to_v2`, making `needs_migration(1)` false and that step unreachable. The step itself added a `battle_results` key nothing reads, and its unit tests passed against hand-built fixtures in that fictional schema. ⚠ Also learned here: **validate AFTER stamping the new version**, not before — asserting `meta.schema_version == to_version` against data still carrying the old one can never be true.
- **A node path is not a stable address when the screen reparents its own scene (Sep 4 2026)**: `ShipPanel._initialize_components()` moves authored nodes into card containers (`_reparent()` around `:203`), so the path `ShipPanel.tscn` declares is valid only **before** the deferred `_ready()` work settles. A test using the authored path passed pre-settle and failed post-settle, which reads exactly like "the scene changed" when nothing had — `find_child(name)` is the fix. The product bug in the same place: the code asked for `"Traits/Container"` (the child is `TraitsContainer`), fell through to `get_node_or_null("Traits")` which **succeeds and binds the PARENT**, and `_update_traits_display()` then freed every child — destroying the "Ship Traits:" header and `%TraitsContainer` on every panel load, not merely on refresh.
- **An orphan lint that reads COMMENTS counts a file's own obituary as a reference (Sep 4 2026)**: `lint_orphan_assets.py` built its reachability edges from raw source, so ~18 files carrying comments like *"the only caller was phases/WorldPhase.gd, a file with zero instantiations"* kept `WorldPhase.gd` **alive in the graph**. The lint was reporting a dead file as reachable BECAUSE other files documented it as dead. Fixed by stripping `#` comments before the edge scan, on the src side AND the tests side (a test's comment must not keep a class alive either). ⚠ Strip with a regex that matches **string literals first** (`"(?:[^"\\]|\\.)*"|'...'|#[^\n]*`) — a naive `line.split("#")` corrupts every `"#ff9a52"` colour literal. Effect of the fix: `reachable` 585 → 559, `test_only` 34 → 50, **`orphans` 0 → 11**. All 11 were then verified by hand; 10 were deleted and one was NOT (see below). New third category `UNWIRED_RULES` keeps a book chapter visible instead of anonymous.
- **`orphans=0` was not true, and one of the 11 was a 14-page book chapter (Sep 4 2026)**: `src/data/tactics/TacticsOperationalMap.gd` declares *"Source: Five Parsecs: Tactics campaign rules pp.155-168"* and implements the whole operational layer (regions, zones, Army Strength, Cohesion, Player Battle Points). **None** of its mechanics exist anywhere else in `src/`. Deleting it would have deleted the chapter — the `reference_a_dead_chapter_can_have_nothing_wrong_with_it` shape, where complete correct code has no caller. It is now listed in the lint's `UNWIRED_RULES` set (which requires a page cite and warns when the entry becomes reachable), NOT in `ALLOWLIST` — that one is only for standalone entry points launched by path, and stretching it would have hidden the finding. **Before deleting any zero-caller file, ask which BOOK PAGES it implements.**
- **The deletion protocol's full-suite gate cannot run (Sep 4 2026)**: `docs/WIRING_CLEANUP_BACKLOG.md` says *"Every wave: headless compile + FULL suite (`-a tests/unit -a tests/integration -a tests/battle -c`) green before commit."* Batching that many gdUnit4 suites into one process **segfaults (signal 11) at ~58 suites started**, deterministically for a given batch. Proven PRE-EXISTING by running the identical batch in a throwaway `git worktree` at HEAD — it crashed in the same neighbourhood. **Run `tests/unit` in batches of ≤40 instead**; the whole directory then passes (7 batches, **3,068 cases, 0 failures**). Never conclude a deletion broke something from a mega-run crash — control it against HEAD in a worktree first, and never with `git restore`.
- **A re-home can silently drop a modifier (Sep 4 2026)**: the p.72 forged-licence rule moved out of the dead `TravelPhase.gd` into `NewWorldArrival.attempt_forged_licence()` — correctly, and better (it enforces "only one attempt", grants the licence, and reads the natural 1 before modifiers). But the move **lost the p.57 Fake ID +1**. `OnboardItemService.license_bonus()` had exactly ONE caller, `InterdictionRule.gd:156` (the p.75 roll), so the item that says *"Add +1 to ALL attempts to obtain a license or other legal document"* did nothing on the one roll it is named for. The bonus now resolves INSIDE `attempt_forged_licence()` rather than being passed in by the caller, because a caller-supplied modifier is exactly what went missing. Pinned by `tests/unit/test_fake_id_forge_license.gd` (7 cases, seeded RNG so the natural-1 branch is deterministic, detection-proven). ⚠ That suite used to drive the DEAD `TravelPhase.gd`, whose copy of the rule also read the book **wrongly** — it returned early on a natural 1 with `success=false`, where the book states two INDEPENDENT clauses (a natural 1 that still totals 6+ both succeeds AND adds a Rival).
- **A rule written out inline three times will lose one copy, and the drawn size is not the declared size (Sep 4 2026, BUG-101 third occurrence)**: terrain escaped the grid again, and it was TWO independent defects. (a) The grid-distributed fallback in `BattlefieldMapView._rebuild_terrain_shapes()` clamped at the TOP of its retry loop and nudged `c.y` at the BOTTOM, commented *"re-clamped next pass"* — on the 16th pass there is no next pass. Clamp and nudge also OSCILLATE (clamp pins to `grid_h - half_y`, nudge pushes to `grid_h + half_y + pad`), so all 16 retries re-test two positions and exhaustion is the COMMON case: **227 of 3,898 shapes, overflow exactly `2*half_y + padding`, worst 101px on a 576px grid.** (b) `BattlefieldShapeLibrary.create_vector_shape()` sets `svs.rx = ry = 4.0` on every RECT, so a body shorter than 8px cannot fit its own corner rounding and the tessellated curve bulges to a **~8.004px floor** — reserving the DECLARED `w`/`h` under-reserved, pushing small `is_scatter` pieces out on 2ft tables (11 shapes, ≤0.82px). The bounds rule is now ONE helper, `_clamp_center_to_grid()`, applied on every exit path, and half-extents come from `svs.get_bounding_rect()`. ⚠ **My own first diagnostic lied**: it compared the drawn footprint against `child.size`, which SVS reports back from the REBUILT CURVE (8.004), not the value assigned (6.29), so it read `error = 0.000` while defect (b) was live — **a check that cannot disagree with the thing it is checking proves nothing**. ⚠ **Operand order matters**: `Rect2 * Transform2D` is documented as the INVERSE (`rect * transform == transform.inverse() * rect`); `Transform2D * Rect2` is forward. ⚠ `Rect2.encloses()` is inclusive (`>=`/`<=`), unlike `has_point()` which excludes right/bottom — an exactly-clamped shape is meant to pass, so assert with a stated epsilon (measured float noise: 0.000061px). Pinned by `tests/unit/test_battlefield_shape_bounds.gd` (2 cases, both detection-proven); wide sweeps via `tests/tools/probe_terrain_bounds.gd`. **Eight other `test_battlefield_*` suites existed and NONE asserted geometry against the grid — which is why this was "verified" visually twice and came back twice.**
- **Absence of code is only a finding once you have read the PAGE (Sep 3 2026)**: the Core Rules "Setting" chapter, pp.136-145, has zero code presence — Trade on the Fringe, Local Authority, Unity Intervention all return nothing on a grep. That is CORRECT: those pages are worldbuilding prose with no dice, no tables and no mechanics. A zero-match grep is a lead, never a gap, and confirming it costs one PyPDF2 extraction. The inverse of the same discipline caught a near-miss the other way: the Cheat Sheet prints a To Hit row ("covered target within 6 inches: 5+") that is NOT on p.44 and looked fabricated — errata v1.06 p.4 adds it explicitly.
- **An edit that lands inside a multi-line statement breaks the file SILENTLY, and a text-scanning test cannot see it (Sep 3 2026)**: a `const ... = preload(...)` was inserted between the two lines of an existing `preload(` continuation in `CheatSheetPanel.gd`. The file stopped parsing; `TacticalBattleUI._instance_log_only_components()` then failed on `_get_res("cheat_sheet").new()` with *"Nonexistent function 'new' in base 'GDScript'"* and **aborted `_setup_ui()`**, so the live battle screen stopped building. Nothing caught it: the panel's own suite (`test_cheat_sheet_from_data.gd`) reads it as TEXT via `FileAccess`, so all 14 content cases stayed green against a file the engine could not load. **A source-scan test proves the right words are present, never that the file COMPILES** — pair every text-scan suite with one case that actually loads the script. Two further traps found while building the guard: a plain `load()` null-check detects NOTHING here (it serves the resource cache, and a parse-broken GDScript still returns a non-null object — which is exactly why the error was "Nonexistent function 'new'" and not a null deref), and **`godot --check-only` EXITS 0 even when it prints a parse error**, besides reporting `Compile Error: Identifier not found: <Autoload>` for any script that references an autoload (14 of 60 changed files), so filter its output on `Parse Error` alone. Guarded by `scripts/lint_multiline_statement_breaks.py`.
- **GDScript rejects unknown escape sequences in string literals, and a regex is where you will hit it (Sep 3 2026)**: `"ContentFlag\.([A-Z_]+)"` is a PARSE ERROR, because `\.` is not one of GDScript's escapes. Valid ones are `\n \t \\ \" \' \a \b \f \r \v \uXXXX`. Write the regex as `[.]`, or double the backslash. The reason this is worth a gotcha rather than a compile error you would notice: **gdUnit4 reports a parse error as "No test cases found" and EXITS 0**, so the suite looks like it ran clean. Read the case COUNT on every run.
- **A `data/RulesReference/` file can be a faithful extraction of the WRONG BOOK (Sep 3 2026)**: `EnemyAI.json` held the COMPENDIUM pp.42-43 "AI Variations" base conditions and 1D6 tables, verbatim and correct, under a Core Rules label — and three consumers rendered them at every tier with no DLC gate, one of them citing "Core Rules pp.113-115" in its own docblock. A player who owned no expansion was told to roll a die for every enemy activation, which Core Rules p.42 explicitly does not do ("The default AI is diceless"), and the seven core bullet routines were in the app NOWHERE. Every census passes this: producer, consumer, key, flag and call site all exist and agree. **Before trusting a rules file, ask which book its text is from.** The two files now carry `_source` and `_provenance_warning` keys; add them to any new extraction. Pinned by `tests/unit/test_enemy_ai_reference.gd`.
- **The errata and the FAQ overturn the printed page, and a correct page cite hides it (Sep 3 2026)**: five rules were implemented exactly as the book prints them and are now WRONG. Lay Low (pay 1D6+1 credits to skip a battle), creation Patrons offering a job on turn 1, discarding all Rumors at a Quest conclusion, the Bio-upgrade's free Implant, recruits rolling the full creation tables, accepting several Patron jobs at once, and Mods/Sights being barred from *disposable* weapons rather than 1-shot ones — none of those are in either rulebook. Sources: `docs/gameplay/rules/5P_errata_and_tweaks106.pdf` (⚠ its page 5 says of ITSELF that it is not official — never implement from that page) and <https://modiphius.net/en-us/pages/five-parsecs-faq>. **Check both before implementing any under-specified table, and treat a `p.NN` comment as evidence the code followed the book, not that the book still says it.**
- **A reference SURFACE can print rules that are in neither book (Sep 3 2026)**: `CheatSheetPanel` — the panel a player consults MID-BATTLE — built every Compendium section from a hand-written literal, and four of them were invented: a D6 casualty table and a 2D6 injury table cited to "p.86"/"p.87" (which hold neither), a salvage-to-credits scale that does not exist, the wrong Suspect table at the wrong range, and the wrong stealth reinforcement rate. One shipped a literal `pass` statement in player-facing text. A dead rule does nothing; a fabricated rule misinforms play. **Never put a mechanic's numbers in a UI literal — render the reference from the SAME data the mechanic reads** (`src/ui/components/battle/CheatSheetSections.gd`), so the two cannot drift. Pinned by `tests/unit/test_cheat_sheet_from_data.gd`, detection-proven by editing the DATA.
- **Godot's JSON parser returns every number as FLOAT — so `value is int` is ALWAYS false on loaded data (Aug 1 2026)**: `StoryEvent.load_from_json()` had `next_clock_ticks = clock_val if clock_val is int else 0`, which silently zeroed the next-clock for all seven Story Events. Nobody noticed for as long as the clock had no caller. Use `int(value)` with an explicit `== null` guard (events 5 and 7 legitimately carry `null` there), never an `is int` type test, on anything that came out of `JSON.parse`.
- **A fix ordered against SOME callers is not a fix (Aug 14 2026)**: `initialize_job_offers()` has THREE callers — `_fetch_campaign_data()`, `_show_current_step() -> _refresh_job_offers()` (:1177), and `initialize_world_phase()` (:961). T9-50 was "fixed" twice by ordering the restore against the first two; both passed every desk gate and failed on hardware. **`grep` the callee and COUNT the call sites before choosing where to insert, or make the fix order-independent (guard the callee).** The killer is #3: `CampaignTurnController` **shows** `WorldPhaseController` each turn rather than re-instantiating it (its own comment, `WorldPhaseController.gd:900-902`), so `initialize_world_phase()` runs AFTER `_ready()` and re-runs `_initialize_components_with_data()` unconditionally. **When a screen is REUSED between turns, `_ready()` is not the whole initialisation story — find the orchestrator entry point first.** Cheap disproof for any such diagnosis: pick a state where the suspected cause CANNOT fire (here, MISSION_PREP, where `_refresh_job_offers()` is unreachable) and see whether the symptom survives.
- **"Settled" is not "hung", and CPU means nothing without a baseline (Aug 14 2026)**: three device runs were spent chasing a non-existent battle-transition hang. **"Ready for Battle" is not the battle launcher** — it COMPLETES the Mission Prep step (hence the greying and the full `✓✓✓✓✓✓` strip); a separate green **"Proceed to Battle"** button appears at the BOTTOM of the page, below the fold. A pixel-diff showing "nothing changed" means the screen has **settled** — scroll and look elsewhere before concluding a control did nothing. And this app idles at **32% CPU on the main menu / 37% on the dashboard** with CPU-time climbing steadily (Godot renders continuously), so ~55% is unremarkable: **take the idle baseline before calling a number anomalous.**
- **A "rebuild from a fixed key literal" chokepoint silently DELETES every other key (Aug 9 2026)**: `CampaignJournal.create_entry()` assembles each entry from a literal `{id, turn_number, timestamp, type, auto_generated, title, description, mood, tags, characters_involved, location, photos, stats, player_notes}`. Anything else its caller passed is gone. Grepping the PRODUCER finds the key (the caller does pass it!) and tells you nothing — grep the chokepoint's literal. A hand-written test fixture of such an output is a shape the app **cannot produce**, so build fixtures with the real producer. This is how five of the Encounter Log's six boxes printed blank on every campaign with 28 green tests.
- **Test the SCREEN, not just the builder it calls (Aug 9 2026)**: every sheet test called `SheetDataContext.build(a, b, c)` and *passed a, b, c in*, so nothing exercised the ~15 lines of `PrintSheetScreen._build_data_context()` that FETCH them — and both device-only defects lived exactly there (a dead `has_method` name, and an object-vs-Dictionary type check). Same shape as the T9-23 stash bug: a test of the callee is blind to a caller defect.
- **When a symptom survives a correct fix, look for a SECOND cause before reverting (Aug 9 2026)**: the Encounter Log was blank for THREE independent reasons, each sufficient alone. "Still blank after your fix" was never evidence the fix was wrong.
- **`damage_hull()` does not exist — the real API is `apply_ship_damage()` (Aug 1 2026)**: `func damage_hull` has ZERO definitions repo-wide, yet `CampaignEventEffects.gd` and `CharacterEventEffects.gd` both guarded on `gsm.has_method("damage_hull")` and returned a result string claiming the ship took damage. Permanently-false branches; the hull was never touched. `GameStateManager.apply_ship_damage(amount) -> int` is the live one and it applies ship traits (Armored -1, Improved Shielding -1, Dodgy Drive +2) and returns the damage actually dealt.
- **A dead-code sweep can remove the seam instead of the corpse (Aug 1 2026)**: `c8fd7e07c` deleted `is_story_event_turn()` / `get_story_turn_mods()` / `get_story_battle_config()` from CampaignPhaseManager as "redundant zero-caller methods". They were zero-caller only because their one consumer, `phases/BattlePhase.gd`, had been deleted six weeks earlier. Before deleting a zero-caller **provider**, ask what used to call it — a missing consumer and genuine dead code look identical. Dead consumers are the dangerous ones; dead providers are usually a missing wire.
- **Galactic War = the Core Rules p.126 2D6 table, nothing else (Jul 29 2026)**: step 14 is "If you are tracking any planets that were previously Invaded, roll 2D6" (2-4 Lost to Unity / 5-7 Contested / 8-9 Making Ground +1 to future rolls / 10+ Unity Victorious, world visitable again and future Invasion Threat at -2). `GalacticWarProcessor` implements it exactly. The tracked list lives on `FiveParsecsCampaignCore.invaded_planets` and is written ONLY via `record_invaded_planet()`, called from `TravelPhase._invasion_escape_result()`; the -2 aftermath is read via `get_invasion_threat_modifier()` in `PaymentProcessor.process_invasion_check()`. **`GalacticWarManager` and its "war track" system were DELETED** — the phrase appears in NEITHER rulebook (the Compendium index has one entry, `Galactic War Progress 126`) and the whole subsystem was inert. Do NOT re-add war tracks, `data/galactic_war/`, `GalacticWarPanel` or `GalacticWarProgressPanel`.
- **Stars of the Story has FIVE options, not four (Core Rules p.67)**: `StarsOfTheStorySystem.StarAbility` = `{ITS_TIME_TO_GO, LOOKED_WORSE, DID_YOU_EVER_MEET, LUCKY_SHOT, RAINY_DAY_FUND}`. Three are mid-battle (`StarsOfTheStorySystem.is_battle_only()` returns true). `DRAMATIC_ESCAPE` was a fabricated mechanic deleted May 2026 — do NOT re-add it. Elite Rank ×5 bonus is a campaign-setup pick via `apply_elite_rank_pick()`, NOT a runtime accrual (book p.65: "You must pick when setting up the campaign"). Persistence field on `FiveParsecsCampaignCore` is `stars_of_the_story` (NOT `stars_of_story_data` — that typo caused a silent failure). Insanity disables all stars. Bug Hunt/Planetfall correctly omit the field (Compendium p.214 forbids carry-over). All journal logging routes through static `StarsOfTheStorySystem.log_use_to_journal(ability, context, result, journal, turn, source)` with `source ∈ {"battle", "post_battle", "dashboard"}`.
- **`.exe` directory name**: The Godot installation folder IS named `*.exe` — this is a directory, not an executable
- **`replace_all` substring trap**: Short identifiers corrupt longer ones (e.g., replacing "HARD" also matches inside "HARDCORE"). Always check for substring collisions. **Also bites function names** — renaming `_next_free_outward` → `next_free_outward` mangled `test_next_free_outward_*` into `testnext_free_outward_*`, breaking gdUnit4 discovery silently (Galaxy Log Phase 0, Jun 1)
- **PlanetDataManager state leaks across modes** unless every campaign core's `apply_pending_qol_data()` calls `pdm.deserialize_all({})` UNCONDITIONALLY. Pre-Jun-1, only 5PFH cleared it (and only when planet_data was non-empty). Bug Hunt / Planetfall / Tactics now also clear on load; 5PFH's empty-data guard was removed. The autoload's `visited_planets.clear()` ONLY executes inside `deserialize_all()` — there is no other clear path
- **Journal `location` field write contract**: `CampaignJournal` battle/travel/milestone entries are all expected to set `location = current_planet.name` so `get_entries_by_location(name)` joins them. Pre-Jun-1, battle entries wrote `"Unknown"` (battle_result never carried a `location` key) and milestone entries omitted the field entirely. Post-Jun-1, all writers resolve from `pdm.get_current_planet().name`. Pre-Jun-1 entries still have `location="Unknown"` — no backfill migration yet
- **Bug Hunt muster-out pickup was broken — now fixed (cross-mode transfer Foundation, Jun 2026)**: muster-out wrote a transfer file to `user://transfers/` but NOTHING ever read it, so mustered-out veterans silently vanished. The mode-generic pickup (`CampaignScreenBase._check_pending_transfers()` + `apply_transfer_rewards()` deleting the file) closed this. Any new transfer SOURCE leg is dead code unless a DESTINATION dashboard calls `_check_pending_transfers.call_deferred()` in `_setup_screen()` — wire both halves. See `docs/sop/cross-mode-transfer.md`.
- **`convert_from_planetfall` debt-swap data-integrity fix (Planetfall pp.165-166, verified planetfall_source.txt L12088-12113)**: the ending matrix was WRONG. Correct values: `loyalty` = `bonus_ship` + `ship_debt 0` (no debt); `independence_won` = `bonus_ship` + `ship_debt_prepaid` (2D6 PARTIAL prepayment) + `bonus_story_points 2` (the OLD BUG zeroed the whole debt — the book only prepays 2D6 of it); `independence_lost` = `add_rival` (Enforcers or Bounty Hunters) + `bonus_story_points 2`; `isolation` = +1 Luck + `isolation_single_char` flag; `ascension` = `gains_psionic`. Never re-introduce full debt forgiveness for `independence_won`.
- **Transfer snapshot + `_layer_planetfall_ending` layering (cross-mode transfer)**: an imported character carries a lossless `snapshot` of its canonical form; `export_to_canonical()` short-circuits on it so a round-trip is verbatim. Planetfall ending bonuses are layered on TOP of the snapshot-restored veteran via `_layer_planetfall_ending()` because the bonuses depend on the ENDING, not on stats. Don't "simplify" by recomputing stats from the Planetfall-side character — use the snapshot.
- **KP→Luck is deliberately NOT converted on Planetfall export**: the book is silent on a KP→Luck export conversion (the p.27 "prefer the Luck system" note is an IMPORT-side option only). `convert_from_planetfall()` restores base Luck (1); imported veterans get their real Luck back losslessly via the snapshot. Inventing a KP→Luck export formula would violate data integrity — do NOT add one.
- **Tactics character import = named veteran, NOT a squad unit (SHIPPED Jun 4)**: Tactics army lists stay species-profile-based. An imported character becomes a NAMED VETERAN (an "officer or hero" figure, Tactics p.185) stored in the serialized `veteran_characters[]` array on `TacticsCampaignCore` — NEVER injected into `campaign_units[]` (that would break points validation). Mutators: `add_veteran_character()` / `remove_veteran_character()` / `get_veteran_characters()`. `CampaignScreenBase._add_character_to_mode()` "tactics" case dispatches to `add_veteran_character()`. The `convert_to_tactics()` / `convert_from_tactics()` conversion is book-faithful (Tactics p.184): the invented `military_backgrounds` list is GONE (replaced with a "military"/"war-torn" substring check grounded in the real gear_database.json backgrounds — the book says only "+2 with a military-type background", no enumerated list); the `max(luck,1)` KP floor moved to the veteran layer as a tagged playability floor so the conversion stays exact ("1 Kill Point per Luck point"); equipment carries over as-is ("carry weapons over as they are"). The `military_backgrounds` GAME_BALANCE_ESTIMATE tag and "must replace first" prerequisite are GONE.
- **`to_dictionary()` hands back the LIVE containers, so it is a SERIALIZER, not a snapshot (Aug 8 2026)**: `FiveParsecsCampaignCore.to_dictionary()` returns `"crew": crew_data`, `"progress": progress_data`, `"equipment": equipment_data` etc. as REFERENCES. That is correct for saving (the JSON writer only reads), and catastrophic for anything that stores the result and expects it to stay put. `CampaignPhaseManager._store_phase_checkpoint()` did exactly that and **aliased the campaign to itself** — every later mutation wrote through into the "snapshot", and `rollback_to_phase()` assigned the same object back. The failure was worse than no checkpoint: scalar `@var`s (credits, `quest_rumors`, turn) DID revert because ints copy by value while every Dictionary silently did not, so a rollback produced an incoherent hybrid (a Quest still active alongside the Rumors it should have spent). Any new consumer that PERSISTS a `to_dictionary()` result must `.duplicate(true)` it. Pinned by `tests/unit/test_destructive_actions_confirm.gd`.
- **There is no soft-keyboard signal in Godot 4.6 — arm on focus, then POLL (Aug 8 2026)**: the whole API is `DisplayServer.virtual_keyboard_show/hide/get_height`, and `get_height()` returns 0 while hidden. The only trigger is `Viewport.gui_focus_changed`, and at the instant it fires the keyboard is still ANIMATING IN, so the height still reads 0 — a handler that samples once on focus measures zero every time and silently does nothing on every device. `src/autoload/KeyboardAvoidance.gd` is the SSOT: arm on focus, poll until the height is stable, apply once, disarm. Note `virtual_keyboard_get_height()` is in PHYSICAL px while Control rects are in the stretched design space (square-1080 `canvas_items`+`expand`, so the ratio differs per orientation) — convert via `to_logical_height()`, never compare directly. `ScrollContainer.follow_focus` exists but only scrolls into the scroll's own rect and knows nothing about the keyboard.
  - **MEASURED on a Lenovo TB361FU (Aug 8 2026): the Godot Android window does NOT resize when the IME opens — the keyboard purely OVERLAYS.** Proven by pixel-diffing two screencaps: the app content above the keyboard line was byte-identical with the keyboard closed and open (0 of 2,048,000 px differed). This is the load-bearing fact for the whole feature — if the window resized, `get_visible_rect()` would already exclude the keyboard and any app-side adjustment would DOUBLE-COUNT. Godot's docs say nothing either way; do not re-derive this, and do not "simplify" the avoidance away on the assumption that Android handles it.
  - **Scrolling alone is not enough.** On a page whose content already fits, the ScrollContainer's range is ZERO and `scroll_vertical += shift` clamps back to 0 — the feature silently no-ops. That is most single-screen forms, and it is how the Campaign Editor failed its first device test with the fix supposedly in. Headroom (a temporary spacer appended to the scroll's content) is what makes the range exist; it must be removed when the keyboard closes or it becomes permanent dead space.
  - **VERIFIED against the engine source: the height is PHYSICAL (raw device) pixels.** The class reference says only "in pixels", so this was traced instead. `DisplayServerAndroid::virtual_keyboard_get_height()` is a straight pass-through of `godot_io_java->get_vk_height()` with no scaling ([display_server_android.cpp](https://github.com/godotengine/godot/blob/4.6/platform/android/display_server_android.cpp)), and the Java side derives it from `WindowInsetsCompat.Type.ime()` — **Android window insets are always raw device px**. So `to_logical_height()` converting by the stretch ratio is correct; do not "simplify" it away.
  - **Engine history worth knowing: the nav bar used to be double-counted.** [godot#86663](https://github.com/godotengine/godot/issues/86663) (with [#41388](https://github.com/godotengine/godot/issues/41388)) reported the navigation-bar height being ADDED to the keyboard height on Android 11+ when the nav bar is permanently visible, giving a keyboard height that is too LARGE — i.e. over-scroll. Affected 4.2-4.3, closed via PR #108287 at **milestone 4.5**, so **4.6 (this project's engine) contains the fix**. It reportedly did not reproduce on every Android 11+ device, so the debug-build `print` in `_apply_avoidance()` (raw/window/logical/shift) is kept to confirm it on the specific test tablet rather than assumed: compare `raw` against the keyboard's measured height in a screencap (~762 of 1600 px on the TB361FU).
- **`--headless --quit` is NOT comprehensive**: Only validates startup scripts. The Godot editor LSP loads ALL scripts. Always reboot editor after headless check
- **`class_name` + autoload conflict**: If a script has `class_name Foo` AND is registered as autoload "Foo", Godot 4.6 errors "Class hides an autoload singleton." Fix: remove `class_name` from autoloaded scripts
- **`Engine.has_singleton()` does NOT work for autoloads**: Autoloads are scene tree nodes at `/root/Name`, NOT engine singletons. For non-Node classes (Resource/RefCounted), use `Engine.get_main_loop().root.get_node_or_null("/root/AutoloadName")`
- **Character.creation_bonuses is single source of truth**: All creation resource data (bonus credits, patrons, rivals, story points, rumors, starting rolls) is in `Character.creation_bonuses`, set once by `CharacterCreator._roll_and_store_creation_bonuses()`. Never re-derive from gear_database.json or `CharacterGeneration.roll_character_tables()`
- **Godot 4.6 type inference**: `var x := untyped_array[i]` fails. Use explicit typing: `var x: Type = array[i]`
- **Two VictoryDescriptions files**: `src/core/victory/` (basic) and `src/game/victory/` (full, used by UI)
- **Verify high-stakes agent claims, not routine ones**: trust current models for search and reading. Re-verify only where being wrong is expensive — game-data values (against `data/RulesReference/` + the PDFs) and the project-manager's routing targets (confirm the file/API exists before delegating). Routine "where is X handled" findings don't need re-verification
- **PowerShell for batch ops**: Bash `sed -i` doesn't work on Windows. Use PowerShell `-replace` with proper regex
- **Character stats are FLAT**: `Character` has `combat`, `reaction`, `toughness`, `speed`, `savvy`, `luck` as direct properties. There is NO `stats` sub-object. `CharacterStats.gd` is a separate Resource class.
- **CharacterCreator.start_creation()**: Accepts `CreatorMode` enum (not bool). Has legacy bool compatibility.
- **FiveParsecsCampaignCore is Resource**: `campaign["key"] = val` silently fails. Use `progress_data["key"]` for runtime state. Use `"key" in campaign` instead of `.has("key")`
- **World phase components need refresh**: Initialized at `_ready()` with stale data. Must call `_refresh_*()` from `_show_current_step()` when entering each step
- **equipment_data key is `"equipment"`**: Ship stash is stored under `campaign.equipment_data["equipment"]`. Do NOT use `"pool"` — that was a systemic bug fixed in Phase 22
- **Character.to_dictionary() dual keys**: Returns both `"id"`/`"name"` AND `"character_id"`/`"character_name"` aliases. Always include both when manually creating crew dicts
- **Legacy saves store crew `origin` as a numeric enum (float); new campaigns store it as a String**: `Character.origin` is `@export var origin: String` validated to enum strings (Character.gd:42), so post-migration campaigns serialize `"origin": "precursor"`. But pre-migration save files persist `"origin": 7.0`. Any string op on a crew member's origin (`.to_lower()`, `==` against a String, `.capitalize()`) HARD-ERRORS (`Invalid call ... 'to_lower' in base 'float'`) on legacy crew. ALWAYS `str()`-wrap: `str(member.get("species_id", member.get("origin", ""))).to_lower()`. Fixed Jun 3 2026 at CrewTaskComponent.gd:262 + CampaignEventEffects.gd:91 (`str()` band-aids); the proper root fix is a load-time `origin` float→String normalization in the save-migration layer. Prefer `species_id` (always String) where present
- **PreBattleUI uses `setup_preview()`**: Not `initialize_battle()` or `set_mission_data()`. Also needs `setup_crew_selection()` for crew panel
- **Autoload timing with `load()` vs `preload()`**: Autoloads parse before import system. StoreManager uses `load()` at runtime for adapter scripts, and adapters use path-based `extends "res://path/to/script.gd"` instead of `extends ClassName`
- **GodotApplePlugins StoreKitManager is NOT a singleton**: Use `ClassDB.class_exists(&"StoreKitManager")` + `ClassDB.instantiate(&"StoreKitManager")`. Do NOT use `Engine.get_singleton()`
- **Android BillingClient availability**: Check with `ClassDB.class_exists(&"BillingClient")`, NOT `Engine.has_singleton()`. Uses official GodotGooglePlayBilling plugin (replaced third-party AndroidIAPP in Phase 34)
- **Steam needs `steam_appid.txt`**: Place at project root with base game App ID. Without it, `steamInitEx()` returns status 1
- **Bug Hunt ↔ 5PFH campaign types are incompatible**: `BugHuntCampaignCore` has `main_characters`/`grunts` (flat Arrays), `FiveParsecsCampaignCore` has `crew_data["members"]` (nested Dict). Always validate `"main_characters" in campaign` before Bug Hunt code. `GameState.load_campaign()` currently only loads FiveParsecsCampaignCore — Bug Hunt uses separate SceneRouter-based loading
- **Bug Hunt temp_data keys use `"bug_hunt_*"` prefix**: `"bug_hunt_battle_context"`, `"bug_hunt_battle_result"`, `"bug_hunt_mission"`. Standard keys: `"world_phase_results"`, `"return_screen"`, `"selected_character"`. No collisions
- **TacticalBattleUI shared between both modes**: Bug Hunt code is guarded by `battle_mode == "bug_hunt"` and `_check_bug_hunt_launch()` validation. Standard flow unaffected
- **Bug Hunt equipment step auto-completes**: `BugHuntCreationCoordinator.go_to_step()` marks EQUIPMENT complete automatically since Bug Hunt uses standard issue (read-only panel). Without this, the Next button won't appear on step 3
- **Planetfall campaign type**: `PlanetfallCampaignCore` uses nested dicts (`config`, `colony`, `progression`, `meta`, `roster`). Campaign type is `"planetfall"`. Save/load uses `PlanetfallCampaignCore.load_from_file()` (not GameState.load_campaign)
- **Planetfall temp_data keys use `"planetfall_*"` prefix**: `"planetfall_battle_result"`, `"planetfall_mission"`. Cleared after `_resume_after_battle()` consumes them
- **PlanetfallTurnController init order**: `_start_or_resume_turn()` MUST be called after `_create_phase_manager()`. Battle phase (7) triggers SceneRouter navigation — completing it via phase_manager frees the TurnController
- **PlanetfallScreenBase extends path-based**: Uses `extends "res://..."` not class_name, due to Godot 4.6 parse order issues. PlanetfallDashboard + TurnController also use path-based extends
- **Planetfall panels extend Control directly**: Not BaseCampaignPanel — they define their own `COLOR_*`/`FONT_SIZE_*` constants locally
- **Tactics data model**: TacticsUnitProfile/VehicleProfile/WeaponProfile are RefCounted with static `from_dict()` factories. Use `load()` pattern in static methods (not `ClassName.new()`)
- **TweenFX pivot_offset**: TweenFX NEVER sets `pivot_offset`. Must call `node.pivot_offset = node.size / 2` before any scale/rotation animation (`press`, `pop_in`, `pulsate`, `punch_in`, `breathe`, `tada`, `critical_hit`, `upgrade`, `attract`, `headshake`). Safe without: `fade_in`, `fade_out`, `blink`, `spotlight`, `alarm`, `shake`
- **TweenFX looping cleanup**: Looping animations (`alarm`, `breathe`, `attract`, `glow_pulse`) must be explicitly stopped with `TweenFX.stop(node, TweenFX.Animations.X)` or `TweenFX.stop_all(node)` in cleanup/hide code
- **TweenFX.tada() signature**: Takes only 2 args `(node, duration)` — no scale parameter
- **GameEnums ↔ GlobalEnums ordinal sync**: After the Mar 23 fix, shared enum members MUST have identical ordinal values. GameEnums-only extras use explicit `= N` values. Verify with MCP Scenario 9 after any enum changes
- **CampaignDashboard dict key fallbacks**: Crew reads `"origin"`/`"character_class"` with fallback to `"species"`/`"class"`. Equipment reads `"weapons"`/`"armor"`/`"gear"` but auto-decomposes from `"equipment"` if unified format found. Always `str()` wrap values assigned to String-typed vars (character_class may be int)
- **BasePhasePanel + BaseCampaignPanel auto-background**: Both inject a `COLOR_BASE` ColorRect in `_ready()` with `show_behind_parent = true`. Named `"__phase_bg"` / `"__panel_bg"` to prevent duplicates. New panels inheriting either base get correct background automatically
- **TransitionManager overlay blocks MCP screenshots**: `TransitionOverlay` (full-screen ColorRect) must be disabled (`visible = false`) for MCP take_screenshot to work during scene transitions. Safe to disable for automated testing
- **MCP `run_project` runs the game in `--debug`, so the debugger HALTS on any runtime error — and "halts under MCP" cuts both ways**: in normal (non-debug) play the same error prints `SCRIPT ERROR` and the process keeps running, so it is tempting to dismiss an MCP "debugger break" as debug-only noise. Two distinct error classes: (a) **Dictionary missing-key access** — Godot returns `null` and continues *within* the same function (often genuinely harmless log-spam); (b) **nonexistent method/property, or a type-method mismatch like `.to_lower()` on a float** — Godot ABORTS the current function (unwinds it) then continues the process. Class (b) is a REAL bug even though the app doesn't close: if the aborted function was doing essential work (a creation card, a post-battle step), that feature silently does nothing. Do not over-claim a crash on (a); do not under-claim a real defect on (b). Walking the campaign happy-path on a LEGACY save under MCP surfaced 4 class-(b) bugs on Jun 3 2026 that unit tests and `--headless` both passed through
- **UI/UX issues tracker**: `docs/QA_UI_UX_ISSUES.md` — 30 issues found, 21 fixed, 9 deferred (card containers, dialog backdrop, max-width, disabled button contrast)
- **Project-wide theme**: `sci_fi_theme.tres` is set via `gui/theme/custom` in `project.godot`. All controls inherit fonts and styles unless overridden. Per-element `add_theme_*_override()` calls always take priority over the project theme
- **Legacy `5PFH.tres` theme removed from CampaignDashboard**: Was a sprite-based theme with empty textures and a different color palette. Dashboard now inherits the project-wide Deep Space theme
- **Bug Hunt panels extend Control (not BaseCampaignPanel)**: `BugHuntCreationUI` has its own `MAX_FORM_WIDTH` and `_apply_content_max_width()` since it doesn't inherit from BaseCampaignPanel
- **Portrait path existence check**: Use `ResourceLoader.exists()` for `res://` paths, `FileAccess.file_exists()` for `user://` paths. `FileAccess.file_exists()` fails for `res://` in exported PCK builds
- **CharacterCard portrait priority**: `_update_portrait()` checks `portrait_path` first (custom image), falls back to colored initials (8 deterministic colors from `name.hash() % 8`). IconRegistry class icons are no longer the default
- **CampaignDashboard ButtonContainer is HFlowContainer**: NOT GridContainer. Auto-wraps, no `columns` property to manage
- **Deleted fabricated systems (Apr 2026)**: MoraleSystem.gd, EnemyLootGenerator.gd, LootEconomyIntegrator.gd, CampaignWorkflowOrchestrator.gd, DeveloperDashboard.gd, WorkflowSystemTester.gd, equipment_tables.json, `src/core/debug/` directory, FiveParsecsStrangeCharacters.gd (6 invented types), BaseStrangeCharacters.gd — all removed. Do NOT reference or re-create these
- **Deleted dead files (Jul 2 2026 fixit sprint)**: CampaignSerializer.gd, CampaignFactory.gd (+`src/core/workflow/` dir), CampaignStateService.gd, GameSystemManager.gd, MissionIntegrator.gd, WorldPhaseUI.gd (the replaced monolith), `src/game/story/StoryQuestData.gd` (duplicate — live copy is `src/core/story/`), legacy CampaignManager.gd, EventManager.gd, SystemErrorIntegrator.gd, UIBackendIntegrationValidator.gd, ValidationErrorBoundary.gd, `src/core/systems/world` (extension-less orphan), `src/core/victory/VictoryConditionSelection.gd` (duplicate — live copy is `src/game/victory/`), the fabricated `BattleCalculations` species region, DeploymentManager `infer_*` methods, and the dead `Skill`/`Ability` enums from BOTH enum files, plus stale tests `test_ship_stash_persistence.gd`. Do NOT re-create; `tests/unit/test_enum_ordinal_sync.gd` + `test_species_rule_gates.gd` pin the invariants. Wiring-audit sprint (Jul 10 2026, branch `wiring-audit-sprint`) DELETED the orphans `src/game/combat/CombatResolver.gd` (the "nonexistent enum" reason was STALE — its `GameEnumsScript` alias resolves to GlobalEnums which HAS `SPECIAL_ABILITY`; the file was simply zero-referenced), `src/ui/screens/rules/RulesDisplay.gd`, `src/ui/screens/rules/RulesReference.gd`. Remaining dead-code is TRACKED BY PERMANENT LINTS (see Testing). **Those backlogs are now CLOSED — `lint_signal_wiring`, `lint_autoload_lookups` and `lint_tscn_connections` all report CLEAN (Aug 6 2026).** The historical counts they were opened with (67 declared-never-emitted / 35 dead `/root/Name` / 6 dead `[connection]`s) are kept here only so a future reader knows what was burned down, not as a current worklist. `EquipmentManager.apply_gun_mod()` still zero-caller (zero-caller backlog).
- **Deleted orphan files (Aug 6 2026)**: `src/core/battle/BattlefieldManager.gd` (431 lines — generated terrain by density float across desert/urban/forest/space_station themes; the live generator is `FPCM_BattlefieldGenerator` with the FOUR BOOK themes only, so this contradicted the verified generator rather than extending it. Its consumers were already removed in the Battle Companion QA sprint — only the file was left behind) and `src/core/enemy/base/Enemy.gd` (366 lines, `extends CharacterBody2D` — real-time 2D physics in a turn-based companion app; its only reference repo-wide was a preload of itself). Do NOT re-create either.
- **Deleted dead tutorial files (Aug 1 2026)**: `src/core/systems/tutorial` (an EXTENSIONLESS GDScript declaring `class_name TutorialActionTracker` — Godot never imported it, so the class did not exist), `src/ui/screens/campaign/NewCampaignTutorial.gd` (341 lines), `src/ui/screens/tutorial/TutorialSelection.tscn` + its README, the `tutorial_selection` SceneRouter route and `"tutorial"` category, the `MainMenu.tscn` `TutorialPopup` subtree with its 4 connections, and `MainMenu.gd`'s `_show_tutorial_popup` / `_connect_tutorial_signals` / `_on_tutorial_popup_button_pressed` / `_handle_tutorial_choice` / `_on_disable_tutorial_toggled`. The whole chain hung off `_show_tutorial_popup()`, which had ZERO callers, so none of it was reachable. Also deleted `src/ui/components/campaign/StoryTrackSection.{gd,tscn}` (301 lines, superseded by the inline dashboard card) and its two silently-skipping tests. Live onboarding is the coach-mark overlay (`TutorialUI` + `data/tutorials/`) plus the book's Introductory Campaign.
- **Deleted dead UI files (Session 40)**: ConfigPanel.gd+.tscn, CampaignSetupScreen.gd, CampaignSetupDialog.gd+.tscn, DifficultyOption.gd, gameplay_options_menu.gd, QuickStartDialog.gd, CampaignLoadDialog.gd, CampaignSummaryPanel.gd, CampaignCreationManager.gd — all replaced by ExpandedConfigPanel/CampaignCreationCoordinator. Do NOT recreate
- **Deprecated PostBattlePhase files (Session 47)**: `src/core/campaign/PostBattlePhase.gd` (old 5-step Control stub), `src/game/campaign/FiveParsecsPostBattlePhase.gd` (zero refs), `src/base/campaign/BasePostBattlePhase.gd` (only ref was dead file). CampaignPhaseManager now uses `src/core/campaign/phases/PostBattlePhase.gd` (14-step orchestrator). Safe to delete the 3 deprecated files
- **Deprecated CoreSystems.WeaponTraitSystem (Session 47)**: Inner class in CoreSystems.gd had fabricated Focused mechanic, zero callers. Weapon traits now via `BattleCalculations.get_weapon_trait_effects()`. Do NOT use WeaponTraitSystem in new code
- **DifficultyLevel HARD/NIGHTMARE/ELITE are DEPRECATED**: GlobalEnums.DifficultyLevel has 3 fabricated values (HARD=3, NIGHTMARE=5, ELITE=7) that are NOT in Core Rules or Compendium. Kept for save compat, aliased to NORMAL/INSANITY/INSANITY in JSON. Never expose in UI or use in new code. Only 5 real modes: Easy(1), Normal(2), Challenging(4), Hardcore(6), Insanity(8)
- **Progressive Difficulty is per-campaign**: Stored in `campaign.progress_data["progressive_difficulty_options"]` (Array of ints). Empty = disabled. `[1]`=basic, `[2]`=advanced, `[1,2]`=both. Read by BattlePhase, NOT by changing the difficulty enum
- **SpeciesDataService load order**: `Character.gd` cannot import `SpeciesDataService` at parse time (Godot loads Character first). Character helper methods use inline `species_id` string checks. Other systems (CharacterCreator, LuckSystem) can reference SpeciesDataService safely
- **`Character.status_effects`**: `@export var status_effects: Array[Dictionary]`, used by the post-battle Character Events system. This gotcha used to warn that `BaseCharacterResource` had a SEPARATE field of the same name — that class was deleted Sep 4 2026, so there is now only one.
- **Character Events: two systems, same name**: `data/campaign_tables/character_events.json` + `CharacterEventEffects.gd` = post-battle D100 table (30 events, Core Rules pp.128-130). `src/data/character_events.gd` = World Phase character events (7 weighted events, used by CharacterPhasePanel). `CharacterEventComponent.gd` is DEPRECATED (hardcoded 20-event table)
- **GameEnums.StrangeCharacterType is DEPRECATED**: Use `Character.species_id` (String) + `SpeciesDataService` for Strange Character identification. The enum has only 8 of 16 types and is kept only for backwards compatibility
- **Equipment data sources**: `gear_database.json` = D100 tables for character creation (backgrounds, weapon_tables, starting_rolls). `equipment_database.json` = weapon/armor/gear STATS (range, shots, damage, traits). These are separate files with different purposes
- **Trade sell value is flat**: Core Rules p.125 — items sell for 1 credit each. No condition tiers, no quality multipliers, no percentage-of-purchase formulas
- **`get_crew_size()` ≠ `get_campaign_crew_size()`**: `get_crew_size()` returns the fluctuating roster count (for upkeep, travel). `get_campaign_crew_size()` returns the fixed 4/5/6 setting chosen at creation (Core Rules p.63) — used for enemy count dice formula, deployment cap, reaction dice, stealth sentries (Compendium p.124), and salvage tension (Compendium p.141). NEVER use roster count where the setting is required
- **Project-level perf settings (Session 59, Apr 28)**: `project.godot` has `[application] run/max_fps=60` and `[physics] common/physics_ticks_per_second=30`. Do NOT bump physics rate back to 60 unless adding real-time physics gameplay (none today — battles are turn-based, no RigidBody2D updates per frame). FPS cap applies to high-refresh displays; expose via Settings UI later if needed.
- **Responsive/adaptive UI config (Jun 2026 mobile/tablet re-pivot)**: `project.godot [display]` is now `viewport 1080×1080` (SQUARE base — required so `canvas_items`+`expand` scales portrait AND landscape without bias), `stretch canvas_items/expand`, `handheld/orientation=6` (SENSOR — both orientations), `viewport_min_width=320`. **`ResponsiveManager` is the single source of truth** and classifies breakpoints by **density-independent physical size** (`window_get_size()/screen_get_scale()`), NOT `get_visible_rect()` — because with the square base, portrait content is always ~1080 wide and can't distinguish a phone from a tablet. Screens consult `get_effective_columns()`/`should_collapse_to_single_column()` and react to the **`layout_class_changed`** signal (fires on rotation, which `breakpoint_changed` misses). Multi-pane screens use `AdaptivePanelGroup`. A `_ready()` override on a `CampaignScreenBase`/`BaseCampaignPanel` subclass MUST call `super._ready()` or it loses all responsive wiring. **Full SOP: `docs/sop/responsive-adaptive-ui.md`.**
- **`Assets/BookImages/` is gitignored**: capital-A directory is excluded as "large art assets." On Windows (case-insensitive FS), edits to `assets/BookImages/` (lowercase) match the same files locally but git treats them as ignored. Bulk import-config edits won't show in `git status`. Plan accordingly when changing texture compression for those files.
- **Lazy-init autoload pattern (Session 59)**: `ReviewManager.gd` defers `_ready()` work to first public access via `_ensure_platform_initialized()`. (`GalacticWarManager.gd` shared this pattern and was DELETED Jul 29 2026 — fabricated 'war track' content, see the Galactic War note below.) When extending: any new public method must call the guard first; any `load_save_data()` MUST set `_initialized = true` BEFORE applying data so lazy-init can't overwrite restored state.
- **`ScalableVectorShape2D` draws its body on the rotated `offset`, not `position` (May 17, BUG-101)**: the addon centers the ellipse/shape at local origin then translates by `offset`, and `offset` is rotated by the node rotation. On-screen center = `position + offset.rotated(rotation)`, NOT `position`. To place a shape's DRAWN center at point `c`: `svs.position = c - svs.offset.rotated(svs.rotation)`. Any grid/sector clamp must clamp the DRAWN center (+ `stroke_width/2` envelope) then back-solve position. This caused TWO premature BUG-101 "verified"s — verify SVS placement empirically via `get_bounding_rect()`×`transform` vs the target rect. See `BattlefieldMapView._rebuild_terrain_shapes()`.
- **`BattlefieldMapView.cell_size` is the STABLE placement base (24), NEVER mutate it (May 17, BUG-102)**: on-screen scaling is the `_terrain_container` display transform via `_get_effective_cell_size()`, not a `cell_size` setter. `BattlefieldGridPanel._update_map_cell_size()` formerly mutated it 16/24→48 on resize after placement baked → top-left cluster. The resize handler is neutered; do not reintroduce any `cell_size` write.
- **Detached `.new()` nodes can't call tree-dependent methods, even `get_node_or_null("/root/X")` (May 17)**: a bare `PostBattlePhase.new()` (or any Node) not added to the scene tree errors "Can't use get_node() with absolute paths from outside the active scene tree" when a method internally resolves autoloads. In unit tests, either `add_child()` it first or don't invoke orchestration methods — a field-contract assertion should not run the full orchestrator.
- **Full-screen overlays MUST extend CanvasLayer, not Control (May 22, NarrativeScreen)**: a `Control` added to root renders BEHIND MainMenu's CanvasLayers (L80 PersistentResourceBar, L90 NotificationManager). For full-screen takeover, `extends CanvasLayer` with `layer = 95` (between chrome and TransitionManager L100), then wrap your UI tree in a child `Control` at `PRESET_FULL_RECT`. The first MCP verification screenshot for NarrativeScreen showed MainMenu because the overlay was a Control. See `src/ui/screens/narrative/NarrativeScreen.gd` for the canonical pattern.
- **Optional asset paths from registries must be ResourceLoader.exists()-guarded (May 22, NarrativeScreen)**: `SpeciesPortraitRegistry.DEFAULT_PORTRAIT` returns `res://assets/portraits/default.png` which doesn't ship. Calling `load(path)` directly on a missing res:// path crashes with "Resource file not found". Always `if ResourceLoader.exists(path): load(path)` before consuming a registry-provided path; let the colored-initials / gradient fallback handle the miss. Pattern in `NarrativeScreen._apply_advisor_portrait()`.
- **`_exit_tree()` not `tree_exited` for autoload access on cleanup (May 22, NarrativeScreen)**: `tree_exited` fires AFTER the node detaches; absolute-path lookups like `get_node_or_null("/root/PersistentResourceBar")` fail at that point with the same "Can't use get_node() with absolute paths from outside the active scene tree" error. Override `_exit_tree()` instead — it fires WHILE the node is still in the tree, so autoload access works. Restore chrome (resource bars, notification manager visibility) from `_exit_tree()`.
- **`get_visible_rect()` cannot detect device portrait — use ResponsiveManager (Jun 24, SYSTEMIC)**: under the square 1080 `canvas_items`+`expand` base, `get_viewport().get_visible_rect().size` returns the VIRTUAL base size (~1080² per Godot 4.6 `Window.content_scale_size`), NOT physical pixels, so `y > x` is ~always false. Portrait/orientation/breakpoint logic MUST use `ResponsiveManager.should_collapse_to_single_column()`/`is_portrait()` (physical via `DisplayServer.window_get_size()/screen_get_scale()`). Found+fixed in 3 places: `MainMenu._on_viewport_resized` (Jun 23), `BaseCampaignPanel.should_use_single_column()` (L474), `CampaignScreenBase.should_use_single_column()` (L383) — the last two silently defeated correct per-panel stacking. Anti-regression: `grep -rn get_visible_rect src/ui` should only find pan/zoom math, never orientation logic. See `docs/sop/responsive-adaptive-ui.md` gotcha #7.
- **Character bg/class/origin/motivation are validated STRING props — setting INT enum ids silently defaults (Jun 24)**: `Character.background`/`character_class`/`origin`/`motivation` are `@export var ...: String` with validating setters (defaults COLONIST/BASELINE/HUMAN/SURVIVAL). Setting an int makes the setter convert via `GlobalEnums.to_string_value()` resolved from the autoload NODE — which FAILS from a detached `Character` Resource (`.new()`, not in tree) and falls to the default. So `char.character_class = 9` silently becomes "BASELINE". Convert int→string at the CALLER (Node context) and pass the string. Was in BOTH `CharacterCreator._on_*_changed` (dropdown) AND `_on_randomize_pressed` (the path crew use) → captain + all crew were BASELINE/COLONIST.
- **2-arg `Dictionary.get(key, default)` silently ABORTS on a Resource (Jun 24, class-(b))**: `Object.get()` takes ONE arg, so the 2-arg form is an invalid call that unwinds the function (app survives, feature silently does nothing). A FRESH campaign holds Character Resources in `crew_data["members"]` (the finalization transform passed them through), so `CrewTaskComponent`'s `crew_member.get("character_name", "...")` aborted → empty crew list → World Phase Step 2 soft-lock. NEW-CAMPAIGN-ONLY (loaded saves are dicts). Crew members are canonically Dictionaries; normalize at the boundary via `to_dictionary()`. The turn system already handles dicts (loaded saves prove it).

---

## Agent Verification Protocol

### 🛑 RULE 0 — Before ANY plan, design, routing decision, or structural claim: READ THE ACTUAL CODE **AND SCENES** (MANDATORY, NON-NEGOTIABLE)

**This applies to EVERY agent, EVERY skill, and EVERY session. No exceptions. It overrides any "models are reliable, trust by default" posture below.**

You may NOT propose a plan, design, edit, routing decision, or factual claim about how something works until you have opened and read the ACTUAL files involved: the `.gd` scripts **AND** the `.tscn`/`.tres` scene/resource files. A plan built on assumption, memory, a docblock, or another agent's relayed summary is **INVALID** — no matter how confident the source seemed.

- **Memory, CLAUDE.md docblocks, SOPs, and sub-agent summaries are LEADS TO VERIFY, never facts.** They go stale. Open the file and confirm before relying on it. "The memory said so / the agent said so / the docblock said so" is NOT verification.
- **Every reference to a node, signal, property, scene tree, `@onready` var, container, or function MUST be confirmed by reading the source** — the `.tscn` (node tree, node types, `unique_name_in_owner`, anchors/containers) for layout/UI, AND the `.gd` (the real `@onready`/`func`/`signal`). Cite `file:line`. If your plan names a node you have not seen in the actual `.tscn`, you have not done the work.
- **UI / layout / responsive work: reading the `.gd` is NOT enough — OPEN THE `.tscn`.** Layout, container types, anchors, and node hierarchy live in the scene file. A UI plan that never opened the scene is incomplete and must be rejected.
- **The `.tscn`/`.tres` wiring is the authority on what is actually INSTANTIATED and LIVE** — `[ext_resource]` scripts, instanced/embedded sub-scenes, `unique_name_in_owner`, autoload registration. A `.gd` can look dead but be wired into a scene (live), or look live but be orphaned (dead). Never judge liveness or structure from the script alone — confirm it in the scene.
- A sub-agent that returns structural claims must have read the files; the calling agent must spot-check the load-bearing ones against the real files before turning them into a plan.
- If you cannot open a file, SAY SO and stop — do not guess.

A plan/design is acceptable ONLY if every structural claim in it traces to a file you actually read. This rule exists because plans were repeatedly built on unverified, relayed, or stale assumptions about scene + code structure, wasting the user's time. **Full code-and-scene due diligence is the floor, not extra effort.**

### Always verify (high-stakes)

- **Game-data values**: before acting on any stat, cost, range, probability, table boundary, weapon property, or species trait, confirm it against source-of-truth — `data/RulesReference/*.json`, then the Core Rules / Compendium PDFs (`docs/rules/`), or the relevant gamemode rulebook extract. This is a source-of-truth rule, not a model-trust one (see "Data Integrity Rules"). Never invent a game value.
- **Routing targets** (project-manager only): before delegating downstream work, confirm the target file/API exists (read it or confirm the path). A bad route cascades across the multi-agent flow.

### Good practice (still worth doing)

- **Prompt specifically**: exact function/class names over vague descriptions (`EquipmentManager.get_sell_value()`, not "equipment pricing"); include directory hints; request structured `path:line` output.
- **"Stub / empty / missing" claims**: a single Read confirms it before you assert — no redundant passes.

### Model tiers reflect cost/latency, not trust

Route by task difficulty — Opus for cross-system or verification-critical work (project-manager, battle-systems, qa-specialist), Sonnet for well-scoped single-domain work. Do not pick a tier based on "which model can I rely on"; all current tiers are reliable for search and reading.

---

## Key Documentation

- `docs/RULES_WIRING_AUDIT_2026-08.md` — **✅ CLOSED Aug 7 2026: 0 open / 0 partial / 136 fixed / 1 corrected.** The record. `docs/RULES_WIRING_CLOSEOUT_PLAN.md` is the route that was taken (complete; kept for its method, not as a worklist). **Do not read 0 open as "the rules are done"** — it means every row someone WROTE DOWN has a call site and a test; eight auditors walked eight subsystems, nobody walked every page of both books
- `docs/DOCUMENTATION_INDEX.md` — Master documentation hub (all docs indexed here)
- `docs/PROJECT_STATUS_2026.md` — Current project status
- `docs/GAME_MECHANICS_IMPLEMENTATION_MAP.md` — 100% compliance tracker (170/170)
- `tests/TESTING_GUIDE.md` — Test methodology (needs update for 4.6)

### Standard Operating Procedures (`docs/sop/`)

Institutional knowledge. **Read the relevant SOP before touching its subsystem; update the SOP in the same commit as the code change that justifies the update.** When SOPs disagree with code, the code wins — but investigate the divergence (update SOP if code is correct; fix code if SOP is correct; never silently delete a rule because current code violates it).

| Doc | Read when |
|-----|-----------|
| `docs/sop/README.md` | SOP index + anti-regressions log (specific traps + the rule that prevents each) |
| `docs/sop/asset-pipeline.md` | Before touching `assets/`, `data/scenes/`, or running any extraction script |
| `docs/sop/narrative-scene-authoring.md` | Before authoring/editing a `data/scenes/<id>.json`, exporting scene art layers, wiring crew figures into a scene, or tuning ambient motion (SceneStage manifest schema, full-canvas layer contract, character slots, ambient "living painting" motion) |
| `docs/sop/visual-runtime-verification.md` | Before merging any change that affects rendering (portraits, scenes, animations, motion, UI textures). Includes the motion transform-probe + full-overlay capture harness |
| `docs/sop/component-patterns.md` | Before writing any new `.gd` component or data file (SSOT accessor, JSON+static loader, path-loaded preload, export-safe `load()`, deferred initial swap) |
| `docs/sop/ornament-panel-pattern.md` | Before writing new rulebook-styled callout panels (rounded chrome + colored stroke + corner brackets via 9-slice atlas). Procedural bracket generator, compact/standard atlas variants, decision matrix vs CalloutCard/BookFrame |
| `docs/sop/cross-mode-transfer.md` | Before adding/editing a character-transfer leg between gamemodes (5PFH/Bug Hunt/Planetfall/Tactics), the `user://transfers/` file-drop envelope, the lossless snapshot, the reward-suppression rule, or the mode-generic dashboard pickup. Canonical-hub + file-drop + snapshot pattern |
| `docs/sop/responsive-adaptive-ui.md` | Before touching `ResponsiveManager`, adding a screen that must adapt to size/orientation (mobile/tablet/desktop), building a multi-pane screen (`AdaptivePanelGroup`), or changing `project.godot [display]`. DPI-aware breakpoints, `layout_class_changed` rotation signal, `get_effective_columns()`, base-class convergence, the square-base/portrait gotchas |
| `docs/sop/sheet-export.md` | Before touching the printable sheets — `SheetRenderer`, `SheetDataContext`, `PdfExportRouter`, `PrintSheetScreen`, or any `data/sheets/**/*_fields.json`. Field-coordinate manifests, the CV extractor's known blind spots, the invisible searchable text layer, the two PDF backends, and the Appendix X caption audit |
| `docs/sop/android-runtime-testing.md` | Before any responsive-UI merge (tier 1 minimum) or before distributing any Android APK (tier 2 required). Deploy routes, adb/logcat, remote-debugger profiling, performance thresholds |
| `docs/sop/decision-log.md` | When tempted to second-guess a pattern, or before proposing to replace one. Append-only — supersede with new entries, never delete |

**Rule for adding an SOP**: only document a pattern after you've used it *twice*. First time is experiment, second time is pattern, third is when you wish you'd written it down. Document at the second.

### QA Documentation Suite (Mar 2026)

| Document | Purpose |
|----------|---------|
| `docs/QA_STATUS_DASHBOARD.md` | Consolidated QA health — open bugs, coverage %, risk areas, next priorities |
| `docs/QA_RULES_ACCURACY_AUDIT.md` | Master data verification (925 values, 131 files) |
| `docs/testing/QA_INTEGRATION_SCENARIOS.md` | 10 end-to-end workflow scripts with MCP command templates |
| `docs/testing/QA_UX_UI_TEST_PLAN.md` | Systematic theme/responsive/animation/accessibility coverage |

Historical QA docs (sprint results, test plans, verification reports) archived in `docs/archive/qa-historical/`.

Update the dashboard after each QA sprint.

---

# Compact instructions

When compacting this conversation, preserve in priority order:

1. **Verified facts with citations** — anything confirmed against a rulebook PDF, `data/RulesReference/`, or a `file:line` read. Keep the citation, not just the claim. A fact without its source becomes a lead again.
2. **The current task's file list and what changed in each** — paths and the specific edit, not a summary of intent.
3. **Contradictions found but not yet resolved** — where two sources disagree and which one the book/code backed. These are the most expensive things to rediscover.
4. **Failing tests, lint findings, and runtime errors verbatim**, including the exact command that produced them.
5. **Decisions the user made** and the reason, especially where they overrode a recommendation.

Drop freely: file contents already written to disk, tool output that was superseded, exploratory searches that found nothing, and any narrative recap of steps that are already reflected in the working tree.
