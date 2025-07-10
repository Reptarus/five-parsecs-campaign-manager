# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
class_name FPCM_CampaignDashboardUI
extends Control

# Safe imports
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class

# Safe dependency loading with preload pattern
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const CampaignPhaseManagerScript = preload("res://src/core/campaign/CampaignPhaseManager.gd")
const FPCM_BasePhasePanel = preload("res://src/ui/screens/campaign/phases/BasePhasePanel.gd")

# Official Five Parsecs Phase Panels - following Four-Phase structure
var TravelPhasePanel: PackedScene = null
var WorldPhasePanel: PackedScene = null
var BattlePhasePanel: PackedScene = null
var PostBattlePhasePanel: PackedScene = null

# Deprecated phase panels - REMOVED
# All non-official phase panels have been removed to match official Five Parsecs rules

# UI Node References using safe access - FIXED TYPE ISSUES
@onready var phase_label: Label = get_node("MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/PhaseLabel") as Label
@onready var credits_label: Label = get_node("MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/CreditsLabel") as Label
@onready var story_points_label: Label = get_node("MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/StoryPointsLabel") as Label
@onready var crew_list: ItemList = get_node("MarginContainer/VBoxContainer/MainContent/LeftPanel/CrewPanel/VBoxContainer/CrewList") as ItemList
@onready var ship_info: Control = get_node("MarginContainer/VBoxContainer/MainContent/LeftPanel/ShipPanel/VBoxContainer/ShipInfo") as Control
@onready var phase_content: Control = get_node("MarginContainer/VBoxContainer/MainContent") as Control
@onready var next_phase_button: Button = get_node("MarginContainer/VBoxContainer/ButtonContainer/ActionButton") as Button
@onready var manage_crew_button: Button = get_node("MarginContainer/VBoxContainer/ButtonContainer/ManageCrewButton") as Button
@onready var save_button: Button = get_node("MarginContainer/VBoxContainer/ButtonContainer/SaveButton") as Button
@onready var load_button: Button = get_node("MarginContainer/VBoxContainer/ButtonContainer/LoadButton") as Button
@onready var quit_button: Button = get_node("MarginContainer/VBoxContainer/ButtonContainer/QuitButton") as Button
# @onready var phase_container = $PhaseContainer # This node doesn't exist in scene

var game_state: GameState
var phase_manager: Node
var current_phase_panel: FPCM_BasePhasePanel

# Manager references (from autoloads)
var alpha_manager: Node = null
var campaign_manager: Node = null

func _ready() -> void:
	# Load official Five Parsecs phase panel scenes
	print("CampaignDashboard: Loading phase panel scenes...")
	TravelPhasePanel = load("res://src/ui/screens/travel/TravelPhaseUI.tscn")
	WorldPhasePanel = load("res://src/ui/screens/world/WorldPhaseUI.tscn")
	PostBattlePhasePanel = load("res://src/ui/screens/postbattle/PostBattleSequence.tscn")
	# Note: Battle phase handled by BattlefieldCompanion, not dashboard panel
	print("CampaignDashboard: Phase panels loaded successfully")

	_initialize_managers()
	_connect_signals()
	_setup_campaign()
	_update_ui()

func _initialize_managers() -> void:
	"""Initialize manager references from autoloads"""
	alpha_manager = get_node("/root/FPCM_AlphaGameManager") if has_node("/root/FPCM_AlphaGameManager") else null
	campaign_manager = get_node("/root/CampaignManager") if has_node("/root/CampaignManager") else null

	# Use campaign manager if available, otherwise fall back to local implementation
	if campaign_manager:
		print("Using CampaignManager from autoload")
	else:
		# Fallback to autoload implementation
		game_state = get_node("/root/GameState")
		phase_manager = CampaignPhaseManagerScript.new()
		phase_manager.name = "PhaseManager"
		add_child(phase_manager)

func _connect_signals() -> void:
	# Connect to campaign manager signals if available
	if campaign_manager:
		if campaign_manager and campaign_manager.has_signal("campaign_updated"):
			var result1: Error = campaign_manager.campaign_updated.connect(_on_campaign_updated)
			assert(result1 == OK, "Failed to connect campaign_updated signal")
		if campaign_manager and campaign_manager.has_signal("phase_changed"):
			var result2: Error = campaign_manager.phase_changed.connect(_on_phase_changed)
			assert(result2 == OK, "Failed to connect phase_changed signal")

	# Connect to local phase manager if using fallback
	if phase_manager:
		if phase_manager and phase_manager.has_signal("phase_changed"):
			var result3: Error = phase_manager.phase_changed.connect(_on_phase_changed)
			assert(result3 == OK, "Failed to connect phase_changed signal")
		if phase_manager and phase_manager.has_signal("phase_completed"):
			var result4: Error = phase_manager.phase_completed.connect(_on_phase_completed)
			assert(result4 == OK, "Failed to connect phase_completed signal")
		if phase_manager and phase_manager.has_signal("phase_event_triggered"):
			var result5: Error = phase_manager.phase_event_triggered.connect(_on_phase_event)
			assert(result5 == OK, "Failed to connect phase_event_triggered signal")

	# Connect button signals with proper validation
	_connect_dashboard_buttons()

func _connect_dashboard_buttons() -> void:
	"""Connect dashboard button signals with validation"""
	if next_phase_button and next_phase_button and next_phase_button.has_method("connect"):
		if not next_phase_button.pressed.is_connected(_on_next_phase_pressed):
			next_phase_button.pressed.connect(_on_next_phase_pressed)
	else:
		push_warning("CampaignDashboard: Next phase button not found or invalid")

	if manage_crew_button and manage_crew_button and manage_crew_button.has_method("connect"):
		if not manage_crew_button.pressed.is_connected(_on_manage_crew_pressed):
			manage_crew_button.pressed.connect(_on_manage_crew_pressed)
	else:
		push_warning("CampaignDashboard: Manage crew button not found or invalid")

	if save_button and save_button and save_button.has_method("connect"):
		if not save_button.pressed.is_connected(_on_save_pressed):
			save_button.pressed.connect(_on_save_pressed)
	else:
		push_warning("CampaignDashboard: Save button not found or invalid")

	if load_button and load_button and load_button.has_method("connect"):
		if not load_button.pressed.is_connected(_on_load_pressed):
			load_button.pressed.connect(_on_load_pressed)
	else:
		push_warning("CampaignDashboard: Load button not found or invalid")

	if quit_button and quit_button and quit_button.has_method("connect"):
		if not quit_button.pressed.is_connected(_on_quit_pressed):
			quit_button.pressed.connect(_on_quit_pressed)
	else:
		push_warning("CampaignDashboard: Quit button not found or invalid")

func _setup_campaign() -> void:
	"""Setup campaign using manager or fallback"""
	if campaign_manager and campaign_manager.has_method("get_current_campaign"):
		# Use campaign manager
		var campaign_data: Dictionary = campaign_manager.get_current_campaign()
		if campaign_data:
			_load_campaign_data(campaign_data)
		else:
			print("No active campaign found")
	elif phase_manager:
		# Use local fallback
		if phase_manager.has_method("setup"):
			phase_manager.setup(game_state)
		if phase_manager.has_method("start_phase"):
			phase_manager.start_phase(safe_get_property(GlobalEnums, "FiveParsecsCampaignPhase").WORLD)

func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	_update_phase_ui(new_phase)
	_load_phase_content(new_phase)

func _on_phase_completed() -> void:
	if next_phase_button:
		next_phase_button.disabled = false

func _on_phase_event(_event: Dictionary) -> void:
	match _event.type:
		"UPKEEP_STARTED":
			_handle_upkeep_event(_event)
		"STORY_STARTED":
			_handle_story_event(_event)
		"CAMPAIGN_STARTED":
			_handle_campaign_event(_event)
		"BATTLE_SETUP_STARTED":
			_handle_battle_setup_event(_event)
		"BATTLE_RESOLUTION_STARTED":
			_handle_battle_resolution_event(_event)
		"ADVANCEMENT_STARTED":
			_handle_advancement_event(_event)
		"TRADE_STARTED":
			_handle_trade_event(_event)
		"END_PHASE_STARTED":
			_handle_end_phase_event(_event)

func _on_next_phase_pressed() -> void:
	if phase_manager:
		var next_phase: int = _get_next_phase(phase_manager.current_phase)
		if next_phase != safe_get_property(GlobalEnums, "FiveParsecsCampaignPhase").NONE:
			if phase_manager.has_method("start_phase"):
				phase_manager.start_phase(next_phase)
			if next_phase_button:
				next_phase_button.disabled = true

func _update_phase_ui(phase: int) -> void:
	if phase_label:
		var phase_names = ["SETUP", "TRAVEL", "WORLD", "BATTLE", "POST_BATTLE"]
		var phase_name = phase_names[phase] if phase >= 0 and phase < phase_names.size() else "UNKNOWN"
		phase_label.text = "Current Phase: " + phase_name
	if next_phase_button:
		var next_phase = _get_next_phase(phase)
		var phase_names = ["SETUP", "TRAVEL", "WORLD", "BATTLE", "POST_BATTLE"]
		var next_phase_name = phase_names[next_phase] if next_phase >= 0 and next_phase < phase_names.size() else "UNKNOWN"
		next_phase_button.text = "Next Phase: " + next_phase_name

func _update_ui() -> void:
	if not game_state or not game_state.campaign:
		return

	if credits_label:
		credits_label.text = "Credits: %d" % game_state.campaign.credits
	if story_points_label:
		story_points_label.text = "Story Points: %d" % game_state.campaign.story_points

	_update_crew_list()
	_update_ship_info()

func _update_crew_list() -> void:
	if not crew_list:
		return
	crew_list.clear()
	if not game_state or not game_state.campaign or not game_state.campaign.crew_members:
		crew_list.add_item("No Crew Members")
		return

	for member in game_state.campaign.crew_members:
		crew_list.add_item(member.character_name)

func _update_ship_info() -> void:
	if not ship_info:
		return
	if not game_state or not game_state.campaign or not game_state.campaign.ship:
		if ship_info is Label:
			ship_info.text = "No Ship Data"
		return

	if ship_info is Label:
		ship_info.text = str(game_state.campaign.ship)

func _load_phase_content(phase: int) -> void:
	if current_phase_panel:
		current_phase_panel.cleanup()
		current_phase_panel.queue_free()

	var panel: FPCM_BasePhasePanel = _create_phase_panel(phase)
	if panel:
		current_phase_panel = panel
		phase_content.add_child(panel)
		panel.setup(game_state, phase_manager)

func _create_phase_panel(phase: int) -> Control:
	"""Create UI panel for official Five Parsecs campaign phases"""
	# Get enum values safely
	var phase_enum = GlobalEnums.FiveParsecsCampaignPhase if GlobalEnums else null
	if not phase_enum:
		push_error("GlobalEnums not available")
		return null
	
	# Use direct integer comparisons instead of complex expressions
	if phase == 0: # SETUP
		# Use crew creation UI for setup phase
		push_warning("SETUP phase should use CrewCreationUI, not dashboard panel")
		return null
	elif phase == 1: # TRAVEL
		if TravelPhasePanel:
			return TravelPhasePanel.instantiate()
		else:
			push_warning("TravelPhasePanel not loaded")
			return null
	elif phase == 2: # WORLD
		if WorldPhasePanel:
			return WorldPhasePanel.instantiate()
		else:
			push_warning("WorldPhasePanel not loaded")
			return null
	elif phase == 3: # BATTLE
		# Battle phase handled by BattlefieldCompanion, not dashboard
		push_warning("BATTLE phase handled by BattlefieldCompanion system")
		return null
	elif phase == 4: # POST_BATTLE
		if PostBattlePhasePanel:
			return PostBattlePhasePanel.instantiate()
		else:
			push_warning("PostBattlePhasePanel not loaded")
			return null
	else:
		push_error("Unknown phase: %d. Using fallback." % phase)
		return null
func _get_next_phase(current: int) -> int:
	"""Get next phase in official Four-Phase Campaign Turn structure"""
	# Use direct integer comparisons for phase transitions
	if current == 0: # SETUP
		return 1 # TRAVEL
	elif current == 1: # TRAVEL
		return 2 # WORLD
	elif current == 2: # WORLD
		return 3 # BATTLE
	elif current == 3: # BATTLE
		return 4 # POST_BATTLE
	elif current == 4: # POST_BATTLE
		# Complete campaign turn - return to Travel for next turn
		return 1 # TRAVEL
	else:
		push_error("Unknown phase: %d. Defaulting to TRAVEL" % current)
		return 1 # TRAVEL

# Event Handlers
func _handle_upkeep_event(_event: Dictionary) -> void:
	_update_ui()

func _handle_story_event(_event: Dictionary) -> void:
	_update_ui()

func _handle_campaign_event(_event: Dictionary) -> void:
	_update_ui()

func _handle_battle_setup_event(_event: Dictionary) -> void:
	_update_ui()

func _handle_battle_resolution_event(_event: Dictionary) -> void:
	_update_ui()

func _handle_advancement_event(_event: Dictionary) -> void:
	_update_ui()

func _handle_trade_event(_event: Dictionary) -> void:
	_update_ui()

func _handle_end_phase_event(_event: Dictionary) -> void:
	_update_ui()

# Button Event Handlers

func _on_manage_crew_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/crew/CrewManagement.tscn")

func _on_save_pressed() -> void:
	game_state.save_campaign()

func _on_load_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/campaign/LoadCampaign.tscn")

func _on_quit_pressed() -> void:
	if campaign_manager and campaign_manager.has_method("save_current_campaign"):
		campaign_manager.save_current_campaign()
	elif game_state:
		if game_state and game_state.has_method("end_campaign"):
			game_state.end_campaign()
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/MainMenu.tscn")

func _on_campaign_updated() -> void:
	"""Handle campaign data updates from campaign manager"""
	_update_ui()

func _load_campaign_data(campaign_data: Variant) -> void:
	"""Load campaign data from manager"""
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	if campaign_data:
		print("Loading campaign data: ", campaign_data)
		# TODO: Update UI with campaign data
		_update_ui()

func setup_phase(campaign_data: Resource) -> void:
	"""Called by MainGameScene when this phase is activated"""
	if campaign_data:
		_load_campaign_data(campaign_data)

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null

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