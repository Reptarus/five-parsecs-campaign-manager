## Pins what the ENLIST RESULT SCREEN says, not what the service returns.
##
## attempt_enlistment has two shapes and they mean opposite things:
##   refused before rolling -> {success, roll: 0, target, reason}   (no `dice`)
##   rolled and missed      -> {success, roll, dice, combat_bonus, patron_bonus, ...}
##
## CharacterTransferPanel rendered BOTH as a roll, so the missing keys fell to
## their .get() defaults and the refusal printed
##   "Dice: [0] + [0] + Combat Skill 0 = 0  (needed 7+)"
## -- a roll that never happened, with the real reason discarded and p.212's
## Story Point rescue offered for a refusal the book does not let a Story Point
## buy. Measured on the tablet 2026-09-22, where a case-sensitive status gate
## refused every healthy 5PFH character and this line was all the player saw.
##
## The service-side suite (test_character_transfer_hub.gd) asserts the two shapes
## differ. Only this suite asserts the SCREEN tells them apart, which is where
## the damage landed.
extends GdUnitTestSuite

const PanelScript := preload("res://src/ui/screens/bug_hunt/panels/CharacterTransferPanel.gd")
const ServiceScript := preload("res://src/core/character/CharacterTransferService.gd")
const RealCharacter := preload("res://src/core/character/Character.gd")

var _panel: Node
var _svc


func before_test() -> void:
	_svc = ServiceScript.new()
	_panel = auto_free(PanelScript.new())
	# In the tree, because _scaled_font() resolves /root/ResponsiveManager by
	# absolute path and that ERRORS-and-aborts from a detached node.
	add_child(_panel)


func _character(combat: int, status: String = "") -> Dictionary:
	var c := RealCharacter.new()
	c.combat = combat
	if not status.is_empty():
		c.status = status
	return c.to_dictionary()


func _rendered_text() -> String:
	## Every Label the panel put on screen, joined. Walked by CLASS rather than by
	## node name: Godot discards a requested name that collides with a sibling.
	var out := PackedStringArray()
	var stack: Array = [_panel]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.is_queued_for_deletion():  # cleared, gone by the next frame
			continue
		if n is Label:
			out.append((n as Label).text)
		if n is Button:
			out.append((n as Button).text)
		for child in n.get_children():
			stack.append(child)
	return "
".join(out)


func test_a_refusal_prints_its_reason_instead_of_a_zero_roll() -> void:
	var refusal: Dictionary = _svc.attempt_enlistment(_character(2, "INJURED"))

	# Premise: this is the shape that has no dice. If the service ever starts
	# rolling for an ineligible character, this suite must say so rather than
	# quietly stop testing the branch it exists for.
	assert_bool(refusal.has("dice")).override_failure_message(
		"PREMISE: a refusal now carries dice, so this case no longer exercises the "
		+ "no-roll render path.").is_false()

	# As both callers do (_execute_transfer, _on_story_point_rescue): the result
	# replaces Step 1, which the panel now draws at _ready.
	_panel._clear_steps()
	_panel._show_enlistment_result(refusal)
	var screen := _rendered_text()

	assert_str(screen).override_failure_message(
		"The screen printed a roll for a character that never rolled:
" + screen
	).not_contains("Dice: [0] + [0]")
	assert_str(screen).contains(str(refusal.get("reason", "")))
	assert_str(screen).contains("CANNOT ENLIST")
	# p.212 grants the Story Point rescue for a FAILED ROLL. Offering it here
	# would invent a rule, and would promise a bypass that cannot work.
	assert_str(screen).override_failure_message(
		"The refusal offered p.212's Story Point rescue, which applies to a failed "
		+ "roll, not to an ineligible character."
	).not_contains("Story Point")


func test_a_completed_roll_prints_the_dice_it_actually_rolled() -> void:
	var dm = get_tree().root.get_node_or_null("/root/DiceManager") if get_tree() else null
	assert_object(dm).is_not_null()
	dm.clear_forced_results("Enlistment: die 1")
	dm.clear_forced_results("Enlistment: die 2")
	assert_bool(dm.queue_forced_result("Enlistment: die 1", 1)).override_failure_message(
		"PREMISE: the QA forcing seam refused the queue, so the dice below are "
		+ "random and this case cannot discriminate.").is_true()
	assert_bool(dm.queue_forced_result("Enlistment: die 2", 1)).is_true()

	var rolled: Dictionary = _svc.attempt_enlistment(_character(2))
	assert_array(rolled.get("dice", [])).is_equal([1, 1])

	_panel._clear_steps()
	_panel._show_enlistment_result(rolled)
	var screen := _rendered_text()

	assert_str(screen).override_failure_message(
		"A real roll must print the dice that were rolled:
" + screen
	).contains("Dice: [1] + [1] + Combat Skill 2")
	# "REJECTED" is the roll-happened wording; "CANNOT ENLIST" is the refusal.
	assert_str(screen).contains("ENLISTMENT REJECTED")
	assert_str(screen).not_contains("CANNOT ENLIST")

	dm.clear_forced_results("Enlistment: die 1")
	dm.clear_forced_results("Enlistment: die 2")
