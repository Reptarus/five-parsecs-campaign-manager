extends GdUnitTestSuite

## The character editor must show the character it was opened on.
##
## FOUND ON THE DEPLOY #19 DEVICE WALK (Sep 5 2026). Opening Edit Member on a crew
## member whose background was "Comfortable Megacity Class" showed
## "Peaceful High Tech Colony" in the Background dropdown, while the preview beside it
## correctly read "Comfortable Megacity". Class and Motivation were right; only
## Background was wrong, which is what made it look like a one-off rather than a rule.
##
## CAUSE: `CharacterCreator._find_item_by_value()` matched a stored enum KEY against the
## dropdown's DISPLAY LABEL, and returned index 0 when nothing matched. That works only
## while every label is a word-for-word transcription of its enum member, and three of
## the 25 book backgrounds are not — the label carries the book's wording while the enum
## member is abbreviated:
##
##     "Giant Overcrowded Dystopian City"  vs  GIANT_OVERCROWDED_CITY
##     "War Torn Hell Hole"                vs  WAR_TORN_HELLHOLE
##     "Comfortable Megacity Class"        vs  COMFORTABLE_MEGACITY
##
## The failure was quiet in the worst way: index 0 is a VALID index naming a REAL
## background, so the form showed a plausible wrong answer rather than an obvious blank.
##
## WHY IT IS TESTED THROUGH THE REAL SCENE. A test that only compared BACKGROUND_ITEMS
## against GlobalEnums would assert a data relationship and would still pass with the fix
## reverted — the discriminating-fixture trap. These cases instantiate the real
## CharacterCreator scene, so they run the real dropdowns built by the real
## _populate_dropdowns(), and reverting _find_item_by_value fails them.

const CREATOR_SCENE := preload("res://src/ui/screens/character/CharacterCreator.tscn")
const CreatorScript := preload("res://src/core/character/Generation/CharacterCreator.gd")

## The three entries whose label is not a transcription of the enum member. Named
## explicitly so that if someone reworders a label to match its enum, this list going
## stale is visible rather than silently reducing what the suite covers.
const KNOWN_DIVERGENT := ["GIANT_OVERCROWDED_CITY", "WAR_TORN_HELLHOLE",
	"COMFORTABLE_MEGACITY"]


## Built from the SCENE, in the tree: the dropdowns are `%`-unique scene nodes populated
## by _ready(), so a bare .new() would leave background_options null and the cases would
## measure nothing.
func _creator() -> Node:
	var c: Node = CREATOR_SCENE.instantiate()
	add_child(c)
	auto_free(c)
	return c


func test_every_background_selects_its_own_row_not_a_plausible_neighbour() -> void:
	var c := _creator()
	var btn: OptionButton = c.background_options
	assert_int(btn.item_count).override_failure_message(
		"the Background dropdown is empty, so this suite would pass vacuously"
	).is_greater(0)

	var wrong: PackedStringArray = []
	for entry in CreatorScript.BACKGROUND_ITEMS:
		var ordinal: int = int(entry[1])
		var stored_key: String = GlobalEnums.to_string_value("background", ordinal)
		var idx: int = c._find_item_by_value(btn, stored_key, "background")
		var got_id: int = btn.get_item_id(idx)
		if got_id != ordinal:
			wrong.append("%s -> showed '%s' (id %d), expected '%s' (id %d)" % [
				stored_key, btn.get_item_text(idx), got_id, str(entry[0]), ordinal])

	assert_int(wrong.size()).override_failure_message(
		"A stored background must select ITS OWN dropdown row. Each line below is a "
		+ "character who would open the editor showing someone else's background:\n  "
		+ "\n  ".join(wrong)
	).is_equal(0)


func test_the_three_divergent_labels_are_exactly_the_ones_text_matching_misses() -> void:
	## Pins the PREMISE of the fix, so the cause stays documented in an executable form.
	## If a label is reworded, this fails and points at KNOWN_DIVERGENT rather than
	## letting the suite quietly stop covering the interesting rows.
	var found: PackedStringArray = []
	for entry in CreatorScript.BACKGROUND_ITEMS:
		var label: String = str(entry[0])
		var ordinal: int = int(entry[1])
		var member: String = GlobalEnums.to_string_value("background", ordinal)
		var normalised: String = label.to_upper().replace(" ", "_").replace("'", "")
		if normalised != member:
			found.append(member)

	var expected := PackedStringArray(KNOWN_DIVERGENT)
	found.sort()
	expected.sort()
	assert_array(Array(found)).override_failure_message(
		"The set of labels that plain text-normalisation cannot resolve has changed. "
		+ "That is not automatically a bug — but update KNOWN_DIVERGENT deliberately, "
		+ "and never by making a label stop matching the BOOK's wording."
	).is_equal(Array(expected))


func test_class_and_motivation_also_round_trip() -> void:
	## Both transcribe cleanly today, so these pass with or without the fix. They are
	## here as the OTHER direction: without them, a "fix" that broke class or motivation
	## while repairing background would still look green.
	var c := _creator()
	for pair in [
		[c.class_options, CreatorScript.CLASS_ITEMS, "character_class"],
		[c.motivation_options, CreatorScript.MOTIVATION_ITEMS, "motivation"],
	]:
		var btn: OptionButton = pair[0]
		var items: Array = pair[1]
		var enum_name: String = pair[2]
		for entry in items:
			var ordinal: int = int(entry[1])
			var stored_key: String = GlobalEnums.to_string_value(enum_name, ordinal)
			var idx: int = c._find_item_by_value(btn, stored_key, enum_name)
			assert_int(btn.get_item_id(idx)).override_failure_message(
				"%s '%s' selected row '%s' instead of '%s'" % [
					enum_name, stored_key, btn.get_item_text(idx), str(entry[0])]
			).is_equal(ordinal)


func test_an_unresolvable_value_still_returns_a_usable_index() -> void:
	## The fallback stays index 0 on purpose — callers pass the result straight to
	## OptionButton.select(), so returning -1 would be worse than a wrong-but-valid row.
	## What changed is that it is no longer SILENT (a debug push_warning names it).
	var c := _creator()
	var idx: int = c._find_item_by_value(c.background_options, "NO_SUCH_BACKGROUND",
		"background")
	assert_int(idx).is_equal(0)
