# Five Parsecs Campaign Manager - System Architecture Deep Dive

## 📘 Introduction

This document provides comprehensive technical documentation of all core systems in the Five Parsecs Campaign Manager. It serves as the definitive reference for developers working on or extending the codebase.

**Related Documentation**:
- [Architecture Guide](ARCHITECTURE.md) - High-level patterns and design
- [API Reference](../developer/API_REFERENCE.md) - Interface specifications
- [Data Architecture](data_architecture.md) - Data flow and storage

---

## 🏗️ Core System Overview

### System Hierarchy

```
Campaign Manager
├── Character System
│   ├── CharacterCreator
│   ├── CharacterManager
│   └── Character (Resource)
├── Campaign System
│   ├── Campaign (Resource)
│   ├── CampaignManager
│   ├── CampaignPhaseManager
│   └── CampaignCreationManager
├── Combat System
│   ├── BattleManager
│   ├── BattlefieldManager
│   ├── EnemyAIManager
│   └── BattleResultsManager
├── Equipment System
│   ├── EquipmentManager
│   ├── WeaponSystem
│   └── ArmorSystem
├── World System
│   ├── PlanetDataManager
│   ├── ContactManager (Patrons/Rivals)
│   └── SectorManager
├── State Management
│   ├── SaveManager
│   ├── SecureSaveManager
│   └── GameStateManager
├── Dice & Random
│   ├── DiceManager
│   └── FallbackDiceManager
└── UI Systems
    ├── CampaignCreationUI
    ├── CampaignDashboard
    └── BattleUI
```

---

## 👤 Character System

### Character.gd (Resource)

**Location**: `src/core/character/Character.gd`
**Type**: Resource (extends RefCounted)
**Purpose**: Represents a single character with stats, equipment, and progression

**Core Properties**:
```gdscript
@export var character_name: String
@export var species: int  # GlobalEnums.Species
@export var background: int  # GlobalEnums.Background
@export var class_type: int  # GlobalEnums.CharacterClass

# Stats
@export var reactions: int = 1
@export var speed: int = 5
@export var combat_skill: int = 0
@export var toughness: int = 4
@export var savvy: int = 0

# Progression
@export var xp: int = 0
@export var level: int = 1
@export var abilities: Array[int] = []

# Equipment
@export var primary_weapon: Resource  # WeaponResource
@export var armor: Resource  # ArmorResource
@export var gear: Array[Resource] = []

# State
@export var current_hp: int = 1
@export var injuries: Array[Dictionary] = []
@export var is_down: bool = false
```

**Key Methods**:
- `apply_damage(amount: int) -> bool` - Reduce HP, check if down
- `make_toughness_save() -> bool` - Roll to resist damage
- `gain_xp(amount: int)` - Add XP, check for level up
- `level_up(choice: int)` - Apply level-up improvement
- `can_act() -> bool` - Check if character can take actions
- `get_initiative() -> int` - Calculate initiative (1D6 + Reactions)

**Signals**:
```gdscript
signal hp_changed(new_hp: int, old_hp: int)
signal went_down
signal xp_gained(amount: int)
signal leveled_up(new_level: int)
signal stat_changed(stat_name: String, new_value: int)
```

### CharacterCreator.gd

**Location**: `src/core/character/CharacterCreator.gd`
**Type**: RefCounted
**Purpose**: Handles character generation following Five Parsecs rules

**Creation Methods**:
```gdscript
# Quick random character
static func create_random_character() -> Character

# Step-by-step creation
static func roll_species() -> int
static func roll_background() -> int
static func determine_stats(species: int, background: int) -> Dictionary
static func roll_starting_equipment(background: int, credits: int) -> Array

# Full creation with choices
static func create_character_interactive(data: Dictionary) -> Character
```

**Character Generation Tables**:
- Species determination
- Background tables (50+ backgrounds)
- Motivation tables
- Class assignment
- Starting equipment by background
- Initial patron/rival rolls

**Digital Enhancements**:
- Validation at each step
- Illegal combinations prevented
- Equipment auto-assignment
- Portrait selection integration

### CharacterManager.gd

**Location**: `src/core/character/Management/CharacterManager.gd`
**Type**: Node (Autoload Singleton)
**Purpose**: Manages all characters in active campaign

**Core Responsibilities**:
- Character roster tracking
- Crew composition validation
- Character state persistence
- Equipment management across crew
- Injury tracking and recovery

**Key Methods**:
```gdscript
func add_character(character: Character) -> void
func remove_character(character: Character) -> void
func get_active_crew() -> Array[Character]
func get_injured_crew() -> Array[Character]
func advance_recovery_timers() -> void
func apply_crew_task_results(character: Character, task: int, result: Dictionary) -> void
```

**Crew Validation**:
- Minimum 4, maximum 6 crew members
- Species compatibility checks
- Equipment distribution validation
- Skill coverage analysis

---

## 🗺️ Campaign System

### Campaign.gd (Resource)

**Location**: `src/core/campaign/Campaign.gd`
**Type**: Resource (FiveParsecsCampaign)
**Purpose**: Root campaign data container

**Core Properties**:
```gdscript
@export var campaign_name: String
@export var difficulty: int = 1
@export var victory_conditions: Dictionary = {}  # Multi-select with custom targets
@export var current_turn: int = 0
@export var credits: int = 0
@export var story_points: int = 0
@export var renown: int = 0

# Campaign State
@export var current_world: Resource  # PlanetData
@export var known_worlds: Array[Resource] = []
@export var crew: Array[Resource] = []  # Characters
@export var ship: Resource  # ShipData
@export var patrons: Array[Resource] = []
@export var rivals: Array[Resource] = []
@export var active_quests: Array[Resource] = []

# Progress Tracking
@export var battles_fought: int = 0
@export var battles_won: int = 0
@export var total_xp_earned: int = 0
@export var worlds_visited: int = 0
```

**Campaign Phases** (from GlobalEnums):
```gdscript
enum CampaignPhase {
    TRAVEL,
    WORLD,
    BATTLE,
    POST_BATTLE
}
```

**Victory Condition Checks** (OR Logic - win when ANY condition achieved):
```gdscript
func check_victory_condition() -> Dictionary:
    # Returns {achieved: bool, condition: String, progress: float}
    for condition_type in victory_conditions.keys():
        var config = victory_conditions[condition_type]
        var target = config.get("target", 0)
        var current = get_progress_for_condition(condition_type)

        if current >= target:
            return {"achieved": true, "condition": condition_type, "progress": 1.0}

    return {"achieved": false, "condition": "", "progress": get_closest_progress()}

func get_progress_for_condition(condition_type: String) -> int:
    match condition_type:
        "TURNS_20", "TURNS_50", "TURNS_100":
            return current_turn
        "WEALTH_100":
            return credits
        "FAME_10":
            return renown
        "QUEST_VICTORY":
            return completed_quests
        # ... etc for all 17 victory types
```

**Victory Conditions Schema**:
```gdscript
# Multi-select Dictionary format
victory_conditions = {
    "TURNS_20": {"target": 20, "progress": 15},
    "WEALTH_100": {"target": 100, "progress": 45}
}
# User can select multiple conditions with custom target values
# Victory achieved when ANY condition reaches target (OR logic)
```

### CampaignManager.gd

**Location**: `src/core/managers/CampaignManager.gd`
**Type**: Node (Autoload Singleton)
**Purpose**: Campaign turn orchestration and state management

**Turn Sequence Control**:
```gdscript
func start_new_turn() -> void
func advance_phase() -> void
func complete_current_phase() -> void
func end_turn() -> void
```

**Phase Handlers**:
```gdscript
# Travel Phase
func handle_travel_phase() -> void:
    - Check for invasion flee
    - Process travel choice
    - Roll travel event if traveling
    - Update world state

# World Phase
func handle_world_phase() -> void:
    - Deduct upkeep
    - Heal injured crew (1 turn recovery)
    - Assign crew tasks
    - Resolve tasks
    - Generate job offers
    - Equipment assignment
    - Mission selection

# Battle Phase
func handle_battle_phase() -> void:
    - Setup battlefield
    - Deploy forces
    - Run combat
    - Track results

# Post-Battle Phase
func handle_post_battle_phase() -> void:
    - Update rival status
    - Update patron status
    - Check quest progress
    - Award pay
    - Battlefield finds
    - Loot collection
    - Injury rolls
    - XP awards
    - Shopping
    - Campaign events
    - Character events
    - Invasion check
```

**Event System Integration**:
```gdscript
signal turn_started(turn_number: int)
signal phase_changed(new_phase: int)
signal turn_completed(turn_number: int)
signal campaign_event_triggered(event_type: String, data: Dictionary)
```

### CampaignCreationManager.gd

**Location**: `src/core/campaign/CampaignCreationManager.gd`
**Purpose**: Wizard for creating new campaigns

**Creation Phases**:
1. Configuration (name, difficulty, victory condition)
2. Crew size selection
3. Character creation (per crew member)
4. Ship acquisition
5. Starting situation generation

**State Management**:
```gdscript
var creation_state: Dictionary = {
    "config": {},
    "crew_size": 0,
    "characters": [],
    "ship": null,
    "starting_world": null,
    "patrons": [],
    "rivals": [],
    "starting_credits": 0
}
```

**Validation at Each Step**:
- Configuration completeness
- Character validity (stats, equipment)
- Crew composition (4-6 members, legal combinations)
- Financial viability (can pay first turn upkeep)

**Integration Points**:
- CharacterCreator for crew generation
- Ship generator for initial vessel
- World generator for starting location
- Patron/Rival tables for initial relationships

---

## ⚔️ Combat System

### BattleManager.gd

**Location**: `src/core/battle/FPCM_BattleManager.gd`
**Type**: Node (Scene-specific)
**Purpose**: Battle orchestration and turn management

**Battle Lifecycle**:
```gdscript
# Initialization
func setup_battle(mission_data: Dictionary) -> void:
    - Load mission parameters
    - Generate battlefield
    - Deploy player crew
    - Deploy enemies
    - Initialize combat state

# Round Management
func start_round() -> void:
    - Roll initiative for all
    - Sort activation order
    - Reset round flags

func process_activation(character: Character) -> void:
    - Enable character controls
    - Wait for player action (or AI)
    - Execute action
    - Update battlefield state

func end_round() -> void:
    - Check victory/defeat
    - Update effects
    - Prepare next round or end battle

# Resolution
func end_battle(result: String) -> void:
    - Calculate outcomes
    - Award XP
    - Track casualties
    - Return to campaign
```

**Combat State Tracking**:
```gdscript
var combat_state: Dictionary = {
    "round_number": 0,
    "active_character": null,
    "activation_order": [],
    "acted_this_round": [],
    "player_characters": [],
    "enemy_characters": [],
    "objectives_completed": [],
    "morale_checks_passed": 0
}
```

**Victory/Defeat Conditions**:
- Mission objective completed
- All enemies defeated/fled
- All player characters down (defeat)
- Voluntary withdrawal

### BattlefieldManager.gd

**Location**: `src/core/battle/BattlefieldManager.gd`
**Purpose**: Terrain, cover, and positioning

**Battlefield Generation**:
```gdscript
func generate_battlefield(world_type: int, density: float) -> void:
    - Create terrain based on world type
    - Place cover (light, heavy, solid)
    - Add obstacles and elevation
    - Position objective markers
    - Designate deployment zones
```

**Cover System**:
```gdscript
enum CoverType {
    NONE,
    LIGHT,  # -1 to hit
    HEAVY,  # -2 to hit
    SOLID   # Blocks LOS
}

func check_cover(position: Vector2, from_position: Vector2) -> int:
    - Raycast from attacker to target
    - Check intersecting terrain
    - Return highest cover value
```

**Line of Sight**:
```gdscript
func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
    - Raycast between positions
    - Check for blocking terrain
    - Check for blocking figures
    - Return true if clear path

func calculate_range(from: Vector2, to: Vector2) -> float:
    - Euclidean distance
    - Convert to tabletop inches
```

**Movement Validation**:
```gdscript
func can_move_to(character: Character, target_position: Vector2) -> bool:
    - Check movement distance vs Speed
    - Validate terrain is passable
    - Check for blocking figures
    - Account for difficult terrain

func get_movement_cost(from: Vector2, to: Vector2) -> float:
    - Base distance
    - Terrain modifiers (difficult ground, climbing)
    - Return total cost in inches
```

### EnemyAIManager.gd

**Location**: `src/core/managers/EnemyAIManager.gd`
**Purpose**: AI decision-making for enemy combatants

**AI Behavior Types**:
```gdscript
enum AIBehavior {
    AGGRESSIVE,   # Charge toward enemies
    DEFENSIVE,    # Use cover, shoot from range
    TACTICAL,     # Flank, focus fire
    BEAST         # Direct charge, brawl-focused
}
```

**Decision Tree**:
```gdscript
func determine_action(enemy: Character) -> Dictionary:
    # 1. Check if in immediate danger
    if is_threatened(enemy):
        return seek_cover_action(enemy)
    
    # 2. Check if can attack
    var targets = get_visible_targets(enemy)
    if targets.size() > 0:
        var best_target = select_target(enemy, targets)
        if can_shoot(enemy, best_target):
            return shoot_action(enemy, best_target)
        else:
            return move_to_shoot_action(enemy, best_target)
    
    # 3. Move toward objective
    return move_to_objective_action(enemy)
```

**Target Selection**:
```gdscript
func select_target(attacker: Character, targets: Array) -> Character:
    var priorities = []
    
    for target in targets:
        var score = 0
        score += 10 if target.current_hp < target.max_hp  # Wounded
        score += 5 if target.armor == null  # Unarmored
        score -= calculate_range(attacker, target) / 2  # Closer is better
        score += 3 if is_in_cover(target) == false  # Exposed
        
        priorities.append({"target": target, "score": score})
    
    priorities.sort_custom(func(a, b): return a.score > b.score)
    return priorities[0].target
```

**Morale System**:
```gdscript
func check_enemy_morale() -> bool:
    var casualties = count_enemy_casualties()
    var total = get_total_enemies()
    
    if casualties / float(total) >= 0.5:  # 50% casualties
        return try_flee()
    
    return false  # Continue fighting
```

---

## 🎒 Equipment System

### EquipmentManager.gd

**Location**: `src/core/equipment/EquipmentManager.gd`
**Purpose**: Equipment database and transactions

**Equipment Types**:
```gdscript
# Weapons
class WeaponResource extends Resource:
    @export var weapon_name: String
    @export var weapon_type: int  # Pistol, Rifle, etc.
    @export var range: int  # In inches
    @export var damage: int = 1
    @export var shots: int = -1  # -1 = unlimited
    @export var traits: Array[int] = []  # Piercing, Area, etc.
    @export var cost: int

# Armor
class ArmorResource extends Resource:
    @export var armor_name: String
    @export var toughness_bonus: int  # +1 or +2
    @export var speed_penalty: int = 0
    @export var cost: int

# Gear
class GearResource extends Resource:
    @export var gear_name: String
    @export var gear_type: int  # Consumable, Tool, etc.
    @export var effect: String  # Description
    @export var single_use: bool = false
    @export var cost: int
```

**Market System**:
```gdscript
func generate_market(world_type: int, world_traits: Array) -> Array:
    var available_items = []
    
    # Base items always available
    available_items.append_array(get_common_items())
    
    # World type affects selection
    match world_type:
        WorldType.INDUSTRIAL:
            available_items.append_array(get_industrial_items())
        WorldType.FRONTIER:
            available_items.append_array(get_frontier_items())
        WorldType.COLONY:
            available_items.append_array(get_colony_items())
    
    # Traits modify availability
    if "Busy Markets" in world_traits:
        available_items.append_array(roll_bonus_items())
    
    return available_items
```

**Equipment Transactions**:
```gdscript
func purchase_item(item: Resource, buyer: Character, campaign: Campaign) -> bool:
    if campaign.credits < item.cost:
        return false  # Cannot afford
    
    campaign.credits -= item.cost
    assign_equipment_to_character(item, buyer)
    emit_signal("item_purchased", item, buyer)
    return true

func sell_item(item: Resource, seller: Character, campaign: Campaign) -> void:
    var sell_price = item.cost / 2  # Sell for half value
    campaign.credits += sell_price
    remove_equipment_from_character(item, seller)
    emit_signal("item_sold", item, seller, sell_price)
```

### Weapon Combat Resolution

**Shooting**:
```gdscript
func resolve_shot(attacker: Character, target: Character, weapon: WeaponResource, battlefield: BattlefieldManager) -> Dictionary:
    # Step 1: Determine Target Number
    var base_tn = 5
    var range_mod = calculate_range_modifier(attacker, target, weapon)
    var cover_mod = battlefield.check_cover(target.position, attacker.position)
    var target_number = base_tn + range_mod + cover_mod
    
    # Step 2: Roll to Hit
    var roll = DiceManager.roll_d6()
    var combat_modifier = attacker.combat_skill
    var total = roll + combat_modifier
    
    # Step 3: Check Hit
    if total >= target_number or roll == 6:  # Natural 6 always hits
        return resolve_damage(target, weapon)
    else:
        return {"hit": false, "result": "Miss"}
```

**Damage Resolution**:
```gdscript
func resolve_damage(target: Character, weapon: WeaponResource) -> Dictionary:
    # Roll Toughness Save
    var save_roll = DiceManager.roll_d6()
    var toughness = target.toughness
    
    # Apply armor bonus
    if target.armor != null:
        toughness += target.armor.toughness_bonus
    
    # Check for piercing trait
    if weapon.has_trait(WeaponTrait.PIERCING):
        toughness -= weapon.get_trait_value(WeaponTrait.PIERCING)
    
    if save_roll <= toughness:
        return {"hit": true, "damage_dealt": 0, "result": "Saved"}
    else:
        target.apply_damage(weapon.damage)
        return {"hit": true, "damage_dealt": weapon.damage, "result": "Wounded"}
```

---

## 🌍 World System

### PlanetDataManager.gd

**Location**: `src/core/world/PlanetDataManager.gd`
**Purpose**: World generation and trait management

**Planet Data**:
```gdscript
class PlanetData extends Resource:
    @export var planet_name: String
    @export var world_type: int  # Colony, Industrial, etc.
    @export var traits: Array[int] = []  # Busy Markets, Dangerous, etc.
    @export var population: int
    @export var is_invaded: bool = false
    @export var instability: int = 0  # For Fringe World Strife
```

**World Generation**:
```gdscript
func generate_random_world() -> PlanetData:
    var world = PlanetData.new()
    world.planet_name = NameGenerator.generate_planet_name()
    world.world_type = roll_world_type()
    world.traits = roll_world_traits(world.world_type)
    world.population = determine_population(world.world_type)
    return world
```

**World Traits System**:
```gdscript
enum WorldTrait {
    BUSY_MARKETS,        # More equipment available
    DANGEROUS,           # More hostile encounters
    RESTRICTED,          # Weapon regulations
    WEALTHY,             # Higher mission pay
    MEDICAL_HUB,         # Better healing
    TECH_CENTER,         # Advanced equipment
    LAWLESS,             # No restrictions
    ADVENTUROUS,         # More opportunities
    VENDETTA_SYSTEM      # Rival activity increased
}

func apply_trait_effects(world: PlanetData, campaign: Campaign) -> void:
    for trait in world.traits:
        match trait:
            WorldTrait.BUSY_MARKETS:
                expand_market_selection()
            WorldTrait.MEDICAL_HUB:
                reduce_injury_recovery_time()
            WorldTrait.RESTRICTED:
                enforce_weapon_licenses()
```

### ContactManager.gd

**Location**: `src/core/world/ContactManager.gd`
**Purpose**: Patron and Rival relationship management

**Contact Types**:
```gdscript
class PatronData extends Resource:
    @export var patron_name: String
    @export var patron_type: int  # Merchant, Military, Corporate, etc.
    @export var loyalty: int = 0  # -5 to +5
    @export var jobs_completed: int = 0
    @export var jobs_failed: int = 0
    @export var current_world: String

class RivalData extends Resource:
    @export var rival_name: String
    @export var rival_type: int  # Personal Enemy, Gang, Corporation, etc.
    @export var threat_level: int = 1  # 1-5
    @export var encounters: int = 0
    @export var last_encounter_result: String  # "Victory", "Defeat", "Fled"
```

**Relationship Progression**:
```gdscript
func update_patron_loyalty(patron: PatronData, mission_result: String) -> void:
    match mission_result:
        "SUCCESS":
            patron.loyalty = min(patron.loyalty + 1, 5)
            patron.jobs_completed += 1
        "FAILURE":
            patron.loyalty = max(patron.loyalty - 1, -5)
            patron.jobs_failed += 1
    
    # Check for patron dismissal
    if patron.loyalty <= -3:
        dismiss_patron(patron)
    
    # Check for special rewards
    if patron.loyalty >= 3 and patron.jobs_completed % 5 == 0:
        award_loyalty_bonus(patron)
```

**Rival Encounters**:
```gdscript
func trigger_rival_encounter(rival: RivalData) -> Dictionary:
    rival.encounters += 1
    
    var mission = {
        "type": "RIVAL_ENCOUNTER",
        "rival": rival,
        "objective": determine_rival_objective(rival),
        "difficulty": rival.threat_level,
        "pay": 0  # No pay for rival fights
    }
    
    return mission

func resolve_rival_encounter(rival: RivalData, result: String) -> void:
    rival.last_encounter_result = result
    
    match result:
        "VICTORY":
            rival.threat_level = max(rival.threat_level - 1, 1)
            # Chance to convert to patron
            if DiceManager.roll_d6() >= 5:
                convert_rival_to_patron(rival)
        "DEFEAT":
            rival.threat_level = min(rival.threat_level + 1, 5)
        "FLED":
            # Rival becomes more aggressive
            rival.threat_level += 1
```

---

## 💾 State Management System

### SaveManager.gd

**Location**: `src/core/state/SaveManager.gd`
**Type**: Autoload Singleton
**Purpose**: Campaign save/load operations

**Save File Structure**:
```gdscript
{
    "version": "1.0.0",
    "timestamp": 1234567890,
    "campaign": {
        "name": "My Campaign",
        "turn": 15,
        "credits": 45,
        "story_points": 3,
        ...
    },
    "crew": [
        {
            "name": "Sara Martinez",
            "species": 0,  # Human
            "stats": {...},
            "equipment": [...],
            ...
        },
        ...
    ],
    "ship": {...},
    "world_state": {...},
    "battle_history": [...]
}
```

**Save Operations**:
```gdscript
func save_campaign(campaign: Campaign, slot: String = "autosave") -> bool:
    var save_data = serialize_campaign(campaign)
    var save_path = get_save_path(slot)
    
    # Validate data before saving
    if not validate_save_data(save_data):
        push_error("Save data validation failed")
        return false
    
    # Write to file
    var file = FileAccess.open(save_path, FileAccess.WRITE)
    if file == null:
        push_error("Cannot open save file: " + save_path)
        return false
    
    file.store_string(JSON.stringify(save_data, "\t"))
    file.close()
    
    emit_signal("campaign_saved", slot)
    return true

func load_campaign(slot: String) -> Campaign:
    var save_path = get_save_path(slot)
    
    if not FileAccess.file_exists(save_path):
        push_error("Save file not found: " + save_path)
        return null
    
    var file = FileAccess.open(save_path, FileAccess.READ)
    var json_string = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var parse_result = json.parse(json_string)
    
    if parse_result != OK:
        push_error("Failed to parse save file")
        return null
    
    var save_data = json.data
    return deserialize_campaign(save_data)
```

**Auto-Save System**:
```gdscript
func enable_autosave() -> void:
    # Auto-save after each major phase
    CampaignManager.phase_completed.connect(_on_phase_completed)

func _on_phase_completed(phase: int) -> void:
    if phase == CampaignPhase.POST_BATTLE:
        save_campaign(CampaignManager.current_campaign, "autosave")
```

**Save Slot Management**:
```gdscript
func get_all_saves() -> Array[Dictionary]:
    var saves = []
    var save_dir = DirAccess.open(get_save_directory())
    
    if save_dir:
        save_dir.list_dir_begin()
        var file_name = save_dir.get_next()
        
        while file_name != "":
            if file_name.ends_with(".save"):
                var metadata = load_save_metadata(file_name)
                saves.append(metadata)
            file_name = save_dir.get_next()
    
    return saves

func delete_save(slot: String) -> bool:
    var save_path = get_save_path(slot)
    return DirAccess.remove_absolute(save_path) == OK
```

### SecureSaveManager.gd

**Location**: `src/core/validation/SecureSaveManager.gd`
**Purpose**: Save data validation and corruption prevention

**Validation Checks**:
```gdscript
func validate_save_data(data: Dictionary) -> bool:
    # Version compatibility
    if not check_version_compatibility(data.get("version", "")):
        return false
    
    # Required fields present
    var required_fields = ["campaign", "crew", "ship"]
    for field in required_fields:
        if not data.has(field):
            push_error("Missing required field: " + field)
            return false
    
    # Data integrity
    if not validate_campaign_data(data.campaign):
        return false
    
    if not validate_crew_data(data.crew):
        return false
    
    return true

func validate_campaign_data(campaign_data: Dictionary) -> bool:
    # Check credits aren't negative
    if campaign_data.get("credits", 0) < 0:
        push_error("Invalid credits value")
        return false
    
    # Check turn number is valid
    if campaign_data.get("turn", 0) < 0:
        push_error("Invalid turn number")
        return false
    
    # Validate victory conditions (multi-select Dictionary)
    var victory_conditions = campaign_data.get("victory_conditions", {})
    if not is_valid_victory_conditions(victory_conditions):
        return false

    return true

func is_valid_victory_conditions(conditions: Dictionary) -> bool:
    # Empty is valid (no victory conditions set)
    if conditions.is_empty():
        return true

    # Each condition must have valid target
    for condition_type in conditions.keys():
        var config = conditions[condition_type]
        if not config is Dictionary:
            return false
        if not config.has("target"):
            return false
        if config.get("target", 0) <= 0:
            return false

    return true
```

**Corruption Recovery**:
```gdscript
func attempt_recovery(corrupted_save_path: String) -> Campaign:
    # Try to extract partial data
    var backup_path = corrupted_save_path + ".backup"
    
    if FileAccess.file_exists(backup_path):
        return load_campaign_from_path(backup_path)
    
    # Try to reconstruct from recent autosaves
    var recent_saves = get_recent_saves()
    if recent_saves.size() > 0:
        return load_campaign_from_path(recent_saves[0])
    
    return null  # Cannot recover
```

---

## 🎲 Dice and Random Systems

### DiceManager.gd

**Location**: `src/core/managers/DiceManager.gd`
**Type**: Autoload Singleton
**Purpose**: Random number generation and dice rolling

**Core Dice Functions**:
```gdscript
func roll_d6() -> int:
    return randi_range(1, 6)

func roll_2d6() -> int:
    return roll_d6() + roll_d6()

func roll_d3() -> int:
    var d6_result = roll_d6()
    if d6_result <= 2:
        return 1
    elif d6_result <= 4:
        return 2
    else:
        return 3

func roll_multiple_d6(count: int) -> Array[int]:
    var results = []
    for i in range(count):
        results.append(roll_d6())
    return results
```

**Table Lookups**:
```gdscript
func roll_on_table(table: Array) -> Variant:
    var roll = roll_d6()
    return table[roll - 1]  # Arrays are 0-indexed

func roll_on_2d6_table(table: Dictionary) -> Variant:
    var roll = roll_2d6()
    return table.get(roll, table.get("default"))
```

**Randomization Options**:
```gdscript
# Seeded random for deterministic results
func set_seed(seed_value: int) -> void:
    seed(seed_value)

# Weighted random
func roll_weighted(weights: Array[float]) -> int:
    var total_weight = weights.reduce(func(a, b): return a + b, 0.0)
    var random_value = randf() * total_weight
    var cumulative = 0.0
    
    for i in range(weights.size()):
        cumulative += weights[i]
        if random_value <= cumulative:
            return i
    
    return weights.size() - 1
```

**Dice Logging** (for transparency):
```gdscript
signal dice_rolled(dice_type: String, result: int, context: String)

func roll_d6_logged(context: String = "") -> int:
    var result = roll_d6()
    emit_signal("dice_rolled", "1D6", result, context)
    return result
```

---

## 🔗 System Integration

### Autoload Singletons

**Initialization Order** (defined in `project.godot`):
1. **GlobalEnums** - Enum definitions (no dependencies)
2. **DiceManager** - Random generation (depends on GlobalEnums)
3. **DataManager** - Data loading (depends on GlobalEnums)
4. **SaveManager** - Save/load (depends on DataManager)
5. **CampaignManager** - Campaign orchestration (depends on all above)
6. **CharacterManager** - Character management (depends on CampaignManager)
7. **EquipmentManager** - Equipment database (depends on DataManager)

**Cross-System Communication**:
```gdscript
# Example: Combat result affecting campaign
# BattleManager emits signal
battle_manager.battle_completed.connect(_on_battle_completed)

func _on_battle_completed(result: Dictionary):
    # CampaignManager receives and processes
    CampaignManager.process_battle_results(result)
    
    # CharacterManager updates crew
    CharacterManager.apply_injuries(result.casualties)
    CharacterManager.award_xp(result.participants, result.xp_earned)
    
    # SaveManager auto-saves
    SaveManager.autosave()
```

### Signal Architecture

**Campaign-Level Signals**:
```gdscript
# CampaignManager
signal turn_started(turn: int)
signal phase_changed(phase: int)
signal credits_changed(amount: int, new_total: int)
signal story_points_changed(new_total: int)
signal campaign_event(event_type: String, data: Dictionary)
```

**Character-Level Signals**:
```gdscript
# Character
signal hp_changed(new_hp: int)
signal went_down
signal recovered
signal xp_gained(amount: int)
signal leveled_up(new_level: int)
```

**Battle Signals**:
```gdscript
# BattleManager
signal round_started(round_number: int)
signal character_activated(character: Character)
signal combat_action_executed(action_type: String, result: Dictionary)
signal battle_ended(victory: bool)
```

---

## 📊 Performance Considerations

### Resource Pooling

**Character Portrait Pool**:
```gdscript
class PortraitPool:
    var available_portraits: Array[Texture2D] = []
    var active_portraits: Dictionary = {}
    
    func get_portrait(character_id: String) -> Texture2D:
        if active_portraits.has(character_id):
            return active_portraits[character_id]
        
        var portrait = load_from_pool_or_disk()
        active_portraits[character_id] = portrait
        return portrait
    
    func release_portrait(character_id: String) -> void:
        if active_portraits.has(character_id):
            available_portraits.append(active_portraits[character_id])
            active_portraits.erase(character_id)
```

### Memory Management

**Large Data Lazy Loading**:
```gdscript
# DataManager loads data on-demand
var _equipment_database: Dictionary = {}
var _equipment_loaded: bool = false

func get_equipment_data() -> Dictionary:
    if not _equipment_loaded:
        _equipment_database = load_equipment_from_json()
        _equipment_loaded = true
    return _equipment_database
```

### Optimization Patterns

**Caching Expensive Calculations**:
```gdscript
# Cache line of sight results
var _los_cache: Dictionary = {}

func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
    var cache_key = "%v_%v" % [from, to]
    
    if _los_cache.has(cache_key):
        return _los_cache[cache_key]
    
    var result = _calculate_los(from, to)
    _los_cache[cache_key] = result
    return result

func clear_los_cache() -> void:
    _los_cache.clear()  # Clear when battlefield changes
```

---

*Last Updated: November 2025*
*System Version: 1.1.0-beta*
*Total Core Systems: 32+*
*Victory Conditions: Multi-select with custom targets (OR logic)*