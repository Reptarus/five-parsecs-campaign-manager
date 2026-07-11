extends GdUnitTestSuite
## Phase 4B-5C: Loot System Tests - Part 3: Gear & Odds/Ends Subtables
## Tests gear and odds/ends subtables (Five Parsecs rulebook p.7150-7220)
## gdUnit4 v6.0.1 compatible

# System under test
var HelperClass
var helper

func before():
	"""Suite-level setup - runs once before all tests"""
	HelperClass = load("res://tests/helpers/LootSystemHelper.gd")
	helper = HelperClass.new()

func after():
	"""Suite-level cleanup - runs once after all tests"""
	helper = null
	HelperClass = null

# ============================================================================
# _roll_gear_subtable() Tests - Gun Mods (2 tests)
# ============================================================================

func test_gear_gun_mods_minimum():
	"""Roll 1 results in gun mod"""
	var result = helper._roll_gear_subtable(1)

	assert_that(result).is_not_empty()
	# Book-correct gun mods (Core Rules p.53); must match LootSystemHelper's list.
	# (Was flaky: expected "Laser Sight" — a gun SIGHT, not a mod — so it failed ~25%
	# of the time when the helper's random pick returned "Hot Shot Pack".)
	var valid_mods = ["Assault Blade", "Bipod", "Stabilizer", "Hot Shot Pack"]
	assert_that(valid_mods).contains(result)

func test_gear_gun_mods_maximum():
	"""Roll 20 results in gun mod"""
	var result = helper._roll_gear_subtable(20)

	assert_that(result).is_not_empty()

# ============================================================================
# _roll_gear_subtable() Tests - Other Gear Types (3 tests)
# ============================================================================

func test_gear_gun_sights():
	"""Roll 30 results in gun sight"""
	var result = helper._roll_gear_subtable(30)

	assert_that(result).is_not_empty()
	# Book gun sights (Core Rules p.132) — must match LootSystemHelper's list.
	# (Was flaky: omitted "Unity Battle Sight", failing when the helper picked it.)
	var valid_sights = ["Laser Sight", "Quality Sight", "Seeker Sight", "Unity Battle Sight"]
	assert_that(valid_sights).contains(result)

func test_gear_protective_items():
	"""Roll 50 results in protective item"""
	var result = helper._roll_gear_subtable(50)

	assert_that(result).is_not_empty()
	# Should be one of the Core Rules protective items (p.132)
	var valid_armor = ["Combat Armor", "Frag Vest", "Flak Screen", "Deflector Field", "Battle Dress", "Camo Cloak", "Flex-Armor", "Screen Generator", "Stealth Gear"]
	assert_that(valid_armor).contains(result)

func test_gear_utility_items():
	"""Roll 85 results in utility item"""
	var result = helper._roll_gear_subtable(85)

	assert_that(result).is_not_empty()
	# Should be one of: Motion Tracker, Jump Belt, Battle Visor, Scanner Bot, Communicator
	var valid_utility = ["Motion Tracker", "Jump Belt", "Battle Visor", "Scanner Bot", "Communicator"]
	assert_that(valid_utility).contains(result)

# ============================================================================
# _roll_odds_and_ends_subtable() Tests - Consumables (2 tests)
# ============================================================================

func test_odds_consumables_minimum():
	"""Roll 1 results in consumable with 2 uses"""
	var result = helper._roll_odds_and_ends_subtable(1)

	assert_that(result).contains("2 uses")
	# All 6 book consumables (Core Rules p.133) — must match LootSystemHelper's list.
	# (Was flaky: omitted "Kiranin Crystals" and "Still", so it failed when the
	# helper's random pick returned either of them.)
	var has_consumable = result.contains("Booster Pills") or result.contains("Combat Serum") or \
						 result.contains("Kiranin Crystals") or result.contains("Rage Out") or \
						 result.contains("Still") or result.contains("Stim-pack")
	assert_that(has_consumable).is_true()

func test_odds_consumables_maximum():
	"""Roll 55 results in consumable with 2 uses"""
	var result = helper._roll_odds_and_ends_subtable(55)

	assert_that(result).contains("2 uses")

# ============================================================================
# _roll_odds_and_ends_subtable() Tests - Implants & Ship Items (2 tests)
# ============================================================================

func test_odds_implants():
	"""Roll 60 results in implant"""
	var result = helper._roll_odds_and_ends_subtable(60)

	assert_that(result).is_not_empty()
	# Should be one of the 11 Core Rules implants (p.133)
	var valid_implants = ["AI Companion", "Body Wire", "Boosted Arm", "Boosted Leg", "Cyber Hand", "Genetic Defenses", "Health Boost", "Nerve Adjuster", "Neural Optimization", "Night Sight", "Pain Suppressor"]
	assert_that(valid_implants).contains(result)

func test_odds_ship_items():
	"""Roll 80 results in ship item"""
	var result = helper._roll_odds_and_ends_subtable(80)

	assert_that(result).is_not_empty()
	# Should be one of: Med-patch, Spare Parts, Repair Bot, Nano-doc, Colonist Ration Packs
	var valid_ship_items = ["Med-patch", "Spare Parts", "Repair Bot", "Nano-doc", "Colonist Ration Packs"]
	assert_that(valid_ship_items).contains(result)
