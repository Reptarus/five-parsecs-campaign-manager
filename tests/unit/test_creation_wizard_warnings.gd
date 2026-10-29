extends GdUnitTestSuite
## The creation wizard's step warnings must describe the player's campaign.
##
## Since T11-13 every non-blocking warning from
## CampaignCreationStateManager._validate_phase_with_warnings() is shown under the
## step title. Walking the wizard on a phone (Sprint U, 2026-10-29) showed four
## of them on a campaign that was set up correctly, each from a different cause:
##
##   - "Crew size not set - will use default of 4": the check read config.crew_size,
##     which nothing writes; the config step writes campaign_crew_size (p.63).
##   - "Captain combat stats need setting": the check was combat < 1, and Combat
##     Skill +0 is the Human baseline (Core Rules p.15).
##   - "Crew/Equipment not generated via backend system (using fallback)": the flag
##     they read, backend_generated, has no producer, so both fired every time and
##     described the implementation rather than the game.
##   - "World data not generated yet": update_world_state() never synced the world
##     to the StateManager, so its copy stayed {} after the player confirmed one.
##
## Each case asserts both directions where a real omission still exists: a
## warning that can never fire is as useless as one that always does.

const COORDINATOR := preload("res://src/ui/screens/campaign/CampaignCreationCoordinator.gd")
const SM := preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")


## In the tree: a detached Node cannot resolve /root/X lookups.
func _coordinator() -> Node:
	var c: Node = COORDINATOR.new()
	add_child(c)
	auto_free(c)
	return c


func _warnings(m, phase: int) -> String:
	var res: Dictionary = m._validate_phase_with_warnings(phase)
	return "\n".join(PackedStringArray(res.get("warnings", [])))


func test_the_config_steps_crew_size_does_not_warn() -> void:
	var c := _coordinator()
	c.update_campaign_config_state({"campaign_name": "Warnings"})
	# Premise: the size the rules read is really there.
	assert_int(int(c.state_manager.campaign_data["config"].get("campaign_crew_size", 0))) \
		.override_failure_message("the config step must carry campaign_crew_size (p.63)") \
		.is_greater(0)
	assert_str(_warnings(c.state_manager, SM.Phase.CONFIG)).override_failure_message(
		"a campaign whose crew size is set must not be told it is unset"
	).not_contains("Crew size")


func test_an_absent_crew_size_still_warns() -> void:
	var m = SM.new()
	m.set_phase_data(SM.Phase.CONFIG, {"campaign_name": "x", "difficulty_level": 2})
	assert_str(_warnings(m, SM.Phase.CONFIG)).contains("Crew size not set")


func test_a_combat_zero_captain_is_not_called_unset() -> void:
	var c := _coordinator()
	var cap := Character.new()
	cap.character_name = "Baseline"
	cap.combat = 0
	cap.toughness = 3
	c.update_captain_state({"captain": cap})
	# Premise: the captain dict carries combat 0 rather than omitting it.
	var cap_dict: Dictionary = c.state_manager.campaign_data["captain"]
	assert_bool(cap_dict.has("combat")).is_true()
	assert_int(int(cap_dict.get("combat", -1))).is_equal(0)
	assert_str(_warnings(c.state_manager, SM.Phase.CAPTAIN_CREATION)).override_failure_message(
		"Combat Skill +0 is the Human baseline (Core Rules p.15), not a missing stat"
	).not_contains("combat")


func test_a_captain_without_combat_still_warns() -> void:
	var m = SM.new()
	m.set_phase_data(SM.Phase.CAPTAIN_CREATION, {"character_name": "x", "toughness": 3})
	assert_str(_warnings(m, SM.Phase.CAPTAIN_CREATION)).contains("combat")


func test_no_step_talks_about_a_backend_fallback() -> void:
	var m = SM.new()
	m.set_phase_data(SM.Phase.CREW_SETUP, {
		"members": [{"character_name": "A"}], "size": 1, "has_captain": true})
	m.set_phase_data(SM.Phase.EQUIPMENT_GENERATION, {
		"equipment": ["Blade"], "is_complete": true})
	var text := _warnings(m, SM.Phase.CREW_SETUP) + "\n" \
		+ _warnings(m, SM.Phase.EQUIPMENT_GENERATION)
	assert_str(text).override_failure_message(
		"backend_generated has no producer, so these warnings fired every time"
	).not_contains("backend")


func test_a_generated_world_reaches_the_final_review_check() -> void:
	var c := _coordinator()
	c.update_world_state({"name": "Falkenhayn III", "traits": []})
	assert_bool((c.state_manager.campaign_data["world"] as Dictionary).is_empty()) \
		.override_failure_message("update_world_state() must sync the StateManager's world") \
		.is_false()
	assert_str(_warnings(c.state_manager, SM.Phase.WORLD_GENERATION)).not_contains(
		"World data not generated")


func test_an_ungenerated_world_still_warns() -> void:
	var m = SM.new()
	assert_str(_warnings(m, SM.Phase.WORLD_GENERATION)).contains("World data not generated")
