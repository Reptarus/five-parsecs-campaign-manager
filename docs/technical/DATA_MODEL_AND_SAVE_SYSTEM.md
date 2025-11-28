# Five Parsecs Campaign Manager - Data Model & Save System

## 📘 Introduction

This document details the data models, save file format, and persistence architecture of the Five Parsecs Campaign Manager.

**Related Documentation**:
- [System Architecture Deep Dive](SYSTEM_ARCHITECTURE_DEEP_DIVE.md) - Core systems
- [Data Architecture](data_architecture.md) - Data flow patterns

---

## 💾 Save File Format

### File Structure

**Save File Location**:
- **Windows**: `%APPDATA%\Godot\app_userdata\FiveParsecsCampaignManager\saves\`
- **macOS**: `~/Library/Application Support/Godot/app_userdata/FiveParsecsCampaignManager/saves/`
- **Linux**: `~/.local/share/godot/app_userdata/FiveParsecsCampaignManager/saves/`

**File Naming**: `<slot_name>.save`
- `autosave.save` - Automatic save after each phase
- `quicksave.save` - F5 quick save
- `manual_YYYY-MM-DD_HH-MM-SS.save` - Manual saves with timestamp
- Custom named saves: `<user_chosen_name>.save`

### JSON Structure

```json
{
  "version": "1.0.0",
  "save_timestamp": 1704567890,
  "game_version": "1.0.0-alpha",
  
  "campaign": {
    "campaign_name": "Fringe Runners",
    "difficulty": 1,
    "victory_conditions": {
      "TURNS_20": {"target": 20, "progress": 15},
      "WEALTH_100": {"target": 100, "progress": 45}
    },
    "current_turn": 15,
    "current_phase": 1,
    "credits": 45,
    "story_points": 3,
    "renown": 2,
    "battles_fought": 12,
    "battles_won": 10,
    "total_xp_earned": 156,
    "campaign_events_history": []
  },
  
  "crew": [
    {
      "character_id": "char_001",
      "character_name": "Sara Martinez",
      "species": 0,
      "background": 5,
      "class_type": 0,
      "motivation": 3,
      "reactions": 1,
      "speed": 5,
      "combat_skill": 2,
      "toughness": 4,
      "savvy": 1,
      "xp": 24,
      "level": 3,
      "abilities": [1, 5],
      "current_hp": 1,
      "max_hp": 1,
      "injuries": [
        {
          "injury_type": "bruised_ribs",
          "recovery_turns": 1,
          "stat_penalty": null
        }
      ],
      "is_down": false,
      "primary_weapon": "wpn_rifle_001",
      "secondary_weapon": null,
      "armor": "armor_flak_001",
      "gear": ["gear_medkit_001"],
      "portrait_id": "portrait_human_female_01"
    }
  ],
  
  "ship": {
    "ship_name": "Rusty Bucket",
    "hull_points": 25,
    "max_hull_points": 30,
    "cargo_capacity": 15,
    "current_cargo": 8,
    "upgrades": ["medical_bay", "cargo_expansion"],
    "debt": 15,
    "debt_origin": "legitimate_bank",
    "debt_interest_rate": 0.05
  },
  
  "world_state": {
    "current_world_id": "world_042",
    "current_world_name": "Proxima Station",
    "world_type": 1,
    "world_traits": [0, 4],
    "known_worlds": ["world_001", "world_023", "world_042"],
    "visited_worlds": ["world_001", "world_023", "world_042"],
    "patrons": [
      {
        "patron_id": "patron_001",
        "patron_name": "Captain Reeves",
        "patron_type": 2,
        "loyalty": 2,
        "jobs_completed": 3,
        "jobs_failed": 0,
        "current_world": "world_042"
      }
    ],
    "rivals": [
      {
        "rival_id": "rival_001",
        "rival_name": "Black Sun Syndicate",
        "rival_type": 4,
        "threat_level": 2,
        "encounters": 1,
        "last_encounter_result": "VICTORY"
      }
    ]
  },
  
  "quests": [
    {
      "quest_id": "quest_rescue_001",
      "quest_name": "Rescue Operation",
      "current_stage": 2,
      "stages_completed": [0, 1],
      "quest_data": {}
    }
  ],
  
  "inventory": {
    "equipped_items": {
      "char_001": {
        "primary": "wpn_rifle_001",
        "armor": "armor_flak_001",
        "gear": ["gear_medkit_001"]
      }
    },
    "stored_items": {
      "weapons": ["wpn_pistol_002", "wpn_blade_001"],
      "armor": [],
      "gear": ["gear_stim_001", "gear_stim_002"]
    }
  },
  
  "statistics": {
    "enemies_defeated": 45,
    "credits_earned_total": 234,
    "story_points_earned_total": 5,
    "characters_lost": 0,
    "missions_completed": 10,
    "missions_failed": 2,
    "worlds_visited": 3,
    "rivals_defeated": 1
  },
  
  "settings": {
    "progressive_difficulty": true,
    "difficulty_tier": 2,
    "story_track_enabled": true,
    "expanded_factions_enabled": true,
    "compendium_content": {
      "psionics": true,
      "new_species": true,
      "elite_enemies": false
    }
  }
}
```

### Required vs Optional Fields

**Required Fields** (save won't load without):
- `version`
- `campaign.campaign_name`
- `campaign.current_turn`
- `crew` (at least 1 character)
- `ship`
- `world_state.current_world_id`

**Optional Fields** (defaults applied):
- `campaign.victory_conditions` (default: {} - no specific victory condition)
- `campaign.renown` (default: 0)
- `campaign.story_points` (default: 0)
- `ship.upgrades` (default: [])
- `world_state.patrons` (default: [])
- `world_state.rivals` (default: [])
- `quests` (default: [])
- `statistics` (auto-calculated if missing)

---

## 📊 Data Models

### Campaign Data Model

```gdscript
class_name FiveParsecsCampaign extends Resource

# Core Identity
@export var campaign_name: String = ""
@export var difficulty: int = 1  # 0-4
@export var victory_conditions: Dictionary = {}  # Multi-select with custom targets

# Victory Conditions Schema:
# {
#   "VICTORY_TYPE": {
#     "target": int,      # Custom target value
#     "progress": int     # Current progress (auto-calculated)
#   }
# }
# Example: {"TURNS_20": {"target": 20, "progress": 15}, "WEALTH_100": {"target": 100, "progress": 45}}
# Victory is achieved when ANY condition reaches target (OR logic)

# Progress Tracking
@export var current_turn: int = 0
@export var current_phase: int = 0  # GlobalEnums.CampaignPhase
@export var credits: int = 0
@export var story_points: int = 0
@export var renown: int = 0

# Campaign State
@export var crew: Array[Character] = []
@export var ship: ShipData
@export var current_world: PlanetData
@export var known_worlds: Array[PlanetData] = []
@export var patrons: Array[PatronData] = []
@export var rivals: Array[RivalData] = []
@export var active_quests: Array[QuestData] = []

# Statistics
@export var battles_fought: int = 0
@export var battles_won: int = 0
@export var total_xp_earned: int = 0
@export var campaign_events_history: Array[Dictionary] = []
```

### Character Data Model

```gdscript
class_name Character extends Resource

# Identity
@export var character_id: String = ""
@export var character_name: String = ""
@export var species: int = 0  # GlobalEnums.Species
@export var background: int = 0
@export var class_type: int = 0
@export var motivation: int = 0

# Stats
@export var reactions: int = 1
@export var speed: int = 5
@export var combat_skill: int = 0
@export var toughness: int = 4
@export var savvy: int = 0

# Progression
@export var xp: int = 0
@export var level: int = 1
@export var abilities: Array[int] = []  # GlobalEnums.Ability

# Health
@export var current_hp: int = 1
@export var max_hp: int = 1
@export var injuries: Array[Dictionary] = []
@export var is_down: bool = false

# Equipment (references to inventory items)
@export var primary_weapon: String = ""  # Item ID
@export var secondary_weapon: String = ""
@export var armor: String = ""
@export var gear: Array[String] = []

# Visuals
@export var portrait_id: String = ""
```

### Ship Data Model

```gdscript
class_name ShipData extends Resource

# Identity
@export var ship_name: String = "Unnamed Vessel"

# Stats
@export var hull_points: int = 20
@export var max_hull_points: int = 20
@export var cargo_capacity: int = 10
@export var current_cargo: int = 0

# Upgrades
@export var upgrades: Array[String] = []  # Upgrade IDs

# Debt
@export var debt: int = 0
@export var debt_origin: String = ""
@export var debt_interest_rate: float = 0.0
@export var debt_enforcement_threshold: int = 0
```

### World Data Model

```gdscript
class_name PlanetData extends Resource

# Identity
@export var world_id: String = ""
@export var planet_name: String = ""

# Characteristics
@export var world_type: int = 0  # GlobalEnums.WorldType
@export var traits: Array[int] = []  # GlobalEnums.WorldTrait
@export var population: int = 0

# State
@export var is_invaded: bool = false
@export var invader_faction: String = ""
@export var instability: int = 0  # For Fringe World Strife

# Coordinates (for star map)
@export var x: float = 0.0
@export var y: float = 0.0
```

### Equipment Data Models

**Weapon**:
```gdscript
class_name WeaponResource extends Resource

@export var weapon_id: String = ""
@export var weapon_name: String = ""
@export var weapon_type: int = 0  # Pistol, Rifle, etc.
@export var range: int = 12  # In inches
@export var damage: int = 1
@export var shots: int = -1  # -1 = unlimited
@export var traits: Array[int] = []  # WeaponTrait enum
@export var cost: int = 0
@export var rarity: int = 0  # Common, Uncommon, Rare
```

**Armor**:
```gdscript
class_name ArmorResource extends Resource

@export var armor_id: String = ""
@export var armor_name: String = ""
@export var toughness_bonus: int = 1
@export var speed_penalty: int = 0
@export var cost: int = 0
```

**Gear**:
```gdscript
class_name GearResource extends Resource

@export var gear_id: String = ""
@export var gear_name: String = ""
@export var gear_type: int = 0  # Consumable, Tool, etc.
@export var effect_description: String = ""
@export var single_use: bool = false
@export var cost: int = 0
```

---

## 🔄 Save/Load Architecture

### SaveManager Workflow

```gdscript
# Saving
func save_campaign(campaign: Campaign, slot: String) -> bool:
    # 1. Serialize campaign to dictionary
    var save_data = serialize_campaign(campaign)
    
    # 2. Validate data integrity
    if not validate_save_data(save_data):
        return false
    
    # 3. Add metadata
    save_data["version"] = VERSION
    save_data["save_timestamp"] = Time.get_unix_time_from_system()
    save_data["game_version"] = get_game_version()
    
    # 4. Convert to JSON
    var json_string = JSON.stringify(save_data, "\t")
    
    # 5. Write to file
    var file_path = get_save_path(slot)
    var file = FileAccess.open(file_path, FileAccess.WRITE)
    if not file:
        push_error("Cannot write save file: " + file_path)
        return false
    
    file.store_string(json_string)
    file.close()
    
    # 6. Create backup
    create_backup(file_path)
    
    return true

# Loading
func load_campaign(slot: String) -> Campaign:
    # 1. Read file
    var file_path = get_save_path(slot)
    if not FileAccess.file_exists(file_path):
        push_error("Save file not found: " + slot)
        return null
    
    var file = FileAccess.open(file_path, FileAccess.READ)
    var json_string = file.get_as_text()
    file.close()
    
    # 2. Parse JSON
    var json = JSON.new()
    var error = json.parse(json_string)
    if error != OK:
        push_error("JSON parse error in save file")
        return attempt_recovery(file_path)
    
    var save_data = json.data
    
    # 3. Version migration (if needed)
    if save_data.version != VERSION:
        save_data = migrate_save_data(save_data)
    
    # 4. Validate
    if not validate_save_data(save_data):
        push_error("Save data validation failed")
        return attempt_recovery(file_path)
    
    # 5. Deserialize
    var campaign = deserialize_campaign(save_data)
    
    return campaign
```

### Serialization Process

```gdscript
func serialize_campaign(campaign: Campaign) -> Dictionary:
    return {
        "campaign": serialize_campaign_core(campaign),
        "crew": serialize_crew(campaign.crew),
        "ship": serialize_ship(campaign.ship),
        "world_state": serialize_world_state(campaign),
        "quests": serialize_quests(campaign.active_quests),
        "inventory": serialize_inventory(campaign),
        "statistics": serialize_statistics(campaign),
        "settings": serialize_settings(campaign)
    }

func serialize_character(character: Character) -> Dictionary:
    return {
        "character_id": character.character_id,
        "character_name": character.character_name,
        "species": character.species,
        "background": character.background,
        "class_type": character.class_type,
        "motivation": character.motivation,
        "reactions": character.reactions,
        "speed": character.speed,
        "combat_skill": character.combat_skill,
        "toughness": character.toughness,
        "savvy": character.savvy,
        "xp": character.xp,
        "level": character.level,
        "abilities": character.abilities,
        "current_hp": character.current_hp,
        "max_hp": character.max_hp,
        "injuries": character.injuries,
        "is_down": character.is_down,
        "primary_weapon": character.primary_weapon,
        "secondary_weapon": character.secondary_weapon,
        "armor": character.armor,
        "gear": character.gear,
        "portrait_id": character.portrait_id
    }
```

### Deserialization Process

```gdscript
func deserialize_campaign(data: Dictionary) -> Campaign:
    var campaign = FiveParsecsCampaign.new()
    
    # Core campaign data
    var campaign_data = data.get("campaign", {})
    campaign.campaign_name = campaign_data.get("campaign_name", "")
    campaign.difficulty = campaign_data.get("difficulty", 1)
    campaign.victory_conditions = campaign_data.get("victory_conditions", {})
    campaign.current_turn = campaign_data.get("current_turn", 0)
    campaign.current_phase = campaign_data.get("current_phase", 0)
    campaign.credits = campaign_data.get("credits", 0)
    campaign.story_points = campaign_data.get("story_points", 0)
    campaign.renown = campaign_data.get("renown", 0)
    
    # Crew
    var crew_data = data.get("crew", [])
    for char_data in crew_data:
        campaign.crew.append(deserialize_character(char_data))
    
    # Ship
    campaign.ship = deserialize_ship(data.get("ship", {}))
    
    # World state
    deserialize_world_state(campaign, data.get("world_state", {}))
    
    # Quests
    var quest_data = data.get("quests", [])
    for quest in quest_data:
        campaign.active_quests.append(deserialize_quest(quest))
    
    return campaign

func deserialize_character(data: Dictionary) -> Character:
    var character = Character.new()
    
    character.character_id = data.get("character_id", "")
    character.character_name = data.get("character_name", "Unknown")
    character.species = data.get("species", 0)
    character.background = data.get("background", 0)
    character.class_type = data.get("class_type", 0)
    character.motivation = data.get("motivation", 0)
    character.reactions = data.get("reactions", 1)
    character.speed = data.get("speed", 5)
    character.combat_skill = data.get("combat_skill", 0)
    character.toughness = data.get("toughness", 4)
    character.savvy = data.get("savvy", 0)
    character.xp = data.get("xp", 0)
    character.level = data.get("level", 1)
    character.abilities = data.get("abilities", [])
    character.current_hp = data.get("current_hp", 1)
    character.max_hp = data.get("max_hp", 1)
    character.injuries = data.get("injuries", [])
    character.is_down = data.get("is_down", false)
    character.primary_weapon = data.get("primary_weapon", "")
    character.secondary_weapon = data.get("secondary_weapon", "")
    character.armor = data.get("armor", "")
    character.gear = data.get("gear", [])
    character.portrait_id = data.get("portrait_id", "")
    
    return character
```

---

## 🔄 Versioning and Migration

### Save File Versioning

**Version Format**: `MAJOR.MINOR.PATCH`
- **MAJOR**: Breaking changes (incompatible format)
- **MINOR**: New fields added (backward compatible)
- **PATCH**: Bug fixes, no format changes

**Current Version**: `1.0.0`

### Migration System

```gdscript
func migrate_save_data(data: Dictionary) -> Dictionary:
    var from_version = data.get("version", "0.0.0")
    var current_version = VERSION
    
    if from_version == current_version:
        return data  # No migration needed
    
    # Chain migrations
    if version_less_than(from_version, "0.9.0"):
        data = migrate_0_8_to_0_9(data)
    
    if version_less_than(from_version, "1.0.0"):
        data = migrate_0_9_to_1_0(data)
    
    # Update version
    data["version"] = current_version
    
    return data

func migrate_0_9_to_1_0(data: Dictionary) -> Dictionary:
    # Example: Add new 'renown' field to campaign
    if not data.campaign.has("renown"):
        data.campaign["renown"] = 0
    
    # Example: Convert old injury format to new
    for character in data.crew:
        if character.has("old_injury_format"):
            character["injuries"] = convert_injury_format(character.old_injury_format)
            character.erase("old_injury_format")
    
    return data
```

### Backward Compatibility

**Guaranteed**:
- PATCH versions always backward compatible
- MINOR versions load older saves
- Missing optional fields use defaults

**Not Guaranteed**:
- MAJOR version changes may break compatibility
- User warned before loading incompatible save
- Migration attempted, but may fail

---

## 🛡️ Data Integrity and Validation

### Validation Checks

```gdscript
func validate_save_data(data: Dictionary) -> bool:
    # Version check
    if not data.has("version"):
        push_error("No version field in save data")
        return false
    
    # Required sections
    if not data.has("campaign") or not data.has("crew") or not data.has("ship"):
        push_error("Missing required save data sections")
        return false
    
    # Campaign validation
    if not validate_campaign_data(data.campaign):
        return false
    
    # Crew validation
    if not validate_crew_data(data.crew):
        return false
    
    # Ship validation
    if not validate_ship_data(data.ship):
        return false
    
    return true

func validate_campaign_data(campaign_data: Dictionary) -> bool:
    # Name present
    if not campaign_data.has("campaign_name") or campaign_data.campaign_name.is_empty():
        push_error("Campaign name missing")
        return false
    
    # Credits not negative
    if campaign_data.get("credits", 0) < 0:
        push_error("Invalid credits value: " + str(campaign_data.credits))
        return false
    
    # Turn number valid
    if campaign_data.get("current_turn", 0) < 0:
        push_error("Invalid turn number")
        return false
    
    # Difficulty in range
    var difficulty = campaign_data.get("difficulty", 1)
    if difficulty < 0 or difficulty > 4:
        push_error("Invalid difficulty: " + str(difficulty))
        return false
    
    return true

func validate_crew_data(crew_data: Array) -> bool:
    # At least 1 crew member
    if crew_data.size() < 1:
        push_error("No crew members in save")
        return false
    
    # Max 6 crew
    if crew_data.size() > 6:
        push_error("Too many crew members: " + str(crew_data.size()))
        return false
    
    # Validate each character
    for character in crew_data:
        if not validate_character_data(character):
            return false
    
    return true

func validate_character_data(char_data: Dictionary) -> bool:
    # Name present
    if not char_data.has("character_name"):
        push_error("Character missing name")
        return false
    
    # Stats in valid ranges
    if char_data.get("reactions", 1) < 0 or char_data.get("reactions", 1) > 5:
        return false
    
    if char_data.get("speed", 5) < 3 or char_data.get("speed", 5) > 8:
        return false
    
    if char_data.get("combat_skill", 0) < 0 or char_data.get("combat_skill", 0) > 3:
        return false
    
    if char_data.get("toughness", 4) < 3 or char_data.get("toughness", 4) > 6:
        return false
    
    if char_data.get("savvy", 0) < 0 or char_data.get("savvy", 0) > 3:
        return false
    
    return true
```

### Corruption Recovery

```gdscript
func attempt_recovery(corrupted_save_path: String) -> Campaign:
    push_warning("Attempting save recovery...")
    
    # 1. Check for backup
    var backup_path = corrupted_save_path + ".backup"
    if FileAccess.file_exists(backup_path):
        push_warning("Backup found, loading...")
        return load_campaign_from_path(backup_path)
    
    # 2. Check for autosave
    if corrupted_save_path != get_save_path("autosave"):
        push_warning("Trying autosave...")
        var autosave = load_campaign("autosave")
        if autosave:
            return autosave
    
    # 3. Try to recover partial data
    push_warning("Attempting partial data extraction...")
    var partial_data = extract_recoverable_data(corrupted_save_path)
    if partial_data:
        return construct_campaign_from_partial(partial_data)
    
    # Recovery failed
    push_error("Save recovery failed")
    return null
```

---

## 💻 Auto-Save System

### Auto-Save Triggers

**After Each Phase**:
```gdscript
func _on_phase_completed(phase: int) -> void:
    if phase == CampaignPhase.POST_BATTLE:
        # Save after completing post-battle
        SaveManager.save_campaign(current_campaign, "autosave")
```

**Before Critical Operations**:
```gdscript
func start_battle() -> void:
    # Auto-save before entering battle
    SaveManager.save_campaign(current_campaign, "pre_battle_autosave")
    _transition_to_battle()
```

**Periodic**:
```gdscript
var autosave_timer: Timer

func _ready() -> void:
    autosave_timer = Timer.new()
    autosave_timer.timeout.connect(_periodic_autosave)
    autosave_timer.wait_time = 300.0  # Every 5 minutes
    autosave_timer.start()

func _periodic_autosave() -> void:
    if CampaignManager.current_campaign:
        SaveManager.save_campaign(CampaignManager.current_campaign, "autosave")
```

### Auto-Save Settings

**User Configurable**:
- Auto-save enabled/disabled
- Auto-save frequency (1-10 minutes)
- Keep multiple auto-saves (rotation)
- Auto-save before battles (on/off)

---

## 📁 Save Slot Management

### Save Operations

```gdscript
# List all saves
func get_all_saves() -> Array[Dictionary]:
    var saves = []
    var save_dir = get_save_directory()
    
    var dir = DirAccess.open(save_dir)
    if not dir:
        return saves
    
    dir.list_dir_begin()
    var file_name = dir.get_next()
    
    while file_name != "":
        if file_name.ends_with(".save"):
            var metadata = load_save_metadata(file_name)
            saves.append(metadata)
        file_name = dir.get_next()
    
    return saves

# Load save metadata (without loading full campaign)
func load_save_metadata(slot: String) -> Dictionary:
    var file_path = get_save_path(slot)
    var file = FileAccess.open(file_path, FileAccess.READ)
    if not file:
        return {}
    
    var json_string = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    json.parse(json_string)
    var data = json.data
    
    return {
        "slot": slot,
        "campaign_name": data.campaign.campaign_name,
        "turn": data.campaign.current_turn,
        "credits": data.campaign.credits,
        "save_timestamp": data.save_timestamp,
        "game_version": data.game_version,
        "file_size": get_file_size(file_path)
    }

# Delete save
func delete_save(slot: String) -> bool:
    var file_path = get_save_path(slot)
    
    # Also delete backup if exists
    var backup_path = file_path + ".backup"
    if FileAccess.file_exists(backup_path):
        DirAccess.remove_absolute(backup_path)
    
    return DirAccess.remove_absolute(file_path) == OK

# Rename save
func rename_save(old_slot: String, new_slot: String) -> bool:
    var old_path = get_save_path(old_slot)
    var new_path = get_save_path(new_slot)
    
    if not FileAccess.file_exists(old_path):
        return false
    
    if FileAccess.file_exists(new_path):
        return false  # Destination already exists
    
    # Copy file
    DirAccess.copy_absolute(old_path, new_path)
    
    # Delete original
    DirAccess.remove_absolute(old_path)
    
    return true
```

---

## 🔒 Save File Security

### Encryption (Optional)

```gdscript
const ENCRYPTION_KEY = "your_encryption_key_here"

func save_encrypted(campaign: Campaign, slot: String) -> bool:
    var save_data = serialize_campaign(campaign)
    var json_string = JSON.stringify(save_data)
    
    # Encrypt
    var encrypted = encrypt_string(json_string, ENCRYPTION_KEY)
    
    # Write encrypted data
    var file = FileAccess.open(get_save_path(slot), FileAccess.WRITE)
    file.store_string(encrypted)
    file.close()
    
    return true
```

### Checksum Validation

```gdscript
func calculate_checksum(data: Dictionary) -> String:
    var json_string = JSON.stringify(data)
    return json_string.md5_text()

func save_with_checksum(campaign: Campaign, slot: String) -> bool:
    var save_data = serialize_campaign(campaign)
    var checksum = calculate_checksum(save_data)
    
    save_data["checksum"] = checksum
    
    # Save normally
    return save_campaign_data(save_data, slot)

func load_with_checksum_validation(slot: String) -> Campaign:
    var save_data = load_save_data(slot)
    
    var stored_checksum = save_data.get("checksum", "")
    save_data.erase("checksum")
    
    var calculated_checksum = calculate_checksum(save_data)
    
    if stored_checksum != calculated_checksum:
        push_error("Save file checksum mismatch - possible corruption")
        return attempt_recovery(get_save_path(slot))
    
    return deserialize_campaign(save_data)
```

---

## 🐛 Troubleshooting Save Issues

### Common Problems

**Save File Not Found**:
- Check save directory permissions
- Verify file path is correct
- Check for file system errors

**Corrupted Save**:
- Try loading backup
- Use recovery tools
- Check disk space

**Version Mismatch**:
- Migration should handle automatically
- If fails, save may be too old
- Export important data manually

**Permission Errors**:
- Run game with appropriate permissions
- Check antivirus isn't blocking
- Verify write access to save directory

---

*Last Updated: November 2025*
*Save Format Version: 1.1.0*
*Supports Backward Compatibility: Down to 0.9.0*
*Victory Conditions: Multi-select with custom targets (OR logic)*