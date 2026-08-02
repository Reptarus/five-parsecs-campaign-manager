extends GdUnitTestSuite
## Starting equipment must reach the crew, in the right SHAPE, and live in
## exactly one place.
##
## Three defects met here:
##
##   1. A second distribution site appended the full item DICTIONARY to a crew
##      member's `equipment`, which is an Array[String]. Godot rejects that
##      outright ("Attempted to push_back a variable of type 'Dictionary' into a
##      TypedArray of type 'String'"), and because the loop still marked the item
##      assigned and broke, it never reached the stash either — the item was
##      annihilated. It survived review only because the block was unreachable.
##
##   2. The stash was given the FULL generated list, so items handed to a crew
##      member ALSO sat in the ship stash, breaking "one item, one home".
##
##   3. Provenance: EquipmentPanel copied `source` ("crew_base") into
##      `source_table`, so the p.28 Savvy substitution gate — which looks for
##      "military_weapon" — could never match, and the swap the book offers was
##      unreachable for every crew.

const FinalizationService = preload(
	"res://src/core/campaign/creation/CampaignFinalizationService.gd")
const StartingEquipmentGenerator = preload(
	"res://src/core/character/Equipment/StartingEquipmentGenerator.gd")
const CharacterScript = preload("res://src/core/character/Character.gd")

func _sample_list() -> Array:
	return [
		{"name": "Hand Laser", "type": "Weapon", "source": "shared_pool",
		 "source_table": "military_weapon", "owner": "Unassigned"},
		{"name": "Blade", "type": "Weapon", "source": "bonus",
		 "source_table": "low_tech_weapon", "owner": "Vex"},
		{"name": "Stim-pack", "type": "Gear", "source": "bonus",
		 "source_table": "gear", "owner": "Rell"},
		{"name": "Scanner", "type": "Gear", "source": "shared_pool",
		 "source_table": "gear", "owner": ""},
	]

# ── Shape: names, never Dictionaries ─────────────────────────────────────

func test_owner_split_yields_item_names_not_dictionaries() -> void:
	var owned := FinalizationService.split_equipment_by_owner(_sample_list())
	assert_array(owned.keys()).contains(["Vex", "Rell"])
	for owner in owned.keys():
		for entry in owned[owner]:
			assert_bool(entry is String).override_failure_message(
				"crew equipment entries must be item NAMES; a Dictionary here is rejected by the typed array and the item is lost"
			).is_true()
	assert_array(owned["Vex"]).contains(["Blade"])

func test_a_name_list_can_actually_be_stored_on_a_character() -> void:
	# The direct regression test for the annihilation: whatever the split
	# produces must be assignable to Character.equipment without loss.
	var owned := FinalizationService.split_equipment_by_owner(_sample_list())
	var c = CharacterScript.new()
	var names: Array = owned["Vex"]
	c.equipment.assign(names)
	assert_int(c.equipment.size()).override_failure_message(
		"the assigned loadout did not survive being stored on the character"
	).is_equal(names.size())
	assert_str(str(c.equipment[0])).is_equal("Blade")

func test_pushing_an_item_dictionary_onto_a_character_loses_it() -> void:
	# Pins WHY the names matter, so nobody "simplifies" this back to dicts.
	var c = CharacterScript.new()
	var before: int = c.equipment.size()
	c.equipment.append({"name": "Blade"})
	assert_int(c.equipment.size()).override_failure_message(
		"Character.equipment accepted a Dictionary — the contract changed and the split must be revisited"
	).is_equal(before)

# ── One item, one home ───────────────────────────────────────────────────

func test_assigned_items_are_excluded_from_the_ship_stash() -> void:
	var stash := FinalizationService.unassigned_equipment(_sample_list())
	var stash_names: Array = []
	for item in stash:
		stash_names.append(str(item.get("name", "")))
	assert_array(stash_names).override_failure_message(
		"an item on a crew member's sheet must not also be in the stash (one item, one home)"
	).not_contains(["Blade", "Stim-pack"])
	assert_array(stash_names).contains(["Hand Laser", "Scanner"])

func test_every_item_lands_in_exactly_one_place() -> void:
	var items := _sample_list()
	var owned := FinalizationService.split_equipment_by_owner(items)
	var stash := FinalizationService.unassigned_equipment(items)
	var owned_count: int = 0
	for owner in owned.keys():
		owned_count += (owned[owner] as Array).size()
	assert_int(owned_count + stash.size()).override_failure_message(
		"items were duplicated or dropped between the crew and the stash"
	).is_equal(items.size())

func test_an_item_owned_by_nobody_real_is_kept_not_dropped() -> void:
	# Blank owner is stash, not a lost item.
	var stash := FinalizationService.unassigned_equipment(
		[{"name": "Orphan", "owner": ""}])
	assert_int(stash.size()).is_equal(1)

# ── Provenance: the p.28 Savvy substitution can find its weapons ─────────

func test_generator_tags_the_table_each_item_was_rolled_on() -> void:
	var pool: Array = StartingEquipmentGenerator.generate_crew_base_pool(null)
	assert_int(pool.size()).override_failure_message(
		"Core Rules p.28: 3 military + 3 low-tech + 1 gear + 1 gadget"
	).is_equal(8)
	var tables := {}
	for item in pool:
		tables[str(item.get("source_table", ""))] = true
	assert_array(tables.keys()).override_failure_message(
		"the Savvy substitution gate matches on source_table == 'military_weapon'; without real table names it can never fire"
	).contains(["military_weapon", "low_tech_weapon", "gear", "gadget"])

func test_source_table_is_not_overwritten_by_the_source_field() -> void:
	# The exact bug: `source_table: item.get("source")` stamped everything
	# "crew_base", which matches no table name the Savvy gate looks for.
	var pool: Array = StartingEquipmentGenerator.generate_crew_base_pool(null)
	for item in pool:
		assert_str(str(item.get("source_table", ""))).override_failure_message(
			"source_table must name a TABLE, not the item's origin bucket"
		).is_not_equal("crew_base")
