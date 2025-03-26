@tool
extends Resource

const RivalsEnemyData = preload("res://src/core/rivals/EnemyData.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Basic properties
@export var enemy_id: String = ""
@export var enemy_name: String = "Unknown Enemy"
@export var enemy_type: int = GameEnums.EnemyType.GANGERS

# Stats
@export var level: int = 1
@export var health: int = 100
@export var max_health: int = 100
@export var armor: int = 0
@export var damage: int = 10
@export var movement_range: int = 4
@export var weapon_range: int = 2

# Combat data
@export var abilities: Array = []
@export var loot_table: Dictionary = {
	"credits": 50,
	"items": []
}

# Dict to store metadata
var _meta_data: Dictionary = {}

var _rivals_data: Resource = null

func _init(p_name: String = "Unknown Enemy") -> void:
	enemy_name = p_name
	enemy_id = str(Time.get_unix_time_from_system())
	
	# Create the rivals data if available
	if RivalsEnemyData:
		_rivals_data = RivalsEnemyData.new(GameEnums.EnemyType.GANGERS)

# Metadata methods for compatibility
func has_meta(name: StringName) -> bool:
	if typeof(name) == TYPE_STRING_NAME:
		return _meta_data.has(String(name))
	return _meta_data.has(name)
	
func get_meta(name: StringName, default = null) -> Variant:
	if has_meta(name):
		return _meta_data[String(name)]
	
	# Provide fallback values based on property mapping
	var key = String(name)
	match key:
		"health": return health
		"max_health": return max_health
		"armor": return armor
		"damage": return damage
		"name": return enemy_name
		"movement_range": return movement_range
		"weapon_range": return weapon_range
	return default
	
func set_meta(name: StringName, value: Variant) -> void:
	_meta_data[String(name)] = value
	
	# Update corresponding properties too
	var key = String(name)
	match key:
		"health": health = value
		"max_health": max_health = value
		"armor": armor = value
		"damage": damage = value
		"name": enemy_name = value
		"movement_range": movement_range = value
		"weapon_range": weapon_range = value

# Getters
func get_id() -> String:
	return enemy_id

func get_name() -> String:
	return enemy_name

func get_type() -> int:
	return enemy_type

func get_level() -> int:
	return level

func get_health() -> int:
	return health

func get_max_health() -> int:
	return max_health

func get_armor() -> int:
	return armor

func get_damage() -> int:
	return damage
	
func get_movement_range() -> int:
	return movement_range
	
func get_weapon_range() -> int:
	return weapon_range
	
func get_behavior() -> int:
	return GameEnums.EnemyBehavior.CAUTIOUS

func get_abilities() -> Array:
	return abilities.duplicate()

func get_loot_table() -> Dictionary:
	return loot_table.duplicate()
	
func get_weapon() -> Resource:
	# Return placeholder for testing
	return null

# For testing, convert to dictionary
func to_dict() -> Dictionary:
	return {
		"enemy_id": enemy_id,
		"enemy_name": enemy_name,
		"enemy_type": enemy_type,
		"level": level,
		"health": health,
		"max_health": max_health,
		"armor": armor,
		"damage": damage,
		"movement_range": movement_range,
		"weapon_range": weapon_range,
		"abilities": abilities,
		"loot_table": loot_table
	}

# Compatibility with rivals data
func serialize() -> Dictionary:
	if _rivals_data and _rivals_data.has_method("serialize"):
		return _rivals_data.serialize()
	return to_dict()

func deserialize(data: Dictionary) -> void:
	if not data:
		return
		
	enemy_id = data.get("enemy_id", enemy_id)
	enemy_name = data.get("enemy_name", data.get("character_name", enemy_name))
	enemy_type = data.get("enemy_type", enemy_type)
	level = data.get("level", level)
	health = data.get("health", health)
	max_health = data.get("max_health", max_health)
	armor = data.get("armor", data.get("armor_save", armor))
	damage = data.get("damage", damage)
	movement_range = data.get("movement_range", movement_range)
	weapon_range = data.get("weapon_range", weapon_range)
	abilities = data.get("abilities", abilities)
	loot_table = data.get("loot_table", loot_table)
	
	# Update rivals data if available
	if _rivals_data and _rivals_data.has_method("deserialize"):
		_rivals_data.deserialize(data)