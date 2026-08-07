extends GdUnitTestSuite
## Core Rules p.125 step 11 "Purchase Items", p.125 selling, and p.54 consumables.
##
## Three defects in one screen, all of them silent:
##
## 1. THE THREE TABLE ROLLS ROLLED NO TABLE. p.125: "You may pay 3 credits to
##    receive a roll on the Military Weapon Table, Gear Table or Gadget Table IN
##    THE CHARACTER CREATION CHAPTER (p.28-29)." All three instead filtered
##    equipment_database.json — the weapon/armor STATS catalogue — by invented
##    categories ("not Pistol, not Melee, not Grenade"; every gear row plus every
##    attachment; "Utility Device with rarity != Common") and picked uniformly.
##    The p.28 Military Weapon Table is EIGHT rows and holds no pistols, so 3
##    credits could return a 1-credit Hand Gun.
##
## 2. SELLING PAID BUT DID NOT REMOVE. `_on_sell_pressed` mutated `stash_items`,
##    a `.duplicate(true)` local copy, and credited the campaign directly — so
##    the same item could be sold every turn forever while the stash never
##    shrank. It also filtered damaged items out of the sell list (p.125 has no
##    condition qualifier) while indexing the UNFILTERED array by the list row.
##
## 3. THE CONSUMABLE PICKER AND THE USE DISAGREED ABOUT WHERE THE STASH IS.
##    `get_stash_consumables()` reads the owner; `use_stash_consumable()` read
##    `_equipment_storage`, the load-time cache. Anything acquired mid-session
##    listed in the in-battle picker and returned `{"used": false}` when tapped.
##
## gdUnit4 v6.0.3 compatible.

const PurchaseComponentScene = preload(
	"res://src/ui/screens/world/components/PurchaseItemsComponent.tscn")
const StartingEquipmentGeneratorClass = preload(
	"res://src/core/character/Equipment/StartingEquipmentGenerator.gd")

const PURCHASE_SRC := "res://src/ui/screens/world/components/PurchaseItemsComponent.gd"
const WIZARD_SRC := "res://src/ui/screens/postbattle/PostBattleSequence.gd"
const EQUIP_MGR_SRC := "res://src/core/equipment/EquipmentManager.gd"
const GEAR_DB := "res://data/gear_database.json"


func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var t: String = f.get_as_text()
	f.close()
	return t


## Source WITHOUT comment lines.
##
## A scan that forbids a string has to ignore comments, or the comment explaining
## why the string is forbidden trips it. Three of these assertions failed on
## their own fix notes ("the invented categorisation", "do NOT add credits here
## as well", "read _equipment_storage again") before this existed.
func _code_only(path: String) -> String:
	var out: PackedStringArray = []
	for line: String in _src(path).split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


func _book_table_names(table: String) -> Array:
	var f := FileAccess.open(GEAR_DB, FileAccess.READ)
	assert_object(f).is_not_null()
	var json := JSON.new()
	var ok: int = json.parse(f.get_as_text())
	f.close()
	assert_int(ok).is_equal(OK)
	var names: Array = []
	for row: Variant in (json.data as Dictionary).get("weapon_tables", {}).get(table, []):
		names.append(str((row as Dictionary).get("name", "")))
	return names


# ── 1. The p.28-29 tables, with their printed weights ───────────────────────

func test_the_three_purchase_rolls_come_from_the_creation_tables() -> void:
	var component: Node = auto_free(PurchaseComponentScene.instantiate())
	add_child(component)

	for spec: Array in [
		["military_weapon", "_roll_on_military_table"],
		["gear", "_roll_on_gear_table"],
		["gadget", "_roll_on_gadget_table"],
	]:
		var table: String = spec[0]
		var method: String = spec[1]
		var legal: Array = _book_table_names(table)
		assert_int(legal.size()).override_failure_message(
			"gear_database.json weapon_tables.%s is empty" % table).is_greater(0)
		var seen := {}
		for _i in 60:
			var item: Dictionary = component.call(method)
			var item_name: String = str(item.get("name", ""))
			assert_bool(item_name in legal).override_failure_message(
				"%s returned '%s', which is NOT on the p.28-29 %s table (%s)."
				% [method, item_name, table, str(legal)]
				+ " It is filtering equipment_database.json again.").is_true()
			assert_int(int(item.get("cost", 0))).override_failure_message(
				"p.125: a table roll costs 3 credits").is_equal(3)
			seen[item_name] = true
		assert_int(seen.size()).override_failure_message(
			"%s produced only %d distinct results over 60 rolls — it is not"
			% [method, seen.size()] + " rolling the table").is_greater(2)


func test_the_military_table_holds_no_cheap_pistols() -> void:
	# The specific symptom the ledger recorded: 3 credits returning a 1-credit
	# item. The p.28 table is 8 rows and none of them is a pistol.
	var legal: Array = _book_table_names("military_weapon")
	assert_int(legal.size()).override_failure_message(
		"p.28 Military Weapon Table is 8 rows").is_equal(8)
	for cheap: String in ["Hand Gun", "Scrap Pistol", "Hold Out Pistol", "Colony Rifle",
			"Shotgun", "Blade"]:
		assert_bool(cheap in legal).override_failure_message(
			"'%s' is not on the p.28 Military Weapon Table" % cheap).is_false()


func test_the_purchase_screen_no_longer_filters_the_stats_database() -> void:
	var src: String = _code_only(PURCHASE_SRC)
	for ghost: String in ["_load_equipment_db", "rarity", "Utility Device"]:
		assert_bool(src.contains(ghost)).override_failure_message(
			"PurchaseItemsComponent still references '%s' — the invented"
			% ghost + " categorisation is back").is_false()


func test_the_one_credit_basics_are_the_four_the_book_names() -> void:
	var component: Node = auto_free(PurchaseComponentScene.instantiate())
	add_child(component)
	var names: Array = []
	for item: Variant in component.get("basic_items"):
		names.append(str((item as Dictionary).get("name", "")))
		assert_int(int((item as Dictionary).get("cost", 0))).override_failure_message(
			"p.125: 'any number of Hand Guns, Blades, Colony Rifles, or Shotguns"
			+ " for 1 credit each'").is_equal(1)
	# "Hand Gun", two words — the name every table and the equipment database
	# uses. "Handgun" matches nothing and stashes a phantom.
	assert_array(names).contains(["Hand Gun", "Blade", "Colony Rifle", "Shotgun"])
	assert_bool("Handgun" in names).override_failure_message(
		"'Handgun' is not an item name anywhere in the data").is_false()


# ── 2. Selling: no condition filter, and the item actually leaves ───────────

func test_selling_has_no_condition_restriction() -> void:
	var src: String = _code_only(PURCHASE_SRC)
	assert_bool(src.contains("if not damaged:")).override_failure_message(
		"the sell list filters damaged items again — p.125 says 'You may sell up"
		+ " to 3 items, earning 1 credit for each', with no condition qualifier"
	).is_false()


func test_selling_routes_through_the_api_that_removes_the_item() -> void:
	var src: String = _code_only(PURCHASE_SRC)
	var start: int = src.find("func _on_sell_pressed")
	assert_int(start).is_greater(-1)
	var body: String = src.substr(start, src.find("\nfunc ", start + 10) - start)
	assert_bool(body.contains("sell_equipment")).override_failure_message(
		"selling no longer calls EquipmentManager.sell_equipment() — the only"
		+ " API that removes the item AND pays for it. Without it the player is"
		+ " paid and keeps the item: free credits, every turn.").is_true()
	# sell_equipment credits internally; a second add_credits here double-pays.
	assert_bool(body.contains("add_credits")).override_failure_message(
		"_on_sell_pressed adds credits itself as well as calling sell_equipment()"
		+ " — that pays twice for one item").is_false()


func test_the_sell_list_maps_rows_back_to_stash_indices() -> void:
	var src: String = _code_only(PURCHASE_SRC)
	assert_bool(src.contains("_sell_row_to_stash")).override_failure_message(
		"the sell list indexes stash_items by the ItemList row again; any"
		+ " filtering silently sells the wrong item").is_true()


# ── 3. Seeding order, and the owner-backed consumable ──────────────────────

func test_the_purchase_component_is_seeded_after_it_enters_the_tree() -> void:
	# @onready vars are null on a freshly instantiate()'d node, so seeding before
	# add_child() leaves the Sell pane empty for the whole step.
	var src: String = _code_only(WIZARD_SRC)
	var add_at: int = src.find("step_content.add_child(purchase_component)")
	var init_at: int = src.find("purchase_component.initialize_purchase_phase")
	assert_int(add_at).override_failure_message(
		"the wizard no longer adds the purchase component").is_greater(-1)
	assert_int(init_at).override_failure_message(
		"the wizard no longer seeds the purchase component").is_greater(-1)
	assert_bool(add_at < init_at).override_failure_message(
		"initialize_purchase_phase() runs BEFORE add_child(), so %SellItemsList is"
		+ " still null and _populate_sell_items() bails at its own guard — the"
		+ " Sell pane never lists anything and p.125 selling has no surface").is_true()


func test_use_stash_consumable_resolves_against_the_owner() -> void:
	var src: String = _code_only(EQUIP_MGR_SRC)
	var start: int = src.find("func use_stash_consumable")
	assert_int(start).is_greater(-1)
	var body: String = src.substr(start, src.find("\nfunc ", start + 10) - start)
	assert_bool(body.contains("get_ship_stash()")).override_failure_message(
		"use_stash_consumable reads _equipment_storage again. That cache is"
		+ " populated only at campaign load, while get_stash_consumables() — the"
		+ " list the in-battle picker shows — reads the owner. Anything acquired"
		+ " mid-session is listed and unusable.").is_true()
	var head: String = body.substr(0, body.find("for eq in"))
	assert_bool(head.contains("_equipment_storage")).override_failure_message(
		"the lookup loop must not iterate the cache").is_false()
