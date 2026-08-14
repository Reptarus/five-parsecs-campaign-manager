extends GdUnitTestSuite
## T9-50 (tablet, Aug 13 2026) — resuming a World Phase checkpoint lost the
## accepted job.
##
## A save resumed at "Step 6 of 6: Mission Prep" rendered:
##     Objective: Unknown / Enemy: Unknown / Danger Level: 0
##     Location: Unknown / Pay: 0 credits
## while `progress.world_phase_results.mission_data` in that same save still held
## the whole job — patron "Regional Contractor", job_type "Move Through", enemy
## "Gun Slingers", pay 6. Walking the identical save cleanly from Step 1 rendered
## the real briefing, which is what proved the data was never lost: only the live
## component's copy of it was.
##
## CAUSE: `_refresh_mission_prep()` reads the mission from
## `job_offer_component.get_accepted_job()` and nowhere else, and that is pure
## in-memory state. `WorldPhaseController.save_checkpoint()` builds its
## `_checkpoint_data` from a FIXED KEY LITERAL — current_step / step_completed /
## world_phase_data / automation_enabled / turn_number / timestamp — which never
## named the job. So the resume rebuilt JobOfferComponent empty.
##
## ⚠ The tempting fix is wrong: falling back to
## `world_phase_results.mission_data` would show TURN 2's job on a turn-3 resume,
## because that key is written at phase COMPLETION. A stale mission presented as
## the current one is worse than a blank one. The job has to be in the checkpoint.
##
## gdUnit4 v6.0.3. NOTE: run with -c, never --headless (project rule).

const JobOfferComponentScript = preload(
	"res://src/ui/screens/world/components/JobOfferComponent.gd")

const WorldPhaseControllerScript = preload(
	"res://src/ui/screens/world/WorldPhaseController.gd")

const WPC_PATH := "res://src/ui/screens/world/WorldPhaseController.gd"


## The shape CampaignTurnController and MissionPrepComponent actually consume.
func _job() -> Dictionary:
	return {
		"id": "job_0_95973",
		"job_type": "Move Through",
		"objective": "Move Through",
		"patron": "Regional Contractor",
		"patron_name": "Regional Contractor",
		"enemy_type": "Gun Slingers",
		"danger_level": 1.0,
		"danger_pay": 6.0,
		"pay": 6.0,
		"location": "Unknown Location",
		"mission_source": "opportunity",
	}


func _component() -> Node:
	var c: Node = auto_free(JobOfferComponentScript.new())
	add_child(c)
	return c


# ── the pair round-trips ─────────────────────────────────────────────────────

func test_the_accepted_job_survives_a_serialize_restore_round_trip() -> void:
	var source: Node = _component()
	source.available_jobs = [_job()] as Array[Dictionary]
	source.selected_job_index = 0
	source.job_accepted = true
	var saved: Dictionary = source.get_step_results()

	# A fresh component is exactly what a resumed checkpoint builds.
	var resumed: Node = _component()
	assert_dict(resumed.get_accepted_job()).override_failure_message(
		"a fresh component must start with no job — otherwise this test proves "
		+ "nothing").is_empty()

	resumed.restore_step_results(saved)
	var job: Dictionary = resumed.get_accepted_job()
	assert_dict(job).override_failure_message(
		"_refresh_mission_prep() reads the mission from get_accepted_job() and "
		+ "nowhere else; empty here is the blank briefing seen on device"
		).is_not_empty()
	assert_str(str(job.get("patron_name", ""))).is_equal("Regional Contractor")
	assert_str(str(job.get("enemy_type", ""))).is_equal("Gun Slingers")
	assert_int(int(job.get("pay", 0))).is_equal(6)


func test_a_checkpoint_taken_before_any_job_was_accepted_restores_none() -> void:
	var source: Node = _component()
	source.available_jobs = [_job()] as Array[Dictionary]
	source.selected_job_index = -1
	source.job_accepted = false
	var resumed: Node = _component()
	resumed.restore_step_results(source.get_step_results())
	assert_dict(resumed.get_accepted_job()).override_failure_message(
		"restoring must not invent an acceptance the player never made").is_empty()


func test_an_out_of_range_index_cannot_resurrect_a_job() -> void:
	# Defensive: a hand-edited or truncated checkpoint must not index past the end.
	var resumed: Node = _component()
	resumed.restore_step_results({
		"job_accepted": true, "selected_job_index": 4, "available_jobs": [],
	})
	assert_dict(resumed.get_accepted_job()).is_empty()
	assert_bool(resumed.job_accepted).is_false()


func test_an_empty_checkpoint_is_harmless() -> void:
	# Pre-fix saves carry no "job_offers" key at all and restore to {} — the same
	# behaviour they have today, so an old save is no worse off.
	var resumed: Node = _component()
	resumed.restore_step_results({})
	assert_dict(resumed.get_accepted_job()).is_empty()


# ── and the controller actually saves + restores it ──────────────────────────
#
# The pair above can round-trip perfectly while the checkpoint still omits the
# job — which is precisely the bug. These anchor both ends on the real file.

func test_the_checkpoint_literal_names_the_job_offers_bundle() -> void:
	var src: String = FileAccess.get_file_as_string(WPC_PATH)
	assert_bool(src.contains("\"job_offers\": job_offers_state")).override_failure_message(
		"save_checkpoint() builds _checkpoint_data from a fixed key literal; a key "
		+ "it does not name is not in the checkpoint at all").is_true()
	assert_bool(src.contains("get_step_results()")).override_failure_message(
		"use the component's own serialization rather than re-listing its fields "
		+ "here, or this literal drifts again").is_true()


func test_the_restore_path_feeds_the_job_back() -> void:
	var src: String = FileAccess.get_file_as_string(WPC_PATH)
	assert_bool(src.contains("restore_step_results(")).override_failure_message(
		"saving the job without restoring it leaves the briefing just as blank"
		).is_true()
	assert_bool(src.contains("_restore_job_offers_from_checkpoint()")).override_failure_message(
		"the restore must be invoked from the checkpoint branch of "
		+ "_setup_initial_state()").is_true()


## ⚠ ORDER IS THE WHOLE FIX, and getting it wrong looks EXACTLY like having no
## fix. Measured on the tablet Aug 13 2026: the accepted job was verifiably in the
## checkpoint on disk (`job_offers.accepted_job.patron_name == "Reputable
## Contractor"`) and the resumed briefing still read "Objective: Unknown / Pay: 0".
##
## Cause: the restore originally sat inside `restore_from_checkpoint()`, which the
## caller invokes BEFORE `_fetch_campaign_data()` — and that reaches
## `_initialize_components_with_data()` ->
## `job_offer_component.initialize_job_offers(world_phase_data)`, rebuilding the
## component and discarding what had just been restored two lines earlier.
##
## So this asserts the ORDER, not merely the presence of the call.
func test_the_job_is_restored_after_the_component_is_re_initialised() -> void:
	var src: String = FileAccess.get_file_as_string(WPC_PATH)
	var branch_at: int = src.find("if has_checkpoint():")
	assert_int(branch_at).is_greater(-1)
	var branch: String = src.substr(branch_at, 1200)

	var fetch_at: int = branch.find("_fetch_campaign_data()")
	var restore_at: int = branch.find("_restore_job_offers_from_checkpoint()")
	var show_at: int = branch.find("_show_current_step()")

	assert_int(fetch_at).override_failure_message(
		"expected _fetch_campaign_data() in the checkpoint branch").is_greater(-1)
	assert_int(restore_at).override_failure_message(
		"expected the job restore in the checkpoint branch").is_greater(-1)
	assert_int(show_at).override_failure_message(
		"expected _show_current_step() in the checkpoint branch").is_greater(-1)

	assert_int(fetch_at).override_failure_message(
		"_fetch_campaign_data() rebuilds JobOfferComponent via "
		+ "initialize_job_offers(); restoring the job BEFORE it is silently "
		+ "undone, and the briefing is blank exactly as if nothing was saved"
		).is_less(restore_at)
	assert_int(restore_at).override_failure_message(
		"_show_current_step() -> _refresh_mission_prep() -> get_accepted_job() "
		+ "reads the job, so the restore must already have happened").is_less(
		show_at)


# ── there are TWO producers, and ordering only cleared the first ─────────────
#
# ⚠ The ordering fix above shipped, was verified on disk, and STILL FAILED on the
# tablet Aug 14 2026. `_show_current_step()` calls `_refresh_job_offers()` on every
# arrival at JOB_OFFERS (WorldPhaseController:1177), which is a SECOND caller of
# `initialize_job_offers()` and runs AFTER the restore. The resume re-rolled the
# accepted "Reputable Contractor / Protect / Isolationists / 7cr" into two
# unrelated offers and cleared the step's checkmark.
#
# These are BEHAVIOURAL on purpose. The previous anchor for this bug asserted that
# a call was PRESENT in the source, which stayed green while the feature was
# broken. Assert the outcome the player sees.

func test_re_initialising_clears_the_acceptance() -> void:
	## The hazard the guard exists for. If this ever goes green-by-idempotence,
	## the guard's premise changed and it can be revisited.
	var comp: Node = _component()
	comp.available_jobs = [_job()] as Array[Dictionary]
	comp.selected_job_index = 0
	comp.job_accepted = true
	assert_dict(comp.get_accepted_job()).is_not_empty()

	comp.initialize_job_offers({"patrons": [], "location": "Joffre VI"})

	assert_bool(comp.job_accepted).override_failure_message(
		"initialize_job_offers() sets job_accepted = false unconditionally "
		+ "(JobOfferComponent.gd:200) — that is exactly why re-running it on a "
		+ "step the player already completed destroys their choice").is_false()


func test_an_accepted_job_survives_arriving_at_the_step_again() -> void:
	## Drives the real controller method. Without the guard, _refresh_job_offers()
	## reaches initialize_job_offers() and the acceptance is gone.
	##
	## The controller MUST be in the tree: _refresh_job_offers() resolves
	## "/root/GameState" by absolute path, which on a detached node ERRORS and
	## aborts the whole function — the job would then survive for the wrong reason
	## and this test would pass with the guard removed.
	var controller: Node = auto_free(WorldPhaseControllerScript.new())
	add_child(controller)
	assert_bool(controller.is_inside_tree()).override_failure_message(
		"detached, the absolute-path lookup aborts the function and this test "
		+ "cannot detect the bug").is_true()

	var comp: Node = _component()
	comp.available_jobs = [_job()] as Array[Dictionary]
	comp.selected_job_index = 0
	comp.job_accepted = true

	controller.job_offer_component = comp
	controller.world_phase_data = {"patrons": [], "location": "Joffre VI"}

	controller._refresh_job_offers()

	var job: Dictionary = comp.get_accepted_job()
	assert_dict(job).override_failure_message(
		"arriving at JOB_OFFERS again re-rolled the board and discarded the "
		+ "accepted job — measured on device as two unrelated offers replacing "
		+ "the one the player took").is_not_empty()
	assert_str(str(job.get("patron_name", ""))).is_equal("Regional Contractor")


func test_the_step_still_initialises_when_nothing_is_accepted_yet() -> void:
	## The guard must not break the legitimate case: first arrival at JOB_OFFERS,
	## where crew tasks may have turned up new patrons and the board SHOULD build.
	var controller: Node = auto_free(WorldPhaseControllerScript.new())
	add_child(controller)

	var comp: Node = _component()
	comp.available_jobs = [] as Array[Dictionary]
	# A value initialize_job_offers() overwrites (:201), so seeing -1 afterwards
	# proves the body actually ran rather than being skipped by the guard.
	comp.selected_job_index = 99
	comp.job_accepted = false

	controller.job_offer_component = comp
	controller.world_phase_data = {"patrons": [], "location": "Joffre VI"}

	controller._refresh_job_offers()

	assert_int(comp.selected_job_index).override_failure_message(
		"guarding too broadly would skip initialisation on first arrival and "
		+ "leave the player with no board at all").is_equal(-1)


# ── the THIRD producer: the orchestrator entry point ─────────────────────────
#
# ⚠ TWO fixes ordered the restore against callers of initialize_job_offers() and
# BOTH still failed on device. `initialize_world_phase()` is the orchestrator entry
# point, CampaignTurnController calls it AFTER _ready() has already restored, and it
# runs `_initialize_components_with_data()` unconditionally (:961) — which both
# clears job_accepted AND re-inits MissionPrep with world_phase_data["mission"],
# a key that does not exist. Its `if not has_checkpoint()` guard then skips
# _show_current_step(), so nothing re-renders and the blank briefing sticks.
#
# MEASURED Aug 14 2026: checkpoint held "Reputable Contractor" / Protect /
# Isolationists / 7cr; resume rendered "Objective: Unknown / Pay: 0". Corroborated
# by the world's Current Event changing across the resume, which only
# _generate_turn_world_event() does and only this function calls.

func _valid_checkpoint(turn: int) -> Dictionary:
	## Non-empty and not stale: has_checkpoint() must return TRUE for this test to
	## exercise the branch at all. Two ways to fail that, both silent:
	##   - `turn_number` differing from _current_campaign_turn() is STALE, and
	##     has_checkpoint() then ERASES _checkpoint_data as a side effect. Take the
	##     turn from the controller at runtime rather than hardcoding one.
	##   - `step_completed` with every value true describes a FINISHED phase, also
	##     stale. Keep at least one false.
	return {
		"current_step": 5,
		"step_completed": {"0": false, "4": true},
		"world_phase_data": {"location": "Joffre VI"},
		"automation_enabled": false,
		"turn_number": turn,
		"job_offers": {
			"job_accepted": true,
			"accepted_job": _job(),
			"available_jobs": [_job()],
			"selected_job_index": 0,
		},
	}


func test_the_orchestrator_entry_point_does_not_destroy_a_restored_job() -> void:
	var controller: Node = auto_free(WorldPhaseControllerScript.new())
	add_child(controller)

	var comp: Node = _component()
	comp.available_jobs = [_job()] as Array[Dictionary]
	comp.selected_job_index = 0
	comp.job_accepted = true

	controller.job_offer_component = comp
	controller._checkpoint_data = _valid_checkpoint(
		controller._current_campaign_turn())
	controller.world_phase_data = {"location": "Joffre VI"}

	assert_bool(controller.has_checkpoint()).override_failure_message(
		"the fixture must be a LIVE checkpoint, or this test never reaches the "
		+ "branch it is meant to cover").is_true()

	controller.initialize_world_phase({}, [], {})

	var job: Dictionary = comp.get_accepted_job()
	assert_dict(job).override_failure_message(
		"initialize_world_phase() re-ran _initialize_components_with_data() over a "
		+ "restored checkpoint and threw the accepted job away — this is the actual "
		+ "T9-50 defect, not the two producers fixed before it").is_not_empty()
	assert_str(str(job.get("enemy_type", ""))).is_equal("Gun Slingers")


func test_a_fresh_turn_entry_still_resets(  # no checkpoint = the other branch
	) -> void:
	## The new early-return must not swallow the reset path that clears last turn's
	## component state on an in-place turn advance.
	var controller: Node = auto_free(WorldPhaseControllerScript.new())
	add_child(controller)

	var comp: Node = _component()
	comp.available_jobs = [_job()] as Array[Dictionary]
	comp.selected_job_index = 0
	comp.job_accepted = true

	controller.job_offer_component = comp
	controller._checkpoint_data = {}          # no checkpoint -> fresh turn entry
	controller.world_phase_data = {"location": "Joffre VI"}

	assert_bool(controller.has_checkpoint()).is_false()

	controller.initialize_world_phase({}, [], {})

	assert_bool(comp.job_accepted).override_failure_message(
		"a fresh turn entry must clear last turn's acceptance via reset_world_phase()"
		).is_false()
