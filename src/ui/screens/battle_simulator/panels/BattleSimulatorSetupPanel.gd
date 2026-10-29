extends Control

## Single-screen Battle Simulator setup panel.
##
## Every choice regenerates ONE battle, the preview shows that battle, and Launch hands
## over exactly that battle. Until 2026-10-29 the preview was a throwaway roll and Launch
## sent only the settings, so the screen generated a SECOND battle: a player read "7
## enemies" here and then fought 5.

signal launch_requested(context: Dictionary)

const DifficultyModifiersRef := preload("res://src/core/systems/DifficultyModifiers.gd")

# Deep Space theme
const COLOR_BASE := UIColors.COLOR_BASE
const COLOR_ELEVATED := UIColors.COLOR_ELEVATED
const COLOR_INPUT := UIColors.COLOR_INPUT
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_ACCENT
const COLOR_ACCENT_HOVER := UIColors.COLOR_ACCENT_HOVER
const COLOR_FOCUS := UIColors.COLOR_FOCUS
const COLOR_TEXT := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := UIColors.COLOR_TEXT_SECONDARY
const COLOR_SUCCESS := UIColors.COLOR_SUCCESS

# SPACING_XS was USED (twice) but never declared, and this panel extends Control
# rather than a Deep Space base class that could supply it — so the script failed
# to PARSE and the Battle Simulator button on the main menu hard-broke into the
# debugger. Value per the Deep Space 8px grid.
const SPACING_XS := 4
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
var _difficulty_note: RichTextLabel
var _enemy_preview: RichTextLabel
var _crew_preview: RichTextLabel
var _mission_preview: RichTextLabel
var _launch_button: Button

var _categories: Array = []
var _current_config: Dictionary = {
	"crew_size": BattleSimulatorSetup.DEFAULT_CREW_SIZE,
	"enemy_category": "random",
	"enemy_type": "random",
	"mission_type": "RANDOM",
	"difficulty_mode": BattleSimulatorSetup.DEFAULT_DIFFICULTY_MODE,
}
## The battle on screen. Launch sends this, never a fresh roll.
var _context: Dictionary = {}


func _ready() -> void:
	_setup = BattleSimulatorSetup.new()
	_categories = _setup.get_enemy_categories()
	_build_ui()
	_refresh_enemy_dropdown()
	_refresh_difficulty_note()
	_regenerate()


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

	var crew_row := HFlowContainer.new()
	crew_row.add_theme_constant_override("h_separation", SPACING_MD)
	crew_row.add_theme_constant_override("v_separation", SPACING_XS)
	crew_content.add_child(crew_row)

	var crew_label := Label.new()
	crew_label.text = "Crew Size:"
	crew_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	crew_label.add_theme_color_override("font_color", COLOR_TEXT)
	crew_row.add_child(crew_label)

	# Core Rules p.63: crew size is 4, 5 or 6, and it decides the enemy numbers dice.
	_crew_size_spin = SpinBox.new()
	_crew_size_spin.min_value = BattleSimulatorSetup.CREW_SIZES[0]
	_crew_size_spin.max_value = BattleSimulatorSetup.CREW_SIZES[-1]
	_crew_size_spin.value = BattleSimulatorSetup.DEFAULT_CREW_SIZE
	_crew_size_spin.step = 1
	_crew_size_spin.custom_minimum_size = Vector2(120, TOUCH_TARGET)
	_crew_size_spin.value_changed.connect(_on_crew_size_changed)
	crew_row.add_child(_crew_size_spin)

	var reroll_btn := Button.new()
	reroll_btn.text = "Roll Again"
	reroll_btn.tooltip_text = "Roll a new crew, opposition and mission with these settings"
	reroll_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET)
	reroll_btn.pressed.connect(_on_reroll_pressed)
	crew_row.add_child(reroll_btn)

	_crew_preview = _create_preview(crew_content, 80)

	# --- Enemy Section ---
	var enemy_card := _create_card("OPPOSITION", vbox)
	var enemy_content := enemy_card.get_meta("content") as VBoxContainer

	_category_dropdown = _create_dropdown_row("Category:", enemy_content)
	_category_dropdown.add_item("Random (roll the encounter table)", 0)
	for i in range(_categories.size()):
		_category_dropdown.add_item(_categories[i].get("name", ""), i + 1)
	_category_dropdown.item_selected.connect(_on_category_selected)

	_enemy_dropdown = _create_dropdown_row("Enemy Type:", enemy_content)
	_enemy_dropdown.item_selected.connect(_on_enemy_selected)

	_enemy_preview = _create_preview(enemy_content, 60)

	# --- Mission Section ---
	var mission_card := _create_card("MISSION", vbox)
	var mission_content := mission_card.get_meta("content") as VBoxContainer

	_mission_dropdown = _create_dropdown_row("Type:", mission_content)
	_mission_dropdown.add_item("Random", 0)
	var mission_types: Array = _setup.get_mission_types()
	for i in range(mission_types.size()):
		_mission_dropdown.add_item(str(mission_types[i].get("name", "")), i + 1)
	_mission_dropdown.item_selected.connect(_on_mission_selected)

	_mission_preview = _create_preview(mission_content, 60)

	# --- Difficulty Section ---
	var diff_card := _create_card("DIFFICULTY", vbox)
	var diff_content := diff_card.get_meta("content") as VBoxContainer

	# Core Rules pp.64-65: the book's five modes, named by DifficultyModifiers (the one
	# source of difficulty names). The list this replaced offered "Hard (+1 enemy)" and
	# "Brutal (+2 enemies)", which are in neither book.
	_difficulty_dropdown = _create_dropdown_row("Mode:", diff_content)
	for i in range(BattleSimulatorSetup.DIFFICULTY_MODES.size()):
		var mode: int = BattleSimulatorSetup.DIFFICULTY_MODES[i]
		_difficulty_dropdown.add_item(DifficultyModifiersRef.get_display_name(mode), i)
		if mode == BattleSimulatorSetup.DEFAULT_DIFFICULTY_MODE:
			_difficulty_dropdown.select(i)
	_difficulty_dropdown.item_selected.connect(_on_difficulty_selected)

	_difficulty_note = _create_preview(diff_content, 0)

	# --- Launch Button ---
	var launch_container := HFlowContainer.new()
	# FlowContainer.AlignmentMode, NOT BoxContainer's — Godot 4.6 treats them as
	# distinct types and the mismatched assignment is a hard PARSE error, which
	# is the second of the two breaks that made this screen unopenable.
	launch_container.alignment = FlowContainer.ALIGNMENT_CENTER
	vbox.add_child(launch_container)

	_launch_button = Button.new()
	_launch_button.text = "LAUNCH THIS BATTLE"
	_launch_button.custom_minimum_size = Vector2(0, 56)
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


func _create_dropdown_row(label_text: String, parent: VBoxContainer) -> OptionButton:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", SPACING_MD)
	row.add_theme_constant_override("v_separation", SPACING_XS)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	row.add_child(label)

	var dropdown := OptionButton.new()
	dropdown.custom_minimum_size = Vector2(0, TOUCH_TARGET)
	dropdown.clip_text = true
	dropdown.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dropdown)
	return dropdown


func _create_preview(parent: VBoxContainer, min_height: int) -> RichTextLabel:
	var preview := RichTextLabel.new()
	preview.bbcode_enabled = true
	preview.fit_content = true
	preview.custom_minimum_size = Vector2(0, min_height)
	ScreenChrome.size_rich_text(preview, FONT_SIZE_SM)
	preview.add_theme_color_override("default_color", COLOR_TEXT_SEC)
	parent.add_child(preview)
	return preview


# --- Signal Handlers ---

func _on_crew_size_changed(value: float) -> void:
	_current_config["crew_size"] = int(value)
	_regenerate()


func _on_reroll_pressed() -> void:
	_regenerate()


func _on_category_selected(index: int) -> void:
	if index == 0:
		_current_config["enemy_category"] = "random"
	else:
		_current_config["enemy_category"] = _categories[index - 1].get("id", "")
	_current_config["enemy_type"] = "random"
	_refresh_enemy_dropdown()
	_regenerate()


func _on_enemy_selected(index: int) -> void:
	if index == 0:
		_current_config["enemy_type"] = "random"
	else:
		var cat_id: String = _current_config.get("enemy_category", "random")
		var enemies: Array = _setup.get_enemies_for_category(cat_id)
		if index - 1 < enemies.size():
			_current_config["enemy_type"] = enemies[index - 1].get("id", "")
	_regenerate()


func _on_mission_selected(index: int) -> void:
	if index == 0:
		_current_config["mission_type"] = "RANDOM"
	else:
		var types: Array = _setup.get_mission_types()
		if index - 1 < types.size():
			_current_config["mission_type"] = types[index - 1].get("type", "")
	_regenerate()


func _on_difficulty_selected(index: int) -> void:
	if index >= 0 and index < BattleSimulatorSetup.DIFFICULTY_MODES.size():
		_current_config["difficulty_mode"] = BattleSimulatorSetup.DIFFICULTY_MODES[index]
	_refresh_difficulty_note()
	_regenerate()


func _on_launch_pressed() -> void:
	launch_requested.emit(_context)


# --- Refresh helpers ---

## Roll the battle the screen shows and Launch sends.
func _regenerate() -> void:
	_context = _setup.generate_battle_context(_current_config)
	_render_context()


## The settings that produced the battle on screen (Play Again reuses them).
func get_config() -> Dictionary:
	return _current_config.duplicate()


## Restore settings from an earlier battle and roll a new one with them.
func apply_config(config: Dictionary) -> void:
	for key in _current_config:
		if config.has(key):
			_current_config[key] = config[key]
	if _crew_size_spin:
		_crew_size_spin.set_value_no_signal(int(_current_config["crew_size"]))
	if _difficulty_dropdown:
		var idx: int = BattleSimulatorSetup.DIFFICULTY_MODES.find(
			int(_current_config["difficulty_mode"]))
		if idx >= 0:
			_difficulty_dropdown.select(idx)
	_refresh_difficulty_note()
	_regenerate()


func get_context() -> Dictionary:
	return _context


func _refresh_enemy_dropdown() -> void:
	_enemy_dropdown.clear()
	var cat_id: String = _current_config.get("enemy_category", "random")
	if cat_id == "random":
		_enemy_dropdown.add_item("Rolled with the category", 0)
		_enemy_dropdown.disabled = true
		return

	_enemy_dropdown.add_item("Random (roll the category's table)", 0)
	_enemy_dropdown.disabled = false
	var enemies: Array = _setup.get_enemies_for_category(cat_id)
	for i in range(enemies.size()):
		_enemy_dropdown.add_item(enemies[i].get("name", ""), i + 1)


## What the selected mode changes in a battle, read off DifficultyModifiers (the
## campaign-only effects, XP and story points, are left out). No number here is a
## literal: each comes from the same accessor the generator applies.
func _refresh_difficulty_note() -> void:
	if _difficulty_note == null:
		return
	var mode: int = int(_current_config.get("difficulty_mode", 2))
	var parts: Array[String] = []
	if DifficultyModifiersRef.get_easy_enemy_reduction(5, mode) > 0:
		parts.append("facing 5+ opponents, remove %d Basic enemy"
			% DifficultyModifiersRef.get_easy_enemy_reduction(5, mode))
	if DifficultyModifiersRef.should_reroll_low_enemy_dice(mode):
		parts.append("reroll 1s and 2s on the enemy numbers dice")
	if DifficultyModifiersRef.get_enemy_count_modifier(mode) > 0:
		parts.append("+%d Basic enemy" % DifficultyModifiersRef.get_enemy_count_modifier(mode))
	if DifficultyModifiersRef.get_specialist_enemy_modifier(mode) > 0:
		parts.append("+%d Specialist enemy"
			% DifficultyModifiersRef.get_specialist_enemy_modifier(mode))
	if DifficultyModifiersRef.is_unique_individual_forced(mode):
		parts.append("always a Unique Individual")
	elif DifficultyModifiersRef.get_unique_individual_roll_modifier(mode) != 0:
		parts.append("%+d to the Unique Individual roll"
			% DifficultyModifiersRef.get_unique_individual_roll_modifier(mode))
	if DifficultyModifiersRef.get_seize_initiative_modifier(mode) != 0:
		parts.append("%+d to Seize the Initiative"
			% DifficultyModifiersRef.get_seize_initiative_modifier(mode))
	var body: String = "; ".join(parts) if not parts.is_empty() \
		else "the battle rules apply as written"
	_difficulty_note.text = "In battle: %s. [color=ui-secondary](Core Rules pp.64-65)[/color]" \
		% body
	_difficulty_note.text = UIColors.bbcode(_difficulty_note.text)


func _render_context() -> void:
	if _crew_preview:
		_crew_preview.text = UIColors.bbcode(crew_preview_text(_context))
	if _enemy_preview:
		_enemy_preview.text = UIColors.bbcode(enemy_preview_text(_context))
	if _mission_preview:
		_mission_preview.text = UIColors.bbcode(mission_preview_text(_context))


## Crew lines. Static so a test can read the text without building the screen.
static func crew_preview_text(context: Dictionary) -> String:
	var lines: Array[String] = []
	for member in context.get("crew", []):
		lines.append("[color=ui-info]%s[/color]  React %d · Speed %d\" · Combat %+d · Tough %d · Savvy %+d%s" % [
			member.get("character_name", "?"), int(member.get("reactions", 0)),
			int(member.get("speed", 0)), int(member.get("combat_skill", 0)),
			int(member.get("toughness", 0)), int(member.get("savvy", 0)),
			("  ·  %s" % member["weapon_name"]) if member.has("weapon_name") else ""])
	var notes: Array[String] = [
		"[color=ui-secondary]Baseline Human profile (Core Rules p.15); weapons rolled on the p.28 Military and Low-tech tables.[/color]"]
	var spares: Array = context.get("spare_weapons", [])
	if not spares.is_empty():
		notes.append("[color=ui-secondary]Spare weapons: %s[/color]" % ", ".join(spares))
	var sitting: Array = context.get("sitting_out", [])
	if not sitting.is_empty():
		notes.append("[color=ui-warning]Sitting this one out (Deployment Condition): %s[/color]"
			% ", ".join(sitting))
	return "\n".join(lines + notes)


## The force as generated: count, its make-up and the type's profile.
static func enemy_preview_text(context: Dictionary) -> String:
	var enemies: Array = context.get("enemies", [])
	if enemies.is_empty():
		return "[color=ui-danger]No opposition was generated.[/color]"
	var first: Dictionary = enemies[0]
	var specialists: int = 0
	var lieutenants: int = 0
	var uniques: int = 0
	for e in enemies:
		if bool(e.get("is_unique_individual", false)):
			uniques += 1
		elif bool(e.get("is_lieutenant", false)):
			lieutenants += 1
		elif bool(e.get("is_specialist", false)):
			specialists += 1
	var makeup: Array[String] = []
	if specialists > 0:
		makeup.append("%d Specialist%s" % [specialists, "" if specialists == 1 else "s"])
	if lieutenants > 0:
		makeup.append("%d Lieutenant%s" % [lieutenants, "" if lieutenants == 1 else "s"])
	if uniques > 0:
		makeup.append("%d Unique Individual%s" % [uniques, "" if uniques == 1 else "s"])
	var text := "[color=ui-warning]%d × %s[/color]" % [
		enemies.size(), first.get("type", first.get("name", "?"))]
	if not makeup.is_empty():
		text += "  (including %s)" % ", ".join(makeup)
	text += "\nCombat %+d · Tough %d · Speed %d\" · Panic %s · AI %s" % [
		int(first.get("combat_skill", 0)), int(first.get("toughness", 0)),
		int(first.get("speed", 0)), str(first.get("panic", "?")), str(first.get("ai", "?"))]
	var rules: Array = first.get("special_rules", [])
	if not rules.is_empty():
		text += "\n[color=ui-secondary]Rules: %s[/color]" % ", ".join(rules)
	return text


## The p.88 / p.89 rolls the battle will open with.
static func mission_preview_text(context: Dictionary) -> String:
	var md: Dictionary = context.get("mission_data", {})
	var lines: Array[String] = ["[color=ui-info]%s[/color]" % str(md.get("title", ""))]
	var objective: Dictionary = md.get("objective_details", {})
	if not objective.is_empty():
		lines.append("Objective: %s (p.89)" % str(objective.get("name", "")))
	var condition: Dictionary = md.get("deployment_condition", {})
	var cond_title: String = str(condition.get("title", ""))
	if not cond_title.is_empty():
		lines.append("Deployment Condition: %s (p.88)" % cond_title)
	# MissionTableManager.roll_notable_sight() returns {type, effect, roll}.
	var sight: Dictionary = md.get("notable_sight", {})
	var sight_type: String = str(sight.get("type", ""))
	if not sight_type.is_empty() and sight_type != "NOTHING":
		lines.append("Notable Sight: %s (p.89)" % sight_type.capitalize())
	return "\n".join(lines)


## Get the current setup instance (for external use if needed)
func get_setup() -> BattleSimulatorSetup:
	return _setup
