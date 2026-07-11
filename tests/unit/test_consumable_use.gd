extends GdUnitTestSuite

## Consumable use from the Stash (Core Rules p.54 — a Free Action in battle, any crew
## member may use a Stash consumable). This is a companion: use returns the effect text
## for the player to apply at the table, and tracks depletion (single-use → removed).

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

var _gs
var _saved
var _eqm

func before_test() -> void:
	_gs = get_node_or_null("/root/GameState")
	_saved = _gs.current_campaign if _gs and "current_campaign" in _gs else null
	_gs.current_campaign = CampaignCore.new()
	_eqm = get_node_or_null("/root/EquipmentManager")

func after_test() -> void:
	_gs.current_campaign = _saved

func test_single_use_consumable_lists_uses_and_is_removed() -> void:
	var cid := "test_stim_%d" % (randi() % 100000)
	_eqm.add_to_ship_stash({
		"id": cid, "name": "Stim-pack", "type": "Consumable",
		"single_use": true, "description": "Prevent casualty — remain on table with 1 Stun."})

	# It's listed as a stash consumable.
	var listed := false
	for c in _eqm.get_stash_consumables():
		if str(c.get("id", "")) == cid:
			listed = true
	assert_bool(listed).is_true()

	# Using it returns the effect text and reports depletion.
	var r: Dictionary = _eqm.use_stash_consumable(cid)
	assert_bool(r.get("used", false)).is_true()
	assert_str(str(r.get("effect", ""))).contains("casualty")
	assert_bool(r.get("depleted", false)).is_true()

	# And it's gone from the stash (single-use).
	var still := false
	for c in _eqm.get_stash_consumables():
		if str(c.get("id", "")) == cid:
			still = true
	assert_bool(still).is_false()

func test_use_missing_consumable_returns_unused() -> void:
	var r: Dictionary = _eqm.use_stash_consumable("nonexistent_id_xyz")
	assert_bool(r.get("used", true)).is_false()
