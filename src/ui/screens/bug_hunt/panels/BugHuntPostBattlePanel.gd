extends Control

## Bug Hunt Post-Battle Panel — Turn Stage 3 of 3
## Handles: Casualties, XP Awards, Reputation, Mustering Out,
## Operational Progress, Military Life events, and R&R.

signal phase_completed(result_data: Dictionary)

const _UC = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := _UC.COLOR_BASE
const COLOR_ELEVATED := _UC.COLOR_ELEVATED
const COLOR_TEXT := _UC.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := _UC.COLOR_TEXT_SECONDARY
const COLOR_BORDER := _UC.COLOR_BORDER
const COLOR_SUCCESS := _UC.COLOR_SUCCESS
const COLOR_WARNING := _UC.COLOR_WARNING
const COLOR_DANGER := _UC.COLOR_DANGER

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

	# Step 2: Update Completed Missions
	_update_completed_missions()

	# Step 3: Mustering Out checks
	_process_mustering_out()

	# Step 4: Reputation
	_process_reputation()

	# Step 5: XP Awards + Advancement
	_process_xp()
	_process_advancement()

	# Step 6: Operational Progress
	_process_operational_progress()

	# Step 7: Military Life event
	_process_military_life()

	# Step 8: R&R check
	_check_rr()

	# Court Martial check (Compendium p.201)
	_check_court_martial()

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
		var casualty_table_data: Dictionary = _post_battle_data.get("casualty_table", {})
		var casualty_entries: Array = casualty_table_data.get("entries", []) if casualty_table_data is Dictionary else []
		for mc in casualties:
			var char_name: String = mc.get("name", mc.get("character_name", "Unknown"))
			var char_id: String = mc.get("id", mc.get("character_id", ""))

			# Determine if Lost Marine (exited via battlefield edge) or Casualty
			var lost_marines: Array = _battle_results.get("lost_marines", [])
			var is_lost_marine: bool = char_id in lost_marines
			var range_key: String = "lost_marine_d100_range" if is_lost_marine else "casualty_d100_range"

			# Roll D100 on appropriate column (Compendium p.202)
			var roll: int = (randi() % 100) + 1
			var result: Dictionary = _find_in_table(casualty_entries, roll, range_key)

			# If lost_marine column has null for this range, try casualty column
			if result.is_empty() and is_lost_marine:
				result = _find_in_table(casualty_entries, roll, "casualty_d100_range")

			var result_lbl := Label.new()
			if result.get("is_dead", false):
				result_lbl.text = "%s — Roll %d — %s — KILLED IN ACTION" % [char_name, roll, result.get("name", "?")]
				result_lbl.add_theme_color_override("font_color", COLOR_DANGER)
			else:
				var turns: int = _roll_dice_formula(result.get("sick_bay_turns", "1"))
				result_lbl.text = "%s — Roll %d — %s — Sick Bay for %d turn(s)" % [char_name, roll, result.get("name", "?"), turns]
				result_lbl.add_theme_color_override("font_color", COLOR_WARNING)
				_results.casualties_processed.append({"id": char_id, "turns": turns})
			result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.add_child(result_lbl)


func _process_xp() -> void:
	## XP Awards — Compendium p.204
	## Casualty or Lost Marine: +1 XP
	## Not casualty, 0-1 Objectives: +2 XP
	## Not casualty, 2+ Objectives: +3 XP
	## Mission Priority 4+: +1 XP (all characters)
	## MVP (player choice): +1 XP
	var card := _create_card("Step 5: Experience and Leveling", _content_container)

	var objectives: int = _battle_results.get("objectives_completed", 0)
	var priority: int = _battle_results.get("priority", 1)
	var casualty_ids: Array = _battle_results.get("casualties", [])
	var lost_marine_ids: Array = _battle_results.get("lost_marines", [])

	if _campaign and "main_characters" in _campaign:
		for mc in _campaign.main_characters:
			if mc is not Dictionary:
				continue
			var char_id: String = mc.get("id", mc.get("character_id", ""))
			var char_name: String = mc.get("name", mc.get("character_name", "Unknown"))

			# Skip characters in sick bay (they didn't participate)
			if _campaign.has_method("get_active_main_characters"):
				var active: Array = _campaign.get_active_main_characters()
				var is_active := false
				for ac in active:
					if ac is Dictionary and ac.get("id", ac.get("character_id", "")) == char_id:
						is_active = true
						break
				if not is_active and char_id not in casualty_ids and char_id not in lost_marine_ids:
					continue

			var xp_earned: int = 0
			var breakdown: Array = []

			# Base XP based on casualty status and objectives
			var is_casualty: bool = char_id in casualty_ids or char_id in lost_marine_ids
			if is_casualty:
				xp_earned += 1
				breakdown.append("+1 (casualty/lost marine)")
			elif objectives <= 1:
				xp_earned += 2
				breakdown.append("+2 (survived, 0-1 objectives)")
			else:
				xp_earned += 3
				breakdown.append("+3 (survived, 2+ objectives)")

			# Priority 4+ bonus
			if priority >= 4:
				xp_earned += 1
				breakdown.append("+1 (priority %d)" % priority)

			_results.xp_awards[char_id] = xp_earned

			var lbl := Label.new()
			lbl.text = "%s: +%d XP (%s)" % [char_name, xp_earned, ", ".join(breakdown)]
			lbl.add_theme_color_override("font_color", COLOR_TEXT)
			card.add_child(lbl)

	# MVP note (player chooses — can't automate)
	var mvp_lbl := Label.new()
	mvp_lbl.text = "MVP: Award +1 XP to one character of your choice."
	mvp_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	mvp_lbl.add_theme_font_size_override("font_size", _scaled_font(13))
	card.add_child(mvp_lbl)


func _update_completed_missions() -> void:
	## Step 2 — Compendium p.203: +1 Completed Missions for each character that took the field.
	var card := _create_card("Step 2: Update Completed Missions", _content_container)
	if _campaign and "main_characters" in _campaign:
		var sick_bay: Dictionary = _campaign.sick_bay if "sick_bay" in _campaign else {}
		for mc in _campaign.main_characters:
			if mc is not Dictionary:
				continue
			var char_id: String = mc.get("id", mc.get("character_id", ""))
			var char_name: String = mc.get("name", mc.get("character_name", "Unknown"))
			if sick_bay.has(char_id):
				var lbl := Label.new()
				lbl.text = "%s — In Sick Bay, tally not updated" % char_name
				lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
				card.add_child(lbl)
				continue
			mc["completed_missions_count"] = mc.get("completed_missions_count", 0) + 1
			var lbl := Label.new()
			lbl.text = "%s — Missions: %d" % [char_name, mc.completed_missions_count]
			lbl.add_theme_color_override("font_color", COLOR_TEXT)
			card.add_child(lbl)


func _process_advancement() -> void:
	## Advancement — Compendium p.204: Spend XP to raise stats.
	## Reactions 8XP (max 4), Speed 6XP (max 8), CS 8XP (max 3),
	## Toughness 8XP (max 5), Savvy 6XP (max 4).
	var adv_data: Dictionary = _post_battle_data.get("experience", {})
	var costs: Array = adv_data.get("advancement_costs", []) if adv_data is Dictionary else []
	if costs.is_empty():
		return

	var card := _create_card("Advancement (Spend XP)", _content_container)
	var note_lbl := Label.new()
	note_lbl.text = "Characters may spend XP to advance stats. Review costs below:"
	note_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	note_lbl.add_theme_font_size_override("font_size", _scaled_font(13))
	card.add_child(note_lbl)

	# Show cost table
	var cost_text := ""
	for cost in costs:
		if cost is Dictionary:
			cost_text += "%s: %d XP (max %s)  " % [
				str(cost.get("stat", "")).capitalize().replace("_", " "),
				cost.get("xp_cost", 0),
				str(cost.get("max_value", "?"))]
	var costs_lbl := Label.new()
	costs_lbl.text = cost_text.strip_edges()
	costs_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	costs_lbl.add_theme_font_size_override("font_size", _scaled_font(12))
	costs_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(costs_lbl)

	# Per-character advancement options
	if _campaign and "main_characters" in _campaign:
		for mc in _campaign.main_characters:
			if mc is not Dictionary:
				continue
			var char_name: String = mc.get("name", mc.get("character_name", "Unknown"))
			var current_xp: int = mc.get("xp", 0) + _results.xp_awards.get(mc.get("id", mc.get("character_id", "")), 0)

			var char_box := VBoxContainer.new()
			char_box.add_theme_constant_override("separation", 4)
			card.add_child(char_box)

			var name_lbl := Label.new()
			name_lbl.text = "%s (XP: %d)" % [char_name, current_xp]
			name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
			char_box.add_child(name_lbl)

			var can_advance := false
			for cost in costs:
				if cost is not Dictionary:
					continue
				var stat_name: String = cost.get("stat", "")
				var xp_cost: int = cost.get("xp_cost", 99)
				var max_val: int = cost.get("max_value", 99)
				var current_stat: int = mc.get(stat_name, 0)

				if current_xp >= xp_cost and current_stat < max_val:
					can_advance = true
					# Create advance button
					var btn := Button.new()
					btn.text = "  %s %d→%d (-%d XP)  " % [
						stat_name.capitalize().replace("_", " "),
						current_stat, current_stat + 1, xp_cost]
					btn.custom_minimum_size.y = 36
					var mc_ref: Dictionary = mc
					var stat_ref: String = stat_name
					var cost_ref := xp_cost
					var char_id_ref: String = mc.get("id", mc.get("character_id", ""))
					btn.pressed.connect(func():
						mc_ref[stat_ref] = mc_ref.get(stat_ref, 0) + 1
						mc_ref["xp"] = mc_ref.get("xp", 0) + _results.xp_awards.get(char_id_ref, 0) - cost_ref
						_results.xp_awards[char_id_ref] = 0  # XP applied to character
						btn.text = "  Done! %s = %d  " % [stat_ref.capitalize().replace("_", " "), mc_ref.get(stat_ref, 0)]
						btn.disabled = true
					)
					char_box.add_child(btn)

			if not can_advance:
				var no_lbl := Label.new()
				no_lbl.text = "  No affordable advances"
				no_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
				no_lbl.add_theme_font_size_override("font_size", _scaled_font(12))
				char_box.add_child(no_lbl)


func _process_reputation() -> void:
	## Reputation — Compendium p.203
	## +1 automatically if 2+ Objectives completed.
	## Then roll 1D6 per Objective (including the first 2): each 5-6 = +1 Rep.
	var card := _create_card("Step 4: Determine Reputation", _content_container)

	var objectives: int = _battle_results.get("objectives_completed", 0)
	var rep_gain: int = 0

	# Base: +1 only if 2+ objectives completed
	if objectives >= 2:
		rep_gain += 1
		var base_lbl := Label.new()
		base_lbl.text = "+1 Reputation (completed 2+ objectives)"
		base_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
		card.add_child(base_lbl)
	else:
		var no_rep_lbl := Label.new()
		no_rep_lbl.text = "No base Reputation (need 2+ objectives, got %d)" % objectives
		no_rep_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		card.add_child(no_rep_lbl)

	# Roll 1D6 per objective: 5-6 = +1 Rep each
	if objectives > 0:
		var bonus_rep: int = 0
		var rolls: Array = []
		for i in range(objectives):
			var roll: int = (randi() % 6) + 1
			rolls.append(str(roll))
			if roll >= 5:
				bonus_rep += 1
		rep_gain += bonus_rep
		var rolls_lbl := Label.new()
		rolls_lbl.text = "Objective rolls: [%s] — %d scored 5+ = +%d Rep" % [", ".join(rolls), bonus_rep, bonus_rep]
		rolls_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		card.add_child(rolls_lbl)

	var total_lbl := Label.new()
	total_lbl.text = "Total: +%d Reputation" % rep_gain
	total_lbl.add_theme_font_size_override("font_size", _scaled_font(16))
	total_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	card.add_child(total_lbl)

	_results.reputation_change = rep_gain


func _process_mustering_out() -> void:
	## Mustering Out — Compendium p.203
	## Roll 2D6 >= Muster target = character leaves.
	## 1-4 missions: no chance. 5-7: 9+ only if casualty. 8-9: 9+. 10-11: 8+.
	## 12: 7+. 13: 6+. 14: 5+. 15: automatic.
	var card := _create_card("Step 3: Check for Mustering Out", _content_container)
	var muster_data: Dictionary = _post_battle_data.get("mustering_out", {})
	var muster_table: Array = muster_data.get("table", []) if muster_data is Dictionary else []

	var casualty_ids: Array = _battle_results.get("casualties", [])
	var lost_marine_ids: Array = _battle_results.get("lost_marines", [])

	if _campaign and "main_characters" in _campaign:
		for mc in _campaign.main_characters:
			if mc is not Dictionary:
				continue
			var missions_count: int = mc.get("completed_missions_count", 0) + 1  # Including this mission
			var char_id: String = mc.get("id", mc.get("character_id", ""))
			var char_name: String = mc.get("name", mc.get("character_name", "Unknown"))
			var was_casualty: bool = char_id in casualty_ids or char_id in lost_marine_ids

			# Find threshold for this mission count
			var threshold: int = 0
			var auto_muster: bool = false
			var casualty_only: bool = false
			for entry in muster_table:
				if entry is not Dictionary:
					continue
				# Handle range entries (e.g. [1, 4], [5, 7])
				if entry.has("completed_missions_range"):
					var r: Array = entry.completed_missions_range
					if r.size() >= 2 and missions_count >= r[0] and missions_count <= r[1]:
						if entry.get("muster_target") == null:
							if missions_count >= 15:
								auto_muster = true
							break  # No chance or auto
						threshold = entry.muster_target
						# Check if casualty-only restriction applies (5-7 range)
						var note: String = str(entry.get("note", ""))
						if "casualty" in note.to_lower():
							casualty_only = true
						break
				# Handle scalar entries (e.g. completed_missions: 12)
				elif entry.has("completed_missions"):
					if missions_count == entry.completed_missions:
						if entry.get("muster_target") == null:
							auto_muster = true
							break
						threshold = entry.muster_target
						break

			var lbl := Label.new()
			if auto_muster:
				lbl.text = "%s: %d missions — Automatic muster out (leaves squad)" % [char_name, missions_count]
				lbl.add_theme_color_override("font_color", COLOR_WARNING)
				_results.mustered_out.append(char_id)
			elif threshold <= 0:
				continue  # No mustering out check needed (1-4 missions)
			elif casualty_only and not was_casualty:
				lbl.text = "%s: %d missions — No muster check (wasn't a casualty)" % [char_name, missions_count]
				lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
			else:
				var die1: int = (randi() % 6) + 1
				var die2: int = (randi() % 6) + 1
				var total: int = die1 + die2
				var musters_out: bool = total >= threshold  # Compendium: "equal or above"

				if musters_out:
					lbl.text = "%s: %d missions — Rolled %d vs %d+ — MUSTERS OUT" % [char_name, missions_count, total, threshold]
					lbl.add_theme_color_override("font_color", COLOR_WARNING)
					_results.mustered_out.append(char_id)
				else:
					lbl.text = "%s: %d missions — Rolled %d vs %d+ — Stays in service" % [char_name, missions_count, total, threshold]
					lbl.add_theme_color_override("font_color", COLOR_TEXT)
			card.add_child(lbl)


func _process_operational_progress() -> void:
	var card := _create_card("Step 6: Operational Progress", _content_container)
	var op_data: Dictionary = _post_battle_data.get("operational_progress", {})
	var op_table: Array = op_data.get("entries", []) if op_data is Dictionary else []

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
	var card := _create_card("Step 7: Military Life", _content_container)
	var mil_data: Dictionary = _post_battle_data.get("military_life", {})
	var mil_table: Array = mil_data.get("entries", []) if mil_data is Dictionary else []

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
	var card := _create_card("Step 8: R&R Check", _content_container)
	var rr_data: Dictionary = _post_battle_data.get("r_and_r", {})
	var interval: int = rr_data.get("missions_required", 4) if rr_data is Dictionary else 4

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


func _check_court_martial() -> void:
	## Court Martial — Compendium p.201
	## If 0 Objectives completed, leader rolls D6. On 1 = removed from campaign.
	## Pay 3 Reputation to call in a favor and avoid.
	var objectives: int = _battle_results.get("objectives_completed", 0)
	if objectives > 0:
		return  # No court martial if any objectives completed

	var card := _create_card("Court Martial", _content_container)
	var warn_lbl := Label.new()
	warn_lbl.text = "ZERO objectives completed. The squad leader faces a court martial!"
	warn_lbl.add_theme_color_override("font_color", COLOR_DANGER)
	card.add_child(warn_lbl)

	var roll: int = (randi() % 6) + 1
	var guilty: bool = roll == 1

	var result_lbl := Label.new()
	if guilty:
		result_lbl.text = "Rolled %d — GUILTY! Squad leader removed from campaign." % roll
		result_lbl.add_theme_color_override("font_color", COLOR_DANGER)
		card.add_child(result_lbl)

		var favor_lbl := Label.new()
		favor_lbl.text = "Pay 3 Reputation to call in a favor and avoid this fate."
		favor_lbl.add_theme_color_override("font_color", COLOR_WARNING)
		card.add_child(favor_lbl)

		# Pay button
		if _campaign and _campaign.has_method("spend_reputation"):
			var pay_btn := Button.new()
			pay_btn.text = "Pay 3 Reputation (Call in Favor)"
			pay_btn.custom_minimum_size.y = 36
			var btn_ref := pay_btn
			pay_btn.pressed.connect(func():
				if _campaign.spend_reputation(3):
					btn_ref.text = "Favor called in — leader saved!"
					btn_ref.disabled = true
					# Remove leader from mustered_out if we added them
				else:
					btn_ref.text = "Not enough Reputation!"
			)
			card.add_child(pay_btn)
	else:
		result_lbl.text = "Rolled %d — Not guilty. No further action." % roll
		result_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
		card.add_child(result_lbl)


func _roll_dice_formula(formula) -> int:
	## Parse dice formulas like "1D3", "1D3+1", or plain integers.
	## Used for sick bay turns (Compendium p.202).
	if formula == null:
		return 0
	if formula is int or formula is float:
		return int(formula)
	var s: String = str(formula).to_upper().strip_edges()
	if s.is_empty() or s == "NULL":
		return 0
	if s.contains("D"):
		var parts := s.split("+")
		var dice_part := parts[0].strip_edges()
		var bonus: int = 0
		if parts.size() > 1:
			bonus = int(parts[1].strip_edges())
		var dice_split := dice_part.split("D")
		var num_dice: int = int(dice_split[0]) if dice_split[0] != "" else 1
		var die_sides: int = int(dice_split[1])
		var result: int = 0
		for i in range(num_dice):
			result += (randi() % die_sides) + 1
		return result + bonus
	return int(s)


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
		var range_val = entry.get("d100_range", [])

		# Handle string special ranges ("below_1", "above_100")
		if range_val is String:
			if range_val == "below_1" and adjusted_roll < 1:
				return entry
			if range_val == "above_100" and adjusted_roll > 100:
				return entry
			continue

		# Handle normal array ranges [low, high]
		if range_val is Array and range_val.size() >= 2:
			if adjusted_roll >= range_val[0] and adjusted_roll <= range_val[1]:
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
