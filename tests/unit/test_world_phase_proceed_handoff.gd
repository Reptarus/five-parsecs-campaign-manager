extends GdUnitTestSuite
## UX-1: completing Mission Prep hands the player to Proceed to Battle.
##
## The prep button used to read "Ready for Battle". It only completes the step; the
## battle is launched by Proceed to Battle in the footer, which appears below the
## fold on a tablet. The two read as one control, and the Aug 14 tablet sprint lost
## three runs waiting on the wrong one. The button now says what it does, and
## completing the step moves focus to Proceed.

const SCENE := "res://src/ui/screens/world/WorldPhaseController.tscn"


func _screen() -> Node:
	var inst: Node = (load(SCENE) as PackedScene).instantiate()
	add_child(inst)
	auto_free(inst)
	return inst


func test_the_prep_button_names_what_it_does() -> void:
	var inst := _screen()
	await get_tree().process_frame
	var btn: Button = inst.mission_prep_component.find_child("ReadyForBattleButton", true, false)
	assert_object(btn).is_not_null()
	assert_str(btn.text).is_equal("Confirm Crew & Gear")
	assert_str(btn.tooltip_text).contains("Proceed to Battle")


func test_completing_prep_puts_focus_on_proceed_to_battle() -> void:
	var inst := _screen()
	await get_tree().process_frame
	await get_tree().process_frame
	inst.automation_enabled = false
	inst.current_step = inst.WorldPhaseStep.MISSION_PREP
	inst.mission_prep_component.prep_completed = true
	var proceed: Button = inst.proceed_to_battle_button
	assert_object(proceed).is_not_null()
	# The premise: before the step completes, nothing has handed Proceed the focus.
	assert_bool(proceed.has_focus()).is_false()
	inst._on_mission_prepared({})
	await get_tree().process_frame
	assert_bool(proceed.is_visible_in_tree()).override_failure_message(
		"Proceed to Battle is not shown after Mission Prep completes").is_true()
	assert_bool(proceed.has_focus()).override_failure_message(
		"completing Mission Prep left the player on the prep button").is_true()
