extends Control

## Tactics Battle Setup Panel — Covers ORDERS, RECON, BATTLE_PREP, DEPLOYMENT phases.
## Generates scenario, shows objectives, displays deployment zones.
## Covers phases 0-3 of the 8-phase turn.

signal phase_completed(phase: int, data: Dictionary)

const _UC = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := _UC.COLOR_BASE
const COLOR_ELEVATED := _UC.COLOR_ELEVATED
const COLOR_ACCENT := _UC.COLOR_ACCENT
const COLOR_TEXT := _UC.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := _UC.COLOR_TEXT_SECONDARY
const COLOR_BORDER := _UC.COLOR_BORDER
const COLOR_FOCUS := _UC.COLOR_FOCUS
const COLOR_SUCCESS := _UC.COLOR_SUCCESS
const SPACING_SM := _UC.SPACING_SM
const SPACING_MD := _UC.SPACING_MD
const SPACING_LG := _UC.SPACING_LG
const TOUCH_TARGET_COMFORT := _UC.TOUCH_TARGET_COMFORT

var _phase_manager = null
var _campaign = null
var _content: VBoxContainer
var _phase_title: Label
var _phase_desc: Label
var _complete_btn: Button

## What this panel resolved, per phase. These are the four keys
## TacticsPhaseManager._apply_phase_results() has always waited for and never received.
## ⚠ `_scenario` is kept ACROSS rebuilds on purpose: it used to be re-rolled inside
## _rebuild_phase_content(), so navigating away and back changed the scenario silently.
var _orders_zone_id: String = ""
var _recon_conducted: bool = false
var _scenario: String = ""
var _deployed_units: Array = []


func _scaled_font(base: int) -> int:
	var rm = get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	_build_ui()


func setup(phase_mgr, campaign_res) -> void:
	_phase_manager = phase_mgr
	_campaign = campaign_res


func show_phase(phase: int) -> void:
	if not _phase_title or not _phase_desc:
		return

	var phase_names = {
		0: "Operational Orders",
		1: "Reconnaissance",
		2: "Battle Preparation",
		3: "Deployment",
	}
	var phase_descs = {
		0: "Plan your approach. Assign units to operational zones and choose your battle plan for this turn.",
		1: "Gather intelligence on enemy positions. Roll Observation tests to reveal enemy composition and terrain features.",
		2: "Generate the battle scenario. Roll for scenario type, objectives, and battlefield conditions.",
		3: "Deploy your forces according to the scenario deployment rules. Place units in your deployment zone.",
	}

	_phase_title.text = phase_names.get(phase, "Unknown Phase")
	_phase_desc.text = phase_descs.get(phase, "")

	# Update content for specific phase
	_rebuild_phase_content(phase)


func _build_ui() -> void:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(vbox)

	_phase_title = Label.new()
	_phase_title.text = "Battle Setup"
	_phase_title.add_theme_font_size_override("font_size", _scaled_font(22))
	_phase_title.add_theme_color_override("font_color", COLOR_TEXT)
	_phase_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_phase_title)

	_phase_desc = Label.new()
	_phase_desc.text = ""
	_phase_desc.add_theme_font_size_override("font_size", _scaled_font(14))
	_phase_desc.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	_phase_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_phase_desc)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(_content)

	# Complete button
	var nav = HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(nav)

	_complete_btn = Button.new()
	_complete_btn.text = "Complete Phase"
	_complete_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	_complete_btn.pressed.connect(_on_complete)
	nav.add_child(_complete_btn)


func _rebuild_phase_content(phase: int) -> void:
	for child in _content.get_children():
		child.queue_free()

	match phase:
		0:  # Orders — pick the Operational Zone this force is committed to.
			_add_info_card("Battle Plan",
				"Choose your operational approach for this turn. "\
				+ "Your battle plan affects AI behavior and deployment options.")
			_add_zone_picker()
		1:  # Recon
			_add_info_card("Intelligence Report",
				"Observation tests reveal enemy composition. "\
				+ "Better intel means fewer surprises during battle.")
			_add_recon_toggle()
		2:  # Battle Prep
			# ⚠ The scenario used to be rolled with `randi() % 4` INSIDE this rebuild,
			# displayed, and then discarded — `_apply_phase_results()` waits for a
			# `scenario` key that no producer ever sent. Worse, rebuilding the phase
			# re-rolled it, so leaving and returning silently changed the scenario the
			# player had just read. It is now chosen once, kept in `_scenario`, and
			# emitted. The four names are the book's own scenarios (Skirmish p.74,
			# Grand Battle p.79, Evolving Objective p.80) and are read from
			# data/tactics/tactics_campaign_config.json rather than retyped here.
			if _scenario.is_empty():
				_scenario = _pick_scenario()
			_add_info_card("Scenario: %s" % _scenario.capitalize().replace("_", " "),
				"Battlefield conditions generated. "\
				+ "Review the scenario briefing before deploying.")
			_add_scenario_picker()
		3:  # Deployment
			_add_info_card("Deployment Zone",
				"Place your forces in the deployment zone. "\
				+ "Consider terrain, cover, and objectives.")
			_add_deployment_summary()


## The Operational Zones the campaign actually has. Empty until zones exist, in which
## case the phase still completes — it simply reports no assignment, which is honest.
func _zones() -> Array:
	if _campaign == null or not ("operational_map" in _campaign):
		return []
	var m: Variant = _campaign.operational_map
	if not (m is Dictionary):
		return []
	var z: Variant = (m as Dictionary).get("zones", [])
	return z if z is Array else []


func _add_zone_picker() -> void:
	var zones: Array = _zones()
	if zones.is_empty():
		return
	var picker := OptionButton.new()
	for z in zones:
		if z is Dictionary:
			picker.add_item(str((z as Dictionary).get(
				"name", (z as Dictionary).get("id", "Zone"))))
			picker.set_item_metadata(picker.item_count - 1,
				str((z as Dictionary).get("id", "")))
	if picker.item_count > 0:
		picker.select(0)
		if _orders_zone_id.is_empty():
			_orders_zone_id = str(picker.get_item_metadata(0))
	picker.item_selected.connect(func(i: int) -> void:
		_orders_zone_id = str(picker.get_item_metadata(i)))
	_content.add_child(picker)


func _add_recon_toggle() -> void:
	var cb := CheckBox.new()
	cb.text = "Observation conducted"
	cb.button_pressed = _recon_conducted
	cb.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	cb.toggled.connect(func(on: bool) -> void: _recon_conducted = on)
	_content.add_child(cb)


func _scenario_types() -> Array:
	var f := FileAccess.open(
		"res://data/tactics/tactics_campaign_config.json", FileAccess.READ)
	if f == null:
		return []
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK or not (json.data is Dictionary):
		return []
	var t: Variant = (json.data as Dictionary).get("scenario_types", [])
	return t if t is Array else []


func _pick_scenario() -> String:
	var types: Array = _scenario_types()
	if types.is_empty():
		return ""
	return str(types[randi() % types.size()])


func _add_scenario_picker() -> void:
	var types: Array = _scenario_types()
	if types.is_empty():
		return
	var picker := OptionButton.new()
	var sel := 0
	for i in range(types.size()):
		picker.add_item(str(types[i]).capitalize().replace("_", " "))
		picker.set_item_metadata(i, str(types[i]))
		if str(types[i]) == _scenario:
			sel = i
	picker.select(sel)
	picker.item_selected.connect(func(i: int) -> void:
		_scenario = str(picker.get_item_metadata(i)))
	_content.add_child(picker)


func _add_deployment_summary() -> void:
	_deployed_units = _campaign_unit_ids()
	if _deployed_units.is_empty():
		return
	var lbl := Label.new()
	lbl.text = "Deploying %d unit(s)." % _deployed_units.size()
	lbl.add_theme_font_size_override("font_size", _scaled_font(14))
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	_content.add_child(lbl)


func _campaign_unit_ids() -> Array:
	var out: Array = []
	if _campaign == null or not ("campaign_units" in _campaign):
		return out
	var units: Variant = _campaign.campaign_units
	if not (units is Array):
		return out
	for u in units:
		if u is Dictionary and not bool((u as Dictionary).get("is_destroyed", false)):
			out.append(str((u as Dictionary).get("unit_id", "")))
	return out


func _add_info_card(card_title: String, body: String) -> void:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = SPACING_MD
	style.content_margin_right = SPACING_MD
	style.content_margin_top = SPACING_SM
	style.content_margin_bottom = SPACING_SM
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	card.add_child(vbox)

	var title = Label.new()
	title.text = card_title
	title.add_theme_font_size_override("font_size", _scaled_font(16))
	title.add_theme_color_override("font_color", COLOR_FOCUS)
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = body
	desc.add_theme_font_size_override("font_size", _scaled_font(14))
	desc.add_theme_color_override("font_color", COLOR_TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	_content.add_child(card)


## Emit what this phase actually resolved.
##
## ⚠ This used to be `phase_completed.emit(current, {})`. All four branches of
## TacticsPhaseManager._apply_phase_results() are keyed on `data.has(...)`, so an empty
## payload meant ORDERS, RECON, BATTLE_PREP and DEPLOYMENT each ran their consumer and
## wrote nothing. A key is included only when this panel genuinely has a value for it —
## an absent key means "not resolved", which the consumer already treats correctly, and
## is very different from sending an empty string.
func _on_complete() -> void:
	var current: int = _phase_manager.current_phase \
		if _phase_manager else 0
	var data: Dictionary = {}
	match current:
		0:
			if not _orders_zone_id.is_empty():
				data["orders"] = {"focus_zone_id": _orders_zone_id}
		1:
			data["intel"] = {"observation_conducted": _recon_conducted}
		2:
			if not _scenario.is_empty():
				data["scenario"] = _scenario
		3:
			if not _deployed_units.is_empty():
				data["deployed_units"] = _deployed_units.duplicate()
	phase_completed.emit(current, data)
