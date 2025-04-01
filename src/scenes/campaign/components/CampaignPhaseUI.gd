# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Control

const Self = preload("res://src/scenes/campaign/components/CampaignPhaseUI.gd")
const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const CampaignPhaseManager = preload("res://src/core/campaign/CampaignPhaseManager.gd")

signal action_requested(action_type: String)

@onready var phase_label := $PhaseLabel
@onready var action_container := $ActionContainer
@onready var description_label := $DescriptionLabel
@onready var progress_bar := $ProgressBar

var phase_manager: CampaignPhaseManager
var current_phase: GameEnums.FiveParcsecsCampaignPhase
var available_actions: Dictionary = {}

const PHASE_NAMES = {
	GameEnums.FiveParcsecsCampaignPhase.NONE: "None",
	GameEnums.FiveParcsecsCampaignPhase.SETUP: "Setup",
	GameEnums.FiveParcsecsCampaignPhase.UPKEEP: "Upkeep",
	GameEnums.FiveParcsecsCampaignPhase.STORY: "Story",
	GameEnums.FiveParcsecsCampaignPhase.TRAVEL: "Travel",
	GameEnums.FiveParcsecsCampaignPhase.PRE_MISSION: "Pre-Mission",
	GameEnums.FiveParcsecsCampaignPhase.MISSION: "Mission",
	GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP: "Battle Setup",
	GameEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION: "Battle Resolution",
	GameEnums.FiveParcsecsCampaignPhase.POST_MISSION: "Post-Mission",
	GameEnums.FiveParcsecsCampaignPhase.ADVANCEMENT: "Advancement",
	GameEnums.FiveParcsecsCampaignPhase.TRADING: "Trade",
	GameEnums.FiveParcsecsCampaignPhase.CHARACTER: "Character",
	GameEnums.FiveParcsecsCampaignPhase.RETIREMENT: "Retirement"
}

const PHASE_DESCRIPTIONS = {
	GameEnums.FiveParcsecsCampaignPhase.NONE: "No active phase",
	GameEnums.FiveParcsecsCampaignPhase.SETUP: "Create your crew and prepare for adventure",
	GameEnums.FiveParcsecsCampaignPhase.UPKEEP: "Maintain your crew and resources",
	GameEnums.FiveParcsecsCampaignPhase.STORY: "Progress through story events",
	GameEnums.FiveParcsecsCampaignPhase.TRAVEL: "Travel between locations",
	GameEnums.FiveParcsecsCampaignPhase.PRE_MISSION: "Prepare for your mission",
	GameEnums.FiveParcsecsCampaignPhase.MISSION: "Undertake your current mission",
	GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP: "Prepare for combat",
	GameEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION: "Handle battle aftermath",
	GameEnums.FiveParcsecsCampaignPhase.POST_MISSION: "Resolve mission outcomes",
	GameEnums.FiveParcsecsCampaignPhase.ADVANCEMENT: "Improve your crew",
	GameEnums.FiveParcsecsCampaignPhase.TRADING: "Buy and sell equipment",
	GameEnums.FiveParcsecsCampaignPhase.CHARACTER: "Manage your characters",
	GameEnums.FiveParcsecsCampaignPhase.RETIREMENT: "End your campaign"
}

func _ready() -> void:
	_setup_ui()
	_connect_signals()

func initialize(manager: CampaignPhaseManager) -> void:
	phase_manager = manager
	phase_manager.phase_changed.connect(_on_phase_changed)
	phase_manager.phase_action_available.connect(_on_phase_action_available)
	phase_manager.phase_completed.connect(_on_phase_completed)
	
	_update_phase_display(GameEnums.FiveParcsecsCampaignPhase.NONE if phase_manager.current_phase == null else phase_manager.current_phase as GameEnums.FiveParcsecsCampaignPhase)

func _setup_ui() -> void:
	# Clear any existing actions
	for child in action_container.get_children():
		child.queue_free()

func _connect_signals() -> void:
	# Connect UI element signals here
	pass

func _update_phase_display(phase: GameEnums.FiveParcsecsCampaignPhase) -> void:
	current_phase = phase
	phase_label.text = PHASE_NAMES[phase]
	description_label.text = PHASE_DESCRIPTIONS[phase]
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

func _get_required_actions(phase: GameEnums.FiveParcsecsCampaignPhase) -> Array:
	match phase:
		GameEnums.FiveParcsecsCampaignPhase.SETUP:
			return ["crew_created", "campaign_selected"]
		GameEnums.FiveParcsecsCampaignPhase.UPKEEP:
			return ["upkeep_paid", "resources_updated"]
		GameEnums.FiveParcsecsCampaignPhase.STORY:
			return ["world_events_resolved", "location_checked"]
		GameEnums.FiveParcsecsCampaignPhase.PRE_MISSION:
			return ["tasks_assigned", "patron_selected"]
		GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP:
			return ["deployment_ready"]
		GameEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION:
			return ["battle_completed", "rewards_calculated"]
		GameEnums.FiveParcsecsCampaignPhase.ADVANCEMENT:
			return ["management_completed"]
		_:
			return []

func _update_available_actions(phase: GameEnums.FiveParcsecsCampaignPhase) -> void:
	# Clear existing action buttons
	for child in action_container.get_children():
		child.queue_free()
	
	# Add new action buttons based on phase
	match phase:
		GameEnums.FiveParcsecsCampaignPhase.NONE:
			return
			
		GameEnums.FiveParcsecsCampaignPhase.SETUP:
			_add_action_button("create_crew", "Create Crew")
			_add_action_button("select_campaign", "Select Campaign")
			_add_action_button("start_campaign", "Start Campaign", not _is_setup_complete())
		
		GameEnums.FiveParcsecsCampaignPhase.UPKEEP:
			_add_action_button("pay_upkeep", "Pay Upkeep")
			_add_action_button("manage_resources", "Manage Resources")
			_add_action_button("check_crew", "Check Crew Status")
			_add_action_button("complete_upkeep", "Complete Upkeep", not _can_complete_upkeep())
		
		GameEnums.FiveParcsecsCampaignPhase.STORY:
			_add_action_button("check_events", "Check Events")
			_add_action_button("view_story", "View Story Progress")
			_add_action_button("resolve_events", "Resolve Events")
			_add_action_button("complete_story", "Complete Story Phase", not _can_complete_story())
		
		GameEnums.FiveParcsecsCampaignPhase.PRE_MISSION:
			_add_action_button("view_missions", "View Available Missions")
			_add_action_button("manage_crew", "Manage Crew")
			_add_action_button("trade_equipment", "Trade Equipment")
			_add_action_button("complete_campaign", "Complete Campaign Phase", not _can_complete_campaign())
		
		GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP:
			_add_action_button("setup_battlefield", "Setup Battlefield")
			_add_action_button("deploy_crew", "Deploy Crew")
			_add_action_button("start_battle", "Start Battle", not _can_start_battle())
		
		GameEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION:
			_add_action_button("resolve_combat", "Resolve Combat")
			_add_action_button("check_casualties", "Check Casualties")
			_add_action_button("collect_rewards", "Collect Rewards")
			_add_action_button("complete_battle", "Complete Battle Phase", not _can_complete_battle())
		
		GameEnums.FiveParcsecsCampaignPhase.ADVANCEMENT:
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

func _on_phase_changed(new_phase: GameEnums.FiveParcsecsCampaignPhase) -> void:
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
