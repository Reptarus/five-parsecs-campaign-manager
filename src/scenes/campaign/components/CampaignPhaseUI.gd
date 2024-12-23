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
	phase_label.text = _get_phase_name(phase)
	description_label.text = _get_phase_description(phase)
	_update_available_actions(phase)

func _update_available_actions(phase: GameEnums.CampaignPhase) -> void:
	# Clear existing action buttons
	for child in action_container.get_children():
		child.queue_free()
	
	# Add new action buttons based on phase
	match phase:
		GameEnums.CampaignPhase.UPKEEP:
			_add_action_button("pay_upkeep", "Pay Upkeep")
			_add_action_button("skip_upkeep", "Skip (Take Debt)")
		
		GameEnums.CampaignPhase.WORLD_STEP:
			_add_action_button("assign_tasks", "Assign Tasks")
			_add_action_button("view_market", "View Market")
			_add_action_button("check_factions", "Check Factions")
		
		GameEnums.CampaignPhase.TRAVEL:
			_add_action_button("start_travel", "Start Travel")
			_add_action_button("check_invasion", "Check Invasion")
			if available_actions.get("can_flee", false):
				_add_action_button("flee_invasion", "Flee Invasion")
		
		GameEnums.CampaignPhase.PATRONS:
			_add_action_button("view_jobs", "View Jobs")
			_add_action_button("check_patrons", "Check Patrons")
			_add_action_button("skip_patrons", "Skip")
		
		GameEnums.CampaignPhase.BATTLE:
			_add_action_button("setup_battle", "Setup Battle")
			_add_action_button("start_battle", "Start Battle")
			_add_action_button("retreat", "Retreat")
		
		GameEnums.CampaignPhase.POST_BATTLE:
			_add_action_button("collect_rewards", "Collect Rewards")
			_add_action_button("check_injuries", "Check Injuries")
			_add_action_button("process_events", "Process Events")
		
		GameEnums.CampaignPhase.MANAGEMENT:
			_add_action_button("manage_crew", "Manage Crew")
			_add_action_button("manage_equipment", "Manage Equipment")
			_add_action_button("manage_resources", "Manage Resources")
			_add_action_button("upgrade_ship", "Upgrade Ship")
			_add_action_button("end_turn", "End Turn")

func _add_action_button(action_type: String, label: String) -> void:
	var button = Button.new()
	button.text = label
	button.disabled = not available_actions.get(action_type, true)
	button.pressed.connect(func(): _on_action_button_pressed(action_type))
	action_container.add_child(button)

func _get_phase_name(phase: GameEnums.CampaignPhase) -> String:
	return GameEnums.CampaignPhase.keys()[phase].capitalize()

func _get_phase_description(phase: GameEnums.CampaignPhase) -> String:
	match phase:
		GameEnums.CampaignPhase.UPKEEP:
			return "Pay maintenance costs and handle crew upkeep."
		GameEnums.CampaignPhase.WORLD_STEP:
			return "Explore the current world and handle local events."
		GameEnums.CampaignPhase.TRAVEL:
			return "Travel to new locations and handle starship events."
		GameEnums.CampaignPhase.PATRONS:
			return "Meet with patrons and accept new jobs."
		GameEnums.CampaignPhase.BATTLE:
			return "Engage in tactical combat."
		GameEnums.CampaignPhase.POST_BATTLE:
			return "Handle battle aftermath and collect rewards."
		GameEnums.CampaignPhase.MANAGEMENT:
			return "Manage your crew and resources."
		_:
			return "Unknown phase"

func _on_phase_changed(new_phase: GameEnums.CampaignPhase) -> void:
	_update_phase_display(new_phase)

func _on_phase_action_available(action_type: String, is_available: bool) -> void:
	available_actions[action_type] = is_available
	_update_available_actions(current_phase)

func _on_phase_completed() -> void:
	# Disable all actions when phase is completed
	for button in action_container.get_children():
		button.disabled = true

func _on_action_button_pressed(action_type: String) -> void:
	action_requested.emit(action_type) 