class_name ProgressiveDifficultyTracker
extends RefCounted
## Progressive Difficulty Tracker - Turn-based scaling system
##
## Two progression options from the Compendium (pp.30-31 — the TOC entry is
## "Progressive Difficulty 30"; the old "pp.56-60" citation here was wrong):
##   OPTION 1 (BASIC, p.30): respawn/strength increases by campaign turn.
##     "Apply both the highest Respawn and the highest Strength entry that
##     applies to you." Cleared table = no respawns, you win the encounter.
##   OPTION 2 (ADVANCED, p.31): gradually enables difficulty toggles by turn.
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

## Milestone data loaded from res://data/progressive_difficulty.json
static var _pd_data: Dictionary = {}
static var _pd_loaded: bool = false

static func _ensure_pd_loaded() -> void:
	if _pd_loaded:
		return
	_pd_loaded = true
	var file := FileAccess.open("res://data/progressive_difficulty.json", FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_pd_data = json.data
	file.close()

static var BASIC_MILESTONES: Array: # @no-lint:variable-name
	get:
		_ensure_pd_loaded()
		return _pd_data.get("basic_milestones", [])


## ============================================================================
## ADVANCED PROGRESSION TABLE (Option 2)
## Unlocks difficulty toggles automatically by turn
## ============================================================================

static var ADVANCED_MILESTONES: Array: # @no-lint:variable-name
	get:
		_ensure_pd_loaded()
		return _pd_data.get("advanced_milestones", [])


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


## ── Option 2 UNLOCKS — the half that was only ever printed ─────────────────
##
## Compendium p.31 Option 2 does not add numbers; it TURNS ON existing chapters
## and difficulty toggles as the campaign ages. The milestone table above was
## byte-faithful and reached exactly one consumer: a block of instruction text.
## So a player on Option 2 read "Enable Strength-Adjusted Enemies" every battle
## from turn 3 and the option was never actually enabled.
##
## Five of the eight milestones name toggles the codebase already implements at
## live rule sites, so unlocking them is a matter of adding their ids to the
## active-toggle set — `compendium_difficulty_toggles.get_active_toggles()` is the
## single chokepoint every rule reads, so this reaches all of them at once rather
## than needing a branch at each.
const OPTION_2_TOGGLE_UNLOCKS := {
	3: ["strength_adjusted"],
	5: ["actually_specialized", "better_leadership"],
	8: ["armored_leaders", "veteran"],
}

## p.31: turn 14 "elite-level enemies on a D6 roll of 4+", 16 "on a 3+", 20
## "always". Returns the D6 target, or 7 when Option 2 has not reached turn 14
## (unreachable on a D6 = never). 1 means always.
const OPTION_2_ELITE_NEVER := 7

static func option_2_toggle_unlocks(turn_number: int) -> Array:
	if not _is_enabled():
		return []
	var out: Array = []
	for turn in OPTION_2_TOGGLE_UNLOCKS.keys():
		if turn_number >= int(turn):
			for id in OPTION_2_TOGGLE_UNLOCKS[turn]:
				if not (id in out):
					out.append(id)
	return out


static func option_2_elite_target(turn_number: int) -> int:
	if not _is_enabled():
		return OPTION_2_ELITE_NEVER
	if turn_number >= 20:
		return 1
	if turn_number >= 16:
		return 3
	if turn_number >= 14:
		return 4
	return OPTION_2_ELITE_NEVER


## Is Option 2 selected for this campaign? `options` is the persisted
## `progress_data["progressive_difficulty_options"]` array — [1] basic, [2]
## advanced, [1,2] both.
static func option_2_selected(options: Array) -> bool:
	return int(ProgressionType.ADVANCED) in options or 2 in options


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
