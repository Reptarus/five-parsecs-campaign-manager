class_name CampaignPhaseUI
extends Control

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal action_requested(action_type: String)

@onready var phase_label := $PhaseLabel
@onready var action_container := $ActionContainer
@onready var description_label := $DescriptionLabel
@onready var progress_bar := $ProgressBar

var phase_manager: CampaignPhaseManager
var current_phase: GameEnums.CampaignPhase
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

func _update_phase_display(phase: GameEnums.CampaignPhase) -> void:
	current_phase = phase
	phase_label.text = GameEnums.PHASE_NAMES[phase]
	description_label.text = GameEnums.PHASE_DESCRIPTIONS[phase]
	_update_available_actions(phase)
	_update_progress_display()

func _update_progress_display() -> void:
	if not phase_manager:
		return
		
	var phase_state = phase_manager.get_phase_state()
	var progress = 0.0
	
	# Calculate progress based on completed actions
	var required_actions = _get_required_actions(current_phase)
	var completed_actions = 0
	for action in required_actions:
		if phase_manager.phase_actions_completed.get(action, false):
			completed_actions += 1
	
	if required_actions.size() > 0:
		progress = float(completed_actions) / required_actions.size()
	
	progress_bar.value = progress * 100

func _get_required_actions(phase: GameEnums.CampaignPhase) -> Array:
	match phase:
		GameEnums.CampaignPhase.SETUP:
			return ["crew_created", "campaign_selected"]
		GameEnums.CampaignPhase.UPKEEP:
			return ["upkeep_paid", "resources_updated"]
		GameEnums.CampaignPhase.STORY:
			return ["world_events_resolved", "location_checked"]
		GameEnums.CampaignPhase.CAMPAIGN:
			return ["tasks_assigned", "patron_selected"]
		GameEnums.CampaignPhase.BATTLE_SETUP:
			return ["deployment_ready"]
		GameEnums.CampaignPhase.BATTLE_RESOLUTION:
			return ["battle_completed", "rewards_calculated"]
		GameEnums.CampaignPhase.ADVANCEMENT:
			return ["management_completed"]
		_:
			return []

func _update_available_actions(phase: GameEnums.CampaignPhase) -> void:
	# Clear existing action buttons
	for child in action_container.get_children():
		child.queue_free()
	
	# Add new action buttons based on phase
	match phase:
		GameEnums.CampaignPhase.NONE:
			return
			
		GameEnums.CampaignPhase.SETUP:
			_add_action_button("create_crew", "Create Crew")
			_add_action_button("select_campaign", "Select Campaign")
			_add_action_button("start_campaign", "Start Campaign", not _is_setup_complete())
		
		GameEnums.CampaignPhase.UPKEEP:
			_add_action_button("pay_upkeep", "Pay Upkeep")
			_add_action_button("manage_resources", "Manage Resources")
			_add_action_button("check_crew", "Check Crew Status")
			_add_action_button("complete_upkeep", "Complete Upkeep", not _can_complete_upkeep())
		
		GameEnums.CampaignPhase.STORY:
			_add_action_button("check_events", "Check Events")
			_add_action_button("view_story", "View Story Progress")
			_add_action_button("resolve_events", "Resolve Events")
			_add_action_button("complete_story", "Complete Story Phase", not _can_complete_story())
		
		GameEnums.CampaignPhase.CAMPAIGN:
			_add_action_button("view_missions", "View Available Missions")
			_add_action_button("manage_crew", "Manage Crew")
			_add_action_button("trade_equipment", "Trade Equipment")
			_add_action_button("complete_campaign", "Complete Campaign Phase", not _can_complete_campaign())
		
		GameEnums.CampaignPhase.BATTLE_SETUP:
			_add_action_button("setup_battlefield", "Setup Battlefield")
			_add_action_button("deploy_crew", "Deploy Crew")
			_add_action_button("start_battle", "Start Battle", not _can_start_battle())
		
		GameEnums.CampaignPhase.BATTLE_RESOLUTION:
			_add_action_button("resolve_combat", "Resolve Combat")
			_add_action_button("check_casualties", "Check Casualties")
			_add_action_button("collect_rewards", "Collect Rewards")
			_add_action_button("complete_battle", "Complete Battle Phase", not _can_complete_battle())
		
		GameEnums.CampaignPhase.ADVANCEMENT:
			_add_action_button("level_up", "Level Up Characters")
			_add_action_button("update_equipment", "Update Equipment")
			_add_action_button("complete_turn", "Complete Turn", not _can_complete_turn())

func _add_action_button(action_type: String, label: String, disabled: bool = false) -> void:
	var button = Button.new()
	button.text = label
	button.disabled = disabled or not available_actions.get(action_type, true)
	button.pressed.connect(func(): _on_action_button_pressed(action_type))
	action_container.add_child(button)

func _is_setup_complete() -> bool:
	return phase_manager.phase_actions_completed.get("crew_created", false) and \
	       phase_manager.phase_actions_completed.get("campaign_selected", false)

func _can_complete_upkeep() -> bool:
	return phase_manager.phase_actions_completed.get("upkeep_paid", false) and \
	       phase_manager.phase_actions_completed.get("resources_updated", false)

func _can_complete_story() -> bool:
	return phase_manager.phase_actions_completed.get("world_events_resolved", false) and \
	       phase_manager.phase_actions_completed.get("location_checked", false)

func _can_complete_campaign() -> bool:
	return phase_manager.phase_actions_completed.get("tasks_assigned", false) and \
	       phase_manager.phase_actions_completed.get("patron_selected", false)

func _can_start_battle() -> bool:
	return phase_manager.phase_actions_completed.get("deployment_ready", false)

func _can_complete_battle() -> bool:
	return phase_manager.phase_actions_completed.get("battle_completed", false) and \
	       phase_manager.phase_actions_completed.get("rewards_calculated", false)

func _can_complete_turn() -> bool:
	return phase_manager.phase_actions_completed.get("management_completed", false)

func _on_action_button_pressed(action_type: String) -> void:
	action_requested.emit(action_type)
	
	# Update UI state immediately for better responsiveness
	_update_progress_display()

func _on_phase_changed(new_phase: GameEnums.CampaignPhase) -> void:
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