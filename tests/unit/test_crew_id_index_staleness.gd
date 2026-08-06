extends GdUnitTestSuite
## get_crew_member_by_id() must never return the WRONG crew member.
##
## THE BUG THIS EXISTS TO PREVENT
## The cached index (character_id -> position) was trusted on a hit after only a range
## check:
##
##     if _crew_id_index.has(character_id):
##         var idx = _crew_id_index[character_id]
##         if idx < members.size():
##             return members[idx]        # never checked members[idx]'s actual id
##
## The docblock promised a linear-scan fallback "if the cache is stale", but that
## fallback fired on a cache MISS only. A stale-but-IN-RANGE hit — exactly what
## Array.remove_at() of a non-final member produces — returned the wrong member and
## returned immediately.
##
## UpkeepPhaseComponent._execute_crew_dismissal() did precisely that: it took the live
## members Array (a reference to the owner) and called remove_at() directly, bypassing
## remove_crew_member(), the chokepoint that rebuilds the index.
##
## CONSEQUENCE: CrewTaskComponent:1443-1457 credits World Phase task XP to whatever
## get_crew_member_by_id returns and RETURNS before reaching its own linear-scan
## fallback — so the XP landed on a different character sheet, with no error. Upkeep
## is where dismissal is offered and crew tasks resolve later in the SAME World Phase,
## so it is a same-turn bug.
##
## GameState.verify_consistency CHECK 3 could not catch it: it flags only entries whose
## index is OUT of range, and this case is in range and wrong.
##
## gdUnit4 v6.0.3 compatible.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")


func _campaign_with_crew() -> Variant:
	var c = CampaignCore.new()
	c.from_dictionary({
		"campaign_id": "idx_t",
		# FIVE members, not three. With a short roster a mid-list removal pushes most
		# stale indices OUT of range, so they fall through to the rebuild by luck of
		# position and the bug hides. A 5-crew campaign (Core Rules p.63 allows 4-6)
		# leaves several stale indices IN range and pointing at the WRONG member —
		# which is the actual defect.
		"crew": {"members": [
			{"character_id": "a", "character_name": "Ana", "experience": 0},
			{"character_id": "b", "character_name": "Bo", "experience": 0},
			{"character_id": "c", "character_name": "Cy", "experience": 0},
			{"character_id": "d", "character_name": "Dee", "experience": 0},
			{"character_id": "e", "character_name": "Eli", "experience": 0},
		]},
	})
	return c


func test_lookup_is_correct_before_any_mutation() -> void:
	var c = _campaign_with_crew()
	assert_str(str(c.get_crew_member_by_id("c").get("character_name"))).is_equal("Cy")


func test_a_raw_remove_at_cannot_produce_a_wrong_member() -> void:
	# Simulates the exact bypass: mutate the owner Array directly, leaving the index
	# untouched. Even with the writer fixed, the READ must be self-validating so any
	# present or future direct mutation is safe.
	var c = _campaign_with_crew()
	for cid in ["a", "b", "c", "d", "e"]:
		c.get_crew_member_by_id(cid)  # fully warm the cache
	c.crew_data["members"].remove_at(1)   # drop Bo from the MIDDLE; c/d/e shift down

	var found = c.get_crew_member_by_id("c")
	assert_object(found).override_failure_message(
		"lookup for 'c' returned null after a raw remove_at"
	).is_not_null()
	assert_str(str(found.get("character_id"))).override_failure_message(
		"stale index returned the WRONG crew member — task XP would land on their sheet"
	).is_equal("c")


func test_a_removed_members_id_no_longer_resolves_to_someone_else() -> void:
	# The dismissed member's id stayed in the index pointing at whoever moved into
	# their slot, so looking them up silently returned a still-employed crew member.
	var c = _campaign_with_crew()
	c.get_crew_member_by_id("a")
	c.crew_data["members"].remove_at(0)

	var ghost = c.get_crew_member_by_id("a")
	if ghost != null:
		assert_str(str(ghost.get("character_id"))).override_failure_message(
			"the dismissed member's id resolved to a DIFFERENT crew member"
		).is_equal("a")


func test_remove_crew_member_keeps_lookups_correct() -> void:
	# The chokepoint the dismissal path now uses.
	var c = _campaign_with_crew()
	c.get_crew_member_by_id("a")
	if not c.has_method("remove_crew_member"):
		return
	c.remove_crew_member("a")

	assert_str(str(c.get_crew_member_by_id("b").get("character_name"))).is_equal("Bo")
	assert_str(str(c.get_crew_member_by_id("c").get("character_name"))).is_equal("Cy")


func test_every_remaining_member_resolves_to_itself_after_a_mid_list_removal() -> void:
	# The general invariant, stated once: whatever the id, you get that member.
	var c = _campaign_with_crew()
	for cid in ["a", "b", "c", "d", "e"]:
		c.get_crew_member_by_id(cid)      # fully warm the cache
	c.crew_data["members"].remove_at(1)   # drop Bo from the middle

	for m in c.crew_data["members"]:
		var cid: String = str(m.get("character_id"))
		var got = c.get_crew_member_by_id(cid)
		assert_str(str(got.get("character_id"))).override_failure_message(
			"lookup for '%s' returned '%s'" % [cid, str(got.get("character_id"))]
		).is_equal(cid)
