extends GdUnitTestSuite
## Core Rules p.82 Explore 83-86 "Offered a small job" and 87-90 "Offered a reward"
## reach the battle and pay.
##
## "When fighting this campaign turn, select a random enemy figure. If your crew kills
## them, earn 2 credits. No reward if they run away." / "...select a random terrain
## feature. If a crew member moves into contact and spends a Combat Action, you can
## retrieve a package and earn 2 credits."
##
## Measured on 2026-10-29 before the fix: both rows were held after the Explore task
## and nothing read them back. No battle named a target, the results form could not
## record one, and no credit was ever paid.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const CrewTasks = preload("res://src/ui/screens/world/components/CrewTaskComponent.gd")
const TurnControllerScript = preload("res://src/ui/screens/campaign/CampaignTurnController.gd")
const FormClass = preload("res://src/ui/components/battle/BattleResultsInputForm.gd")
const Normalizer = preload("res://src/core/battle/BattleResultNormalizer.gd")
const PostBattleContextClass = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const Completion = preload("res://src/core/campaign/phases/post_battle/PostBattleCompletion.gd")
const TacticalBattleScene := preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")
const Events = preload("res://src/core/campaign/DeferredCrewEvents.gd")
const SaveDirGuard = preload("res://tests/fixtures/helpers/save_dir_guard.gd")

const CONTRACT := {"seed": 42, "sectors": [
	{"label": "A1", "features": ["Crates"]}, {"label": "B2", "features": ["Ruined wall"]}]}

var _prior_campaign: Resource = null
var _user_state: Dictionary = {}


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_prior_campaign = GameState.current_campaign
	var c = CampaignCore.new()
	c.from_dictionary({"campaign_id": "explore_bounties_suite"})
	c.progress_data["turns_played"] = 3
	c.equipment_data = {"equipment": []}
	GameState.current_campaign = c


func after_test() -> void:
	DiceManager.clear_forced_results("Exploration Table")
	GameState.current_campaign = _prior_campaign
	SaveDirGuard.restore(_user_state)


func _pd() -> Dictionary:
	return GameState.current_campaign.progress_data


## Hold both rows through the real Explore producer.
func _explore_both() -> void:
	var comp = auto_free(CrewTasks.new())
	add_child(comp)
	var member := {"id": "c1", "character_id": "c1", "character_name": "Ana", "savvy": 0,
		"species_id": "human", "origin": "HUMAN", "equipment": [], "status_effects": []}
	comp.crew_data = [member]
	for roll: int in [84, 88]:
		DiceManager.queue_forced_result("Exploration Table", roll)
		comp._resolve_table_task({"details": "", "reward": "", "penalty": "",
			"success": false, "roll": 0, "modified_roll": 0}, {"id": "explore"}, member)


func _stamp() -> Array:
	var ctl = auto_free(TurnControllerScript.new())
	ctl.game_state = GameState
	return ctl._stamp_explore_bounties(CONTRACT.duplicate(true), {"count": 7})


func test_each_held_bounty_gets_a_target_and_its_rule() -> void:
	_explore_both()
	var bounties: Array = _stamp()
	assert_int(bounties.size()).is_equal(2)
	var job: Dictionary = bounties[0]
	assert_str(str(job.kind)).is_equal("Offered a small job")
	assert_str(str(job.target)).contains("of 7")
	assert_str(str(job.rule)).contains("No reward if they run away")
	assert_int(int(job.credits)).override_failure_message(
		"the amount comes from the row's bounty_credits").is_equal(2)
	var reward: Dictionary = bounties[1]
	assert_bool(str(reward.target) in ["Crates (sector A1)", "Ruined wall (sector B2)"]) \
		.override_failure_message("a random terrain feature on this table").is_true()
	assert_str(str(reward.rule)).contains("Combat Action")
	# Seeded off the table, so a resumed battle names the same targets.
	assert_array(_stamp()).is_equal(bounties)


func test_the_battle_card_names_the_targets() -> void:
	_explore_both()
	var contract: Dictionary = CONTRACT.duplicate(true)
	contract["explore_bounties"] = _stamp()
	GameState.set_battlefield_data(contract)
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	# A campaign battle: CampaignTurnController calls initialize_battle(). Without
	# this the deferred _check_standalone_mode() declares the screen standalone
	# (TacticalBattleUI:1071) and the card reads its own table, not the campaign's.
	ui._battle_initialized = true
	add_child(ui)
	await get_tree().process_frame
	assert_bool(ui._is_standalone_battle()).override_failure_message(
		"premise: this must be the campaign's battle").is_false()
	ui._stored_mission_data = {"enemy_force": {"count": 7}}
	var card: Control = ui._build_battle_card()
	auto_free(card)
	var text := ""
	for n in card.find_children("*", "Label", true, false):
		text += (n as Label).text + "\n"
	assert_str(text).contains("Offered a small job: enemy figure")
	assert_str(text).contains("Offered a reward:")


func test_the_form_asks_and_post_battle_pays_only_what_was_claimed() -> void:
	_explore_both()
	var bounties: Array = _stamp()
	var mission := {"explore_bounties": bounties}
	var form = FormClass.new()
	add_child(form)
	auto_free(form)
	form.setup([{"character_name": "Ana", "combat": 1, "reactions": 1, "toughness": 3,
		"speed": 4}], 7, mission, {})
	assert_int(form._bounty_checks.size()).is_equal(2)
	(form._bounty_checks[str(bounties[0].event_id)] as CheckBox).button_pressed = true
	var captured: Array = []
	form.results_submitted.connect(func(r: Dictionary) -> void: captured.append(r))
	form._on_submit()
	var result: Dictionary = Normalizer.normalize(captured[0], mission, 3)
	assert_array(result.get("explore_bounties", [])).override_failure_message(
		"the stamp crosses the normalizer").has_size(2)

	var ctx = PostBattleContextClass.new()
	ctx.campaign = GameState.current_campaign
	ctx.game_state_manager = GameStateManager
	ctx.battle_result = result
	var before: int = GameStateManager.get_credits()
	var paid: Array = Completion.new().apply_explore_bounties(ctx)
	assert_int(GameStateManager.get_credits() - before).override_failure_message(
		"the small job was claimed, the package was not").is_equal(2)
	assert_int(paid.size()).is_equal(1)
	for kind: String in ["Offered a small job", "Offered a reward"]:
		assert_int(Events.live(_pd(), kind, 3).size()).override_failure_message(
			"\"this campaign turn\": spent either way").is_equal(0)


## The cases above call the stamp and the payment directly, so neither would notice
## if the battle start or the post-battle step stopped calling them. Comment lines are
## stripped so the docblocks that name these calls cannot satisfy the check.
func _code_only(path: String) -> String:
	var out: PackedStringArray = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().begins_with("#"):
			out.append(line)
	return "\n".join(out)


func test_the_battle_start_stamps_and_post_battle_pays() -> void:
	var ctc := _code_only("res://src/ui/screens/campaign/CampaignTurnController.gd")
	assert_str(ctc).contains(
		"var bounties: Array = _stamp_explore_bounties(active_battlefield, enemy_force_info)")
	assert_str(ctc).contains("mission_data[\"explore_bounties\"] = bounties")
	assert_str(_code_only("res://src/core/campaign/phases/PostBattlePhase.gd")) \
		.contains("_completion.apply_explore_bounties(_ctx)")
