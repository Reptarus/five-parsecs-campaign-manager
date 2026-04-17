extends PanelContainer

## Battle Results Input Form — LOG_ONLY Tier
##
## Simple form for players who fight battles on the physical tabletop.
## The player inputs what happened, and the app calculates post-battle results.
## Produces the same result Dictionary as TacticalBattleUI._resolve_battle().

signal results_submitted(result: Dictionary)

var _crew: Array = []
var _enemy_count: int = 0
var _mission_data: Dictionary = {}
var _casualty_checks: Array[CheckBox] = []
var _injury_checks: Array[CheckBox] = []

var _outcome_btn: OptionButton
var _held_field_check: CheckBox
var _rounds_spin: SpinBox
var _enemies_defeated_spin: SpinBox
var _enemies_total_label: Label
var _submit_btn: Button

func setup(crew: Array, enemy_count: int, mission_data: Dictionary = {}) -> void:
	_crew = crew
	_enemy_count = enemy_count
	_mission_data = mission_data
	if is_inside_tree():
		_build_ui()

func _ready() -> void:
	if not _crew.is_empty():
		_build_ui()

func _build_ui() -> void:
	# Panel styling
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = UIColors.COLOR_SECONDARY
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(UIColors.SPACING_XL)
	panel_style.border_color = UIColors.COLOR_BORDER
	panel_style.set_border_width_all(1)
	add_theme_stylebox_override("panel", panel_style)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", UIColors.SPACING_LG)
	scroll.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "BATTLE RESULTS"
	title.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XL)
	title.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Record the outcome of your tabletop battle"
	subtitle.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	subtitle.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Separator
	vbox.add_child(HSeparator.new())

	# === OUTCOME SECTION ===
	var outcome_section := _create_section("OUTCOME")
	var outcome_card: VBoxContainer = outcome_section[1]
	var outcome_row := HBoxContainer.new()
	outcome_row.add_theme_constant_override("separation", UIColors.SPACING_LG)

	var outcome_left := VBoxContainer.new()
	outcome_left.add_theme_constant_override("separation", UIColors.SPACING_SM)
	var outcome_label := Label.new()
	outcome_label.text = "Battle Result"
	outcome_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	outcome_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	outcome_left.add_child(outcome_label)

	_outcome_btn = OptionButton.new()
	_outcome_btn.add_item("Won", 0)
	_outcome_btn.add_item("Lost", 1)
	_outcome_btn.add_item("Fled", 2)
	_outcome_btn.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	_outcome_btn.item_selected.connect(_on_outcome_changed)
	outcome_left.add_child(_outcome_btn)
	outcome_row.add_child(outcome_left)

	_held_field_check = CheckBox.new()
	_held_field_check.text = "Held the field"
	_held_field_check.button_pressed = true
	_held_field_check.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	outcome_row.add_child(_held_field_check)

	var rounds_vbox := VBoxContainer.new()
	rounds_vbox.add_theme_constant_override("separation", UIColors.SPACING_SM)
	var rounds_label := Label.new()
	rounds_label.text = "Rounds fought"
	rounds_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	rounds_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	rounds_vbox.add_child(rounds_label)

	_rounds_spin = SpinBox.new()
	_rounds_spin.min_value = 1
	_rounds_spin.max_value = 20
	_rounds_spin.value = 3
	_rounds_spin.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	rounds_vbox.add_child(_rounds_spin)
	outcome_row.add_child(rounds_vbox)

	outcome_card.add_child(outcome_row)
	vbox.add_child(outcome_section[0])

	# === ENEMIES SECTION ===
	var enemy_section := _create_section("ENEMIES")
	var enemy_card: VBoxContainer = enemy_section[1]
	var enemy_row := HBoxContainer.new()
	enemy_row.add_theme_constant_override("separation", UIColors.SPACING_MD)

	var defeated_label := Label.new()
	defeated_label.text = "Defeated:"
	defeated_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_MD)
	enemy_row.add_child(defeated_label)

	_enemies_defeated_spin = SpinBox.new()
	_enemies_defeated_spin.min_value = 0
	_enemies_defeated_spin.max_value = _enemy_count
	_enemies_defeated_spin.value = _enemy_count
	_enemies_defeated_spin.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	enemy_row.add_child(_enemies_defeated_spin)

	_enemies_total_label = Label.new()
	_enemies_total_label.text = "/ %d total" % _enemy_count
	_enemies_total_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_MD)
	_enemies_total_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	enemy_row.add_child(_enemies_total_label)

	enemy_card.add_child(enemy_row)
	vbox.add_child(enemy_section[0])

	# === CREW CASUALTIES SECTION ===
	var cas_section := _create_section("CREW CASUALTIES")
	var cas_card: VBoxContainer = cas_section[1]
	var cas_hint := Label.new()
	cas_hint.text = "Check crew members who were killed or removed from play"
	cas_hint.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	cas_hint.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	cas_card.add_child(cas_hint)

	_casualty_checks.clear()
	for member in _crew:
		var check := CheckBox.new()
		check.text = _get_crew_display(member)
		check.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
		check.toggled.connect(_on_casualty_toggled.bind(member))
		cas_card.add_child(check)
		_casualty_checks.append(check)
	vbox.add_child(cas_section[0])

	# === CREW INJURIES SECTION ===
	var inj_section := _create_section("CREW INJURIES")
	var inj_card: VBoxContainer = inj_section[1]
	var inj_hint := Label.new()
	inj_hint.text = "Check crew members who were injured but survived"
	inj_hint.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	inj_hint.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	inj_card.add_child(inj_hint)

	_injury_checks.clear()
	for i in _crew.size():
		var member = _crew[i]
		var check := CheckBox.new()
		check.text = _get_crew_name(member)
		check.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
		inj_card.add_child(check)
		_injury_checks.append(check)
	vbox.add_child(inj_section[0])

	# === SUBMIT BUTTON ===
	vbox.add_child(HSeparator.new())
	_submit_btn = Button.new()
	_submit_btn.text = "Submit Battle Results"
	_submit_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_COMFORT)
	_submit_btn.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_LG)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = UIColors.COLOR_EMERALD
	btn_style.set_corner_radius_all(8)
	btn_style.set_content_margin_all(12)
	_submit_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(UIColors.COLOR_EMERALD, 0.85)
	_submit_btn.add_theme_stylebox_override("hover", btn_hover)
	_submit_btn.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	_submit_btn.pressed.connect(_on_submit)
	vbox.add_child(_submit_btn)

func _create_section(title_text: String) -> Array:
	## Returns [outer_container, inner_content] — add outer to parent, children to inner
	var card_panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_TERTIARY
	style.set_corner_radius_all(8)
	style.set_content_margin_all(UIColors.SPACING_MD)
	style.border_color = UIColors.COLOR_BORDER
	style.set_border_width_all(1)
	card_panel.add_theme_stylebox_override("panel", style)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", UIColors.SPACING_SM)

	var header := Label.new()
	header.text = title_text
	header.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_LG)
	header.add_theme_color_override("font_color", UIColors.COLOR_AMBER)
	inner.add_child(header)

	card_panel.add_child(inner)
	return [card_panel, inner]

func _get_crew_display(member) -> String:
	var name_str := _get_crew_name(member)
	var combat = _safe_get(member, "combat", _safe_get(member, "combat_skill", 0))
	var react = _safe_get(member, "reactions", _safe_get(member, "reaction", 0))
	var tough = _safe_get(member, "toughness", 0)
	var spd = _safe_get(member, "speed", 4)
	return "%s  CS:%s R:%s T:%s Spd:%s" % [name_str, str(combat), str(react), str(tough), str(spd)]

func _get_crew_name(member) -> String:
	if member is Dictionary:
		return member.get("character_name", member.get("name", "Unknown"))
	elif "character_name" in member:
		return str(member.character_name)
	elif "name" in member:
		return str(member.name)
	return "Unknown"

func _safe_get(obj, key: String, default = 0):
	if obj is Dictionary:
		return obj.get(key, default)
	if key in obj:
		return obj.get(key)
	return default

func _on_outcome_changed(index: int) -> void:
	# Auto-manage held_field based on outcome
	if index == 0: # Won
		_held_field_check.button_pressed = true
		_held_field_check.disabled = false
	else: # Lost or Fled
		_held_field_check.button_pressed = false
		_held_field_check.disabled = true

func _on_casualty_toggled(_pressed: bool, _member) -> void:
	# If a crew member is marked as casualty, uncheck their injury box
	for i in _crew.size():
		if _crew[i] == _member and i < _injury_checks.size():
			if _pressed:
				_injury_checks[i].button_pressed = false
				_injury_checks[i].disabled = true
			else:
				_injury_checks[i].disabled = false

func _on_submit() -> void:
	var victory: bool = _outcome_btn.selected == 0
	var fled: bool = _outcome_btn.selected == 2

	# Build casualty and injury arrays
	var casualties_data: Array = []
	var injuries_data: Array = []
	var participants: Array = _crew.duplicate()

	for i in _crew.size():
		if i < _casualty_checks.size() and _casualty_checks[i].button_pressed:
			casualties_data.append(_crew[i])
		elif i < _injury_checks.size() and _injury_checks[i].button_pressed:
			injuries_data.append(_crew[i])

	var crew_alive: int = _crew.size() - casualties_data.size()
	var enemies_defeated: int = int(_enemies_defeated_spin.value)
	var held_field: bool = _held_field_check.button_pressed and crew_alive > 0

	var result: Dictionary = {
		# Outcome
		"victory": victory,
		"won": victory,
		"held_field": held_field,
		"auto_resolved": false,
		"fled_early": fled,
		# Statistics
		"rounds_fought": int(_rounds_spin.value),
		"enemies_defeated_count": enemies_defeated,
		"enemies_remaining": _enemy_count - enemies_defeated,
		"crew_alive": crew_alive,
		"psionic_uses": 0,
		# Crew data
		"crew_casualties": casualties_data.size(),
		"crew_injuries": injuries_data.size(),
		"crew_casualties_data": casualties_data,
		"crew_injuries_data": injuries_data,
		"crew_participants": participants,
		# Enemy data
		"defeated_enemies": [],
		"defeated_enemy_list": [],
		# Mission context passthrough
		"success": victory,
		"is_red_zone": _mission_data.get("is_red_zone", false),
		"is_black_zone": _mission_data.get("is_black_zone", false),
		"is_quest_finale": _mission_data.get("is_quest_finale", false),
		"mission_source": _mission_data.get("mission_source", "opportunity"),
		"mission_type": _mission_data.get("type", _mission_data.get("mission_type", "")),
		"enemy_type": _mission_data.get("enemy_type", "Unknown"),
	}

	results_submitted.emit(result)
