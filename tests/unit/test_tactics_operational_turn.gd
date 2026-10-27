extends GdUnitTestSuite

## Five Parsecs: Tactics operational turn, pp.92-99 — TacticsOperationalTurn.
##
## Before 2026-10-27 the operational layer never ran: no Zone was ever opened, so Step 3
## had nothing to resolve and the campaign could not move. These cases drive the rules
## with SCRIPTED dice (TacticsOperationalTurn.new([..])) so each asserts one book rule
## against the map state it leaves, never against a receipt heading — a heading
## renders whether or not the rule fired (the Bug Hunt Phase 7 trap).

const Turn = preload("res://src/core/campaign/TacticsOperationalTurn.gd")
const PhaseManager = preload("res://src/core/campaign/TacticsPhaseManager.gd")
const TacticsCore = preload("res://src/game/campaign/TacticsCampaignCore.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _user_state: Dictionary = {}


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()


func after_test() -> void:
	SaveDirGuard.restore(_user_state)
	_user_state = {}


## One Zone in a neutral region. Both sides' territory touches it unless told not to,
## so neither side gets p.97's "+1 if the enemy is not adjacent" die by default.
func _map(p_as: int, e_as: int, p_adj := true, e_adj := true) -> Dictionary:
	return {
		"player_cohesion": 5, "enemy_cohesion": 5, "player_battle_points": 0,
		"operational_turn": 1, "focus_zone_id": "z1", "player_zone_id": "z1",
		"regions": [
			{"id": "pr1", "name": "Your Region 1", "owner": "player"},
			{"id": "er1", "name": "Enemy Region 1", "owner": "enemy"},
			{"id": "nr1", "name": "Neutral Region 1", "owner": "neutral"},
		],
		"zones": [{"id": "z1", "region_id": "nr1", "name": "Pass", "attacker": "player",
			"player_army_strength": p_as, "enemy_army_strength": e_as,
			"player_adjacent": p_adj, "enemy_adjacent": e_adj, "opened_turn": 1}],
		"orders_history": [], "next_zone_seq": 2,
	}


func _manager(campaign: Resource):
	var pm = PhaseManager.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(campaign)
	return pm


func _zone(map: Dictionary) -> Dictionary:
	return (map.zones as Array)[0] if not (map.zones as Array).is_empty() else {}


# MARK: - Step 3 (p.97)

func test_a_single_high_die_costs_the_loser_one_army_strength() -> void:
	var map := _map(4, 4)
	Turn.new([6, 3]).resolve_zone_battles(map)
	assert_int(_zone(map).enemy_army_strength).is_equal(3)
	assert_int(_zone(map).player_army_strength).is_equal(4)


## Row 1: both sides roll two or more 6s -> both -1, then "fight again immediately"
## with -1 Combat Die each (minimum 1).
func test_both_sides_rolling_multiple_sixes_refight_with_one_fewer_die() -> void:
	var map := _map(4, 4, false, false)  # neither territory touches: 2 dice each
	var t = Turn.new([6, 6, 6, 6, 5, 2])
	var r: Dictionary = t.resolve_zone_battles(map)
	assert_int(t.rolls.size()) \
		.override_failure_message("the refight should roll ONE die a side (2+2, then 1+1)") \
		.is_equal(6)
	assert_int(_zone(map).player_army_strength).is_equal(3)
	assert_int(_zone(map).enemy_army_strength).is_equal(2)
	assert_str("\n".join(PackedStringArray(r.lines))).contains("fight again")


## p.98 Army Destruction: "The Operational Zone ceases to exist, and the area falls
## under control of the survivors."
func test_destroying_an_army_hands_the_region_to_the_survivor() -> void:
	var map := _map(3, 1)  # 2+ stronger: the player rolls 2 dice
	var r: Dictionary = Turn.new([6, 2, 1]).resolve_zone_battles(map)
	assert_array(map.zones).is_empty()
	assert_str(str((map.regions as Array)[2].owner)).is_equal("player")
	assert_int(int(r.zones_won.player)).is_equal(1)
	assert_str(str(map.focus_zone_id)).is_empty()


## A region that changes hands from a FACTION costs that faction Cohesion (Step 9).
func test_losing_a_held_region_is_counted_for_step_nine() -> void:
	var map := _map(1, 3)
	(map.zones as Array)[0].region_id = "pr1"
	var r: Dictionary = Turn.new([1, 6, 2]).resolve_zone_battles(map)
	assert_str(str((map.regions as Array)[0].owner)).is_equal("enemy")
	assert_int(int(r.regions_lost.player)).is_equal(1)


func test_pbp_buy_combat_dice_only_where_the_player_army_stands() -> void:
	var map := _map(4, 4)
	var t = Turn.new([2, 2, 1])  # 1 base + 1 PBP = 2 player dice, 1 enemy die
	t.resolve_zone_battles(map, 1)
	assert_int(t.rolls.size()).is_equal(3)


# MARK: - p.98 Assault Option

func test_an_assault_adds_a_die_and_costs_a_point_when_it_fails_to_win() -> void:
	var map := _map(4, 3)  # 1 point stronger: eligible, not yet 2+ stronger
	var t = Turn.new([3, 2, 3])  # player 3,2 vs enemy 3 -> tied 1-4: inconclusive
	t.resolve_zone_battles(map, 0, ["z1"])
	assert_int(t.rolls.size()) \
		.override_failure_message("an assault rolls one extra Combat Die (p.98)") \
		.is_equal(3)
	assert_int(_zone(map).player_army_strength) \
		.override_failure_message("p.98: fails to win -> loses 1 Army Strength") \
		.is_equal(3)
	assert_int(_zone(map).enemy_army_strength).is_equal(3)


func test_a_winning_assault_costs_nothing() -> void:
	var map := _map(4, 3)
	Turn.new([6, 1, 2]).resolve_zone_battles(map, 0, ["z1"])
	assert_int(_zone(map).player_army_strength).is_equal(4)
	assert_int(_zone(map).enemy_army_strength).is_equal(2)


func test_an_army_that_is_not_stronger_cannot_assault() -> void:
	var map := _map(4, 4)
	var t = Turn.new([3, 3])
	t.resolve_zone_battles(map, 0, ["z1"])
	assert_int(t.rolls.size()).is_equal(2)
	assert_int(_zone(map).player_army_strength).is_equal(4)


# MARK: - Step 4 Operational Orders (p.98)

func test_bolster_positions_strengthens_the_weakest_army() -> void:
	var map := _map(2, 4)
	(map.zones as Array).append({"id": "z2", "region_id": "er1", "name": "Ridge",
		"player_army_strength": 5, "enemy_army_strength": 5,
		"player_adjacent": true, "enemy_adjacent": true})
	Turn.new([]).carry_out_orders(map, {"player": {"roll": 6, "name": "Bolster"}})
	assert_int(_zone(map).player_army_strength).is_equal(3)


func test_both_sides_attacking_one_zone_get_a_die_each_in_the_first_combat() -> void:
	var map := _map(4, 4)
	var t = Turn.new([1, 1, 2, 2, 1, 1, 1, 1])
	var r: Dictionary = t.carry_out_orders(map, {
		"player": {"roll": 2, "name": "Continued Offensive"},
		"enemy": {"roll": 2, "name": "Continued Offensive"}})
	assert_str("\n".join(PackedStringArray(r.lines))).contains("+1 Combat Die each")
	# First combat 2 dice a side (4 rolls); the second attack on the same Zone is a
	# separate combat with no bonus (1 die a side).
	assert_int(t.rolls.size()).is_equal(6)


# MARK: - Step 5 Commando Raids (p.99)

func test_a_raid_six_damages_and_a_one_loses_every_committed_point() -> void:
	var map := _map(4, 4)
	map.player_battle_points = 3
	var r: Dictionary = Turn.new([6, 1]).commando_raid(map, "z1", 2)
	assert_int(int(map.player_battle_points)).is_equal(1)
	assert_int(_zone(map).enemy_army_strength) \
		.override_failure_message("p.99: the damage applies even if the PBP are lost") \
		.is_equal(3)
	assert_int(int(r.raid.pbp_lost)).is_equal(2)


func test_a_raid_needs_points_it_actually_holds() -> void:
	var map := _map(4, 4)
	map.player_battle_points = 1
	assert_dict(Turn.new([6, 6]).commando_raid(map, "z1", 2)).is_empty()
	assert_int(int(map.player_battle_points)).is_equal(1)


# MARK: - Step 6 Redeploy (p.99)

func test_the_ai_reinforces_a_weak_army_from_its_strongest() -> void:
	var map := _map(4, 2)
	(map.zones as Array).append({"id": "z2", "region_id": "er1", "name": "Ridge",
		"player_army_strength": 3, "enemy_army_strength": 5,
		"player_adjacent": true, "enemy_adjacent": true})
	Turn.new([]).ai_redeploy(map, "enemy")
	assert_int(_zone(map).enemy_army_strength).is_equal(3)
	assert_int(int((map.zones as Array)[1].enemy_army_strength)).is_equal(4)


# MARK: - Opening (pp.93-95) and the legacy-save path

func test_the_opening_map_has_cohesion_regions_three_zones_and_a_focus() -> void:
	var out: Dictionary = Turn.new().build_opening_map(
		{"player_cohesion": 5, "enemy_cohesion": 5})
	var map: Dictionary = out.map
	assert_int((map.regions as Array).size()) \
		.override_failure_message("5 + 5 held, plus the p.93 example's 5 neutral") \
		.is_equal(15)
	assert_int((map.zones as Array).size()).is_equal(3)
	var ids: Array = []
	for z in map.zones:
		ids.append(str(z.id))
		assert_int(int(z.player_army_strength)).is_greater(0)
		assert_int(int(z.enemy_army_strength)).is_greater(0)
	assert_array(ids).contains([str(map.focus_zone_id)])
	assert_str(str(map.player_zone_id)).is_equal(str(map.focus_zone_id))


func test_a_campaign_with_an_empty_map_is_opened_when_its_turn_starts() -> void:
	var c = TacticsCore.new()
	c.operational_map = {"player_cohesion": 5, "enemy_cohesion": 5,
		"player_battle_points": 0, "operational_turn": 0, "focus_zone_id": "",
		"regions": [], "zones": [], "orders_history": []}
	var pm = _manager(c)
	pm.start_new_turn()
	assert_int((c.operational_map.zones as Array).size()) \
		.override_failure_message("an empty map is the shape every pre-2026-10-27 save "
			+ "has; it must be opened, or Step 3 never has a Zone to resolve") \
		.is_equal(3)


## p.95: "any number of tabletop battles". An invented cap of three used to stop here.
func test_a_fourth_battle_in_one_turn_is_allowed() -> void:
	var c = TacticsCore.new()
	c.operational_map = _map(4, 4)
	var pm = _manager(c)
	pm.start_new_turn()
	for _i in range(3):
		pm.go_to_phase(PhaseManager.Phase.BATTLE)
		pm.complete_current_phase({"battle_result": {"won": true}, "play_another": true})
	assert_bool(pm.can_play_another_battle()).is_true()
	pm.go_to_phase(PhaseManager.Phase.BATTLE)
	pm.complete_current_phase({"battle_result": {"won": true}, "play_another": true})
	assert_int(pm.current_phase).is_equal(PhaseManager.Phase.BATTLE_PREP)


## p.96: "0 for a draw". A draw also cancels nothing — so a win followed by a draw
## still banks the win's point. Read as a defeat, the draw would cancel it to 0.
func test_a_draw_earns_no_player_battle_point_and_cancels_nothing() -> void:
	var c = TacticsCore.new()
	c.operational_map = _map(4, 4)
	var pm = _manager(c)
	pm.start_new_turn()
	pm.go_to_phase(PhaseManager.Phase.BATTLE)
	pm.complete_current_phase({"battle_result": {"won": true}, "play_another": true})
	pm.go_to_phase(PhaseManager.Phase.BATTLE)
	pm.complete_current_phase({"battle_result": {"won": false, "draw": true}})
	assert_int(int(c.operational_map.player_battle_points)) \
		.override_failure_message("the draw cancelled the earlier win's PBP") \
		.is_equal(1)
	var last: Dictionary = c.battle_history[-1]
	assert_str(str(last.cp_basis)).is_equal("draw")
	assert_int((last.cp_dice as Array).size()).is_equal(3)
