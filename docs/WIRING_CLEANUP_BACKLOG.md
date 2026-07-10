# Wiring / Dead-Code Cleanup Backlog

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

## Priority tier 1 — LIVE bugs (do first; these are not just dead code)

**5 live signal dead-wires** (`lint_signal_wiring.py`, `[LIVE DEAD-WIRE]`) — a
listener exists but the signal is never emitted, so the feature silently never
fires (same class as the fixed `reroll_requested`). Each: decide WIRE (find the
rules-legal emit point) vs DELETE (signal + listeners). First confirm whether the
owning component is even in a live scene (several are in the combat-override
subsystem that looks up the dead `/root/CombatManager`).

- `manual_override_applied` — `BaseCombatManager.gd:25` + `state_verification_controller.gd:59` (2 listeners)
- `override_requested` — `manual_override_panel.gd:5` (1)
- `tactical_advantage_changed` — `BaseBattlefieldManager.gd:12` (1)
- `rival_escalated` — `RivalBattleGenerator.gd:41` (1) — most likely live code

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

## Priority tier 3 — dead autoload lookups (35, `lint_autoload_lookups.py`)

Fix-or-delete each (a `# lint:ignore` for genuine test seams — see the MockDiceSystem
`/root/DiceSystem` case, already annotated). Names not in `project.godot [autoload]`:
`FPCM_AlphaGameManager` (×6), `CombatManager` (×5), `CampaignManager` (×4),
`FiveParsecsCombatSystem` (×3), `CampaignCreationUI` (×2), `UIManager` (×2),
`BattleTracker` (×2), plus `PatronSystem`, `BattleManager`, `CharacterManagerAutoload`,
`DataManagerAutoload` (→ `DataManager`), `OptimizedSystemsAutoload`,
`CampaignCreationStateBridge`. Most are guarded (`get_node_or_null`/`has_node`) dead
fallbacks → delete the branch + the now-dead local var. Verify the 5 possible
runtime-node names before deleting (`PostBattlePhase`, `PersistentResourceBar`,
`CampaignCreationUI`, `CampaignCreationStateBridge`, `BattleTracker` — allowlist with
evidence if actually added under /root).

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
