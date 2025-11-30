## PreBattleUI manages the pre-battle setup interface
class_name FPCM_PreBattleUI
extends Control

## Design System Constants (from BaseCampaignPanel)
const COLOR_PRIMARY := Color("#0a0d14")      # Darkest background
const COLOR_SECONDARY := Color("#111827")    # Card backgrounds
const COLOR_TERTIARY := Color("#1f2937")     # Elevated elements
const COLOR_BORDER := Color("#374151")       # Border color
const COLOR_BLUE := Color("#3b82f6")         # Primary accent
const COLOR_EMERALD := Color("#10b981")      # Success
const COLOR_AMBER := Color("#f59e0b")        # Warning
const COLOR_RED := Color("#ef4444")          # Danger
const COLOR_CYAN := Color("#06b6d4")         # Highlights
const COLOR_TEXT_PRIMARY := Color("#f3f4f6") # Bright text
const COLOR_TEXT_SECONDARY := Color("#9ca3af") # Gray text

const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

## Dependencies
# GlobalEnums available as autoload singleton
const Character = preload("res://src/core/character/Character.gd")
const TerrainLayoutGenerator = preload("res://src/core/terrain/TerrainLayoutGenerator.gd")
const TerrainSuggestionItemScene = preload("res://src/ui/components/TerrainSuggestionItem.tscn")

# Battle Phase Types
enum BattlePhase {
	NONE,
	SETUP,
	DEPLOYMENT,
	INITIATIVE,
	ACTION,
	REACTION,
	CLEANUP
}

## Optional dependencies that may not exist
var _terrain_system_script: GDScript = preload("res://src/core/terrain/UnifiedTerrainSystem.gd") if FileAccess.file_exists("res://src/core/terrain/UnifiedTerrainSystem.gd") else null

## Signals
signal crew_selected(crew: Array[Character])
signal deployment_confirmed
signal terrain_ready
signal preview_updated
signal terrain_suggestions_generated(suggestions: Array)
signal all_terrain_confirmed

## Node references
@onready var mission_info_panel: Control = $"MarginContainer/VBoxContainer/MainContent/LeftPanel/MissionInfo/VBoxContainer/Content"
@onready var enemy_info_panel: Control = $"MarginContainer/VBoxContainer/MainContent/LeftPanel/EnemyInfo/VBoxContainer/Content"
@onready var battlefield_preview: Control = $"MarginContainer/VBoxContainer/MainContent/CenterPanel/BattlefieldPreview/VBoxContainer/PreviewContent"
@onready var crew_selection_panel: Control = $"MarginContainer/VBoxContainer/MainContent/RightPanel/CrewSelection/VBoxContainer/ScrollContainer/Content"
@onready var deployment_panel: Control = $MarginContainer/VBoxContainer/MainContent/RightPanel/DeploymentPanel/VBoxContainer/Content
@onready var confirm_button: Button = $MarginContainer/VBoxContainer/FooterPanel/HBoxContainer/ConfirmButton
@onready var back_button: Button = $MarginContainer/VBoxContainer/FooterPanel/HBoxContainer/BackButton

# Terrain suggestions UI elements (from scene)
@onready var terrain_suggestions_container: VBoxContainer = %TerrainSuggestionsList
@onready var generate_terrain_button: Button = %GenerateButton
@onready var confirm_all_terrain_button: Button = %ConfirmAllButton

# D100 and Initiative display labels (from scene)
@onready var deployment_condition_label: Label = %DeploymentConditionLabel
@onready var notable_sights_label: Label = %NotableSightsLabel
@onready var initiative_result_label: Label = %InitiativeResultLabel

## State
var current_mission: StoryQuestData
var selected_crew: Array[Character]
var terrain_system: Node # Will be cast to UnifiedTerrainSystem if available

## Terrain Suggestion State
var terrain_layout_generator: Node
var terrain_suggestions: Array = []
var terrain_suggestion_items: Array = []
var confirmed_suggestions: Array = []

func _ready() -> void:
	_apply_glass_morphism_styling()
	_initialize_systems()
	_connect_signals()
	confirm_button.disabled = true

	# Load mission data from GameState
	_load_mission_from_gamestate()

## Apply glass morphism styling to panels
func _apply_glass_morphism_styling() -> void:
	# Style mission info panel
	if mission_info_panel and mission_info_panel.get_parent() is PanelContainer:
		var panel = mission_info_panel.get_parent() as PanelContainer
		panel.add_theme_stylebox_override("panel", _create_glass_card_style())
	
	# Style enemy info panel
	if enemy_info_panel and enemy_info_panel.get_parent() is PanelContainer:
		var panel = enemy_info_panel.get_parent() as PanelContainer
		panel.add_theme_stylebox_override("panel", _create_glass_card_style())
	
	# Style battlefield preview
	if battlefield_preview and battlefield_preview.get_parent() is PanelContainer:
		var panel = battlefield_preview.get_parent() as PanelContainer
		panel.add_theme_stylebox_override("panel", _create_glass_card_style())
	
	# Style crew selection panel
	if crew_selection_panel and crew_selection_panel.get_parent() is PanelContainer:
		var panel = crew_selection_panel.get_parent() as PanelContainer
		panel.add_theme_stylebox_override("panel", _create_glass_card_style())
	
	# Style deployment panel
	if deployment_panel and deployment_panel.get_parent() is PanelContainer:
		var panel = deployment_panel.get_parent() as PanelContainer
		panel.add_theme_stylebox_override("panel", _create_glass_card_style())

func _create_glass_card_style(alpha: float = 0.8) -> StyleBoxFlat:
	"""Create glass morphism card style"""
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, alpha)
	style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(SPACING_LG)
	return style

## Initialize required systems
func _initialize_systems() -> void:
	if _terrain_system_script:
		terrain_system = _terrain_system_script.new()
		if battlefield_preview:
			battlefield_preview.add_child(terrain_system)
			if terrain_system.has_signal("terrain_generated"):
				terrain_system.terrain_generated.connect(_on_terrain_generated)

	# Initialize terrain suggestions UI
	_setup_terrain_suggestions_ui()

## Connect UI signals
func _connect_signals() -> void:
	if confirm_button and not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)

	# Connect terrain suggestion buttons
	if generate_terrain_button and not generate_terrain_button.pressed.is_connected(generate_terrain_suggestions):
		generate_terrain_button.pressed.connect(generate_terrain_suggestions)

	if confirm_all_terrain_button and not confirm_all_terrain_button.pressed.is_connected(_on_confirm_all_terrain):
		confirm_all_terrain_button.pressed.connect(_on_confirm_all_terrain)

## Load mission data from GameState and setup UI
func _load_mission_from_gamestate() -> void:
	var game_state = get_node_or_null("/root/GameState")
	if not game_state or not game_state.current_campaign:
		push_warning("PreBattleUI: No GameState or campaign found")
		return

	var campaign = game_state.current_campaign

	# Get current mission from world phase
	if "current_mission" in campaign:
		var mission_data = campaign.current_mission

		# Build preview data dictionary
		var preview_data = {
			"title": mission_data.get("objective", "Mission").capitalize(),
			"description": mission_data.get("objective_description", ""),
			"enemy_type": mission_data.get("enemy_type", "Unknown Hostiles"),
			"pay": mission_data.get("pay", 0),
			"danger_level": mission_data.get("danger_level", 1),
			"deployment_condition": mission_data.get("deployment_condition", ""),
			"notable_sights": mission_data.get("notable_sights", ""),
			"patron": mission_data.get("patron", ""),
			"location": mission_data.get("location", "")
		}

		# Setup the preview with mission data
		setup_preview(preview_data)

		# Update D100 condition labels if present
		if deployment_condition_label:
			var condition = mission_data.get("deployment_condition", "")
			deployment_condition_label.text = condition if condition else "Standard Deployment"

		if notable_sights_label:
			var sights = mission_data.get("notable_sights", "")
			notable_sights_label.text = sights if sights else "None"

		print("PreBattleUI: Loaded mission from GameState - %s" % preview_data.title)
	else:
		push_warning("PreBattleUI: No current_mission in campaign")

func _on_confirm_all_terrain() -> void:
	"""Confirm all terrain suggestions at once"""
	for suggestion in terrain_suggestions:
		if not suggestion in confirmed_suggestions:
			confirmed_suggestions.append(suggestion)
	all_terrain_confirmed.emit()
	print("PreBattleUI: All %d terrain suggestions confirmed" % confirmed_suggestions.size())

## Setup the UI with mission data
func setup_preview(data: Dictionary) -> void:
	if not data:
		push_error("PreBattleUI: Invalid preview data")
		return

	_setup_mission_info(data)
	_setup_enemy_info(data)
	_setup_battlefield_preview(data)
	preview_updated.emit()

## Setup mission information
func _setup_mission_info(data: Dictionary) -> void:
	if not mission_info_panel:
		return

	var mission_title := Label.new()
	mission_title.text = data.get("title", "Unknown Mission")
	mission_title.add_theme_font_size_override("font_size", 18)

	var mission_desc := Label.new()
	mission_desc.text = data.get("description", "")
	mission_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var battle_type := Label.new()
	battle_type.text = "Battle Type: %s" % data.get("battle_type", "Standard")

	mission_info_panel.add_child(mission_title)
	mission_info_panel.add_child(mission_desc)
	mission_info_panel.add_child(battle_type)

	# Add separator before pre-battle rolls
	var sep := HSeparator.new()
	mission_info_panel.add_child(sep)

	# Display D100 pre-battle rolls
	display_prebattle_rolls()

## Setup enemy information
func _setup_enemy_info(data: Dictionary) -> void:
	if not enemy_info_panel:
		return

	var enemy_force: Character = data.enemy_force
	var enemy_list := VBoxContainer.new()

	for unit in enemy_force.units:
		var unit_label := Label.new()
		unit_label.text = unit.type
		enemy_list.add_child(unit_label)

	enemy_info_panel.add_child(enemy_list)

## Setup battlefield preview
func _setup_battlefield_preview(data: Dictionary) -> void:
	if not battlefield_preview:
		return

	# Generate terrain from terrain system if available
	if terrain_system and terrain_system.has_method("generate_battlefield"):
		terrain_system.generate_battlefield(data)

	# Generate terrain suggestions for tabletop setup
	var layout_type := data.get("layout_type", -1) as int
	generate_terrain_suggestions(layout_type)

## Setup crew selection
func setup_crew_selection(available_crew: Array[Character]) -> void:
	if not crew_selection_panel:
		return

	var crew_list := VBoxContainer.new()

	for character in available_crew:
		var char_button := Button.new()
		char_button.text = character.character_name
		char_button.toggle_mode = true
		char_button.pressed.connect(_on_character_selected.bind(character))
		crew_list.add_child(char_button)

	crew_selection_panel.add_child(crew_list)

## Handle character selection
func _on_character_selected(character: Character) -> void:
	if not selected_crew:
		selected_crew = []

	if selected_crew.has(character):
		selected_crew.erase(character)
	else:
		selected_crew.append(character)

	crew_selected.emit(selected_crew) # warning: return value discarded (intentional)
	_update_confirm_button()

## Handle terrain generation completion
func _on_terrain_generated(_terrain_data: Dictionary) -> void:
	terrain_ready.emit() # warning: return value discarded (intentional)
	_update_confirm_button()

## Handle confirm button press
func _on_confirm_pressed() -> void:
	deployment_confirmed.emit() # warning: return value discarded (intentional)

## Update confirm button state
func _update_confirm_button() -> void:
	if not confirm_button:
		return

	confirm_button.disabled = selected_crew.is_empty() or not terrain_system or not terrain_system and terrain_system.has_method("is_terrain_ready") or not terrain_system.is_terrain_ready()

## Get selected crew
func get_selected_crew() -> Array[Character]:
	return selected_crew

## Cleanup
func cleanup() -> void:
	selected_crew.clear()
	current_mission = null

	if terrain_system and terrain_system.has_method("cleanup"):
		terrain_system.cleanup()

	# Clear terrain suggestions
	_clear_terrain_suggestions()

	# Clear UI panels
	if mission_info_panel:
		for child in mission_info_panel.get_children():
			child.queue_free()
	if enemy_info_panel:
		for child in enemy_info_panel.get_children():
			child.queue_free()
	if crew_selection_panel:
		for child in crew_selection_panel.get_children():
			child.queue_free()
	if deployment_panel:
		for child in deployment_panel.get_children():
			child.queue_free()

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

# =====================================================
# D100 PRE-BATTLE TABLES
# =====================================================

## D100 Deployment Conditions table (Core Rules p.XX)
const DEPLOYMENT_CONDITIONS := {
	# 01-20: No special conditions
	1: {"name": "No Special Conditions", "effect": "Standard deployment rules apply", "range": [1, 20]},
	# 21-30: Poor Visibility
	21: {"name": "Poor Visibility", "effect": "Maximum visibility 12\". All shots beyond 12\" impossible.", "range": [21, 30]},
	# 31-40: Brief Engagement
	31: {"name": "Brief Engagement", "effect": "Battle ends after 4 rounds regardless of victory conditions.", "range": [31, 40]},
	# 41-50: Toxic Environment
	41: {"name": "Toxic Environment", "effect": "Characters not in cover at end of round take 1 Stun hit.", "range": [41, 50]},
	# 51-60: Defensive Position
	51: {"name": "Defensive Position", "effect": "Enemy deploys first and cannot move on first round.", "range": [51, 60]},
	# 61-70: Exposed Position
	61: {"name": "Exposed Position", "effect": "Crew must deploy within 3\" of table edge.", "range": [61, 70]},
	# 71-80: Reinforcements
	71: {"name": "Reinforcements", "effect": "D6 additional enemies arrive at end of round 3.", "range": [71, 80]},
	# 81-90: Delayed Arrival
	81: {"name": "Delayed Arrival", "effect": "Half crew (round up) cannot deploy until round 2.", "range": [81, 90]},
	# 91-100: Surprise Attack
	91: {"name": "Surprise Attack", "effect": "Crew gets a free round of actions before enemies activate.", "range": [91, 100]}
}

## D100 Notable Sights table (Core Rules p.XX)
const NOTABLE_SIGHTS := {
	# 01-15: Nothing of interest
	1: {"name": "Nothing of Interest", "effect": "No special features.", "range": [1, 15]},
	# 16-25: Loot Cache
	16: {"name": "Loot Cache", "effect": "Place loot token in center. First to reach it gains 1 Credit.", "range": [16, 25]},
	# 26-35: Wounded Civilian
	26: {"name": "Wounded Civilian", "effect": "Civilian in center needs escort off table. Gain 1 Story Point if saved.", "range": [26, 35]},
	# 36-45: Abandoned Equipment
	36: {"name": "Abandoned Equipment", "effect": "Roll on Loot Table for free item at battle end.", "range": [36, 45]},
	# 46-55: Tactical Advantage
	46: {"name": "Tactical Advantage", "effect": "Place 2 additional cover pieces anywhere on the field.", "range": [46, 55]},
	# 56-65: Hazardous Materials
	56: {"name": "Hazardous Materials", "effect": "D3 terrain pieces become dangerous. Contact causes 1 hit.", "range": [56, 65]},
	# 66-75: High Ground
	66: {"name": "High Ground", "effect": "Place elevated position. +1 to hit when shooting from it.", "range": [66, 75]},
	# 76-85: Communications Array
	76: {"name": "Communications Array", "effect": "Control it at battle end for +1 to next mission roll.", "range": [76, 85]},
	# 86-95: Rival Intel
	86: {"name": "Rival Intel", "effect": "Datapad in center. Retrieve for intel on one Rival.", "range": [86, 95]},
	# 96-100: Mysterious Artifact
	96: {"name": "Mysterious Artifact", "effect": "Precursor item. Roll on special loot table.", "range": [96, 100]}
}

## Roll on D100 Deployment Conditions table
func roll_deployment_conditions() -> Dictionary:
	var roll := randi_range(1, 100)
	for key in DEPLOYMENT_CONDITIONS:
		var condition: Dictionary = DEPLOYMENT_CONDITIONS[key]
		if roll >= condition.range[0] and roll <= condition.range[1]:
			return {"roll": roll, "name": condition.name, "effect": condition.effect}
	return {"roll": roll, "name": "No Special Conditions", "effect": "Standard deployment rules apply"}

## Roll on D100 Notable Sights table
func roll_notable_sights() -> Dictionary:
	var roll := randi_range(1, 100)
	for key in NOTABLE_SIGHTS:
		var sight: Dictionary = NOTABLE_SIGHTS[key]
		if roll >= sight.range[0] and roll <= sight.range[1]:
			return {"roll": roll, "name": sight.name, "effect": sight.effect}
	return {"roll": roll, "name": "Nothing of Interest", "effect": "No special features."}

## Display pre-battle rolls in mission info panel
func display_prebattle_rolls() -> void:
	# Roll on tables
	var deployment := roll_deployment_conditions()
	var sights := roll_notable_sights()

	# Update deployment condition label (from scene)
	if deployment_condition_label:
		deployment_condition_label.text = "Deployment [%d]: %s\n%s" % [deployment.roll, deployment.name, deployment.effect]
		deployment_condition_label.add_theme_color_override("font_color", COLOR_CYAN)

	# Update notable sights label (from scene)
	if notable_sights_label:
		notable_sights_label.text = "Notable Sight [%d]: %s\n%s" % [sights.roll, sights.name, sights.effect]
		notable_sights_label.add_theme_color_override("font_color", COLOR_AMBER)

	print("PreBattleUI: Rolled Deployment [%d] %s, Notable Sights [%d] %s" % [deployment.roll, deployment.name, sights.roll, sights.name])

## Display initiative roll result
func display_initiative_result(seized: bool, roll_result: int, savvy_bonus: int) -> void:
	if not initiative_result_label:
		return

	var result_text := "Initiative: %d (2D6 + %d Savvy) - %s" % [
		roll_result, savvy_bonus,
		"SEIZED!" if seized else "Failed"
	]

	initiative_result_label.text = result_text
	if seized:
		initiative_result_label.add_theme_color_override("font_color", COLOR_EMERALD)
	else:
		initiative_result_label.add_theme_color_override("font_color", COLOR_AMBER)

# =====================================================
# TERRAIN SUGGESTION SYSTEM
# =====================================================

## Setup terrain suggestions UI container
func _setup_terrain_suggestions_ui() -> void:
	# Terrain suggestions container is now in the scene as %TerrainSuggestionsList
	# Just initialize the generator if needed
	if not terrain_layout_generator:
		terrain_layout_generator = Node.new()
		terrain_layout_generator.name = "TerrainLayoutGenerator"
		add_child(terrain_layout_generator)

## Generate terrain suggestions based on mission/battlefield type
func generate_terrain_suggestions(layout_type: int = -1) -> void:
	# Clear existing suggestions
	_clear_terrain_suggestions()

	# Determine layout type from mission or use random
	if layout_type < 0:
		layout_type = randi() % 5  # Random from 5 layout types

	# Generate 6-8 terrain pieces per Five Parsecs rules
	var piece_count := randi_range(6, 8)

	terrain_suggestions = []
	for i in range(piece_count):
		var suggestion := _generate_terrain_suggestion(i, layout_type)
		terrain_suggestions.append(suggestion)

	# Display the suggestions
	_display_terrain_suggestions()
	terrain_suggestions_generated.emit(terrain_suggestions)

## Generate a single terrain suggestion
func _generate_terrain_suggestion(index: int, layout_type: int) -> Dictionary:
	# Terrain types based on Five Parsecs rules
	var terrain_types := ["cover", "cover", "cover", "elevation", "difficult", "special"]
	var terrain_type: String = terrain_types[index % terrain_types.size()]

	# Determine priority (first 3 are required, rest recommended)
	var priority := 1 if index < 3 else 2

	# Generate description based on type
	var descriptions := {
		"cover": ["Stone wall or metal barrier", "Shipping containers", "Rocky outcrop", "Ruined building section", "Cargo crates"],
		"elevation": ["Elevated platform", "Building roof access", "Hill or ridge", "Watchtower"],
		"difficult": ["Rubble field", "Dense vegetation", "Water feature", "Crater"],
		"special": ["Objective marker", "Power generator", "Communications relay", "Supply cache"]
	}

	var type_descriptions: Array = descriptions.get(terrain_type, ["Generic terrain"])
	var visual_description: String = type_descriptions[randi() % type_descriptions.size()]

	# Generate placement based on layout type
	var placement := _get_placement_description(index, layout_type)

	# Generate game effects
	var effects := _get_terrain_effects(terrain_type)

	# Suggested models
	var models := _get_suggested_models(terrain_type)

	return {
		"suggestion_id": "terrain_%d" % index,
		"terrain_type": terrain_type,
		"visual_description": visual_description,
		"placement_description": placement,
		"game_effects": effects,
		"suggested_models": models,
		"priority": priority,
		"estimated_footprint": Vector2(3, 3),
		"alternative_options": []
	}

## Get placement description based on layout and index
func _get_placement_description(index: int, layout_type: int) -> String:
	var positions := ["Center battlefield", "North edge", "South edge", "East quarter", "West quarter", "Northeast corner", "Southwest corner", "Between deployment zones"]

	# Layout-specific placements
	match layout_type:
		0:  # OPEN - sparse, spread out
			return "Spread placement - %s" % positions[index % positions.size()]
		1:  # DENSE - clustered
			return "Clustered placement - %s area" % ["center", "north", "south"][index % 3]
		2:  # ASYMMETRIC
			if index < 4:
				return "Dense side (left half) - %s" % positions[index % 4]
			else:
				return "Open side (right half) - %s" % positions[index % 4]
		3:  # CORRIDOR
			return "Along corridor path - position %d" % (index + 1)
		4:  # SCATTERED
			return "Random scatter - %s" % positions[index % positions.size()]

	return positions[index % positions.size()]

## Get game effects for terrain type
func _get_terrain_effects(terrain_type: String) -> Array:
	match terrain_type:
		"cover":
			return ["Blocks line of sight", "Provides cover bonus (+2 to hit)", "Can be positioned behind for protection"]
		"elevation":
			return ["Height advantage for shooting", "May block LOS from below", "Climbing costs extra movement"]
		"difficult":
			return ["Halves movement speed", "No cover bonus", "May cause additional effects"]
		"special":
			return ["Mission-specific effects", "May be objective", "Check mission briefing"]
		_:
			return ["Standard terrain effects"]

## Get suggested models for terrain type
func _get_suggested_models(terrain_type: String) -> Array:
	match terrain_type:
		"cover":
			return ["Walls", "Barriers", "Crates", "Rubble"]
		"elevation":
			return ["Platforms", "Hills", "Buildings", "Towers"]
		"difficult":
			return ["Debris", "Vegetation", "Water", "Craters"]
		"special":
			return ["Objectives", "Generators", "Terminals"]
		_:
			return ["Generic terrain"]

## Display terrain suggestions in UI
func _display_terrain_suggestions() -> void:
	if not terrain_suggestions_container:
		return

	# Clear existing items
	for item in terrain_suggestion_items:
		if is_instance_valid(item):
			item.queue_free()
	terrain_suggestion_items.clear()
	confirmed_suggestions.clear()

	# Create suggestion items
	for suggestion in terrain_suggestions:
		var item: Control = TerrainSuggestionItemScene.instantiate()
		terrain_suggestions_container.add_child(item)
		terrain_suggestion_items.append(item)

		# Setup the suggestion data
		if item.has_method("setup_suggestion"):
			item.setup_suggestion(suggestion)

		# Connect signals
		if item.has_signal("suggestion_confirmed"):
			item.suggestion_confirmed.connect(_on_terrain_suggestion_confirmed)
		if item.has_signal("suggestion_modified"):
			item.suggestion_modified.connect(_on_terrain_suggestion_modified)
		if item.has_signal("suggestion_rejected"):
			item.suggestion_rejected.connect(_on_terrain_suggestion_rejected)

## Handle terrain suggestion confirmation
func _on_terrain_suggestion_confirmed(suggestion_id: String) -> void:
	if suggestion_id not in confirmed_suggestions:
		confirmed_suggestions.append(suggestion_id)
	print("PreBattleUI: Terrain suggestion confirmed - %s (%d/%d)" % [suggestion_id, confirmed_suggestions.size(), terrain_suggestions.size()])

	# Check if all required suggestions are confirmed
	_check_all_terrain_confirmed()

## Handle terrain suggestion modification
func _on_terrain_suggestion_modified(suggestion_id: String, modifications: Dictionary) -> void:
	print("PreBattleUI: Terrain suggestion modified - %s: %s" % [suggestion_id, str(modifications)])

	# Find and update the suggestion
	for i in range(terrain_suggestions.size()):
		if terrain_suggestions[i].suggestion_id == suggestion_id:
			t