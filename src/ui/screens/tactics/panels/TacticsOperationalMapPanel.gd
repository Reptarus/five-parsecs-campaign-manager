extends Control

## Tactics Operational Map Panel — Covers STRATEGIC phase (phase 7).
## Shows operational map state, resolves operational combat, issues orders,
## manages commando raids and force redeployment.

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
const COLOR_WARNING := _UC.COLOR_WARNING
const SPACING_SM := _UC.SPACING_SM
const SPACING_MD := _UC.SPACING_MD
const SPACING_LG := _UC.SPACING_LG
const TOUCH_TARGET_COMFORT := _UC.TOUCH_TARGET_COMFORT

const OperationalMapRef = preload("res://src/data/tactics/TacticsOperationalMap.gd")
const OperationalRulesRef = preload(
	"res://src/core/campaign/TacticsOperationalRules.gd")

var _phase_manager = null
var _campaign = null
var _content: VBoxContainer
var _complete_btn: Button

## A WORKING COPY of the campaign's operational map. The player's raids mutate this,
## and `_on_complete()` ships the result to TacticsPhaseManager — the campaign's own
## copy is only written by the consumer, so abandoning the phase changes nothing.
var _map = null
## PBP committed this phase. Sent as `pbp_spent` and deducted by
## TacticsPhaseManager._apply_strategic_results().
## ⚠ Do NOT also send player_battle_points inside `operational_map_update`: the consumer
## deducts `pbp_spent` from the campaign's stored value, so carrying both would
## double-count the spend.
var _pbp_spent: int = 0
var _raid_zone_id: String = ""
var _raid_log: Array = []


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


func show_phase(_phase: int) -> void:
	_rebuild_content()


func _build_ui() -> void:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(vbox)

	var title = Label.new()
	title.text = "STRATEGIC PHASE"
	title.add_theme_font_size_override("font_size", _scaled_font(22))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = "Resolve operational combat, issue orders, "\
		+ "redeploy forces, and open new zones."
	desc.add_theme_font_size_override("font_size", _scaled_font(14))
	desc.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(_content)

	var nav = HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(nav)

	_complete_btn = Button.new()
	_complete_btn.text = "Complete Strategic Phase"
	_complete_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	_complete_btn.pressed.connect(_on_complete)
	nav.add_child(_complete_btn)


func _rebuild_content() -> void:
	for child in _content.get_children():
		child.queue_free()

	if not _campaign or not "operational_map" in _campaign:
		var lbl = Label.new()
		lbl.text = "No operational map data."
		lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		_content.add_child(lbl)
		return

	# Rebuild the working copy from the campaign each time the phase is shown, so a
	# re-entry never carries a previous visit's uncommitted raids.
	_map = OperationalMapRef.from_dict(_campaign.operational_map)
	_pbp_spent = 0
	_raid_log.clear()
	_render_map()


## Split out so a raid can redraw without re-reading the campaign (which would discard
## the working copy's damage).
func _render_map() -> void:
	for child in _content.get_children():
		child.queue_free()

	var p_coh: int = _map.player_cohesion
	var e_coh: int = _map.enemy_cohesion
	_add_stat_row("Player Cohesion", str(p_coh),
		COLOR_SUCCESS if p_coh >= 3 else COLOR_DANGER)
	_add_stat_row("Enemy Cohesion", str(e_coh),
		COLOR_DANGER if e_coh >= 3 else COLOR_SUCCESS)

	# ⚠ p.96 caps PBP at 3 saved, so show the ceiling rather than a bare number — a
	# player holding 3 needs to know further wins are discarded "without any effects".
	var pbp: int = _map.player_battle_points
	_add_stat_row("Player Battle Points",
		"%d / %d max" % [pbp, OperationalRulesRef.max_saved_battle_points()],
		COLOR_FOCUS)

	# The operational turn checklist, READ FROM THE BOOK DATA rather than retyped.
	# This used to be an eight-line hardcoded literal whose wording had drifted from
	# the book's own section headings and which omitted Step 9 (Adjust Cohesion) —
	# the campaign's end condition.
	var steps: Array = OperationalRulesRef.turn_steps()
	if steps.is_empty():
		_add_card("Operational Turn Steps",
			"Step list unavailable — data/tactics/tactics_campaign_config.json "
			+ "could not be read.")
	else:
		var lines: Array = []
		for s in steps:
			if s is Dictionary:
				lines.append("%d. %s — %s" % [
					int(s.get("step", 0)), str(s.get("name", "")),
					str(s.get("description", ""))])
		_add_card("Operational Turn Steps (Tactics pp.96-99)",
			"\n".join(PackedStringArray(lines)))

	_render_zones()
	_render_raid_controls()


func _render_zones() -> void:
	var zones: Array = _map.zones
	if zones.is_empty():
		# Honest empty state. Before 2026-09-07 nothing ever appended to `zones`, so
		# this branch was the only one that could ever run — and it printed
		# "Active Zones: 0" as though that were a campaign state rather than a gap.
		_add_card("Operational Zones",
			"No Operational Zones have been opened yet. Zones are created during "
			+ "campaign setup and by Step 7 (Open new Zones) at the end of an "
			+ "operational turn.")
		return

	var body: Array = []
	for z in zones:
		if not (z is Dictionary):
			continue
		var zone: Dictionary = z
		body.append("%s — you %d / enemy %d" % [
			str(zone.get("name", zone.get("id", "Zone"))),
			int(zone.get("player_army_strength", 0)),
			int(zone.get("enemy_army_strength", 0))])
	_add_card("Operational Zones (Army Strength)",
		"\n".join(PackedStringArray(body)))


## Step 5 — Commando Raids (p.99). Commit PBP against a Zone and roll 1D6 per point.
func _render_raid_controls() -> void:
	var zones: Array = _map.zones
	if zones.is_empty() or _map.player_battle_points <= 0:
		return

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
	_content.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	card.add_child(vbox)

	var t = Label.new()
	t.text = "Step 5 — Commando Raids"
	t.add_theme_font_size_override("font_size", _scaled_font(16))
	t.add_theme_color_override("font_color", COLOR_FOCUS)
	vbox.add_child(t)

	var hint = Label.new()
	hint.text = "Roll 1D6 per point committed. Any 1-2 loses every point committed "\
		+ "against that Zone; every 6 costs the defender 1 Army Strength — and that "\
		+ "damage lands even when the points are lost."
	hint.add_theme_font_size_override("font_size", _scaled_font(13))
	hint.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)

	var picker = OptionButton.new()
	for z in zones:
		if z is Dictionary:
			picker.add_item(str((z as Dictionary).get(
				"name", (z as Dictionary).get("id", "Zone"))))
			picker.set_item_metadata(picker.item_count - 1,
				str((z as Dictionary).get("id", "")))
	if picker.item_count > 0:
		picker.select(0)
		_raid_zone_id = str(picker.get_item_metadata(0))
	picker.item_selected.connect(func(idx: int) -> void:
		_raid_zone_id = str(picker.get_item_metadata(idx)))
	vbox.add_child(picker)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(row)
	for n in range(1, mini(_map.player_battle_points, 3) + 1):
		var btn = Button.new()
		btn.text = "Raid with %d PBP" % n
		btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
		btn.pressed.connect(_on_raid.bind(n))
		row.add_child(btn)

	if not _raid_log.is_empty():
		var log_lbl = Label.new()
		log_lbl.text = "\n".join(PackedStringArray(_raid_log))
		log_lbl.add_theme_font_size_override("font_size", _scaled_font(13))
		log_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(log_lbl)


func _on_raid(points: int) -> void:
	if _map == null or _raid_zone_id.is_empty():
		return
	var receipt: Dictionary = _map.spend_pbp_commando_raid(_raid_zone_id, points)
	if receipt.is_empty():
		return
	_pbp_spent += int(receipt.get("spent", 0))
	var dmg: int = int(receipt.get("army_strength_damage", 0))
	var lost: int = int(receipt.get("pbp_lost", 0))
	_raid_log.append("Rolled %s — %s%s" % [
		str(receipt.get("rolls", [])),
		("-%d Army Strength" % dmg) if dmg > 0 else "no damage",
		(", %d PBP lost" % lost) if lost > 0 else ""])
	_render_map()


func _add_stat_row(label: String, value: String, color: Color) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_MD)
	_content.add_child(hbox)

	var lbl = Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", _scaled_font(16))
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var val = Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", _scaled_font(18))
	val.add_theme_color_override("font_color", color)
	hbox.add_child(val)


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


## Emit what the STRATEGIC phase actually resolved.
##
## ⚠ This used to be `phase_completed.emit(7, {})`. Every branch of
## TacticsPhaseManager._apply_strategic_results() is keyed on `data.has(...)`, so an
## empty payload meant the consumer ran and did nothing — the operational map was
## never written back and PBP was never deducted. The transport half is in
## TacticsTurnController._connect_signals(), which used to drop the dictionary as well;
## BOTH halves are required and each is detection-proven separately in
## tests/unit/test_tactics_turn_payload.gd.
##
## `operational_map_update` deliberately carries zones + cohesion + focus but NOT
## player_battle_points — the consumer derives that from `pbp_spent`, and sending both
## would deduct the spend twice.
func _on_complete() -> void:
	if _map == null:
		# Nothing was rendered (no campaign, or no operational map on it). Emit an
		# empty payload rather than a fabricated one: the phase still completes, and
		# an absent key is how the consumer is told "nothing was resolved here".
		phase_completed.emit(7, {})
		return

	var update: Dictionary = {
		"zones": _map.zones.duplicate(true),
		"player_cohesion": _map.player_cohesion,
		"enemy_cohesion": _map.enemy_cohesion,
		"focus_zone_id": _map.focus_zone_id,
	}
	phase_completed.emit(7, {
		"operational_map_update": update,
		"pbp_spent": _pbp_spent,
	})
