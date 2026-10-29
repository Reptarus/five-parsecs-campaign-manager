extends Control

## Tactics Operational Map Panel — the STRATEGIC phase (phase 7).
##
## Walks the operational turn in the order Tactics p.96 prints it — Step 3 Operational
## Combat in every Zone, Step 4 Operational Orders, Step 5 Commando Raids, Step 6
## Redeploy, Step 7 new Zones and Focus, Step 8 player commitment — and shows each
## step's dice as a receipt card. Step 9 (Cohesion) is applied by TacticsPhaseManager
## from the `regions_lost` this panel reports.
##
## ⚠ Until 2026-10-27 this panel showed the step LIST and a Commando Raid button, and
## nothing else ran: the combat and orders rules had zero callers and no Zone had ever
## been created. The rules now run through TacticsOperationalTurn.

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

const OperationalRulesRef = preload(
	"res://src/core/campaign/TacticsOperationalRules.gd")
const ReceiptCardRef := preload("res://src/ui/components/common/ReceiptCard.gd")
const OperationalTurnRef = preload(
	"res://src/core/campaign/TacticsOperationalTurn.gd")
const TouchScrollOpenerRef = preload(
	"res://src/ui/components/common/TouchScrollOpener.gd")

enum Stage { COMBAT, ORDERS_ROLL, ORDERS_APPLY, RAIDS, REDEPLOY, NEW_ZONES, COMMIT }

var _phase_manager = null
var _campaign = null
var _content: VBoxContainer
var _complete_btn: Button

## A WORKING COPY of the campaign's operational map (the Dictionary it stores). Every
## step mutates this copy; `_on_complete()` ships it to TacticsPhaseManager, which is
## the only writer of the campaign. Abandoning the phase changes nothing.
var _map: Dictionary = {}
var _turn = null
var _stage: int = Stage.COMBAT
var _receipts: Array = []
## Running totals across every step this phase: Step 9 needs the regions lost, Step 7
## the Zones won.
var _regions_lost: Dictionary = {"player": 0, "enemy": 0}
var _zones_won: Dictionary = {"player": 0, "enemy": 0}
## PBP committed this phase (Step 3 dice and Step 5 raids). Sent as `pbp_spent` and
## deducted by TacticsPhaseManager._apply_strategic_results().
## ⚠ Do NOT also send player_battle_points inside `operational_map_update`: the consumer
## deducts `pbp_spent` from the campaign's stored value, so carrying both would
## double-count the spend.
var _pbp_spent: int = 0
var _combat_pbp: int = 0
## Zones where the player opts into the p.98 Assault Option this turn.
var _assault_zones: Array = []
var _rolled_orders: Dictionary = {}
var _order_target: String = ""
var _raid_zone_id: String = ""
var _redeploy_from: String = ""
var _redeploy_to: String = ""
var _attack_region: String = ""


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
	desc.text = "Resolve the operational turn one step at a time (Tactics pp.96-99). "\
		+ "Mirror each result on your campaign map."
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
	_map = {}
	if _campaign and "operational_map" in _campaign \
			and _campaign.operational_map is Dictionary:
		# Rebuilt from the campaign each time the phase is shown, so a re-entry never
		# carries a previous visit's uncommitted steps.
		_map = (_campaign.operational_map as Dictionary).duplicate(true)
	_turn = OperationalTurnRef.new()
	_stage = Stage.COMBAT
	_receipts.clear()
	_regions_lost = {"player": 0, "enemy": 0}
	_zones_won = {"player": 0, "enemy": 0}
	_pbp_spent = 0
	_combat_pbp = 0
	_assault_zones = []
	_rolled_orders = {}
	_order_target = ""
	_raid_zone_id = ""
	_redeploy_from = ""
	_redeploy_to = ""
	_attack_region = ""
	_render()


func _render() -> void:
	for child in _content.get_children():
		child.queue_free()

	if _map.is_empty():
		var lbl = Label.new()
		lbl.text = "No operational map data."
		lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		_content.add_child(lbl)
		_complete_btn.disabled = false
		return

	_render_status()
	_render_receipts()
	_render_zones()

	match _stage:
		Stage.COMBAT:
			_render_combat_step()
		Stage.ORDERS_ROLL:
			_add_action("Roll Step 4 — Operational Orders (1D6 each side)",
				_on_roll_orders)
		Stage.ORDERS_APPLY:
			_render_orders_step()
		Stage.RAIDS:
			_render_raid_controls()
			_add_action("Continue to Step 6 — Redeploy Forces", _advance_to.bind(Stage.REDEPLOY))
		Stage.REDEPLOY:
			_render_redeploy_step()
		Stage.NEW_ZONES:
			_render_new_zones_step()
		Stage.COMMIT:
			_render_commit_step()

	_complete_btn.disabled = _stage != Stage.COMMIT
	# Every surface built here defaults to MOUSE_FILTER_STOP, which swallows a finger's
	# drag before the ScrollContainer sees it.
	TouchScrollOpenerRef.open_subtree(_content)


func _render_status() -> void:
	var p_coh: int = int(_map.get("player_cohesion", 5))
	var e_coh: int = int(_map.get("enemy_cohesion", 5))
	var p_lost: int = int(_regions_lost.player)
	var e_lost: int = int(_regions_lost.enemy)
	_add_stat_row("Player Cohesion", str(p_coh) if p_lost == 0 \
		else "%d (−%d this turn)" % [p_coh, p_lost],
		COLOR_SUCCESS if p_coh - p_lost >= 3 else COLOR_DANGER)
	_add_stat_row("Enemy Cohesion", str(e_coh) if e_lost == 0 \
		else "%d (−%d this turn)" % [e_coh, e_lost],
		COLOR_DANGER if e_coh - e_lost >= 3 else COLOR_SUCCESS)
	# ⚠ p.96 caps PBP at 3 saved, so show the ceiling rather than a bare number.
	_add_stat_row("Player Battle Points", "%d / %d max" % [
		int(_map.get("player_battle_points", 0)),
		OperationalRulesRef.max_saved_battle_points()], COLOR_FOCUS)

	var owned: Dictionary = {"player": 0, "enemy": 0, "neutral": 0}
	for region in _map.get("regions", []):
		if region is Dictionary:
			var o: String = str(region.get("owner", "neutral"))
			owned[o] = int(owned.get(o, 0)) + 1
	_add_stat_row("Regions (yours / enemy / neutral)", "%d / %d / %d" % [
		owned.player, owned.enemy, owned.neutral], COLOR_TEXT)


## Zone cards. The two check boxes mirror the player's paper map, which the app cannot
## see: p.97 grants "+1 Combat Die if the enemy is not adjacent to their own territory".
func _render_zones() -> void:
	var zones: Array = _map.get("zones", [])
	if zones.is_empty():
		_add_card("Operational Zones", "No Operational Zone is open. Step 4 (a New "
			+ "Offensive) and Step 7 (a faction that won a Zone attacks) open new ones.")
		return
	for z in zones:
		if not (z is Dictionary):
			continue
		var zone: Dictionary = z
		var tags: PackedStringArray = PackedStringArray()
		if str(zone.get("id", "")) == str(_map.get("focus_zone_id", "")):
			tags.append("Operational Focus")
		if str(zone.get("id", "")) == str(_map.get("player_zone_id", "")):
			tags.append("your army is here")
		var card := _add_card("%s%s" % [str(zone.get("name", zone.get("id", "Zone"))),
				"" if tags.is_empty() else " — " + ", ".join(tags)],
			"Army Strength: you %d, enemy %d" % [
				int(zone.get("player_army_strength", 0)),
				int(zone.get("enemy_army_strength", 0))])
		if _stage <= Stage.ORDERS_APPLY:
			var box: VBoxContainer = card.get_child(0)
			for side in ["player", "enemy"]:
				var cb := CheckBox.new()
				cb.text = "Your territory touches this Zone" if side == "player" \
					else "Enemy territory touches this Zone"
				# Wrapped like the assault box below: these set a phone page's width (330).
				cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				cb.button_pressed = bool(zone.get(side + "_adjacent", true))
				cb.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
				cb.toggled.connect(func(on: bool) -> void: zone[side + "_adjacent"] = on)
				box.add_child(cb)
		var zid: String = str(zone.get("id", ""))
		if _stage == Stage.COMBAT and OperationalTurnRef.can_assault(zone, "player"):
			var box2: VBoxContainer = card.get_child(0)
			var ab := CheckBox.new()
			ab.text = "Launch an assault: +1 Combat Die, but -1 Army Strength if you " \
				+ "fail to win (p.98)"
			ab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ab.button_pressed = _assault_zones.has(zid)
			ab.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
			ab.toggled.connect(func(on: bool) -> void:
				if on and not _assault_zones.has(zid):
					_assault_zones.append(zid)
				elif not on:
					_assault_zones.erase(zid))
			box2.add_child(ab)


# MARK: - Step 3

func _render_combat_step() -> void:
	var held: int = int(_map.get("player_battle_points", 0))
	var here: Dictionary = OperationalTurnRef._zone(_map, str(_map.get("player_zone_id", "")))
	if held > 0 and not here.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", SPACING_SM)
		_content.add_child(row)
		var lbl := Label.new()
		lbl.text = "PBP to spend in %s (+1 Combat Die each, p.97):" % here.get("name", "")
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", COLOR_TEXT)
		row.add_child(lbl)
		var pick := OptionButton.new()
		for n in range(held + 1):
			pick.add_item(str(n))
		pick.select(clampi(_combat_pbp, 0, held))
		pick.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
		pick.item_selected.connect(func(i: int) -> void: _combat_pbp = i)
		row.add_child(pick)
	_add_action("Resolve Step 3 — Operational Combat in every Zone", _on_resolve_combat)


func _on_resolve_combat() -> void:
	var spend: int = clampi(_combat_pbp, 0, int(_map.get("player_battle_points", 0)))
	if spend > 0:
		_map["player_battle_points"] = int(_map.get("player_battle_points", 0)) - spend
		_pbp_spent += spend
	_take(_turn.resolve_zone_battles(_map, spend, _assault_zones))
	_stage = Stage.ORDERS_ROLL
	_render()


# MARK: - Step 4

func _on_roll_orders() -> void:
	_rolled_orders = _turn.roll_orders()
	var targets: Array = _player_order_targets()
	_order_target = str(targets[0]) if not targets.is_empty() else ""
	_stage = Stage.ORDERS_APPLY
	_render()


func _player_order_targets() -> Array:
	var row: Dictionary = _rolled_orders.get("player", {})
	return OperationalTurnRef.order_target_zones(_map, "player", int(row.get("roll", 0)))


func _render_orders_step() -> void:
	var lines: PackedStringArray = PackedStringArray()
	for f in ["player", "enemy"]:
		var row: Dictionary = _rolled_orders.get(f, {})
		lines.append("%s rolled %d — %s: %s" % [
			"You" if f == "player" else "The enemy", int(row.get("roll", 0)),
			str(row.get("name", "?")), str(row.get("effect", ""))])
	_add_card("Step 4 — Operational Orders (p.98)", "\n".join(lines))

	var targets: Array = _player_order_targets()
	if not targets.is_empty():
		_add_zone_picker("Your order's Zone (p.98: a player may select the target):",
			targets, _order_target, func(id: String) -> void: _order_target = id)
	_add_action("Carry Out Orders", _on_carry_out_orders)


func _on_carry_out_orders() -> void:
	_take(_turn.carry_out_orders(_map, _rolled_orders, _order_target))
	_stage = Stage.RAIDS
	_render()


# MARK: - Step 5

## Commit PBP against a Zone's enemy army and roll 1D6 per point.
func _render_raid_controls() -> void:
	var zones: Array = _map.get("zones", [])
	var held: int = int(_map.get("player_battle_points", 0))
	if zones.is_empty() or held <= 0:
		_add_card("Step 5 — Commando Raids (p.99)",
			"No Player Battle Points to commit." if held <= 0 else "No Zone to raid.")
		return

	var ids: Array = []
	for z in zones:
		if z is Dictionary:
			ids.append(str((z as Dictionary).get("id", "")))
	if not ids.has(_raid_zone_id):
		_raid_zone_id = str(ids[0])
	_add_card("Step 5 — Commando Raids (p.99)",
		"Commit unspent PBP against the same or an adjacent region. Roll 1D6 per point: "
		+ "any 1-2 loses every point committed there; every 6 costs the defender 1 Army "
		+ "Strength, and that damage lands even when the points are lost.")
	_add_zone_picker("Raid target:", ids, _raid_zone_id,
		func(id: String) -> void: _raid_zone_id = id)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", SPACING_SM)
	_content.add_child(row)
	for n in range(1, held + 1):
		var btn = Button.new()
		btn.text = "Raid with %d PBP" % n
		btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
		btn.pressed.connect(_on_raid.bind(n))
		row.add_child(btn)


func _on_raid(points: int) -> void:
	var receipt: Dictionary = _turn.commando_raid(_map, _raid_zone_id, points)
	if receipt.is_empty():
		return
	_pbp_spent += int(receipt.get("spent", 0))
	_take(receipt)
	_render()


# MARK: - Step 6

func _render_redeploy_step() -> void:
	var sources: Array = OperationalTurnRef.redeploy_sources(_map, "player")
	var all_ids: Array = []
	for z in _map.get("zones", []):
		if z is Dictionary:
			all_ids.append(str((z as Dictionary).get("id", "")))
	if sources.is_empty() or all_ids.size() < 2:
		_add_card("Step 6 — Redeploy Forces (p.99)",
			"You have no army that can spare a point of Army Strength.")
	else:
		_add_card("Step 6 — Redeploy Forces (p.99)",
			"You may move 1 Army Strength between two of your armies, provided they are "
			+ "connected through a series of friendly territories on your map.")
		_add_zone_picker("Take 1 from:", [""] + sources, _redeploy_from,
			func(id: String) -> void: _redeploy_from = id)
		_add_zone_picker("Give it to:", [""] + all_ids, _redeploy_to,
			func(id: String) -> void: _redeploy_to = id)
	_add_action("Resolve Step 6 — Redeploy", _on_redeploy)


func _on_redeploy() -> void:
	var receipt: Dictionary = OperationalTurnRef._receipt("Step 6 — Redeploy Forces (p.99)")
	if not _redeploy_from.is_empty() and not _redeploy_to.is_empty():
		receipt.lines.append_array(
			_turn.redeploy(_map, "player", _redeploy_from, _redeploy_to).lines)
	else:
		receipt.lines.append("You did not redeploy.")
	receipt.lines.append_array(_turn.ai_redeploy(_map, "enemy").lines)
	_take(receipt)
	_attack_region = ""
	_stage = Stage.NEW_ZONES
	_render()


# MARK: - Step 7

func _render_new_zones_step() -> void:
	if int(_zones_won.player) > 0:
		var targets: Array = OperationalTurnRef.attack_targets(_map, "player")
		if not targets.is_empty():
			if not targets.has(_attack_region):
				_attack_region = str(targets[0])
			_add_region_picker("You won a Zone, so you attack a region adjacent to your "
				+ "territory:", targets, _attack_region,
				func(id: String) -> void: _attack_region = id)
	_add_action("Resolve Step 7 — Open new Zones and select the Focus", _on_new_zones)


func _on_new_zones() -> void:
	_take(_turn.open_new_zones(_map, _zones_won, _attack_region))
	_stage = Stage.COMMIT
	_render()


# MARK: - Step 8

func _render_commit_step() -> void:
	var ids: Array = []
	for z in _map.get("zones", []):
		if z is Dictionary:
			ids.append(str((z as Dictionary).get("id", "")))
	if ids.is_empty():
		_add_card("Step 8 — Choose Player Commitments (p.99)",
			"No Zone is open for your army this turn.")
		return
	if not ids.has(str(_map.get("player_zone_id", ""))):
		_map["player_zone_id"] = str(ids[0])
	_add_zone_picker("Step 8 — assign your army to a Zone:", ids,
		str(_map.get("player_zone_id", "")),
		func(id: String) -> void: _map["player_zone_id"] = id)


# MARK: - Shared builders

func _take(receipt: Dictionary) -> void:
	if receipt.is_empty():
		return
	_receipts.append(receipt)
	for side in ["player", "enemy"]:
		_regions_lost[side] = int(_regions_lost[side]) \
			+ int(receipt.get("regions_lost", {}).get(side, 0))
		_zones_won[side] = int(_zones_won[side]) \
			+ int(receipt.get("zones_won", {}).get(side, 0))


func _advance_to(stage: int) -> void:
	_stage = stage
	_render()


func _zone_name(id: String) -> String:
	var z: Dictionary = OperationalTurnRef._zone(_map, id)
	return str(z.get("name", id)) if not z.is_empty() else "—"


func _add_zone_picker(caption: String, ids: Array, selected: String,
		on_pick: Callable) -> void:
	_add_picker(caption, ids, selected, on_pick, _zone_name)


func _add_region_picker(caption: String, ids: Array, selected: String,
		on_pick: Callable) -> void:
	_add_picker(caption, ids, selected, on_pick, func(id: String) -> String:
		var r: Dictionary = OperationalTurnRef._region(_map, id)
		var held_by: String = str(r.get("owner", "neutral"))
		return "%s (%s)" % [str(r.get("name", id)),
			"enemy territory" if held_by == "enemy" else held_by])


func _add_picker(caption: String, ids: Array, selected: String, on_pick: Callable,
		label_for: Callable) -> void:
	var lbl := Label.new()
	lbl.text = caption
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", _scaled_font(14))
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	_content.add_child(lbl)
	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	for id in ids:
		pick.add_item("—" if str(id).is_empty() else str(label_for.call(str(id))))
		pick.set_item_metadata(pick.item_count - 1, str(id))
		if str(id) == selected:
			pick.select(pick.item_count - 1)
	pick.item_selected.connect(func(i: int) -> void:
		on_pick.call(str(pick.get_item_metadata(i))))
	_content.add_child(pick)


func _add_action(text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.pressed.connect(callback)
	_content.add_child(btn)


func _add_stat_row(label: String, value: String, color: Color) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_MD)
	_content.add_child(hbox)

	var lbl = Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", _scaled_font(16))
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(lbl)

	var val = Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", _scaled_font(18))
	val.add_theme_color_override("font_color", color)
	hbox.add_child(val)


func _add_card(card_title: String, body: String) -> PanelContainer:
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

	if not body.is_empty():
		var b = Label.new()
		b.text = body
		b.add_theme_font_size_override("font_size", _scaled_font(14))
		b.add_theme_color_override("font_color", COLOR_TEXT)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(b)

	_content.add_child(card)
	return card


## Each STRATEGIC step's dice, one card per step, through the shared receipt (UX-6).
func _render_receipts() -> void:
	for r in _receipts:
		if r is Dictionary and not (r.get("lines", []) as Array).is_empty():
			var card: PanelContainer = _add_card(str(r.get("title", "")), "")
			ReceiptCardRef.fill(card.get_child(0), r, Callable(), 14)


## Emit what the STRATEGIC phase resolved.
##
## ⚠ This used to be `phase_completed.emit(7, {})`. Every branch of
## TacticsPhaseManager._apply_strategic_results() is keyed on `data.has(...)`, so an
## empty payload meant the consumer ran and did nothing. The transport half is in
## TacticsTurnController._connect_signals(); BOTH halves are detection-proven in
## tests/unit/test_tactics_turn_payload.gd.
##
## Cohesion is NOT in `operational_map_update`: the consumer derives it from
## `regions_lost` / `enemy_regions_lost` (Step 9), and sending the value too would
## apply the loss twice. Likewise player_battle_points rides as `pbp_spent` only.
func _on_complete() -> void:
	if _map.is_empty():
		# Nothing was rendered (no campaign, or no operational map on it). Emit an
		# empty payload rather than a fabricated one: the phase still completes, and
		# an absent key is how the consumer is told "nothing was resolved here".
		phase_completed.emit(7, {})
		return

	var turn: int = int(_campaign.operational_turn) \
		if _campaign and "operational_turn" in _campaign else 0
	OperationalTurnRef.log_strategic_phase(_map, turn, _receipts)
	var update: Dictionary = {}
	for key in ["zones", "regions", "focus_zone_id", "player_zone_id",
			"orders_history", "next_zone_seq"]:
		if _map.has(key):
			update[key] = _map[key].duplicate(true) \
				if (_map[key] is Array or _map[key] is Dictionary) else _map[key]
	phase_completed.emit(7, {
		"operational_map_update": update,
		"pbp_spent": _pbp_spent,
		"regions_lost": int(_regions_lost.player),
		"enemy_regions_lost": int(_regions_lost.enemy),
	})
