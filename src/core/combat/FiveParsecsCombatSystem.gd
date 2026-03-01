extends Node
class_name FiveParsecsCombatSystem

## Five Parsecs Combat System - Consolidated Implementation
## Merges BaseCombatManager + BaseMainBattleController functionality
## Framework Bible compliant: Simple, direct Five Parsecs combat implementation
## Replaces 8 complex Base classes with unified combat system

# Safe imports
const Character = preload("res://src/core/character/Character.gd")
const FiveParsecsBattlefield = preload("res://src/core/combat/FiveParsecsBattlefield.gd")
const FiveParsecsCombatData = preload("res://src/core/combat/FiveParsecsCombatData.gd")

# Core combat signals - simplified from multiple signal sources
signal combat_started(battle_data: Dictionary)
signal combat_ended(result: Dictionary)
signal turn_started(turn_number: int, active_faction: String)
signal turn_ended(turn_number: int, active_faction: String)
signal character_activated(character: Character)
signal character_action_completed(character: Character, action: String)
signal combat_result_calculated(attacker: Character, target: Character, result: Dictionary)
signal reaction_dice_rolled(dice_pool: Array, crew_size: int)
signal reaction_dice_assigned(character_name: String, die_value: int, is_quick: bool)

# Combat state - unified state management
enum CombatPhase {
	SETUP,
	DEPLOYMENT,
	BATTLE,
	RESOLUTION,
	CLEANUP
}

enum ActionType {
	MOVE,
	SHOOT,
	BRAWL,
	DASH,
	AIM,
	HUNKER_DOWN,
	SPECIAL
}

# Combat data
var current_phase: CombatPhase = CombatPhase.SETUP
var current_turn: int = 0
var active_faction: String = ""
var active_character: Character = null
var combat_active: bool = false

# Battle participants
var crew_characters: Array[Character] = []
var enemy_characters: Array[Character] = []
var all_characters: Array[Character] = []

# Combat systems
var battlefield: FiveParsecsBattlefield = null
var combat_data: FiveParsecsCombatData = null

# Reaction dice system (Five Parsecs rules)
var reaction_dice_pool: Array[int] = []
var reaction_dice_assignments: Dictionary = {}  # character_name -> die_value
var unassigned_dice: Array[int] = []

# Five Parsecs combat rules - direct implementation
const BASE_MOVEMENT_INCHES = 6
const DASH_MOVEMENT_INCHES = 12
const BASE_ATTACK_RANGE = 24
const COVER_MODIFIER = -1  # -1 to hit when in cover
const HEIGHT_ADVANTAGE = 1  # +1 to hit from higher ground

func _ready() -> void:
	print("FiveParsecsCombatSystem: Initialized consolidated combat system")
	_setup_combat_systems()

func _setup_combat_systems() -> void:
	## Initialize combat subsystems
	if not battlefield:
		battlefield = FiveParsecsBattlefield.new()
		add_child(battlefield)
	
	if not combat_data:
		combat_data = FiveParsecsCombatData.new()

## Main Combat Flow - Simple state machine

func start_combat(crew: Array, enemies: Array, mission_data: Dictionary = {}) -> void:
	## Start a Five Parsecs combat encounter
	print("FiveParsecsCombatSystem: Starting combat encounter")

	# Initialize combat data - accept untyped arrays for compatibility
	crew_characters.clear()
	for c in crew:
		if c is Character:
			crew_characters.append(c)
	enemy_characters.clear()
	for e in enemies:
		if e is Character:
			enemy_characters.append(e)
	all_characters = crew_characters + enemy_characters
	
	# Reset combat state
	current_turn = 0
	current_phase = CombatPhase.SETUP
	combat_active = true
	
	# Setup battlefield
	if battlefield:
		battlefield.generate_battlefield(mission_data)
	
	# Move to deployment
	_advance_to_deployment()
	
	combat_started.emit({
		"crew_size": crew_characters.size(),
		"enemy_size": enemy_characters.size(),
		"mission_type": mission_data.get("type", "standard")
	})

func _advance_to_deployment() -> void:
	## Handle deployment phase
	current_phase = CombatPhase.DEPLOYMENT
	print("FiveParsecsCombatSystem: Deployment phase")
	
	# Deploy characters (simplified Five Parsecs deployment)
	_deploy_characters()
	
	# Start battle phase
	_advance_to_battle()

func _deploy_characters() -> void:
	## Deploy characters using Five Parsecs rules
	if not battlefield:
		return
	
	# Deploy crew on one side
	var crew_deployment_zone = battlefield.get_deployment_zone("crew")
	for i in range(crew_characters.size()):
		var character = crew_characters[i]
		var position = crew_deployment_zone[i % crew_deployment_zone.size()]
		battlefield.place_character(character, position)
	
	# Deploy enemies on opposite side
	var enemy_deployment_zone = battlefield.get_deployment_zone("enemy")
	for i in range(enemy_characters.size()):
		var character = enemy_characters[i]
		var position = enemy_deployment_zone[i % enemy_deployment_zone.size()]
		battlefield.place_character(character, position)

func _advance_to_battle() -> void:
	## Start battle phase with turn sequence
	current_phase = CombatPhase.BATTLE
	current_turn = 1
	active_faction = "crew"  # Crew always goes first in Five Parsecs
	
	print("FiveParsecsCombatSystem: Battle phase started")
	_start_turn()

func _start_turn() -> void:
	## Start a new turn for the active faction
	print("FiveParsecsCombatSystem: Turn %d - %s faction" % [current_turn, active_faction])
	turn_started.emit(current_turn, active_faction)

	# Roll reaction dice at start of crew's turn (Five Parsecs rules)
	if active_faction == "crew":
		roll_reaction_dice()

	# Get characters for active faction
	var active_characters = crew_characters if active_faction == "crew" else enemy_characters

	# Process each character's activation
	for character in active_characters:
		if character.health > 0:  # Only activate conscious characters
			_activate_character(character)

	_end_turn()

## Reaction Dice System (Five Parsecs Core Rules)

func roll_reaction_dice() -> void:
	## Roll reaction dice at start of crew turn - one D6 per crew member
	var living_crew = crew_characters.filter(func(c): return c.health > 0)
	var crew_size = living_crew.size()

	# Clear previous assignments
	reaction_dice_pool.clear()
	reaction_dice_assignments.clear()
	unassigned_dice.clear()

	# Roll one D6 per living crew member
	for i in range(crew_size):
		var die_value = randi() % 6 + 1
		reaction_dice_pool.append(die_value)
		unassigned_dice.append(die_value)

	# Sort unassigned dice for easier assignment (highest first)
	unassigned_dice.sort()
	unassigned_dice.reverse()

	print("FiveParsecsCombatSystem: Rolled %d reaction dice: %s" % [crew_size, str(reaction_dice_pool)])
	reaction_dice_rolled.emit(reaction_dice_pool, crew_size)

func assign_reaction_die(character: Character, die_index: int) -> bool:
	## Assign a reaction die to a character - determines Quick vs Slow action
	if die_index < 0 or die_index >= unassigned_dice.size():
		return false

	if not character or character.character_name in reaction_dice_assignments:
		return false

	var die_value = unassigned_dice[die_index]
	unassigned_dice.remove_at(die_index)
	reaction_dice_assignments[character.character_name] = die_value

	# Determine if Quick Action (die <= Reactions stat) or Slow Action (die > Reactions)
	var reactions_stat = _get_character_reactions(character)
	var is_quick = die_value <= reactions_stat

	print("FiveParsecsCombatSystem: %s assigned die %d (Reactions: %d) - %s Action" % [
		character.character_name, die_value, reactions_stat,
		"Quick" if is_quick else "Slow"
	])

	reaction_dice_assigned.emit(character.character_name, die_value, is_quick)
	return true

func _get_character_reactions(character: Character) -> int:
	## Get character's Reactions stat for Quick/Slow determination
	if character.has_method("get_reactions"):
		return character.get_reactions()
	elif "reactions" in character:
		return character.reactions
	elif "stats" in character and character.stats is Dictionary:
		return character.stats.get("reactions", 1)
	# Default reactions value
	return 1

func is_quick_action(character: Character) -> bool:
	## Check if character has a Quick Action this turn
	if not character.character_name in reaction_dice_assignments:
		return false

	var die_value = reaction_dice_assignments[character.character_name]
	var reactions_stat = _get_character_reactions(character)
	return die_value <= reactions_stat

func get_unassigned_dice() -> Array[int]:
	## Get remaining unassigned reaction dice
	return unassigned_dice

func get_reaction_dice_state() -> Dictionary:
	## Get current reaction dice state for UI
	return {
		"pool": reaction_dice_pool,
		"assignments": reaction_dice_assignments,
		"unassigned": unassigned_dice
	}

func _activate_character(character: Character) -> void:
	## Activate a character for their turn
	active_character = character
	character_activated.emit(character)
	
	print("FiveParsecsCombatSystem: Activating %s" % character.character_name)
	
	# AI or player decision making would happen here
	# For now, perform a basic action
	_perform_character_action(character)

func _perform_character_action(character: Character) -> void:
	## Perform action for character (AI or player controlled)
	# Simple AI: Move toward nearest enemy and shoot if possible
	var action_result = {}
	
	if active_faction == "enemy":
		action_result = _perform_ai_action(character)
	else:
		# Player character - would normally wait for player input
		action_result = _perform_default_action(character)
	
	character_action_completed.emit(character, action_result.get("action", "none"))

func _perform_ai_action(character: Character) -> Dictionary:
	## Simple AI for enemy characters
	# Find nearest crew member
	var nearest_target = _find_nearest_target(character, crew_characters)
	if not nearest_target:
		return {"action": "none"}
	
	var character_pos = battlefield.get_character_position(character)
	var target_pos = battlefield.get_character_position(nearest_target)
	
	if not character_pos or not target_pos:
		return {"action": "none"}
	
	var distance = battlefield.calculate_distance(character_pos, target_pos)
	
	# If within range, shoot. Otherwise, move closer
	if distance <= BASE_ATTACK_RANGE:
		return _perform_ranged_attack(character, nearest_target)
	else:
		return _perform_move_action(character, target_pos)

func _perform_default_action(character: Character) -> Dictionary:
	## Default action for player characters when no input
	# Simple default: hunker down
	return {"action": "hunker_down", "character": character.character_name}

func _find_nearest_target(character: Character, targets: Array) -> Character:
	## Find nearest living target
	var nearest: Character = null
	var min_distance = INF
	var character_pos = battlefield.get_character_position(character)
	
	if not character_pos:
		return null
	
	for target in targets:
		if target.health <= 0:
			continue
		
		var target_pos = battlefield.get_character_position(target)
		if not target_pos:
			continue
		
		var distance = battlefield.calculate_distance(character_pos, target_pos)
		if distance < min_distance:
			min_distance = distance
			nearest = target
	
	return nearest

func _perform_ranged_attack(attacker: Character, target: Character) -> Dictionary:
	## Perform Five Parsecs ranged attack
	var attacker_pos = battlefield.get_character_position(attacker)
	var target_pos = battlefield.get_character_position(target)
	
	if not attacker_pos or not target_pos:
		return {"action": "attack_failed", "reason": "position_error"}
	
	# Five Parsecs attack calculation
	var base_skill = attacker.combat
	var hit_modifiers = 0
	
	# Check for cover
	if battlefield.has_cover(target_pos):
		hit_modifiers += COVER_MODIFIER
	
	# Check for height advantage
	if battlefield.has_height_advantage(attacker_pos, target_pos):
		hit_modifiers += HEIGHT_ADVANTAGE
	
	# Roll to hit (Five Parsecs uses d6)
	var hit_roll = randi() % 6 + 1
	var modified_skill = base_skill + hit_modifiers
	
	var hit_success = hit_roll <= modified_skill
	
	var result = {
		"action": "ranged_attack",
		"attacker": attacker.character_name,
		"target": target.character_name,
		"hit_roll": hit_roll,
		"modified_skill": modified_skill,
		"hit": hit_success
	}
	
	if hit_success:
		# Apply damage
		var damage = _calculate_damage(attacker, target)
		target.health -= damage
		result["damage"] = damage
		result["target_health"] = target.health
		
		print("FiveParsecsCombatSystem: %s hits %s for %d damage" % [attacker.character_name, target.character_name, damage])
	else:
		print("FiveParsecsCombatSystem: %s misses %s" % [attacker.character_name, target.character_name])
	
	combat_result_calculated.emit(attacker, target, result)
	return result

func _perform_move_action(character: Character, target_position: Vector2i) -> Dictionary:
	## Move character toward target position
	var current_pos = battlefield.get_character_position(character)
	if not current_pos:
		return {"action": "move_failed", "reason": "no_position"}
	
	# Simple move toward target (would be more sophisticated in full implementation)
	var new_position = battlefield.find_move_toward(current_pos, target_position, BASE_MOVEMENT_INCHES)
	battlefield.move_character(character, new_position)
	
	return {
		"action": "move",
		"character": character.character_name,
		"from": current_pos,
		"to": new_position
	}

func _calculate_damage(attacker: Character, target: Character) -> int:
	## Calculate Five Parsecs damage
	# Simple damage calculation - would be enhanced with weapon data
	var base_damage = 1
	
	# Character combat skill affects damage potential
	if attacker.combat >= 5:
		base_damage += 1
	
	# Target toughness reduces damage
	if target.toughness >= 4:
		base_damage = max(0, base_damage - 1)
	
	return max(1, base_damage)  # Always at least 1 damage

func _end_turn() -> void:
	## End current turn and advance to next faction
	turn_ended.emit(current_turn, active_faction)
	
	# Switch faction
	if active_faction == "crew":
		active_faction = "enemy"
		_start_turn()
	else:
		active_faction = "crew"
		current_turn += 1
		
		# Check for battle end conditions
		if _check_battle_end():
			_end_combat()
		else:
			_start_turn()

func _check_battle_end() -> bool:
	## Check if battle should end
	# Count living characters
	var living_crew = 0
	var living_enemies = 0
	
	for character in crew_characters:
		if character.health > 0:
			living_crew += 1
	
	for character in enemy_characters:
		if character.health > 0:
			living_enemies += 1
	
	# Battle ends if one side is eliminated
	return living_crew == 0 or living_enemies == 0

func _end_combat() -> void:
	## End combat and cleanup
	current_phase = CombatPhase.RESOLUTION
	combat_active = false
	
	# Determine winner
	var living_crew = crew_characters.filter(func(c): return c.health > 0).size()
	var living_enemies = enemy_characters.filter(func(c): return c.health > 0).size()
	
	var result = {
		"victory": "draw",
		"living_crew": living_crew,
		"living_enemies": living_enemies,
		"total_turns": current_turn
	}
	
	if living_crew > 0 and living_enemies == 0:
		result.victory = "crew"
	elif living_enemies > 0 and living_crew == 0:
		result.victory = "enemy"
	
	print("FiveParsecsCombatSystem: Combat ended - %s victory" % result.victory)
	combat_ended.emit(result)
	
	# Cleanup
	_cleanup_combat()

func _cleanup_combat() -> void:
	## Cleanup combat state
	current_phase = CombatPhase.CLEANUP
	active_character = null
	active_faction = ""

	# Clear character arrays
	crew_characters.clear()
	enemy_characters.clear()
	all_characters.clear()

	# Clear reaction dice state
	reaction_dice_pool.clear()
	reaction_dice_assignments.clear()
	unassigned_dice.clear()

	print("FiveParsecsCombatSystem: Combat cleanup completed")

## Utility Methods

func get_combat_state() -> Dictionary:
	## Get current combat state for UI/debugging
	return {
		"phase": CombatPhase.keys()[current_phase],
		"turn": current_turn,
		"active_faction": active_faction,
		"active_character": active_character.character_name if active_character else "",
		"combat_active": combat_active,
		"crew_count": crew_characters.size(),
		"enemy_count": enemy_characters.size()
	}

func is_combat_active() -> bool:
	## Check if combat is currently active
	return combat_active and current_phase == CombatPhase.BATTLE

func get_battlefield() -> FiveParsecsBattlefield:
	## Get battlefield reference for UI
	return battlefield

func get_combat_data() -> FiveParsecsCombatData:
	## Get combat data reference
	return combat_data

## Legacy compatibility methods for migration

func initialize_battle(crew: Array, enemies: Array) -> void:
	## Legacy method for BaseBattleController compatibility
	start_combat(crew, enemies)

func process_turn() -> void:
	## Legacy method - turn processing is now automatic
	pass