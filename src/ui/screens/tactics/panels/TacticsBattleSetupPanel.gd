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

const UnitRecordRef = preload("res://src/data/tactics/TacticsCampaignUnit.gd")
const TouchScrollOpenerRef = preload("res://src/ui/components/common/TouchScrollOpener.gd")

var _phase_manager = null
var _campaign = null
var _content: VBoxContainer
var _phase_title: Label
var _phase_desc: Label
var _complete_btn: Button

## What this panel resolved, per phase. These are the keys
## TacticsPhaseManager._apply_phase_results() has always waited for and never received.
## ⚠ There is no Recon key: the p.39 Observation test is rolled at the table during the
## battle, so this phase only shows the rule (see _add_observation_rule()).
## ⚠ `_scenario` is kept ACROSS rebuilds on purpose: it used to be re-rolled inside
## _rebuild_phase_content(), so navigating away and back changed the scenario silently.
var _orders_zone_id: String = ""
var _scenario: String = ""
var _deployed_units: Array = []
## Indices into campaign.battle_advantages the player is spending on this battle
## (p.107). Applied by TacticsPhaseManager when BATTLE_PREP completes.
var _advantages_used: Array = []
var _last_phase: int = -1


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
		0: "Commit Your Force",
		1: "Reconnaissance",
		2: "Battle Preparation",
		3: "Deployment",
	}
	var phase_descs = {
		0: "Choose the Operational Zone your force fights in this turn (Tactics p.96).",
		1: "How your units will spot hidden and uncertain enemies once the battle begins (Tactics p.39).",
		2: "Choose the scenario type for this battle and decide whether to spend any banked battle advantages.",
		3: "Deploy your forces according to the scenario deployment rules. Place units in your deployment zone.",
	}

	_phase_title.text = phase_names.get(phase, "Unknown Phase")
	_phase_desc.text = phase_descs.get(phase, "")
	if phase != _last_phase:
		if phase == 2:
			_advantages_used = []
		_last_phase = phase

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
			# ⚠ This card used to read "Battle Plan ... Your battle plan affects AI behavior
			# and deployment options". The book's battle plan is the AI Battle Plan System
			# (p.58), an in-battle option for solo play; the control below picks a ZONE.
			_add_info_card("Operational Zone",
				"Each player force is assigned to an Operational Zone, and the battles it "\
				+ "plays are tracked for that Zone (p.96, Step 1). It starts where Step 8 of "\
				+ "the last turn committed it.")
			_add_zone_picker()
		1:  # Recon
			_add_observation_rule()
		2:  # Battle Prep
			# ⚠ The scenario used to be rolled with `randi() % 4` INSIDE this rebuild,
			# displayed, and then discarded — `_apply_phase_results()` waits for a
			# `scenario` key that no producer ever sent. Worse, rebuilding the phase
			# re-rolled it, so leaving and returning silently changed the scenario the
			# player had just read. It is now chosen once, kept in `_scenario`, and
			# emitted. The four names are the book's own scenarios (Skirmish p.74,
			# Grand Battle p.79, Evolving Objective p.80) and are read from
			# data/tactics/tactics_campaign_config.json rather than retyped here.
			# ⚠ There is no scenario-selection roll in the book: pp.74-81 present the
			# four scenario types for the players to choose between. The `randi()`
			# default that used to sit here was a roll the rules do not have.
			_add_info_card("Scenario: %s" % (
					_scenario.capitalize().replace("_", " ") if not _scenario.is_empty()
					else "choose one"),
				"Pick the scenario type you will play (Tactics pp.74-81). Every "\
				+ "rulebook scenario scores Victory Points (p.73).")
			_add_scenario_picker()
			_add_battle_advantages()
		3:  # Deployment
			_add_info_card("Deployment Zone",
				"Place your forces in the deployment zone. "\
				+ "Consider terrain, cover, and objectives.")
			_add_deployment_summary()
	# Every card and CheckBox here is STOP-filtered by construction, which swallows a
	# finger drag before the ScrollContainer sees it (the T9-45 / §2 sweep shape).
	TouchScrollOpenerRef.open_subtree(_content)


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
		# Default to where the army already stands (Step 8 of the last turn).
		var committed: String = str((_campaign.operational_map as Dictionary).get(
			"player_zone_id", "")) if _campaign and "operational_map" in _campaign else ""
		if _orders_zone_id.is_empty():
			_orders_zone_id = committed
		var sel: int = 0
		for i in range(picker.item_count):
			if str(picker.get_item_metadata(i)) == _orders_zone_id:
				sel = i
		picker.select(sel)
		_orders_zone_id = str(picker.get_item_metadata(sel))
	picker.item_selected.connect(func(i: int) -> void:
		_orders_zone_id = str(picker.get_item_metadata(i)))
	_content.add_child(picker)


## ⚠ This phase used to say "Observation tests reveal enemy composition. Better intel
## means fewer surprises during battle" over an "Observation conducted" checkbox whose
## value nothing read. Neither is in the book: the Observation test (p.39) is a Free
## Action a unit takes when it ACTIVATES during the battle, against Hidden and Uncertain
## elements, and the 8-step operational turn (p.96) has no pre-battle reconnaissance.
## The companion therefore shows the rule the players will roll at the table.
func _add_observation_rule() -> void:
	_add_info_card("Observation (Tactics p.39)",
		"When a unit with Line of Sight to Hidden or Uncertain elements activates, it "
		+ "makes an Observation test as a Free Action: roll 2D6.\n"
		+ "• Uncertain elements are spotted within (both dice added + Training) inches.\n"
		+ "• Hidden elements are spotted within (the highest die + Training) inches.\n"
		+ "One test covers the whole unit, measured from where it stands before moving. "
		+ "A Scan action (p.27) makes a second test after moving.\n"
		+ "Recon squads add +1 to all Observation distances (p.137); Scouts add +2 (p.140).")


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


func _add_scenario_picker() -> void:
	var types: Array = _scenario_types()
	if types.is_empty():
		return
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	picker.add_item("— choose a scenario type —")
	picker.set_item_metadata(0, "")
	var sel := 0
	for i in range(types.size()):
		picker.add_item(str(types[i]).capitalize().replace("_", " "))
		picker.set_item_metadata(i + 1, str(types[i]))
		if str(types[i]) == _scenario:
			sel = i + 1
	picker.select(sel)
	picker.item_selected.connect(func(i: int) -> void:
		_scenario = str(picker.get_item_metadata(i)))
	_content.add_child(picker)


## p.107: battle advantages are "a single-use bonus which can be spent in a battle when
## you wish. Once purchased, it may be saved indefinitely ... Once a battle advantage is
## used, it is gone." They were bought and banked nowhere before 2026-10-27 (T-08).
func _add_battle_advantages() -> void:
	if _campaign == null or not ("battle_advantages" in _campaign):
		return
	var banked: Array = _campaign.battle_advantages
	if banked.is_empty():
		return
	_add_info_card("Banked Battle Advantages (Tactics pp.107-108)",
		"Tick any you are using in this battle. Each is spent when this phase completes.")
	for i in range(banked.size()):
		var adv: Variant = banked[i]
		if not (adv is Dictionary):
			continue
		var cb := CheckBox.new()
		cb.text = "%s — %s" % [str(adv.get("name", "")), str(adv.get("desc", ""))]
		cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cb.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
		cb.button_pressed = _advantages_used.has(i)
		cb.toggled.connect(func(on: bool) -> void:
			if on and not _advantages_used.has(i):
				_advantages_used.append(i)
			elif not on:
				_advantages_used.erase(i))
		_content.add_child(cb)


func _add_deployment_summary() -> void:
	_deployed_units = _campaign_unit_ids()
	if _deployed_units.is_empty():
		return
	var lines: PackedStringArray = PackedStringArray(
		["Deploying %d unit(s)." % _deployed_units.size()])
	for u in _campaign.campaign_units:
		if not (u is Dictionary):
			continue
		var note: String = UnitRecordRef.condition_text(u)
		if not note.is_empty():
			lines.append("%s: %s" % [UnitRecordRef.display_name(u), note])
	var lbl := Label.new()
	lbl.text = "\n".join(lines)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	# p.106: a Lost unit never deploys, and a Devastated one is unusable for two
	# campaign battles. A Weakened unit DOES deploy, one figure short.
	for u in units:
		if u is Dictionary and UnitRecordRef.is_deployable(u):
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
			# Step 1 (p.96): the Zone this force is committed to. It is NOT the
			# Operational Focus (p.94), which is chosen in Step 7.
			if not _orders_zone_id.is_empty():
				data["orders"] = {"player_zone_id": _orders_zone_id}
		2:
			if not _scenario.is_empty():
				data["scenario"] = _scenario
			if not _advantages_used.is_empty():
				data["battle_advantages_used"] = _advantages_used.duplicate()
		3:
			if not _deployed_units.is_empty():
				data["deployed_units"] = _deployed_units.duplicate()
	phase_completed.emit(current, data)
