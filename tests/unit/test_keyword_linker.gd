extends GdUnitTestSuite
## KeywordLinker static helper tests
##
## Exercises BBCode building functions and KeywordDB-driven wrapping.
## Runtime tooltip dispatch (meta_clicked → KeywordTooltip.show_for_keyword) is
## smoke-tested via MCP; these tests cover the pure transformations.
## gdUnit4 v6.0.3 compatible.

const KeywordLinkerScript := preload("res://src/ui/components/tooltips/KeywordLinker.gd")

# Store original KeywordDB data to restore after tests
var _original_keywords: Dictionary = {}

func before():
	# Snapshot KeywordDB state — wrap_known_keywords depends on its contents
	_original_keywords = KeywordDB.keywords.duplicate(true)

func after():
	KeywordDB.keywords = _original_keywords

func before_test():
	# Reset KeywordDB to a known small set so wrap_known_keywords assertions
	# are reproducible regardless of data/keywords.json contents.
	KeywordDB.keywords.clear()
	var heavy := KeywordDB.KeywordData.new(
		"Heavy", "-1 to Hit if firer moved this round", [], 51, "weapon_trait")
	var pistol := KeywordDB.KeywordData.new(
		"Pistol", "+1 to Brawling rolls", [], 51, "weapon_trait")
	KeywordDB.keywords["heavy"] = heavy
	KeywordDB.keywords["pistol"] = pistol


func test_build_traits_bbcode_wraps_multiple_terms_with_color_and_meta() -> void:
	var result: String = KeywordLinkerScript.build_traits_bbcode(["Pistol", "Heavy"])
	# Both traits get rendered as colored, clickable spans with "keyword:" prefix
	assert_str(result).contains("[url=keyword:Pistol]")
	assert_str(result).contains("[url=keyword:Heavy]")
	assert_str(result).contains("[color=#4FC3F7]")
	# Joined by ", "
	assert_str(result).contains(", ")


func test_build_traits_bbcode_returns_empty_on_empty_input() -> void:
	# Typed Array parameter does not accept null in Godot 4.6 (parse error);
	# empty-array path is the only callable degenerate case.
	assert_str(KeywordLinkerScript.build_traits_bbcode([])).is_equal("")


func test_build_traits_bbcode_skips_empty_strings() -> void:
	# Empty / whitespace-only entries should be skipped, not rendered as bare commas
	var result: String = KeywordLinkerScript.build_traits_bbcode(["Pistol", "", "Heavy", "   "])
	assert_str(result).contains("[url=keyword:Pistol]")
	assert_str(result).contains("[url=keyword:Heavy]")
	# Should be exactly one separator between the two real terms
	assert_int(result.count(", ")).is_equal(1)


func test_build_keyword_link_for_single_term() -> void:
	var result: String = KeywordLinkerScript.build_keyword_link("Stun")
	assert_str(result).is_equal("[url=keyword:Stun][color=#4FC3F7]Stun[/color][/url]")

	# Whitespace handling
	assert_str(KeywordLinkerScript.build_keyword_link("   ")).is_equal("")
	assert_str(KeywordLinkerScript.build_keyword_link("")).is_equal("")


func test_wrap_known_keywords_injects_color_and_keeps_unmatched_text() -> void:
	# "Hand Cannon, Pistol" — "Pistol" is a known trait, "Hand Cannon" is not
	var result: String = KeywordLinkerScript.wrap_known_keywords("Hand Cannon, Pistol")
	# Known term wrapped with color via post-processing
	assert_str(result).contains("[url=pistol]")
	assert_str(result).contains("[color=#4FC3F7]")
	# Unmatched substring still present verbatim
	assert_str(result).contains("Hand Cannon")
