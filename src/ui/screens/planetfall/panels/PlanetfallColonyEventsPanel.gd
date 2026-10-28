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
const LifeformScript := preload("res://src/core/systems/PlanetfallLifeformGenerator.gd")
const ConditionScript := preload("res://src/core/systems/PlanetfallConditionSystem.gd")
const RosterRules := preload("res://src/core/systems/PlanetfallRosterRules.gd")

const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_ELEVATED := UIColors.COLOR_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_BLUE
const COLOR_SUCCESS := UIColors.COLOR_EMERALD
const COLOR_WARNING := UIColors.COLOR_AMBER
const COLOR_DANGER := UIColors.COLOR_RED
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
## The normal event plus any a Milestone queued (p.156 2nd Milestone: "Immediately roll
## for a Colony Event ... in addition to the normal event").
var _events_owed: int = 1
var _events_rolled: int = 0
## The character / class picked in the choice on screen (pp.63-64).
var _choice_pick: OptionButton
var _choice_class: OptionButton

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
	_events_rolled = 0
	_events_owed = 1 + (_campaign.get_extra_rolls("colony_event")
			if _campaign and _campaign.has_method("get_extra_rolls") else 0)
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


## One footer press is one player click: roll the event owed, or continue past the one
## on screen, which re-arms the roll while a Milestone still owes another. Rolling them
## all at once would finish the step before the player saw an event or made a choice.
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
	_title_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_LG))
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
	_roll_btn.custom_minimum_size = Vector2(0, 48)
	_roll_btn.pressed.connect(_on_roll_pressed)
	btn_box.add_child(_roll_btn)

	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.custom_minimum_size = Vector2(0, 48)
	_continue_btn.pressed.connect(_on_continue_pressed)
	_continue_btn.visible = false
	btn_box.add_child(_continue_btn)


## ============================================================================
## EVENT RESOLUTION
## ============================================================================

func _on_roll_pressed() -> void:
	_roll_btn.disabled = true
	_rolled = true
	_events_rolled += 1
	_clear_container(_choice_container)
	if _events_rolled > 1:
		_add_result_bbcode("\n[b]Milestone Colony Event %d of %d[/b]" % [
				_events_rolled - 1, _events_owed - 1])

	var roll: int = _resolver.roll_d100("Planetfall Colony Event")
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
		# REPORTED to the phase manager, which applies it once with any building
		# mitigation and its Morale cost (p.87). Applied here it lowered Integrity but
		# never reached Morale. "Cannot be mitigated" (p.63) travels as its own key.
		var dmg: int = effect.get("colony_damage", 0)
		var key: String = "colony_damage_unmitigable" \
				if effect.get("colony_damage_unmitigatable", false) else "colony_damage"
		_result_data[key] = int(_result_data.get(key, 0)) + dmg
		_add_result_bbcode(
			"\n[color=#DC2626]Colony Damage: %d%s[/color]" % [
				dmg, " (cannot be mitigated)" if key == "colony_damage_unmitigable" else ""])

	if effect.has("ancient_signs"):
		# p.63 Colonists find. This printed the sign and recorded nothing until 2026-10-27.
		if _campaign.has_method("apply_colony_event"):
			_campaign.apply_colony_event({"ancient_signs": int(effect.get("ancient_signs", 0))})
		_add_result_bbcode(
			"\n[color=#10B981]+%d Ancient Sign(s)[/color]" % effect.get("ancient_signs", 0))

	if effect.has("xp_all_characters"):
		var xp: int = effect.get("xp_all_characters", 0)
		_add_result_bbcode(
			"\n[color=#10B981]+%d XP to all roster characters[/color]" % xp)
		if _campaign and "roster" in _campaign and _campaign.has_method("award_xp"):
			for char_dict in _campaign.roster:
				if _is_present(char_dict):
					_campaign.award_xp(str(char_dict.get("id", "")), xp)

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
		# p.87: a repair stops at the maximum, so print what was actually restored.
		var repaired: int = _campaign.repair_colony(repair) \
			if _campaign.has_method("repair_colony") else 0
		_add_result_bbcode(
			"\n[color=#10B981]Repaired %d point(s) of Colony Damage.[/color]" % repaired)

	if effect.has("research_points_wasted"):
		# p.63 Scientific dead end; the core takes it off the next points earned.
		if "research_points_wasted" in _campaign:
			_campaign.research_points_wasted += int(effect.get("research_points_wasted", 0))
		_add_result_bbcode(
			"\n[color=#DC2626]Your next %d Research Points earned will be wasted.[/color]" %
			effect.get("research_points_wasted", 0))

	if effect.has("story_points_blocked_this_turn"):
		_add_result_bbcode(
			"\n[color=#DC2626]Cannot use Story Points for the rest of this turn.[/color]")
		_result_data["story_points_blocked"] = true

	# p.64 Animal migrations / Changing climate conditions. Both printed "has been erased"
	# and erased nothing until 2026-10-27.
	if effect.has("erase_lifeform_entry"):
		_report_erased("Lifeform Encounter", LifeformScript.new().erase_random_entry(_campaign))

	if effect.has("erase_conditions_entry"):
		_report_erased("Campaign Conditions", ConditionScript.new().erase_random_entry(_campaign))

	if effect.has("virus_spread"):
		_resolve_virus_event()

	_record_event()


func _report_erased(table: String, slot: int) -> void:
	if slot < 0:
		_add_result_bbcode("\nNo %s entry has been filled yet, so there is none to erase." % table)
		return
	_add_result_bbcode("\n[color=#D97706]%s entry %d erased. It is filled again when that "
			% [table, slot + 1] + "entry is rolled.[/color]")


## Every event rolled this step, in order; "event" stays the first for older readers.
## Keyed on the count, not on equality: an accepted choice can record the same event
## twice, while two rolls of the same row are two events.
func _record_event() -> void:
	var events: Array = _result_data.get("events", [])
	if events.size() < _events_rolled:
		events.append(_current_event)
	_result_data["events"] = events
	if not _result_data.has("event"):
		_result_data["event"] = _current_event


func _build_choice_ui(event_id: String, effect: Dictionary) -> void:
	## Build the player's choice for the events that need one. pp.63-64. Until
	## 2026-10-27 every pick here went to roster[0], the Public relations demand kept
	## nobody out, Experimental medicine shortened no recovery and the Supply ship always
	## took Research Points.
	_clear_container(_choice_container)
	_choice_pick = null
	_choice_class = null

	var choice_label := RichTextLabel.new()
	choice_label.bbcode_enabled = true
	choice_label.fit_content = true
	choice_label.scroll_active = false
	choice_label.add_theme_font_size_override("normal_font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	choice_label.add_theme_color_override("default_color", COLOR_WARNING)
	_choice_container.add_child(choice_label)

	match event_id:
		"public_relations_demand":
			choice_label.text = "Select a character who will not take part in any mission this " \
					+ "campaign turn, or decline and adjust Colony Morale by -2."
			_choice_pick = _character_picker(_can_sit_out)
			_add_choice_button("Keep them out this turn", event_id, effect)
		"specialist_training":
			choice_label.text = "Add a new character to your roster if you have a vacancy, " \
					+ "OR grant +3 XP to an existing character."
			if _has_vacancy():
				_choice_class = OptionButton.new()
				_choice_class.custom_minimum_size = Vector2(0, 48)
				for cls in RosterRules.REPLACEMENT_CLASSES:
					_choice_class.add_item(str(cls).capitalize())
				_choice_container.add_child(_choice_class)
				_add_choice_button("Add a new character", event_id, effect, "add")
			_choice_pick = _character_picker()
			_add_choice_button("+3 XP to the selected character", event_id, effect, "xp")
		"hostile_wildlife":
			choice_label.text = "Play a Patrol Mission this turn, or adjust Colony Morale by -2. " \
					+ "If you commit and then play a different mission, the -2 still applies."
			_add_choice_button("Commit to a Patrol Mission", event_id, effect)
		"experimental_medicine":
			choice_label.text = "Select a character recovering from injuries: their recovery " \
					+ "time is reduced by 2 turns. Colony Morale +1."
			_choice_pick = _character_picker(_is_recovering)
			_add_choice_button("Apply", event_id, effect)
		"report_on_progress":
			choice_label.text = "Select one character to earn 1D6 XP. Colony Morale +1."
			_choice_pick = _character_picker()
			_add_choice_button("Award the XP", event_id, effect)
		"gold_rush":
			choice_label.text = "Select 2 random sectors: unexplored or Exploited ones roll " \
					+ "Resource and Hazard values; Explored but not Exploited ones gain +1 Resource."
			_add_choice_button("Accept Event", event_id, effect)
		"supply_ship":
			choice_label.text = "Choose the priority, then roll 2D6: the highest die goes to " \
					+ "your priority and the lowest to the other. +1 grunt."
			_add_choice_button("Research Points priority", event_id, effect, "rp")
			_add_choice_button("Build Points priority", event_id, effect, "bp")
		_:
			choice_label.text = "Make your choice for this event."
			_add_choice_button("Accept Event", event_id, effect)

	# Decline option where applicable
	var penalty: int = effect.get("morale_penalty_if_declined", 0)
	if penalty != 0:
		var decline_btn := Button.new()
		decline_btn.text = "Decline (%+d Morale)" % penalty
		decline_btn.custom_minimum_size = Vector2(0, 48)
		decline_btn.pressed.connect(func():
			if _campaign and _campaign.has_method("adjust_morale"):
				_campaign.adjust_morale(penalty)
			_add_result_bbcode(
				"\n[color=#DC2626]Event declined. Colony Morale %+d[/color]" % penalty)
			_finalize_choice()
		)
		_choice_container.add_child(decline_btn)


func _add_choice_button(text: String, event_id: String, effect: Dictionary,
		option: String = "") -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 48)
	btn.pressed.connect(func(): _apply_choice_accept(event_id, effect, option))
	_choice_container.add_child(btn)
	return btn


## An OptionButton over the roster characters `filter` accepts; each item's metadata is
## the character id. A character away on R&R is never offered: p.70 "they cannot be the
## target of events".
func _character_picker(filter: Callable = Callable()) -> OptionButton:
	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(0, 48)
	if _campaign and "roster" in _campaign:
		for c in _campaign.roster:
			if _is_present(c) and (not filter.is_valid() or bool(filter.call(c))):
				pick.add_item("%s (%s)" % [str(c.get("name", "?")),
						str(c.get("class", "")).capitalize()])
				pick.set_item_metadata(pick.item_count - 1, str(c.get("id", "")))
	if pick.item_count == 0:
		pick.add_item("No eligible character")
		pick.disabled = true
	_choice_container.add_child(pick)
	return pick


func _picked_id() -> String:
	if _choice_pick == null or _choice_pick.disabled or _choice_pick.selected < 0:
		return ""
	return str(_choice_pick.get_item_metadata(_choice_pick.selected))


func _picked_name() -> String:
	return _name_of(_picked_id())


func _name_of(id: String) -> String:
	var who: Variant = _campaign.get_roster_character_by_id(id) \
			if id != "" and _campaign.has_method("get_roster_character_by_id") else null
	return str(who.get("name", id)) if who is Dictionary else id


## p.69: "If a character is currently absent from the campaign entirely, such as during
## the R&R event, they cannot be the target of events." Every roster walk here uses it.
func _is_present(c: Variant) -> bool:
	if not c is Dictionary:
		return false
	return not (_campaign.has_method("is_away") and _campaign.is_away(str(c.get("id", ""))))


func _recovery_left(c: Dictionary) -> int:
	var bay: Dictionary = _campaign.sick_bay if "sick_bay" in _campaign else {}
	return int(bay.get(str(c.get("id", "")), 0))


## p.63: "They can be [a] character currently in Sick Bay if they have only one turn of
## recovery left."
func _can_sit_out(c: Dictionary) -> bool:
	return _recovery_left(c) <= 1


func _is_recovering(c: Dictionary) -> bool:
	return _recovery_left(c) > 0


func _has_vacancy() -> bool:
	return _campaign != null and "roster" in _campaign \
			and _campaign.roster.size() < RosterRules.roster_capacity(_campaign)


func _apply_choice_accept(event_id: String, effect: Dictionary, option: String = "") -> void:
	match event_id:
		"public_relations_demand":
			var id := _picked_id()
			if id != "" and _campaign.has_method("assign_event_sitout"):
				_campaign.assign_event_sitout(id)
				_add_result_bbcode("\n[color=#D97706]%s will not take part in a mission this "
						% _picked_name() + "campaign turn.[/color]")

		"specialist_training":
			if option == "add" and _choice_class != null and _has_vacancy():
				var cls: String = str(RosterRules.REPLACEMENT_CLASSES[maxi(_choice_class.selected, 0)])
				var new_id: String = RosterRules.next_character_id(_campaign)
				_campaign.add_roster_character(RosterRules.standard_character(
						cls, new_id, "Colonist %d" % (_campaign.roster.size() + 1)))
				_add_result_bbcode("\n[color=#10B981]A new %s joins the roster.[/color]"
						% cls.capitalize())
			elif _picked_id() != "" and _campaign.has_method("award_xp"):
				_campaign.award_xp(_picked_id(), 3)
				_add_result_bbcode("\n[color=#10B981]+3 XP to %s.[/color]" % _picked_name())

		"hostile_wildlife":
			if "patrol_required_turn" in _campaign:
				_campaign.patrol_required_turn = int(_campaign.campaign_turn)
			_add_result_bbcode("\n[color=#4FC3F7]Committed to a Patrol Mission this turn. Any "
					+ "other mission costs Colony Morale -2 at Mission Determination.[/color]")

		"supply_ship":
			var d1: int = _resolver.roll_d6("Planetfall Supply Ship")
			var d2: int = _resolver.roll_d6("Planetfall Supply Ship")
			var high: int = maxi(d1, d2)
			var low: int = mini(d1, d2)
			var rp: int = high if option != "bp" else low
			var bp: int = low if option != "bp" else high
			_add_result_bbcode(
				"\n[color=#10B981]Supply Ship: 2D6 = %d, %d. +%d RP, +%d BP (%s priority)[/color]" % [
					d1, d2, rp, bp, "Build Points" if option == "bp" else "Research Points"])
			if _campaign.has_method("apply_colony_event"):
				_campaign.apply_colony_event({"research_points": rp, "build_points": bp})
			if _campaign.has_method("gain_grunts"):
				_campaign.gain_grunts(int(effect.get("grunts", 1)))
			_add_result_bbcode("[color=#10B981]+1 Grunt[/color]")

		"report_on_progress":
			var xp_roll: int = _resolver.roll_d6("Planetfall Report XP")
			if _picked_id() != "" and _campaign.has_method("award_xp"):
				_campaign.award_xp(_picked_id(), xp_roll)
			_add_result_bbcode("\n[color=#10B981]+%d XP (D6) to %s. +1 Morale.[/color]"
					% [xp_roll, _picked_name()])
			if _campaign.has_method("adjust_morale"):
				_campaign.adjust_morale(int(effect.get("colony_morale", 1)))

		"experimental_medicine":
			var id := _picked_id()
			if id != "" and _campaign.has_method("reduce_recovery"):
				var left: int = _campaign.reduce_recovery(id, int(effect.get("reduce_recovery", 2)))
				_add_result_bbcode("\n[color=#10B981]%s: %s[/color]" % [_picked_name(),
						"fully recovered and can act normally this turn" if left == 0
						else "%d turn(s) of recovery left" % left])
			else:
				_add_result_bbcode("\nNo one is recovering from injuries.")
			if _campaign.has_method("adjust_morale"):
				_campaign.adjust_morale(int(effect.get("colony_morale", 1)))
			_add_result_bbcode("[color=#10B981]Colony Morale +1[/color]")

		_:
			_add_result_bbcode("\n[color=#10B981]Event accepted.[/color]")
			_apply_automatic_effects(effect, event_id)

	_finalize_choice()


func _finalize_choice() -> void:
	for b in _choice_container.find_children("*", "BaseButton", true, false):
		(b as BaseButton).disabled = true
	_record_event()
	_continue_btn.visible = true
	_continue_btn.disabled = false


func _resolve_virus_event() -> void:
	## Hostile Virus. Planetfall p.64: "Roll a D6 for each character on your roster; any who
	## roll a natural 1 have contracted the virus. Once you have rolled for every character,
	## for each infected character pick a random non-infected character and roll again.
	## Continue until no more natural 1s are rolled." Each infected character spreads ONCE:
	## the old loop re-rolled for every infected character each round. The Morale -2 comes
	## from the event's colony_morale key; this applied it a second time until 2026-10-27.
	if not _campaign or not "roster" in _campaign:
		return
	var infected: Array[String] = []
	for char_dict in _campaign.roster:
		if _is_present(char_dict):
			if _resolver.roll_d6("Planetfall Virus Infection") == 1:
				infected.append(str(char_dict.get("id", "")))
	var to_spread: Array[String] = infected.duplicate()
	while not to_spread.is_empty():
		to_spread.pop_front()
		var candidates: Array = []
		for cd in _campaign.roster:
			if _is_present(cd) and not infected.has(str(cd.get("id", ""))):
				candidates.append(str(cd.get("id", "")))
		if candidates.is_empty():
			break
		var target: String = candidates[_resolver.pick_index(candidates.size(),
				"Planetfall Virus Target")]
		if _resolver.roll_d6("Planetfall Virus Infection") == 1:
			infected.append(target)
			to_spread.append(target)

	for inf_id in infected:
		var turns: int = _resolver.roll_1d3("Planetfall Virus Recovery")
		if _campaign.has_method("add_to_sick_bay"):
			_campaign.add_to_sick_bay(inf_id, turns)
		_add_result_bbcode("[color=#DC2626]%s: %d turn(s) in Sick Bay[/color]"
				% [_name_of(inf_id), turns])
	_add_result_bbcode(
		"\n[color=#DC2626]Hostile Virus: %d character(s) infected.[/color]" % infected.size())


func _on_continue_pressed() -> void:
	if _events_rolled < _events_owed:
		# A Milestone still owes an event: Continue re-arms the roll for it.
		_rolled = false
		_continue_btn.visible = false
		_roll_btn.text = "Roll Milestone Colony Event (D100)"
		_roll_btn.visible = true
		_roll_btn.disabled = false
		return
	_emit_completion()


func _emit_completion() -> void:
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
	lbl.add_theme_font_size_override("normal_font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	lbl.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	_content_vbox.add_child(lbl)


func _add_result_bbcode(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.text = text
	lbl.add_theme_font_size_override("normal_font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	lbl.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_result_container.add_child(lbl)


func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
