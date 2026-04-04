extends Control

## Bug Hunt Post-Battle Panel — Turn Stage 3 of 3
## Handles: Casualties, XP Awards, Reputation, Mustering Out,
## Operational Progress, Military Life events, and R&R.

signal phase_completed(result_data: Dictionary)

const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_TEXT := Color("#E0E0E0")
const COLOR_TEXT_SEC := Color("#808080")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")

const POST_BATTLE_PATH := "res://data/bug_hunt/bug_hunt_post_battle.json"

var _campaign: Resource
var _phase_manager = null
var _post_battle_data: Dictionary = {}
var _battle_results: Dictionary = {}  # From TacticalBattleUI
var _results: Dictionary = {}
var _processed: bool = false

var _content_container: VBoxContainer


func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	_load_data()
	_build_ui()


func set_campaign(c: Resource) -> void:
	_campaign = c


func set_phase_manager(pm) -> void:
	_phase_manager = pm


func set_battle_results(results: Dictionary) -> void:
	## Receive real battle results from TacticalBattleUI via TurnController.
	_battle_results = results


func refresh() -> void:
	_processed = false
	_results.clear()
	_populate_post_battle()


func complete() -> void:
	if not _processed:
		_process_post_battle()
	phase_completed.emit({"post_battle_result": _results})


func _load_data() -> void:
	var file := FileAccess.open(POST_BATTLE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_post_battle_data = json.data
	file.close()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	_content_container = VBoxContainer.new()
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_container.add_theme_constant_override("separation", 16)
	scroll.add_child(_content_container)


func _populate_post_battle() -> void:
	for child in _content_container.get_children():
		child.queue_free()

	if not _campaign:
		var lbl := Label.new()
		lbl.text = "No campaign data available."
		lbl.add_theme_color_override("font_color", COLOR_WARNING)
		_content_container.add_child(lbl)
		return

	# Process button
	var process_btn := Button.new()
	process_btn.text = "Process Post-Battle"
	process_btn.custom_minimum_size = Vector2(220, 48)
	process_btn.pressed.connect(_process_post_battle)
	_content_container.add_child(process_btn)


func _process_post_battle() -> void:
	if _processed:
		return
	_processed = true

	# Clear and rebuild
	for child in _content_container.get_children():
		child.queue_free()

	_results = {
		"xp_awards": {},
		"reputation_change": 0,
		"op_progress_modifier": 0,
		"casualties_processed": [],
		"mustered_out": [],
		"military_life_event": {}
	}

	# Step 1: Casualty Processing
	_process_casualties()

	# Step 2: XP Awards
	_process_xp()

	# Step 3: Reputation
	_process_reputation()

	# Step 4: Mustering Out checks
	_process_mustering_out()

	# Step 5: Operational Progress
	_process_operational_progress()

	# Step 6: Military Life event
	_process_military_life()

	# Step 7: R&R check
	_check_rr()

	# Complete button
	var complete_btn := Button.new()
	complete_btn.text = "Complete Post-Battle"
	complete_btn.custom_minimum_size = Vector2(220, 48)
	complete_btn.pressed.connect(func(): complete())
	_content_container.add_child(complete_btn)


func _process_casualties() -> void:
	var card := _create_card("Step 1: Casualties", _content_container)

	# Use real battle results if available, otherwise fall back to random
	var casualty_ids: Array = _battle_results.get("casualties", [])
	var casualties: Array = []
	if not casualty_ids.is_empty() and _campaign and "main_characters" in _campaign:
		for mc in _campaign.main_characters:
			if mc is Dictionary:
				var mc_id: String = mc.get("id", mc.get("character_id", ""))
				if mc_id in casualty_ids:
					casualties.append(mc)
	elif _campaign and "main_characters" in _campaign:
		# Fallback: no battle data — random 20% (should not happen with wiring)
		# Use active characters only (excludes those already in sick bay)
		var active_chars: Array = []
		if _campaign.has_method("get_active_main_characters"):
			active_chars = _campaign.get_active_main_characters()
		else:
			active_chars = _campaign.main_characters
		for mc in active_chars:
			if mc is Dictionary and randi() % 5 == 0:
				casualties.append(mc)

	if casualties.is_empty():
		var lbl := Label.new()
		lbl.text = "No casualties this mission. Outstanding!"
		lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
		card.add_child(lbl)
	else:
		var casualty_table: Array = _post_battle_data.get("casualty_table", [])
		for mc in casualties:
			var char_name: String = mc.get("name", mc.get("character_name", "Unknown"))
			var char_id: String = mc.get("id", mc.get("character_id", ""))

			# Roll D100 on casualty table
			var roll: int = (randi() % 100) + 1
			var result: Dictionary = _find_in_table(casualty_table, roll, "casualty_d100_range")

			var result_lbl := Label.new()
			if result.get("effect", "") == "killed":
				result_lbl.text = "%s — Roll %d — %s — KILLED IN ACTION" % [char_name, roll, result.get("name", "?")]
				result_lbl.add_theme_color_override("font_color", COLOR_DANGER)
			else:
				var turns: int = result.get("sick_bay_turns", 1)
				result_lbl.text = "%s — Roll %d — %s — Sick Bay for %d turn(s)" % [char_name, roll, result.get("name", "?"), turns]
				result_lbl.add_theme_color_override("font_color", COLOR_WARNING)
				_results.casualties_processed.append({"id": char_id, "turns": turns})
			result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.add_child(result_lbl)


func _process_xp() -> void:
	var card := _create_card("Step 2: XP Awards", _content_container)
	var xp_rules: Dictionary = _post_battle_data.get("xp_awards", {})
	var base_xp: int = xp_rules.get("base_mission_xp", 1)

	if _campaign and "main_characters" in _campaign:
		for mc in _campaign.main_characters:
			if mc is not Dictionary:
				continue
			var char_id: String = mc.get("id", mc.get("character_id", ""))
			var char_name: String = mc.get("name", mc.get("character_name", "Unknown"))
			var xp_earned: int = base_xp

			# Bonus XP for kills from battle results
			var kills_data: Dictionary = _battle_results.get("kills", {})
			var kill_bonus: int = kills_data.get(char_id, 0)
			xp_earned += kill_bonus

			_results.xp_awards[char_id] = xp_earned

			var lbl := Label.new()
			lbl.text = "%s: +%d XP (base %d + %d kills)" % [char_name, xp_earned, base_xp, kill_bonus]
			lbl.add_theme_color_override("font_color", COLOR_TEXT)
			card.add_child(lbl)


func _process_reputation() -> void:
	var card := _create_card("Step 3: Reputation", _content_container)

	# +1 for completing mission
	var rep_gain: int = 1
	var base_lbl := Label.new()
	base_lbl.text = "+1 Reputation for completing the mission"
	base_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
	card.add_child(base_lbl)

	# +1 per objective completed from battle results
	var objectives: int = _battle_results.get("objectives_completed", 0)
	if objectives > 0:
		rep_gain += objectives
		var obj_lbl := Label.new()
		obj_lbl.text = "+%d Reputation for %d objective(s) completed" % [objectives, objectives]
		obj_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
		card.add_child(obj_lbl)

	var total_lbl := Label.new()
	total_lbl.text = "Total: +%d Reputation" % rep_gain
	total_lbl.add_theme_font_size_override("font_size", _scaled_font(16))
	total_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	card.add_child(total_lbl)

	_results.reputation_change = rep_gain


func _process_mustering_out() -> void:
	var card := _create_card("Step 4: Mustering Out Checks", _content_container)
	var muster_table: Array = _post_battle_data.get("mustering_out_table", [])

	if _campaign and "main_characters" in _campaign:
		for mc in _campaign.main_characters:
			if mc is not Dictionary:
				continue
			var missions_count: int = mc.get("completed_missions_count", 0) + 1  # Including this mission
			var char_name: String = mc.get("name", mc.get("character_name", "Unknown"))

			# Find threshold for this mission count
			var threshold: int = 0
			for entry in muster_table:
				if entry is Dictionary and entry.get("completed_missions", 0) == missions_count:
					threshold = entry.get("muster_2d6", 0)
					break

			if threshold <= 0:
				continue  # No mustering out check needed yet

			var die1: int = (randi() % 6) + 1
			var die2: int = (randi() % 6) + 1
			var total: int = die1 + die2
			var musters_out: bool = total <= threshold

			var lbl := Label.new()
			if musters_out:
				lbl.text = "%s: %d missions — Rolled %d vs %d — MUSTERS OUT (leaves squad)" % [char_name, missions_count, total, threshold]
				lbl.add_theme_color_override("font_color", COLOR_WARNING)
				_results.mustered_out.append(mc.get("id", mc.get("character_id", "")))
			else:
				lbl.text = "%s: %d missions — Rolled %d vs %d — Stays in service" % [char_name, missions_count, total, threshold]
				lbl.add_theme_color_override("font_color", COLOR_TEXT)
			card.add_child(lbl)


func _process_operational_progress() -> void:
	var card := _create_card("Step 5: Operational Progress", _content_container)
	var op_table: Array = _post_battle_data.get("operational_progress_table", [])

	var modifier: int = 0
	if _campaign and "operational_progress_modifier" in _campaign:
		modifier = _campaign.operational_progress_modifier

	var roll: int = (randi() % 100) + 1 + modifier
	var result: Dictionary = _find_in_op_progress(op_table, roll)

	var lbl := Label.new()
	lbl.text = "Roll: %d (D100=%d + modifier %d) — %s" % [roll, roll - modifier, modifier, result.get("name", "No change")]
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(lbl)

	if not result.get("description", "").is_empty():
		var desc := Label.new()
		desc.text = result.get("description", "")
		desc.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		desc.add_theme_font_size_override("font_size", _scaled_font(13))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(desc)

	_results.op_progress_modifier = result.get("cumulative_modifier", 0)


func _process_military_life() -> void:
	var card := _create_card("Step 6: Military Life", _content_container)
	var mil_table: Array = _post_battle_data.get("military_life_table", [])

	if mil_table.is_empty():
		var lbl := Label.new()
		lbl.text = "No military life events table loaded."
		lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		card.add_child(lbl)
		return

	var roll: int = (randi() % 100) + 1
	var result: Dictionary = _find_in_table(mil_table, roll, "d100_range")

	var lbl := Label.new()
	lbl.text = "Roll %d — %s" % [roll, result.get("name", "Nothing noteworthy")]
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	card.add_child(lbl)

	if not result.get("effect", "").is_empty():
		var effect := Label.new()
		effect.text = result.get("effect", "")
		effect.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		effect.add_theme_font_size_override("font_size", _scaled_font(13))
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(effect)

	_results.military_life_event = result


func _check_rr() -> void:
	var card := _create_card("Step 7: R&R Check", _content_container)
	var rr_rules: Dictionary = _post_battle_data.get("rr_rules", {})
	var interval: int = rr_rules.get("mission_interval", 4)

	var turn: int = 1
	if _campaign and "campaign_turn" in _campaign:
		turn = _campaign.campaign_turn

	var lbl := Label.new()
	if turn % interval == 0:
		lbl.text = "R&R is available this turn! Squad may take a break (no mission next turn). All Sick Bay recoveries advance by 1 turn."
		lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
	else:
		var next_rr: int = interval - (turn % interval)
		lbl.text = "R&R in %d more mission(s). (Spend 1 Reputation to take early R&R.)" % next_rr
		lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(lbl)


func _find_in_table(table: Array, roll: int, range_key: String) -> Dictionary:
	for entry in table:
		if entry is Dictionary and entry.has(range_key):
			var range_val: Array = entry[range_key]
			if range_val.size() >= 2 and roll >= range_val[0] and roll <= range_val[1]:
				return entry
	return {}


func _find_in_op_progress(table: Array, adjusted_roll: int) -> Dictionary:
	for entry in table:
		if entry is not Dictionary:
			continue
		var range_val: Array = entry.get("d100_range", [])
		if range_val.size() < 2:
			continue

		# Handle "below 1" and "above 100" special ranges
		var low: int = range_val[0]
		var high: int = range_val[1]

		if low == -999 and adjusted_roll < 1:
			return entry
		if high == 999 and adjusted_roll > 100:
			return entry
		if adjusted_roll >= low and adjusted_roll <= high:
			return entry
	return {}


func _create_card(title_text: String, parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", _scaled_font(18))
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(lbl)

	return vbox
