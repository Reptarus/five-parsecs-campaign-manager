extends GdUnitTestSuite
## Battle-phase sprint, P0.1 — End-Phase enemy Morale (Core Rules p.114).
##
## The mechanic was fully implemented and completely unreachable: set_enemy_count()
## and setup_from_enemy_data() had ZERO callers, so enemies_remaining stayed 0 and
## perform_morale_check() capped every result to zero bails:
##   bailable     = maxi(0, enemies_remaining - fearless)  -> 0
##   actual_bails = mini(bails, bailable)                  -> 0
## The check that ends most Five Parsecs battles could never remove a figure.
##
## These cases are RNG-INDEPENDENT: with a Panic range of 1-6 every possible 1D6
## result falls inside the range, so the bail count is fully determined by the cap
## — which is exactly the thing that was broken.

const TRACKER = preload("res://src/ui/components/battle/MoralePanicTracker.gd")

func _tracker() -> Object:
	# Detached is fine: every UI reference in this component is null-guarded, so
	# _ready() never having run does not affect the mechanic.
	return auto_free(TRACKER.new())

# ── The defect ────────────────────────────────────────────────────────────

func test_unseeded_tracker_can_never_bail_anyone() -> void:
	# The pre-fix state, reproduced exactly: nothing ever called set_enemy_count.
	var t = _tracker()
	t.setup_from_enemy_data({"name": "Gangers", "panic": "1-6", "special_rules": []})
	t.casualties_this_round = 2

	var result: Dictionary = t.perform_morale_check()

	assert_int(result["bails"]).is_equal(0)

func test_seeded_tracker_bails_every_die_inside_the_panic_range() -> void:
	var t = _tracker()
	t.setup_from_enemy_data({"name": "Gangers", "panic": "1-6", "special_rules": []})
	t.set_enemy_count(5)
	t.casualties_this_round = 2

	var result: Dictionary = t.perform_morale_check()

	# Core Rules p.114: one die per figure lost this round; each die in the Bail
	# range removes one enemy.
	assert_int(result["bails"]).is_equal(2)
	assert_int(t.enemies_remaining).is_equal(3)
	assert_int(t.fled_enemies).is_equal(2)

func test_bails_cannot_exceed_the_figures_still_standing() -> void:
	var t = _tracker()
	t.setup_from_enemy_data({"name": "Gangers", "panic": "1-6", "special_rules": []})
	t.set_enemy_count(1)
	t.casualties_this_round = 3

	assert_int(t.perform_morale_check()["bails"]).is_equal(1)

# ── The enemy's real numbers reach the panel ──────────────────────────────

func test_panic_range_comes_from_the_enemy_not_the_default() -> void:
	# Pre-fix the panel always showed the hardcoded default of 2.
	var t = _tracker()
	t.setup_from_enemy_data({"name": "Raiders", "panic": "1-3", "special_rules": []})

	assert_int(t.panic_range_max).is_equal(3)
	assert_str(t.enemy_type_name).is_equal("Raiders")

func test_panic_zero_means_fight_to_the_death() -> void:
	# Core Rules p.114: "Some enemy types have a Bail Range of 0, indicating that
	# they fight to the death."
	var t = _tracker()
	t.setup_from_enemy_data({"name": "Converted", "panic": "0", "special_rules": []})
	t.set_enemy_count(4)
	t.casualties_this_round = 3

	var result: Dictionary = t.perform_morale_check()

	assert_bool(t.is_fearless_all).is_true()
	assert_int(result["bails"]).is_equal(0)
	assert_int(t.enemies_remaining).is_equal(4)

func test_special_rules_are_detected_from_the_enemy_entry() -> void:
	var t = _tracker()
	t.setup_from_enemy_data({
		"name": "Test Foe", "panic": "1-2",
		"special_rules": ["Stubborn: ignores the first casualty", "Dogged"],
	})

	assert_bool(t.is_stubborn).is_true()
	assert_bool(t.is_dogged).is_true()

func test_stubborn_ignores_the_first_casualty_of_the_battle_only() -> void:
	var t = _tracker()
	t.setup_from_enemy_data({
		"name": "Test Foe", "panic": "1-6", "special_rules": ["Stubborn"]})
	t.set_enemy_count(6)

	# Round 1: one casualty, absorbed by Stubborn.
	t.casualties_this_round = 1
	assert_int(t.perform_morale_check()["bails"]).is_equal(0)

	# Round 2: the discount is spent, so the die is rolled.
	t.new_round()
	t.casualties_this_round = 1
	assert_int(t.perform_morale_check()["bails"]).is_equal(1)

func test_fearless_figures_are_not_bailable() -> void:
	# Core Rules p.114 Fearless / p.105 Unique Individuals: skipped by Morale dice.
	var t = _tracker()
	t.setup_from_enemy_data({"name": "Test Foe", "panic": "1-6", "special_rules": []})
	t.set_enemy_count(3)
	t.lieutenant_count = 1
	t.unique_individual_present = true
	t.casualties_this_round = 3

	# 3 figures left, 2 of them Fearless -> at most 1 can bail.
	assert_int(t.perform_morale_check()["bails"]).is_equal(1)

func test_new_round_clears_the_per_round_casualty_count() -> void:
	var t = _tracker()
	t.setup_from_enemy_data({"name": "Test Foe", "panic": "1-6", "special_rules": []})
	t.set_enemy_count(5)
	t.casualties_this_round = 2

	t.new_round()

	assert_int(t.casualties_this_round).is_equal(0)
	assert_str(t.perform_morale_check()["message"]).contains("No casualties")
