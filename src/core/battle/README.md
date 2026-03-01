# Core Battle System

**Last Updated**: 2026-02-28
**Files**: 37 scripts, ~14,422 lines

## Overview

Core battle logic for the Five Parsecs tabletop companion. This directory contains non-UI battle systems: state management, combat resolution, event processing, and tier control.

The main battle UI is `src/ui/screens/battle/TacticalBattleUI.gd` (1,694 lines).
Battle components are in `src/ui/components/battle/` (27 files, 7,218 lines).

See `docs/technical/BATTLE_SYSTEM_ARCHITECTURE.md` for full architecture docs.

## Key Files

| File | Lines | Purpose |
| --- | --- | --- |
| FPCM_BattleManager.gd | 589 | Battle FSM — phase transitions, state management |
| FPCM_BattleState.gd | ~200 | Serializable battle data (crew, enemies, terrain, results) |
| BattleResolver.gd | 530 | Thin orchestrator — delegates to BattleCalculations |
| BattleCalculations.gd | ~400 | Actual combat math (hit rolls, damage, modifiers) |
| BattleRoundTracker.gd | ~350 | Round/phase progression, event triggers at rounds 2/4 |
| BattleTierController.gd | ~250 | Three-tier visibility (LOG_ONLY / ASSISTED / FULL_ORACLE) |
| BattleEventsSystem.gd | ~300 | Battle event generation and processing |
| BattlefieldManager.gd | ~200 | Terrain and deployment zone management |
| DiceSystem.gd (in systems/) | ~250 | Dice rolling patterns (d6, 2d6, d100) |

## Architecture

All core battle classes extend `Resource` or `RefCounted` (not `Node`). They are instantiated with `.new()`, not placed in scenes.

```
FPCM_BattleManager (Resource)
  ├── battle_state: FPCM_BattleState
  ├── dice_system: DiceSystem
  ├── battle_events_system: BattleEventsSystem
  └── Signals: phase_changed, battle_completed, battle_error
```

`BattleResolver.resolve_battle()` is the static entry point for automated combat:
```
BattleResolver.resolve_battle(crew, enemies, mission)
  → BattleCalculations.calculate_hit()
  → BattleCalculations.calculate_damage()
  → returns BattleResult
```

## Tier System

`BattleTierController` manages what UI components are visible:
- **LOG_ONLY (0)**: Journal, dice, calculator, character cards
- **ASSISTED (1)**: + morale, activation, objectives, deployment, initiative
- **FULL_ORACLE (2)**: + enemy AI intent, enemy generation wizard

Tier can only upgrade mid-battle (never downgrade).
