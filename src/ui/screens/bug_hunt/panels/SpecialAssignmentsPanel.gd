extends Control

## Special Assignments Panel — Bug Hunt Turn Stage 1 of 3
## Characters can attempt training, request support, or skip.
## Each assignment requires a 2D6 roll against a target number.

signal phase_completed(result_data: Dictionary)

const _UC = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := _UC.COLOR_BASE
const COLOR_ELEVATED := _UC.COLOR_ELEVATED
const COLOR_TEXT := _UC.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := _UC.COLOR_TEXT_SECONDARY
const COLOR_BORDER := _UC.COLOR_BORDER
const COLOR_SUCCESS := _UC.COLOR_SUCCESS
const COLOR_WARNING := _UC.COLOR_WARNING
const COLOR_ACCENT := _UC.COLOR_ACCENT

const ASSIGNMENTS_PATH := "res://data/bug_hunt/bug_hunt_special_assignments.json"

var _campaign: Resource
var _phase_manager = null
var _assignments_data: Array = []
var _assignment_slots: Array[Dictionary] = []  # {character_id, character_name, assignment_id}
var _results_container: VBoxContainer
var _characters_container: VBoxContainer
var _completed: bool = false


func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	_load_assignments_data()
	_build_ui()


func set_campaign(c: Resource) -> void:
	_campaign = c


func set_phase_manager(pm) -> void:
	_phase_manager = pm


func refresh() -> void:
	_completed = false
	_assignment_slots.clear()
	_populate_characters()


func complete() -> void:
	if _completed:
		return
	_completed = true
	# Gather results and emit
	var results := {"completed_assignments": _assignment_slots.duplicate(true)}
	phase_completed.emit(results)


func _load_assignments_data() -> void:
	var file := FileAccess.open(ASSIGNMENTS_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_assignments_data = json.data.get("assignments", [])
	file.close()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	# Info card
	var info_card := _create_card("Special Assignments", vbox)
	var info_lbl := Label.new()
	info_lbl.text = "Each Main Character not in Sick Bay may attempt one Special Assignment.\nRoll 2D6 — meet or beat the target number to succeed.\nA character can only complete each assignment once in their career."
	info_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	info_lbl.add_theme_font_size_override("font_size", _scaled_font(14))
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_card.add_child(info_lbl)

	# Characters + assignment selection
	_characters_container = VBoxContainer.new()
	_characters_container.add_theme_constant_override("separation", 12)
	vbox.add_child(_characters_container)

	# Results area
	_results_container = VBoxContainer.new()
	_results_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_results_container)

	# Roll All button
	var roll_btn := Button.new()
	roll_btn.text = "Roll All Assignments"
	roll_btn.custom_minimum_size = Vector2(200, 44)
	roll_btn.pressed.connect(_on_roll_all)
	vbox.add_child(roll_btn)

	# Skip button
	var skip_btn := Button.new()
	skip_btn.text = "Skip Assignments"
	skip_btn.custom_minimum_size = Vector2(200, 44)
	skip_btn.pressed.connect(func(): complete())
	vbox.add_child(skip_btn)


func _populate_characters() -> void:
	for child in _characters_container.get_children():
		child.queue_free()
	for child in _results_container.get_children():
		child.queue_free()

	if not _campaign or not "main_characters" in _campaign:
		return

	var characters: Array = _campaign.main_characters
	var sick_bay: Dictionary = _campaign.sick_bay if "sick_bay" in _campaign else {}
	var completed: Dictionary = _campaign.completed_assignments if "completed_assignments" in _campaign else {}

	for mc in characters:
		if mc is not Dictionary:
			continue
		var char_id: String = mc.get("id", mc.get("character_id", ""))
		var char_name: String = mc.get("name", mc.get("character_name", "Unknown"))

		# Skip sick bay characters
		if sick_bay.has(char_id):
			var sick_card := _create_card(char_name + " (Sick Bay)", _characters_container)
			var sick_lbl := Label.new()
			sick_lbl.text = "Recovering — %d turn(s) remaining" % sick_bay.get(char_id, 1)
			sick_lbl.add_theme_color_override("font_color", COLOR_WARNING)
			sick_card.add_child(sick_lbl)
			continue

		var card := _create_card(char_name, _characters_container)

		# Show current stats for reference
		var stats_lbl := Label.new()
		stats_lbl.text = "R:%d  S:%d  CS:%d  T:%d  Sv:%d  XP:%d  Missions:%d" % [
			mc.get("reactions", 1), mc.get("speed", 4), mc.get("combat_skill", 0),
			mc.get("toughness", 3), mc.get("savvy", 0), mc.get("xp", 0),
			mc.get("completed_missions_count", 0)]
		stats_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		stats_lbl.add_theme_font_size_override("font_size", _scaled_font(12))
		card.add_child(stats_lbl)

		# Assignment dropdown — filter by eligibility (Compendium p.183)
		var char_completed: Array = completed.get(char_id, [])
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		card.add_child(hbox)

		var assign_lbl := Label.new()
		assign_lbl.text = "Assignment:"
		assign_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		hbox.add_child(assign_lbl)

		var option := OptionButton.new()
		option.add_item("None (Skip)", 0)
		# Track which JSON index maps to which dropdown item
		var _eligible_indices: Array = []
		for i in range(_assignments_data.size()):
			var assignment: Dictionary = _assignments_data[i]
			var a_id: String = assignment.get("id", "")
			var target: int = assignment.get("target_2d6", 99)

			# Check: already completed this assignment (once per career)
			if a_id in char_completed:
				continue

			# Check requirements
			if not _meets_requirements(mc, assignment):
				continue

			_eligible_indices.append(i)
			var suffix := ""
			# Show stat cap info if applicable
			if assignment.has("stat_cap"):
				var cap: Dictionary = assignment.stat_cap
				var current_val: int = mc.get(cap.get("stat", ""), 0)
				if current_val > cap.get("max_before_bonus", 99):
					suffix = " [at cap]"
			option.add_item("%s (2D6 >= %d)%s" % [assignment.get("name", "?"), target, suffix], i + 1)
		option.custom_minimum_size.x = 320
		hbox.add_child(option)

		if _eligible_indices.is_empty():
			var done_lbl := Label.new()
			done_lbl.text = "All eligible assignments completed!"
			done_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
			card.add_child(done_lbl)

		# Store reference for later
		_assignment_slots.append({
			"character_id": char_id,
			"character_name": char_name,
			"character_data": mc,
			"option_button": option,
			"assignment_id": "",
			"result": ""
		})


func _meets_requirements(char_data: Dictionary, assignment: Dictionary) -> bool:
	## Check if character meets assignment requirements (Compendium p.183).
	var reqs: Array = assignment.get("requirements", [])
	for req in reqs:
		if req is not Dictionary:
			continue
		var req_type: String = req.get("type", "")
		match req_type:
			"stat_min":
				# e.g. Commando: Reactions or Combat Skill >= 2
				var stat_val: int = char_data.get(req.get("stat", ""), 0)
				var needed: int = req.get("value", 99)
				var meets_primary: bool = stat_val >= needed
				# Check OR condition
				if not meets_primary and req.has("or_stat"):
					var or_val: int = char_data.get(req.get("or_stat", ""), 0)
					meets_primary = or_val >= req.get("or_value", needed)
				if not meets_primary:
					return false
			"completed_missions_min":
				var missions: int = char_data.get("completed_missions_count", 0)
				if missions < req.get("value", 99):
					return false
			"assignment_completed":
				# e.g. Officer Training requires Leadership Training
				var needed_id: String = req.get("assignment_id", "")
				var completed: Dictionary = {}
				if _campaign and "completed_assignments" in _campaign:
					completed = _campaign.completed_assignments
				var char_id: String = char_data.get("id", char_data.get("character_id", ""))
				var char_completed: Array = completed.get(char_id, [])
				if needed_id not in char_completed:
					return false
	return true


func _on_roll_all() -> void:
	for child in _results_container.get_children():
		child.queue_free()

	var total_rep_gain: int = 0

	for slot in _assignment_slots:
		var option: OptionButton = slot.get("option_button")
		if not is_instance_valid(option):
			continue

		var selected_idx: int = option.selected
		if selected_idx <= 0:
			slot.assignment_id = ""
			slot.result = "skipped"
			continue

		# Map dropdown selection back to assignment data via item ID
		var assignment_data_idx: int = option.get_item_id(selected_idx) - 1
		if assignment_data_idx < 0 or assignment_data_idx >= _assignments_data.size():
			continue

		var assignment: Dictionary = _assignments_data[assignment_data_idx]
		var target: int = assignment.get("target_2d6", 99)

		# Roll 2D6
		var die1: int = (randi() % 6) + 1
		var die2: int = (randi() % 6) + 1
		var total: int = die1 + die2
		var success: bool = total >= target

		slot.assignment_id = assignment.get("id", "")
		slot.result = "success" if success else "failure"

		var char_id: String = slot.character_id
		var char_data: Dictionary = slot.get("character_data", {})

		# Display result
		var result_card := _create_card(slot.character_name, _results_container)

		var roll_lbl := Label.new()
		roll_lbl.text = "%s — Rolled %d+%d=%d vs %d" % [
			assignment.get("name", "?"), die1, die2, total, target]
		roll_lbl.add_theme_color_override("font_color", COLOR_SUCCESS if success else COLOR_WARNING)
		result_card.add_child(roll_lbl)

		if success:
			var awards: Array = []

			# Apply stat bonuses (Compendium p.183)
			_apply_stat_awards(char_data, assignment, awards)

			# Apply bonus XP
			var bonus_xp: int = assignment.get("bonus_xp", 0)
			if bonus_xp > 0:
				char_data["xp"] = char_data.get("xp", 0) + bonus_xp
				awards.append("+%d XP" % bonus_xp)

			# Apply bonus reputation (accumulate for campaign)
			var bonus_rep: int = assignment.get("bonus_reputation", 0)
			if bonus_rep > 0:
				total_rep_gain += bonus_rep
				awards.append("+%d Reputation" % bonus_rep)

			# Track completion (once per career)
			if _campaign and "completed_assignments" in _campaign:
				if not _campaign.completed_assignments.has(char_id):
					_campaign.completed_assignments[char_id] = []
				_campaign.completed_assignments[char_id].append(slot.assignment_id)

			# Show awards
			var award_lbl := Label.new()
			award_lbl.text = "SUCCESS! Awards: %s" % ", ".join(awards) if not awards.is_empty() else "SUCCESS! (Training logged)"
			award_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
			award_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			result_card.add_child(award_lbl)

			# Show training award description
			var training: String = assignment.get("training_award", "")
			if not training.is_empty() and training != "None":
				var train_lbl := Label.new()
				train_lbl.text = training
				train_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
				train_lbl.add_theme_font_size_override("font_size", _scaled_font(13))
				result_card.add_child(train_lbl)
		else:
			var fail_lbl := Label.new()
			fail_lbl.text = "FAILED — Not accepted this turn. May retry next campaign turn."
			fail_lbl.add_theme_color_override("font_color", COLOR_WARNING)
			result_card.add_child(fail_lbl)

	# Apply accumulated reputation to campaign
	if total_rep_gain > 0 and _campaign and _campaign.has_method("add_reputation"):
		_campaign.add_reputation(total_rep_gain)

	# Auto-complete after rolling
	complete()


func _apply_stat_awards(char_data: Dictionary, assignment: Dictionary, awards: Array) -> void:
	## Apply stat bonuses from successful assignment (Compendium p.183).
	## Respects stat caps (e.g. "Combat Skill +1 if currently lower than 2").

	# Single stat cap
	if assignment.has("stat_cap"):
		var cap: Dictionary = assignment.stat_cap
		_apply_single_stat(char_data, cap, awards)

	# Multiple stat caps (e.g. Commando, Survival)
	if assignment.has("stat_caps"):
		var caps: Array = assignment.stat_caps
		for cap in caps:
			if cap is Dictionary:
				_apply_single_stat(char_data, cap, awards)


func _apply_single_stat(char_data: Dictionary, cap: Dictionary, awards: Array) -> void:
	var stat_name: String = cap.get("stat", "")
	var max_before: int = cap.get("max_before_bonus", 99)
	var bonus: int = cap.get("bonus", 1)

	if stat_name.is_empty():
		return

	var current: int = char_data.get(stat_name, 0)
	if current <= max_before:
		char_data[stat_name] = current + bonus
		awards.append("%s %d→%d" % [stat_name.capitalize().replace("_", " "), current, current + bonus])
	else:
		awards.append("%s already at cap (%d)" % [stat_name.capitalize().replace("_", " "), current])


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
	lbl.add_theme_font_size_override("font_size", _scaled_font(16))
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(lbl)

	return vbox
