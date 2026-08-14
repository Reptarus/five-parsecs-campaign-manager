extends GdUnitTestSuite
## A legacy save's ship stash must survive load -> save -> load without losing items.
##
## FOUND ON REAL HARDWARE (Aug 9 2026, deploy #4). Loading
## `22222222_1775243767.save` on the tablet and pressing Save took the stash from
## **13 items to 8** — Assault Blade x2, Hot Shot Pack x2 and Booster Pills were
## destroyed, permanently, in one round trip. The dashboard showed "Gear 8" and
## nothing errored.
##
## The fixture at tests/fixtures/saves/legacy_split_format_stash.json is the real
## equipment block off that device, trimmed to the keys this test needs. It carries
## the two shapes that matter:
##
##   8 id-LESS items  (keys: condition/name/owner/quality_modifier/source/...)
##                    ALSO echoed byte-identically under "gear" by the old
##                    split-format writer.
##   5 id-bearing loot items (keys: category/description/id/location/name/...)
##                    with only THREE DISTINCT IDS — "Assault Blade" x2 share
##                    `loot_157153_1063` and "Hot Shot Pack" x2 share
##                    `loot_157153_6433`.
##
## ⚠ That last fact is the load-bearing one: an id in this data identifies an item
## TYPE from a loot roll, NOT a physical card. Deduping by id therefore deletes real
## items. Two looted Assault Blades are two Assault Blades.

const CampaignCore := preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const FIXTURE := "res://tests/fixtures/saves/legacy_split_format_stash.json"

const EXPECTED_TOTAL := 13
const EXPECTED_NAMES := {
	"Military Rifle": 1, "Rattle Gun": 1, "Infantry Laser": 1, "Shotgun": 1,
	"Scrap Pistol": 1, "Handgun": 1, "Beam Light": 1, "Snooper Bot": 1,
	"Assault Blade": 2, "Hot Shot Pack": 2, "Booster Pills": 1,
}


func _load_fixture() -> Dictionary:
	var f: FileAccess = FileAccess.open(FIXTURE, FileAccess.READ)
	assert_object(f).is_not_null()
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	assert_bool(parsed is Dictionary).is_true()
	return parsed


func _campaign_from_fixture() -> Resource:
	var c: Resource = CampaignCore.new()
	c.from_dictionary(_load_fixture())
	return c


func _stash_names(c: Resource) -> Dictionary:
	var counts: Dictionary = {}
	for item in c.equipment_data.get("equipment", []):
		if item is Dictionary:
			var n: String = str(item.get("name", "?"))
			counts[n] = int(counts.get(n, 0)) + 1
	return counts


# ============================================================================
# The fixture itself — if these drift, the test below is measuring nothing
# ============================================================================

func test_the_fixture_still_describes_the_defect_it_was_captured_for() -> void:
	var eq: Dictionary = _load_fixture()["equipment"]
	assert_int((eq["equipment"] as Array).size()).is_equal(EXPECTED_TOTAL)
	assert_int((eq["gear"] as Array).size()).is_equal(8) \
		.override_failure_message("the split-format 'gear' echo is what made the union 21")
	var ids: Array[String] = []
	for item in eq["equipment"]:
		var id: String = str((item as Dictionary).get("id", ""))
		if not id.is_empty():
			ids.append(id)
	var distinct: Dictionary = {}
	for id in ids:
		distinct[id] = true
	assert_int(ids.size()).is_equal(5)
	assert_int(distinct.size()).is_equal(3) \
		.override_failure_message(
			"The whole point of this fixture is that ids COLLIDE (5 items, 3 ids). "
			+ "If they no longer do, id-based dedup would look correct here.")


# ============================================================================
# The actual contract
# ============================================================================

func test_a_legacy_stash_keeps_every_item_through_the_load_heal() -> void:
	var c: Resource = _campaign_from_fixture()
	var gs: Node = get_node_or_null("/root/GameState")
	assert_object(gs).is_not_null() \
		.override_failure_message("GameState autoload required — this tests the real path")
	gs._restore_equipment_from_campaign(c)

	var counts: Dictionary = _stash_names(c)
	var total: int = 0
	for n in counts:
		total += int(counts[n])
	assert_int(total).is_equal(EXPECTED_TOTAL) \
		.override_failure_message(
			"stash is %d after the load heal, expected %d.\n  got:      %s\n  expected: %s"
			% [total, EXPECTED_TOTAL, str(counts), str(EXPECTED_NAMES)])
	for name in EXPECTED_NAMES:
		assert_int(int(counts.get(name, 0))).is_equal(int(EXPECTED_NAMES[name])) \
			.override_failure_message(
				"%s: %d in stash, expected %d" % [
					name, int(counts.get(name, 0)), int(EXPECTED_NAMES[name])])


func test_the_split_format_echo_keys_are_erased_not_merged() -> void:
	# "gear"/"items" are the un-erased duplicate views the old writer left behind.
	# They must be consumed, or get_all_equipment() keeps double-counting forever.
	var c: Resource = _campaign_from_fixture()
	var gs: Node = get_node_or_null("/root/GameState")
	gs._restore_equipment_from_campaign(c)
	for key in ["weapons", "armor", "gear", "items"]:
		assert_bool(c.equipment_data.has(key)).is_false() \
			.override_failure_message("equipment_data still carries the '%s' echo" % key)
	assert_int(c.get_all_equipment().size()).is_equal(EXPECTED_TOTAL)


func test_the_heal_is_idempotent() -> void:
	# Loading twice must not grow OR shrink the stash. The original corruption was a
	# grow-on-every-load; the regression found on device was a shrink-on-every-load.
	var c: Resource = _campaign_from_fixture()
	var gs: Node = get_node_or_null("/root/GameState")
	gs._restore_equipment_from_campaign(c)
	var after_first: int = c.get_all_equipment().size()
	gs._restore_equipment_from_campaign(c)
	var after_second: int = c.get_all_equipment().size()
	assert_int(after_second).is_equal(after_first) \
		.override_failure_message(
			"stash changed on a second load: %d -> %d" % [after_first, after_second])
	assert_int(after_second).is_equal(EXPECTED_TOTAL)


## The FULL load path, not just the heal.
##
## The device lost MORE than the direct-restore test reproduces (13 -> 8 there,
## 13 -> 11 here before the fix), and load_campaign() does several things around
## the heal — set_current_campaign() first, then the EquipmentManager rehydrate
## whose write-through targets that same campaign. This runs the real entry point
## so the difference has somewhere to show up.
func test_the_full_load_campaign_path_keeps_every_stash_item() -> void:
	var tmp := "user://_test_legacy_stash.save"
	var src: FileAccess = FileAccess.open(FIXTURE, FileAccess.READ)
	var text: String = src.get_as_text()
	src.close()
	var dst: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	dst.store_string(text)
	dst.close()

	var gs: Node = get_node_or_null("/root/GameState")
	assert_object(gs).is_not_null()
	var result: Variant = gs.load_campaign(tmp)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	assert_bool(bool((result as Dictionary).get("success", false))).is_true() \
		.override_failure_message("load_campaign failed: %s" % str(result))

	var c = gs.current_campaign
	assert_object(c).is_not_null()
	var counts: Dictionary = {}
	for item in c.equipment_data.get("equipment", []):
		if item is Dictionary:
			var n: String = str(item.get("name", "?"))
			counts[n] = int(counts.get(n, 0)) + 1
	var total: int = 0
	for n in counts:
		total += int(counts[n])
	assert_int(total).is_equal(EXPECTED_TOTAL) \
		.override_failure_message(
			"after a real load_campaign() the stash is %d, expected %d\n  got: %s"
			% [total, EXPECTED_TOTAL, str(counts)])


## Two real items sharing one loot id must end up with DISTINCT ids.
##
## EquipmentManager keys its runtime cache by id and rejects a repeat
## ("Equipment with ID already exists"), so before this the cache held 11 while the
## persisted stash held 13 — a silent divergence between what is saved and what
## the live screens can see.
##
## ⚠ The FIRST occurrence must keep the ORIGINAL id: a character's equipment list
## can reference a stash item by id (the id->name heal below the dedup does exactly
## that), and that reference has to keep resolving.
func test_colliding_loot_ids_are_made_unique_without_losing_items() -> void:
	var c: Resource = _campaign_from_fixture()
	var gs: Node = get_node_or_null("/root/GameState")
	gs._restore_equipment_from_campaign(c)

	var ids: Dictionary = {}
	var blades: Array[String] = []
	for item in c.equipment_data.get("equipment", []):
		var id: String = str((item as Dictionary).get("id", ""))
		assert_bool(ids.has(id)).is_false() \
			.override_failure_message("duplicate stash id survived the heal: %s" % id)
		ids[id] = true
		if str((item as Dictionary).get("name", "")) == "Assault Blade":
			blades.append(id)

	assert_int(blades.size()).is_equal(2) \
		.override_failure_message("both Assault Blades must survive")
	assert_str(blades[0]).is_equal("loot_157153_1063") \
		.override_failure_message(
			"the FIRST copy must keep the original id so id references still resolve")
	assert_str(blades[1]).is_not_equal(blades[0])


func test_the_runtime_cache_matches_the_persisted_stash() -> void:
	# The whole point of unique ids: what EquipmentManager can see must equal what
	# the save contains. A divergence here is invisible until a screen reads one
	# and the sheet reads the other.
	var c: Resource = _campaign_from_fixture()
	var gs: Node = get_node_or_null("/root/GameState")
	gs.current_campaign = c
	gs._restore_equipment_from_campaign(c)
	var em: Node = get_node_or_null("/root/EquipmentManager")
	assert_object(em).is_not_null()
	assert_int((em.get_all_equipment() as Array).size()).is_equal(EXPECTED_TOTAL) \
		.override_failure_message(
			"EquipmentManager holds %d items but the stash has %d"
			% [(em.get_all_equipment() as Array).size(), EXPECTED_TOTAL])
