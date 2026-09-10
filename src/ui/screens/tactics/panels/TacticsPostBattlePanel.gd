extends Control

## Tactics Post-Battle Panel — Covers POST_BATTLE + ADVANCEMENT phases.
## Process casualties, award CP, check story events, spend CP on upgrades.
## Covers phases 5-6 of the 8-phase turn.

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

var _phase_manager = null
var _campaign = null
var _content: VBoxContainer
var _phase_title: Label
var _complete_btn: Button

## What this panel resolved. These are keys TacticsPhaseManager has always waited for
## and never received, because both _on_complete() branches emitted `{}`.
var _story_event: Dictionary = {}
var _cp_spent: int = 0
var _purchases: Array = []
var _roster_changes: Array = []


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

	for child in _content.get_children():
		child.queue_free()

	if phase == 5:  # POST_BATTLE
		_phase_title.text = "Post-Battle"
		_build_post_battle_content()
	elif phase == 6:  # ADVANCEMENT
		_phase_title.text = "Advancement"
		_build_advancement_content()


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


func _build_post_battle_content() -> void:
	# Battle result summary
	_add_card("Battle Result",
		"Process casualties and award Campaign Points. "\
		+ "Each battle earns 1 CP, +1 for victory, +1 for secondary objectives.")

	# CP earned display
	if _campaign:
		var cp: int = 0
		if _campaign.has_method("get_available_cp"):
			cp = _campaign.get_available_cp()
		var cp_lbl = Label.new()
		cp_lbl.text = "Available CP: %d" % cp
		cp_lbl.add_theme_font_size_override("font_size", _scaled_font(18))
		cp_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
		cp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(cp_lbl)

	# Casualty list
	_add_card("Casualties",
		"Review unit losses from this battle. "\
		+ "Destroyed units can be replaced by spending CP during Advancement.")

	# Story event check — Tactics pp.102-104, a real D100 table in
	# data/tactics/tactics_story_events.json (21 rows). It used to be DESCRIBED here and
	# never rolled; `_apply_post_battle_results()` waits for a `story_event` key that no
	# producer sent, so campaign.story_events could never grow.
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
		# No table, no event. Never fabricate a row — an unrolled event is a far
		# smaller problem than an invented one appearing in the campaign log.
		return
	var roll: int = randi_range(1, 100)
	for row in table:
		if not (row is Dictionary):
			continue
		var r: Dictionary = row
		if roll >= int(r.get("roll_min", 0)) and roll <= int(r.get("roll_max", -1)):
			_story_event = r.duplicate(true)
			_story_event["roll"] = roll
			break
	_rebuild_for_current_phase()


## The two content builders are chosen by phase; re-enter through show_phase() so a
## roll redraws the same phase rather than guessing which builder to call.
func _rebuild_for_current_phase() -> void:
	var current: int = _phase_manager.current_phase if _phase_manager else 5
	show_phase(current)


func _build_advancement_content() -> void:
	# ⚠ THIS BODY IS GENERATED FROM TacticsCampaignCore.CP_PURCHASES, never written
	# out here. It used to be a prose literal reading "- Unit Upgrade (1 CP): Acquire
	# a veteran skill" — a price the book does not charge, since p.107 prices Gain
	# Veteran Skill at **4 CP**. A mechanic's numbers in a UI literal drift from the
	# mechanic by construction; the card and the buttons below now render from the
	# same array, so the prose a player reads is the CP they are charged.
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
		"Use your earned CP to improve your force:
" + "
".join(body_lines))

	if _campaign:
		var cp: int = 0
		if _campaign.has_method("get_available_cp"):
			cp = _campaign.get_available_cp()
		var remaining: int = maxi(cp - _cp_spent, 0)
		var cp_lbl = Label.new()
		cp_lbl.text = "CP Available to Spend: %d" % remaining
		cp_lbl.add_theme_font_size_override("font_size", _scaled_font(18))
		cp_lbl.add_theme_color_override("font_color",
			COLOR_SUCCESS if remaining > 0 else COLOR_TEXT_SEC)
		cp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(cp_lbl)

		# The three purchases the card above describes, made actionable. Without these
		# `cp_spent` had no producer, so CP accumulated and could never be spent.
		# ⚠ Only the SPEND is recorded here; the campaign is debited by
		# TacticsPhaseManager._apply_advancement_results() through spend_cp(), which is
		# the mutation API. Spending twice in one visit is why this tracks a running
		# total rather than emitting one purchase.
		if remaining > 0:
			# ⚠ HFlowContainer, not HBox: thirteen priced purchases will not fit one row
			# at any sane width, and an HBox would drive the panel's minimum width past
			# the viewport -- the T11-18 / T11-42 shape.
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", SPACING_SM)
			flow.add_theme_constant_override("v_separation", SPACING_SM)
			_content.add_child(flow)
			for entry in TacticsCampaignCore.CP_PURCHASES:
				var cost: int = int(entry.get("cost", 0))
				var b := Button.new()
				b.text = "%s (%d CP)" % [str(entry.get("name", "")), cost]
				b.tooltip_text = str(entry.get("desc", ""))
				b.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
				# ⚠ CHECK THE PRICE YOU CHARGE AGAINST THE PRICE YOU CHECK. A 4 CP
				# veteran skill must not be reachable on 2 remaining CP.
				b.disabled = cost > remaining
				b.pressed.connect(_on_spend_cp.bind(str(entry.get("id", ""))))
				flow.add_child(b)

		if not _purchases.is_empty():
			var log_lbl := Label.new()
			log_lbl.text = "Committed: " + ", ".join(PackedStringArray(_purchases))
			log_lbl.add_theme_font_size_override("font_size", _scaled_font(13))
			log_lbl.add_theme_color_override("font_color", COLOR_TEXT)
			log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_content.add_child(log_lbl)


func _on_spend_cp(purchase_id: String) -> void:
	var entry: Dictionary = TacticsCampaignCore.cp_purchase(purchase_id)
	var cost: int = int(entry.get("cost", 0))
	# ⚠ An unknown id costs 0, and 0 means REFUSE, never "free". Charging 0 would
	# hand the player a purchase the book prices at 1-4 CP for nothing.
	if cost <= 0:
		push_warning("[Tactics] unknown CP purchase id: %s" % purchase_id)
		return
	var available: int = 0
	if _campaign and _campaign.has_method("get_available_cp"):
		available = _campaign.get_available_cp()
	# ⚠ The AUTHORITY on affordability. The button's `disabled` is a courtesy;
	# this is the check that cannot be bypassed by a stale rebuild.
	if cost > available - _cp_spent:
		return
	_cp_spent += cost
	_purchases.append("%s (%d CP)" % [str(entry.get("name", "")), cost])
	# ⚠ Deliberately NOT emitting a `roster_changes` entry here. That consumer
	# (_reinforce_unit / _replace_unit) matches on `unit_id`, and this panel has no unit
	# picker yet — an entry with an empty id would match nothing and silently do
	# nothing, which is worse than not sending one. The CP is still charged, because
	# that is what the player chose. Add the picker and the key together.
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
	vbox.add_child(t)

	var b = Label.new()
	b.text = body
	b.add_theme_font_size_override("font_size", _scaled_font(14))
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(b)

	_content.add_child(card)


## Emit what this phase resolved. Was `phase_completed.emit(current, {})` for both the
## POST_BATTLE and ADVANCEMENT phases, so `story_event`, `skills_acquired`, `cp_spent`
## and `roster_changes` all had consumers that could never fire.
func _on_complete() -> void:
	var current: int = _phase_manager.current_phase \
		if _phase_manager else 5
	var data: Dictionary = {}
	match current:
		5:  # POST_BATTLE
			if not _story_event.is_empty():
				data["story_event"] = _story_event.duplicate(true)
		6:  # ADVANCEMENT
			if _cp_spent > 0:
				data["cp_spent"] = _cp_spent
			if not _roster_changes.is_empty():
				data["roster_changes"] = _roster_changes.duplicate(true)
	phase_completed.emit(current, data)
