extends GdUnitTestSuite
## House rules — Core Rules p.65 step 5, "Establish House Rules".
##
## WHAT THIS SUITE USED TO ASSERT, AND WHY THAT WAS WORTHLESS (rewritten
## 2026-09-04). The old version checked that eight rule definitions existed and
## that the data table could be read back. It never once asked whether enabling a
## rule did anything — and it could not have, because
## `HouseRulesHelper.is_enabled()` probed `GameState.is_house_rule_enabled()` and
## `GameStateManager.get_house_rules()`, NEITHER OF WHICH IS DEFINED ANYWHERE, so
## it returned `false` unconditionally. The old suite even had a case named
## `test_helper_is_enabled_returns_false_when_no_game_state`, which passed
## because of the defect rather than in spite of it.
##
## There were TWO independent breaks and either one alone was fatal:
##   1. the accessor above, and
##   2. the creation UI was a free-text TextEdit whose lines were stored straight
##      into `campaign.house_rules`, so "Varied Armaments" never equalled the id
##      "varied_armaments".
##
## SCOPE CHANGE: six of the eight rules were tagged `"source": "Community"` —
## invented mechanics in src/data/, two carrying unsourced numeric values — and
## were removed. Only rules the rulebook prints remain. A player's own house
## rules are recorded as prose in `house_rules_notes`, which is deliberately
## never matched against a rule id.

const HouseRulesHelper = preload("res://src/core/systems/HouseRulesHelper.gd")
const HouseRulesDefinitions = preload("res://src/data/house_rules_definitions.gd")


class StubCampaign extends Resource:
	var house_rules: Array = []
	func get_house_rules() -> Array:
		return house_rules.duplicate()


var _saved_campaign: Variant = null


func before_test() -> void:
	# One object per case. A suite-level `before()` would share this across
	# cases and let one case's rules leak into the next.
	var gs := _game_state()
	if gs:
		_saved_campaign = gs.current_campaign


func after_test() -> void:
	var gs := _game_state()
	if gs:
		gs.current_campaign = _saved_campaign


func _game_state() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/GameState")
	return null


func _with_rules(rules: Array) -> void:
	var gs := _game_state()
	assert_object(gs).override_failure_message(
		"GameState autoload is required to exercise the real read path"
	).is_not_null()
	var c := StubCampaign.new()
	c.house_rules = rules
	gs.current_campaign = c


# --- the table only holds rules the book prints ---------------------------

func test_only_book_cited_rules_remain() -> void:
	var rules: Array[Dictionary] = HouseRulesDefinitions.get_all_rules()
	assert_int(rules.size()).override_failure_message(
		"only rules printed in a rulebook belong in this table"
	).is_equal(2)
	var ids := HouseRulesDefinitions.get_all_rule_ids()
	assert_array(ids).contains(["varied_armaments", "wild_galaxy"])


func test_no_rule_is_sourced_to_community() -> void:
	# The six removed rules were all tagged "Community": invented mechanics
	# sitting in src/data/ with no book page. Guard the door behind them.
	for rule: Dictionary in HouseRulesDefinitions.get_all_rules():
		var source: String = str(rule.get("source", ""))
		assert_str(source).override_failure_message(
			"rule '%s' has source '%s' — every rule here must cite a rulebook page"
				% [rule.get("id", "?"), source]
		).starts_with("Core Rules p.")


func test_every_rule_quotes_the_book() -> void:
	for rule: Dictionary in HouseRulesDefinitions.get_all_rules():
		assert_str(str(rule.get("book_text", ""))).override_failure_message(
			"rule '%s' must carry the book's own wording" % rule.get("id", "?")
		).is_not_empty()


func test_wild_galaxy_cites_the_page_the_rule_is_printed_on() -> void:
	# Cited as p.65 until 2026-09-04. p.65 is the campaign-setup step that
	# invites house rules; the Wild Galaxy optional rule is printed in the World
	# Traits sidebar on p.73 (PDF idx 72).
	var rule: Dictionary = HouseRulesDefinitions.get_rule("wild_galaxy")
	assert_str(str(rule.get("source", ""))).is_equal("Core Rules p.73")


func test_wild_galaxy_says_to_ignore_a_contradictory_second_roll() -> void:
	# The old description said "use both results", which the book does not say.
	var rule: Dictionary = HouseRulesDefinitions.get_rule("wild_galaxy")
	assert_str(str(rule.get("book_text", "")).to_lower()).contains(
		"ignore the second roll")
	assert_str(str(rule.get("description", "")).to_lower()).contains("ignore")


# --- ids vs prose ---------------------------------------------------------

func test_is_known_rule_accepts_ids_and_rejects_prose() -> void:
	assert_bool(HouseRulesDefinitions.is_known_rule("varied_armaments")).is_true()
	assert_bool(HouseRulesDefinitions.is_known_rule("Varied Armaments")).override_failure_message(
		"display text must never count as a rule id — that mismatch is exactly"
		+ " what made the whole feature inert"
	).is_false()
	assert_bool(HouseRulesDefinitions.is_known_rule("brutal_combat")).override_failure_message(
		"a removed Community rule must not be resurrectable by a hand-edited save"
	).is_false()


# --- the accessor, which is the half that was dead ------------------------

func test_an_enabled_rule_id_reads_back_as_enabled() -> void:
	_with_rules(["varied_armaments"])
	assert_bool(HouseRulesHelper.is_enabled("varied_armaments")).override_failure_message(
		"is_enabled() must read the campaign — the owner of house_rules"
	).is_true()


func test_a_rule_that_was_not_selected_is_not_enabled() -> void:
	_with_rules(["varied_armaments"])
	assert_bool(HouseRulesHelper.is_enabled("wild_galaxy")).is_false()


func test_free_text_prose_never_enables_anything() -> void:
	# Legacy campaigns hold exactly this: whatever the old TextEdit captured.
	_with_rules(["Crits do double damage", "Varied Armaments", "wild galaxy"])
	assert_array(HouseRulesHelper.get_enabled_rules()).override_failure_message(
		"prose must be filtered out, not matched"
	).is_empty()
	assert_bool(HouseRulesHelper.is_enabled("varied_armaments")).is_false()
	assert_bool(HouseRulesHelper.is_enabled("wild_galaxy")).is_false()


func test_a_removed_community_rule_cannot_be_switched_on() -> void:
	_with_rules(["brutal_combat", "wealthy_patrons", "narrative_injuries"])
	assert_array(HouseRulesHelper.get_enabled_rules()).is_empty()
	assert_bool(HouseRulesHelper.is_enabled("brutal_combat")).is_false()


func test_duplicates_are_collapsed() -> void:
	_with_rules(["wild_galaxy", "wild_galaxy"])
	assert_int(HouseRulesHelper.get_enabled_rules().size()).is_equal(1)


func test_no_campaign_means_nothing_is_enabled() -> void:
	var gs := _game_state()
	if gs:
		gs.current_campaign = null
	assert_bool(HouseRulesHelper.is_enabled("wild_galaxy")).is_false()
	assert_array(HouseRulesHelper.get_enabled_rules()).is_empty()


func test_an_empty_rule_id_is_never_enabled() -> void:
	_with_rules(["wild_galaxy"])
	assert_bool(HouseRulesHelper.is_enabled("")).is_false()


# --- config persistence (live path) ---------------------------------------
#
# These used to drive src/data/config/CampaignConfig.gd. That class was deleted
# 2026-09-04 as production-dead: nothing in src/ ever referenced it, and the real
# carrier is the plain `local_campaign_config` Dictionary on ExpandedConfigPanel,
# handed downstream through get_campaign_config_data().

func test_config_data_carries_rules_and_notes() -> void:
	## get_campaign_config_data() REBUILDS its result from a fixed key literal
	## (ExpandedConfigPanel.gd:1807-1826), so any key absent from that literal is
	## silently dropped however the panel stored it. house_rules was missing
	## entirely, which is why an enabled rule never reached the campaign. This is
	## the chokepoint, so it is the thing worth asserting.
	var panel = ConfigPanelScript.new()
	auto_free(panel)
	panel._on_house_rule_toggled(true, "wild_galaxy")
	panel.local_campaign_config["house_rules_notes"] = "Rerolls cost a beer."

	var data: Dictionary = panel.get_campaign_config_data()
	assert_array(data.get("house_rules", [])).override_failure_message(
		"the rule id must survive the fixed-key rebuild"
	).contains(["wild_galaxy"])
	assert_str(str(data.get("house_rules_notes", ""))).override_failure_message(
		"the player's own house rules must persist alongside the rule ids,"
		+ " in their own field"
	).is_equal("Rerolls cost a beer.")


func test_config_data_defaults_when_house_rules_absent() -> void:
	# A legacy or hand-edited config carries neither key; both must default
	# safely rather than propagating null into the campaign.
	var panel = ConfigPanelScript.new()
	auto_free(panel)
	panel.local_campaign_config.erase("house_rules")
	panel.local_campaign_config.erase("house_rules_notes")

	var data: Dictionary = panel.get_campaign_config_data()
	assert_array(data.get("house_rules", [])).is_empty()
	assert_str(str(data.get("house_rules_notes", "x"))).is_equal("")



# --- wild_galaxy actually does something (it had ZERO consumers) ----------

const WorldGeneratorRef = preload("res://src/core/campaign/WorldGenerator.gd")


func _roll_traits_many(times: int) -> Array:
	## Returns the trait-count observed across `times` generated worlds.
	var gen = WorldGeneratorRef.new()
	if gen.has_method("_ready"):
		add_child(gen)
		auto_free(gen)
	var counts: Array = []
	for _i in range(times):
		var t: Array = gen._generate_planetary_traits({})
		counts.append(t.size())
	return counts


func test_wild_galaxy_off_gives_exactly_one_trait() -> void:
	# Core Rules p.72 step 4: "Roll D100 on the following table to determine what
	# trait applies to the world." Singular.
	_with_rules([])
	for n: int in _roll_traits_many(25):
		assert_int(n).override_failure_message(
			"a world gets ONE p.72 trait unless Wild Galaxy is on"
		).is_equal(1)


func test_wild_galaxy_on_rolls_a_second_trait() -> void:
	# p.73: "you may opt to roll twice for each world you visit."
	# The second roll can duplicate the first, which is skipped, so this asserts
	# that SOME world in a decent sample came back with two — not that all did.
	_with_rules(["wild_galaxy"])
	var counts: Array = _roll_traits_many(40)
	var with_two: int = 0
	for n: int in counts:
		assert_int(n).override_failure_message(
			"Wild Galaxy rolls twice, so a world has 1 or 2 traits — never %d" % n
		).is_between(1, 2)
		if n == 2:
			with_two += 1
	assert_int(with_two).override_failure_message(
		"Wild Galaxy produced a second trait on 0 of 40 worlds — the rule is"
		+ " not wired (it had zero consumers before 2026-09-04)"
	).is_greater(0)


# --- the picker writes IDS, which was the second fatal cause ---------------

const ConfigPanelScript = preload(
	"res://src/ui/screens/campaign/panels/ExpandedConfigPanel.gd")


func test_the_picker_stores_a_canonical_id_not_display_text() -> void:
	## The old UI was a free-text TextEdit whose lines went straight into
	## campaign.house_rules, so nothing a player typed could ever equal a rule id.
	## Drive the panel's own toggle handler and check what it stores.
	var panel = ConfigPanelScript.new()
	auto_free(panel)

	panel._on_house_rule_toggled(true, "varied_armaments")
	var stored: Array = panel.local_campaign_config.get("house_rules", [])
	assert_array(stored).override_failure_message(
		"the picker must store the canonical id"
	).contains(["varied_armaments"])

	# ...and unticking removes it rather than leaving a stale entry.
	panel._on_house_rule_toggled(false, "varied_armaments")
	assert_array(panel.local_campaign_config.get("house_rules", [])).is_empty()


func test_the_picker_never_stores_an_unknown_id() -> void:
	# Guards a hand-edited or legacy config from re-enabling a removed rule.
	var panel = ConfigPanelScript.new()
	auto_free(panel)
	panel.local_campaign_config["house_rules"] = ["brutal_combat", "prose line"]
	panel._on_house_rule_toggled(true, "wild_galaxy")
	var stored: Array = panel.local_campaign_config.get("house_rules", [])
	assert_array(stored).override_failure_message(
		"only known rule ids may survive a toggle"
	).contains_exactly(["wild_galaxy"])


func test_the_prose_box_writes_a_different_key_entirely() -> void:
	# The two vocabularies must never share an array again.
	var panel = ConfigPanelScript.new()
	auto_free(panel)
	panel.house_rules_edit = TextEdit.new()
	auto_free(panel.house_rules_edit)
	panel.house_rules_edit.text = "Rerolls cost a beer."
	panel._on_house_rules_notes_changed()
	assert_str(str(panel.local_campaign_config.get("house_rules_notes", ""))
		).is_equal("Rerolls cost a beer.")
	assert_array(panel.local_campaign_config.get("house_rules", [])
		).override_failure_message(
			"prose must never land in the mechanical rule list"
		).is_empty()
