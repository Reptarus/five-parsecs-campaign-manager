extends GdUnitTestSuite
## Does a Bug Hunt turn PROGRESS through each panel's own control, and does a
## finished turn END?
##
## Bug Hunt Sprint 1, Phase 0 evidence. The Sep 10 parity audit recorded a soft-lock
## from a static read: "the only complete() caller is Advance, and Advance is disabled
## until the phase is complete". The first four cases measure that claim on the REAL
## BugHuntTurnController scene, so the row stands or falls on observation.
##
## WHAT IS ASSERTED: phase PROGRESSION, never the Advance button's enabled state.
## Advance mirrors `_phase_complete[current_phase]` (BugHuntPhaseManager
## _update_navigation), and every flag is cleared at turn start
## (_reset_phase_completion). So the moment a phase completes and the turn moves on,
## Advance reads the NEXT phase's flag, which is false: a disabled Advance is the
## CORRECT state after a successful completion, and asserting on it cannot tell a
## soft-lock from a working turn.
##
## THE TURN-END CASES (the last three) ask what happens once the turn is over:
## "Start Next Turn" must begin the next turn, must not apply the finished turn's
## results a second time, and a campaign reopened from that turn's save must not
## replay it. They pin the controller's OWN stated intent, _on_advance_pressed()'s
## "between turns" branch that calls start_new_turn(), and they read campaign STATE,
## because the button looks correct either way. The reopen case accepts either
## reasonable fix: resume at turn two, or wait at the finished turn.
##
## SIDE EFFECTS. The first four cases never reach _complete_turn(), the only save in
## this flow: the Post-Battle case drives the panel standalone (BugHuntPostBattlePanel
## has no disk write, transfer or navigation), and the Mission phase is entered
## through the battle RETURN, because its Launch control calls
## SceneRouter.navigate_to("tactical_battle") and would replace the test scene.
## The turn-end cases DO reach it. GameState.save_campaign() writes
## user://saves/<campaign_id>.save through SaveFileWriter (leaving .tmp and .bak
## siblings), then sets last_campaign and rewrites ALL of user://settings.cfg, which
## _try_auto_load_last_campaign() reads at every launch. So the core carries a fixed
## id, its three save files are removed before and after every case, and the settings
## are restored as the dictionary AND the file's exact bytes: save_settings()
## re-serialises every key, so a key-level restore would still rewrite the file.
## The reopened campaign comes from BugHuntCampaignCore.load_from_file(), not
## GameState.load_campaign(), whose apply_pending_qol_data() also resets the
## PlanetDataManager autoload. Journal writes land in the CampaignJournal autoload,
## which is snapshotted and restored.

const TURN_SCENE := "res://src/ui/screens/bug_hunt/BugHuntTurnController.tscn"
const PhaseManagerScript := preload("res://src/core/campaign/BugHuntPhaseManager.gd")
const PostBattlePanelScript := preload(
		"res://src/ui/screens/bug_hunt/panels/BugHuntPostBattlePanel.gd")
const CoreScript := preload("res://src/game/campaign/BugHuntCampaignCore.gd")
const RESULT_KEY := "bug_hunt_battle_result"
## The p.205 roll context, verbatim from BugHuntPostBattleResolver
## _step_operational_progress(). DiceManager matches a forced key as a
## case-insensitive SUBSTRING of the context, so this must stay in step with it.
const OP_PROGRESS_KEY := "Bug Hunt Operational Progress"
## p.206 Military Life, rolled once per turn for a random main character. Two of
## its twenty rows cost 1 Reputation (16-20 "Time in the Brig", 91-95 "Did
## something stupid"), so an unforced roll can cancel the p.203 award and make the
## Reputation premise below fail about one run in fourteen -- measured, not feared.
const MILITARY_LIFE_KEY := "Bug Hunt Military Life"
## Row 31-35 "Time flies" -- the only row that touches neither Reputation nor any
## other campaign state ("Just playing cards in barracks. No effect.").
const MILITARY_LIFE_NEUTRAL := 33
const PROBE_ID := "zz_bug_hunt_turn_completion_probe"
const PROBE_SAVE := "user://saves/zz_bug_hunt_turn_completion_probe.save"
const SETTINGS_PATH := "user://settings.cfg"
const BATTLE_RESULT := {"victory": true, "casualties": [], "rounds": 4}
# Two objectives make p.203's base Reputation (+1) certain, so a second application of
# the turn's Reputation change is observable, and they skip the Court Martial roll. A
# played mission reports no objectives today; only the launch-failure fallbacks do.
const OBJECTIVES_RESULT := {
	"victory": true, "casualties": [], "rounds": 4, "objectives_completed": 2}

var _core: Resource = null
var _saved_campaign: Variant = null
var _had_result := false
var _saved_result: Variant = null
var _saved_entries: Array = []
var _saved_milestones: Array = []
var _saved_histories: Dictionary = {}
var _saved_next_entry_id := 1
var _saved_settings: Dictionary = {}
var _settings_existed := false
var _settings_bytes := PackedByteArray()


func _journal() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/CampaignJournal")


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameState")


func _gsm() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager")


func _dice() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/DiceManager")


func before_test() -> void:
	_core = _make_core()
	var dice_in := _dice()
	if dice_in:
		dice_in.clear_forced_results(OP_PROGRESS_KEY)
		dice_in.clear_forced_results(MILITARY_LIFE_KEY)
	var gs := _gs()
	if gs:
		_saved_campaign = gs.current_campaign
		gs.current_campaign = _core
		_saved_settings = (gs.game_settings as Dictionary).duplicate(true)
	_settings_existed = FileAccess.file_exists(SETTINGS_PATH)
	_settings_bytes = PackedByteArray()
	if _settings_existed:
		_settings_bytes = FileAccess.get_file_as_bytes(SETTINGS_PATH)
	# A run aborted mid-case can leave a probe save behind, and load_from_file()
	# falls back to its .bak, so clear them before a case can read one.
	_remove_probe_saves()
	var gsm := _gsm()
	if gsm:
		# A result left behind by another suite would route the controller into
		# _resume_after_battle() and skip Special Assignments entirely.
		_had_result = gsm.has_temp_data(RESULT_KEY)
		_saved_result = gsm.get_temp_data(RESULT_KEY)
		gsm.clear_temp_data(RESULT_KEY)
	var journal := _journal()
	if journal:
		_saved_entries = journal.entries.duplicate(true)
		_saved_milestones = journal.milestones.duplicate(true)
		_saved_histories = journal.character_histories.duplicate(true)
		_saved_next_entry_id = journal.next_entry_id


func after_test() -> void:
	var dice_out := _dice()
	if dice_out:
		# An unconsumed forced value outlives the case: the queue lives on the
		# autoload, not on this suite.
		dice_out.clear_forced_results(OP_PROGRESS_KEY)
		dice_out.clear_forced_results(MILITARY_LIFE_KEY)
	var gs := _gs()
	if gs:
		gs.current_campaign = _saved_campaign
		gs.game_settings = _saved_settings.duplicate(true)
	_restore_settings_file()
	_remove_probe_saves()
	var gsm := _gsm()
	if gsm:
		if _had_result:
			gsm.set_temp_data(RESULT_KEY, _saved_result)
		else:
			gsm.clear_temp_data(RESULT_KEY)
	var journal := _journal()
	if journal:
		# Same restore as test_journal_lifecycle.gd, index rebuilt from the entries.
		journal.entries.assign(_saved_entries)
		journal.milestones.assign(_saved_milestones)
		journal.character_histories = _saved_histories.duplicate(true)
		journal.next_entry_id = _saved_next_entry_id
		journal.entries_by_id.clear()
		for entry_v in journal.entries:
			var entry: Dictionary = entry_v
			var eid: String = str(entry.get("id", ""))
			if not eid.is_empty():
				journal.entries_by_id[eid] = entry


func _restore_settings_file() -> void:
	# Same shape as test_theme_manager.gd's config restore, written only on a change.
	if _settings_existed:
		if FileAccess.get_file_as_bytes(SETTINGS_PATH) != _settings_bytes:
			var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
			if f:
				f.store_buffer(_settings_bytes)
	elif FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)


func _remove_probe_saves() -> void:
	# SaveFileWriter.write_text_atomic() writes path + ".tmp" and keeps path + ".bak".
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = PROBE_SAVE + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _make_core() -> Resource:
	var core: Resource = CoreScript.new()
	core.campaign_name = "Turn completion probe"
	# Fixed, so the save _complete_turn() writes has a name this suite can remove.
	# get_campaign_id() otherwise mints one from the clock.
	core.campaign_id = PROBE_ID
	var squad: Dictionary = BugHuntCharacterGeneration.new().generate_squad(
			["Alpha", "Bravo", "Charlie"])
	core.initialize_squad(squad.get("main_characters", []), squad.get("grunts", []))
	core.start_campaign()
	return core


func _build_controller() -> Control:
	var ctl: Control = load(TURN_SCENE).instantiate()
	add_child(ctl)
	auto_free(ctl)
	# _ready() defers _initialize(), so the panels do not exist until a frame later.
	for i in 3:
		await get_tree().process_frame
	return ctl


func _find_button(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node as Button
	return null


func _assert_on_our_campaign(ctl: Control) -> void:
	# Without this premise every case passes vacuously: a controller that found no
	# campaign returns before building a phase manager or any panel.
	assert_object(ctl.campaign).override_failure_message(
		"premise: the controller must initialise against the pinned Bug Hunt core"
	).is_same(_core)
	assert_object(ctl.phase_manager).is_not_null()


## The population BugHuntMissionPanel stamps onto the mission before the battle
## (:334-350): every main character not in Sick Bay. The Phase 5 resolver gates the
## p.203 tally and the p.204 XP awards on it and will not invent one, so a result
## without it is a shape the app cannot produce -- and every award silently reads 0.
## Re-derived per mission, because Sick Bay changes between turns.
func _with_participants(result: Dictionary) -> Dictionary:
	var out: Dictionary = result.duplicate(true)
	if out.has("participant_ids"):
		return out
	var ids: Array = []
	var sick_bay: Dictionary = _core.sick_bay if "sick_bay" in _core else {}
	for mc in _core.main_characters:
		if not (mc is Dictionary):
			continue
		var cid: String = str(mc.get("id", mc.get("character_id", "")))
		if cid.is_empty() or sick_bay.has(cid) or cid in ids:
			continue
		ids.append(cid)
	out["participant_ids"] = ids
	return out


## character id -> the field's value, for a comparison that survives a character
## leaving the roster between the two reads (see test_the_second_turn_also_plays_to_its_end).
func _counts_by_id(key: String) -> Dictionary:
	var out := {}
	for mc in _core.main_characters:
		if mc is Dictionary:
			out[str(mc.get("id", mc.get("character_id", "")))] = int(mc.get(key, 0))
	return out


func _sum_character_field(key: String) -> int:
	var total := 0
	for mc in _core.main_characters:
		if mc is Dictionary:
			total += int(mc.get(key, 0))
	return total


## Plays turn one to its end through the controls a player uses and returns the
## controller left showing the finished turn, or null when a premise fails, so no
## case built on it can pass against a turn that never ended.
func _complete_turn_one(result: Dictionary = BATTLE_RESULT) -> Control:
	var first: Control = await _build_controller()
	_assert_on_our_campaign(first)
	return await _finish_turn_from(first, 1, result)


## Plays to its end the turn the given controller is SHOWING -- which must be sitting
## at Special Assignments -- and returns the controller left showing the finished turn.
## Not the one passed in: the battle return rebuilds the screen.
##
## Split out of _complete_turn_one() so the SECOND turn can be played through exactly
## the same controls. The turn number is a parameter rather than a read of
## campaign_turn, because asserting a value against the code that just produced it is
## the check that cannot disagree with itself.
func _finish_turn_from(ctl: Control, expected_turn: int, result: Dictionary) -> Control:
	var gsm := _gsm()
	assert_object(gsm).is_not_null()
	if gsm == null:
		return null

	var first: Control = ctl
	var skip := _find_button(first.panels[0], "Skip Assignments")
	assert_object(skip).override_failure_message(
		"premise: Special Assignments must offer its Skip control").is_not_null()
	if skip == null:
		return null
	skip.pressed.emit()
	await get_tree().process_frame
	assert_int(first.phase_manager.current_phase).override_failure_message(
		"premise: Skip must reach the Mission phase"
	).is_equal(PhaseManagerScript.Phase.MISSION)

	# Launch replaces this scene, the battle screen stores its result, and the
	# controller is rebuilt from that result. Stand in for all three.
	first.queue_free()
	await get_tree().process_frame
	var stamped: Dictionary = _with_participants(result)
	assert_array(stamped["participant_ids"]).override_failure_message(
		"premise: somebody must take the field, or the tally and the XP awards are " +
		"correctly zero and every award assertion below passes vacuously"
	).is_not_empty()
	gsm.set_temp_data(RESULT_KEY, stamped)

	var second: Control = await _build_controller()
	_assert_on_our_campaign(second)
	assert_int(second.phase_manager.current_phase).override_failure_message(
		"premise: the battle return must land on Post-Battle"
	).is_equal(PhaseManagerScript.Phase.POST_BATTLE)
	var post_battle: Control = second.panels[2]
	var process := _find_button(post_battle, "Process Post-Battle")
	assert_object(process).override_failure_message(
		"premise: Post-Battle must offer its Process control").is_not_null()
	if process == null:
		return null
	process.pressed.emit()
	await get_tree().process_frame
	var complete := _find_button(post_battle, "Complete Post-Battle")
	assert_object(complete).override_failure_message(
		"premise: processing must reveal the Complete control").is_not_null()
	if complete == null:
		return null
	complete.pressed.emit()
	await get_tree().process_frame

	assert_int(_core.campaign_turn).override_failure_message(
		"premise: turn %d must be the turn that just ended" % expected_turn
	).is_equal(expected_turn)
	var next := _find_button(second, "Start Next Turn")
	assert_object(next).override_failure_message(
		"premise: a finished turn must offer Start Next Turn").is_not_null()
	if next == null:
		return null
	assert_bool(next.disabled).override_failure_message(
		"premise: Start Next Turn must be enabled once the turn ends").is_false()
	return second


# --- Special Assignments ------------------------------------------------------

func test_rolling_real_assignments_advances_the_turn_to_mission() -> void:
	var ctl: Control = await _build_controller()
	_assert_on_our_campaign(ctl)
	assert_int(ctl.phase_manager.current_phase).is_equal(
			PhaseManagerScript.Phase.SPECIAL_ASSIGNMENTS)

	# Assign every trooper through the picker a player uses. An EMPTY roll skips
	# every slot (SpecialAssignmentsPanel.gd:259) and would never reach the code
	# that rolls and awards, so it could pass while the real path aborts.
	var sa: Control = ctl.panels[0]
	var assigned := 0
	for node in sa.find_children("*", "OptionButton", true, false):
		var picker := node as OptionButton
		for i in range(1, picker.item_count):
			if not picker.is_item_disabled(i):
				picker.select(i)
				assigned += 1
				break
	assert_int(assigned).override_failure_message(
		"premise: at least one trooper must receive a real assignment").is_greater(0)

	var roll := _find_button(sa, "Roll All Assignments")
	assert_object(roll).is_not_null()
	roll.pressed.emit()
	await get_tree().process_frame

	assert_int(ctl.phase_manager.current_phase).override_failure_message(
		"Special Assignments did not advance through its own Roll control"
	).is_equal(PhaseManagerScript.Phase.MISSION)


func test_skipping_assignments_advances_the_turn_to_mission() -> void:
	var ctl: Control = await _build_controller()
	_assert_on_our_campaign(ctl)

	var skip := _find_button(ctl.panels[0], "Skip Assignments")
	assert_object(skip).is_not_null()
	skip.pressed.emit()
	await get_tree().process_frame

	assert_int(ctl.phase_manager.current_phase).override_failure_message(
		"Special Assignments did not advance through its own Skip control"
	).is_equal(PhaseManagerScript.Phase.MISSION)


# --- Mission: entered through the battle return --------------------------------

func test_returning_from_battle_lands_on_post_battle() -> void:
	var gsm := _gsm()
	assert_object(gsm).is_not_null()
	gsm.set_temp_data(RESULT_KEY, BATTLE_RESULT.duplicate(true))

	var ctl: Control = await _build_controller()
	_assert_on_our_campaign(ctl)

	assert_int(ctl.phase_manager.current_phase).override_failure_message(
		"a stored battle result must route the rebuilt controller to Post-Battle"
	).is_equal(PhaseManagerScript.Phase.POST_BATTLE)
	# The controller clears the result so a later rebuild cannot replay the battle.
	assert_that(gsm.get_temp_data(RESULT_KEY)).is_null()


func test_the_battle_return_completes_the_mission_phase() -> void:
	## Landing on POST_BATTLE is true whether the return COMPLETES the Mission phase
	## or merely navigates past it, so the case above cannot tell the two apart. This
	## one asserts where the damage lands.
	##
	## Completing MISSION is what runs BugHuntPhaseManager._apply_phase_results(MISSION),
	## the ONLY consumer of the battle result: it parks the normalizer's casualty_ids in
	## _pending_casualty_ids for the p.202 Step 1 roll. Navigate past it and the battle's
	## casualties are dropped on the floor -- silently, because .get() on a missing key
	## is a default, never a fault.
	var gsm := _gsm()
	assert_object(gsm).is_not_null()

	var mains: Array = _core.main_characters
	assert_int(mains.size()).override_failure_message(
		"fixture premise: the probe squad must have main characters to lose"
	).is_greater(0)
	var downed_id: String = str(mains[0].get("id", mains[0].get("character_id", "")))
	assert_str(downed_id).override_failure_message(
		"fixture premise: the first main character must carry an id"
	).is_not_empty()

	## TacticalBattleUI's own vocabulary, so the normalizer has to DERIVE the ids
	## rather than read a key a test handed it.
	gsm.set_temp_data(RESULT_KEY, {
		"victory": true, "rounds": 4,
		"crew_casualties_data": [{"id": downed_id, "name": "Alpha"}],
	})

	var ctl: Control = await _build_controller()
	_assert_on_our_campaign(ctl)

	assert_bool(ctl.phase_manager.is_phase_complete(PhaseManagerScript.Phase.MISSION)
	).override_failure_message(
		"the battle return must COMPLETE the Mission phase, not jump over it: " +
		"_phase_complete[MISSION] is false, so phase_completed never fired, the " +
		"journal never logged the mission, and the battle result reached no consumer"
	).is_true()

	assert_array(ctl.phase_manager._pending_casualty_ids).override_failure_message(
		"the battle's casualties must reach the phase manager for the p.202 Step 1 " +
		"roll; they were dropped between the battle screen and the post-battle step"
	).contains([downed_id])

# --- Post-Battle: the panel owns its completion control --------------------------

func test_post_battle_panel_completes_through_its_own_controls() -> void:
	var panel: Control = auto_free(PostBattlePanelScript.new())
	add_child(panel)
	panel.set_campaign(_core)
	panel.set_battle_results(BATTLE_RESULT.duplicate(true))
	panel.refresh()
	await get_tree().process_frame

	var emitted: Array = []
	panel.phase_completed.connect(func(data: Dictionary): emitted.append(data))

	var process := _find_button(panel, "Process Post-Battle")
	assert_object(process).is_not_null()
	process.pressed.emit()
	await get_tree().process_frame

	# The Complete control only exists once processing has run.
	var complete := _find_button(panel, "Complete Post-Battle")
	assert_object(complete).override_failure_message(
		"Process Post-Battle must reveal the panel's own Complete control").is_not_null()
	complete.pressed.emit()

	assert_int(emitted.size()).override_failure_message(
		"Complete Post-Battle must emit phase_completed exactly once").is_equal(1)
	# gdUnit4 assertions do not abort the case, so without this guard a missing emit
	# would also fail the payload check (or index out of bounds) and read as two faults.
	if emitted.size() == 1:
		var payload: Dictionary = emitted[0]
		assert_bool(payload.has("post_battle_result")).override_failure_message(
			"the Post-Battle payload must carry post_battle_result for the phase manager"
		).is_true()


# --- Turn end: a finished turn must give way to the next one ---------------------

func test_start_next_turn_begins_the_next_turn() -> void:
	var ctl: Control = await _complete_turn_one()
	if ctl == null:
		return

	_find_button(ctl, "Start Next Turn").pressed.emit()
	await get_tree().process_frame

	var turn: int = _core.campaign_turn
	assert_int(turn).override_failure_message(
		"Start Next Turn did not start turn two: campaign_turn is still %d" % turn
	).is_equal(2)
	assert_int(ctl.phase_manager.current_phase).override_failure_message(
		"Start Next Turn must open the next turn on Special Assignments"
	).is_equal(PhaseManagerScript.Phase.SPECIAL_ASSIGNMENTS)


func test_start_next_turn_does_not_apply_the_finished_turn_again() -> void:
	var xp_at_start := _sum_character_field("xp")
	var reputation_at_start: int = _core.reputation
	var progress_at_start: int = _core.operational_progress_modifier

	# p.205's +-5 rows are what make a second application observable, and an
	# unforced D100 cannot reach one reliably: four of the ten rows carry no
	# modifier and two more are conditional on last mission's Objectives. Row
	# 81-90 "Break through" is the unconditional +5, so the roll is forced to 85.
	# It is queued TWICE on purpose. The queue is FIFO per key, so the finished
	# turn consumes the first and a turn wrongly re-applied consumes the second
	# and lands on +10. Queuing a DIFFERENT second value would let the defect
	# through whenever that second row's modifier happened to be 0.
	var dice := _dice()
	assert_object(dice).override_failure_message(
		"premise: the DiceManager autoload must be present to force the roll"
	).is_not_null()
	if dice == null:
		return
	assert_bool(dice.queue_forced_result(OP_PROGRESS_KEY, 85)).override_failure_message(
		"premise: queue_forced_result is debug-build only and it refused the value, " +
		"so the roll below is random and this case cannot discriminate"
	).is_true()
	dice.queue_forced_result(OP_PROGRESS_KEY, 85)

	# Military Life is a SECOND rule writing the same counter this case asserts on.
	# Forced to the neutral row and queued twice for the same FIFO reason, so the
	# Reputation assertion below can only move if the p.203 step itself re-ran.
	dice.queue_forced_result(MILITARY_LIFE_KEY, MILITARY_LIFE_NEUTRAL)
	dice.queue_forced_result(MILITARY_LIFE_KEY, MILITARY_LIFE_NEUTRAL)

	var ctl: Control = await _complete_turn_one(OBJECTIVES_RESULT)
	if ctl == null:
		return
	var xp := _sum_character_field("xp")
	var reputation: int = _core.reputation
	# Without an award there is nothing to repeat, and "unchanged" would pass vacuously.
	assert_int(xp).override_failure_message(
		"premise: completing Post-Battle must award XP").is_greater(xp_at_start)
	assert_int(reputation).override_failure_message(
		"premise: two objectives must award Reputation").is_greater(reputation_at_start)
	var tally := _sum_character_field("completed_missions_count")
	var progress: int = _core.operational_progress_modifier
	assert_int(progress).override_failure_message(
		"premise: the forced 85 must land on p.205's unconditional +5 row and write " +
		"the modifier; with it unchanged, the assertion below passes vacuously"
	).is_equal(progress_at_start + 5)

	_find_button(ctl, "Start Next Turn").pressed.emit()
	await get_tree().process_frame

	# Sick Bay is not asserted: ticking it at the start of a turn is legitimate.
	assert_int(_sum_character_field("xp")).override_failure_message(
		"Start Next Turn awarded the finished turn's XP again").is_equal(xp)
	assert_int(_sum_character_field("completed_missions_count")).override_failure_message(
		"Start Next Turn counted the finished mission again").is_equal(tally)
	assert_int(_core.reputation).override_failure_message(
		"Start Next Turn applied the finished turn's Reputation change again").is_equal(reputation)
	# Discriminating since Phase 5: the resolver writes op_modifier from the row's
	# `modifier` key and the roll above is forced into the unconditional +5 row, so a
	# re-applied turn consumes the second queued 85 and lands on +10.
	assert_int(_core.operational_progress_modifier).override_failure_message(
		"Start Next Turn applied the finished turn's Operational Progress again").is_equal(progress)


func test_reopening_a_finished_turn_does_not_replay_it() -> void:
	var ctl: Control = await _complete_turn_one()
	if ctl == null:
		return

	# Reopen from the save the finished turn wrote, as Continue would.
	var loaded: Resource = CoreScript.load_from_file(PROBE_SAVE)
	assert_object(loaded).override_failure_message(
		"premise: ending the turn must write the campaign save").is_not_null()
	if loaded == null:
		return
	assert_int(loaded.campaign_turn).override_failure_message(
		"premise: the save must record turn one").is_equal(1)
	ctl.queue_free()
	await get_tree().process_frame

	_gs().current_campaign = loaded
	var reopened: Control = await _build_controller()
	assert_object(reopened.campaign).override_failure_message(
		"premise: the rebuilt controller must open the reloaded campaign").is_same(loaded)
	var pm: Node = reopened.phase_manager
	assert_object(pm).is_not_null()
	if pm == null:
		return

	var replaying: bool = pm.turn_number == 1 \
			and pm.current_phase == PhaseManagerScript.Phase.SPECIAL_ASSIGNMENTS
	var message := ("reopening the finished turn put it back on Special Assignments"
			+ " (turn %d, phase %d)") % [pm.turn_number, pm.current_phase]
	assert_bool(replaying).override_failure_message(message).is_false()


# --- Mid-turn save: the phase must survive a reload -------------------------------

func test_every_phase_transition_writes_the_phase_to_the_campaign() -> void:
	## The PRODUCER half, asserted on the live core. BugHuntPhaseManager._persist_phase()
	## is called from _go_to_phase(), i.e. on every transition and not only at turn end,
	## because a Save taken mid-turn otherwise stores a stale phase. Nothing else in the
	## app writes this field while a turn is running, so this case has exactly one cause.
	var ctl: Control = await _build_controller()
	_assert_on_our_campaign(ctl)

	var skip := _find_button(ctl.panels[0], "Skip Assignments")
	assert_object(skip).is_not_null()
	if skip == null:
		return
	skip.pressed.emit()
	await get_tree().process_frame
	assert_int(ctl.phase_manager.current_phase).override_failure_message(
		"premise: Skip must reach the Mission phase"
	).is_equal(PhaseManagerScript.Phase.MISSION)

	var stored: int = _core.current_turn_phase
	# One assertion, and the message names WHICH of the two causes it is: an untouched
	# field means no transition writes it at all, any other value means it is stale.
	assert_int(stored).override_failure_message(
		"the campaign's stored phase is %d after the turn reached Mission -- %s" % [
			stored,
			("no transition writes it at all" if stored == CoreScript.PHASE_UNRECORDED
				else "it is stale from an earlier transition")]
	).is_equal(PhaseManagerScript.Phase.MISSION)


func test_saving_mid_turn_reopens_that_phase_instead_of_replaying_the_turn() -> void:
	## The CONSUMER half, through the Save button a player presses. Case 6 covers the
	## turn-END phase, which _complete_turn() writes directly; this is the only case
	## that exercises a save taken while a turn is still running.
	var ctl: Control = await _build_controller()
	_assert_on_our_campaign(ctl)

	var skip := _find_button(ctl.panels[0], "Skip Assignments")
	assert_object(skip).is_not_null()
	if skip == null:
		return
	skip.pressed.emit()
	await get_tree().process_frame
	assert_int(ctl.phase_manager.current_phase).override_failure_message(
		"premise: the save must be taken mid-turn, at Mission"
	).is_equal(PhaseManagerScript.Phase.MISSION)

	var save := _find_button(ctl, "Save")
	assert_object(save).override_failure_message(
		"premise: the turn screen must offer a Save control").is_not_null()
	if save == null:
		return
	save.pressed.emit()
	await get_tree().process_frame

	var loaded: Resource = CoreScript.load_from_file(PROBE_SAVE)
	assert_object(loaded).override_failure_message(
		"premise: pressing Save must write the campaign save").is_not_null()
	if loaded == null:
		return
	ctl.queue_free()
	await get_tree().process_frame

	_gs().current_campaign = loaded
	var reopened: Control = await _build_controller()
	assert_object(reopened.campaign).override_failure_message(
		"premise: the rebuilt controller must open the reloaded campaign").is_same(loaded)
	var pm: Node = reopened.phase_manager
	assert_object(pm).is_not_null()
	if pm == null:
		return

	assert_int(pm.current_phase).override_failure_message(
		("a campaign saved during the Mission phase reopened at phase %d, so the rest "
			+ "of the turn is skipped and Special Assignments is replayed")
		% pm.current_phase
	).is_equal(PhaseManagerScript.Phase.MISSION)
	# campaign_turn increments at turn START, so the stored number already identifies
	# the turn in progress. Reopening must not add to it (the T11-20 "+1" is a 5PFH
	# rule about COMPLETED turns and does not transfer).
	assert_int(pm.turn_number).override_failure_message(
		"reopening mid-turn advanced the turn to %d" % pm.turn_number).is_equal(1)


# --- The loop closes: a second turn plays through as well -------------------------

func test_the_second_turn_also_plays_to_its_end() -> void:
	## Case 4 proves turn two OPENS. This proves it CLOSES -- and measurement makes it
	## the ONLY case in the suite that detects a lost turn-END persist.
	##
	## Dropping _persist_phase() from _complete_turn() leaves case 6 GREEN and fails
	## this one. Case 6 asserts a NEGATIVE -- "not back at Special Assignments" -- which
	## a wrong-but-different phase still satisfies (POST_BATTLE survives in the save and
	## resumes there), while this case asserts the positive, current_turn_phase == NONE.
	## Dropping the OTHER _persist_phase() call site, in _go_to_phase(), leaves this case
	## green and fails cases 7 and 8, so the two call sites are pinned separately.
	##
	## The panel's own _completed reset is NOT what this case exercises: the battle
	## return frees and rebuilds the controller, so turn two's post-battle panel is a
	## fresh instance either way. The manager's _reset_phase_completion() is likewise
	## discarded at that rebuild. Both are covered elsewhere, not here.
	var first: Control = await _complete_turn_one()
	if first == null:
		return
	var tally_after_one := _counts_by_id("completed_missions_count")

	_find_button(first, "Start Next Turn").pressed.emit()
	await get_tree().process_frame
	assert_int(first.phase_manager.current_phase).override_failure_message(
		"premise: turn two must open on Special Assignments"
	).is_equal(PhaseManagerScript.Phase.SPECIAL_ASSIGNMENTS)

	var second: Control = await _finish_turn_from(first, 2, BATTLE_RESULT)
	assert_object(second).override_failure_message(
		"turn two did not play through to its end").is_not_null()
	if second == null:
		return

	assert_int(_core.current_turn_phase).override_failure_message(
		"turn two ended but the campaign still records phase %d, so reopening the save "
		% _core.current_turn_phase + "would drop the player back into it"
	).is_equal(PhaseManagerScript.Phase.NONE)
	# The buttons being clickable is not evidence the turn RAN. The tally rising a
	# second time is: it is written by the post-battle step, once per mission.
	#
	# Compared PER CHARACTER, never summed over the roster. Turn two's own post-battle
	# can remove a character -- this case reports no objectives, so the p.201 Court
	# Martial is rolled and a 1 removes the leader -- and a roster sum then falls by
	# that character's whole count while every survivor rose by one. Summed, this case
	# failed about one run in five with the step working: measured 2026-10-27,
	# Alpha/Bravo/Charlie 2/2/1 -> Bravo/Charlie 3/2, sum 5 -> 5.
	var tally_after_two := _counts_by_id("completed_missions_count")
	var rose: Array = []
	for cid: String in tally_after_one:
		if tally_after_two.has(cid) and int(tally_after_two[cid]) > int(tally_after_one[cid]):
			rose.append(cid)
	assert_array(rose).override_failure_message(
		"turn two completed without counting its mission, so its post-battle step "
		+ "did not apply (no character present after both turns gained a mission: "
		+ "%s -> %s)" % [tally_after_one, tally_after_two]).is_not_empty()
