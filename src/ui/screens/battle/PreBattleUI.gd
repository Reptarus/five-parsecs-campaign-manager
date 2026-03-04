## PreBattleUI manages the pre-battle setup interface
# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Control


## Dependencies
const StoryQuestData = preload("res://src/core/story/StoryQuestData.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const UnifiedTerrainSystem = preload("res://src/core/terrain/UnifiedTerrainSystem.gd")

## Optional dependencies that may not exist
var _terrain_system_script = preload("res://src/core/terrain/UnifiedTerrainSystem.gd") if FileAccess.file_exists("res://src/core/terrain/UnifiedTerrainSystem.gd") else null

## Signals
signal crew_selected(crew: Array)
signal deployment_confirmed
signal terrain_ready
signal preview_updated
signal back_pressed

## Node references
@onready var mission_info_panel = $MarginContainer/VBoxContainer/MainContent/LeftPanel/MissionInfo/VBoxContainer/Content
@onready var enemy_info_panel = $MarginContainer/VBoxContainer/MainContent/LeftPanel/EnemyInfo/VBoxContainer/Content
@onready var battlefield_preview = $MarginContainer/VBoxContainer/MainContent/CenterPanel/BattlefieldPreview/VBoxContainer/PreviewContent
@onready var crew_selection_panel = $MarginContainer/VBoxContainer/MainContent/RightPanel/CrewSelection/VBoxContainer/ScrollContainer/Content
@onready var confirm_button = $MarginContainer/VBoxContainer/FooterPanel/HBoxContainer/ConfirmButton
@onready var back_button = $MarginContainer/VBoxContainer/FooterPanel/HBoxContainer/BackButton

## State
var current_mission: StoryQuestData
var selected_crew: Array = []
var terrain_system: Node # Will be cast to UnifiedTerrainSystem if available

func _ready() -> void:
	_initialize_systems()
	_connect_signals()
	confirm_button.disabled = true

## Initialize required systems
func _initialize_systems() -> void:
	if _terrain_system_script:
		terrain_system = _terrain_system_script.new()
		if battlefield_preview:
			battlefield_preview.add_child(terrain_system)
			if terrain_system.has_signal("terrain_generated"):
				terrain_system.terrain_generated.connect(_on_terrain_generated)

## Connect UI signals
func _connect_signals() -> void:
	if confirm_button and not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	back_pressed.emit()

## Accept deployment condition data and display in mission panel
func set_deployment_condition(condition: Dictionary) -> void:
	if not condition or condition.is_empty():
		return
	if not mission_info_panel:
		return

	var separator := HSeparator.new()
	mission_info_panel.add_child(separator)

	var header := Label.new()
	header.text = "Deployment Condition"
	header.add_theme_font_size_override("font_size", 16)
	mission_info_panel.add_child(header)

	var title := Label.new()
	title.text = condition.get("title", "Unknown")
	mission_info_panel.add_child(title)

	var desc := Label.new()
	desc.text = condition.get("description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_info_panel.add_child(desc)

	var summary: String = condition.get(
		"effects_summary", "")
	if summary != "":
		var effects_label := Label.new()
		effects_label.text = summary
		effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mission_info_panel.add_child(effects_label)

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

	var mission_desc := Label.new()
	mission_desc.text = data.get("description", "No description available")

	var battle_type := Label.new()
	battle_type.text = "Battle Type: " + GlobalEnums.BattleType.keys()[data.get("battle_type", 0)]

	mission_info_panel.add_child(mission_title)
	mission_info_panel.add_child(mission_desc)
	mission_info_panel.add_child(battle_type)

## Setup enemy information
func _setup_enemy_info(data: Dictionary) -> void:
	if not enemy_info_panel:
		return

	var enemy_force = data.get("enemy_force", {})
	var enemy_list := VBoxContainer.new()

	for unit in enemy_force.get("units", []):
		var unit_label := Label.new()
		unit_label.text = unit.get("type", "Unknown Unit")
		enemy_list.add_child(unit_label)

	enemy_info_panel.add_child(enemy_list)

## Setup battlefield preview
func _setup_battlefield_preview(data: Dictionary) -> void:
	if not battlefield_preview:
		return

	# If terrain system is available, use it
	if terrain_system and terrain_system.has_method("generate_battlefield"):
		terrain_system.generate_battlefield(data)
		return

	# Fallback: show terrain suggestions as formatted text
	var terrain_data: Dictionary = data.get("terrain", {})
	# Also try loading from GameState battlefield data
	if terrain_data.is_empty():
		var game_state = get_node_or_null("/root/GameState")
		if game_state and game_state.has_method("get_battlefield_data"):
			var bf_data: Dictionary = game_state.get_battlefield_data()
			terrain_data = bf_data.get("terrain", bf_data)

	if terrain_data.is_empty():
		var placeholder := Label.new()
		placeholder.text = "Terrain suggestions not available.\nSet up terrain on your physical table as desired."
		placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		placeholder.add_theme_color_override("font_color", Color("#9ca3af"))
		placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
		battlefield_preview.add_child(placeholder)
		return

	# Render terrain suggestions as text
	var terrain_log := RichTextLabel.new()
	terrain_log.bbcode_enabled = true
	terrain_log.fit_content = true
	terrain_log.set_anchors_preset(Control.PRESET_FULL_RECT)
	terrain_log.add_theme_color_override("default_color", Color("#f3f4f6"))
	terrain_log.add_theme_font_size_override("normal_font_size", 14)

	var bbcode: String = "[b]Terrain Setup Guide[/b]\n\n"

	# Theme
	var theme_name: String = terrain_data.get("theme", "")
	if theme_name != "":
		bbcode += "[color=#f59e0b]Theme:[/color] %s\n\n" % theme_name

	# Sectors
	var sectors: Dictionary = terrain_data.get("sectors", {})
	if not sectors.is_empty():
		for sector_key in sectors:
			var sector_info = sectors[sector_key]
			var desc: String = sector_info if sector_info is String else str(sector_info)
			bbcode += "[color=#3b82f6]%s:[/color] %s\n" % [sector_key, desc]
	elif terrain_data.has("suggestions"):
		# Array of suggestion strings
		var suggestions: Array = terrain_data.get("suggestions", [])
		for suggestion in suggestions:
			bbcode += "- %s\n" % str(suggestion)
	elif terrain_data.has("description"):
		bbcode += str(terrain_data["description"])

	terrain_log.text = bbcode
	battlefield_preview.add_child(terrain_log)

## Setup crew selection — accepts both Character objects and Dictionaries
func setup_crew_selection(available_crew: Array) -> void:
	if not crew_selection_panel:
		return

	var crew_list := VBoxContainer.new()

	for item in available_crew:
		var char_button := Button.new()
		if item is Character:
			char_button.text = item.name
		elif item is Dictionary:
			char_button.text = item.get("name", item.get("character_name", "Unknown"))
		else:
			char_button.text = str(item)
		char_button.toggle_mode = true
		char_button.pressed.connect(_on_character_selected.bind(item))
		crew_list.add_child(char_button)

	crew_selection_panel.add_child(crew_list)

## Handle character selection
func _on_character_selected(character) -> void:
	if selected_crew.has(character):
		selected_crew.erase(character)
	else:
		selected_crew.append(character)

	crew_selected.emit(selected_crew)
	_update_confirm_button()

## Handle terrain generation completion
func _on_terrain_generated(_terrain_data: Dictionary) -> void:
	terrain_ready.emit()
	_update_confirm_button()

## Handle confirm button press
func _on_confirm_pressed() -> void:
	deployment_confirmed.emit()

## Update confirm button state
func _update_confirm_button() -> void:
	if not confirm_button:
		return

	# Require crew selection; terrain system is optional (text fallback exists)
	var terrain_ok: bool = true
	if terrain_system and terrain_system.has_method("is_terrain_ready"):
		terrain_ok = terrain_system.is_terrain_ready()
	confirm_button.disabled = selected_crew.is_empty() or not terrain_ok

## Get selected crew
func get_selected_crew() -> Array:
	return selected_crew

## Cleanup
func cleanup() -> void:
	selected_crew.clear()
	current_mission = null

	if terrain_system and terrain_system.has_method("cleanup"):
		terrain_system.cleanup()

	# Clear UI panels
	for child in mission_info_panel.get_children():
		child.queue_free()
	for child in enemy_info_panel.get_children():
		child.queue_free()
	for child in crew_selection_panel.get_children():
		child.queue_free()
