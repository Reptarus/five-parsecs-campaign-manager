class_name MilitaryHierarchySystem
extends Node

## MilitaryHierarchySystem
##
## Manages military rank progression and command abilities for Bug Hunt DLC.
## Provides rank-based bonuses, leadership abilities, and tactical commands.
##
## Usage:
##   MilitaryHierarchySystem.assign_initial_ranks(squad)
##   MilitaryHierarchySystem.promote_soldier(soldier)
##   MilitaryHierarchySystem.get_command_bonus(leader, soldiers)

signal soldier_promoted(soldier: Dictionary, old_rank: String, new_rank: String)
signal command_ability_used(leader: Dictionary, ability: String, targets: Array)
signal leadership_bonus_applied(leader: Dictionary, target: Dictionary, bonus: int)

## Military ranks
enum Rank {
	PRIVATE,      # Base rank
	CORPORAL,     # Squad leader
	SERGEANT,     # Veteran leader
	LIEUTENANT,   # Officer
	CAPTAIN       # Commanding officer
}

## Command abilities by rank
const RANK_ABILITIES := {
	Rank.PRIVATE: [],
	Rank.CORPORAL: ["inspire_nearby"],
	Rank.SERGEANT: ["inspire_nearby", "rally_troops"],
	Rank.LIEUTENANT: ["inspire_nearby", "rally_troops", "tactical_deployment"],
	Rank.CAPTAIN: ["inspire_nearby", "rally_troops", "tactical_deployment", "reinforcement_call"]
}

## XP required for each rank
const RANK_XP_REQUIREMENTS := {
	Rank.PRIVATE: 0,
	Rank.CORPORAL: 5,
	Rank.SERGEANT: 15,
	Rank.LIEUTENANT: 30,
	Rank.CAPTAIN: 50
}

## Current rank assignments
var soldier_ranks: Dictionary = {}

## Ability cooldowns (ability_id -> rounds remaining)
var ability_cooldowns: Dictionary = {}

## Content filter
var content_filter: ContentFilter = null

func _ready() -> void:
	content_filter = ContentFilter.new()

## Assign initial ranks to squad
func assign_initial_ranks(squad: Array) -> void:
	# First soldier is Corporal, rest are Privates
	for i in range(squad.size()):
		var soldier := squad[i]
		var rank := Rank.PRIVATE if i > 0 else Rank.CORPORAL

		soldier.rank = Rank.keys()[rank]
		_update_soldier_rank(soldier, rank)

	print("MilitaryHierarchySystem: Initial ranks assigned to %d soldiers" % squad.size())

## Get soldier's current rank as enum
func get_rank(soldier: Dictionary) -> Rank:
	var rank_str: String = soldier.get("rank", "Private")
	return Rank[rank_str.to_upper()] if rank_str.to_upper() in Rank else Rank.PRIVATE

## Get rank bonuses for soldier
func get_rank_bonuses(soldier: Dictionary) -> Dictionary:
	var rank := get_rank(soldier)

	var bonuses := {
		"morale_bonus": 0,          # Bonus to morale checks
		"panic_resistance": 0,      # Bonus to panic checks
		"leadership_radius": 0,     # inches for leadership aura
		"command_points": 0,        # Special actions per turn
		"equipment_slots": 0        # Extra equipment slots
	}

	match rank:
		Rank.PRIVATE:
			pass # No bonuses

		Rank.CORPORAL:
			bonuses.morale_bonus = 1
			bonuses.panic_resistance = 1
			bonuses.leadership_radius = 4

		Rank.SERGEANT:
			bonuses.morale_bonus = 2
			bonuses.panic_resistance = 2
			bonuses.leadership_radius = 6
			bonuses.command_points = 1

		Rank.LIEUTENANT:
			bonuses.morale_bonus = 3
			bonuses.panic_resistance = 3
			bonuses.leadership_radius = 8
			bonuses.command_points = 2
			bonuses.equipment_slots = 1

		Rank.CAPTAIN:
			bonuses.morale_bonus = 4
			bonuses.panic_resistance = 4
			bonuses.leadership_radius = 12
			bonuses.command_points = 3
			bonuses.equipment_slots = 2

	return bonuses

## Check if soldier can be promoted
func can_promote(soldier: Dictionary) -> bool:
	var current_rank := get_rank(soldier)

	# Can't promote beyond Captain
	if current_rank == Rank.CAPTAIN:
		return false

	# Check XP requirement
	var next_rank: Rank = (current_rank + 1) as Rank
	var required_xp := RANK_XP_REQUIREMENTS[next_rank]
	var soldier_xp := soldier.get("xp", 0) + (soldier.get("level", 1) - 1) * 5 # Accumulated XP

	return soldier_xp >= required_xp

## Promote soldier to next rank
func promote_soldier(soldier: Dictionary) -> bool:
	if not can_promote(soldier):
		return false

	var old_rank := get_rank(soldier)
	var new_rank: Rank = (old_rank + 1) as Rank

	var old_rank_name := Rank.keys()[old_rank]
	var new_rank_name := Rank.keys()[new_rank]

	soldier.rank = new_rank_name
	_update_soldier_rank(soldier, new_rank)

	print("MilitaryHierarchySystem: %s promoted from %s to %s!" % [
		soldier.get("name", "Unknown"),
		old_rank_name,
		new_rank_name
	])

	soldier_promoted.emit(soldier, old_rank_name, new_rank_name)
	return true

## Get soldiers within leader's command radius
func get_soldiers_in_command(leader: Dictionary, all_soldiers: Array) -> Array:
	var bonuses := get_rank_bonuses(leader)
	var command_radius := bonuses.leadership_radius

	if command_radius <= 0:
		return []

	var leader_pos := _get_position(leader)
	var soldiers_in_range := []

	for soldier in all_soldiers:
		if soldier == leader:
			continue

		var soldier_pos := _get_position(soldier)
		var distance := leader_pos.distance_to(soldier_pos)

		if distance <= command_radius:
			soldiers_in_range.append(soldier)

	return soldiers_in_range

## Apply leadership bonuses to nearby soldiers
func apply_leadership_bonuses(leader: Dictionary, soldier: Dictionary) -> int:
	var bonuses := get_rank_bonuses(leader)

	if bonuses.leadership_radius <= 0:
		return 0

	var leader_pos := _get_position(leader)
	var soldier_pos := _get_position(soldier)
	var distance := leader_pos.distance_to(soldier_pos)

	if distance <= bonuses.leadership_radius:
		var bonus := bonuses.morale_bonus
		leadership_bonus_applied.emit(leader, soldier, bonus)
		return bonus

	return 0

## Use command ability
func use_command_ability(leader: Dictionary, ability_name: String, targets: Array = []) -> bool:
	var rank := get_rank(leader)
	var abilities: Array = RANK_ABILITIES[rank]

	if not ability_name in abilities:
		push_warning("MilitaryHierarchySystem: %s (%s) doesn't have ability '%s'" % [
			leader.get("name", "Unknown"),
			Rank.keys()[rank],
			ability_name
		])
		return false

	# Check cooldown
	var ability_id := "%s_%s" % [_get_soldier_id(leader), ability_name]
	if ability_cooldowns.has(ability_id) and ability_cooldowns[ability_id] > 0:
		print("MilitaryHierarchySystem: Ability '%s' on cooldown (%d rounds)" % [
			ability_name,
			ability_cooldowns[ability_id]
		])
		return false

	# Execute ability
	var success := _execute_ability(leader, ability_name, targets)

	if success:
		# Set cooldown
		var cooldown := _get_ability_cooldown(ability_name)
		ability_cooldowns[ability_id] = cooldown

		command_ability_used.emit(leader, ability_name, targets)
		print("MilitaryHierarchySystem: %s used '%s' (cooldown: %d)" % [
			leader.get("name", "Unknown"),
			ability_name,
			cooldown
		])

	return success

## Process cooldowns (call each round)
func process_round() -> void:
	# Decrease all cooldowns
	for ability_id in ability_cooldowns.keys():
		ability_cooldowns[ability_id] -= 1
		if ability_cooldowns[ability_id] <= 0:
			ability_cooldowns.erase(ability_id)

## Get highest ranking soldier
func get_highest_rank_soldier(soldiers: Array) -> Dictionary:
	var highest_rank := Rank.PRIVATE
	var highest_soldier := {}

	for soldier in soldiers:
		var rank := get_rank(soldier)
		if rank > highest_rank:
			highest_rank = rank
			highest_soldier = soldier

	return highest_soldier

## Get all available abilities for soldier
func get_available_abilities(soldier: Dictionary) -> Array:
	var rank := get_rank(soldier)
	return RANK_ABILITIES[rank].duplicate()

## Get ability description
func get_ability_description(ability_name: String) -> Dictionary:
	var descriptions := {
		"inspire_nearby": {
			"name": "Inspire Nearby",
			"description": "Grant +1 to morale checks for all soldiers within command radius",
			"cooldown": 0,
			"type": "passive"
		},
		"rally_troops": {
			"name": "Rally Troops",
			"description": "Attempt to rally all panicked soldiers within command radius",
			"cooldown": 2,
			"type": "active"
		},
		"tactical_deployment": {
			"name": "Tactical Deployment",
			"description": "Allow one soldier within command radius to move before battle starts",
			"cooldown": 3,
			"type": "active"
		},
		"reinforcement_call": {
			"name": "Reinforcement Call",
			"description": "Call for backup - add 1D3 soldiers to next mission",
			"cooldown": 5,
			"type": "active"
		}
	}

	return descriptions.get(ability_name, {})

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _update_soldier_rank(soldier: Dictionary, rank: Rank) -> void:
	var soldier_id := _get_soldier_id(soldier)
	soldier_ranks[soldier_id] = rank

func _execute_ability(leader: Dictionary, ability_name: String, targets: Array) -> bool:
	match ability_name:
		"inspire_nearby":
			return _ability_inspire_nearby(leader)

		"rally_troops":
			return _ability_rally_troops(leader, targets)

		"tactical_deployment":
			return _ability_tactical_deployment(leader, targets)

		"reinforcement_call":
			return _ability_reinforcement_call(leader)

		_:
			push_error("MilitaryHierarchySystem: Unknown ability '%s'" % ability_name)
			return false

func _ability_inspire_nearby(leader: Dictionary) -> bool:
	# Passive aura - always active
	print("MilitaryHierarchySystem: %s inspires nearby soldiers (+1 morale)" % leader.get("name", "Unknown"))
	return true

func _ability_rally_troops(leader: Dictionary, targets: Array) -> bool:
	# Attempt to rally panicked soldiers
	var panic_system := get_node_or_null("/root/PanicSystem")
	if not panic_system:
		return false

	var rallied_count := 0
	for target in targets:
		if panic_system.rally_soldier(target, leader):
			rallied_count += 1

	print("MilitaryHierarchySystem: %s rallied %d soldiers" % [
		leader.get("name", "Unknown"),
		rallied_count
	])

	return rallied_count > 0

func _ability_tactical_deployment(leader: Dictionary, targets: Array) -> bool:
	# Allow soldier to reposition
	if targets.is_empty():
		return false

	var target := targets[0]
	print("MilitaryHierarchySystem: %s grants tactical deployment to %s" % [
		leader.get("name", "Unknown"),
		target.get("name", "Unknown")
	])

	# Mark soldier for pre-battle movement
	target.has_tactical_deployment = true
	return true

func _ability_reinforcement_call(leader: Dictionary) -> bool:
	# Call reinforcements for next mission
	var reinforcements := randi() % 3 + 1

	print("MilitaryHierarchySystem: %s called for reinforcements (+%d soldiers next mission)" % [
		leader.get("name", "Unknown"),
		reinforcements
	])

	# Store reinforcement count for campaign system
	leader.pending_reinforcements = reinforcements
	return true

func _get_ability_cooldown(ability_name: String) -> int:
	var description := get_ability_description(ability_name)
	return description.get("cooldown", 0)

func _get_position(entity: Dictionary) -> Vector2:
	if entity.has("position"):
		var pos = entity.position
		if pos is Vector2:
			return pos

	# Fallback
	return Vector2.ZERO

func _get_soldier_id(soldier: Dictionary) -> String:
	return soldier.get("id", "soldier_unknown")
