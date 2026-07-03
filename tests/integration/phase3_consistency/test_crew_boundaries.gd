extends GdUnitTestSuite
## Phase 3A: CharacterManager registry integrity (rewritten 2026-07-02).
##
## The original suite targeted an older CharacterManager API that no longer
## exists (create_character(data), remove_character_from_roster,
## set_max_crew_size/get_max_crew_size, get_crew_size) and asserted
## crew-size RULES that are a campaign-level concern in the current design
## (the fixed 4/5/6 campaign_crew_size setting on FiveParsecsCampaignCore,
## Core Rules p.63 — not this generic registry). Cut for that reason:
##   - test_enforce_maximum_crew_size
##   - test_enforce_minimum_crew_size_validation
##   - test_dynamic_max_crew_size_adjustment
## This suite covers the registry's REAL contract: create_character() /
## add_character(dict) / remove_character(id) / has/get / signals — plus the
## duplicate-entry fix (re-adding a character no longer duplicates the
## active list; replacing an id evicts the old entry).

# System under test
var CharacterManagerClass
var character_manager = null


func before():
	CharacterManagerClass = load(
		"res://src/core/character/Management/CharacterManager.gd")


func before_test():
	seed(12345)
	character_manager = auto_free(CharacterManagerClass.new())
	character_manager._initialize_manager()


func after_test():
	character_manager = null


# ============================================================================
# Creation & identity
# ============================================================================

func test_create_character_assigns_unique_ids():
	var ids := {}
	for i in range(5):
		var character = character_manager.create_character()
		assert_that(character).is_not_null()
		var char_id: String = str(character.get("id", ""))
		assert_str(char_id).is_not_empty()
		assert_bool(ids.has(char_id)).is_false()
		ids[char_id] = true
	assert_int(character_manager.get_all_characters().size()).is_equal(5)


func test_add_character_generates_missing_id():
	var character = {"name": "No Id Yet", "status": {}}
	assert_bool(character_manager.add_character(character)).is_true()
	assert_str(str(character.get("id", ""))).is_not_empty()
	assert_bool(character_manager.has_character(character["id"])).is_true()


func test_readding_same_character_does_not_duplicate():
	var character = character_manager.create_character()
	character_manager.add_character(character)
	assert_int(character_manager.get_all_characters().size()).is_equal(1)
	assert_int(character_manager.get_active_characters().size()).is_equal(1)


func test_replacing_id_evicts_old_entry():
	var first = character_manager.create_character()
	var replacement = {"id": first["id"], "name": "Replacement", "status": {}}
	character_manager.add_character(replacement)
	assert_int(character_manager.get_all_characters().size()).is_equal(1)
	assert_int(character_manager.get_active_characters().size()).is_equal(1)
	var stored = character_manager.get_character(first["id"])
	assert_str(str(stored.get("name", ""))).is_equal("Replacement")


# ============================================================================
# Removal
# ============================================================================

func test_character_removal_updates_counts():
	var character = character_manager.create_character()
	assert_int(character_manager.get_all_characters().size()).is_equal(1)

	assert_bool(character_manager.remove_character(character["id"])).is_true()
	assert_int(character_manager.get_all_characters().size()).is_equal(0)
	assert_int(character_manager.get_active_characters().size()).is_equal(0)
	assert_bool(character_manager.has_character(character["id"])).is_false()


func test_character_removal_emits_signal():
	var character = character_manager.create_character()
	var removed := [false]
	character_manager.character_removed.connect(
		func(_character): removed[0] = true)
	character_manager.remove_character(character["id"])
	assert_bool(removed[0]).is_true()


func test_remove_nonexistent_returns_false():
	assert_bool(character_manager.remove_character("no_such_id")).is_false()


func test_get_character_roundtrip():
	var character = character_manager.create_character()
	var fetched = character_manager.get_character(character["id"])
	assert_that(fetched).is_not_null()
	assert_str(str(fetched.get("id", ""))).is_equal(str(character["id"]))
