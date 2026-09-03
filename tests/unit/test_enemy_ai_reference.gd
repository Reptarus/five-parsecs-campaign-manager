extends GdUnitTestSuite
## Enemy AI: the CORE routine vs the Compendium AI Variations option.
##
## THE DEFECT THIS PINS (Sep 2026 page walk).
## `data/RulesReference/EnemyAI.json` held the COMPENDIUM pp.42-43 "AI VARIATIONS"
## base conditions and 1D6 action tables, VERBATIM, under a Core Rules label —
## a faithful extraction of the WRONG BOOK. Three consumers printed it with no
## DLC gate at all (`TacticalBattleUI._ai_reference_lines`,
## `EnemyAIOracleRouter._get_reference_text` / `_get_d6_table_result`,
## `EnemyIntentPanel`'s D6 mode), so:
##
##   * a player who owned no expansion was told to roll 1D6 for every enemy
##     activation, which the core rules do not do — Core Rules p.42, verbatim:
##     "The default AI is diceless to keep the game moving as quickly as
##     possible"; and
##   * the ACTUAL core AI — seven diceless bullet routines on pp.42-43 — was in
##     the app nowhere. Not dead code: absent code.
##
## Meanwhile the chapter's own API, `roll_ai_behavior()` / `get_ai_behavior()`,
## read `ai_behavior_table` — a key whose value in difficulty_toggles.json was
## the empty array `[]` — and had zero callers between them. So the option a
## player PAID for did nothing, and its rules were being given away for free
## under the wrong name.
##
## Neither census could see this: producer, consumer, key and flag were all
## present and self-consistent. Only diffing the TEXT against the PDF finds it.
##
## gdUnit4 v6.0.3 compatible.

const Toggles = preload("res://src/data/compendium_difficulty_toggles.gd")
const RouterClass = preload("res://src/core/battle/EnemyAIOracleRouter.gd")

const CORE_AI_PATH := "res://data/RulesReference/EnemyAI.json"

## Core Rules p.42: "one of seven broad AI types".
const BOOK_AI_TYPES := [
	"Aggressive", "Cautious", "Tactical", "Defensive", "Rampage", "Beast",
	"Guardian",
]

## Compendium p.42, verbatim: "enemies with the Beast, Rampage, and Guardian AIs
## function as they would currently. No changes are made." So the option's table
## covers exactly the other four.
const VARIATION_TYPES := ["aggressive", "cautious", "tactical", "defensive"]
const UNCHANGED_TYPES := ["Beast", "Rampage", "Guardian"]

var _saved_flag: bool = false
var _saved_owned: bool = false


func _dlc() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


func before_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	_saved_owned = dlc.has_dlc("freelancers_handbook")
	_saved_flag = dlc.is_feature_enabled(dlc.ContentFlag.get("AI_VARIATIONS"))
	# Every case states its own gate, so start from OFF rather than inheriting
	# whatever the previous suite left set.
	dlc.set_feature_enabled(dlc.ContentFlag.get("AI_VARIATIONS"), false)


func after_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.get("AI_VARIATIONS"), _saved_flag)
	dlc.set_dlc_owned("freelancers_handbook", _saved_owned)


func _enable_variations() -> bool:
	var dlc := _dlc()
	if dlc == null:
		return false
	dlc.set_dlc_owned("freelancers_handbook", true)
	dlc.set_feature_enabled(dlc.ContentFlag.get("AI_VARIATIONS"), true)
	return dlc.is_feature_enabled(dlc.ContentFlag.get("AI_VARIATIONS"))


func _core_types() -> Array:
	var f := FileAccess.open(CORE_AI_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	assert_that(parsed is Dictionary).is_true()
	var content: Array = (parsed as Dictionary).get("EnemyAI", {}).get("content", [])
	for section in content:
		if section is Dictionary and str(section.get("title", "")) == "AI Types":
			return section.get("types", [])
	return []


# ── The core data file is core-only ──────────────────────────────────────

func test_all_seven_book_ai_types_are_present() -> void:
	var names: Array = []
	for t in _core_types():
		names.append(str(t.get("name", "")))
	assert_int(names.size()).is_equal(7)
	for wanted in BOOK_AI_TYPES:
		assert_bool(wanted in names).override_failure_message(
			"Core Rules p.42 lists seven AI types; '%s' is missing from %s"
			% [wanted, str(names)]).is_true()


func test_every_core_type_carries_its_book_bullets() -> void:
	for t in _core_types():
		var rules: Array = t.get("core_rules", [])
		assert_array(rules).override_failure_message(
			"AI type '%s' has no core_rules, so its reference card is empty"
			% str(t.get("name", "?"))).is_not_empty()
		assert_int(int(t.get("page", 0))).is_between(42, 43)


func test_the_core_ai_is_diceless() -> void:
	# Core Rules p.42: "The default AI is diceless to keep the game moving as
	# quickly as possible." A die reference anywhere in the core ROUTINES means
	# Compendium text has leaked back into this file.
	#
	# Scoped to core_rules deliberately: the file's _provenance_warning describes
	# the dice tables that were REMOVED, and must be allowed to say so.
	for t in _core_types():
		for bullet in t.get("core_rules", []):
			var text: String = str(bullet).to_lower()
			for banned in ["1d6", "roll", "die ", "dice"]:
				assert_bool(text.contains(banned)).override_failure_message(
					"'%s' bullet mentions '%s' — the core AI is DICELESS (p.42): %s"
					% [str(t.get("name", "?")), banned, str(bullet)]).is_false()


func test_the_core_file_holds_no_compendium_keys() -> void:
	# base_condition / behavior_table are the AI Variations shape. Their presence
	# here is the original defect.
	for t in _core_types():
		for banned_key in ["base_condition", "behavior_table"]:
			assert_bool(t.has(banned_key)).override_failure_message(
				("'%s' still carries '%s' — that is Compendium pp.42-43 data"
				+ " and belongs in data/compendium/difficulty_toggles.json")
				% [str(t.get("name", "?")), banned_key]).is_false()


func test_a_core_bullet_matches_the_book_verbatim() -> void:
	# Core Rules p.43, Aggressive, first bullet. One anchored spot-check so a
	# future "tidy up" of the wording fails a test rather than shipping.
	var found := ""
	for t in _core_types():
		if str(t.get("name", "")) == "Aggressive":
			var rules: Array = t.get("core_rules", [])
			if not rules.is_empty():
				found = str(rules[0])
	assert_str(found).is_equal(
		"Aggressive enemies with opponents in sight will advance at least half a"
		+ " move towards them, attempting to remain in Cover if possible.")


# ── The Compendium option is gated, and is the only source of dice ────────

func test_variations_return_nothing_while_the_option_is_off() -> void:
	assert_bool(Toggles.ai_variations_enabled()).is_false()
	for key in VARIATION_TYPES:
		assert_dict(Toggles.ai_variation_for(key)).override_failure_message(
			"'%s' handed out an AI Variations table with the DLC flag OFF" % key
		).is_empty()
	assert_dict(Toggles.roll_ai_behavior("cautious")).is_empty()
	assert_dict(Toggles.get_ai_behavior("cautious", 3)).is_empty()


func test_the_four_variation_types_have_a_six_row_table_when_enabled() -> void:
	if not _enable_variations():
		return
	for key in VARIATION_TYPES:
		var variation: Dictionary = Toggles.ai_variation_for(key)
		assert_dict(variation).override_failure_message(
			"'%s' has no AI Variations table (Compendium pp.42-43)" % key
		).is_not_empty()
		assert_str(str(variation.get("base_condition", ""))).is_not_empty()
		var actions: Array = variation.get("actions", [])
		assert_int(actions.size()).override_failure_message(
			"'%s' table has %d rows; the book's is 1-6" % [key, actions.size()]
		).is_equal(6)
		var seen: Array = []
		for entry in actions:
			seen.append(int(entry.get("roll", 0)))
		for face in range(1, 7):
			assert_bool(face in seen).override_failure_message(
				"'%s' table has no row for a die result of %d" % [key, face]
			).is_true()


func test_the_three_unchanged_types_have_no_table_even_when_enabled() -> void:
	# p.42: "enemies with the Beast, Rampage, and Guardian AIs function as they
	# would currently. No changes are made." An empty result here is the BOOK'S
	# answer, not a data gap — a future "fix" that invents tables for these three
	# must fail.
	if not _enable_variations():
		return
	for name in UNCHANGED_TYPES:
		assert_dict(Toggles.ai_variation_for(name)).override_failure_message(
			"'%s' was given a variation table; the Compendium leaves it unchanged"
			% name).is_empty()


func test_a_roll_resolves_to_a_row_of_that_types_own_table() -> void:
	if not _enable_variations():
		return
	var row: Dictionary = Toggles.roll_ai_behavior("Cautious")
	assert_dict(row).is_not_empty()
	assert_int(int(row.get("roll", 0))).is_between(1, 6)
	assert_str(str(row.get("action", ""))).is_not_empty()
	assert_str(str(row.get("ai_type", ""))).is_equal("cautious")

	# Cautious 1 is the book's own row. Aggressive 1 differs, which proves the
	# lookup is per-type rather than one shared table.
	var cautious_one: Dictionary = Toggles.get_ai_behavior("cautious", 1)
	assert_str(str(cautious_one.get("action", ""))).is_equal(
		"Retreat a full move, remaining in Cover. Maintain Line of Sight if possible.")
	var aggressive_one: Dictionary = Toggles.get_ai_behavior("aggressive", 1)
	assert_str(str(aggressive_one.get("action", ""))).is_not_equal(
		str(cautious_one.get("action", "")))


func test_letter_codes_resolve_the_same_as_type_names() -> void:
	# Core Rules p.92 prints AI as a letter, and the call sites hold different
	# forms; a mismatch would silently drop the table for a live enemy.
	if not _enable_variations():
		return
	for pair in [["A", "aggressive"], ["C", "cautious"], ["T", "tactical"],
			["D", "defensive"]]:
		var by_code: Dictionary = Toggles.ai_variation_for(str(pair[0]))
		var by_name: Dictionary = Toggles.ai_variation_for(str(pair[1]))
		assert_str(str(by_code.get("base_condition", "x"))).override_failure_message(
			"code '%s' did not resolve to '%s'" % [str(pair[0]), str(pair[1])]
		).is_equal(str(by_name.get("base_condition", "y")))


func test_group_actions_and_the_impossible_action_note_are_available() -> void:
	# p.42's procedure text is what makes the table usable at the table; it was
	# the "Group Actions" section of the core file before this.
	if not _enable_variations():
		return
	var rules: Dictionary = Toggles.AI_VARIATION_RULES
	assert_dict(rules).is_not_empty()
	var group: Array = rules.get("group_actions", [])
	assert_array(group).is_not_empty()
	assert_bool(str(group[0]).contains("2\"")).override_failure_message(
		"Group Actions must state the book's 2\" proximity: %s" % str(group[0])
	).is_true()
	assert_str(str(rules.get("impossible_actions", ""))).contains(
		"inject some logic")


# ── The consumers ─────────────────────────────────────────────────────────

func test_the_reference_card_shows_core_bullets_and_no_dice_by_default() -> void:
	var r = auto_free(RouterClass.new())
	var text: String = r._get_reference_text("Aggressive")
	assert_str(text).contains("Core Rules p.")
	assert_str(text).contains("advance at least half a move")
	assert_bool(text.contains("Otherwise roll 1D6")).override_failure_message(
		"the reference card offered a 1D6 roll with AI Variations OFF: %s" % text
	).is_false()


func test_the_reference_card_appends_the_variation_block_when_enabled() -> void:
	if not _enable_variations():
		return
	var r = auto_free(RouterClass.new())
	var text: String = r._get_reference_text("Aggressive")
	# The core routine stays — the option ADDS to it, it does not replace it.
	assert_str(text).contains("advance at least half a move")
	assert_str(text).contains("AI VARIATIONS (Compendium pp.42-43)")
	assert_str(text).contains("Otherwise roll 1D6")


func test_the_d6_mode_declines_to_roll_while_the_option_is_off() -> void:
	var r = auto_free(RouterClass.new())
	var text: String = r._get_d6_table_result("Cautious", 4)
	assert_str(text).contains("DICELESS")
	assert_bool(text.contains("Action:")).override_failure_message(
		"the D6 mode produced an action with the option OFF: %s" % text
	).is_false()


func test_the_d6_mode_resolves_an_action_when_enabled() -> void:
	if not _enable_variations():
		return
	var r = auto_free(RouterClass.new())
	var text: String = r._get_d6_table_result("Cautious", 1)
	assert_str(text).contains("Action:")
	assert_str(text).contains(
		"Retreat a full move, remaining in Cover. Maintain Line of Sight if possible.")


func test_the_d6_mode_says_so_for_the_three_unchanged_types() -> void:
	if not _enable_variations():
		return
	var r = auto_free(RouterClass.new())
	var text: String = r._get_d6_table_result("Beast", 5)
	assert_str(text).contains("leaves it unchanged")
	# The core routine must still reach the player rather than a bare refusal.
	assert_str(text).contains("nearest opponent")


func test_the_decision_steps_are_a_compendium_feature() -> void:
	# These four steps were an "AI Decision Making" section of the core file and
	# are Compendium p.42's "How to Use the New AI". The core rules have no
	# activation procedure beyond each type's bullets.
	var r = auto_free(RouterClass.new())
	assert_array(r.get_decision_steps()).is_empty()
	if not _enable_variations():
		return
	var steps: Array = r.get_decision_steps()
	assert_array(steps).is_not_empty()
	var blob: String = " ".join(PackedStringArray(
		steps.map(func(s): return str(s))))
	assert_str(blob).contains("1D6")


func test_targeting_priority_is_gone() -> void:
	# Its three "priorities" appear in NEITHER book — targeting is part of each
	# type's own bullets, and they differ per type (Cautious fights at maximum
	# range; Beast closes). Zero callers, so nothing showed the invented list.
	var r = auto_free(RouterClass.new())
	assert_bool(r.has_method("get_targeting_priority")).override_failure_message(
		"get_targeting_priority() is back — its content is not in either rulebook"
	).is_false()
