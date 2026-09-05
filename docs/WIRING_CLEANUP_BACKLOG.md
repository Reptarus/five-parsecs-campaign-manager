# Wiring / Dead-Code Cleanup Backlog

> ## ▶ RESUME STATE (2026-08-06 — battle-phase delivery audit)
>
> - **All four wiring lints CLEAN (exit 0)**: `signal_wiring`, `tscn_connections`,
>   `autoload_lookups`, `data_ownership`. `lint_orphan_assets` reports
>   **`orphans=0`**.
> - **2 orphans deleted**: `src/core/battle/BattlefieldManager.gd` (431 lines —
>   density-float terrain across desert/urban/forest/space_station themes, which
>   CONTRADICTS the live four-book-theme `FPCM_BattlefieldGenerator`; its consumers
>   were already removed in the Battle Companion QA sprint, only the file was left)
>   and `src/core/enemy/base/Enemy.gd` (366 lines, `extends CharacterBody2D` —
>   real-time physics in a turn-based companion; sole reference was a preload of
>   itself).
> - **`lint_data_ownership` was reporting a real p.65 rules bug, not a style nit.**
>   `TravelEventResolver` was the ONE story-point award site bypassing
>   `GameStateManager`, where the Insanity gate lives — so Insanity campaigns
>   earned story points from pp.70-72 travel events and nowhere else. A second
>   finding (`CampaignEventEffects._grant_credits`) had its ownership order
>   inverted, so the manager's mirror and `credits_changed` signal never fired on a
>   p.126 grant. Fixed `dbc33c70a`.
> - **⚠ This doc was RIGHT and CLAUDE.md was wrong** about the P1
>   `get_deployable_crew` work below. CLAUDE.md claimed the deployment gate was
>   UNENFORCED because that function has zero callers. It does — but it is a
>   wrapper around `filter_deployable()`, which is live at four battle-path call
>   sites. CLAUDE.md is corrected. **When two docs disagree, the one describing a
>   commit usually beats the one describing a grep.**
> - **PRODUCTION-DEAD is now 41 files** (was 39). Still NOT deleted, still a
>   product decision — see tier 7. `lint_orphan_assets` exits 1 on this category
>   alone, so a red exit no longer means "orphans exist".
>
> ## ▶ RESUME STATE (last updated 2026-07-30 — reachability sweep)
> - **236 orphan files DELETED** (scripts + scenes, unreachable from product AND
>   tests). Found by the new `scripts/lint_orphan_assets.py`, which walks the real
>   reference graph from real entry points instead of grepping. It now exits with
>   `orphans=0` at fixpoint.
> - **Why the earlier grep-based passes under-counted:** a DEAD scene keeps its
>   script alive. `MainCampaignScene.tscn` was referenced by nothing at all, yet
>   its `ext_resource` made `MainCampaignScene.gd` look live. Script-pass and
>   scene-pass have to converge, which the graph does in one shot.
> - **⚠ CORRECTION to tier-1 below:** this doc previously recorded
>   `combat/{SimpleUnitCard,TerrainOverlay,TerrainTooltip}` as **"KEPT — LIVE"**.
>   That was wrong. All three had **zero** word-boundary references in `src/`, and
>   all three are now deleted. A manual liveness judgement recorded as fact is
>   exactly what the lint exists to replace.
> - **39 files are PRODUCTION-DEAD but test-referenced** — triaged below, NOT
>   deleted. Several are finished features that were never wired into a screen;
>   deleting them would throw away work, and wiring them is a product decision.
> - **CLAUDE.md's widget table is stale**: `BookFrame`, `OrnamentPanel`,
>   `ContactMarkerPanel`, `InlineRenameWidget`, `DiceFeed` and
>   `AttackResolutionOverlay` are all documented as live components but are
>   referenced only from their own files (or tests).
>
> ## ▶ RESUME STATE (2026-07-10)
> - **Branch `master`, working tree CLEAN.** BOTH the 6-tier cleanup AND the follow-on Book-Rule
>   Wiring Sprint are COMPLETE and committed. Cleanup: `5d38d039`→`65209733`. Wiring sprint:
>   `2df0949a` (P1), `c1c02a31` (P2), `3ee5f2d5` (P3). Nothing uncommitted.
> - **Lint counts: ALL 4 CLEAN ✅** — signal-wiring 0 · tscn 0 · autoload 0 · data-ownership 0.
>   Full suite: **151 suites / 1695 cases / 0 failures** (deterministic).
> - **DONE — cleanup (all 6 tiers) THEN the wiring sprint that used the clean slate:**
>   - **P1** (`2df0949a`): `get_deployable_crew` filter now excludes DEAD/MISSING/RETIRED + Sick-Bay/
>     recovering + departed/skip_next_battle, wired into both deploy sites; `current_mission` battle-handoff
>     bug fixed (progress_data live channel); PatronRivalManager patron-panel str()-hardened.
>   - **P2** (`c1c02a31`): Unity Agent "Call in a Favor" (p.20) — 3 backend methods + favor UI.
>   - **P3** (`3ee5f2d5`): Krag armor 2cr-modify gate in AssignEquipmentComponent; consumable-use
>     (companion effect-text + depletion) with a battle ActionBar button; 3 pre-existing flaky loot tests fixed.
> - **NEXT — no tracked cleanup or book-rule-wiring items remain.** All Blocked paths unblocked, all
>   flagged gaps wired, all lints clean. Future work is net-new features / whatever the user prioritizes.
>   The 3 permanent lints (`scripts/lint_*.py`) remain the going-forward guard against wiring rot.
> - **KEY GOTCHAS:** `/root/DiceSystem` is a MockDiceSystem TEST SEAM (already
>   `# lint:ignore`), NOT dead — grep `tests/` before "fixing" any `/root/Name`.
>   Producer battle-result keys are TEST-PINNED — never rename. `.uid` siblings
>   auto-generate; delete them WITH their `.gd`/`.tscn`, never hand-create.
> - **AFTER clean slate:** unblock the 2 paths (bottom of this doc): `get_deployable_crew`
>   deployment filter + Unity Agent favor-resolution UI.
> - Memory: `project_session_jul10_wiring_audit_sprint`, `reference_battle_result_normalizer_contract`,
>   `reference_autoload_lookup_test_seam`. Plan/ledger:
>   `C:\Users\admin\.claude\plans\commit-and-start-investigating-delightful-bentley.md`.

**Goal:** the cleanest possible codebase — remove ALL dead code across every aspect,
reach a clean slate, THEN unblock the two Blocked book-rule paths.

**Established:** 2026-07-10 (wiring-audit sprint). This is the tracked worklist the
three lints produce. Re-run counts any time:

```powershell
py scripts/lint_signal_wiring.py       # declared-never-emitted signals
py scripts/lint_tscn_connections.py    # .tscn [connection] -> missing method
py scripts/lint_autoload_lookups.py    # /root/Name not an autoload
py scripts/lint_data_ownership.py      # data-ownership violations (should stay clean)
```

**Deletion protocol (run per item BEFORE deleting):** grep ALL of `\.name\(`,
`has_method("name")`, `call\w*\(\s*["']name`, `Callable\(.*name`, `method="name"`
in `**/*.tscn`, the `signal_variants` arrays in `SignalConnectionManager.gd`, and
`tests/`. ANY hit → keep + record why. For a `/root/Name` lookup, ALSO grep
`tests/` for a mock injection (test seam — see the DiceSystem lesson).

**ALSO GREP THE UID (added 2026-09-04).** `uid://` is a SECOND reference form: Godot's
ResourceUID exists so references survive a rename or move, so a `.tscn` can point at a
script by UID with its path nowhere in the file — and this repo has **106 `uid://`
references** in `src/` scenes. Read each candidate's UID out of its `.uid` sibling and
grep THAT across `src/`, `tests/` and `project.godot` as well. A path-only grep can come
back clean while a live scene still resolves the file. (The Sep 4 sweep ran this check:
0 hits across all 39 — but it was not part of the protocol before.)

Delete the `.uid` sibling with every `.gd`/`.tscn`. Every wave: headless compile + the suites green before commit. ⚠ The single-process
FULL run SEGFAULTS at ~58 suites (proven pre-existing in a throwaway worktree at HEAD),
so run `tests/unit` in batches of **≤38** and `tests/integration` (34 suites) in one go.

Definition of done for the "clean slate": all four lints exit 0 (or every residual
carries a justified `# lint:ignore` / allowlist entry), and the zero-caller +
temp_data lists below are emptied.

---

## Priority tier 1 — the 5 "live" signal dead-wires (INVESTIGATED — all dead scaffolds, DELETE)

Investigation 2026-07-10: none are live bugs to WIRE. Every listener is a stub or
its owning component is orphaned. All resolve to DELETE (clean-slate direction).

- `rival_escalated` — **DONE (deleted this session).** RivalBattleGenerator is live
  and its escalation MECHANIC is used, but the notification was unimplemented: signal
  never emitted + `CampaignTurnController._on_backend_rival_escalated` was a `pass`
  stub. Deleted signal + guarded connect + stub handler. (66 signals / 4 live remain.)
- `manual_override_applied`, `override_requested` — **DONE (deleted with the combat
  subsystem, this session).** The whole `src/ui/components/combat/{log,overrides,rules,state}/`
  UI subsystem (13 component pairs) was runtime-dead: no live `.tscn` embeds it, no
  `class_name` for indirect ref, the live combat log is `FPCM_UnifiedBattleLog` (which
  "Replaces BattleJournal + FallbackLog"). Deleted the 4 subdirs + the 2 test suites that
  pinned the dead code (`test_combat_log_explanations`, `test_validation_panel`).
  **KEPT:** `BaseCombatManager`/`FiveParsecsCombatManager` (LIVE — used by FiveParsecsCombatSystem/
  AIController/EnemyTacticalAI) and the top-level `combat/{SimpleUnitCard,TerrainOverlay,TerrainTooltip}`.
  > **⚠ 2026-07-30 CORRECTION — this "KEPT" line was WRONG.** All three of
  > `SimpleUnitCard` / `TerrainOverlay` / `TerrainTooltip` had **zero** word-boundary
  > references anywhere in `src/`, and `FiveParsecsCombatSystem` was itself an orphan,
  > so the "LIVE — used by FiveParsecsCombatSystem" chain was dead at both ends. All
  > deleted in the tier-7 reachability sweep. See tier 7.
- `tactical_advantage_changed` — `BaseBattlefieldManager.gd:12`. **Still open (Tier 4).**
  Declared in the LIVE `BaseBattlefieldManager` base class (NOT the deleted subsystem) with
  1 remaining listener elsewhere, never emitted. Verify BaseBattlefieldManager liveness +
  find the listener before deleting.

## Priority tier 2 — dead scenes / load-time errors — DONE ✅ (`lint_tscn_connections.py` exits 0)

- **Legacy TravelPhaseUI** — **DONE (deleted this session).** Confirmed dead 3 ways: its
  live script `campaign/TravelPhase.gd` had NONE of the 6 `_on_*` handlers nor `phase_completed`
  (so the .tscn connections + CTC's `has_signal` guard could never fire); instanced in CTC but
  only ever `.hide()`d, never shown (unified World Phase superseded it); the SceneRouter
  `"travel_phase"` key was reachable only via a debug-only `navigate_to_campaign_phase("travel")`
  and the zero-caller `get_scenes_by_category` arrays. DELETED: `travel/TravelPhaseUI.tscn` +
  `travel/TravelPhaseUI.gd` (class_name TravelPhaseUI, no type-users) + `campaign/TravelPhase.gd`
  (wrong-script, attached to no other scene) + their `.uid`s; removed CTC.gd wiring
  (`@onready`/assert/connect/disconnect/`.hide()`), the CTC.tscn instance node + ext_resource,
  and the SceneRouter key + 2 array entries + the `"travel"` alias. **Left as a Tier-5 orphan:**
  `CampaignTurnController._on_travel_phase_completed` (now zero-caller; `has_method`-guarded in
  `test_ui_backend_bridge.gd`, so harmless).
- **Bare `/root/...` `get_node`** — **DONE.** All resolved by Tier 3 + the combat-subsystem
  deletion (`combat_log_controller`/`state_verification_controller` gone with the subsystem;
  ResponsiveContainer/BattlefieldMain/TacticalBattleUI bare lookups removed in Tier 3).
  `lint_autoload_lookups.py` now exits 0.

## Priority tier 3 — dead autoload lookups — DONE ✅ (`lint_autoload_lookups.py` exits 0)

Resolved 2026-07-10. 31 of 35 removed in the Tier 3 commit; the final 4
(`/root/CombatManager` in `combat/{log,rules,state}/`) died with the combat-subsystem
deletion. `lint_autoload_lookups.py` now CLEAN (0 findings).

Dispositions applied:
- **Dead guarded branches removed (kept the live fallback that followed):**
  `FPCM_AlphaGameManager` (TravelPhase, TacticalBattleUI, BattlefieldMain, MissionSelectionUI —
  the phantom autoload that was never registered), `PatronSystem` (WorldPhase → inline
  patron-job generation), `CampaignManager` (DeveloperQuickStart health-check list entry,
  MainCampaignScene fallback, CampaignPhasePanel, EquipmentManager screen ×2 → hardcoded
  fallbacks; the legacy CampaignManager autoload was deleted Jul 2), `CharacterManagerAutoload`
  (MainCampaignScene), `CampaignCreationUI` (MainCampaignScene search-path entry,
  BaseCampaignPanel `get_coordinator_reference` Method 2 — other methods cover it),
  `UIManager` (ResponsiveContainer — deleted the zero-caller `register_with_ui_manager`),
  `DataManagerAutoload` + `BattleTracker` + `FiveParsecsCombatSystem` (TacticalBattleUI/
  EquipmentManager — the reaction-dice-via-autoload integration was never built),
  `OptimizedSystemsAutoload` (GameDataLoader), `PostBattlePhase` (PostBattleSequence dead
  alternative — the live path is the already-fixed `get_phase_handler("post_battle")`;
  CampaignEventComponent/CharacterEventComponent collapsed to the `find_child` fallback),
  `CampaignCreationStateBridge` (EquipmentGenerationScene → always standalone mode).
- **Dead vars removed:** TacticalBattleUI `alpha_manager` + `battle_tracker` (assigned, never read).
- **Orphan file DELETED:** `src/core/managers/AlphaGameManager.gd` (+.uid) — `extends Node`,
  no `class_name`, zero path/class/dynamic refs; the manager the phantom `FPCM_AlphaGameManager`
  autoload was meant to be. Removed its internal `/root/BattleManager` finding too.
- **Allowlisted (`# lint:ignore`, honest):** `/root/PersistentResourceBar` (NarrativeScreen ×2).
  It's a real, documented L80 chrome component (`src/ui/components/common/PersistentResourceBar.gd`)
  but is **not instantiated by any screen** — so it fails the allowlist's "actually created"
  evidence bar; the null-guarded restore hooks no-op safely. **FEATURE-BACKLOG:** either wire
  PersistentResourceBar into campaign screens or delete the orphan component + its hooks.

## Priority tier 4 — dead signals — DONE ✅ (`lint_signal_wiring.py` exits 0)

Resolved 2026-07-10. All 64 removed. Method: a batch verifier
(`scratchpad/verify_dead_signals.py`) confirmed 63 of them had ZERO non-declaration
references anywhere (no emit / connect / has_signal / `.tscn [connection]` /
SignalConnectionManager variants); the 3 apparent "other refs" were all name-collisions
(a dict key `result["character_died"]`, an analytics event string `"validation_error"`,
and an `add_user_signal` on a *different* stub node for `campaign_progress_updated`) —
none referenced the dead declarations. Removed the 63 decls via a self-auditing script
driven off the lint's own output (auto-skipped the LIVE-DEAD-WIRE tag). Then the 1 LIVE
DEAD-WIRE — `tactical_advantage_changed` (BaseBattlefieldManager) — was DELETED at all 3
ends (decl + the `UnifiedAISystem._ready()` connect + the `_on_tactical_advantage_changed`
handler): it was never emitted AND mis-wired (signal `(unit,int,float)` vs handler
`(Vector2,float)` — would have errored if it ever fired). **ALL 4 LINTS NOW CLEAN.**

## Priority tier 5 — zero-caller public methods — DONE ✅

Resolved 2026-07-10. **METHODOLOGY FIX (reusable):** the first detector matched only
`\.NAME(` and gave **13 false positives** — it missed GDScript bareword calls (`NAME()`
no dot) and dynamic dispatch. Corrected detector: `\bNAME\s*\(` (any call form) +
`(has_method|call|call_deferred)\(["']NAME["']`, excluding the `func NAME(` def line;
name-collisions err toward KEEP. 42 initial candidates → 23 true-redundant deletions.

- **DELETED 23** (each redundant — mechanic live via another path): EquipmentManager (7)
  `apply_gun_mod` (→ weapon traits), `repair_equipment`, 3 onboard getters (→ `get_onboard_item_effect`),
  `get_equipment_by_category`, `remove_equipment_from_character` (→ `EquipmentTransferService`);
  GameStateManager (7) `set_difficulty`/`set_language`/`set_tutorials_enabled` (→ `SettingsManager.set_setting`),
  `get`/`set_campaign_phase`, `get_supplies`, `get_narrative_wrap_override`;
  CampaignPhaseManager (8) story/intro wrappers (bypassed by direct `story_track`/`intro_state`
  access) + `advance_campaign`/`get_campaign_results`/`validate_current_campaign`;
  CampaignTurnController (1) `_on_travel_phase_completed` (Tier-2 orphan, has_method-guarded test).
- **CASCADE:** deleting `set_campaign_phase`/`set_difficulty` orphaned their sole-emitted signals
  `campaign_phase_changed` + `difficulty_changed` (0 listeners) → also DELETED. (A stale
  self-mapping string `"campaign_phase_changed"` remains in `FiveParsecsConstants` event-name
  registry — harmless, not lint-flagged, left to avoid touching that shared file.)
- **The `EquipmentManager` `create_weapon_item`/`create_armor_item`/`create_gear_item` and the
  CampaignPhaseManager `complete_current_turn`/`start_sub_phase`/`reset_phase_tracking` etc. that
  the OLD list called zero-caller are NOT — they have bareword callers. Kept.**

## Discovered unwired book-mechanic gaps — WIRED ✅ (Book-Rule Wiring Sprint, 2026-07-10)

The Tier-5 flagged gaps were WIRED in the follow-on Book-Rule Wiring Sprint (Phase 3, commit `3ee5f2d5`):
- **`use_consumable` → WIRED.** Book-scoped: this is a COMPANION not a simulator, so "use" shows the
  effect TEXT (already in `equipment_database.json`) + tracks depletion. Added
  `EquipmentManager.get_stash_consumables()` + `use_stash_consumable()` + a "💊 Consumable" button on
  the battle-companion ActionBar (Core Rules p.54, Free Action from the Stash). Test `test_consumable_use` 2/2.
- **`modify_armor_for_krag` + `set_armor_krag_designation` → WIRED.** Hardened `is_armor_item` (enum OR
  string type), gated `AssignEquipmentComponent`'s equip: a Krag equipping non-Krag armor is offered the
  2cr modification, else blocked (Compendium p.15). Test `test_krag_armor` 6/6.

## Priority tier 6 — dead temp_data writes — DONE ✅ (1 behavioral case flagged)

Resolved 2026-07-10. Verified each key's read sites (literal AND `TEMP_KEY_*` constant forms +
direct `temp_data[...]`) — all 6 target keys were written, never read. DELETED the dead writes:
`return_screen` (×2), `crew_add_mode` (×1), `world_phase_results` (×2 — incl. the whole dead
`if set_temp_data / elif progress_data` block; its only "read" `WorldPhaseSummary:51
"world_phase_results" in campaign` inspects the campaign OBJECT, not the stored copy),
`planetfall_mission` (×2, kept the live `_battle_result`/`_battle_context` siblings),
`bug_hunt_mission` (×2, same). Removed the now-unused `TEMP_KEY_CREW_ADD_MODE`/
`TEMP_KEY_RETURN_SCREEN` consts (kept `TEMP_KEY_SELECTED_CHARACTER` — live). **`pending_combat`
book-check DONE:** no rules data links travel events to a `pending_combat` handoff, and
`set_pending_combat` is zero-caller (writer TravelPhaseUI deleted in Tier 2) → deleted the method
(dead plumbing, not an implemented mechanic; a real travel→combat feature would be a fresh build).

**`current_mission` behavioral bug → FIXED ✅** (Book-Rule Wiring Sprint P1.2, commit `2df0949a`).
Confirmed a real functional bug: WorldPhaseController:1703 persisted the JOB_OFFERS mission "for Battle
Phase" via `set_current_mission`, which wrote ONLY the dead temp channel, while the battle reads it
(CTC:1499) via `get_current_mission` → `progress_data`. Repointed `set_current_mission` to
`campaign.progress_data["current_mission"]` (the live channel). MCP round-trip verified.

---

## Blocked paths — UNBLOCKED ✅ (Book-Rule Wiring Sprint, 2026-07-10)

Both Blocked paths were wired in the follow-on Book-Rule Wiring Sprint after the clean slate.

1. **`get_deployable_crew` deployment filter → DONE** (P1.1, commit `2df0949a`). The filter also
   didn't work as written — `status` only holds DEAD/MISSING/RETIRED ("DEPARTED" + `skip_next_battle`
   live in `status_effects`), and INJURED/Sick-Bay crew weren't excluded at all (Core Rules p.55: a
   Sick Bay character "cannot participate in battles"; p.76 they rejoin only at `recovery_turns == 0`).
   Now excludes DEAD/MISSING/RETIRED, Sick Bay/recovering, and departed/skip_next_battle effects;
   exposed `filter_deployable(crew)` as the single authority and routed the battle-deployment sites
   (PreBattleUI selection + CTC:1497 deploy) through a CTC `_deployable()` helper. Test 10/10; MCP-verified.
2. **Unity Agent "Call in a Favor" → DONE** (P2, commit `c1c02a31`). Implemented the 3 missing
   `GameStateManager` methods (`remove_random_rival`/`add_quest_rumor`/`add_patron` — `add_patron`
   produces a display-safe patron) and filled the empty `CampaignDashboard._on_phase_event` hook with
   the favor UI (ItemChoicePopup 3-choice on 10-12; travel-or-lose on 2-4 → `mark_unity_agent_trait_lost`).
   Book-verified p.20. Test `test_unity_agent_favor` 6/6; MCP-verified live resolution.

---

## Tier 7 — reachability sweep (2026-07-30)

Run `python scripts/lint_orphan_assets.py` (add `--list` to enumerate). It walks
the reference graph from real entry points — `project.godot` `run/main_scene` and
every `[autoload]`, plus a documented-standalone allowlist — and reports anything
unreachable. Edges: `res://` literals in `.gd`, `path=` in `.tscn`/`.tres`
ext_resources, and **word-bounded** `class_name` usage.

Word boundaries are not optional here: `CampaignManager` is a substring of
`CampaignPhaseManager`, and `MissionGenerator` of `StealthMissionGenerator` /
`TacticsMissionGenerator`. A substring scan reports both orphans as live. Same
trap as the `replace_all` rule in CLAUDE.md.

**Verified inputs before trusting the graph:** all 139 `Script` ext_resources in
the repo carry a `path=` (no uid-only refs to miss); `data/` JSON never names a
script or scene; and every dynamic `load()` takes a DATA path (texture, portrait,
pooled scene) — no script is loaded from a runtime-composed name. If any of those
stops holding, the lint goes stale and needs the new case added.

### Deleted: 236 files, `orphans=0` at fixpoint

Notable clusters: the `MainCampaignScene` script+scene pair (the case that proves
why one grep pass is not enough), `ui/screens/campaign/CampaignManager.gd`,
`core/victory/VictoryDescriptions.gd` (the documented "basic" duplicate),
duplicate-name corpses shadowing live autoloads (`core/managers/` and
`game/world/WorldEconomyManager.gd`, `game/world/PlanetCache.gd`), the
`WeaponSystem`→`GearDatabase` chain (`GearDatabase` could not even compile — its
`preload` targeted a `GameEnums.gd` path that does not exist), 4 never-wired
mission classes, and `combat/{SimpleUnitCard,TerrainOverlay,TerrainTooltip}`
(previously mis-recorded in tier 1 as KEPT/LIVE).

Also removed as unreachable-and-broken: the `"main_game"` route (target scene
absent from the repo) and `"new_campaign_tutorial"` + its scene, whose node names
did not match the shared script's `@onready` paths, so none of its buttons had a
handler. See `e33d3294`.

### ✅ CLOSED 2026-09-04 — all 39 production-dead files deleted (`test_only` 39 → 0)

`lint_orphan_assets.py` now reports `files=557 reachable_from_product=556 test_only=0
orphans=0 unwired_rules=1` and **exits 0 for the first time**. The one remaining entry
is `src/data/tactics/TacticsOperationalMap.gd`, which is a book chapter with no caller
(Tactics pp.92-100), not an orphan.

**What went:** 11,349 lines / 364 KB across 39 files — battle scaffolds (`BattleResults`,
`BattleSetupData`, `BattlefieldTypes`, `FPCM_BattleManager`, `FPCM_BattleState`,
`PostBattleProcessor`), the Resource-based item model (`GameItem`, `GameGear`,
`GameArmor`, `GameWeapon`, `ConsolidatedArmor`) the app abandoned for Dictionaries,
mission/patron/rival generators, `EconomySystem` (842 lines, already disclaimed as dead
by `UpkeepSystem.gd:277-282`), `BaseCharacterResource` + `character_base`, the terrain
pair, `CampaignConfig`, `ShipData`/`ShipComponent`, `ContactManager`,
`RivalBattleGenerator`, and the deprecated `ResponsiveContainer` shim. Plus 3 fabricated
JSON tables whose only readers were deleted files, and 4 orphaned test fixtures with
zero callers anywhere.

**Every one was checked for a book chapter first, and none qualified.** Nine carried page
cites; all nine proved duplicate-or-fabricated. The two that looked unique were killed by
the PDF: `roll_background_event` cites p.14-15 for a d66 table (p.14 is Crew Type Tables,
p.15 is Human Characters; the book's Background/Motivation/Class tables are **D100 at
pp.24-27**) and grants "+1 to Leadership / Survival / Morale checks", none a Five Parsecs
stat; `calculate_enemy_count` is superseded by `EnemyGenerator.gd:589-658`.

**Test cost, and what was preserved.** 303 cases across 16 suites depended on them. Each
suite was classified PURE-DEAD (dies with the scaffold) or MIXED (also covers live code)
before anything was removed — that gate is what kept 21 live implant cases which the file
name hid inside `test_equipment_classes.gd`. Preserved into new homes:
`tests/unit/test_character_implants.gd` (21) and `tests/unit/test_dice_system_contexts.gd`
(1 — DiceSystem had no other suite anywhere). Trimmed in place: `test_ship_system` 47→8
(with a duck-typed stub, deliberately using `component_id` so it still exercises the third
branch of `Ship.get_component_by_id`), `test_generator_wiring` 24→10,
`test_edge_cases_negative` 12→3, `test_house_rules` 21→20 (repointed onto the live
`ExpandedConfigPanel.get_campaign_config_data()` chokepoint). `test_expanded_connections`
(22) was left untouched — its name invites confusion with the deleted
`CharacterConnections.gd` and it is a wholly live suite.

⚠ **Eleven of the removed cases asserted nothing at all** — 7 comment-only bodies in
`test_edge_cases_negative` plus 10-of-13 in `test_battle_ui_components` guarded on an
`event_bus` its own setup hard-sets to `null`. They reported PASS forever. Count asserting
cases, not cases.

⚠ **The deletions exposed 8 new permanently-false `has_method` guards**, each naming a
method defined only on a deleted class, each already falling through to the live branch.
All are allowlisted in `lint_dead_has_method_guards.py` with the reason; 8 stale entries
were dropped. A zero-caller `create_enhanced_character()` block (68 lines) in
`CharacterGeneration.gd` went with them.

---

## Campaign creation audit — deferred items (Aug 2 2026)

From the two-wave creation-wizard audit (73 findings, 47 CONFIRMED / 25
OVERSTATED / 1 REFUTED after adversarial verification). Everything below was
found and understood; it is listed here because it was deliberately NOT done,
each for a stated reason, rather than silently dropped.

**Needs a producer AND a consumer in one change** — landing half of these would
recreate the exact defect the audit existed to find:

- **p.72 Licensing Requirement.** `license_required` / `license_cost` appear in
  no live file, so the Freelancer License rule has never executed on any world in
  any campaign. Needs the world-generation roll *and* the Upkeep-side
  enforcement together.
- **Unique-kill and character-upgrade tallies.** `VictoryChecker` now reads
  `progress_data["unique_individuals_killed"]` and `["characters_upgraded_10"]`,
  and `GameStateManager` has the mutators
  (`increment_unique_individual_kills`, `record_character_upgrade_milestone`),
  but nothing CALLS them. The natural call sites are in
  `core/campaign/phases/post_battle/`, which was being edited by another session
  during this sprint. Five of the seventeen Victory Conditions sit at 0/N until
  this is wired — visible and honest, rather than resolving to "no victory
  condition set" as they used to.
- **Progressive Difficulty consumer.** The option now reaches and persists on the
  campaign, but `ProgressiveDifficultyTracker` is entirely static and nothing
  calls its statics. Wiring `get_enemy_count_bonus()` means threading the turn
  number and the campaign's options through `EnemyGenerator._calculate_enemy_count()`
  — a signature change across the enemy-generation path.

**Blocked on a data-model decision:**

- **Crew members-vs-total convention.** `crew["size"]` is the TOTAL (4/5/6) while
  the crew panel stores members EXCLUDING the captain, and
  `_merge_captain_into_crew` changes which is true depending on when you look.
  The strict `_validate_crew_phase()` compares the two directly, so it reports a
  legal campaign as short by one — observed live as "Final validation failed.
  Total errors: 2" on a perfectly valid campaign. This is why
  `get_validation_summary()["has_critical_errors"]` is hard-coded false and why
  `CampaignFinalizationService`'s business-logic layer was removed rather than
  repointed: both feed lists that BLOCK campaign creation. Reconcile the
  convention first, then give that key meaning.

**Approved scope-outs (user decision, hybrid option):**

- The 12 Compendium difficulty toggles: `_build_difficulty_toggles_section` is
  defined and never called, and no runtime system reads individual toggle ids.
  Each toggle is a full rule variant needing its own book verification.
- Runtime resolvers for `ELITE_ENEMIES`, `TERRAIN_GENERATION`,
  `GRID_BASED_MOVEMENT`, `DEPLOYMENT_VARIABLES`; their toggles should stay
  hidden for owned packs until the resolvers exist.

**Cosmetic / bloat, still open:**

- The equipment condition/quality system remains in the display layer and in
  `StartingEquipmentGenerator.apply_equipment_condition()`. Starting gear no
  longer rolls a condition (the mechanic is absent from Core Rules pp.28-29 —
  extracted and checked), but the badges and `quality_modifier` writes survive.
  Nothing reads `quality_modifier` for gameplay.
- `ShipPanel` resolves its traits container to `Traits/Container` where the scene
  node is `TraitsContainer`, then frees the section's own header label on every
  refresh.
- The Ship step's fallback branch invents a debt of 0-3 credits, matching no row
  of the p.31 Ship Table.
- `MainMenu._on_onboard_existing_pressed()` sets `temp_data("onboarding_mode")`
  and then calls `_start_new_campaign()`, whose first act is
  `clear_all_temp_data()` — so the flag is wiped before the wizard opens and the
  onboarding branch can never fire. Deferred only because `MainMenu.gd` was in
  another session's uncommitted set.

---

## `BattleJournal` — DELETED 2026-09-04

`src/ui/components/battle/BattleJournal.gd` (329 lines, `class_name
FPCM_BattleJournal`) + `.tscn` + both `.uid`s.

**Why it was a corpse and not a missing wire.** The distinction CLAUDE.md insists
on — *"before deleting a zero-caller provider, ask what used to call it"* — has a
clear answer here: the consumer was **migrated on purpose**, not lost.

- `UnifiedBattleLog.gd` says so in its own header: *"replaces BattleJournal"* and
  *"Exposes the same API as BattleJournal so all signal connections work."*
- `TacticalBattleUI.gd:214`: `var unified_log: FPCM_UnifiedBattleLog = null
  # Replaces BattleJournal + FallbackLog`, and TacticalBattleUI writes to it at
  **90** call sites.
- The Sep 3 sprint (Phase 7) removed the `battle_journal` scene-registry entry,
  which is what orphaned the files.
- Verified before deleting: **zero** instantiations — no `preload`, no `load`, no
  `.tscn` embed, and no reference to either UID (`uid://bq4h7m3rwk8ty` scene,
  `uid://upiu8b1fobau` script). Its own `.tscn` referenced only its own script.

`lint_orphan_assets.py` `orphans` is back to **0** (it was 2). Exit is still 1
because of `test_only=34`, the deliberate tier-7 backlog below — unchanged.

### What was NOT deleted, and why

**`BattleTierController.TIER_COMPONENTS` and its test suite stay.** The map is
inert — `get_enabled_components()` / `is_component_enabled()` have ZERO production
callers (`git log -S` finds each in exactly one commit, the one that introduced
it, so neither ever gained or lost a caller), and only
`test_battle_tier_controller_features.gd` reads them. The gating that actually
runs is `TacticalBattleUI._apply_tier_visibility()` — its own docblock says *"REAL
per-tier gating (was inert pre-redesign)"* — which works on **drawer toolbars**
rather than per-component node names, plus `_instance_assisted_components()` /
`_instance_oracle_components()` gating instantiation on `tier >= 1` / `tier >= 2`.

So the map records intended tier scaling that the redesign implemented a different
way. Deleting it would erase the design record, which is the trap `c8fd7e07c`
already fell into once. It now carries a docblock saying it is design data, and its
`&"BattleJournal"` key was renamed to `&"UnifiedBattleLog"` so it does not name a
deleted file. Counts are unchanged, so the suite's `is_equal(14)` assertions hold.

### Stale references cleaned up in the same pass

A note describing a deleted file sends the next reader looking for it, so every
surviving mention now says it is gone:

- `BattleKeywordDB.gd:7` ("Used by BattleJournal and CheatSheetPanel")
- `TacticalBattleUI.gd:2087, :6918` (comments naming it as the log target)
- `UnifiedBattleLog.gd` header (now states BattleJournal was deleted)
- `docs/technical/BATTLE_SYSTEM_ARCHITECTURE.md` (component table + signal hub)
- `docs/technical/BATTLE_HUD_SIGNAL_ARCHITECTURE.md` (component tree)
- `docs/technical/TACTICAL_BATTLE_UI_ARCHITECTURE.md`, `CODEBASE_OPTIMIZATION_AUDIT.md`
- `docs/testing/BATTLE_COMPANION_COVERAGE_MATRIX.md`, `BATTLE_UI_COMPONENT_AUDIT.md`
  (annotated, not rewritten — it is a historical snapshot, and it also had the path
  wrong: never `src/core/battle/`, always `src/ui/components/battle/`)
- `docs/QOL_FEATURE_CANDIDATES.md` (KeywordDB consumer list)
- **`docs/GAME_MECHANICS_IMPLEMENTATION_MAP.md`** carried a *"Needs Wiring"* entry
  and a gap row reading *"BattleJournal logging | Battles produce blank journal —
  logging methods never called"*. Both were stale: the replacement is written to at
  90 call sites. Row marked RESOLVED, wiring entry removed.

`docs/archive/**` left untouched — historical by definition.

---

## Sep 4 2026 — orphan sweep after fixing the lint that hid them

`lint_orphan_assets.py` computed reachability from RAW source, so a comment naming
a class counted as a reference. This repo's comments are unusually full of the
names of files they explain are DEAD, so dead files were kept alive by their own
obituaries. Fixed on both the src and tests sides; `orphans` went **0 → 11**.

**Deleted (10 files + .uid siblings)** — each verified unreachable from product AND
tests, and audited for rules held hostage:

| File | Why it was safe |
|---|---|
| `core/campaign/phases/WorldPhase.gd` | 3 public funcs: 2 re-homed, 1 unreferenced. Its last reference was an UNUSED `const WorldPhase = preload(...)` at `WorldPhaseController.gd:50`, now removed |
| `core/campaign/phases/TravelPhase.gd` | 10 public funcs: 2 re-homed, 7 unreferenced, 1 hostage (`attempt_forge_license`) — re-homed and FIXED first, see below |
| `core/managers/ResourceManager.gd` | 6 re-homed; zero references |
| `core/managers/ResourceTransaction.gd` | referenced only by ResourceManager; `EconomySystem` has its own inner class of the same name (a collision, not a reference) |
| `core/systems/IGameSystem.gd` | an interface; all 6 methods re-homed |
| `qol/BattleSetupWizard.gd` | QoL wrapper superseded by `BattleSimulatorSetup`; no book rules |
| `ui/components/common/OverflowMenu.gd` | pure UI widget, no rules; removed from the CLAUDE.md widget table |
| `ui/components/common/Tooltip.gd` | its ONLY reference was a self-`load()` at its own line 323 |
| `ui/screens/world/components/CampaignEventComponent.gd` | superseded — live path is `campaign_events.json` + `CampaignEventEffects.gd` (5 consumers) |
| `ui/screens/world/components/CharacterEventComponent.gd` | self-documented DEPRECATED, names its own replacement |
| `ui/screens/world/WorldPhaseAutomationController.gd` | this doc already book-checked it: invented "Digital Dice / object pooling" scaffolding |

**KEPT, and it is a finding, not an orphan:**
`src/data/tactics/TacticsOperationalMap.gd` — *"Source: Five Parsecs: Tactics
campaign rules pp.155-168"*, the whole operational layer (regions, zones, Army
Strength, Cohesion, Player Battle Points). NONE of its mechanics exist elsewhere
in `src/`. Deleting it deletes the chapter. Now tracked by the lint's new
`UNWIRED_RULES` set, which requires a page cite and warns once the entry becomes
reachable. **Wiring it is open work.**

**Rules bug found while re-homing:** the p.72 forged-licence attempt did not apply
the p.57 Fake ID **+1**. `OnboardItemService.license_bonus()` had one caller
(`InterdictionRule.gd:156`, the p.75 roll). Fixed inside
`NewWorldArrival.attempt_forged_licence()` so a caller cannot forget it again;
`JobOfferComponent` now shows the bonus in its breakdown.

⚠ **This doc's own full-suite gate is unrunnable.** Batching that many gdUnit4
suites in one process segfaults at ~58 suites, on unmodified HEAD (proven with a
throwaway worktree). Run `tests/unit` in batches of **≤40**: 7 batches,
**3,068 cases, 0 failures**.

---

## Sep 4 2026 — the D-tier verification sprint (7 fixes, all detection-proven)

Every row below was re-checked against the actual code, 21 real save files and
the PDFs rather than against this backlog. That retired 3 entries as already
fixed, corrected 1 plan assumption and 1 wrong page cite, and surfaced **five
live defects nobody had written down**.

| # | Defect | Evidence it was real | Pinned by |
|---|---|---|---|
| D-a | House rules never applied — TWO independent causes | 8 guarded call sites permanently in their default branch | `test_house_rules.gd` (18) |
| D-b | Core Rules **p.24** Leader +1 Luck granted nowhere | `apply_leader_luck_bonus()` had 0 callers; `add_luck()` had exactly 1 — that dead function | `test_leader_luck_bonus.gd` (10) |
| D-c | 4 dead Seize the Initiative producers | nothing read `mission_data["seize_initiative_modifier"]`; the Black Job +1 is recorded in CLAUDE.md as shipped Aug 7 | `test_seize_initiative_funnel.gd` (9) |
| D-d | 3 of 7 Advanced Training courses had no effect | `security` / `pilot` / `mechanic` — purchasable and inert | `test_training_effects_applied.gd` (11) |
| D-e | `ShipPanel` destroyed its own scene nodes every load | bound the parent section instead of the list | `test_ship_panel_traits_container.gd` (4) |
| D-f | `SaveFileMigration` validated a schema no save has | 0 of 3 required keys present in any of 21 saves | `test_save_migration_origin.gd` (15) + a real-file probe |
| D-g | 2 backend nodes instantiated and never invoked | 0 external callers across every public method of either | — (removal only) |

**Stale, struck from this backlog:** the mechanics-map "Needs Wiring" rows (all
six methods have live callers), the ShipPanel 0-3 debt fallback (fixed, with the
reason at the site), and the equipment condition/quality remnants (they live only
in files already production-dead).

**Deliberately NOT deleted:** `ContactManager` and `RivalBattleGenerator` moved
from "reachable" to `test_only` when their dead instantiation was removed.
`RivalBattleGenerator` cites Core Rules p.91 ×5 and p.119 ×2. The p.91 rival
battle types ARE live elsewhere (`BattleSetupRules.gd:30-31`), so these are
parallel duplicates rather than a lost chapter — but that is a wire-or-delete
call for the tier-7 triage, not something a wiring fix should decide.

**Also removed:** the six `"source": "Community"` house rules (invented mechanics
in `src/data/`, two carrying unsourced numeric values) and their consumers,
including the `narrative_injuries` dialog. ⚠ That last one was a complete
352-line UI, not a stub — it was unreachable because `is_enabled()` always
returned false, but it is recoverable from git if the decision is revisited.

**Verification:** 7 gating lints CLEAN · `lint_orphan_assets` `orphans=0,
unwired_rules=1` · `verify_battle_ui` 137/0 · `verify_post_battle` 47/0 ·
`verify_story_track` 9/0 · `--headless` parse-clean · full `tests/unit` in
batches of <=38. Every fix reverted in isolation first to prove the test detects
it; one revert came back GREEN and had to be redone faithfully (see CLAUDE.md,
"a detection proof is only as discriminating as its fixture").
