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


## Every creation step fits the width a phone gives it. Measured in place, in the real
## creation screen at a phone's design width (the screen's own 20 px side margins and
## the scrollbar both come off). The Initial Missions cards needed 322 px against ~290
## and ran off the right edge; a bare "page <= 338" bar (the roster suite's) passed it.
func test_every_creation_step_fits_a_phone() -> void:
	const PHONE := Vector2i(338, 734)
	var sv := SubViewport.new()
	sv.size = PHONE
	add_child(sv)
	auto_free(sv)
	var ui: Control = load("res://src/ui/screens/planetfall/PlanetfallCreationUI.tscn") \
		.instantiate()
	sv.add_child(ui)
	for _i in range(4):
		await get_tree().process_frame
	assert_int(ui.panels.size()).override_failure_message("premise: six steps") \
		.is_equal(6)
	var too_wide: Array[String] = []
	for i in range(ui.panels.size()):
		for p in ui.panels:
			(p as Control).visible = false
		var panel: Control = ui.panels[i]
		panel.visible = true
		panel.modulate.a = 1.0
		for _f in range(3):
			await get_tree().process_frame
		var scrolls: Array = panel.find_children("*", "ScrollContainer", true, false)
		if scrolls.is_empty():
			continue
		# ⚠ Measure against the SCREEN EDGE. A scroll whose horizontal axis is disabled
		# has already grown to its page's minimum, so "page <= scroll" holds however far
		# the page overflows (a first version of this case passed with the defect back:
		# need 318, room 318). Reverted, the scroll's right edge measured 346 on 338.
		var scroll: ScrollContainer = scrolls[0]
		var page: Control = scroll.get_child(0)
		var right: float = scroll.get_global_rect().end.x
		if right > float(PHONE.x) + 0.5:
			too_wide.append("step %d (%s): ends at %.0f on a %d px screen (page needs %.0f)"
				% [i + 1, panel.get_script().resource_path.get_file(), right, PHONE.x,
				page.get_combined_minimum_size().x])
	assert_float(float(ui.size.x)).override_failure_message(
		"premise: the screen was laid out at phone width").is_less_equal(PHONE.x)
	assert_array(too_wide).override_failure_message("steps wider than a phone: %s"
		% str(too_wide)).is_empty()


func test_mission_result_records_success_per_mission() -> void:
	var panel = auto_free(PanelScript.new())
	add_child(panel)
	panel._on_mission_result("perimeter", "perimeter_success", true)
	assert_bool(panel._results["missions"].get("perimeter", false)).is_true()
	assert_bool(panel._results.get("perimeter_success", false)).is_true()
