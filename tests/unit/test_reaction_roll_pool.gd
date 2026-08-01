extends GdUnitTestSuite
## The Reaction Roll, Core Rules p.113.
##
## THE GAPS THESE PIN, all three of which shipped together:
##
## 1. IT IS A POOL. "Roll a number of D6 equal to the number of your characters.
##    Assign each of the dice results to one of your characters." Which die goes
##    to whom is the player's decision and the round's main tactical choice. The
##    app rolled one die per figure and pinned it, deleting the decision.
##
## 2. THE APP ROLLED TWICE AND THE ROLLS DISAGREED.
##    _assign_crew_reaction_slots() rolled and set react_slot (which drives the
##    Quick/Slow rails); _on_roll_reactions_pressed() — the button the player
##    presses — rolled AGAIN, logged that second result, and never touched
##    react_slot. The numbers shown were not the numbers used.
##
## 3. THE FERAL RULE DID NOT EXIST. p.113 "Feral Impetuous Actions": "If your
##    crew has a Feral character, and you roll exactly a single 1 on your
##    Initiative dice, it must be assigned to a Feral character. This rule does
##    not apply if you roll multiple 1s."

const Pool = preload("res://src/core/battle/ReactionRollPool.gd")

func _fig(id: String, reactions: int, feral: bool = false) -> Dictionary:
	return {"id": id, "name": id, "reactions": reactions, "is_feral": feral}

# ── The pool is one die per figure ───────────────────────────────────────

func test_the_pool_has_one_die_per_character() -> void:
	for n in [1, 3, 5, 6]:
		assert_int(Pool.roll_pool(n).size()).is_equal(n)

func test_every_die_is_a_d6() -> void:
	for d in Pool.roll_pool(50):
		assert_int(int(d)).is_between(1, 6)

func test_the_roller_is_injectable_for_deterministic_tests() -> void:
	var fixed: Callable = func() -> int: return 4
	assert_array(Pool.roll_pool(3, fixed)).contains_exactly([4, 4, 4])

# ── Slot assignment matches the book's comparison ────────────────────────

func test_a_die_at_or_below_reactions_acts_quick() -> void:
	# "Any character assigned a die result equal or below their Reaction score
	# will act in the Quick Actions phase."
	assert_int(Pool.slot_for(1, 1)).is_equal(Pool.SLOT_QUICK)
	assert_int(Pool.slot_for(2, 3)).is_equal(Pool.SLOT_QUICK)

func test_a_die_above_reactions_acts_slow() -> void:
	assert_int(Pool.slot_for(2, 1)).is_equal(Pool.SLOT_SLOW)
	assert_int(Pool.slot_for(6, 5)).is_equal(Pool.SLOT_SLOW)

# ── The default assignment is a real permutation of the pool ─────────────

func test_every_die_is_used_exactly_once() -> void:
	# An assignment that invents or reuses a die is not an assignment of THIS
	# roll. Fixed dice, so the assertion is exact rather than statistical.
	var dice: Array = [1, 3, 5, 6]
	var figures: Array = [_fig("a", 1), _fig("b", 3), _fig("c", 2), _fig("d", 5)]
	var out: Dictionary = Pool.auto_assign(dice, figures)
	assert_int(out.size()).is_equal(4)
	var used: Array = []
	for k in out.keys():
		used.append(int(out[k]))
	used.sort()
	assert_array(used).contains_exactly([1, 3, 5, 6])

func test_the_default_puts_as_many_figures_as_possible_into_quick() -> void:
	# Dice 1 and 2; figures with Reactions 1 and 2. The 1 must go to the
	# Reactions-1 figure or it is wasted — a naive in-order assignment gives the
	# 1 to the Reactions-2 figure and drops the other to Slow.
	var dice: Array = [1, 2]
	var figures: Array = [_fig("high", 2), _fig("low", 1)]
	var out: Dictionary = Pool.auto_assign(dice, figures)
	assert_int(Pool.slot_for(int(out["low"]), 1)).is_equal(Pool.SLOT_QUICK)
	assert_int(Pool.slot_for(int(out["high"]), 2)).is_equal(Pool.SLOT_QUICK)

func test_a_figure_that_cannot_qualify_absorbs_the_worst_die() -> void:
	# Reactions 1 cannot use a 5 or 6, so it should take the largest and leave
	# the small die for someone who can act on it.
	var dice: Array = [2, 6]
	var figures: Array = [_fig("picky", 1), _fig("able", 3)]
	var out: Dictionary = Pool.auto_assign(dice, figures)
	assert_int(int(out["able"])).is_equal(2)
	assert_int(int(out["picky"])).is_equal(6)

# ── Feral Impetuous Actions (p.113) ──────────────────────────────────────

func test_a_lone_one_must_go_to_a_feral() -> void:
	var dice: Array = [1, 4, 5]
	var figures: Array = [_fig("human", 2), _fig("feral", 1, true), _fig("other", 3)]
	assert_bool(Pool.feral_die_required(dice, figures)).is_true()
	var out: Dictionary = Pool.auto_assign(dice, figures)
	assert_int(int(out["feral"])).override_failure_message(
		"p.113: a single rolled 1 must be assigned to a Feral character").is_equal(1)

func test_multiple_ones_release_the_constraint() -> void:
	# "This rule does not apply if you roll multiple 1s."
	var dice: Array = [1, 1, 5]
	var figures: Array = [_fig("human", 2), _fig("feral", 1, true), _fig("other", 3)]
	assert_bool(Pool.feral_die_required(dice, figures)).is_false()

func test_no_feral_in_the_crew_means_no_constraint() -> void:
	var dice: Array = [1, 4, 5]
	var figures: Array = [_fig("a", 2), _fig("b", 1), _fig("c", 3)]
	assert_bool(Pool.feral_die_required(dice, figures)).is_false()

func test_a_pool_with_no_ones_never_triggers_the_rule() -> void:
	var dice: Array = [2, 3, 4]
	var figures: Array = [_fig("feral", 1, true), _fig("b", 2), _fig("c", 3)]
	assert_bool(Pool.feral_die_required(dice, figures)).is_false()

# ── Validation of a player-edited assignment ─────────────────────────────

func test_a_valid_reassignment_is_accepted() -> void:
	var dice: Array = [2, 5]
	var figures: Array = [_fig("a", 3), _fig("b", 3)]
	var v: Dictionary = Pool.validate({"a": 5, "b": 2}, dice, figures)
	assert_bool(v["valid"]).override_failure_message(str(v.get("error", ""))).is_true()

func test_a_die_that_was_never_rolled_is_rejected() -> void:
	var dice: Array = [2, 5]
	var figures: Array = [_fig("a", 3), _fig("b", 3)]
	assert_bool(Pool.validate({"a": 6, "b": 2}, dice, figures)["valid"]).is_false()

func test_using_the_same_die_twice_is_rejected() -> void:
	# The most tempting edit — give both good figures the low die.
	var dice: Array = [2, 5]
	var figures: Array = [_fig("a", 3), _fig("b", 3)]
	assert_bool(Pool.validate({"a": 2, "b": 2}, dice, figures)["valid"]).is_false()

func test_moving_the_lone_one_off_a_feral_is_rejected() -> void:
	var dice: Array = [1, 4]
	var figures: Array = [_fig("feral", 1, true), _fig("human", 4)]
	var v: Dictionary = Pool.validate({"feral": 4, "human": 1}, dice, figures)
	assert_bool(v["valid"]).is_false()
	assert_str(str(v["error"])).contains("Feral")

func test_the_feral_check_is_skipped_when_the_rule_does_not_apply() -> void:
	# Two 1s: the player may put them wherever they like.
	var dice: Array = [1, 1]
	var figures: Array = [_fig("feral", 1, true), _fig("human", 1)]
	assert_bool(Pool.validate({"feral": 1, "human": 1}, dice, figures)["valid"]).is_true()

# ── Degenerate inputs ────────────────────────────────────────────────────

func test_no_figures_produces_no_assignment() -> void:
	assert_dict(Pool.auto_assign([1, 2, 3], [])).is_empty()

func test_a_single_figure_gets_the_single_die() -> void:
	var out: Dictionary = Pool.auto_assign([4], [_fig("solo", 2)])
	assert_int(int(out["solo"])).is_equal(4)
	assert_int(Pool.slot_for(4, 2)).is_equal(Pool.SLOT_SLOW)
