class_name ProgressiveDifficultyTracker
extends RefCounted
## Progressive Difficulty Tracker - Turn-based scaling system
##
## Two progression options from the Compendium (pp.56-60):
##   OPTION 1 (BASIC): Simple respawn/strength increases by turn number
##   OPTION 2 (ADVANCED): Gradually enables difficulty toggles by turn number
##
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
## Gated behind DLCManager.ContentFlag.PROGRESSIVE_DIFFICULTY.


enum ProgressionType {
	NONE,
	BASIC,
	ADVANCED,
}


## ============================================================================
## BASIC PROGRESSION TABLE (Option 1)
## Turn-based text modifiers applied to each battle
## ============================================================================

const BASIC_MILESTONES: Array[Dictionary] = [
	{
		"turn": 4,
		"id": "respawn_1",
		"label": "Respawn 1",
		"instruction": "RESPAWN 1: Replace the first basic enemy slain at end of each round.",
	},
	{
		"turn": 5,
		"id": "strength_1",
		"label": "Strength 1",
		"instruction": "STRENGTH 1: +1 basic enemy per encounter.",
	},
	{
		"turn": 8,
		"id": "respawn_2",
		"label": "Respawn 2",
		"instruction": "RESPAWN 2: Replace the first TWO basic enemies slain at end of each round.",
	},
	{
		"turn": 10,
		"id": "strength_2",
		"label": "Strength 2",
		"instruction": "STRENGTH 2: +2 basic enemies per encounter.",
	},
	{
		"turn": 12,
		"id": "respawn_3",
		"label": "Respawn 3",
		"instruction": "RESPAWN 3: Replace the first THREE basic enemies slain at end of each round.",
	},
	{
		"turn": 15,
		"id": "strength_3",
		"label": "Strength 3",
		"instruction": "STRENGTH 3: +2 basic enemies, +1 Lieutenant per encounter.",
	},
	{
		"turn": 16,
		"id": "respawn_4",
		"label": "Respawn 4",
		"instruction": "RESPAWN 4: Replace the first FOUR basic enemies slain at end of each round.",
	},
	{
		"turn": 20,
		"id": "respawn_5_strength_4",
		"label": "Respawn 5 + Strength 4",
		"instruction": "RESPAWN 5 + STRENGTH 4: Replace first FIVE slain. +2 basic, +1 specialist, +1 Lieutenant per encounter.",
	},
]


## ============================================================================
## ADVANCED PROGRESSION TABLE (Option 2)
## Unlocks difficulty toggles automatically by turn
## ============================================================================

const ADVANCED_MILESTONES: Array[Dictionary] = [
	{
		"turn": 3,
		"id": "strength_adjusted",
		"label": "Strength-Adjusted Enemies",
		"instruction": "PROGRESSIVE: Enable Strength-Adjusted Enemies. Enemy count = crew size + modifiers.",
	},
	{
		"turn": 4,
		"id": "deployment_variables",
		"label": "Deployment Variables",
		"instruction": "PROGRESSIVE: Enable Deployment Variables. Roll D6 for deployment modifications.",
	},
	{
		"turn": 5,
		"id": "actually_specialized",
		"label": "Actually Specialized + Better Leadership",
		"instruction": "PROGRESSIVE: Specialists get min Combat +1, Toughness 4. Unique Individuals roll 7+ (not 9+).",
	},
	{
		"turn": 6,
		"id": "escalating_battles",
		"label": "Escalating Battles",
		"instruction": "PROGRESSIVE: Enable Escalating Battles. Check for reinforcements each round.",
	},
	{
		"turn": 8,
		"id": "armored_leaders",
		"label": "Armored Leaders + Veteran",
		"instruction": "PROGRESSIVE: Lieutenants get 5+ Armor Save. 1 basic enemy gets +1 Combat Skill.",
	},
	{
		"turn": 14,
		"id": "elite_4plus",
		"label": "Elite Enemies (4+)",
		"instruction": "PROGRESSIVE: Roll D6 for each enemy group - on 4+, upgrade to Elite.",
	},
	{
		"turn": 16,
		"id": "elite_3plus",
		"label": "Elite Enemies (3+)",
		"instruction": "PROGRESSIVE: Roll D6 for each enemy group - on 3+, upgrade to Elite.",
	},
	{
		"turn": 20,
		"id": "elite_always",
		"label": "Elite Enemies (Always)",
		"instruction": "PROGRESSIVE: ALL enemy groups are Elite.",
	},
]


## ============================================================================
## DLC GATING
## ============================================================================

static func _is_enabled() -> bool:
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr:
		return false
	return dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.PROGRESSIVE_DIFFICULTY)


## ============================================================================
## PUBLIC API
## ============================================================================

## Get all active milestones for a given turn number and progression type.
static func get_active_milestones(turn_number: int, progression_type: int) -> Array[Dictionary]:
	if not _is_enabled():
		return []
	var table: Array[Dictionary] = []
	match progression_type:
		ProgressionType.BASIC:
			table.assign(BASIC_MILESTONES)
		ProgressionType.ADVANCED:
			table.assign(ADVANCED_MILESTONES)
		_:
			return []
	var active: Array[Dictionary] = []
	for milestone in table:
		if turn_number >= milestone.turn:
			active.append(milestone)
	return active


## Get the LATEST milestone unlocked this turn (for notification).
static func get_newly_unlocked(turn_number: int, progression_type: int) -> Dictionary:
	if not _is_enabled():
		return {}
	var table: Array[Dictionary] = []
	match progression_type:
		ProgressionType.BASIC:
			table.assign(BASIC_MILESTONES)
		ProgressionType.ADVANCED:
			table.assign(ADVANCED_MILESTONES)
		_:
			return {}
	for milestone in table:
		if milestone.turn == turn_number:
			return milestone
	return {}


## Get combined instruction text for all active modifiers.
static func get_instruction_text(turn_number: int, progression_type: int) -> String:
	var milestones := get_active_milestones(turn_number, progression_type)
	if milestones.is_empty():
		return ""
	var lines: Array[String] = ["[b]PROGRESSIVE DIFFICULTY (Turn %d):[/b]" % turn_number]
	for m in milestones:
		lines.append("  " + m.instruction)
	return "\n".join(lines)


## Get enemy count modifier from basic progression.
static func get_enemy_count_bonus(turn_number: int, progression_type: int) -> int:
	if progression_type != ProgressionType.BASIC:
		return 0
	if turn_number >= 20:
		return 2 + 1 + 1  # +2 basic, +1 specialist, +1 lieutenant
	elif turn_number >= 15:
		return 2 + 1  # +2 basic, +1 lieutenant
	elif turn_number >= 10:
		return 2
	elif turn_number >= 5:
		return 1
	return 0


## Get respawn count from basic progression.
static func get_respawn_count(turn_number: int, progression_type: int) -> int:
	if progression_type != ProgressionType.BASIC:
		return 0
	if turn_number >= 20:
		return 5
	elif turn_number >= 16:
		return 4
	elif turn_number >= 12:
		return 3
	elif turn_number >= 8:
		return 2
	elif turn_number >= 4:
		return 1
	return 0
