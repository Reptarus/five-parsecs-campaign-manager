extends GdUnitTestSuite

## Five Parsecs: Tactics army organisation — p.134 Infantry Platoon, p.135 Company and
## Armored Platoon, p.138 Mechanized Infantry, p.141 vehicles, p.152 creatures.
##
## ⚠ Before 2026-10-27 the builder could not express most of this: every unit went to
## Platoon 1 (so a company's other platoons were always empty and failed), company
## supports were counted by an org slot no unit carries (so their cap never bound),
## options and transports could not be chosen or priced, and no army could field a
## vehicle. Every roster here is built through TacticsRosterEntry.from_entry_dict(), the
## resolver the creation wizard prices and validates through.

const Loader := preload("res://src/data/tactics/TacticsSpeciesBookLoader.gd")
const Validator := preload("res://src/data/tactics/TacticsCompositionValidator.gd")
const RosterScript := preload("res://src/data/tactics/TacticsRoster.gd")
const EntryScript := preload("res://src/data/tactics/TacticsRosterEntry.gd")
const Coordinator := preload("res://src/ui/screens/tactics/TacticsCreationCoordinator.gd")
const RosterPanel := preload("res://src/ui/screens/tactics/panels/TacticsRosterPanel.gd")

var _book: TacticsSpeciesBook = null


func before() -> void:
	_book = Loader.load_species_book("human_colonists")


func _e(unit: String, platoon: int = 0, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"entry_id": "e%d" % randi(), "unit_id": "human_" + unit,
		"display_name": unit, "platoon_index": platoon, "selected_upgrades": []}
	d.merge(extra, true)
	return d


func _roster(entries: Array, org := "platoon", platoons := 1, armored: Array = [],
		pickup := false, book: TacticsSpeciesBook = null) -> TacticsRoster:
	var r: TacticsRoster = RosterScript.new()
	r.points_limit = 5000
	r.org_type = RosterScript.OrgType.COMPANY if org == "company" else RosterScript.OrgType.PLATOON
	r.platoon_count = platoons
	r.armored_platoons = armored
	r.is_pickup = pickup
	r.species_book = book if book else _book
	for d in entries:
		r.entries.append(EntryScript.from_entry_dict(d, r.species_book))
	return r


## A legal p.134 infantry platoon: 1 leader, 2 squads.
func _platoon(idx: int) -> Array:
	return [_e("sergeant", idx), _e("infantry_squad", idx), _e("infantry_squad", idx)]


func _has(errors: Array, needle: String) -> bool:
	for e in errors:
		if needle in str(e):
			return true
	return false


# MARK: - p.135 Company

func test_a_legal_two_platoon_company_validates() -> void:
	var errors := Validator.validate(_roster(_platoon(0) + _platoon(1), "company", 2))
	assert_array(errors).override_failure_message(str(errors)).is_empty()


func test_company_supports_are_counted_by_assignment_and_capped_at_platoon_count() -> void:
	var base: Array = _platoon(0) + _platoon(1)
	var ok := Validator.validate(_roster(base + [_e("weapon_team", -1), _e("weapon_team", -1)],
		"company", 2))
	assert_bool(_has(ok, "company supports")).override_failure_message(str(ok)).is_false()
	var over := Validator.validate(_roster(base + [_e("weapon_team", -1),
		_e("weapon_team", -1), _e("infantry_squad", -1)], "company", 2))
	assert_bool(_has(over, "Too many company supports")) \
		.override_failure_message("3 company supports with 2 platoons must fail: %s" % str(over)) \
		.is_true()


func test_company_supports_may_include_only_one_vehicle() -> void:
	var base: Array = _platoon(0) + _platoon(1)
	var one := Validator.validate(_roster(base + [_e("vehicle_apc_tracked", -1)], "company", 2))
	assert_bool(_has(one, "vehicle")).override_failure_message(str(one)).is_false()
	var two := Validator.validate(_roster(base + [_e("vehicle_apc_tracked", -1),
		_e("vehicle_armored_car", -1)], "company", 2))
	assert_bool(_has(two, "only 1 vehicle")).override_failure_message(str(two)).is_true()


func test_company_cannot_take_a_specialist_or_exceed_its_leader_cap() -> void:
	var base: Array = _platoon(0) + _platoon(1)
	var spec := Validator.validate(_roster(base + [_e("medic", -1)], "company", 2))
	assert_bool(_has(spec, "a company may add only")).override_failure_message(str(spec)).is_true()
	var leaders := Validator.validate(_roster(base + [_e("sergeant", -1), _e("major", -1),
		_e("epic", -1)], "company", 2))
	assert_bool(_has(leaders, "Too many company leaders")) \
		.override_failure_message(str(leaders)).is_true()


func test_a_unit_assigned_past_the_last_platoon_is_refused() -> void:
	var errors := Validator.validate(_roster(_platoon(0) + [_e("medic", 1)]))
	assert_bool(_has(errors, "no Platoon 2")).override_failure_message(str(errors)).is_true()


# MARK: - p.134 vehicles are Supports in an infantry platoon

func test_a_vehicle_is_a_support_in_an_infantry_platoon() -> void:
	var one := Validator.validate(_roster(_platoon(0) + [_e("vehicle_light_tank_tracked")]))
	assert_array(one).override_failure_message(str(one)).is_empty()
	# Two supports with two troops breaks "must be fewer than number of Troops".
	var two := Validator.validate(_roster(_platoon(0) + [_e("vehicle_light_tank_tracked"),
		_e("vehicle_armored_car")]))
	assert_bool(_has(two, "must be fewer than troop count")) \
		.override_failure_message(str(two)).is_true()


# MARK: - p.135 Armored Platoon

func _armored(troops: Array, supports: Array = []) -> Array:
	var out: Array = [_e("vehicle_medium_tank_tracked", 0, {"role": "leader"})]
	for v in troops:
		out.append(_e("vehicle_" + v, 0, {"role": "troop"}))
	return out + supports


func test_a_legal_armored_platoon_validates() -> void:
	var r := _roster(_armored(["light_tank_tracked", "light_tank_grav", "light_tank_tracked"],
		[_e("infantry_squad", 0, {"transport_vehicle_id": "apc_tracked"})]), "platoon", 1, [0])
	var errors := Validator.validate(r)
	assert_array(errors).override_failure_message(str(errors)).is_empty()


func test_the_first_three_troop_vehicles_must_be_the_same_type() -> void:
	var r := _roster(_armored(["light_tank_tracked", "medium_tank_tracked", "light_tank_tracked"]),
		"platoon", 1, [0])
	assert_bool(_has(Validator.validate(r), "must be the same type")).is_true()


func test_armored_supports_must_ride_in_a_transport_and_be_fewer_than_troops() -> void:
	var foot := _roster(_armored(["light_tank_tracked", "light_tank_tracked"],
		[_e("infantry_squad")]), "platoon", 1, [0])
	assert_bool(_has(Validator.validate(foot), "must be mounted in a transport")).is_true()
	var many := _roster(_armored(["light_tank_tracked", "light_tank_tracked"],
		[_e("infantry_squad", 0, {"transport_vehicle_id": "apc_tracked"}),
		_e("storm_squad", 0, {"transport_vehicle_id": "apc_tracked"})]), "platoon", 1, [0])
	assert_bool(_has(Validator.validate(many), "must be fewer than troop count")).is_true()


func test_an_armored_platoon_takes_no_weapon_teams_specialists_or_characters() -> void:
	for unit in ["weapon_team", "medic", "sergeant"]:
		var r := _roster(_armored(["light_tank_tracked", "light_tank_tracked"], [_e(unit)]),
			"platoon", 1, [0])
		assert_bool(_has(Validator.validate(r), "cannot be part of an armored platoon")) \
			.override_failure_message("%s was accepted in an armored platoon" % unit).is_true()


func test_an_armored_platoon_needs_exactly_one_leader_vehicle() -> void:
	var r := _roster([_e("vehicle_light_tank_tracked", 0, {"role": "troop"}),
		_e("vehicle_light_tank_tracked", 0, {"role": "troop"})], "platoon", 1, [0])
	assert_bool(_has(Validator.validate(r), "exactly 1 Leader vehicle")).is_true()


# MARK: - p.138 Mechanized Infantry

func test_a_transport_must_carry_the_whole_squad_and_adds_its_cost() -> void:
	var on_foot: TacticsRosterEntry = EntryScript.from_entry_dict(_e("infantry_squad"), _book)
	var mounted: TacticsRosterEntry = EntryScript.from_entry_dict(
		_e("infantry_squad", 0, {"transport_vehicle_id": "apc_tracked"}), _book)
	assert_int(mounted.get_total_cost() - on_foot.get_total_cost()).is_equal(50)
	assert_array(mounted.validate()).is_empty()
	var crowded: TacticsRosterEntry = EntryScript.from_entry_dict(
		_e("infantry_squad", 0, {"transport_vehicle_id": "ifv_grav", "model_count": 6}), _book)
	assert_bool(_has(crowded.validate(), "carries 5 figures")) \
		.override_failure_message(str(crowded.validate())).is_true()


func test_chosen_options_are_priced_and_a_pick_one_group_holds_one() -> void:
	var plain: TacticsRosterEntry = EntryScript.from_entry_dict(_e("sergeant"), _book)
	var hero: TacticsRosterEntry = EntryScript.from_entry_dict(
		_e("sergeant", 0, {"selected_upgrades": ["Hero", "Leader"]}), _book)
	assert_int(hero.get_total_cost() - plain.get_total_cost()).is_equal(15)
	var lasers: TacticsRosterEntry = EntryScript.from_entry_dict(
		_e("infantry_squad", 0, {"selected_upgrades": ["Infantry Lasers (whole squad)"]}), _book)
	assert_int(lasers.get_total_cost()).is_equal(
		EntryScript.from_entry_dict(_e("infantry_squad"), _book).get_total_cost() + 4)


# MARK: - p.152 creatures in pick-up games

func test_creatures_cannot_be_an_army_in_a_pick_up_game() -> void:
	var beasts: TacticsSpeciesBook = Loader.load_species_book("creatures")
	assert_object(beasts).is_not_null()
	var r := _roster([], "platoon", 1, [], true, beasts)
	r.entries.append(EntryScript.from_entry_dict({"unit_id": "swarm"}, beasts))
	assert_bool(_has(Validator.validate(r), "Creatures may not be fielded")).is_true()
	r.is_pickup = false
	assert_bool(_has(Validator.validate(r), "Creatures may not be fielded")) \
		.override_failure_message("p.152 limits PICK-UP games only").is_false()
	var humans := _roster(_platoon(0), "platoon", 1, [], true)
	assert_bool(_has(Validator.validate(humans), "Creatures")).is_false()


# MARK: - The builder screen

func _builder(config: Dictionary) -> Array:
	var coord = Coordinator.new()
	add_child(coord)
	auto_free(coord)
	coord.update_config(config)
	coord.update_species({"species_id": "human_colonists"})
	var panel = RosterPanel.new()
	panel.size = Vector2(900, 1400)
	add_child(panel)
	auto_free(panel)
	panel.set_coordinator(coord)
	panel.roster_updated.connect(coord.update_roster)
	panel.refresh()
	return [coord, panel]


func test_the_builder_assigns_a_company_platoon_a_transport_and_an_option() -> void:
	var pair := _builder({"campaign_name": "T", "points_limit": 1000, "org_type": "company",
		"platoon_count": 2, "armored_platoons": [], "play_mode": "solo"})
	var coord = pair[0]
	var panel = pair[1]
	# Press the screen's own "+ Add" beside the Infantry Squad row.
	var add: Button = null
	for lbl in panel.find_children("*", "Label", true, false):
		if (lbl as Label).text.begins_with("Infantry Squad ("):
			for sib in lbl.get_parent().get_children():
				if sib is Button:
					add = sib
	assert_object(add).override_failure_message("no Add button for the squad").is_not_null()
	add.pressed.emit()
	await get_tree().process_frame
	var platoon: OptionButton = panel.find_child("PlatoonPicker", true, false)
	var transport: OptionButton = panel.find_child("TransportPicker", true, false)
	assert_object(platoon).override_failure_message("no company platoon picker").is_not_null()
	assert_object(transport).override_failure_message("no squad transport picker").is_not_null()
	platoon.item_selected.emit(1)
	await get_tree().process_frame
	assert_int(int(coord.roster_entries[0].get("platoon_index", 0))).is_equal(1)
	transport = panel.find_child("TransportPicker", true, false)
	var apc := -1
	for i in transport.item_count:
		if transport.get_item_text(i).begins_with("Mechanized: APC (Tracked)") \
				or transport.get_item_text(i).contains("APC"):
			apc = i
			break
	assert_int(apc).override_failure_message("no APC offered").is_greater(0)
	var before: int = coord.entry_cost(coord.roster_entries[0])
	transport.item_selected.emit(apc)
	await get_tree().process_frame
	assert_str(str(coord.roster_entries[0].get("transport_vehicle_id", ""))).is_not_empty()
	assert_int(coord.entry_cost(coord.roster_entries[0])).is_greater(before)


func test_the_wizard_has_no_separate_vehicles_step() -> void:
	assert_bool(Coordinator.STEP_NAMES.has("Vehicles")).is_false()
	assert_int(Coordinator.STEP_NAMES.size()).is_equal(4)
