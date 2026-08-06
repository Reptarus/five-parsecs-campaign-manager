extends GdUnitTestSuite
## Core Rules p.119 Post-Battle Activities, as amended by the official errata
## v1.06. Two separate rules on one page, neither of which worked.
##
## Step 1, Resolve Rival Status: chasing off an EXISTING Rival is 1D6, "+1 if
## you Tracked them down" and "+1 if you killed a Unique Individual in the
## battle"; 4+ removes them. The errata amends that second modifier to read
## "a Unique Individual OR LIEUTENANT".
##   THE BUG: the modifier read enemy["is_unique"], a key no producer writes.
##   Every result path builds defeated_enemies with was_unique_individual /
##   was_lieutenant, so killing the enemy Boss never helped you shake a Rival.
##
## Step 2, Resolve Patron Status: the errata adds "Failing a job you have
## accepted from a known Patron causes them to be removed from your list of
## known Patrons."
##   THE BUG: failure only logged an NPCTracker interaction. The Patron stayed
##   on the list and kept offering work, so a failed contract cost nothing.

const ContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const ResolverClass = preload("res://src/core/campaign/phases/post_battle/RivalPatronResolver.gd")

const RIVAL_ID := "rival_gangers_1"

func _resolver() -> Object:
	return auto_free(ResolverClass.new())

func _ctx_with_defeated(defeated: Array) -> Object:
	var ctx = auto_free(ContextClass.new())
	ctx.defeated_enemies = defeated
	return ctx

# ── Step 1: the Rival-removal modifier ────────────────────────────────────

func _modifier_applied(defeated: Array) -> bool:
	## _roll_rival_removal is 1D6 + modifiers. With no campaign attached the
	## Tracked bonus cannot apply, so any total above 6 proves THIS modifier
	## fired, and any total of 7 is unreachable without it.
	var r = _resolver()
	var ctx = _ctx_with_defeated(defeated)
	for _i in range(200):
		if int(r._roll_rival_removal(ctx, RIVAL_ID)) > 6:
			return true
	return false

func test_killing_a_unique_individual_adds_the_modifier() -> void:
	assert_bool(_modifier_applied([
		{"rival_id": RIVAL_ID, "was_unique_individual": true},
	])).override_failure_message(
		"A slain Unique Individual did not add +1 to the Rival removal roll").is_true()

func test_killing_a_lieutenant_adds_the_modifier() -> void:
	# The errata's amendment. Before it, only a Unique Individual counted.
	assert_bool(_modifier_applied([
		{"rival_id": RIVAL_ID, "was_lieutenant": true},
	])).override_failure_message(
		"Errata v1.06 extends the +1 to a slain Lieutenant; it did not apply").is_true()

func test_a_legacy_is_unique_key_still_counts() -> void:
	# Tolerated for any older result dict that used the pre-consolidation name.
	assert_bool(_modifier_applied([
		{"rival_id": RIVAL_ID, "is_unique": true},
	])).is_true()

func test_killing_rank_and_file_adds_nothing() -> void:
	assert_bool(_modifier_applied([
		{"rival_id": RIVAL_ID, "was_unique_individual": false, "was_lieutenant": false},
	])).override_failure_message(
		"An ordinary casualty granted the +1").is_false()

func test_a_unique_belonging_to_a_different_rival_adds_nothing() -> void:
	# The book credits the Rival you fought, not any Unique Individual anywhere.
	assert_bool(_modifier_applied([
		{"rival_id": "some_other_rival", "was_unique_individual": true},
	])).is_false()

func test_the_modifier_counts_once_even_with_several_special_kills() -> void:
	# p.119 grants a single +1, not one per figure. Max reachable is 6 + 1 = 7.
	var r = _resolver()
	var ctx = _ctx_with_defeated([
		{"rival_id": RIVAL_ID, "was_unique_individual": true},
		{"rival_id": RIVAL_ID, "was_lieutenant": true},
		{"rival_id": RIVAL_ID, "was_unique_individual": true},
	])
	for _i in range(200):
		assert_int(int(r._roll_rival_removal(ctx, RIVAL_ID))).is_less_equal(7)

# ── Step 2: a failed contract drops the Patron ────────────────────────────

func _ctx_with_patrons(patrons: Array) -> Object:
	var ctx = auto_free(ContextClass.new())
	ctx.campaign = {"patrons": patrons}
	return ctx

func test_remove_patron_drops_the_named_contact() -> void:
	var ctx = _ctx_with_patrons([
		{"id": "patron_a", "name": "The Broker"},
		{"id": "patron_b", "name": "Lady Silver"},
	])
	assert_bool(ctx.remove_patron("patron_b")).is_true()
	var left: Array = ctx.campaign["patrons"]
	assert_int(left.size()).is_equal(1)
	assert_str(str(left[0]["id"])).is_equal("patron_a")

func test_remove_patron_leaves_everyone_else_alone() -> void:
	# The errata drops ONLY the Patron whose accepted job was failed.
	var ctx = _ctx_with_patrons([
		{"id": "patron_a"}, {"id": "patron_b"}, {"id": "patron_c"},
	])
	ctx.remove_patron("patron_b")
	var ids: Array = []
	for p in ctx.campaign["patrons"]:
		ids.append(str(p["id"]))
	assert_array(ids).contains_exactly(["patron_a", "patron_c"])

func test_removing_an_unknown_patron_reports_no_change() -> void:
	var ctx = _ctx_with_patrons([{"id": "patron_a"}])
	assert_bool(ctx.remove_patron("nobody")).is_false()
	assert_int((ctx.campaign["patrons"] as Array).size()).is_equal(1)

func test_an_empty_patron_id_is_never_treated_as_a_match() -> void:
	# battle_result carries "" when the mission had no Patron; that must not
	# silently drop a contact whose id failed to serialise.
	var ctx = _ctx_with_patrons([{"id": ""}, {"id": "patron_a"}])
	assert_bool(ctx.remove_patron("")).is_false()
	assert_int((ctx.campaign["patrons"] as Array).size()).is_equal(2)

func test_remove_patron_matches_the_patron_id_key_too() -> void:
	# Patron dicts are written by more than one producer; both spellings appear.
	var ctx = _ctx_with_patrons([{"patron_id": "patron_z"}])
	assert_bool(ctx.remove_patron("patron_z")).is_true()
	assert_int((ctx.campaign["patrons"] as Array).size()).is_equal(0)
