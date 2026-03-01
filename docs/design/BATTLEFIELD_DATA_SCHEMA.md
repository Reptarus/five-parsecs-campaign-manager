# Battlefield Generator Data Schema Design

**Author**: Campaign Data Architect
**Date**: 2025-11-29
**Godot Version**: 4.6
**Schema Version**: 1

---

## Design Principles

### 1. Resources Are Immutable Value Objects
- All battlefield data structures extend `Resource` for save/load compatibility
- No direct mutation during generation - use Command pattern for procedural generation
- Deep copy before serialization to prevent reference corruption

### 2. ID References Prevent Circular Dependencies
- Use String UUIDs for all entity references (`terrain_id`, `enemy_id`, `unique_individual_id`)
- Lookup services resolve IDs at runtime (BattlefieldManager resolves terrain_id → TerrainFeature)
- Pattern: `weapon_table_id: String` not `weapon: WeaponResource`

### 3. Procedurally Reproducible
- All generation driven by `generation_seed: int`
- Same seed + same mission data = identical battlefield every time
- Enables save/load of battlefield state without storing entire grid

### 4. Flat Data Structures
- Maximum 2 levels of Resource inheritance
- Composition over inheritance (e.g., EnemyDeployment contains Array of enemy_ids, not Enemy objects)
- Behavior driven by data (AI type enum) not class hierarchy

---

## Core Data Structures

### BattlefieldGenerationContext (Resource)
**Purpose**: Input parameters for battlefield generation
**Lifecycle**: Created at mission start, discarded after generation
**Save/Load**: Not persisted (recreated from mission seed)

```gdscript
class_name BattlefieldGenerationContext
extends Resource

## Immutable generation parameters
@export var generation_seed: int = 0  # Procedural seed for reproducibility
@export var mission_type: String = "patrol"  # From mission resource
@export var terrain_theme: String = "urban"  # "urban", "wilderness", "spaceport", "industrial"
@export var battlefield_size: Vector2i = Vector2i(36, 24)  # Standard Five Parsecs size
@export var crew_size: int = 4  # Affects enemy count
@export var difficulty: int = 2  # 1-5 difficulty modifier
@export var special_conditions: Array[String] = []  # ["low_visibility", "debris_field"]

## Mission-specific overrides (from mission resource)
@export var force_terrain_features: Array[String] = []  # ["water_crossing", "bunker"]
@export var force_objective_count: int = -1  # -1 = auto-calculate
@export var deployment_variant: String = "standard"  # "standard", "ambush", "surrounded"

## Validation
func is_valid() -> bool:
    return generation_seed > 0 and not terrain_theme.is_empty() and crew_size > 0
```

---

### TerrainFeatureData (Resource)
**Purpose**: Single terrain feature (cover, elevation, difficult terrain)
**Lifecycle**: Created during generation, persisted in save files
**Save/Load**: Fully serializable via @export properties

```gdscript
class_name TerrainFeatureData
extends Resource

## Unique identification
@export var terrain_id: String = ""  # UUID: "terrain_rock_pile_1234567890"
@export var feature_type: String = ""  # "cover_large", "elevation", "difficult_terrain", "linear_wall"

## Positioning (grid coordinates)
@export var positions: Array[Vector2i] = []  # Cells occupied by this feature
@export var center_position: Vector2i = Vector2i(-1, -1)  # For placement hints

## Five Parsecs Rulebook Properties (p.88-92)
@export var cover_value: int = 0  # 0 = none, 1 = soft cover, 2 = hard cover
@export var blocks_los: bool = false  # Does it block line of sight?
@export var movement_cost_multiplier: float = 1.0  # 1.0 = normal, 2.0 = difficult
@export var is_impassable: bool = false  # Cannot be crossed at all

## Display data (for UI/visualization)
@export var display_name: String = ""  # "Rocky Outcrop"
@export var description: String = ""  # "Provides hard cover and elevated firing position"
@export var sprite_id: String = ""  # Asset reference (future: for 3D visualization)

## Procedural generation metadata (NOT saved)
var source_json_id: String = ""  # Reference to data/battlefield/features/*.json
var placement_tags: Array[String] = []  # ["urban", "large", "scatter"]

## Factory methods for standard types
static func create_cover_large(seed: int, position: Vector2i) -> TerrainFeatureData:
    var feature := TerrainFeatureData.new()
    feature.terrain_id = "terrain_cover_large_%d" % seed
    feature.feature_type = "cover_large"
    feature.center_position = position
    feature.positions = [position, position + Vector2i(1, 0), position + Vector2i(0, 1)]
    feature.cover_value = 2
    feature.blocks_los = true
    feature.movement_cost_multiplier = 1.0
    feature.display_name = "Large Cover"
    feature.description = "Concrete barrier providing hard cover"
    return feature

static func create_difficult_terrain(seed: int, position: Vector2i, size: int = 2) -> TerrainFeatureData:
    var feature := TerrainFeatureData.new()
    feature.terrain_id = "terrain_difficult_%d" % seed
    feature.feature_type = "difficult_terrain"
    feature.center_position = position
    feature.movement_cost_multiplier = 2.0
    feature.display_name = "Rough Ground"
    feature.description = "Debris field slowing movement"

    # Generate 2x2 area
    for x in range(size):
        for y in range(size):
            feature.positions.append(position + Vector2i(x, y))

    return feature

## Serialization (automatic via @export)
func to_dict() -> Dictionary:
    return {
        "terrain_id": terrain_id,
        "feature_type": feature_type,
        "positions": positions.map(func(v): return {"x": v.x, "y": v.y}),
        "center_position": {"x": center_position.x, "y": center_position.y},
        "cover_value": cover_value,
        "blocks_los": blocks_los,
        "movement_cost_multiplier": movement_cost_multiplier,
        "is_impassable": is_impassable,
        "display_name": display_name,
        "description": description
    }

static func from_dict(data: Dictionary) -> TerrainFeatureData:
    var feature := TerrainFeatureData.new()
    feature.terrain_id = data.get("terrain_id", "")
    feature.feature_type = data.get("feature_type", "")
    feature.cover_value = data.get("cover_value", 0)
    feature.blocks_los = data.get("blocks_los", false)
    feature.movement_cost_multiplier = data.get("movement_cost_multiplier", 1.0)
    feature.is_impassable = data.get("is_impassable", false)
    feature.display_name = data.get("display_name", "")
    feature.description = data.get("description", "")

    # Deserialize positions
    var pos_array = data.get("positions", [])
    for pos_data in pos_array:
        if pos_data is Dictionary:
            feature.positions.append(Vector2i(pos_data.get("x", 0), pos_data.get("y", 0)))

    var center = data.get("center_position", {})
    if center is Dictionary:
        feature.center_position = Vector2i(center.get("x", -1), center.get("y", -1))

    return feature
```

---

### EnemyDeploymentData (Resource)
**Purpose**: Enemy force composition and positioning
**Lifecycle**: Created during mission setup, persisted in save files
**Save/Load**: Fully serializable

```gdscript
class_name EnemyDeploymentData
extends Resource

## Enemy force metadata
@export var deployment_id: String = ""  # UUID: "deployment_1234567890"
@export var enemy_category: String = ""  # From enemy_types.json: "raiders", "corporate_security"
@export var total_enemy_count: int = 0  # Calculated from crew size + difficulty

## Unit composition (ID references to avoid circular deps)
@export var basic_enemy_ids: Array[String] = []  # ["enemy_raider_01", "enemy_raider_02"]
@export var specialist_enemy_ids: Array[String] = []  # ["enemy_raider_specialist_01"]
@export var lieutenant_id: String = ""  # Elite enemy types only
@export var captain_id: String = ""  # Elite enemy types only
@export var unique_individual_id: String = ""  # If rolled (9+ on 1d10)

## Deployment positions (resolved at runtime)
@export var deployment_zone: Array[Vector2i] = []  # Available deployment cells
@export var assigned_positions: Dictionary = {}  # {"enemy_raider_01": Vector2i(34, 12)}

## AI behavior settings (Five Parsecs p.102-105)
@export var ai_type: String = "A"  # "A" (Aggressive), "T" (Tactical), "C" (Cautious), "D" (Defensive), "R" (Rampaging), "G" (Guardian)
@export var special_rules: Array[String] = []  # ["Stubborn", "Alert", "Careless"]

## Morale tracking
@export var panic_range: String = "1-2"  # "1", "1-2", "1-3"
@export var is_fearless: bool = false  # Lieutenants/Captains/Unique

## Factory method
static func create_standard_deployment(context: BattlefieldGenerationContext, rng: RandomNumberGenerator) -> EnemyDeploymentData:
    var deployment := EnemyDeploymentData.new()
    deployment.deployment_id = "deployment_%d" % Time.get_unix_time_from_system()
    deployment.enemy_category = "raiders"  # Example
    deployment.total_enemy_count = _calculate_enemy_count(context.crew_size, context.difficulty, rng)
    deployment.ai_type = "A"
    deployment.panic_range = "1-2"
    return deployment

static func _calculate_enemy_count(crew_size: int, difficulty: int, rng: RandomNumberGenerator) -> int:
    # Five Parsecs p.63 - Crew size-based enemy generation
    var base_count: int = 0
    match crew_size:
        6:
            base_count = max(rng.randi_range(1, 6), rng.randi_range(1, 6))
        5:
            base_count = rng.randi_range(1, 6)
        4:
            base_count = min(rng.randi_range(1, 6), rng.randi_range(1, 6))
        _:
            base_count = max(rng.randi_range(1, 6), rng.randi_range(1, 6))

    # Apply difficulty modifier
    if difficulty >= 3:
        base_count += 1
    if difficulty >= 4:
        base_count += 1

    return max(1, base_count)

## Serialization
func to_dict() -> Dictionary:
    return {
        "deployment_id": deployment_id,
        "enemy_category": enemy_category,
        "total_enemy_count": total_enemy_count,
        "basic_enemy_ids": basic_enemy_ids.duplicate(),
        "specialist_enemy_ids": specialist_enemy_ids.duplicate(),
        "lieutenant_id": lieutenant_id,
        "captain_id": captain_id,
        "unique_individual_id": unique_individual_id,
        "deployment_zone": deployment_zone.map(func(v): return {"x": v.x, "y": v.y}),
        "assigned_positions": _serialize_positions(assigned_positions),
        "ai_type": ai_type,
        "special_rules": special_rules.duplicate(),
        "panic_range": panic_range,
        "is_fearless": is_fearless
    }

static func _serialize_positions(positions: Dictionary) -> Dictionary:
    var serialized := {}
    for key in positions.keys():
        var pos: Vector2i = positions[key]
        serialized[key] = {"x": pos.x, "y": pos.y}
    return serialized
```

---

### UniqueIndividualData (Resource)
**Purpose**: One-time generated elite enemy with procedural name and enhanced stats
**Lifecycle**: Generated once, persisted across campaign if recurring
**Save/Load**: Fully serializable

```gdscript
class_name UniqueIndividualData
extends Resource

## Unique identification
@export var unique_id: String = ""  # UUID: "unique_hired_killer_1234567890"
@export var unique_type: String = ""  # From elite_enemy_types.json: "Enemy Bruiser", "Hired Killer"

## Procedurally generated identity (Five Parsecs p.100-101)
@export var procedural_name: String = ""  # "Vex Korran", "The Butcher of Zeta"
@export var generation_seed: int = 0  # For name reproducibility

## Enhanced stats (base enemy + modifiers)
@export var base_enemy_category: String = ""  # "raiders" (inherits stats from this)
@export var combat_skill_modifier: int = 0  # +1 for Boss, +2 for Hired Killer
@export var toughness_modifier: int = 0  # +1 for Bruiser/Boss
@export var speed: String = ""  # "5\"", "6\"" (from unique individual table)
@export var savvy: int = 0  # For special abilities

## Equipment (weapon table IDs, not weapon objects)
@export var weapon_table_ids: Array[String] = []  # ["hand_cannon", "shatter_axe"]
@export var armor_save: int = 0  # 0 = none, 4 = 4+, 5 = 5+

## Special abilities (Five Parsecs p.100-101)
@export var has_luck: bool = false  # Luck stat (can reroll)
@export var luck_value: int = 0  # Usually 1
@export var special_rules: Array[String] = []  # ["Overbearing", "Following Fire", "Authority Figure"]

## Recurring enemy tracking (campaign persistence)
@export var is_recurring: bool = false  # Has appeared before
@export var times_encountered: int = 0  # Campaign tracking
@export var previous_battle_ids: Array[String] = []  # Battle history

## Factory method - Procedural name generation
static func create_unique_individual(type_data: Dictionary, base_category: String, seed: int) -> UniqueIndividualData:
    var unique := UniqueIndividualData.new()
    unique.unique_id = "unique_%s_%d" % [type_data.get("name", "unknown").replace(" ", "_"), seed]
    unique.unique_type = type_data.get("name", "Unknown Unique")
    unique.generation_seed = seed
    unique.base_enemy_category = base_category

    # Generate procedural name
    unique.procedural_name = _generate_procedural_name(seed)

    # Apply stat modifiers from type_data
    unique.combat_skill_modifier = _parse_modifier(type_data.get("combat_skill", "-"))
    unique.toughness_modifier = _parse_modifier(type_data.get("toughness", "-"))
    unique.speed = type_data.get("speed", "5\"")
    unique.has_luck = type_data.get("luck", 0) > 0
    unique.luck_value = type_data.get("luck", 0)
    unique.special_rules = type_data.get("special_rules", []).duplicate()

    # Parse weapons
    var weapons_str: String = type_data.get("weapons", "")
    unique.weapon_table_ids = _parse_weapon_table_ids(weapons_str)

    return unique

static func _generate_procedural_name(seed: int) -> String:
    # Procedural name generation using seed
    var rng := RandomNumberGenerator.new()
    rng.seed = seed

    var first_names := ["Vex", "Kira", "Zade", "Rylan", "Nova", "Cade", "Jax", "Soren", "Dax", "Lyra"]
    var last_names := ["Korran", "Voss", "Thane", "Drake", "Rourke", "Cross", "Steele", "Ash", "Raven", "Storm"]
    var titles := ["the Butcher", "the Ghost", "the Viper", "the Shadow", "the Blade", "the Hunter"]

    var first := first_names[rng.randi() % first_names.size()]
    var last := last_names[rng.randi() % last_names.size()]

    # 30% chance of title
    if rng.randi() % 10 < 3:
        var title := titles[rng.randi() % titles.size()]
        return "%s %s, %s" % [first, last, title]

    return "%s %s" % [first, last]

static func _parse_modifier(value: String) -> int:
    if value == "-":
        return 0
    if value.begins_with("+"):
        return value.substr(1).to_int()
    return value.to_int()

static func _parse_weapon_table_ids(weapons_str: String) -> Array[String]:
    # "Hand Cannon, Shatter Axe" → ["hand_cannon", "shatter_axe"]
    var weapon_ids: Array[String] = []
    var weapons := weapons_str.split(",")
    for weapon in weapons:
        var normalized := weapon.strip_edges().to_lower().replace(" ", "_")
        weapon_ids.append(normalized)
    return weapon_ids

## Serialization
func to_dict() -> Dictionary:
    return {
        "unique_id": unique_id,
        "unique_type": unique_type,
        "procedural_name": procedural_name,
        "generation_seed": generation_seed,
        "base_enemy_category": base_enemy_category,
        "combat_skill_modifier": combat_skill_modifier,
        "toughness_modifier": toughness_modifier,
        "speed": speed,
        "savvy": savvy,
        "weapon_table_ids": weapon_table_ids.duplicate(),
        "armor_save": armor_save,
        "has_luck": has_luck,
        "luck_value": luck_value,
        "special_rules": special_rules.duplicate(),
        "is_recurring": is_recurring,
        "times_encountered": times_encountered,
        "previous_battle_ids": previous_battle_ids.duplicate()
    }
```

---

### WeaponTableConstants (Static Class)
**Purpose**: Weapon lookup table (ID-based, not Resource objects)
**Lifecycle**: Static data, never instantiated
**Save/Load**: Not persisted (weapons referenced by ID only)

```gdscript
class_name WeaponTableConstants
extends RefCounted

## Weapon table IDs mapped to properties (Five Parsecs p.112-115)
const WEAPON_PROPERTIES: Dictionary = {
    "handgun": {
        "name": "Handgun",
        "range": 12,
        "shots": 1,
        "damage": 1,
        "traits": []
    },
    "hand_cannon": {
        "name": "Hand Cannon",
        "range": 10,
        "shots": 1,
        "damage": 2,
        "traits": ["Piercing"]
    },
    "shotgun": {
        "name": "Shotgun",
        "range": 12,
        "shots": 2,
        "damage": 1,
        "traits": ["Melee"]
    },
    "auto_rifle": {
        "name": "Auto Rifle",
        "range": 24,
        "shots": 2,
        "damage": 1,
        "traits": []
    },
    "military_rifle": {
        "name": "Military Rifle",
        "range": 30,
        "shots": 1,
        "damage": 1,
        "traits": ["Aimed"]
    },
    "plasma_rifle": {
        "name": "Plasma Rifle",
        "range": 24,
        "shots": 1,
        "damage": 2,
        "traits": ["Piercing", "Snap Shot"]
    },
    "shatter_axe": {
        "name": "Shatter Axe",
        "range": 0,
        "shots": 0,
        "damage": 2,
        "traits": ["Melee", "Piercing"]
    },
    "ripper_sword": {
        "name": "Ripper Sword",
        "range": 0,
        "shots": 0,
        "damage": 2,
        "traits": ["Melee"]
    },
    "blade": {
        "name": "Blade",
        "range": 0,
        "shots": 0,
        "damage": 1,
        "traits": ["Melee"]
    }
}

## Weapon table lookup
static func get_weapon_properties(weapon_id: String) -> Dictionary:
    return WEAPON_PROPERTIES.get(weapon_id, {
        "name": "Unknown Weapon",
        "range": 0,
        "shots": 0,
        "damage": 0,
        "traits": []
    })

## Weapon table ID list (for random selection)
static func get_all_weapon_ids() -> Array[String]:
    return WEAPON_PROPERTIES.keys() as Array[String]

static func get_ranged_weapon_ids() -> Array[String]:
    var ranged: Array[String] = []
    for weapon_id in WEAPON_PROPERTIES.keys():
        var props: Dictionary = WEAPON_PROPERTIES[weapon_id]
        if props.get("range", 0) > 0:
            ranged.append(weapon_id)
    return ranged

static func get_melee_weapon_ids() -> Array[String]:
    var melee: Array[String] = []
    for weapon_id in WEAPON_PROPERTIES.keys():
        var props: Dictionary = WEAPON_PROPERTIES[weapon_id]
        if "Melee" in props.get("traits", []):
            melee.append(weapon_id)
    return melee
```

---

## Integration with GameState

### BattlefieldStateData (Resource)
**Purpose**: Complete battlefield state for save/load
**Lifecycle**: Created at battle start, persisted in GameState.battle_results
**Save/Load**: Fully serializable

```gdscript
class_name BattlefieldStateData
extends Resource

## Battle identification
@export var battle_id: String = ""  # UUID: "battle_1234567890"
@export var generation_seed: int = 0  # For battlefield reproducibility
@export var mission_type: String = ""  # Reference to mission that spawned this battle

## Terrain state (ID references)
@export var terrain_feature_ids: Array[String] = []  # ["terrain_rock_pile_01", "terrain_bunker_02"]

## Enemy deployment (ID reference to avoid circular deps)
@export var deployment_id: String = ""  # "deployment_1234567890"

## Unique individual (if present)
@export var unique_individual_id: String = ""  # "unique_hired_killer_1234567890" or ""

## Battle phase tracking
@export var current_round: int = 1
@export var battle_phase: String = "deployment"  # "deployment", "combat", "completed"

## GameState integration
func serialize_to_game_state() -> Dictionary:
    return {
        "battle_id": battle_id,
        "generation_seed": generation_seed,
        "mission_type": mission_type,
        "terrain_feature_ids": terrain_feature_ids.duplicate(),
        "deployment_id": deployment_id,
        "unique_individual_id": unique_individual_id,
        "current_round": current_round,
        "battle_phase": battle_phase
    }

static func deserialize_from_game_state(data: Dictionary) -> BattlefieldStateData:
    var state := BattlefieldStateData.new()
    state.battle_id = data.get("battle_id", "")
    state.generation_seed = data.get("generation_seed", 0)
    state.mission_type = data.get("mission_type", "")
    state.terrain_feature_ids = data.get("terrain_feature_ids", []).duplicate()
    state.deployment_id = data.get("deployment_id", "")
    state.unique_individual_id = data.get("unique_individual_id", "")
    state.current_round = data.get("current_round", 1)
    state.battle_phase = data.get("battle_phase", "deployment")
    return state
```

---

## Migration Strategy

### Schema Version Tracking
```gdscript
class_name BattlefieldDataMigration
extends RefCounted

const CURRENT_SCHEMA_VERSION: int = 1

static func needs_migration(data: Dictionary) -> bool:
    var schema_version := data.get("battlefield_schema_version", 0)
    return schema_version < CURRENT_SCHEMA_VERSION

static func migrate(data: Dictionary) -> Dictionary:
    var schema_version := data.get("battlefield_schema_version", 0)

    # Future migrations
    # if schema_version < 2:
    #     data = _migrate_v1_to_v2(data)

    data["battlefield_schema_version"] = CURRENT_SCHEMA_VERSION
    return data
```

---

## Validation Rules

### Runtime Validation
```gdscript
class_name BattlefieldDataValidator
extends RefCounted

static func validate_terrain_feature(feature: TerrainFeatureData) -> Dictionary:
    var errors: Array[String] = []

    if feature.terrain_id.is_empty():
        errors.append("Missing terrain_id")

    if feature.positions.is_empty():
        errors.append("TerrainFeature has no positions")

    if feature.cover_value < 0 or feature.cover_value > 2:
        errors.append("Invalid cover_value: %d (must be 0-2)" % feature.cover_value)

    return {
        "valid": errors.is_empty(),
        "errors": errors
    }

static func validate_deployment(deployment: EnemyDeploymentData) -> Dictionary:
    var errors: Array[String] = []

    if deployment.deployment_id.is_empty():
        errors.append("Missing deployment_id")

    if deployment.total_enemy_count <= 0:
        errors.append("Invalid total_enemy_count: %d" % deployment.total_enemy_count)

    if deployment.ai_type.is_empty():
        errors.append("Missing ai_type")

    return {
        "valid": errors.is_empty(),
        "errors": errors
    }
```

---

## Success Metrics

### Data Integrity
- Zero save corruption across 10,000+ battlefield generation cycles
- 100% battlefield reproducibility from same seed
- No circular reference errors in save files

### Performance
- Battlefield generation completes in <200ms for standard 36x24 grid
- Save/load roundtrip for complete battlefield state in <100ms
- Terrain feature lookup (by ID) in <1ms

### Version Compatibility
- Old saves load in new versions via migration system
- New schema additions backward-compatible (default values)
- Migration errors logged but never crash

---

## File Locations

```
src/core/battle/data/
├── BattlefieldGenerationContext.gd
├── TerrainFeatureData.gd
├── EnemyDeploymentData.gd
├── UniqueIndividualData.gd
├── BattlefieldStateData.gd
├── WeaponTableConstants.gd
├── BattlefieldDataValidator.gd
└── BattlefieldDataMigration.gd

data/battlefield/
├── weapon_tables.json
├── unique_individual_names.json (procedural name lists)
└── deployment_zones.json (standard/ambush/surrounded variants)
```

---

## Integration Example

```gdscript
# In BattlefieldGenerator.gd
func generate_battlefield(context: BattlefieldGenerationContext) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = context.generation_seed

    # Generate terrain
    var terrain_features: Array[TerrainFeatureData] = []
    for i in range(rng.randi_range(4, 8)):
        var feature := TerrainFeatureData.create_cover_large(
            context.generation_seed + i,
            Vector2i(rng.randi_range(5, 30), rng.randi_range(5, 20))
        )
        terrain_features.append(feature)

    # Generate enemy deployment
    var deployment := EnemyDeploymentData.create_standard_deployment(context, rng)

    # Check for unique individual (9+ on 1d10)
    var unique_roll := rng.randi_range(1, 10)
    var unique_individual: UniqueIndividualData = null
    if unique_roll >= 9:
        var unique_type_data := _load_random_unique_type(rng)
        unique_individual = UniqueIndividualData.create_unique_individual(
            unique_type_data,
            deployment.enemy_category,
            context.generation_seed + 9999
        )
        deployment.unique_individual_id = unique_individual.unique_id

    # Store in GameState
    var battlefield_state := BattlefieldStateData.new()
    battlefield_state.battle_id = "battle_%d" % Time.get_unix_time_from_system()
    battlefield_state.generation_seed = context.generation_seed
    battlefield_state.mission_type = context.mission_type
    battlefield_state.deployment_id = deployment.deployment_id
    if unique_individual:
        battlefield_state.unique_individual_id = unique_individual.unique_id

    # Serialize terrain IDs only (terrain features stored separately)
    for feature in terrain_features:
        battlefield_state.terrain_feature_ids.append(feature.terrain_id)

    GameState.set_battle_results(battlefield_state.serialize_to_game_state())

    return {
        "terrain_features": terrain_features,
        "deployment": deployment,
        "unique_individual": unique_individual,
        "battlefield_state": battlefield_state
    }
```

---

## End of Schema Design

**Status**: Ready for implementation
**Next Steps**:
1. Implement Resource classes in `src/core/battle/data/`
2. Create validator and migration systems
3. Write GUT tests for serialization roundtrip
4. Integrate with BattlefieldGenerator.gd
