extends GdUnitTestSuite

## Planetfall tutorial-missions panel (Planetfall pp.44-45).
##
## Two things these pin, both of which were broken:
##  1. data/planetfall/tutorial_missions.json had ZERO loaders repo-wide. The
##     panel hardcoded a one-line blurb per mission, so the book's setup text,
##     objectives, table sizes and "teaches" notes never reached the player.
##  2. `analysis_all_six` was read by PlanetfallCreationCoordinator (3 RP instead
##     of 2) and written by NOTHING, so that reward tier was unreachable.

const PanelScript = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallTutorialPanel.gd")

const DATA_PATH := "res://data/planetfall/tutorial_missions.json"


func test_tutorial_mission_data_file_loads() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var json := JSON.new()
	assert_int(json.parse(file.get_as_text())).is_equal(OK)
	var data: Dictionary = json.get_data()
	var missions: Array = data.get("missions", [])
	assert_int(missions.size()).is_equal(3)


func test_panel_reads_missions_from_the_book_data() -> void:
	var panel = auto_free(PanelScript.new())
	add_child(panel)
	var missions: Array = panel._load_missions()
	assert_int(missions.size()).is_equal(3)
	# The rich fields the hardcoded blurbs dropped.
	var first: Dictionary = missions[0]
	assert_str(str(first.get("id", ""))).is_equal("beacons")
	assert_bool(str(first.get("setup", "")).is_empty()).is_false()
	assert_bool(str(first.get("objective", "")).is_empty()).is_false()
	assert_bool(str(first.get("teaches", "")).is_empty()).is_false()


func test_analysis_all_six_bonus_is_reachable() -> void:
	## Planetfall p.45: "2 Research Points (3 if all 6 Contacts revealed)".
	var panel = auto_free(PanelScript.new())
	add_child(panel)
	# The checkbox only renders for a mission whose reward declares bonus_all_six.
	var boxes: Array = panel.find_children("*", "CheckBox", true, false)
	assert_int(boxes.size()).is_greater_equal(1)

	assert_bool(panel._results.get("analysis_all_six", true)).is_false()
	panel._on_all_six_toggled(true)
	assert_bool(panel._results.get("analysis_all_six", false)).is_true()


func test_mission_result_records_success_per_mission() -> void:
	var panel = auto_free(PanelScript.new())
	add_child(panel)
	panel._on_mission_result("perimeter", "perimeter_success", true)
	assert_bool(panel._results["missions"].get("perimeter", false)).is_true()
	assert_bool(panel._results.get("perimeter_success", false)).is_true()
