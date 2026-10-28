extends GdUnitTestSuite

## Bug Hunt creation wizard — Compendium p.170 squad size, and the order in which the
## new campaign is registered and seeded.
##
## CR-1  generate_squad() stopped at 4, and only a TYPED 4th name produced a 4th
##       character. p.170: "You could increase the number of main characters to four
##       or even five".
## CR-2  finalize() wrote the squad's Reputation through GameStateManager, which
##       writes to GameState.current_campaign, BEFORE registering the new campaign.
##       The write landed on the previous campaign and the new squad started at 0.
## CR-5  The Review step kept its own validation copy with no upper bound.

const CharGen = preload("res://src/core/character/BugHuntCharacterGeneration.gd")
const Coordinator = preload("res://src/ui/screens/bug_hunt/BugHuntCreationCoordinator.gd")
const SquadPanel = preload("res://src/ui/screens/bug_hunt/panels/BugHuntSquadPanel.gd")
const ReviewPanel = preload("res://src/ui/screens/bug_hunt/panels/BugHuntReviewPanel.gd")
const CoreScript = preload("res://src/game/campaign/BugHuntCampaignCore.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _user_state: Dictionary = {}
var _saved_campaign: Variant = null


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	var gs: Node = get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null


func after_test() -> void:
	var gs: Node = get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	_saved_campaign = null
	SaveDirGuard.restore(_user_state)
	_user_state = {}


func _coordinator() -> Node:
	var c: Node = Coordinator.new()
	add_child(c)
	auto_free(c)
	return c


func test_generate_squad_honours_the_p170_sizes() -> void:
	var gen = CharGen.new()
	for n in [3, 4, 5]:
		assert_int((gen.generate_squad([], n).main_characters as Array).size()).is_equal(n)
	assert_int((gen.generate_squad([], 6).main_characters as Array).size()) \
		.override_failure_message("p.170 stops at five").is_equal(5)
	# Existing callers pass names only: the name count still drives the size.
	assert_int((gen.generate_squad([]).main_characters as Array).size()).is_equal(3)
	assert_int((gen.generate_squad(["A", "B", "C", "D"]).main_characters as Array).size()) \
		.is_equal(4)


## The picker is what reaches the generator. A helper that accepts a count is not a
## fix until the screen passes one.
func test_the_squad_panel_generates_five_when_five_is_picked() -> void:
	var coord := _coordinator()
	var panel: Control = SquadPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.set_coordinator(coord)
	panel._size_option.select(2)
	assert_int(panel._size_option.get_selected_id()).is_equal(5)
	panel._on_generate_squad()
	assert_int((panel._squad_data.main_characters as Array).size()) \
		.override_failure_message("p.170: picking 5 must field 5 main characters") \
		.is_equal(5)


func test_build_campaign_seeds_reputation_on_the_new_campaign_not_the_previous_one() -> void:
	var gs: Node = get_tree().root.get_node_or_null("/root/GameState")
	assert_object(gs).override_failure_message("the case needs the GameState autoload") \
		.is_not_null()
	var previous = CoreScript.new()
	previous.campaign_name = "Previous"
	previous.reputation = 7
	gs.current_campaign = previous
	var coord := _coordinator()
	var squad: Dictionary = CharGen.new().generate_squad(["A", "B", "C"])
	squad["total_reputation"] = 3
	var built = coord.build_campaign({
		"config": {"campaign_name": "New Squad", "difficulty": "mess_me_up"},
		"squad": squad, "equipment": {}})
	assert_int(int(built.reputation)) \
		.override_failure_message("the squad's Reputation must land on the NEW campaign") \
		.is_equal(3)
	assert_int(int(previous.reputation)) \
		.override_failure_message("the previous campaign's Reputation was overwritten") \
		.is_equal(7)
	assert_object(gs.current_campaign).is_same(built)


func test_the_review_step_rejects_a_six_character_squad() -> void:
	var panel: Control = ReviewPanel.new()
	auto_free(panel)
	var errors: Array = panel._get_validation_errors({"campaign_name": "X"}, [1, 2, 3, 4, 5, 6])
	assert_bool(str(errors).contains("caps at 5")) \
		.override_failure_message("p.170 caps the squad at 5: %s" % str(errors)).is_true()
	assert_array(panel._get_validation_errors({"campaign_name": "X"}, [1, 2, 3, 4, 5])) \
		.is_empty()
