extends GdUnitTestSuite

## Planetfall post-battle delivery (T9a): the battle result reaches Steps 9-12, and
## Steps 4 and 12 between them carry the p.61/p.68 Disruption rule.
## Pages: p.51 (Strongpoint), p.59 (bot repair), p.61 (Enemy Activity), p.62 (Raid),
## p.66 (Injuries), p.67 (XP), p.68 (Steps 11-12), p.90 (Crisis), p.134 (Finds).
##
## ⚠ Before 2026-10-27 the post-battle panel read twelve keys and the battle screen
## produced one (`won`): no played battle rolled an Injury, the p.68 Rescue exemption
## never applied, a dead character stayed on the roster, bots and civvies rolled the
## Injury table, Step 11 charged only the casualties whose roll went badly, and a
## resume re-rolled Steps 9, 10 and 12.

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const PMScript = preload("res://src/core/campaign/PlanetfallPhaseManager.gd")
const Normalizer = preload("res://src/core/battle/PlanetfallBattleResultNormalizer.gd")
const PostBattlePanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallPostBattlePanel.gd")
const AutoResolve = preload("res://src/ui/screens/planetfall/panels/PlanetfallAutoResolveDialog.gd")
const SimpleDialog = preload("res://src/ui/screens/planetfall/panels/PlanetfallSimpleDialog.gd")
const LockAndLoad = preload("res://src/ui/screens/planetfall/panels/PlanetfallLockAndLoadPanel.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const Phase = PMScript.Phase

var _user_state: Dictionary
var _saved_campaign: Variant
var _dm: Node


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


func _core() -> Resource:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.game_phase = "active"
	core.campaign_turn = 3
	core.story_points = 0
	core.grunts = 10
	core.roster = [
		{"id": "c1", "name": "Ash", "class": "trooper", "xp": 0},
		{"id": "c2", "name": "Kip", "class": "scientist", "xp": 0},
		{"id": "b1", "name": "Bolt", "class": "bot", "xp": 0},
		{"id": "v1", "name": "Pip", "class": "civvy", "xp": 0},
	]
	return core


## What TacticalBattleUI returns from a played battle: every downed crew figure in
## crew_injuries_data (Core p.122), crew_casualties_data empty, the mission id only as
## `mission_type`.
func _played(core: Resource, downed: Array, won: bool = true) -> Dictionary:
	var by_id: Dictionary = {}
	for c in core.roster:
		by_id[c.id] = c.duplicate()
	var injured: Array = []
	for cid in downed:
		injured.append(by_id[cid])
	return {"won": won, "victory": won, "mission_type": "patrol",
		"crew_participants": by_id.values(), "crew_injuries_data": injured,
		"crew_casualties_data": []}


func _stamp(extra: Dictionary = {}) -> Dictionary:
	var s := {"id": "patrol", "mission_name": "Patrol Mission", "opposition_type": "tactical",
		"enemy_type": "Raiders", "tactical_enemy_index": 0, "grunts_deployed": 2,
		"deployed_ids": ["c1", "c2", "b1", "v1"]}
	s.merge(extra, true)
	return s


func _pm(core: Resource) -> Node:
	var pm: Node = PMScript.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	return pm


func _pm_at(core: Resource, phase: int) -> Node:
	var pm := _pm(core)
	pm.start_new_turn()
	while pm.current_phase != phase:
		pm.complete_current_phase({})
	return pm


func _mount(script: GDScript) -> Control:
	var panel: Control = script.new()
	add_child(panel)
	auto_free(panel)
	return panel


func _post_battle(core: Resource, pm: Node) -> Control:
	var panel := _mount(PostBattlePanel)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.set_battle_results(pm.get_battle_result())
	return panel


func _dialog(core: Resource, pm: Node, step: String) -> Control:
	var panel := _mount(AutoResolve)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.configure(step, pm.current_phase)
	panel.phase_completed.connect(pm.complete_current_phase)
	panel.refresh()
	return panel


func _force(key: String, values: Array) -> void:
	for v in values:
		_dm.queue_forced_result(key, v)


func _queued(key: String) -> bool:
	return _dm.get_forced_results().has(key.to_lower())


func _xp(core: Resource, cid: String) -> int:
	return int(core.get_roster_character_by_id(cid).get("xp", 0))


# ── The normalizer: what the battle screen recorded reaches pp.66-68 ─────────────

func test_a_played_battle_reaches_the_post_battle_keys() -> void:
	var core := _core()
	var r: Dictionary = Normalizer.normalize(_played(core, ["c1", "b1", "v1"]), _stamp(),
			core.roster, {})
	assert_str(str(r.mission_id)).is_equal("patrol")
	assert_array(r.casualties).contains_exactly(["c1", "b1", "v1"])
	assert_array(r.participants).contains_exactly_in_any_order(["c1", "c2", "b1", "v1"])
	assert_array(r.injury_roll_ids) \
		.override_failure_message("p.66: civvies do not roll and a bot is marked Broken") \
		.contains_exactly(["c1"])
	assert_array(r.broken_bot_ids).contains_exactly(["b1"])
	assert_array(r.civvy_casualty_ids).contains_exactly(["v1"])
	assert_bool(r.has_scientist_standing) \
		.override_failure_message("p.134: Kip deployed and is not a casualty").is_true()
	assert_bool(r.has_scout_standing).is_false()
	assert_int(int(r.tactical_enemy_index)).is_equal(0)


func test_the_battle_screens_mission_type_is_the_fallback_id() -> void:
	var core := _core()
	var r: Dictionary = Normalizer.normalize(_played(core, []), {}, core.roster, {})
	assert_str(str(r.mission_id)).is_equal("patrol")


func test_the_debrief_is_bounded_by_what_the_battle_recorded() -> void:
	var core := _core()
	var r: Dictionary = Normalizer.normalize(_played(core, ["c1"]), _stamp(), core.roster, {
		"grunt_casualties": 5, "boss_killers": ["c2", "zz", "c2"],
		"coward_ids": ["c1", "c2"], "find_rolls": 3, "mission_data_gained": 1})
	assert_int(int(r.grunt_casualties)) \
		.override_failure_message("never more grunts than went in").is_equal(2)
	assert_array(r.boss_killers) \
		.override_failure_message("a killer deployed, and counts once").contains_exactly(["c2"])
	assert_array(r.coward_ids) \
		.override_failure_message("p.67: a casualty is awarded as normal").contains_exactly(["c2"])
	assert_int(int(r.find_rolls)).is_equal(3)
	assert_int(int(r.battle_casualty_count)) \
		.override_failure_message("1 character and 2 grunts were battle casualties").is_equal(3)
	var lost: Dictionary = Normalizer.normalize(_played(core, [], false), _stamp(),
			core.roster, {"find_rolls": 2})
	assert_int(int(lost.find_rolls)) \
		.override_failure_message("p.134: Finds come after winning").is_equal(0)


# ── The stamp survives the rebuilt controller ─────────────────────────────────────

func test_the_mission_stamp_survives_the_battle_round_trip() -> void:
	var core := _core()
	_pm(core).stamp_mission(_stamp({"id": "rescue"}))
	var pm := _pm(core)
	pm.restore_from_campaign()
	var raw := _played(core, ["c1", "c2"])
	raw["mission_type"] = ""
	pm.set_battle_result(raw)
	assert_str(str(pm.get_battle_result().mission_id)) \
		.override_failure_message("the stamp was taken before the battle").is_equal("rescue")
	assert_int(int(pm.preview_morale_step().change)) \
		.override_failure_message("p.68: a Rescue Mission costs no Morale for casualties") \
		.is_equal(-1)
	pm.apply_battle_debrief({"colonists_lost": 2})
	assert_int(int(pm.preview_morale_step().change)) \
		.override_failure_message("p.68: \"except for the colonists in the mission\"") \
		.is_equal(-3)


# ── Step 9 (p.66) ─────────────────────────────────────────────────────────────────

func test_step_9_rolls_each_casualty_once_by_the_book() -> void:
	var core := _core()
	var pm := _pm(core)
	pm.stamp_mission(_stamp())
	pm.set_battle_result(_played(core, ["c1", "b1", "v1"]))
	pm.apply_battle_debrief({"grunt_casualties": 2})
	_force("Planetfall Injury", [1])
	_force("Planetfall Grunt Casualty", [1, 6])
	var receipt: Dictionary = pm.resolve_injury_step()
	assert_object(core.get_roster_character_by_id("c1")) \
		.override_failure_message("p.66 Dead: \"The character is gone.\"").is_null()
	assert_bool(core.bot_operational) \
		.override_failure_message("p.66: a bot casualty is marked Broken").is_false()
	assert_object(core.get_roster_character_by_id("v1")).is_not_null()
	assert_int(core.grunts).override_failure_message("one grunt rolled 1-2").is_equal(9)
	assert_str("\n".join(PackedStringArray(receipt.lines))).contains("civvies do not roll")
	_force("Planetfall Injury", [1])
	pm.resolve_injury_step()
	assert_int(core.grunts).override_failure_message("Step 9 resolves once").is_equal(9)
	assert_bool(_queued("Planetfall Injury")) \
		.override_failure_message("nothing was rolled the second time").is_true()


func test_step_11_counts_every_battle_casualty_not_only_the_unlucky() -> void:
	var core := _core()
	var pm := _pm(core)
	pm.stamp_mission(_stamp())
	pm.set_battle_result(_played(core, ["c1"]))
	_force("Planetfall Injury", [70])
	pm.resolve_injury_step()
	assert_object(core.get_roster_character_by_id("c1")) \
		.override_failure_message("premise: 70 is Okay").is_not_null()
	assert_int(int(pm.preview_morale_step().change)) \
		.override_failure_message("p.68: -1, and -1 for the battle casualty whatever its roll") \
		.is_equal(-2)


func test_the_step_9_debrief_carries_the_grunt_count_to_the_roll() -> void:
	var core := _core()
	var pm := _pm(core)
	pm.stamp_mission(_stamp())
	pm.set_battle_result(_played(core, []))
	var panel := _post_battle(core, pm)
	panel.refresh()
	assert_object(panel._grunt_spin) \
		.override_failure_message("two grunts went in, so the count is asked").is_not_null()
	assert_int(int(panel._grunt_spin.max_value)).is_equal(2)
	panel._grunt_spin.value = 2
	_force("Planetfall Grunt Casualty", [1, 1])
	panel._on_action_pressed()
	assert_int(core.grunts).is_equal(8)
	var again := _post_battle(core, pm)
	again.refresh()
	assert_bool(again._action_btn.visible) \
		.override_failure_message("a resume shows the receipt and rolls nothing").is_false()


# ── The bot (pp.59, 66) ───────────────────────────────────────────────────────────

func test_a_broken_bot_and_a_just_repaired_bot_stay_off_the_table() -> void:
	var core := _core()
	core.break_bot()
	assert_str(core.deployment_block_reason("b1", "patrol")).is_equal("BROKEN")
	var pm := _pm_at(core, Phase.REPAIRS)
	var dlg := _mount(SimpleDialog)
	dlg.set_campaign(core)
	dlg.set_phase_manager(pm)
	dlg.configure("repairs", pm.current_phase)
	dlg.phase_completed.connect(pm.complete_current_phase)
	dlg.refresh()
	dlg.complete()
	assert_bool(core.bot_operational).is_true()
	assert_str(core.deployment_block_reason("b1", "patrol")) \
		.override_failure_message("p.59: repaired \"but cannot be deployed into combat this turn\"") \
		.is_equal("REPAIRED THIS TURN")
	var panel := _mount(LockAndLoad)
	panel.set_campaign(core)
	panel.set_mission_context({"selected_mission": {"id": "patrol"}})
	panel.refresh()
	var bot_row: HBoxContainer = null
	for row in panel._roster_container.get_children():
		if row is HBoxContainer and row.get_child_count() > 1 \
				and (row.get_child(1) as Label).text.begins_with("Bolt"):
			bot_row = row
	assert_object(bot_row).override_failure_message("premise: the bot has a row").is_not_null()
	assert_bool((bot_row.get_child(0) as CheckBox).disabled).is_true()
	assert_str((bot_row.get_child(1) as Label).text).contains("[REPAIRED THIS TURN]")
	core.campaign_turn += 1
	assert_str(core.deployment_block_reason("b1", "patrol")).is_equal("")


# ── Step 10 (p.67) ────────────────────────────────────────────────────────────────

func test_cowardice_forfeits_the_battles_xp() -> void:
	var core := _core()
	var pm := _pm(core)
	pm.stamp_mission(_stamp())
	pm.set_battle_result(_played(core, ["c1"]))
	pm.apply_battle_debrief({"coward_ids": ["c2"]})
	var panel := _post_battle(core, pm)
	panel._current_sub_step = panel.SubStep.EXPERIENCE
	panel._resolve_experience()
	assert_int(_xp(core, "c2")) \
		.override_failure_message("p.67: off an edge in rounds 1-2 forfeits all XP").is_equal(0)
	assert_int(_xp(core, "c1")) \
		.override_failure_message("a casualty still participated: +1").is_equal(1)


# ── Step 12 and Step 4: Disruption, the Strongpoint (pp.51, 61, 68) ───────────────

func _tactical_core(type_id: String) -> Resource:
	var core := _core()
	core.tactical_enemies = [
		{"type": {"id": "old_foe", "name": "Old Foe"}, "occupied_sectors": [1, 2, 3],
			"defeated": true},
		{"type": {"id": type_id, "name": "Raiders"}, "occupied_sectors": [4]},
	]
	return core


func _win_against_enemy(core: Resource, mission_id: String) -> void:
	var pm := _pm(core)
	pm.stamp_mission(_stamp({"id": mission_id, "tactical_enemy_index": 1}))
	pm.set_battle_result(_played(core, []))
	var panel := _post_battle(core, pm)
	panel._current_sub_step = panel.SubStep.ENEMY_INFO
	panel._resolve_enemy_info()


func test_a_beaten_tactical_enemy_sits_out_the_next_enemy_activity() -> void:
	var core := _tactical_core("raiders")
	_win_against_enemy(core, "patrol")
	var pm := _pm_at(core, Phase.ENEMY_ACTIVITY)
	assert_bool(core.is_enemy_disrupted(1)) \
		.override_failure_message("premise: the next turn is the one it sits out").is_true()
	var dlg := _dialog(core, pm, "enemy_activity")
	_force("Planetfall Enemy Activity", [95])
	dlg.complete()
	dlg.complete()
	assert_int(core.colony_integrity) \
		.override_failure_message("p.61 Disruption: no activity, so no Raid").is_equal(0)
	assert_bool(_queued("Planetfall Enemy Activity")) \
		.override_failure_message("the table was not rolled").is_true()


func test_the_converted_are_not_disrupted_and_a_raid_counts_one_enemys_sectors() -> void:
	var core := _tactical_core("converted_recon_team")
	_win_against_enemy(core, "patrol")
	var pm := _pm_at(core, Phase.ENEMY_ACTIVITY)
	var dlg := _dialog(core, pm, "enemy_activity")
	_force("Planetfall Enemy Activity", [95])
	dlg.complete()
	dlg.complete()
	assert_int(core.colony_integrity) \
		.override_failure_message("p.62: the acting enemy's 1 sector + 1; not every enemy's") \
		.is_equal(-2)


func test_winning_the_assault_destroys_the_enemy_and_lifts_morale() -> void:
	var core := _tactical_core("raiders")
	var before: int = core.colony_morale
	_win_against_enemy(core, "assault")
	assert_bool(bool(core.tactical_enemies[1].get("defeated", false))) \
		.override_failure_message("p.51: the Assault \"removes them from the campaign\"").is_true()
	assert_array(core.tactical_enemies[1].occupied_sectors).is_empty()
	assert_int(core.colony_morale - before).is_equal(5)


func test_waiting_for_the_right_moment_spends_a_point_and_rolls_nothing() -> void:
	var core := _tactical_core("raiders")
	core.story_points = 1
	var pm := _pm_at(core, Phase.ENEMY_ACTIVITY)
	var dlg := _dialog(core, pm, "enemy_activity")
	assert_object(dlg._wait_check).is_not_null()
	dlg._wait_check.button_pressed = true
	_force("Planetfall Enemy Activity", [95])
	dlg.complete()
	assert_int(core.story_points) \
		.override_failure_message("spent on completion, never while the step can resume") \
		.is_equal(1)
	dlg.complete()
	assert_int(core.story_points).is_equal(0)
	assert_bool(_queued("Planetfall Enemy Activity")).is_true()
	assert_int(core.colony_integrity).is_equal(0)


# ── Step 12a Finds (pp.90, 134) ───────────────────────────────────────────────────

func _finds_ready(core: Resource) -> Node:
	var pm := _pm(core)
	pm.stamp_mission(_stamp())
	pm.set_battle_result(_played(core, []))
	pm.apply_battle_debrief({"find_rolls": 1})
	return pm


func _open_finds(core: Resource, pm: Node) -> Control:
	var panel := _post_battle(core, pm)
	panel._transition_to_sub_step(panel.SubStep.POST_MISSION_FINDS, "FINDS", "Step 12a",
			"Roll Finds")
	return panel


func test_finds_are_rolled_once_across_a_resume() -> void:
	var core := _core()
	var pm := _finds_ready(core)
	_force("Planetfall Post-Mission Find", [61])
	_open_finds(core, pm)._on_action_pressed()
	assert_int(core.story_points).override_failure_message("61: +1 Story Point").is_equal(1)
	_force("Planetfall Post-Mission Find", [61])
	var again := _open_finds(core, pm)
	assert_bool(again._action_btn.visible).is_false()
	assert_int(core.story_points).is_equal(1)
	assert_bool(_queued("Planetfall Post-Mission Find")).is_true()


func test_a_crisis_takes_a_point_from_each_find() -> void:
	var core := _core()
	core.in_crisis = true
	core.research_data = {"current_rp": 0}
	var pm := _finds_ready(core)
	_force("Planetfall Post-Mission Find", [1])
	_open_finds(core, pm)._on_action_pressed()
	assert_int(int(core.research_data.current_rp)) \
		.override_failure_message("p.134 01-25: 2 RP; p.90: every source gives 1 less") \
		.is_equal(1)
