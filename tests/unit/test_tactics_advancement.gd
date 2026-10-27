extends GdUnitTestSuite

## Five Parsecs: Tactics pp.107-108 (Spending CP) with p.148 (veteran categories) —
## TacticsAdvancement, applied by TacticsPhaseManager, chosen in TacticsPostBattlePanel.
##
## ⚠ Before 2026-10-27 every purchase charged its CP and did NOTHING: the panel had no
## target picker, so it sent no target, so the consumer had nothing to match. These
## cases assert the CAMPAIGN after the phase completes — what a player would find on
## their roster — not that a signal fired.

const PhaseManager = preload("res://src/core/campaign/TacticsPhaseManager.gd")
const TacticsCore = preload("res://src/game/campaign/TacticsCampaignCore.gd")
const Advancement = preload("res://src/core/campaign/TacticsAdvancement.gd")
const UnitRecord = preload("res://src/data/tactics/TacticsCampaignUnit.gd")
const PostBattlePanel = preload("res://src/ui/screens/tactics/panels/TacticsPostBattlePanel.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _user_state: Dictionary = {}


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()


func after_test() -> void:
	SaveDirGuard.restore(_user_state)
	_user_state = {}


## A Human army with a squad, a sergeant-type character and a weapon team. The unit
## ids are the Army Builder ids the creation wizard composes (pp.133-139).
func _campaign(cp: int = 20) -> Resource:
	var c = TacticsCore.new()
	c.species_id = "human_colonists"
	for base in ["human_infantry_squad", "human_sergeant", "human_weapon_team"]:
		var rec: Dictionary = UnitRecord.new_unit(base, "human_colonists", base)
		rec["unit_id"] = base + "_u"
		c.campaign_units.append(rec)
	c.operational_map = {"player_cohesion": 5, "enemy_cohesion": 5,
		"player_battle_points": 0, "operational_turn": 1, "focus_zone_id": "z1",
		"regions": [{"id": "nr1", "name": "N", "owner": "neutral"}],
		"zones": [{"id": "z1", "region_id": "nr1", "name": "Pass",
			"player_army_strength": 4, "enemy_army_strength": 4}],
		"orders_history": []}
	c.earn_cp(cp)
	return c


func _manager(campaign: Resource):
	var pm = PhaseManager.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(campaign)
	return pm


func _advance(campaign: Resource, purchases: Array, cp_spent: int):
	var pm = _manager(campaign)
	pm.go_to_phase(PhaseManager.Phase.ADVANCEMENT)
	pm.complete_current_phase({"cp_spent": cp_spent, "advancement_purchases": purchases})
	return pm


func _unit(c: Resource, uid: String) -> Dictionary:
	for rec in c.campaign_units:
		if str(rec.unit_id) == uid:
			return rec
	return {}


# MARK: - p.148 categories

## p.147, Heavy Combat Bots: "Bots cannot obtain veteran skills." A crewed vehicle can
## (p.148: "Vehicles may have a single veteran skill").
func test_a_combat_bot_is_never_offered_a_veteran_skill() -> void:
	var c = _campaign()
	for base in ["human_vehicle_cim_l_demon", "human_vehicle_light_tank_tracked"]:
		var rec: Dictionary = UnitRecord.new_unit(base, "human_colonists", base, 1)
		rec["unit_id"] = base + "_u"
		c.campaign_units.append(rec)
	var ids: Array = []
	for t in Advancement.targets(c, "veteran_skill"):
		ids.append(t.unit_id)
	assert_bool(ids.has("human_vehicle_light_tank_tracked_u")).override_failure_message(
		"a light tank should take the vehicle list: %s" % str(ids)).is_true()
	assert_bool(ids.has("human_vehicle_cim_l_demon_u")).override_failure_message(
		"p.147: a combat bot cannot obtain veteran skills").is_false()


func test_a_squad_takes_one_squad_skill_and_one_sergeant_skill() -> void:
	var c := _campaign()
	var base: Dictionary = Advancement.base_unit(_unit(c, "human_infantry_squad_u"),
		"human_colonists")
	assert_dict(base).is_not_empty()
	var lists: Array = []
	for s in Advancement.open_skills(base, []):
		if not lists.has(s.list):
			lists.append(s.list)
	assert_array(lists).contains_exactly_in_any_order(["squad_skills", "sergeant_skills"])


func test_a_weapon_team_takes_the_gun_crew_list() -> void:
	var c := _campaign()
	var base: Dictionary = Advancement.base_unit(_unit(c, "human_weapon_team_u"),
		"human_colonists")
	for s in Advancement.open_skills(base, []):
		assert_str(str(s.list)).is_equal("gun_crew_skills")


func test_synthetic_species_cannot_be_veterans_unless_a_rule_says_so() -> void:
	assert_bool(Advancement.can_be_veteran("human_colonists")).is_true()
	assert_bool(Advancement.can_be_veteran("converted")) \
		.override_failure_message("p.146/p.148: the Converted can never be veterans") \
		.is_false()
	assert_bool(Advancement.can_be_veteran("soulless")) \
		.override_failure_message("p.158: Soulless 'may acquire veteran skills as normal'") \
		.is_true()


# MARK: - Purchases land on the campaign

func test_a_bought_veteran_skill_reaches_the_unit_and_the_cp_is_charged() -> void:
	var c := _campaign(10)
	_advance(c, [{"id": "veteran_skill", "unit_id": "human_infantry_squad_u",
		"choice": "squad_skills:brave"}], 4)
	var skills: Array = c.veteran_skills.get("human_infantry_squad_u", [])
	assert_int(skills.size()).is_equal(1)
	assert_str(str(skills[0].id)).is_equal("brave")
	assert_int(c.get_available_cp()).is_equal(6)


func test_a_squad_cannot_take_a_second_squad_skill() -> void:
	var c := _campaign()
	_advance(c, [{"id": "veteran_skill", "unit_id": "human_infantry_squad_u",
		"choice": "squad_skills:brave"}], 4)
	var pm = _advance(c, [{"id": "veteran_skill", "unit_id": "human_infantry_squad_u",
		"choice": "squad_skills:keen_shots"}], 4)
	assert_int((c.veteran_skills["human_infantry_squad_u"] as Array).size()).is_equal(1)
	assert_str(pm.last_advancement_receipt[0]).starts_with("Not applied")


func test_retraining_replaces_the_skill_within_its_list() -> void:
	var c := _campaign()
	_advance(c, [{"id": "veteran_skill", "unit_id": "human_infantry_squad_u",
		"choice": "squad_skills:brave"}], 4)
	_advance(c, [{"id": "retrain_unit", "unit_id": "human_infantry_squad_u",
		"choice": "brave>squad_skills:keen_shots"}], 2)
	var skills: Array = c.veteran_skills["human_infantry_squad_u"]
	assert_int(skills.size()).is_equal(1)
	assert_str(str(skills[0].id)).is_equal("keen_shots")


func test_hero_is_offered_only_to_individuals_and_recorded_as_an_upgrade() -> void:
	var c := _campaign()
	var ids: Array = []
	for t in Advancement.targets(c, "hero_trait"):
		ids.append(t.unit_id)
	assert_array(ids).contains_exactly(["human_sergeant_u"])
	_advance(c, [{"id": "hero_trait", "unit_id": "human_sergeant_u", "choice": "Hero"}], 2)
	assert_array(_unit(c, "human_sergeant_u").selected_upgrades).contains(["Hero"])


func test_a_destroyed_unit_is_replaced_without_its_veteran_skills() -> void:
	var c := _campaign()
	c.veteran_skills["human_infantry_squad_u"] = [{"id": "brave", "list": "squad_skills"}]
	UnitRecord.apply_unit_loss(_unit(c, "human_infantry_squad_u"), "lost")
	_advance(c, [{"id": "replace_destroyed", "unit_id": "human_infantry_squad_u",
		"choice": "human_infantry_squad"}], 1)
	assert_dict(_unit(c, "human_infantry_squad_u")).is_empty()
	assert_bool(c.veteran_skills.has("human_infantry_squad_u")).is_false()
	var squads: int = 0
	for rec in c.campaign_units:
		if str(rec.base_unit_id) == "human_infantry_squad":
			squads += 1
			assert_bool(UnitRecord.is_deployable(rec)).is_true()
	assert_int(squads).is_equal(1)


## p.107: single-use, saved indefinitely, gone once used.
func test_a_battle_advantage_is_banked_then_spent_in_battle_prep() -> void:
	var c := _campaign()
	_advance(c, [{"id": "battle_luck", "unit_id": "", "choice": ""}], 1)
	assert_int(c.battle_advantages.size()).is_equal(1)
	var pm = _manager(c)
	pm.go_to_phase(PhaseManager.Phase.BATTLE_PREP)
	pm.complete_current_phase({"battle_advantages_used": [0]})
	assert_array(c.battle_advantages).is_empty()
	assert_str(str(c.current_battle.battle_advantages[0].id)).is_equal("battle_luck")


func test_banked_advantages_survive_a_save_round_trip() -> void:
	var c := _campaign()
	c.add_battle_advantage(TacticsCore.cp_purchase("battle_support"))
	var copy = TacticsCore.new()
	copy.from_dictionary(c.to_dictionary())
	assert_int(copy.battle_advantages.size()).is_equal(1)


# MARK: - The panel sends a target, and refuses what it cannot afford

func test_the_panel_emits_the_purchase_with_its_target() -> void:
	var c := _campaign(4)
	var pm = _manager(c)
	pm.go_to_phase(PhaseManager.Phase.ADVANCEMENT)
	var panel = PostBattlePanel.new()
	add_child(panel)
	auto_free(panel)
	panel.setup(pm, c)
	panel.show_phase(6)
	var got: Array = []
	panel.phase_completed.connect(func(_p: int, d: Dictionary) -> void: got.append(d))
	panel._on_pick_purchase("veteran_skill")
	panel._on_confirm_purchase()
	panel._on_pick_purchase("hero_trait")  # 2 CP, but all 4 are committed
	panel._on_confirm_purchase()
	panel._on_complete()
	assert_int(got.size()).is_equal(1)
	var purchases: Array = got[0].get("advancement_purchases", [])
	assert_int(purchases.size()) \
		.override_failure_message("the 2 CP Hero trait must be refused on 0 remaining CP") \
		.is_equal(1)
	assert_str(str(purchases[0].unit_id)).is_not_empty()
	assert_str(str(purchases[0].choice)).contains(":")
	assert_int(int(got[0].cp_spent)).is_equal(4)


# MARK: - p.106 Unit Losses (post-battle half of the same panel)

## A unit ticked "completely destroyed" is rolled on completion even if Roll was never
## pressed, so a loss cannot be skipped by completing the phase.
func test_a_ticked_unit_is_rolled_and_emitted_on_completion() -> void:
	var c := _campaign()
	var pm = _manager(c)
	pm.go_to_phase(PhaseManager.Phase.POST_BATTLE)
	var panel = PostBattlePanel.new()
	add_child(panel)
	auto_free(panel)
	panel.setup(pm, c)
	panel.show_phase(5)
	panel._destroyed["human_infantry_squad_u"] = true
	var got: Array = []
	panel.phase_completed.connect(func(_p: int, d: Dictionary) -> void: got.append(d))
	panel._on_complete()
	var losses: Array = got[0].get("unit_losses", [])
	assert_int(losses.size()).is_equal(1)
	assert_str(str(losses[0].unit_id)).is_equal("human_infantry_squad_u")
	assert_array(["lost", "devastated", "weakened", "okay"]).contains([str(losses[0].id)])


## The CP card is rendered from what record_battle() stamped, never a literal.
func test_the_battle_result_card_shows_the_book_award() -> void:
	var c := _campaign(0)
	c.record_battle({"won": true, "victory_points": 3})
	var panel = PostBattlePanel.new()
	add_child(panel)
	auto_free(panel)
	panel.setup(null, c)
	var text: String = panel._battle_result_text()
	assert_str(text).contains("dropped the lowest")
	assert_str(text).contains("1 CP per Victory Point")
	assert_str(text).not_contains("secondary objectives")
