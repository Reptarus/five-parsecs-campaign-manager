class_name Character
extends Resource

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const CharacterInventory = preload("res://Resources/CrewAndCharacters/CharacterInventory.gd")

signal stats_changed
signal status_changed(new_status: GlobalEnums.CharacterStatus)

@export_group("Basic Info")
@export var character_name: String
@export var role: int = GlobalEnums.CrewRole.SOLDIER

@export_group("Character Traits")
@export var background: int = GlobalEnums.Background.SOLDIER
@export var motivation: int = GlobalEnums.Motivation.WEALTH
@export var origin: GlobalEnums.Origin

# Core state properties needed by derived classes
var status: int = GlobalEnums.CharacterStatus.HEALTHY
var current_action: int = GlobalEnums.EnemyAction.NONE  # Needed by Enemy class
var inventory: CharacterInventory
var stats: Dictionary = {}

func _init() -> void:
	inventory = CharacterInventory.new()
	_initialize_stats()

func _initialize_stats() -> void:
	for stat in GlobalEnums.CharacterStats.values():
		stats[stat] = 0

func set_status(new_status: int) -> void:
	if status != new_status:
		status = new_status
		status_changed.emit(status)

func can_act() -> bool:
	return status != GlobalEnums.CharacterStatus.CRITICAL and status != GlobalEnums.CharacterStatus.INJURED

func serialize() -> Dictionary:
	return {
		"name": character_name,
		"role": role,
		"background": background,
		"motivation": motivation,
		"stats": stats,
		"status": status,
		"inventory": inventory.serialize()
	}

static func deserialize(data: Dictionary) -> Character:
	var character = Character.new()
	character.character_name = data.get("name", "Unknown")
	character.role = data.get("role", GlobalEnums.CrewRole.SOLDIER)
	character.background = data.get("background", GlobalEnums.Background.SOLDIER)
	character.motivation = data.get("motivation", GlobalEnums.Motivation.WEALTH)
	character.status = data.get("status", GlobalEnums.CharacterStatus.HEALTHY)
	
	# Load stats
	if data.has("stats"):
		for stat in data["stats"]:
			character.stats[stat] = data["stats"][stat]
	
	return character
