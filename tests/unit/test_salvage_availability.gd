extends GdUnitTestSuite

## Compendium p.137 salvage-availability D6 (Salvage Jobs, pp.137-147).
##
## THE BUG THESE PIN (Aug 6 battle-phase audit): the table was rolled ONLY by
## SalvageJobGenerator.find_salvage_job(), which had ZERO callers repo-wide. The
## live producer — generate_salvage_job(), called from
## JobOfferComponent._generate_compendium_missions — never rolled it, so three
## separate rules were inert:
##   roll 1   "No job available this campaign turn."  → a salvage job was offered
##            EVERY campaign turn instead of five turns in six
##   roll 2-3 "requires 2 Credit non-refundable fee to accept" → never charged
##   roll 6   the illegal job → `is_illegal` had NO producer anywhere in src/, so
##            SalvageMissionPanel's illegal branch and the "authorities on your
##            trail" consequence were unreachable
##
## Assertions are INVARIANTS over many rolls, never "roll N times and expect a 6".
## A seed fixes the RNG stream, not the value.

const SalvageJobGenerator = preload("res://src/core/mission/SalvageJobGenerator.gd")
const CompendiumSalvageJobs = preload("res://src/data/compendium_salvage_jobs.gd")

const ROLL_SAMPLES := 300

var _dlc: Node = null
var _restore_enabled: bool = false


func before_test() -> void:
	_dlc = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")
	if _dlc == null:
		return
	# The generator self-gates on SALVAGE_JOBS. The gate is TWO-level (owned AND
	# toggled) and _enabled_flags defaults false, so "owned" alone is not "on".
	var dlc_id: String = _dlc.get_dlc_for_feature(_dlc.ContentFlag.SALVAGE_JOBS)
	_restore_enabled = _dlc.is_feature_enabled(_dlc.ContentFlag.SALVAGE_JOBS)
	_dlc.set_dlc_owned(dlc_id, true)
	_dlc.set_feature_enabled(_dlc.ContentFlag.SALVAGE_JOBS, true)


func after_test() -> void:
	if _dlc:
		_dlc.set_feature_enabled(_dlc.ContentFlag.SALVAGE_JOBS, _restore_enabled)


func test_availability_table_carries_all_four_book_rows() -> void:
	var ids: Array = []
	for row in CompendiumSalvageJobs.SALVAGE_AVAILABILITY:
		ids.append(str(row.get("id", "")))
	assert_array(ids).contains(["no_job", "fee", "salvage_job", "illegal_job"])


func test_acceptance_fee_is_the_book_value() -> void:
	# "requires 2 Credit non-refundable fee to accept" — Compendium p.137.
	assert_int(SalvageJobGenerator.SALVAGE_ACCEPTANCE_FEE).is_equal(2)


func test_generated_job_always_carries_the_availability_outcome() -> void:
	## Every non-empty job must report which row it came from and both of that
	## row's consequences. A job dict missing these keys is the original bug.
	var seen_any: bool = false
	for i in range(ROLL_SAMPLES):
		var job: Dictionary = SalvageJobGenerator.generate_salvage_job(5)
		if job.is_empty():
			continue  # roll of 1 — "no job available", a legitimate outcome
		seen_any = true
		assert_bool(job.has("availability_id")).is_true()
		assert_bool(job.has("is_illegal")).is_true()
		assert_bool(job.has("acceptance_fee")).is_true()
		# A generated job is never the no_job row — that returns {} instead.
		assert_str(str(job["availability_id"])).is_not_equal("no_job")
	assert_bool(seen_any).is_true()


func test_each_row_maps_to_its_own_consequence() -> void:
	## The mapping is what makes the roll mean anything: illegal_job must set
	## is_illegal, the fee row must charge, and a plain job must do neither.
	for i in range(ROLL_SAMPLES):
		var job: Dictionary = SalvageJobGenerator.generate_salvage_job(5)
		if job.is_empty():
			continue
		var row: String = str(job.get("availability_id", ""))
		match row:
			"illegal_job":
				assert_bool(bool(job["is_illegal"])).is_true()
				assert_int(int(job["acceptance_fee"])).is_equal(0)
			"fee":
				assert_bool(bool(job["is_illegal"])).is_false()
				assert_int(int(job["acceptance_fee"])).is_equal(
					SalvageJobGenerator.SALVAGE_ACCEPTANCE_FEE)
			"salvage_job":
				assert_bool(bool(job["is_illegal"])).is_false()
				assert_int(int(job["acceptance_fee"])).is_equal(0)


func test_illegal_flag_is_a_real_bool_for_the_panel() -> void:
	## SalvageMissionPanel does mission_data.get("is_illegal", false) and passes it
	## straight into SalvageJobGenerator.generate_post_mission_text(units, bool).
	## A non-bool here would silently take the wrong branch.
	for i in range(ROLL_SAMPLES):
		var job: Dictionary = SalvageJobGenerator.generate_salvage_job(5)
		if job.is_empty():
			continue
		assert_bool(job["is_illegal"] is bool).is_true()


func test_authorities_check_uses_the_book_threshold() -> void:
	## "roll D6: 1-4 you got away with it; 5-6 authorities on trail."
	assert_int(SalvageJobGenerator.AUTHORITIES_CAUGHT_THRESHOLD).is_equal(5)


func test_authorities_check_is_internally_consistent() -> void:
	## Invariants over many rolls, never "expect a 6". caught must agree with the
	## threshold, and credits_owed must equal the roll value ("pay roll value in
	## Credits") only when actually caught.
	var saw_caught: bool = false
	var saw_clear: bool = false
	for i in range(ROLL_SAMPLES):
		var check: Dictionary = SalvageJobGenerator.roll_authorities_check(4)
		var roll: int = int(check["roll"])
		assert_bool(roll >= 1 and roll <= 6).is_true()
		var caught: bool = bool(check["caught"])
		assert_bool(caught).is_equal(
			roll >= SalvageJobGenerator.AUTHORITIES_CAUGHT_THRESHOLD)
		if caught:
			saw_caught = true
			assert_int(int(check["credits_owed"])).is_equal(roll)
		else:
			saw_clear = true
			assert_int(int(check["credits_owed"])).is_equal(0)
	# Both branches must actually occur, or the assertions above are vacuous.
	assert_bool(saw_caught).is_true()
	assert_bool(saw_clear).is_true()


func test_authorities_check_always_offers_all_three_book_options() -> void:
	## The book says "choose ONE" of exactly three. A prompt that offered fewer
	## would quietly remove a legal answer from the player.
	var check: Dictionary = SalvageJobGenerator.roll_authorities_check(3)
	var ids: Array = []
	for opt_v in check["options"]:
		var opt: Dictionary = opt_v
		ids.append(str(opt["id"]))
		# Every option needs a label, or ItemChoicePopup renders a blank button.
		assert_str(str(opt.get("label", ""))).is_not_empty()
	assert_array(ids).contains_exactly_in_any_order([
		SalvageJobGenerator.AUTHORITIES_OPTION_PAY,
		SalvageJobGenerator.AUTHORITIES_OPTION_SALVAGE,
		SalvageJobGenerator.AUTHORITIES_OPTION_RIVAL,
	])


func test_post_mission_text_states_the_authorities_roll_when_illegal() -> void:
	## The consequence text the illegal branch exists to deliver. Verified against
	## salvage_jobs.json: "roll D6: 1-4 you got away with it; 5-6 authorities on
	## trail (choose ONE: pay roll value in Credits, hand over all Salvage units,
	## or add Enforcer Rival)."
	var illegal: String = SalvageJobGenerator.generate_post_mission_text(3, true)
	var lawful: String = SalvageJobGenerator.generate_post_mission_text(3, false)
	assert_str(illegal.to_lower()).contains("d6")
	assert_str(illegal.to_lower()).contains("illegal")
	assert_str(lawful.to_lower()).not_contains("illegal")
