extends Control

## Tactics Post-Battle Panel — Covers POST_BATTLE + ADVANCEMENT phases.
## Shows the CP award (pp.106-107), rolls Unit Losses (pp.105-106) and the story event
## (pp.102-104), then spends CP on the pp.107-108 purchases.
## Covers phases 5-6 of the 8-phase turn.
##
## This panel only REPORTS. TacticsPhaseManager applies every result it emits, and
## TacticsAdvancement decides what a purchase may target and what it does.

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
const COLOR_DANGER := _UC.COLOR_DANGER
const SPACING_SM := _UC.SPACING_SM
const SPACING_MD := _UC.SPACING_MD
const SPACING_LG := _UC.SPACING_LG
const TOUCH_TARGET_COMFORT := _UC.TOUCH_TARGET_COMFORT

const RulesRef = preload("res://src/core/campaign/TacticsOperationalRules.gd")
const AdvancementRef = preload("res://src/core/campaign/TacticsAdvancement.gd")
const UnitRecordRef = preload("res://src/data/tactics/TacticsCampaignUnit.gd")
const TouchScrollOpenerRef = preload("res://src/ui/components/common/TouchScrollOpener.gd")

var _phase_manager = null
var _campaign = null
var _content: VBoxContainer
var _phase_title: Label
var _complete_btn: Button
## The phase last drawn. Entering a DIFFERENT phase resets that phase's state, so a
## story event or a purchase from last turn is never re-emitted this turn.
var _last_phase: int = -1

## POST_BATTLE state.
var _story_event: Dictionary = {}
## unit_id -> true when the player ticks "completely destroyed" (p.106).
var _destroyed: Dictionary = {}
## unit_id -> the rolled p.106 row, with unit_id and recovery_battles.
var _unit_losses: Dictionary = {}

## ADVANCEMENT state.
var _cp_spent: int = 0
## [{id, unit_id, choice, label}] — emitted as `advancement_purchases`.
var _purchases: Array = []
var _pending_id: String = ""
var _pending_unit: String = ""
var _pending_choice: Variant = ""
var _refit_checks: Array = []


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
	if not _phase_title:
		return
	if phase != _last_phase:
		_reset_state(phase)
		_last_phase = phase

	for child in _content.get_children():
		child.queue_free()

	if phase == 5:  # POST_BATTLE
		_phase_title.text = "Post-Battle"
		_build_post_battle_content()
	elif phase == 6:  # ADVANCEMENT
		_phase_title.text = "Advancement"
		_build_advancement_content()
	TouchScrollOpenerRef.open_subtree(_content)


func _reset_state(phase: int) -> void:
	if phase == 5:
		_story_event = {}
		_destroyed = {}
		_unit_losses = {}
	elif phase == 6:
		_cp_spent = 0
		_purchases = []
		_clear_pending()


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
	_phase_title.text = "Post-Battle"
	_phase_title.add_theme_font_size_override("font_size", _scaled_font(22))
	_phase_title.add_theme_color_override("font_color", COLOR_TEXT)
	_phase_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_phase_title)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(_content)

	var nav = HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(nav)

	_complete_btn = Button.new()
	_complete_btn.text = "Complete Phase"
	_complete_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	_complete_btn.pressed.connect(_on_complete)
	nav.add_child(_complete_btn)


func _dice() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("/root/DiceManager") if tree else null


func _d6(context: String) -> int:
	var dm := _dice()
	return int(dm.roll_d6(context)) if dm else randi_range(1, 6)


# ── POST_BATTLE ─────────────────────────────────────────────────────────────

func _build_post_battle_content() -> void:
	_add_card("Battle Result", _battle_result_text())

	if _campaign and _campaign.has_method("get_available_cp"):
		var cp_lbl = Label.new()
		cp_lbl.text = "Available CP: %d" % _campaign.get_available_cp()
		cp_lbl.add_theme_font_size_override("font_size", _scaled_font(18))
		cp_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
		cp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(cp_lbl)

	_build_unit_losses()

	# Story event — Tactics pp.102-104, a real D100 table in
	# data/tactics/tactics_story_events.json (21 rows).
	if _story_event.is_empty():
		_add_card("Story Events",
			"Roll on the D100 story event table to see "\
			+ "if anything changes on the strategic level.")
		var roll_btn := Button.new()
		roll_btn.text = "Roll Story Event (D100)"
		roll_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
		roll_btn.pressed.connect(_on_roll_story_event)
		_content.add_child(roll_btn)
	else:
		_add_card("Story Event — %s (rolled %d)" % [
				str(_story_event.get("name", "?")),
				int(_story_event.get("roll", 0))],
			str(_story_event.get("description", "")) + "\n\n"
			+ str(_story_event.get("player_effect", "")))


## Rendered from what record_battle() stamped. ⚠ This card used to read "Each battle
## earns 1 CP, +1 for victory, +1 for secondary objectives" — the fabricated rule the
## 2026-09-04 fix removed from the core and left printed here.
func _battle_result_text() -> String:
	var hist: Array = _campaign.battle_history if _campaign and "battle_history" in _campaign \
		else []
	if hist.is_empty() or not (hist[-1] is Dictionary):
		return "No battle was recorded this turn."
	var e: Dictionary = hist[-1]
	var outcome: String = "Draw" if bool(e.get("draw", false)) \
		else ("Victory" if bool(e.get("won", false)) else "Defeat")
	var dice: Array = e.get("cp_dice", [])
	var earned: int = int(e.get("cp_earned", 0))
	if dice.size() != 3:
		return "%s. Campaign Points earned: %d." % [outcome, earned]
	var sorted: Array = dice.duplicate()
	sorted.sort()
	var base: int = int(sorted[1]) + int(sorted[2])
	var basis: String = str(e.get("cp_basis", ""))
	var why: String = {
		"victory_points": "1 CP per Victory Point",
		"victory": "victory, no Victory Points",
		"draw": "draw, no Victory Points",
		"defeat": "defeat, no Victory Points",
	}.get(basis, basis)
	return "%s. Campaign Points: rolled %s, dropped the lowest = %d, plus %d (%s) = %d CP "\
		% [outcome, str(dice), base, earned - base, why, earned] + "(Tactics pp.106-107)."


## p.105: "If a unit remains on the table at the end of the game, we assume it
## recovers completely." Only a unit that was COMPLETELY destroyed rolls on p.106.
func _build_unit_losses() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for r in RulesRef.unit_loss_table():
		if r is Dictionary:
			var lo: int = int(r.get("roll", r.get("roll_min", 0)))
			var hi: int = int(r.get("roll", r.get("roll_max", 0)))
			rows.append("%s %s: %s" % [str(lo) if lo == hi else "%d-%d" % [lo, hi],
				str(r.get("name", "")), str(r.get("description", ""))])
	_add_card("Unit Losses (Tactics pp.105-106)",
		"A unit still on the table at the end recovers completely. Tick each unit "
		+ "that was COMPLETELY destroyed, then roll one D6 for it:\n" + "\n".join(rows))

	for rec in _deployed_records():
		var r: Dictionary = rec
		var uid: String = str(r.get("unit_id", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", SPACING_SM)
		_content.add_child(row)
		var cb := CheckBox.new()
		cb.text = "%s — completely destroyed" % UnitRecordRef.display_name(r)
		cb.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.button_pressed = bool(_destroyed.get(uid, false))
		cb.disabled = _unit_losses.has(uid)
		cb.toggled.connect(func(on: bool) -> void: _destroyed[uid] = on)
		row.add_child(cb)
		if _unit_losses.has(uid):
			var res := Label.new()
			res.text = "%d: %s" % [int(_unit_losses[uid].get("rolled", 0)),
				str(_unit_losses[uid].get("name", ""))]
			res.add_theme_color_override("font_color", COLOR_ACCENT)
			row.add_child(res)

	var roll := Button.new()
	roll.text = "Roll Unit Losses for ticked units"
	roll.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	roll.pressed.connect(func() -> void:
		_roll_pending_losses()
		_rebuild_for_current_phase())
	_content.add_child(roll)


## The units this battle deployed (stamped at DEPLOYMENT), or every deployable unit
## when the stamp is missing.
func _deployed_records() -> Array:
	var out: Array = []
	if not _campaign:
		return out
	var ids: Array = []
	if "current_battle" in _campaign:
		ids = _campaign.current_battle.get("deployed_units", [])
	for rec in _campaign.campaign_units:
		if not (rec is Dictionary):
			continue
		var uid: String = str(rec.get("unit_id", ""))
		if (ids.is_empty() and UnitRecordRef.is_deployable(rec)) or ids.has(uid):
			out.append(rec)
	return out


func _roll_pending_losses() -> void:
	for rec in _deployed_records():
		var uid: String = str(rec.get("unit_id", ""))
		if not bool(_destroyed.get(uid, false)) or _unit_losses.has(uid):
			continue
		var roll: int = _d6("Tactics Unit Losses: %s" % UnitRecordRef.display_name(rec))
		var row: Dictionary = RulesRef.unit_loss_for(roll)
		if row.is_empty():
			continue  # No table, no result — never a fabricated condition.
		row["unit_id"] = uid
		_unit_losses[uid] = row


func _story_event_table() -> Array:
	var f := FileAccess.open(
		"res://data/tactics/tactics_story_events.json", FileAccess.READ)
	if f == null:
		return []
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK or not (json.data is Dictionary):
		return []
	var e: Variant = (json.data as Dictionary).get("events", [])
	return e if e is Array else []


func _on_roll_story_event() -> void:
	var table: Array = _story_event_table()
	if table.is_empty():
		# No table, no event. Never fabricate a row.
		return
	var dm := _dice()
	var roll: int = int(dm.roll_d100("Tactics Story Event")) if dm else randi_range(1, 100)
	for row in table:
		if not (row is Dictionary):
			continue
		var r: Dictionary = row
		if roll >= int(r.get("roll_min", 0)) and roll <= int(r.get("roll_max", -1)):
			_story_event = r.duplicate(true)
			_story_event["roll"] = roll
			break
	_rebuild_for_current_phase()


## Re-enter through show_phase() so a roll redraws the same phase.
func _rebuild_for_current_phase() -> void:
	var current: int = _phase_manager.current_phase if _phase_manager else 5
	show_phase(current)


# ── ADVANCEMENT ─────────────────────────────────────────────────────────────

func _remaining_cp() -> int:
	var cp: int = 0
	if _campaign and _campaign.has_method("get_available_cp"):
		cp = _campaign.get_available_cp()
	return maxi(cp - _cp_spent, 0)


func _build_advancement_content() -> void:
	# ⚠ GENERATED FROM TacticsCampaignCore.CP_PURCHASES, never written out here, so the
	# prose a player reads is the CP they are charged (p.107 prices a veteran skill at
	# 4 CP; this card once said 1).
	var seen_groups: PackedStringArray = PackedStringArray()
	var body_lines: PackedStringArray = PackedStringArray()
	for entry in TacticsCampaignCore.CP_PURCHASES:
		var grp: String = str(entry.get("group", ""))
		if not seen_groups.has(grp):
			seen_groups.append(grp)
			body_lines.append("[%s]" % grp)
		body_lines.append("- %s (%d CP): %s" % [
			str(entry.get("name", "")),
			int(entry.get("cost", 0)),
			str(entry.get("desc", ""))])
	_add_card("Spend Campaign Points (Tactics pp.107-108)",
		"Use your earned CP to improve your force:\n" + "\n".join(body_lines))

	if not _campaign:
		return
	var remaining: int = _remaining_cp()
	var cp_lbl = Label.new()
	cp_lbl.text = "CP Available to Spend: %d" % remaining
	cp_lbl.add_theme_font_size_override("font_size", _scaled_font(18))
	cp_lbl.add_theme_color_override("font_color",
		COLOR_SUCCESS if remaining > 0 else COLOR_TEXT_SEC)
	cp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(cp_lbl)

	if not _pending_id.is_empty():
		_build_pending_purchase()
	elif remaining > 0:
		# ⚠ HFlowContainer, not HBox: thirteen priced purchases will not fit one row,
		# and an HBox would drive the panel's minimum width past the viewport.
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", SPACING_SM)
		flow.add_theme_constant_override("v_separation", SPACING_SM)
		_content.add_child(flow)
		for entry in TacticsCampaignCore.CP_PURCHASES:
			var pid: String = str(entry.get("id", ""))
			var cost: int = int(entry.get("cost", 0))
			var b := Button.new()
			b.text = "%s (%d CP)" % [str(entry.get("name", "")), cost]
			b.tooltip_text = str(entry.get("desc", ""))
			b.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
			# ⚠ CHECK THE PRICE YOU CHARGE AGAINST THE PRICE YOU CHECK.
			b.disabled = cost > remaining or (AdvancementRef.needs_target(pid)
				and _targets(pid).is_empty())
			b.pressed.connect(_on_pick_purchase.bind(pid))
			flow.add_child(b)

	if not _purchases.is_empty():
		var lines: PackedStringArray = PackedStringArray()
		for p in _purchases:
			lines.append(str(p.get("label", "")))
		_add_card("Committed this phase", "\n".join(lines))


## Targets for a purchase, minus units this visit has already committed the same
## purchase to (or replaced) — the campaign is only changed when the phase completes,
## so without this filter a squad could buy the same skill list twice.
func _targets(pid: String) -> Array:
	var out: Array = []
	for t in AdvancementRef.targets(_campaign, pid):
		var uid: String = str(t.get("unit_id", ""))
		var blocked := false
		for p in _purchases:
			if str(p.get("unit_id", "")) != uid:
				continue
			var other: String = str(p.get("id", ""))
			if other in ["unit_replacement", "replace_destroyed"] \
					or (other == pid and pid != "veteran_skill"):
				blocked = true
		if not blocked and (pid != "veteran_skill" or not _choices(pid, uid).is_empty()):
			out.append(t)
	return out


func _choices(pid: String, uid: String) -> Array:
	var out: Array = []
	var pending_lists: PackedStringArray = PackedStringArray()
	for p in _purchases:
		if str(p.get("id", "")) == "veteran_skill" and str(p.get("unit_id", "")) == uid:
			pending_lists.append(str(p.get("choice", "")).split(":")[0])
	for c in AdvancementRef.choices(_campaign, pid, uid):
		if pid == "veteran_skill" and pending_lists.has(str(c.get("value", "")).split(":")[0]):
			continue
		out.append(c)
	return out


func _on_pick_purchase(pid: String) -> void:
	_clear_pending()
	_pending_id = pid
	var t: Array = _targets(pid)
	if not t.is_empty():
		_pending_unit = str(t[0].get("unit_id", ""))
	_rebuild_for_current_phase()


func _clear_pending() -> void:
	_pending_id = ""
	_pending_unit = ""
	_pending_choice = ""
	_refit_checks = []


func _build_pending_purchase() -> void:
	var entry: Dictionary = TacticsCampaignCore.cp_purchase(_pending_id)
	_add_card("Buying: %s (%d CP)" % [str(entry.get("name", "")),
			int(entry.get("cost", 0))], str(entry.get("desc", "")))

	if AdvancementRef.needs_target(_pending_id):
		var units := OptionButton.new()
		units.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
		var targets: Array = _targets(_pending_id)
		for i in range(targets.size()):
			units.add_item(str(targets[i].get("label", "")))
			units.set_item_metadata(i, str(targets[i].get("unit_id", "")))
			if str(targets[i].get("unit_id", "")) == _pending_unit:
				units.select(i)
		units.item_selected.connect(func(i: int) -> void:
			_pending_unit = str(units.get_item_metadata(i))
			_pending_choice = ""
			_refit_checks = []
			_rebuild_for_current_phase())
		_content.add_child(units)

	var opts: Array = _choices(_pending_id, _pending_unit)
	if _pending_id == "unit_refit":
		# p.108: "You can make multiple changes" in one refit — tick the options kept.
		if _refit_checks.is_empty():
			for c in opts:
				if bool(c.get("checked", false)):
					_refit_checks.append(str(c.get("value", "")))
		for c in opts:
			var v: String = str(c.get("value", ""))
			var cb := CheckBox.new()
			cb.text = str(c.get("label", ""))
			cb.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
			cb.button_pressed = _refit_checks.has(v)
			cb.toggled.connect(func(on: bool) -> void:
				if on and not _refit_checks.has(v):
					_refit_checks.append(v)
				elif not on:
					_refit_checks.erase(v))
			_content.add_child(cb)
	elif not opts.is_empty():
		var pick := OptionButton.new()
		pick.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
		pick.fit_to_longest_item = false
		pick.clip_text = true
		for i in range(opts.size()):
			pick.add_item(str(opts[i].get("label", "")))
			pick.set_item_metadata(i, opts[i].get("value", ""))
		var sel: int = 0
		for i in range(opts.size()):
			if str(opts[i].get("value", "")) == str(_pending_choice):
				sel = i
		pick.select(sel)
		_pending_choice = opts[sel].get("value", "")
		pick.item_selected.connect(func(i: int) -> void:
			_pending_choice = pick.get_item_metadata(i))
		_content.add_child(pick)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SPACING_MD)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(row)
	var ok := Button.new()
	ok.text = "Confirm"
	ok.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	ok.disabled = (AdvancementRef.needs_target(_pending_id) and _pending_unit.is_empty()) \
		or (_pending_id != "unit_refit" and not AdvancementRef.is_battle_advantage(_pending_id)
			and opts.is_empty())
	ok.pressed.connect(_on_confirm_purchase)
	row.add_child(ok)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	cancel.pressed.connect(func() -> void:
		_clear_pending()
		_rebuild_for_current_phase())
	row.add_child(cancel)


func _on_confirm_purchase() -> void:
	var entry: Dictionary = TacticsCampaignCore.cp_purchase(_pending_id)
	var cost: int = int(entry.get("cost", 0))
	# ⚠ An unknown id costs 0, and 0 means REFUSE, never "free".
	if cost <= 0 or cost > _remaining_cp():
		return
	var choice: Variant = _refit_checks.duplicate() if _pending_id == "unit_refit" \
		else _pending_choice
	var label: String = "%s (%d CP)" % [str(entry.get("name", "")), cost]
	if not _pending_unit.is_empty():
		for rec in _campaign.campaign_units:
			if rec is Dictionary and str(rec.get("unit_id", "")) == _pending_unit:
				label += " — " + UnitRecordRef.display_name(rec)
	_purchases.append({"id": _pending_id, "unit_id": _pending_unit, "choice": choice,
		"label": label})
	_cp_spent += cost
	_clear_pending()
	_rebuild_for_current_phase()


func _add_card(card_title: String, body: String) -> void:
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

	var t = Label.new()
	t.text = card_title
	t.add_theme_font_size_override("font_size", _scaled_font(16))
	t.add_theme_color_override("font_color", COLOR_FOCUS)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(t)

	var b = Label.new()
	b.text = body
	b.add_theme_font_size_override("font_size", _scaled_font(14))
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(b)

	_content.add_child(card)


## Emit what this phase resolved. ⚠ A ticked-but-unrolled unit is rolled here, so the
## loss cannot be skipped by completing the phase without pressing Roll.
func _on_complete() -> void:
	var current: int = _phase_manager.current_phase \
		if _phase_manager else 5
	var data: Dictionary = {}
	match current:
		5:  # POST_BATTLE
			_roll_pending_losses()
			if not _story_event.is_empty():
				data["story_event"] = _story_event.duplicate(true)
			if not _unit_losses.is_empty():
				data["unit_losses"] = _unit_losses.values().duplicate(true)
		6:  # ADVANCEMENT
			if _cp_spent > 0:
				data["cp_spent"] = _cp_spent
			if not _purchases.is_empty():
				data["advancement_purchases"] = _purchases.duplicate(true)
	phase_completed.emit(current, data)
