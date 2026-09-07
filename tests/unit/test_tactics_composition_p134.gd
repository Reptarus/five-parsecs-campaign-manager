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


func _add(r: TacticsRoster, slot: int, count: int = 1, shared_id: String = "") -> void:
	for _i in range(count):
		_uid += 1
		var p := TacticsUnitProfile.new()
		p.org_slot = slot
		# Ids are unique by default only so failure messages name distinct units.
		# ⚠ This comment used to read: "a platoon may not take two specialists of the SAME
		# type, and a shared id would fail that separate rule and mask the one under test".
		# That rule was FABRICATED and was deleted on 2026-09-06 — so the invention had
		# propagated into the fixture design of the very suite meant to police this file,
		# and the fixture was quietly built to never exercise it. Pass `shared_id` to
		# construct the case the old comment was steering away from.
		p.unit_id = shared_id if shared_id != "" else "u%d" % _uid
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


func test_two_specialists_of_the_same_type_are_legal() -> void:
	# p.134 states ONE specialist rule: "A platoon may have 1 specialist unit per 2 troops
	# selected." It is a ratio and nothing else. The validator additionally rejected two
	# specialists sharing a unit_id, commented "one of each type" — an invented
	# restriction that REJECTED LEGAL ARMIES. Deleted 2026-09-06; this is its detection
	# proof, and it fails before the deletion and passes after.
	#
	# The book states type-composition rules plainly when it has one, and the only two
	# places it does so near here both contradict the deleted check:
	#   p.134 Troops  — "The platoon does not have to consist of all the same type."
	#   p.135 Armored — "The first 3 vehicles ... must be the same type" (a REQUIREMENT)
	var r := _make_roster()
	_add(r, TacticsUnitProfile.OrgSlot.LEADER, 1)
	_add(r, TacticsUnitProfile.OrgSlot.TROOP, 4)
	# 4 troops earn exactly 2 specialists, so the RATIO is satisfied with nothing to
	# spare — the only thing that could reject this roster is the deleted rule.
	_add(r, TacticsUnitProfile.OrgSlot.SPECIALIST_SLOT, 2, "sniper_team")
	assert_str(_errors(r)).override_failure_message(
		"Tactics has no duplicate restriction: 4 troops earn 2 specialists and the book "
		+ "never requires them to differ"
	).is_empty()


func test_the_printed_limits_match_the_enforced_limits() -> void:
	# A displayed limit that exists nowhere else is how the p.134 mismatch survived: the
	# builder told players one thing while the validator enforced another.
	var summary: String = Validator.get_limits_summary(
		TacticsRoster.OrgType.PLATOON, 500)
	assert_str(summary).contains("2-4 Troop units")
	assert_str(summary).contains("0-3 Support units")
	assert_str(summary).contains("1-2 Platoon Leaders")
	# The summary printed the fabricated rule too, so deleting the check without the
	# string would have left the builder still advertising it to players.
	assert_str(summary).override_failure_message(
		"the fabricated 'one of each type' specialist clause must be gone from the "
		+ "player-facing summary, not just from the validator"
	).not_contains("one of each")


func test_the_roster_panel_actually_displays_the_limits() -> void:
	# ⚠ get_limits_summary() was a ZERO-CALLER function until 2026-09-06 — reachable only
	# from the case above — while its docstring claimed the strings are "what a player
	# reads while building". A string-only assertion is exactly what let that stand: the
	# caps were correct, tested, and rendered by nobody. This case asserts the SCREEN.
	var script: GDScript = load(
		"res://src/ui/screens/tactics/panels/TacticsRosterPanel.gd")
	assert_object(script).override_failure_message(
		"TacticsRosterPanel.gd failed to load — a parse error in it also lands here"
	).is_not_null()

	var panel: Control = script.new()
	add_child(panel)
	auto_free(panel)
	await get_tree().process_frame

	# owned=false: the panel builds its tree in code, so nothing has an owner and the
	# default owned=true search returns null (the ShipPanel trap, CLAUDE.md Gotchas).
	var lbl: Node = panel.find_child("LimitsSummary", true, false)
	assert_object(lbl).override_failure_message(
		"the roster panel must render a LimitsSummary label"
	).is_not_null()

	# Defaults with no coordinator are PLATOON / 500 pts, so the platoon caps apply.
	assert_str(lbl.text).override_failure_message(
		"the label must carry the validator's own summary, not a hand-written copy"
	).contains("2-4 Troop units")
	assert_str(lbl.text).contains("0-3 Support units")
	assert_str(lbl.text).contains("1-2 Platoon Leaders")
