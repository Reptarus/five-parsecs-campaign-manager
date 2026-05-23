extends GdUnitTestSuite
## CampaignJournal player-notes carryback tests
##
## Verifies the path: TacticalBattleUI battle-notes textbox →
## GameStateManager.set_temp_data("battle_player_notes", ...) →
## CampaignJournal.auto_create_battle_entry() (consumes + clears).
## gdUnit4 v6.0.3 compatible.

var _saved_entries: Array[Dictionary] = []
var _saved_index: Dictionary = {}

func before_test() -> void:
	_saved_entries = CampaignJournal.entries.duplicate()
	_saved_index = CampaignJournal.entries_by_id.duplicate()
	CampaignJournal.entries.clear()
	CampaignJournal.entries_by_id.clear()
	# Wipe any prior battle notes so tests start clean.
	if GameStateManager and GameStateManager.has_method("clear_temp_data"):
		GameStateManager.clear_temp_data("battle_player_notes")


func after_test() -> void:
	CampaignJournal.entries = _saved_entries
	CampaignJournal.entries_by_id = _saved_index
	if GameStateManager and GameStateManager.has_method("clear_temp_data"):
		GameStateManager.clear_temp_data("battle_player_notes")


func test_explicit_player_notes_field_lands_in_entry_description() -> void:
	var result := {
		"turn": 4,
		"location": "Test Site",
		"outcome": "victory",
		"player_notes": "Kept the high ground all game.",
	}
	CampaignJournal.auto_create_battle_entry(result)

	var summary: Dictionary = CampaignJournal.get_turn_summary(4)
	assert_int(summary["total"]).is_equal(1)
	# Find the entry and check its description carries the notes
	var found := false
	var expected := "Kept the high ground all game."
	for entry in CampaignJournal.entries:
		if int(entry.get("turn_number", 0)) == 4:
			found = true
			assert_str(str(entry.get("description", ""))).contains(expected)
			assert_str(str(entry.get("player_notes", ""))).is_equal(expected)
	assert_bool(found).is_true()


func test_temp_data_fallback_is_consumed_and_cleared() -> void:
	# Simulate the player typing into TacticalBattleUI's floating textbox
	GameStateManager.set_temp_data(
		"battle_player_notes", "Rolled a clutch crit on round 3.")
	var result := {"turn": 5, "location": "Pivot Hold", "outcome": "victory"}
	CampaignJournal.auto_create_battle_entry(result)

	# Notes folded into entry
	var f5 := {"type": "battle", "turn_min": 5, "turn_max": 5}
	var entries_at_5 := CampaignJournal.filter_entries(f5)
	assert_int(entries_at_5.size()).is_equal(1)
	assert_str(str(entries_at_5[0].get("description", ""))) \
		.contains("Rolled a clutch crit")

	# temp_data cleared so next battle starts fresh
	assert_bool(
		GameStateManager.has_temp_data("battle_player_notes")).is_false()


func test_no_notes_keeps_entry_description_clean() -> void:
	var result := {"turn": 6, "location": "Quiet Field", "outcome": "victory"}
	CampaignJournal.auto_create_battle_entry(result)
	var f6 := {"type": "battle", "turn_min": 6, "turn_max": 6}
	var entries_at_6 := CampaignJournal.filter_entries(f6)
	assert_int(entries_at_6.size()).is_equal(1)
	# No "[Notes]" prefix in description when no notes were provided
	assert_str(str(entries_at_6[0].get("description", ""))).not_contains("[Notes]")
