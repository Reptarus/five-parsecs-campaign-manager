class_name FPCM_EscalationSystem
extends Resource

## Escalation System - Post-Round 4 Battle Management
##
## After round 4, each round the player rolls d6:
## - 1-2: Battle ends (one side breaks off)
## - 3-5: Battle continues normally
## - 6: Escalation event occurs
##
## All outputs are TEXT INSTRUCTIONS for the player to execute on the physical table.
## Reference: Five Parsecs From Home Core Rules

signal escalation_checked(round: int, roll: int, result: String)
signal escalation_triggered(instruction_text: String)
signal battle_ending(reason: String)

## Escalation event types with tabletop instructions
const ESCALATION_EVENTS: Array[Dictionary] = [
	{
		"name": "Reinforcements",
		"instruction": "Place d6 additional enemies at the nearest table edge to any existing enemy. Use the same enemy type as the majority on the table.",
		"dice": "d6",
	},
	{
		"name": "Environmental Hazard",
		"instruction": "Roll d6 for sector (count left-to-right, top-to-bottom). That sector is now dangerous terrain - any figure ending activation there takes a Stun marker.",
		"dice": "d6",
	},
	{
		"name": "Objective Shift",
		"instruction": "Move the primary objective marker 1d6 inches in a random direction (roll d6: 1-2 North, 3 East, 4 South, 5-6 West). If it leaves the table, place at nearest edge.",
		"dice": "d6",
	},
	{
		"name": "Sniper!",
		"instruction": "A hidden sniper fires at the nearest crew member in the open. Roll to hit at Combat +1. If hit, roll for damage normally. The sniper is not placed on the table.",
		"dice": "none",
	},
	{
		"name": "Communications Jam",
		"instruction": "No crew member may use the Dash action this round. Enemy figures with ranged weapons gain +1 to hit.",
		"dice": "none",
	},
	{
		"name": "Rally!",
		"instruction": "All stunned enemy figures immediately recover (remove all Stun markers from enemies). Any fled enemies return at the nearest table edge.",
		"dice": "none",
	},
]

## Battle ending flavor text
const ENDING_REASONS: Array[String] = [
	"The enemy breaks contact and withdraws under covering fire.",
	"A cease-fire is called - both sides pull back to regroup.",
	"Smoke and confusion allow the enemy to slip away.",
	"The enemy scatters, no longer willing to press the fight.",
	"Reinforcement signals force the enemy to retreat before they arrive.",
	"The battle reaches a natural conclusion as ammunition runs low.",
]

var _escalation_history: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.seed = Time.get_unix_time_from_system()

## Check escalation for the current round. Returns result dictionary.
## Call this at the END_PHASE of rounds > 4.
## roll_result: -1 means auto-roll, >= 1 means player provided the roll.
func check_escalation(round_number: int, roll_result: int = -1) -> Dictionary:
	if round_number <= 4:
		return {"applicable": false, "round": round_number}

	var roll: int = roll_result if roll_result >= 1 else _rng.randi_range(1, 6)

	var result: Dictionary = {
		"applicable": true,
		"round": round_number,
		"roll": roll,
		"outcome": "",
		"instruction": "",
	}

	if roll <= 2:
		# Battle ends
		var reason: String = ENDING_REASONS[_rng.randi_range(0, ENDING_REASONS.size() - 1)]
		result.outcome = "battle_ends"
		result.instruction = "Battle Over! " + reason
		battle_ending.emit(reason)
	elif roll == 6:
		# Escalation event
		var event: Dictionary = ESCALATION_EVENTS[_rng.randi_range(0, ESCALATION_EVENTS.size() - 1)]
		result.outcome = "escalation"
		result.instruction = "ESCALATION - %s: %s" % [event.name, event.instruction]
		escalation_triggered.emit(result.instruction)
	else:
		# Battle continues
		result.outcome = "continues"
		result.instruction = "Battle continues normally. (Rolled %d)" % roll

	_escalation_history.append(result)
	escalation_checked.emit(round_number, roll, result.outcome)
	return result

## Get a specific escalation event by index (for manual selection).
func get_escalation_event(index: int) -> Dictionary:
	if index >= 0 and index < ESCALATION_EVENTS.size():
		return ESCALATION_EVENTS[index]
	return {}

## Get all escalation events (for UI display).
func get_all_escalation_events() -> Array[Dictionary]:
	return ESCALATION_EVENTS

## Get escalation history for battle log.
func get_history() -> Array[Dictionary]:
	return _escalation_history

## Whether escalation applies this round.
func should_check_escalation(round_number: int) -> bool:
	return round_number > 4

## Serialize for save/load.
func serialize() -> Dictionary:
	return {
		"escalation_history": _escalation_history,
	}

## Deserialize from save data.
func deserialize(data: Dictionary) -> void:
	_escalation_history = []
	for entry in data.get("escalation_history", []):
		_escalation_history.append(entry)
