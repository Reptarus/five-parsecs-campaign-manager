extends GdUnitTestSuite
## The wizard's Next button must reflect the CURRENT state of a step.
##
## Two gates run in series and neither one worked:
##
##   1. The coordinator's completion map was MONOTONIC — `if is_complete: status
##      = true` with no else, and nothing anywhere ever wrote false. Satisfy the
##      crew step, advance, come back, delete a member, and Next stayed enabled
##      on the strength of a stale flag.
##
##   2. advance_to_next_phase() consults only the warnings-shaped validator,
##      which never set blocks_progression for the crew phase at all. The strict
##      _validate_crew_phase() — where the over-size check lives — is not on the
##      advance path, so that check could not block anything.

const StateManagerScript = preload(
	"res://src/core/campaign/creation/CampaignCreationStateManager.gd")

func _manager():
	return StateManagerScript.new()

func _crew(members: int, size: int) -> Dictionary:
	var list: Array = []
	for i in range(members):
		list.append({"character_name": "Crew %d" % i, "character_id": "c%d" % i})
	return {"members": list, "size": size, "has_captain": true}

# ── The over-size block, on the path the Next button actually takes ──────

func test_an_over_size_roster_blocks_progression() -> void:
	var m = _manager()
	m.set_phase_data(StateManagerScript.Phase.CREW_SETUP, _crew(8, 6))
	var result: Dictionary = m._validate_phase_with_warnings(
		StateManagerScript.Phase.CREW_SETUP)
	assert_bool(result.get("blocks_progression", false)).override_failure_message(
		"an 8-member roster for a crew of 6 must block the advance path, not just warn"
	).is_true()
	assert_array(result.get("blocking_errors", [])).is_not_empty()

func test_a_legal_roster_does_not_block() -> void:
	var m = _manager()
	m.set_phase_data(StateManagerScript.Phase.CREW_SETUP, _crew(6, 6))
	var result: Dictionary = m._validate_phase_with_warnings(
		StateManagerScript.Phase.CREW_SETUP)
	assert_bool(result.get("blocks_progression", false)).override_failure_message(
		"a crew that is exactly the chosen size must be allowed through"
	).is_false()

func test_an_incomplete_roster_warns_rather_than_blocks() -> void:
	# Under-size is an unfinished step, not a rules violation — the player is
	# still building. Only OVER size is illegal (Core Rules p.65).
	var m = _manager()
	m.set_phase_data(StateManagerScript.Phase.CREW_SETUP, _crew(2, 6))
	var result: Dictionary = m._validate_phase_with_warnings(
		StateManagerScript.Phase.CREW_SETUP)
	assert_bool(result.get("blocks_progression", false)).override_failure_message(
		"a half-built crew must not hard-block navigation"
	).is_false()

func test_the_advance_call_itself_refuses_an_over_size_crew() -> void:
	# End of the chain: advance_to_next_phase() is what the Next button reaches.
	var m = _manager()
	m.current_phase = StateManagerScript.Phase.CREW_SETUP
	m.set_phase_data(StateManagerScript.Phase.CREW_SETUP, _crew(9, 4))
	assert_bool(m.advance_to_next_phase()).override_failure_message(
		"advance_to_next_phase() let an over-size crew through"
	).is_false()
	assert_int(int(m.current_phase)).is_equal(int(StateManagerScript.Phase.CREW_SETUP))

# ── The validation summary reports the key its consumers read ────────────

func test_validation_summary_publishes_has_critical_errors() -> void:
	# Two consumers read this key and nothing ever wrote it, so both silently
	# took the false default. It must at least EXIST so the contract is checkable.
	var m = _manager()
	var summary: Dictionary = m.get_validation_summary()
	assert_bool(summary.has("has_critical_errors")).override_failure_message(
		"get_validation_summary() must publish has_critical_errors — two callers read it"
	).is_true()
	assert_bool(summary.has("validation_errors")).is_true()

func test_the_removed_business_logic_method_still_does_not_exist() -> void:
	# The guard that called this was permanently false. If someone later adds the
	# method, the layer that used to call it is gone and needs re-wiring — this
	# is here so that gets noticed rather than silently doing nothing again.
	var m = _manager()
	assert_bool(m.has_method("validate_complete_state")).override_failure_message(
		"validate_complete_state() now exists; re-wire the finalization business-logic layer that was removed because it did not"
	).is_false()
