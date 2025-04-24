@tool
extends Resource
class_name BaseCharacterResource
# Changed from extending character_base.gd to be explicit about type
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const BaseCharacter = preload("res://src/base/character/character_base.gd")
const GameEnums = preload("res://src/core/enums/GameEnums.gd")

# Core character delegation and wrapper instance
var _base_character = null

## Core implementation of character for Five Parsecs
##
## Extends BaseCharacter with game-specific functionality for
## the Five Parsecs From Home rule system.

# Core character properties with default values
var character_name: String = "New Character"
var character_type: int = 0
var level: int = 1
var experience: int = 0
var health: int = 100
var max_health: int = 100
var is_dead: bool = false
var is_wounded: bool = false
var status_effects: Array = []

# Core stats
var reaction: int = 0
var combat: int = 0
var toughness: int = 0
var speed: int = 0

# Five Parsecs specific character properties
var character_class: int = 0 # GameEnums.CharacterClass.NONE
var origin: int = 0 # GameEnums.Origin.NONE
var background: int = 0 # GameEnums.Background.NONE
var motivation: int = 0 # GameEnums.Motivation.NONE

# Additional Five Parsecs stats
var _savvy: int = 0
var _luck: int = 0
var _training: int = 0 # GameEnums.Training.NONE

# Equipment specific to Five Parsecs
var weapons: Array = [] # Weapon resources
var armor: Array = [] # Armor resources
var items: Array = [] # Item resources

# Character type flags for Five Parsecs
var is_bot: bool = false
var is_soulless: bool = false
var is_human: bool = false

# Additional traits for Five Parsecs
var traits: Array = []

# Signals
signal experience_changed(old_value, new_value)
signal level_changed(old_value, new_value)
signal health_changed(old_value, new_value)
signal status_changed(status)
signal training_changed(old_value, new_value)

# Static helpers for test compatibility and type safety
static func is_resource_script() -> bool:
	return true

func _init() -> void:
	# Set a default character class as the character type
	character_type = 0 # GameEnums.CharacterClass.SOLDIER
	_create_base_character()
	_connect_signals()

# Create the base character for delegation with error handling
func _create_base_character() -> void:
	if not ResourceLoader.exists("res://src/base/character/character_base.gd"):
		push_warning("BaseCharacter script not found, some functionality will be limited")
		return
		
	var script = load("res://src/base/character/character_base.gd")
	if not script or not script is GDScript:
		push_warning("BaseCharacter is not a valid GDScript, some functionality will be limited")
		return
		
	var instance = script.new()
	if not instance:
		push_warning("Failed to create BaseCharacter instance, some functionality will be limited")
		return
		
	_base_character = instance

# Connect base signals to this resource's signals
func _connect_signals() -> void:
	if not _base_character:
		return
		
	# Connect signals if they exist in the base character
	var signals_to_connect = [
		{"signal_name": "experience_changed", "method": "_on_base_experience_changed"},
		{"signal_name": "level_changed", "method": "_on_base_level_changed"},
		{"signal_name": "health_changed", "method": "_on_base_health_changed"},
		{"signal_name": "status_changed", "method": "_on_base_status_changed"}
	]
	
	for sig_data in signals_to_connect:
		if _base_character.has_signal(sig_data.signal_name):
			# Check if already connected
			if not _base_character.is_connected(sig_data.signal_name, Callable(self, sig_data.method)):
				_base_character.connect(sig_data.signal_name, Callable(self, sig_data.method))
	
	# Initialize properties from base character
	if _base_character:
		# Safely access properties using get() method instead of direct access
		if _base_character.get("character_name") != null:
			character_name = _base_character.character_name
		if _base_character.get("level") != null:
			level = _base_character.level
		if _base_character.get("experience") != null:
			experience = _base_character.experience
		if _base_character.get("health") != null:
			health = _base_character.health
		if _base_character.get("max_health") != null:
			max_health = _base_character.max_health
		if _base_character.get("is_dead") != null:
			is_dead = _base_character.is_dead
		if _base_character.get("is_wounded") != null:
			is_wounded = _base_character.is_wounded

# Signal forwarders
func _on_base_experience_changed(old_value, new_value) -> void:
	experience_changed.emit(old_value, new_value)
	
func _on_base_level_changed(old_value, new_value) -> void:
	level_changed.emit(old_value, new_value)
	
func _on_base_health_changed(old_value, new_value) -> void:
	health_changed.emit(old_value, new_value)
	
func _on_base_status_changed(status_value) -> void:
	status_changed.emit(status_value)

# Additional property getters/setters for Five Parsecs stats
var savvy: int:
	get: return _savvy
	set(value):
		_savvy = clampi(value, 0, MAX_STATS.savvy)

var luck: int:
	get: return _luck
	set(value):
		var max_luck = MAX_STATS.luck
		if is_human:
			max_luck = 3 # Humans can have more luck
		_luck = clampi(value, 0, max_luck)

var training: int:
	get: return _training
	set(value):
		if value >= 0:
			var old_value = _training
			_training = value
			training_changed.emit(old_value, _training)

# Maximum values for stats (extending the base stats)
const MAX_STATS = {
	"reaction": 6,
	"combat": 5,
	"speed": 8,
	"savvy": 5,
	"toughness": 6,
	"luck": 1 # Humans can have 3
}

## Five Parsecs specific methods

## Set character name with validation
func set_character_name(value: String) -> void:
	if value.is_empty():
		return
		
	character_name = value
	
	if _base_character and _base_character.has_method("set_character_name"):
		_base_character.set_character_name(value)

## Set character class
func set_character_class(value: int) -> void:
	character_class = value
	
	if _base_character and _base_character.has_method("set_character_type"):
		_base_character.set_character_type(value)
		
## Set origin
func set_origin(value: int) -> void:
	origin = value
	
	# Update human flag based on origin
	is_human = (origin == 0) # GameEnums.Origin.HUMAN

## Set background
func set_background(value: int) -> void:
	background = value

## Set motivation
func set_motivation(value: int) -> void:
	motivation = value

## Roll for a stat check using appropriate dice
func roll_stat_check(stat_name: String, difficulty: int = 0) -> bool:
	var stat_value = 0
	match stat_name.to_lower():
		"reaction": stat_value = reaction
		"combat": stat_value = combat
		"toughness": stat_value = toughness
		"speed": stat_value = speed
		"savvy": stat_value = savvy
		"luck": stat_value = luck
	
	# Roll dice logic here
	var roll = randi() % 6 + 1 # Simulate d6 roll
	return roll + stat_value >= difficulty

## Add experience to the character
func add_experience(amount: int) -> bool:
	if amount <= 0 or is_bot:
		return false
		
	if _base_character and _base_character.has_method("add_experience"):
		var result = _base_character.add_experience(amount)
		if result:
			# Sync our local copies
			experience = _base_character.experience
			level = _base_character.level
		return result
		
	var old_experience = experience
	var old_level = level
	
	# Cap experience at some maximum value
	experience = clampi(experience + amount, 0, 10000)
	
	# Handle leveling up
	var experience_for_level = level * 100
	if experience >= experience_for_level:
		level += 1
		level_changed.emit(old_level, level)
	
	experience_changed.emit(old_experience, experience)
	return true

## Apply Five Parsecs specific status effects
func apply_status_effect(effect: Dictionary) -> void:
	if _base_character and _base_character.has_method("apply_status_effect"):
		_base_character.apply_status_effect(effect)
		
		# Sync status effects from base character
		if _base_character.get("status_effects") != null:
			status_effects = _base_character.status_effects.duplicate()
		return
		
	status_effects.append(effect)
	status_changed.emit("effect_applied")

## Process character recovery between campaign turns
func process_recovery() -> bool:
	if _base_character and _base_character.has_method("process_recovery"):
		var result = _base_character.process_recovery()
		
		# Sync changes from base character
		if _base_character.get("is_wounded") != null:
			is_wounded = _base_character.is_wounded
		if _base_character.get("health") != null:
			health = _base_character.health
		if _base_character.get("status_effects") != null:
			status_effects = _base_character.status_effects.duplicate()
			
		return result
	
	var recovered = false
	if is_wounded and not is_dead:
		# Roll recovery check
		var recovery_roll = randi() % 6 + 1 + toughness
		if recovery_roll >= 6:
			is_wounded = false
			health = maxi(1, max_health / 2)
			recovered = true
	
	# Process status effects
	for i in range(status_effects.size() - 1, -1, -1):
		var effect = status_effects[i]
		if "duration" in effect: # Use "in" operator instead of has()
			effect.duration -= 1
			if effect.duration <= 0:
				status_effects.remove_at(i)
	
	return recovered

## Add a trait to the character
func add_trait(trait_name: String) -> void:
	if trait_name.is_empty():
		return
		
	if _base_character and _base_character.has_method("add_trait"):
		_base_character.add_trait(trait_name)
		
		# Sync traits from base character 
		if _base_character.get("traits") != null:
			traits = _base_character.traits.duplicate()
		return
		
	if not trait_name in traits: # Use "in" operator instead of has()
		traits.append(trait_name)

## Check if character has a specific trait
func has_trait(trait_name: String) -> bool:
	if trait_name.is_empty():
		return false
		
	if _base_character and _base_character.has_method("has_trait"):
		return _base_character.has_trait(trait_name)
		
	return trait_name in traits # Use "in" operator instead of has()

## Serialize character data for saving
func serialize() -> Dictionary:
	if _base_character and _base_character.has_method("serialize"):
		var base_data = _base_character.serialize()
		
		# Merge with our specific data
		base_data["character_class"] = character_class
		base_data["origin"] = origin
		base_data["background"] = background
		base_data["motivation"] = motivation
		base_data["savvy"] = _savvy
		base_data["luck"] = _luck
		base_data["training"] = _training
		base_data["is_bot"] = is_bot
		base_data["is_soulless"] = is_soulless
		base_data["is_human"] = is_human
		
		return base_data
	
	return {
		"character_name": character_name,
		"character_type": character_type,
		"level": level,
		"experience": experience,
		"health": health,
		"max_health": max_health,
		"is_dead": is_dead,
		"is_wounded": is_wounded,
		"status_effects": status_effects,
		"reaction": reaction,
		"combat": combat,
		"toughness": toughness,
		"speed": speed,
		"character_class": character_class,
		"origin": origin,
		"background": background,
		"motivation": motivation,
		"savvy": _savvy,
		"luck": _luck,
		"training": _training,
		"is_bot": is_bot,
		"is_soulless": is_soulless,
		"is_human": is_human,
		"traits": traits
	}

## Deserialize character data from saved state
func deserialize(data: Dictionary) -> void:
	if not data:
		push_warning("Attempt to deserialize null or empty data")
		return
		
	if _base_character and _base_character.has_method("deserialize"):
		# Create a copy of data for base character
		var base_data = data.duplicate()
		_base_character.deserialize(base_data)
		
		# Sync common properties from base character
		if _base_character.get("character_name") != null:
			character_name = _base_character.character_name
		if _base_character.get("character_type") != null:
			character_type = _base_character.character_type
		if _base_character.get("level") != null:
			level = _base_character.level
		if _base_character.get("experience") != null:
			experience = _base_character.experience
		if _base_character.get("health") != null:
			health = _base_character.health
		if _base_character.get("max_health") != null:
			max_health = _base_character.max_health
		if _base_character.get("is_dead") != null:
			is_dead = _base_character.is_dead
		if _base_character.get("is_wounded") != null:
			is_wounded = _base_character.is_wounded
		if _base_character.get("status_effects") != null:
			status_effects = _base_character.status_effects.duplicate()
		if _base_character.get("reaction") != null:
			reaction = _base_character.reaction
		if _base_character.get("combat") != null:
			combat = _base_character.combat
		if _base_character.get("toughness") != null:
			toughness = _base_character.toughness
		if _base_character.get("speed") != null:
			speed = _base_character.speed
	
	# Load specific Five Parsecs properties - use "in" operator instead of has()
	if "character_name" in data:
		character_name = data.character_name
	if "character_type" in data:
		character_type = data.character_type
	if "level" in data:
		level = data.level
	if "experience" in data:
		experience = data.experience
	if "health" in data:
		health = data.health
	if "max_health" in data:
		max_health = data.max_health
	if "is_dead" in data:
		is_dead = data.is_dead
	if "is_wounded" in data:
		is_wounded = data.is_wounded
	if "status_effects" in data:
		status_effects = data.status_effects
	if "reaction" in data:
		reaction = data.reaction
	if "combat" in data:
		combat = data.combat
	if "toughness" in data:
		toughness = data.toughness
	if "speed" in data:
		speed = data.speed
	if "character_class" in data:
		character_class = data.character_class
	if "origin" in data:
		origin = data.origin
	if "background" in data:
		background = data.background
	if "motivation" in data:
		motivation = data.motivation
	if "savvy" in data:
		_savvy = data.savvy
	if "luck" in data:
		_luck = data.luck
	if "training" in data:
		_training = data.training
	if "is_bot" in data:
		is_bot = data.is_bot
	if "is_soulless" in data:
		is_soulless = data.is_soulless
	if "is_human" in data:
		is_human = data.is_human
	if "traits" in data:
		traits = data.traits

# Add a static type check method to help prevent assignment errors
static func is_valid_node_target(node: Node) -> bool:
	return false # This resource should never be assigned to a Node

# Ensure the resource has a valid path to allow serialization
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Clean up the base character instance when this resource is freed
		if _base_character and _base_character is Node and is_instance_valid(_base_character):
			_base_character.queue_free()
	
	# Add serialization safety
	if what == NOTIFICATION_POSTINITIALIZE:
		# Add a resource path if one doesn't exist (needed for proper serialization)
		if resource_path.is_empty():
			# Use a temporary path that's unique for this session
			resource_path = "res://tests/generated/character_resource_%d.tres" % [Time.get_unix_time_from_system()]
