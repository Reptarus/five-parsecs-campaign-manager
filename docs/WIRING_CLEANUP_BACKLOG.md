# Wiring / Dead-Code Cleanup Backlog

> ## ▶ RESUME STATE (last updated 2026-07-10)
> - **Branch `master`, working tree CLEAN.** This session's cleanup commits:
>   `5d38d039` (Tier 3 autoload), `e837ea6c` (combat subsystem), `74121314` (Tier 2 TravelPhaseUI).
>   All committed. Nothing uncommitted.
> - **Lint counts: ALL 4 CLEAN ✅** — signal-wiring 0 · tscn 0 · autoload 0 · data-ownership 0.
>   The lint-tracked dead-code slate is CLEAN. Remaining tiers (5, 6) are NOT lint-covered.
> - **DONE — ALL 6 CLEANUP TIERS COMPLETE:** wiring-audit sprint; Tier 1 `rival_escalated`;
>   Tier 3 (autoload CLEAN); combat subsystem DELETED; Tier 2 TravelPhaseUI DELETED (tscn CLEAN);
>   Tier 4 (all 64 dead signals — signal CLEAN); Tier 5 (23 redundant methods + 2 cascade signals;
>   3 book-mechanics PRESERVED+flagged); **Tier 6 (6 dead temp_data keys' writes + `set_pending_combat`
>   + 2 unused consts DELETED; `current_mission` FLAGGED as a behavioral latent-bug case).**
>   **ALL 4 LINTS CLEAN. The lint-tracked + backlog-tracked dead-code slate is CLEAN.**
> - **NEXT — the clean slate is reached; remaining work is WIRING, not cleanup:**
>   (1) unblock the 2 Blocked paths (`get_deployable_crew` deployment filter; Unity Agent favor UI);
>   (2) decide wire-or-cut on the 3 flagged book-mechanic gaps (`use_consumable`, Krag armor ×2);
>   (3) resolve the `current_mission` behavioral flag (Tier 6 — is WorldPhaseController:1703's mission
>   a latent bug?). Each is a feature/behavioral task needing the user's call, NOT dead-code removal.
> - **PER WAVE:** run the deletion protocol (below) before each delete; headless
>   compile + FULL suite (`-a tests/unit -a tests/integration -a tests/battle -c`,
>   baseline 149 suites / 1683 cases / 0 fail) green before commit; one wave = one commit.
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
`tests/` for a mock injection (test seam — see the DiceSystem lesson). Delete the
`.uid` sibling with every `.gd`/`.tscn`. Every wave: headless compile + FULL suite
(`-a tests/unit -a tests/integration -a tests/battle -c`) green before commit.

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

## Discovered unwired book-mechanic gaps (2026-07-10) — decide wire-or-cut (user chose PRESERVE)

Zero-caller methods found in Tier 5 that are NOT redundant — they implement a book mechanic
that is live NOWHERE else, so they're gaps (like the Blocked paths), not dead code. Preserved:
- **`EquipmentManager.use_consumable`** — no consumable-use UI exists anywhere; consumables can
  be looted/held but never used. Verify book intent (is there an active-use mechanic?) then wire or cut.
- **`EquipmentManager.modify_armor_for_krag` + `set_armor_krag_designation`** — real Compendium
  mechanic (`data/compendium/species.json`: Trade-table armor must be designated Krag/non-Krag,
  Modification 2 Credits reversible; Skulkers/Engineers can wear Krag armor). Implemented, never
  wired to any equipment/trade flow. Wire into the trade/equipment UI or cut.

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

**FLAGGED (behavioral, NOT a clean dead-write — excluded from the delete):** `current_mission`.
`GameStateManager.set_current_mission()` writes ONLY the dead temp channel, but `get_current_mission()`
reads `progress_data["current_mission"]` (written LIVE at CampaignTurnController:924 +
WorldPhaseController:1180). `set_current_mission` is still CALLED — DeveloperQuickStart:379 (guarded)
and WorldPhaseController:1703, whose flow is SEPARATE from the live :1180 write. So :1703 may have a
LATENT BUG (its mission stored to a dead channel, never retrievable). Needs a behavioral check: is
:1703's mission read elsewhere, or should `set_current_mission` write `progress_data` (fix) / be
deleted with its call sites (if redundant)? Not dead-code-cleanup scope.

---

## Blocked paths — UNBLOCK ONLY AFTER the clean slate

1. **`get_deployable_crew` deployment filter.** Uncalled; the live path
   `GameState.get_active_crew()` applies NO status filter, so DEAD/RETIRED/DEPARTED/
   MISSING + the Character-Events `skip_next_battle` gate are unenforced at deployment
   (Core Rules pp.128-130). Wire the filter into the battle-crew assembly + add a
   `skip_next_battle` status-effect exclusion; verify via MCP that an affected member is
   excluded from the deployed roster. Keep `get_deployable_crew` as the fix seed.
2. **Unity Agent "Call in a Favor" resolution UI** (Core Rules p.20).
   `CampaignPhaseManager.resolve_unity_agent_favor()` / `mark_unity_agent_trait_lost()`
   are correct scaffolding with no UI caller (the per-turn roll IS wired). Build the
   player-facing favor-choice / trait-loss dialog and wire these two methods to it. Note
   `resolve_unity_agent_favor` also calls `gsm.remove_random_rival()` (dead) —
   fix/implement that too.
