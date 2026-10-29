extends GdUnitTestSuite
## The creation screen offers the Compendium pp.32-34 Difficulty Toggles.
##
## Every rule site reads is_toggle_active(), and the campaign's selection travels
## panel -> coordinator -> finalization -> progress_data["difficulty_toggles"]. The
## one thing missing was a screen that OFFERS the options: ExpandedConfigPanel's
## builder had no caller, the Expansion Features card switches only the pack, and
## the Settings panel writes the no-campaign fallback file. So no campaign could
## switch on a single option. These cases build the real panel and read what a
## player is offered and what the coordinator is handed.
##
## The pack is flipped in memory only: set_dlc_owned() persists, and switching a
## pack off through it disables every flag that pack carries.

const PanelScene = preload("res://src/ui/screens/campaign/panels/ExpandedConfigPanel.tscn")
const Toggles = preload("res://src/data/compendium_difficulty_toggles.gd")
const SaveDirGuard = preload("res://tests/fixtures/helpers/save_dir_guard.gd")

const ALL_TOGGLE_IDS := [
	"strength_adjusted", "slaves_to_stargrind_money",
	"slaves_to_stargrind_progression", "veteran", "actually_specialized",
	"armored_leaders", "better_leadership", "paying_by_hour",
	"movement_all_over", "fickle_scans", "starting_gutter", "reduced_lethality",
]

var _snap: Dictionary = {}
var _owned: Dictionary = {}
var _flags: Dictionary = {}


func before_test() -> void:
	_snap = SaveDirGuard.snapshot()
	var dlc := get_node("/root/DLCManager")
	_owned = dlc._owned_dlcs.duplicate()
	_flags = dlc._enabled_flags.duplicate()


func after_test() -> void:
	var dlc := get_node("/root/DLCManager")
	dlc._owned_dlcs = _owned
	dlc._enabled_flags = _flags
	Toggles.clear_creation_toggles()
	SaveDirGuard.restore(_snap)


func _set_pack(on: bool) -> void:
	var dlc := get_node("/root/DLCManager")
	dlc._owned_dlcs["freelancers_handbook"] = true
	dlc._enabled_flags[dlc.ContentFlag.DIFFICULTY_TOGGLES] = on


func _panel() -> Node:
	var p: Node = auto_free(PanelScene.instantiate())
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	return p


func _texts(node: Node) -> String:
	var out := ""
	if node is Label:
		out += (node as Label).text + "\n"
	for child in node.get_children():
		out += _texts(child)
	return out


func test_the_creation_screen_offers_all_twelve_options() -> void:
	_set_pack(true)
	var panel: Node = await _panel()
	var offered: Array = panel.difficulty_toggle_checkboxes.keys()
	offered.sort()
	var expected: Array = ALL_TOGGLE_IDS.duplicate()
	expected.sort()
	assert_array(offered).is_equal(expected)
	# Each one is a real control on the screen, not only a dictionary entry.
	for id: String in ALL_TOGGLE_IDS:
		var cb: CheckBox = panel.difficulty_toggle_checkboxes[id]
		assert_bool(cb.is_inside_tree()).is_true()


func test_a_ticked_option_reaches_the_config_the_coordinator_reads() -> void:
	_set_pack(true)
	var panel: Node = await _panel()
	var cb: CheckBox = panel.difficulty_toggle_checkboxes["veteran"]
	cb.button_pressed = true
	var cfg: Dictionary = panel.get_campaign_config_data()
	assert_array(cfg.get("difficulty_toggles", [])).contains(["veteran"])
	cb.button_pressed = false
	assert_array(panel.get_campaign_config_data().get("difficulty_toggles", [])).not_contains(["veteran"])


func test_the_options_appear_when_the_pack_is_switched_on() -> void:
	_set_pack(false)
	var panel: Node = await _panel()
	assert_int(panel.difficulty_toggle_checkboxes.size()).is_equal(0)
	assert_str(_texts(panel)).contains("Switch on \"Difficulty Toggles\" under Expansion Features")
	_set_pack(true)
	panel._on_expansion_flags_changed({})
	assert_int(panel.difficulty_toggle_checkboxes.size()).is_equal(12)
	# A choice survives the pack being switched off and on again.
	panel.difficulty_toggle_checkboxes["fickle_scans"].button_pressed = true
	_set_pack(false)
	panel._on_expansion_flags_changed({})
	_set_pack(true)
	panel._on_expansion_flags_changed({})
	assert_bool(panel.difficulty_toggle_checkboxes["fickle_scans"].button_pressed).is_true()


func test_the_two_time_pressure_options_carry_the_books_names() -> void:
	# Compendium p.34 prints "They are Paying us by the Hour" and "There's Movement
	# all over the Place"; the battle screen already used these, the picker did not.
	_set_pack(true)
	var names: Dictionary = {}
	for t: Dictionary in Toggles.get_difficulty_toggles():
		names[str(t.get("id"))] = str(t.get("name"))
	assert_str(names.get("paying_by_hour", "")).is_equal("They are Paying us by the Hour")
	assert_str(names.get("movement_all_over", "")).is_equal("There's Movement all over the Place")
