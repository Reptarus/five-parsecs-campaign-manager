extends Control

## Bug Hunt Mission Panel — Turn Stage 2 of 3
## Generates mission parameters (Priority, contacts, objectives, loadout)
## and launches the battle through TacticalBattleUI.

signal phase_completed(result_data: Dictionary)

const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_TEXT := Color("#E0E0E0")
const COLOR_TEXT_SEC := Color("#808080")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_ACCENT := Color("#2D5A7B")

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

	# Calculate Priority
	var turn: int = 1
	if _campaign and "campaign_turn" in _campaign:
		turn = _campaign.campaign_turn
	var difficulty: String = "mess_me_up"
	if _campaign and "difficulty" in _campaign:
		difficulty = _campaign.difficulty

	var priority: int = _calculate_priority(turn, difficulty)
	var spawn_rating: int = maxi(priority - 1, 1)

	# Roll objective — objectives is a Dictionary with "types" Array inside
	var objectives_data: Dictionary = _missions_data.get("objectives", {})
	var objective_types: Array = objectives_data.get("types", [])
	var objective: Dictionary = objectives_data.duplicate()
	objective.erase("types")  # Keep metadata (description, placement_rule, etc.)
	if objective_types.size() > 0:
		objective["selected_type"] = objective_types[randi() % objective_types.size()]

	# Roll contact markers
	var base_contacts: int = _missions_data.get("base_contact_markers", 4)
	var extra: int = 0
	if _campaign and "extra_contact_markers" in _campaign:
		extra = _campaign.extra_contact_markers
	var total_contacts: int = base_contacts + extra

	# Build mission context
	_mission_context = {
		"priority": priority,
		"spawn_rating": spawn_rating,
		"objective": objective,
		"contact_markers": total_contacts,
		"difficulty": difficulty,
		"turn": turn,
		"battle_result": {}
	}

	# Display briefing
	var briefing_card := _create_card("Mission Briefing", _briefing_container)
	_add_row(briefing_card, "Priority", str(priority))
	_add_row(briefing_card, "Spawn Rating", str(spawn_rating))
	_add_row(briefing_card, "Contact Markers", str(total_contacts))
	var sel_type: Dictionary = objective.get("selected_type", {})
	_add_row(briefing_card, "Objective", sel_type.get("name", "Patrol"))
	_add_row(briefing_card, "Objective Goal", sel_type.get("achieved_when", objective.get("description", "Complete the objective")))

	# Difficulty modifiers
	var diff_settings: Dictionary = _get_difficulty_settings(difficulty)
	if not diff_settings.is_empty():
		_add_row(briefing_card, "Difficulty", difficulty.replace("_", " ").capitalize())
		if diff_settings.get("extra_contacts", 0) > 0:
			_add_row(briefing_card, "Extra Contacts", "+%d" % diff_settings.extra_contacts)

	# Loadout selection (informational)
	var loadout_card := _create_card("Select Loadouts (per character)", _loadout_container)
	var loadout_info := Label.new()
	loadout_info.text = "Each Main Character selects one mission weapon:\n• Combat Rifle (26\" | 1 Shot | Dmg 0)\n• Shotgun (12\" | 2 Shots | Dmg 1 | Focused)\n• Boarding Sword (Melee | +2 Brawl)\n\nOne MC may swap their Service Pistol for a Hand Cannon (8\" | 1 Shot | Dmg 1)."
	loadout_info.add_theme_color_override("font_color", COLOR_TEXT)
	loadout_info.add_theme_font_size_override("font_size", _scaled_font(14))
	loadout_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loadout_card.add_child(loadout_info)

	# Roll support teams
	_roll_support_teams(priority)

	_launch_button.visible = true


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

	# Standard: Priority = turn number / 3, min 1, max 5
	var base_priority: int = maxi(ceili(float(turn) / 3.0), 1)
	return mini(base_priority, 5)


func _get_difficulty_settings(difficulty: String) -> Dictionary:
	var settings: Array = _missions_data.get("difficulty_settings", [])
	for s in settings:
		if s is Dictionary and s.get("id", "") == difficulty:
			return s
	return {}


func _roll_support_teams(priority: int) -> void:
	var support_options: Array = _support_data.get("support_options", [])
	if support_options.is_empty():
		return

	var support_card := _create_card("Support Team Requests (Priority %d)" % priority, _support_container)

	# Free fire team
	var free_lbl := Label.new()
	free_lbl.text = "FREE: Fire Team — 4 Grunts with Combat Rifles"
	free_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
	support_card.add_child(free_lbl)

	# Difficulty bonus
	var bonus: int = 0
	var difficulty: String = _mission_context.get("difficulty", "mess_me_up")
	if difficulty == "im_too_pretty_to_die":
		bonus = 2

	# Roll for each available support option (spend priority as support points)
	var support_points: int = priority + bonus
	var info_lbl := Label.new()
	info_lbl.text = "Support Points: %d (Priority %d + bonus %d). Spend 1 Reputation for +1." % [support_points, priority, bonus]
	info_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	info_lbl.add_theme_font_size_override("font_size", _scaled_font(13))
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	support_card.add_child(info_lbl)

	# Show available support options
	for opt in support_options:
		if opt is not Dictionary:
			continue
		var target: int = opt.get("target_2d6", 99)
		var opt_lbl := Label.new()
		opt_lbl.text = "  %s — 2D6 >= %d — %s" % [opt.get("name", "?"), target, opt.get("contents", "")]
		opt_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		opt_lbl.add_theme_font_size_override("font_size", _scaled_font(13))
		opt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		support_card.add_child(opt_lbl)


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
