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
- **Deployment/terrain issues** → Read `deployment-victory.md`
- **Victory condition** → Read `deployment-victory.md`
- **Battle UI components** → Read `battle-ui-wiring.md`
- **Pre-battle setup** → Read `battle-ui-wiring.md` (PreBattleUI section)

## Key Source Files

| File | Class/Role | Purpose |
|------|-----------|---------|
| `src/core/battle/state/BattleStateMachine.gd` | `BattleStateMachineClass` | Battle state + phase flow (3 states, 6 phases) |
| `src/core/battle/BattleResolver.gd` | `BattleResolver` | Static combat resolution (RefCounted) |
| `src/core/managers/DeploymentManager.gd` | Resource | Deployment zones + terrain generation |
| `src/core/victory/VictoryChecker.gd` | `VictoryChecker` | Victory condition evaluation (18 types) |
| `src/ui/screens/battle/TacticalBattleUI.gd` | `FPCM_TacticalBattleUI` | Tactical battle companion (3 oracle tiers) |
| `src/ui/screens/battle/PreBattleUI.gd` | Control | Pre-battle crew selection + preview |

## Rules Data Authority

All battle mechanics MUST be verified against `data/RulesReference/` files. Key files: `Bestiary.json` (enemy stats/tables), `EnemyAI.json` (AI behavior), `EliteEnemies.json` (elite variants), `TerrainTables.json` (terrain rules), `AlternateEnemyDeployment.json`.

**NEVER invent combat values, enemy stats, or weapon modifiers.** Verify against RulesReference before implementing.

## Critical Gotchas

1. **Tabletop companion, not simulator** — output is text instructions, not automatic movement
2. **Three oracle tiers** — LOG_ONLY, ASSISTED, FULL_ORACLE — components are tier-aware
3. **BattleResolver is static** — use `BattleResolver.resolve_battle()`, never instantiate as Node
4. **PreBattleUI has two setup methods** — `setup_preview(data)` + `setup_crew_selection(crew)`, not one
5. **TacticalBattleUI shared with Bug Hunt** — changes must work in both modes
6. **MAX_COMBAT_ROUNDS = 6** (Five Parsecs p.118 — verify in `data/RulesReference/`), MIN = 3
