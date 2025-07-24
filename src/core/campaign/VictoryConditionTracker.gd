@tool
extends Node
class_name VictoryConditionTracker

## Victory Condition Tracker Implementation for Five Parsecs From Home
## Tracks the progress of various victory conditions for campaign completion

# Preload necessary enums and data managers
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const DataManager = preload("res://src/core/data/DataManager.gd")

# Signals
signal victory_condition_reached(condition_type: int, details: Dictionary)
signal victory_progress_updated(condition_type: int, current: int, required: int)

# Private variables
var _data_manager: Object
var _active_conditions: Dictionary = {}
var _campaign_data: Dictionary = {}

# Initialize the tracker
func _init() -> void:
	_data_manager = DataManager.get_instance() if _data_manager and _data_manager.has_method("get_instance") else null
	_data_manager.ensure_data_loaded() if _data_manager and _data_manager.has_method("ensure_data_loaded") else null
	_load_data()

# Load necessary data
func _load_data() -> void:
	var victory_data = _data_manager.load_json_file("res://data/victory_conditions.json")
	if victory_data:
		_campaign_data = victory_data
	else:
		push_error("Failed to load victory conditions data")

# Set up victory conditions for a campaign
func setup_victory_conditions(campaign_type: int, custom_conditions: Array = []) -> void:
	_active_conditions.clear()

	# Set default _conditions based on campaign type
	match campaign_type:
		GlobalEnums.FiveParcsecsCampaignType.STANDARD:
			_add_condition(GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_THRESHOLD, {"threshold": 10000})
			_add_condition(GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_THRESHOLD, {"threshold": 20})

		GlobalEnums.FiveParcsecsCampaignType.STORY:
			_add_condition(GlobalEnums.FiveParsecsCampaignVictoryType.STORY_COMPLETE, {})

		GlobalEnums.FiveParcsecsCampaignType.SANDBOX:
			_add_condition(GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100, {})

		GlobalEnums.FiveParcsecsCampaignType.TUTORIAL:
			_add_condition(GlobalEnums.FiveParsecsCampaignVictoryType.MISSION_COUNT, {"count": 3})

	# Add any custom _conditions
	for condition in custom_conditions:
		if condition is Dictionary and condition.has("type") and condition.has("params"):
			_add_condition(condition.type, condition.params)

# Add a victory condition with parameters
func _add_condition(condition_type: int, params: Dictionary) -> void:
	var condition = {
		"_type": condition_type,
		"params": params,
		"current_progress": 0,
		"required_progress": _get_required_progress(condition_type, params)
	}

	_active_conditions[condition_type] = condition

# Calculate the required progress for a condition _type
func _get_required_progress(condition_type: int, params: Dictionary) -> int:
	match condition_type:
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_THRESHOLD:
			return params.get("threshold", 10000)

		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_THRESHOLD:
			return params.get("threshold", 20)

		GlobalEnums.FiveParsecsCampaignVictoryType.MISSION_COUNT:
			return params.get("count", 10)

		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20:
			return 20

		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50:
			return 50

		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100:
			return 100

		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3:
			return 3

		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5:
			return 5

		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10:
			return 10

		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_COMPLETE:
			return 1

		_:
			return 1

# Update progress for a specific condition by name/id
func update_progress(condition_type: int, progress: int) -> void:
	if not _active_conditions.has(condition_type):
		return

	var condition = _active_conditions[condition_type]
	condition.current_progress = progress

	# Check if condition is met
	if condition.current_progress >= condition.required_progress:
		victory_condition_reached.emit(condition_type, condition) # warning: return value discarded (intentional)
	else:
		victory_progress_updated.emit(condition_type, condition.current_progress, condition.required_progress)

# Increment progress for a specific condition
func increment_progress(condition_type: int, amount: int = 1) -> void:
	if not _active_conditions.has(condition_type):
		return

	var condition = _active_conditions[condition_type]
	condition.current_progress += amount

	# Check if condition is met
	if condition.current_progress >= condition.required_progress:
		victory_condition_reached.emit(condition_type, condition)
	else:
		victory_progress_updated.emit(condition_type, condition.current_progress, condition.required_progress)

# Check if any victory condition has been met
func check_victory() -> bool:
	for condition_key in _active_conditions:
		var condition = _active_conditions[condition_key]
		if condition.current_progress >= condition.required_progress:
			return true

	return false

# Get all victory conditions with their progress
func get_victory_conditions() -> Dictionary:
	return _active_conditions.duplicate(true)

# Get progress for a specific condition
func get_condition_progress(condition_type: int) -> Dictionary:
	if _active_conditions.has(condition_type):
		return _active_conditions[condition_type].duplicate(true)
	else:
		return {}

# Record a completed mission
func record_mission_complete(mission_type: int) -> void:
	# Update mission count condition if active
	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.MISSION_COUNT):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.MISSION_COUNT)

	# Update story progress if it's a story mission and the condition is active
	if mission_type == GlobalEnums.MissionType.PATRON and _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.STORY_COMPLETE):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.STORY_COMPLETE)

# Record a completed campaign turn
func record_campaign_turn() -> void:
	# Check which turn counters are active and update them
	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20)

	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50)

	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100)

# Update credits for credit threshold victory condition
func update_credits(credits: int) -> void:
	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_THRESHOLD):
		update_progress(GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_THRESHOLD, credits)

# Update reputation for reputation threshold victory condition
func update_reputation(reputation: int) -> void:
	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_THRESHOLD):
		update_progress(GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_THRESHOLD, reputation)

# Record completion of a quest
func record_quest_complete() -> void:
	# Update all quest counters
	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3)

	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5)

	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10)

	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.STORY_COMPLETE):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5)

	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.STORY_COMPLETE):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.STORY_COMPLETE)

