## PreBattleUI manages the pre-battle setup interface
# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Control


## Dependencies
const StoryQuestData = preload("res://src/core/story/StoryQuestData.gd")
const UnifiedTerrainSystem = preload("res://src/core/terrain/UnifiedTerrainSystem.gd")

## Optional dependencies that may not exist
var _terrain_system_script = preload("res://src/core/terrain/UnifiedTerrainSystem.gd") if ResourceLoader.exists("res://src/core/terrain/UnifiedTerrainSystem.gd") else null

## Signals
signal crew_selected(crew: Array)
signal deployment_confirmed
signal terrain_ready
signal preview_updated
signal back_pressed

## Tracking tier selection (moved here from TacticalBattleUI overlay)
## 0 = LOG_ONLY, 1 = ASSISTED, 2 = FULL_ORACLE
var selected_tier: int = 0

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
var _max_deploy: int = 6  # Campaign crew size deployment limit (Core Rules p.63/85)
var _deploy_label: Label  # "Deploying X / Y max" display

func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base

func _ready() -> void:
	_apply_base_background()
	_initialize_systems()
	_connect_signals()
	confirm_button.disabled = true

## Apply the Deep Space COLOR_BASE background behind this panel
func _apply_base_background() -> void:
	var bg := ColorRect.new()
	bg.name = "__phase_bg"
	bg.color = Color("#1A1A2E")  # COLOR_BASE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	add_child(bg)
	move_child(bg, 0)

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
	header.add_theme_font_size_override("font_size", _scaled_font(16))
	mission_info_panel.add_child(header)

	var title := Label.new()
	title.text = condition.get("title", "Unknown")
	title.add_theme_font_size_override("font_size", _scaled_font(16))
	title.add_theme_color_override(
		"font_color", Color("#D97706"))
	mission_info_panel.add_child(title)

	# Show canonical rule text from Core Rules p.88
	var desc := Label.new()
	desc.text = condition.get("description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", _scaled_font(14))
	mission_info_panel.add_child(desc)

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

	# Initiative context summary (pre-computed by CampaignTurnController)
	var init_ctx: Dictionary = data.get("initiative_context", {})
	if not init_ctx.is_empty():
		var sep := HSeparator.new()
		mission_info_panel.add_child(sep)
		var init_header := Label.new()
		init_header.text = "Seize the Initiative"
		init_header.add_theme_font_size_override("font_size", _scaled_font(16))
		mission_info_panel.add_child(init_header)
		var init_info := Label.new()
		var prob: float = init_ctx.get("success_probability", 0.0)
		init_info.text = "Need %d+ on 2D6 (Savvy +%d) — %.0f%% chance" % [
			init_ctx.get("required_roll", 10),
			init_ctx.get("highest_savvy", 0),
			prob * 100.0]
		init_info.add_theme_font_size_override("font_size", _scaled_font(14))
		init_info.add_theme_color_override("font_color", Color("#4FC3F7"))
		init_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mission_info_panel.add_child(init_info)

	# Tier selector — player picks tracking level before combat starts
	var tier_sep := HSeparator.new()
	mission_info_panel.add_child(tier_sep)
	_build_tier_selector()

## Setup enemy information — Core Rules table format (pp.91-94)
func _setup_enemy_info(data: Dictionary) -> void:
	if not enemy_info_panel:
		return

	var enemy_force: Dictionary = data.get("enemy_force", {})
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	# ── Table header: "Enemy Forces" ──
	var title := Label.new()
	title.text = "Enemy Forces"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _scaled_font(16))
	container.add_child(title)

	# ── Stat table (GridContainer, 8 columns) ──
	var table_panel := PanelContainer.new()
	var table_style := StyleBoxFlat.new()
	table_style.bg_color = Color("#252542")  # COLOR_ELEVATED
	table_style.border_color = Color("#3A3A5C")  # COLOR_BORDER
	table_style.set_border_width_all(1)
	table_style.set_corner_radius_all(4)
	table_style.set_content_margin_all(4)
	table_panel.add_theme_stylebox_override("panel", table_style)

	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Header row
	var headers := ["ENEMY", "NUMBERS", "PANIC", "SPEED",
		"CMB", "TGH", "AI", "WEAPONS"]
	for h in headers:
		var lbl := Label.new()
		lbl.text = h
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", _scaled_font(10))
		lbl.add_theme_color_override("font_color", Color("#808080"))
		grid.add_child(lbl)

	# Data row
	var type_name: String = enemy_force.get("type", "")
	if type_name.is_empty():
		type_name = data.get("enemy_type",
			data.get("enemy_faction", "Unknown"))

	var spd: int = enemy_force.get("speed", 0)
	var cmb: int = enemy_force.get("combat_skill", 0)
	var tgh: int = enemy_force.get("toughness", 0)
	var numbers_str: String = str(enemy_force.get("numbers", ""))
	var panic_str: String = str(enemy_force.get("panic", ""))
	var ai_str: String = str(enemy_force.get("ai", ""))
	var weapons_val = enemy_force.get("weapons", "")
	var weapons_str: String = ""
	if weapons_val is Array:
		weapons_str = ", ".join(
			weapons_val.map(func(w): return str(w)))
	else:
		weapons_str = str(weapons_val)

	var cmb_str := "+%d" % cmb if cmb >= 0 else str(cmb)
	var values := [type_name, numbers_str, panic_str,
		'%d"' % spd, cmb_str, str(tgh), ai_str, weapons_str]

	for i in range(values.size()):
		var lbl := Label.new()
		lbl.text = values[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", _scaled_font(13))
		if i == 0:
			# Enemy name in red
			lbl.add_theme_color_override(
				"font_color", Color("#DC2626"))
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		else:
			lbl.add_theme_color_override(
				"font_color", Color("#4FC3F7"))
		grid.add_child(lbl)

	table_panel.add_child(grid)
	container.add_child(table_panel)

	# ── Count ──
	var total: int = enemy_force.get("count",
		data.get("enemy_count", 0))
	if total > 0:
		var count_lbl := Label.new()
		count_lbl.text = "Count: %d" % total
		count_lbl.add_theme_font_size_override("font_size", _scaled_font(13))
		container.add_child(count_lbl)

	# ── Special rules ──
	var rules: Array = enemy_force.get("special_rules", [])
	for rule in rules:
		var rule_lbl := Label.new()
		rule_lbl.text = str(rule)
		rule_lbl.add_theme_font_size_override("font_size", _scaled_font(12))
		rule_lbl.add_theme_color_override(
			"font_color", Color("#D97706"))
		rule_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(rule_lbl)

	enemy_info_panel.add_child(container)

## Setup battlefield preview
func _setup_battlefield_preview(data: Dictionary) -> void:
	if not battlefield_preview:
		return

	# If terrain system is available, use it
	if terrain_system and terrain_system.has_method("generate_battlefield"):
		terrain_system.generate_battlefield(data)
		return

	# Gather terrain data from preview data or GameState
	var terrain_data: Dictionary = data.get("terrain", {})
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

	var theme_name: String = terrain_data.get("theme", terrain_data.get("theme_name", ""))

	# Try to extract sector data for the visual map view
	var sector_array: Array = _extract_sector_array(terrain_data)
	if not sector_array.is_empty():
		# Use BattlefieldMapView for visual overhead grid
		var map_view := BattlefieldMapView.new()
		map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
		map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var world_traits: Array = terrain_data.get("world_traits", [])
		map_view.populate_from_sectors(sector_array, theme_name, world_traits)
		battlefield_preview.add_child(map_view)

		# Store terrain data for passthrough to post-battle
		_store_terrain_for_passthrough(sector_array, theme_name)
		return

	# Fallback: render terrain suggestions as text
	_setup_text_terrain_fallback(terrain_data, theme_name)

## Extract sector data into the Array format BattlefieldMapView expects.
## Handles both dict-keyed sectors and pre-formatted sector arrays.
func _extract_sector_array(terrain_data: Dictionary) -> Array:
	# Format A: sectors as Array of {label, features}
	if terrain_data.has("sector_list"):
		var sector_list = terrain_data.get("sector_list", [])
		if sector_list is Array and not sector_list.is_empty():
			return sector_list

	# Format B: sectors as Dictionary {label: features_or_description}
	var sectors = terrain_data.get("sectors", {})
	if sectors is Dictionary and not sectors.is_empty():
		var result: Array = []
		for sector_key: String in sectors:
			var sector_info = sectors[sector_key]
			var features: Array = []
			if sector_info is Array:
				features = sector_info
			elif sector_info is String:
				# Single description string — split on comma or use as-is
				if ", " in sector_info:
					features = sector_info.split(", ")
				else:
					features = [sector_info]
			elif sector_info is Dictionary:
				features = sector_info.get("features", [])
			result.append({"label": sector_key, "features": features})
		return result

	return []

## Store terrain data in GameState temp_data for post-battle passthrough
func _store_terrain_for_passthrough(sectors: Array, theme_name: String) -> void:
	var game_state = get_node_or_null("/root/GameState")
	if game_state and "temp_data" in game_state:
		game_state.temp_data["battlefield_terrain"] = {
			"sectors": sectors,
			"theme_name": theme_name
		}

## Text fallback for terrain data without structured sectors
func _setup_text_terrain_fallback(terrain_data: Dictionary, theme_name: String) -> void:
	var terrain_log := RichTextLabel.new()
	terrain_log.bbcode_enabled = true
	terrain_log.fit_content = true
	terrain_log.set_anchors_preset(Control.PRESET_FULL_RECT)
	terrain_log.add_theme_color_override("default_color", Color("#f3f4f6"))
	terrain_log.add_theme_font_size_override("normal_font_size", _scaled_font(14))

	var bbcode: String = "[b]Terrain Setup Guide[/b]\n\n"
	if theme_name != "":
		bbcode += "[color=#f59e0b]Theme:[/color] %s\n\n" % theme_name

	if terrain_data.has("suggestions"):
		var suggestions: Array = terrain_data.get("suggestions", [])
		for suggestion in suggestions:
			bbcode += "- %s\n" % str(suggestion)
	elif terrain_data.has("description"):
		bbcode += str(terrain_data["description"])

	terrain_log.text = bbcode
	battlefield_preview.add_child(terrain_log)

## Setup crew selection — accepts both Character objects and Dictionaries
## max_deploy: deployment cap from campaign crew size setting (Core Rules p.63/85)
func setup_crew_selection(
	available_crew: Array, max_deploy: int = 6
) -> void:
	if not crew_selection_panel:
		return
	_max_deploy = max_deploy

	var crew_list := VBoxContainer.new()

	# Deployment counter label
	_deploy_label = Label.new()
	_deploy_label.add_theme_font_size_override("font_size", 14)
	_deploy_label.add_theme_color_override(
		"font_color", Color("#4FC3F7"))
	crew_list.add_child(_deploy_label)

	for item in available_crew:
		var char_button := Button.new()
		if item is Character:
			char_button.text = item.name
		elif item is Dictionary:
			char_button.text = item.get(
				"name", item.get("character_name", "Unknown"))
		else:
			char_button.text = str(item)
		char_button.toggle_mode = true
		# Style the pressed/selected state
		var pressed_style := StyleBoxFlat.new()
		pressed_style.bg_color = Color("#2D5A7B")
		pressed_style.border_color = Color("#4FC3F7")
		pressed_style.set_border_width_all(2)
		pressed_style.set_corner_radius_all(8)
		char_button.add_theme_stylebox_override("pressed", pressed_style)
		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color("#1E1E36")
		normal_style.border_color = Color("#3A3A5C")
		normal_style.set_border_width_all(1)
		normal_style.set_corner_radius_all(8)
		char_button.pressed.connect(
			_on_character_selected.bind(item, char_button))
		crew_list.add_child(char_button)
		# Pre-select up to max_deploy crew members
		if selected_crew.size() < _max_deploy:
			char_button.button_pressed = true
			selected_crew.append(item)

	crew_selection_panel.add_child(crew_list)
	_update_deploy_label()
	crew_selected.emit(selected_crew)
	_update_confirm_button()

## Handle character selection with deployment limit enforcement
func _on_character_selected(character, button: Button = null) -> void:
	if selected_crew.has(character):
		selected_crew.erase(character)
	else:
		# Enforce deployment cap (Core Rules p.63/85)
		if selected_crew.size() >= _max_deploy:
			# Revert toggle — at deployment limit
			if button:
				button.button_pressed = false
			return
		selected_crew.append(character)

	_update_deploy_label()
	crew_selected.emit(selected_crew)
	_update_confirm_button()

func _update_deploy_label() -> void:
	if _deploy_label:
		_deploy_label.text = "Deploying %d / %d max" % [
			selected_crew.size(), _max_deploy]

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

## Build the tracking tier radio buttons (LOG_ONLY / ASSISTED / FULL_ORACLE)
func _build_tier_selector() -> void:
	if not mission_info_panel:
		return

	var header := Label.new()
	header.text = "Tracking Level"
	header.add_theme_font_size_override("font_size", _scaled_font(16))
	mission_info_panel.add_child(header)

	var desc := Label.new()
	desc.text = "How much should the app track for you?"
	desc.add_theme_font_size_override("font_size", _scaled_font(12))
	desc.add_theme_color_override("font_color", Color("#808080"))
	mission_info_panel.add_child(desc)

	var tier_names: Array[String] = [
		"Log Only — manual play, dice journal",
		"Assisted — auto-roll + guidance overlays",
		"Full Oracle — AI runs enemy turns",
	]
	var button_group := ButtonGroup.new()
	for i in range(tier_names.size()):
		var radio := CheckBox.new()
		radio.text = tier_names[i]
		radio.button_group = button_group
		radio.add_theme_font_size_override("font_size", _scaled_font(14))
		radio.custom_minimum_size.y = 40  # Touch-friendly
		if i == 0:
			radio.button_pressed = true  # Default to LOG_ONLY
		radio.pressed.connect(_on_tier_radio_pressed.bind(i))
		mission_info_panel.add_child(radio)

func _on_tier_radio_pressed(tier: int) -> void:
	selected_tier = tier

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
	for child in battlefield_preview.get_children():
		if not child == terrain_system:
			child.queue_free()
	for child in crew_selection_panel.get_children():
		child.queue_free()
