extends GdUnitTestSuite
## Core Rules pp.131-134 — the Loot Table's THIRD roll.
##
## p.131, verbatim: "This usually requires three rolls, though the process can be
## sped up by using percentile dice in distinct colors. Roll to determine the
## category, then the subtable, and finally the exact item in question."
##
## Rolls one and two were byte-exact in data/loot_tables.json. Roll three did not
## exist: each leaf subtable stored a flat `items: [name, ...]` list with no
## ranges, and FIVE separate resolvers each picked from it uniformly at random.
## Every printed frequency on pp.131-134 was flattened — a Blade is a 20% melee
## result and paid out at 12.5%; a Suppression Maul is 5% and also paid 12.5%;
## grenades are 60/40 Frakk/Dazzle and came out 50/50; a Stim-pack is 30% of
## consumables and paid 16.7%.
##
## Two kinds of check here, and they catch different regressions:
##   - the DATA tests are deterministic and pin the book (ranges, names, tiling);
##   - the DISTRIBUTION tests prove the resolver actually ROLLS on that data.
##     Data alone would still pass with a uniform picker.
##
## gdUnit4 v6.0.3 compatible.

const LootTableResolverClass = preload("res://src/core/equipment/LootTableResolver.gd")

const LOOT_JSON := "res://data/loot_tables.json"

## The 12 leaf subtables the book prints item ranges for.
const LEAF_CATEGORIES: Array[String] = [
	"slug_weapons", "energy_weapons", "special_weapons", "melee_weapons", "grenades",
	"gun_mods", "gun_sights", "protective_items", "utility_items",
	"consumables", "implants", "ship_items",
]


func _tables() -> Dictionary:
	var f := FileAccess.open(LOOT_JSON, FileAccess.READ)
	assert_that(f).override_failure_message("cannot open %s" % LOOT_JSON).is_not_null()
	var json := JSON.new()
	var ok: int = json.parse(f.get_as_text())
	f.close()
	assert_int(ok).override_failure_message("loot_tables.json does not parse").is_equal(OK)
	return (json.data as Dictionary).get("tables", {})


## Godot's JSON parser returns EVERY number as a float, so a raw `roll_range`
## out of loot_tables.json is `[86.0, 100.0]` and compares unequal to `[86, 100]`.
## Normalise before asserting; never type-test JSON numbers with `is int`.
func _ints(a: Variant) -> Array[int]:
	var out: Array[int] = []
	for v: Variant in (a as Array):
		out.append(int(v))
	return out


## Find one leaf subtable entry by its category name.
func _leaf(category: String) -> Dictionary:
	var t := _tables()
	for parent: String in ["weapon_subtable", "gear_subtable", "odds_and_ends_subtable"]:
		for entry: Variant in t.get(parent, []):
			if entry is Dictionary and str(entry.get("category", "")) == category:
				return entry
	return {}


# ── THE DATA (deterministic) ────────────────────────────────────────────────

## Every leaf subtable must tile 1-100 exactly once. A gap silently swallows a
## roll; an overlap means the earlier entry wins and a printed item is
## unreachable. Both were possible before ranges existed at all.
func test_every_leaf_subtable_tiles_1_to_100() -> void:
	for category: String in LEAF_CATEGORIES:
		var entry := _leaf(category)
		assert_bool(entry.is_empty()).override_failure_message(
			"no leaf subtable '%s' in loot_tables.json" % category).is_false()
		var covered: Array[int] = []
		covered.resize(101)
		covered.fill(0)
		for item: Variant in entry.get("items", []):
			assert_bool(item is Dictionary).override_failure_message(
				"%s still stores flat name strings — the third roll has no data"
				% category).is_true()
			var rng: Array = (item as Dictionary).get("roll_range", [])
			assert_int(rng.size()).override_failure_message(
				"%s/%s has no roll_range" % [category, str((item as Dictionary).get("name", "?"))]
			).is_equal(2)
			for n: int in range(int(rng[0]), int(rng[1]) + 1):
				covered[n] += 1
		for n: int in range(1, 101):
			assert_int(covered[n]).override_failure_message(
				"%s: D100 roll %d is covered %d times (want exactly 1)"
				% [category, n, covered[n]]).is_equal(1)


## Spot-pin the ranges the book prints, for three tables chosen because they are
## the ones the old uniform picker distorted most.
func test_printed_ranges_match_the_book() -> void:
	var expected := {
		# p.132 Grenades Subtable — two rows, 60/40.
		"grenades": {"3 Frakk Grenades": [1, 60], "3 Dazzle Grenades": [61, 100]},
		# p.132 Melee Weapons Subtable — the widest spread, 20% down to 5%.
		"melee_weapons": {
			"Blade": [1, 20], "Brutal Melee Weapon": [21, 40], "Boarding Saber": [41, 55],
			"Ripper Sword": [56, 75], "Shatter Axe": [76, 85], "Power Claw": [86, 90],
			"Glare Sword": [91, 95], "Suppression Maul": [96, 100],
		},
		# p.133 Consumables Subtable — Stim-pack is 30% of the table.
		"consumables": {
			"Booster Pills": [1, 20], "Combat Serum": [21, 30], "Kiranin Crystals": [31, 40],
			"Rage Out": [41, 55], "Still": [56, 70], "Stim-pack": [71, 100],
		},
	}
	for category: String in expected.keys():
		var want: Dictionary = expected[category]
		var got := {}
		for item: Variant in _leaf(category).get("items", []):
			var d: Dictionary = item
			got[str(d.get("name", ""))] = _ints(d.get("roll_range", []))
		assert_int(got.size()).override_failure_message(
			"%s row count changed: %s" % [category, str(got.keys())]).is_equal(want.size())
		for name: String in want.keys():
			assert_array(got.get(name, [])).override_failure_message(
				"%s / %s: book says %s, json says %s"
				% [category, name, str(want[name]), str(got.get(name, []))]
			).is_equal(want[name])


## The first two rolls were already correct and must stay that way — the fix
## touched the same file.
func test_category_and_subtable_rolls_are_unchanged() -> void:
	var t := _tables()
	var main := {}
	for e: Variant in t.get("main_loot", []):
		var d: Dictionary = e
		main[str(d.get("category", ""))] = _ints(d.get("roll_range", []))
	assert_array(main.get("WEAPON", [])).is_equal([1, 25])
	assert_array(main.get("DAMAGED_WEAPONS", [])).is_equal([26, 35])
	assert_array(main.get("DAMAGED_GEAR", [])).is_equal([36, 45])
	assert_array(main.get("GEAR", [])).is_equal([46, 65])
	assert_array(main.get("ODDS_AND_ENDS", [])).is_equal([66, 80])
	assert_array(main.get("REWARDS", [])).is_equal([81, 100])

	var weap := {}
	for e: Variant in t.get("weapon_subtable", []):
		var d: Dictionary = e
		weap[str(d.get("category", ""))] = _ints(d.get("roll_range", []))
	assert_array(weap.get("slug_weapons", [])).is_equal([1, 35])
	assert_array(weap.get("energy_weapons", [])).is_equal([36, 50])
	assert_array(weap.get("special_weapons", [])).is_equal([51, 65])
	assert_array(weap.get("melee_weapons", [])).is_equal([66, 85])
	assert_array(weap.get("grenades", [])).is_equal([86, 100])


# ── THE ROLL (statistical, but not flaky) ───────────────────────────────────
#
# Bounds below are ~7 standard deviations from the book value and ~7 from the
# uniform value, in opposite directions. Under the correct distribution these
# fail with probability ~1e-12; under a uniform picker they fail essentially
# always. That separation is the whole point: a data-only test would pass with
# the bug still in place.

func _sample(category: String, n: int) -> Dictionary:
	var entry := _leaf(category)
	var counts := {}
	for _i in n:
		var name: String = LootTableResolverClass.roll_item_in(entry)
		counts[name] = int(counts.get(name, 0)) + 1
	return counts


func test_melee_frequencies_follow_the_printed_ranges() -> void:
	const N := 6000
	var c := _sample("melee_weapons", N)
	# Blade 1-20 = 20% of the table. Uniform over 8 items would be 12.5%.
	var blade: float = float(c.get("Blade", 0)) / N
	assert_bool(blade > 0.16 and blade < 0.24).override_failure_message(
		"Blade is p.132 rows 1-20 = 20%%, observed %.1f%% over %d rolls."
		% [blade * 100.0, N]
		+ " 12.5%% means the third roll is picking uniformly again.").is_true()
	# Suppression Maul 96-100 = 5%. Uniform would be 12.5% — 2.5x too generous
	# for the best melee weapon in the book.
	var maul: float = float(c.get("Suppression Maul", 0)) / N
	assert_bool(maul > 0.03 and maul < 0.07).override_failure_message(
		"Suppression Maul is p.132 rows 96-100 = 5%%, observed %.1f%%"
		% (maul * 100.0)).is_true()
	assert_int(c.size()).override_failure_message(
		"all 8 melee rows should be reachable, saw %s" % str(c.keys())).is_equal(8)


func test_grenade_split_is_sixty_forty() -> void:
	const N := 6000
	var c := _sample("grenades", N)
	var frakk: float = float(c.get("3 Frakk Grenades", 0)) / N
	assert_bool(frakk > 0.555 and frakk < 0.645).override_failure_message(
		"p.132 Grenades is 1-60 Frakk / 61-100 Dazzle = 60/40; observed %.1f%%"
		% (frakk * 100.0) + " (50%% means a coin flip, i.e. the old uniform pick)"
	).is_true()


func test_stim_pack_is_thirty_percent_of_consumables() -> void:
	const N := 6000
	var c := _sample("consumables", N)
	# 71-100 = 30%. Uniform over 6 items would be 16.7%.
	var stim: float = float(c.get("Stim-pack", 0)) / N
	assert_bool(stim > 0.255 and stim < 0.345).override_failure_message(
		"Stim-pack is p.133 rows 71-100 = 30%%, observed %.1f%%" % (stim * 100.0)).is_true()


## Every item the book prints must be reachable. A range typo that orphans a row
## shows up here rather than as a rare missing item months later.
func test_every_printed_item_is_reachable() -> void:
	for category: String in LEAF_CATEGORIES:
		var entry := _leaf(category)
		var want: int = (entry.get("items", []) as Array).size()
		var seen := {}
		# 60 samples per row is enough that the narrowest band in any table
		# (3 percentage points) is hit with overwhelming probability.
		for _i in want * 60:
			seen[LootTableResolverClass.roll_item_in(entry)] = true
		assert_int(seen.size()).override_failure_message(
			"%s: only %d of %d printed items were reachable — missing %s"
			% [category, seen.size(), want, str(
				(entry.get("items", []) as Array).filter(
					func(i: Variant) -> bool: return not seen.has(str((i as Dictionary).get("name", ""))))
				.map(func(i: Variant) -> String: return str((i as Dictionary).get("name", ""))))]
		).is_equal(want)


# ── ONE IMPLEMENTATION, NOT FIVE ────────────────────────────────────────────

## The procedure had five copies, all wrong the same way, and fixing one would
## have left four shipping. These four files must delegate rather than reach
## into `items` themselves.
##
## Source-level rather than behavioural because that is the actual invariant:
## a future copy-paste is the regression this guards against, and it would pass
## every behavioural test above by accident of calling the shared roller once.
func test_no_resolver_picks_from_the_item_list_itself() -> void:
	var offenders: PackedStringArray = []
	for path: String in [
		"res://src/core/equipment/LootTableResolver.gd",
		"res://src/core/systems/LootSystemConstants.gd",
		"res://src/ui/screens/world/components/CrewTaskComponent.gd",
		"res://src/ui/components/dialogs/CrewTaskEventDialog.gd",
		"res://src/ui/screens/postbattle/PostBattleSequence.gd",
	]:
		var f := FileAccess.open(path, FileAccess.READ)
		assert_that(f).override_failure_message("cannot open %s" % path).is_not_null()
		var line_no := 0
		for line: String in f.get_as_text().split("\n"):
			line_no += 1
			var code: String = line.strip_edges()
			if code.begins_with("#"):
				continue
			# The shape of the bug: indexing an item list by a fresh randi().
			if "items[randi()" in code or "_pool[randi()" in code or "_items[randi()" in code:
				offenders.append("%s:%d  %s" % [path.get_file(), line_no, code])
		f.close()
	# LootTableResolver keeps exactly one, inside the legacy-shape fallback.
	assert_int(offenders.size()).override_failure_message(
		"a resolver is picking from the item list directly instead of rolling"
		+ " D100 on it:\n  " + "\n  ".join(offenders)).is_less_equal(1)
