extends GdUnitTestSuite
## CampaignJournal.get_turn_summary() tests
##
## Verifies per-turn aggregation: counts entries by type, returns zero-filled
## summary on missing-turn input, handles unknown entry types gracefully.
## gdUnit4 v6.0.3 compatible.

var _saved_entries: Array[Dictionary] = []
var _saved_index: Dictionary = {}

func before_test() -> void:
	# Snapshot existing CampaignJournal state and clear for test isolation
	_saved_entries = CampaignJournal.entries.duplicate()
	_saved_index = CampaignJournal.entries_by_id.duplicate()
	CampaignJournal.entries.clear()
	CampaignJournal.entries_by_id.clear()


func after_test() -> void:
	CampaignJournal.entries = _saved_entries
	CampaignJournal.entries_by_id = _saved_index


func test_get_turn_summary_counts_each_type_independently() -> void:
	CampaignJournal.create_entry({"turn_number": 3, "type": "battle"})
	CampaignJournal.create_entry({"turn_number": 3, "type": "battle"})
	CampaignJournal.create_entry({"turn_number": 3, "type": "story"})
	CampaignJournal.create_entry({"turn_number": 3, "type": "purchase"})
	CampaignJournal.create_entry({"turn_number": 3, "type": "purchase"})
	CampaignJournal.create_entry({"turn_number": 3, "type": "purchase"})

	var summary: Dictionary = CampaignJournal.get_turn_summary(3)
	assert_int(summary["total"]).is_equal(6)
	assert_int(summary["turn_number"]).is_equal(3)
	var by_type: Dictionary = summary["by_type"]
	assert_int(by_type["battle"]).is_equal(2)
	assert_int(by_type["story"]).is_equal(1)
	assert_int(by_type["purchase"]).is_equal(3)
	assert_int(by_type["injury"]).is_equal(0)


func test_get_turn_summary_returns_zero_filled_summary_for_missing_turn() -> void:
	CampaignJournal.create_entry({"turn_number": 1, "type": "battle"})
	var summary: Dictionary = CampaignJournal.get_turn_summary(99)
	assert_int(summary["total"]).is_equal(0)
	assert_int(summary["turn_number"]).is_equal(99)
	# All default buckets should be present at zero
	var by_type: Dictionary = summary["by_type"]
	assert_int(by_type["battle"]).is_equal(0)
	assert_int(by_type["story"]).is_equal(0)
	assert_int(by_type["purchase"]).is_equal(0)
	assert_int(by_type["injury"]).is_equal(0)
	assert_int(by_type["milestone"]).is_equal(0)
	assert_int(by_type["custom"]).is_equal(0)


func test_get_turn_summary_isolates_each_turn() -> void:
	CampaignJournal.create_entry({"turn_number": 1, "type": "battle"})
	CampaignJournal.create_entry({"turn_number": 2, "type": "battle"})
	CampaignJournal.create_entry({"turn_number": 2, "type": "battle"})
	CampaignJournal.create_entry({"turn_number": 3, "type": "battle"})

	assert_int(CampaignJournal.get_turn_summary(1)["total"]).is_equal(1)
	assert_int(CampaignJournal.get_turn_summary(2)["total"]).is_equal(2)
	assert_int(CampaignJournal.get_turn_summary(3)["total"]).is_equal(1)


func test_get_turn_summary_preserves_unknown_types_without_dropping_them() -> void:
	# Custom user types or future-added types shouldn't be lost from the count.
	CampaignJournal.create_entry({"turn_number": 4, "type": "battle"})
	CampaignJournal.create_entry({"turn_number": 4, "type": "experimental_event"})
	var summary: Dictionary = CampaignJournal.get_turn_summary(4)
	assert_int(summary["total"]).is_equal(2)
	var by_type: Dictionary = summary["by_type"]
	assert_int(by_type["battle"]).is_equal(1)
	assert_int(by_type["experimental_event"]).is_equal(1)
