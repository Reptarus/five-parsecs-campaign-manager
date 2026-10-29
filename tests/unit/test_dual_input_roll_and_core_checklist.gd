extends GdUnitTestSuite
## The Core Rules pre-battle checklist, and the dice row it used to carry.
##
## The checklist offered a "Roll d100" beside the p.88 Deployment Condition and
## p.89 Notable Sight steps, both already rolled before the battle and shown on
## the Battle Card, so a player could roll them a second time and get a different
## answer. Its Seize the Initiative step taught an invented rule, "Roll 1d6. On a
## 6 ... (Core Rules p.38)". p.112 is 2D6 plus the crew's highest Savvy, 10+, and
## the battle screen already opens that roll with the campaign's modifiers.
##
## The dice row (DualInputRoll) also rolled a raw randi_range(), so no QA seam
## could force it, and as an HBoxContainer its minimum width was the sum of its
## parts: the widest thing in the battle modal, past a phone's edge.

const ChecklistScript = preload("res://src/ui/components/battle/PreBattleChecklist.gd")
const DualInputRoll = preload("res://src/ui/components/battle/DualInputRoll.gd")

var _dm: Node


func before_test() -> void:
	_dm = get_node("/root/DiceManager")
	_dm.clear_forced_results()


func after_test() -> void:
	_dm.clear_forced_results()


func _item(id: String) -> Dictionary:
	for item: Dictionary in ChecklistScript.CHECKLIST_ITEMS:
		if str(item.id) == id:
			return item
	return {}


func test_no_core_step_rolls_a_table_the_campaign_already_rolled() -> void:
	for id: String in ["deployment_conditions", "notable_sighting", "seize_initiative"]:
		var item := _item(id)
		assert_bool(item.is_empty()).override_failure_message("no '%s' step" % id).is_false()
		assert_bool(item.has("dice_type")).override_failure_message(
			"'%s' still offers its own die" % id).is_false()
	assert_str(str(_item("deployment_conditions").hint)).contains("p.88")
	assert_str(str(_item("notable_sighting").hint)).contains("p.89")


func test_the_seize_step_states_the_p112_rule() -> void:
	var hint := str(_item("seize_initiative").hint)
	assert_str(hint).contains("2D6")
	assert_str(hint).contains("Savvy")
	assert_str(hint).contains("10+")
	assert_str(hint).contains("p.112")
	assert_str(hint).not_contains("1d6")
	assert_str(hint).not_contains("p.38")


func test_the_rendered_core_checklist_has_no_dice_row() -> void:
	var cl: Node = auto_free(ChecklistScript.new())
	add_child(cl)
	await await_idle_frame()
	cl.set_tier(1)
	# Premise: the tier-1 steps rendered, so "no dice row" cannot pass on an empty list.
	assert_int(cl.get_item_count()).is_greater(3)
	assert_array(cl.find_children("*", "HFlowContainer", true, false).filter(
		func(n: Node) -> bool: return n.get_script() == DualInputRoll)).is_empty()


func _roller(dice: String, label: String = "") -> Node:
	var r: Node = auto_free(DualInputRoll.new())
	r.dice_type = dice
	r.context_label = label
	add_child(r)
	return r


func test_a_companion_roll_can_be_forced() -> void:
	var r := _roller("d6")
	for value: int in [2, 5]:
		_dm.queue_forced_result("Companion Roll", value)
		r._on_roll_pressed()
		assert_int(r.get_last_result()).is_equal(value)
	var two := _roller("2d6")
	_dm.queue_forced_result("Companion Roll", 11)
	two._on_roll_pressed()
	assert_int(two.get_last_result()).is_equal(11)


func test_the_roll_row_wraps_instead_of_setting_its_width() -> void:
	var r := _roller("d100", "Check for Notable Sighting")
	await await_idle_frame()
	var sum := 0.0
	for child in r.get_children():
		if child is Control and (child as Control).visible:
			sum += (child as Control).get_combined_minimum_size().x
	# Premise: at least the label and the two buttons are showing.
	assert_float(sum).is_greater(0.0)
	# A row's minimum is the sum of its parts; a flow's is its widest part.
	assert_float(r.get_combined_minimum_size().x).is_less(sum)
