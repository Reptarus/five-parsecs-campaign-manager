extends GdUnitTestSuite
## The battle objective panel shows the objective the battle tracks, and only that.
##
## Core Rules p.89: the objective is rolled once, before the battle
## (CampaignTurnController -> MissionTableManager), and BattleObjectiveTracker
## scores that one. The panel used to carry a free "Reroll" button that drew a new
## objective and displayed it while the tracker kept the original, so the screen
## showed one objective and scored another. It also labelled every battle
## "Mission Type: Opportunity", because nothing passed it the real type.

const PANEL := "res://src/ui/components/battle/ObjectiveDisplay.tscn"
const MissionObjectiveSystem = preload("res://src/core/battle/MissionObjectiveSystem.gd")

var _panel: Node


func before_test() -> void:
	_panel = auto_free(load(PANEL).instantiate())
	add_child(_panel)
	await await_idle_frame()


func _objective() -> Object:
	var obj = MissionObjectiveSystem.new().get_objective_by_id("FIGHT_OFF")
	assert_object(obj).is_not_null()
	return obj


func _button_texts() -> Array:
	var out: Array = []
	for child in _panel.get_node("VBox/ButtonContainer").get_children():
		if child is Button and not child.is_queued_for_deletion():
			out.append((child as Button).text)
	return out


func test_the_panel_offers_no_reroll() -> void:
	_panel.display_objective(_objective(), 0, "patron")
	var texts := _button_texts()
	# Premise: the button row was built, so an empty list cannot pass vacuously.
	assert_array(texts).contains(["Continue"])
	assert_array(texts).not_contains(["Reroll"])


func test_the_mission_type_label_names_the_real_type() -> void:
	var label: Label = _panel.get_node("VBox/MissionTypeLabel")
	_panel.display_objective(_objective(), 0, "patron")
	assert_bool(label.visible).is_true()
	assert_str(label.text).is_equal("Mission Type: Patron")
	# No type given: the label hides rather than claiming Opportunity.
	_panel.display_objective(_objective(), 0)
	assert_bool(label.visible).is_false()
