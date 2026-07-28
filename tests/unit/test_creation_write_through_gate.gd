extends GdUnitTestSuite
## During campaign creation, equipment must not write through to the campaign
## GameState currently holds.
##
## THE BUG THIS EXISTS TO PREVENT
## EquipmentManager.add_equipment() writes each item through to
## GameState.current_campaign.equipment_data for persistence. That is correct during
## play, but the campaign-creation wizard does not call set_current_campaign() until
## AFTER finalization (CampaignCreationUI.gd:335) — so while the wizard is open,
## "current" is still the PREVIOUSLY PLAYED campaign. EquipmentPanel loads the new
## crew's starting loadout into the manager at step 4, and every one of those items
## was being appended to the old campaign's ship stash.
##
## The new campaign never needed the write-through: finalization builds its
## equipment_data from the wizard's own data (CampaignFinalizationService.gd:280).
##
## gdUnit4 v6.0.3 compatible.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")


func _eq_mgr() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/EquipmentManager")


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameState")


var _previous_campaign = null
var _swapped := false


func after_test() -> void:
	## GameState and EquipmentManager are live autoloads — always restore them.
	var eq := _eq_mgr()
	if eq and eq.has_method("set_campaign_write_through"):
		eq.set_campaign_write_through(true)
	if eq and eq.has_method("clear_all_equipment"):
		eq.clear_all_equipment()
	if _swapped:
		var gs := _gs()
		if gs:
			gs.current_campaign = _previous_campaign
		_previous_campaign = null
		_swapped = false


func _install_prior_campaign() -> Variant:
	var gs := _gs()
	if gs == null:
		return null
	var prior = CampaignCore.new()
	prior.campaign_id = "the_previous_campaign"
	prior.equipment_data = {"equipment": []}
	_previous_campaign = gs.current_campaign
	_swapped = true
	gs.current_campaign = prior
	return prior


func test_write_through_is_suppressed_while_creating() -> void:
	var eq := _eq_mgr()
	if eq == null or not eq.has_method("set_campaign_write_through"):
		fail("EquipmentManager.set_campaign_write_through is missing — the gate is gone")
		return
	var prior = _install_prior_campaign()
	if prior == null:
		return

	eq.clear_all_equipment()
	eq.set_campaign_write_through(false)          # what the wizard does on open
	eq.add_equipment({"id": "new_crew_pistol", "name": "Hand Gun"})

	var prior_stash: Array = prior.equipment_data.get("equipment", [])
	assert_int(prior_stash.size()).override_failure_message(
		"the new campaign's starting gear was appended to the PREVIOUS campaign's stash"
	).is_equal(0)


func test_the_item_still_reaches_the_runtime_registry() -> void:
	# Suppressing the write-through must not stop the wizard's own panels from
	# seeing the equipment they just generated.
	var eq := _eq_mgr()
	if eq == null or not eq.has_method("set_campaign_write_through"):
		return
	if _install_prior_campaign() == null:
		return

	eq.clear_all_equipment()
	eq.set_campaign_write_through(false)
	eq.add_equipment({"id": "visible_item", "name": "Blade"})

	assert_int(eq.get_ship_stash_count()).is_equal(1)


func test_write_through_resumes_once_re_enabled() -> void:
	# _exit_tree() restores it; if that ever regressed, the LIVE campaign would stop
	# persisting its stash — a worse bug than the one being fixed.
	var eq := _eq_mgr()
	if eq == null or not eq.has_method("set_campaign_write_through"):
		return
	var live = _install_prior_campaign()
	if live == null:
		return

	eq.clear_all_equipment()
	eq.set_campaign_write_through(false)
	eq.set_campaign_write_through(true)
	eq.add_equipment({"id": "played_item", "name": "Rifle"})

	var stash: Array = live.equipment_data.get("equipment", [])
	assert_int(stash.size()).override_failure_message(
		"the live campaign stopped persisting its ship stash"
	).is_equal(1)
