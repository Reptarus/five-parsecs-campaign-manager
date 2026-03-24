class_name FPCM_CharacterQuickRollPanel
extends PanelContainer

## Character Quick Roll Panel — One-tap dice rolls with all bonuses/debuffs applied
##
## Connects character data (stats, species, equipment, status) to BattleCalculations
## static methods, producing fully explained roll results with BBCode modifier breakdowns.
## Manual situation toggles (cover, range, elevation) let the player match their physical table.
##
## Core Rules references:
##   - Hit rolls: p.44 (1D6 + Combat Skill vs threshold table)
##   - Brawl: p.45 (1D6 + Combat Skill + weapon bonus, K'Erin double-roll)
##   - Damage: p.46 (1D6 + Damage vs Toughness)
##   - Reaction: p.112 (D6 vs Reactions stat → Quick/Slow)
##   - Aim: p.46 (reroll 1s if didn't move)
##   - Snap Fire: p.113 (-1 to hit during enemy actions)
##   - Luck: p.91-92 (spend to reroll any die)

signal roll_completed(character_name: String, roll_type: String, result: Dictionary)

enum RollType { HIT, BRAWL, DAMAGE, REACTION }

# Design system constants
const SPACING_SM: int = UIColors.SPACING_SM
const SPACING_MD: int = UIColors.SPACING_MD
const SPACING_LG: int = UIColors.SPACING_LG
const TOUCH_TARGET_MIN: int = UIColors.TOUCH_TARGET_MIN
const FONT_SIZE_SM: int = UIColors.FONT_SIZE_SM
const FONT_SIZE_MD: int = UIColors.FONT_SIZE_MD
const FONT_SIZE_LG: int = UIColors.FONT_SIZE_LG
const FONT_SIZE_XL: int = UIColors.FONT_SIZE_XL

const COLOR_BASE: Color = UIColors.COLOR_BASE
const COLOR_ELEVATED: Color = UIColors.COLOR_ELEVATED
const COLOR_INPUT: Color = UIColors.COLOR_INPUT
const COLOR_BORDER: Color = UIColors.COLOR_BORDER
const COLOR_ACCENT: Color = UIColors.COLOR_ACCENT
const COLOR_TEXT_PRIMARY: Color = UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY: Color = UIColors.COLOR_TEXT_SECONDARY

# Roll type labels for display
const ROLL_TYPE_LABELS: Dictionary = {
	RollType.HIT: "Hit Roll",
	RollType.BRAWL: "Brawl",
	RollType.DAMAGE: "Damage",
	RollType.REACTION: "Reaction",
}

# State
var _crew: Array = []
var _selected_character: Dictionary = {}
var _current_roll_type: RollType = RollType.HIT
var _last_result: Dictionary = {}
var _rng := RandomNumberGenerator.new()

# UI node references (built in _ready)
var _crew_list: VBoxContainer
var _crew_scroll: ScrollContainer
var _roll_type_option: OptionButton
var _cover_check: CheckBox
var _elevated_check: CheckBox
var _range_spin: SpinBox
var _roll_button: Button
var _result_display: RichTextLabel
var _luck_button: Button
var _character_label: Label

# Brawl-specific inputs (shown only in BRAWL mode)
var _brawl_section: VBoxContainer
var _opponent_combat_spin: SpinBox
var _opponent_weapon_option: OptionButton
var _opponent_species_edit: LineEdit
var _opponent_stun_spin: SpinBox
var _outnumbering_spin: SpinBox

# Damage-specific inputs (shown only in DAMAGE mode)
var _damage_section: VBoxContainer
var _weapon_damage_spin: SpinBox
var _target_toughness_spin: SpinBox
var _armor_option: OptionButton
var _screen_option: OptionButton
var _piercing_check: CheckBox

func _ready() -> void:
	_rng.seed = Time.get_unix_time_from_system()
	if is_inside_tree():
		_setup_ui()

# =====================================================
# PUBLIC API
# =====================================================

func set_crew(crew: Array) -> void:
	_crew = crew
	_rebuild_crew_list()

func select_character(character_name: String) -> void:
	for char_data: Dictionary in _crew:
		var name_val: String = str(char_data.get("character_name", char_data.get("name", "")))
		if name_val == character_name:
			_selected_character = char_data
			_update_character_display()
			return

# =====================================================
# UI CONSTRUCTION
# =====================================================

func _setup_ui() -> void:
	custom_minimum_size = Vector2(380, 500)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_ELEVATED
	panel_style.set_corner_radius_all(8)
	panel_style.border_color = COLOR_BORDER
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.content_margin_left = SPACING_MD
	panel_style.content_margin_right = SPACING_MD
	panel_style.content_margin_top = SPACING_MD
	panel_style.content_margin_bottom = SPACING_MD
	add_theme_stylebox_override("panel", panel_style)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", SPACING_SM)
	add_child(main_vbox)

	# Title
	var title := Label.new()
	title.text = "Character Quick Roll"
	title.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	# Selected character display
	_character_label = Label.new()
	_character_label.text = "No character selected"
	_character_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_character_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_character_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_character_label)

	# Crew list (collapsible scroll)
	_crew_scroll = ScrollContainer.new()
	_crew_scroll.custom_minimum_size = Vector2(0, 100)
	_crew_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_crew_scroll)

	_crew_list = VBoxContainer.new()
	_crew_list.add_theme_constant_override("separation", 4)
	_crew_scroll.add_child(_crew_list)

	# Separator
	main_vbox.add_child(HSeparator.new())

	# Roll type selector
	var type_row := HBoxContainer.new()
	type_row.add_theme_constant_override("separation", SPACING_SM)
	main_vbox.add_child(type_row)

	var type_label := Label.new()
	type_label.text = "Roll Type:"
	type_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	type_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	type_row.add_child(type_label)

	_roll_type_option = OptionButton.new()
	_roll_type_option.add_item("Hit Roll", RollType.HIT)
	_roll_type_option.add_item("Brawl", RollType.BRAWL)
	_roll_type_option.add_item("Damage", RollType.DAMAGE)
	_roll_type_option.add_item("Reaction", RollType.REACTION)
	_roll_type_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	_roll_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roll_type_option.item_selected.connect(_on_roll_type_changed)
	type_row.add_child(_roll_type_option)

	# Situation toggles (Hit Roll mode)
	_build_hit_inputs(main_vbox)

	# Brawl-specific inputs
	_build_brawl_inputs(main_vbox)

	# Damage-specific inputs
	_build_damage_inputs(main_vbox)

	# Roll button
	_roll_button = Button.new()
	_roll_button.text = "Roll"
	_roll_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	var roll_style := StyleBoxFlat.new()
	roll_style.bg_color = COLOR_ACCENT
	roll_style.set_corner_radius_all(6)
	roll_style.content_margin_left = SPACING_MD
	roll_style.content_margin_right = SPACING_MD
	_roll_button.add_theme_stylebox_override("normal", roll_style)
	_roll_button.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_roll_button.pressed.connect(_on_roll_pressed)
	main_vbox.add_child(_roll_button)

	# Result display
	_result_display = RichTextLabel.new()
	_result_display.bbcode_enabled = true
	_result_display.fit_content = true
	_result_display.custom_minimum_size = Vector2(0, 80)
	_result_display.scroll_active = true
	_result_display.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	_result_display.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	main_vbox.add_child(_result_display)

	# Luck reroll button (hidden until a roll is made)
	_luck_button = Button.new()
	_luck_button.text = "Spend Luck to Reroll"
	_luck_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	_luck_button.visible = false
	var luck_style := StyleBoxFlat.new()
	luck_style.bg_color = UIColors.COLOR_AMBER
	luck_style.set_corner_radius_all(6)
	_luck_button.add_theme_stylebox_override("normal", luck_style)
	_luck_button.pressed.connect(_on_luck_pressed)
	main_vbox.add_child(_luck_button)

	# Initialize visibility
	_on_roll_type_changed(0)

func _build_hit_inputs(parent: VBoxContainer) -> void:
	# Cover, elevation, range — shown for HIT and REACTION
	var hit_section := VBoxContainer.new()
	hit_section.name = "HitInputs"
	hit_section.add_theme_constant_override("separation", 4)
	parent.add_child(hit_section)

	_cover_check = CheckBox.new()
	_cover_check.text = "Target in Cover"
	_cover_check.custom_minimum_size.y = TOUCH_TARGET_MIN
	_cover_check.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	hit_section.add_child(_cover_check)

	_elevated_check = CheckBox.new()
	_elevated_check.text = "Attacker Elevated"
	_elevated_check.custom_minimum_size.y = TOUCH_TARGET_MIN
	_elevated_check.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	hit_section.add_child(_elevated_check)

	var range_row := HBoxContainer.new()
	range_row.add_theme_constant_override("separation", SPACING_SM)
	hit_section.add_child(range_row)

	var range_label := Label.new()
	range_label.text = "Range (inches):"
	range_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	range_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	range_row.add_child(range_label)

	_range_spin = SpinBox.new()
	_range_spin.min_value = 1
	_range_spin.max_value = 48
	_range_spin.value = 12
	_range_spin.step = 1
	_range_spin.custom_minimum_size = Vector2(80, TOUCH_TARGET_MIN)
	_range_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_row.add_child(_range_spin)

func _build_brawl_inputs(parent: VBoxContainer) -> void:
	_brawl_section = VBoxContainer.new()
	_brawl_section.name = "BrawlInputs"
	_brawl_section.add_theme_constant_override("separation", 4)
	_brawl_section.visible = false
	parent.add_child(_brawl_section)

	var section_label := Label.new()
	section_label.text = "Opponent"
	section_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	section_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_brawl_section.add_child(section_label)

	# Opponent combat skill
	var combat_row := HBoxContainer.new()
	combat_row.add_theme_constant_override("separation", SPACING_SM)
	_brawl_section.add_child(combat_row)

	var combat_label := Label.new()
	combat_label.text = "Combat Skill:"
	combat_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	combat_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	combat_row.add_child(combat_label)

	_opponent_combat_spin = SpinBox.new()
	_opponent_combat_spin.min_value = 0
	_opponent_combat_spin.max_value = 5
	_opponent_combat_spin.value = 1
	_opponent_combat_spin.custom_minimum_size = Vector2(80, TOUCH_TARGET_MIN)
	_opponent_combat_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_row.add_child(_opponent_combat_spin)

	# Opponent weapon type
	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", SPACING_SM)
	_brawl_section.add_child(weapon_row)

	var weapon_label := Label.new()
	weapon_label.text = "Weapon:"
	weapon_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	weapon_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	weapon_row.add_child(weapon_label)

	_opponent_weapon_option = OptionButton.new()
	_opponent_weapon_option.add_item("None (+0)", 0)
	_opponent_weapon_option.add_item("Pistol (+1)", 1)
	_opponent_weapon_option.add_item("Melee (+2)", 2)
	_opponent_weapon_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	_opponent_weapon_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_row.add_child(_opponent_weapon_option)

	# Opponent species
	var species_row := HBoxContainer.new()
	species_row.add_theme_constant_override("separation", SPACING_SM)
	_brawl_section.add_child(species_row)

	var species_label := Label.new()
	species_label.text = "Species:"
	species_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	species_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	species_row.add_child(species_label)

	_opponent_species_edit = LineEdit.new()
	_opponent_species_edit.placeholder_text = "human"
	_opponent_species_edit.custom_minimum_size = Vector2(120, TOUCH_TARGET_MIN)
	_opponent_species_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line_style := StyleBoxFlat.new()
	line_style.bg_color = COLOR_INPUT
	line_style.set_corner_radius_all(4)
	line_style.content_margin_left = SPACING_SM
	_opponent_species_edit.add_theme_stylebox_override("normal", line_style)
	species_row.add_child(_opponent_species_edit)

	# Stun markers on opponent
	var stun_row := HBoxContainer.new()
	stun_row.add_theme_constant_override("separation", SPACING_SM)
	_brawl_section.add_child(stun_row)

	var stun_label := Label.new()
	stun_label.text = "Opponent Stuns:"
	stun_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	stun_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	stun_row.add_child(stun_label)

	_opponent_stun_spin = SpinBox.new()
	_opponent_stun_spin.min_value = 0
	_opponent_stun_spin.max_value = 3
	_opponent_stun_spin.value = 0
	_opponent_stun_spin.custom_minimum_size = Vector2(80, TOUCH_TARGET_MIN)
	stun_row.add_child(_opponent_stun_spin)

	# Outnumbering bonus
	var outnumber_row := HBoxContainer.new()
	outnumber_row.add_theme_constant_override("separation", SPACING_SM)
	_brawl_section.add_child(outnumber_row)

	var outnumber_label := Label.new()
	outnumber_label.text = "Outnumbering (+1):"
	outnumber_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	outnumber_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	outnumber_row.add_child(outnumber_label)

	_outnumbering_spin = SpinBox.new()
	_outnumbering_spin.min_value = 0
	_outnumbering_spin.max_value = 1
	_outnumbering_spin.value = 0
	_outnumbering_spin.custom_minimum_size = Vector2(80, TOUCH_TARGET_MIN)
	outnumber_row.add_child(_outnumbering_spin)

func _build_damage_inputs(parent: VBoxContainer) -> void:
	_damage_section = VBoxContainer.new()
	_damage_section.name = "DamageInputs"
	_damage_section.add_theme_constant_override("separation", 4)
	_damage_section.visible = false
	parent.add_child(_damage_section)

	var section_label := Label.new()
	section_label.text = "Damage Resolution"
	section_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	section_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_damage_section.add_child(section_label)

	# Weapon damage
	var dmg_row := HBoxContainer.new()
	dmg_row.add_theme_constant_override("separation", SPACING_SM)
	_damage_section.add_child(dmg_row)

	var dmg_label := Label.new()
	dmg_label.text = "Weapon Damage:"
	dmg_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	dmg_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	dmg_row.add_child(dmg_label)

	_weapon_damage_spin = SpinBox.new()
	_weapon_damage_spin.min_value = 0
	_weapon_damage_spin.max_value = 5
	_weapon_damage_spin.value = 0
	_weapon_damage_spin.custom_minimum_size = Vector2(80, TOUCH_TARGET_MIN)
	_weapon_damage_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dmg_row.add_child(_weapon_damage_spin)

	# Target toughness
	var tough_row := HBoxContainer.new()
	tough_row.add_theme_constant_override("separation", SPACING_SM)
	_damage_section.add_child(tough_row)

	var tough_label := Label.new()
	tough_label.text = "Target Toughness:"
	tough_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	tough_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	tough_row.add_child(tough_label)

	_target_toughness_spin = SpinBox.new()
	_target_toughness_spin.min_value = 1
	_target_toughness_spin.max_value = 8
	_target_toughness_spin.value = 3
	_target_toughness_spin.custom_minimum_size = Vector2(80, TOUCH_TARGET_MIN)
	_target_toughness_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tough_row.add_child(_target_toughness_spin)

	# Armor type
	var armor_row := HBoxContainer.new()
	armor_row.add_theme_constant_override("separation", SPACING_SM)
	_damage_section.add_child(armor_row)

	var armor_label := Label.new()
	armor_label.text = "Armor:"
	armor_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	armor_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	armor_row.add_child(armor_label)

	_armor_option = OptionButton.new()
	_armor_option.add_item("None")
	_armor_option.add_item("Light (6+)")
	_armor_option.add_item("Combat (5+)")
	_armor_option.add_item("Heavy (4+)")
	_armor_option.add_item("Powered (3+)")
	_armor_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	_armor_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	armor_row.add_child(_armor_option)

	# Screen type
	var screen_row := HBoxContainer.new()
	screen_row.add_theme_constant_override("separation", SPACING_SM)
	_damage_section.add_child(screen_row)

	var screen_label := Label.new()
	screen_label.text = "Screen:"
	screen_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	screen_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	screen_row.add_child(screen_label)

	_screen_option = OptionButton.new()
	_screen_option.add_item("None")
	_screen_option.add_item("Basic (6+)")
	_screen_option.add_item("Military (5+)")
	_screen_option.add_item("Advanced (4+)")
	_screen_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	_screen_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen_row.add_child(_screen_option)

	# Piercing
	_piercing_check = CheckBox.new()
	_piercing_check.text = "Piercing (ignores armor)"
	_piercing_check.custom_minimum_size.y = TOUCH_TARGET_MIN
	_piercing_check.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	_damage_section.add_child(_piercing_check)

# =====================================================
# CREW LIST
# =====================================================

func _rebuild_crew_list() -> void:
	for child: Node in _crew_list.get_children():
		child.queue_free()

	for char_data: Dictionary in _crew:
		var char_name: String = str(char_data.get("character_name", char_data.get("name", "Unknown")))
		var combat: int = char_data.get("combat", char_data.get("combat_skill", 0))
		var reactions: int = char_data.get("reactions", char_data.get("reaction", 1))

		var btn := Button.new()
		btn.text = "%s  [C:%d R:%d]" % [char_name, combat, reactions]
		btn.custom_minimum_size.y = 40
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_crew_selected.bind(char_data))

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = COLOR_INPUT
		btn_style.set_corner_radius_all(4)
		btn_style.content_margin_left = SPACING_SM
		btn.add_theme_stylebox_override("normal", btn_style)

		_crew_list.add_child(btn)

func _on_crew_selected(char_data: Dictionary) -> void:
	_selected_character = char_data
	_update_character_display()

func _update_character_display() -> void:
	if _selected_character.is_empty():
		_character_label.text = "No character selected"
		_roll_button.text = "Roll"
		return

	var char_name: String = str(_selected_character.get("character_name",
		_selected_character.get("name", "Unknown")))
	var combat: int = _selected_character.get("combat", _selected_character.get("combat_skill", 0))
	var reactions: int = _selected_character.get("reactions", _selected_character.get("reaction", 1))
	var toughness: int = _selected_character.get("toughness", 3)
	var species: String = str(_selected_character.get("species", "Human"))
	var stuns: int = _selected_character.get("stun_markers", 0)

	_character_label.text = "%s (%s) C:%d R:%d T:%d%s" % [
		char_name, species, combat, reactions, toughness,
		" [STUNNED x%d]" % stuns if stuns > 0 else ""
	]
	_roll_button.text = "Roll for %s" % char_name

# =====================================================
# ROLL TYPE SWITCHING
# =====================================================

func _on_roll_type_changed(index: int) -> void:
	_current_roll_type = index as RollType
	var hit_inputs: Node = get_node_or_null("VBoxContainer/HitInputs")
	if hit_inputs:
		hit_inputs.visible = (_current_roll_type == RollType.HIT)
	if _brawl_section:
		_brawl_section.visible = (_current_roll_type == RollType.BRAWL)
	if _damage_section:
		_damage_section.visible = (_current_roll_type == RollType.DAMAGE)

# =====================================================
# DICE ROLLING
# =====================================================

func _roll_d6() -> int:
	return _rng.randi_range(1, 6)

func _on_roll_pressed() -> void:
	if _selected_character.is_empty():
		_result_display.text = "[color=#DC2626]Select a character first.[/color]"
		return

	_luck_button.visible = false
	_last_result = {}

	match _current_roll_type:
		RollType.HIT:
			_execute_hit_roll()
		RollType.BRAWL:
			_execute_brawl_roll()
		RollType.DAMAGE:
			_execute_damage_roll()
		RollType.REACTION:
			_execute_reaction_roll()

func _execute_hit_roll() -> void:
	var combat_skill: int = _selected_character.get("combat",
		_selected_character.get("combat_skill", 0))
	var species: String = str(_selected_character.get("species", "human"))
	var stuns: int = _selected_character.get("stun_markers", 0)
	var is_aiming: bool = _selected_character.get("is_aiming", false)
	var is_snap_fire: bool = _selected_character.get("is_holding_snap", false)

	var target_in_cover: bool = _cover_check.button_pressed
	var range_inches: float = _range_spin.value
	var attacker_elevated: bool = _elevated_check.button_pressed

	# Determine weapon range from character equipment (fallback to rifle)
	var weapon_range: int = _selected_character.get("weapon_range",
		BattleCalculations.RIFLE_RANGE)

	# Calculate hit threshold via BattleCalculations
	var modifiers := {
		"is_stunned": stuns > 0,
		"is_suppressed": false,
		"has_aim_bonus": is_aiming,
	}

	var threshold: int = BattleCalculations.calculate_hit_threshold(
		combat_skill, target_in_cover, attacker_elevated, false,
		range_inches, weapon_range, modifiers
	)

	# Roll
	var roll: int = _roll_d6()

	# Aim: reroll 1s (Core Rules p.46)
	var aim_rerolled: bool = false
	if is_aiming and roll == 1:
		roll = _roll_d6()
		aim_rerolled = true

	# Snap fire penalty (Core Rules p.113)
	var snap_penalty: int = -1 if is_snap_fire else 0

	var effective_roll: int = roll + combat_skill + snap_penalty
	var hit: bool = effective_roll >= threshold

	_last_result = {
		"type": "hit",
		"roll": roll,
		"combat_skill": combat_skill,
		"threshold": threshold,
		"hit": hit,
		"natural_six": roll == 6,
	}

	# Build breakdown
	var bbcode := "[b]HIT ROLL[/b]\n"
	bbcode += "Roll: [b]%d[/b]" % roll
	if aim_rerolled:
		bbcode += " [color=#10B981](rerolled 1 — Aimed)[/color]"
	bbcode += "\n"
	bbcode += "+ Combat Skill: [b]+%d[/b]\n" % combat_skill
	if snap_penalty != 0:
		bbcode += "[color=#DC2626]+ Snap Fire: %d[/color]\n" % snap_penalty
	if stuns > 0:
		bbcode += "[color=#D97706]Stunned (x%d): penalty applied[/color]\n" % stuns
	bbcode += "Total: [b]%d[/b] vs threshold [b]%d+[/b]\n" % [effective_roll, threshold]

	# Target info
	bbcode += "  (Range: %d\", %s, %s)\n" % [
		int(range_inches),
		"Cover" if target_in_cover else "Open",
		"Elevated" if attacker_elevated else "Ground"
	]

	if hit:
		bbcode += "[color=#10B981][b]HIT![/b][/color]"
		if roll == 6:
			bbcode += " [color=#10B981](Natural 6 — always hits)[/color]"
	else:
		bbcode += "[color=#DC2626][b]MISS[/b][/color]"

	_result_display.text = bbcode
	_check_luck_available()

	var char_name: String = str(_selected_character.get("character_name",
		_selected_character.get("name", "Unknown")))
	roll_completed.emit(char_name, "hit", _last_result)

func _execute_brawl_roll() -> void:
	var char_name: String = str(_selected_character.get("character_name",
		_selected_character.get("name", "Unknown")))
	var species: String = str(_selected_character.get("species", "human"))

	# Build attacker dict for BattleCalculations
	var attacker := {
		"combat_skill": _selected_character.get("combat",
			_selected_character.get("combat_skill", 0)),
		"species": species,
		"weapon_type": _get_attacker_brawl_weapon_type(),
		"weapon_traits": _selected_character.get("weapon_traits", []),
	}

	# Build defender dict from manual inputs
	var weapon_bonus_idx: int = _opponent_weapon_option.selected
	var defender_weapon_type: String = "none"
	match weapon_bonus_idx:
		1: defender_weapon_type = "pistol"
		2: defender_weapon_type = "melee"

	var defender := {
		"combat_skill": int(_opponent_combat_spin.value),
		"species": _opponent_species_edit.text.strip_edges() if _opponent_species_edit.text.strip_edges() != "" else "human",
		"weapon_type": defender_weapon_type,
		"weapon_traits": [],
	}

	# Outnumbering bonus (applied to attacker side per Core Rules p.45)
	var outnumber_bonus: int = int(_outnumbering_spin.value)
	if outnumber_bonus > 0:
		attacker["outnumbering_bonus"] = outnumber_bonus

	# Stun bonus: +1 per stun marker on opponent (Core Rules p.45)
	var opponent_stuns: int = int(_opponent_stun_spin.value)
	if opponent_stuns > 0:
		attacker["opponent_stun_bonus"] = opponent_stuns

	# Resolve via BattleCalculations
	var result: Dictionary = BattleCalculations.resolve_brawl(attacker, defender, _roll_d6)

	_last_result = result
	_last_result["type"] = "brawl"

	# Build breakdown
	var bbcode := "[b]BRAWL[/b]\n"
	bbcode += "[b]%s[/b] vs Opponent\n\n" % char_name

	# Attacker side
	bbcode += "Attacker roll: [b]%d[/b]" % result.get("attacker_raw_roll", 0)
	if result.get("attacker_kerin_rerolled", false):
		bbcode += " [color=#10B981](K'Erin: best of 2)[/color]"
	if result.get("attacker_rerolled", false):
		bbcode += " [color=#10B981](Elegant reroll)[/color]"
	bbcode += "\n"
	bbcode += "+ Combat: +%d, Weapon: +%d" % [
		attacker["combat_skill"], result.get("attacker_weapon_bonus", 0)]
	if result.get("attacker_species_bonus", 0) != 0:
		bbcode += ", Species: +%d" % result.get("attacker_species_bonus", 0)
	if outnumber_bonus > 0:
		bbcode += " [color=#10B981]+%d outnumber[/color]" % outnumber_bonus
	if opponent_stuns > 0:
		bbcode += " [color=#10B981]+%d stun bonus[/color]" % opponent_stuns
	bbcode += "\nAttacker Total: [b]%d[/b]\n\n" % (result.get("attacker_total", 0) + outnumber_bonus + opponent_stuns)

	# Defender side
	bbcode += "Defender roll: [b]%d[/b]" % result.get("defender_raw_roll", 0)
	if result.get("defender_kerin_rerolled", false):
		bbcode += " [color=#10B981](K'Erin: best of 2)[/color]"
	bbcode += "\n"
	bbcode += "+ Combat: +%d, Weapon: +%d" % [
		defender["combat_skill"], result.get("defender_weapon_bonus", 0)]
	bbcode += "\nDefender Total: [b]%d[/b]\n\n" % result.get("defender_total", 0)

	# Winner
	var winner: String = result.get("winner", "draw")
	match winner:
		"attacker":
			bbcode += "[color=#10B981][b]%s WINS![/b][/color]\n" % char_name.to_upper()
			bbcode += "Opponent takes a Hit + pushed 1\" back\n"
			bbcode += "%s gets 2\" bonus move" % char_name
		"defender":
			bbcode += "[color=#DC2626][b]OPPONENT WINS![/b][/color]\n"
			bbcode += "%s takes a Hit + pushed 1\" back" % char_name
		_:
			bbcode += "[color=#D97706][b]DRAW — both take a Hit![/b][/color]"

	# Natural 6/1 effects
	var effects: Array = result.get("effects", [])
	if "natural_6_attacker" in effects or result.get("attacker_raw_roll", 0) == 6:
		bbcode += "\n[color=#10B981]Natural 6: Extra hit on opponent![/color]"
	if "natural_1_attacker" in effects or result.get("attacker_raw_roll", 0) == 1:
		bbcode += "\n[color=#DC2626]Natural 1: Opponent gets extra hit![/color]"
	if result.get("defender_raw_roll", 0) == 6:
		bbcode += "\n[color=#DC2626]Defender Natural 6: Extra hit on %s![/color]" % char_name
	if result.get("defender_raw_roll", 0) == 1:
		bbcode += "\n[color=#10B981]Defender Natural 1: %s gets extra hit![/color]" % char_name

	_result_display.text = bbcode
	_check_luck_available()
	roll_completed.emit(char_name, "brawl", _last_result)

func _execute_damage_roll() -> void:
	var weapon_damage: int = int(_weapon_damage_spin.value)
	var target_toughness: int = int(_target_toughness_spin.value)

	# Map option indices to type strings
	var armor_types: Array = ["none", "light", "combat", "heavy", "powered"]
	var screen_types: Array = ["none", "basic", "military", "advanced"]
	var armor_type: String = armor_types[_armor_option.selected]
	var screen_type: String = screen_types[_screen_option.selected]

	var weapon_traits: Array = []
	if _piercing_check.button_pressed:
		weapon_traits.append("piercing")

	# Roll damage
	var damage_roll: int = _roll_d6()
	var total_damage: int = damage_roll + weapon_damage
	var is_casualty: bool = total_damage >= target_toughness or damage_roll == 6

	_last_result = {
		"type": "damage",
		"roll": damage_roll,
		"weapon_damage": weapon_damage,
		"total": total_damage,
		"toughness": target_toughness,
		"is_casualty": is_casualty,
	}

	var bbcode := "[b]DAMAGE ROLL[/b]\n"
	bbcode += "Roll: [b]%d[/b] + Weapon Damage: [b]+%d[/b] = [b]%d[/b]\n" % [
		damage_roll, weapon_damage, total_damage]
	bbcode += "vs Toughness: [b]%d[/b]\n\n" % target_toughness

	if is_casualty:
		bbcode += "[color=#10B981][b]CASUALTY![/b][/color]"
		if damage_roll == 6:
			bbcode += " [color=#10B981](Natural 6 — always kills)[/color]"

		# Check saves
		if armor_type != "none" or screen_type != "none":
			var save_roll: int = _roll_d6()
			var target_dict := {"armor": armor_type, "screen": screen_type}
			var save_result: Dictionary = BattleCalculations.resolve_saves(
				save_roll, target_dict, weapon_traits, total_damage)

			_last_result["save_roll"] = save_roll
			_last_result["saved"] = save_result.get("saved", false)

			bbcode += "\n\n[b]SAVING THROW[/b]\n"
			bbcode += "Roll: [b]%d[/b]" % save_roll
			if save_result.get("armor_pierced", false):
				bbcode += " [color=#D97706](Armor PIERCED — only screen counts)[/color]"
			bbcode += "\n"

			if save_result.get("saved", false):
				bbcode += "[color=#10B981][b]SAVED![/b] Target is Stunned instead[/color]"
			else:
				bbcode += "[color=#DC2626][b]NOT SAVED — Remove as casualty[/b][/color]"
		else:
			bbcode += "\nNo saves available — remove as casualty"
	else:
		bbcode += "[color=#D97706][b]STUNNED[/b] — pushed 1\" back, place Stun marker[/color]"

	_result_display.text = bbcode
	_check_luck_available()

	var char_name: String = str(_selected_character.get("character_name",
		_selected_character.get("name", "Unknown")))
	roll_completed.emit(char_name, "damage", _last_result)

func _execute_reaction_roll() -> void:
	var reactions: int = _selected_character.get("reactions",
		_selected_character.get("reaction", 1))
	var char_name: String = str(_selected_character.get("character_name",
		_selected_character.get("name", "Unknown")))

	var roll: int = _roll_d6()
	var is_quick: bool = roll <= reactions

	_last_result = {
		"type": "reaction",
		"roll": roll,
		"reactions_stat": reactions,
		"is_quick": is_quick,
	}

	var bbcode := "[b]REACTION ROLL[/b] — %s\n" % char_name
	bbcode += "Roll: [b]%d[/b] vs Reactions: [b]%d[/b]\n\n" % [roll, reactions]

	if is_quick:
		bbcode += "[color=#10B981][b]QUICK ACTIONS[/b] — Acts before enemies![/color]\n"
		bbcode += "May also hold for Snap Fire (-1 to hit)"
	else:
		bbcode += "[color=#D97706][b]SLOW ACTIONS[/b] — Acts after enemies[/color]"

	_result_display.text = bbcode
	_luck_button.visible = false  # No luck spending on reaction rolls
	roll_completed.emit(char_name, "reaction", _last_result)

# =====================================================
# LUCK SYSTEM
# =====================================================

func _check_luck_available() -> void:
	if _selected_character.is_empty():
		_luck_button.visible = false
		return

	# Check if we have a Character resource to pass to LuckSystem
	var char_resource: Resource = _selected_character.get("_resource", null)
	if char_resource and LuckSystem.can_spend_luck(char_resource):
		var remaining: int = LuckSystem.get_available_luck(char_resource)
		_luck_button.text = "Spend Luck to Reroll (%d remaining)" % remaining
		_luck_button.visible = true
	else:
		_luck_button.visible = false

func _on_luck_pressed() -> void:
	var char_resource: Resource = _selected_character.get("_resource", null)
	if not char_resource:
		return

	var original_roll: int = _last_result.get("roll", 0)
	var luck_result: Dictionary = LuckSystem.spend_luck_reroll(
		char_resource, original_roll, _roll_d6)

	if luck_result.get("success", false):
		var new_roll: int = luck_result.get("new_roll", original_roll)
		var old_text: String = _result_display.text
		_result_display.text = old_text + "\n\n[color=#F59E0B][b]LUCK REROLL![/b] New roll: %d (was %d) — %d Luck remaining[/color]" % [
			new_roll, original_roll, luck_result.get("luck_remaining", 0)]
		_luck_button.visible = false

# =====================================================
# HELPERS
# =====================================================

func _get_attacker_brawl_weapon_type() -> String:
	var weapon_traits: Array = _selected_character.get("weapon_traits", [])
	if "melee" in weapon_traits:
		return "melee"
	elif "pistol" in weapon_traits:
		return "pistol"
	return "none"
