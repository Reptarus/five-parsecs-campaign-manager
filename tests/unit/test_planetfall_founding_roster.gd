extends GdUnitTestSuite

## Planetfall creation, Steps 2-3: the founding roster (pp.14-20) and the character
## backgrounds (pp.21-23).
##
## ⚠ Until 2026-10-28 both steps were self-described stubs. The roster step made eight
## "Colonist N" in the recommended mix, offered no sub-species, and the coordinator
## accepted any roster of THREE or more against the book's eight. The backgrounds step
## rolled raw randi(), made the first four on the list experienced instead of letting the
## player choose, and showed no result. No suite touched either step.

const RosterRules = preload("res://src/core/systems/PlanetfallRosterRules.gd")
const Backgrounds = preload("res://src/core/systems/PlanetfallBackgrounds.gd")
const CoordScript = preload("res://src/ui/screens/planetfall/PlanetfallCreationCoordinator.gd")
const RosterPanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallRosterPanel.gd")
const BackgroundsPanel = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallBackgroundsPanel.gd")
const ExpeditionPanel = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallExpeditionPanel.gd")
const ReviewPanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallReviewPanel.gd")
const SectorGridScript = preload("res://src/ui/screens/planetfall/panels/PlanetfallSectorGrid.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const NameRoller = preload("res://src/core/character/Generation/CharacterTableRoller.gd")
const CreationUI = preload("res://src/ui/screens/planetfall/PlanetfallCreationUI.gd")

const PHONE_DESIGN_WIDTH := 338.0
const MIX := ["scientist", "scientist", "scout", "scout", "trooper", "trooper", "trooper",
		"trooper"]

var _user_state: Dictionary
var _dm: Node


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	SaveDirGuard.restore(_user_state)


func _roster(classes: Array = MIX) -> Array:
	var out: Array = []
	for i in range(classes.size()):
		out.append(RosterRules.standard_character(classes[i], "pf_char_%d" % i, "C%d" % i))
	return out


func _with(roster: Array, i: int, sid: String) -> Array:
	roster[i] = RosterRules.with_subspecies(roster[i], sid)
	return roster


func _coord() -> Node:
	var coord: Node = CoordScript.new()
	add_child(coord)
	auto_free(coord)
	return coord


# ── The roster rules (pp.14-20) ──────────────────────────────────────────────────

func test_the_recommended_mix_is_a_legal_roster() -> void:
	assert_array(RosterRules.roster_problems(_roster())).is_empty()


func test_the_founding_roster_is_eight_characters() -> void:
	assert_array(RosterRules.roster_problems(_roster(["scientist", "scout", "trooper"]))) \
			.is_not_empty()
	assert_array(RosterRules.roster_problems(_roster(MIX.slice(0, 7)))).is_not_empty()


func test_every_class_is_required() -> void:
	var troopers: Array = []
	troopers.resize(8)
	troopers.fill("trooper")
	var problems: Array = RosterRules.roster_problems(_roster(troopers))
	assert_str(" ".join(PackedStringArray(problems))).contains("Scientist").contains("Scout")


func test_subspecies_limits_follow_p19() -> void:
	assert_array(RosterRules.roster_problems(_with(_with(_roster(), 0, "feral"), 1, "feral"))) \
			.is_empty()
	assert_array(RosterRules.roster_problems(_with(_with(_roster(), 0, "feral"), 1, "hulker"))) \
			.is_empty()
	assert_array(RosterRules.roster_problems(_with(_with(_roster(), 0, "hulker"), 1, "stalker"))) \
			.is_not_empty()
	var three: Array = _with(_with(_with(_roster(), 0, "feral"), 1, "feral"), 2, "stalker")
	assert_array(RosterRules.roster_problems(three)).is_not_empty()


func test_one_soulless_emissary_and_only_as_a_trooper() -> void:
	assert_array(RosterRules.roster_problems(_with(_roster(), 7, "soulless_emissary"))).is_empty()
	assert_array(RosterRules.roster_problems(_with(_roster(), 2, "soulless_emissary"))) \
			.is_not_empty()
	var two: Array = _with(_with(_roster(), 6, "soulless_emissary"), 7, "soulless_emissary")
	assert_array(RosterRules.roster_problems(two)).is_not_empty()


func test_a_subspecies_sets_the_profile_it_begins_with() -> void:
	var trooper: Dictionary = RosterRules.standard_character("trooper", "t", "T")
	var hulker: Dictionary = RosterRules.with_subspecies(trooper, "hulker")
	assert_int(int(hulker.toughness)).is_equal(5)
	var soulless: Dictionary = RosterRules.with_subspecies(trooper, "soulless_emissary")
	assert_int(int(soulless.toughness)).is_equal(4)
	assert_int(int(soulless.savvy)).is_equal(1)
	assert_int(int(soulless.get("saving_throw", 0))).is_equal(6)
	var back: Dictionary = RosterRules.with_subspecies(hulker, "")
	assert_int(int(back.toughness)).is_equal(3)
	assert_str(str(back.subspecies)).is_equal("")


func test_the_coordinator_gate_reads_the_book_roster() -> void:
	var coord := _coord()
	coord.update_roster(_roster(["scientist", "scout", "trooper"]))
	assert_bool(coord.is_step_complete(1)).is_false()
	coord.update_roster(_roster())
	assert_bool(coord.is_step_complete(1)).is_true()


func test_the_founded_colony_keeps_a_hulkers_toughness() -> void:
	var coord := _coord()
	coord.update_roster(_with(_roster(), 7, "hulker"))
	var campaign: Resource = coord.build_campaign()
	var hulker: Dictionary = campaign.get_roster_character_by_id("pf_char_7")
	assert_int(int(hulker.get("toughness", 0))).is_equal(5)
	assert_str(str(hulker.get("subspecies", ""))).is_equal("hulker")


# ── Backgrounds (pp.21-23) ───────────────────────────────────────────────────────

func _force(context: String, values: Array) -> void:
	assert_object(_dm).is_not_null()
	for v in values:
		_dm.queue_forced_result(context, int(v))


func test_an_inexperienced_character_rolls_motivation_only() -> void:
	_force(Backgrounds.MOTIVATION_DIE, [35])
	var record: Dictionary = Backgrounds.roll_character(false)
	assert_str(str(record.motivation)).is_equal("Danger")
	assert_bool(record.has("prior_experience")).is_false()


func test_a_forced_army_career_raises_the_founded_characters_reactions() -> void:
	var coord := _coord()
	var roster: Array = _roster()
	coord.update_roster(roster)
	var data: Dictionary = {}
	for i in range(roster.size()):
		if i == 0:
			_force(Backgrounds.MOTIVATION_DIE, [1])
			_force(Backgrounds.PRIOR_EXPERIENCE_DIE, [3])
			_force(Backgrounds.NOTABLE_EVENT_DIE, [1])
		data[roster[i].id] = Backgrounds.roll_character(i < 4)
	assert_str(str(data["pf_char_0"].prior_experience)).is_equal("Army")
	coord.update_backgrounds(data)
	assert_bool(coord.is_step_complete(2)).is_true()
	var campaign: Resource = coord.build_campaign()
	# Scientist Reactions 1 (p.18) + Army +1 (p.22).
	assert_int(int(campaign.get_roster_character_by_id("pf_char_0").reactions)).is_equal(2)


func test_backgrounds_need_exactly_four_experienced() -> void:
	var roster: Array = _roster()
	var data: Dictionary = {}
	for i in range(roster.size()):
		data[roster[i].id] = Backgrounds.roll_character(i < 3)
	assert_bool(Backgrounds.backgrounds_complete(roster, data)).is_false()
	data[roster[3].id] = Backgrounds.roll_character(true)
	assert_bool(Backgrounds.backgrounds_complete(roster, data)).is_true()
	data[roster[4].id] = Backgrounds.roll_character(true)
	assert_bool(Backgrounds.backgrounds_complete(roster, data)).is_false()


func test_a_roster_change_drops_the_backgrounds_of_a_character_who_left() -> void:
	var coord := _coord()
	var roster: Array = _roster()
	coord.update_roster(roster)
	var data: Dictionary = {}
	for i in range(roster.size()):
		data[roster[i].id] = Backgrounds.roll_character(i < 4)
	coord.update_backgrounds(data)
	roster[0] = RosterRules.standard_character("scientist", "pf_char_9", "New")
	coord.update_roster(roster)
	assert_bool(coord.background_data.has("pf_char_0")).is_false()
	assert_bool(coord.is_step_complete(2)).is_false()


# ── The screens ──────────────────────────────────────────────────────────────────

func _roster_panel(coord: Node) -> Control:
	var panel: Control = RosterPanel.new()
	panel.roster_updated.connect(coord.update_roster)
	panel.set_coordinator(coord)
	add_child(panel)
	auto_free(panel)
	return panel


## A re-render queue_free()s each old CARD, which marks the card and not its children, and
## the old card stays in the tree until the frame ends; so a node is live only if no
## ancestor up to `root` is queued. Without this the probe reads the previous render.
func _live(node: Node, root: Node) -> bool:
	var n: Node = node
	while n != null and n != root:
		if n.is_queued_for_deletion():
			return false
		n = n.get_parent()
	return true


func _subspecies_pickers(panel: Node) -> Array:
	return panel.find_children("*", "OptionButton", true, false).filter(func(o: Node) -> bool:
		return _live(o, panel) and (o as OptionButton).item_count == 5)


## A founded character's name carries no rank title. The shared 5PFH name generator
## prefixes one name in five with a title (Trooper, Scout, Specialist...), which named a
## Scientist "Trooper Cael Yang (Scientist)" on the Step 7 roster.
func test_a_founded_name_carries_no_rank_title() -> void:
	var panel := _roster_panel(_coord())
	var titles: Array = NameRoller._get_titles()
	assert_bool(titles.is_empty()).override_failure_message("premise: titles exist").is_false()
	var titled: Array[String] = []
	for i in range(200):
		var name_text: String = str(panel._new_character("scientist").get("name", ""))
		if name_text.get_slice(" ", 0) in titles:
			titled.append(name_text)
	assert_array(titled).override_failure_message(
		"founded characters were named with a title: %s" % [titled]).is_empty()


func test_the_roster_screen_starts_legal_and_announces_itself_when_shown() -> void:
	var coord := _coord()
	var panel := _roster_panel(coord)
	assert_bool(coord.is_step_complete(1)).is_false()
	panel.hide()
	panel.show()
	assert_int(coord.roster_data.size()).is_equal(8)
	assert_bool(coord.is_step_complete(1)).is_true()


func test_the_screen_disables_a_third_sub_species() -> void:
	var coord := _coord()
	var panel := _roster_panel(coord)
	(_subspecies_pickers(panel)[0] as OptionButton).item_selected.emit(1)
	(_subspecies_pickers(panel)[1] as OptionButton).item_selected.emit(1)
	var third: OptionButton = _subspecies_pickers(panel)[2]
	assert_bool(third.is_item_disabled(1)).is_true()
	assert_bool(third.is_item_disabled(2)).is_true()
	assert_bool(third.is_item_disabled(3)).is_true()
	assert_bool(third.is_item_disabled(4)).is_false()
	assert_bool(coord.is_step_complete(1)).is_true()


func test_choosing_the_soulless_emissary_makes_a_trooper() -> void:
	var coord := _coord()
	var panel := _roster_panel(coord)
	(_subspecies_pickers(panel)[0] as OptionButton).item_selected.emit(4)
	var c: Dictionary = coord.roster_data[0]
	assert_str(str(c["class"])).is_equal("trooper")
	assert_int(int(c.toughness)).is_equal(4)


func _backgrounds_panel(coord: Node) -> Control:
	var panel: Control = BackgroundsPanel.new()
	panel.backgrounds_updated.connect(coord.update_backgrounds)
	panel.set_coordinator(coord)
	add_child(panel)
	auto_free(panel)
	panel.refresh()
	return panel


func test_the_backgrounds_screen_rolls_only_once_four_are_chosen() -> void:
	var coord := _coord()
	coord.update_roster(_roster())
	var panel := _backgrounds_panel(coord)
	panel.roll_all()
	assert_bool(coord.background_data.is_empty()).is_true()
	for i in range(5):
		panel.set_experienced("pf_char_%d" % i, true)
	panel.roll_all()
	assert_int(coord.background_data.size()).is_equal(8)
	var experienced: int = 0
	for cid in coord.background_data:
		if bool(coord.background_data[cid].get("experienced", false)):
			experienced += 1
	assert_int(experienced).is_equal(4)
	assert_bool(coord.is_step_complete(2)).is_true()
	# Rolled characters are headed by name; a greyed, disabled checkbox read as a
	# character who was switched off.
	var live_checks: Array = panel.find_children("*", "CheckBox", true, false).filter(
		func(n: Node) -> bool: return _live(n, panel))
	assert_int(live_checks.size()).override_failure_message(
		"a rolled character still shows the experienced checkbox").is_equal(0)


## p.52: "Roll D100 on the Expedition Type table". One roll: until 2026-10-28 a second
## press re-rolled for free under a "(Story Point)" label no rule supports.
func test_the_expedition_rolls_once_through_the_forceable_die() -> void:
	var coord := _coord()
	var panel: Control = ExpeditionPanel.new()
	panel.expedition_updated.connect(coord.update_expedition)
	add_child(panel)
	auto_free(panel)
	_force("Planetfall Expedition Type", [16, 1])
	panel._on_roll_pressed()
	assert_str(str(coord.config_data.get("expedition_type", ""))).is_equal("Corporate Funded")
	panel._on_roll_pressed()
	assert_str(str(coord.config_data.get("expedition_type", ""))).is_equal("Corporate Funded")
	var left: Array = _dm.get_forced_results().get("planetfall expedition type", [])
	assert_int(left.size()).is_equal(1)


func test_a_cleared_name_founds_the_default_name() -> void:
	var coord := _coord()
	coord.update_expedition({"campaign_name": "  ", "colony_name": ""})
	assert_str(coord.campaign_name()).is_equal(CoordScript.DEFAULT_CAMPAIGN_NAME)
	assert_str(coord.colony_name()).is_equal(CoordScript.DEFAULT_CAMPAIGN_NAME)
	coord.update_roster(_roster())
	var campaign: Resource = coord.build_campaign()
	assert_str(str(campaign.campaign_name)).is_equal(CoordScript.DEFAULT_CAMPAIGN_NAME)


func test_the_review_names_every_character_and_shows_the_map() -> void:
	var coord := _coord()
	coord.update_expedition({"campaign_name": "Haven"})
	coord.update_roster(_roster())
	coord.update_map_config({"grid_size": [6, 6], "grid_rows": 6, "grid_cols": 6,
		"home_sector": [2, 2]})
	var panel: Control = ReviewPanel.new()
	panel.set_coordinator(coord)
	add_child(panel)
	auto_free(panel)
	panel.refresh()
	var text: String = ""
	for lbl in panel.find_children("*", "Label", true, false):
		if _live(lbl, panel):
			text += (lbl as Label).text + "\n"
	assert_str(text).contains("Haven")
	for i in range(8):
		assert_str(text).contains("C%d, " % i)
	var grids: Array = panel.find_children("*", "", true, false).filter(func(n: Node) -> bool:
		return _live(n, panel) and n.get_script() == SectorGridScript)
	assert_int(grids.size()).is_equal(1)


## The review prints the profile the colony is founded with. It printed the profile
## before the Prior Experience bonus, so an Army career's Reactions 2 read as 1.
func test_the_review_shows_the_profile_with_the_background_bonus() -> void:
	var coord := _coord()
	var roster: Array = _roster()
	coord.update_roster(roster)
	var data: Dictionary = {}
	for i in range(roster.size()):
		if i == 0:
			_force(Backgrounds.MOTIVATION_DIE, [1])
			_force(Backgrounds.PRIOR_EXPERIENCE_DIE, [3])
			_force(Backgrounds.NOTABLE_EVENT_DIE, [1])
		data[roster[i].id] = Backgrounds.roll_character(i < 4)
	coord.update_backgrounds(data)
	var panel: Control = ReviewPanel.new()
	panel.set_coordinator(coord)
	add_child(panel)
	auto_free(panel)
	panel.refresh()
	var founded: int = int(coord.build_campaign().get_roster_character_by_id("pf_char_0").reactions)
	assert_int(founded).override_failure_message("premise: Army raised Reactions").is_equal(2)
	var line: String = ""
	for lbl in panel.find_children("*", "Label", true, false):
		var t: String = (lbl as Label).text
		if _live(lbl, panel) and t.begins_with("Reactions") and line == "":
			line = t
	assert_str(line).starts_with("Reactions %d " % founded)


func test_both_screens_fit_a_phone() -> void:
	var coord := _coord()
	var roster_panel := _roster_panel(coord)
	roster_panel.hide()
	roster_panel.show()
	var bg_panel := _backgrounds_panel(coord)
	for i in range(4):
		bg_panel.set_experienced("pf_char_%d" % i, true)
	bg_panel.roll_all()
	await get_tree().process_frame
	await get_tree().process_frame
	for panel in [roster_panel, bg_panel]:
		var scroll := (panel as Control).get_child(0) as ScrollContainer
		var page: Control = scroll.get_child(0)
		var width: float = page.get_combined_minimum_size().x
		# The room a step really gets on a phone: the creation screen's two side margins and
		# the page's own scrollbar come off the screen width. A bare "<= 338" passed a page
		# that ran ~30 px off the right edge (the Initial Missions cards did exactly that).
		var room: float = PHONE_DESIGN_WIDTH - 2.0 * CreationUI.NARROW_SIDE_MARGIN \
				- scroll.get_v_scroll_bar().get_combined_minimum_size().x
		var widest: String = ""
		var widest_w: float = 0.0
		for c in page.find_children("*", "Control", true, false):
			var w: float = (c as Control).get_combined_minimum_size().x
			if w > widest_w and not c is Container:
				widest_w = w
				widest = "%s '%s'" % [c.get_class(), str(c.get("text")) if "text" in c else ""]
		assert_float(room).override_failure_message("premise: a phone leaves a step room") \
				.is_greater(200.0)
		assert_float(width).override_failure_message(
				"%s is %.0f px wide against %.0f px of room; widest leaf %s %.0f px"
				% [(panel as Node).get_script().resource_path.get_file(), width, room, widest,
				widest_w]).is_less_equal(room)
