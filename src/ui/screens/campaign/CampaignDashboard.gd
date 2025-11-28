# Campaign Dashboard UI - Simplified (Framework Bible Compliant)
# Reads directly from GameStateManager - no duplicate state management
class_name FPCM_CampaignDashboardUI
extends Control

# Safe imports - removed BaseCampaignDashboardSystem (overengineered abstraction)
const FPCM_BasePhasePanel = preload("res://src/ui/screens/campaign/phases/BasePhasePanel.gd")

# Character display component
const CharacterCardScene = preload("res://src/ui/components/character/CharacterCard.tscn")
const Character = preload("res://src/core/character/Character.gd")

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
@onready var campaign_progress_tracker: PanelContainer = %CampaignProgressTracker
@onready var crew_scroll_container: ScrollContainer = %CrewScrollContainer
@onready var crew_card_container: Container = %CrewCardContainer
@onready var ship_info: Label = %ShipInfo
@onready var world_info_label: Label = %WorldInfo
@onready var quest_info_label: Label = get_node_or_null("MarginContainer/VBoxContainer/MainContent/RightPanel/QuestPanel/VBoxContainer/QuestInfo")
@onready var patron_list: ItemList = %PatronList
@onready var rival_list: ItemList = %RivalList
@onready var phase_content: Control = get_node("MarginContainer/VBoxContainer/MainContent") as Control
@onready var next_phase_button: Button = %ActionButton
@onready var manage_crew_button: Button = %ManageCrewButton
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var quit_button: Button = %QuitButton

# Battle History UI elements
@onready var battle_history_list: VBoxContainer = %BattleHistoryList
@onready var resume_battle_button: Button = %ResumeBattleButton
@onready var current_battle_status: Label = %CurrentBattleStatus

# Victory Progress UI
@onready var victory_progress_panel = %VictoryProgressPanel

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

func _ready() -> void:
	print("CampaignDashboard: Initializing (simplified - reads from GameStateManager directly)")

	# Load official Five Parsecs phase panel scenes
	TravelPhasePanel = load("res://src/ui/screens/travel/TravelPhaseUI.tscn")
	WorldPhasePanel = load("res://src/ui/screens/world/WorldPhaseController.tscn")
	PostBattlePhasePanel = load("res://src/ui/screens/postbattle/PostBattleSequence.tscn")

	_connect_dashboard_buttons()
	_setup_campaign_progress_tracker()
	_setup_responsive_crew_container()
	_update_ui()
	_setup_button_icons()

	# Setup developer panel for quick testing
	_setup_developer_panel()

	# Track viewport size for responsive updates
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
	var viewport_width := get_viewport().get_visible_rect().size.x
	var card_variant: int = CharacterCardScene.instantiate().CardVariant.COMPACT if viewport_width < 768 else CharacterCardScene.instantiate().CardVariant.STANDARD

	# Create/reuse CharacterCard for each crew member
	for i in range(crew_members.size()):
		var member = crew_members[i]
		
		# Convert member data to Character if needed
		var character: Character = null
		if member is Character:
			character = member
		elif member is Dictionary:
			character = Character.new()
			character.character_name = member.get("character_name", "Unknown")
			character.reactions = member.get("reactions", 1)
			character.speed = member.get("speed", 4)
			character.combat = member.get("combat", 0)
			character.toughness = member.get("toughness", 3)
			character.savvy = member.get("savvy", 0)
			character.luck = member.get("luck", 0)
			character.health = member.get("health", 3)
			character.max_health = member.get("max_health", 3)
			character.character_class = member.get("character_class", "")
			character.background = member.get("background", "")

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
	"""Update action button text and state based on current phase"""
	if not next_phase_button:
		return

	if not GameStateManager:
		next_phase_button.text = "Action"
		return

	var current_phase: int = GameStateManager.get_campaign_phase()

	# Set button text and tooltip based on phase
	match current_phase:
		0:  # Setup
			next_phase_button.text = "Begin Campaign"
			next_phase_button.tooltip_text = "Start your campaign journey"
		1:  # Travel
			next_phase_button.text = "Travel Phase"
			next_phase_button.tooltip_text = "Plan your travel route"
		2:  # World
			next_phase_button.text = "World Actions"
			next_phase_button.tooltip_text = "Perform world phase activities"
		3:  # Battle
			next_phase_button.text = "Enter Battle"
			next_phase_button.tooltip_text = "Begin tactical combat"
		4:  # Post-Battle
			next_phase_button.text = "Post-Battle"
			next_phase_button.tooltip_text = "Resolve battle aftermath"
		_:
			next_phase_button.text = "Next Phase"
			next_phase_button.tooltip_text = "Advance to next phase"

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

## CAMPAIGN PROGRESS TRACKER - Visual turn phase indicator

func _setup_campaign_progress_tracker() -> void:
	"""Setup 7-step campaign phase breadcrumb tracker"""
	if not campaign_progress_tracker:
		return
	
	var progress_container := campaign_progress_tracker.get_node("ProgressContainer") as HBoxContainer
	if not progress_container:
		return
	
	# Define phase structure (repeating cycle)
	var phases := ["Travel", "World", "Battle", "Post-Battle"]
	
	# Create phase indicators
	for i in range(phases.size()):
		if i > 0:
			# Add connector line
			var connector := ColorRect.new()
			connector.custom_minimum_size = Vector2(24, 2)
			connector.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			connector.color = Color("#3A3A5C")  # COLOR_BORDER
			progress_container.add_child(connector)
		
		# Create phase circle button
		var phase_btn := Button.new()
		phase_btn.custom_minimum_size = Vector2(48, 48)  # TOUCH_TARGET_MIN
		phase_btn.text = phases[i].substr(0, 1)  # First letter (T, W, B, P)
		phase_btn.tooltip_text = phases[i]
		phase_btn.flat = false
		
		# Style phase button
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#1E1E36")  # COLOR_INPUT
		style.border_color = Color("#3A3A5C")  # COLOR_BORDER
		style.set_border_width_all(2)
		style.set_corner_radius_all(24)  # Circular
		phase_btn.add_theme_stylebox_override("normal", style)
		
		# Connect to phase jump handler
		phase_btn.pressed.connect(_on_phase_indicator_pressed.bind(i + 1))  # Phase enum starts at 1
		
		progress_container.add_child(phase_btn)
	
	# Update initial state
	_update_campaign_progress_tracker()

func _update_campaign_progress_tracker() -> void:
	"""Update progress tracker to highlight current phase"""
	if not campaign_progress_tracker:
		return
	
	var progress_container := campaign_progress_tracker.get_node_or_null("ProgressContainer") as HBoxContainer
	if not progress_container:
		return
	
	var current_phase: int = 1  # Default to Travel
	if GameStateManager:
		current_phase = GameStateManager.get_campaign_phase()
	
	# Update phase button styles (skip connectors - every other child)
	var phase_index := 0
	for i in range(progress_container.get_child_count()):
		var child := progress_container.get_child(i)
		
		# Skip connector lines (ColorRect)
		if child is ColorRect:
			continue
		
		if child is Button:
			var phase_btn := child as Button
			var is_current := (phase_index + 1 == current_phase)
			var is_completed := (phase_index + 1 < current_phase)
			
			# Update style based on state
			var style := StyleBoxFlat.new()
			if is_current:
				# Current phase - accent color
				style.bg_color = Color("#2D5A7B")  # COLOR_ACCENT
				style.border_color = Color("#4FC3F7")  # COLOR_FOCUS (cyan highlight)
				phase_btn.modulate = Color.WHITE
			elif is_completed:
				# Completed phase - success color
				style.bg_color = Color("#10B981")  # COLOR_SUCCESS (green)
				style.border_color = Color("#10B981")
				phase_btn.modulate = Color.WHITE
			else:
				# Future phase - disabled color
				style.bg_color = Color("#1E1E36")  # COLOR_INPUT
				style.border_color = Color("#404040")  # COLOR_TEXT_DISABLED
				phase_btn.modulate = Color("#808080")  # COLOR_TEXT_SECONDARY
			
			style.set_border_width_all(2)
			style.set_corner_radius_all(24)
			phase_btn.add_theme_stylebox_override("normal", style)
			
			phase_index += 1

func _on_phase_indicator_pressed(phase: int) -> void:
	"""Handle phase indicator button press - jump to phase"""
	print("CampaignDashboard: Phase indicator pressed for phase %d" % phase)
	
	# Only allow jumping to current or previous phases (no skipping ahead)
	if GameStateManager:
		var current_phase := GameStateManager.get_campaign_phase()
		if phase > current_phase:
			print("  Cannot jump to future phase (current: %d, requested: %d)" % [current_phase, phase])
			return
	
	# Navigate to appropriate phase screen
	match phase:
		1:  # Travel
			get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/travel/TravelPhaseUI.tscn")
		2:  # World
			get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/world/WorldPhaseController.tscn")
		3:  # Battle
			get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/battle/BattleHUDCoordinator.tscn")
		4:  # Post-Battle
			get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/postbattle/PostBattleSequence.tscn")

## RESPONSIVE CREW CONTAINER SETUP

func _setup_responsive_crew_container() -> void:
	"""Setup responsive crew card container (horizontal scroll on mobile, grid on desktop)"""
	if not crew_scroll_container or not crew_card_container:
		return
	
	# Determine initial layout based on viewport
	var viewport_width := get_viewport().get_visible_rect().size.x
	_update_crew_container_layout(viewport_width)

func _update_crew_container_layout(viewport_width: int) -> void:
	"""Update crew container layout based on viewport width"""
	if not crew_card_container:
		return
	
	# Mobile (<768px): Horizontal scroll with VBoxContainer
	# Desktop (>=768px): GridContainer 2 columns
	if viewport_width < 768:
		# Mobile: Horizontal scroll
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
	else:
		# Desktop: Grid layout
		if crew_scroll_container:
			crew_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			crew_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		
		# Replace container with GridContainer
		if not crew_card_container is GridContainer:
			var new_container := GridContainer.new()
			new_container.name = "CrewCardContainer"
			new_container.columns = 2
			new_container.add_theme_constant_override("h_separation", 8)
			new_container.add_theme_constant_override("v_separation", 8)
			
			# Transfer children
			for child in crew_card_container.get_children():
				crew_card_container.remove_child(child)
				new_container.add_child(child)
			
			var parent := crew_card_container.get_parent()
			parent.remove_child(crew_card_container)
			parent.add_child(new_container)
			crew_card_container = new_container

func _on_viewport_resized() -> void:
	"""Handle viewport resize - update responsive layouts"""
	var viewport_width := get_viewport().get_visible_rect().size.x
	
	# Only update if width changed significantly (avoid redundant updates)
	if abs(viewport_width - _current_viewport_width) > 50:
		_current_viewport_width = viewport_width
		_update_crew_container_layout(viewport_width)
		_update_crew_list()  # Refresh cards with appropriate variant

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