extends GdUnitTestSuite
## Sprint 7b: the post-battle screen follows the Introductory Campaign's step lists.
##
## THE DEFECT THIS PINS. The backend skipped every post-battle step a guided turn leaves
## out, and the screen then offered its own roll for each one. So the turn-0 training
## battle, of which Compendium p.105 says "No experience points or other post-battle
## functions are carried out", offered Battlefield Finds, the Loot Table, an Injury roll
## for every knocked-out recruit and a Character Event. Turns 1-3 offered the steps their
## lists (pp.104-109) leave out. The screen also draws its first step before the backend
## has run, so it must redraw once the run has its answer.

const PostBattleScene := preload("res://src/ui/screens/postbattle/PostBattleSequence.tscn")
const PostBattlePhaseScript := preload("res://src/core/campaign/phases/PostBattlePhase.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const TURN_ONE: Array = ["get_paid", "battlefield_finds", "gather_loot", "injuries", "experience"]

var _user_state: Dictionary
var _pbp: Node
var _saved_handler: Variant
var _saved_active: bool
var _saved_steps: Array


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	# The screen finds its backend through CampaignPhaseManager, whose setup() builds
	# the handler. A test process may not have run setup(), so build one the same way.
	_saved_handler = CampaignPhaseManager.post_battle_phase_handler
	_pbp = _saved_handler
	if _pbp == null:
		_pbp = auto_free(PostBattlePhaseScript.new())
		add_child(_pbp)
		CampaignPhaseManager.post_battle_phase_handler = _pbp
	assert_object(CampaignPhaseManager.get_phase_handler("post_battle")).override_failure_message(
		"premise: the screen can find the post-battle backend").is_same(_pbp)
	_saved_active = _pbp._intro_gating_active
	_saved_steps = _pbp._intro_allowed_steps.duplicate()


func after_test() -> void:
	if _pbp != null and is_instance_valid(_pbp):
		_pbp._intro_gating_active = _saved_active
		_pbp._intro_allowed_steps = _saved_steps
	CampaignPhaseManager.post_battle_phase_handler = _saved_handler
	SaveDirGuard.restore(_user_state)


func _gate(active: bool, steps: Array) -> void:
	_pbp._intro_gating_active = active
	_pbp._intro_allowed_steps = steps


## A battle whose fallbacks would offer rolls: the crew held the field and lost two.
func _screen() -> Control:
	var ui: Control = auto_free(PostBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	ui._connect_backend_signals()
	ui.battle_results = {"held_field": true, "victory": true, "crew_casualties": 2}
	return ui


func _show(ui: Control, step: int) -> void:
	ui.current_step = step
	ui._show_current_step()


func _skip_text(ui: Control) -> String:
	var n: Node = ui.step_content.find_child("IntroSkippedStep", true, false)
	return str((n as Label).text) if n is Label else ""


func _roll_buttons(ui: Control) -> Array:
	var out: Array = []
	for b in ui.step_content.find_children("*", "Button", true, false):
		if "Roll" in str((b as Button).text):
			out.append((b as Button).text)
	return out


func test_a_training_battle_offers_no_post_battle_roll() -> void:
	_gate(true, [])
	var ui: Control = await _screen()
	for step: int in range(0, 13):
		_show(ui, step)
		assert_str(_skip_text(ui)).override_failure_message(
			"step %d" % (step + 1)).contains("Training battle")
		assert_array(_roll_buttons(ui)).override_failure_message(
			"step %d" % (step + 1)).is_empty()
		assert_bool(ui.next_button.disabled).override_failure_message(
			"step %d" % (step + 1)).is_false()
	_show(ui, 5)
	assert_bool(ui.roll_button.visible).override_failure_message(
		"the skipped Invasion step has no die").is_false()


func test_turn_one_keeps_its_listed_steps_and_skips_the_rest() -> void:
	_gate(true, TURN_ONE)
	var ui: Control = await _screen()
	_show(ui, 6)
	assert_str(_skip_text(ui)).is_empty()
	assert_array(_roll_buttons(ui)).contains(["Roll on Loot Table (D100)"])
	for step: int in [0, 1, 2, 5, 10, 11, 12]:
		_show(ui, step)
		assert_str(_skip_text(ui)).override_failure_message(
			"step %d" % (step + 1)).contains("skips this step")


## The first step is drawn before the backend has run; the run's start redraws it.
func test_the_first_step_is_redrawn_once_the_run_starts() -> void:
	_gate(false, [])
	var ui: Control = await _screen()
	_show(ui, 0)
	assert_str(_skip_text(ui)).override_failure_message(
		"premise: not gated before the run").is_empty()
	_gate(true, [])
	_pbp.post_battle_phase_started.emit()
	assert_str(_skip_text(ui)).contains("Training battle")


## The backend answers from the snapshot it took when its run started.
func test_the_backend_answers_from_its_snapshot() -> void:
	var pbp: Node = auto_free(PostBattlePhaseScript.new())
	pbp._intro_gating_active = false
	assert_bool(pbp.intro_skips_step("gather_loot")).is_false()
	pbp._intro_gating_active = true
	pbp._intro_allowed_steps = TURN_ONE.duplicate()
	assert_bool(pbp.intro_skips_step("gather_loot")).is_false()
	assert_bool(pbp.intro_skips_step("check_invasion")).is_true()
	assert_bool(pbp.intro_skips_step("")).override_failure_message(
		"steps 1-3 are on no guided turn's list").is_true()
	assert_bool(pbp.is_intro_training_battle()).is_false()
	pbp._intro_allowed_steps = []
	assert_bool(pbp.is_intro_training_battle()).is_true()
