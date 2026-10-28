extends GdUnitTestSuite

## CharacterTransferPanel: touch scrolling (DU-12), the p.212 Story Point rescue
## (DU-13), and the backdrop row (DU-11) pinned and closed.
##
## ⚠ DU-12: the panel is code-built and opened from a dashboard button, so
## `test_touch_scroll_sweep` (which instantiates .tscn screens) could never reach it.
## This case asks it the sweep's own question: once populated, does
## `TouchScrollOpener.open_subtree()` still find STOP controls to open?
##
## ⚠ DU-13: p.212 "If the roll fails, 1 Story Point will get you in with any suitable
## explanation." The rejection screen printed that sentence with nothing to press. The
## point belongs to the SOURCE crew, whose save is on disk, so the case uses a real
## temporary save file (never one in user://saves/).

const PanelScript = preload("res://src/ui/screens/bug_hunt/panels/CharacterTransferPanel.gd")
const ServiceScript = preload("res://src/core/character/CharacterTransferService.gd")
const OpenerScript = preload("res://src/ui/components/common/TouchScrollOpener.gd")
const PROBE_SAVE := "user://du13_transfer_probe.json"

var _dm: Node


func before_test() -> void:
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")


func after_test() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var p: String = ProjectSettings.globalize_path(PROBE_SAVE + suffix)
		if FileAccess.file_exists(PROBE_SAVE + suffix):
			DirAccess.remove_absolute(p)


func _recruit(id: String) -> Dictionary:
	return {"id": id, "character_id": id, "name": "Rook " + id,
		"character_name": "Rook " + id, "combat": 0, "status": "ACTIVE",
		"game_mode": "standard"}


func _panel() -> Control:
	var panel: Control = PanelScript.new()
	add_child(panel)
	auto_free(panel)
	return panel


func _write_save(story_points: int, difficulty: int) -> void:
	var f := FileAccess.open(PROBE_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"config": {"difficulty": difficulty},
		"resources": {"story_points": story_points},
		"crew": {"members": [_recruit("r1")]},
	}))
	f.close()


func _fail_the_roll(panel: Control) -> void:
	panel.load_characters_from_array([_recruit("r1")])
	panel._source_save_path = PROBE_SAVE
	panel._selected_character = _recruit("r1")
	panel.set_direction("enlist")
	_dm.queue_forced_result("Bug Hunt Enlistment: die 1", 1)
	_dm.queue_forced_result("Bug Hunt Enlistment: die 2", 1)
	panel._execute_transfer()


func _rescue_button(panel: Control) -> Button:
	for n in panel.find_children("*", "Button", true, false):
		if (n as Button).text.begins_with("Spend 1 Story Point"):
			return n
	return null


# ── DU-11: pinned, and closed as a false lead ────────────────────────────────────

## The 0.95 backdrop is the overlay convention shared with PlanetfallCharacterImportPanel,
## PlanetfallDashboard and TacticsVeteranImportPanel, and a ColorRect's default STOP
## filter is what keeps a tap from reaching the dashboard underneath.
func test_the_backdrop_is_near_opaque_and_blocks_the_screen_behind() -> void:
	var bg: ColorRect = _panel().get_child(0) as ColorRect
	assert_object(bg).is_not_null()
	assert_float(bg.color.a).is_greater_equal(0.9)
	assert_int(bg.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


# ── DU-12: a finger drag reaches the scroll ──────────────────────────────────────

func test_a_populated_panel_leaves_nothing_to_swallow_a_drag() -> void:
	var panel := _panel()
	panel.load_characters_from_array([_recruit("r1"), _recruit("r2")])
	await get_tree().process_frame
	assert_int(panel._step_container.get_child_count()) \
		.override_failure_message("premise: step 1 built its character list").is_greater(0)
	assert_int(OpenerScript.open_subtree(panel._content)) \
		.override_failure_message("STOP controls still stand between a finger and the scroll") \
		.is_equal(0)


# ── DU-13: the p.212 Story Point rescue ──────────────────────────────────────────

func test_a_failed_roll_can_be_bought_with_a_story_point() -> void:
	_write_save(2, 2)
	var panel := _panel()
	var committed: Array = []
	panel.character_transferred.connect(
		func(p: Dictionary, _d: String) -> void: committed.append(p))
	_fail_the_roll(panel)
	assert_array(committed).override_failure_message("premise: the forced roll failed") \
		.is_empty()
	var rescue := _rescue_button(panel)
	assert_object(rescue).is_not_null()
	rescue.pressed.emit()
	assert_int(committed.size()).is_equal(1)
	assert_int(ServiceScript.story_points_in_save(PROBE_SAVE)) \
		.override_failure_message("the point is spent from the SOURCE crew's save") \
		.is_equal(1)


func test_no_rescue_where_story_points_are_off() -> void:
	_write_save(2, GlobalEnums.DifficultyLevel.INSANITY)
	var panel := _panel()
	_fail_the_roll(panel)
	assert_object(_rescue_button(panel)).override_failure_message(
		"Insanity switches Story Points off (Core Rules p.65)").is_null()
