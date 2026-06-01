extends GdUnitTestSuite
## Tests for Opus 4.8 audit B1 — journal-by-location join correctness.
##
## Pre-fix: TravelPhase wrote planet names as `location`, PostBattleCompletion
## wrote "Unknown" (battle_result never carried that key), and milestone
## entries wrote no `location` field at all. Result: querying journal entries
## by planet name missed most or all of them.
##
## These tests defend the post-fix invariants:
##   - auto_create_milestone_entry promotes `planet_name` / `location` from
##     `data` onto the entry's `location` field.
##   - get_entries_by_location(planet_name) returns ALL entry types (travel +
##     battle + milestone) for that planet.

const CampaignJournalClass := preload("res://src/core/campaign/CampaignJournal.gd")


func _make_journal() -> Node:
	# Instantiate a fresh CampaignJournal node so each test starts clean.
	# We use the class directly rather than the autoload to avoid mutating
	# shared state across other test suites.
	var j: Node = CampaignJournalClass.new()
	add_child(j)
	# Approximate the autoload's _ready() side effects without filesystem I/O.
	# Tests only interact with in-memory entries arrays.
	return j


# ============================================================================
# B1: auto_create_milestone_entry populates location field
# ============================================================================

func test_milestone_planet_arrival_carries_planet_name_as_location() -> void:
	var j: Node = _make_journal()
	j.auto_create_milestone_entry("planet_arrival", {
		"turn": 3,
		"planet_name": "Foo Prime",
		"trait_name": "industrial",
	})
	# Find the just-created entry. There's exactly one entry in this fresh journal.
	assert_int(j.entries.size()).is_equal(1)
	var entry: Dictionary = j.entries[0]
	assert_str(str(entry.get("location", ""))).is_equal("Foo Prime")
	assert_str(str(entry.get("type", ""))).is_equal("milestone")


func test_milestone_planet_departure_carries_planet_name_as_location() -> void:
	var j: Node = _make_journal()
	j.auto_create_milestone_entry("planet_departure", {
		"turn": 5,
		"planet_name": "Bar Secundus",
	})
	assert_int(j.entries.size()).is_equal(1)
	assert_str(str(j.entries[0].get("location", ""))).is_equal("Bar Secundus")


func test_milestone_explicit_location_key_takes_precedence() -> void:
	# If a caller passes `location` directly, prefer it over `planet_name`
	# (defensive — current callers don't do this, but the contract should
	# accept it).
	var j: Node = _make_journal()
	j.auto_create_milestone_entry("planet_arrival", {
		"turn": 1,
		"location": "Explicit Loc",
		"planet_name": "Should Be Ignored",
	})
	assert_str(str(j.entries[0].get("location", ""))).is_equal("Explicit Loc")


func test_milestone_empty_when_neither_key_present() -> void:
	# Other milestone types (e.g. "ship_purchased") may not carry a planet.
	# Confirm the fix doesn't crash and leaves location empty for those.
	var j: Node = _make_journal()
	j.auto_create_milestone_entry("ship_purchased", {
		"turn": 10,
		"stats": {"credits_spent": 70},
	})
	assert_int(j.entries.size()).is_equal(1)
	assert_str(str(j.entries[0].get("location", ""))).is_equal("")


# ============================================================================
# B1: get_entries_by_location returns all entry types for a planet
# ============================================================================

func test_get_entries_by_location_finds_battle_travel_and_milestone() -> void:
	var j: Node = _make_journal()
	# Battle entry on Foo (mimics what PostBattleCompletion writes post-fix).
	j.auto_create_battle_entry({
		"turn": 1,
		"location": "Foo",
		"outcome": "victory",
		"casualties": 0,
		"loot": 1,
		"xp": 2,
		"enemy_type": "Raiders",
		"crew_ids": [],
	})
	# Travel entry on Foo (mimics TravelPhase write).
	j.create_entry({
		"turn_number": 2,
		"type": "travel",
		"title": "Travel to Foo",
		"description": "Jumped to Foo Prime.",
		"location": "Foo",
	})
	# Milestone entry on Foo via the post-fix path.
	j.auto_create_milestone_entry("planet_arrival", {
		"turn": 2,
		"planet_name": "Foo",
	})
	# Entry on a DIFFERENT planet that must NOT match.
	j.create_entry({
		"turn_number": 3,
		"type": "story",
		"title": "Story event",
		"description": "Unrelated to Foo.",
		"location": "Bar",
	})

	var foo_entries: Array = j.get_entries_by_location("Foo")
	# 3 Foo entries: battle + travel + milestone. NOT the Bar one.
	assert_int(foo_entries.size()).is_equal(3)
	var types_seen: Dictionary = {}
	for entry in foo_entries:
		types_seen[entry.get("type", "")] = true
	assert_bool(types_seen.has("battle")).is_true()
	assert_bool(types_seen.has("travel")).is_true()
	assert_bool(types_seen.has("milestone")).is_true()


func test_get_entries_by_location_returns_empty_for_unknown_planet() -> void:
	var j: Node = _make_journal()
	j.auto_create_milestone_entry("planet_arrival", {
		"turn": 1,
		"planet_name": "Foo",
	})
	var no_results: Array = j.get_entries_by_location("DoesNotExist")
	assert_int(no_results.size()).is_equal(0)


# ============================================================================
# B1: get_used_locations reflects post-fix population
# ============================================================================

func test_get_used_locations_includes_milestone_planet() -> void:
	# Pre-fix, milestone entries had no `location` field, so they never
	# contributed to get_used_locations(). Verify that's no longer the case.
	var j: Node = _make_journal()
	j.auto_create_milestone_entry("planet_arrival", {
		"turn": 1,
		"planet_name": "Solo Planet",
	})
	var used: Array = j.get_used_locations()
	assert_bool(used.has("Solo Planet")).is_true()
