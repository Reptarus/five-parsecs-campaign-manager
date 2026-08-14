extends GdUnitTestSuite
## Equipment prices, repairs and the market (audit rows 203 + 204).
##
## Core Rules p.125 step 11 is the WHOLE of Purchase Items, verbatim:
##   "You may pay 3 credits to receive a roll on the Military Weapon Table, Gear
##    Table or Gadget Table in the Character Creation chapter (p.28-29)."
##   "You may purchase any number of Hand Guns, Blades, Colony Rifles, or
##    Shotguns for 1 credit each."
##   "You may sell up to 3 items, earning 1 credit for each."
## Core Rules p.78 "Repair Your Kit" is a FREE crew task — 1D6 + Savvy, +1 for an
## Engineer, "You may spend credits on spare parts. Every 1 credit spent before
## the roll grants a +1 bonus." There is no shop, no resale percentage, and no
## repair fee anywhere in either rulebook.
##
## TWO fabricated economies sat next to those flat numbers:
##   `src/ui/screens/equipment/EquipmentManager.gd` — 515 lines quoting a base
##     buy price of 500 credits, sell at 60% of buy, repair at 2500, and Quick
##     (+50%) / Quality (+100%) repair tiers. Reachable from the campaign-creation
##     wizard's "Manual Select" button, i.e. shown to a crew holding ~4 credits.
##   `src/core/systems/TradingSystem.gd` — 828 lines of market volatility, price
##     fluctuation, per-world-type market conditions and supply/demand. It was
##     CONSTRUCTED on every World Phase entry and the instance was never used.
##
## Both are deleted. This suite is the regression pin: the numbers must not come
## back, and the book prices must stay put.
##
## gdUnit4 v6.0.3 compatible.

const PURCHASE_SRC := "res://src/ui/screens/world/components/PurchaseItemsComponent.gd"
const EQUIP_SCREEN_SRC := "res://src/ui/screens/equipment/EquipmentManager.gd"
const EQUIP_SCREEN_SCENE := "res://src/ui/screens/equipment/EquipmentManager.tscn"
const UPKEEP_SRC := "res://src/core/systems/UpkeepSystem.gd"
const TRADING_SRC := "res://src/core/systems/TradingSystem.gd"


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var t: String = f.get_as_text()
	f.close()
	return t


## Comments stripped — this suite asserts the ABSENCE of strings that are named
## in the very comments explaining why they were removed.
func _code_only(path: String) -> String:
	var out: PackedStringArray = []
	for line in _read(path).split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


func test_the_book_prices_are_the_only_prices() -> void:
	## p.125's three numbers, as constants, at the one live purchase screen.
	var src: String = _code_only(PURCHASE_SRC)
	assert_bool(src.contains("const BASIC_ITEM_COST: int = 1")).is_true()
	assert_bool(src.contains("const TABLE_ROLL_COST: int = 3")).is_true()
	assert_bool(src.contains("const MAX_ITEMS_SOLD_PER_TURN: int = 3")).is_true()
	assert_bool(src.contains("const SELL_PRICE_PER_ITEM: int = 1")).is_true()


func test_trading_system_is_gone() -> void:
	## An 828-line fabricated market economy, instantiated every World Phase entry
	## and never used.
	assert_bool(FileAccess.file_exists(TRADING_SRC)) \
		.override_failure_message(
			"TradingSystem.gd is back. It has no basis in either rulebook —"
			+ " p.125 is 3cr per roll / 1cr basics / 1cr sell, flat.").is_false()
	var src: String = _code_only(PURCHASE_SRC)
	assert_bool(src.contains("TradingSystem")) \
		.override_failure_message("PurchaseItemsComponent references TradingSystem again") \
		.is_false()


func test_the_fabricated_shop_and_repair_service_are_gone() -> void:
	## The exact fabricated numbers, so a re-add is caught by value and not just
	## by function name.
	var src: String = _code_only(EQUIP_SCREEN_SRC)
	for banned in [
		"_calculate_buy_price", "_calculate_sell_price", "_calculate_repair_cost",
		"_generate_market_equipment", "_on_buy_equipment_pressed",
		"_on_sell_equipment_pressed", "_on_repair_equipment_pressed",
		"Quick Repair", "Quality Repair", "0.6", "2500",
	]:
		assert_bool(src.contains(banned)) \
			.override_failure_message(
				"the fabricated equipment shop is back in EquipmentManager.gd: %s"
				% banned).is_false()


func test_the_shop_buttons_are_gone_from_the_scene() -> void:
	## RULE 0: the scene is the authority on what is actually wired. Leaving the
	## buttons behind would leave two [connection] entries pointing at methods
	## that no longer exist — a dead button, which is exactly what
	## lint_tscn_connections exists to catch.
	var scene: String = _read(EQUIP_SCREEN_SCENE)
	for banned in ["TradeButton", "RepairButton", "_on_trade_pressed", "_on_repair_pressed"]:
		assert_bool(scene.contains(banned)) \
			.override_failure_message("EquipmentManager.tscn still has %s" % banned).is_false()
	# The assignment half — this screen's real job — must survive.
	assert_bool(scene.contains("GenerateEquipmentButton")).is_true()
	assert_bool(_code_only(EQUIP_SCREEN_SRC).contains("func _assign_equipment_to_crew")).is_true()
	assert_bool(_code_only(EQUIP_SCREEN_SRC).contains("func set_crew_data")).is_true()


func test_upkeep_credits_have_no_dead_economy_branch() -> void:
	## `economy_system` was declared `= null` and never assigned anywhere in the
	## repo, so both "PRIORITY 1: use EconomySystem" branches were permanently
	## false and the FALLBACK was always the real implementation. A dead branch
	## that names a system makes that system look like the authority.
	var src: String = _code_only(UPKEEP_SRC)
	assert_bool(src.contains("economy_system")) \
		.override_failure_message(
			"UpkeepSystem has an economy_system branch again — check it can"
			+ " actually be reached before reinstating it").is_false()
