extends GdUnitTestSuite

## Core Rules p.60 "Getting a New Ship", and the surface it never had.
##
## THE GAP. `ShiplessSystem.roll_ship_offer()` and `.purchase_ship()` implemented
## p.60 correctly and had ZERO callers anywhere in `src/`. No button, no crew
## task, no world step. Meanwhile `apply_ship_destruction()` genuinely fires -
## from `GameStateManager:803` and from the invasion-flight route in
## `UpkeepPhaseComponent` - so a crew really could lose its ship and then stay
## shipless for the rest of the campaign, capped at a 5-item Stash, with no path
## back. The ledger's signature shape: correct code, no call site.
##
## p.60 verbatim: "Each campaign turn you may look for a new vessel. Roll 2D6+3
## and multiply the total by 10 to find the cost in credits. Roll once on the
## Ship Table in the Character Creation chapter (p.31). This is the ship on
## offer. You may opt to pass and look for a new ship each campaign turn. You
## can finance up to 70 credits of the cost."

const Shipless = preload("res://src/core/ship/ShiplessSystem.gd")


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var s := f.get_as_text()
	f.close()
	return s


# ── the offer ─────────────────────────────────────────────────────────────

func test_the_price_is_2d6_plus_3_times_ten() -> void:
	# 2D6+3 spans 5..15, so the price spans 50..150 and nothing else.
	var lo := 999
	var hi := 0
	for _i in range(400):
		var offer: Dictionary = Shipless.roll_ship_offer()
		var cost: int = int(offer.get("cost", 0))
		assert_bool(cost >= 50 and cost <= 150).override_failure_message(
			"price %d is outside 2D6+3 x10 (50..150)" % cost).is_true()
		assert_int(cost % 10).override_failure_message(
			"price %d is not a multiple of 10" % cost).is_equal(0)
		lo = mini(lo, cost)
		hi = maxi(hi, cost)
	assert_int(lo).override_failure_message(
		"400 offers never reached the 50 floor; lowest was %d" % lo).is_less(80)
	assert_int(hi).override_failure_message(
		"400 offers never approached the 150 ceiling; highest was %d" % hi
	).is_greater(120)


func test_the_offer_carries_an_actual_ship_from_the_p31_table() -> void:
	# "Roll once on the Ship Table in the Character Creation chapter (p.31).
	# This is the ship on offer." Before this fix the offer was a price and
	# nothing else, so a purchase would have produced a vessel with no Hull
	# Points and no traits.
	for _i in range(60):
		var offer: Dictionary = Shipless.roll_ship_offer()
		var ship: Dictionary = offer.get("ship", {})
		assert_bool(ship.is_empty()).override_failure_message(
			"the offer carries no ship; p.60 says to roll on the p.31 table"
		).is_false()
		assert_str(str(ship.get("name", ""))).is_not_empty()
		assert_int(int(ship.get("hull_points", 0))).override_failure_message(
			"ship %s was offered with 0 Hull Points" % str(ship.get("name", ""))
		).is_greater(0)


func test_the_ship_table_covers_every_roll_and_all_thirteen_rows() -> void:
	# p.31 prints THIRTEEN rows, 1-12 Worn freighter ... 96-100 Retired military
	# patrol ship. A gap would return {} and silently offer no ship.
	var spans: Array = _generation_table()
	assert_int(spans.size()).override_failure_message(
		"the p.31 Ship Table prints 13 rows; the data has %d" % spans.size()
	).is_equal(13)
	var next_expected := 1
	var ids := {}
	for row in spans:
		var span: Array = row.get("range", [])
		assert_int(int(span[0])).override_failure_message(
			"p.31 span starts at %s, expected %d (gap or overlap)"
			% [str(span), next_expected]).is_equal(next_expected)
		next_expected = int(span[1]) + 1
		ids[str(row.get("type", ""))] = true
	assert_int(next_expected).override_failure_message(
		"the p.31 spans stop at %d, not 100" % (next_expected - 1)).is_equal(101)
	assert_int(ids.size()).is_equal(13)
	assert_str(str(spans[0].get("type", ""))).override_failure_message(
		"p.31 row 1-12 must be the Worn freighter").is_equal("worn_freighter")


func _generation_table() -> Array:
	var f := FileAccess.open("res://data/ships.json", FileAccess.READ)
	assert_object(f).is_not_null()
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if raw is Dictionary:
		return (raw as Dictionary).get("generation_table", [])
	return []


func test_every_offered_ship_resolves_to_a_real_ship_type() -> void:
	# roll_ship_table() must map its span to an entry in ship_types; a typo in
	# the `type` key would return {} and the offer would carry no vessel.
	for _i in range(120):
		var ship: Dictionary = Shipless.roll_ship_table()
		assert_bool(ship.is_empty()).override_failure_message(
			"a p.31 roll resolved to no ship type").is_false()
		assert_str(str(ship.get("id", ""))).is_not_empty()
		assert_int(int(ship.get("hull_points", 0))).is_greater(0)


func test_financing_is_capped_at_seventy() -> void:
	# "You can finance up to 70 credits of the cost."
	for _i in range(200):
		var offer: Dictionary = Shipless.roll_ship_offer()
		var cost: int = int(offer.get("cost", 0))
		var fin: int = int(offer.get("max_financed", 0))
		var down: int = int(offer.get("min_down_payment", 0))
		assert_int(fin).override_failure_message(
			"financed %d exceeds the p.60 cap of 70" % fin).is_less_equal(70)
		assert_int(fin + down).override_failure_message(
			"down payment %d + financed %d != price %d" % [down, fin, cost]
		).is_equal(cost)


# ── the purchase ──────────────────────────────────────────────────────────

func _campaign() -> Resource:
	var core := load("res://src/game/campaign/FiveParsecsCampaignCore.gd")
	var c: Resource = core.new()
	return c


func test_buying_installs_the_vessel_not_just_a_flag() -> void:
	# Before the fix `purchase_ship()` set has_ship = true and wrote no
	# ship_data, so the crew owned a boolean: no name, no Hull Points, no traits.
	var c := _campaign()
	if c == null or not ("has_ship" in c):
		return
	var offer: Dictionary = Shipless.roll_ship_offer()
	var ship: Dictionary = offer.get("ship", {})
	var result: Dictionary = Shipless.purchase_ship(
		c, 0, int(offer.get("max_financed", 0)), ship)
	assert_bool(bool(result.get("success", false))).override_failure_message(
		str(result.get("reason", "purchase failed"))).is_true()
	assert_bool(bool(c.has_ship)).is_true()
	if "ship_data" in c and c.ship_data is Dictionary:
		var sd: Dictionary = c.ship_data
		assert_str(str(sd.get("name", ""))).override_failure_message(
			"the purchased ship has no name"
		).is_equal(str(ship.get("name", "")))
		assert_int(int(sd.get("hull_points", 0))).override_failure_message(
			"the purchased ship has no Hull Points"
		).is_equal(int(ship.get("hull_points", 0)))
		assert_int(int(sd.get("max_hull_points", 0))).is_greater(0)


func test_financing_over_the_cap_is_refused() -> void:
	var c := _campaign()
	if c == null:
		return
	var result: Dictionary = Shipless.purchase_ship(c, 0, 71, {})
	assert_bool(bool(result.get("success", true))).override_failure_message(
		"financing 71 credits was accepted; p.60 caps it at 70"
	).is_false()


# ── the surface, which is the half that was missing ───────────────────────

func test_the_upkeep_step_can_actually_reach_the_rule() -> void:
	var src: String = _read(
		"res://src/ui/screens/world/components/UpkeepPhaseComponent.gd")
	assert_str(src).override_failure_message(
		"nothing calls roll_ship_offer(); p.60 is unreachable again"
	).contains("ShiplessSystemRef.roll_ship_offer()")
	assert_str(src).override_failure_message(
		"nothing calls purchase_ship(); the offer cannot be accepted"
	).contains("ShiplessSystemRef.purchase_ship(")
	assert_str(src).override_failure_message(
		"there is no button to look for a ship"
	).contains("_on_find_ship_pressed")
	assert_str(src).override_failure_message(
		"the button must be built into the travel row so it is on screen"
	).contains("_ensure_find_ship_button(btn_row)")


func test_the_button_shows_only_when_the_crew_has_no_ship() -> void:
	# p.60's search belongs to "Being Without a Ship". Showing it beside Travel
	# on an ordinary turn would offer a second ship to a crew that has one.
	var src: String = _read(
		"res://src/ui/screens/world/components/UpkeepPhaseComponent.gd")
	assert_str(src).contains("_find_ship_button.visible = not has_ship")


func test_the_down_payment_is_charged_through_the_credits_owner() -> void:
	# Data-ownership rule: GameStateManager is the credits chokepoint and writes
	# through to the campaign. purchase_ship() is therefore handed 0 down.
	var src: String = _read(
		"res://src/ui/screens/world/components/UpkeepPhaseComponent.gd")
	assert_str(src).contains("GameStateManager.remove_credits(down)")
	assert_str(src).override_failure_message(
		"a failed purchase must refund the down payment"
	).contains("GameStateManager.modify_credits(down)")
