class_name FPCM_MoralePanicTracker
extends PanelContainer

## Enemy Morale — Core Rules pp.114-118
##
## At the end of each round, if any enemies were killed in combat:
## - Roll 1D6 per casualty this round
## - Each die within the enemy's Panic range = 1 enemy Bails
## - Remove bailing figures closest to enemy battlefield edge first
## - Bailed enemies do NOT count as killed (no extra morale dice)
##
## Modifiers:
## - Boss alive: Panic range -1
## - Boss killed this round: +1 extra morale die
## - Stubborn: Ignore the first casualty of the battle
## - Fearless: Lieutenants and Unique Individuals never bail
## - Cowardly: Lieutenants ARE affected by morale (exception)
## - Dogged: 1-2 figures remaining = become Fearless

# Signals
signal morale_check_performed(result: Dictionary)
signal enemies_bailed(bail_count: int)

# UI References (wired in _ready from code-built UI)
var _title_label: Label
var _enemy_info_label: Label
var _status_label: Label
var _modifiers_label: Label
var _kills_spin: SpinBox
var _add_kill_btn: Button
var _roll_btn: Button
var _new_round_btn: Button
var _result_display: RichTextLabel

# Boss toggle
var _boss_alive_check: CheckBox
var _boss_killed_check: CheckBox

# Enemy tracking
var total_enemies: int = 0
var enemies_remaining: int = 0
var casualties_this_round: int = 0
var fled_enemies: int = 0
var enemy_type_name: String = ""

# Panic range (parsed from "1-2" format in enemy data)
var panic_range_max: int = 2  # Upper bound — die <= this = bail

# Modifiers (Core Rules pp.114-118)
var has_boss: bool = false
var boss_killed_this_round: bool = false
var is_stubborn: bool = false
var _stubborn_first_ignored: bool = false  # Track if first casualty was already ignored
var is_fearless_all: bool = false  # Panic 0 = fight to death
var has_cowardly: bool = false     # Lieutenants affected by morale
var is_dogged: bool = false        # 1-2 remaining = Fearless
var lieutenant_count: int = 0
var unique_individual_present: bool = false


func _ready() -> void:
	_build_ui()
	_update_display()


## ── PUBLIC API ──────────────────────────────────────────────

func set_enemy_count(count: int) -> void:
	total_enemies = count
	enemies_remaining = count
	casualties_this_round = 0
	fled_enemies = 0
	_stubborn_first_ignored = false
	_update_display()

func setup_from_enemy_data(data: Dictionary) -> void:
	## Initialize from enemy_types.json entry
	enemy_type_name = data.get("name", "Unknown")
	_parse_panic_range(str(data.get("panic", "1")))

	# Detect special rules
	var special: Array = data.get("special_rules", [])
	is_stubborn = false
	is_fearless_all = false
	has_cowardly = false
	is_dogged = false

	for rule_text in special:
		var rule_lower: String = str(rule_text).to_lower()
		if "stubborn" in rule_lower:
			is_stubborn = true
		if "fearless" in rule_lower:
			is_fearless_all = true
		if "cowardly" in rule_lower:
			has_cowardly = true
		if "dogged" in rule_lower:
			is_dogged = true

	# Panic range 0 = fight to death (also flagged as fearless)
	if panic_range_max <= 0:
		is_fearless_all = true

	_update_display()

func new_round() -> void:
	## Reset per-round state
	casualties_this_round = 0
	boss_killed_this_round = false
	if _kills_spin:
		_kills_spin.value = 0
	if _boss_killed_check:
		_boss_killed_check.button_pressed = false
	_clear_result()
	_update_display()


## ── CORE MECHANIC: perform_morale_check() ───────────────────

func perform_morale_check() -> Dictionary:
	## The ONE morale mechanic (Core Rules pp.114-118)
	## Roll 1D6 per casualty. Each die within panic range = 1 bail.
	var kills: int = casualties_this_round
	var result: Dictionary = {
		"enemy_type": enemy_type_name,
		"kills": kills,
		"bails": 0,
		"rolls": [],
		"effective_panic": 0,
		"message": "",
	}

	# Stubborn: ignore first casualty of the battle (not per-round)
	if is_stubborn and not _stubborn_first_ignored and kills > 0:
		kills -= 1
		_stubborn_first_ignored = true
		result["stubborn_applied"] = true

	# No kills after modifier → no check
	if kills <= 0:
		result.message = "No casualties to check (Stubborn ignored first kill)." \
			if result.get("stubborn_applied", false) \
			else "No casualties this round — no morale check needed."
		_display_check_result(result)
		morale_check_performed.emit(result)
		return result

	# Dogged: 1-2 remaining = become Fearless
	if is_dogged and enemies_remaining <= 2:
		result.message = "Dogged: %d remaining — enemies become Fearless! No morale check." \
			% enemies_remaining
		_display_check_result(result)
		morale_check_performed.emit(result)
		return result

	# Calculate effective panic range
	var effective_panic: int = panic_range_max
	# Read boss state from UI toggles
	has_boss = _boss_alive_check.button_pressed if _boss_alive_check else has_boss
	boss_killed_this_round = _boss_killed_check.button_pressed \
		if _boss_killed_check else boss_killed_this_round

	if has_boss and not boss_killed_this_round:
		effective_panic -= 1  # Boss reduces panic range by 1

	result.effective_panic = effective_panic

	# Fearless / panic 0 → fight to the death
	if effective_panic <= 0 or is_fearless_all:
		result.message = "Panic range 0 — enemies fight to the death!"
		_display_check_result(result)
		morale_check_performed.emit(result)
		return result

	# Boss killed this round: +1 extra die
	var dice_count: int = kills
	if boss_killed_this_round:
		dice_count += 1
		result["boss_extra_die"] = true

	# Roll D6 per effective kill
	var rolls: Array[int] = []
	var bails: int = 0
	for i: int in range(dice_count):
		var roll: int = randi_range(1, 6)
		rolls.append(roll)
		if roll <= effective_panic:
			bails += 1

	result.rolls = rolls
	result.bails = bails

	# Cap bails at enemies that CAN bail
	# Fearless figures (Lieutenants unless Cowardly, Unique Individuals) skip
	var fearless_count: int = 0
	if not has_cowardly:
		fearless_count += lieutenant_count
	if unique_individual_present:
		fearless_count += 1
	var bailable: int = maxi(0, enemies_remaining - fearless_count)
	var actual_bails: int = mini(bails, bailable)
	result.bails = actual_bails

	# Apply bails
	if actual_bails > 0:
		fled_enemies += actual_bails
		enemies_remaining = maxi(0, enemies_remaining - actual_bails)
		enemies_bailed.emit(actual_bails)

	_display_check_result(result)
	_update_display()
	morale_check_performed.emit(result)
	return result


## ── UI BUILD ────────────────────────────────────────────────

func _build_ui() -> void:
	## Build the entire panel UI from code (no .tscn dependencies
	## beyond the root PanelContainer shell)
	# Panel style
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_ELEVATED
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.border_color = UIColors.COLOR_RED
	style.set_content_margin_all(UIColors.SPACING_MD)
	add_theme_stylebox_override("panel", style)

	# Clear any .tscn children
	for child in get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIColors.SPACING_SM)
	add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "Enemy Morale"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_LG)
	_title_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	vbox.add_child(_title_label)

	vbox.add_child(HSeparator.new())

	# Enemy info row: "Gangers — Panic: 1-2"
	_enemy_info_label = Label.new()
	_enemy_info_label.text = "No enemy data"
	_enemy_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_info_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_MD)
	_enemy_info_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	vbox.add_child(_enemy_info_label)

	# Status row: "Remaining: 5/8 | Bailed: 3"
	_status_label = Label.new()
	_status_label.text = "Enemies: 0 / 0"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	_status_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	vbox.add_child(_status_label)

	# Modifiers label (conditional)
	_modifiers_label = Label.new()
	_modifiers_label.text = ""
	_modifiers_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modifiers_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XS)
	_modifiers_label.add_theme_color_override("font_color", UIColors.COLOR_AMBER)
	_modifiers_label.visible = false
	vbox.add_child(_modifiers_label)

	vbox.add_child(HSeparator.new())

	# Boss toggles row
	var boss_row := HBoxContainer.new()
	boss_row.add_theme_constant_override("separation", UIColors.SPACING_MD)
	boss_row.alignment = BoxContainer.ALIGNMENT_CENTER

	_boss_alive_check = CheckBox.new()
	_boss_alive_check.text = "Boss alive (-1 panic)"
	_boss_alive_check.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	_boss_alive_check.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	boss_row.add_child(_boss_alive_check)

	_boss_killed_check = CheckBox.new()
	_boss_killed_check.text = "Boss killed (+1 die)"
	_boss_killed_check.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	_boss_killed_check.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	boss_row.add_child(_boss_killed_check)

	vbox.add_child(boss_row)

	# Kills input row
	var kills_row := HBoxContainer.new()
	kills_row.add_theme_constant_override("separation", UIColors.SPACING_SM)
	kills_row.alignment = BoxContainer.ALIGNMENT_CENTER

	var kills_lbl := Label.new()
	kills_lbl.text = "Kills this round:"
	kills_lbl.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	kills_lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	kills_row.add_child(kills_lbl)

	_kills_spin = SpinBox.new()
	_kills_spin.min_value = 0
	_kills_spin.max_value = 20
	_kills_spin.value = 0
	_kills_spin.custom_minimum_size = Vector2(70, UIColors.TOUCH_TARGET_MIN)
	_kills_spin.value_changed.connect(_on_kills_changed)
	kills_row.add_child(_kills_spin)

	_add_kill_btn = Button.new()
	_add_kill_btn.text = "+1 Kill"
	_add_kill_btn.custom_minimum_size = Vector2(80, UIColors.TOUCH_TARGET_MIN)
	_add_kill_btn.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	_add_kill_btn.pressed.connect(_on_add_kill)
	kills_row.add_child(_add_kill_btn)

	vbox.add_child(kills_row)

	# Action buttons row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", UIColors.SPACING_SM)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER

	_roll_btn = Button.new()
	_roll_btn.text = "Roll Morale Check"
	_roll_btn.custom_minimum_size = Vector2(160, UIColors.TOUCH_TARGET_MIN)
	_roll_btn.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_MD)
	var roll_style := StyleBoxFlat.new()
	roll_style.bg_color = Color(UIColors.COLOR_RED, 0.7)
	roll_style.set_corner_radius_all(6)
	roll_style.set_content_margin_all(UIColors.SPACING_XS)
	_roll_btn.add_theme_stylebox_override("normal", roll_style)
	_roll_btn.pressed.connect(_on_roll_morale_check)
	btn_row.add_child(_roll_btn)

	_new_round_btn = Button.new()
	_new_round_btn.text = "New Round"
	_new_round_btn.custom_minimum_size = Vector2(110, UIColors.TOUCH_TARGET_MIN)
	_new_round_btn.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	_new_round_btn.pressed.connect(new_round)
	btn_row.add_child(_new_round_btn)

	vbox.add_child(btn_row)

	# Result display (BBCode)
	_result_display = RichTextLabel.new()
	_result_display.bbcode_enabled = true
	_result_display.fit_content = true
	_result_display.custom_minimum_size = Vector2(0, 60)
	_result_display.scroll_active = false
	_result_display.add_theme_font_size_override(
		"normal_font_size", UIColors.FONT_SIZE_SM)
	_result_display.add_theme_color_override(
		"default_color", UIColors.COLOR_TEXT_PRIMARY)
	vbox.add_child(_result_display)


## ── DISPLAY ─────────────────────────────────────────────────

func _update_display() -> void:
	# Enemy info
	if _enemy_info_label:
		if is_fearless_all and panic_range_max <= 0:
			_enemy_info_label.text = "%s — Panic: 0 (fight to the death)" \
				% enemy_type_name
		else:
			_enemy_info_label.text = "%s — Panic: 1-%d" \
				% [enemy_type_name, panic_range_max]

	# Status
	if _status_label:
		_status_label.text = "Remaining: %d / %d | Bailed: %d" \
			% [enemies_remaining, total_enemies, fled_enemies]
		if enemies_remaining == 0:
			_status_label.add_theme_color_override(
				"font_color", UIColors.COLOR_EMERALD)
		elif enemies_remaining <= total_enemies / 2:
			_status_label.add_theme_color_override(
				"font_color", UIColors.COLOR_AMBER)
		else:
			_status_label.add_theme_color_override(
				"font_color", UIColors.COLOR_TEXT_SECONDARY)

	# Modifiers
	if _modifiers_label:
		var mods: Array[String] = []
		if is_stubborn:
			mods.append("Stubborn (ignore 1st casualty)")
		if is_dogged:
			mods.append("Dogged (1-2 left = Fearless)")
		if has_cowardly:
			mods.append("Cowardly (Lieutenants roll morale)")
		if lieutenant_count > 0 and not has_cowardly:
			mods.append("%d Lieutenant(s) (Fearless)" % lieutenant_count)
		if unique_individual_present:
			mods.append("Unique Individual (Fearless)")

		if mods.size() > 0:
			_modifiers_label.text = " | ".join(mods)
			_modifiers_label.visible = true
		else:
			_modifiers_label.visible = false


func _display_check_result(result: Dictionary) -> void:
	if not _result_display:
		return

	var bbcode := ""

	# Special messages (no rolls)
	var msg: String = result.get("message", "")
	if not msg.is_empty():
		bbcode += "[color=#%s]%s[/color]" \
			% [UIColors.COLOR_AMBER.to_html(false), msg]
		_result_display.text = bbcode
		return

	# Header
	var effective_panic: int = result.get("effective_panic", panic_range_max)
	bbcode += "[b]Morale Check — %s[/b]\n" % enemy_type_name
	bbcode += "Effective Panic Range: [b]1-%d[/b]" % effective_panic
	if result.get("boss_extra_die", false):
		bbcode += " (+1 die: Boss killed)"
	if result.get("stubborn_applied", false):
		bbcode += " (Stubborn: 1st kill ignored)"
	bbcode += "\n"

	# Dice results
	var rolls: Array = result.get("rolls", [])
	var bails: int = result.get("bails", 0)

	bbcode += "Rolls: "
	for r in rolls:
		var roll_val: int = int(r)
		if roll_val <= effective_panic:
			bbcode += "[color=#%s][b]%d[/b][/color] " \
				% [UIColors.COLOR_EMERALD.to_html(false), roll_val]
		else:
			bbcode += "[color=#%s]%d[/color] " \
				% [UIColors.COLOR_TEXT_MUTED.to_html(false), roll_val]
	bbcode += "\n\n"

	# Result
	if bails > 0:
		bbcode += "[color=#%s][b]%d enemy figure(s) Bail![/b][/color]\n" \
			% [UIColors.COLOR_EMERALD.to_html(false), bails]
		bbcode += "Remove %d figure(s) closest to the enemy battlefield edge.\n" \
			% bails

		# Fearless reminder
		var fearless_notes: Array[String] = []
		if lieutenant_count > 0 and not has_cowardly:
			fearless_notes.append("Skip Lieutenants (Fearless)")
		if unique_individual_present:
			fearless_notes.append("Skip Unique Individuals (Fearless)")
		if fearless_notes.size() > 0:
			bbcode += "[color=#%s]%s[/color]\n" \
				% [UIColors.COLOR_AMBER.to_html(false),
				   " | ".join(fearless_notes)]

		bbcode += "[color=#%s]Bailed enemies do NOT count as killed.[/color]" \
			% UIColors.COLOR_TEXT_MUTED.to_html(false)
	else:
		bbcode += "[color=#%s]No enemies Bail — they hold firm.[/color]" \
			% UIColors.COLOR_AMBER.to_html(false)

	_result_display.text = bbcode


func _clear_result() -> void:
	if _result_display:
		_result_display.text = ""


## ── INPUT HANDLERS ──────────────────────────────────────────

func _on_add_kill() -> void:
	casualties_this_round += 1
	if _kills_spin:
		_kills_spin.value = casualties_this_round

func _on_kills_changed(new_value: float) -> void:
	casualties_this_round = int(new_value)

func _on_roll_morale_check() -> void:
	perform_morale_check()


## ── HELPERS ─────────────────────────────────────────────────

func _parse_panic_range(panic_str: String) -> void:
	## Parse "1-2", "1-3", "1", "0" format from enemy_types.json
	var stripped: String = panic_str.strip_edges()
	if stripped == "0":
		panic_range_max = 0
		is_fearless_all = true
		return

	if "-" in stripped:
		var parts: PackedStringArray = stripped.split("-")
		if parts.size() >= 2:
			panic_range_max = int(parts[1])
		else:
			panic_range_max = int(parts[0])
	else:
		panic_range_max = int(stripped)

	is_fearless_all = (panic_range_max <= 0)


## ── LEGACY COMPAT ───────────────────────────────────────────
## These methods match the old API so TacticalBattleUI doesn't crash
## while we update signal connections.

func set_base_morale(_value: int) -> void:
	pass  # No longer used — panic range comes from enemy data

func set_morale_modifier(_modifier: int) -> void:
	pass  # No longer used

func add_casualty() -> void:
	## Legacy: increment kill count
	casualties_this_round += 1
	if _kills_spin:
		_kills_spin.value = casualties_this_round
