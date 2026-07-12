extends GdUnitTestSuite

## Fake ID on-board item grants +1 to a forged-license attempt (Core Rules p.57 —
## "+1 to all attempts to obtain a license"; the attempt itself is p.72, 1D6+Savvy,
## 6+). The bonus applies to attempt_forge_license(), NOT to the requirement roll.
## Ownership is a ship-stash name query (Fake ID is acquirable via the Gear table +
## the ship-items loot table), so no separate on-board ownership subsystem exists.

const TravelPhaseScript = preload("res://src/core/campaign/phases/TravelPhase.gd")

var _eqm
var _tp

func before_test() -> void:
	_eqm = get_node_or_null("/root/EquipmentManager")
	if _eqm and _eqm.has_method("clear_all_equipment"):
		_eqm.clear_all_equipment()
	_tp = TravelPhaseScript.new()
	add_child(_tp)  # tree membership so get_node_or_null("/root/EquipmentManager") resolves

func after_test() -> void:
	if _eqm and _eqm.has_method("clear_all_equipment"):
		_eqm.clear_all_equipment()
	if is_instance_valid(_tp):
		_tp.queue_free()

func test_no_fake_id_means_no_bonus() -> void:
	var r: Dictionary = _tp.attempt_forge_license(2)
	assert_bool(r.get("fake_id", true)).is_false()
	# total is exactly raw roll + Savvy, no +1.
	assert_int(int(r["total"])).is_equal(int(r["roll"]) + 2)

func test_fake_id_in_stash_adds_one() -> void:
	_eqm.add_to_ship_stash({"id": "fakeid_test", "name": "Fake ID", "type": "Gear"})
	var r: Dictionary = _tp.attempt_forge_license(2)
	assert_bool(r.get("fake_id", false)).is_true()
	# total is raw roll + Savvy + 1 (Fake ID). Holds on every branch, incl. a natural 1.
	assert_int(int(r["total"])).is_equal(int(r["roll"]) + 2 + 1)

func test_fake_id_name_match_is_case_insensitive() -> void:
	_eqm.add_to_ship_stash({"id": "fakeid_lc", "name": "fake id", "type": "Gear"})
	var r: Dictionary = _tp.attempt_forge_license(0)
	assert_bool(r.get("fake_id", false)).is_true()
