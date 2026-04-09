# Tactica Prototype → FPCM Tactics Conversion Map

## Overview

The Tactica prototype at `c:\Users\admin\Desktop\tacticaprototype1\` is a Godot 4.6 project with 322 GDScript files implementing Age of Fantasy (OPR) tabletop rules. It provides **architectural reference** for army building, combat resolution, and data structures — but uses a different IP.

**CRITICAL RULE**: Only STRUCTURE/PATTERNS transfer. ALL game data values must come from the Five Parsecs Tactics rulebook at `docs/rules/tactics_source.txt`.

## What Transfers (~16 files worth of patterns)

### Data Model Patterns
| Prototype File | FPCM Equivalent | What Transfers |
|---------------|-----------------|---------------|
| `src/core/ArmyCompositionValidator.gd` | `TacticsArmyValidator.gd` | Validation logic structure: hero limits, duplicate limits, points caps, min/max unit sizes |
| `src/core/AOFRulesEngine.gd` (~1200 lines) | `TacticsRulesEngine.gd` | Combat resolution pipeline pattern: attack rolls, saves, damage, morale. NOT actual values |
| `src/core/GameStateMachine.gd` | `TacticsBattleStateMachine.gd` | State machine pattern for tactical turns |
| `src/core/CombatCalculator.gd` | Part of TacticsRulesEngine | Dice math, modifier stacking pattern |

### Resource Shapes
| Prototype File | FPCM Equivalent | What Transfers |
|---------------|-----------------|---------------|
| `UnitProfile` Resource | JSON unit profile schema | Field structure: stats, special rules, cost, keywords |
| `WeaponProfile` Resource | JSON weapon profile schema | Field structure: range, shots, damage, traits |
| `SpecialRule` Resource | JSON special rule schema | Field structure: name, description, effect type, parameters |
| `Faction` Resource | JSON army book schema | Field structure: name, units, faction_rules, weapons |

### Army Builder UI Patterns
| Prototype File | FPCM Equivalent | What Transfers |
|---------------|-----------------|---------------|
| `ArmyBuilderPanel` | `TacticsArmyBuilderUI.gd` | Panel layout pattern: roster list, points display, validation feedback |
| `ArmyBookLoader` | `TacticsDataManager` section | JSON loading pattern for army book data |

## What Does NOT Transfer (~306 files to discard)

### 3D Battlefield (discard entirely)
- `godot-3d-env/` — Terrain3D integration, elevation, LOD
- `src/battlefield/` — Grid system, hex tiles, 3D terrain placement
- `src/sprites/` — HD-2D sprite rendering, billboards
- `src/vfx/` — Particle effects, weapon trails, explosions
- PhantomCamera3D — Camera system
- Octagonal movement system

### AI System (discard — different approach)
- `src/ai/` — LimboAI behavior trees
- Behavior tree nodes, blackboard system
- FPCM uses simpler D6-based AI tables, not behavior trees

### Exploration & Base Building (discard — different game)
- `src/exploration/` — 3D exploration system
- `src/base/` — Base building (not same as Planetfall colonies)
- `src/story/` — Narrative events (different from Tactics campaign events)
- Cutscene system

### Infrastructure (discard — FPCM has its own)
- Project config, autoloads, theme
- Save/load system (FPCM has GameState pattern)
- Scene transitions (FPCM has SceneRouter + TransitionManager)

## Key Concept Mapping

| Prototype (AOF) | Five Parsecs Tactics | Notes |
|-----------------|---------------------|-------|
| `quality` | `training` | Different name, similar concept |
| `defense` | `toughness` + saves | Tactics splits defense into toughness and saving throws |
| `tough(N)` | `kill_points: N` | Tactics uses KP explicitly |
| `hero` | Major/Epic Character | Same concept, different naming |
| `faction` | species army list | 17 fantasy factions → 14 Five Parsecs species |
| `.tres` Resource files | JSON data files | FPCM uses JSON + GameDataManager, not .tres instances |
| LimboAI trees | D6 AI behavior tables | Completely different AI approach |

## Army Book Schema (adapt from prototype)

The prototype stores army books in `src/data/army_books/` with 17 directories (Age of Fantasy factions). The STRUCTURE is reusable for Five Parsecs Tactics:

```json
{
  "faction_id": "humans",
  "faction_name": "Human Alliance",
  "faction_special_rules": [
    {"name": "Widely Skilled", "description": "+1 to communication tests", "effect": "comm_bonus_1"}
  ],
  "unit_profiles": {
    "civilian": {
      "name": "Civilian",
      "tier": 1,
      "speed": 4, "reactions": 1, "combat_skill": 0,
      "toughness": 3, "kp": 1, "savvy": 0, "training": 0,
      "cost": 5,
      "special_rules": [],
      "default_weapons": ["civilian_pistol"]
    },
    "military": { ... },
    "sergeant": { ... },
    "major": { ... },
    "epic": { ... }
  },
  "weapon_profiles": {
    "infantry_rifle": {
      "name": "Infantry Rifle", "range": 24, "shots": 1,
      "damage": 1, "traits": [], "cost": 0
    }
  },
  "vehicle_profiles": {
    "apc": {
      "name": "APC", "kp": 4, "armor": "4+",
      "transport": 8, "weapons": ["hull_gun"],
      "traits": ["armored", "transport"], "cost": 40
    }
  }
}
```

**ALL VALUES in this schema are PLACEHOLDERS**. Real values must be extracted from the Five Parsecs Tactics rulebook.

## Prototype Key Files (verified to exist)

- `c:\Users\admin\Desktop\tacticaprototype1\src\core\ArmyCompositionValidator.gd` — army building validation
- `c:\Users\admin\Desktop\tacticaprototype1\src\core\AOFRulesEngine.gd` — combat resolution (~1200 lines)
- `c:\Users\admin\Desktop\tacticaprototype1\src\core\GameStateMachine.gd` — tactical state machine
- `c:\Users\admin\Desktop\tacticaprototype1\src\data\army_books\` — 17 faction directories

## Conversion Principles

1. **Study the prototype for HOW, use the rulebook for WHAT** — prototype teaches architecture patterns, rulebook provides all game data
2. **JSON not .tres** — FPCM uses JSON data files loaded by GameDataManager, not Godot Resource instances
3. **2D UI, not 3D battlefield** — FPCM is a tabletop companion with text instructions, not a 3D tactical simulator
4. **Deep Space theme** — All UI follows FPCM's Deep Space design system (colors, fonts, spacing)
5. **Serialization contract** — `to_dictionary()`/`from_dictionary()` with `"campaign_type": "tactics"`, FileAccess + JSON
6. **`preload()` for scripts** — `const PanelClass = preload("res://path/to/Panel.gd")`, NOT `load()` at runtime
