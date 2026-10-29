extends GdUnitTestSuite
## Core Rules p.70, starship travel event 13-17 Raided, after a failed intimidation:
##
##   "set up a battle in cramped territory, using the Criminal Elements Encounter
##    Table (p.94). Enemy numbers are determined by rolling 3D6, picking the highest
##    die (with campaign crew size 5, roll 2D6 and pick highest; with campaign crew
##    size 4, roll 1D6). Add the numbers indicated in the enemy table, +1 extra
##    figure. There is no objective. If you drive them off, they flee back to their
##    ship. If you lose, you lose all credits and everything in your Stash, though
##    you can keep the ship. If you win, you get the normal rewards for winning an
##    Opportunity mission (see p.120), plus a bonus roll on the Loot Table (p.131)."
##
## The travel event rolled the dice into `base_enemy_count` and stamped
## `enemy_category`, and nothing read either: the battle rolled the ordinary p.63
## dice on whatever table the opportunity column drew. The right dice sat in
## EnemyGenerator.calculate_raided_enemy_count(), called only by its tests. The
## loss and the bonus Loot roll were not applied anywhere.
##
## Every die is forced through DiceManager, and a case that forces one also checks
## the queue was consumed, so a roll that bypasses DiceManager cannot pass.

const EnemyGen = preload("res://src/core/systems/EnemyGenerator.gd")
const SetupRules = preload("res://src/core/battle/BattleSetupRules.gd")
const Resolver = preload("res://src/core/world/TravelEventResolver.gd")
const Normalizer = preload("res://src/core/battle/BattleResultNormalizer.gd")
const PaymentProc = preload("res://src/core/campaign/phases/post_battle/PaymentProcessor.gd")
const ContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const PostBattlePhaseScript = preload("res://src/core/campaign/phases/PostBattlePhase.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const SaveDirGuard = preload("res://tests/fixtures/helpers/save_dir_guard.gd")

const NORMAL := 2  # GlobalEnums.DifficultyLevel.NORMAL

var _snap: Dictionary = {}
var _prev_campaign = null


## Counts Loot Table rolls instead of making them.
class LootCounter extends "res://src/core/campaign/phases/post_battle/LootProcessor.gd":
	var rolls := 0
	func _roll_loot_table() -> Array[Dictionary]:
		rolls += 1
		return []


func before_test() -> void:
	_snap = SaveDirGuard.snapshot()
	_prev_campaign = get_node("/root/GameState").current_campaign
	# No campaign: the Strength-adjusted toggle and every campaign read fall back.
	get_node("/root/GameState").current_campaign = null


func after_test() -> void:
	get_node("/root/DiceManager").clear_forced_results()
	get_node("/root/GameState").current_campaign = _prev_campaign
	SaveDirGuard.restore(_snap)


func _force(key: String, values: Array) -> void:
	for v: int in values:
		assert_bool(get_node("/root/DiceManager").queue_forced_result(key, v)).is_true()


func _consumed(what: String) -> void:
	assert_dict(get_node("/root/DiceManager").get_forced_results()).override_failure_message(
		"a forced %s value was never consumed" % what).is_empty()


func _raid_campaign() -> Resource:
	var c: Resource = CampaignCore.new()
	c.credits = 12
	c.equipment_data = {"equipment": [
		{"id": "s1", "name": "Blade"}, {"id": "s2", "name": "Scrap Pistol"}]}
	c.crew_data = {"members": [{"character_id": "c1", "character_name": "Ana",
		"equipment": ["Colony Rifle"]}]}
	get_node("/root/GameState").current_campaign = c
	return c


func _loss_ctx(campaign: Resource, held_field: bool) -> RefCounted:
	var ctx: RefCounted = ContextClass.new()
	ctx.campaign = campaign
	ctx.game_state_manager = get_node("/root/GameStateManager")
	ctx.battle_result = {
		"setup_rules": SetupRules.compute({"travel_event_raid": true}, 6, 6),
		"held_field": held_field,
		"turn": 3,
	}
	return ctx


func test_the_dice_count_follows_the_campaign_crew_size() -> void:
	assert_int(EnemyGen.raided_dice_count(6)).is_equal(3)
	assert_int(EnemyGen.raided_dice_count(5)).is_equal(2)
	assert_int(EnemyGen.raided_dice_count(4)).is_equal(1)


func test_the_count_is_the_highest_die_plus_one_figure() -> void:
	var gen: Resource = EnemyGen.new()
	_force("Enemy Count", [2, 5, 3])
	assert_int(gen._calculate_enemy_count(NORMAL, 6, false, 0, true)).override_failure_message(
		"crew 6 raid: 3D6 pick highest (5) +1 figure").is_equal(6)
	_consumed("Enemy Count (crew 6)")
	_force("Enemy Count", [4, 1])
	assert_int(gen._calculate_enemy_count(NORMAL, 5, false, 0, true)).is_equal(5)
	_consumed("Enemy Count (crew 5)")
	_force("Enemy Count", [3])
	assert_int(gen._calculate_enemy_count(NORMAL, 4, false, 0, true)).is_equal(4)
	_consumed("Enemy Count (crew 4)")
	# The control: the same first two dice on an ordinary crew-6 battle (p.63, 2D6
	# pick higher, no extra figure).
	_force("Enemy Count", [2, 5])
	assert_int(gen._calculate_enemy_count(NORMAL, 6)).is_equal(5)
	_consumed("Enemy Count (ordinary)")


func test_the_raid_fights_criminal_elements() -> void:
	# 99 on the opportunity column is Roving Threats, so a raid that still rolls
	# the column fights the wrong table here, not merely sometimes.
	_force("Encounter Category", [99])
	var enemies: Array = EnemyGen.new().generate_enemies_as_dicts(
		{"travel_event_raid": true, "mission_source": "opportunity",
			"difficulty_mode": NORMAL}, 6)
	assert_array(enemies).is_not_empty()
	for e: Dictionary in enemies:
		assert_str(str(e.get("category", ""))).override_failure_message(
			"a Raided battle fielded %s, not Criminal Elements" % e.get("category")) \
			.is_equal("criminal_elements")


func test_the_raid_battle_rolls_the_raided_dice() -> void:
	# Three dice at crew 6. An ordinary p.63 roll takes two and leaves one queued.
	_force("Enemy Count", [1, 1, 1])
	var enemies: Array = EnemyGen.new().generate_enemies_as_dicts(
		{"travel_event_raid": true, "mission_source": "opportunity",
			"difficulty_mode": NORMAL}, 6)
	assert_array(enemies).is_not_empty()
	var left: Dictionary = get_node("/root/DiceManager").get_forced_results()
	assert_bool(left.has("enemy count")).override_failure_message(
		"the Raided battle rolled the ordinary enemy-count dice, not 3D6 (p.70)").is_false()


func test_a_failed_intimidation_stamps_the_raid() -> void:
	var out: Dictionary = Resolver._resolve_raided(null,
		[{"character_name": "Ana", "savvy": -10}])
	var battle: Dictionary = out.get("forced_battle", {})
	assert_bool(bool(battle.get("travel_event_raid", false))).is_true()
	assert_str(str(battle.get("objective", ""))).is_equal("none")
	# The keys nothing read are gone, so nobody mistakes them for the rule.
	assert_bool(battle.has("base_enemy_count")).is_false()


func test_setup_carries_the_note_and_the_loss_penalty() -> void:
	var raid: Dictionary = SetupRules.compute({"travel_event_raid": true}, 6, 6)
	var kinds: Array = (raid["loss_penalties"] as Array).map(
		func(p: Dictionary) -> String: return str(p.get("type", "")))
	assert_array(kinds).contains(["raid_loss"])
	assert_str(" ".join(raid["setup_notes"])).contains("cramped").contains("p.70")
	var ordinary: Dictionary = SetupRules.compute({}, 6, 6)
	assert_array(ordinary["loss_penalties"]).is_empty()


func test_losing_the_raid_takes_every_credit_and_the_stash() -> void:
	var c := _raid_campaign()
	var applied: Array = PaymentProc.new().process_scenario_loss_penalties(_loss_ctx(c, false))
	assert_int(int(c.credits)).override_failure_message(
		"p.70: a lost raid costs all credits").is_equal(0)
	assert_array(c.equipment_data["equipment"]).override_failure_message(
		"p.70: a lost raid costs everything in the Stash").is_empty()
	# The crew's own sheets are not the Stash.
	assert_array(c.crew_data["members"][0]["equipment"]).is_equal(["Colony Rifle"])
	assert_int(applied.size()).is_equal(1)
	assert_int(int(applied[0]["amount"])).is_equal(12)
	assert_array(applied[0]["items"]).is_equal(["Blade", "Scrap Pistol"])


func test_driving_them_off_keeps_credits_and_stash() -> void:
	var c := _raid_campaign()
	var applied: Array = PaymentProc.new().process_scenario_loss_penalties(_loss_ctx(c, true))
	assert_array(applied).is_empty()
	assert_int(int(c.credits)).is_equal(12)
	assert_int((c.equipment_data["equipment"] as Array).size()).is_equal(2)


func test_driving_them_off_is_the_win() -> void:
	# Run the real orchestrator. `success` arrives false (there is no objective to
	# meet), and holding the field must still count as winning for every step.
	var phase: Node = auto_free(PostBattlePhaseScript.new())
	add_child(phase)
	phase.start_post_battle_phase({"travel_event_raid": true, "held_field": true,
		"success": false, "turn": 3, "crew_participants": [], "injuries_sustained": []})
	assert_bool(phase.mission_successful).override_failure_message(
		"the crew drove the raiders off and the post-battle steps saw a loss").is_true()
	assert_bool(bool(phase.battle_result.get("success", false))).is_true()


func test_being_driven_off_is_not_a_win() -> void:
	var phase: Node = auto_free(PostBattlePhaseScript.new())
	add_child(phase)
	phase.start_post_battle_phase({"travel_event_raid": true, "held_field": false,
		"success": true, "turn": 3, "crew_participants": [], "injuries_sustained": []})
	assert_bool(phase.mission_successful).is_false()


func test_a_won_raid_rolls_one_more_loot() -> void:
	var cases := [
		[{"travel_event_raid": true, "success": true}, 2],
		[{"travel_event_raid": true, "success": false}, 1],
		[{"success": true}, 1],
	]
	for row: Array in cases:
		var ctx: RefCounted = ContextClass.new()
		ctx.battle_result = row[0]
		var loot := LootCounter.new()
		loot.process_loot_gathering(ctx)
		assert_int(loot.rolls).override_failure_message(
			"loot rolls for %s" % str(row[0])).is_equal(int(row[1]))


func test_the_flag_crosses_the_result_normalizer() -> void:
	var out: Dictionary = Normalizer.normalize({}, {"travel_event_raid": true}, 3)
	assert_bool(bool(out.get("travel_event_raid", false))).is_true()
