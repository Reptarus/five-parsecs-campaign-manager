extends GdUnitTestSuite

## Compendium p.181 Movie Magic is OFFERED and SPENT (PB-4).
##
## ⚠ Before 2026-10-27 `BugHuntCampaignCore.use_movie_magic()` had no caller: the ten
## once-per-campaign cards were initialised, saved and never offered anywhere. Three of
## them act on rolls the app makes itself, so they are wired into those rolls:
##   Extra Support  the first support request needs no roll (mission setup)
##   Survived       one character ignores an injury roll (post-battle step 1)
##   Escape         marines off the edge skip the Lost Marine table (post-battle step 1)
## The other seven act at the table and are listed, with a Use button, on the Bug Hunt
## Battle Card.

const CoreScript = preload("res://src/game/campaign/BugHuntCampaignCore.gd")
const Resolver = preload("res://src/core/campaign/BugHuntPostBattleResolver.gd")
const PhaseManager = preload("res://src/core/campaign/BugHuntPhaseManager.gd")
const MissionPanel = preload("res://src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd")
const TacticalBattleScene := preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")

const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
## The phase manager's persist() goes through GameState.save_campaign(), which also
## rewrites last_campaign: unguarded, the next process auto-loads this Bug Hunt core
## and a 5PFH suite reads its String difficulty (measured 2026-10-27, Sprint 3 gate).

var _dm: Node
var _user_state: Dictionary


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	SaveDirGuard.restore(_user_state)


## Pin every post-battle roll the case does not care about (the resolver suite's set).
func _quiet() -> void:
	_dm.queue_forced_result("Bug Hunt Operational Progress", 50)
	_dm.queue_forced_result("Bug Hunt Military Life", 33)
	_dm.queue_forced_result("Bug Hunt Military Life", 33)
	_dm.queue_forced_result("Bug Hunt Muster Out", 2)
	for i in range(4):
		_dm.queue_forced_result("Bug Hunt Reputation", 1)


func _snapshot(battle: Dictionary, cards: Array) -> Dictionary:
	return {
		"characters": [
			{"id": "a", "name": "Alpha", "combat_skill": 1, "toughness": 3, "xp": 0,
				"completed_missions_count": 0},
			{"id": "b", "name": "Bravo", "combat_skill": 1, "toughness": 3, "xp": 0,
				"completed_missions_count": 0}],
		"reputation": 0, "operational_progress_modifier": 0,
		"missions_in_current_operation": 0, "pending_military_life_rolls": 0,
		"sick_bay": {}, "battle_result": battle, "movie_magic_available": cards,
	}


func _choices(receipt: Dictionary, kind: String) -> Array:
	return (receipt.get("choices_needed", []) as Array).filter(
		func(c: Variant) -> bool: return c is Dictionary and str(c.get("kind", "")) == kind)


# ── Survived ─────────────────────────────────────────────────────────────────────

func test_survived_cancels_one_characters_injury_roll_and_spends_the_card() -> void:
	_quiet()
	_dm.queue_forced_result("Bug Hunt Casualty", 1)  # p.202 01-05 Gruesome fate (dead)
	_dm.queue_forced_result("Bug Hunt Casualty", 1)
	var receipt: Dictionary = Resolver.new().resolve(_snapshot(
		{"participant_ids": ["a", "b"], "casualty_ids": ["a", "b"],
			"objectives_completed": 1}, ["survived"]))
	var offered: Array = _choices(receipt, "movie_magic_survived")
	assert_int(offered.size()).override_failure_message(
		"p.181: both casualties may be the one who survives").is_equal(2)
	var answers := {}
	for c in offered:
		answers[str(c.id)] = true
	var chosen: Dictionary = Resolver.apply_choices(receipt, answers)
	assert_int((chosen.cancelled as Array).size()).override_failure_message(
		"one card, so only ONE character survives").is_equal(1)
	var uses: Array = (chosen.effects as Array).filter(
		func(e: Variant) -> bool: return str(e.get("op", "")) == "use_movie_magic")
	assert_int(uses.size()).is_equal(1)

	# End to end through the one mutator: Alpha keeps their place on the roster.
	var core = CoreScript.new()
	core.campaign_name = "T"
	core.main_characters = (_snapshot({}, []).characters as Array).duplicate(true)
	var pm = PhaseManager.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	pm._apply_post_battle_results({"receipt": receipt,
		"answers": {"movie_magic_survived:a": true}})
	var ids: Array = (core.main_characters as Array).map(
		func(m: Variant) -> String: return str(m.get("id", "")))
	assert_array(ids).contains(["a"])
	assert_bool(core.is_movie_magic_available("survived")).is_false()


func test_a_played_card_is_not_offered_again() -> void:
	_quiet()
	_dm.queue_forced_result("Bug Hunt Casualty", 1)
	var receipt: Dictionary = Resolver.new().resolve(_snapshot(
		{"participant_ids": ["a"], "casualty_ids": ["a"], "objectives_completed": 1}, []))
	assert_array(_choices(receipt, "movie_magic_survived")).is_empty()


# ── Escape ───────────────────────────────────────────────────────────────────────

func test_escape_spares_lost_marines_the_lost_marine_table() -> void:
	_quiet()
	_dm.queue_forced_result("Bug Hunt Casualty", 10)  # Lost Marine 01-30 Gruesome fate
	var receipt: Dictionary = Resolver.new().resolve(_snapshot(
		{"participant_ids": ["a"], "casualty_ids": ["a"], "lost_marine_ids": ["a"],
			"objectives_completed": 1}, ["escape"]))
	var offered: Array = _choices(receipt, "movie_magic_escape")
	assert_int(offered.size()).is_equal(1)
	var kills: Array = (receipt.effects as Array).filter(
		func(e: Variant) -> bool: return str(e.get("op", "")) == "kill")
	assert_array(kills[0].cancel_choice).contains(["movie_magic_escape"])
	var chosen: Dictionary = Resolver.apply_choices(receipt, {"movie_magic_escape": true})
	assert_array(chosen.cancelled).contains(["movie_magic_escape"])


# ── Extra Support ────────────────────────────────────────────────────────────────

func test_extra_support_approves_the_first_request_without_a_roll() -> void:
	for i in 3:
		_dm.queue_forced_result("Bug Hunt Objective: die %d" % (i + 1), i + 1)
	_dm.queue_forced_result("Bug Hunt Priority: die 1", 3)
	_dm.queue_forced_result("Bug Hunt Priority: die 2", 6)
	var core = CoreScript.new()
	core.campaign_name = "T"
	var panel: Control = MissionPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel._generate_mission()
	var check: CheckBox = panel._extra_support_check
	assert_object(check).is_not_null()
	check.button_pressed = true
	(panel._support_buttons[0] as Button).pressed.emit()
	var first: Dictionary = (panel._mission_context.support as Array)[0]
	assert_bool(bool(first.approved)).is_true()
	assert_bool(bool(first.movie_magic)).is_true()
	assert_bool(core.is_movie_magic_available("extra_support")).is_false()
	# The second request rolls as normal: a forced 1+1 is below every target.
	_dm.queue_forced_result("Bug Hunt Support die 1", 1)
	_dm.queue_forced_result("Bug Hunt Support die 2", 1)
	(panel._support_buttons[1] as Button).pressed.emit()
	assert_bool(bool((panel._mission_context.support as Array)[1].approved)).is_false()


# ── the table cards, on the Battle Card ──────────────────────────────────────────

func test_the_battle_card_lists_the_cards_and_spends_one() -> void:
	var gs: Node = get_tree().root.get_node_or_null("/root/GameState")
	assert_object(gs).is_not_null()
	var previous = gs.current_campaign
	var core = CoreScript.new()
	core.campaign_name = "T"
	gs.current_campaign = core
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	ui._stored_mission_data = {"battle_mode": "bug_hunt"}
	var card: Control = ui._build_battle_card()
	auto_free(card)
	gs.current_campaign = previous
	var text := ""
	var use: Button = null
	for n in card.find_children("*", "", true, false):
		if n is Label:
			text += (n as Label).text + "\n"
		elif n is Button and use == null and (n as Button).text == "Use":
			use = n
	assert_str(text).contains("Movie Magic: 10 card(s) left")
	assert_str(text).contains("Remove Contact")
	use.pressed.emit()
	assert_int(core.movie_magic_available().size()).is_equal(9)
	assert_bool(use.disabled).is_true()
