extends GdUnitTestSuite
## Sprint 7b: the Battle Log reaches the campaign journal.
##
## THE DEFECT THIS PINS. Guide chapter 6 says three times that the battle screen keeps
## "a battle log for the campaign journal". Nothing carried it there. The log's own
## `merge_into_campaign_journal()` had no caller, and it could not have been the route:
## the battle's journal entry is written by the post-battle sequence after the battle
## screen is done. The log now rides the channel the Battle Notes already use, and the
## journal reads and clears it when it writes the battle entry.

const TacticalBattleScene := preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")
const CampaignCoreClass := preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const KEY := "battle_log_narrative"

var _user_state: Dictionary
var _saved_campaign: Variant
var _saved_entries: Array[Dictionary] = []
var _saved_index: Dictionary = {}


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_saved_campaign = GameState.current_campaign
	_saved_entries = CampaignJournal.entries.duplicate()
	_saved_index = CampaignJournal.entries_by_id.duplicate()
	CampaignJournal.entries.clear()
	CampaignJournal.entries_by_id.clear()
	GameStateManager.clear_temp_data(KEY)


func after_test() -> void:
	GameStateManager.clear_temp_data(KEY)
	CampaignJournal.entries = _saved_entries
	CampaignJournal.entries_by_id = _saved_index
	GameState.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


func _battle(mission: Dictionary) -> Control:
	GameState.current_campaign = CampaignCoreClass.new()
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	ui.initialize_battle([], [], mission)
	await get_tree().process_frame
	assert_object(ui.unified_log).override_failure_message(
		"premise: the battle screen built its log").is_not_null()
	return ui


func _battle_entry() -> Dictionary:
	for e: Dictionary in CampaignJournal.entries:
		if str(e.get("type", "")) == "battle":
			return e
	return {}


## A campaign battle, started through the real entry point: what the log records lands
## in that battle's journal entry, and the channel is empty afterwards.
func test_a_campaign_battle_carries_its_log_into_the_battle_entry() -> void:
	var ui: Control = await _battle({"title": "Probe"})
	ui.unified_log.log_enemy_casualty("Raider", "Vex")
	CampaignJournal.auto_create_battle_entry(
		{"turn": 4, "location": "Test Site", "outcome": "victory"})
	var desc: String = str(_battle_entry().get("description", ""))
	assert_str(desc).contains("Battle log")
	assert_str(desc).contains("Raider eliminated (by Vex)")
	assert_str(desc).contains("Enemy casualties: 1")
	# The journal screen renders a description as BBCode, its export as Markdown.
	assert_str(desc).not_contains("**")
	assert_str(desc).not_contains("###")
	assert_bool(GameStateManager.has_temp_data(KEY)).override_failure_message(
		"one battle's log must not land on the next battle's entry").is_false()


## A Battle Simulator battle is not the campaign's, so it leaves the channel alone.
func test_a_standalone_battle_leaves_the_campaign_channel_alone() -> void:
	GameStateManager.set_temp_data(KEY, "the campaign's battle")
	var ui: Control = await _battle({"title": "Probe", "standalone": true})
	ui.unified_log.log_enemy_casualty("Raider", "Vex")
	assert_str(str(GameStateManager.get_temp_data(KEY, ""))).is_equal(
		"the campaign's battle")


## A new campaign battle replaces an earlier battle's log rather than adding to it.
func test_a_new_battle_replaces_an_earlier_log() -> void:
	GameStateManager.set_temp_data(KEY, "Battle log\nRound 1\n• Old casualty")
	await _battle({"title": "Probe"})
	assert_str(str(GameStateManager.get_temp_data(KEY, ""))).not_contains("Old casualty")
