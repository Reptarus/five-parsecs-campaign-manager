---
name: battle-systems
description: "Use this skill when working with the battle state machine, combat resolution, deployment zones, victory conditions, tactical battle UI, or pre-battle setup. Covers BattleStateMachine, BattleResolver, DeploymentManager, VictoryChecker, TacticalBattleUI, PreBattleUI, and all battle-phase components."
---

# Battle Systems

## Reference Files

| Reference | Contents |
|-----------|----------|
| `references/battle-state-machine.md` | BattleStateMachine states/transitions/phases, enums, combat flow, save/load |
| `references/combat-resolution.md` | BattleResolver static API, deployment modifiers, round execution, outcome calculation |
| `references/deployment-victory.md` | DeploymentManager zones/terrain, VictoryChecker 18 types, mission objectives |
| `references/battle-ui-wiring.md` | TacticalBattleUI signals, three-tier visibility, PreBattleUI dual setup methods |

## Quick Decision Tree

- **Battle phase stuck** → Read `battle-state-machine.md`
- **Combat math wrong** → Read `combat-resolution.md`
- **Deployment/terrain issues** → Read `deployment-victory.md` (also see BattlefieldGenerator for Compendium terrain themes)
- **Victory condition** → Read `deployment-victory.md`
- **Battle UI components** → Read `battle-ui-wiring.md`
- **Pre-battle setup** → Read `battle-ui-wiring.md` (PreBattleUI section)

## Key Source Files

| File | Class/Role | Purpose |
|------|-----------|---------|
| `src/core/battle/state/BattleStateMachine.gd` | `BattleStateMachineClass` | Battle state + phase flow (3 states, 6 phases) |
| `src/core/battle/BattleResolver.gd` | `BattleResolver` | Static combat resolution (RefCounted) |
| `src/core/battle/BattlefieldGenerator.gd` | `FPCM_BattlefieldGenerator` | Compendium 5-step terrain generation (7 themes, world traits, seeded RNG) |
| `src/core/managers/DeploymentManager.gd` | Resource | Deployment zones + deployment type inference |
| `src/core/victory/VictoryChecker.gd` | `VictoryChecker` | Victory condition evaluation (18 types) |
| `src/ui/screens/battle/TacticalBattleUI.gd` | `FPCM_TacticalBattleUI` | Tactical battle companion (3 oracle tiers) |
| `src/ui/screens/battle/PreBattleUI.gd` | Control | Pre-battle crew selection + tier selector + preview |
| `src/ui/components/battle/BattlefieldMapView.gd` | `BattlefieldMapView` | Graph-paper terrain map (SVS shapes, objectives, units) |
| `src/ui/components/battle/BattlefieldGridPanel.gd` | PanelContainer | Terrain map wrapper (header, legend, popover, regenerate) |
| `src/ui/screens/battle_simulator/BattleSimulatorUI.gd` | Control | Standalone battle mode (Setup→Battle→Results) |
| `src/core/battle/BattleSimulatorSetup.gd` | RefCounted | Lightweight crew/enemy data fabricator |
| `src/game/combat/CombatResolver.gd` | Node | Combat resolution with 24-method character interface |

## Rules Data Authority

All battle mechanics MUST be verified against `data/RulesReference/` files. Key files: `Bestiary.json` (enemy stats/tables), `EnemyAI.json` (AI behavior), `EliteEnemies.json` (elite variants), `TerrainTables.json` (terrain rules), `AlternateEnemyDeployment.json`.

**NEVER invent combat values, enemy stats, or weapon modifiers.** Verify against RulesReference before implementing.

## JSON-Driven Battle Data

| JSON File | Consumer(s) | Contents |
|-----------|-------------|----------|
| `data/injury_results.json` | PostBattleProcessor, ExperienceTrainingProcessor, BattleCalculations | D100 injury tables (human/bot), XP awards (Core Rules p.122-123) |
| `data/injury_table.json` | DataManager, GameDataManager | Older injury table format (same data, different structure) |
| `data/unique_individual.json` | BattlePhase._determine_unique_individual() | Presence thresholds, difficulty modifiers, Interested Parties +1, exclusion rules |
| `data/enemy_types.json` | BattlePhase._roll_unique_individual_type(), EnemyGenerator | 21 unique individual types (D100 table), 59 enemy types, AI mappings |

## Critical Gotchas

1. **Tabletop companion, not simulator** — output is text instructions, not automatic movement
2. **Three oracle tiers** — LOG_ONLY, ASSISTED, FULL_ORACLE — components are tier-aware
3. **BattleResolver is static** — use `BattleResolver.resolve_battle()`, never instantiate as Node
4. **PreBattleUI has two setup methods** — `setup_preview(data)` + `setup_crew_selection(crew)`, not one. Also has `selected_tier` (int 0/1/2) for tier selection
5. **TacticalBattleUI shared across 3 modes** — Standard 5PFH, Bug Hunt, and Battle Simulator. Changes must work in all three
6. **MAX_COMBAT_ROUNDS = 6** (Five Parsecs p.118 — verify in `data/RulesReference/`), MIN = 3
7. **BattlefieldGenerator returns combat_notes** — `result["combat_notes"]` (Array[String]) for world trait non-terrain effects. Also `result["seed"]` for reproducibility
8. **BattleTransitionUI is bypassed** — CampaignTurnController goes directly to PreBattleUI via `_launch_pre_battle_directly()`
9. **tactical_battle_completed emits Dictionary** — not BattleResult class. 20+ fields (held_field, crew_participants, defeated_enemies, mission flags)
10. **DRAMATIC_COMBAT wires through TWO resolvers** (May 29 2026, B3 Sprint 4). Both `BattleResolver.resolve_battle` and `NoMinisResolver.resolve_battle` query `CompendiumDifficultyTogglesRef.get_adjusted_shooting_thresholds()` once at entry, stash on `battlefield_data["dramatic_combat"] = true` + `["adjusted_shooting_thresholds"] = {open:5, cover:6}`, then inject into the attacker dict before each `BattleCalculations.resolve_ranged_attack` call. `BattleCalculations.resolve_ranged_attack` reads `attacker.get("dramatic_combat")` to swap to the Adjusted Shooting table (5+ open / 6+ cover per Compendium p.87). **Trap**: if you add a new DLC-gated combat mechanic, wiring it ONLY in BattleCalculations is dead code — the resolver must inject the flag. Catalog query is self-gating (returns `{}` when DLC off), so the call is always safe. Verify at runtime by MCP-flipping `DLCManager._enabled_flags[DRAMATIC_COMBAT] = true/false` and asserting overlay presence on `battlefield_data`.
11. **`dramatic_weapons_stats` table** (`data/compendium/difficulty_toggles.json`) — 35 entries from Compendium pp.88-89. Use `CompendiumDifficultyToggles.get_dramatic_weapon_stats(weapon_id)` to look up overrides (returns `{}` when DRAMATIC_COMBAT off). Weapon-id normalization: `to_lower().replace(" ", "_").replace("-", "_")` (so "Blast Pistol" matches "blast_pistol").
