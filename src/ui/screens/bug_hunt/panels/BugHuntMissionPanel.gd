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
const WEAPONS_PATH := "res://data/bug_hunt/bug_hunt_weapons.json"

var _campaign: Resource
var _phase_manager = null
var _missions_data: Dictionary = {}
var _support_data: Dictionary = {}
var _mission_generated: bool = false
var _mission_context: Dictionary = {}

## Derived during generation and read by the stamp in _launch_mission().
## They are members rather than return values because _calculate_priority()
## has one call site and three callers' worth of meaning: the priority itself,
## whether the escalation option supplied it, and which step of the sequence.
var _escalation_step: int = -1  # -1 = the escalation option is not in use
var _participant_ids: Array = []  # main characters who take the field (p.203)

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
	_signals_roll = 0  # a new mission rolls its own Signals (p.208)
	_rep_priority_shift = 0
	_rep_for_support = 0
	_support_requests_made = 0
	_support_buttons.clear()
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
	for w in _load_json(WEAPONS_PATH).get("weapons", []):
		if w is Dictionary:
			_weapons_by_id[str(w.get("id", ""))] = w


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
	gen_btn.custom_minimum_size = Vector2(0, 48)
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
	_launch_button.custom_minimum_size = Vector2(0, 48)
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
	var obj_roll1: int = _roll_d6("Bug Hunt Objective: die 1")
	var obj_roll2: int = _roll_d6("Bug Hunt Objective: die 2")
	var obj_roll3: int = _roll_d6("Bug Hunt Objective: die 3")
	var obj_matches: Dictionary = {}  # die_value -> count
	for d in [obj_roll1, obj_roll2, obj_roll3]:
		obj_matches[d] = obj_matches.get(d, 0) + 1

	var active_objectives: Array = []
	var vital_objective: int = -1
	var critical_objective: int = -1
	for die_val in obj_matches:
		var count: int = obj_matches[die_val]
		# Roll D6 for objective type (Compendium p.185).
		#
		# The roll is matched against each entry's own `d6_value`, NOT against its
		# position in the array. This was `randi() % objective_types.size()`, which
		# agreed with the data only by the coincidence that the six types happen to
		# be stored in d6_value order: reorder them, or add a seventh, and the "D6"
		# in the comment silently stops being one. The sibling reader of this same
		# table shape, BugHuntBattleSetup.gd:126-138, already matches on d6_value —
		# two readers of one shape must read it the same way.
		var obj_type_roll: int = _roll_d6("Bug Hunt Objective: type")
		var obj_type: Dictionary = _find_by_d6_value(objective_types, obj_type_roll)
		var rating: String = "normal"
		if count == 3:
			critical_objective = die_val
			rating = "critical"
		elif count == 2:
			vital_objective = die_val
			rating = "vital"
		# The WEIGHT travels with the objective (Compendium pp.185, 201: a Vital
		# Objective counts as 2, a Critical as 3). Read from data, never a literal
		# here -- the briefing below prints it and the post-battle scorer sums it,
		# and a mechanic's numbers living in a UI literal is how the two drift.
		active_objectives.append({
			"die_value": die_val,
			"type": obj_type,
			"rating": rating,
			"weight": _objective_weight(rating)
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
	# p.206 "Friend in the Intel Corps": "Modify Priority of next mission by +/- 1",
	# the sign being the player's pick, banked by the post-battle step.
	var military_life: int = _campaign.military_life_flag_total("priority_modifier") \
		if _campaign and _campaign.has_method("military_life_flag_total") else 0
	priority += military_life
	# p.187: "Regardless of points spent or modifiers, Priority cannot be reduced below
	# 1 or raised above 6." The clamp comes LAST, so the unclamped value is kept for
	# the Reputation adjustment (MG-1) to start from.
	_base_priority = priority
	_rep_priority_shift = 0
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

	# Build mission context.
	#
	# THE STAMP. Everything the post-battle sequence needs to know about this
	# scenario is written here, BEFORE the battle, and read back through
	# BugHuntBattleResultNormalizer -- the 5PFH foundation (see CLAUDE.md, "the
	# battle-phase data funnel"). The battle screen cannot report Bug Hunt
	# objectives: they are dice on the physical table, not a tracked objective,
	# so the player declares them at the debrief and the stamp is what the
	# declaration is scored AGAINST.
	_mission_context = {
		"priority": priority,
		"spawn_rating": spawn_rating,
		"military_life_priority": military_life,
		"escalation_step": _escalation_step,
		"objectives": active_objectives,
		"objective_count": objective_count,
		"has_vital": vital_objective >= 0,
		"has_critical": critical_objective >= 0,
		"contact_markers": total_contacts,
		"difficulty": difficulty,
		# The p.186 row in force travels with the mission, like `scoring` below, so the
		# battle applies the same Numbers adjustment (p.194) the briefing was built from.
		"difficulty_rules": diff_settings.duplicate(true),
		"turn": turn,
		# The thresholds IN FORCE for this mission travel with it, so the debrief
		# scores against what the player was briefed with rather than against
		# whatever the data file says by the time they get back.
		"scoring": _missions_data.get("objectives", {}).get("scoring", {}).duplicate(true),
		"use_signals": false,
		"signals_total": 0,
		"participant_ids": [],
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

	_priority_lbl = _add_row(briefing_card, "Priority", str(priority))
	if military_life != 0:
		_add_row(briefing_card, "Military Life", "%+d Priority, a friend in the Intel Corps (p.206)"
			% military_life)
	_spawn_lbl = _add_row(briefing_card, "Spawn Rating", str(spawn_rating))
	_build_priority_control(briefing_card)
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
		# Roll the count HERE so the stamp carries it. BugHuntBattleSetup used to
		# roll its own 1D6 at launch and keep the number to itself, so the p.201
		# rule ("4 or more signals initially ... investigate at least 2") had no
		# initial count to test against after the battle.
		# ⚠ ONCE per mission (MG-10). It used to re-roll on every toggle, so turning
		# the rule off and on again re-rolled the p.208 1D6 until it suited.
		if pressed:
			if _signals_roll <= 0:
				_signals_roll = _roll_d6("Bug Hunt Signals: count")
			_mission_context["signals_total"] = _signals_roll
		else:
			_mission_context["signals_total"] = 0
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
	_roll_support_teams()

	_launch_button.visible = true


func _build_loadout_selection() -> void:
	## Per-character weapon choice (Compendium p.187)
	var loadout_card := _create_card("Step 6: Select Loadouts", _loadout_container)

	if not _campaign or not "main_characters" in _campaign:
		return

	var sick_bay: Dictionary = _campaign.sick_bay if "sick_bay" in _campaign else {}
	# A HOLDER, not a bool. GDScript lambdas capture a local by VALUE, so each
	# checkbox's `toggled` closure got its own copy of `hand_cannon_assigned`,
	# frozen false at capture time -- the p.187 "one main character may opt to
	# swap" limit could never bind, and every marine could take the Hand Cannon.
	# A Dictionary is a reference, so all the closures share one fact.
	var hand_cannon := {"assigned": false}
	_participant_ids.clear()
	_mission_context["loadout"] = {}

	for mc in _campaign.main_characters:
		if mc is not Dictionary:
			continue
		var char_id: String = mc.get("id", mc.get("character_id", ""))
		var char_name: String = mc.get("name", mc.get("character_name", "Unknown"))

		if sick_bay.has(char_id):
			continue
		# p.206 "Time in the Brig" / "Detached on special duties": misses this mission.
		if _campaign.has_method("military_life_flag") \
				and _campaign.military_life_flag(char_id, "miss_next_mission") > 0:
			var held := Label.new()
			held.text = "%s misses this mission (Military Life, Compendium p.206)." % char_name
			held.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			held.add_theme_color_override("font_color", COLOR_WARNING)
			loadout_card.add_child(held)
			continue
		# Took the field. p.203: "Update this number by 1 if the character took
		# the field. Characters in Sick Bay do not update their tally." This is
		# the population the tally and the muster-out check are owed, so it is
		# stamped rather than re-derived after the battle from a roster that the
		# battle may already have changed.
		if char_id != "" and char_id not in _participant_ids:
			_participant_ids.append(char_id)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		loadout_card.add_child(hbox)

		var name_lbl := Label.new()
		name_lbl.text = char_name + ":"
		name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		name_lbl.custom_minimum_size.x = 140
		hbox.add_child(name_lbl)

		# Mission weapon choice (p.187), read from data. ⚠ These were three string
		# literals carrying their own stats, and the choice was never stamped, so the
		# battle never knew which weapon anyone carried (MG-9).
		var choices: Array = _loadout_choices()
		var loadout: Dictionary = _mission_context.get("loadout", {})
		loadout[char_id] = {"name": char_name,
			"weapon": str(choices[0]) if not choices.is_empty() else "", "hand_cannon": false}
		_mission_context["loadout"] = loadout
		var weapon_opt := OptionButton.new()
		for wid in choices:
			weapon_opt.add_item(_weapon_label(str(wid)))
		weapon_opt.custom_minimum_size.x = 280
		var entry_ref: Dictionary = loadout[char_id]
		weapon_opt.item_selected.connect(func(idx: int) -> void:
			if idx >= 0 and idx < choices.size():
				entry_ref["weapon"] = str(choices[idx])
		)
		hbox.add_child(weapon_opt)

		# Hand Cannon swap (only 1 MC)
		var hc_check := CheckBox.new()
		hc_check.text = "Hand Cannon swap"
		hc_check.tooltip_text = "Swap the Service Pistol for a %s. One main character only." \
			% _weapon_label("hand_cannon")
		var hc_ref := hc_check
		var hc_holder := hand_cannon
		hc_check.toggled.connect(func(pressed: bool):
			if pressed and hc_holder["assigned"]:
				# set_pressed_no_signal, never button_pressed: the latter re-enters
				# this same handler with pressed == false, which would clear the
				# holder and hand the swap to the second marine who asked for it.
				hc_ref.set_pressed_no_signal(false)
				return
			hc_holder["assigned"] = pressed
			entry_ref["hand_cannon"] = pressed
		)
		hbox.add_child(hc_check)


func _calculate_priority(turn: int, difficulty: String) -> int:
	# Campaign escalation check
	var use_escalation: bool = false
	if _campaign and "use_campaign_escalation" in _campaign:
		use_escalation = _campaign.use_campaign_escalation

	_escalation_step = -1
	if use_escalation:
		# Fixed Priority sequence from missions JSON (Compendium p.187).
		#
		# The key is `campaign_escalation_option`. This read was
		# `campaign_escalation`, which the file does not declare -- so the
		# sequence came back EMPTY, `idx` resolved to 0, and the function
		# returned the hardcoded 3 below on every turn. A player who enabled
		# escalation got a flat Priority 3 campaign, not the book's ramp.
		var escalation: Dictionary = _missions_data.get("campaign_escalation_option", {})
		var sequence: Array = escalation.get("priority_sequence", [])
		if sequence.size() > 0:
			# p.187 prints eight ratings and says nothing of mission 9. The option's own
			# purpose is a campaign that "slowly escalates", so the last rating HOLDS;
			# this was `% size`, which dropped mission 9 back to Priority 1 (MG-13). The
			# clamp also keeps a turn of 0 off index -1, which GDScript reads as the LAST
			# element and would have opened the campaign at Priority 6.
			var idx: int = clampi(turn - 1, 0, sequence.size() - 1)
			_escalation_step = idx
			return int(sequence[idx])
		push_warning("BugHuntMissionPanel: campaign escalation is on but the data has no priority_sequence; rolling instead.")

	# Standard: Roll 2D6 pick the lower die (Compendium p.187)
	# Vital/Critical modifiers applied by caller after objective generation.
	# Two separate D6 rolls, never roll_2d6(): that returns the SUM, and p.187
	# asks for the LOWER of the two dice, which a sum cannot yield.
	var die1: int = _roll_d6("Bug Hunt Priority: die 1")
	var die2: int = _roll_d6("Bug Hunt Priority: die 2")
	var base_priority: int = mini(die1, die2)
	return clampi(base_priority, 1, 6)


func _objective_weight(rating: String) -> int:
	## Compendium pp.185, 201 -- read from data.objectives.scoring.weights.
	## Falls back to 1 (a normal Objective) rather than 0: an unknown rating must
	## still count as the Objective it is, and a 0 here would silently re-create
	## the "no mission ever scores" defect this stamp exists to fix.
	var scoring: Dictionary = _missions_data.get("objectives", {}).get("scoring", {})
	var weights: Dictionary = scoring.get("weights", {})
	return int(weights.get(rating, 1))


func _persist_stamped_mission() -> void:
	## The stamp has to survive a process death between launch and debrief, so it
	## lives on the campaign, not only in temp_data. `current_mission` is already
	## a serialized top-level field on BugHuntCampaignCore.
	##
	## Do NOT add get_current_mission/set_current_mission to the core to tidy this
	## up: GameState.gd duck-types on those names to decide what a campaign IS.
	if _campaign == null or not ("current_mission" in _campaign):
		return
	_campaign.current_mission = _mission_context.duplicate(true)
	if _campaign.has_method("persist"):
		_campaign.persist()


func _report_launch_failure(reason: String) -> void:
	## A battle that could not start is a failure, not a victory. Tell the player
	## and leave the phase incomplete so they can retry -- the mission is still
	## generated, and the Launch button is still there.
	push_warning("BugHuntMissionPanel: %s" % reason)
	## `show_notification` DOES NOT EXIST -- `func show_notification` has zero
	## definitions repo-wide, so a guard on it is permanently false and the
	## player is told nothing. The real API is show_info / show_success /
	## show_warning / show_error / show_toast (NotificationManager.gd:105-131).
	var nm := get_node_or_null("/root/NotificationManager")
	if nm and nm.has_method("show_error"):
		nm.show_error("Could not start the mission: %s" % reason)


func _get_difficulty_settings(difficulty: String) -> Dictionary:
	var settings: Array = _missions_data.get("difficulty_settings", [])
	for s in settings:
		if s is Dictionary and s.get("id", "") == difficulty:
			return s
	return {}


## The p.208 Signals 1D6, rolled the first time the rule is switched on (MG-10).
var _signals_roll: int = 0
## p.187 Reputation spending. Committed here, spent once at launch.
const MAX_PRIORITY_REPUTATION := 2
var _base_priority: int = 1
var _rep_priority_shift: int = 0
var _rep_for_support: int = 0
var _support_requests_made: int = 0
var _support_buttons: Array[Button] = []
var _priority_lbl: Label
var _spawn_lbl: Label
var _prio_down_btn: Button
var _prio_up_btn: Button
var _buy_support_btn: Button
var _support_points_lbl: Label
var _extra_support_check: CheckBox
var _weapons_by_id: Dictionary = {}
var _support_results_box: VBoxContainer


func _roll_support_teams() -> void:
	## Step 7: Force Strength (Compendium pp.187-189)
	## Each Support point grants one 2D6 roll against a support type. The points are
	## computed by _support_points_total() from the STAMPED Priority, never passed in,
	## because the Step 4 Reputation control can still move Priority after this card
	## is built.
	var support_options: Array = _support_data.get("support_options", [])
	if support_options.is_empty():
		return

	var support_card := _create_card("Step 7: Force Strength", _support_container)
	_support_requests_made = 0
	_rep_for_support = 0
	_support_buttons.clear()
	_mission_context["support"] = []

	# Free fire team (always provided). The text is the data's, and the team is the
	# Support table's own Fire Team row, so the label cannot disagree with either.
	var free_lbl := Label.new()
	free_lbl.text = "FREE: %s %s" % [str(_support_data.get("free_fire_team", "")),
		_fire_team_contents()]
	free_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	free_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
	support_card.add_child(free_lbl)

	_support_points_lbl = Label.new()
	_support_points_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_support_points_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	support_card.add_child(_support_points_lbl)

	# p.187: "1 point of Reputation may be spent to gain +1 Support." ⚠ This used to be a
	# label only, with nothing to press (MG-2).
	_buy_support_btn = Button.new()
	_buy_support_btn.text = "Spend 1 Reputation: +1 Support Point"
	_buy_support_btn.custom_minimum_size.y = 44
	_buy_support_btn.pressed.connect(_on_buy_support_point)
	support_card.add_child(_buy_support_btn)

	# p.181 Movie Magic "Extra Support": "The first Support option you request does not
	# require a die roll." Once per campaign; spent when that request is made.
	_extra_support_check = null
	if _campaign and _campaign.has_method("is_movie_magic_available") \
			and _campaign.is_movie_magic_available("extra_support"):
		_extra_support_check = CheckBox.new()
		_extra_support_check.text = "Movie Magic, Extra Support: the first request needs " \
			+ "no roll. Once per campaign (p.181)."
		_extra_support_check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		support_card.add_child(_extra_support_check)

	var rep_note := Label.new()
	rep_note.text = "%s Each option can only be requested once, and each request is " \
		% str(_support_data.get("support_points_rule", "")) \
		+ "rolled before the next is chosen (p.187)."
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
		_support_buttons.append(request_btn)
		request_btn.pressed.connect(func():
			if _support_points_remaining() <= 0:
				desc_ref.text = "No Support Points remaining!"
				desc_ref.add_theme_color_override("font_color", COLOR_WARNING)
				return
			var free: bool = _support_requests_made == 0 and _extra_support_check != null \
				and _extra_support_check.button_pressed
			_support_requests_made += 1
			var support_name: String = str(opt_ref.get("name", "?"))
			var d1: int = 0
			var d2: int = 0
			if free:
				_campaign.use_movie_magic("extra_support")
			else:
				d1 = _roll_d6("Bug Hunt Support die 1: %s" % support_name)
				d2 = _roll_d6("Bug Hunt Support die 2: %s" % support_name)
			if _extra_support_check:
				_extra_support_check.disabled = true
			var total: int = d1 + d2
			var tgt: int = opt_ref.get("target_2d6", 99)
			btn_ref.disabled = true
			btn_ref.set_meta("requested", true)
			# The battle needs to know what arrived (MG-8). ⚠ The result used to live only
			# in this label, so approved support never reached the battle.
			(_mission_context["support"] as Array).append({
				"id": str(opt_ref.get("id", "")), "name": support_name,
				"contents": str(opt_ref.get("contents", "")),
				"notes": str(opt_ref.get("notes", "")),
				"roll": total, "target": tgt, "approved": free or total >= tgt,
				"movie_magic": free})
			_refresh_support_controls()
			if free:
				desc_ref.text = "%s — Movie Magic, no roll — APPROVED! %s" % [
					support_name, opt_ref.get("contents", "")]
				desc_ref.add_theme_color_override("font_color", COLOR_SUCCESS)
			elif total >= tgt:
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
	_refresh_support_controls()


# ── Step 4 / Step 7 Reputation spending (Compendium p.187) ───────────────────────

## "You may spend up to 2 points of Reputation, with each point raising or lowering
## the Priority Rating by 1." Priority sets the Spawn Rating and the Support points,
## so it is locked once a Support request has been rolled.
func _build_priority_control(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	_prio_down_btn = Button.new()
	_prio_down_btn.text = "Priority -1 (1 Reputation)"
	_prio_down_btn.custom_minimum_size.y = 44
	_prio_down_btn.pressed.connect(_on_shift_priority.bind(-1))
	row.add_child(_prio_down_btn)
	_prio_up_btn = Button.new()
	_prio_up_btn.text = "Priority +1 (1 Reputation)"
	_prio_up_btn.custom_minimum_size.y = 44
	_prio_up_btn.pressed.connect(_on_shift_priority.bind(1))
	row.add_child(_prio_up_btn)


func _on_shift_priority(delta: int) -> void:
	var shifted: int = _rep_priority_shift + delta
	if absi(shifted) > MAX_PRIORITY_REPUTATION or _support_requests_made > 0:
		return
	if absi(shifted) > absi(_rep_priority_shift) and _reputation_available() <= 0:
		return
	_rep_priority_shift = shifted
	var priority: int = clampi(_base_priority + _rep_priority_shift, 1, 6)
	_mission_context["priority"] = priority
	_mission_context["spawn_rating"] = clampi(priority - 1, 0, 3)  # p.187 Step 5
	_mission_context["priority_reputation_shift"] = _rep_priority_shift
	if _priority_lbl:
		_priority_lbl.text = str(priority) if _rep_priority_shift == 0 \
			else "%d (%+d for %d Reputation)" % [priority, _rep_priority_shift,
				absi(_rep_priority_shift)]
	if _spawn_lbl:
		_spawn_lbl.text = str(_mission_context["spawn_rating"])
	_refresh_support_controls()


func _on_buy_support_point() -> void:
	if _reputation_available() <= 0:
		return
	_rep_for_support += 1
	_refresh_support_controls()


## Reputation not yet committed to a Priority shift or a Support point. Nothing is
## SPENT until launch (_spend_committed_reputation), so backing out costs nothing.
func _reputation_available() -> int:
	var held: int = int(_campaign.reputation) if _campaign and "reputation" in _campaign else 0
	return held - absi(_rep_priority_shift) - _rep_for_support


## p.187: Support points = Priority, +2 on I'm too pretty to die (the difficulty row's
## extra_support_points), +1 per Reputation spent, plus p.205's permanent "+1 Support
## roll in future missions" (campaign.extra_support_rolls). ⚠ The difficulty bonus was
## a literal and the last two were never added (MG-3, MG-4).
func _support_points_total() -> int:
	var rules: Dictionary = _mission_context.get("difficulty_rules", {})
	var permanent: int = int(_campaign.extra_support_rolls) \
		if _campaign and "extra_support_rolls" in _campaign else 0
	return int(_mission_context.get("priority", 1)) + int(rules.get("extra_support_points", 0)) \
		+ permanent + _rep_for_support


func _support_points_remaining() -> int:
	return _support_points_total() - _support_requests_made


## One place decides what is pressable. ⚠ Every request button stayed enabled with no
## points left (MG-11, "12 requests enabled vs 1 point" on the tablet).
func _refresh_support_controls() -> void:
	var remaining: int = _support_points_remaining()
	for b in _support_buttons:
		if is_instance_valid(b):
			b.disabled = remaining <= 0 or bool(b.get_meta("requested", false))
	var locked: bool = _support_requests_made > 0
	if _prio_down_btn:
		_prio_down_btn.disabled = locked or _rep_priority_shift <= -MAX_PRIORITY_REPUTATION \
			or (_rep_priority_shift <= 0 and _reputation_available() <= 0)
	if _prio_up_btn:
		_prio_up_btn.disabled = locked or _rep_priority_shift >= MAX_PRIORITY_REPUTATION \
			or (_rep_priority_shift >= 0 and _reputation_available() <= 0)
	if _buy_support_btn:
		_buy_support_btn.disabled = _reputation_available() <= 0
	if _support_points_lbl:
		_support_points_lbl.text = "Support Points: %d left of %d (Priority %d, difficulty " \
			% [remaining, _support_points_total(), int(_mission_context.get("priority", 1))] \
			+ "%+d, campaign %+d, Reputation %+d)" % [
				int((_mission_context.get("difficulty_rules", {}) as Dictionary).get(
					"extra_support_points", 0)),
				int(_campaign.extra_support_rolls) if _campaign
					and "extra_support_rolls" in _campaign else 0,
				_rep_for_support]
	_mission_context["support_reputation_spent"] = _rep_for_support


## Spend what was committed, ONCE: a launch that fails can be retried, and a second
## press must not charge again.
func _spend_committed_reputation() -> void:
	if bool(_mission_context.get("reputation_spent", false)):
		return
	var cost: int = absi(_rep_priority_shift) + _rep_for_support
	if cost > 0 and _campaign and _campaign.has_method("spend_reputation"):
		_campaign.spend_reputation(mini(cost, int(_campaign.reputation)))
	_mission_context["reputation_spent"] = true


## p.187: the loadout is "for the duration of the mission", so it goes on the battle's
## COPY of each character (the caller passes duplicates), never on the campaign roster.
func _apply_loadout(crew: Array) -> void:
	var loadout: Dictionary = _mission_context.get("loadout", {})
	for member in crew:
		if member is not Dictionary:
			continue
		# Same key fallback as the stamp in _build_loadout_selection().
		var pick: Dictionary = loadout.get(
			str(member.get("id", member.get("character_id", ""))), {})
		if pick.is_empty():
			continue
		var gear: Array = (member.get("equipment", []) as Array).duplicate()
		if bool(pick.get("hand_cannon", false)) and gear.has("service_pistol"):
			gear[gear.find("service_pistol")] = "hand_cannon"
		if str(pick.get("weapon", "")) != "":
			gear.append(str(pick.weapon))
		member["equipment"] = gear
		member["mission_weapon"] = str(pick.get("weapon", ""))


## p.206 results that land on THIS mission are spent by launching it, exactly once.
## "Miss the next mission" is spent for everyone who carried it, Sick Bay included:
## a mission was flown and they were not on it.
func _spend_military_life_flags() -> void:
	if bool(_mission_context.get("military_life_spent", false)) or not _campaign \
			or not _campaign.has_method("consume_military_life_flag_everywhere"):
		return
	_campaign.consume_military_life_flag_everywhere("miss_next_mission")
	_campaign.consume_military_life_flag_everywhere("priority_modifier")
	_mission_context["military_life_spent"] = true


func _loadout_choices() -> Array:
	var choices: Variant = _missions_data.get("loadout", {}).get("mission_weapon_choices", [])
	return choices if choices is Array else []


func _weapon_label(weapon_id: String) -> String:
	var w: Dictionary = _weapons_by_id.get(weapon_id, {})
	if w.is_empty():
		return weapon_id
	if str(w.get("category", "")) == "melee":
		return "%s (Melee: %s)" % [str(w.get("name", weapon_id)), str(w.get("description", ""))]
	var traits: Array = w.get("traits", [])
	return "%s (%d\" | %d Shot%s | Dmg %d%s)" % [str(w.get("name", weapon_id)),
		int(w.get("range", 0)), int(w.get("shots", 0)),
		"" if int(w.get("shots", 0)) == 1 else "s", int(w.get("damage", 0)),
		"" if traits.is_empty() else " | " + ", ".join(PackedStringArray(traits)).capitalize()]


func _fire_team_contents() -> String:
	for opt in _support_data.get("support_options", []):
		if opt is Dictionary and str(opt.get("id", "")) == "fire_team":
			return "(%s)" % str(opt.get("contents", ""))
	return ""


func _launch_mission() -> void:
	# Generate battle context using BugHuntBattleSetup
	var BugHuntBattleSetupClass = load("res://src/core/battle/BugHuntBattleSetup.gd")
	if not BugHuntBattleSetupClass:
		# A failed launch must NOT complete the phase, and must never record a
		# won mission. This branch used to stamp objectives_completed = 1 and
		# call complete() -- one of only two producers of that key anywhere, so
		# the sole way a Bug Hunt campaign ever scored an objective was for the
		# battle to fail to start.
		_report_launch_failure("Cannot load BugHuntBattleSetup.")
		return

	_mission_context["participant_ids"] = _participant_ids.duplicate()
	_spend_committed_reputation()
	_spend_military_life_flags()
	_persist_stamped_mission()

	var battle_setup = BugHuntBattleSetupClass.new()
	var battle_context: Dictionary = battle_setup.generate_battle_context(
		_mission_context, _campaign)

	# TacticalBattleUI._try_auto_init_from_temp_data expects the context in
	# {crew, enemies, mission_data} shape. generate_battle_context returns a
	# FLAT payload, so wrap it: crew = the Bug Hunt squad (main characters +
	# grunts); enemies spawn in-battle from contact markers (none at start);
	# the flat payload rides as mission_data (it already carries
	# battle_mode + contacts / tactical locations / spawn points, so the
	# bug-hunt battle code still finds them). Fixed 2026-07-03 — previously
	# the flat dict was stored directly, so the battle got EMPTY rosters and
	# the entire payload was dropped (the keys don't match crew/enemies).
	var crew: Array = []
	if _campaign:
		if _campaign.has_method("get_active_main_characters"):
			# Filtered by the STAMP as well: the p.206 flags were spent above, so a
			# re-derived roster would field a marine the loadout step held back.
			for mc in _campaign.get_active_main_characters():
				if mc is Dictionary \
						and str(mc.get("id", mc.get("character_id", ""))) in _participant_ids:
					crew.append(mc.duplicate(true))
		elif "main_characters" in _campaign:
			crew = _campaign.main_characters.duplicate(true)
		if "grunts" in _campaign and _campaign.grunts is Array:
			crew.append_array(_campaign.grunts.duplicate(true))
	_apply_loadout(crew)
	var wrapped := {
		"crew": crew,
		"enemies": [],
		"mission_data": battle_context,
	}

	# Store battle + mission context for TacticalBattleUI to pick up
	var gs_mgr = get_node_or_null("/root/GameStateManager")
	if gs_mgr and gs_mgr.has_method("set_temp_data"):
		gs_mgr.set_temp_data("bug_hunt_battle_context", wrapped)

	# Navigate to TacticalBattleUI — do NOT complete() here;
	# the turn controller will handle completion on return from battle
	var router = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("tactical_battle")
	else:
		_report_launch_failure("SceneRouter is not available.")


func _create_card(title_text: String, parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
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


func _add_row(parent: VBoxContainer, label_text: String, value_text: String) -> Label:
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
	return val


## ── Dice routing ────────────────────────────────────────────────────────────
## Book table rolls go through the DiceManager autoload so they are recorded in
## the roll history and can be forced from the QA dialog in a debug build.
## Map PLACEMENT is deliberately NOT routed: 5PFH's BattlefieldGenerator.gd has
## zero DiceManager references and seeds a local RNG for placement, so routing
## placement here would both break that precedent and flood the forced-roll
## queue with entries a tester never asked to control.
func _roll_d6(context: String) -> int:
	var dm: Node = get_node_or_null("/root/DiceManager")
	if dm:
		return int(dm.roll_d6(context))
	return randi_range(1, 6)


## Match a D6 roll against a table whose rows carry `d6_value` or `d6_range`.
## Mirrors BugHuntBattleSetup._generate_tactical_locations_count() so the two
## readers of this table shape cannot drift apart.
func _find_by_d6_value(table: Array, roll: int) -> Dictionary:
	for entry in table:
		if not (entry is Dictionary):
			continue
		if entry.has("d6_value") and int(entry.d6_value) == roll:
			return entry
		if entry.has("d6_range") and entry.d6_range is Array:
			var r: Array = entry.d6_range
			if r.size() >= 2 and roll >= int(r[0]) and roll <= int(r[1]):
				return entry
	return {}
