extends GdUnitTestSuite
## Enemy morale / Bail coverage — Core Rules p.113 ("Running Away").
##
## Roll 1D6 per casualty this round; each die within the Panic (Bail) range = 1 Bail
## (closest to enemy edge first, capped at bailable figures). Modifiers: Boss alive
## → panic −1; Boss killed → +1 die; Stubborn → ignore first casualty of the battle;
## Fearless (Panic 0) → fight to the death.
##
## RNG-proofing: with panic_range_max = 6 EVERY die (1-6) is within range, so bails ==
## dice_count deterministically. Boss state is read from the UI checkboxes, so the
## tracker is added to the tree and boss toggles are set via the checkboxes.

const Tracker = preload("res://src/ui/components/battle/MoralePanicTracker.gd")

var _t: Control

func before_test() -> void:
	_t = auto_free(Tracker.new())
	add_child(_t)
	await get_tree().process_frame  # let _ready() build the UI (incl. boss checkboxes)

func test_all_dice_bail_when_panic_is_six() -> void:
	_t.panic_range_max = 6
	_t.casualties_this_round = 2
	_t.enemies_remaining = 5
	var r: Dictionary = _t.perform_morale_check()
	assert_int(r["kills"]).is_equal(2)
	assert_int(r["effective_panic"]).is_equal(6)
	assert_int(r["bails"]).is_equal(2)  # both dice ≤ 6

func test_bails_capped_at_bailable_figures() -> void:
	_t.panic_range_max = 6
	_t.casualties_this_round = 5
	_t.enemies_remaining = 2  # only 2 left to bail
	var r: Dictionary = _t.perform_morale_check()
	assert_int(r["bails"]).is_equal(2)

func test_boss_alive_reduces_panic_range_by_one() -> void:
	_t.panic_range_max = 3
	_t.casualties_this_round = 1
	_t.enemies_remaining = 5
	if _t._boss_alive_check:
		_t._boss_alive_check.button_pressed = true
	if _t._boss_killed_check:
		_t._boss_killed_check.button_pressed = false
	var r: Dictionary = _t.perform_morale_check()
	assert_int(r["effective_panic"]).is_equal(2)  # 3 − 1 boss

func test_boss_killed_adds_extra_die() -> void:
	_t.panic_range_max = 6
	_t.casualties_this_round = 1
	_t.enemies_remaining = 5
	if _t._boss_alive_check:
		_t._boss_alive_check.button_pressed = false
	if _t._boss_killed_check:
		_t._boss_killed_check.button_pressed = true
	var r: Dictionary = _t.perform_morale_check()
	assert_bool(r.get("boss_extra_die", false)).is_true()
	assert_int(r["bails"]).is_equal(2)  # 1 kill + 1 boss die, both ≤ 6

func test_stubborn_ignores_first_casualty() -> void:
	_t.panic_range_max = 6
	_t.casualties_this_round = 1
	_t.enemies_remaining = 5
	_t.is_stubborn = true
	_t._stubborn_first_ignored = false
	var r: Dictionary = _t.perform_morale_check()
	assert_bool(r.get("stubborn_applied", false)).is_true()
	assert_int(r["bails"]).is_equal(0)  # only casualty ignored → no dice

func test_fearless_panic_zero_never_bails() -> void:
	_t.panic_range_max = 0
	_t.is_fearless_all = true
	_t.casualties_this_round = 3
	_t.enemies_remaining = 5
	var r: Dictionary = _t.perform_morale_check()
	assert_int(r["bails"]).is_equal(0)
	assert_str(str(r.get("message", ""))).contains("death")

func test_no_casualties_no_check() -> void:
	_t.panic_range_max = 2
	_t.casualties_this_round = 0
	_t.enemies_remaining = 5
	var r: Dictionary = _t.perform_morale_check()
	assert_int(r["bails"]).is_equal(0)
