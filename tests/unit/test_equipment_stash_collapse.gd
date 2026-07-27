extends GdUnitTestSuite
## Pins the "one item, one home" tabletop invariant at the two places it was
## being broken: campaign finalization, and load.
##
## THE BUG THIS EXISTS TO PREVENT
## CampaignFinalizationService._transform_equipment_data_for_turn_system() folds
## weapons/armor/gear into the flat "equipment" list, but used to `duplicate(true)`
## the source dict and never erase the keys it had just consumed. The result
## carried the SAME items under several keys at once, and that shape persisted
## into every save. FiveParsecsCampaignCore.get_all_equipment() then unions
## equipment + weapons + armor + gear, so the restore loop in
## GameState._restore_equipment_from_campaign() received each item TWICE and
## emitted one "Equipment with ID already exists" per item on every boot.
##
## Observed in a real save before the fix: "equipment" and "gear" byte-identical,
## 8 items each, same persisted ids, 8 errors per launch.
##
## gdUnit4 v6.0.3 compatible.

const FinalizationService = preload(
	"res://src/core/campaign/creation/CampaignFinalizationService.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

## The exact shape observed in the corrupted save: the flat list and the category
## list holding the same id-bearing items, plus the id-less creation copy.
func _triplicated_equipment_data() -> Dictionary:
	var with_ids: Array = [
		{"id": "rattle_gun_5168_92512", "name": "Rattle Gun"},
		{"id": "military_rifle_5168_68459", "name": "Military Rifle"},
		{"id": "handgun_5169_4840", "name": "Handgun"},
	]
	return {
		"equipment": with_ids.duplicate(true),
		"gear": with_ids.duplicate(true),
		"weapons": [],
		"armor": [],
		# id-less creation-format copy; get_all_equipment() never reads this key
		"items": [{"name": "Rattle Gun"}, {"name": "Military Rifle"}, {"name": "Handgun"}],
		"credits": 12,
	}


func _ids_of(items: Array) -> Array:
	var out: Array = []
	for it in items:
		if it is Dictionary and not str(it.get("id", "")).is_empty():
			out.append(str(it["id"]))
	return out


# --- The source fix: finalization must not emit the consumed keys -------------

func test_transform_erases_the_keys_it_folded_in() -> void:
	var svc := FinalizationService.new()
	var out: Dictionary = svc._transform_equipment_data_for_turn_system(
		_triplicated_equipment_data())
	for consumed in ["weapons", "armor", "gear", "items"]:
		assert_bool(out.has(consumed)).override_failure_message(
			"'%s' survived the transform; it will duplicate into the save" % consumed
		).is_false()


func test_transform_keeps_the_canonical_flat_stash() -> void:
	var svc := FinalizationService.new()
	var out: Dictionary = svc._transform_equipment_data_for_turn_system(
		_triplicated_equipment_data())
	assert_bool(out.has("equipment")).is_true()
	assert_bool(out["equipment"] is Array).is_true()


func test_transform_output_has_no_duplicate_ids() -> void:
	# The union of equipment + gear contained each id twice going in.
	var svc := FinalizationService.new()
	var out: Dictionary = svc._transform_equipment_data_for_turn_system(
		_triplicated_equipment_data())
	var ids := _ids_of(out["equipment"])
	var unique := {}
	for i in ids:
		unique[i] = true
	assert_int(ids.size()).override_failure_message(
		"duplicate ids survived finalization: %s" % str(ids)
	).is_equal(unique.size())


func test_transform_preserves_credits() -> void:
	# Guard the erase loop against over-reaching into unrelated keys.
	var svc := FinalizationService.new()
	var out: Dictionary = svc._transform_equipment_data_for_turn_system(
		_triplicated_equipment_data())
	assert_int(int(out.get("credits", -1))).is_equal(12)


func test_transform_still_folds_a_split_only_payload() -> void:
	# The fold itself must keep working: a creation payload with NO flat key and
	# only category keys still has to produce the flat stash.
	var svc := FinalizationService.new()
	var out: Dictionary = svc._transform_equipment_data_for_turn_system({
		"weapons": [{"id": "w1", "name": "Handgun"}],
		"gear": [{"id": "g1", "name": "Med Kit"}],
	})
	assert_int((out["equipment"] as Array).size()).is_equal(2)
	assert_bool(out.has("gear")).is_false()


# --- The end-to-end invariant on the campaign resource -----------------------

func test_get_all_equipment_returns_each_item_once_after_finalization() -> void:
	# get_all_equipment() unions equipment + weapons + armor + gear. Once
	# finalization stops emitting the category keys, that union is just the stash.
	var svc := FinalizationService.new()
	var out: Dictionary = svc._transform_equipment_data_for_turn_system(
		_triplicated_equipment_data())

	var campaign = CampaignCore.new()
	campaign.set_starting_equipment(out)

	var all_items: Array = campaign.get_all_equipment()
	var ids := _ids_of(all_items)
	var unique := {}
	for i in ids:
		unique[i] = true
	assert_int(ids.size()).override_failure_message(
		"get_all_equipment() handed the restore loop duplicate ids: %s" % str(ids)
	).is_equal(unique.size())
	assert_int(ids.size()).is_equal(3)


# --- CHECK 5: the runtime invariant that catches a re-infection -------------

func _with_temp_campaign(equipment_data: Dictionary) -> Array:
	## Swaps a throwaway campaign into GameState, returns verify_consistency()'s
	## violations, and restores whatever was there. GameState is an autoload, so
	## leaving a test campaign behind would pollute every later suite.
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	if gs == null:
		return []
	var previous = gs.current_campaign
	var campaign = CampaignCore.new()
	campaign.set_starting_equipment(equipment_data)
	gs.current_campaign = campaign
	var violations: Array = gs.verify_consistency()
	gs.current_campaign = previous
	return violations


func _split_violations(violations: Array) -> Array:
	var out: Array = []
	for v in violations:
		if str(v).begins_with("SPLIT STASH"):
			out.append(str(v))
	return out


func test_check5_flags_a_stash_that_regained_category_keys() -> void:
	# The exact damage CampaignDashboard._build_equipment_section used to do by
	# writing its display split back onto the live campaign dict.
	var violations := _with_temp_campaign({
		"equipment": [{"id": "a1", "name": "Rattle Gun"}],
		"gear": [{"id": "a1", "name": "Rattle Gun"}],
	})
	assert_int(_split_violations(violations).size()).override_failure_message(
		"CHECK 5 did not flag a split stash; got: %s" % str(violations)
	).is_greater(0)


func test_check5_is_quiet_on_a_canonical_stash() -> void:
	# Anti-false-positive: the healthy shape must not trip it, or the check gets
	# ignored as noise and stops being a guard at all.
	var violations := _with_temp_campaign({
		"equipment": [{"id": "a1", "name": "Rattle Gun"}],
		"credits": 12,
	})
	assert_int(_split_violations(violations).size()).override_failure_message(
		"CHECK 5 false-positived on a canonical stash: %s" % str(violations)
	).is_equal(0)


func test_the_corrupt_shape_really_did_duplicate() -> void:
	# Anti-vacuous guard: proves the invariant above is worth asserting by showing
	# the pre-fix shape genuinely produces doubles through the same accessor. If
	# this ever stops failing to dedupe, get_all_equipment() changed and the tests
	# above are no longer testing what they claim.
	var campaign = CampaignCore.new()
	campaign.set_starting_equipment(_triplicated_equipment_data())
	var ids := _ids_of(campaign.get_all_equipment())
	assert_int(ids.size()).override_failure_message(
		"expected the corrupt shape to yield 6 id-bearing entries (3 doubled)"
	).is_equal(6)
