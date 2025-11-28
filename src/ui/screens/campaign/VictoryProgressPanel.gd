extends PanelContainer

# GlobalEnums available as autoload singleton
const GameState = preload("res://src/core/state/GameState.gd")
const FallbackCampaignManager = preload("res://src/core/systems/FallbackCampaignManager.gd")
const FPCM_VictoryDescriptions = preload("res://src/game/victory/VictoryDescriptions.gd")

@onready var progress_bar := $MarginContainer/VBoxContainer/ProgressBar
@onready var progress_label := $MarginContainer/VBoxContainer/ProgressLabel
@onready var milestone_container := $MarginContainer/VBoxContainer/MilestoneContainer

var game_state: GameState
var campaign_manager # Type will be inferred from CampaignManager singleton
var victory_type: GlobalEnums.FiveParsecsCampaignVictoryType
var current_progress: float = 0.0
var target_progress: float = 20.0 # Default for TURNS_20
var milestones: Array[float] = []

# Multi-condition support
var victory_conditions: Array[int] = []  # All tracked victory types
var condition_progress: Dictionary = {}  # {victory_type: {current, target, percentage}}
var closest_condition: int = -1  # Victory type closest to completion

var _using_fallback: bool = false

func _ready() -> void:
	# Initialize campaign manager with fallback
	if has_node("/root/CampaignManager"):
		campaign_manager = get_node("/root/CampaignManager")
		_using_fallback = false
	else:
		# Create fallback campaign manager
		var fallback = FallbackCampaignManager.new()
		campaign_manager = fallback
		_using_fallback = true
		print("VictoryProgressPanel: Created fallback CampaignManager")
		push_warning("VictoryProgressPanel: Using fallback CampaignManager - autoload not available")

	# Get game_state with null safety
	if campaign_manager and "game_state" in campaign_manager:
		game_state = campaign_manager.game_state

	if not game_state:
		push_error("VictoryProgressPanel: GameState not found - displaying placeholder")
		_setup_placeholder_display()
		return

	_initialize_victory_tracking()
	_connect_signals()
	update_display()

func _setup_placeholder_display() -> void:
	"""Show placeholder when no game state is available"""
	if progress_label:
		progress_label.text = "No active campaign"
	if progress_bar:
		progress_bar.value = 0

func _connect_signals() -> void:
	if not campaign_manager:
		return

	# Check if campaign_system exists and has the required signals
	if "campaign_system" in campaign_manager and campaign_manager.campaign_system:
		var cs = campaign_manager.campaign_system
		if cs.has_signal("campaign_turn_completed"):
			cs.campaign_turn_completed.connect(_on_turn_completed)
		if cs.has_signal("campaign_progress_updated"):
			cs.campaign_progress_updated.connect(_on_progress_updated)
	else:
		push_warning("VictoryProgressPanel: campaign_system not available - progress updates disabled")

func _initialize_victory_tracking() -> void:
	# Get victory conditions - support both single and multi-condition modes
	victory_conditions.clear()
	condition_progress.clear()

	# Check for multi-condition support (new system)
	if "victory_conditions" in game_state and game_state.victory_conditions is Array:
		for cond in game_state.victory_conditions:
			if cond is int:
				victory_conditions.append(cond)

	# Fallback to single condition (legacy support)
	if victory_conditions.is_empty():
		if "campaign_victory_condition" in game_state:
			victory_type = game_state.campaign_victory_condition
			victory_conditions.append(victory_type)
		elif game_state.has_meta("campaign_victory_condition"):
			victory_type = game_state.get_meta("campaign_victory_condition")
			victory_conditions.append(victory_type)
		else:
			victory_type = GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20
			victory_conditions.append(victory_type)
			push_warning("VictoryProgressPanel: No victory condition set, defaulting to TURNS_20")

	# Initialize tracking for each condition
	for cond_type in victory_conditions:
		var target = _get_target_for_type(cond_type)
		condition_progress[cond_type] = {
			"current": 0.0,
			"target": target,
			"percentage": 0.0
		}

	# Set primary victory type (first in list or closest to completion)
	if victory_conditions.size() > 0:
		victory_type = victory_conditions[0]
		target_progress = _get_target_for_type(victory_type)
		milestones = _get_milestones_for_type(victory_type)

	progress_bar.max_value = target_progress
	_setup_milestone_icons()

func _get_target_for_type(vtype: int) -> float:
	"""Get target value for a victory type using FPCM_VictoryDescriptions"""
	match vtype:
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20:
			return 20.0
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50:
			return 50.0
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100:
			return 100.0
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20:
			return 20.0
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_50:
			return 50.0
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_100:
			return 100.0
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3:
			return 3.0
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5:
			return 5.0
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10:
			return 10.0
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_10:
			return 10.0
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_20:
			return 20.0
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K:
			return 50000.0
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_100K:
			return 100000.0
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_10:
			return 10.0
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_20:
			return 20.0
		GlobalEnums.FiveParsecsCampaignVictoryType.CHARACTER_SURVIVAL:
			return 1.0
		GlobalEnums.FiveParsecsCampaignVictoryType.CREW_SIZE_10:
			return 10.0
		_:
			return 20.0

func _get_milestones_for_type(vtype: int) -> Array[float]:
	"""Get milestone values for a victory type"""
	var target = _get_target_for_type(vtype)
	return [target * 0.25, target * 0.5, target * 0.75]

func _setup_milestone_icons() -> void:
	for i: int in range(3):
		var milestone_icon = milestone_container.get_child(i)
		if milestone_icon:
			milestone_icon.modulate = Color(0.5, 0.5, 0.5) # Dim by default

func update_display() -> void:
	# Update progress for all tracked conditions
	_update_all_condition_progress()

	# Find closest condition to completion
	_find_closest_condition()

	# Display the closest condition (or primary if single)
	var display_type = closest_condition if closest_condition >= 0 else victory_type
	if condition_progress.has(display_type):
		current_progress = condition_progress[display_type].current
		target_progress = condition_progress[display_type].target
	else:
		current_progress = _calculate_progress_for_type(display_type)
		target_progress = _get_target_for_type(display_type)

	progress_bar.max_value = target_progress
	progress_bar.value = current_progress

	# Build progress text using FPCM_VictoryDescriptions
	var name = FPCM_VictoryDescriptions.get_victory_name(display_type)
	var percentage = (current_progress / target_progress * 100.0) if target_progress > 0 else 0.0
	var progress_text = "%s: %d/%d (%.0f%%)" % [name, int(current_progress), int(target_progress), percentage]

	# Add indicator if multiple conditions are tracked
	if victory_conditions.size() > 1:
		progress_text += " [Closest]"

	progress_label.text = progress_text
	_update_milestone_display()

func _update_all_condition_progress() -> void:
	"""Update progress tracking for all victory conditions"""
	for cond_type in victory_conditions:
		var current = _calculate_progress_for_type(cond_type)
		var target = _get_target_for_type(cond_type)
		var percentage = (current / target * 100.0) if target > 0 else 0.0

		condition_progress[cond_type] = {
			"current": current,
			"target": target,
			"percentage": percentage
		}

func _find_closest_condition() -> void:
	"""Find the victory condition closest to completion"""
	var highest_percentage = -1.0
	closest_condition = -1

	for cond_type in victory_conditions:
		if condition_progress.has(cond_type):
			var percentage = condition_progress[cond_type].percentage
			if percentage > highest_percentage:
				highest_percentage = percentage
				closest_condition = cond_type

func _calculate_progress_for_type(vtype: int) -> float:
	"""Calculate current progress for a specific victory type"""
	match vtype:
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20, \
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50, \
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100:
			return float(game_state.campaign_turn) if "campaign_turn" in game_state else 0.0
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20, \
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_50, \
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_100:
			return float(game_state.battles_won) if "battles_won" in game_state else 0.0
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3, \
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5, \
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10:
			if "completed_quests" in game_state and game_state.completed_quests is Array:
				return float(game_state.completed_quests.size())
			return 0.0
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_10, \
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_20:
			return float(game_state.story_points) if "story_points" in game_state else 0.0
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K, \
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_100K:
			return float(game_state.credits) if "credits" in game_state else 0.0
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_10, \
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_20:
			return float(game_state.reputation) if "reputation" in game_state else 0.0
		GlobalEnums.FiveParsecsCampaignVictoryType.CHARACTER_SURVIVAL:
			return float(game_state.character_survival_progress) if "character_survival_progress" in game_state else 0.0
		GlobalEnums.FiveParsecsCampaignVictoryType.CREW_SIZE_10:
			if "crew" in game_state and game_state.crew is Array:
				return float(game_state.crew.size())
			return 0.0
	return 0.0

func _calculate_current_progress() -> float:
	match victory_type:
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20, GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50, GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100:
			return float(game_state.campaign_turn)
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3, GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5, GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10:
			return float(game_state.completed_quests.size())
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_20:
			return float(game_state.story_points)
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_100K:
			return float(game_state.credits)
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_20:
			return float(game_state.reputation)
		GlobalEnums.FiveParsecsCampaignVictoryType.CHARACTER_SURVIVAL:
			return float(game_state.character_survival_progress)
	return 0.0

func _update_milestone_display() -> void:
	for i: int in range(3):
		var milestone_icon = milestone_container.get_child(i)
		if milestone_icon and i < (safe_call_method(milestones, "size") as int):
			if current_progress >= milestones[i]:
				milestone_icon.modulate = Color(1, 1, 1) # Full brightness for achieved
			else:
				milestone_icon.modulate = Color(0.5, 0.5, 0.5) # Dim for not achieved

func _on_turn_completed() -> void:
	update_display()

func _on_progress_updated(progress: float) -> void:
	current_progress = progress
	update_display()
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
