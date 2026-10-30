extends GdUnitTestSuite
## Sprint 7b BS1: a Bug Hunt battle's Reference tab prints the Bug Hunt battle rules.
##
## THE DEFECT THIS PINS. TacticalBattleUI chose the Reference sheet with
## `"planetfall" if _is_planetfall_mode else "core"`, so a Bug Hunt battle got the Core
## Rules sheet: Morale (p.114) where Bug Hunt p.200 says "there is no morale system",
## the natural-6 casualty, the 5PFH weapon table instead of the fifteen on p.179, and a
## failed save that still Stuns where p.178 knocks the trooper back instead.
##
## Also pinned here: the panel parses a section's BBCode only when it is first opened,
## and a battle that switches mode in the same frame never builds the Core Rules nodes
## (Godot docs: assigning RichTextLabel.text parses the whole string; every node costs).

const TacticalBattleScene := preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")
const PanelScript := preload("res://src/ui/components/battle/CheatSheetPanel.gd")
const Sections := preload("res://src/ui/components/battle/CheatSheetSections.gd")
const CoreScript := preload("res://src/game/campaign/BugHuntCampaignCore.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const WEAPONS_PATH := "res://data/bug_hunt/bug_hunt_weapons.json"

var _user_state: Dictionary
var _saved_campaign: Variant
var _added_headers: PackedStringArray = []


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null
	_added_headers = []


func after_test() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


func _on_node_added(node: Node) -> void:
	if node is Button:
		_added_headers.append((node as Button).text)


func _titles(panel: Node) -> Array:
	var out: Array = []
	for s: Dictionary in panel._sections:
		out.append(str(s.get("title", "")))
	return out


func _section_text(panel: Node, title: String) -> String:
	for s: Dictionary in panel._sections:
		if str(s.get("title", "")) == title:
			return str(s.get("content", ""))
	return ""


func _all_text(sections: Array) -> String:
	var out := ""
	for s: Dictionary in sections:
		out += str(s.get("content", "")) + "\n"
	return out


## The call site: a real battle screen, started in Bug Hunt mode.
func test_a_bug_hunt_battle_reads_the_bug_hunt_rules() -> void:
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	var core = CoreScript.new()
	core.campaign_name = "Probe"
	gs.current_campaign = core
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	ui.initialize_battle([], [], {"battle_mode": "bug_hunt", "title": "Probe"})
	await get_tree().process_frame
	var sheet: Node = ui.cheat_sheet_panel
	assert_object(sheet).override_failure_message("premise: the Reference drawer exists") \
		.is_not_null()
	var titles := _titles(sheet)
	assert_array(titles).contains(["Battle Round (Bug Hunt p.198, p.173)",
		"Resolving Hits (Bug Hunt p.178)", "Enemy Movement (Bug Hunt p.200)",
		"Weapons (Bug Hunt p.179)"])
	assert_array(titles).not_contains(["Morale Rules (p.114)", "Turn Sequence (pp.112-113)",
		"Common Weapons (p.50)", "Damage & Armor (p.46)"])
	assert_str(sheet._title_label.text).is_equal("Bug Hunt Quick Reference")
	assert_str(_section_text(sheet, "Enemy Movement (Bug Hunt p.200)")) \
		.contains("there is no morale system in Bug Hunt")
	assert_str(_section_text(sheet, "Resolving Hits (Bug Hunt p.178)")) \
		.contains("Equal to Toughness: knocked back 1\" and Wounded") \
		.contains("the figure is not Stunned but is knocked back 1\"")


## p.179 as printed: fifteen weapons, and a dash wherever the page prints one.
func test_the_weapon_section_is_the_p179_table() -> void:
	var weapons := ""
	for s: Dictionary in Sections.bug_hunt_sections():
		if str(s.title) == "Weapons (Bug Hunt p.179)":
			weapons = str(s.content)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WEAPONS_PATH))
	assert_int((data.weapons as Array).size()).override_failure_message(
		"premise: p.179 lists fifteen weapons").is_equal(15)
	for w: Dictionary in data.weapons:
		assert_str(weapons).contains("[b]%s[/b]" % str(w.name))
	assert_str(weapons) \
		.contains("[b]Boarding Sword[/b]  Brawl | Shots – | Damage 0 | Melee") \
		.contains("[b]Power Claw[/b]  Brawl | Shots – | Damage 1 | Melee") \
		.contains("[b]Flash Grenade[/b]  6\" | Shots – | Damage – | Stun") \
		.contains("[b]Mounted Launcher[/b]  18\" | Shots – | Damage – | Launcher") \
		.contains("[b]Frag Grenade[/b]  6\" | Shots 2 | Damage 0 | Area") \
		.contains("[b]Incinerator[/b]  8\" | Shots 3 | Damage 1 | Focused, Area") \
		.contains("[b]Carbine[/b]  18\" | Shots 1 | Damage 0 | –") \
		.contains("[b]Overheat:[/b]")


## Nothing from the Core Rules sheet leaks into the Bug Hunt one.
func test_no_core_rule_reaches_the_bug_hunt_sheet() -> void:
	var text := _all_text(Sections.bug_hunt_sections())
	assert_str(text).is_not_empty()
	assert_str(text).not_contains("Panic range").not_contains("Bail") \
		.not_contains("Luck").not_contains("Seize the Initiative")


## The drawer goes between all three sheets and leaves nothing behind.
func test_the_drawer_switches_between_all_three_sheets() -> void:
	var sheet: Node = auto_free(PanelScript.new())
	add_child(sheet)
	await get_tree().process_frame
	var core_titles := _titles(sheet)
	for mode: String in ["bug_hunt", "planetfall", "bug_hunt", "core"]:
		sheet.set_rules_mode(mode)
		assert_int(sheet._section_bodies.size()).is_equal(_titles(sheet).size())
		assert_int(sheet._vbox.get_child_count()).is_equal(2 * _titles(sheet).size())
	assert_array(_titles(sheet)).is_equal(core_titles)
	assert_str(sheet._title_label.text).is_equal("Quick Reference")


## A section's BBCode is parsed when it is first opened, never before.
func test_a_section_is_parsed_only_when_opened() -> void:
	var sheet: Node = auto_free(PanelScript.new())
	add_child(sheet)
	sheet.set_rules_mode("bug_hunt")
	assert_bool(sheet._nodes_built).is_true()
	for body: RichTextLabel in sheet._section_bodies:
		assert_str(body.text).is_empty()
	sheet._toggle_section(0)
	var first: RichTextLabel = sheet._section_bodies[0]
	assert_bool(first.visible).is_true()
	assert_str(first.text).contains("Quick Action")
	var second: RichTextLabel = sheet._section_bodies[1]
	assert_str(second.text).is_empty()


## The battle screen switches mode in the same frame it adds the panel, so the Core
## Rules nodes must never be built at all. Only node_added can see a node that is
## created and freed within one frame.
func test_a_same_frame_mode_switch_never_builds_the_core_nodes() -> void:
	get_tree().node_added.connect(_on_node_added)
	var sheet: Node = auto_free(PanelScript.new())
	add_child(sheet)
	sheet.set_rules_mode("bug_hunt")
	await get_tree().process_frame
	get_tree().node_added.disconnect(_on_node_added)
	var joined := "\n".join(_added_headers)
	assert_str(joined).override_failure_message(
		"premise: the Bug Hunt headers were seen entering the tree").contains("Bug Hunt p.178")
	assert_str(joined).not_contains("Turn Sequence (pp.112-113)")
	assert_int(sheet._vbox.get_child_count()).is_equal(2 * _titles(sheet).size())


## A "This Battle" section stays on top, and still opens its own body, across a switch.
func test_the_battle_section_survives_a_mode_switch() -> void:
	var sheet: Node = auto_free(PanelScript.new())
	add_child(sheet)
	await get_tree().process_frame
	sheet.set_battle_context({"enemy_force": {"type": "Bugs", "count": 6}})
	sheet.set_rules_mode("bug_hunt")
	assert_bool(bool(sheet._sections[0].get("_is_battle", false))).is_true()
	assert_str(str(sheet._vbox.get_child(0).name)).is_equal("_battle_header")
	assert_int(sheet._section_bodies.size()).is_equal(_titles(sheet).size())
	assert_int(sheet._vbox.get_child_count()).is_equal(2 * _titles(sheet).size())
	(sheet._section_buttons[1] as Button).pressed.emit()
	assert_str((sheet._section_bodies[1] as RichTextLabel).text).contains("Quick Action")
