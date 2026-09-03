extends GdUnitTestSuite

## Core Rules p.24 "Leaders", verbatim: "Once you have created all of your
## characters, pick one to be the Leader. This character receives 1 Luck point
## and will never leave the crew through random events, though they can
## certainly be slain. While you are free to select a Bot as your Leader, they
## do not receive Luck if you do."
##
## THE GAP. The +1 Luck half was wired (CharacterCreator._setup_captain_bonuses,
## with the Bot exclusion). The "never leaves" half was QUOTED IN A COMMENT at
## CharacterCreator:414 and enforced nowhere. CampaignEventEffects does guard
## is_captain; CharacterEventEffects had three departure routes and guarded none,
## so a Swift Leader rolling Business Elsewhere (p.128, 4-6: "If the character is
## Swift, they never return") or a Feeler Leader having a mental breakdown (p.22)
## was removed from the crew permanently.

const Effects = preload(
	"res://src/core/campaign/phases/post_battle/CharacterEventEffects.gd")


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var s := f.get_as_text()
	f.close()
	return s


func _effects() -> Object:
	return Effects.new()


# ── the rule ──────────────────────────────────────────────────────────────

func test_the_leader_is_not_marked_departed() -> void:
	var fx := _effects()
	var leader := {"character_name": "Cap", "is_captain": true, "status": "active"}
	fx._mark_departed(leader)
	assert_str(str(leader.get("status", ""))).override_failure_message(
		"the Leader was marked '%s'; p.24 says they never leave through a random"
		% str(leader.get("status", "")) + " event"
	).is_not_equal("departed")


func test_an_ordinary_crew_member_still_departs() -> void:
	# The exemption must be narrow. If the guard swallowed every departure the
	# p.128 and p.22 rules would stop working for the rest of the crew, which is
	# a worse bug than the one being fixed.
	var fx := _effects()
	var grunt := {"character_name": "Deckhand", "is_captain": false, "status": "active"}
	fx._mark_departed(grunt)
	assert_str(str(grunt.get("status", ""))).override_failure_message(
		"a non-Leader must still be able to leave the crew"
	).is_equal("departed")


func test_a_member_with_no_is_captain_key_still_departs() -> void:
	# Legacy crew dicts may not carry the key at all. Absent must mean "not the
	# Leader", never "exempt".
	var fx := _effects()
	var legacy := {"character_name": "Old Save", "status": "active"}
	fx._mark_departed(legacy)
	assert_str(str(legacy.get("status", ""))).override_failure_message(
		"a crew member with no is_captain key was treated as the Leader"
	).is_equal("departed")


func test_is_leader_reads_the_captain_flag_on_both_shapes() -> void:
	# Crew members are Dictionaries after a load and Character Resources on a
	# fresh campaign, and _member_field() is the dual-shape reader.
	var fx := _effects()
	assert_bool(fx._is_leader({"is_captain": true})).is_true()
	assert_bool(fx._is_leader({"is_captain": false})).is_false()
	assert_bool(fx._is_leader({})).is_false()


# ── the wiring: all three routes must go through the guard ────────────────

func test_every_departure_route_goes_through_the_guarded_chokepoint() -> void:
	# Guarded at the CALLEE rather than at each call site, so a fourth departure
	# route added later cannot miss it. This is the T9-50 lesson: a fix ordered
	# against SOME callers is not a fix.
	var src: String = _read(
		"res://src/core/campaign/phases/post_battle/CharacterEventEffects.gd")
	var code := ""
	for line in src.split("\n"):
		var stripped := (line as String).strip_edges()
		if stripped.begins_with("#"):
			continue
		code += line + "\n"
	assert_str(code).override_failure_message(
		"the guard must live inside _mark_departed, not at the call sites"
	).contains("if _is_leader(character):")
	# No route may still set the status by hand and bypass the guard.
	assert_str(code).override_failure_message(
		"a departure route still writes status directly, bypassing the p.24 guard"
	).not_contains('character.status = "DEPARTED"')


func test_the_creators_promise_is_actually_kept() -> void:
	# CharacterCreator quotes the rule. Before this fix that quote was the only
	# place it existed.
	var creator: String = _read(
		"res://src/core/character/Generation/CharacterCreator.gd")
	assert_str(creator).contains("never leave the crew through random")
	var effects: String = _read(
		"res://src/core/campaign/phases/post_battle/CharacterEventEffects.gd")
	assert_str(effects).override_failure_message(
		"CharacterEventEffects must cite p.24 where it enforces the exemption"
	).contains("p.24")
