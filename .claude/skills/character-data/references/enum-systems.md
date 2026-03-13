# Three Enum Systems Reference

## CRITICAL: All Three Must Stay In Sync

Any enum modification MUST be applied to all three files simultaneously.

| File | Type | Access Pattern | Enum Count |
|------|------|----------------|------------|
| `src/core/systems/GlobalEnums.gd` | Node (autoloaded as `GlobalEnums`) | `GlobalEnums.EnumName.VALUE` | 70+ |
| `src/core/enums/GameEnums.gd` | RefCounted (`class_name GameEnums`) | `GameEnums.EnumName.VALUE` | 80+ |
| `src/game/campaign/crew/FiveParsecsGameEnums.gd` | Node (@tool) | `FiveParsecsGameEnums.EnumName.VALUE` | 4 |

## FiveParsecsGameEnums (Smallest — 4 Enums)

```gdscript
# CharacterClass (15 values)
enum CharacterClass { NONE, SOLDIER, MEDIC, ROGUE, PSIONICIST, TECH, BRUTE,
  GUNSLINGER, ACADEMIC, PILOT, ENGINEER, MERCHANT, SECURITY, BROKER, BOT_TECH }

# CharacterStatus (11 values)
enum CharacterStatus { NONE, HEALTHY, INJURED, SERIOUSLY_INJURED, CRITICALLY_INJURED,
  INCAPACITATED, STUNNED, SUPPRESSED, DEAD, CAPTURED, MISSING }

# ShipType (8 values)
enum ShipType { NONE, SHUTTLE, LIGHT_FREIGHTER, MEDIUM_FREIGHTER, HEAVY_FREIGHTER,
  CORVETTE, PATROL_SHIP, EXPLORER, LUXURY_YACHT }

# CampaignType (11 values)
enum CampaignType { NONE, STANDARD, FREELANCER, MERCENARY, EXPLORER, TRADER,
  BOUNTY_HUNTER, CUSTOM, TUTORIAL, STORY, SANDBOX }
```

Display constants: `CHARACTER_CLASS_NAMES`, `CHARACTER_STATUS_NAMES`, `SHIP_TYPE_NAMES`, `CAMPAIGN_TYPE_NAMES`

Helper methods: `get_character_class_name()`, `get_character_status_name()`, `get_ship_type_name()`, `get_campaign_type_name()`

## GlobalEnums (Primary — 70+ Enums)

### Campaign & Phase Enums
- `FiveParsecsCampaignPhase` (14 values): NONE, SETUP, STORY, TRAVEL, PRE_MISSION, MISSION, BATTLE_SETUP, BATTLE_RESOLUTION, POST_MISSION, UPKEEP, ADVANCEMENT, TRADING, CHARACTER, RETIREMENT
- `DifficultyLevel` (9 values)
- `EditMode` (4 values): NONE, CREATE, EDIT, VIEW

### Character Enums
- `CharacterClass` (30 values — superset of FiveParsecsGameEnums)
- `Origin` (15 values): HUMAN, ENGINEER, FERAL, KERIN, PRECURSOR, SOULLESS, SWIFT, BOT, CORE_WORLDS, FRONTIER, DEEP_SPACE, COLONY, HIVE_WORLD, FORGE_WORLD
- `Background` (32 values): MILITARY, MERCENARY, CRIMINAL, COLONIST, ACADEMIC, EXPLORER, TRADER, etc.
- `Motivation` (22 values): WEALTH, REVENGE, GLORY, KNOWLEDGE, POWER, JUSTICE, SURVIVAL, etc.
- `Training` (9 values)

### Combat & Battle Enums
- `BattlePhase`, `CombatPhase`, `UnitAction`
- `WeaponType`, `ArmorType`, `ItemType`, `ItemRarity`

### Mission & World Enums
- `MissionType`, `MissionObjective`, `JobType`
- `WorldTrait`, `PlanetType`, `LocationType`
- `CrewTaskType` / `CrewTask` (17 values)

### Victory Enums
- `FiveParsecsCampaignVictoryType` (24 types): TURNS_20/50/100, CREDITS_*, REPUTATION_*, QUESTS_*, BATTLES_*

### Helper Methods
- `get_training_name(training) -> String`
- `to_string_value(enum_name, value) -> String`
- `get_class_display_name(char_class) -> String`
- `get_background_display_name(bg) -> String`
- `get_origin_display_name(origin) -> String`

## GameEnums (Secondary — 80+ Enums)

Similar to GlobalEnums but with:
- Inline documentation comments on each enum
- Some streamlined versions (Background: 12 values vs GlobalEnums' 32)
- Additional enums: `CharacterStats` (7 values), `DeploymentType`, `ResourceType`

### Helper Methods
- `get_enum_string(enum_type, value) -> String`
- `size(enum_type) -> int`
- `get_equipment_type_from_string(equipment_string) -> int`
- `get_training_name(training) -> String`
- `get_character_class_name(class_type) -> String`

## Enum Sync Protocol

When adding/modifying an enum value:

1. **Identify which files contain the enum** — not all enums exist in all three files
2. **Add the value in all files** with the same name and numeric position
3. **Update display name dictionaries** (e.g., `CHARACTER_CLASS_NAMES`) in all files
4. **Update helper methods** that return string representations
5. **Run headless compile check**:
   ```
   & "C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" --headless --quit --path "c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager" 2>&1
   ```
6. **Search for consumers** — grep for the enum name across the codebase

## Common Sync Pitfalls

- GlobalEnums.CharacterClass has **30 values**; FiveParsecsGameEnums.CharacterClass has **15**. They overlap but are not identical
- GameEnums.Background has **12 values** (streamlined); GlobalEnums.Background has **32**
- Adding a value to one file without updating others causes silent enum mismatches
- String-based enum lookups (Character.gd uses String properties) can diverge from int-based lookups (BaseCharacterResource uses int properties)
