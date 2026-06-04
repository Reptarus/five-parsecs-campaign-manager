---
name: character-data
description: "Use this skill when working with character data models, the two-enum system, JSON game data files, equipment management, or world/economy systems. Covers Character.gd, BaseCharacterResource, GlobalEnums, GameEnums, EquipmentManager, DataManager, GameDataManager, PlanetDataManager, WorldEconomyManager, and all 132 JSON files in data/."
---

# Character & Data Systems

## Reference Files

| Reference | Contents |
|-----------|----------|
| `references/character-model.md` | Character.gd full API (~1,900 lines), BaseCharacterResource, flat stats, dual-key aliases, implant system, serialization format |
| `references/enum-systems.md` | Two-enum alignment table (GlobalEnums vs GameEnums), sync protocol, diff-check |
| `references/json-data-catalog.md` | All 132 JSON files: path, schema summary, consumer system, validation rules |
| `references/equipment-world.md` | EquipmentManager API, equipment_data key, sell value logic, PlanetDataManager, PlanetCache, WorldEconomyManager |

## Quick Decision Tree

- **Modifying character stats/properties** → Read `character-model.md`
- **Adding/changing enum values** → Read `enum-systems.md` (MUST sync both files: GlobalEnums + GameEnums)
- **Working with JSON data files** → Read `json-data-catalog.md`
- **Equipment/world/economy changes** → Read `equipment-world.md`
- **Character serialization bugs** → Read `character-model.md` (to_dictionary/from_dictionary section)
- **Adding new data tables** → Read `json-data-catalog.md` + `equipment-world.md` for loading pattern
- **PlanetDataManager cross-mode contamination** → Every campaign core's `apply_pending_qol_data()` MUST call `pdm.deserialize_all({})` unconditionally so 5PFH state can't bleed into Bug Hunt / Planetfall / Tactics. The autoload's `visited_planets.clear()` only executes inside `deserialize_all()`. Empty dict cleanly clears via the `clear()` at top of the function. See CLAUDE.md gotchas (Jun 2026 Galaxy Log audit B3/B4)
- **Starting world seeding** → `CampaignFinalizationService.finalize_campaign()` registers the starting world with PlanetDataManager via `pdm.get_or_generate_planet()` so it joins `visited_planets` with `discovered_on_turn=0`. Without this, `travel_history` is empty on Turn 0 and downstream consumers (Galaxy Log anchor logic, future world-history features) would crash or miss the home world (Jun 2026 Galaxy Log audit B2)
- **Journal `location` write contract** → All journal writers (TravelPhase, PostBattleCompletion, CampaignJournal.auto_create_milestone_entry) MUST set `location = current_planet.name` so `get_entries_by_location()` can join entries to a planet. Resolve via `pdm.get_current_planet().name` — do NOT read from `battle_result.location` (it's never populated). See CLAUDE.md gotchas (Jun 2026 Galaxy Log audit B1)

## Key Source Files

| File | Class/Role | Purpose |
|------|-----------|---------|
| `src/core/character/Character.gd` | `Character` | Canonical character model (~1,900 lines) |
| `src/core/character/SpeciesDataService.gd` | `SpeciesDataService` | Static species lookup from character_species.json (16 Strange Characters + primary + compendium) |
| `src/core/character/CharacterTransferService.gd` | `CharacterTransferService` | Cross-mode character transfer — **canonical hub** (5PFH-standard Character dict is the interchange form). `export_to_canonical` / `import_from_canonical` / `transfer_character` compose any-to-any routes through 5PFH. Lossless `snapshot` embed; reward-suppression unless `target_mode == "five_parsecs"`. File-drop via `user://transfers/<id>.json`. See gamemode skills' `cross-mode-safety.md` for full route matrix |
| `src/core/character/Base/Character.gd` | `BaseCharacterResource` | Base Resource with flat stats |
| `src/core/systems/GlobalEnums.gd` | Autoload `GlobalEnums` | Primary enum definitions (70+) |
| `src/core/enums/GameEnums.gd` | `GameEnums` | Secondary enum definitions (80+); CharacterClass/CharacterStatus/ShipType/CampaignType (FiveParsecsGameEnums.gd deleted Sprint A Bug 3, 2026-05-24) |
| `src/core/equipment/EquipmentManager.gd` | Autoload | Equipment operations, pricing |
| `src/core/data/DataManager.gd` | Autoload | Data persistence, JSON loading |
| `src/core/managers/GameDataManager.gd` | Autoload | Game data loading (injuries, enemies, gear, etc.) |
| `src/core/world/PlanetDataManager.gd` | Autoload | Planet persistence, world events |
| `src/core/world/WorldEconomyManager.gd` | Autoload | Credits, transactions, price adjustments |

## Rules Data Authority

All game data values MUST be verified against `data/RulesReference/` files (extracted from Core Rules and Compendium PDFs). Key RulesReference files for this skill: `SpeciesList.json`, `EquipmentItems.json`, `Bestiary.json`, `Campaign.json`, `DifficultyOptions.json`.

**NEVER invent stats, costs, ranges, or probabilities.** If data isn't in RulesReference, ask the user to provide it from the book. See `docs/QA_RULES_ACCURACY_AUDIT.md` for the full verification checklist.

## Critical Gotchas

1. **Stats are FLAT** — `combat`, `reactions`, `toughness`, `speed`, `savvy`, `luck`, `tech` are direct properties. NO `stats` sub-object
2. **Both enum files must stay in sync** — GlobalEnums, GameEnums (FiveParsecsGameEnums.gd deleted Sprint A Bug 3, 2026-05-24)
3. **Dual-key aliases** — `to_dictionary()` returns both `"id"`/`"character_id"` and `"name"`/`"character_name"`
4. **Equipment key is `"equipment"`** — NOT `"pool"` (Phase 22 fix)
5. **`class_name` + autoload conflict** — Godot 4.6 errors if a script has both
6. **Use `load()` not `preload()`** in autoloaded scripts (autoloads parse before import system)
7. **FiveParsecsCampaignCore is Resource** — `campaign["key"] = val` silently fails; use `progress_data["key"]`
