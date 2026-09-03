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

# ── The two tallies those conditions read now have PRODUCERS ─────────────
#
# THE DEFECT THIS PINS (Sep 2026 page walk). Every case above proves the
# conditions REPORT correctly when handed a number. Nothing produced the number.
# `GameStateManager.increment_unique_individual_kills()` and
# `record_character_upgrade_milestone()` both had ZERO callers, and no
# per-character upgrade count existed anywhere in the codebase — so five of the
# seventeen conditions sat at 0/N for the entire life of every campaign, however
# many Unique Individuals the crew killed or however much XP they spent.
#
# That is the classic shape in this project: a consumer reading a key no producer
# writes. A test on the CHECKER is blind to it, which is exactly why these live
# here beside the checker cases.

const AdvancementService = preload("res://src/core/services/CharacterAdvancementService.gd")
const CTC_SRC := "res://src/ui/screens/campaign/CampaignTurnController.gd"
const ADV_PANEL_SRC := "res://src/ui/screens/campaign/phases/AdvancementPhasePanel.gd"

func _gsm() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager")

func _read_src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot read %s" % path).is_not_null()
	var text: String = f.get_as_text()
	f.close()
	return text

func test_a_character_carries_a_persisted_upgrade_count() -> void:
	# Round-trip, because the milestone is banked per character and a count that
	# does not survive a save/load would silently reset every session.
	var c: Character = Character.new()
	c.character_name = "Upgrade Round Trip"
	c.character_upgrades = 7
	var reloaded: Character = Character.new()
	reloaded.from_dictionary(c.to_dictionary())
	assert_int(reloaded.character_upgrades).override_failure_message(
		"character_upgrades did not survive to_dictionary/from_dictionary"
	).is_equal(7)

func test_record_character_upgrade_counts_on_both_crew_shapes() -> void:
	# A fresh campaign holds Character Resources; a loaded save holds
	# Dictionaries. Counting on only one is how half the campaigns would miss it.
	var gsm := _gsm()
	if gsm == null:
		return
	var as_dict: Dictionary = {"character_upgrades": 0}
	assert_int(gsm.record_character_upgrade(as_dict)).is_equal(1)
	assert_int(int(as_dict["character_upgrades"])).is_equal(1)

	var as_res: Character = Character.new()
	assert_int(gsm.record_character_upgrade(as_res)).is_equal(1)
	assert_int(as_res.character_upgrades).is_equal(1)

func test_the_milestone_fires_once_on_the_tenth_upgrade() -> void:
	# p.64 counts CHARACTERS who reached ten upgrades, so the campaign tally must
	# move exactly once per character — not on every upgrade after the tenth.
	var gsm := _gsm()
	if gsm == null:
		return
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	if gs == null:
		return
	var saved = gs.current_campaign
	var campaign := FiveParsecsCampaignCore.new()
	gs.current_campaign = campaign

	var member: Dictionary = {"character_upgrades": 0}
	for _i in range(13):
		gsm.record_character_upgrade(member)
	assert_int(int(member["character_upgrades"])).is_equal(13)
	assert_int(int(campaign.progress_data.get("characters_upgraded_10", 0))) \
		.override_failure_message(
			"thirteen upgrades on ONE character must bank exactly one milestone"
		).is_equal(1)

	# A second character reaching ten banks a second.
	var other: Dictionary = {"character_upgrades": 9}
	gsm.record_character_upgrade(other)
	assert_int(int(campaign.progress_data.get("characters_upgraded_10", 0))).is_equal(2)

	gs.current_campaign = saved

func test_the_milestone_survives_the_characters_death() -> void:
	# p.64, verbatim: "If one character Upgrades 10 times and dies, all 10
	# Character Upgrades still count." Banking on the campaign rather than
	# computing from the live roster is what makes that true.
	var gsm := _gsm()
	if gsm == null:
		return
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	if gs == null:
		return
	var saved = gs.current_campaign
	var campaign := FiveParsecsCampaignCore.new()
	gs.current_campaign = campaign

	var doomed: Dictionary = {"character_upgrades": 9, "status": "ACTIVE"}
	gsm.record_character_upgrade(doomed)
	doomed["status"] = "DEAD"
	doomed.erase("character_upgrades")  # the character is gone entirely
	assert_int(int(campaign.progress_data.get("characters_upgraded_10", 0))).is_equal(1)

	gs.current_campaign = saved

func test_the_advancement_service_records_an_upgrade() -> void:
	# The service every live Dictionary-crew path goes through. Asserts on the
	# MEMBER, where the damage lands — a source scan would survive the call being
	# commented out.
	#
	# ⚠ The stat key is `combat_skill`, NOT `combat`. An earlier version of this
	# case used "combat", which is not a key in
	# data/character_advancement.json's `advancement_costs`, so advance_stat()
	# returned "Invalid stat name" and the case skipped its own assertion — it
	# passed with the fix REVERTED. Assert the advancement succeeded first, so the
	# case can never go vacuous again.
	var gsm := _gsm()
	if gsm == null:
		return
	var member: Dictionary = {
		"character_name": "Advancer", "experience": 40, "combat_skill": 1,
		"character_upgrades": 0, "is_bot": false,
	}
	var result: Dictionary = AdvancementService.advance_stat(member, "combat_skill")
	assert_bool(bool(result.get("success", false))).override_failure_message(
		"the fixture must actually advance, or this case proves nothing: %s"
		% str(result.get("message", ""))).is_true()
	assert_int(int(member.get("combat_skill", 0))).is_equal(2)
	assert_int(int(member.get("character_upgrades", 0))).override_failure_message(
		"advance_stat() raised a stat without recording a Character Upgrade"
	).is_equal(1)

func test_both_live_advance_paths_call_the_chokepoint() -> void:
	# AdvancementPhasePanel mutates the member directly instead of going through
	# the service, so it needs its OWN call. Without this, the commonest way a
	# player spends XP (the Advancement phase) would not count.
	assert_str(_read_src(ADV_PANEL_SRC)).override_failure_message(
		"AdvancementPhasePanel's STAT branch does not record a Character Upgrade"
	).contains("record_character_upgrade")

func test_the_post_battle_stats_site_tallies_unique_kills() -> void:
	# Anchored on the exact enabling call, not on the words "unique kills": a
	# comment mentioning the rule would satisfy a looser scan.
	assert_str(_read_src(CTC_SRC)).override_failure_message(
		"nothing accumulates unique-individual kills after a battle"
	).contains("gsm.increment_unique_individual_kills(uniques_killed)")

func test_the_unique_kill_tally_reads_the_producers_real_keys() -> void:
	# `was_unique_individual` is what every producer writes on defeated_enemies
	# (`is_unique` is the legacy spelling kept for older results), and
	# `unique_kills` is the crew-id list the results form writes. Reading a key
	# nobody writes is the defect this whole suite exists for.
	var src: String = _read_src(CTC_SRC)
	assert_str(src).contains("was_unique_individual")
	assert_str(src).contains("unique_kills")

func test_the_tally_counts_off_the_stored_battle_result() -> void:
	# `_on_post_battle_completed(results)` receives the POST-BATTLE PROCESSING
	# output, which carries neither key; the battle's own result is the
	# controller's stored `battle_results`. Counting off the parameter would
	# always yield zero.
	var src: String = _read_src(CTC_SRC)
	assert_str(src).override_failure_message(
		"the tally must read battle_results (the stored original), not the results parameter"
	).contains("for enemy in battle_results.get(\"defeated_enemies\", [])")
