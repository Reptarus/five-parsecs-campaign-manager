class_name ProblemSolvingTests
extends RefCounted
## Problem Solving — Core Rules Appendix IV, p.152. VERBATIM.
##
## The whole appendix, quoted:
##
##   "Players inclined towards more complex scenarios may set their figures an
##    array of tasks to accomplish: Doors that need opening, computers that need
##    hacking, and strange alien animals that need calming. This section offers a
##    few quick solutions to handle these situations as they arise. Pick
##    whichever fits your situation best. Such tasks and tests are optional and
##    will not come up in typical play, being intended for creative players to
##    toy with.
##
##    Performing a test uses replaces a figure's Combat Action for that round
##    unless the rules or a scenario dictates otherwise.
##
##    Quick Test: Decide if the test is Easy or Hard, then roll a D6. An Easy
##    test is passed on a roll of 3+ while a Hard test is passed on a roll of 5+.
##
##    Opposed Test: Roll a D6 for each figure with the higher roll prevailing. On
##    a draw, the action is unresolved this round.
##
##    Wits Test: Set a Challenge Rating from 2 to 7. Roll 1D6 and add the Savvy
##    score of the character. If the result is equal or better, the test is
##    passed.
##
##    Risk and Fumbles: Rolling a 1 on the die for any Problem Solving tests
##    above (before modifiers) Stuns the character - they have injured or
##    exhausted themselves temporarily. If you deem a given test to be inherently
##    Risky, rolling a 1 inflicts a Damage +0 Hit as well."
##
## WHY THIS FILE EXISTS. Appendix IV had ZERO code presence — not a dead
## implementation, an absent one. It is also the resolver Appendix VIII needs:
## p.172's "if a player wishes to request help, a 1D6+Savvy roll of 5+ is usually
## needed" is a Wits Test with a Challenge Rating of 5, and the GM's +/-1 is the
## modifier this signature already carries.
##
## Core rules, no DLC gate: the appendix is in the base book.

enum TestKind { QUICK_EASY, QUICK_HARD, OPPOSED, WITS }

## p.152: "An Easy test is passed on a roll of 3+ while a Hard test is passed on
## a roll of 5+."
const EASY_TARGET := 3
const HARD_TARGET := 5

## p.152: "Set a Challenge Rating from 2 to 7."
const WITS_RATING_MIN := 2
const WITS_RATING_MAX := 7

## p.152: "Rolling a 1 on the die ... (BEFORE MODIFIERS) Stuns the character."
const FUMBLE_FACE := 1


static func _roll_d6(roller: Callable) -> int:
	if roller.is_valid():
		return clampi(int(roller.call()), 1, 6)
	return randi_range(1, 6)


## Quick Test (p.152). `hard` selects the 5+ target instead of 3+.
##
## Returns {kind, roll, target, passed, fumble, stunned, damage_hit, summary}.
## `damage_hit` is true only when the caller declared the test Risky.
static func quick_test(hard: bool = false, risky: bool = false,
		roller: Callable = Callable()) -> Dictionary:
	var roll: int = _roll_d6(roller)
	var target: int = HARD_TARGET if hard else EASY_TARGET
	var out: Dictionary = {
		"kind": TestKind.QUICK_HARD if hard else TestKind.QUICK_EASY,
		"roll": roll,
		"target": target,
		"passed": roll >= target,
		"fumble": roll == FUMBLE_FACE,
	}
	_apply_fumble(out, risky)
	out["summary"] = "%s Test: rolled %d, needed %d+ — %s.%s" % [
		"Hard" if hard else "Easy", roll, target,
		"PASSED" if out["passed"] else "failed", _fumble_text(out)]
	return out


## Opposed Test (p.152): "Roll a D6 for each figure with the higher roll
## prevailing. On a draw, the action is unresolved this round."
##
## `winner` is "actor", "opponent" or "" for the draw, and `passed` is true only
## for the actor — a draw is NOT a pass, it is an unresolved action.
static func opposed_test(risky: bool = false, roller: Callable = Callable(),
		opponent_roller: Callable = Callable()) -> Dictionary:
	var roll: int = _roll_d6(roller)
	var opposing: int = _roll_d6(opponent_roller if opponent_roller.is_valid() else roller)
	var winner: String = ""
	if roll > opposing:
		winner = "actor"
	elif opposing > roll:
		winner = "opponent"
	var out: Dictionary = {
		"kind": TestKind.OPPOSED,
		"roll": roll,
		"opponent_roll": opposing,
		"winner": winner,
		"passed": winner == "actor",
		"draw": winner == "",
		"fumble": roll == FUMBLE_FACE,
	}
	_apply_fumble(out, risky)
	var verdict: String = "unresolved this round (draw)"
	if winner == "actor":
		verdict = "you prevail"
	elif winner == "opponent":
		verdict = "they prevail"
	out["summary"] = "Opposed Test: %d vs %d — %s.%s" % [
		roll, opposing, verdict, _fumble_text(out)]
	return out


## Wits Test (p.152): 1D6 + Savvy against a Challenge Rating of 2 to 7.
##
## `modifier` carries the Appendix VIII "+/-1 based on circumstances" and any
## scenario adjustment. The FUMBLE is checked on the raw die — the book says
## "before modifiers" — so a natural 1 stuns even when Savvy would have carried
## the total over the rating.
static func wits_test(challenge_rating: int, savvy: int, risky: bool = false,
		modifier: int = 0, roller: Callable = Callable()) -> Dictionary:
	var rating: int = clampi(challenge_rating, WITS_RATING_MIN, WITS_RATING_MAX)
	var roll: int = _roll_d6(roller)
	var total: int = roll + savvy + modifier
	var out: Dictionary = {
		"kind": TestKind.WITS,
		"roll": roll,
		"savvy": savvy,
		"modifier": modifier,
		"total": total,
		"target": rating,
		"passed": total >= rating,
		"fumble": roll == FUMBLE_FACE,
	}
	_apply_fumble(out, risky)
	out["summary"] = "Wits Test: %d + Savvy %d%s = %d vs Challenge %d — %s.%s" % [
		roll, savvy,
		("" if modifier == 0 else (" %+d" % modifier)),
		total, rating, "PASSED" if out["passed"] else "failed", _fumble_text(out)]
	return out


## Appendix VIII p.172: "if a player wishes to request help, a 1D6+Savvy roll of
## 5+ is usually needed. The GM can apply a +/-1 modifier based on circumstances.
## A NATURAL 6 means the NC ... will request to join your crew permanently."
##
## A Wits Test at Challenge 5, with the natural-6 recruitment clause on top.
static func request_neutral_help(savvy: int, modifier: int = 0,
		roller: Callable = Callable()) -> Dictionary:
	var out: Dictionary = wits_test(5, savvy, false, clampi(modifier, -1, 1), roller)
	out["wants_to_join"] = int(out.get("roll", 0)) == 6
	if bool(out["wants_to_join"]):
		out["summary"] += (" Natural 6: they ask to join the crew permanently if"
			+ " they survive (Core Rules p.172).")
	return out


## p.152 Risk and Fumbles, applied identically to all three tests.
static func _apply_fumble(out: Dictionary, risky: bool) -> void:
	var fumbled: bool = bool(out.get("fumble", false))
	out["stunned"] = fumbled
	out["damage_hit"] = fumbled and risky
	out["risky"] = risky


static func _fumble_text(out: Dictionary) -> String:
	if not bool(out.get("fumble", false)):
		return ""
	if bool(out.get("damage_hit", false)):
		return (" Natural 1: the character is Stunned and takes a Damage +0 Hit"
			+ " (Risky test, Core Rules p.152).")
	return " Natural 1: the character is Stunned (Core Rules p.152)."


## The appendix as reference text, for the battle Reference drawer.
static func get_reference_text() -> String:
	return """[b]Problem Solving (Core Rules Appendix IV, p.152)[/b]
Optional tests for doors, computers, animals and similar. A test
REPLACES that figure's Combat Action for the round, unless the
scenario says otherwise.

[b]Quick Test[/b]
Decide Easy or Hard, then roll a D6.
  Easy passes on [color=#10B981]3+[/color]    Hard passes on [color=#10B981]5+[/color]

[b]Opposed Test[/b]
Roll a D6 for each figure. Higher roll prevails.
On a draw the action is [color=#D97706]unresolved this round[/color].

[b]Wits Test[/b]
Set a Challenge Rating from [color=#4FC3F7]2 to 7[/color].
Roll 1D6 and add the character's Savvy. Equal or better passes.
A rating of 7 means a crew of +0 Savvy cannot pass at all.

[b]Risk and Fumbles[/b]
A natural [color=#DC2626]1[/color] on any of these tests (BEFORE modifiers)
Stuns the character. If you deem the test Risky, it also
inflicts a [color=#DC2626]Damage +0 Hit[/color]."""
