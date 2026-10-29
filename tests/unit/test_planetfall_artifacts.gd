extends GdUnitTestSuite

## Planetfall Alien Artifacts in use (pp.135-136) and Bio-Analysis Research (p.92).
##
## ⚠ Before 2026-10-28 an Artifact was a name in `artifacts_found` and nothing read its
## effect: no Colony Item changed the colony, no Single-Use item could be activated, no
## equipment reached a character, and the Neo-ancient data cache granted its Milestone
## the moment it was FOUND, where p.136 says "When activated". Bio-Analysis existed only as
## a line in a Hunt's reward text: no sample was kept and no screen could start one.

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const ResearchScript = preload("res://src/core/systems/PlanetfallResearchSystem.gd")
const LifeformScript = preload("res://src/core/systems/PlanetfallLifeformGenerator.gd")
const MilestoneScript = preload("res://src/core/systems/PlanetfallMilestoneSystem.gd")
const GuideScript = preload("res://src/core/battle/PlanetfallBattleGuide.gd")
const EquipmentPanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallEquipmentPanel.gd")
const ResearchPanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallResearchPanel.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _user_state: Dictionary
var _dm: Node
var _artifacts: Array = []


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")
	if _artifacts.is_empty():
		var parsed: Variant = JSON.parse_string(
				FileAccess.get_file_as_string("res://data/planetfall/artifacts.json"))
		for e in parsed.get("artifacts", parsed.get("entries", [])):
			_artifacts.append(e)


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	SaveDirGuard.restore(_user_state)


func _core() -> Resource:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.campaign_turn = 4
	core.colony_morale = 0
	core.roster = [
		{"id": "c1", "name": "Ash", "class": "trooper", "xp": 0, "speed": 4, "toughness": 3},
		{"id": "c2", "name": "Kip", "class": "scientist", "xp": 0, "speed": 4, "toughness": 3},
	]
	return core


## The real table entry, so a test reads the shipped effect and never a stand-in.
func _artifact(id: String) -> Dictionary:
	for a in _artifacts:
		if str(a.get("id", "")) == id:
			return (a as Dictionary).duplicate(true)
	return {}


# ── Single-Use (p.135: "You can choose when to use them") ──────────────────────

func test_a_single_use_artifact_waits_and_is_gone_once_used() -> void:
	var core := _core()
	core.acquire_artifact(_artifact("transcendence_blueprints"))
	assert_int(int(core.colony_morale)).override_failure_message(
		"found is not activated: nothing happens until the player chooses").is_equal(0)
	core.use_artifact("transcendence_blueprints")
	assert_int(int(core.colony_morale)).is_equal(4)
	assert_int(int(core.augmentation_points)).is_equal(1)
	core.use_artifact("transcendence_blueprints")
	assert_int(int(core.colony_morale)).override_failure_message(
		"p.135: once activated 'they are gone'").is_equal(4)


func test_a_serum_raises_the_chosen_characters_stat_for_good() -> void:
	var core := _core()
	core.acquire_artifact(_artifact("bio_frame_optimization_serum"))
	core.use_artifact("bio_frame_optimization_serum", "c2")
	assert_int(int(core.get_roster_character_by_id("c2").toughness)).is_equal(4)
	assert_int(int(core.get_roster_character_by_id("c1").toughness)).is_equal(3)


func test_the_psi_wave_emitter_empties_sick_bay() -> void:
	var core := _core()
	core.add_to_sick_bay("c1", 3)
	core.acquire_artifact(_artifact("altered_psi_wave_emitter"))
	core.use_artifact("altered_psi_wave_emitter")
	assert_bool(core.sick_bay.has("c1")).is_false()


func test_the_pattern_booster_restores_a_character_who_died_this_turn() -> void:
	var core := _core()
	core.slay_character("c1")
	core.acquire_artifact(_artifact("organic_pattern_booster"))
	core.use_artifact("organic_pattern_booster", "c1")
	assert_object(core.get_roster_character_by_id("c1")).override_failure_message(
		"p.136: 'A character that just died can be restored to life'").is_not_null()


func test_the_pattern_booster_cannot_reach_last_turns_dead() -> void:
	var core := _core()
	core.slay_character("c1")
	core.campaign_turn += 1
	core.acquire_artifact(_artifact("organic_pattern_booster"))
	core.use_artifact("organic_pattern_booster", "c1")
	assert_object(core.get_roster_character_by_id("c1")).override_failure_message(
		"p.136: only a character that JUST died").is_null()


## The SAME turn, so only the death-vs-departure distinction can keep c2 away: with the
## turn advanced, the prune would hide a dismissal recorded as a death.
func test_the_pattern_booster_cannot_bring_back_the_dismissed() -> void:
	var core := _core()
	core.dismiss_character("c2")
	core.acquire_artifact(_artifact("organic_pattern_booster"))
	core.use_artifact("organic_pattern_booster", "c2")
	assert_object(core.get_roster_character_by_id("c2")).override_failure_message(
		"p.69: a dismissed character 'cannot be returned to the campaign later'").is_null()


func test_the_data_cache_grants_its_milestone_when_activated_not_when_found() -> void:
	var core := _core()
	core.acquire_artifact(_artifact("neo_ancient_data_cache"))
	assert_array(MilestoneScript.new().claim_new_sources(core)).override_failure_message(
		"p.136: 'When activated, this counts as completing a campaign Milestone'").is_empty()
	core.use_artifact("neo_ancient_data_cache")
	assert_int(int(core.milestones_completed)).is_equal(1)


# ── Equipment (p.135: given for good, lost with the carrier) ──────────────────

func test_artifact_equipment_is_given_once_and_never_traded() -> void:
	var core := _core()
	core.acquire_artifact(_artifact("focused_beam_emitter"))
	core.give_artifact("focused_beam_emitter", "c1")
	core.give_artifact("focused_beam_emitter", "c2")
	assert_str(str(core.get_found_artifact("focused_beam_emitter").carrier)) \
		.override_failure_message("p.135: 'cannot be traded away later'").is_equal("c1")
	assert_int(core.artifacts_carried_by("c1").size()).is_equal(1)


# ── The Armory overlay drives the same API ─────────────────────────────────────

func test_the_armory_activates_and_gives_artifacts() -> void:
	var core := _core()
	core.acquire_artifact(_artifact("transcendence_blueprints"))
	core.acquire_artifact(_artifact("shard_projection_rifle"))
	var panel: Control = auto_free(EquipmentPanel.new())
	add_child(panel)
	panel.set_campaign(core)
	panel.refresh()
	var list: Node = panel.find_child("AlienArtifacts", true, false)
	var activate: Button = null
	var give: Button = null
	for b in list.find_children("*", "Button", true, false):
		if (b as Button).text == "Activate":
			activate = b
		elif (b as Button).text.begins_with("Give"):
			give = b
	assert_object(activate).is_not_null()
	assert_object(give).is_not_null()
	activate.pressed.emit()
	give.pressed.emit()
	assert_int(int(core.colony_morale)).is_equal(4)
	assert_str(str(core.get_found_artifact("shard_projection_rifle").carrier)).is_equal("c1")


# ── Bio-Analysis (p.92) ────────────────────────────────────────────────────────

func _sampled(core: Resource) -> void:
	core.lifeform_table = [{"name": "Glasswing", "speed": 6, "combat_skill": 1,
		"toughness": 4, "kp": 1, "evolutions_applied": [], "generated": true}]
	core.record_lifeform_sample(0)
	core.research_data["current_rp"] = 5


func test_a_sampled_lifeform_can_be_analyzed_for_3_rp() -> void:
	var core := _core()
	_sampled(core)
	_dm.queue_forced_result("Planetfall Bio-Analysis", 6)
	var r: Dictionary = ResearchScript.new().conduct_bio_analysis(core, 0)
	assert_bool(bool(r.get("success", false))).is_true()
	assert_str(str(core.lifeform_table[0].bio_analysis.id)).is_equal("predictive_movement")
	assert_int(int(core.research_data.current_rp)).is_equal(2)


func test_an_unsampled_lifeform_cannot_be_analyzed() -> void:
	var core := _core()
	core.lifeform_table = [{"name": "Glasswing", "speed": 6, "kp": 1, "generated": true}]
	core.research_data["current_rp"] = 5
	var r: Dictionary = ResearchScript.new().conduct_bio_analysis(core, 0)
	assert_bool(bool(r.get("success", true))).override_failure_message(
		"p.92: 'You must collect a sample ... by successfully completing a Hunt'").is_false()
	assert_int(int(core.research_data.current_rp)).is_equal(5)


func test_an_evolution_clears_the_analysis_and_the_sample() -> void:
	var core := _core()
	_sampled(core)
	ResearchScript.new().conduct_bio_analysis(core, 0)
	var gen := LifeformScript.new()
	var evo_roll: int = 0
	for roll in range(1, 101):
		if not gen.get_evolution(roll).is_empty():
			evo_roll = roll
			break
	gen.apply_evolution(core, 0, evo_roll)
	assert_bool(core.lifeform_table[0].has("bio_analysis")).override_failure_message(
		"p.92: a profile change 'including evolution' loses the benefit").is_false()
	assert_bool(bool(core.lifeform_table[0].get("sampled", false))).is_false()


func test_the_battle_screen_shows_the_analysis() -> void:
	var core := _core()
	_sampled(core)
	_dm.queue_forced_result("Planetfall Bio-Analysis", 1)
	ResearchScript.new().conduct_bio_analysis(core, 0)
	assert_str(GuideScript.profile_line(core.lifeform_table[0])).contains(
		"Bio-Analysis, Hit bonus")


func test_the_research_screen_offers_the_analysis() -> void:
	var core := _core()
	_sampled(core)
	var panel: Control = auto_free(ResearchPanel.new())
	add_child(panel)
	panel.set_campaign(core)
	panel.refresh()
	var found: Button = null
	for b in panel.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Analyze Glasswing"):
			found = b
	assert_object(found).override_failure_message(
		"no screen could start a Bio-Analysis").is_not_null()
	_dm.queue_forced_result("Planetfall Bio-Analysis", 2)
	found.pressed.emit()
	assert_str(str(core.lifeform_table[0].bio_analysis.id)).is_equal("brawling_bonus")


# ── p.136 Alien translation guide ──────────────────────────────────────────────

func test_the_translation_guide_halves_the_next_two_topics() -> void:
	var core := _core()
	core.acquire_artifact(_artifact("alien_translation_guide"))
	core.use_artifact("alien_translation_guide")
	_sampled(core)
	var rs := ResearchScript.new()
	assert_int(rs.bio_analysis_cost(core)).override_failure_message(
		"3 RP halved, rounded up").is_equal(2)
	rs.conduct_bio_analysis(core, 0)
	assert_int(rs.discounts_left(core)).is_equal(1)
	var tid: String = str(rs.get_all_theories()[0].get("id", ""))
	var full: int = int(rs.get_theory(tid).get("theory_cost", 0))
	core.research_data["current_rp"] = 99
	rs.invest_in_theory(core, tid, 1)
	assert_int(rs.theory_cost_for(core, tid)).is_equal(ceili(full / 2.0))
	assert_int(rs.discounts_left(core)).override_failure_message(
		"p.136: 'the next TWO research topics'").is_equal(0)
