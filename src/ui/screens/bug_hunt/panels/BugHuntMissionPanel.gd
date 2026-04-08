extends Control

## Bug Hunt Mission Panel — Turn Stage 2 of 3
## Generates mission parameters (Priority, contacts, objectives, loadout)
## and launches the battle through TacticalBattleUI.

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

const MISSIONS_PATH := "res://data/bug_hunt/bug_hunt_missions.json"
const SUPPORT_PATH := "res://data/bug_hunt/bug_hunt_support_teams.json"

var _campaign: Resource
var _phase_manager = null
var _missions_data: Dictionary = {}
var _support_data: Dictionary = {}
var _mission_generated: bool = false
var _mission_context: Dictionary = {}

var _briefing_container: VBoxContainer
var _loadout_container: VBoxContainer
var _support_container: VBoxContainer
var _launch_button: Button


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


func refresh() -> void:
	_mission_generated = false
	_mission_context.clear()
	_clear_containers()


func complete() -> void:
	if not _mission_generated:
		return
	# Mission completion — results come from battle
	var result := {"battle_result": _mission_context.get("battle_result", {})}
	phase_completed.emit(result)


func _load_data() -> void:
	_missions_data = _load_json(MISSIONS_PATH)
	_support_data = _load_json(SUPPORT_PATH)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		file.close()
		return json.data
	file.close()
	return {}


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	# Generate Mission button
	var gen_btn := Button.new()
	gen_btn.text = "Generate Mission"
	gen_btn.custom_minimum_size = Vector2(200, 48)
	gen_btn.pressed.connect(_generate_mission)
	vbox.add_child(gen_btn)

	# Mission briefing
	_briefing_container = VBoxContainer.new()
	_briefing_container.add_theme_constant_override("separation", 12)
	vbox.add_child(_briefing_container)

	# Loadout selection
	_loadout_container = VBoxContainer.new()
	_loadout_container.add_theme_constant_override("separation", 12)
	vbox.add_child(_loadout_container)

	# Support team results
	_support_container = VBoxContainer.new()
	_support_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_support_container)

	# Launch button
	_launch_button = Button.new()
	_launch_button.text = "Launch Mission"
	_launch_button.custom_minimum_size = Vector2(200, 48)
	_launch_button.pressed.connect(_launch_mission)
	_launch_button.visible = false
	vbox.add_child(_launch_button)


func _clear_containers() -> void:
	for c in [_briefing_container, _loadout_container, _support_container]:
		if c:
			for child in c.get_children():
				child.queue_free()
	if _launch_button:
		_launch_button.visible = false


func _generate_mission() -> void:
	if _mission_generated:
		return
	_mission_generated = true
	_clear_containers()

	var turn: int = 1
	if _campaign and "campaign_turn" in _campaign:
		turn = _campaign.campaign_turn
	var difficulty: String = "mess_me_up"
	if _campaign and "difficulty" in _campaign:
		difficulty = _campaign.difficulty
	var diff_settings: Dictionary = _get_difficulty_settings(difficulty)

	## ── Step 2: Determine and Place Objectives (Compendium p.185) ──────
	var objectives_data: Dictionary = _missions_data.get("objectives", {})
	var objective_types: Array = objectives_data.get("types", [])

	# Place 6 numbered dice, roll 3D6 to determine which stay
	var obj_roll1: int = (randi() % 6) + 1
	var obj_roll2: int = (randi() % 6) + 1
	var obj_roll3: int = (randi() % 6) + 1
	var obj_matches: Dictionary = {}  # die_value -> count
	for d in [obj_roll1, obj_roll2, obj_roll3]:
		obj_matches[d] = obj_matches.get(d, 0) + 1

	var active_objectives: Array = []
	var vital_objective: int = -1
	var critical_objective: int = -1
	for die_val in obj_matches:
		var count: int = obj_matches[die_val]
		# Roll D6 for objective type
		var obj_type_roll: int = (randi() % objective_types.size()) if objective_types.size() > 0 else 0
		var obj_type: Dictionary = objective_types[obj_type_roll] if obj_type_roll < objective_types.size() else {}
		var rating: String = "normal"
		if count == 3:
			critical_objective = die_val
			rating = "critical"
		elif count == 2:
			vital_objective = die_val
			rating = "vital"
		active_objectives.append({
			"die_value": die_val,
			"type": obj_type,
			"rating": rating
		})

	var objective_count: int = active_objectives.size()

	## ── Step 3: Difficulty (already selected at campaign creation) ──────

	## ── Step 4: Determine Priority (Compendium p.187) ──────
	var priority: int = _calculate_priority(turn, difficulty)
	# Vital/Critical modifiers
	if critical_objective >= 0:
		priority += 2
	elif vital_objective >= 0:
		priority += 1
	priority = clampi(priority, 1, 6)

	## ── Step 5: Spawn Rating ──────
	var spawn_rating: int = clampi(priority - 1, 0, 3)

	## ── Contact markers (Compendium p.190) ──────
	# 1 per objective + 1 in center
	var base_contacts: int = objective_count + 1
	# Difficulty adjustments
	var contact_mod: int = diff_settings.get("initial_contacts_modifier", 0)
	# Extra from operational progress
	var extra: int = 0
	if _campaign and "extra_contact_markers" in _campaign:
		extra = _campaign.extra_contact_markers
	var total_contacts: int = maxi(base_contacts + contact_mod + extra, 1)

	# Build mission context
	_mission_context = {
		"priority": priority,
		"spawn_rating": spawn_rating,
		"objectives": active_objectives,
		"objective_count": objective_count,
		"has_vital": vital_objective >= 0,
		"has_critical": critical_objective >= 0,
		"contact_markers": total_contacts,
		"difficulty": difficulty,
		"turn": turn,
		"battle_result": {}
	}

	## ── Display Briefing ──────
	var briefing_card := _create_card("Mission Briefing", _briefing_container)

	# Objective dice roll display
	var obj_text := "Objective dice: [%d, %d, %d] → %d objective(s)" % [
		obj_roll1, obj_roll2, obj_roll3, objective_count]
	if critical_objective >= 0:
		obj_text += " (CRITICAL — counts as 3!)"
	elif vital_objective >= 0:
		obj_text += " (Vital — counts as 2)"
	_add_row(briefing_card, "Objectives", obj_text)

	for obj in active_objectives:
		var obj_type: Dictionary = obj.get("type", {})
		var rating_tag: String = ""
		if obj.rating == "vital":
			rating_tag = " [VITAL]"
		elif obj.rating == "critical":
			rating_tag = " [CRITICAL]"
		_add_row(briefing_card, "  #%d%s" % [obj.die_value, rating_tag],
			"%s — %s" % [obj_type.get("name", "Patrol"), obj_type.get("achieved_when", "")])

	_add_row(briefing_card, "Priority", str(priority))
	_add_row(briefing_card, "Spawn Rating", str(spawn_rating))
	_add_row(briefing_card, "Contact Markers", str(total_contacts))
	_add_row(briefing_card, "Difficulty", difficulty.replace("_", " ").capitalize())

	## ── Signals Optional Rule (Compendium p.208) ──────
	var signals_card := _create_card("Signals (Optional Rule)", _briefing_container)
	var signals_check := CheckBox.new()
	signals_check.text = "Use Signals rule this mission"
	signals_check.tooltip_text = "Adds 1D6 Signal markers (survivors, evidence, ambushes). Reduces Tactical Locations to compensate."
	signals_check.add_theme_color_override("font_color", COLOR_TEXT)
	signals_check.toggled.connect(func(pressed: bool):
		_mission_context["use_signals"] = pressed
	)
	signals_card.add_child(signals_check)
	var signals_note := Label.new()
	signals_note.text = "If 4+ Signals: must investigate at least 2 or lose 1 Objective."
	signals_note.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	signals_note.add_theme_font_size_override("font_size", _scaled_font(12))
	signals_card.add_child(signals_note)

	## ── Step 6: Loadout Selection (Compendium p.187) ──────
	_build_loadout_selection()

	## ── Step 7: Support Teams (Compendium pp.188-189) ──────
	_roll_support_teams(priority)

	_launch_button.visible = true


func _build_loadout_selection() -> void:
	## Per-character weapon choice (Compendium p.187)
	var loadout_card := _create_card("Step 6: Select Loadouts", _loadout_container)

	if not _campaign or not "main_characters" in _campaign:
		return

	var sick_bay: Dictionary = _campaign.sick_bay if "sick_bay" in _campaign else {}
	var hand_cannon_assigned := false

	for mc in _campaign.main_characters:
		if mc is not Dictionary:
			continue
		var char_id: String = mc.get("id", mc.get("character_id", ""))
		var char_name: String = mc.get("name", mc.get("character_name", "Unknown"))

		if sick_bay.has(char_id):
			continue

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		loadout_card.add_child(hbox)

		var name_lbl := Label.new()
		name_lbl.text = char_name + ":"
		name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		name_lbl.custom_minimum_size.x = 140
		hbox.add_child(name_lbl)

		# Mission weapon choice
		var weapon_opt := OptionButton.new()
		weapon_opt.add_item("Combat Rifle (26\" | 1 Shot | Dmg 0)")
		weapon_opt.add_item("Shotgun (12\" | 2 Shots | Dmg 1 | Focused)")
		weapon_opt.add_item("Boarding Sword (Melee | +2 Brawl)")
		weapon_opt.custom_minimum_size.x = 280
		hbox.add_child(weapon_opt)

		# Hand Cannon swap (only 1 MC)
		var hc_check := CheckBox.new()
		hc_check.text = "Hand Cannon swap"
		hc_check.tooltip_text = "Swap Service Pistol for Hand Cannon (8\" | 1 Shot | Dmg 1). One MC only."
		var hc_ref := hc_check
		hc_check.toggled.connect(func(pressed: bool):
			if pressed and hand_cannon_assigned:
				hc_ref.button_pressed = false
				return
			hand_cannon_assigned = pressed
		)
		hbox.add_child(hc_check)


func _calculate_priority(turn: int, difficulty: String) -> int:
	# Campaign escalation check
	var use_escalation: bool = false
	if _campaign and "use_campaign_escalation" in _campaign:
		use_escalation = _campaign.use_campaign_escalation

	if use_escalation:
		# Fixed Priority sequence from missions JSON
		var escalation: Dictionary = _missions_data.get("campaign_escalation", {})
		var sequence: Array = escalation.get("priority_sequence", [])
		var idx: int = (turn - 1) % sequence.size() if sequence.size() > 0 else 0
		return sequence[idx] if idx < sequence.size() else 3

	# Standard: Roll 2D6 pick the lower die (Compendium p.187)
	# Vital/Critical modifiers applied by caller after objective generation.
	var die1: int = (randi() % 6) + 1
	var die2: int = (randi() % 6) + 1
	var base_priority: int = mini(die1, die2)
	return clampi(base_priority, 1, 6)


func _get_difficulty_settings(difficulty: String) -> Dictionary:
	var settings: Array = _missions_data.get("difficulty_settings", [])
	for s in settings:
		if s is Dictionary and s.get("id", "") == difficulty:
			return s
	return {}


var _support_points_remaining: int = 0
var _support_results_box: VBoxContainer


func _roll_support_teams(priority: int) -> void:
	## Step 7: Force Strength (Compendium pp.187-189)
	## Support points = Priority. +2 for "I'm Too Pretty". 1 Rep = +1 Support.
	## Each point grants one 2D6 roll against a support type.
	var support_options: Array = _support_data.get("support_options", [])
	if support_options.is_empty():
		return

	var support_card := _create_card("Step 7: Force Strength", _support_container)

	# Free fire team (always provided)
	var free_lbl := Label.new()
	free_lbl.text = "FREE: Fire Team — 4 Grunts with Combat Rifles (always included)"
	free_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
	support_card.add_child(free_lbl)

	# Calculate support points
	var bonus: int = 0
	var difficulty: String = _mission_context.get("difficulty", "mess_me_up")
	if difficulty == "im_too_pretty_to_die":
		bonus = 2
	_support_points_remaining = priority + bonus

	var points_lbl := Label.new()
	points_lbl.text = "Support Points: %d (Priority %d + difficulty bonus %d)" % [
		_support_points_remaining, priority, bonus]
	points_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	support_card.add_child(points_lbl)

	var rep_note := Label.new()
	rep_note.text = "Spend 1 Reputation for +1 Support Point. Each option can only be requested once."
	rep_note.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	rep_note.add_theme_font_size_override("font_size", _scaled_font(13))
	rep_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	support_card.add_child(rep_note)

	# Interactive support request buttons
	for opt in support_options:
		if opt is not Dictionary:
			continue
		var target: int = opt.get("target_2d6", 99)
		var opt_name: String = opt.get("name", "?")
		var contents: String = opt.get("contents", "")

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		support_card.add_child(hbox)

		var request_btn := Button.new()
		request_btn.text = "Request"
		request_btn.custom_minimum_size = Vector2(90, 36)

		var desc_lbl := Label.new()
		desc_lbl.text = "%s (2D6 >= %d) — %s" % [opt_name, target, contents]
		desc_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		desc_lbl.add_theme_font_size_override("font_size", _scaled_font(13))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var opt_ref: Dictionary = opt
		var btn_ref: Button = request_btn
		var desc_ref := desc_lbl
		request_btn.pressed.connect(func():
			if _support_points_remaining <= 0:
				desc_ref.text = "No Support Points remaining!"
				desc_ref.add_theme_color_override("font_color", COLOR_WARNING)
				return
			_support_points_remaining -= 1
			var d1: int = (randi() % 6) + 1
			var d2: int = (randi() % 6) + 1
			var total: int = d1 + d2
			var tgt: int = opt_ref.get("target_2d6", 99)
			btn_ref.disabled = true
			if total >= tgt:
				desc_ref.text = "%s — Rolled %d+%d=%d vs %d — APPROVED! %s" % [
					opt_ref.get("name", "?"), d1, d2, total, tgt, opt_ref.get("contents", "")]
				desc_ref.add_theme_color_override("font_color", COLOR_SUCCESS)
			else:
				desc_ref.text = "%s — Rolled %d+%d=%d vs %d — Denied. Support unavailable." % [
					opt_ref.get("name", "?"), d1, d2, total, tgt]
				desc_ref.add_theme_color_override("font_color", COLOR_WARNING)
		)
		hbox.add_child(request_btn)
		hbox.add_child(desc_lbl)


func _launch_mission() -> void:
	# Generate battle context using BugHuntBattleSetup
	var BugHuntBattleSetupClass = load("res://src/core/battle/BugHuntBattleSetup.gd")
	if not BugHuntBattleSetupClass:
		push_warning("BugHuntMissionPanel: Cannot load BugHuntBattleSetup")
		_mission_context.battle_result = {
			"completed": true, "objectives_completed": 1, "casualties": []
		}
		complete()
		return

	var battle_setup = BugHuntBattleSetupClass.new()
	var battle_context: Dictionary = battle_setup.generate_battle_context(
		_mission_context, _campaign)

	# Store battle + mission context for TacticalBattleUI to pick up
	var gs_mgr = get_node_or_null("/root/GameStateManager")
	if gs_mgr and gs_mgr.has_method("set_temp_data"):
		gs_mgr.set_temp_data("bug_hunt_battle_context", battle_context)
		gs_mgr.set_temp_data("bug_hunt_mission", _mission_context)

	# Navigate to TacticalBattleUI — do NOT complete() here;
	# the turn controller will handle completion on return from battle
	var router = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("tactical_battle")
	else:
		push_warning("BugHuntMissionPanel: SceneRouter not available")
		_mission_context.battle_result = {
			"completed": true, "objectives_completed": 1, "casualties": []
		}
		complete()


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


func _add_row(parent: VBoxContainer, label_text: String, value_text: String) -> void:
	var hbox := HBoxContainer.new()
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text + ":"
	lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	lbl.custom_minimum_size.x = 160
	hbox.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_color_override("font_color", COLOR_TEXT)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(val)
