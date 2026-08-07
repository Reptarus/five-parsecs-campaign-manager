extends GdUnitTestSuite
## Compendium p.110 "Generating Factions" — the call that was never made.
##
## The whole Expanded Factions chapter (jobs p.111, Loyalty and Favors p.112,
## Activities p.113, Events pp.114-115, Destruction p.115) is written, wired and
## correctly DLC-gated, and it could never fire: nothing in the game ever created
## a Faction, so `active_factions` was empty for a campaign's entire life.
##
## The per-world LIFECYCLE was even built — TravelPhase stores the departing
## world's factions, clears state on arrival, restores them on a return visit.
## It simply had nothing to store. This is the dead-chapter shape: complete data,
## correct readers, correct gate, zero callers.
##
## `initialize()` was not the missing call. It has no caller and no `_ready()`,
## and TravelPhase sets `_initialized = true` directly to skip it — rightly, since
## the default it ran generated 8-16 factions across eight hardcoded "categories"
## that appear nowhere in the Compendium.
##
## gdUnit4 v6.0.3 compatible.

const FactionSystemClass = preload("res://src/core/systems/FactionSystem.gd")

var _sys: Node = null
var _saved_flag: bool = false


func _dlc() -> Node:
	return get_node_or_null("/root/DLCManager")


func before_test() -> void:
	# Expanded Factions is Compendium content, so generation is DLC-gated. The
	# gate is TWO-level (owned AND toggled) and `_enabled_flags` defaults false,
	# so a test that does not enable it measures the gate, not the rule.
	var dlc: Node = _dlc()
	if dlc:
		_saved_flag = dlc.is_feature_enabled(dlc.ContentFlag.EXPANDED_FACTIONS)
		dlc.set_feature_enabled(dlc.ContentFlag.EXPANDED_FACTIONS, true)
	_sys = FactionSystemClass.new()
	add_child(_sys)
	_sys._load_faction_data()


func after_test() -> void:
	var dlc: Node = _dlc()
	if dlc:
		dlc.set_feature_enabled(dlc.ContentFlag.EXPANDED_FACTIONS, _saved_flag)
	if is_instance_valid(_sys):
		_sys.queue_free()
	_sys = null


## The gate itself, asserted rather than assumed: with Expanded Factions OFF the
## rule must produce nothing, because the chapter is paid Compendium content.
func test_generation_is_gated_on_expanded_factions() -> void:
	var dlc: Node = _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.EXPANDED_FACTIONS, false)
	_sys.cleanup()
	assert_int(_sys.generate_world_factions(true).size()).override_failure_message(
		"factions generated with the Expanded Factions content flag off"
	).is_equal(0)
	dlc.set_feature_enabled(dlc.ContentFlag.EXPANDED_FACTIONS, true)
	assert_int(_sys.generate_world_factions(true).size()).is_between(2, 4)


# ── The p.110 type table ────────────────────────────────────────────────────

## Seven types, and the Influence/Power modifiers are the book's.
func test_the_type_table_matches_the_book() -> void:
	var table: Array = _sys.faction_data.get("generation", {}).get("type_table", [])
	assert_int(table.size()).override_failure_message(
		"p.110 has exactly seven Faction types").is_equal(7)
	var expected := {
		"Charismatic leader": [0, 0],
		"Merchant cartel": [1, 0],
		"Criminal enterprise": [0, 1],
		"Advocacy group": [0, 0],
		"Political movement": [0, 1],
		"Religious movement": [1, 0],
		"Secretive organization": [1, 1],
	}
	for entry in table:
		var t: String = str(entry.get("type", ""))
		assert_bool(expected.has(t)).override_failure_message(
			"'%s' is not one of the seven p.110 types" % t).is_true()
		assert_int(int(entry.get("influence_mod", -9))).override_failure_message(
			"%s Influence modifier" % t).is_equal(expected[t][0])
		assert_int(int(entry.get("power_mod", -9))).override_failure_message(
			"%s Power modifier" % t).is_equal(expected[t][1])


## D100 tables write the top of the range as "00", meaning 100 — p.110's last row
## is literally "91-00". Parsed naively that is [91, 0], so `roll >= 91 and roll
## <= 0` never matches and Secretive organization (10% of the table) could never
## be rolled.
func test_the_d100_wheel_convention_is_honoured() -> void:
	assert_array(_sys._parse_roll_range("91-00")).is_equal([91, 100])
	assert_array(_sys._parse_roll_range("01-10")).is_equal([1, 10])
	assert_array(_sys._parse_roll_range("51-60")).is_equal([51, 60])


## Every roll 1-100 must land on exactly one row — no gaps, no overlaps.
func test_the_type_table_covers_every_roll_exactly_once() -> void:
	var table: Array = _sys.faction_data.get("generation", {}).get("type_table", [])
	for roll in range(1, 101):
		var hits: int = 0
		for entry in table:
			var r: Array = _sys._parse_roll_range(str(entry.get("roll", "")))
			if roll >= r[0] and roll <= r[1]:
				hits += 1
		assert_int(hits).override_failure_message(
			"roll %d matched %d rows on the p.110 type table" % [roll, hits]
		).is_equal(1)


# ── The p.110 generation rule ───────────────────────────────────────────────

## "When creating a new world, generate 1D3+1 Factions as well." 1D3+1 is 2-4.
func test_generation_produces_one_d3_plus_one_factions() -> void:
	var seen := {}
	for attempt in 40:
		_sys.cleanup()
		var made: Array = _sys.generate_world_factions(true)
		assert_int(made.size()).override_failure_message(
			"p.110 generates 1D3+1 = 2-4 factions, got %d" % made.size()
		).is_between(2, 4)
		seen[made.size()] = true
	# All three counts must be reachable, or the dice expression is wrong.
	assert_int(seen.size()).override_failure_message(
		"1D3+1 must be able to produce 2, 3 and 4; only saw %s" % str(seen.keys())
	).is_equal(3)


## "Each Faction is rated for two qualities: Influence and Power. Roll 1D3+1 for
## each of these qualities, applying any modifiers from the Faction type."
## So the floor is 2 (1+1, no modifier) and the ceiling is 5 (3+1, +1 modifier).
func test_influence_and_power_are_one_d3_plus_one_plus_modifier() -> void:
	var mods := {}
	for entry in _sys.faction_data.get("generation", {}).get("type_table", []):
		mods[str(entry.get("type", ""))] = [
			int(entry.get("influence_mod", 0)), int(entry.get("power_mod", 0))]

	for attempt in 30:
		_sys.cleanup()
		for faction in _sys.generate_world_factions(true):
			var t: String = str(faction.get("type", ""))
			assert_bool(mods.has(t)).override_failure_message(
				"generated a faction of non-book type '%s'" % t).is_true()
			var infl: int = int(faction.get("influence", -9))
			var pwr: int = int(faction.get("power", -9))
			assert_int(infl).override_failure_message(
				"%s Influence %d outside 1D3+1+%d" % [t, infl, mods[t][0]]
			).is_between(2 + mods[t][0], 4 + mods[t][0])
			assert_int(pwr).override_failure_message(
				"%s Power %d outside 1D3+1+%d" % [t, pwr, mods[t][1]]
			).is_between(2 + mods[t][1], 4 + mods[t][1])


## Loyalty starts at 0 — the crew has done nothing for them yet (p.112).
func test_new_factions_start_at_zero_loyalty() -> void:
	_sys.cleanup()
	for faction in _sys.generate_world_factions(true):
		assert_int(int(faction.get("loyalty", -1))).is_equal(0)


## Every generated faction must be individually addressable. Names come from a
## 5x5 prefix/suffix pool per type, so two of a world's factions CAN collide;
## assigning on a colliding key would silently hand the player 3 factions where
## the book rolled 4.
func test_colliding_names_do_not_swallow_a_faction() -> void:
	for attempt in 40:
		_sys.cleanup()
		var made: Array = _sys.generate_world_factions(true)
		assert_int(_sys.active_factions.size()).override_failure_message(
			"rolled %d factions but only %d are addressable — a name collision"
			% [made.size(), _sys.active_factions.size()]
			+ " overwrote one").is_equal(made.size())


## A return visit restores this world's stored factions; generation must not then
## re-roll on top of them. The guard is what lets TravelPhase make ONE call that
## is correct for a first visit and a return visit alike.
func test_generation_skips_a_world_that_already_has_factions() -> void:
	_sys.cleanup()
	var first: Array = _sys.generate_world_factions(true)
	assert_int(first.size()).is_between(2, 4)
	var second: Array = _sys.generate_world_factions()
	assert_int(second.size()).override_failure_message(
		"factions were re-rolled on top of a restored world").is_equal(0)
	assert_int(_sys.active_factions.size()).is_equal(first.size())


## Compendium p.111: "If you began the campaign on this world, you may choose
## ONE Faction to start at Loyalty 1. The rest begin at Loyalty 0."
func test_home_world_grants_exactly_one_point_of_loyalty() -> void:
	for attempt in 20:
		_sys.cleanup()
		var made: Array = _sys.generate_world_factions(true, true)
		var loyal: int = 0
		for f in made:
			var l: int = int(f.get("loyalty", 0))
			assert_int(l).override_failure_message(
				"p.111 grants Loyalty 1, never more").is_between(0, 1)
			loyal += l
		assert_int(loyal).override_failure_message(
			"exactly ONE faction starts at Loyalty 1 on the home world").is_equal(1)


## "If you are off-worlders, all Loyalties begin at 0." Every world reached by
## travel is one the crew are off-worlders on.
func test_a_travelled_to_world_grants_no_loyalty() -> void:
	for attempt in 20:
		_sys.cleanup()
		for f in _sys.generate_world_factions(true, false):
			assert_int(int(f.get("loyalty", 0))).override_failure_message(
				"off-worlders start every Loyalty at 0").is_equal(0)


## p.111 Faction Jobs: "SELECT a Faction ... and roll 1D6" — ONE check per turn,
## not one per faction. Looping every faction compounds the odds: four factions
## at Influence 3 turns a 50% chance of a job into 94%.
func test_only_one_faction_job_check_is_made_per_turn() -> void:
	for attempt in 25:
		_sys.cleanup()
		_sys.generate_world_factions(true)
		var offers: Array = _sys.get_faction_mission_opportunities()
		assert_int(offers.size()).override_failure_message(
			"p.111 allows ONE Faction job check per turn; got %d offers"
			% offers.size()).is_between(0, 1)
		for o in offers:
			# "Faction jobs are treated as a Patron job, but do NOT roll for
			# Danger Pay or Benefits."
			assert_str(str(o.get("mission_source", ""))).is_equal("faction")
			assert_bool(o.get("skip_danger_pay", false)).is_true()
			assert_bool(o.get("skip_benefits", false)).is_true()


## The fabricated default is gone: 8-16 factions across eight "categories"
## (government / corporate / military / pirate / alien) that are in no rulebook.
func test_no_factions_are_created_outside_the_book_rule() -> void:
	_sys.cleanup()
	_sys._initialize_default_data()
	assert_int(_sys.active_factions.size()).override_failure_message(
		"something populated factions outside generate_world_factions()"
	).is_equal(0)
