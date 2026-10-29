extends GdUnitTestSuite
## The Bug Hunt co-op campaign (Compendium pp.209-211), driven through the real rules
## module and the real campaign core with forced dice.
##
## WHAT EACH GROUP PROVES.
##   Generation (p.210): the 2D6 Priority keeps the LOWER die, the Factor D100 places one
##     of each Factor before any duplicate, and a stash of 1D6 comes with a KEPT roll ending
##     in 5 or 0. Forced end to end, and asserted twice from the same queue for determinism.
##   The Battles (p.211): 2+ Objectives clears the sector and pays 1 Support point plus the
##     stash into the common pool; fewer leaves it under enemy control; Sheltered refuses an
##     attack until a neighbour is cleared; each player attacks once per operational turn.
##   End of turn (pp.210-211): every Enemy Moves row lands on the map; Infiltration points
##     raise a neighbour's Priority, capped at the p.187 maximum of 6.
##   Victory (p.210): every sector cleared ends the campaign and rolls no Enemy Moves.
##   Persistence: a round trip keeps the map with whole numbers, and a save with no `coop`
##     key loads as a non-co-op campaign.
##   The Operational Progress skip (p.210): the resolver does not roll step 6 for a co-op
##     snapshot, and the single mutator drops a p.205 effect on a co-op campaign even when
##     the receipt was resolved without the flag. Each with a non-co-op control.
##
## THE RULES MODULE REACHES THE AUTOLOAD, so `after_test()` clearing the forced queue is
## mandatory: an unconsumed value rides /root/DiceManager into every later suite.
##
## gdUnit4 v6.0.3.

const Coop = preload("res://src/core/campaign/BugHuntCoopCampaign.gd")
const BugHuntCore = preload("res://src/game/campaign/BugHuntCampaignCore.gd")
const Resolver = preload("res://src/core/campaign/BugHuntPostBattleResolver.gd")
const PhaseManager = preload("res://src/core/campaign/BugHuntPhaseManager.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

const PRIORITY_1 := "Bug Hunt Co-op Priority: die 1"
const PRIORITY_2 := "Bug Hunt Co-op Priority: die 2"
const FACTOR := "Bug Hunt Co-op Sector Factor"
const STASH := "Bug Hunt Co-op Resource Stash"
const ENEMY_MOVE := "Bug Hunt Co-op Enemy Move"
const TARGET := "Bug Hunt Co-op Target Sector"
const INFILTRATION := "Bug Hunt Co-op Infiltration"
const WASTAGE := "Bug Hunt Co-op Wastage"

var _dm: Node = null
var _user_state: Dictionary


func before_test() -> void:
	# The phase-manager cases persist through GameState.save_campaign(), which also
	# rewrites last_campaign; the guard removes only what this test wrote.
	_user_state = SaveDirGuard.snapshot()
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")
	# INSTRUMENT THE PREMISE: without the autoload every forced value below is a no-op and
	# every behavioural case would pass on whatever the RNG gave.
	assert_object(_dm).override_failure_message(
		"/root/DiceManager did not resolve under the runner, so nothing below can force "
		+ "anything").is_not_null()
	_dm.clear_forced_results()


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	SaveDirGuard.restore(_user_state)


# ──────────────────────────────────────────────────────────────────────── fixtures

## A 2x2 map, one player. S1 is cleared; S2-S4 are enemy-held. No Infiltration point, so
## an end phase rolls Enemy Moves and nothing else.
##   S1 Reactor  P2 hot_zone   cleared   adj S2,S3
##   S2 Docks    P4 swarming   stash 3   adj S1,S4
##   S3 Mine     P6 sheltered            adj S1,S4
##   S4 Spire    P1 obstructed           adj S2,S3
func _fixture(players: Array = ["Ana"]) -> Dictionary:
	return Coop.normalize({
		"enabled": true,
		"players": players,
		"sectors": [
			{"id": "S1", "name": "Reactor", "priority": 2, "factors": ["hot_zone"],
				"stash": 0, "cleared": true, "conditions": [], "adjacent": ["S2", "S3"]},
			{"id": "S2", "name": "Docks", "priority": 4, "factors": ["swarming"],
				"stash": 3, "cleared": false, "conditions": [], "adjacent": ["S1", "S4"]},
			{"id": "S3", "name": "Mine", "priority": 6, "factors": ["sheltered"],
				"stash": 0, "cleared": false, "conditions": [], "adjacent": ["S1", "S4"]},
			{"id": "S4", "name": "Spire", "priority": 1, "factors": ["obstructed"],
				"stash": 0, "cleared": false, "conditions": [], "adjacent": ["S2", "S3"]},
		],
		"support_pool": 5,
		"op_turn": 1,
		"support_penalty": 0,
		"attacked_this_turn": [],
	})


func _sector(coop: Dictionary, id: String) -> Dictionary:
	for s in coop.sectors:
		if str(s.id) == id:
			return s
	return {}


func _core_with(coop: Dictionary) -> Object:
	var core = BugHuntCore.new()
	core.campaign_name = "Coop Probe"
	core.coop = coop
	return core


func _queue_generation_of_three() -> void:
	## Sector 1: dice 5,2 -> P2; D100 25 Infiltration point, ends in 5 -> stash, D6 4.
	## Sector 2: dice 6,6 -> P6; D100 40 Sheltered, ends in 0 -> stash, D6 6.
	## Sector 3: dice 1,4 -> P1; D100 35 is Sheltered AGAIN (and ends in 5) -> rerolled,
	##           62 Swarming kept. The discarded 35 places no stash.
	for v in [5, 6, 1]:
		_dm.queue_forced_result(PRIORITY_1, v)
	for v in [2, 6, 4]:
		_dm.queue_forced_result(PRIORITY_2, v)
	for v in [25, 40, 35, 62]:
		_dm.queue_forced_result(FACTOR, v)
	for v in [4, 6]:
		_dm.queue_forced_result(STASH, v)


# ─────────────────────────────────────────────────────────────── premise
func test_the_forcing_seam_is_armed() -> void:
	assert_bool(OS.is_debug_build()).override_failure_message(
		"queue_forced_result() is debug-only; every behavioural case would roll at random"
		).is_true()
	_dm.queue_forced_result(FACTOR, 91)
	assert_int(_dm.roll_d100("Bug Hunt Co-op Sector Factor")).is_equal(91)


# ─────────────────────────────────────────────────────────── generation, p.210
func test_generation_is_deterministic_under_forced_rolls() -> void:
	_queue_generation_of_three()
	var first: Dictionary = Coop.new_campaign(["Ana"], 3)
	assert_dict(_dm.get_forced_results()).override_failure_message(
		"a queued value was not consumed, so a context does not match its key, or a roll "
		+ "the book requires was skipped: %s" % str(_dm.get_forced_results())).is_empty()

	_queue_generation_of_three()
	var second: Dictionary = Coop.new_campaign(["Ana"], 3)

	assert_bool(bool(first.ok)).is_true()
	assert_dict(first.coop).is_equal(second.coop)
	var sectors: Array = first.coop.sectors
	assert_int(sectors.size()).is_equal(3)
	assert_array(sectors.map(func(s: Variant) -> int: return int(s.priority))).is_equal([2, 6, 1])
	assert_array(sectors.map(func(s: Variant) -> Array: return s.factors)).is_equal(
		[["infiltration_point"], ["sheltered"], ["swarming"]])
	assert_array(sectors.map(func(s: Variant) -> int: return int(s.stash))).is_equal([4, 6, 0])
	# The near-square grid: 3 sectors in 2 columns.
	assert_array(sectors.map(func(s: Variant) -> Array: return s.adjacent)).is_equal(
		[["S2", "S3"], ["S1"], ["S1"]])
	assert_bool(bool(first.coop.enabled)).is_true()
	assert_int(int(first.coop.support_pool)).is_equal(0)
	assert_int(int(first.coop.op_turn)).is_equal(1)


func test_priority_keeps_the_lower_die() -> void:
	## p.210 "Roll 2D6 and pick the lower of the dice". Both orders, so a min() that only
	## ever reads die 1 or die 2 fails one of them.
	_dm.queue_forced_result(PRIORITY_1, 6)
	_dm.queue_forced_result(PRIORITY_2, 3)
	_dm.queue_forced_result(PRIORITY_1, 2)
	_dm.queue_forced_result(PRIORITY_2, 5)
	_dm.queue_forced_result(PRIORITY_1, 4)
	_dm.queue_forced_result(PRIORITY_2, 4)
	for v in [1, 16, 31]:
		_dm.queue_forced_result(FACTOR, v)
	var r: Dictionary = Coop.new_campaign(["Ana"], 3)
	assert_array(r.coop.sectors.map(func(s: Variant) -> int: return int(s.priority))).is_equal(
		[3, 2, 4])


func test_every_factor_is_placed_once_before_any_duplicate() -> void:
	## Nine sectors: the first seven rolls are the seven Factors, so the eighth and ninth
	## may duplicate -- and must be accepted rather than rerolled.
	for v in [1, 16, 31, 51, 66, 81, 91, 2, 17]:
		_dm.queue_forced_result(FACTOR, v)
	var r: Dictionary = Coop.new_campaign(["Ana", "Ben", "Cy"], 3)
	assert_bool(bool(r.ok)).is_true()
	assert_array(r.coop.sectors.map(func(s: Variant) -> String: return str(s.factors[0]))).is_equal([
		"ambush_zone", "infiltration_point", "sheltered", "swarming", "obstructed",
		"inaccessible", "hot_zone", "ambush_zone", "infiltration_point"])
	assert_dict(_dm.get_forced_results()).is_empty()


func test_setup_refuses_a_sector_count_outside_the_guideline() -> void:
	assert_bool(bool(Coop.new_campaign(["Ana"], 2).ok)).is_false()
	assert_bool(bool(Coop.new_campaign(["Ana"], 6).ok)).is_false()
	assert_bool(bool(Coop.new_campaign([], 3).ok)).is_false()
	assert_bool(bool(Coop.new_campaign(["  "], 3).ok)).is_false()
	var five: Dictionary = Coop.new_campaign(["Ana", "Ben"], 5)
	assert_int((five.coop.sectors as Array).size()).is_equal(10)


func test_a_refused_setup_leaves_the_core_untouched() -> void:
	var core = BugHuntCore.new()
	var r: Dictionary = core.start_coop_campaign(["Ana"], 9)
	assert_bool(bool(r.ok)).is_false()
	assert_bool(core.is_coop()).is_false()
	assert_dict(core.coop).is_empty()


# ─────────────────────────────────────────────────────────── The Battles, p.211
func test_a_two_objective_mission_clears_the_sector_and_pays_the_stash() -> void:
	var core = _core_with(_fixture())
	var r: Dictionary = core.record_coop_battle("Ana", "S2", {"objectives_completed": 2})
	assert_bool(bool(r.ok)).is_true()
	assert_bool(bool(r.victory)).is_true()
	assert_int(int(r.support_awarded)).is_equal(1)
	assert_int(int(r.stash_paid)).is_equal(3)
	var s2: Dictionary = _sector(core.coop, "S2")
	assert_bool(bool(s2.cleared)).is_true()
	assert_int(int(s2.stash)).override_failure_message(
		"a stash is claimed once; left on the sector it would pay again if retaken").is_equal(0)
	# 5 in the pool + 1 for the victory + the 3-point stash.
	assert_int(int(core.coop.support_pool)).is_equal(9)


func test_one_objective_is_a_failure_and_the_sector_stays_with_the_enemy() -> void:
	var core = _core_with(_fixture())
	var r: Dictionary = core.record_coop_battle("Ana", "S2", {"objectives_completed": 1})
	assert_bool(bool(r.ok)).is_true()
	assert_bool(bool(r.victory)).is_false()
	assert_bool(bool(_sector(core.coop, "S2").cleared)).is_false()
	assert_int(int(_sector(core.coop, "S2").stash)).is_equal(3)
	assert_int(int(core.coop.support_pool)).is_equal(5)


func test_each_player_attacks_one_sector_per_operational_turn() -> void:
	var core = _core_with(_fixture(["Ana", "Ben"]))
	assert_bool(bool(core.record_coop_battle("Ana", "S4", {"objectives_completed": 0}).ok)).is_true()
	var again: Dictionary = core.record_coop_battle("Ana", "S2", {"objectives_completed": 3})
	assert_bool(bool(again.ok)).is_false()
	assert_bool(bool(_sector(core.coop, "S2").cleared)).is_false()
	assert_bool(bool(core.record_coop_battle("Ben", "S2", {"objectives_completed": 3}).ok)).is_true()
	assert_bool(bool(core.record_coop_battle("Zed", "S4", {"objectives_completed": 3}).ok)).is_false()


func test_a_sheltered_sector_cannot_be_attacked_until_a_neighbour_is_cleared() -> void:
	var coop := _fixture()
	_sector(coop, "S1").cleared = false
	var refused: Dictionary = Coop.can_attack(coop, "S3", "Ana")
	assert_bool(bool(refused.ok)).is_false()
	assert_str(str(refused.reason)).contains("Sheltered")
	assert_bool(bool(Coop.apply_battle_result(coop, "Ana", "S3", {"objectives_completed": 3}).ok)
		).is_false()
	assert_bool(bool(_sector(coop, "S3").cleared)).is_false()
	# A neighbour falls: now it may be attacked.
	_sector(coop, "S1").cleared = true
	assert_bool(bool(Coop.can_attack(coop, "S3", "Ana").ok)).is_true()


func test_the_common_pool_is_drawn_down_and_never_below_zero() -> void:
	var core = _core_with(_fixture())
	assert_int(core.draw_coop_support(3)).is_equal(3)
	assert_int(int(core.coop.support_pool)).is_equal(2)
	assert_int(core.draw_coop_support(5)).is_equal(2)
	assert_int(int(core.coop.support_pool)).is_equal(0)


# ──────────────────────────────────────────────────── Enemy Moves, p.211
func _end_turn_with_move(coop: Dictionary, move_roll: int, target_roll: int = 0) -> Dictionary:
	_dm.queue_forced_result(ENEMY_MOVE, move_roll)
	if target_roll > 0:
		_dm.queue_forced_result(TARGET, target_roll)
	var r: Dictionary = Coop.end_operational_turn(coop)
	assert_bool(bool(r.ok)).is_true()
	assert_dict(_dm.get_forced_results()).override_failure_message(
		"a forced roll was not consumed: %s" % str(_dm.get_forced_results())).is_empty()
	return r


func test_enemy_assault_retakes_a_cleared_sector_at_priority_three() -> void:
	var coop := _fixture()
	var r := _end_turn_with_move(coop, 5)  # the only cleared sector is S1, so no pick roll
	var s1: Dictionary = _sector(coop, "S1")
	assert_bool(bool(s1.cleared)).is_false()
	assert_int(int(s1.priority)).is_equal(3)
	assert_str(str(r.moves[0].sector_id)).is_equal("S1")


func test_enemy_assault_with_no_cleared_sector_has_no_effect() -> void:
	var coop := _fixture()
	_sector(coop, "S1").cleared = false
	var r := _end_turn_with_move(coop, 5)
	assert_bool(bool(r.moves[0].applied)).is_false()
	assert_int(int(_sector(coop, "S1").priority)).is_equal(2)


func test_enemy_digs_in_establishes_control_and_gathers_forces_add_factors() -> void:
	var coop := _fixture()
	_end_turn_with_move(coop, 15, 1)  # enemy sectors S2,S3,S4 -> roll 1 = S2
	assert_array(_sector(coop, "S2").factors).is_equal(["swarming", "ambush_zone"])
	_end_turn_with_move(coop, 25, 2)  # roll 2 = S3
	assert_array(_sector(coop, "S3").factors).is_equal(["sheltered", "obstructed"])
	_end_turn_with_move(coop, 35, 3)  # roll 3 = S4
	assert_array(_sector(coop, "S4").factors).is_equal(["obstructed", "infiltration_point"])


func test_enemy_sabotage_costs_every_battle_one_support_point_next_turn_only() -> void:
	var coop := _fixture(["Ana", "Ben"])
	_dm.queue_forced_result(ENEMY_MOVE, 45)
	_dm.queue_forced_result(ENEMY_MOVE, 40)
	var r: Dictionary = Coop.end_operational_turn(coop)
	assert_int((r.moves as Array).size()).override_failure_message(
		"p.211 'Each player rolls on the table' -- two players, two rolls").is_equal(2)
	assert_int(int(coop.support_penalty)).is_equal(2)
	assert_int(int(Coop.battle_modifiers(coop, "S2").support_penalty)).is_equal(2)
	# The following end phase rolls no sabotage: the penalty has been fought through.
	_dm.queue_forced_result(ENEMY_MOVE, 90)
	_dm.queue_forced_result(TARGET, 1)
	_dm.queue_forced_result(ENEMY_MOVE, 90)
	_dm.queue_forced_result(TARGET, 1)
	Coop.end_operational_turn(coop)
	assert_int(int(coop.support_penalty)).is_equal(0)


func test_enemy_patrols_swarms_and_elites_reach_the_battle_modifiers() -> void:
	var coop := _fixture()
	_end_turn_with_move(coop, 50, 1)  # S2 heavily patrolled
	_end_turn_with_move(coop, 60, 1)  # S2 swarmed
	_end_turn_with_move(coop, 70, 1)  # S2 held by elite forces
	var mods: Dictionary = Coop.battle_modifiers(coop, "S2")
	assert_array(_sector(coop, "S2").conditions).is_equal(["patrolled", "swarmed", "elites"])
	assert_int(int(mods.battle.aggression_die_bonus)).is_equal(1)
	assert_int(int(mods.battle.extra_contact_markers)).is_equal(1)
	assert_int(int(mods.battle.elite_combat_skill_to)).is_equal(1)
	assert_int(int(mods.battle.elite_toughness_to)).is_equal(4)
	assert_int(int(mods.battle.elite_speed_bonus_inches)).is_equal(1)
	# The setup Factor's own value is in the same merge.
	assert_int(int(mods.battle.enemies_per_contact_bonus)).is_equal(1)
	assert_int(int(mods.priority)).is_equal(4)
	# Clearing the sector disperses the forces that held it.
	Coop.apply_battle_result(coop, "Ana", "S2", {"objectives_completed": 2})
	assert_array(_sector(coop, "S2").conditions).is_empty()


func test_wastage_removes_one_d3_from_the_pool_and_never_below_zero() -> void:
	var coop := _fixture()
	_dm.queue_forced_result(WASTAGE, 2)
	_end_turn_with_move(coop, 80)
	assert_int(int(coop.support_pool)).is_equal(3)
	coop.support_pool = 1
	_dm.queue_forced_result(WASTAGE, 3)
	_end_turn_with_move(coop, 80)
	assert_int(int(coop.support_pool)).is_equal(0)


func test_suspicious_activity_raises_priority_up_to_the_p187_maximum() -> void:
	var coop := _fixture()
	_end_turn_with_move(coop, 90, 1)  # S2 4 -> 5
	assert_int(int(_sector(coop, "S2").priority)).is_equal(5)
	_end_turn_with_move(coop, 90, 2)  # S3 already 6
	assert_int(int(_sector(coop, "S3").priority)).override_failure_message(
		"p.187: Priority cannot be raised above 6").is_equal(6)


func test_an_infiltration_point_raises_an_adjacent_priority_each_turn() -> void:
	var coop := _fixture()
	_sector(coop, "S4").factors = ["infiltration_point"]  # adjacent S2 (P4), S3 (P6)
	_dm.queue_forced_result(INFILTRATION, 1)
	var r := _end_turn_with_move(coop, 45)
	assert_int(int(_sector(coop, "S2").priority)).is_equal(5)
	assert_str(str(r.infiltrations[0].sector_id)).is_equal("S2")
	_dm.queue_forced_result(INFILTRATION, 2)
	_end_turn_with_move(coop, 45)
	assert_int(int(_sector(coop, "S3").priority)).override_failure_message(
		"p.210 '(to a maximum of 6)'").is_equal(6)


func test_the_end_phase_advances_the_operational_turn() -> void:
	var coop := _fixture()
	coop.attacked_this_turn = ["Ana"]
	_end_turn_with_move(coop, 45)
	assert_int(int(coop.op_turn)).is_equal(2)
	assert_array(coop.attacked_this_turn).is_empty()


# ─────────────────────────────────────────────────────────── victory, p.210
func test_clearing_the_last_sector_wins_the_campaign() -> void:
	var coop := _fixture()
	_sector(coop, "S3").cleared = true
	_sector(coop, "S4").cleared = true
	var core = _core_with(coop)
	assert_str(core.game_phase).is_not_equal("completed")
	var r: Dictionary = core.record_coop_battle("Ana", "S2", {"objectives_completed": 2})
	assert_bool(bool(r.campaign_won)).is_true()
	assert_bool(Coop.is_campaign_won(core.coop)).is_true()
	assert_str(core.game_phase).is_equal("completed")
	# A won campaign rolls no Enemy Moves -- the queued roll must survive.
	_dm.queue_forced_result(ENEMY_MOVE, 5)
	var end: Dictionary = core.end_coop_operational_turn()
	assert_bool(bool(end.campaign_won)).is_true()
	assert_array(end.moves).is_empty()
	assert_bool(_dm.get_forced_results().has(ENEMY_MOVE.to_lower())).is_true()


func test_an_uncleared_sector_means_the_campaign_goes_on() -> void:
	var coop := _fixture()
	assert_bool(Coop.is_campaign_won(coop)).is_false()
	assert_bool(Coop.is_campaign_won({})).is_false()


# ─────────────────────────────────────────────────────────── persistence
func test_a_round_trip_keeps_the_map_in_whole_numbers() -> void:
	var core = BugHuntCore.new()
	core.campaign_name = "Coop Round Trip"
	var r: Dictionary = core.start_coop_campaign(["Ana", "Ben"], 3)
	assert_bool(bool(r.ok)).is_true()
	core.record_coop_battle("Ana", str(core.coop.sectors[0].id), {"objectives_completed": 2})

	var text: String = JSON.stringify(core.to_dictionary())
	var loaded = BugHuntCore.new()
	loaded.from_dictionary(JSON.parse_string(text))

	assert_bool(loaded.is_coop()).is_true()
	assert_dict(loaded.coop).is_equal(core.coop)
	assert_int(typeof(loaded.coop.sectors[0].priority)).override_failure_message(
		"a JSON float Priority renders '3.0' (T11-33)").is_equal(TYPE_INT)
	assert_int(typeof(loaded.coop.support_pool)).is_equal(TYPE_INT)
	assert_int(typeof(loaded.coop.op_turn)).is_equal(TYPE_INT)


func test_a_save_without_the_coop_key_loads_as_a_normal_campaign() -> void:
	var core = BugHuntCore.new()
	core.campaign_name = "Legacy"
	var data: Dictionary = core.to_dictionary()
	data.erase("coop")
	var loaded = BugHuntCore.new()
	loaded.from_dictionary(data)
	assert_bool(loaded.is_coop()).is_false()
	assert_dict(loaded.coop).is_empty()
	# The rest of the load still ran -- an abort in from_dictionary would leave this unset.
	assert_str(loaded.campaign_name).is_equal("Legacy")
	assert_int(loaded.movie_magic_used.size()).is_greater(0)

	var garbled := core.to_dictionary()
	garbled["coop"] = "not a dictionary"
	var loaded2 = BugHuntCore.new()
	loaded2.from_dictionary(garbled)
	assert_bool(loaded2.is_coop()).is_false()


# ──────────────────────────────────────────── the Operational Progress skip, p.210
func _quiet_post_battle() -> void:
	_dm.queue_forced_result("Bug Hunt Military Life", 33)
	_dm.queue_forced_result("Bug Hunt Military Life", 33)
	_dm.queue_forced_result("Bug Hunt Muster Out", 2)
	for i in range(4):
		_dm.queue_forced_result("Bug Hunt Reputation", 1)


func _post_battle_snapshot(coop_enabled: bool) -> Dictionary:
	return {
		"characters": [{"id": "a", "name": "Alpha", "combat_skill": 1, "toughness": 3,
			"xp": 0, "completed_missions_count": 0}],
		"reputation": 0,
		"operational_progress_modifier": 5,
		"missions_in_current_operation": 0,
		"pending_military_life_rolls": 0,
		"sick_bay": {},
		"battle_result": {"participant_ids": ["a"], "objectives_completed": 1},
		"coop_enabled": coop_enabled,
	}


func _op_progress_effects(receipt: Dictionary) -> Array:
	return (receipt.effects as Array).filter(
		func(e: Variant) -> bool: return str(e.get("cite", "")) == Resolver.CITE_OP_PROGRESS)


func test_the_resolver_does_not_roll_operational_progress_for_a_coop_campaign() -> void:
	## A forced 100 + 5 is the p.205 Parade. On a co-op snapshot it must not be rolled at
	## all, so the queued value is still waiting afterwards.
	_quiet_post_battle()
	_dm.queue_forced_result("Bug Hunt Operational Progress", 100)
	var receipt: Dictionary = Resolver.new().resolve(_post_battle_snapshot(true))
	assert_array(_op_progress_effects(receipt)).is_empty()
	assert_bool(_dm.get_forced_results().has("bug hunt operational progress")).override_failure_message(
		"the Operational Progress D100 was rolled for a co-op campaign").is_true()
	var step6: Array = (receipt.steps as Array).filter(
		func(s: Variant) -> bool: return int(s.get("step", -1)) == 6)
	assert_int(step6.size()).is_equal(1)
	assert_bool(bool(step6[0].skipped)).is_true()
	assert_str(str(step6[0].lines[0])).contains("p.210")


func test_control_a_normal_campaign_still_rolls_operational_progress() -> void:
	## Without this the case above passes against a resolver that never rolls step 6.
	_quiet_post_battle()
	_dm.queue_forced_result("Bug Hunt Operational Progress", 100)
	var receipt: Dictionary = Resolver.new().resolve(_post_battle_snapshot(false))
	var ops: Array = _op_progress_effects(receipt).map(func(e: Variant) -> String: return str(e.op))
	assert_array(ops).contains(["campaign_victory"])


func _apply_through_the_mutator(core: Object) -> void:
	var pm = PhaseManager.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	pm._apply_post_battle_results({"receipt": {
		"steps": [],
		"effects": [
			{"op": "op_modifier", "amount": 5, "cite": Resolver.CITE_OP_PROGRESS},
			{"op": "campaign_victory", "cite": Resolver.CITE_OP_PROGRESS},
			{"op": "reputation", "amount": 2, "cite": Resolver.CITE_REPUTATION},
		],
	}})


func test_the_mutator_drops_operational_progress_effects_on_a_coop_campaign() -> void:
	var core = _core_with(_fixture())
	_apply_through_the_mutator(core)
	assert_int(int(core.operational_progress_modifier)).override_failure_message(
		"p.210: the Operational Progress table is not used in a co-op campaign").is_equal(0)
	assert_str(core.game_phase).is_not_equal("completed")
	# Every other step still applies.
	assert_int(int(core.reputation)).is_equal(2)


func test_control_the_mutator_applies_them_on_a_normal_campaign() -> void:
	var core = BugHuntCore.new()
	core.campaign_name = "Coop Control"
	_apply_through_the_mutator(core)
	assert_int(int(core.operational_progress_modifier)).is_equal(5)
	assert_str(core.game_phase).is_equal("completed")
	assert_int(int(core.reputation)).is_equal(2)


## The resolver cases above hand it a hand-built snapshot. The panel builds the real
## one, and it never carried the flag, so a co-op receipt still showed a p.205 roll
## that the phase manager's backstop then threw away.
func test_the_post_battle_panel_tells_the_resolver_it_is_a_coop_campaign() -> void:
	var panel = auto_free(load(
		"res://src/ui/screens/bug_hunt/panels/BugHuntPostBattlePanel.gd").new())
	panel.set_campaign(_core_with(_fixture()))
	assert_bool(bool(panel._build_snapshot().get("coop_enabled", false))).is_true()
	panel.set_campaign(BugHuntCore.new())
	assert_bool(bool(panel._build_snapshot().get("coop_enabled", true))).is_false()
