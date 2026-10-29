extends GdUnitTestSuite
## Compendium p.34 Fickle Scans: "Any Notable Sight that has not been investigated
## by the end of Round 3 is removed from play."
##
## The check named the sight from a "name" key the rolled sight never carries
## (MissionTableManager.roll_notable_sight writes type, effect and roll), so the
## log always read "the Notable Sight (unknown)". It also set a removal flag that
## nothing read, so the sight's marker stayed on the map for the rest of the battle.

const TBUI := preload("res://src/ui/screens/battle/TacticalBattleUI.gd")
const MapView := preload("res://src/ui/components/battle/BattlefieldMapView.gd")
const Toggles := preload("res://src/data/compendium_difficulty_toggles.gd")

const CENTER := {"type": "center", "grid_pos": Vector2i(8, 8), "label": "Objective"}
const SIGHT_MARKER := {"type": "notable_sight", "grid_pos": Vector2i(3, 4),
	"label": "Sight: Loot Cache"}

var _owned: Dictionary = {}
var _flags: Dictionary = {}


func before_test() -> void:
	var dlc := get_node("/root/DLCManager")
	_owned = dlc._owned_dlcs.duplicate()
	_flags = dlc._enabled_flags.duplicate()
	# In memory only: set_dlc_owned() would write user://dlc_ownership.cfg.
	dlc._owned_dlcs["freelancers_handbook"] = true
	dlc._enabled_flags[dlc.ContentFlag.DIFFICULTY_TOGGLES] = true
	Toggles.set_creation_toggles(["fickle_scans"])


func after_test() -> void:
	Toggles.clear_creation_toggles()
	var dlc := get_node("/root/DLCManager")
	dlc._owned_dlcs = _owned
	dlc._enabled_flags = _flags


## A battle screen that never enters the tree, so _ready() builds nothing; the
## log falls back to battle_log and the map is a bare BattlefieldMapView.
func _battle(sight: Dictionary) -> Node:
	var ui: Node = auto_free(TBUI.new())
	ui.battle_log = auto_free(RichTextLabel.new())
	ui.battlefield_grid_panel = auto_free(MapView.new())
	ui._stored_mission_data = {"notable_sight": sight}
	ui.battlefield_grid_panel.set_objective_positions([CENTER, SIGHT_MARKER])
	return ui


func _markers(ui: Node, type: String) -> int:
	var n := 0
	for m: Dictionary in ui.battlefield_grid_panel.get_objective_positions():
		if str(m.get("type", "")) == type:
			n += 1
	return n


func test_the_sight_is_named_and_its_marker_leaves_the_map() -> void:
	# Premise: the option is on, so a silent check cannot pass for the wrong reason.
	assert_bool(Toggles.is_toggle_active("fickle_scans")).is_true()
	var ui := _battle({"type": "LOOT_CACHE", "effect": "Roll on the Loot table.", "roll": 50})
	assert_int(_markers(ui, "notable_sight")).is_equal(1)
	ui._check_fickle_scans(3)
	var log_text: String = ui.battle_log.get_parsed_text()
	assert_str(log_text).contains("Notable Sight (Loot Cache)")
	assert_str(log_text).not_contains("unknown")
	assert_int(_markers(ui, "notable_sight")).is_equal(0)
	assert_int(_markers(ui, "center")).is_equal(1)
	# A rebuild of the markers (a regenerate, or a resumed battle) keeps it off.
	ui._set_map_objectives([CENTER, SIGHT_MARKER])
	assert_int(_markers(ui, "notable_sight")).is_equal(0)


func test_a_battle_with_no_sight_announces_nothing() -> void:
	assert_bool(Toggles.is_toggle_active("fickle_scans")).is_true()
	var ui := _battle({"type": "NOTHING", "effect": "Nothing special.", "roll": 5})
	ui._check_fickle_scans(3)
	assert_str(ui.battle_log.get_parsed_text()).is_empty()
	assert_bool(bool(ui._stored_mission_data.get("notable_sight_removed", false))).is_false()
