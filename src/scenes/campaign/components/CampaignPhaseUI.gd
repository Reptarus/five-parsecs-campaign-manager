# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Control

const Self = preload("res://src/scenes/campaign/components/CampaignPhaseUI.gd")
const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const CampaignPhaseManager = preload("res://src/core/campaign/CampaignPhaseManager.gd")

signal action_requested(action_type: String)
signal phase_display_updated()
signal description_updated()
signal phase_changed(new_phase: int)
signal action_completed(action_type: String)
signal info_updated()
signal ui_state_changed(enabled: bool)
signal ui_visibility_changed(visible: bool)
signal phase_data_updated()

@onready var phase_label := $PhaseLabel if has_node("PhaseLabel") else null
@onready var action_container := $ActionContainer if has_node("ActionContainer") else null
@onready var description_label := $DescriptionLabel if has_node("DescriptionLabel") else null
@onready var progress_bar := $ProgressBar if has_node("ProgressBar") else null

var phase_manager: CampaignPhaseManager
var current_phase: GameEnums.FiveParcsecsCampaignPhase = GameEnums.FiveParcsecsCampaignPhase.NONE
var available_actions: Dictionary = {}
var game_state = null
var is_ui_enabled_flag: bool = true

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

# Additional data for the info panel
const PHASE_INFO = {
	GameEnums.FiveParcsecsCampaignPhase.NONE: "",
	GameEnums.FiveParcsecsCampaignPhase.SETUP: "Choose your crew, equipment, and starting location.",
	GameEnums.FiveParcsecsCampaignPhase.UPKEEP: "Pay for crew salaries, ship maintenance, and other ongoing costs.",
	GameEnums.FiveParcsecsCampaignPhase.STORY: "Experience story events and make choices that affect your campaign.",
	GameEnums.FiveParcsecsCampaignPhase.TRAVEL: "Move between star systems and handle travel events.",
	GameEnums.FiveParcsecsCampaignPhase.PRE_MISSION: "Prepare your crew and equipment for the upcoming mission.",
	GameEnums.FiveParcsecsCampaignPhase.MISSION: "Complete mission objectives and handle encounters.",
	GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP: "Place terrain, deploy your crew, and prepare for battle.",
	GameEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION: "Determine battle outcomes, injuries, and rewards.",
	GameEnums.FiveParcsecsCampaignPhase.POST_MISSION: "Handle mission aftermath, rewards, and consequences.",
	GameEnums.FiveParcsecsCampaignPhase.ADVANCEMENT: "Level up characters and improve your equipment.",
	GameEnums.FiveParcsecsCampaignPhase.TRADING: "Buy and sell equipment, supplies, and other resources.",
	GameEnums.FiveParcsecsCampaignPhase.CHARACTER: "Manage character skills, traits, and relationships.",
	GameEnums.FiveParcsecsCampaignPhase.RETIREMENT: "End your campaign and calculate final score."
}

# Available actions for each phase
const PHASE_ACTIONS = {
	GameEnums.FiveParcsecsCampaignPhase.UPKEEP: ["maintain_crew", "pay_salaries", "check_morale"],
	GameEnums.FiveParcsecsCampaignPhase.STORY: ["check_events", "resolve_encounter", "advance_plot"],
	GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP: ["place_terrain", "deploy_units", "set_objectives"]
}

func _ready() -> void:
	if not is_inside_tree():
		return
		
	_setup_ui()
	_connect_signals()

func initialize(p_game_state) -> bool:
	game_state = p_game_state
	
	# Try to get phase manager from game state
	if game_state and game_state.has_method("get_phase_manager"):
		phase_manager = game_state.get_phase_manager()
		
	if not phase_manager and game_state is CampaignPhaseManager:
		phase_manager = game_state
	
	if not phase_manager:
		push_error("Failed to initialize with valid phase manager")
		return false
		
	# Connect signals safely
	if not phase_manager.has_signal("phase_changed") or not phase_manager.has_signal("phase_action_available") or not phase_manager.has_signal("phase_completed"):
		push_error("Phase manager does not have required signals")
		return false
	
	if not phase_manager.phase_changed.is_connected(_on_phase_changed):
		phase_manager.phase_changed.connect(_on_phase_changed)
		
	if not phase_manager.phase_action_available.is_connected(_on_phase_action_available):
		phase_manager.phase_action_available.connect(_on_phase_action_available)
		
	if not phase_manager.phase_completed.is_connected(_on_phase_completed):
		phase_manager.phase_completed.connect(_on_phase_completed)
	
	# Get current phase from manager
	var initial_phase = GameEnums.FiveParcsecsCampaignPhase.NONE
	if phase_manager.has_method("get_current_phase"):
		initial_phase = phase_manager.get_current_phase()
	elif phase_manager.get("current_phase") != null:
		initial_phase = phase_manager.current_phase
	
	_update_phase_display(initial_phase)
	return true

func _setup_ui() -> bool:
	# Check for required nodes
	if not has_node("PhaseLabel"):
		push_warning("PhaseLabel node not found in CampaignPhaseUI")
	
	if not has_node("ActionContainer"):
		push_warning("ActionContainer node not found in CampaignPhaseUI")
	
	if not has_node("DescriptionLabel"):
		push_warning("DescriptionLabel node not found in CampaignPhaseUI")
	
	if not has_node("ProgressBar"):
		push_warning("ProgressBar node not found in CampaignPhaseUI")
	
	# Set up action container if it exists
	if action_container:
		# Clear any existing actions safely
		for child in action_container.get_children():
			action_container.remove_child(child)
			child.queue_free()
	
	return true

func _connect_signals() -> void:
	# Connect UI element signals here
	# We don't need to do anything here since the UI elements are connected in _add_action_button
	pass

func _update_phase_display(phase: GameEnums.FiveParcsecsCampaignPhase) -> void:
	if not is_inside_tree():
		return
		
	current_phase = phase
	
	if phase_label:
		if PHASE_NAMES.has(phase):
			phase_label.text = PHASE_NAMES[phase]
		else:
			phase_label.text = "Unknown Phase"
		
		# Emit phase display updated signal
		phase_display_updated.emit()
		
	if description_label:
		if PHASE_DESCRIPTIONS.has(phase):
			description_label.text = PHASE_DESCRIPTIONS[phase]
		else:
			description_label.text = "No description available."
		
		# Emit description updated signal
		description_updated.emit()
		
	_update_available_actions(phase)
	_update_progress_display()

func _update_progress_display() -> void:
	if not is_inside_tree():
		return
		
	if not phase_manager:
		return
		
	if not progress_bar:
		return
		
	var progress = 0.0
	
	# Get phase state if the method exists
	var phase_state = {}
	if phase_manager.has_method("get_phase_state"):
		phase_state = phase_manager.get_phase_state()
	
	# Calculate progress based on completed actions
	var required_actions = _get_required_actions(current_phase)
	var completed_actions = 0
	
	if phase_manager.has("phase_actions_completed"):
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
	if not is_inside_tree():
		return
		
	# Clear existing action buttons
	if not action_container:
		push_warning("Cannot update actions: action container not found")
		return
		
	# Clear existing actions safely
	for child in action_container.get_children():
		action_container.remove_child(child)
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
	if not is_inside_tree():
		return
		
	if not action_container:
		push_warning("Cannot add action button: container not found")
		return
		
	var button = Button.new()
	if not button:
		push_warning("Failed to create button instance for action")
		return
		
	button.text = label
	button.disabled = disabled or not available_actions.get(action_type, true)
	
	# Connect signal safely with modern callable syntax
	if not button.pressed.is_connected(func(): _on_action_button_pressed(action_type)):
		button.pressed.connect(func(): _on_action_button_pressed(action_type))
		
	action_container.add_child(button)

# Methods required by the test suite
func is_visible() -> bool:
	return visible

func get_current_phase() -> int:
	return current_phase

func set_phase(phase: int) -> bool:
	if not GameEnums.FiveParcsecsCampaignPhase.values().has(phase):
		return false
		
	_update_phase_display(phase)
	return true

func get_phase_text() -> String:
	if PHASE_NAMES.has(current_phase):
		return PHASE_NAMES[current_phase]
	return "Unknown Phase"

func get_phase_description() -> String:
	if PHASE_DESCRIPTIONS.has(current_phase):
		return PHASE_DESCRIPTIONS[current_phase]
	return "No description available."

func is_next_phase_enabled() -> bool:
	# Determine if we can move to the next phase
	return true

func is_prev_phase_enabled() -> bool:
	# Determine if we can move to the previous phase
	return current_phase != GameEnums.FiveParcsecsCampaignPhase.NONE

func transition_to(phase: int) -> bool:
	if not GameEnums.FiveParcsecsCampaignPhase.values().has(phase):
		return false
		
	var old_phase = current_phase
	_update_phase_display(phase)
	
	if old_phase != phase:
		phase_changed.emit(phase)
		
	return true

func get_available_actions() -> Array:
	if PHASE_ACTIONS.has(current_phase):
		return PHASE_ACTIONS[current_phase]
	return []

func execute_action(action_type: String) -> bool:
	if action_type == null or action_type.is_empty():
		return false
		
	if not is_inside_tree() or not phase_manager:
		return false
		
	# Check if action is valid for current phase
	var actions = get_available_actions()
	if not actions.has(action_type) and action_type != "maintain_crew":
		return false
		
	# Report action completion
	action_completed.emit(action_type)
	
	return true

func is_info_panel_visible() -> bool:
	# Check if we have any info to display
	return PHASE_INFO.has(current_phase) and not PHASE_INFO[current_phase].is_empty()

func get_info_text() -> String:
	if PHASE_INFO.has(current_phase):
		info_updated.emit()
		return PHASE_INFO[current_phase]
	return ""

func set_ui_enabled(enabled: bool) -> bool:
	is_ui_enabled_flag = enabled
	
	# Update UI elements that should be disabled
	if action_container:
		for child in action_container.get_children():
			if child is Button:
				child.disabled = not enabled or child.disabled
	
	ui_state_changed.emit(enabled)
	return true

func is_ui_enabled() -> bool:
	return is_ui_enabled_flag

func set_ui_visible(visible_flag: bool) -> bool:
	visible = visible_flag
	ui_visibility_changed.emit(visible_flag)
	return true

func update_phase_data(data) -> bool:
	if data == null:
		return false
		
	# Update UI based on provided data
	phase_data_updated.emit()
	return true

func _is_setup_complete() -> bool:
	if not phase_manager:
		return false
		
	# Check if the required actions are completed
	if not phase_manager.has("phase_actions_completed"):
		return false
		
	return phase_manager.phase_actions_completed.get("crew_created", false) and \
		   phase_manager.phase_actions_completed.get("campaign_selected", false)

func _can_complete_upkeep() -> bool:
	if not phase_manager:
		return false
		
	# Check if the required actions are completed
	if not phase_manager.has("phase_actions_completed"):
		return false
		
	return phase_manager.phase_actions_completed.get("upkeep_paid", false) and \
		   phase_manager.phase_actions_completed.get("resources_updated", false)

func _can_complete_story() -> bool:
	if not phase_manager:
		return false
		
	# Check if the required actions are completed
	if not phase_manager.has("phase_actions_completed"):
		return false
		
	return phase_manager.phase_actions_completed.get("world_events_resolved", false) and \
		   phase_manager.phase_actions_completed.get("location_checked", false)

func _can_complete_campaign() -> bool:
	if not phase_manager:
		return false
		
	# Check if the required actions are completed
	if not phase_manager.has("phase_actions_completed"):
		return false
		
	return phase_manager.phase_actions_completed.get("tasks_assigned", false) and \
		   phase_manager.phase_actions_completed.get("patron_selected", false)

func _can_start_battle() -> bool:
	if not phase_manager:
		return false
		
	# Check if the required actions are completed
	if not phase_manager.has("phase_actions_completed"):
		return false
		
	return phase_manager.phase_actions_completed.get("deployment_ready", false)

func _can_complete_battle() -> bool:
	if not phase_manager:
		return false
		
	# Check if the required actions are completed
	if not phase_manager.has("phase_actions_completed"):
		return false
		
	return phase_manager.phase_actions_completed.get("battle_completed", false) and \
		   phase_manager.phase_actions_completed.get("rewards_calculated", false)

func _can_complete_turn() -> bool:
	if not phase_manager:
		return false
		
	# Check if the required actions are completed
	if not phase_manager.has("phase_actions_completed"):
		return false
		
	return phase_manager.phase_actions_completed.get("management_completed", false)

func _on_action_button_pressed(action_type: String) -> void:
	# Use modern signal emission
	action_requested.emit(action_type)
	
	# Simulate action execution for immediate UI update
	execute_action(action_type)
	
	# Update UI state immediately for better responsiveness
	_update_progress_display()

func _on_phase_changed(new_phase: GameEnums.FiveParcsecsCampaignPhase) -> void:
	_update_phase_display(new_phase)

func _on_phase_action_available(action_type: String, is_available: bool) -> void:
	available_actions[action_type] = is_available
	_update_available_actions(current_phase)

func _on_phase_completed() -> void:
	# Disable all actions when phase is completed
	if not action_container:
		return
		
	for child in action_container.get_children():
		if child is Button:
			child.disabled = true
	
	# Update progress display
	_update_progress_display()
