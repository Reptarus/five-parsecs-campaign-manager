extends GdUnitTestSuite
## Compendium p.111 Faction jobs, delivered as the book prints them.
##
## "Select a Faction you would like to work for and roll 1D6. If the roll is equal to
## or below the Influence score of the Faction, they have a job available... Faction
## jobs are treated as a Patron job, but do not roll for Danger Pay or Benefits.
## Factions only ask if there is a serious need: Add 1 additional standard opponent
## to the enemy force you will face."
##
## Measured on 2026-10-29 before the fix: the job was a dict FactionSystem invented
## (a 1-5 difficulty, Influence x 500 credits, a per-type "bonus") and appended to
## the offers without the Patron builder, so it had no Time Frame, Hazards or
## Conditions; nothing added the extra opponent; and the D6 re-rolled every time the
## job step was shown, so leaving the step and coming back fished for a job.

const FactionSystemScript = preload("res://src/core/systems/FactionSystem.gd")
const JobOfferScript = preload("res://src/ui/screens/world/components/JobOfferComponent.gd")
const EnemyGeneratorScript = preload("res://src/core/systems/EnemyGenerator.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const SaveDirGuard = preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _prior_campaign: Resource = null
var _user_state: Dictionary = {}
var _saved_flag: bool = false
var _sys: Node


func _dlc() -> Node:
	return get_node_or_null("/root/DLCManager")


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_prior_campaign = GameState.current_campaign
	var c = CampaignCore.new()
	c.from_dictionary({"campaign_id": "faction_jobs_suite"})
	c.progress_data["turns_played"] = 4
	GameState.current_campaign = c
	var dlc: Node = _dlc()
	if dlc:
		_saved_flag = dlc.is_feature_enabled(dlc.ContentFlag.EXPANDED_FACTIONS)
		dlc.set_feature_enabled(dlc.ContentFlag.EXPANDED_FACTIONS, true)
	_sys = auto_free(FactionSystemScript.new())
	add_child(_sys)
	_sys.active_factions = {"f1": {"name": "Iron Hand", "influence": 6, "power": 3}}


func after_test() -> void:
	for key in ["Faction Job Check", "D10 Roll", "Enemy Count", "Unique Individual: die"]:
		DiceManager.clear_forced_results(key)
	var dlc: Node = _dlc()
	if dlc:
		dlc.set_feature_enabled(dlc.ContentFlag.EXPANDED_FACTIONS, _saved_flag)
	GameState.current_campaign = _prior_campaign
	SaveDirGuard.restore(_user_state)


func _offer(faction_job: Dictionary) -> Dictionary:
	var comp = auto_free(JobOfferScript.new())
	add_child(comp)
	return comp._faction_job_offer(faction_job, "Somewhere")


func test_a_faction_job_says_who_is_asking_and_invents_nothing() -> void:
	var offers: Array = _sys.get_faction_mission_opportunities()
	assert_int(offers.size()).is_equal(1)
	var o: Dictionary = offers[0]
	assert_str(str(o.get("faction_id", ""))).is_equal("f1")
	assert_str(str(o.get("faction_name", ""))).is_equal("Iron Hand")
	assert_str(str(o.get("mission_source", ""))).is_equal("faction")
	for key in ["difficulty", "rewards", "faction_bonus", "description"]:
		assert_bool(o.has(key)).override_failure_message(
			"'%s' is in neither book" % key).is_false()


func test_the_check_is_made_once_per_turn() -> void:
	_sys.active_factions["f1"]["influence"] = 3
	DiceManager.queue_forced_result("Faction Job Check", 6)  # above Influence 3: no job
	DiceManager.queue_forced_result("Faction Job Check", 1)  # would be a job
	assert_array(_sys.get_faction_mission_opportunities()).is_empty()
	assert_array(_sys.get_faction_mission_opportunities()).override_failure_message(
		"returning to the job step re-rolled the D6").is_empty()
	# A new turn is a new check.
	GameState.current_campaign.progress_data["turns_played"] = 5
	assert_int(_sys.get_faction_mission_opportunities().size()).is_equal(1)
	# The verdict is saved with the campaign, so a reload cannot re-roll it either.
	var fresh = auto_free(FactionSystemScript.new())
	add_child(fresh)
	fresh.update_data(_sys.get_data())
	DiceManager.queue_forced_result("Faction Job Check", 6)
	assert_int(fresh.get_faction_mission_opportunities().size()).override_failure_message(
		"a reload re-rolled the turn's check").is_equal(1)


func test_a_faction_job_is_a_patron_job_without_danger_pay_or_benefits() -> void:
	# Every D10 a 10, on which a Patron job gets a Benefit, a Hazard and a Condition.
	for _i in 16:
		DiceManager.queue_forced_result("D10 Roll", 10)
	var job: Dictionary = _offer({"faction_id": "f1", "faction_name": "Iron Hand",
		"mission_source": "faction"})
	assert_str(str(job.get("mission_source", ""))).is_equal("faction")
	assert_int(int(job.get("danger_pay", -1))).override_failure_message(
		"p.111: a Faction job does not roll for Danger Pay").is_equal(0)
	assert_array(job.get("benefits", [])).override_failure_message(
		"p.111: a Faction job does not roll for Benefits").is_empty()
	assert_array(job.get("hazards", [])).override_failure_message(
		"treated as a Patron job, so Hazards are rolled").is_not_empty()
	assert_array(job.get("conditions", [])).is_not_empty()
	assert_str(str(job.get("time_frame", ""))).is_not_empty()
	assert_str(str(job.get("faction_id", ""))).is_equal("f1")
	assert_bool(job.has("patron_id")).override_failure_message(
		"p.119 Step 2 would add the Faction as a Patron on a win").is_false()
	# p.115 Tensions rising is the only Danger Pay a Faction job carries.
	var tense: Dictionary = _offer({"faction_id": "f1", "faction_name": "Iron Hand",
		"mission_source": "faction", "tensions_rising_bonus": true})
	assert_int(int(tense.get("danger_pay", 0))).is_equal(1)


func test_a_faction_job_adds_one_standard_opponent() -> void:
	var counts := {}
	for source: String in ["patron", "faction"]:
		DiceManager.queue_forced_result("Enemy Count", 3)  # crew size 5: one D6
		for _i in 4:
			DiceManager.queue_forced_result("Unique Individual: die", 1)
		var gen = EnemyGeneratorScript.new()
		counts[source] = (gen.generate_enemies_as_dicts(
			{"mission_source": source, "enemy_type": "Gangers"}, 5) as Array).size()
		DiceManager.clear_forced_results("Unique Individual: die")
	assert_int(int(counts["faction"]) - int(counts["patron"])).override_failure_message(
		"p.111: 'Add 1 additional standard opponent' (patron %d, faction %d)"
		% [counts["patron"], counts["faction"]]).is_equal(1)


## The offer list runs inside screen code that reads the FactionSystem autoload, so
## the call is pinned. Comment lines are stripped so a docblock cannot satisfy it.
func test_the_job_step_builds_the_faction_job_on_the_patron_tables() -> void:
	var code := PackedStringArray()
	for line in FileAccess.get_file_as_string(
			"res://src/ui/screens/world/components/JobOfferComponent.gd").split("\n"):
		if not line.strip_edges().begins_with("#"):
			code.append(line)
	assert_str("\n".join(code)).contains(
		"missions.append(_faction_job_offer(faction_job, location))")
