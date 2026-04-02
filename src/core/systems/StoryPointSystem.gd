class_name StoryPointSystem
extends RefCounted

## Story Point System - Five Parsecs Campaign Manager
##
## Core Rules Reference: p.66-67
##
## Story points are a meta-currency that players can spend to influence outcomes
## and gain advantages during the campaign. They represent narrative control and
## dramatic intervention capabilities.
##
## Starting Points:
## - Base: 1D6+1 story points at campaign start
## - Hardcore mode: -1 starting point
## - Insanity mode: Story points disabled (system not used)
##
## Earning Points:
## - +1 every 3rd campaign turn (turns 3, 6, 9, 12, etc.)
## - +1 if holding field after battle when a character was killed
##
## Spending Points (per-turn limits enforced):
## 1. Roll twice, pick one result (any table outside combat) - 1 point, unlimited
## 2. Reroll any result (must accept new result) - 1 point, unlimited
## 3. Get 3 credits - 1 point, ONCE per turn
## 4. Get +3 XP for one character - 1 point, ONCE per turn
## 5. Take additional campaign action - 1 point, ONCE per turn

## Signals

## Emitted when story point total changes
signal story_points_changed(old_value: int, new_value: int)

## Emitted when a story point is spent
## details contains context like character_id for XP, amount for credits
signal story_point_spent(spend_type: SpendType, details: Dictionary)

## Emitted when story points are earned
signal story_points_earned(amount: int, reason: String)

## Emitted when spending is denied (out of points or per-turn limit)
signal spending_denied(spend_type: SpendType, reason: String)

## Types of story point expenditures
enum SpendType {
	ROLL_TWICE_PICK_ONE,  ## Roll on table twice, choose preferred result
	REROLL_RESULT,        ## Reroll a single result (must accept)
	GET_CREDITS,          ## Gain 3 credits (once per turn)
	GET_XP,               ## Give +3 XP to one character (once per turn)
	EXTRA_ACTION          ## Take additional campaign action (once per turn)
}

## Constants loaded from res://data/campaign_config.json story_points section
## Source: Core Rules pp.66-67
static var _sp_data: Dictionary = {}
static var _sp_loaded: bool = false

static func _ensure_sp_loaded() -> void:
	if _sp_loaded:
		return
	_sp_loaded = true
	var file := FileAccess.open("res://data/campaign_config.json", FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_sp_data = json.data.get("story_points", {})
	file.close()

static func _sp_val(key: String, default_val: int) -> int:
	_ensure_sp_loaded()
	return int(_sp_data.get(key, default_val))

static var STARTING_POINTS_BASE_MIN: int: # @no-lint:variable-name
	get: return _sp_val("starting_points_base_min", 2)
static var STARTING_POINTS_BASE_MAX: int: # @no-lint:variable-name
	get: return _sp_val("starting_points_base_max", 7)
static var HARDCORE_PENALTY: int: # @no-lint:variable-name
	get: return _sp_val("hardcore_penalty", -1)
static var TURN_EARNING_INTERVAL: int: # @no-lint:variable-name
	get: return _sp_val("turn_earning_interval", 3)
static var BATTLE_EARNING_AMOUNT: int: # @no-lint:variable-name
	get: return _sp_val("battle_earning_amount", 1)
static var CREDITS_REWARD: int: # @no-lint:variable-name
	get: return _sp_val("credits_reward", 3)
static var XP_REWARD: int: # @no-lint:variable-name
	get: return _sp_val("xp_reward", 3)
static var SPEND_COST: int: # @no-lint:variable-name
	get: return _sp_val("spend_cost", 1)

## Current story point balance
var _current_points: int = 0

## Per-turn spending limits (reset each turn)
var _credits_spent_this_turn: bool = false
var _xp_spent_this_turn: bool = false
var _action_spent_this_turn: bool = false

## Campaign reference for difficulty settings (Variant to avoid type conflicts)
var _campaign: Variant = null

## Constructor
func _init(campaign: Variant = null) -> void:
	_campaign = campaign

## Initialize starting story points based on difficulty
## Returns the number of starting points rolled
func initialize_starting_points(difficulty: int) -> int:
	# Check for Insanity mode (story points disabled)
	if _is_story_points_disabled():
		_current_points = 0
		story_points_changed.emit(0, 0)
		return 0

	# Roll 1D6+1 for base starting points (using randi for simple d6)
	var base_roll: int = (randi() % 6) + 1 + 1  # d6 + 1
	var starting_points: int = base_roll

	# Apply Hardcore penalty
	if difficulty == GlobalEnums.DifficultyLevel.HARDCORE:
		starting_points += HARDCORE_PENALTY

	# Ensure minimum of 0 (in case hardcore reduces below 0)
	starting_points = maxi(0, starting_points)

	var old_value := _current_points
	_current_points = starting_points
	story_points_changed.emit(old_value, _current_points)

	return starting_points

## Check if story points system is disabled (Nightmare mode only)
func _is_story_points_disabled() -> bool:
	if _campaign == null:
		return false

	# Nightmare mode disables story points entirely
	# Hardcore mode reduces starting points but does NOT disable the system
	if _campaign is Object and "config" in _campaign:
		var config = _campaign.config
		# Handle both Object and Dictionary config types
		if config is Dictionary and "difficulty" in config:
			return config["difficulty"] == GlobalEnums.DifficultyLevel.INSANITY
		elif config is Object and "difficulty" in config:
			return config.difficulty == GlobalEnums.DifficultyLevel.INSANITY
	return false

## Get current story point balance
func get_current_points() -> int:
	return _current_points

## Check if player can spend a story point for given type
## Returns true if spending is allowed, false if blocked by limits or insufficient points
func can_spend(spend_type: SpendType) -> bool:
	# Check if story points are disabled
	if _is_story_points_disabled():
		return false

	# Check if player has points to spend
	if _current_points < SPEND_COST:
		return false

	# Check per-turn limits
	match spend_type:
		SpendType.ROLL_TWICE_PICK_ONE:
			return true  # Unlimited uses
		SpendType.REROLL_RESULT:
			return true  # Unlimited uses
		SpendType.GET_CREDITS:
			return not _credits_spent_this_turn
		SpendType.GET_XP:
			return not _xp_spent_this_turn
		SpendType.EXTRA_ACTION:
			return not _action_spent_this_turn
		_:
			push_error("Unknown SpendType: %d" % spend_type)
			return false

## Spend a story point
## spend_type: Type of expenditure
## details: Context dictionary (e.g., {"character_id": "abc123"} for XP spending)
## Returns true if spending succeeded, false if denied
func spend_point(spend_type: SpendType, details: Dictionary = {}) -> bool:
	# Validate spending is allowed
	if not can_spend(spend_type):
		var reason := _get_spending_denial_reason(spend_type)
		spending_denied.emit(spend_type, reason)
		return false

	# Deduct story point
	var old_value := _current_points
	_current_points -= SPEND_COST
	story_points_changed.emit(old_value, _current_points)

	# Mark per-turn limit used
	_mark_per_turn_spending(spend_type)

	# Emit spending event
	story_point_spent.emit(spend_type, details)

	return true

## Get reason for spending denial (for error messages)
func _get_spending_denial_reason(spend_type: SpendType) -> String:
	if _is_story_points_disabled():
		return "Story points are disabled in Insanity mode"

	if _current_points < SPEND_COST:
		return "Insufficient story points (need %d, have %d)" % [SPEND_COST, _current_points]

	match spend_type:
		SpendType.GET_CREDITS:
			return "Credits already purchased this turn"
		SpendType.GET_XP:
			return "XP already granted this turn"
		SpendType.EXTRA_ACTION:
			return "Extra action already taken this turn"
		_:
			return "Unknown spending type"

## Mark per-turn spending limit as used
func _mark_per_turn_spending(spend_type: SpendType) -> void:
	match spend_type:
		SpendType.GET_CREDITS:
			_credits_spent_this_turn = true
		SpendType.GET_XP:
			_xp_spent_this_turn = true
		SpendType.EXTRA_ACTION:
			_action_spent_this_turn = true
		# ROLL_TWICE_PICK_ONE and REROLL_RESULT have no limits

## Check if player earns story point from turn progression
## Returns number of points earned (0 or 1)
func check_turn_earning(turn_number: int) -> int:
	if _is_story_points_disabled():
		return 0

	# Earn point every 3rd turn (3, 6, 9, 12, etc.)
	if turn_number > 0 and turn_number % TURN_EARNING_INTERVAL == 0:
		_add_story_points(BATTLE_EARNING_AMOUNT, "Turn %d milestone" % turn_number)
		return BATTLE_EARNING_AMOUNT

	return 0

## Check if player earns story point from battle outcome
## held_field: Did crew hold the battlefield?
## character_killed: Was any character killed this battle?
## Returns number of points earned (0 or 1)
func check_battle_earning(held_field: bool, character_killed: bool) -> int:
	if _is_story_points_disabled():
		return 0

	# Earn point only if BOTH conditions are met
	if held_field and character_killed:
		_add_story_points(BATTLE_EARNING_AMOUNT, "Held field after character death")
		return BATTLE_EARNING_AMOUNT

	return 0

## Add story points (internal helper)
func _add_story_points(amount: int, reason: String) -> void:
	var old_value := _current_points
	_current_points += amount
	story_points_changed.emit(old_value, _current_points)
	story_points_earned.emit(amount, reason)

## Reset per-turn spending limits (call at start of each turn)
func reset_turn_limits() -> void:
	_credits_spent_this_turn = false
	_xp_spent_this_turn = false
	_action_spent_this_turn = false

## Get per-turn spending status (for UI display)
func get_turn_spending_status() -> Dictionary:
	return {
		"credits_available": not _credits_spent_this_turn,
		"xp_available": not _xp_spent_this_turn,
		"action_available": not _action_spent_this_turn
	}

## Manual addition/removal (for save/load, debug, or special events)
func add_points(amount: int, reason: String = "Manual addition") -> void:
	if _is_story_points_disabled():
		push_warning("Cannot add story points in Insanity mode")
		return

	_add_story_points(amount, reason)

func remove_points(amount: int) -> void:
	var old_value := _current_points
	_current_points = maxi(0, _current_points - amount)
	story_points_changed.emit(old_value, _current_points)

## Set campaign reference (if not provided in constructor)
func set_campaign(campaign: Variant) -> void:
	_campaign = campaign

## Serialize for save/load
func to_dict() -> Dictionary:
	return {
		"current_points": _current_points,
		"credits_spent_this_turn": _credits_spent_this_turn,
		"xp_spent_this_turn": _xp_spent_this_turn,
		"action_spent_this_turn": _action_spent_this_turn
	}

## Deserialize from save data
func from_dict(data: Dictionary) -> void:
	_current_points = data.get("current_points", 0)
	_credits_spent_this_turn = data.get("credits_spent_this_turn", false)
	_xp_spent_this_turn = data.get("xp_spent_this_turn", false)
	_action_spent_this_turn = data.get("action_spent_this_turn", false)
