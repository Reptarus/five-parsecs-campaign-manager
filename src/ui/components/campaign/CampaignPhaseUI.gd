class_name FPCM_CampaignPhaseUI
extends Control

# GlobalEnums available as autoload singleton
const CampaignPhaseManager = preload("res://src/core/campaign/CampaignPhaseManager.gd")

signal action_requested(action_type: String)

@onready var phase_label := $PhaseLabel
@onready var action_container := $ActionContainer
@onready var description_label := $DescriptionLabel
@onready var progress_bar := $ProgressBar

var phase_manager: CampaignPhaseManager
var current_phase: GlobalEnums.FiveParsecsCampaignPhase
var available_actions: Dictionary = {}

func _ready() -> void:
	_setup_ui()
	_connect_signals()

func initialize(manager: CampaignPhaseManager) -> void:
	phase_manager = manager
	phase_manager.phase_changed.connect(_on_phase_changed)
	phase_manager.phase_action_available.connect(_on_phase_action_available)
	phase_manager.phase_completed.connect(_on_phase_completed)

	_update_phase_display(phase_manager.current_phase)

func _setup_ui() -> void:
	# Clear any existing actions
	for child in action_container.get_children():
		child.queue_free()

func _connect_signals() -> void:
	# Connect UI element signals here
	pass

func _update_phase_display(phase: GlobalEnums.FiveParsecsCampaignPhase) -> void:
	current_phase = phase
	phase_label.text = GlobalEnums.PHASE_NAMES[phase]
	description_label.text = GlobalEnums.PHASE_DESCRIPTIONS[phase]
	_update_available_actions(phase)
	_update_progress_display()

func _update_progress_display() -> void:
	if not phase_manager:
		return

	var _phase_state = phase_manager.get_phase_state()
	var progress: int = 0

	# Calculate progress based on completed actions
	var required_actions = _get_required_actions(current_phase)
	var completed_actions: int = 0
	for action in required_actions:
		if phase_manager.phase_actions_completed.get(action, false):
			completed_actions += 1

	if required_actions.size() > 0:
		progress = float(completed_actions) / required_actions.size()

	progress_bar._value = progress * 100

func _get_required_actions(phase: GlobalEnums.FiveParsecsCampaignPhase) -> Array:
	match phase:
		GlobalEnums.FiveParsecsCampaignPhase.SETUP:
			return ["Create crew", "Select ship", "Choose starting world"]
		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL:
			return ["Decide travel", "Resolve events", "Arrive at destination"]
		GlobalEnums.FiveParsecsCampaignPhase.WORLD:
			return ["Upkeep & repairs", "Assign crew tasks", "Handle jobs", "Select battle"]
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE:
			return ["Execute combat", "Apply damage", "Check objectives"]
		GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE:
			return ["Handle casualties", "Collect rewards", "Process advancement"]
		_:
			return []

func _update_available_actions(phase: GlobalEnums.FiveParsecsCampaignPhase) -> void:
	# Clear existing action buttons
	for child in action_container.get_children():
		child.queue_free()

	# Add new action buttons based on phase
	match phase:
		GlobalEnums.FiveParsecsCampaignPhase.NONE:
			return

		GlobalEnums.FiveParsecsCampaignPhase.SETUP:
			_add_action_button("create_crew", "Create Crew")
			_add_action_button("select_campaign", "Select Campaign")
			_add_action_button("start_campaign", "Start Campaign", not _is_setup_complete())

		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL:
			_add_action_button("check_events", "Check Events")
			_add_action_button("view_story", "View Story Progress")
			_add_action_button("resolve_events", "Resolve Events")
			_add_action_button("complete_story", "Complete Story Phase", not _can_complete_story())

		GlobalEnums.FiveParsecsCampaignPhase.WORLD:
			_add_action_button("pay_upkeep", "Pay Upkeep")
			_add_action_button("view_missions", "View Available Missions")
			_add_action_button("manage_crew", "Manage Crew")
			_add_action_button("trade_equipment", "Trade Equipment")
			_add_action_button("complete_campaign", "Complete Campaign Phase", not _can_complete_campaign())

		GlobalEnums.FiveParsecsCampaignPhase.BATTLE:
			_add_action_button("setup_battlefield", "Setup Battlefield")
			_add_action_button("deploy_crew", "Deploy Crew")
			_add_action_button("execute_combat", "Execute Combat")
			_add_action_button("complete_battle", "Complete Battle", not _can_start_battle())

		GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE:
			_add_action_button("resolve_combat", "Resolve Combat")
			_add_action_button("check_casualties", "Check Casualties")
			_add_action_button("collect_rewards", "Collect Rewards")
			_add_action_button("complete_battle", "Complete Battle Phase", not _can_complete_battle())

		GlobalEnums.FiveParsecsCampaignPhase.BATTLE:
			_add_action_button("level_up", "Level Up Characters")
			_add_action_button("update_equipment", "Update Equipment")
			_add_action_button("complete_turn", "Complete Turn", not _can_complete_turn())

func _add_action_button(action_type: String, label: String, disabled: bool = false) -> void:
	var button := Button.new()
	button.text = label

	button.disabled = disabled or not available_actions.get(action_type, true)
	button.pressed.connect(func(): _on_action_button_pressed(action_type))
	action_container.add_child(button)

func _is_setup_complete() -> bool:
	return phase_manager.phase_actions_completed.get("crew_created", false) and phase_manager.phase_actions_completed.get("campaign_selected", false)

func _can_complete_upkeep() -> bool:
	return phase_manager.phase_actions_completed.get("upkeep_paid", false)

func _can_complete_story() -> bool:
	return phase_manager.phase_actions_completed.get("world_events_resolved", false) and phase_manager.phase_actions_completed.get("location_checked", false)

func _can_complete_campaign() -> bool:
	return phase_manager.phase_actions_completed.get("tasks_assigned", false) and phase_manager.phase_actions_completed.get("patron_selected", false)

func _can_start_battle() -> bool:
	return phase_manager.phase_actions_completed.get("deployment_ready", false)

func _can_complete_battle() -> bool:
	return phase_manager.phase_actions_completed.get("battle_completed", false) and phase_manager.phase_actions_completed.get("rewards_calculated", false)

func _can_complete_turn() -> bool:
	return phase_manager.phase_actions_completed.get("management_completed", false)

func _on_action_button_pressed(action_type: String) -> void:
	action_requested.emit(action_type)

	# Update UI state immediately for better responsiveness
	_update_progress_display()

func _on_phase_changed(new_phase: GlobalEnums.FiveParsecsCampaignPhase) -> void:
	_update_phase_display(new_phase)

func _on_phase_action_available(action_type: String, is_available: bool) -> void:
	available_actions[action_type] = is_available
	_update_available_actions(current_phase)

func _on_phase_completed() -> void:
	# Disable all actions when phase is completed
	for child in action_container.get_children():
		if child is Button:
			child.disabled = true

	# Update progress display
	_update_progress_display()

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
