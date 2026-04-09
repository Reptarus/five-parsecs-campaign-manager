class_name PlanetfallColonyEventsPanel
extends Control

## Step 5: Colony Events — D100 roll with varied effects.
## Some events require player choices (which character, priority selection).
## Source: Planetfall pp.63-64
##
## Implements the standard panel interface contract.

signal phase_completed(result_data: Dictionary)

const PlanetfallEventResolverScript := preload(
	"res://src/core/systems/PlanetfallEventResolver.gd")

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

var _campaign: Resource
var _phase_manager: Node
var _resolver: PlanetfallEventResolverScript
var _rolled: bool = false
var _current_event: Dictionary = {}
var _result_data: Dictionary = {}

var _title_label: Label
var _content_vbox: VBoxContainer
var _result_container: VBoxContainer
var _roll_btn: Button
var _choice_container: VBoxContainer
var _continue_btn: Button


func _ready() -> void:
	_resolver = PlanetfallEventResolverScript.new()
	_build_ui()


## ============================================================================
## PANEL INTERFACE CONTRACT
## ============================================================================

func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func set_phase_manager(pm: Node) -> void:
	_phase_manager = pm


func refresh() -> void:
	_rolled = false
	_current_event = {}
	_result_data = {}
	if _title_label:
		_title_label.text = "STEP 5: COLONY EVENTS"
	_clear_container(_content_vbox)
	_clear_container(_result_container)
	_clear_container(_choice_container)
	if _roll_btn:
		_roll_btn.visible = true
		_roll_btn.disabled = false
	if _continue_btn:
		_continue_btn.visible = false

	# Show flavor text
	_add_info_text(
		"Life on Home is unpredictable. Roll D100 to determine which event takes place this campaign turn.")


func complete() -> void:
	if not _rolled:
		_on_roll_pressed()
	else:
		_on_continue_pressed()


## ============================================================================
## UI BUILD
## ============================================================================

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "STEP 5: COLONY EVENTS"
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(_content_vbox)

	_result_container = VBoxContainer.new()
	_result_container.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(_result_container)

	_choice_container = VBoxContainer.new()
	_choice_container.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(_choice_container)

	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(btn_box)

	_roll_btn = Button.new()
	_roll_btn.text = "Roll Colony Event (D100)"
	_roll_btn.custom_minimum_size = Vector2(240, 48)
	_roll_btn.pressed.connect(_on_roll_pressed)
	btn_box.add_child(_roll_btn)

	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.custom_minimum_size = Vector2(200, 48)
	_continue_btn.pressed.connect(_on_continue_pressed)
	_continue_btn.visible = false
	btn_box.add_child(_continue_btn)


## ============================================================================
## EVENT RESOLUTION
## ============================================================================

func _on_roll_pressed() -> void:
	_roll_btn.disabled = true
	_rolled = true

	var roll: int = _resolver.roll_d100()
	_current_event = _resolver.resolve_colony_event(roll)

	var event_name: String = _current_event.get("name", "No Event")
	var event_desc: String = _current_event.get("description", "")
	var event_id: String = _current_event.get("id", "")

	_add_result_bbcode("[b]D100 Roll: %d[/b]" % roll)
	_add_result_bbcode("\n[b]%s[/b]" % event_name)
	_add_result_bbcode(event_desc)

	# Apply automatic effects
	var effect: Dictionary = _current_event.get("effect", {})
	var requires_choice: bool = _current_event.get("requires_player_choice", false)

	if not requires_choice:
		_apply_automatic_effects(effect, event_id)
		_continue_btn.visible = true
		_continue_btn.disabled = false
		_roll_btn.visible = false
	else:
		_build_choice_ui(event_id, effect)
		_roll_btn.visible = false


func _apply_automatic_effects(effect: Dictionary, event_id: String) -> void:
	if not _campaign:
		return

	if effect.has("research_points"):
		var rp: int = effect.get("research_points", 0)
		_add_result_bbcode(
			"\n[color=#10B981]+%d Research Point(s)[/color]" % rp)
		if _campaign.has_method("apply_colony_event"):
			_campaign.apply_colony_event({"research_points": rp})

	if effect.has("build_points"):
		var bp: int = effect.get("build_points", 0)
		_add_result_bbcode(
			"\n[color=#10B981]+%d Build Point(s)[/color]" % bp)
		if _campaign.has_method("apply_colony_event"):
			_campaign.apply_colony_event({"build_points": bp})

	if effect.has("colony_morale"):
		var morale: int = effect.get("colony_morale", 0)
		if _campaign.has_method("adjust_morale"):
			_campaign.adjust_morale(morale)
		var color: String = "#10B981" if morale > 0 else "#DC2626"
		_add_result_bbcode(
			"\n[color=%s]Colony Morale %+d[/color]" % [color, morale])

	if effect.has("colony_damage"):
		var dmg: int = effect.get("colony_damage", 0)
		if _campaign.has_method("adjust_integrity"):
			_campaign.adjust_integrity(-dmg)
		_add_result_bbcode(
			"\n[color=#DC2626]Colony Damage: %d[/color]" % dmg)

	if effect.has("ancient_signs"):
		_add_result_bbcode(
			"\n[color=#10B981]+%d Ancient Sign(s)[/color]" % effect.get("ancient_signs", 0))

	if effect.has("xp_all_characters"):
		var xp: int = effect.get("xp_all_characters", 0)
		_add_result_bbcode(
			"\n[color=#10B981]+%d XP to all roster characters[/color]" % xp)
		if _campaign and "roster" in _campaign:
			for char_dict in _campaign.roster:
				if char_dict is Dictionary:
					char_dict["xp"] = char_dict.get("xp", 0) + xp

	if effect.has("grunts"):
		var g: int = effect.get("grunts", 0)
		if _campaign.has_method("gain_grunts"):
			_campaign.gain_grunts(g)
		_add_result_bbcode(
			"\n[color=#10B981]+%d Grunt(s)[/color]" % g)

	if effect.has("free_scout_action"):
		_add_result_bbcode(
			"\n[color=#4FC3F7]You may perform a free Scout action this turn.[/color]")

	if effect.has("repair_all_bots"):
		if _campaign and "bot_operational" in _campaign:
			_campaign.bot_operational = true
		_add_result_bbcode(
			"\n[color=#10B981]All bots repaired immediately.[/color]")

	if effect.has("colony_damage_repair"):
		var repair: int = effect.get("colony_damage_repair", 0)
		if _campaign.has_method("repair_colony"):
			_campaign.repair_colony(repair)
		_add_result_bbcode(
			"\n[color=#10B981]Repaired %d point(s) of Colony Damage.[/color]" % repair)

	if effect.has("research_points_wasted"):
		_add_result_bbcode(
			"\n[color=#DC2626]Your next %d Research Points earned will be wasted.[/color]" %
			effect.get("research_points_wasted", 0))

	if effect.has("story_points_blocked_this_turn"):
		_add_result_bbcode(
			"\n[color=#DC2626]Cannot use Story Points for the rest of this turn.[/color]")
		_result_data["story_points_blocked"] = true

	if effect.has("erase_lifeform_entry"):
		_add_result_bbcode(
			"\n[color=#D97706]A random Lifeform Encounter entry has been erased.[/color]")

	if effect.has("erase_conditions_entry"):
		_add_result_bbcode(
			"\n[color=#D97706]A random Campaign Conditions entry has been erased.[/color]")

	if effect.has("virus_spread"):
		_resolve_virus_event()

	_result_data["event"] = _current_event


func _build_choice_ui(event_id: String, effect: Dictionary) -> void:
	## Build player choice controls for events that need them.
	_clear_container(_choice_container)

	var choice_label := RichTextLabel.new()
	choice_label.bbcode_enabled = true
	choice_label.fit_content = true
	choice_label.scroll_active = false
	choice_label.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	choice_label.add_theme_color_override("default_color", COLOR_WARNING)

	match event_id:
		"public_relations_demand":
			choice_label.text = "Choose: Select a character to be unavailable, or accept -2 Colony Morale."
		"specialist_training":
			choice_label.text = "Choose: Add a new character (if vacancy) or grant +3 XP to existing."
		"hostile_wildlife":
			choice_label.text = "Choose: Play a Patrol Mission this turn, or accept -2 Colony Morale."
		"experimental_medicine":
			choice_label.text = "Select an injured character to heal 2 turns faster."
		"report_on_progress":
			choice_label.text = "Select a character to earn 1D6 XP."
		"gold_rush":
			choice_label.text = "Select 2 sectors for resource generation."
		"supply_ship":
			choice_label.text = "Choose priority: Research Points or Build Points?"
		_:
			choice_label.text = "Make your choice for this event."

	_choice_container.add_child(choice_label)

	# For most choice events, provide simple accept/decline buttons
	var accept_btn := Button.new()
	accept_btn.text = "Accept Event"
	accept_btn.custom_minimum_size = Vector2(200, 48)
	accept_btn.pressed.connect(func():
		_apply_choice_accept(event_id, effect)
		accept_btn.disabled = true
	)
	_choice_container.add_child(accept_btn)

	# Decline option where applicable
	var penalty: int = effect.get("morale_penalty_if_declined", 0)
	if penalty != 0:
		var decline_btn := Button.new()
		decline_btn.text = "Decline (%+d Morale)" % penalty
		decline_btn.custom_minimum_size = Vector2(200, 48)
		decline_btn.pressed.connect(func():
			if _campaign and _campaign.has_method("adjust_morale"):
				_campaign.adjust_morale(penalty)
			_add_result_bbcode(
				"\n[color=#DC2626]Event declined. Colony Morale %+d[/color]" % penalty)
			_finalize_choice()
			decline_btn.disabled = true
			accept_btn.disabled = true
		)
		_choice_container.add_child(decline_btn)


func _apply_choice_accept(event_id: String, effect: Dictionary) -> void:
	match event_id:
		"supply_ship":
			# Roll 2D6, split high/low — default RP priority
			var d1: int = _resolver.roll_d6()
			var d2: int = _resolver.roll_d6()
			var high: int = max(d1, d2)
			var low: int = min(d1, d2)
			_add_result_bbcode(
				"\n[color=#10B981]Supply Ship: 2D6 = %d, %d → +%d RP (priority), +%d BP[/color]" % [
					d1, d2, high, low])
			if _campaign.has_method("apply_colony_event"):
				_campaign.apply_colony_event({"research_points": high, "build_points": low})
			if _campaign.has_method("gain_grunts"):
				_campaign.gain_grunts(1)
			_add_result_bbcode("[color=#10B981]+1 Grunt[/color]")

		"specialist_training":
			_add_result_bbcode(
				"\n[color=#10B981]+3 XP applied to first roster character.[/color]")
			if _campaign and "roster" in _campaign and not _campaign.roster.is_empty():
				var char_dict: Dictionary = _campaign.roster[0]
				if char_dict is Dictionary:
					char_dict["xp"] = char_dict.get("xp", 0) + 3

		"report_on_progress":
			var xp_roll: int = _resolver.roll_d6()
			_add_result_bbcode(
				"\n[color=#10B981]+%d XP (D6) to selected character. +1 Morale.[/color]" % xp_roll)
			if _campaign and "roster" in _campaign and not _campaign.roster.is_empty():
				var char_dict: Dictionary = _campaign.roster[0]
				if char_dict is Dictionary:
					char_dict["xp"] = char_dict.get("xp", 0) + xp_roll
			if _campaign and _campaign.has_method("adjust_morale"):
				_campaign.adjust_morale(1)

		"experimental_medicine":
			_add_result_bbcode(
				"\n[color=#10B981]Recovery time reduced by 2 turns. +1 Morale.[/color]")
			if _campaign and _campaign.has_method("adjust_morale"):
				_campaign.adjust_morale(1)

		_:
			_add_result_bbcode("\n[color=#10B981]Event accepted.[/color]")
			_apply_automatic_effects(effect, event_id)

	_finalize_choice()


func _finalize_choice() -> void:
	_result_data["event"] = _current_event
	_continue_btn.visible = true
	_continue_btn.disabled = false


func _resolve_virus_event() -> void:
	## Hostile Virus — roll D6 per character. Planetfall pp.63-64.
	if not _campaign or not "roster" in _campaign:
		return
	var infected: Array[String] = []
	for char_dict in _campaign.roster:
		if char_dict is Dictionary:
			if _resolver.roll_d6() == 1:
				infected.append(char_dict.get("id", ""))
	# Spread phase
	var spread_round: int = 0
	while spread_round < 10:  # Safety cap
		var new_infected: Array[String] = []
		for inf_id in infected:
			# Pick random non-infected
			var candidates: Array = []
			for cd in _campaign.roster:
				if cd is Dictionary:
					var cid: String = cd.get("id", "")
					if not infected.has(cid) and not new_infected.has(cid):
						candidates.append(cid)
			if not candidates.is_empty():
				var target: String = candidates[randi_range(0, candidates.size() - 1)]
				if _resolver.roll_d6() == 1:
					new_infected.append(target)
		if new_infected.is_empty():
			break
		infected.append_array(new_infected)
		spread_round += 1

	# Apply sick bay
	for inf_id in infected:
		var turns: int = _resolver.roll_1d3()
		if _campaign.has_method("add_to_sick_bay"):
			_campaign.add_to_sick_bay(inf_id, turns)

	_add_result_bbcode(
		"\n[color=#DC2626]Hostile Virus: %d character(s) infected, sent to Sick Bay.[/color]" %
		infected.size())
	if _campaign.has_method("adjust_morale"):
		_campaign.adjust_morale(-2)
	_add_result_bbcode("[color=#DC2626]Colony Morale -2[/color]")


func _on_continue_pressed() -> void:
	_continue_btn.disabled = true
	phase_completed.emit(_result_data)


## ============================================================================
## HELPERS
## ============================================================================

func _add_info_text(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.text = text
	lbl.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	lbl.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	_content_vbox.add_child(lbl)


func _add_result_bbcode(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.text = text
	lbl.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	lbl.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_result_container.add_child(lbl)


func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
