@tool
extends Node
class_name FPCM_CrewMember

signal health_changed(new_health: int)
signal status_changed(new_status: FiveParsecsGameEnums.CharacterStatus)
signal experience_gained(amount: int)
signal level_up(new_level: int)

# Dependencies
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameEnums = preload("res://src/game/campaign/crew/FiveParsecsGameEnums.gd")

# Character data
var character: Node
var inventory: Dictionary = {}
var active_weapon: Dictionary = {}

# Basic character attributes
var character_class: FiveParsecsGameEnums.CharacterClass = FiveParsecsGameEnums.CharacterClass.SOLDIER
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
var status: GameEnums.CharacterStatus = GameEnums.CharacterStatus.HEALTHY

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
		FiveParsecsGameEnums.CharacterClass.SOLDIER:
			combat_skill = 1
		FiveParsecsGameEnums.CharacterClass.SECURITY:
			reactions = 2
		FiveParsecsGameEnums.CharacterClass.BROKER:
			savvy = 1
		FiveParsecsGameEnums.CharacterClass.ENGINEER:
			savvy = 1
		FiveParsecsGameEnums.CharacterClass.MEDIC:
			savvy = 1
		FiveParsecsGameEnums.CharacterClass.BOT_TECH:
			toughness = 4
			speed = 3
		FiveParsecsGameEnums.CharacterClass.MERCHANT:
			reactions = 2
		FiveParsecsGameEnums.CharacterClass.ROGUE:
			speed = 3
		FiveParsecsGameEnums.CharacterClass.PSIONICIST:
			savvy = 2
		FiveParsecsGameEnums.CharacterClass.TECH:
			savvy = 2
		FiveParsecsGameEnums.CharacterClass.BRUTE:
			toughness = 3
		FiveParsecsGameEnums.CharacterClass.GUNSLINGER:
			combat_skill = 2
		FiveParsecsGameEnums.CharacterClass.ACADEMIC:
			savvy = 2
		FiveParsecsGameEnums.CharacterClass.PILOT:
			reactions = 3

func set_default_stats() -> void:
	# Set default stats based on Five Parsecs rules
	max_health = 10 + toughness
	health = max_health
	morale = 10
	status = GameEnums.CharacterStatus.HEALTHY

func equip_default_gear() -> void:
	# Simplified gear setup
	if not inventory:
		inventory = {}
	
	# Add basic weapon data
	var default_weapon = {
		"name": "Basic Weapon",
		"type": GameEnums.WeaponType.PISTOL,
		"damage": 1
	}
	
	match character_class:
		FiveParsecsGameEnums.CharacterClass.SOLDIER:
			default_weapon.type = GameEnums.WeaponType.RIFLE
		FiveParsecsGameEnums.CharacterClass.SECURITY:
			default_weapon.type = GameEnums.WeaponType.PISTOL
		FiveParsecsGameEnums.CharacterClass.BOT_TECH:
			default_weapon.type = GameEnums.WeaponType.HEAVY
		FiveParsecsGameEnums.CharacterClass.MERCHANT:
			default_weapon.type = GameEnums.WeaponType.PISTOL
		_:
			default_weapon.type = GameEnums.WeaponType.PISTOL
	
	inventory["weapon"] = default_weapon
	active_weapon = default_weapon

func handle_incapacitation() -> void:
	# Handle character being reduced to 0 health
	status = GameEnums.CharacterStatus.CRITICAL
	
	# Roll for injury
	var injury_roll = randi() % 6 + 1
	if injury_roll <= 2:
		# Minor injury - will recover after battle
		status = GameEnums.CharacterStatus.INJURED
	elif injury_roll <= 5:
		# Serious injury - will need medical attention
		status = GameEnums.CharacterStatus.CRITICAL
	else:
		# Critical injury - may die without immediate help
		status = GameEnums.CharacterStatus.CRITICAL

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
			status = GameEnums.CharacterStatus.INJURED
		"suppress":
			status = GameEnums.CharacterStatus.INJURED
		"disarmed":
			status = GameEnums.CharacterStatus.INJURED
		"bleeding":
			status = GameEnums.CharacterStatus.INJURED
		"inspire":
			status = GameEnums.CharacterStatus.HEALTHY
			is_inspired = true
		"focus":
			status = GameEnums.CharacterStatus.HEALTHY
			is_focused = true
		"rage":
			status = GameEnums.CharacterStatus.HEALTHY
			is_enraged = true
		"tech_boost":
			status = GameEnums.CharacterStatus.HEALTHY
		"wounded":
			status = GameEnums.CharacterStatus.INJURED
		"seriously_wounded":
			status = GameEnums.CharacterStatus.CRITICAL
		"critically_wounded":
			status = GameEnums.CharacterStatus.CRITICAL
	
	status_changed.emit( status)

func remove_status_effect(effect_name: String) -> void:
	# Reset status to healthy
	status = GameEnums.CharacterStatus.HEALTHY
	recovery_time = 0
	is_inspired = false
	is_focused = false
	is_enraged = false

func get_stat_modifier(stat_name: String) -> int:
	# Get modifiers for stats based on status effects
	var modifier: int = 0
	
	match status:
		GameEnums.CharacterStatus.HEALTHY:
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
		GameEnums.CharacterStatus.INJURED:
			if stat_name in ["combat_skill", "speed"]:
				modifier -= 1
		GameEnums.CharacterStatus.CRITICAL:
			if stat_name in ["combat_skill", "reactions", "speed"]:
				modifier -= 3
	
	return modifier
