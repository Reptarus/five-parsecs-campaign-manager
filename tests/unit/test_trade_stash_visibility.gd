extends GdUnitTestSuite
## Items written straight to the campaign stash must be visible to every stash reader.
##
## THE BUG THIS EXISTS TO PREVENT
## campaign.equipment_data["equipment"] is the OWNER (data-ownership table).
## EquipmentManager._equipment_storage is a CACHE populated only at campaign load
## (GameState._restore_equipment_from_campaign), so for a whole play session it was a
## frozen snapshot taken at load time.
##
## TradePhasePanel writes the owner directly at SIX sites and never touches the
## manager: :436 ship component, :445 buy, :492 sell, :611 the 3-credit trade-table
## roll, :646/:665 the Merchant reroll swap. So anything bought or rolled during the
## TRADING step — a mandatory step of every campaign turn — was invisible to every
## cache reader:
##   ShipStashPanel.gd:165/:289/:418  -> "No items in ship stash"
##   UpkeepPhaseComponent.gd:303      -> not offered for the p.76 sell-for-upkeep
##   TravelPhase.gd:1181              -> a Fake ID bought in Trade granted no +1 on
##                                       the licence roll (Core Rules p.57)
##   TacticalBattleUI.gd:3866         -> consumable unusable in the next battle
##   WorldPhase.gd:1003               -> wrong stash count
##
## The dashboard reads campaign.equipment_data directly, so it DID show the item —
## producing "my gear vanished in Trade but not on the dashboard".
##
## FIX: the stash accessors resolve from the OWNER, so every consumer is correct no
## matter which writer ran.
##
## gdUnit4 v6.0.3 compatible.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

var _previous = null
var _swapped := false


func _eq() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/EquipmentManager")


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameState")


func after_test() -> void:
	var eq := _eq()
	if eq and eq.has_method("clear_all_equipment"):
		eq.clear_all_equipment()
	if _swapped:
		var gs := _gs()
		if gs:
			gs.current_campaign = _previous
		_previous = null
		_swapped = false


func _campaign_with_stash(items: Array) -> Variant:
	var gs := _gs()
	if gs == null:
		return null
	var c = CampaignCore.new()
	c.campaign_id = "trade_vis"
	c.equipment_data = {"equipment": items.duplicate(true)}
	_previous = gs.current_campaign
	_swapped = true
	gs.current_campaign = c
	return c


func _buy_in_trade(campaign, item: Dictionary) -> void:
	## Exactly what TradePhasePanel does: mutate the pool and assign it back.
	## It never calls EquipmentManager.
	var pool: Array = campaign.equipment_data.get("equipment", [])
	pool.append(item)
	campaign.equipment_data["equipment"] = pool


func test_an_item_bought_in_trade_appears_in_the_ship_stash() -> void:
	var eq := _eq()
	var c = _campaign_with_stash([])
	if eq == null or c == null:
		return
	eq.clear_all_equipment()          # the cache as it stands mid-session
	_buy_in_trade(c, {"id": "hand_gun", "name": "Hand Gun"})

	var stash: Array = eq.get_ship_stash()
	var names := []
	for i in stash:
		if i is Dictionary:
			names.append(str((i as Dictionary).get("id", "")))
	assert_array(names).override_failure_message(
		"an item bought during Trade is not in the ship stash — ShipStashPanel would show it as empty"
	).contains(["hand_gun"])


func test_the_stash_count_reflects_a_trade_purchase() -> void:
	var eq := _eq()
	var c = _campaign_with_stash([])
	if eq == null or c == null:
		return
	eq.clear_all_equipment()
	_buy_in_trade(c, {"id": "blade", "name": "Blade"})

	assert_int(eq.get_ship_stash_count()).override_failure_message(
		"get_ship_stash_count still counts the stale cache"
	).is_equal(1)


func test_a_consumable_bought_in_trade_is_usable_in_battle() -> void:
	# TacticalBattleUI:3866 -> get_stash_consumables()
	var eq := _eq()
	var c = _campaign_with_stash([])
	if eq == null or c == null:
		return
	eq.clear_all_equipment()
	_buy_in_trade(c, {"id": "stim", "name": "Stim Pack", "type": "consumable"})

	var found := false
	for item in eq.get_stash_consumables():
		if item is Dictionary and str((item as Dictionary).get("id", "")) == "stim":
			found = true
	assert_bool(found).override_failure_message(
		"a consumable bought in Trade cannot be used in the next battle"
	).is_true()


func test_a_fake_id_bought_in_trade_is_findable() -> void:
	# TravelPhase._fake_id_license_bonus scans the stash for the Core Rules p.57 +1.
	var eq := _eq()
	var c = _campaign_with_stash([])
	if eq == null or c == null:
		return
	eq.clear_all_equipment()
	_buy_in_trade(c, {"id": "fake_id", "name": "Fake ID"})

	# TravelPhase.gd:1181 calls get_ship_stash(), not get_all_equipment() — the latter
	# is the flat registry (stash + character-owned) and is cache-backed by design.
	var found := false
	for item in eq.get_ship_stash():
		if item is Dictionary and str((item as Dictionary).get("id", "")) == "fake_id":
			found = true
	assert_bool(found).override_failure_message(
		"a Fake ID bought in Trade grants no +1 on the licence roll"
	).is_true()


func test_an_item_sold_in_trade_disappears_from_the_stash() -> void:
	# The same bypass in reverse: TradePhasePanel:492 removes from the pool directly.
	var eq := _eq()
	var c = _campaign_with_stash([{"id": "old_rifle", "name": "Old Rifle"}])
	if eq == null or c == null:
		return
	c.equipment_data["equipment"] = []   # sold

	for item in eq.get_ship_stash():
		if item is Dictionary:
			assert_str(str((item as Dictionary).get("id", ""))).override_failure_message(
				"a sold item is still listed in the stash"
			).is_not_equal("old_rifle")


func test_no_campaign_falls_back_to_the_cache() -> void:
	# Battle Simulator and unit tests run with no current_campaign.
	var eq := _eq()
	var gs := _gs()
	if eq == null or gs == null:
		return
	_previous = gs.current_campaign
	_swapped = true
	gs.current_campaign = null
	eq.clear_all_equipment()
	eq.add_equipment({"id": "standalone", "name": "Standalone"})

	assert_int(eq.get_ship_stash().size()).override_failure_message(
		"the cache fallback broke for campaign-less modes"
	).is_equal(1)
