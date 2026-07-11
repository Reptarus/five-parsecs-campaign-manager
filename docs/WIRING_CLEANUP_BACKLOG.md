# Wiring / Dead-Code Cleanup Backlog

> ## ▶ RESUME STATE (last updated 2026-07-10)
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
