---
name: character-data
description: "Use this skill when working with character data models, the three-enum system, JSON game data files, equipment management, or world/economy systems. Covers Character.gd, BaseCharacterResource, GlobalEnums, GameEnums, FiveParsecsGameEnums, EquipmentManager, DataManager, GameDataManager, PlanetDataManager, WorldEconomyManager, and all 132 JSON files in data/."
---

# Character & Data Systems

## Reference Files

| Reference | Contents |
|-----------|----------|
| `references/character-model.md` | Character.gd full API (~1,900 lines), BaseCharacterResource, flat stats, dual-key aliases, implant system, serialization format |
| `references/enum-systems.md` | Three-enum alignment table (GlobalEnums vs GameEnums vs FiveParsecsGameEnums), sync protocol, diff-check |
| `references/json-data-catalog.md` | All 132 JSON files: path, schema summary, consumer system, validation rules |
| `references/equipment-world.md` | EquipmentManager API, equipment_data key, sell value logic, PlanetDataManager, PlanetCache, WorldEconomyManager |

## Quick Decision Tree

- **Modifying character stats/properties** → Read `character-model.md`
- **Adding/changing enum values** → Read `enum-systems.md` (MUST sync all 3 files)
- **Working with JSON data files** → Read `json-data-catalog.md`
- **Equipment/world/economy changes** → Read `equipment-world.md`
- **Character serialization bugs** → Read `character-model.md` (to_dictionary/from_dictionary section)
- **Adding new data tables** → Read `json-data-catalog.md` + `equipment-world.md` for loading pattern

## Key Source Files

| File | Class/Role | Purpose |
|------|-----------|---------|
| `src/core/character/Character.gd` | `Character` | Canonical character model (~1,900 lines) |
| `src/core/character/Base/Character.gd` | `BaseCharacterResource` | Base Resource with flat stats |
| `src/core/systems/GlobalEnums.gd` | Autoload `GlobalEnums` | Primary enum definitions (70+) |
| `src/core/enums/GameEnums.gd` | `GameEnums` | Secondary enum definitions (80+) |
| `src/game/campaign/crew/FiveParsecsGameEnums.gd` | Node | CharacterClass, CharacterStatus, ShipType, CampaignType |
| `src/core/equipment/EquipmentManager.gd` | Autoload | Equipment operations, pricing |
| `src/core/data/DataManager.gd` | Autoload | Data persistence, JSON loading |
| `src/core/managers/GameDataManager.gd` | Autoload | Game data loading (injuries, enemies, gear, etc.) |
| `src/core/world/PlanetDataManager.gd` | Autoload | Planet persistence, world events |
| `src/core/world/WorldEconomyManager.gd` | Autoload | Credits, transactions, price adjustments |

## Critical Gotchas

1. **Stats are FLAT** — `combat`, `reactions`, `toughness`, `speed`, `savvy`, `luck`, `tech` are direct properties. NO `stats` sub-object
2. **Three enum files must stay in sync** — GlobalEnums, GameEnums, FiveParsecsGameEnums
3. **Dual-key aliases** — `to_dictionary()` returns both `"id"`/`"character_id"` and `"name"`/`"character_name"`
4. **Equipment key is `"equipment"`** — NOT `"pool"` (Phase 22 fix)
5. **`class_name` + autoload conflict** — Godot 4.6 errors if a script has both
6. **Use `load()` not `preload()`** in autoloaded scripts (autoloads parse before import system)
7. **FiveParsecsCampaignCore is Resource** — `campaign["key"] = val` silently fails; use `progress_data["key"]`
