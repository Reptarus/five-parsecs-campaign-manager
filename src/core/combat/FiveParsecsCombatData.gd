extends RefCounted
class_name FiveParsecsCombatData

## Five Parsecs Combat Data - Consolidated Implementation
## Merges BaseBattleData + BaseBattleRules + BaseBattleCharacter functionality
## Framework Bible compliant: Simple data containers and validation
## Pure data structures with Five Parsecs rule constants

# Safe imports
const Character = preload("res://src/core/character/Character.gd")

## Five Parsecs Combat Constants - Direct from rulebook

# Movement rules
const BASE_MOVEMENT = 6  # 6 inches base movement
const DASH_MOVEMENT = 12  # Double move with Dash action
const DIFFICULT_TERRAIN_PENALTY = 2  # Extra inches of move cost

# Combat rules
const BASE_HIT_CHANCE = 4  # Need 4+ on d6 (modified by Combat skill)
const COVER_MODIFIER = -1  # -1 to hit when target in cover
const HEIGHT_ADVANTAGE = 1  # +1 to hit from elevated position
const POINT_BLANK_BONUS = 1  # +1 to hit at 2" or less
const LONG_RANGE_PENALTY = -1  # -1 to hit beyond 12"

# Weapon ranges (inches)
const PISTOL_RANGE = 8
const RIFLE_RANGE = 24
const SHOTGUN_RANGE = 6
const HEAVY_WEAPON_RANGE = 36

# Armor saves
const NO_ARMOR_SAVE = 7  # Impossible save
const LIGHT_ARMOR_SAVE = 6  # 6+ save
const COMBAT_ARMOR_SAVE = 5  # 5+ save
const BATTLE_SUIT_SAVE = 4  # 4+ save

# Status effects
const STUNNED_DURATION = 1  # Stunned for 1 turn
const SUPPRESSED_PENALTY = -1  # -1 to all actions when suppressed

## Combat Data Structures

# Battle participant data
class CombatCharacter:
	var character: Character
	var position: Vector2i = Vector2i(-1, -1)
	var faction: String = ""
	var actions_remaining: int = 2
	var is_stunned: bool = false
	var is_suppressed: bool = false
	var has_acted: bool = false
	var cover_bonus: bool = false
	var elevation_bonus: bool = false
	
	func _init(char: Character, f: String = ""):
		character = char
		faction = f
	
	func reset_for_turn() -> void:
		actions_remaining = 2
		has_acted = false
		is_suppressed = false  # Suppression clears each turn
	
	func can_act() -> bool:
		return actions_remaining > 0 and not is_stunned and character.health > 0
	
	func spend_action() -> bool:
		if actions_remaining > 0:
			actions_remaining -= 1
			has_acted = true
			return true
		return false

# Combat action data
class CombatAction:
	enum Type {
		MOVE,
		SHOOT,
		BRAWL,
		DASH,
		AIM,
		HUNKER_DOWN,
		SPECIAL
	}
	
	var type: Type
	var character: Character
	var target: Character = null
	var target_position: Vector2i = Vector2i(-1, -1)
	var modifiers: Dictionary = {}
	var result: Dictionary = {}
	
	func _init(action_type: Type, actor: Character):
		type = action_type
		character = actor

# Combat weapon data for battle calculations (local class)
class CombatWeaponData:
	var name: String
	var range: int
	var damage: int
	var traits: Array[String] = []
	var actions_required: int = 1
	
	func _init(weapon_name: String, weapon_range: int, weapon_damage: int):
		name = weapon_name
		range = weapon_range  
		damage = weapon_damage

# Battle objective tracking
class BattleObjective:
	enum Type {
		ELIMINATE_ENEMIES,
		HOLD_POSITION,
		RETRIEVE_ITEM,
		ESCAPE,
		CUSTOM
	}
	
	var type: Type
	var description: String
	var faction: String
	var completed: bool = false
	var progress: int = 0
	var required_progress: int = 1
	
	func _init(obj_type: Type, desc: String, target_faction: String):
		type = obj_type
		description = desc
		faction = target_faction

## Core Combat Rules Implementation

func calculate_hit_chance(attacker: Character, target: Character, range: float, modifiers: Dictionary = {}) -> int:
	"""Calculate Five Parsecs hit chance"""
	var base_chance = attacker.combat  # Combat skill is the base
	
	# Apply range modifiers
	if range <= 2:
		base_chance += POINT_BLANK_BONUS
	elif range > 12:
		base_chance += LONG_RANGE_PENALTY
	
	# Apply cover modifier
	if modifiers.get("target_in_cover", false):
		base_chance += COVER_MODIFIER
	
	# Apply height advantage
	if modifiers.get("height_advantage", false):
		base_chance += HEIGHT_ADVANTAGE
	
	# Apply suppression
	if modifiers.get("attacker_suppressed", false):
		base_chance += SUPPRESSED_PENALTY
	
	# Clamp to valid d6 range (1-6, but we'll allow auto-hit at 1+ and auto-miss at 7+)
	return clamp(base_chance, 1, 7)

func calculate_damage(weapon: CombatWeaponData, attacker: Character, target: Character) -> int:
	"""Calculate Five Parsecs damage"""
	var base_damage = weapon.damage
	
	# Character skill can affect damage (simplified)
	if attacker.combat >= 5:
		base_damage += 1
	
	return max(1, base_damage)

func calculate_armor_save(target: Character, damage: int) -> int:
	"""Calculate armor save value needed"""
	# Simplified armor system - would be enhanced with actual armor data
	if target.has_method("get_armor_save"):
		return target.get_armor_save()
	else:
		# Fallback based on character toughness
		if target.toughness >= 5:
			return LIGHT_ARMOR_SAVE
		else:
			return NO_ARMOR_SAVE

func validate_action(action: CombatAction, combat_character: CombatCharacter) -> bool:
	"""Validate if action can be performed"""
	if not combat_character.can_act():
		return false
	
	match action.type:
		CombatAction.Type.MOVE:
			return _validate_move_action(action, combat_character)
		CombatAction.Type.SHOOT:
			return _validate_shoot_action(action, combat_character)
		CombatAction.Type.BRAWL:
			return _validate_brawl_action(action, combat_character)
		CombatAction.Type.DASH:
			return combat_character.actions_remaining >= 2  # Dash requires 2 actions
		CombatAction.Type.AIM:
			return true  # Can always aim
		CombatAction.Type.HUNKER_DOWN:
			return true  # Can always hunker down
		_:
			return false

func _validate_move_action(action: CombatAction, combat_character: CombatCharacter) -> bool:
	"""Validate move action"""
	if action.target_position == Vector2i(-1, -1):
		return false
	
	# Check if position is within movement range
	var distance = _calculate_distance(combat_character.position, action.target_position)
	return distance <= BASE_MOVEMENT

func _validate_shoot_action(action: CombatAction, combat_character: CombatCharacter) -> bool:
	"""Validate shoot action"""
	if not action.target:
		return false
	
	if action.target.health <= 0:
		return false
	
	# Check range (simplified - would use actual weapon data)
	var distance = _calculate_distance(combat_character.position, action.target_position)
	return distance <= RIFLE_RANGE  # Default weapon range

func _validate_brawl_action(action: CombatAction, combat_character: CombatCharacter) -> bool:
	"""Validate brawl action"""
	if not action.target:
		return false
	
	if action.target.health <= 0:
		return false
	
	# Must be adjacent (1 inch)
	var distance = _calculate_distance(combat_character.position, action.target_position)
	return distance <= 1

## Default Weapon Database - Five Parsecs Standard

func get_default_weapons() -> Array[CombatWeaponData]:
	"""Get default Five Parsecs weapons"""
	return [
		CombatWeaponData.new("Scrap Pistol", PISTOL_RANGE, 1),
		CombatWeaponData.new("Colony Rifle", RIFLE_RANGE, 1),
		CombatWeaponData.new("Military Rifle", RIFLE_RANGE, 2),
		CombatWeaponData.new("Shotgun", SHOTGUN_RANGE, 2),
		CombatWeaponData.new("Hand Cannon", PISTOL_RANGE, 2),
		CombatWeaponData.new("Blast Rifle", RIFLE_RANGE, 1),
		CombatWeaponData.new("Needle Rifle", RIFLE_RANGE, 1),
		CombatWeaponData.new("Plasma Rifle", RIFLE_RANGE, 2),
		CombatWeaponData.new("Auto Rifle", RIFLE_RANGE, 1),
		CombatWeaponData.new("Heavy Support Weapon", HEAVY_WEAPON_RANGE, 3)
	]

func get_weapon_by_name(weapon_name: String) -> CombatWeaponData:
	"""Get weapon data by name"""
	var weapons = get_default_weapons()
	for weapon in weapons:
		if weapon.name == weapon_name:
			return weapon
	
	# Return default weapon if not found
	return CombatWeaponData.new("Basic Weapon", RIFLE_RANGE, 1)

## Combat Resolution Methods

func resolve_ranged_attack(attacker: CombatCharacter, target: CombatCharacter, weapon: CombatWeaponData, modifiers: Dictionary = {}) -> Dictionary:
	"""Resolve Five Parsecs ranged attack"""
	var distance = _calculate_distance(attacker.position, target.position)
	var hit_chance = calculate_hit_chance(attacker.character, target.character, distance, modifiers)
	
	# Roll to hit
	var hit_roll = randi() % 6 + 1
	var hit_success = hit_roll <= hit_chance
	
	var result = {
		"action": "ranged_attack",
		"attacker": attacker.character.character_name,
		"target": target.character.character_name,
		"weapon": weapon.name,
		"distance": distance,
		"hit_chance": hit_chance,
		"hit_roll": hit_roll,
		"hit": hit_success,
		"damage": 0,
		"armor_save_needed": 7,
		"armor_roll": 0,
		"final_damage": 0
	}
	
	if hit_success:
		var damage = calculate_damage(weapon, attacker.character, target.character)
		var armor_save_needed = calculate_armor_save(target.character, damage)
		var armor_roll = randi() % 6 + 1
		var armor_saved = armor_roll >= armor_save_needed
		
		result.damage = damage
		result.armor_save_needed = armor_save_needed
		result.armor_roll = armor_roll
		
		if not armor_saved:
			result.final_damage = damage
			target.character.health -= damage
		else:
			result.final_damage = 0
	
	return result

func resolve_brawl_attack(attacker: CombatCharacter, target: CombatCharacter, modifiers: Dictionary = {}) -> Dictionary:
	"""Resolve Five Parsecs brawl combat"""
	# Brawl is opposed rolls
	var attacker_roll = randi() % 6 + 1 + attacker.character.combat
	var defender_roll = randi() % 6 + 1 + target.character.combat
	
	var result = {
		"action": "brawl",
		"attacker": attacker.character.character_name,
		"target": target.character.character_name,
		"attacker_roll": attacker_roll,
		"defender_roll": defender_roll,
		"attacker_wins": false,
		"damage": 0
	}
	
	if attacker_roll > defender_roll:
		result.attacker_wins = true
		result.damage = 1  # Brawl does 1 damage
		target.character.health -= 1
	
	return result

## Utility Methods

func _calculate_distance(pos1: Vector2i, pos2: Vector2i) -> float:
	"""Calculate distance between positions"""
	var dx = abs(pos1.x - pos2.x)
	var dy = abs(pos1.y - pos2.y)
	return sqrt(dx * dx + dy * dy)

func create_combat_character(character: Character, faction: String) -> CombatCharacter:
	"""Create combat wrapper for character"""
	return CombatCharacter.new(character, faction)

func create_combat_action(action_type: CombatAction.Type, character: Character) -> CombatAction:
	"""Create combat action"""
	return CombatAction.new(action_type, character)

func create_battle_objective(obj_type: BattleObjective.Type, description: String, faction: String) -> BattleObjective:
	"""Create battle objective"""
	return BattleObjective.new(obj_type, description, faction)

## Data Validation

func validate_character_data(character: Character) -> bool:
	"""Validate character has required combat data"""
	if not character:
		return false
	
	if character.character_name.is_empty():
		return false
	
	if character.health <= 0:
		return false
	
	if character.combat < 1 or character.combat > 6:
		return false
	
	return true

func validate_combat_state(combat_characters: Array) -> Array[String]:
	"""Validate combat state and return any errors"""
	var errors: Array[String] = []
	
	if combat_characters.is_empty():
		errors.append("No combat characters found")
		return errors
	
	var factions = {}
	for combat_char in combat_characters:
		if not validate_character_data(combat_char.character):
			errors.append("Invalid character data: " + combat_char.character.character_name)
		
		factions[combat_char.faction] = true
	
	if factions.size() < 2:
		errors.append("Need at least 2 factions for combat")
	
	return errors

## Legacy Compatibility

func get_battle_rules() -> Dictionary:
	"""Legacy method for BaseBattleRules compatibility"""
	return {
		"base_movement": BASE_MOVEMENT,
		"base_hit_chance": BASE_HIT_CHANCE,
		"cover_modifier": COVER_MODIFIER,
		"height_advantage": HEIGHT_ADVANTAGE
	}

func get_combat_constants() -> Dictionary:
	"""Legacy method for combat constants"""
	return {
		"movement": BASE_MOVEMENT,
		"dash_movement": DASH_MOVEMENT,
		"pistol_range": PISTOL_RANGE,
		"rifle_range": RIFLE_RANGE,
		"cover_modifier": COVER_MODIFIER,
		"height_advantage": HEIGHT_ADVANTAGE
	}