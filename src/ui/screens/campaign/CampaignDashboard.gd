# Campaign Dashboard UI - Simplified (Framework Bible Compliant)
# Reads directly from GameStateManager - no duplicate state management
class_name FPCM_CampaignDashboardUI
extends Control

# Safe imports - removed BaseCampaignDashboardSystem (overengineered abstraction)
const FPCM_BasePhasePanel = preload("res://src/ui/screens/campaign/phases/BasePhasePanel.gd")

# Official Five Parsecs Phase Panels - following Four-Phase structure
var TravelPhasePanel: PackedScene = null
var WorldPhasePanel: PackedScene = null
var BattlePhasePanel: PackedScene = null
var PostBattlePhasePanel: PackedScene = null

# UI Node References using safe access
@onready var phase_label: Label = get_node("MarginContainer/VBoxContainer/HeaderPanel/GridContainer/PhaseLabel") as Label
@onready var credits_label: Label = get_node("MarginContainer/VBoxContainer/HeaderPanel/GridContainer/CreditsLabel") as Label
@onready var story_points_label: Label = get_node("MarginContainer/VBoxContainer/HeaderPanel/GridContainer/StoryPointsLabel") as Label
@onready var patrons_label: Label = get_node("MarginContainer/VBoxContainer/HeaderPanel/GridContainer/PatronsLabel") as Label
@onready var rivals_label: Label = get_node("MarginContainer/VBoxContainer/HeaderPanel/GridContainer/RivalsLabel") as Label
@onready var rumors_label: Label = get_node("MarginContainer/VBoxContainer/HeaderPanel/GridContainer/RumorsLabel") as Label
@onready var crew_list: ItemList = get_node("MarginContainer/VBoxContainer/MainContent/LeftPanel/CrewPanel/VBoxContainer/CrewList") as ItemList
@onready var ship_info: Control = get_node("MarginContainer/VBoxContainer/MainContent/LeftPanel/ShipPanel/VBoxContainer/ShipInfo") as Control
@onready var phase_content: Control = get_node("MarginContainer/VBoxContainer/MainContent") as Control
@onready var next_phase_button: Button = get_node("MarginContainer/VBoxContainer/ButtonContainer/ActionButton") as Button
@onready var manage_crew_button: Button = get_node("MarginContainer/VBoxContainer/ButtonContainer/ManageCrewButton") as Button
@onready var save_button: Button = get_node("MarginContainer/VBoxContainer/ButtonContainer/SaveButton") as Button
@onready var load_button: Button = get_node("MarginContainer/VBoxContainer/ButtonContainer/LoadButton") as Button
@onready var quit_button: Button = get_node("MarginContainer/VBoxContainer/ButtonContainer/QuitButton") as Button

# Current phase panel instance
var current_phase_panel: FPCM_BasePhasePanel

# Developer panel variables
var developer_panel: Control
var developer_mode: bool = false

func _ready() -> void:
	print("CampaignDashboard: Initializing (simplified - reads from GameStateManager directly)")

	# Load official Five Parsecs phase panel scenes
	TravelPhasePanel = load("res://src/ui/screens/travel/TravelPhaseUI.tscn")
	WorldPhasePanel = load("res://src/ui/screens/world/WorldPhaseController.tscn")
	PostBattlePhasePanel = load("res://src/ui/screens/postbattle/PostBattleSequence.tscn")

	_connect_dashboard_buttons()
	_update_ui()
	_setup_button_icons()

	# Setup developer panel for quick testing
	_setup_developer_panel()

	print("CampaignDashboard: Ready - displaying campaign from GameStateManager")

func _connect_dashboard_buttons() -> void:
	"""Connect dashboard button signals with validation"""
	if next_phase_button:
		next_phase_button.pressed.connect(_on_next_phase_pressed)
	if manage_crew_button:
		manage_crew_button.pressed.connect(_on_manage_crew_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

## SIMPLIFIED UI UPDATE - Reads directly from GameStateManager

func _update_ui() -> void:
	"""Update all UI elements from GameStateManager (single source of truth)"""
	if not GameStateManager:
		push_error("CampaignDashboard: GameStateManager not available!")
		return

	# Update credits display
	if credits_label:
		var credits: int = GameStateManager.get_credits()
		credits_label.text = "Credits: %d" % credits
		# Color-code credits based on threshold
		if credits < 100:
			credits_label.modulate = Color(1.0, 0.5, 0.5)  # Red - low funds
		elif credits < 500:
			credits_label.modulate = Color(1.0, 1.0, 0.5)  # Yellow - moderate
		else:
			credits_label.modulate = Color(0.5, 1.0, 0.5)  # Green - healthy

	# Update story points display
	if story_points_label:
		var story_points: int = GameStateManager.get_story_progress()
		story_points_label.text = "Story Points: %d" % story_points
		# Color-code story points to show progress
		if story_points == 0:
			story_points_label.modulate = Color(0.8, 0.8, 0.8)  # Gray - no progress
		elif story_points < 5:
			story_points_label.modulate = Color(1.0, 1.0, 0.5)  # Yellow - some progress
		else:
			story_points_label.modulate = Color(0.5, 1.0, 0.5)  # Green - good progress

	# Update patrons display (from character creation or campaign events)
	if patrons_label:
		var patrons: Array = GameStateManager.get_patrons()
		patrons_label.text = "Patrons: %d" % patrons.size()
		# Color-code based on patron count
		if patrons.size() == 0:
			patrons_label.modulate = Color(0.8, 0.8, 0.8)  # Gray - none
		else:
			patrons_label.modulate = Color(0.5, 1.0, 0.5)  # Green - have patrons

	# Update rivals display (from character creation or campaign events)
	if rivals_label:
		var rivals: Array = GameStateManager.get_rivals()
		rivals_label.text = "Rivals: %d" % rivals.size()
		# Color-code based on rival threat level
		if rivals.size() == 0:
			rivals_label.modulate = Color(0.5, 1.0, 0.5)  # Green - no threats
		elif rivals.size() < 3:
			rivals_label.modulate = Color(1.0, 1.0, 0.5)  # Yellow - some rivals
		else:
			rivals_label.modulate = Color(1.0, 0.5, 0.5)  # Red - many enemies

	# Update quest rumors display (from character creation or campaign events)
	if rumors_label:
		var rumors: int = GameStateManager.get_quest_rumors()
		rumors_label.text = "Quest Rumors: %d" % rumors
		# Color-code based on available rumors
		if rumors == 0:
			rumors_label.modulate = Color(0.8, 0.8, 0.8)  # Gray - no leads
		else:
			rumors_label.modulate = Color(0.5, 1.0, 0.5)  # Green - have opportunities

	# Update phase display
	if phase_label:
		var current_phase: int = GameStateManager.get_campaign_phase()
		var phase_name: String = _get_phase_name(current_phase)
		var phase_text: String = "Current Phase: %s" % phase_name

		# Add warnings for critical situations
		var warnings: Array[String] = []
		var credits: int = GameStateManager.get_credits()
		if credits < 50:
			warnings.append("⚠️ LOW FUNDS")
		var crew_size: int = GameStateManager.get_crew_size()
		if crew_size < 4:
			warnings.append("⚠️ UNDERSTAFFED")

		if warnings.size() > 0:
			phase_text += " | " + " ".join(warnings)
			phase_label.modulate = Color(1.0, 1.0, 0.5)  # Yellow for warnings
		else:
			phase_label.modulate = Color(1.0, 1.0, 1.0)  # White - normal

		phase_label.text = phase_text

	_update_crew_list()
	_update_ship_info()

func _update_crew_list() -> void:
	"""Update crew list from GameStateManager"""
	print("CampaignDashboard._update_crew_list() called")

	if not crew_list:
		print("  crew_list node not found!")
		return
	crew_list.clear()

	if not GameStateManager:
		print("  GameStateManager not available!")
		crew_list.add_item("GameStateManager not available")
		return

	print("  Calling GameStateManager.get_crew_members()")
	var crew_members: Array = GameStateManager.get_crew_members()
	print("  Received %d crew members from GameStateManager" % crew_members.size())

	if crew_members.is_empty():
		print("  Crew members array is EMPTY - displaying 'No Crew Members'")
		crew_list.add_item("No Crew Members")
		return

	# Add crew members with status indicators
	var active_count: int = 0
	var injured_count: int = 0
	var dead_count: int = 0

	for member in crew_members:
		var status_icon: String = "✅"
		var status: String = member.get("status", "ACTIVE")

		match status:
			"ACTIVE":
				status_icon = "✅"
				active_count += 1
			"INJURED":
				status_icon = "🩹"
				injured_count += 1
			"DEAD":
				status_icon = "💀"
				dead_count += 1
			_:
				status_icon = "❓"

		var member_name: String = member.get("character_name", "Unknown")
		crew_list.add_item("%s %s" % [status_icon, member_name])

	# Add crew status summary at the top
	if crew_list.item_count > 0:
		var summary: String = "Crew Status: %d Active" % active_count
		if injured_count > 0:
			summary += ", %d Injured" % injured_count
		if dead_count > 0:
			summary += ", %d Dead" % dead_count

		crew_list.add_item(summary, null, false)  # Non-selectable separator
		crew_list.move_item(crew_list.item_count - 1, 0)  # Move to top

func _update_ship_info() -> void:
	"""Update ship info from GameStateManager"""
	if not ship_info:
		return

	if not GameStateManager:
		if ship_info is Label:
			ship_info.text = "GameStateManager not available"
		return

	var ship = GameStateManager.get_player_ship()
	if not ship or (ship is Dictionary and ship.is_empty()):
		if ship_info is Label:
			ship_info.text = "No Ship Data"
			ship_info.modulate = Color(1.0, 0.5, 0.5)  # Red for missing data
		return

	if ship_info is Label:
		var ship_name: String = ship.get("name", "Unknown Ship")
		var hull: int = ship.get("hull_integrity", 100)
		var fuel: int = ship.get("fuel", 100)

		# Build ship status display with indicators
		var ship_text: String = "%s\n" % ship_name

		# Hull status
		var hull_icon: String = "🛡️"
		if hull < 30:
			hull_icon = "⚠️"
			ship_info.modulate = Color(1.0, 0.5, 0.5)  # Red - critical
		elif hull < 60:
			hull_icon = "⚠️"
			ship_info.modulate = Color(1.0, 1.0, 0.5)  # Yellow - damaged
		else:
			ship_info.modulate = Color(0.5, 1.0, 0.5)  # Green - healthy

		ship_text += "%s Hull: %d%%\n" % [hull_icon, hull]

		# Fuel status
		var fuel_icon: String = "⛽"
		if fuel < 20:
			fuel_icon = "⚠️"
		ship_text += "%s Fuel: %d%%" % [fuel_icon, fuel]

		ship_info.text = ship_text

## Helper methods

func _get_phase_name(phase: int) -> String:
	"""Get human-readable phase name"""
	match phase:
		0: return "Setup"
		1: return "Travel"
		2: return "World"
		3: return "Battle"
		4: return "Post-Battle"
		_: return "Unknown"

## Button Event Handlers

func _on_next_phase_pressed() -> void:
	"""Advance to next campaign phase"""
	if not next_phase_button:
		return

	# Navigate to World Phase
	print("CampaignDashboard: Navigating to World Phase...")
	if SceneRouter and SceneRouter.has_method("navigate_to"):
		SceneRouter.navigate_to("world_phase")
	else:
		push_error("CampaignDashboard: SceneRouter not available")

func _on_manage_crew_pressed() -> void:
	# Verify scene tree exists
	if not get_tree():
		push_error("CampaignDashboard: Scene tree not available")
		return

	# Navigate to new CrewManagementScreen
	print("CampaignDashboard: Navigating to Crew Management...")
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/crew/CrewManagementScreen.tscn")

func _on_save_pressed() -> void:
	if GameState and GameState.has_method("save_game"):
		var success: bool = GameState.save_game("current_campaign", true)
		if success:
			print("CampaignDashboard: Campaign saved successfully")
		else:
			push_warning("CampaignDashboard: Save failed - operation may be queued")
	else:
		push_warning("CampaignDashboard: GameState not available")

func _on_load_pressed() -> void:
	if SceneRouter and SceneRouter.has_method("navigate_to"):
		SceneRouter.navigate_to("load_campaign")
	else:
		get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/campaign/LoadCampaign.tscn")

func _on_quit_pressed() -> void:
	# Verify scene tree exists
	if not get_tree():
		push_error("CampaignDashboard: Scene tree not available")
		return

	# Save before quitting
	if GameState and GameState.has_method("save_game"):
		GameState.save_game("current_campaign", true)
		print("CampaignDashboard: Auto-saved before quit")

	if SceneRouter and SceneRouter.has_method("navigate_to"):
		SceneRouter.navigate_to("main_menu")
	else:
		get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/mainmenu/MainMenu.tscn")

## Setup button icons for enhanced UI visual hierarchy
func _setup_button_icons() -> void:
	"""Setup icons for dashboard buttons to improve visual clarity and user experience"""
	# Phase 1: Core Dashboard Icons Integration
	
	# Manage Crew Button - icon_manage_crew.svg
	if manage_crew_button:
		manage_crew_button.icon = preload("res://assets/basic icons/icon_manage_crew.svg")
		manage_crew_button.expand_icon = true
		manage_crew_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		print("CampaignDashboard: Manage crew icon applied successfully")
	else:
		push_warning("CampaignDashboard: Manage crew button not found for icon assignment")
	
	# Save Campaign Button - icon_save_campaign.svg
	if save_button:
		save_button.icon = preload("res://assets/basic icons/icon_save_campaign.svg")
		save_button.expand_icon = true
		save_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		print("CampaignDashboard: Save campaign icon applied successfully")
	else:
		push_warning("CampaignDashboard: Save button not found for icon assignment")

## DEVELOPER PANEL INTEGRATION - Quick testing from dashboard

func _setup_developer_panel() -> void:
	"""Setup developer quick start panel if in debug mode"""
	developer_mode = OS.is_debug_build()
	if not developer_mode:
		return

	print("CampaignDashboard: Setting up developer panel for quick testing...")

	# Load and instantiate developer panel with safety checks
	var dev_scene_path: String = "res://src/ui/debug/DeveloperQuickStart.tscn"

	# Check if scene file exists first
	if not FileAccess.file_exists(dev_scene_path):
		print("CampaignDashboard: Developer panel scene file not found: " + dev_scene_path)
		return

	@warning_ignore("untyped_declaration")
	var developer_scene = load(dev_scene_path)

	if developer_scene:
		@warning_ignore("unsafe_method_access")
		developer_panel = developer_scene.instantiate()
		if developer_panel:
			developer_panel.hide() # Start hidden
			self.add_child(developer_panel)
			_connect_developer_signals()
			print("CampaignDashboard: Developer panel ready - press F11 to toggle")
		else:
			push_error("CampaignDashboard: Failed to instantiate developer panel")
	else:
		print("CampaignDashboard: Failed to load developer panel scene: " + dev_scene_path)

func _connect_developer_signals() -> void:
	"""Connect signals from developer panel"""
	if not developer_panel or not developer_panel.has_signal("test_campaign_requested"):
		return

	# Connect to test campaign creation signal
	@warning_ignore("return_value_discarded")
	developer_panel.test_campaign_requested.connect(_on_developer_test_campaign)

func _on_developer_test_campaign(campaign_data: Variant) -> void:
	"""Handle test campaign request from developer panel - refresh dashboard"""
	var campaign_name: String = ""
	if campaign_data is Dictionary:
		campaign_name = campaign_data.get("name", "Unknown")
	elif campaign_data is String:
		campaign_name = campaign_data
	else:
		campaign_name = str(campaign_data)

	print("CampaignDashboard: Test campaign created (%s) - refreshing dashboard..." % campaign_name)

	# Hide developer panel
	if developer_panel:
		developer_panel.hide()

	# Refresh the dashboard UI to show new campaign data
	_update_ui()

	print("CampaignDashboard: Dashboard refreshed with new test campaign data")

func _input(event: InputEvent) -> void:
	"""Handle developer panel hotkey"""
	if not developer_mode:
		return

	# Toggle developer panel with F11
	@warning_ignore("unsafe_property_access")
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		if developer_panel:
			_toggle_developer_panel()

func _toggle_developer_panel() -> void:
	"""Toggle developer panel visibility"""
	if not developer_panel:
		return

	if developer_panel.visible:
		developer_panel.hide()
		print("CampaignDashboard: Developer panel hidden")
	else:
		developer_panel.show()
		print("CampaignDashboard: Developer panel shown")
