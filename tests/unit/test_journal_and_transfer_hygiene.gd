extends GdUnitTestSuite
## Journal growth is bounded and ordered; transfers cannot duplicate or wedge.
##
## FOUR DEFECTS THIS PINS
##
## 1. JOURNAL RE-SORTED ON EVERY INSERT. create_entry() called _sort_entries_by_turn()
##    after every append — O(n^2 log n) growth across a campaign — with an unstable
##    comparator, so entries sharing a turn number could reshuffle on each insert.
##    Now inserted in order.
##
## 2. JOURNAL NEVER PRUNED. entries / milestones / character timelines only ever
##    appended, and the whole corpus is deep-copied and JSON-stringified into every
##    save (~8 saves per campaign turn). A turn-100 campaign projected to ~650 KB
##    rewritten on every World Phase "Next" tap. Capped at MAX_ENTRIES, milestones
##    exempt.
##
## 3. DUPLICATE CROSS-MODE IMPORT. Import is a PULL that does not remove the character
##    from the source, so importing the same veteran twice put two entries with the
##    SAME character_id on one roster — every id-keyed lookup then resolves to whichever
##    is first, and XP/injuries land on one arbitrarily.
##
## 4. UNREADABLE TRANSFER FILE RETAINED FOREVER. A malformed envelope silently failed
##    validation and stayed in user://transfers/, re-read and re-skipped on every
##    dashboard open, while the character was already gone from the source roster.
##    Now quarantined to .corrupt — out of the scan, bytes kept.
##
## gdUnit4 v6.0.3 compatible.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const TransferService = preload("res://src/core/character/CharacterTransferService.gd")


func _journal() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/CampaignJournal")


# --- journal -------------------------------------------------------------------

func test_entries_stay_ordered_without_a_full_resort() -> void:
	var j := _journal()
	if j == null:
		return
	j.load_from_save({})
	for t in [1, 2, 3, 5, 4]:      # 4 arrives late — must land before 5
		j.create_entry({"turn_number": t, "title": "T%d" % t})
	var turns: Array = []
	for e in j.entries:
		turns.append(int(e.get("turn_number", 0)))
	var sorted_turns := turns.duplicate()
	sorted_turns.sort()
	assert_array(turns).override_failure_message(
		"journal entries are out of turn order: %s" % str(turns)
	).is_equal(sorted_turns)
	j.load_from_save({})


func test_the_journal_is_capped() -> void:
	var j := _journal()
	if j == null or not ("MAX_ENTRIES" in j):
		fail("CampaignJournal.MAX_ENTRIES is missing — the journal grows unbounded again")
		return
	j.load_from_save({})
	var cap: int = int(j.MAX_ENTRIES)
	for i in range(cap + 25):
		j.create_entry({"turn_number": i, "title": "e%d" % i})
	assert_int(j.entries.size()).override_failure_message(
		"journal grew past its cap: %d entries" % j.entries.size()
	).is_less_equal(cap)
	j.load_from_save({})


func test_milestones_are_never_pruned() -> void:
	# Milestones are the campaign's narrative spine — losing them to a cap would be
	# worse than the size problem the cap solves.
	var j := _journal()
	if j == null or not ("MAX_ENTRIES" in j):
		return
	j.load_from_save({})
	j.create_entry({"turn_number": 0, "title": "THE MILESTONE", "type": "milestone"})
	for i in range(int(j.MAX_ENTRIES) + 25):
		j.create_entry({"turn_number": i + 1, "title": "e%d" % i})
	var kept := false
	for e in j.entries:
		if str(e.get("type", "")) == "milestone":
			kept = true
	assert_bool(kept).override_failure_message(
		"a milestone was pruned away"
	).is_true()
	j.load_from_save({})


# --- transfers -----------------------------------------------------------------

func test_importing_the_same_character_twice_is_rejected() -> void:
	var Base = load("res://src/ui/screens/campaign/CampaignScreenBase.gd")
	var screen = Base.new()
	add_child(screen)
	auto_free(screen)

	var campaign = CampaignCore.new()
	campaign.from_dictionary({"campaign_id": "dup_t", "crew": {"members": []}})
	var ch := {"character_id": "vet_1", "character_name": "Rell"}

	var first: bool = screen._add_character_to_mode(campaign, "five_parsecs", ch)
	var second: bool = screen._add_character_to_mode(campaign, "five_parsecs", ch)

	assert_bool(first).is_true()
	assert_bool(second).override_failure_message(
		"the same character imported twice — two roster entries share one character_id"
	).is_false()
	assert_int(campaign.crew_data.get("members", []).size()).is_equal(1)


func test_an_unreadable_transfer_file_is_quarantined() -> void:
	var dir := "user://transfers/"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "transfer_broken_test.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ this is not valid json")
	f.close()

	TransferService.load_pending_transfers("five_parsecs")

	assert_bool(FileAccess.file_exists(path)).override_failure_message(
		"the unreadable envelope is still in the scan — it will be re-skipped forever"
	).is_false()
	var quarantined := path + ".corrupt"
	assert_bool(FileAccess.file_exists(quarantined)).override_failure_message(
		"the bytes were destroyed rather than quarantined — the character is unrecoverable"
	).is_true()
	if FileAccess.file_exists(quarantined):
		DirAccess.remove_absolute(quarantined)
