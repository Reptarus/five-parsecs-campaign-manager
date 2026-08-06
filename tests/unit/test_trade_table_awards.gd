extends GdUnitTestSuite
## The Trade Table actually hands something over (Core Rules pp.79-80).
##
## Six entries — rolls 1-3, 7-9, 45-48, 79-81, 82-86 and 87-91, so 23 results in
## 100 — carried `requires_roll` in JSON, had no `items`, and had no case in
## CrewTaskComponent._apply_runtime_rolls_trade(). The dialog printed "Roll once
## on the Loot Table (p.131)" as flavour text and the crew came home with
## nothing. Roughly one Trade action in four was a visible no-op.
##
## Two of them also cite tables the resolver was pointing at the wrong file:
## p.28's Low-Tech Weapon Table and p.29's Gear Table live in gear_database.json
## (the character-creation tables), NOT in the p.131-132 Loot Table.

const CrewTaskComponentClass = preload(
	"res://src/ui/screens/world/components/CrewTaskComponent.gd")

var _comp

func before_test() -> void:
	# MUST be in the tree. The component resolves autoloads by absolute path, and
	# get_node_or_null("/root/X") on a DETACHED node errors and aborts the
	# enclosing function — the test would then measure the trap, not the code.
	_comp = auto_free(CrewTaskComponentClass.new())
	add_child(_comp)

## Every name on one of the pp.28-29 creation D100 tables, read from the file
## rather than sampled. A 40-draw sample does NOT cover a 100-entry table, and
## the first draft of these two cases failed for exactly that reason — reporting
## a correct resolver as broken.
func _creation_table_names(table_name: String) -> Array:
	var file := FileAccess.open("res://data/gear_database.json", FileAccess.READ)
	if not file:
		return []
	var json := JSON.new()
	var parsed: int = json.parse(file.get_as_text())
	file.close()
	if parsed != OK or not json.data is Dictionary:
		return []
	var table: Array = json.data.get("weapon_tables", {}).get(table_name, [])
	var names: Array = []
	for entry in table:
		if entry is Dictionary:
			names.append(str(entry.get("name", "")))
	return names

func _trade_result(entry_name: String) -> Dictionary:
	var result: Dictionary = {
		"name": entry_name, "effect": "", "credits": 0, "xp": 0,
		"items": [], "story_points": 0,
	}
	_comp._apply_runtime_rolls_trade(result, 1)
	return result

# ── The six entries that awarded nothing ────────────────────────────────────

func test_a_personal_weapon_awards_an_item() -> void:
	assert_array(_trade_result("A personal weapon")["items"]).is_not_empty()

func test_find_something_useful_awards_an_item() -> void:
	assert_array(_trade_result("Find something useful")["items"]).is_not_empty()

func test_something_interesting_awards_an_item() -> void:
	assert_array(_trade_result("Something interesting")["items"]).is_not_empty()

func test_blinking_lights_awards_an_item() -> void:
	assert_array(_trade_result("A lot of blinking lights")["items"]).is_not_empty()

func test_gently_used_awards_a_damaged_item() -> void:
	var items: Array = _trade_result("Gently used")["items"]
	assert_array(items).is_not_empty()
	# "damaged" in the string is what _add_item_to_stash reads to set
	# condition = "damaged" (p.80: "The item is damaged and needs Repair").
	assert_str(str(items[0])).contains("damaged")

func test_pre_owned_awards_a_damaged_item() -> void:
	var items: Array = _trade_result("Pre-owned")["items"]
	assert_array(items).is_not_empty()
	assert_str(str(items[0])).contains("damaged")

## Negative control: an entry the book pays in credits must NOT gain an item,
## or the six assertions above would pass against a function that stuffs an item
## into every result.
func test_a_credit_entry_still_awards_no_item() -> void:
	assert_array(_trade_result("Contraband")["items"]).is_empty()

# ── The two entries that cited the wrong table ──────────────────────────────

## p.79 roll 1-3 sends you to the p.28 Low-Tech Weapon Table. The resolver used
## to pull from the LOOT table's melee_weapons subtable, so "A personal weapon"
## handed over a Power Claw, Suppression Maul, Glare Sword or Ripper Sword —
## none of which are on p.28, and all of which are far better than what the book
## awards there.
func test_low_tech_weapon_resolves_off_the_p28_table() -> void:
	var p28_names: Array = _creation_table_names("low_tech_weapon")
	assert_array(p28_names).is_not_empty()

	var resolved: Array = []
	for _i in range(40):
		resolved.append_array(_comp._resolve_random_loot("Low Tech Weapon (random)"))
	assert_array(resolved).is_not_empty()
	for name in resolved:
		assert_bool(p28_names.has(str(name))).override_failure_message(
			"'%s' is not on the p.28 Low-Tech Weapon Table" % name).is_true()

## p.79 roll 7-9 sends you to the p.29 Gear Table, which is a different table
## from the p.132 Gear subsection of the Loot Table that "Gear Loot" resolves.
func test_gear_table_resolves_off_the_p29_table() -> void:
	var p29_names: Array = _creation_table_names("gear")
	assert_array(p29_names).is_not_empty()

	var resolved: Array = []
	for _i in range(40):
		resolved.append_array(_comp._resolve_random_loot("Gear Table (random)"))
	assert_array(resolved).is_not_empty()
	for name in resolved:
		assert_bool(p29_names.has(str(name))).override_failure_message(
			"'%s' is not on the p.29 Gear Table" % name).is_true()

## And the p.132 Gear subsection still resolves off the LOOT table — the two
## must not collapse into one.
func test_gear_loot_still_resolves_off_the_loot_table() -> void:
	var resolved: Array = _comp._resolve_random_loot("Gear Loot (random)")
	assert_array(resolved).is_not_empty()
	assert_str(str(resolved[0])).is_not_equal("Gear Loot (random)")
