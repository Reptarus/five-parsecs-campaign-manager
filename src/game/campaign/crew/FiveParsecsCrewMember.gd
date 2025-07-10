@tool
extends Node
class_name FPCM_CrewMember

signal health_changed(new_health: int)
signal status_changed(new_status: GlobalEnums.CharacterStatus)
signal experience_gained(amount: int)
signal level_up(new_level: int)

# Dependencies
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Character data
var character: Node
var inventory: Dictionary = {}
var active_weapon: Dictionary = {}

# Basic character attributes
var character_class: FiveParsecsGlobalEnums.CharacterClass = FiveParsecsGlobalEnums.CharacterClass.SOLDIER
var combat_skill: int = 0
var reactions: int = 0
var savvy: int = 0
var toughness: int = 3
var speed: int = 4
var luck: int = 0

# Health and status
var health: int = 10
var max_health: int = 10
var morale: int = 10
var status: GlobalEnums.CharacterStatus = GlobalEnums.CharacterStatus.HEALTHY

# Experience
var level: int = 1
var experience: int = 0

# Character identity
var character_name: String = "Crew Member"
var traits: Array[String] = []
var advances_available: int = 0

# Status tracking
var recovery_time: int = 0
var is_inspired: bool = false
var is_focused: bool = false
var is_enraged: bool = false

func _ready() -> void:
	# Override the base _ready to call our specific initialization
	_initialize_character()
	set_default_stats()
	equip_default_gear()

func _initialize_character() -> void:
	# Basic character initialization - simplified
	if not character:
		character = Node.new()
	if not inventory:
		inventory = {}

func _init() -> void:
	# Basic initialization - detailed setup happens in _ready
	_initialize_character()
	_apply_class_bonuses()

func _apply_class_bonuses() -> void:
	match character_class:
		FiveParsecsGlobalEnums.CharacterClass.SOLDIER:
			combat_skill = 1
		FiveParsecsGlobalEnums.CharacterClass.SECURITY:
			reactions = 2
		FiveParsecsGlobalEnums.CharacterClass.BROKER:
			savvy = 1
		FiveParsecsGlobalEnums.CharacterClass.ENGINEER:
			savvy = 1
		FiveParsecsGlobalEnums.CharacterClass.MEDIC:
			savvy = 1
		FiveParsecsGlobalEnums.CharacterClass.BOT_TECH:
			toughness = 4
			speed = 3
		FiveParsecsGlobalEnums.CharacterClass.MERCHANT:
			reactions = 2
		GlobalEnums.CharacterClass.ROGUE:
			speed = 3
		GlobalEnums.CharacterClass.PSIONICIST:
			savvy = 2
		GlobalEnums.CharacterClass.TECH:
			savvy = 2
		GlobalEnums.CharacterClass.BRUTE:
			toughness = 3
		GlobalEnums.CharacterClass.GUNSLINGER:
			combat_skill = 2
		GlobalEnums.CharacterClass.ACADEMIC:
			savvy = 2
		GlobalEnums.CharacterClass.PILOT:
			reactions = 3

func set_default_stats() -> void:
	# Set default stats based on Five Parsecs rules
	max_health = 10 + toughness
	health = max_health
	morale = 10
	status = GlobalEnums.CharacterStatus.HEALTHY

func equip_default_gear() -> void:
	# Simplified gear setup
	if not inventory:
		inventory = {}

	# Add basic weapon data
	var default_weapon = {
		"name": "Basic Weapon",
		"type": GlobalEnums.WeaponType.PISTOL,
		"damage": 1
	}

	match character_class:
		FiveParsecsGlobalEnums.CharacterClass.SOLDIER:
			default_weapon.type = GlobalEnums.WeaponType.RIFLE
		FiveParsecsGlobalEnums.CharacterClass.SECURITY:
			default_weapon.type = GlobalEnums.WeaponType.PISTOL
		FiveParsecsGlobalEnums.CharacterClass.BOT_TECH:
			default_weapon.type = GlobalEnums.WeaponType.HEAVY
		FiveParsecsGlobalEnums.CharacterClass.MERCHANT:
			default_weapon.type = GlobalEnums.WeaponType.PISTOL
		_:
			default_weapon.type = GlobalEnums.WeaponType.PISTOL

	inventory["weapon"] = default_weapon
	active_weapon = default_weapon

func handle_incapacitation() -> void:
	# Handle character being reduced to 0 health
	status = GlobalEnums.CharacterStatus.CRITICAL

	# Roll for injury
	var injury_roll = randi() % 6 + 1
	if injury_roll <= 2:
		# Minor injury - will recover after battle
		status = GlobalEnums.CharacterStatus.INJURED
	elif injury_roll <= 5:
		# Serious injury - will need medical attention
		status = GlobalEnums.CharacterStatus.CRITICAL
	else:
		# Critical injury - may die without immediate help
		status = GlobalEnums.CharacterStatus.CRITICAL

func apply_status_effect(effect_data: Dictionary) -> void:
	# Apply status effects specific to Five Parsecs
	var effect = effect_data.get("effect", "")

	var duration = effect_data.get("duration", 1)

	# Store the recovery time
	recovery_time = duration

	# Reset status flags
	is_inspired = false
	is_focused = false
	is_enraged = false

	# Map our custom status effects to the available CharacterStatus enum values
	match effect:
		"stunned", "stun":
			status = GlobalEnums.CharacterStatus.INJURED
		"suppress":
			status = GlobalEnums.CharacterStatus.INJURED
		"disarmed":
			status = GlobalEnums.CharacterStatus.INJURED
		"bleeding":
			status = GlobalEnums.CharacterStatus.INJURED
		"inspire":
			status = GlobalEnums.CharacterStatus.HEALTHY
			is_inspired = true
		"focus":
			status = GlobalEnums.CharacterStatus.HEALTHY
			is_focused = true
		"rage":
			status = GlobalEnums.CharacterStatus.HEALTHY
			is_enraged = true
		"tech_boost":
			status = GlobalEnums.CharacterStatus.HEALTHY
		"wounded":
			status = GlobalEnums.CharacterStatus.INJURED
		"seriously_wounded":
			status = GlobalEnums.CharacterStatus.CRITICAL
		"critically_wounded":
			status = GlobalEnums.CharacterStatus.CRITICAL

	status_changed.emit(status)

func remove_status_effect(effect_name: String) -> void:
	# Reset status to healthy
	status = GlobalEnums.CharacterStatus.HEALTHY
	recovery_time = 0
	is_inspired = false
	is_focused = false
	is_enraged = false

func get_stat_modifier(stat_name: String) -> int:
	# Get modifiers for stats based on status effects
	var modifier: int = 0

	match status:
		GlobalEnums.CharacterStatus.HEALTHY:
			if is_inspired:
				if stat_name == "combat_skill":
					modifier += 1
			if is_focused:
				if stat_name == "reactions":
					modifier += 1
			if is_enraged:
				if stat_name == "combat_skill":
					modifier += 1
				if stat_name == "reactions":
					modifier -= 1
		GlobalEnums.CharacterStatus.INJURED:
			if stat_name in ["combat_skill", "speed"]:
				modifier -= 1
		GlobalEnums.CharacterStatus.CRITICAL:
			if stat_name in ["combat_skill", "reactions", "speed"]:
				modifier -= 3

	return modifier

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null