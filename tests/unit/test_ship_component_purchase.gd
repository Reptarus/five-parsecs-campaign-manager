extends GdUnitTestSuite
## Core Rules p.60 Ship Components, bought on the Ship screen.
##
## p.60: "Only one Component can be added each turn. When purchased, the Component is
## fully functional at the beginning of the next campaign turn." The screen asked the
## GameState autoload for get_credits()/remove_credits(), which it does not have, so
## the affordability guard was always false and every Component was FREE. The
## dead-guard lint cannot see that: it matches method names, and both names exist on
## GameStateManager. Compendium p.147: salvage pays 1:1 toward a ship module.
##
## The screen also carried a second copy of Upkeep (Repair, Pay Debt) and a fuel tank
## the rules do not have (Refuel, "Initiate Travel"). Those controls are gone; hull and
## debt are shown, not edited.

const ShipScene = preload("res://src/ui/screens/ships/ShipManager.tscn")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const SalvageLedger = preload("res://src/core/campaign/SalvageLedger.gd")
const SaveDirGuard = preload("res://tests/fixtures/helpers/save_dir_guard.gd")

const CHEAP := "Data Base"
const SECOND := "Cargo Hold"

var _snap: Dictionary = {}
var _prev_campaign = null
var _campaign = null


func before_test() -> void:
	_snap = SaveDirGuard.snapshot()
	_prev_campaign = get_node("/root/GameState").current_campaign


func after_test() -> void:
	get_node("/root/GameState").current_campaign = _prev_campaign
	SaveDirGuard.restore(_snap)


func _setup(credits: int, salvage: int = 0) -> Node:
	_campaign = CampaignCore.new()
	_campaign.credits = credits
	_campaign.ship_data = {"name": "Test Hull", "type": "Worn Freighter",
		"hull_points": 30, "max_hull": 30, "traits": [], "components": []}
	_campaign.progress_data["turns_played"] = 3
	get_node("/root/GameState").current_campaign = _campaign
	if salvage > 0:
		SalvageLedger.add_units(_campaign, salvage)
	var screen: Node = auto_free(ShipScene.instantiate())
	add_child(screen)
	return screen


func _id(screen: Node, comp_name: String) -> String:
	for comp: Variant in screen._components_db:
		if comp is Dictionary and comp.get("name", "") == comp_name:
			return str(comp.get("id", ""))
	return ""


func _credits() -> int:
	return int(get_node("/root/GameStateManager").get_credits())


func test_a_purchase_is_paid_for() -> void:
	var screen := _setup(100)
	var cost: int = screen._get_component_cost(CHEAP)
	assert_int(cost).is_greater(0)
	screen._on_upgrade_purchased(CHEAP)
	assert_int(_credits()).is_equal(100 - cost)
	assert_array(_campaign.ship_data["components"]).contains([_id(screen, CHEAP)])


func test_an_unaffordable_purchase_spends_nothing() -> void:
	var screen := _setup(0, 2)
	assert_int(screen._get_component_cost(CHEAP)).is_greater(2)
	screen._on_upgrade_purchased(CHEAP)
	assert_array(_campaign.ship_data["components"]).is_empty()
	assert_int(_credits()).is_equal(0)
	# The salvage offered toward it is handed back.
	assert_int(SalvageLedger.get_units(_campaign)).is_equal(2)


func test_salvage_pays_toward_a_module() -> void:
	var screen := _setup(0, 50)
	var cost: int = screen._get_component_cost(CHEAP)
	screen._on_upgrade_purchased(CHEAP)
	assert_array(_campaign.ship_data["components"]).contains([_id(screen, CHEAP)])
	assert_int(SalvageLedger.get_units(_campaign)).is_equal(50 - cost)


func test_one_component_per_turn() -> void:
	var screen := _setup(100)
	var first: int = screen._get_component_cost(CHEAP)
	screen._on_upgrade_purchased(CHEAP)
	screen._on_upgrade_purchased(SECOND)
	assert_int(_campaign.ship_data["components"].size()).is_equal(1)
	assert_int(_credits()).is_equal(100 - first)
	# A new turn opens the slot again.
	_campaign.progress_data["turns_played"] = 4
	screen._on_upgrade_purchased(SECOND)
	assert_int(_campaign.ship_data["components"].size()).is_equal(2)


func test_a_component_works_from_the_next_turn() -> void:
	var screen := _setup(100)
	var id := _id(screen, CHEAP)
	screen._on_upgrade_purchased(CHEAP)
	assert_bool(ShipComponentQuery.has_component(id)).is_false()
	_campaign.progress_data["turns_played"] = 4
	assert_bool(ShipComponentQuery.has_component(id)).is_true()


func test_a_component_saved_without_a_stamp_works() -> void:
	# Every ship saved before this rule carries no install turn.
	_setup(0)
	_campaign.ship_data["components"] = ["data_base"]
	assert_bool(ShipComponentQuery.has_component("data_base")).is_true()


func test_hull_and_debt_are_shown_not_edited() -> void:
	var screen := _setup(10)
	assert_object(screen.current_hull).is_instanceof(Label)
	assert_object(screen.debt_amount).is_instanceof(Label)
	for gone: String in ["RepairButton", "PayDebtButton", "RefuelButton",
			"TravelButton", "UpgradeButton"]:
		assert_object(screen.find_child(gone, true, false)).is_null()
