extends GdUnitTestSuite

## Combat log panel tests (rewritten 2026-07-02).
##
## The original 21-case suite asserted a "Phase 4.2 post-roll explanation"
## message format ("HIT! Rolled 5 vs 5+"...) that combat_log_panel.gd never
## implemented — roll explanations shipped in the assisted-roll panels
## (CharacterQuickRollPanel / BrawlResolverPanel bbcode breakdowns) instead.
## Those cases are Cut; this suite covers the panel's REAL contract.
##
## It also pins two production fixes found via the old suite's crashes:
## - add_log_entry timestamps now use use_space=true (the default ISO form
##   has no space, so _add_entry_to_list's split(" ")[1] aborted on EVERY
##   entry — the visible list never populated in live battles)
## - all log_list touches are null-guarded for scene-less instantiation

const CombatLogPanel := preload(
	"res://src/ui/components/combat/log/combat_log_panel.gd")

var log_panel


func before_test() -> void:
	log_panel = auto_free(CombatLogPanel.new())
	log_panel.max_entries = 50
	add_child(log_panel)


func test_add_log_entry_records_entry() -> void:
	log_panel.add_log_entry("combat", "Test message", {"key": "value"})
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["type"]).is_equal("combat")
	assert_str(entry["message"]).is_equal("Test message")
	assert_str(str(entry["details"].get("key", ""))).is_equal("value")


func test_timestamp_has_space_separator() -> void:
	# Pins the split(" ")[1] abort fix: timestamps must be "date time" form
	log_panel.add_log_entry("combat", "stamp check")
	var stamp: String = str(log_panel.log_entries[0]["timestamp"])
	assert_bool(" " in stamp).is_true()


func test_max_entries_trims_oldest() -> void:
	log_panel.max_entries = 3
	for i in range(5):
		log_panel.add_log_entry("combat", "entry %d" % i)
	assert_int(log_panel.log_entries.size()).is_equal(3)
	assert_str(log_panel.log_entries[0]["message"]).is_equal("entry 2")
	assert_str(log_panel.log_entries[2]["message"]).is_equal("entry 4")


func test_log_combat_result_hit_message() -> void:
	log_panel.log_combat_result("Marine Alpha", "Raider", {
		"hit": true, "damage": 2, "effects": ["stun"]})
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var msg: String = log_panel.log_entries[0]["message"]
	assert_str(msg).contains("Marine Alpha")
	assert_str(msg).contains("Raider")
	assert_str(msg).contains("Hit!")
	assert_str(msg).contains("2 damage")
	assert_str(msg).contains("stun")


func test_log_combat_result_miss_message() -> void:
	log_panel.log_combat_result("Marine Alpha", "Raider", {"hit": false})
	var msg: String = log_panel.log_entries[0]["message"]
	assert_str(msg).contains("Miss!")


func test_clear_log_empties_entries_and_signals() -> void:
	log_panel.add_log_entry("combat", "to be cleared")
	var cleared := [false]
	log_panel.log_cleared.connect(func(): cleared[0] = true)
	log_panel.clear_log()
	assert_int(log_panel.log_entries.size()).is_equal(0)
	assert_bool(cleared[0]).is_true()


func test_scene_less_instantiation_does_not_abort() -> void:
	# The panel script without its scene (@onready nodes null) must still
	# keep bookkeeping working — every log_list touch is null-guarded.
	for i in range(3):
		log_panel.add_log_entry("combat", "no-scene entry %d" % i)
	log_panel.clear_log()
	assert_int(log_panel.log_entries.size()).is_equal(0)
