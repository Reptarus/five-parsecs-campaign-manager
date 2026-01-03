# Campaign Dashboard UI - Simplified (Framework Bible Compliant)
# Reads directly from GameStateManager - no duplicate state management
class_name FPCM_CampaignDashboardUI
extends Control

# Safe imports - removed BaseCampaignDashboardSystem (overengineered abstraction)
const FPCM_BasePhasePanel = preload("res://src/ui/screens/campaign/phases/BasePhasePanel.gd")

# Character display component
const CharacterCardScene = preload("res://src/ui/components/character/CharacterCard.tscn")
const Character = preload("res://src/core/character/Character.gd")

# Story Point spending dialog (Core Rules p.67 - Story Points)
const StoryPointDialogScene = preload("res://src/ui/components/story/StoryPointSpendingDialog.tscn")

# Official Five Parsecs Phase Panels - following Four-Phase structure
var TravelPhasePanel: PackedScene = null
var WorldPhasePanel: PackedScene = null
var BattlePhasePanel: PackedScene = null
var PostBattlePhasePanel: PackedScene = null

# UI Node References - using %NodeName for maintainability
@onready var phase_label: Label = %PhaseLabel
@onready var credits_label: Label = %CreditsLabel
@onready var story_points_label: Label = %StoryPointsLabel
@onready var patrons_label: Label = %PatronsLabel
@onready var rivals_label: Label = %RivalsLabel
@onready var rumors_label: Label = %RumorsLabel
@onready var pending_events_label: Label = %PendingEventsLabel
@onready var campaign_progress_tracker: HBoxContainer = %CampaignProgressTracker
@onready var crew_scroll_container: ScrollContainer = %CrewScrollContainer
@onready var crew_card_container: Container = %CrewCardContainer
@onready var ship_info: Label = %ShipInfo
# WorldInfo label - may not exist if WorldStatusCard is used instead
@onready var world_info_label: Label = get_node_or_null("%WorldInfo")
@onready var quest_info_label: Label = get_node_or_null("MarginContainer/VBoxContainer/MainContent/RightPanel/QuestPanel/VBoxContainer/QuestInfo")
@onready var patron_list: ItemList = %PatronList
@onready var rival_list: ItemList = %RivalList
@onready var phase_content: Control = get_node("MarginContainer/VBoxContainer/MainContent") as Control
# Legacy buttons - use get_node_or_null since these may not exist in scene
@onready var next_phase_button: Button = get_node_or_null("%ActionButton")
@onready var manage_crew_button: Button = get_node_or_null("%ManageCrewButton")
@onready var save_button: Button = get_node_or_null("%SaveButton")
@onready var load_button: Button = get_node_or_null("%LoadButton")
@onready var quit_button: Button = get_node_or_null("%QuitButton")

# Battle History UI elements
@onready var battle_history_list: VBoxContainer = %BattleHistoryList
@onready var resume_battle_button: Button = %ResumeBattleButton
@onready var current_battle_status: Label = %CurrentBattleStatus

# Victory Progress UI
@onready var victory_progress_panel = %VictoryProgressPanel

# Quick Actions Footer (bottom toolbar)
@onready var quick_actions_footer = %QuickActionsFooter

# Sub-component cards for data display
@onready var mission_status_card = %MissionStatusCard
@onready var story_track_section = %StoryTrackSection
@onready var world_status_card = %WorldStatusCard

# Autoload reference (helps static analyzer)
@onready var _responsive_manager: Node = get_node("/root/ResponsiveManager")

# Current phase panel instance
var current_phase_panel: FPCM_BasePhasePanel

# Battle history data
var battle_history: Array = []

# CharacterCard pool for performance (reuse instead of recreate)
var _character_card_pool: Array[Control] = []
var _current_viewport_width: int = 0

# Campaign phase names for progress tracker
const PHASE_NAMES: Array[String] = ["Travel", "World", "Battle", "Post-Battle"]

# Developer panel variables
var developer_panel: Control
var developer_mode: bool = false

# Story Point spending dialog instance
var story_point_dialog: Window = null

func _ready() -> void:
	print("CampaignDashboard: Initializing (simplified - reads from GameStateManager directly)")

	# Load official Five Parsecs phase panel scenes
	TravelPhasePanel = load("res://src/ui/screens/travel/TravelPhaseUI.tscn")
	WorldPhasePanel = load("res://src/ui/screens/world/WorldPhaseController.tscn")
	PostBattlePhasePanel = load("res://src/ui/screens/postbattle/PostBattleSequence.tscn")

	_connect_dashboard_buttons()
	_connect_quick_actions_footer()
	_connect_component_signals()
	_hide_legacy_buttons()
	_apply_glass_style_to_panels()
	_setup_campaign_progress_tracker()
	_setup_responsive_crew_container()
	_update_ui()
	_setup_button_icons()

	# Setup developer panel for quick testing
	_setup_developer_panel()

	# Setup Story Point spending dialog
	_setup_story_point_dialog()

	# Connect to ResponsiveManager for centralized breakpoint management
	_responsive_manager.breakpoint_changed.connect(_on_responsive_breakpoint_changed)
	# Initialize with current breakpoint
	_apply_responsive_layout(_responsive_manager.current_breakpoint)

	# Track viewport size for responsive updates (legacy support)
	get_viewport().size_changed.connect(_on_viewport_resized)

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
	if resume_battle_button:
		resume_battle_button.pressed.connect(_on_resume_battle_pressed)

func _connect_quick_actions_footer() -> void:
	"""Connect QuickActionsFooter signals to dashboard handlers"""
	if not quick_actions_footer:
		push_warning("CampaignDashboard: QuickActionsFooter not found")
		return

	quick_actions_footer.save_pressed.connect(_on_save_pressed)
	quick_actions_footer.characters_pressed.connect(_on_manage_crew_pressed)
	quick_actions_footer.ship_pressed.connect(_on_ship_info_pressed)
	quick_actions_footer.trading_pressed.connect(_on_trading_pressed)
	quick_actions_footer.world_pressed.connect(_on_world_pressed)
	quick_actions_footer.settings_pressed.connect(_on_settings_pressed)
	print("CampaignDashboard: QuickActionsFooter signals connected")

func _connect_component_signals() -> void:
	"""Connect signals from sub-component cards for navigation"""
	# MissionStatusCard - click to view mission details
	if mission_status_card and mission_status_card.has_signal("mission_details_requested"):
		mission_status_card.mission_details_requested.connect(_on_mission_details_requested)
		print("CampaignDashboard: MissionStatusCard signal connected")
	
	# WorldStatusCard - click to view world details
	if world_status_card and world_status_card.has_signal("world_details_requested"):
		world_status_card.world_details_requested.connect(_on_world_details_requested)
		print("CampaignDashboard: WorldStatusCard signal connected")
	
	# StoryTrackSection - click to view story/quest details
	if story_track_section and story_track_section.has_signal("story_details_requested"):
		story_track_section.story_details_requested.connect(_on_story_details_requested)
		print("CampaignDashboard: StoryTrackSection signal connected")
	
	# VictoryProgressPanel - connect if it has signals
	if victory_progress_panel and victory_progress_panel.has_signal("victory_details_requested"):
		victory_progress_panel.victory_details_requested.connect(_on_victory_details_requested)
		print("CampaignDashboard: VictoryProgressPanel signal connected")

func _hide_legacy_buttons() -> void:
	"""Hide old header buttons - replaced by QuickActionsFooter (kept for rollback)"""
	if save_button:
		save_button.visible = false
	if manage_crew_button:
		manage_crew_button.visible = false
	if load_button:
		load_button.visible = false
	if quit_button:
		quit_button.visible = false

func _apply_glass_style_to_panels() -> void:
	"""Apply glass morphism style to legacy PanelContainers"""
	var panels := [
		"MarginContainer/VBoxContainer/MainContent/LeftPanel/CrewPanel",
		"MarginContainer/VBoxContainer/MainContent/LeftPanel/ShipPanel",
		"MarginContainer/VBoxContainer/MainContent/LeftPanel/BattleHistoryPanel",
		"MarginContainer/VBoxContainer/MainContent/RightPanel/QuestPanel",
		"MarginContainer/VBoxContainer/MainContent/RightPanel/PatronPanel",
		"MarginContainer/VBoxContainer/MainContent/RightPanel/RivalPanel"
	]

	for panel_path in panels:
		var panel := get_node_or_null(panel_path) as PanelContainer
		if panel:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.145, 0.161, 0.259, 0.8)  # COLOR_ELEVATED with alpha
			style.border_color = Color(0.227, 0.227, 0.361, 0.5)  # COLOR_BORDER
			style.set_border_width_all(1)
			style.set_corner_radius_all(12)
			panel.add_theme_stylebox_override("panel", style)

## SIMPLIFIED UI UPDATE - Reads directly from GameStateManager

func _update_ui() -> void:
	"""Update all UI elements from GameStateManager (single source of truth)"""
	if not GameStateManager:
		push_error("CampaignDashboard: GameStateManager not available!")
		return

	# Update credits display (compact format)
	if credits_label:
		var credits: int = GameStateManager.get_credits()
		credits_label.text = "%d cr" % credits
		# Color-code credits based on threshold
		if credits < 100:
			credits_label.modulate = Color(1.0, 0.5, 0.5)  # Red - low funds
		elif credits < 500:
			credits_label.modulate = Color(1.0, 1.0, 0.5)  # Yellow - moderate
		else:
			credits_label.modulate = Color(0.5, 1.0, 0.5)  # Green - healthy

	# Update story points display (compact format)
	if story_points_label:
		var story_points: int = GameStateManager.get_story_progress()
		story_points_label.text = "%d SP" % story_points
		# Color-code story points to show progress
		if story_points == 0:
			story_points_label.modulate = Color(0.8, 0.8, 0.8)  # Gray - no progress
		elif story_points < 5:
			story_points_label.modulate = Color(1.0, 1.0, 0.5)  # Yellow - some progress
		else:
			story_points_label.modulate = Color(0.5, 1.0, 0.5)  # Green - good progress

	# Update patrons display (compact format with icon)
	if patrons_label:
		var patrons: Array = GameStateManager.get_patrons()
		patrons_label.text = "👤 %dP" % patrons.size()
		# Color-code based on patron count
		if patrons.size() == 0:
			patrons_label.modulate = Color(0.8, 0.8, 0.8)  # Gray - none
		else:
			patrons_label.modulate = Color(0.5, 1.0, 0.5)  # Green - have patrons

	# Update rivals display (compact format with icon)
	if rivals_label:
		var rivals: Array = GameStateManager.get_rivals()
		rivals_label.text = "⚔️ %dR" % rivals.size()
		# Color-code based on rival threat level
		if rivals.size() == 0:
			rivals_label.modulate = Color(0.5, 1.0, 0.5)  # Green - no threats
		elif rivals.size() < 3:
			rivals_label.modulate = Color(1.0, 1.0, 0.5)  # Yellow - some rivals
		else:
			rivals_label.modulate = Color(1.0, 0.5, 0.5)  # Red - many enemies

	# Update quest rumors display (compact format with icon)
	if rumors_label:
		var rumors: int = GameStateManager.get_quest_rumors()
		rumors_label.text = "📜 %dQ" % rumors
		# Color-code based on available rumors
		if rumors == 0:
			rumors_label.modulate = Color(0.8, 0.8, 0.8)  # Gray - no leads
		else:
			rumors_label.modulate = Color(0.5, 1.0, 0.5)  # Green - have opportunities

	# Update pending deferred events display (compact format with icon)
	if pending_events_label:
		var pending_events: Array = GameStateManager.get_pending_events()
		var active_count: int = 0
		for event in pending_events:
			if not event.get("consumed", false):
				active_count += 1
		pending_events_label.text = "📋 %d Events" % active_count
		# Color-code based on pending events
		if active_count == 0:
			pending_events_label.modulate = Color(0.8, 0.8, 0.8)  # Gray - none
		else:
			pending_events_label.modulate = Color(0.5, 0.8, 1.0)  # Blue - has events

	# Update phase display with turn number
	if phase_label:
		var current_phase: int = GameStateManager.get_campaign_phase()
		var phase_name: String = _get_phase_name(current_phase)
		var turn_number: int = GameStateManager.get_campaign_turn() if GameStateManager.has_method("get_campaign_turn") else 1
		var phase_text: String = "Turn %d: %s" % [turn_number, phase_name]

		# Add warnings for critical situations
		var warnings: Array[String] = []
		var credits: int = GameStateManager.get_credits()
		if credits < 50:
			warnings.append("⚠️ LOW FUNDS")
		var crew_size: int = GameStateManager.get_crew_size()
		if crew_size < 4:
			warnings.append("⚠️ UNDERSTAFFED")

		# Add warnings for deferred events
		var battle_events = GameStateManager.get_pending_events_by_trigger("THIS_BATTLE")
		if battle_events.size() > 0:
			warnings.append("⚔️ %d BATTLE OBJECTIVES" % battle_events.size())
		var turn_events = GameStateManager.get_pending_events_by_trigger("NEXT_TURN")
		if turn_events.size() > 0:
			warnings.append("⏰ %d TURN EVENTS" % turn_events.size())

		if warnings.size() > 0:
			phase_text += " | " + " ".join(warnings)
			phase_label.modulate = Color(1.0, 1.0, 0.5)  # Yellow for warnings
		else:
			phase_label.modulate = Color(1.0, 1.0, 1.0)  # White - normal

		phase_label.text = phase_text

	_update_campaign_progress_tracker()
	_update_crew_list()
	_update_ship_info()
	_update_world_info()
	_update_quest_info()
	_update_patron_list()
	_update_rival_list()
	_update_battle_history()
	_update_action_button()

	# Update victory progress display
	if victory_progress_panel and victory_progress_panel.has_method("update_display"):
		victory_progress_panel.update_display()

	# Update sub-component cards with data from GameStateManager
	_update_mission_status()
	_update_story_track()
	_update_world_status()

func _update_crew_list() -> void:
	"""Update crew display using CharacterCard components with responsive layout"""
	print("CampaignDashboard._update_crew_list() called")

	if not crew_card_container:
		print("  crew_card_container node not found!")
		return

	# Clear existing cards (return to pool for reuse)
	for child in crew_card_container.get_children():
		child.hide()
		if child not in _character_card_pool:
			_character_card_pool.append(child)

	if not GameStateManager:
		print("  GameStateManager not available!")
		var error_label := Label.new()
		error_label.text = "GameStateManager not available"
		error_label.modulate = Color.RED
		crew_card_container.add_child(error_label)
		return

	print("  Calling GameStateManager.get_crew_members()")
	var crew_members: Array = GameStateManager.get_crew_members()
	print("  Received %d crew members from GameStateManager" % crew_members.size())

	if crew_members.is_empty():
		print("  Crew members array is EMPTY - displaying 'No Crew Members'")
		var empty_label := Label.new()
		empty_label.text = "No Crew Members"
		empty_label.modulate = Color(0.7, 0.7, 0.7)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		crew_card_container.add_child(empty_label)
		return

	# Determine variant based on viewport width
	var viewport := get_viewport()
	if not viewport:
		push_warning("CampaignDashboard: Viewport not available for crew list")
		return
	var viewport_width := viewport.get_visible_rect().size.x
	# CardVariant values are pixel heights: COMPACT=80, STANDARD=180
	var card_variant: int = 80 if viewport_width < 768 else 180

	# Create/reuse CharacterCard for each crew member
	# Sprint 26.3: Character-Everywhere - crew members are always Character objects
	for i in range(crew_members.size()):
		var character: Character = crew_members[i] as Character
		if not character:
			push_warning("CampaignDashboard: Invalid crew member at index %d" % i)
			continue

		# Get card from pool or create new
		var character_card: Control = null
		if i < _character_card_pool.size():
			character_card = _character_card_pool[i]
			character_card.show()
			if character_card.get_parent() != crew_card_container:
				crew_card_container.add_child(character_card)
		else:
			character_card = CharacterCardScene.instantiate()
			crew_card_container.add_child(character_card)
			_character_card_pool.append(character_card)
			
			# Connect signals (only for new cards)
			if character_card.has_signal("card_tapped"):
				character_card.card_tapped.connect(_on_character_card_tapped.bind(character))
			if character_card.has_signal("view_details_pressed"):
				character_card.view_details_pressed.connect(_on_character_view_details.bind(character))

		# Set character data and variant
		if character_card.has_method("set_character"):
			character_card.set_character(character)
		if character_card.has_method("set_variant"):
			character_card.set_variant(card_variant)

	print("  Created/updated %d CharacterCards" % crew_members.size())

func _on_character_card_tapped(character: Character) -> void:
	"""Handle character card tap - navigate to character details"""
	if not character:
		return
	print("CampaignDashboard: Character card tapped: %s" % character.character_name)
	_navigate_to_character_details(character)

func _on_character_view_details(character: Character) -> void:
	"""Handle view details button press"""
	if not character:
		return
	print("CampaignDashboard: View details pressed for: %s" % character.character_name)
	_navigate_to_character_details(character)

func _navigate_to_character_details(character: Character) -> void:
	"""Navigate to character details screen"""
	# Store selected character for details screen
	if GameStateManager:
		GameStateManager.set_temp_data("selected_character", character)
		GameStateManager.set_temp_data("return_screen", "campaign_dashboard")

	# Navigate to character details
	if get_tree():
		get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/character/CharacterDetailsScreen.tscn")

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
		ship_text += "%s Fuel: %d%%\n" % [fuel_icon, fuel]

		# Ship debt status
		var debt: int = ship.get("debt", 0)
		if debt > 0:
			var debt_icon: String = "💰"
			if debt > 1000:
				debt_icon = "⚠️"
				ship_info.modulate = Color(1.0, 0.5, 0.5)  # Red - high debt
			ship_text += "%s Debt: %d cr" % [debt_icon, debt]
		else:
			ship_text = ship_text.trim_suffix("\n")  # Remove trailing newline if no debt

		ship_info.text = ship_text

func _update_world_info() -> void:
	"""Update world/planet info from GameStateManager"""
	if not world_info_label:
		return

	if not GameStateManager:
		world_info_label.text = "GameStateManager not available"
		return

	# Get current planet from game state
	var game_state = GameStateManager.game_state
	if not game_state or not "current_campaign" in game_state:
		world_info_label.text = "No Campaign Data"
		world_info_label.modulate = Color(0.8, 0.8, 0.8)
		return

	# Get current location from GameState (not campaign dict)
	var current_location: Dictionary = {}
	if GameStateManager.has_method("get_current_location"):
		current_location = GameStateManager.get_current_location()

	# Fallback: check campaign dict
	if current_location.is_empty():
		var campaign = game_state.get("current_campaign")
		if campaign and campaign is Dictionary:
			current_location = campaign.get("current_location", {})

	if current_location.is_empty():
		world_info_label.text = "No Planet Selected"
		world_info_label.modulate = Color(0.8, 0.8, 0.8)
		return

	# Build world info display
	var planet_name: String = current_location.get("name", "Unknown Planet")
	var planet_type: String = current_location.get("type", "Standard")
	var traits: Array = current_location.get("traits", [])

	var world_text: String = "%s\n" % planet_name
	world_text += "Type: %s\n" % planet_type

	if not traits.is_empty():
		world_text += "Traits: %s" % ", ".join(traits)
	else:
		world_text += "Traits: None"

	world_info_label.text = world_text
	world_info_label.modulate = Color(0.5, 1.0, 0.5)  # Green - have location

func _update_quest_info() -> void:
	"""Update quest info from GameStateManager"""
	if not quest_info_label:
		return

	if not GameStateManager:
		quest_info_label.text = "No Quest Data"
		quest_info_label.modulate = Color(0.8, 0.8, 0.8)
		return

	# Get active quest from GameStateManager
	var active_quest: Dictionary = {}
	if GameStateManager.has_method("get_active_quest"):
		active_quest = GameStateManager.get_active_quest()
	elif GameStateManager.game_state and "active_quest" in GameStateManager.game_state:
		active_quest = GameStateManager.game_state.get("active_quest")
		if active_quest == null:
			active_quest = {}

	if active_quest.is_empty():
		quest_info_label.text = "No Active Quest"
		quest_info_label.modulate = Color(0.8, 0.8, 0.8)
		return

	# Build quest display
	var quest_name: String = active_quest.get("name", "Unknown Quest")
	var quest_progress: int = active_quest.get("progress", 0)
	var quest_target: int = active_quest.get("target", 1)
	var quest_type: String = active_quest.get("type", "")

	var quest_text: String = "%s\n" % quest_name
	if quest_type:
		quest_text += "Type: %s\n" % quest_type
	quest_text += "Progress: %d/%d" % [quest_progress, quest_target]

	quest_info_label.text = quest_text

	# Color based on progress
	var progress_ratio: float = float(quest_progress) / float(quest_target) if quest_target > 0 else 0.0
	if progress_ratio >= 1.0:
		quest_info_label.modulate = Color(0.5, 1.0, 0.5)  # Green - complete
	elif progress_ratio >= 0.5:
		quest_info_label.modulate = Color(1.0, 1.0, 0.5)  # Yellow - in progress
	else:
		quest_info_label.modulate = Color(1.0, 1.0, 1.0)  # White - early

func _update_mission_status() -> void:
	"""Update MissionStatusCard with current mission data"""
	if not mission_status_card or not mission_status_card.has_method("set_mission_data"):
		return

	var mission_data := {}
	if GameStateManager and GameStateManager.has_method("get_active_mission"):
		mission_data = GameStateManager.get_active_mission()
	elif GameStateManager and GameStateManager.game_state and "active_mission" in GameStateManager.game_state:
		mission_data = GameStateManager.game_state.active_mission

	if mission_data == null:
		mission_data = {}

	mission_status_card.set_mission_data(mission_data)

func _update_story_track() -> void:
	"""Update StoryTrackSection with quest/story data"""
	if not story_track_section or not story_track_section.has_method("set_story_data"):
		return

	var story_data := {}
	if GameStateManager:
		var active_quest := {}
		var story_progress := 0

		if GameStateManager.has_method("get_active_quest"):
			active_quest = GameStateManager.get_active_quest()
		elif GameStateManager.game_state and "active_quest" in GameStateManager.game_state:
			active_quest = GameStateManager.game_state.active_quest

		if GameStateManager.has_method("get_story_progress"):
			story_progress = GameStateManager.get_story_progress()
		elif GameStateManager.game_state and "story_progress" in GameStateManager.game_state:
			story_progress = GameStateManager.game_state.story_progress

		if active_quest == null:
			active_quest = {}

		story_data = {
			"active_quest": active_quest,
			"story_progress": story_progress
		}

	story_track_section.set_story_data(story_data)

func _update_world_status() -> void:
	"""Update WorldStatusCard with current location data"""
	if not world_status_card or not world_status_card.has_method("set_world_data"):
		return

	var world_data := {}
	if GameStateManager and GameStateManager.has_method("get_current_location"):
		world_data = GameStateManager.get_current_location()
	elif GameStateManager and GameStateManager.game_state and "current_location" in GameStateManager.game_state:
		world_data = GameStateManager.game_state.current_location

	if world_data == null:
		world_data = {}

	world_status_card.set_world_data(world_data)

func _update_patron_list() -> void:
	"""Update patron list from GameStateManager"""
	if not patron_list:
		return

	patron_list.clear()

	if not GameStateManager:
		patron_list.add_item("GameStateManager not available")
		return

	var patrons: Array = GameStateManager.get_patrons()

	if patrons.is_empty():
		patron_list.add_item("No Patrons")
		return

	# Add each patron to the list
	for patron in patrons:
		var patron_name: String = ""
		var relationship: String = ""

		if patron is Dictionary:
			patron_name = patron.get("name", "Unknown Patron")
			relationship = patron.get("relationship", "Neutral")
		elif patron is Resource:
			patron_name = patron.get_meta("name", "Unknown Patron") if patron.has_meta("name") else "Unknown Patron"
			relationship = patron.get_meta("relationship", "Neutral") if patron.has_meta("relationship") else "Neutral"
		else:
			patron_name = str(patron)
			relationship = "Unknown"

		# Format: "Name (Relationship)"
		var display_text: String = "%s (%s)" % [patron_name, relationship]
		patron_list.add_item(display_text)

func _update_rival_list() -> void:
	"""Update rival list from GameStateManager"""
	if not rival_list:
		return

	rival_list.clear()

	if not GameStateManager:
		rival_list.add_item("GameStateManager not available")
		return

	var rivals: Array = GameStateManager.get_rivals()

	if rivals.is_empty():
		rival_list.add_item("No Rivals")
		return

	# Add each rival to the list with threat indicators
	for rival in rivals:
		var rival_name: String = ""
		var threat_level: int = 1

		if rival is Dictionary:
			rival_name = rival.get("name", "Unknown Rival")
			threat_level = rival.get("threat_level", rival.get("level", 1))
		elif rival is Resource:
			rival_name = rival.get_meta("name", "Unknown Rival") if rival.has_meta("name") else "Unknown Rival"
			threat_level = rival.get_meta("threat_level", 1) if rival.has_meta("threat_level") else 1
		else:
			rival_name = str(rival)
			threat_level = 1

		# Format: "⚔️ Name (Threat: X)"
		var threat_icon: String = "⚔️"
		if threat_level >= 3:
			threat_icon = "💀"  # High threat
		elif threat_level >= 2:
			threat_icon = "⚠️"  # Medium threat

		var display_text: String = "%s %s (Threat: %d)" % [threat_icon, rival_name, threat_level]
		rival_list.add_item(display_text)

func _update_action_button() -> void:
	"""Update action button text and state based on current phase - context-specific"""
	if not next_phase_button:
		return

	if not GameStateManager:
		next_phase_button.text = "Action"
		return

	var current_phase: int = GameStateManager.get_campaign_phase()
	var turn_number: int = GameStateManager.get_campaign_turn() if GameStateManager.has_method("get_campaign_turn") else 1
	var is_new_campaign: bool = turn_number <= 1 and current_phase == 0

	# Set button text and tooltip based on phase - follows Five Parsecs turn structure
	# Campaign Turn: Step 1 (Travel) -> Step 2 (World) -> Step 3 (Battle) -> Step 4 (Post-Battle)
	match current_phase:
		0:  # Setup/New Campaign -> Travel Phase
			if is_new_campaign:
				next_phase_button.text = "Begin Campaign → Travel Phase"
				next_phase_button.tooltip_text = "Start Turn 1: Travel Phase (Step 1)"
			else:
				next_phase_button.text = "Begin Turn %d → Travel Phase" % turn_number
				next_phase_button.tooltip_text = "Start campaign turn with Travel Phase"
		1:  # Travel Phase
			next_phase_button.text = "Continue Travel Phase"
			next_phase_button.tooltip_text = "Step 1: Decide whether to travel (p.69)"
		2:  # World Phase
			next_phase_button.text = "Continue World Phase"
			next_phase_button.tooltip_text = "Step 2: Upkeep, tasks, jobs, battle prep (p.76)"
		3:  # Battle Phase
			next_phase_button.text = "Enter Battle"
			next_phase_button.tooltip_text = "Step 3: Tabletop Battle (p.87)"
		4:  # Post-Battle Phase
			next_phase_button.text = "Post-Battle Sequence"
			next_phase_button.tooltip_text = "Step 4: Resolve aftermath, loot, XP (p.119)"
		_:
			next_phase_button.text = "Next Phase"
			next_phase_button.tooltip_text = "Advance to next campaign phase"

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
	"""Advance to next campaign phase - phase-aware navigation"""
	if not next_phase_button:
		return

	# Verify scene tree exists
	if not get_tree():
		push_error("CampaignDashboard: Scene tree not available")
		return

	# Get current phase and navigate to appropriate screen
	var current_phase: int = 2  # Default to World
	if GameStateManager:
		current_phase = GameStateManager.get_campaign_phase()

	var target_scene: String = ""
	var phase_name: String = ""

	match current_phase:
		0:  # Setup -> Travel
			target_scene = "res://src/ui/screens/travel/TravelPhaseUI.tscn"
			phase_name = "Travel Phase"
		1:  # Travel -> World
			target_scene = "res://src/ui/screens/world/WorldPhaseController.tscn"
			phase_name = "World Phase"
		2:  # World -> Battle (or stay in World for actions)
			target_scene = "res://src/ui/screens/world/WorldPhaseController.tscn"
			phase_name = "World Phase"
		3:  # Battle
			target_scene = "res://src/ui/screens/battle/PreBattle.tscn"
			phase_name = "Battle Phase"
		4:  # Post-Battle
			target_scene = "res://src/ui/screens/postbattle/PostBattleSequence.tscn"
			phase_name = "Post-Battle Phase"
		_:
			target_scene = "res://src/ui/screens/world/WorldPhaseController.tscn"
			phase_name = "World Phase"

	print("CampaignDashboard: Navigating to %s..." % phase_name)

	if SceneRouter and SceneRouter.has_method("navigate_to"):
		var route_name: String = phase_name.to_lower().replace(" ", "_").replace("-", "_")
		SceneRouter.navigate_to(route_name)
	else:
		# Fallback: direct scene navigation
		get_tree().call_deferred("change_scene_to_file", target_scene)

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

## QUICK ACTIONS FOOTER HANDLERS - New button handlers for bottom toolbar

func _on_ship_info_pressed() -> void:
	"""Navigate to Ship Management screen"""
	print("CampaignDashboard: Navigating to Ship Management...")
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/ships/ShipManager.tscn")

func _on_trading_pressed() -> void:
	"""Navigate to Trading screen"""
	print("CampaignDashboard: Navigating to Trading...")
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/campaign/TradingScreen.tscn")

func _on_world_pressed() -> void:
	"""Navigate to World Phase screen"""
	print("CampaignDashboard: Navigating to World Phase...")
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/world/WorldPhaseController.tscn")

func _on_settings_pressed() -> void:
	"""Navigate to Settings screen"""
	print("CampaignDashboard: Navigating to Settings...")
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/settings/SettingsScreen.tscn")

## COMPONENT CARD SIGNAL HANDLERS - Navigation from card clicks

func _on_mission_details_requested() -> void:
	"""Handle MissionStatusCard click - navigate to mission details"""
	print("CampaignDashboard: Navigating to Mission Details...")
	# Navigate to mission/world phase for mission management
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/world/WorldPhaseController.tscn")

func _on_world_details_requested() -> void:
	"""Handle WorldStatusCard click - navigate to world details"""
	print("CampaignDashboard: Navigating to World Details...")
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/world/WorldPhaseController.tscn")

func _on_story_details_requested() -> void:
	"""Handle StoryTrackSection click - navigate to story/quest details"""
	print("CampaignDashboard: Navigating to Story Details...")
	# Navigate to a story/quest details screen (fallback to world phase)
	var story_screen := "res://src/ui/screens/story/StoryDetailsScreen.tscn"
	if FileAccess.file_exists(story_screen):
		get_tree().call_deferred("change_scene_to_file", story_screen)
	else:
		# Fallback to world phase which handles quests
		get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/world/WorldPhaseController.tscn")

func _on_victory_details_requested() -> void:
	"""Handle VictoryProgressPanel click - show victory conditions details"""
	print("CampaignDashboard: Showing Victory Conditions Details...")
	# Could open a popup or navigate to victory conditions screen
	# For now, just log - could be enhanced with a modal later
	pass

## CAMPAIGN PROGRESS TRACKER - Uses CampaignTurnProgressTracker component

func _setup_campaign_progress_tracker() -> void:
	"""Initialize progress tracker component - the component builds its own UI"""
	if not campaign_progress_tracker:
		push_warning("CampaignDashboard: CampaignProgressTracker not found")
		return
	
	# Connect the step_clicked signal from the component (check to avoid duplicates)
	if campaign_progress_tracker.has_signal("step_clicked"):
		if not campaign_progress_tracker.step_clicked.is_connected(_on_progress_step_clicked):
			campaign_progress_tracker.step_clicked.connect(_on_progress_step_clicked)
			print("CampaignDashboard: Progress tracker step_clicked signal connected")
	
	# Sync tracker with current game state phase
	if GameStateManager and campaign_progress_tracker.has_method("set_current_step"):
		var phase: int = GameStateManager.get_campaign_phase()
		var step_index: int = _phase_to_step(phase)
		campaign_progress_tracker.set_current_step(step_index)
	
	# Update initial state
	_update_campaign_progress_tracker()
	print("CampaignDashboard: Progress tracker initialized and synced")

func _phase_to_step(phase: int) -> int:
	"""Map campaign phase to progress tracker step index"""
	# Campaign phases: 0=Setup, 1=Travel, 2=World, 3=Battle, 4=Post-Battle
	# Step indices: 0=Travel, 1=World, 2=Mission, 3=Battle, 4=Loot, 5=Advance, 6=End Turn
	match phase:
		0:  # Setup -> Travel
			return 0
		1:  # Travel
			return 0
		2:  # World
			return 1
		3:  # Battle
			return 3
		4:  # Post-Battle
			return 4
		_:
			return 0

func _update_campaign_progress_tracker() -> void:
	"""Update progress tracker to highlight current phase using component API"""
	if not campaign_progress_tracker:
		return
	
	var current_phase: int = 1  # Default to Travel (step index 0)
	if GameStateManager:
		current_phase = GameStateManager.get_campaign_phase()
	
	# Map campaign phase to step index (0-6 for 7-step tracker)
	# Campaign phases: 0=Setup, 1=Travel, 2=World, 3=Battle, 4=Post-Battle
	# Step indices: 0=Travel, 1=World, 2=Mission, 3=Battle, 4=Loot, 5=Advance, 6=End Turn
	var step_index: int = 0
	match current_phase:
		0:  # Setup -> Travel
			step_index = 0
		1:  # Travel
			step_index = 0
		2:  # World
			step_index = 1
		3:  # Battle
			step_index = 3
		4:  # Post-Battle
			step_index = 4
		_:
			step_index = 0
	
	# Use component's API to update display
	if campaign_progress_tracker.has_method("set_current_step"):
		campaign_progress_tracker.set_current_step(step_index)

func _on_progress_step_clicked(step_index: int) -> void:
	"""Handle progress tracker step click - navigate to corresponding phase"""
	print("CampaignDashboard: Progress step clicked: %d" % step_index)
	
	# Step indices from CampaignTurnProgressTracker:
	# 0=Travel, 1=World, 2=Mission, 3=Battle, 4=Loot, 5=Advance, 6=End Turn
	
	# Only allow jumping to current or completed steps
	if GameStateManager:
		var current_phase := GameStateManager.get_campaign_phase()
		# Map step_index to campaign phase for comparison
		var target_phase := _step_to_phase(step_index)
		if target_phase > current_phase:
			print("  Cannot jump to future phase (current: %d, requested: %d)" % [current_phase, target_phase])
			return
	
	# Navigate to appropriate phase screen based on step index
	match step_index:
		0:  # Travel
			get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/travel/TravelPhaseUI.tscn")
		1, 2:  # World or Mission (both in World phase)
			get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/world/WorldPhaseController.tscn")
		3:  # Battle
			get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/battle/BattleHUDCoordinator.tscn")
		4, 5, 6:  # Loot, Advance, End Turn (all Post-Battle)
			get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/postbattle/PostBattleSequence.tscn")

func _step_to_phase(step_index: int) -> int:
	"""Convert step index (0-6) to campaign phase (0-4)"""
	match step_index:
		0: return 1  # Travel
		1, 2: return 2  # World/Mission
		3: return 3  # Battle
		4, 5, 6: return 4  # Post-Battle (Loot, Advance, End Turn)
		_: return 1

## RESPONSIVE CREW CONTAINER SETUP

func _setup_responsive_crew_container() -> void:
	"""Setup responsive crew card container (horizontal scroll on mobile, grid on desktop)"""
	if not crew_scroll_container or not crew_card_container:
		return
	
	# Determine initial layout based on viewport
	var viewport_width := get_viewport().get_visible_rect().size.x
	_update_crew_container_layout(viewport_width)

func _update_crew_container_layout(viewport_width: int) -> void:
	"""Update crew container layout based on viewport width with proper breakpoints"""
	if not crew_card_container:
		return
	
	# Breakpoints:
	# - Mobile (<768px): Single column, horizontal scroll, 8px gap
	# - Tablet (768-1024px): 2 columns, vertical scroll, 12px gap
	# - Desktop (>1024px): 2-3 columns, vertical scroll, 16px gap
	
	if viewport_width < 768:
		# Mobile: Horizontal scroll with single row
		if crew_scroll_container:
			crew_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			crew_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		
		# Replace container with HBoxContainer for horizontal layout
		if not crew_card_container is HBoxContainer:
			var new_container := HBoxContainer.new()
			new_container.name = "CrewCardContainer"
			new_container.add_theme_constant_override("separation", 8)
			
			# Transfer children
			for child in crew_card_container.get_children():
				crew_card_container.remove_child(child)
				new_container.add_child(child)
			
			var parent := crew_card_container.get_parent()
			parent.remove_child(crew_card_container)
			parent.add_child(new_container)
			crew_card_container = new_container
	elif viewport_width < 1024:
		# Tablet: 2 columns with 12px gap
		if crew_scroll_container:
			crew_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			crew_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		
		if not crew_card_container is GridContainer:
			var new_container := GridContainer.new()
			new_container.name = "CrewCardContainer"
			new_container.columns = 2
			new_container.add_theme_constant_override("h_separation", 12)
			new_container.add_theme_constant_override("v_separation", 12)
			
			# Transfer children
			for child in crew_card_container.get_children():
				crew_card_container.remove_child(child)
				new_container.add_child(child)
			
			var parent := crew_card_container.get_parent()
			parent.remove_child(crew_card_container)
			parent.add_child(new_container)
			crew_card_container = new_container
		else:
			# Update existing GridContainer settings
			crew_card_container.columns = 2
			crew_card_container.add_theme_constant_override("h_separation", 12)
			crew_card_container.add_theme_constant_override("v_separation", 12)
	else:
		# Desktop: 2-3 columns with 16px gap
		if crew_scroll_container:
			crew_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			crew_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		
		# Determine column count based on width
		var columns: int = 2 if viewport_width < 1440 else 3
		
		if not crew_card_container is GridContainer:
			var new_container := GridContainer.new()
			new_container.name = "CrewCardContainer"
			new_container.columns = columns
			new_container.add_theme_constant_override("h_separation", 16)
			new_container.add_theme_constant_override("v_separation", 16)
			
			# Transfer children
			for child in crew_card_container.get_children():
				crew_card_container.remove_child(child)
				new_container.add_child(child)
			
			var parent := crew_card_container.get_parent()
			parent.remove_child(crew_card_container)
			parent.add_child(new_container)
			crew_card_container = new_container
		else:
			# Update existing GridContainer settings
			crew_card_container.columns = columns
			crew_card_container.add_theme_constant_override("h_separation", 16)
			crew_card_container.add_theme_constant_override("v_separation", 16)

func _on_viewport_resized() -> void:
	"""Handle viewport resize - update responsive layouts (legacy support)"""
	var viewport_width := get_viewport().get_visible_rect().size.x
	
	# Only update if width changed significantly (avoid redundant updates)
	if abs(viewport_width - _current_viewport_width) > 50:
		_current_viewport_width = viewport_width
		_update_crew_container_layout(viewport_width)
		_update_crew_list()  # Refresh cards with appropriate variant

func _on_responsive_breakpoint_changed(new_breakpoint: int) -> void:
	"""Handle ResponsiveManager breakpoint changes"""
	_apply_responsive_layout(new_breakpoint)
	_update_crew_list()  # Refresh cards with appropriate variant
	print("CampaignDashboard: Layout updated via ResponsiveManager - Breakpoint: %s" % _responsive_manager.get_breakpoint_name())

func _apply_responsive_layout(bp: int) -> void:
	"""Apply responsive layout based on ResponsiveManager breakpoint"""
	# Note: parameter named 'bp' because 'breakpoint' is a reserved keyword
	if not crew_card_container:
		return
	
	# Get viewport width for additional breakpoint logic
	var viewport_width := get_viewport().get_visible_rect().size.x
	
	# Use ResponsiveManager helpers for consistent behavior
	if _responsive_manager.should_use_horizontal_scroll():
		# Mobile (<768px): Horizontal scroll with 8px gap
		if crew_scroll_container:
			crew_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			crew_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		
		# Replace with HBoxContainer for horizontal layout
		if not crew_card_container is HBoxContainer:
			var new_container := HBoxContainer.new()
			new_container.name = "CrewCardContainer"
			new_container.add_theme_constant_override("separation", 8)
			
			# Transfer children
			for child in crew_card_container.get_children():
				crew_card_container.remove_child(child)
				new_container.add_child(child)
			
			var parent := crew_card_container.get_parent()
			parent.remove_child(crew_card_container)
			parent.add_child(new_container)
			crew_card_container = new_container
	else:
		# Tablet/Desktop: Grid layout with breakpoint-aware spacing
		if crew_scroll_container:
			crew_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			crew_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		
		# Determine columns and spacing based on viewport width
		var columns: int = 2
		var spacing: int = 12  # Tablet default
		
		if viewport_width >= 1024:
			# Desktop: 2-3 columns with 16px gap
			columns = 3 if viewport_width >= 1440 else 2
			spacing = 16
		else:
			# Tablet: 2 columns with 12px gap
			columns = 2
			spacing = 12
		
		# Replace with GridContainer or update existing
		if not crew_card_container is GridContainer:
			var new_container := GridContainer.new()
			new_container.name = "CrewCardContainer"
			new_container.columns = columns
			new_container.add_theme_constant_override("h_separation", spacing)
			new_container.add_theme_constant_override("v_separation", spacing)
			
			# Transfer children
			for child in crew_card_container.get_children():
				crew_card_container.remove_child(child)
				new_container.add_child(child)
			
			var parent := crew_card_container.get_parent()
			parent.remove_child(crew_card_container)
			parent.add_child(new_container)
			crew_card_container = new_container
		else:
			# Update existing GridContainer
			crew_card_container.columns = columns
			crew_card_container.add_theme_constant_override("h_separation", spacing)
			crew_card_container.add_theme_constant_override("v_separation", spacing)

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


func _setup_story_point_dialog() -> void:
	"""Setup the Story Point spending dialog (Core Rules p.67)"""
	# Make story_points_label clickable to open dialog
	if story_points_label:
		story_points_label.mouse_filter = Control.MOUSE_FILTER_STOP
		story_points_label.gui_input.connect(_on_story_points_label_clicked)
		story_points_label.tooltip_text = "Click to spend Story Points"
		# Add visual hint that it's clickable
		story_points_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	print("CampaignDashboard: Story Point spending dialog setup complete")


func _on_story_points_label_clicked(event: InputEvent) -> void:
	"""Handle click on story points label to open spending dialog"""
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_open_story_point_dialog()


func _open_story_point_dialog() -> void:
	"""Open the Story Point spending dialog"""
	# Get current story points
	var current_story_points: int = GameStateManager.get_story_progress()

	if current_story_points <= 0:
		print("CampaignDashboard: No story points available to spend")
		# Could show a toast/notification here
		return

	# Create dialog if not exists
	if not story_point_dialog or not is_instance_valid(story_point_dialog):
		story_point_dialog = StoryPointDialogScene.instantiate()
		add_child(story_point_dialog)

		# Connect dialog signals (using actual signal names from StoryPointSpendingDialog)
		if story_point_dialog.has_signal("option_selected"):
			story_point_dialog.option_selected.connect(_on_story_point_spent)
		if story_point_dialog.has_signal("dialog_cancelled"):
			story_point_dialog.dialog_cancelled.connect(_on_story_point_dialog_closed)

	# Show the dialog with current story points and spending status
	if story_point_dialog.has_method("show_dialog"):
		# Get spending status from StoryPointSystem if available
		var spending_status: Dictionary = {}
		story_point_dialog.show_dialog(current_story_points, spending_status)
	else:
		story_point_dialog.show()

	story_point_dialog.grab_focus()
	print("CampaignDashboard: Story Point dialog opened with %d points" % current_story_points)


func _on_story_point_spent(spend_type: int, details: Dictionary) -> void:
	"""Handle story point being spent"""
	print("CampaignDashboard: Story point spent - type: %d, details: %s" % [spend_type, str(details)])

	# Update the UI to reflect the change
	_update_ui()

	# The actual spending logic is handled by the StoryPointSystem through the dialog


func _on_story_point_dialog_closed() -> void:
	"""Handle dialog being closed"""
	print("CampaignDashboard: Story Point dialog closed")
	# Refresh UI in case points were spent
	_update_ui()

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
		get_viewport().set_input_as_handled()  # Consume event to prevent propagation
		if developer_panel:
			_toggle_developer_panel()
		else:
			push_warning("CampaignDashboard: Developer panel not instantiated - check debug build")

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

## BATTLE HISTORY TRACKING - Resume suspended games and view history

func _update_battle_history() -> void:
	"""Update battle history display and check for suspended battles"""
	_load_battle_history()
	_display_battle_history()
	_check_suspended_battle()

func _load_battle_history() -> void:
	"""Load battle history from GameStateManager"""
	if not GameStateManager:
		return

	# Get battle history from game state
	if GameStateManager.has_method("get_battle_history"):
		battle_history = GameStateManager.get_battle_history()
	elif GameStateManager.game_state and "battle_history" in GameStateManager.game_state:
		# Fix: Only one argument is allowed in get(). Providing default after checking presence.
		battle_history = GameStateManager.game_state.get("battle_history")
		if battle_history == null:
			battle_history = []
	else:
		battle_history = []

func _display_battle_history() -> void:
	"""Display battle history entries in the UI"""
	if not battle_history_list:
		return

	# Clear existing entries
	for child in battle_history_list.get_children():
		child.queue_free()

	if battle_history.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No battles yet"
		empty_label.modulate = Color(0.7, 0.7, 0.7)
		battle_history_list.add_child(empty_label)
		return

	# Display most recent battles first (up to 10)
	var display_count := mini(battle_history.size(), 10)
	for i in range(display_count):
		var battle_data: Dictionary = battle_history[battle_history.size() - 1 - i]
		var entry := _create_battle_history_entry(battle_data)
		battle_history_list.add_child(entry)

func _create_battle_history_entry(battle_data: Dictionary) -> Control:
	"""Create a visual entry for a battle in history"""
	var container := HBoxContainer.new()

	# Result icon
	var result_icon := Label.new()
	if battle_data.get("victory", false):
		result_icon.text = "✅"
	else:
		result_icon.text = "❌"
	container.add_child(result_icon)

	# Battle info
	var info_label := Label.new()
	var turn_num: int = battle_data.get("turn", 0)
	var mission_type: String = battle_data.get("mission_type", "Battle")
	var rounds: int = battle_data.get("rounds_fought", 0)
	var casualties: int = battle_data.get("casualties", 0)

	info_label.text = "T%d: %s (%d rds" % [turn_num, mission_type, rounds]
	if casualties > 0:
		info_label.text += ", %d KIA" % casualties
	info_label.text += ")"
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	container.add_child(info_label)

	return container

func _check_suspended_battle() -> void:
	"""Check if there's a suspended battle that can be resumed"""
	if not GameStateManager:
		_update_battle_status("No active battle")
		return

	# Check for suspended battle state
	var suspended_battle: Dictionary = {}
	if GameStateManager.has_method("get_suspended_battle"):
		suspended_battle = GameStateManager.get_suspended_battle()
	elif GameStateManager.game_state and "suspended_battle" in GameStateManager.game_state:
		suspended_battle = GameStateManager.game_state.get("suspended_battle")
		if suspended_battle == null:
			suspended_battle = {}

	if suspended_battle.is_empty() or not suspended_battle.get("is_active", false):
		_update_battle_status("No active battle")
		if resume_battle_button:
			resume_battle_button.hide()
		return

	# Show suspended battle info
	var phase: String = suspended_battle.get("phase", "Unknown")
	var turn: int = suspended_battle.get("turn", 0)
	var round_num: int = suspended_battle.get("round", 0)

	var status_text := "⏸️ Battle suspended: Turn %d, %s Phase" % [turn, phase]
	if round_num > 0:
		status_text += ", Round %d" % round_num

	_update_battle_status(status_text)

	# Show resume button
	if resume_battle_button:
		resume_battle_button.show()

func _update_battle_status(status: String) -> void:
	"""Update the current battle status display"""
	if current_battle_status:
		current_battle_status.text = status

func _on_resume_battle_pressed() -> void:
	"""Resume a suspended battle"""
	print("CampaignDashboard: Resuming suspended battle...")

	if not GameStateManager:
		push_error("CampaignDashboard: Cannot resume - GameStateManager not available")
		return

	# Get suspended battle data
	var suspended_battle: Dictionary = {}
	if GameStateManager.has_method("get_suspended_battle"):
		suspended_battle = GameStateManager.get_suspended_battle()
	elif GameStateManager.game_state and "suspended_battle" in GameStateManager.game_state:
		suspended_battle = GameStateManager.game_state.get("suspended_battle")
		if suspended_battle == null:
			suspended_battle = {}

	if suspended_battle.is_empty():
		push_warning("CampaignDashboard: No suspended battle to resume")
		return

	# Navigate to appropriate battle scene based on phase
	var phase: String = suspended_battle.get("phase", "PreBattle")

	match phase:
		"PreBattle":
			get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/battle/PreBattle.tscn")
		"TacticalBattle", "Combat":
			get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/battle/TacticalBattleUI.tscn")
		"PostBattle":
			get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/postbattle/PostBattleSequence.tscn")
		_:
			# Default to campaign turn controller
			get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/campaign/CampaignTurnController.tscn")

	print("CampaignDashboard: Navigating to %s phase" % phase)

## PUBLIC: Add battle to history (call from battle completion)

func add_battle_to_history(battle_result: Dictionary) -> void:
	"""Add a completed battle to history and save to GameState"""
	var history_entry := {
		"turn": GameStateManager.get_campaign_turn() if GameStateManager else 1,
		"mission_type": battle_result.get("mission_type", "Battle"),
		"victory": battle_result.get("victory", false),
		"rounds_fought": battle_result.get("rounds_fought", 0),
		"casualties": battle_result.get("crew_casualties", []).size(),
		"injuries": battle_result.get("crew_injuries", []).size(),
		"loot": battle_result.get("loot_found", []).size(),
		"credits_earned": battle_result.get("credits_earned", 0),
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	# Add to local history
	battle_history.append(history_entry)
	
	# Save to GameStateManager
	if GameStateManager and GameStateManager.has_method("add_battle_history"):
		GameStateManager.add_battle_history(history_entry)
	
	# Update display
	_display_battle_history()
