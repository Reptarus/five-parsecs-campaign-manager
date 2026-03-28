extends Control

## Single-screen Battle Simulator setup panel.
## Lets the player configure crew size, enemy type, mission, and difficulty
## before launching a standalone battle.

signal launch_requested(config: Dictionary)

# Deep Space theme
const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_INPUT := Color("#1E1E36")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_ACCENT_HOVER := Color("#3A7199")
const COLOR_FOCUS := Color("#4FC3F7")
const COLOR_TEXT := Color("#E0E0E0")
const COLOR_TEXT_SEC := Color("#808080")
const COLOR_SUCCESS := Color("#10B981")

const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24
const SPACING_XL := 32
const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18
const FONT_SIZE_XL := 24
const TOUCH_TARGET := 48

var _setup: BattleSimulatorSetup
var _crew_size_spin: SpinBox
var _category_dropdown: OptionButton
var _enemy_dropdown: OptionButton
var _mission_dropdown: OptionButton
var _difficulty_dropdown: OptionButton
var _enemy_preview: RichTextLabel
var _crew_preview: RichTextLabel
var _launch_button: Button

var _categories: Array = []
var _current_config: Dictionary = {
	"crew_size": 4,
	"enemy_category": "random",
	"enemy_type": "random",
	"mission_type": "RANDOM",
	"difficulty": 2,
}


func _ready() -> void:
	_setup = BattleSimulatorSetup.new()
	_categories = _setup.get_enemy_categories()
	_build_ui()
	_refresh_enemy_dropdown()
	_refresh_previews()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(vbox)

	# --- Crew Section ---
	var crew_card := _create_card("YOUR CREW", vbox)
	var crew_content := crew_card.get_meta("content") as VBoxContainer

	var crew_row := HBoxContainer.new()
	crew_row.add_theme_constant_override("separation", SPACING_MD)
	crew_content.add_child(crew_row)

	var crew_label := Label.new()
	crew_label.text = "Crew Size:"
	crew_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	crew_label.add_theme_color_override("font_color", COLOR_TEXT)
	crew_row.add_child(crew_label)

	_crew_size_spin = SpinBox.new()
	_crew_size_spin.min_value = 3
	_crew_size_spin.max_value = 6
	_crew_size_spin.value = 4
	_crew_size_spin.step = 1
	_crew_size_spin.custom_minimum_size = Vector2(120, TOUCH_TARGET)
	_crew_size_spin.value_changed.connect(_on_crew_size_changed)
	crew_row.add_child(_crew_size_spin)

	var reroll_btn := Button.new()
	reroll_btn.text = "Reroll Names"
	reroll_btn.custom_minimum_size = Vector2(140, TOUCH_TARGET)
	reroll_btn.pressed.connect(_on_reroll_pressed)
	crew_row.add_child(reroll_btn)

	_crew_preview = RichTextLabel.new()
	_crew_preview.bbcode_enabled = true
	_crew_preview.fit_content = true
	_crew_preview.custom_minimum_size = Vector2(0, 80)
	_crew_preview.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	_crew_preview.add_theme_color_override("default_color", COLOR_TEXT_SEC)
	crew_content.add_child(_crew_preview)

	# --- Enemy Section ---
	var enemy_card := _create_card("OPPOSITION", vbox)
	var enemy_content := enemy_card.get_meta("content") as VBoxContainer

	var cat_row := HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", SPACING_MD)
	enemy_content.add_child(cat_row)

	var cat_label := Label.new()
	cat_label.text = "Category:"
	cat_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	cat_label.add_theme_color_override("font_color", COLOR_TEXT)
	cat_row.add_child(cat_label)

	_category_dropdown = OptionButton.new()
	_category_dropdown.custom_minimum_size = Vector2(220, TOUCH_TARGET)
	_category_dropdown.add_item("Random", 0)
	for i in range(_categories.size()):
		_category_dropdown.add_item(_categories[i].get("name", ""), i + 1)
	_category_dropdown.item_selected.connect(_on_category_selected)
	cat_row.add_child(_category_dropdown)

	var type_row := HBoxContainer.new()
	type_row.add_theme_constant_override("separation", SPACING_MD)
	enemy_content.add_child(type_row)

	var type_label := Label.new()
	type_label.text = "Enemy Type:"
	type_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	type_label.add_theme_color_override("font_color", COLOR_TEXT)
	type_row.add_child(type_label)

	_enemy_dropdown = OptionButton.new()
	_enemy_dropdown.custom_minimum_size = Vector2(220, TOUCH_TARGET)
	_enemy_dropdown.item_selected.connect(_on_enemy_selected)
	type_row.add_child(_enemy_dropdown)

	_enemy_preview = RichTextLabel.new()
	_enemy_preview.bbcode_enabled = true
	_enemy_preview.fit_content = true
	_enemy_preview.custom_minimum_size = Vector2(0, 60)
	_enemy_preview.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	_enemy_preview.add_theme_color_override("default_color", COLOR_TEXT_SEC)
	enemy_content.add_child(_enemy_preview)

	# --- Mission Section ---
	var mission_card := _create_card("MISSION", vbox)
	var mission_content := mission_card.get_meta("content") as VBoxContainer

	var mission_row := HBoxContainer.new()
	mission_row.add_theme_constant_override("separation", SPACING_MD)
	mission_content.add_child(mission_row)

	var mission_label := Label.new()
	mission_label.text = "Type:"
	mission_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	mission_label.add_theme_color_override("font_color", COLOR_TEXT)
	mission_row.add_child(mission_label)

	_mission_dropdown = OptionButton.new()
	_mission_dropdown.custom_minimum_size = Vector2(220, TOUCH_TARGET)
	_mission_dropdown.add_item("Random", 0)
	var mission_types: Array = _setup.get_mission_types()
	for i in range(mission_types.size()):
		_mission_dropdown.add_item(mission_types[i].get("type", ""), i + 1)
	_mission_dropdown.item_selected.connect(_on_mission_selected)
	mission_row.add_child(_mission_dropdown)

	# --- Difficulty Section ---
	var diff_card := _create_card("DIFFICULTY", vbox)
	var diff_content := diff_card.get_meta("content") as VBoxContainer

	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", SPACING_MD)
	diff_content.add_child(diff_row)

	var diff_label := Label.new()
	diff_label.text = "Level:"
	diff_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	diff_label.add_theme_color_override("font_color", COLOR_TEXT)
	diff_row.add_child(diff_label)

	_difficulty_dropdown = OptionButton.new()
	_difficulty_dropdown.custom_minimum_size = Vector2(280, TOUCH_TARGET)
	_difficulty_dropdown.add_item("1 - Easy (fewer enemies)", 0)
	_difficulty_dropdown.add_item("2 - Normal", 1)
	_difficulty_dropdown.add_item("3 - Challenging", 2)
	_difficulty_dropdown.add_item("4 - Hard (+1 enemy)", 3)
	_difficulty_dropdown.add_item("5 - Brutal (+2 enemies)", 4)
	_difficulty_dropdown.select(1) # Default: Normal
	_difficulty_dropdown.item_selected.connect(_on_difficulty_selected)
	diff_row.add_child(_difficulty_dropdown)

	# --- Launch Button ---
	var launch_container := HBoxContainer.new()
	launch_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(launch_container)

	_launch_button = Button.new()
	_launch_button.text = "LAUNCH BATTLE"
	_launch_button.custom_minimum_size = Vector2(280, 56)
	_launch_button.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_launch_button.pressed.connect(_on_launch_pressed)
	launch_container.add_child(_launch_button)

	# TweenFX press feedback
	var tweenfx = Engine.get_main_loop().root.get_node_or_null("/root/TweenFX") if Engine.get_main_loop() else null
	if tweenfx and tweenfx.has_method("press"):
		for btn: Button in [reroll_btn, _launch_button]:
			btn.pivot_offset = btn.size / 2
			btn.pressed.connect(func(): tweenfx.press(btn))


func _create_card(title_text: String, parent: VBoxContainer) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)
	panel.add_child(content)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override("font_color", COLOR_ACCENT_HOVER)  # ISSUE-052: consistent accent
	content.add_child(title)

	panel.set_meta("content", content)
	return panel


# --- Signal Handlers ---

func _on_crew_size_changed(value: float) -> void:
	_current_config["crew_size"] = int(value)
	_refresh_previews()


func _on_reroll_pressed() -> void:
	_refresh_previews()


func _on_category_selected(index: int) -> void:
	if index == 0:
		_current_config["enemy_category"] = "random"
	else:
		_current_config["enemy_category"] = _categories[index - 1].get("id", "")
	_current_config["enemy_type"] = "random"
	_refresh_enemy_dropdown()
	_refresh_previews()


func _on_enemy_selected(index: int) -> void:
	if index == 0:
		_current_config["enemy_type"] = "random"
	else:
		var cat_id: String = _current_config.get("enemy_category", "random")
		var enemies: Array = _setup.get_enemies_for_category(cat_id)
		if index - 1 < enemies.size():
			_current_config["enemy_type"] = enemies[index - 1].get("id", "")
	_refresh_previews()


func _on_mission_selected(index: int) -> void:
	if index == 0:
		_current_config["mission_type"] = "RANDOM"
	else:
		var types: Array = _setup.get_mission_types()
		if index - 1 < types.size():
			_current_config["mission_type"] = types[index - 1].get("type", "")


func _on_difficulty_selected(index: int) -> void:
	_current_config["difficulty"] = index + 1


func _on_launch_pressed() -> void:
	launch_requested.emit(_current_config.duplicate())


# --- Refresh helpers ---

func _refresh_enemy_dropdown() -> void:
	_enemy_dropdown.clear()
	_enemy_dropdown.add_item("Random", 0)

	var cat_id: String = _current_config.get("enemy_category", "random")
	if cat_id == "random":
		_enemy_dropdown.disabled = true
		return

	_enemy_dropdown.disabled = false
	var enemies: Array = _setup.get_enemies_for_category(cat_id)
	for i in range(enemies.size()):
		_enemy_dropdown.add_item(enemies[i].get("name", ""), i + 1)


func _refresh_previews() -> void:
	# Generate a preview battle context to show crew/enemy stats
	var context: Dictionary = _setup.generate_battle_context(_current_config)

	# Crew preview — ISSUE-051: stat badge style
	if _crew_preview:
		var crew_text := ""
		for member in context.get("crew", []):
			crew_text += "[color=#4FC3F7]%s[/color]  " % member.get("character_name", "?")
			crew_text += "[color=#808080]CS[/color] %d  " % member.get("combat_skill", 0)
			crew_text += "[color=#808080]React[/color] %d  " % member.get("reactions", 0)
			crew_text += "[color=#808080]Tough[/color] %d  " % member.get("toughness", 0)
			crew_text += "[color=#808080]Spd[/color] %d  " % member.get("speed", 0)
			crew_text += "[color=#808080]Savvy[/color] %d\n" % member.get("savvy", 0)
		_crew_preview.text = crew_text.strip_edges()

	# Enemy preview
	if _enemy_preview:
		var enemies: Array = context.get("enemies", [])
		var enemy_count: int = enemies.size()
		var first_enemy: Dictionary = enemies[0] if not enemies.is_empty() else {}
		var enemy_text := "[color=#D97706]%d enemies[/color]" % enemy_count
		if not first_enemy.is_empty():
			enemy_text += " — Combat: %d  Tough: %d  Spd: %d  AI: %s" % [
				first_enemy.get("combat_skill", 0),
				first_enemy.get("toughness", 0),
				first_enemy.get("speed", 0),
				first_enemy.get("ai", "?"),
			]
			var rules: Array = first_enemy.get("special_rules", [])
			if not rules.is_empty():
				enemy_text += "\n[color=#808080]Rules: %s[/color]" % ", ".join(rules)
		_enemy_preview.text = enemy_text


## Get the current setup instance (for external use if needed)
func get_setup() -> BattleSimulatorSetup:
	return _setup
