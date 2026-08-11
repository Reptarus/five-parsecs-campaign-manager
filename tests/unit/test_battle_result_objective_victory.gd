extends GdUnitTestSuite
## T5-06 — the recorded battle result must agree with the objective (Core Rules p.89)
##
## Book text, verified against the PDF (p.89, "5. Determine the Objective"):
##
##   "To Win the battle, you must achieve the objective (even if you are
##    subsequently chased from the battlefield, unless the specific mission
##    objective states otherwise)."
##
## Found on device: ticking "Objective achieved" left Battle Result reading "Lost",
## and the two controls could be submitted contradicting each other. That was not
## only a display fault — the emitted payload carried `mission_success` derived from
## the objective and `victory`/`won` derived from the dropdown, and those feed
## DIFFERENT post-battle consumers. One battle, two answers.
##
## gdUnit4 v6.0.3 compatible. NOTE: run with -c, never --headless (project rule).

const Form := preload("res://src/ui/components/battle/BattleResultsInputForm.gd")

const WON := 0
const LOST := 1
const FLED := 2


func test_achieving_the_objective_is_a_win() -> void:
	assert_bool(Form.decide_victory(WON, true, true)).is_true()


func test_achieving_the_objective_is_a_win_even_when_the_dropdown_says_lost() -> void:
	# The exact contradiction observed on the tablet.
	assert_bool(Form.decide_victory(LOST, true, true)).is_true()


func test_being_chased_off_does_not_cost_the_win() -> void:
	# p.89's parenthesis, and the reason "Fled" is deliberately NOT rewritten in the
	# UI the way "Lost" is: fleeing stays true as its own fact (fled_early drives the
	# p.123 XP rule) while the battle is still won.
	assert_bool(Form.decide_victory(FLED, true, true)).is_true()


func test_failing_the_objective_is_not_a_win_however_the_fight_went() -> void:
	# The other direction matters just as much: holding the field while failing to
	# deliver is not a win, and the form's own comment already said so for
	# mission_success. victory now agrees.
	assert_bool(Form.decide_victory(WON, true, false)).is_false()
	assert_bool(Form.decide_victory(LOST, true, false)).is_false()


func test_without_an_objective_the_dropdown_is_the_only_signal() -> void:
	# DETECTION-CRITICAL in the opposite direction. If has_objective were ignored and
	# this always read objective_met, every non-objective battle would record as a
	# loss — an unchecked box on a form that never showed one.
	assert_bool(Form.decide_victory(WON, false, false)).is_true()
	assert_bool(Form.decide_victory(LOST, false, false)).is_false()
	assert_bool(Form.decide_victory(FLED, false, false)).is_false()


func test_the_form_still_exposes_both_halves_of_the_result() -> void:
	# victory and mission_success remain SEPARATE keys — they are not redundant on a
	# non-objective battle, and downstream reads both. This guards against someone
	# "simplifying" one away now that they agree on objective missions.
	var src := FileAccess.open(
		"res://src/ui/components/battle/BattleResultsInputForm.gd", FileAccess.READ)
	assert_that(src).is_not_null()
	var text := src.get_as_text()
	assert_str(text).contains("\"victory\": victory")
	assert_str(text).contains("mission_success")
	# And the derivation must actually be wired into submit, not just defined.
	assert_str(text).contains("decide_victory(")
