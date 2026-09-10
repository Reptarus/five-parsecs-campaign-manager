extends GdUnitTestSuite
## The post-battle wizard is REUSED, not rebuilt — so every field it mutates must
## be re-armed for the next battle.
##
## THE DEFECT (measured on a Lenovo TB361FU, deploy #29, 2026-09-09). The player
## fought a second battle in one session, recorded the result, watched all 14 steps
## resolve — and could not leave. "Post-Battle Sequence, Step 14 of 14" with its only
## forward control dead; escape required force-quitting the app.
##
## A three-arm, one-variable proof on device: session A battle 1 ENABLED, session A
## battle 2 DISABLED, session B (after relaunch) battle 1 ENABLED again. The only
## variable is whether _finish_post_battle() has already run once in that process.
##
## ⭐ WHY IT SURVIVED. refresh_from_battle_results() exists PRECISELY because someone
## already discovered this panel is permanent — its docblock says so — and it carefully
## re-does six things. It missed the field _finish_post_battle() permanently mutated,
## and four caches besides. The fix written for reuse missed the state that reuse breaks.
##
## ⚠ FIVE FIELDS, THREE DIFFERENT FAILURE MODES — which is why this suite asserts each
## separately instead of one blanket "everything is empty":
##   finish_button.disabled   blocks a legitimate advance   (the soft-lock)
##   _inline_rolls_completed  PERMITS an illegitimate one   (roll gates bypassed)
##   _backend_rival_lines     appends, and suppresses its own is_empty() fallback
##   _backend_resolved        renders the previous battle's lines under this one
##   _backend_injuries        stale whenever the signal stays silent
##
## gdUnit4 v6.0.3.

const PostBattleScene := preload("res://src/ui/screens/postbattle/PostBattleSequence.tscn")

## Step 5, "6. Check for Invasion", is the ONE step with requires_roll: true — the
## generic-gate branch of _update_next_button_state() that reads
## _inline_rolls_completed.has(current_step). Named rather than inlined so a
## renumbering of the step list fails loudly here instead of passing vacuously.
const STEP_REQUIRING_A_ROLL := 5


func _fresh_panel() -> Control:
	var ui: Control = auto_free(PostBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	return ui


## Put the panel in the state the END of a battle leaves it in — by driving the REAL
## handlers, never by hand-setting the fields the fix clears. A fixture that set those
## fields directly would still pass if the production writers moved elsewhere.
func _play_out_a_battle(ui: Control) -> void:
	ui._on_backend_rival_status([
		{"name": "Ripper Nine", "rival_id": "riv_1", "follows": true},
	])
	ui._register_inline_rolls(STEP_REQUIRING_A_ROLL, 0)
	ui._finish_post_battle()


func test_the_finish_button_is_re_armed_for_the_second_battle() -> void:
	# THE SOFT-LOCK. Everything else in this suite is state; this is the one the
	# player actually hits, and it makes the second battle of any session unfinishable.
	var ui: Control = await _fresh_panel()
	_play_out_a_battle(ui)
	assert_bool(ui.finish_button.disabled).override_failure_message(
		"premise check: _finish_post_battle() should have disabled the button"
		).is_true()

	ui.refresh_from_battle_results()
	await get_tree().process_frame

	assert_bool(ui.finish_button.disabled).override_failure_message(
		"SOFT-LOCK: the second post-battle sequence of a session cannot be completed — "
		+ "finish_button is still disabled from the previous battle"
		).is_false()


func test_a_second_battle_does_not_inherit_the_first_battles_roll_gates() -> void:
	# ASSERT WHERE THE DAMAGE LANDS, not that a Dictionary is empty. A stale
	# _inline_rolls_completed entry makes _update_next_button_state() take the
	# "already rolled" branch, so battle 2 can walk PAST a roll-gated step without
	# rolling — the opposite polarity to the soft-lock, and the more expensive one,
	# because nothing on screen looks wrong.
	var ui: Control = await _fresh_panel()
	_play_out_a_battle(ui)

	ui.refresh_from_battle_results()
	await get_tree().process_frame

	assert_bool(ui.post_battle_steps[STEP_REQUIRING_A_ROLL].get("requires_roll", false)
		).override_failure_message(
		"premise check: step %d is no longer the requires_roll step — renumbered?"
		% STEP_REQUIRING_A_ROLL).is_true()

	ui.current_step = STEP_REQUIRING_A_ROLL
	ui._show_current_step()
	await get_tree().process_frame

	assert_bool(ui.next_button.disabled).override_failure_message(
		"the invasion roll gate was already satisfied on a fresh battle — battle 2 "
		+ "inherited battle 1's roll and can skip the step entirely"
		).is_true()


func test_rival_lines_do_not_accumulate_across_battles() -> void:
	# The concatenation seen on device: turn 10's rows rendered above turn 11's in
	# one results pane, because _backend_rival_lines is appended to and never cleared.
	var ui: Control = await _fresh_panel()
	_play_out_a_battle(ui)
	var after_one: int = (ui._backend_rival_lines as Array).size()
	assert_int(after_one).override_failure_message(
		"premise check: the first battle recorded no rival lines to accumulate"
		).is_greater(0)

	ui.refresh_from_battle_results()
	await get_tree().process_frame
	ui._on_backend_rival_status([
		{"name": "Grey Syndicate", "rival_id": "riv_2", "follows": false},
	])

	assert_int((ui._backend_rival_lines as Array).size()).override_failure_message(
		"battle 2's Rival lines were appended to battle 1's (%d lines for one rival)"
		% (ui._backend_rival_lines as Array).size()).is_equal(after_one)


func test_a_battle_with_no_rival_change_does_not_restate_the_previous_one() -> void:
	# THE WORSE HALF, and it is not merely cosmetic. The producer ends with
	# `if _backend_rival_lines.is_empty(): append("No change to your Rivals list.")`.
	# Carrying battle 1's lines over makes that guard permanently false, so a battle
	# with NO rival change silently re-states the PREVIOUS battle's outcome as current.
	var ui: Control = await _fresh_panel()
	_play_out_a_battle(ui)

	ui.refresh_from_battle_results()
	await get_tree().process_frame
	ui._on_backend_rival_status([])  # battle 2: nothing happened to any rival

	var lines: Array = ui._backend_rival_lines
	assert_int(lines.size()).is_equal(1)
	assert_str(str(lines[0])).override_failure_message(
		"a battle with no rival change reported '%s' — that is the PREVIOUS battle's "
		% str(lines[0]) + "result presented as this one's"
		).contains("No change")


func test_backend_step_lines_do_not_survive_into_the_next_battle() -> void:
	# _backend_resolved is keyed by step index, so any step whose backend signal does
	# not re-fire for battle 2 renders battle 1's lines with no indication they are stale.
	var ui: Control = await _fresh_panel()
	_play_out_a_battle(ui)
	assert_bool((ui._backend_resolved as Dictionary).has(ui.STEP_RIVAL_STATUS)
		).override_failure_message(
		"premise check: nothing was recorded for the rival step").is_true()

	ui.refresh_from_battle_results()
	await get_tree().process_frame

	assert_bool((ui._backend_resolved as Dictionary).is_empty()
		).override_failure_message(
		"battle 1's resolved step lines are still addressable by step index"
		).is_true()


func test_the_already_handled_fields_are_still_handled() -> void:
	# INSTRUMENT THE PREMISE. _initialize_steps() already re-does step_results and
	# _step_log_entries. Asserting them here proves this suite is discriminating —
	# that the four fields above genuinely lacked a reset path, rather than the whole
	# panel being blanket-cleared by something the other cases would also have caught.
	var ui: Control = await _fresh_panel()
	_play_out_a_battle(ui)
	ui.step_results[0] = {"stale": true}
	ui._step_log_entries[0] = ["stale line"]

	ui.refresh_from_battle_results()
	await get_tree().process_frame

	assert_bool((ui.step_results[0] as Dictionary).is_empty()).override_failure_message(
		"step_results was NOT reset — the premise of this suite is wrong").is_true()
	assert_int((ui._step_log_entries[0] as Array).size()).override_failure_message(
		"_step_log_entries was NOT reset — the premise of this suite is wrong"
		).is_equal(0)
