@tool
extends Node
class_name VictoryConditionTracker

## Victory Condition Tracker Implementation for Five Parsecs From Home
## Tracks the progress of various victory conditions for campaign completion

# Preload necessary enums and data managers
# GlobalEnums available as autoload singleton
const DataManager = preload("res://src/core/data/DataManager.gd")

# Signals
signal victory_condition_reached(condition_type: int, details: Dictionary)
signal victory_progress_updated(condition_type: int, current: int, required: int)

# Private variables
# DataManager is now used as static class - no instance needed
var _active_conditions: Dictionary = {}
var _campaign_data: Dictionary = {}

# Initialize the tracker
func _init() -> void:
	# DataManager will be initialized by autoload
	_load_data()

# Load necessary data
func _load_data() -> void:
	var victory_data = DataManager._load_json_safe("res://data/victory_conditions.json", "VictoryConditionTracker")
	if victory_data:
		_campaign_data = victory_data
	else:
		push_error("Failed to load victory conditions data")

# Set up victory conditions for a campaign
func setup_victory_conditions(campaign_type: int, custom_conditions: Array = []) -> void:
	_active_conditions.clear()

	# Set default _conditions based on campaign type
	match campaign_type:
		GlobalEnums.CampaignType.STANDARD:
			_add_condition(GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K, {})
			_add_condition(GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_10, {})

		GlobalEnums.CampaignType.FREELANCER:
			_add_condition(GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5, {})

		GlobalEnums.CampaignType.MERCENARY:
			_add_condition(GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100, {})

		GlobalEnums.CampaignType.EXPLORER:
			_add_condition(GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20, {})

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
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20:
			return 20

		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50:
			return 50

		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100:
			return 100

		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20:
			return 20

		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_50:
			return 50

		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_100:
			return 100

		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3:
			return 3

		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5:
			return 5

		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10:
			return 10

		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_10:
			return 10

		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_20:
			return 20

		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K:
			return 50000

		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_100K:
			return 100000

		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_10:
			return 10

		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_20:
			return 20

		GlobalEnums.FiveParsecsCampaignVictoryType.CHARACTER_SURVIVAL:
			return 1

		GlobalEnums.FiveParsecsCampaignVictoryType.CREW_SIZE_10:
			return 10

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

# Record a completed battle
func record_battle_complete() -> void:
	# Update battle count conditions if active
	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20)

	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_50):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_50)

	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_100):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_100)

# Record a completed campaign turn
func record_campaign_turn() -> void:
	# Check which turn counters are active and update them
	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20)

	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50)

	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100)

# Update credits for credit victory conditions
func update_credits(credits: int) -> void:
	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K):
		update_progress(GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K, credits)

	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_100K):
		update_progress(GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_100K, credits)

# Update reputation for reputation victory conditions
func update_reputation(reputation: int) -> void:
	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_10):
		update_progress(GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_10, reputation)

	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_20):
		update_progress(GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_20, reputation)

# Record completion of a quest
func record_quest_complete() -> void:
	# Update all quest counters
	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3)

	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5)

	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10)

# Record story points earned
func record_story_points(points: int) -> void:
	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_10):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_10, points)

	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_20):
		increment_progress(GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_20, points)

# Update crew size for crew size victory condition
func update_crew_size(size: int) -> void:
	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.CREW_SIZE_10):
		update_progress(GlobalEnums.FiveParsecsCampaignVictoryType.CREW_SIZE_10, size)

# Record character survival (called when original character survives dangerous situations)
func record_character_survival() -> void:
	if _active_conditions.has(GlobalEnums.FiveParsecsCampaignVictoryType.CHARACTER_SURVIVAL):
		# This victory condition is met by simply keeping the character alive
		# We could track dangerous situations survived, but for now just mark as complete
		update_progress(GlobalEnums.FiveParsecsCampaignVictoryType.CHARACTER_SURVIVAL, 1)
