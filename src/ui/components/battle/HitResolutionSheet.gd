class_name FPCM_HitResolutionSheet
extends PanelContainer

## Resolving Hits — Core Rules p.46.
##
## "If a character is Hit, regardless of the source, roll 1D6 and add the Damage
## rating of the attack. If the result equals or exceeds the Toughness of the
## target or is a natural 6, the character becomes a casualty and is removed from
## play. A roll that is less than Toughness will push the target 1" directly away
## from the attacker... Mark the figure as Stunned."
##
## ── WHY THIS EXISTS ─────────────────────────────────────────────────────────
## The played path had no hit resolution at all. `CharacterStatusCard` carried a
## "Damage" button that called `apply_damage(1)`, decrementing a `current_health`
## that TacticalBattleUI seeded as `max_health = toughness`. That is a hit-point
## model, and Five Parsecs does not have one: a Hit is a casualty or a Stun, and
## nothing in between. A Toughness 3 figure needed three presses to go down, so a
## player following the book had to translate every result themselves and the
## on-screen "2 / 3 HP" meant nothing in the rules.
##
## The correct resolution already existed one call away, in
## `BattleCalculations.resolve_hit_outcome()` — implemented, unit-tested, and
## reached only by the auto-resolve and brawl paths. This sheet calls it.
##
## ── COMPANION MODEL ─────────────────────────────────────────────────────────
## The player owns the physical table, so the two book outcomes are ALWAYS
## available as direct declarations — they may well have rolled the die in their
## hand already. The dice helper is offered on top of that at ASSISTED+, never
## instead of it.

const BattleCalculationsRef = preload("res://src/core/battle/BattleCalculations.gd")

## outcome: {result: "down"|"stun", roll, total, natural_6, damage, save_roll,
##           saved, declared, credited_to}
signal hit_resolved(outcome: Dictionary)
signal cancelled

var _figure_name: String = ""
var _toughness: int = 3
var _tier: int = 0
var _is_enemy: bool = false
var _crew_names: Array[String] = []
var _credited_default: String = ""

var _damage_spin: SpinBox = null
var _save_spin: SpinBox = null
var _credit_btn: OptionButton = null
var _result_label: RichTextLabel = null
var _apply_btn: Button = null
## A rolled result is DISPLAYED first and applied on a second, explicit press.
## Emitting straight from the roll would apply the outcome in the same frame the
## player first sees the number, which is the thing they most want to read.
var _pending: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## `crew_names` / `credited_default` drive the kill-attribution picker and are only
## used when the target is an enemy. Core Rules p.123 pays XP for "the first
## casualty of the battle" and for killing a Unique Individual, and the app could
## not see who scored either — those keys had no producer outside the manual
## results form, so a played battle never earned them.
func setup(figure_name: String, toughness: int, tier: int, is_enemy: bool,
		crew_names: Array = [], credited_default: String = "") -> void:
	_figure_name = figure_name
	_toughness = maxi(1, toughness)
	_tier = tier
	_is_enemy = is_enemy
	_crew_names.clear()
	for n in crew_names:
		_crew_names.append(str(n))
	_credited_default = credited_default
	_build()


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_BASE
	style.border_color = UIColors.COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(UIColors.SPACING_LG)
	add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UIColors.SPACING_MD)
	add_child(col)

	var title := Label.new()
	title.text = "%s is Hit" % _figure_name
	title.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_LG)
	title.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)

	var rule := Label.new()
	rule.text = ("Roll 1D6 and add the attack's Damage. Equal to or above "
		+ "Toughness %d, or a natural 6, and the figure is a casualty — remove "
		+ "it. Below that, push it 1\" away and mark it Stunned. "
		+ "(Core Rules p.46)") % _toughness
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	rule.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	col.add_child(rule)

	if _is_enemy and not _crew_names.is_empty():
		col.add_child(_build_credit_row())

	# The player's own declaration always comes first: they are looking at the
	# table and may have rolled the die already.
	var declare := Label.new()
	declare.text = "What happened on the table?"
	declare.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	declare.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	col.add_child(declare)

	var down_btn := _make_button("Casualty — remove the figure",
		UIColors.COLOR_DANGER)
	down_btn.pressed.connect(_on_declared.bind("down"))
	col.add_child(down_btn)

	var stun_btn := _make_button("Stunned — push back 1\"", UIColors.COLOR_WARNING)
	stun_btn.pressed.connect(_on_declared.bind("stun"))
	col.add_child(stun_btn)

	if _tier >= 1:
		col.add_child(HSeparator.new())
		col.add_child(_build_roller())

	var cancel := _make_button("Cancel", UIColors.COLOR_ELEVATED)
	cancel.pressed.connect(func() -> void: cancelled.emit())
	col.add_child(cancel)


func _build_credit_row() -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", UIColors.SPACING_XS)
	var lbl := Label.new()
	lbl.text = "Credited to"
	lbl.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	row.add_child(lbl)
	_credit_btn = OptionButton.new()
	_credit_btn.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	for i in range(_crew_names.size()):
		_credit_btn.add_item(_crew_names[i], i)
		if _crew_names[i] == _credited_default:
			_credit_btn.select(i)
	row.add_child(_credit_btn)
	return row


func _build_roller() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIColors.SPACING_SM)

	var hdr := Label.new()
	hdr.text = "…or let the app roll it"
	hdr.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	hdr.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	box.add_child(hdr)

	_damage_spin = _labelled_spin(box, "Weapon Damage", 0, 0, 6)
	# p.46: "A successful Saving Throw roll means the Hit has been deflected.
	# However, the deflection still leaves the figure Stunned." 0 = no save.
	_save_spin = _labelled_spin(box, "Saving Throw (0 = none)", 0, 0, 6)

	var roll_btn := _make_button("Roll 1D6", UIColors.COLOR_ACCENT)
	roll_btn.pressed.connect(_on_roll_pressed)
	box.add_child(roll_btn)

	_result_label = RichTextLabel.new()
	_result_label.bbcode_enabled = true
	_result_label.fit_content = true
	_result_label.scroll_active = false
	_result_label.visible = false
	_result_label.add_theme_font_size_override("normal_font_size",
		UIColors.FONT_SIZE_SM)
	box.add_child(_result_label)

	_apply_btn = _make_button("Apply", UIColors.COLOR_EMERALD)
	_apply_btn.visible = false
	_apply_btn.pressed.connect(_on_apply_pressed)
	box.add_child(_apply_btn)
	return box


func _labelled_spin(parent: Node, text: String, value: int, lo: int,
		hi: int) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIColors.SPACING_SM)
	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	row.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = lo
	spin.max_value = hi
	spin.value = value
	spin.custom_minimum_size = Vector2(96, UIColors.TOUCH_TARGET_MIN)
	row.add_child(spin)
	parent.add_child(row)
	return spin


func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.set_corner_radius_all(8)
	st.set_content_margin_all(UIColors.SPACING_SM)
	btn.add_theme_stylebox_override("normal", st)
	var hov := st.duplicate()
	hov.bg_color = color.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	return btn


func _credited_to() -> String:
	if _credit_btn == null or not is_instance_valid(_credit_btn):
		return _credited_default
	var idx: int = _credit_btn.selected
	if idx < 0 or idx >= _crew_names.size():
		return _credited_default
	return _crew_names[idx]


func _on_declared(result: String) -> void:
	hit_resolved.emit({
		"result": result,
		"declared": true,
		"saved": false,
		"credited_to": _credited_to() if result == "down" else "",
	})


func _on_roll_pressed() -> void:
	var damage: int = int(_damage_spin.value)
	var save_target: int = int(_save_spin.value)
	var roller: Callable = func() -> int: return _rng.randi_range(1, 6)

	# p.46: the save is rolled against the Hit and, when it succeeds, replaces the
	# casualty with a Stun — it does not remove the Stun as well.
	if save_target > 0:
		var save_roll: int = roller.call()
		if save_roll >= save_target:
			_show_result("[color=#D97706]Save %d vs %d+ — deflected. The figure is still Stunned (p.46).[/color]"
				% [save_roll, save_target])
			_stage({
				"result": "stun",
				"declared": false,
				"saved": true,
				"save_roll": save_roll,
				"credited_to": "",
			})
			return

	var out: Dictionary = BattleCalculationsRef.resolve_hit_outcome(
		damage, _toughness, roller)
	var txt: String = "Rolled %d + %d Damage = %d vs Toughness %d" % [
		int(out.get("roll", 0)), damage, int(out.get("total", 0)), _toughness]
	if bool(out.get("natural_6", false)):
		txt += " — natural 6"
	if bool(out.get("casualty", false)):
		_show_result("[color=#DC2626]%s → CASUALTY, remove the figure.[/color]" % txt)
	else:
		_show_result("[color=#D97706]%s → Stunned, push back 1\".[/color]" % txt)
	_stage({
		"result": "down" if bool(out.get("casualty", false)) else "stun",
		"declared": false,
		"saved": false,
		"roll": int(out.get("roll", 0)),
		"total": int(out.get("total", 0)),
		"natural_6": bool(out.get("natural_6", false)),
		"damage": damage,
		"credited_to": _credited_to() if bool(out.get("casualty", false)) else "",
	})


func _stage(outcome: Dictionary) -> void:
	## Hold the rolled outcome until the player confirms it.
	_pending = outcome
	if _apply_btn and is_instance_valid(_apply_btn):
		_apply_btn.text = ("Apply — remove the figure"
			if str(outcome.get("result", "")) == "down"
			else "Apply — Stunned")
		_apply_btn.visible = true


func _on_apply_pressed() -> void:
	if _pending.is_empty():
		return
	hit_resolved.emit(_pending)


func _show_result(bbcode: String) -> void:
	if _result_label == null or not is_instance_valid(_result_label):
		return
	_result_label.text = bbcode
	_result_label.visible = true
