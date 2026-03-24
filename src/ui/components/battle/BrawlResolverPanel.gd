class_name FPCM_BrawlResolverPanel
extends PanelContainer

## Brawl Resolver Panel — Step-by-step melee combat resolution
##
## Walks the player through Core Rules brawl resolution (p.45):
## 1. Each side rolls D6 + Combat Skill
## 2. +2 if carrying Melee weapon, +1 if carrying Pistol
## 3. K'Erin roll twice, use better. Elegant: reroll if < 4
## 4. Natural 6 = extra hit on opponent. Natural 1 = opponent gets extra hit
## 5. Lower total takes a Hit + pushed 1". Winner gets 2" bonus move
## 6. Draw = both take a Hit
## 7. Multiple opponents: +1 bonus to outnumbering side
## 8. Stunned opponent: attacker gets +1 per stun marker removed

signal brawl_resolved(result: Dictionary)

# Design tokens
const SPACING_SM: int = UIColors.SPACING_SM
const SPACING_MD: int = UIColors.SPACING_MD
const TOUCH_TARGET_MIN: int = UIColors.TOUCH_TARGET_MIN
const FONT_SIZE_SM: int = UIColors.FONT_SIZE_SM
const FONT_SIZE_MD: int = UIColors.FONT_SIZE_MD
const FONT_SIZE_LG: int = UIColors.FONT_SIZE_LG
const FONT_SIZE_XL: int = UIColors.FONT_SIZE_XL

const COLOR_ELEVATED: Color = UIColors.COLOR_ELEVATED
const COLOR_INPUT: Color = UIColors.COLOR_INPUT
const COLOR_BORDER: Color = UIColors.COLOR_BORDER
const COLOR_ACCENT: Color = UIColors.COLOR_ACCENT
const COLOR_TEXT_PRIMARY: Color = UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY: Color = UIColors.COLOR_TEXT_SECONDARY

# State
var _crew: Array = []
var _selected_attacker: Dictionary = {}
var _rng := RandomNumberGenerator.new()

# UI references
var _attacker_label: Label
var _attacker_list: VBoxContainer
var _attacker_scroll: ScrollContainer
var _defender_combat_spin: SpinBox
var _defender_weapon_option: OptionButton
var _defender_species_edit: LineEdit
var _defender_stun_spin: SpinBox
var _outnumber_spin: SpinBox
var _roll_button: Button
var _result_display: RichTextLabel

func _ready() -> void:
	_rng.seed = Time.get_unix_time_from_system()
	if is_inside_tree():
		_setup_ui()

# =====================================================
# PUBLIC API
# =====================================================

func set_crew(crew: Array) -> void:
	_crew = crew
	_rebuild_attacker_list()

# =====================================================
# UI CONSTRUCTION
# =====================================================

func _setup_ui() -> void:
	custom_minimum_size = Vector2(380, 520)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_ELEVATED
	panel_style.set_corner_radius_all(8)
	panel_style.border_color = COLOR_BORDER
	panel_style.set_border_width_all(1)
	panel_style.content_margin_left = SPACING_MD
	panel_style.content_margin_right = SPACING_MD
	panel_style.content_margin_top = SPACING_MD
	panel_style.content_margin_bottom = SPACING_MD
	add_theme_stylebox_override("panel", panel_style)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", SPACING_SM)
	add_child(main)

	# Title
	var title := Label.new()
	title.text = "Brawl Resolver"
	title.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(title)

	# Attacker selection
	_attacker_label = Label.new()
	_attacker_label.text = "Select attacker from crew:"
	_attacker_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	_attacker_label.add_theme_color_override("font_color", COLOR_ACCENT)
	main.add_child(_attacker_label)

	_attacker_scroll = ScrollContainer.new()
	_attacker_scroll.custom_minimum_size = Vector2(0, 80)
	main.add_child(_attacker_scroll)

	_attacker_list = VBoxContainer.new()
	_attacker_list.add_theme_constant_override("separation", 4)
	_attacker_scroll.add_child(_attacker_list)

	main.add_child(HSeparator.new())

	# Defender inputs header
	var def_header := Label.new()
	def_header.text = "Defender (opponent)"
	def_header.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	def_header.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	main.add_child(def_header)

	# Defender combat skill
	var combat_row := _make_input_row("Combat Skill:")
	main.add_child(combat_row)
	_defender_combat_spin = SpinBox.new()
	_defender_combat_spin.min_value = 0
	_defender_combat_spin.max_value = 5
	_defender_combat_spin.value = 1
	_defender_combat_spin.custom_minimum_size = Vector2(80, TOUCH_TARGET_MIN)
	_defender_combat_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_row.add_child(_defender_combat_spin)

	# Defender weapon
	var weapon_row := _make_input_row("Weapon:")
	main.add_child(weapon_row)
	_defender_weapon_option = OptionButton.new()
	_defender_weapon_option.add_item("None (+0)", 0)
	_defender_weapon_option.add_item("Pistol (+1)", 1)
	_defender_weapon_option.add_item("Melee (+2)", 2)
	_defender_weapon_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	_defender_weapon_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_row.add_child(_defender_weapon_option)

	# Defender species
	var species_row := _make_input_row("Species:")
	main.add_child(species_row)
	_defender_species_edit = LineEdit.new()
	_defender_species_edit.placeholder_text = "human"
	_defender_species_edit.custom_minimum_size = Vector2(120, TOUCH_TARGET_MIN)
	_defender_species_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line_style := StyleBoxFlat.new()
	line_style.bg_color = COLOR_INPUT
	line_style.set_corner_radius_all(4)
	line_style.content_margin_left = SPACING_SM
	_defender_species_edit.add_theme_stylebox_override("normal", line_style)
	species_row.add_child(_defender_species_edit)

	# Stun markers
	var stun_row := _make_input_row("Stun Markers:")
	main.add_child(stun_row)
	_defender_stun_spin = SpinBox.new()
	_defender_stun_spin.min_value = 0
	_defender_stun_spin.max_value = 3
	_defender_stun_spin.value = 0
	_defender_stun_spin.custom_minimum_size = Vector2(80, TOUCH_TARGET_MIN)
	stun_row.add_child(_defender_stun_spin)

	# Outnumbering
	var outnumber_row := _make_input_row("Outnumbering:")
	main.add_child(outnumber_row)
	_outnumber_spin = SpinBox.new()
	_outnumber_spin.min_value = 0
	_outnumber_spin.max_value = 1
	_outnumber_spin.value = 0
	_outnumber_spin.tooltip_text = "+1 bonus to outnumbering side (Core Rules p.45)"
	_outnumber_spin.custom_minimum_size = Vector2(80, TOUCH_TARGET_MIN)
	outnumber_row.add_child(_outnumber_spin)

	# Roll button
	_roll_button = Button.new()
	_roll_button.text = "Roll Brawl"
	_roll_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	var roll_style := StyleBoxFlat.new()
	roll_style.bg_color = COLOR_ACCENT
	roll_style.set_corner_radius_all(6)
	_roll_button.add_theme_stylebox_override("normal", roll_style)
	_roll_button.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_roll_button.pressed.connect(_on_roll_pressed)
	main.add_child(_roll_button)

	# Result display
	_result_display = RichTextLabel.new()
	_result_display.bbcode_enabled = true
	_result_display.fit_content = true
	_result_display.custom_minimum_size = Vector2(0, 100)
	_result_display.scroll_active = true
	_result_display.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	_result_display.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	main.add_child(_result_display)

func _make_input_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SPACING_SM)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	row.add_child(lbl)
	return row

# =====================================================
# ATTACKER SELECTION
# =====================================================

func _rebuild_attacker_list() -> void:
	for child: Node in _attacker_list.get_children():
		child.queue_free()

	for char_data: Dictionary in _crew:
		var char_name: String = str(char_data.get("character_name", char_data.get("name", "Unknown")))
		var combat: int = char_data.get("combat", char_data.get("combat_skill", 0))
		var species: String = str(char_data.get("species", "Human"))

		var btn := Button.new()
		btn.text = "%s (C:%d, %s)" % [char_name, combat, species]
		btn.custom_minimum_size.y = 40
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = COLOR_INPUT
		btn_style.set_corner_radius_all(4)
		btn_style.content_margin_left = SPACING_SM
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.pressed.connect(_on_attacker_selected.bind(char_data))
		_attacker_list.add_child(btn)

func _on_attacker_selected(char_data: Dictionary) -> void:
	_selected_attacker = char_data
	var char_name: String = str(char_data.get("character_name", char_data.get("name", "Unknown")))
	_attacker_label.text = "Attacker: %s" % char_name

# =====================================================
# BRAWL RESOLUTION
# =====================================================

func _roll_d6() -> int:
	return _rng.randi_range(1, 6)

func _on_roll_pressed() -> void:
	if _selected_attacker.is_empty():
		_result_display.text = "[color=#DC2626]Select an attacker first![/color]"
		return

	var char_name: String = str(_selected_attacker.get("character_name",
		_selected_attacker.get("name", "Unknown")))

	# Build attacker dict for BattleCalculations
	var attacker := {
		"combat_skill": _selected_attacker.get("combat",
			_selected_attacker.get("combat_skill", 0)),
		"species": str(_selected_attacker.get("species", "human")),
		"weapon_type": _get_attacker_weapon_type(),
		"weapon_traits": _selected_attacker.get("weapon_traits", []),
	}

	# Build defender dict from inputs
	var def_weapon_type: String = "none"
	match _defender_weapon_option.selected:
		1: def_weapon_type = "pistol"
		2: def_weapon_type = "melee"

	var defender := {
		"combat_skill": int(_defender_combat_spin.value),
		"species": _defender_species_edit.text.strip_edges() if _defender_species_edit.text.strip_edges() != "" else "human",
		"weapon_type": def_weapon_type,
		"weapon_traits": [],
	}

	# Resolve via BattleCalculations
	var result: Dictionary = BattleCalculations.resolve_brawl(attacker, defender, _roll_d6)

	var outnumber_bonus: int = int(_outnumber_spin.value)
	var stun_bonus: int = int(_defender_stun_spin.value)

	# Build BBCode result
	var bbcode := "[b]BRAWL RESOLUTION[/b]\n"
	bbcode += "[b]%s[/b] vs Opponent\n\n" % char_name

	# Attacker
	bbcode += "[color=#3B82F6][b]Attacker:[/b][/color]\n"
	bbcode += "  Roll: [b]%d[/b]" % result.get("attacker_raw_roll", 0)
	if result.get("attacker_kerin_rerolled", false):
		bbcode += " [color=#10B981](K'Erin: best of 2 rolls)[/color]"
	if result.get("attacker_rerolled", false):
		bbcode += " [color=#10B981](Elegant: rerolled < 4)[/color]"
	bbcode += "\n"
	bbcode += "  + Combat Skill: +%d\n" % attacker["combat_skill"]
	bbcode += "  + Weapon: +%d\n" % result.get("attacker_weapon_bonus", 0)
	if result.get("attacker_species_bonus", 0) != 0:
		bbcode += "  + Species: +%d\n" % result.get("attacker_species_bonus", 0)
	if outnumber_bonus > 0:
		bbcode += "  [color=#10B981]+ Outnumbering: +%d[/color]\n" % outnumber_bonus
	if stun_bonus > 0:
		bbcode += "  [color=#10B981]+ Stunned opponent: +%d (per stun marker)[/color]\n" % stun_bonus
	var att_total: int = result.get("attacker_total", 0) + outnumber_bonus + stun_bonus
	bbcode += "  Total: [b]%d[/b]\n\n" % att_total

	# Defender
	bbcode += "[color=#EF4444][b]Defender:[/b][/color]\n"
	bbcode += "  Roll: [b]%d[/b]" % result.get("defender_raw_roll", 0)
	if result.get("defender_kerin_rerolled", false):
		bbcode += " [color=#10B981](K'Erin: best of 2 rolls)[/color]"
	bbcode += "\n"
	bbcode += "  + Combat Skill: +%d\n" % defender["combat_skill"]
	bbcode += "  + Weapon: +%d\n" % result.get("defender_weapon_bonus", 0)
	if result.get("defender_species_bonus", 0) != 0:
		bbcode += "  + Species: +%d\n" % result.get("defender_species_bonus", 0)
	bbcode += "  Total: [b]%d[/b]\n\n" % result.get("defender_total", 0)

	# Winner
	var winner: String = result.get("winner", "draw")
	match winner:
		"attacker":
			bbcode += "[color=#10B981][b]%s WINS THE BRAWL![/b][/color]\n" % char_name.to_upper()
			bbcode += "Opponent takes a Hit (resolve damage).\n"
			bbcode += "Opponent pushed 1\" back.\n"
			bbcode += "%s gets a 2\" bonus move.\n" % char_name
		"defender":
			bbcode += "[color=#DC2626][b]OPPONENT WINS THE BRAWL![/b][/color]\n"
			bbcode += "%s takes a Hit (resolve damage).\n" % char_name
			bbcode += "%s pushed 1\" back.\n" % char_name
		_:
			bbcode += "[color=#D97706][b]DRAW — Both combatants take a Hit![/b][/color]\n"
			bbcode += "Both pushed 1\" apart.\n"

	# Natural 6/1 special effects
	bbcode += "\n"
	var att_roll: int = result.get("attacker_raw_roll", 0)
	var def_roll: int = result.get("defender_raw_roll", 0)
	if att_roll == 6:
		bbcode += "[color=#10B981]Attacker Natural 6: Extra hit on opponent![/color]\n"
	if att_roll == 1:
		bbcode += "[color=#DC2626]Attacker Natural 1: Opponent inflicts extra hit![/color]\n"
	if def_roll == 6:
		bbcode += "[color=#DC2626]Defender Natural 6: Extra hit on %s![/color]\n" % char_name
	if def_roll == 1:
		bbcode += "[color=#10B981]Defender Natural 1: %s inflicts extra hit![/color]\n" % char_name

	# Damage instructions
	bbcode += "\n[color=#9CA3AF]Resolve Hits using highest Damage value of any Melee/Pistol weapon carried. No suitable weapon = Damage +0.[/color]"

	_result_display.text = bbcode
	brawl_resolved.emit(result)

func _get_attacker_weapon_type() -> String:
	var weapon_traits: Array = _selected_attacker.get("weapon_traits", [])
	if "melee" in weapon_traits:
		return "melee"
	elif "pistol" in weapon_traits:
		return "pistol"
	return "none"
