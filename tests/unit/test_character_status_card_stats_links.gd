extends GdUnitTestSuite
## CharacterStatusCard keyword-link stats contract (Sprint 2 F2)
##
## The basic + tier-1 stat strips emit BBCode with [url=keyword:KEY]LABEL[/url]
## links pointing at KeywordDB. This test pins down:
##   1. The stat KEYS used (canonical KeywordDB lookups: combat_skill, etc.)
##   2. The compact LABELS shown to the player (Combat / Tough / React / Savvy)
##   3. Both display paths emit links — not raw stat names
##
## gdUnit4 v6.0.3 compatible. Does not instantiate CharacterStatusCard.gd
## (which is PanelContainer-based and would pull in the .tscn) — verifies the
## KeywordLinker contract that the card relies on instead.

const KeywordLinkerScript := preload("res://src/ui/components/tooltips/KeywordLinker.gd")


func test_build_keyword_link_labeled_emits_compact_label_with_canonical_key() -> void:
	# Combat shown as "Combat" but KeywordDB key is "combat_skill".
	var result: String = KeywordLinkerScript.build_keyword_link_labeled(
		"combat_skill", "Combat")
	assert_bool(result.contains("[url=keyword:combat_skill]")).is_true()
	assert_bool(result.contains("Combat")).is_true()
	# Display label must not collide with the canonical key.
	assert_bool(result.contains("combat_skill]Combat")).is_false()


func test_build_keyword_link_labeled_empty_inputs_return_empty() -> void:
	assert_str(KeywordLinkerScript.build_keyword_link_labeled("", "Combat")
		).is_equal("")
	assert_str(KeywordLinkerScript.build_keyword_link_labeled("combat_skill", "")
		).is_equal("")
	assert_str(KeywordLinkerScript.build_keyword_link_labeled("", "")
		).is_equal("")


func test_all_character_stats_resolvable_via_keyword_linker() -> void:
	# All five Five Parsecs character stats must have working short-label links.
	# This guards against future re-keying breaking the CharacterStatusCard
	# stat strip.
	var stat_map: Dictionary = {
		"combat_skill": "Combat",
		"toughness": "Tough",
		"reactions": "React",
		"savvy": "Savvy",
		"speed": "Speed",
	}
	for key in stat_map.keys():
		var label: String = stat_map[key]
		var bb: String = KeywordLinkerScript.build_keyword_link_labeled(key, label)
		assert_bool(bb.contains("[url=keyword:%s]" % key)
			).override_failure_message(
				"Stat key '%s' label '%s' did not produce a meta URL" % [key, label]
			).is_true()
		assert_bool(bb.contains(label)
			).override_failure_message(
				"Stat key '%s' label '%s' did not include the display label" % [key, label]
			).is_true()
