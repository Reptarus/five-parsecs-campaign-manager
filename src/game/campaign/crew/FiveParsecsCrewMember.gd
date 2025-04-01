@tool
# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends BaseCrewMember

const Self = preload("res://src/game/campaign/crew/FiveParsecsCrewMember.gd")
const BaseCrewMember = preload("res://src/base/campaign/crew/BaseCrewMember.gd")
const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const FiveParsecsGameEnums = preload("res://src/game/campaign/crew/FiveParsecsGameEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const GameWeapon = preload("res://src/core/systems/items/GameWeapon.gd")
const CharacterInventory = preload("res://src/core/character/Equipment/CharacterInventory.gd")

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
	if not character:
		character = Character.new()
	if not inventory:
		inventory = CharacterInventory.new()

func _init() -> void:
	# Basic initialization - detailed setup happens in _ready
	character = Character.new()
	inventory = CharacterInventory.new()
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
	# Equip default gear based on character class
	if not inventory:
		push_error("Inventory not initialized")
		return
		
	# Clear existing inventory
	inventory.clear()
	
	# Add default weapon based on class
	var default_weapon = GameWeapon.new()
	match character_class:
		FiveParsecsGameEnums.CharacterClass.SOLDIER:
			default_weapon.weapon_type = GameEnums.WeaponType.RIFLE
		FiveParsecsGameEnums.CharacterClass.SECURITY:
			default_weapon.weapon_type = GameEnums.WeaponType.PISTOL
		FiveParsecsGameEnums.CharacterClass.BOT_TECH:
			default_weapon.weapon_type = GameEnums.WeaponType.HEAVY
		FiveParsecsGameEnums.CharacterClass.MERCHANT:
			default_weapon.weapon_type = GameEnums.WeaponType.PISTOL
		_:
			default_weapon.weapon_type = GameEnums.WeaponType.PISTOL
	
	inventory.add_weapon(default_weapon)
	active_weapon = default_weapon
	
	# Add class-specific equipment
	match character_class:
		FiveParsecsGameEnums.CharacterClass.MEDIC:
			var medkit = create_equipment_item(GameEnums.ItemType.CONSUMABLE, "Medkit")
			inventory.add_equipment(medkit)
		FiveParsecsGameEnums.CharacterClass.ENGINEER:
			var toolkit = create_equipment_item(GameEnums.ItemType.GEAR, "Toolkit")
			inventory.add_equipment(toolkit)

# Helper function to create equipment items
func create_equipment_item(item_type: int, item_name: String) -> Dictionary:
	return {
		"type": item_type,
		"name": item_name,
		"description": "Standard issue " + item_name.to_lower(),
		"value": 10,
		"weight": 1
	}

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
	
	emit_signal("status_changed", status)

func remove_status_effect(effect_name: String) -> void:
	# Reset status to healthy
	status = GameEnums.CharacterStatus.HEALTHY
	recovery_time = 0
	is_inspired = false
	is_focused = false
	is_enraged = false

func get_stat_modifier(stat_name: String) -> int:
	# Get modifiers for stats based on status effects
	var modifier = 0
	
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

func from_dict(data: Dictionary) -> bool:
	if not data is Dictionary or data.is_empty():
		return false
		
	if not super.from_dict(data):
		return false
	
	# Five Parsecs Specific data
	if data.has("recovery_time"): recovery_time = data.recovery_time
	if data.has("is_inspired"): is_inspired = data.is_inspired
	if data.has("is_focused"): is_focused = data.is_focused
	if data.has("is_enraged"): is_enraged = data.is_enraged
	
	# Setup character and inventory if needed
	_initialize_character()
	
	# Load character data if available
	if data.has("character") and character != null and character.has_method("from_dictionary"):
		if not character.from_dictionary(data.character):
			push_error("Failed to load character data")
			return false
	
	# Load inventory data if available
	if data.has("inventory") and inventory != null and inventory.has_method("from_dictionary"):
		if not inventory.from_dictionary(data.inventory):
			push_error("Failed to load inventory data")
			return false
	
	# Apply class bonuses if not already applied
	_apply_class_bonuses()
	
	return true

func initialize_from_data(member_data: Dictionary) -> void:
	# Set basic properties
	if member_data.has("character_name"):
		character_name = member_data.character_name
	
	if member_data.has("character_class"):
		character_class = member_data.character_class
		_apply_class_bonuses()
	
	# These properties were causing linter errors because they don't exist in this class
	# If these properties are needed, they should be added to the class definition first
	# if member_data.has("species"):
	#	species = member_data.species
	
	# if member_data.has("background"):
	#	background = member_data.background
	
	if member_data.has("level"):
		level = member_data.level
	
	if member_data.has("experience"):
		experience = member_data.experience
	
	# Set attributes
	if member_data.has("combat_skill"):
		combat_skill = member_data.combat_skill
	
	if member_data.has("reactions"):
		reactions = member_data.reactions
	
	if member_data.has("toughness"):
		toughness = member_data.toughness
	
	if member_data.has("savvy"):
		savvy = member_data.savvy
	
	# Set status
	if member_data.has("recovery_time"):
		recovery_time = member_data.recovery_time
	
	if member_data.has("is_inspired"):
		is_inspired = member_data.is_inspired
	
	if member_data.has("is_focused"):
		is_focused = member_data.is_focused
	
	if member_data.has("is_enraged"):
		is_enraged = member_data.is_enraged
	
	# Initialize character if it exists
	if member_data.has("character") and character:
		# If character has an initialize method, use it
		if character.has_method("initialize_from_data"):
			character.initialize_from_data(member_data.character)
		# Otherwise try to set common properties manually
		else:
			if member_data.character.has("health"):
				character.health = member_data.character.health
			if member_data.character.has("max_health"):
				character.max_health = member_data.character.max_health
	
	# Initialize inventory if it exists
	if member_data.has("inventory") and inventory:
		# If inventory has an initialize method, use it
		if inventory.has_method("initialize_from_data"):
			inventory.initialize_from_data(member_data.inventory)
		# Otherwise try to set common properties manually
		elif member_data.inventory.has("items") and member_data.inventory.items is Array:
			# Add each item to inventory
			for item_data in member_data.inventory.items:
				# This is a simplified version - you'd need proper item creation logic
				if inventory.has_method("add_item"):
					# Create item based on type
					if item_data.has("type"):
						var item = null
						match item_data.type:
							"weapon":
								item = GameWeapon.new()
								if item.has_method("initialize_from_data"):
									item.initialize_from_data(item_data)
							# Add other item types as needed
						
						if item and inventory.has_method("add_item"):
							inventory.add_item(item)