extends Resource

const Self = preload("res://src/core/utils/stat_distribution.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsCharacter = preload("res://src/base/character/character_base.gd")
const StatusEffect = preload("res://src/ui/screens/campaign/StatusEffects.gd")

signal stat_changed(stat: String, new_value: int)

var character: FiveParsecsCharacter
var base_stats: Dictionary = {}
var temporary_modifiers: Dictionary = {}
var permanent_modifiers: Dictionary = {}

func _init(character_instance: FiveParsecsCharacter = null) -> void:
	character = character_instance
	_initialize_stats()

func _initialize_stats() -> void:
	if character:
		base_stats = {
			"reactions": character.stats.reactions,
			"speed": character.stats.speed,
			"combat_skill": character.stats.combat_skill,
			"toughness": character.stats.toughness,
			"savvy": character.stats.savvy,
			"luck": character.stats.luck
		}
		temporary_modifiers = {}
		permanent_modifiers = {}

# Core stat management functions
func update_stat(stat: String, new_value: int) -> void:
	if stat in base_stats:
		base_stats[stat] = new_value
		print("%s's %s changed to %d" % [character.character_name, stat, new_value])
		
		# Update the corresponding stat in CharacterStats
		match stat:
			"reactions": character.stats.reactions = new_value
			"speed": character.stats.speed = new_value
			"combat_skill": character.stats.combat_skill = new_value
			"toughness": character.stats.toughness = new_value
			"savvy": character.stats.savvy = new_value
			"luck": character.stats.luck = new_value
			
		stat_changed.emit(stat, new_value)
	else:
		push_error("Invalid stat: %s" % stat)

func get_current_stat(stat: String) -> int:
	var current_value = base_stats[stat]
	
	if permanent_modifiers.has(stat):
		current_value += permanent_modifiers[stat]
	
	if temporary_modifiers.has(stat):
		for modifier in temporary_modifiers[stat]:
			current_value += modifier["value"]
	
	# Apply Core Rules stat limits
	match stat:
		"reactions": return clampi(current_value, 1, 6)
		"speed": return clampi(current_value, 4, 8)
		"combat_skill": return clampi(current_value, -3, 3)
		"toughness": return clampi(current_value, 3, 6)
		"savvy": return clampi(current_value, -3, 3)
		"luck": return clampi(current_value, 0, 3)
		_: return current_value

func meets_stat_threshold(stat: String, threshold: int) -> bool:
	return get_current_stat(stat) >= threshold

# Modifier management
func add_temporary_modifier(stat: String, value: int, duration: int):
	if not temporary_modifiers.has(stat):
		temporary_modifiers[stat] = []
	temporary_modifiers[stat].append({"value": value, "duration": duration})
	stat_changed.emit(stat, get_current_stat(stat))

func add_permanent_modifier(stat: String, value: int):
	if not permanent_modifiers.has(stat):
		permanent_modifiers[stat] = 0
	permanent_modifiers[stat] += value
	stat_changed.emit(stat, get_current_stat(stat))

func remove_temporary_modifier(stat: String, index: int):
	if temporary_modifiers.has(stat) and index < temporary_modifiers[stat].size():
		temporary_modifiers[stat].remove_at(index)
		stat_changed.emit(stat, get_current_stat(stat))

func serialize() -> Dictionary:
	return {
		"base_stats": base_stats,
		"temporary_modifiers": temporary_modifiers,
		"permanent_modifiers": permanent_modifiers
	}

static func deserialize(data_dict: Dictionary, character_instance: FiveParsecsCharacter) -> Resource:
	var new_stat_distribution = new()
	new_stat_distribution._init(character_instance)
	if data_dict.has("base_stats"):
		new_stat_distribution.base_stats = data_dict["base_stats"]
	if data_dict.has("temporary_modifiers"):
		new_stat_distribution.temporary_modifiers = data_dict["temporary_modifiers"]
	if data_dict.has("permanent_modifiers"):
		new_stat_distribution.permanent_modifiers = data_dict["permanent_modifiers"]
	return new_stat_distribution
