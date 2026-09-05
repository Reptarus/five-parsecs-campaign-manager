extends GdUnitTestSuite
## Tactics p.134 "Infantry Platoon Organization" — the army-builder composition limits.
##
## Book text, verbatim from docs/rules/tactics_source.txt (raw marker 136 -> printed 134;
## the Tactics extract offset is marker MINUS two):
##
##   "Leaders (1-2)"   — "A platoon must have one character, and may include a second."
##   "Troops (2-4)"    — "A platoon must have 2 squads, and may take a total of 4."
##   "Supports (0-3; must be fewer than number of Troops)"
##   "Specialists (0-1 per 2 Troops)"
##
## The validator previously enforced Leader 1 / Troops 2-5 / Supports 0-4 / Specialists 2,
## which are the **Armored Platoon** optional rule from p.135 applied to the wrong
## organisation. It therefore accepted illegal armies AND rejected legal ones, which is
## why both directions are asserted here rather than just the rejections.

const Validator := preload("res://src/data/tactics/TacticsCompositionValidator.gd")

var _uid := 0


func _make_roster() -> TacticsRoster:
	var r := TacticsRoster.new()
	r.org_type = TacticsRoster.OrgType.PLATOON
	r.platoon_count = 1
	r.points_limit = 500
	# validate() returns early without one; the composition rules never read it.
	r.species_book = TacticsSpeciesBook.new()
	return r


func _add(r: TacticsRoster, slot: int, count: int = 1) -> void:
	for _i in range(count):
		_uid += 1
		var p := TacticsUnitProfile.new()
		p.org_slot = slot
		# Unique ids: a platoon may not take two specialists of the SAME type, and a
		# shared id would fail that separate rule and mask the one under test.
		p.unit_id = "u%d" % _uid
		p.unit_name = "Unit %d" % _uid
		p.points_cost = 0
		var e := TacticsRosterEntry.new()
		e.base_profile = p
		e.platoon_index = 0
		r.entries.append(e)


## A legal minimum platoon, which each case then perturbs in ONE direction.
func _legal(troops: int = 2, supports: int = 0, specialists: int = 0,
		leaders: int = 1) -> TacticsRoster:
	var r := _make_roster()
	_add(r, TacticsUnitProfile.OrgSlot.LEADER, leaders)
	_add(r, TacticsUnitProfile.OrgSlot.TROOP, troops)
	_add(r, TacticsUnitProfile.OrgSlot.SUPPORT, supports)
	_add(r, TacticsUnitProfile.OrgSlot.SPECIALIST_SLOT, specialists)
	return r


func _errors(r: TacticsRoster) -> String:
	return "\n".join(Validator.validate(r))


func test_the_baseline_platoon_is_legal() -> void:
	# Guards every other case: if the minimum legal army is rejected, a "correctly
	# rejected" result below would prove nothing.
	assert_str(_errors(_legal())).is_empty()


func test_troops_are_two_to_four() -> void:
	assert_str(_errors(_legal(2))).override_failure_message(
		"2 troops is the book minimum and must pass").is_empty()
	assert_str(_errors(_legal(4))).override_failure_message(
		"4 troops is the book maximum and must pass").is_empty()
	assert_str(_errors(_legal(1))).contains("at least")
	assert_str(_errors(_legal(5))).override_failure_message(
		"5 troops is the ARMORED platoon's limit (p.135), not the infantry one"
	).contains("Max 4 troop")


func test_supports_obey_both_the_cap_and_the_fewer_than_troops_clause() -> void:
	# Neither clause implies the other, so both directions need a case.
	assert_str(_errors(_legal(4, 3))).override_failure_message(
		"4 troops with 3 supports is legal: at the cap and still fewer than troops"
	).is_empty()
	assert_str(_errors(_legal(4, 4))).override_failure_message(
		"4 supports breaks the 0-3 cap even though troops would allow it"
	).contains("Max 3 support")
	assert_str(_errors(_legal(3, 3))).override_failure_message(
		"3 supports is within the cap but equals the troop count, which the book forbids"
	).contains("fewer than")


func test_specialists_scale_with_troops_rather_than_a_flat_cap() -> void:
	assert_int(Validator.max_specialists_for(2)).is_equal(1)
	assert_int(Validator.max_specialists_for(3)).is_equal(1)
	assert_int(Validator.max_specialists_for(4)).is_equal(2)
	assert_str(_errors(_legal(2, 0, 1))).override_failure_message(
		"2 troops earn 1 specialist").is_empty()
	assert_str(_errors(_legal(2, 0, 2))).override_failure_message(
		"2 troops earn only 1 specialist — a flat cap of 2 was the old bug"
	).contains("Max 1 specialist")
	assert_str(_errors(_legal(4, 0, 2))).override_failure_message(
		"4 troops earn 2 specialists").is_empty()


func test_a_platoon_may_take_a_second_leader() -> void:
	assert_str(_errors(_legal(2, 0, 0, 1))).is_empty()
	assert_str(_errors(_legal(2, 0, 0, 2))).override_failure_message(
		"the book says a platoon 'may include a second' character; 2 leaders is legal"
	).is_empty()
	assert_str(_errors(_legal(2, 0, 0, 0))).contains("Needs a platoon leader")
	assert_str(_errors(_legal(2, 0, 0, 3))).contains("Max 2 leaders")


func test_the_printed_limits_match_the_enforced_limits() -> void:
	# A displayed limit that exists nowhere else is how the p.134 mismatch survived: the
	# builder told players one thing while the validator enforced another.
	var summary: String = Validator.get_limits_summary(
		TacticsRoster.OrgType.PLATOON, 500)
	assert_str(summary).contains("2-4 Troop units")
	assert_str(summary).contains("0-3 Support units")
	assert_str(summary).contains("1-2 Platoon Leaders")
