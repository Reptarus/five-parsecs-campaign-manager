class_name BattleResults
extends Resource

## Battle → Post-Battle data contract
## Contains all results from a battle for post-battle processing
##
## Usage:
##   var results := BattleResults.new()
##   results.set_outcome("victory")
##   results.add_casualty(character, "critical_hit")
##   SignalBus.battle_ended.emit(results)

# Battle outcome
@export var outcome: String = ""  # "victory", "defeat", "retreat", "draw"
@export var battle_id: String = ""
@export var mission_id: String = ""

# Combat statistics
@export var rounds_fought: int = 0
@export var turns_elapsed: int = 0
@export var enemies_defeated: int = 0
@export var enemies_fled: int = 0
@export var hold_field: bool = false  # Crew held the battlefield (for loot)

# Crew status - these flow to post-battle phase
@export var crew_participants: Array[String] = []  # IDs of crew who participated
@export var casualties: Array[Dictionary] = []  # [{crew_id, type, round, cause}]
@export var injuries: Array[Dictionary] = []  # [{crew_id, injury_type, damage, recovery_turns}]

# Rewards
@export var base_payment: int = 0
@export var danger_pay: int = 0
@export var bonus_credits: int = 0
@export var loot_rolls: int = 0  # Number of loot rolls earned
@export var loot_items: Array[Dictionary] = []  # [{type, quality, item_id}]

# Experience - per character
@export var xp_earned: Dictionary = {}  # {crew_id: xp_amount}
@export var achievements: Array[Dictionary] = []  # [{crew_id, achievement, xp_bonus}]

# Story/Campaign impact
@export var story_points: int = 0
@export var objectives_completed: Array[String] = []
@export var objectives_failed: Array[String] = []
@export var events_triggered: Array[String] = []

# Rival/Patron changes
@export var rival_defeated: bool = false
@export var rival_id: String = ""
@export var patron_satisfied: bool = false
@export var patron_id: String = ""

# Metadata
@export var result_timestamp: float = 0.0

func _init() -> void:
	battle_id = "result_" + str(randi()) + "_" + str(Time.get_ticks_msec())
	result_timestamp = Time.get_ticks_msec() / 1000.0

## Set battle outcome
func set_outcome(p_outcome: String) -> void:
	outcome = p_outcome
	# Auto-set hold_field for victory
	if p_outcome == "victory":
		hold_field = true

## Add crew participant
func add_participant(crew_id: String) -> void:
	if crew_id not in crew_participants:
		crew_participants.append(crew_id)

## Add casualty record
func add_casualty(crew_id: String, casualty_type: String, round_occurred: int = 0, cause: String = "") -> void:
	casualties.append({
		"crew_id": crew_id,
		"type": casualty_type,  # "killed", "critically_wounded", "missing"
		"round": round_occurred,
		"cause": cause
	})

## Add injury record
func add_injury(crew_id: String, injury_type: String, damage: int, recovery_turns: int) -> void:
	injuries.append({
		"crew_id": crew_id,
		"injury_type": injury_type,
		"damage": damage,
		"recovery_turns": recovery_turns
	})

## Set experience for a crew member
func set_xp(crew_id: String, xp: int) -> void:
	xp_earned[crew_id] = xp

## Add XP to existing (for bonuses)
func add_xp(crew_id: String, xp: int) -> void:
	if crew_id in xp_earned:
		xp_earned[crew_id] += xp
	else:
		xp_earned[crew_id] = xp

## Add achievement bonus
func add_achievement(crew_id: String, achievement: String, xp_bonus: int) -> void:
	achievements.append({
		"crew_id": crew_id,
		"achievement": achievement,
		"xp_bonus": xp_bonus
	})
	add_xp(crew_id, xp_bonus)

## Add loot item
func add_loot(item_type: String, quality: String = "standard", item_id: String = "") -> void:
	loot_items.append({
		"type": item_type,
		"quality": quality,
		"item_id": item_id
	})

## Calculate total credits earned
func get_total_credits() -> int:
	return base_payment + danger_pay + bonus_credits

## Calculate total XP awarded
func get_total_xp() -> int:
	var total := 0
	for xp in xp_earned.values():
		total += xp
	return total

## Check if victory
func is_victory() -> bool:
	return outcome == "victory"

## Check if defeat
func is_defeat() -> bool:
	return outcome == "defeat"

## Get casualty count
func get_casualty_count() -> int:
	return casualties.size()

## Get injury count
func get_injury_count() -> int:
	return injuries.size()

## Get surviving participants (participated but not casualty)
func get_survivors() -> Array[String]:
	var survivors: Array[String] = []
	var casualty_ids: Array[String] = []

	for casualty in casualties:
		casualty_ids.append(casualty.get("crew_id", ""))

	for participant in crew_participants:
		if participant not in casualty_ids:
			survivors.append(participant)

	return survivors

## Export to dictionary for post-battle processing
## This format matches what PostBattlePhase expects
func to_post_battle_format() -> Dictionary:
	return {
		# Core outcome
		"success": is_victory(),
		"outcome": outcome,
		"battle_id": battle_id,
		"mission_id": mission_id,

		# Crew data - CRITICAL: These were missing in original flow
		"crew_participants": crew_participants,
		"injuries_sustained": injuries,
		"casualties": casualties,

		# Payment
		"base_payment": base_payment,
		"danger_pay": danger_pay,
		"bonus_credits": bonus_credits,

		# Combat stats
		"enemies_defeated": enemies_defeated,
		"enemies_fled": enemies_fled,
		"hold_field": hold_field,
		"rounds_fought": rounds_fought,

		# Loot
		"loot_rolls": loot_rolls,
		"loot_items": loot_items,

		# Experience
		"xp_earned": xp_earned,
		"achievements": achievements,

		# Story impact
		"story_points": story_points,
		"objectives_completed": objectives_completed,
		"objectives_failed": objectives_failed,
		"events_triggered": events_triggered,

		# Rival/Patron
		"rival_defeated": rival_defeated,
		"rival_id": rival_id,
		"patron_satisfied": patron_satisfied,
		"patron_id": patron_id,

		# Legacy format for backward compatibility
		"defeated_enemy_list": _build_enemy_list()
	}

## Build enemy list for legacy format
func _build_enemy_list() -> Array[Dictionary]:
	var enemy_list: Array[Dictionary] = []
	for i in range(enemies_defeated):
		enemy_list.append({
			"type": "defeated",
			"is_rival": rival_defeated and i == 0,
			"rival_id": rival_id if (rival_defeated and i == 0) else ""
		})
	return enemy_list

## Validate results before sending to post-battle
func validate() -> Array[String]:
	var errors: Array[String] = []

	if outcome == "":
		errors.append("Battle outcome not set")

	if crew_participants.is_empty():
		errors.append("No crew participants recorded")

	return errors

## Check if results are valid
func is_valid() -> bool:
	return validate().is_empty()

## Create from FPCM_BattleState (for integration with existing system)
static func from_battle_state(state: Resource) -> Resource:
	var results = (load("res://src/core/battle/BattleResults.gd")).new()

	if not state:
		return results

	# Extract from FPCM_BattleState fields
	results.battle_id = state.get("battle_id") if "battle_id" in state else ""
	results.outcome = state.get("battle_outcome") if "battle_outcome" in state else ""
	results.rounds_fought = state.get("current_round") if "current_round" in state else 0
	results.turns_elapsed = state.get("current_turn") if "current_turn" in state else 0

	# Copy casualties and injuries
	var state_casualties = state.get("casualties") if "casualties" in state else []
	for casualty in state_casualties:
		results.casualties.append(casualty)

	var state_injuries = state.get("injuries") if "injuries" in state else []
	for injury in state_injuries:
		results.injuries.append(injury)

	# Extract credits and XP
	results.base_payment = state.get("credits_earned") if "credits_earned" in state else 0
	results.xp_earned = state.get("experience_gained") if "experience_gained" in state else {}
	results.story_points = state.get("story_points_earned") if "story_points_earned" in state else 0

	# Extract participants from unit_status
	var unit_status = state.get("unit_status") if "unit_status" in state else {}
	for unit_id in unit_status:
		var unit_data = unit_status[unit_id]
		if unit_data.get("type") == "crew":
			results.crew_participants.append(unit_id)

	# Count enemies defeated
	for unit_id in unit_status:
		var unit_data = unit_status[unit_id]
		if unit_data.get("type") == "enemy" and not unit_data.get("is_active", true):
			results.enemies_defeated += 1

	# Set hold_field based on outcome
	results.hold_field = results.outcome == "victory"

	return results
