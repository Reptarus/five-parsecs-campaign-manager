extends GdUnitTestSuite
## Tests for the canonical journal taxonomy.
## Every EntryType enum value must have a label, color, icon, and string alias.
## validate_entry() must warn-but-accept non-canonical fields (backwards compat).

const JET := preload("res://src/core/campaign/JournalEntryTypes.gd")

# ============================================================================
# EntryType — every enum value is fully described
# ============================================================================

func test_every_entry_type_has_label():
	for t in JET.EntryType.values():
		var label: String = JET.TYPE_LABELS.get(t, "")
		assert_that(label.is_empty()).is_false()

func test_every_entry_type_has_color():
	for t in JET.EntryType.values():
		assert_that(JET.TYPE_COLORS.has(t)).is_true()

func test_every_entry_type_has_icon():
	for t in JET.EntryType.values():
		var icon: String = JET.TYPE_ICONS.get(t, "")
		assert_that(icon.is_empty()).is_false()

func test_every_entry_type_has_string_alias():
	for t in JET.EntryType.values():
		assert_that(JET.TYPE_TO_STRING.has(t)).is_true()
		var s: String = JET.TYPE_TO_STRING[t]
		assert_that(JET.STRING_TO_TYPE.get(s, -1)).is_equal(t)

# ============================================================================
# Type round-trip
# ============================================================================

func test_type_from_string_battle():
	assert_that(JET.type_from_string("battle")).is_equal(JET.EntryType.BATTLE)

func test_type_to_string_battle():
	assert_that(JET.type_to_string(JET.EntryType.BATTLE)).is_equal("battle")

func test_type_from_string_unknown_falls_back_to_custom():
	assert_that(JET.type_from_string("nonexistent")).is_equal(JET.EntryType.CUSTOM)

func test_type_to_color_accepts_enum():
	var c: Color = JET.type_to_color(JET.EntryType.BATTLE)
	assert_that(c).is_equal(JET.TYPE_COLORS[JET.EntryType.BATTLE])

func test_type_to_color_accepts_string():
	var c: Color = JET.type_to_color("battle")
	assert_that(c).is_equal(JET.TYPE_COLORS[JET.EntryType.BATTLE])

func test_type_to_color_unknown_returns_default():
	var c: Color = JET.type_to_color("unknown_type")
	assert_that(c).is_equal(JET.DEFAULT_TYPE_COLOR)

func test_type_to_label_known():
	assert_that(JET.type_to_label(JET.EntryType.STORY)).is_equal("Story")

func test_type_to_icon_known():
	assert_that(JET.type_to_icon(JET.EntryType.BATTLE)).is_equal("[B]")

func test_is_canonical_type_known():
	assert_that(JET.is_canonical_type("battle")).is_true()

func test_is_canonical_type_unknown():
	assert_that(JET.is_canonical_type("foo")).is_false()

func test_get_all_type_strings_returns_all_14():
	var all_strs: Array[String] = JET.get_all_type_strings()
	assert_that(all_strs.size()).is_equal(14)
	assert_that(all_strs).contains(["battle", "story", "milestone", "injury"])

# ============================================================================
# Mood — including the 3 Stars-emitted aliases
# ============================================================================

func test_mood_from_string_canonical():
	assert_that(JET.mood_from_string("triumph")).is_equal(JET.Mood.TRIUMPH)

func test_mood_from_string_alias_relieved_to_neutral():
	assert_that(JET.mood_from_string("relieved")).is_equal(JET.Mood.NEUTRAL)

func test_mood_from_string_alias_desperate_to_somber():
	assert_that(JET.mood_from_string("desperate")).is_equal(JET.Mood.SOMBER)

func test_mood_from_string_alias_triumphant_to_triumph():
	assert_that(JET.mood_from_string("triumphant")).is_equal(JET.Mood.TRIUMPH)

func test_mood_from_string_unknown_returns_neutral():
	assert_that(JET.mood_from_string("blah")).is_equal(JET.Mood.NEUTRAL)

func test_mood_to_color_triumph_is_emerald():
	var c: Color = JET.mood_to_color(JET.Mood.TRIUMPH)
	assert_that(c).is_equal(Color("#10B981"))

func test_mood_to_label_known():
	assert_that(JET.mood_to_label(JET.Mood.DEFEAT)).is_equal("Defeat")

# ============================================================================
# Tags — canonical 25-tag set
# ============================================================================

func test_tag_color_canonical():
	var c: Color = JET.tag_color("stars_of_the_story")
	assert_that(c).is_equal(Color("#8B5CF6"))

func test_tag_color_unknown_returns_default():
	var c: Color = JET.tag_color("invented_tag")
	assert_that(c).is_equal(JET.DEFAULT_TAG_COLOR)

func test_tag_label_canonical():
	assert_that(JET.tag_label("stars_of_the_story")).is_equal("Stars of the Story")

func test_tag_label_unknown_falls_back_capitalized():
	## Unknown tags get a humanized fallback: "campaign_setup_v2" → "Campaign Setup V2"
	var lbl: String = JET.tag_label("unknown_tag")
	assert_that(lbl).is_equal("Unknown Tag")

func test_is_canonical_tag_known():
	assert_that(JET.is_canonical_tag("red_zone")).is_true()

func test_is_canonical_tag_unknown():
	assert_that(JET.is_canonical_tag("not_a_tag")).is_false()

func test_get_all_tag_keys_returns_25():
	var keys: Array[String] = JET.get_all_tag_keys()
	assert_that(keys.size()).is_equal(25)
	assert_that(keys).contains([
		"stars_of_the_story", "battle", "red_zone", "milestone",
	])

# ============================================================================
# validate_entry — soft-validate, warn but accept
# ============================================================================

func test_validate_entry_canonical_returns_true():
	var entry: Dictionary = {
		"type": "battle",
		"mood": "triumph",
		"tags": ["battle", "combat"],
	}
	assert_that(JET.validate_entry(entry)).is_true()

func test_validate_entry_unknown_type_returns_false():
	var entry: Dictionary = {
		"type": "invented_type",
		"mood": "neutral",
		"tags": [],
	}
	assert_that(JET.validate_entry(entry)).is_false()

func test_validate_entry_unknown_mood_returns_false():
	var entry: Dictionary = {
		"type": "battle",
		"mood": "ecstatic_with_doom",
		"tags": [],
	}
	assert_that(JET.validate_entry(entry)).is_false()

func test_validate_entry_unknown_tag_returns_false():
	var entry: Dictionary = {
		"type": "battle",
		"mood": "neutral",
		"tags": ["invented_tag"],
	}
	assert_that(JET.validate_entry(entry)).is_false()

func test_validate_entry_alias_mood_accepted():
	## Stars logger emits "relieved" / "desperate" / "triumphant" — must validate.
	var entry: Dictionary = {
		"type": "story",
		"mood": "relieved",
		"tags": ["stars_of_the_story"],
	}
	assert_that(JET.validate_entry(entry)).is_true()

func test_validate_entry_missing_type_does_not_warn():
	## Empty type should not warn (e.g. tag-only filter test fixtures).
	var entry: Dictionary = {"mood": "neutral", "tags": []}
	assert_that(JET.validate_entry(entry)).is_true()

# ============================================================================
# Milestone categories
# ============================================================================

func test_every_milestone_category_has_string_alias():
	for c in JET.MilestoneCategory.values():
		assert_that(JET.MILESTONE_CATEGORY_STRINGS.has(c)).is_true()
		var s: String = JET.MILESTONE_CATEGORY_STRINGS[c]
		assert_that(s.is_empty()).is_false()
