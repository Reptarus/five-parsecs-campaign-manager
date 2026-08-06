extends GdUnitTestSuite
## All seventeen Victory Conditions on Core Rules p.64 must be achievable.
##
## The wizard offered all seventeen — data/campaign_config.json matches the book
## exactly — but VictoryChecker mapped only nine. The other eight fell through to
## NONE, so a campaign built around one could never be won and reported "No
## victory condition set" forever.
##
## Godot Dictionaries preserve insertion order and the checker read keys()[0], so
## an unmapped condition clicked FIRST also nullified an achievable one clicked
## afterwards. The wizard is single-select now (p.64: "you can only achieve that
## selected condition"), which removes that interaction at the source.

const VictoryChecker = preload("res://src/core/victory/VictoryChecker.gd")

const CONFIG_PATH := "res://data/campaign_config.json"

func _all_condition_keys() -> Array:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	var json := JSON.new()
	assert_int(json.parse(f.get_as_text())).is_equal(OK)
	var vc: Dictionary = (json.data as Dictionary).get("victory_conditions", {})
	return vc.keys()

func test_the_book_offers_seventeen_conditions() -> void:
	assert_int(_all_condition_keys().size()).override_failure_message(
		"Core Rules p.64 lists exactly 17 Victory Conditions"
	).is_equal(17)

func test_every_offered_condition_maps_to_a_real_enum() -> void:
	var none: int = GlobalEnums.FiveParsecsCampaignVictoryType.NONE
	var unmapped: Array = []
	for key in _all_condition_keys():
		if VictoryChecker._map_condition_key_to_enum(str(key)) == none:
			unmapped.append(str(key))
	assert_array(unmapped).override_failure_message(
		"these conditions are offered by the wizard but map to NONE, so a campaign built on one can never be won: %s"
		% str(unmapped)
	).is_empty()

func test_each_condition_maps_to_a_DISTINCT_enum() -> void:
	# Two keys sharing an enum would silently make one win the other's campaign.
	var seen := {}
	for key in _all_condition_keys():
		var mapped: int = VictoryChecker._map_condition_key_to_enum(str(key))
		assert_bool(seen.has(mapped)).override_failure_message(
			"\"%s\" maps to the same enum as \"%s\"" % [str(key), str(seen.get(mapped, ""))]
		).is_false()
		seen[mapped] = str(key)

func test_an_unknown_key_still_resolves_to_none() -> void:
	assert_int(VictoryChecker._map_condition_key_to_enum("not_a_condition")) \
		.is_equal(GlobalEnums.FiveParsecsCampaignVictoryType.NONE)

# ── The new conditions report progress instead of "no condition set" ─────

class _StubCampaign extends RefCounted:
	var victory_conditions: Dictionary = {}
	var progress_data: Dictionary = {}
	var difficulty: int = 0
	var credits: int = 0
	var reputation: int = 0
	var story_points: int = 0

func _campaign_with(key: String, progress: Dictionary = {}, diff: int = 0):
	var c := _StubCampaign.new()
	c.victory_conditions = {key: {"name": key}}
	c.progress_data = progress
	c.difficulty = diff
	return c

func test_unique_kill_conditions_report_progress() -> void:
	var c = _campaign_with("unique_kills_10", {"unique_individuals_killed": 4})
	var result: Dictionary = VictoryChecker.check_victory(c, 1)
	assert_bool(result.get("achieved", true)).is_false()
	assert_str(str(result.get("message", ""))).override_failure_message(
		"an offered condition must report progress, not 'No victory condition set'"
	).contains("4 / 10")

func test_unique_kill_condition_can_be_achieved() -> void:
	var c = _campaign_with("unique_kills_10", {"unique_individuals_killed": 10})
	assert_bool(VictoryChecker.check_victory(c, 1).get("achieved", false)).is_true()

func test_character_upgrade_conditions_count_characters_not_upgrades() -> void:
	# p.64: three characters each reaching 10 Upgrades satisfies "Upgrade 3
	# Characters 10 Times" — and they need not be alive or contemporaries.
	var c = _campaign_with("upgrade_3x10", {"characters_upgraded_10": 3})
	assert_bool(VictoryChecker.check_victory(c, 1).get("achieved", false)).is_true()
	var short = _campaign_with("upgrade_5x10", {"characters_upgraded_10": 3})
	assert_bool(VictoryChecker.check_victory(short, 1).get("achieved", true)).is_false()

func test_difficulty_locked_conditions_require_that_mode() -> void:
	# "Play 50 campaign turns in Hardcore mode" must not be satisfiable by 50
	# turns on Normal.
	var wrong_mode = _campaign_with("hardcore_50", {},
		GlobalEnums.DifficultyLevel.NORMAL)
	assert_bool(VictoryChecker.check_victory(wrong_mode, 50).get("achieved", true)) \
		.override_failure_message("50 turns on Normal must not win the Hardcore condition") \
		.is_false()
	var right_mode = _campaign_with("hardcore_50", {},
		GlobalEnums.DifficultyLevel.HARDCORE)
	assert_bool(VictoryChecker.check_victory(right_mode, 50).get("achieved", false)) \
		.is_true()

func test_a_mapped_condition_is_never_reported_as_unset() -> void:
	# The old failure mode, checked for every key the wizard can produce.
	for key in _all_condition_keys():
		var c = _campaign_with(str(key))
		var msg: String = str(VictoryChecker.check_victory(c, 1).get("message", ""))
		assert_str(msg).override_failure_message(
			"\"%s\" reported: %s" % [str(key), msg]
		).is_not_equal("No victory condition set")
