# Wiring / Dead-Code Cleanup Backlog

> ## ▶ RESUME STATE (last updated 2026-07-10)
> - **Branch `master`, working tree CLEAN** (after the Tier 3 commit — run `git log -1`).
>   All wiring-audit + cleanup work is committed. Nothing uncommitted.
> - **Lint counts:** signals 66 (4 live dead-wires) · tscn 6 · **autoload 4** (was 35;
>   the 4 residual are `/root/CombatManager` in the combat subsystem, die with Tier 2) ·
>   data-ownership CLEAN. Re-run any lint to refresh (commands below).
> - **DONE:** the wiring-audit sprint (normalizer + 8 live fixes + orphan deletes +
>   contract doc + lints); Tier 1 `rival_escalated`; **Tier 3 (31 dead autoload lookups
>   removed + orphan `AlphaGameManager.gd` deleted + `PersistentResourceBar` `# lint:ignore`d —
>   see the Tier 3 section for full dispositions).**
> - **NEXT (recommended order):** the **combat subsystem** (`src/ui/components/combat/{overrides,state,log,rules}/`,
>   ~13 pairs) — clears the last 4 autoload findings AND Tier-1's `manual_override_applied`/
>   `override_requested`/`tactical_advantage_changed`. **Per-component** protocol (combat_log has
>   a `test_combat_log_explanations` dep — do NOT bulk `git rm`). THEN Tier 3-residual auto-clears,
>   then legacy TravelPhaseUI (Tier 2 tscn), then Tier 4/5/6.
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
- `manual_override_applied`, `override_requested` — DELETE with the **orphaned
  combat-override subsystem** (see tier 2). The listeners live in that subsystem; no
  external code instances it.
- `tactical_advantage_changed` — `BaseBattlefieldManager.gd:12`. Verify BaseBattlefieldManager
  liveness (base class); the listener is likely in the same dead battlefield-base tree → DELETE.

## Priority tier 2 — dead scenes / load-time errors

- **Legacy TravelPhaseUI** (all 6 `lint_tscn_connections.py` findings). `TravelPhaseUI.tscn`
  is scripted by `campaign/TravelPhase.gd` (missing all 6 `_on_*` handlers);
  `travel/TravelPhaseUI.gd` (class_name TravelPhaseUI) has 4 handlers but is attached
  to no scene. Instanced-but-hidden in `CampaignTurnController.tscn`, superseded by the
  unified World Phase (CampaignTurnController.gd:1390 "legacy"). DECISION: delete the
  whole legacy screen (scene + both scripts + the controller's `%TravelPhaseUI` instance
  + `@onready`/assert/signal wiring at CTC :29,:96,:127-128,:214-216,:613), OR repoint the
  script to `travel/TravelPhaseUI.gd` if the screen should live. Verify class_name
  `TravelPhaseUI` has no other users first.
- **Bare `/root/...` `get_node`** (subset of the 35 autoload findings, tagged `[BARE
  get_node]`) — these error at runtime, not just null. `combat_log_controller.gd:11`
  (`/root/CombatManager`), `ResponsiveContainer.gd:306` (`/root/UIManager`),
  `state_verification_controller.gd:37`, `BattlefieldMain.gd:49` + `TacticalBattleUI.gd:333`
  (`/root/FPCM_AlphaGameManager`), `TacticalBattleUI.gd:335` (`/root/BattleTracker`).

## Priority tier 3 — dead autoload lookups — DONE (35 → 4 residual, all combat-subsystem)

Resolved 2026-07-10. 31 of 35 removed; the 4 residual are `/root/CombatManager` in
`src/ui/components/combat/{log,rules,state}/` — deferred to the combat-subsystem
deletion (Tier 2) because those files are being deleted wholesale (editing files
about to be removed is wasted work). After that wave, `lint_autoload_lookups.py`
exits 0.

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

## Priority tier 4 — dead signals with NO listener (62, `lint_signal_wiring.py`)

Harmless forward-declared component API nobody consumes. Per-signal: DELETE unless a
near-term consumer is planned. Bulk-deletable but lower value; do after tiers 1-3.

## Priority tier 5 — zero-caller public methods (~23; NOT lint-covered)

Unused-but-harmless public API. Run the deletion protocol per method. Known set:
autoload `EquipmentManager` (×14 incl. `apply_gun_mod`, `use_consumable`,
`repair_equipment`, `create_weapon_item`, `remove_equipment_from_character`, the
onboard-item getters, `create_armor_item`/`create_gear_item`, krag helpers);
`GameStateManager` (`set_campaign_phase`, `set_tutorials_enabled`, `set_language`,
`get_supplies`; **NOT `get_deployable_crew`** — that's a Blocked path, keep);
`CampaignPhaseManager` (×9 incl. `complete_current_turn`, `start_sub_phase`,
`reset_phase_tracking`, `get_campaign_results`, `validate_current_campaign`).
Re-prove zero-caller at execution time (some had `b>0` bareword hits = possible
dynamic dispatch).

## Priority tier 6 — dead temp_data writes (NOT lint-covered)

`GameStateManager` temp keys written but never read: `return_screen`, `crew_add_mode`,
`current_mission` (temp channel — live copy is `progress_data`), `world_phase_results`
(temp channel), `planetfall_mission`, `bug_hunt_mission`. Delete the writes. `pending_combat`
(TravelPhaseUI.gd:660 → sole writer, 0 readers) needs a Core-Rules-p.35 book-check first:
book-backed travel→combat handoff → `Blocked(feature)`; else delete.

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
