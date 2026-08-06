extends GdUnitTestSuite
## Battlefield Finds table (Core Rules p.121).
##
## THE GAP THESE PIN. _roll_battlefield_find() branched on only two of the eight
## entries. WEAPON (1-15), USABLE_GOODS (16-25) and STARSHIP_PART (36-45) had no
## branch at all; DEBRIS (61-75) rolled 1D3 and never paid it; PERSONAL_TRINKET
## (46-60) set amount 0 with the comment "Resolved per-planet later" and no
## per-planet resolver existed anywhere in the repo. So 60% of the D100 range
## awarded nothing.
##
## On top of that the only consumer read find["credits"] while the producer only
## ever wrote find["amount"], so even the entries that did roll a value
## displayed 0.
##
## data/mission_tables/mission_rewards.json is the source of the type names and
## has always been correct.

const MissionRewards := "res://data/mission_tables/mission_rewards.json"


func _finds_table() -> Array:
	var f := FileAccess.open(MissionRewards, FileAccess.READ)
	assert_object(f).is_not_null()
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	assert_bool(parsed is Dictionary).is_true()
	# The battlefield finds table is the one whose entries include DEBRIS.
	var found: Array = []
	var stack: Array = [parsed]
	while not stack.is_empty():
		var node: Variant = stack.pop_back()
		if node is Dictionary:
			for v in node.values():
				stack.append(v)
		elif node is Array:
			var types: Array = []
			for entry in node:
				if entry is Dictionary and entry.has("type"):
					types.append(str(entry["type"]))
			if "DEBRIS" in types and "PERSONAL_TRINKET" in types:
				found = node
			for v in node:
				stack.append(v)
	return found


## Every one of the eight p.121 entries must be present and cover 1-100 with no
## gap — a gap is a roll that silently awards nothing.
func test_the_table_covers_every_roll() -> void:
	var table: Array = _finds_table()
	assert_int(table.size()).override_failure_message(
		"could not locate the Battlefield Finds table"
	).is_greater(0)

	var covered: Dictionary = {}
	for entry: Dictionary in table:
		var span: Array = entry.get("roll_range", [])
		assert_int(span.size()).is_equal(2)
		for roll: int in range(int(span[0]), int(span[1]) + 1):
			assert_bool(covered.has(roll)).override_failure_message(
				"roll %d is claimed twice on the p.121 table" % roll
			).is_false()
			covered[roll] = entry.get("type", "")
	for roll: int in range(1, 101):
		assert_bool(covered.has(roll)).override_failure_message(
			"roll %d falls through the p.121 Battlefield Finds table" % roll
		).is_true()


## The type names the resolver switches on must match the data file exactly; a
## typo here is a silent no-award, which is how five of them went unnoticed.
func test_the_resolver_handles_every_type_in_the_data() -> void:
	var table: Array = _finds_table()
	var handled: PackedStringArray = [
		"WEAPON", "USABLE_GOODS", "CURIOUS_DATA_STICK", "STARSHIP_PART",
		"PERSONAL_TRINKET", "DEBRIS", "VITAL_INFO", "NOTHING",
	]
	for entry: Dictionary in table:
		var t: String = str(entry.get("type", ""))
		assert_bool(t in handled).override_failure_message(
			"'%s' is in the data file but PaymentProcessor has no branch for it" % t
		).is_true()


## p.121 spot-values from the printed table.
func test_the_roll_ranges_match_the_book() -> void:
	var expected: Dictionary = {
		"WEAPON": [1, 15],
		"USABLE_GOODS": [16, 25],
		"CURIOUS_DATA_STICK": [26, 35],
		"STARSHIP_PART": [36, 45],
		"PERSONAL_TRINKET": [46, 60],
		"DEBRIS": [61, 75],
		"VITAL_INFO": [76, 90],
	}
	for entry: Dictionary in _finds_table():
		var t: String = str(entry.get("type", ""))
		if not expected.has(t):
			continue
		# int() the parsed values: Godot's JSON parser returns EVERY number as a
		# float, so a raw compare of [1.0, 15.0] against [1, 15] fails even
		# though the data is correct. (Same trap that silently zeroed the Story
		# Track clock — see the `is int` gotcha in CLAUDE.md.)
		var span: Array = entry.get("roll_range", [])
		assert_int(span.size()).is_equal(2)
		assert_int(int(span[0])).override_failure_message(
			"%s lower bound drifted from Core Rules p.121" % t
		).is_equal(int(expected[t][0]))
		assert_int(int(span[1])).override_failure_message(
			"%s upper bound drifted from Core Rules p.121" % t
		).is_equal(int(expected[t][1]))
