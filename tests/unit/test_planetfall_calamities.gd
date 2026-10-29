extends GdUnitTestSuite

## Planetfall Calamities (pp.165-168): the setup each entry opens with, the rolls it makes
## "at the end of each campaign turn" (Step 18), what each mission does to it (Step 12),
## and the reward when it ends.
##
## ⚠ Before 2026-10-28 the Super Weapon advanced at TURN START with a raw die and was
## reported only by push_warning; no other Calamity rolled at all; no setup ran for any
## of the eight; and seven could never end, because nothing asked the table what only
## the table knows (an anomaly cleared, a Sleeper chip found, a Controller killed).
##
## Every case drives the path a player reaches and asserts campaign state.

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const PMScript = preload("res://src/core/campaign/PlanetfallPhaseManager.gd")
const CalamityScript = preload("res://src/core/systems/PlanetfallCalamitySystem.gd")
const MapScript = preload("res://src/core/systems/PlanetfallMap.gd")
const AutoResolve = preload("res://src/ui/screens/planetfall/panels/PlanetfallAutoResolveDialog.gd")
const SimpleDialog = preload("res://src/ui/screens/planetfall/panels/PlanetfallSimpleDialog.gd")
const RosterRules = preload("res://src/core/systems/PlanetfallRosterRules.gd")
const PostBattlePanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallPostBattlePanel.gd")
const Guide = preload("res://src/core/battle/PlanetfallBattleGuide.gd")
const CalamityPanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallCalamityPanel.gd")
const TurnScene = preload("res://src/ui/screens/planetfall/PlanetfallTurnController.tscn")
const MissionPanelScript = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallMissionPanel.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const Phase = PMScript.Phase
const MISSIONS := "res://data/planetfall/mission_types.json"
const CALAMITY_DATA := "res://data/planetfall/calamities.json"
const SLYN_CHECK := "Planetfall Slyn Aggression"

## D100 rolls inside each entry's range on the p.165 table.
const SWARM := 5
const ENVIRONMENTAL := 20
const SUPER_WEAPON := 30
const VIRUS := 40
const MEGA := 55
const WILDLIFE := 70
const ROBOT := 80
const SLYN := 95

const HOME := "2,2"

var _user_state: Dictionary
var _saved_campaign: Variant
var _dm: Node


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")
	_dm.clear_forced_results()


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


## A colony on a 6x6 map, home at R3 C3, one Tactical Enemy holding R1 C1. The map is
## generated before any roll is forced, so its site placement consumes nothing queued.
func _core(roster_size: int = 1) -> Resource:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.game_phase = "active"
	core.campaign_turn = 3
	core.grunts = 10
	core.colony_morale = 0
	core.colony_damage_mitigation = 0
	core.turn_damage_mitigation = 0
	var names := ["Ash", "Kip", "Rue", "Tam"]
	core.roster = []
	for i in range(roster_size):
		core.roster.append({"id": "c%d" % (i + 1), "name": names[i], "class": "trooper",
				"xp": 0})
	MapScript.generate(core, 6, 6, [2, 2], 4)
	core.tactical_enemies = [{"type": {"name": "Krorg Raiders"},
			"occupied_sectors": [MapScript.key(0, 0)]}]
	return core


func _pm(core: Resource) -> Node:
	var pm: Node = PMScript.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	return pm


func _force(key: String, values: Array) -> void:
	for v in values:
		_dm.queue_forced_result(key, v)


func _trigger(core: Resource, roll: int) -> Dictionary:
	return CalamityScript.new().trigger_calamity(core, roll)


## The live record, resolved or not.
func _record(core: Resource, calamity_id: String) -> Dictionary:
	for cal in core.active_calamities:
		if cal is Dictionary and str(cal.get("id", "")) == calamity_id:
			return cal
	return {}


func _progress(core: Resource, calamity_id: String) -> Dictionary:
	var cal := _record(core, calamity_id)
	if not cal.get("progress") is Dictionary:
		cal["progress"] = {}
	return cal["progress"]


func _resolved(core: Resource, calamity_id: String) -> bool:
	return bool(_record(core, calamity_id).get("resolved", false))


func _text(receipt: Dictionary) -> String:
	return "\n".join(receipt.get("lines", []).map(func(x): return str(x)))


func _flagged(core: Resource, flag: String) -> Array:
	return MapScript.flagged(core.map_data, flag)


## Replace whatever the Swarm's setup infested with `keys`.
func _swarm_only(core: Resource, keys: Array) -> void:
	for k in _flagged(core, "swarm"):
		MapScript.set_flag(core, str(k), "swarm", false)
	for k in keys:
		MapScript.set_flag(core, str(k), "swarm", true)


## The sectors one Swarm spread roll is made for (every sector adjacent to an infested one).
func _spread_candidates(core: Resource) -> int:
	var infested: Array = _flagged(core, "swarm")
	var seen: Array = []
	for s in infested:
		for k in MapScript.adjacent_keys(core.map_data, str(s)):
			if not seen.has(k) and not infested.has(k):
				seen.append(k)
	return seen.size()


## One mission through Step 12: the stamp, what the battle screen returned, the debrief.
func _step12(core: Resource, stamp: Dictionary, won: bool,
		debrief: Dictionary = {}) -> Dictionary:
	var pm := _pm(core)
	var s := {"mission_name": str(stamp.get("id", "")).capitalize(),
			"opposition_type": "tactical", "tactical_enemy_index": -1, "grunts_deployed": 0,
			"deployed_ids": ["c1"]}
	s.merge(stamp, true)
	pm.stamp_mission(s)
	pm.set_battle_result({"won": won, "victory": won, "crew_participants": core.roster.duplicate(true),
			"crew_injuries_data": [], "crew_casualties_data": []})
	pm.apply_battle_debrief(debrief)
	return pm.resolve_intel_step()


# ── Setup: each entry's opening paragraph ───────────────────────────────────────────

## p.165: "A random Tactical Enemy is building a super weapon", progress from 0.
func test_the_super_weapon_is_built_by_a_tactical_enemy_from_zero() -> void:
	var core := _core()
	var out := _trigger(core, SUPER_WEAPON)
	assert_str(str(out.get("id", ""))).is_equal("enemy_super_weapon")
	assert_int(int(_progress(core, "enemy_super_weapon").get("enemy_index", -9))).is_equal(0)
	assert_int(int(_progress(core, "enemy_super_weapon").get("weapon_progress", -9))).is_equal(0)
	assert_str(_text(out)).contains("Krorg Raiders is building a super weapon")


func test_with_no_enemy_on_the_map_the_weapon_site_meets_a_scouting_force() -> void:
	var core := _core()
	core.tactical_enemies = []
	var out := _trigger(core, SUPER_WEAPON)
	assert_int(int(_progress(core, "enemy_super_weapon").get("enemy_index", -9))).is_equal(-1)
	assert_str(_text(out)).contains("minor scouting force")


## p.165: "Randomly select 3 map sectors. They can be enemy held."
func test_environmental_risk_marks_three_anomalous_sectors_never_the_colony() -> void:
	var core := _core()
	_trigger(core, ENVIRONMENTAL)
	var anomalies := _flagged(core, "anomaly")
	assert_int(anomalies.size()).is_equal(3)
	assert_bool(anomalies.has(HOME)).override_failure_message(
		"the colony's own sector was made anomalous").is_false()


## p.167: "Randomly select a map sector that is not enemy held. It is immediately infested".
func test_the_swarm_infests_one_sector_that_is_neither_the_colony_nor_enemy_held() -> void:
	var core := _core()
	_trigger(core, SWARM)
	var swarm := _flagged(core, "swarm")
	assert_int(swarm.size()).is_equal(1)
	assert_bool(swarm.has(HOME) or swarm.has(MapScript.key(0, 0))).is_false()


## p.168: "Randomly select two characters on your roster and roll 1D6 for each ... If the
## roll is a 6, they immediately fall ill." Ill means quarantined in Sick Bay.
func test_the_virus_exposes_two_characters_and_quarantines_a_6() -> void:
	var core := _core(2)
	_force(CalamityScript.VIRUS_DIE, [6, 3])
	_trigger(core, VIRUS)
	var points: Dictionary = _progress(core, "virus").get("virus_points", {})
	var values: Array = points.values().map(func(v): return int(v))
	values.sort()
	assert_array(values).is_equal([3, 6])
	var ill: String = str(points.keys().filter(func(k): return int(points[k]) == 6)[0])
	assert_bool(core.is_quarantined(ill)).is_true()
	assert_int(int(core.sick_bay.get(ill, 0))).is_greater_equal(1)
	assert_int(core.quarantined.size()).is_equal(1)


## The four battlefield Calamities roll nothing at Step 18.
func test_a_battlefield_calamity_owes_no_end_of_turn_roll() -> void:
	var core := _core()
	for roll in [MEGA, WILDLIFE, ROBOT, SLYN]:
		_trigger(core, roll)
	assert_int(CalamityScript.new().get_calamity_count(core)).is_equal(4)
	assert_bool(_pm(core).calamity_step_owed()).is_false()
	_trigger(core, SUPER_WEAPON)
	assert_bool(_pm(core).calamity_step_owed()).is_true()


# ── Step 18: "at the end of each campaign turn" ────────────────────────────────────

## p.165: "The enemy will complete 1D6 points of progress at the end of every campaign
## turn."
func test_the_super_weapon_advances_1d6_at_the_end_of_the_turn() -> void:
	var core := _core()
	_trigger(core, SUPER_WEAPON)
	_force(CalamityScript.WEAPON_PROGRESS_DIE, [4])
	var receipt: Dictionary = _pm(core).resolve_calamity_step()
	assert_int(int(_progress(core, "enemy_super_weapon").weapon_progress)).is_equal(4)
	assert_str(_text(receipt)).contains("progress 4 of 15")


## p.165: at 15 "the weapon is launched and will inflict 3D6 damage to your colony. Every 6
## rolled on the damage roll also causes a randomly selected character to make a roll on
## the Post-Battle Injury table ... starting again from 0."
func test_at_15_the_weapon_launches_for_3d6_and_an_injury_roll_per_6() -> void:
	var core := _core()
	_trigger(core, SUPER_WEAPON)
	_progress(core, "enemy_super_weapon")["weapon_progress"] = 12
	var integrity_before: int = core.colony_integrity
	_force(CalamityScript.WEAPON_PROGRESS_DIE, [3])
	_force(CalamityScript.WEAPON_DAMAGE_DIE, [6, 2, 1])
	var text := _text(_pm(core).resolve_calamity_step())
	assert_int(integrity_before - core.colony_integrity).is_equal(9)
	assert_int(int(_progress(core, "enemy_super_weapon").weapon_progress)).override_failure_message(
		"building the next weapon starts again from 0").is_equal(0)
	assert_str(text).contains("LAUNCHED")
	assert_int(text.count("rolls on the Post-Battle Injury table")).is_equal(1)


## A resumed Step 18 shows what it rolled and rolls nothing twice.
func test_step_18_rolls_once_even_across_a_resume() -> void:
	var core := _core()
	_trigger(core, SUPER_WEAPON)
	_force(CalamityScript.WEAPON_PROGRESS_DIE, [4])
	var pm := _pm(core)
	var first: Dictionary = pm.resolve_calamity_step()
	pm.resolve_calamity_step()
	# The controller's resume path (PlanetfallTurnController :195).
	var resumed := _pm(core)
	resumed.restore_from_campaign()
	assert_bool(resumed.get_calamity_receipt().is_empty()).override_failure_message(
		"the resumed phase manager lost the receipt").is_false()
	resumed.resolve_calamity_step()
	assert_int(int(_progress(core, "enemy_super_weapon").weapon_progress)).override_failure_message(
		"Step 18 rolled again").is_equal(4)
	assert_array(resumed.get_calamity_receipt().get("lines", [])).is_equal(first.lines)


## pp.165-166: a D6 per anomaly, 5-6 a flare-up on the 1D6 table: 3-4 is 1 Colony Damage
## "that bypasses all defenses", 6 another sector develops an anomaly.
func test_an_anomaly_flares_up_on_5_or_6() -> void:
	var core := _core()
	core.colony_damage_mitigation = 5
	_trigger(core, ENVIRONMENTAL)
	var integrity_before: int = core.colony_integrity
	_force(CalamityScript.ANOMALY_DIE, [1, 5, 6])
	_force(CalamityScript.FLARE_UP_DIE, [3, 6])
	var text := _text(_pm(core).resolve_calamity_step())
	assert_int(integrity_before - core.colony_integrity).override_failure_message(
		"the flare-up's damage must bypass mitigation").is_equal(1)
	assert_int(_flagged(core, "anomaly").size()).is_equal(4)
	assert_str(text).contains("no effect (p.165)")


## Flare-up 1-2: "A random character is injured and must spend one campaign turn in Sick Bay."
func test_a_flare_up_of_1_or_2_puts_a_character_in_sick_bay() -> void:
	var core := _core()
	_trigger(core, ENVIRONMENTAL)
	_force(CalamityScript.ANOMALY_DIE, [5, 1, 1])
	_force(CalamityScript.FLARE_UP_DIE, [2])
	_pm(core).resolve_calamity_step()
	assert_int(int(core.sick_bay.get("c1", 0))).is_equal(1)


## p.167: "If they infest a sector held by an enemy, the enemy loses the sector".
func test_the_swarm_takes_an_enemy_held_sector_first() -> void:
	var core := _core()
	core.tactical_enemies[0].occupied_sectors = [MapScript.key(0, 0), MapScript.key(5, 5)]
	_trigger(core, SWARM)
	_swarm_only(core, [MapScript.key(0, 1)])
	_force(CalamityScript.SWARM_SPREAD_DIE, [6])
	_pm(core).resolve_calamity_step()
	assert_bool(_flagged(core, "swarm").has(MapScript.key(0, 0))).override_failure_message(
		"the enemy-held sector is tested first, and a 6 infests it").is_true()
	assert_array(MapScript.held_by(core, 0)).is_equal([MapScript.key(5, 5)])


## "... unless it was their final sector they held, in which case they evacuate to another
## random map sector."
func test_an_enemy_losing_its_last_sector_to_the_swarm_evacuates() -> void:
	var core := _core()
	_trigger(core, SWARM)
	_swarm_only(core, [MapScript.key(0, 1)])
	_force(CalamityScript.SWARM_SPREAD_DIE, [6])
	_pm(core).resolve_calamity_step()
	var held: Array = MapScript.held_by(core, 0)
	assert_int(held.size()).is_equal(1)
	var dest: String = str(held[0])
	assert_str(dest).is_not_equal(MapScript.key(0, 0))
	assert_str(dest).is_not_equal(HOME)
	assert_bool(_flagged(core, "swarm").has(dest)).is_false()


## p.167: "If the Swarm would expand into your colony sector, you must fight a Pitched
## Battle mission next campaign turn."
func test_the_swarm_reaching_the_colony_forces_a_pitched_battle_next_turn() -> void:
	var core := _core()
	_trigger(core, SWARM)
	_swarm_only(core, [MapScript.key(1, 1)])
	var misses: Array = []
	for _i in range(_spread_candidates(core) - 1):
		misses.append(1)
	_force(CalamityScript.SWARM_SPREAD_DIE, misses + [6])
	_force(CalamityScript.SWARM_ATTACK_DIE, [1])
	_pm(core).resolve_calamity_step()
	assert_bool(_flagged(core, "swarm").has(HOME)).override_failure_message(
		"the colony sector is never infested, it is fought for").is_false()
	assert_dict(core.get_mission_offer("pitched_battle")).override_failure_message(
		"the offer must not be live this turn").is_empty()
	core.campaign_turn += 1
	var offer: Dictionary = core.get_mission_offer("pitched_battle")
	assert_bool(bool(offer.get("forced", false)) and bool(offer.get("swarm", false))).is_true()


## p.167: a Swarm sector adjacent to the colony attacks: "On a 6, you take 6 Damage and one
## of your grunts is killed."
func test_a_swarm_on_the_perimeter_breaks_through_on_a_6() -> void:
	var core := _core()
	_trigger(core, SWARM)
	_swarm_only(core, [MapScript.key(1, 1)])
	var misses: Array = []
	for _i in range(_spread_candidates(core)):
		misses.append(1)
	_force(CalamityScript.SWARM_SPREAD_DIE, misses)
	_force(CalamityScript.SWARM_ATTACK_DIE, [6])
	var integrity_before: int = core.colony_integrity
	_pm(core).resolve_calamity_step()
	assert_int(integrity_before - core.colony_integrity).is_equal(6)
	assert_int(core.grunts).is_equal(9)


## "On 3-5, your colony takes damage equal to the die roll."
func test_a_swarm_on_the_perimeter_does_damage_equal_to_a_3_to_5() -> void:
	var core := _core()
	_trigger(core, SWARM)
	_swarm_only(core, [MapScript.key(1, 1)])
	var misses: Array = []
	for _i in range(_spread_candidates(core)):
		misses.append(1)
	_force(CalamityScript.SWARM_SPREAD_DIE, misses)
	_force(CalamityScript.SWARM_ATTACK_DIE, [4])
	var integrity_before: int = core.colony_integrity
	_pm(core).resolve_calamity_step()
	assert_int(integrity_before - core.colony_integrity).is_equal(4)
	assert_int(core.grunts).is_equal(10)


## p.168: 2D6 at or below the Cure Data: "The virus no longer spreads, and your characters
## recover immediately." The reward: 4 turns of injury recovery, "You can save any of this
## effect for later." Injury time owed under the quarantine stays owed.
func test_the_cure_ends_the_virus_and_keeps_owed_injury_time() -> void:
	var core := _core(3)
	_force(CalamityScript.VIRUS_DIE, [1, 1])
	_trigger(core, VIRUS)
	core.add_to_sick_bay("c1", 3)
	core.quarantine("c1")
	_progress(core, "virus")["cure_data"] = 4
	_force(CalamityScript.CURE_DIE, [3])
	_pm(core).resolve_calamity_step()
	assert_bool(_resolved(core, "virus")).is_true()
	assert_bool(core.is_quarantined("c1")).is_false()
	assert_int(int(core.sick_bay.get("c1", 0))).is_equal(3)
	assert_int(core.recovery_reduction_bank).is_equal(4)


## p.168: "At the end of each campaign turn, select three characters": a character with
## Virus Points gains +1 and falls ill at 6; one without rolls as at setup.
func test_the_virus_spreads_to_three_healthy_characters() -> void:
	var core := _core(4)
	_force(CalamityScript.VIRUS_DIE, [1, 1])
	_trigger(core, VIRUS)
	var p := _progress(core, "virus")
	p["virus_points"] = {"c2": 5, "c3": 2}
	p["cure_data"] = 4
	core.quarantine("c1")
	_force(CalamityScript.CURE_DIE, [12])
	_force(CalamityScript.VIRUS_DIE, [4])
	var text := _text(_pm(core).resolve_calamity_step())
	assert_str(text).contains("not yet (p.168)")
	assert_bool(core.is_quarantined("c2")).override_failure_message(
		"5 Virus Points + 1 = 6 falls ill").is_true()
	assert_bool(core.is_quarantined("c3") or core.is_quarantined("c4")).is_false()
	var points: Dictionary = p.virus_points
	assert_bool(points.has("c1")).override_failure_message(
		"a quarantined character was exposed again").is_false()
	assert_int(int(points.get("c3", 0))).override_failure_message(
		"a character with Virus Points gains +1, rolling nothing").is_equal(3)
	assert_int(int(points.get("c4", 0))).override_failure_message(
		"a character without Virus Points rolls as at setup").is_equal(4)


## p.168: quarantined until the cure; the injury beneath still heals.
func test_a_quarantine_holds_through_the_sick_bay_tick() -> void:
	var core := _core()
	core.add_to_sick_bay("c1", 1)
	core.quarantine("c1")
	for _i in range(3):
		core.tick_sick_bay()
	assert_bool(core.sick_bay.has("c1")).is_true()
	core.release_quarantine()
	assert_bool(core.sick_bay.has("c1")).override_failure_message(
		"the injury beneath had healed, so the release frees the character").is_false()


# ── Step 12: what each mission does to an active Calamity ──────────────────────────

## p.165: "Once successful, you can then play out a Strike mission, with success destroying
## the weapon production capability. This ends the Calamity." Reward: "roll twice on the
## Post-Mission Finds table".
func test_a_won_strike_on_the_builder_ends_the_weapon_with_two_finds() -> void:
	var core := _core()
	_trigger(core, SUPER_WEAPON)
	_force(CalamityScript.FIND_DIE, [50, 50])
	var text := _text(_step12(core, {"id": "strike", "tactical_enemy_index": 0}, true))
	assert_bool(_resolved(core, "enemy_super_weapon")).is_true()
	assert_int(text.count("Post-Mission Find, D100 50")).is_equal(2)


func test_a_strike_on_another_enemy_leaves_the_weapon() -> void:
	var core := _core()
	core.tactical_enemies.append({"type": {"name": "Hive Drones"},
			"occupied_sectors": [MapScript.key(5, 5)]})
	_force(CalamityScript.PICK_DIE, [1])
	_trigger(core, SUPER_WEAPON)
	assert_int(int(_progress(core, "enemy_super_weapon").enemy_index)).is_equal(0)
	_step12(core, {"id": "strike", "tactical_enemy_index": 1}, true)
	assert_bool(_resolved(core, "enemy_super_weapon")).is_false()


## p.166: "Once all three Objectives are clear, a character must move into contact ... and
## roll 1D6+Savvy, scoring a 6 or better" clears the anomaly, +2 Raw Materials.
func test_a_patrol_clears_an_anomaly_only_with_all_three_objectives() -> void:
	var core := _core()
	_trigger(core, ENVIRONMENTAL)
	var k: String = str(_flagged(core, "anomaly")[0])
	var rm_before: int = core.raw_materials
	_step12(core, {"id": "patrol", "sector": k}, true,
			{"objectives_completed": 2, "calamity": {"anomaly_cleared": true}})
	assert_bool(_flagged(core, "anomaly").has(k)).is_true()
	assert_int(core.raw_materials).is_equal(rm_before)


func test_clearing_an_anomaly_pays_2_raw_materials_and_the_last_ends_it() -> void:
	var core := _core()
	_trigger(core, ENVIRONMENTAL)
	var anomalies := _flagged(core, "anomaly")
	var k: String = str(anomalies[0])
	var rm_before: int = core.raw_materials
	_step12(core, {"id": "patrol", "sector": k}, true,
			{"objectives_completed": 3, "calamity": {"anomaly_cleared": true}})
	assert_bool(_flagged(core, "anomaly").has(k)).is_false()
	assert_int(core.raw_materials - rm_before).is_equal(2)
	assert_bool(_resolved(core, "environmental_risk")).override_failure_message(
		"two anomalies remain").is_false()

	var last := _core()
	_trigger(last, ENVIRONMENTAL)
	var only: String = str(_flagged(last, "anomaly")[0])
	for other in _flagged(last, "anomaly"):
		if str(other) != only:
			MapScript.set_flag(last, str(other), "anomaly", false)
	_step12(last, {"id": "patrol", "sector": only}, true,
			{"objectives_completed": 3, "calamity": {"anomaly_cleared": true}})
	assert_bool(_resolved(last, "environmental_risk")).is_true()


## p.166: "You must kill 5 such Lifeforms to end the Calamity." Reward: "Randomly select
## three map sectors and increase their Resource ratings by +1 each."
func test_five_marked_lifeforms_end_the_mega_predators_and_raise_three_sectors() -> void:
	var core := _core()
	_trigger(core, MEGA)
	_progress(core, "mega_predators")["enhanced_killed"] = 3
	_step12(core, {"id": "patrol"}, true, {"calamity": {"marked_lifeforms_killed": 2}})
	assert_bool(_resolved(core, "mega_predators")).is_true()
	var raised: Array = MapScript.all_keys(core.map_data).filter(func(x):
		return int(MapScript.sector(core.map_data, x).get("resource_bonus", 0)) == 1)
	assert_int(raised.size()).is_equal(3)
	assert_bool(raised.has(HOME)).is_false()


## p.166: chips come from "a Sleeper outside of a Delve mission"; 5 chips end it and "Add
## 4 Research Points".
func test_five_sleeper_chips_end_the_rampage_for_4_research_points() -> void:
	var core := _core()
	_trigger(core, ROBOT)
	var rp_before: int = int(core.research_data.get("current_rp", 0))
	_step12(core, {"id": "patrol"}, true, {"calamity": {"sleeper_chips": 5}})
	assert_bool(_resolved(core, "robot_rampage")).is_true()
	assert_int(int(core.research_data.get("current_rp", 0)) - rp_before).is_equal(4)


func test_sleeper_chips_on_a_delve_do_not_count() -> void:
	var core := _core()
	_trigger(core, ROBOT)
	_step12(core, {"id": "delve"}, true, {"calamity": {"sleeper_chips": 5}})
	assert_bool(_resolved(core, "robot_rampage")).is_false()
	assert_int(int(_progress(core, "robot_rampage").get("chips_collected", 0))).is_equal(0)


## p.167: "Once you have killed 30, they decide to step down their offensive." Reward: "add
## 2 grunts".
func test_thirty_slyn_killed_end_the_assault_for_two_grunts() -> void:
	var core := _core()
	_trigger(core, SLYN)
	_step12(core, {"id": "patrol", "opposition_type": "slyn"}, true,
			{"calamity": {"slyn_killed": 30}})
	assert_bool(_resolved(core, "slyn_assault")).is_true()
	assert_int(core.grunts).is_equal(12)


## p.167: "This uses the Skirmish mission. Victory clears out the sector". p.168: it ends
## "when every sector has been cleared"; reward: a trooper recruit, saved for later.
func test_a_won_skirmish_clears_the_swarm_and_the_last_ends_it() -> void:
	var core := _core()
	_trigger(core, SWARM)
	var k: String = str(_flagged(core, "swarm")[0])
	_step12(core, {"id": "skirmish", "sector": k}, true)
	assert_bool(_flagged(core, "swarm").is_empty()).is_true()
	assert_bool(_resolved(core, "swarm_infestation")).is_true()
	assert_int(core.bonus_recruits).is_equal(1)


## p.168: "Each time you complete the mission you receive two points of Cure Data."
func test_a_won_hunt_brings_back_two_cure_data() -> void:
	var core := _core(2)
	_force(CalamityScript.VIRUS_DIE, [1, 1])
	_trigger(core, VIRUS)
	_step12(core, {"id": "hunt"}, true)
	assert_int(int(_progress(core, "virus").get("cure_data", 0))).is_equal(2)


## p.168: "Killing the Controller and moving into base contact with where it fell ... ends
## the Calamity." Reward: "You may add 1 Augmentation Point."
func test_a_confirmed_controller_kill_ends_the_wildlife_for_an_augmentation_point() -> void:
	var core := _core()
	_trigger(core, WILDLIFE)
	var before: int = core.augmentation_points
	_step12(core, {"id": "hunt"}, true, {"calamity": {"controller_killed": true}})
	assert_bool(_resolved(core, "wildlife_aggression")).is_true()
	assert_int(core.augmentation_points - before).is_equal(1)


# ── The screens ─────────────────────────────────────────────────────────────────────

func _step18_dialog(core: Resource, pm: Node) -> Control:
	var panel: Control = AutoResolve.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.configure("update_tracking", Phase.UPDATE_TRACKING)
	panel.refresh()
	return panel


func _shown(panel: Control) -> String:
	var out: Array[String] = []
	for n in panel._result_container.find_children("*", "RichTextLabel", true, false):
		out.append((n as RichTextLabel).text)
	return "\n".join(out)


## Step 18 waits for the roll when a Calamity owes one, and shows it once rolled.
func test_step_18_rolls_the_active_calamities_on_the_turn_screen() -> void:
	var core := _core()
	_trigger(core, SUPER_WEAPON)
	var pm := _pm(core)
	var panel := _step18_dialog(core, pm)
	assert_bool(panel.step_status().ready).override_failure_message(
		"a Calamity roll is owed, so the step must wait for it").is_false()
	_force(CalamityScript.WEAPON_PROGRESS_DIE, [5])
	panel.complete()
	assert_int(int(_progress(core, "enemy_super_weapon").weapon_progress)).is_equal(5)
	assert_str(_shown(panel)).contains("progress 5 of 15")
	var reopened := _step18_dialog(core, pm)
	assert_bool(reopened.step_status().ready).is_true()
	assert_str(_shown(reopened)).contains("progress 5 of 15")


func _debrief_panel(core: Resource, pm: Node) -> Control:
	var panel: Control = auto_free(PostBattlePanel.new())
	add_child(panel)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.set_battle_results(pm.get_battle_result())
	panel._build_debrief()
	return panel


## The debrief asks a Hunt whether the Controller died, and the answer ends the Calamity.
func test_the_debrief_asks_the_controller_question_and_the_answer_lands() -> void:
	var core := _core()
	_trigger(core, WILDLIFE)
	var pm := _pm(core)
	pm.stamp_mission({"id": "hunt", "deployed_ids": ["c1"]})
	pm.set_battle_result({"won": true, "crew_participants": core.roster.duplicate(true),
			"crew_injuries_data": []})
	var panel := _debrief_panel(core, pm)
	var input: Variant = panel._calamity_inputs.get("controller_killed")
	assert_bool(input is CheckBox).override_failure_message(
		"the Hunt's debrief must ask about the Controller (p.168)").is_true()
	(input as CheckBox).button_pressed = true
	var before: int = core.augmentation_points
	pm.apply_battle_debrief(panel._collect_debrief())
	pm.resolve_intel_step()
	assert_bool(_resolved(core, "wildlife_aggression")).is_true()
	assert_int(core.augmentation_points - before).is_equal(1)


## A mission the rule does not name is asked nothing.
func test_a_patrol_is_not_asked_about_the_controller() -> void:
	var core := _core()
	_trigger(core, WILDLIFE)
	var pm := _pm(core)
	pm.stamp_mission({"id": "patrol", "deployed_ids": ["c1"]})
	pm.set_battle_result({"won": true, "crew_participants": [], "crew_injuries_data": []})
	var panel := _debrief_panel(core, pm)
	assert_dict(panel._calamity_inputs).is_empty()


## The anomaly question needs the patrol to be in an anomalous sector.
func test_a_patrol_in_an_anomaly_is_asked_whether_it_was_cleared() -> void:
	var core := _core()
	_trigger(core, ENVIRONMENTAL)
	var k: String = str(_flagged(core, "anomaly")[0])
	var pm := _pm(core)
	pm.stamp_mission({"id": "patrol", "sector": k, "deployed_ids": ["c1"]})
	pm.set_battle_result({"won": true, "crew_participants": [], "crew_injuries_data": []})
	var panel := _debrief_panel(core, pm)
	assert_bool(panel._calamity_inputs.get("anomaly_cleared") is CheckBox).is_true()



# ── Battle time (C-c): what each Calamity changes on the table ──────────────────────

func _mission(id: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MISSIONS))
	for m in data.get("missions", []):
		if m is Dictionary and str(m.get("id", "")) == id:
			return (m as Dictionary).duplicate(true)
	return {}


func _site_keys(core: Resource, mission_id: String) -> Array:
	return MapScript.mission_sites(core, _mission(mission_id)).map(
			func(s: Dictionary) -> String: return str(s.key))


## What Step 6 offers: the mission screen asks PlanetfallMap.mission_availability() of
## every mission (PlanetfallMissionPanel._build_mission_list). This read
## PlanetfallMissionSetup.get_available_missions(), which nothing in the app called
## (deleted 2026-10-28).
func _available(core: Resource) -> Array:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MISSIONS))
	var out: Array = []
	for m in data.get("missions", []):
		if m is Dictionary and bool(MapScript.mission_availability(core, m).available):
			out.append(str(m.id))
	return out


## p.167: "you must roll twice to see if they interfere. If both rolls indicate
## interference, you will automatically encounter 8 Slyn."
func test_a_slyn_assault_rolls_twice_and_two_attacks_field_8_slyn() -> void:
	_force(SLYN_CHECK, [3, 3])
	# A 1 on the size die is 6 Slyn (p.153), so only the p.167 rule can make it 8.
	_force(Guide.SLYN_SIZE_DIE, [1])
	var r: Dictionary = Guide.resolve_opposition(_mission("exploration"), false, true)
	assert_str(str(r.type)).is_equal("slyn")
	assert_bool(bool(r.slyn_eight)).is_true()
	assert_str(str(r.line)).contains("Slyn assault (p.167)")
	var force: Dictionary = Guide.build_force(null, "slyn", {}, -1, true)
	assert_int((force.enemies as Array).size()).is_equal(8)


func test_in_a_slyn_assault_either_check_brings_the_slyn() -> void:
	_force(SLYN_CHECK, [9, 3, 9, 9])
	var one: Dictionary = Guide.resolve_opposition(_mission("exploration"), false, true)
	assert_str(str(one.type)).is_equal("slyn")
	assert_bool(bool(one.slyn_eight)).is_false()
	var neither: Dictionary = Guide.resolve_opposition(_mission("exploration"), false, true)
	assert_str(str(neither.type)).is_equal("lifeforms")


func test_without_an_assault_one_check_is_rolled() -> void:
	_force(SLYN_CHECK, [9, 3])
	assert_str(str(Guide.resolve_opposition(_mission("exploration")).type)).is_equal("lifeforms")
	assert_str(str(Guide.resolve_opposition(_mission("exploration")).type)) \
		.override_failure_message("the first call consumed the second check").is_equal("slyn")


## p.168: "Roll 2D6+4 for the number of Swarm encountered", on the Swarm profile.
func test_a_swarm_battle_fields_2d6_plus_4_on_the_swarm_profile() -> void:
	var mission := _mission("skirmish")
	mission["swarm"] = true
	assert_str(str(Guide.resolve_opposition(mission).type)).is_equal("swarm")
	_force(CalamityScript.SWARM_NUMBER_DIE, [7])
	var force: Dictionary = Guide.build_force(null, "swarm", {}, -1)
	var enemies: Array = force.enemies
	assert_int(enemies.size()).is_equal(11)
	assert_int(int(enemies[0].speed)).is_equal(6)
	assert_int(int(enemies[0].combat_skill)).is_equal(1)
	assert_int(int(enemies[0].toughness)).is_equal(4)
	assert_str(str(force.rows[0].head)).contains("2D6+4 = 11")


func test_the_swarm_number_in_the_data_is_the_engines() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CALAMITY_DATA))
	var found: bool = false
	for e in data.entries:
		if str(e.get("id", "")) == "swarm_infestation":
			found = true
			assert_str(str(e.enemy_profile.number)).is_equal(
					"2D6+%d" % CalamityScript.SWARM_NUMBER_BONUS)
	assert_bool(found).is_true()


## p.167: "The Swarm prevents all access to sectors they occupy", and "To defeat the
## Swarm ... This uses the Skirmish mission."
func test_an_infested_sector_is_closed_to_every_mission_but_the_skirmish() -> void:
	var core := _core()
	_trigger(core, SWARM)
	var k: String = str(_flagged(core, "swarm")[0])
	assert_bool(_site_keys(core, "patrol").has(k)).is_false()
	assert_bool(MapScript.explore_targets(core).has(k)).is_false()
	var swarm_sites: Array = MapScript.mission_sites(core, _mission("skirmish")).filter(
			func(s: Dictionary) -> bool: return str(s.key) == k)
	assert_int(swarm_sites.size()).is_equal(1)
	assert_bool(bool(swarm_sites[0].get("swarm", false))).is_true()


func test_the_swarm_skirmish_is_offered_with_no_tactical_enemy_on_the_map() -> void:
	var core := _core()
	core.tactical_enemies = []
	assert_bool(_available(core).has("skirmish")).is_false()
	_trigger(core, SWARM)
	assert_bool(_available(core).has("skirmish")).override_failure_message(
		"the Skirmish is how the Swarm is fought, enemy or not").is_true()


func test_the_swarm_at_the_colony_names_itself_and_page_167() -> void:
	var core := _core()
	core.offer_mission("pitched_battle", {"enemy_index": -1, "forced": true, "swarm": true})
	var patrol: Dictionary = MapScript.mission_availability(core, _mission("patrol"))
	assert_bool(bool(patrol.available)).is_false()
	assert_str(str(patrol.reason)).contains("The Swarm has reached the colony")
	assert_str(str(patrol.reason)).contains("p.167")
	var sites: Array = MapScript.mission_sites(core, _mission("pitched_battle"))
	assert_str(str(sites[0].label)).contains("the Swarm attacks")
	assert_bool(bool(sites[0].swarm)).is_true()


## p.165: with no Tactical Enemy building it, the weapon site is fought as a minor
## scouting force; while the builder holds the map, its Boss is what the Strike finds.
func test_with_no_builder_the_weapon_site_is_open_to_a_strike() -> void:
	var core := _core()
	core.tactical_enemies = []
	_trigger(core, SUPER_WEAPON)
	var site: String = MapScript.weapon_site(core)
	assert_str(site).is_not_empty()
	assert_str(site).is_not_equal(HOME)
	assert_bool(_site_keys(core, "strike").has(site)).is_true()
	assert_bool(_available(core).has("strike")).is_true()


func test_while_the_builder_is_on_the_map_the_site_stays_closed() -> void:
	var core := _core()
	_trigger(core, SUPER_WEAPON)
	assert_str(MapScript.weapon_site(core)).is_empty()
	core.tactical_enemies[0]["defeated"] = true
	assert_str(MapScript.weapon_site(core)).override_failure_message(
		"a defeated builder leaves the site to its scouting force").is_not_empty()


func test_a_won_strike_on_the_weapon_site_ends_the_weapon() -> void:
	var core := _core()
	core.tactical_enemies = []
	_trigger(core, SUPER_WEAPON)
	_step12(core, {"id": "strike", "weapon_site": true}, true)
	assert_bool(_resolved(core, "enemy_super_weapon")).is_true()


## The rules each Calamity adds reach the battle in the Calamity's own data text.
func test_robot_rampage_rules_reach_every_battle_and_chips_only_outside_a_delve() -> void:
	var core := _core()
	_trigger(core, ROBOT)
	var cal := CalamityScript.new()
	var patrol: Array = cal.battle_rows(core, "patrol", "", "lifeforms")
	assert_int(patrol.size()).is_equal(1)
	assert_str(str(patrol[0].head)).contains("(Planetfall p.166)")
	assert_str(str(patrol[0].detail)).contains("Sleeper chips found: 0 of 5.")
	assert_str(str(patrol[0].detail)).contains("Kill Sleepers outside Delve")
	var delve: Array = cal.battle_rows(core, "delve", "", "delve_hazards")
	assert_str(str(delve[0].detail)).not_contains("Kill Sleepers outside Delve")


func test_the_anomaly_rules_ride_only_a_patrol_into_that_sector() -> void:
	var core := _core()
	_trigger(core, ENVIRONMENTAL)
	var cal := CalamityScript.new()
	var anomalies := _flagged(core, "anomaly")
	var k: String = str(anomalies[0])
	var clear: String = str(MapScript.all_keys(core.map_data).filter(func(x: String) -> bool:
		return x != HOME and not anomalies.has(x))[0])
	assert_int(cal.battle_rows(core, "patrol", k, "lifeforms").size()).is_equal(1)
	assert_int(cal.battle_rows(core, "patrol", clear, "lifeforms").size()).is_equal(0)
	assert_int(cal.battle_rows(core, "hunt", k, "lifeforms").size()).is_equal(0)


## The launch hands the battle screen both: the assault's double check, and the rows.
func test_the_launch_carries_the_assault_check_and_the_calamity_rows() -> void:
	var core := _core()
	_trigger(core, ROBOT)
	_trigger(core, SLYN)
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	gs.current_campaign = core
	var tc: Control = TurnScene.instantiate()
	add_child(tc)
	auto_free(tc)
	await get_tree().process_frame
	await get_tree().process_frame
	tc._mission_context = _mission("exploration")
	tc._deployed_data = {}
	_force(SLYN_CHECK, [3, 3])
	# A 1 on the size die is 6 Slyn (p.153), so only the p.167 rule can make it 8.
	_force(Guide.SLYN_SIZE_DIE, [1])
	var payload: Dictionary = tc.build_battle_payload()
	assert_str(str(payload.stamp.opposition_type)).is_equal("slyn")
	assert_int((payload.context.enemies as Array).size()).is_equal(8)
	var heads: String = "\n".join((payload.context.mission_data.opposition_force_rows as Array)
			.map(func(r: Dictionary) -> String: return str(r.head)))
	assert_str(heads).contains("Slyn assault (p.167)")
	assert_str(heads).contains("Robot rampage (Planetfall p.166)")
	assert_str(heads).contains("Slyn assault (Planetfall p.167)")


# ── The Calamity panel (C-d) ────────────────────────────────────────────────────────

func _labels(node: Node) -> String:
	var out: Array[String] = []
	for n in node.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	return "\n".join(out)


func test_the_calamity_panel_shows_progress_the_engine_keeps() -> void:
	var core := _core()
	_trigger(core, SUPER_WEAPON)
	_trigger(core, SWARM)
	_trigger(core, MEGA)
	var panel: Control = CalamityPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel.refresh()
	var shown := _labels(panel)
	assert_str(shown).contains("Weapon progress: 0 of 15.")
	assert_str(shown).contains("Infested sectors (1)")
	assert_str(shown).override_failure_message(
		"a Calamity with no progress yet must still show where it stands") \
		.contains("Marked Lifeforms killed: 0 of 5.")


## The site a player picks carries its Calamity into the turn: the Swarm, or the weapon.
func test_the_mission_panel_hands_on_a_swarm_or_weapon_site() -> void:
	var panel: Control = auto_free(MissionPanelScript.new())
	add_child(panel)
	panel.set_campaign(_core())
	var emitted: Array = []
	panel.phase_completed.connect(func(d: Dictionary) -> void: emitted.append(d))
	panel._selected_mission = _mission("skirmish")
	panel._selected_site = {"key": "0,1", "enemy_index": -1, "swarm": true}
	panel._on_confirm_pressed()
	panel._selected_mission = _mission("strike")
	panel._selected_site = {"key": "4,4", "enemy_index": -1, "weapon_site": true}
	panel._on_confirm_pressed()
	assert_int(emitted.size()).is_equal(2)
	assert_bool(bool(emitted[0].selected_mission.get("swarm", false))).is_true()
	assert_bool(bool(emitted[1].selected_mission.get("weapon_site", false))).is_true()


## p.165: the weapon site's scouting force is "not connected to any other group", so the
## Strike does not field whichever enemy happens to be first on the list.
func test_a_weapon_site_strike_is_stamped_and_fights_the_scouting_force() -> void:
	var core := _core()
	_trigger(core, SUPER_WEAPON)
	core.tactical_enemies[0]["defeated"] = true
	core.tactical_enemies.append({"type": {"name": "Hive Drones"},
			"occupied_sectors": [MapScript.key(5, 5)]})
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	gs.current_campaign = core
	var tc: Control = TurnScene.instantiate()
	add_child(tc)
	auto_free(tc)
	await get_tree().process_frame
	await get_tree().process_frame
	var mission := _mission("strike")
	mission["weapon_site"] = true
	mission["sector"] = MapScript.weapon_site(core)
	tc._mission_context = mission
	tc._deployed_data = {}
	var payload: Dictionary = tc.build_battle_payload()
	assert_bool(bool(payload.stamp.get("weapon_site", false))).is_true()
	assert_int(int(payload.stamp.tactical_enemy_index)).override_failure_message(
		"the scouting force was replaced by the Hive Drones").is_equal(-1)


# ── The reward banks reach their steps (p.168) ──────────────────────────────────────

func _recovery_dialog(core: Resource) -> Control:
	var d: Control = auto_free(AutoResolve.new())
	add_child(d)
	d.set_campaign(core)
	d.set_phase_manager(_pm(core))
	d.configure("recovery", Phase.RECOVERY)
	d.refresh()
	return d


## p.168 Virus reward: "reduce any injury recovery times for injured characters by a
## total of 4 turns". Spent at Step 1, before the turn's own healing (p.58).
func test_banked_recovery_turns_are_spent_at_step_1_before_the_turn_heals() -> void:
	var core := _core(2)
	core.sick_bay = {"c1": 4, "c2": 1}
	core.recovery_reduction_bank = 4
	var d := _recovery_dialog(core)
	assert_bool(d._recovery_spins.has("c2")).override_failure_message(
		"a character on their last turn heals this turn anyway").is_false()
	var spin: SpinBox = d._recovery_spins["c1"]
	assert_int(int(spin.max_value)).is_equal(3)
	spin.value = 3
	d._on_resolve_pressed()
	assert_bool(core.sick_bay.has("c1")).override_failure_message(
		"3 banked turns and this turn's healing clear a 4-turn injury").is_false()
	assert_int(core.recovery_reduction_bank).is_equal(1)


func test_the_recovery_boxes_share_one_bank() -> void:
	var core := _core(2)
	core.sick_bay = {"c1": 5, "c2": 5}
	core.recovery_reduction_bank = 4
	var d := _recovery_dialog(core)
	(d._recovery_spins["c1"] as SpinBox).value = 3
	(d._recovery_spins["c2"] as SpinBox).value = 3
	assert_int(int((d._recovery_spins["c2"] as SpinBox).value)).override_failure_message(
		"the second box asked for more than the bank had left").is_equal(1)
	d._on_resolve_pressed()
	assert_int(core.recovery_reduction_bank).is_equal(0)
	assert_int(int(core.sick_bay["c1"])).is_equal(1)
	assert_int(int(core.sick_bay["c2"])).is_equal(3)


## "You can save any of this effect for later."
func test_an_unspent_recovery_bank_is_saved_for_later() -> void:
	var core := _core(1)
	core.sick_bay = {"c1": 3}
	core.recovery_reduction_bank = 4
	var d := _recovery_dialog(core)
	d._on_resolve_pressed()
	assert_int(core.recovery_reduction_bank).is_equal(4)
	assert_int(int(core.sick_bay["c1"])).is_equal(2)


## p.168 Swarm reward: "recruit one trooper to your roster if you have a vacancy ...
## This recruit does not count against your available replacements."
func test_a_banked_recruit_joins_as_a_trooper_and_uses_no_attempt() -> void:
	var core := _core(2)
	core.bonus_recruits = 1
	var added: Array = _pm(core).resolve_replacements(
			{"bonus_recruits": 1, "new_characters": [{"class": "scout"}]})
	assert_int(added.size()).override_failure_message(
		"the recruit took the rolled replacement's place").is_equal(2)
	assert_int(core.bonus_recruits).is_equal(0)
	assert_str(str(core.get_roster_character_by_id(str(added[0])).get("class", ""))) \
		.is_equal("trooper")


func test_a_banked_recruit_with_no_vacancy_stays_banked() -> void:
	var core := _core(1)
	core.bonus_recruits = 2
	var capacity: int = RosterRules.roster_capacity(core)
	while core.roster.size() < capacity - 1:
		core.roster.append({"id": "x%d" % core.roster.size(), "name": "X", "class": "trooper"})
	_pm(core).resolve_replacements({"bonus_recruits": 2})
	assert_int(core.roster.size()).is_equal(capacity)
	assert_int(core.bonus_recruits).override_failure_message(
		"a recruit with no room to join was spent anyway").is_equal(1)


## Step 13's screen offers the bank before the roll and hands the choice on.
func test_the_replacements_step_hands_on_the_recruits_taken() -> void:
	var core := _core(2)
	core.bonus_recruits = 1
	var d: Control = auto_free(SimpleDialog.new())
	add_child(d)
	d.set_campaign(core)
	d.configure("replacements", Phase.REPLACEMENTS)
	d.refresh()
	assert_object(d._recruit_spin).is_not_null()
	assert_int(int(d._recruit_spin.value)).is_equal(1)
	var emitted: Array = []
	d.phase_completed.connect(func(data: Dictionary) -> void: emitted.append(data))
	d._on_continue_pressed()
	assert_int(int(emitted[0].get("bonus_recruits", 0))).is_equal(1)
	var before: int = core.roster.size()
	_pm(core).resolve_replacements(emitted[0])
	assert_int(core.roster.size()).is_equal(before + 1)
