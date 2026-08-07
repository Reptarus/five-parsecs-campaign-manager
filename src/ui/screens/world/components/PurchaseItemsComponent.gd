extends WorldPhaseComponent
class_name PurchaseItemsComponent

## Purchase Items Component - Shopping/Trading System
## Implements Core Rules p.123 - Post-battle item purchasing
## - Buy weapons/gear (3 credits per roll on tables)
## - Sell items (1 credit each, max 3 per turn)
## - Buy basic items (Handgun, Blade, Colony Rifle, Shotgun for 1 credit)

const AdaptivePanelGroupClass = preload("res://src/ui/components/base/AdaptivePanelGroup.gd")
## Core Rules p.125 step 11, verbatim: "You may pay 3 credits to receive a roll
## on the Military Weapon Table, Gear Table or Gadget Table IN THE CHARACTER
## CREATION CHAPTER (p.28-29)." Those are the D100 tables in gear_database.json
## that campaign creation already rolls — same tables, same weights, one roller.
const StartingEquipmentGeneratorClass = preload(
	"res://src/core/character/Equipment/StartingEquipmentGenerator.gd")
## Compendium p.147 — the Scrapper trades Loot Table finds for Salvage units.
const SalvageLedgerRef = preload("res://src/core/campaign/SalvageLedger.gd")
const ScrapperTradeDialogScript = preload(
	"res://src/ui/components/dialogs/ScrapperTradeDialog.gd")
## Core Rules p.74 "Weapon licensing — Any weapon obtained through the Trade Table
## or purchased outright costs +1 credit" and "Import restrictions — You cannot
## sell any items on this world". Both accessors existed with ZERO callers.
const WorldTraitEffectsClass = preload("res://src/core/world/WorldTraitEffects.gd")

# Market system integration
var equipment_manager: Node = null

# The three purchase panes reparented into this group (set in _setup_adaptive_panels).
var _panel_group: Control = null

# UI Components
@onready var credits_display: Label = %CreditsDisplay
@onready var purchase_container: HBoxContainer = %PurchaseContainer
@onready var basic_items_list: ItemList = %BasicItemsList
@onready var table_roll_options: VBoxContainer = %TableRollOptions
@onready var sell_items_list: ItemList = %SellItemsList
@onready var cart_list: ItemList = %CartList
@onready var confirm_purchase_button: Button = %ConfirmPurchaseButton
@onready var sell_button: Button = %SellButton
@onready var roll_military_button: Button = %RollMilitaryButton
@onready var roll_gear_button: Button = %RollGearButton
@onready var roll_gadget_button: Button = %RollGadgetButton

# State
var current_credits: int = 0
var cart_items: Array[Dictionary] = []
var cart_total: int = 0
var items_sold_this_turn: int = 0
var stash_items: Array = []
var purchase_completed: bool = false

# Five Parsecs pricing (Core Rules p.123)
const BASIC_ITEM_COST: int = 1
const TABLE_ROLL_COST: int = 3
const MAX_ITEMS_SOLD_PER_TURN: int = 3
const SELL_PRICE_PER_ITEM: int = 1

# Core Rules p.125: "You may purchase any number of Hand Guns, Blades, Colony
# Rifles, or Shotguns for 1 credit each."
#
# "Hand Gun" is two words — that is the name in equipment_database.json and on
# every table that lists it. This read "Handgun", which matches NOTHING, so the
# cheapest weapon in the game went into the stash as a phantom no stats lookup
# could resolve.
var basic_items: Array[Dictionary] = [
	{"name": "Hand Gun", "type": "weapon", "category": "low_tech", "cost": 1},
	{"name": "Blade", "type": "weapon", "category": "melee", "cost": 1},
	{"name": "Colony Rifle", "type": "weapon", "category": "low_tech", "cost": 1},
	{"name": "Shotgun", "type": "weapon", "category": "low_tech", "cost": 1}
]

func _ready() -> void:
	name = "PurchaseItemsComponent"
	super._ready()
	# Initialize market systems
	equipment_manager = get_node_or_null("/root/EquipmentManager")
	# TradingSystem.new() WAS HERE and has been deleted with the class (audit row
	# 204). It was 828 lines of fabricated market economy — market volatility,
	# price fluctuation, per-world-type market conditions, rare-item chances,
	# supply/demand — none of which appears in either rulebook. Core Rules p.125
	# is the whole of Purchase Items: "You may pay 3 credits to receive a roll on
	# the Military Weapon Table, Gear Table or Gadget Table"; "any number of Hand
	# Guns, Blades, Colony Rifles, or Shotguns for 1 credit each"; "You may sell
	# up to 3 items, earning 1 credit for each." Those flat prices are what this
	# component already implements.
	#
	# It was CONSTRUCTED here on every World Phase entry (loading its JSON) and
	# the instance was then never used — `trading_system` appeared exactly three
	# times in the file: the preload, the declaration and this line. So it cost
	# load time and presented a convincing second, wrong source of truth for
	# prices sitting next to the correct constants.

func _subscribe_to_events() -> void:
	_subscribe(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)

func _connect_ui_signals() -> void:
	## Connect UI button signals
	if confirm_purchase_button:
		confirm_purchase_button.pressed.connect(_on_confirm_purchase_pressed)
	if sell_button:
		sell_button.pressed.connect(_on_sell_pressed)
	if roll_military_button:
		roll_military_button.pressed.connect(_on_roll_military_pressed)
	if roll_gear_button:
		roll_gear_button.pressed.connect(_on_roll_gear_pressed)
	if roll_gadget_button:
		roll_gadget_button.pressed.connect(_on_roll_gadget_pressed)
	if basic_items_list:
		basic_items_list.item_activated.connect(_on_basic_item_selected)
	if sell_items_list:
		sell_items_list.item_activated.connect(_on_sell_item_selected)

func _setup_initial_state() -> void:
	## Initialize component state
	cart_items.clear()
	cart_total = 0
	items_sold_this_turn = 0
	purchase_completed = false
	_populate_basic_items()
	_update_ui_display()
	_setup_adaptive_panels()

func _setup_adaptive_panels() -> void:
	if _panel_group:
		return  # _setup_initial_state may re-run; guard re-entry.
	var left_panel: Control = get_node_or_null("%LeftPanel")
	var center_panel: Control = get_node_or_null("%CenterPanel")
	var right_panel: Control = get_node_or_null("%RightPanel")
	if not (left_panel and center_panel and right_panel):
		return
	var main_content: Node = left_panel.get_parent()       # the PurchaseContainer HBox
	var vbox: Node = main_content.get_parent() if main_content else null
	if not vbox:
		return
	var idx: int = main_content.get_index()
	var group := AdaptivePanelGroupClass.new()
	group.name = "AdaptiveContent"
	# TABS in portrait: Buy / Cart / Sell are 3 distinct surfaces, so a tab strip
	# reads better on a phone than a long stacked scroll.
	group.portrait_mode = AdaptivePanelGroupClass.PortraitMode.TABS
	group.max_columns = 3
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(group)
	vbox.move_child(group, idx)
	group.add_pane(left_panel, "Buy")
	group.add_pane(center_panel, "Cart")
	group.add_pane(right_panel, "Sell")
	main_content.queue_free()  # now empty; Header + separator untouched
	_panel_group = group

## Public API
func initialize_purchase_phase(credits: int, stash: Array) -> void:
	## Initialize purchase phase with current credits and stash
	current_credits = credits
	stash_items = stash.duplicate(true)
	items_sold_this_turn = 0
	purchase_completed = false

	_populate_sell_items()
	_refresh_scrapper_button()
	_update_ui_display()

	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, {
			"phase_name": "purchase_items",
			"credits": credits
		})

func _populate_basic_items() -> void:
	## Populate basic items list
	if not basic_items_list:
		return

	basic_items_list.clear()
	for item in basic_items:
		# Every basic item on this list is a weapon (`type: "weapon"`), so the p.74
		# surcharge applies to all four. Shown in the label AND charged in
		# _on_basic_item_selected — a displayed price the cart does not honour is
		# how a player ends a turn short of Upkeep they thought they could afford.
		basic_items_list.add_item("%s (%d credit)" % [
			item.name, _weapon_cost(int(item.cost))])

## Row index in `sell_items_list` -> index in `stash_items`. The list used to be
## a FILTERED view while `_on_sell_pressed` indexed `stash_items` with the list's
## row number, so any filtering silently sold the wrong item. The filter is gone
## (see below) but the mapping is kept explicit so re-adding one cannot
## reintroduce the desync.
var _sell_row_to_stash: Array[int] = []

func _populate_sell_items() -> void:
	## Core Rules p.125, verbatim and complete: "You may sell up to 3 items,
	## earning 1 credit for each." There is NO condition qualifier — a damaged
	## item sells for the same 1 credit as any other, and p.125's Trade section
	## states the flat 1-credit price with no quality tiers either.
	##
	## This filtered out anything carrying a `damaged` key, an invented
	## restriction. It was invisible only because nothing wrote that key; the
	## p.131 Loot Table's DAMAGED rows (26-45, a fifth of all loot) now mark
	## items `needs_repair`, and a broken-but-sellable item is exactly the case
	## a player reaches for when they are one credit short of Upkeep.
	if not sell_items_list:
		return

	sell_items_list.clear()
	_sell_row_to_stash.clear()
	if _selling_forbidden():
		sell_items_list.add_item("Import restrictions: you cannot sell here (p.74)")
		sell_items_list.set_item_disabled(0, true)
		if sell_button:
			sell_button.disabled = true
			sell_button.tooltip_text = (
				"Core Rules p.74, Import restrictions: You cannot sell any items on "
				+ "this world.")
		return
	for i: int in range(stash_items.size()):
		var item: Variant = stash_items[i]
		var item_name: String = str(item.get("name", "Unknown Item")) if item is Dictionary \
			else str(item)
		# Shared predicate — reading only `needs_repair` here labelled p.131 Loot
		# damage but never the p.127 Campaign Event / p.71 Accident damage, which
		# writes `damaged`. Same item state, two spellings, half the labels.
		var broken: bool = EquipmentTransferService.is_item_damaged(item)
		var label: String = "%s%s (+%d credit)" % [
			item_name, " [needs Repair]" if broken else "", SELL_PRICE_PER_ITEM]
		sell_items_list.add_item(label)
		_sell_row_to_stash.append(i)

## Purchase Actions
func _on_basic_item_selected(index: int) -> void:
	## Add basic item to cart
	if index < 0 or index >= basic_items.size():
		return

	var item = basic_items[index].duplicate()
	# The surcharge is baked into the CART entry, not applied later at checkout:
	# `_add_to_cart` sums `cost` into `cart_total`, which is what the affordability
	# check and the charge both read. Adjusting it anywhere else would leave the
	# list price and the bill disagreeing.
	item["cost"] = _weapon_cost(int(item.get("cost", 0)))
	_add_to_cart(item)

func _on_roll_military_pressed() -> void:
	## Roll on Military Weapons Table (3 credits, +1 under p.74 Weapon licensing).
	## The affordability check must use the SAME number the cart will charge —
	## checking the base 3 while charging 4 lets a 3-credit crew add an item they
	## cannot pay for, which is the guard-applied-to-N-1-of-N shape.
	if current_credits - cart_total < _weapon_cost(TABLE_ROLL_COST):
		return

	var result = _roll_on_military_table()
	_add_to_cart(result)

func _on_roll_gear_pressed() -> void:
	## Roll on Gear Table (3 credits)
	if current_credits - cart_total < TABLE_ROLL_COST:
		return

	var result = _roll_on_gear_table()
	_add_to_cart(result)

func _on_roll_gadget_pressed() -> void:
	## Roll on Gadget Table (3 credits)
	if current_credits - cart_total < TABLE_ROLL_COST:
		return

	var result = _roll_on_gadget_table()
	_add_to_cart(result)

## ── The Scrapper (Compendium p.147) ─────────────────────────────────────────
##
## "You can visit the Scrappers once per campaign turn, and may opt to hang on to
## Salvage units if you don't find anything that interests you."
##
## Lives in the purchase step rather than post-battle Step 4 where p.147 names it,
## for a reason the book does not have to worry about: salvage PERSISTS between
## turns, so a crew holding 7 units from two battles ago must still be able to
## spend them on a turn where they banked none. Anchoring the only entry point to
## the tally would have stranded exactly that crew. The tally itself does happen
## at Step 4 (PostBattlePhase step 4d), which is what p.147 actually requires.
var _scrapper_button: Button = null


func _refresh_scrapper_button() -> void:
	var campaign: Variant = _campaign_for_scrapper()
	var units: int = SalvageLedgerRef.get_units(campaign)
	var turn: int = _current_turn()
	var can_visit: bool = campaign != null and units > 0 \
		and SalvageLedgerRef.can_visit_scrapper(campaign, turn)

	if not can_visit:
		if _scrapper_button and is_instance_valid(_scrapper_button):
			_scrapper_button.get_parent().remove_child(_scrapper_button)
			_scrapper_button.queue_free()
			_scrapper_button = null
		return

	if _scrapper_button and is_instance_valid(_scrapper_button):
		_scrapper_button.text = "Visit the Scrapper (%d Salvage)" % units
		return
	if table_roll_options == null:
		return

	_scrapper_button = Button.new()
	_scrapper_button.name = "ScrapperButton"
	_scrapper_button.text = "Visit the Scrapper (%d Salvage)" % units
	_scrapper_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	_scrapper_button.tooltip_text = (
		"Three rolls on the Loot Table, priced in Salvage units. Once per campaign "
		+ "turn (Compendium p.147).")
	_scrapper_button.pressed.connect(_on_scrapper_pressed)
	table_roll_options.add_child(_scrapper_button)


func _on_scrapper_pressed() -> void:
	var campaign: Variant = _campaign_for_scrapper()
	if campaign == null:
		return
	var dialog = ScrapperTradeDialogScript.new()
	get_tree().root.add_child(dialog)
	dialog.purchased.connect(
		func(item_names: Array, units_spent: int) -> void:
			var journal: Node = get_node_or_null("/root/CampaignJournal")
			if journal and journal.has_method("create_entry"):
				journal.create_entry({
					"type": "purchase",
					"auto_generated": true,
					"title": "Traded with the Scrapper",
					"description": "Traded %d Salvage unit(s) for %s (Compendium p.147)."
						% [units_spent, ", ".join(PackedStringArray(item_names))],
					"tags": ["salvage", "scrapper"],
				}))
	dialog.closed.connect(func() -> void: _refresh_scrapper_button())
	dialog.open_for(campaign, _current_turn())
	# The visit is consumed the moment the offers are shown, so the button goes
	# now rather than waiting for the dialog to close.
	_refresh_scrapper_button()


## Core Rules p.74: "Weapon licensing — Any weapon obtained through the Trade
## Table or purchased outright costs +1 credit."
func _weapon_cost(base_cost: int) -> int:
	return WorldTraitEffectsClass.weapon_purchase_cost(base_cost, _world_traits())


## Core Rules p.74: "Import restrictions — You cannot sell any items on this
## world." A hard prohibition, so the sell list is emptied and the button
## disabled rather than the sale failing after the click.
func _selling_forbidden() -> bool:
	return WorldTraitEffectsClass.selling_forbidden(_world_traits())


func _world_traits() -> Array:
	var campaign: Variant = _campaign_for_scrapper()
	if campaign == null:
		return []
	return WorldTraitEffectsClass.traits_for_current_world(campaign)


func _campaign_for_scrapper() -> Variant:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or not ("current_campaign" in gs):
		return null
	return gs.current_campaign


func _current_turn() -> int:
	var campaign: Variant = _campaign_for_scrapper()
	if campaign == null or not ("progress_data" in campaign):
		return 0
	var pd: Variant = campaign.progress_data
	return int((pd as Dictionary).get("turns_played", 0)) if pd is Dictionary else 0


func _add_to_cart(item: Dictionary) -> void:
	## Add item to shopping cart
	cart_items.append(item)
	cart_total += item.get("cost", 0)
	_update_cart_display()
	_update_ui_display()

func _on_sell_pressed() -> void:
	## Sell selected item
	if not sell_items_list or sell_items_list.get_selected_items().is_empty():
		return

	# The disabled button is presentation; THIS is the rule. A gate that lives
	# only in the widget is one rebuild away from being bypassed.
	if _selling_forbidden():
		return

	if items_sold_this_turn >= MAX_ITEMS_SOLD_PER_TURN:
		return

	var row: int = sell_items_list.get_selected_items()[0]
	if row < 0 or row >= _sell_row_to_stash.size():
		return
	var selected: int = _sell_row_to_stash[row]
	if selected < 0 or selected >= stash_items.size():
		return
	var item: Variant = stash_items[selected]
	var item_id: String = str(item.get("id", "")) if item is Dictionary else ""

	# THE ITEM HAS TO LEAVE THE STASH. This used to `remove_at()` on `stash_items`
	# — a `stash.duplicate(true)` local copy made in initialize_purchase_phase —
	# and then credit the campaign directly. So the player was paid and KEPT the
	# item: sell the same Frag Vest three times a turn, every turn, for free
	# credits, while the stash never shrank.
	#
	# EquipmentManager.sell_equipment() is the one API that does both halves
	# (remove_equipment -> _remove_from_campaign_stash, then add_credits). It is
	# the same call the p.76 sell-for-upkeep dialog makes — one rule, one door.
	# It credits internally, so do NOT add credits here as well.
	if item_id.is_empty() or not equipment_manager \
			or not equipment_manager.has_method("sell_equipment"):
		push_error("PurchaseItemsComponent: cannot sell '%s' — no equipment id or manager;"
			% (str(item.get("name", "?")) if item is Dictionary else str(item))
			+ " refusing to pay for an item that would not leave the stash")
		return
	if equipment_manager.sell_equipment(item_id) <= 0:
		push_warning("PurchaseItemsComponent: sell_equipment('%s') removed nothing" % item_id)
		return

	stash_items.remove_at(selected)
	current_credits += SELL_PRICE_PER_ITEM
	items_sold_this_turn += 1

	_populate_sell_items()
	_update_ui_display()


func _on_sell_item_selected(index: int) -> void:
	## Quick-sell on double-click
	if index >= 0:
		sell_items_list.select(index)
		_on_sell_pressed()

func _on_confirm_purchase_pressed() -> void:
	## Confirm and complete purchase
	if cart_total > current_credits:
		return

	# Update GameStateManager credits first
	if GameStateManager:
		GameStateManager.remove_credits(cart_total)

	# Add items to ship stash via EquipmentManager (respects 10-item capacity)
	var items_added = 0
	var items_failed = 0
	var refund_amount = 0

	for item in cart_items:
		# Ensure item has required fields
		if not item.has("id"):
			item["id"] = "purchase_" + str(Time.get_ticks_msec()) + "_" + str(randi())
		item["location"] = "ship_stash"
		
		# Use EquipmentManager (validates capacity)
		if equipment_manager and equipment_manager.has_method("add_to_ship_stash"):
			if equipment_manager.can_add_to_ship_stash():
				if equipment_manager.add_to_ship_stash(item):
					stash_items.append(item)  # Update local state
					items_added += 1
				else:
					push_warning("PurchaseItemsComponent: Failed to add %s to ship stash" % item.get("name", "Unknown"))
					refund_amount += item.get("cost", 0)
					items_failed += 1
			else:
				push_warning("PurchaseItemsComponent: Ship stash full - refunding %s" % item.get("name", "Unknown"))
				refund_amount += item.get("cost", 0)
				items_failed += 1
				break  # Stop processing remaining items
		else:
			push_error("PurchaseItemsComponent: EquipmentManager not available")
			refund_amount += item.get("cost", 0)
			items_failed += 1

	# Refund failed items
	if refund_amount > 0:
		current_credits += refund_amount
		if GameStateManager:
			GameStateManager.add_credits(refund_amount)

	# Update local state with actual items added
	current_credits -= (cart_total - refund_amount)

	purchase_completed = true

	# Publish completion event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, {
			"phase_name": "purchase_items",
			"items_purchased": cart_items.size(),
			"credits_spent": cart_total,
			"items_sold": items_sold_this_turn
		})

	# Clear cart
	cart_items.clear()
	cart_total = 0
	_update_cart_display()
	_update_ui_display()

## Table Rolls — the p.28-29 CREATION tables, rolled D100 with their printed
## weights (Core Rules p.125 step 11 names those tables explicitly).
##
## THE BUG THIS FIXES: none of the three rolled a table at all. Each filtered
## `equipment_database.json` — the weapon/armor STATS file, which lists every
## item in the game — by an invented heuristic, then picked UNIFORMLY:
##   military = "not Pistol, not Melee, not Grenade"
##   gear     = every gear row + every attachment row
##   gadget   = "Utility Device with rarity != Common"
## None of those categories exist in either book. The p.28 Military Weapon Table
## is EIGHT rows (Military Rifle 1-25 … Shatter Axe 96-100) and contains no
## pistols at all, so 3 credits could return a 1-credit Hand Gun or a Scrap
## Pistol; the Gear "table" was the entire gear catalogue at flat odds; and the
## Gadget filter leaned on a `rarity` field the book does not have. Every
## printed weight on pp.28-29 was ignored in all three.
func _roll_on_military_table() -> Dictionary:
	return _roll_creation_table("military_weapon", "weapon", "military", "Military Rifle")

func _roll_on_gear_table() -> Dictionary:
	return _roll_creation_table("gear", "gear", "", "Frag Vest")

func _roll_on_gadget_table() -> Dictionary:
	return _roll_creation_table("gadget", "gadget", "", "Battle Visor")

func _roll_creation_table(table_name: String, item_type: String, category: String,
		fallback: String) -> Dictionary:
	var dice_manager: Node = get_node_or_null("/root/DiceManager")
	var rolled: String = StartingEquipmentGeneratorClass.roll_on_weapon_table(
		table_name, dice_manager)
	# p.74 Weapon licensing applies to a weapon "purchased outright" — the p.125
	# 3-credit Military Weapon Table roll is exactly that. Gear and Gadget rolls go
	# through the same function and are NOT weapons, so the surcharge is keyed on
	# `item_type`, not applied to every table roll.
	var roll_cost: int = _weapon_cost(TABLE_ROLL_COST) if item_type == "weapon" \
		else TABLE_ROLL_COST
	var result: Dictionary = {
		"cost": roll_cost,
		"type": item_type,
		"name": rolled if not rolled.is_empty() else fallback,
		"source_table": table_name,
	}
	if not category.is_empty():
		result["category"] = category
	return result

## UI Updates
func _update_cart_display() -> void:
	## Update shopping cart display
	if not cart_list:
		return

	cart_list.clear()
	for item in cart_items:
		cart_list.add_item("%s (%d cr)" % [item.name, item.cost])

func _update_ui_display() -> void:
	## Update all UI elements
	if credits_display:
		var remaining = current_credits - cart_total
		credits_display.text = "Credits: %d (Cart: %d, Remaining: %d)" % [current_credits, cart_total, remaining]

	# Update button states. The Military table sells a WEAPON, so it carries the
	# p.74 Weapon licensing surcharge; Gear and Gadget do not.
	var remaining_credits: int = current_credits - cart_total
	var can_afford_roll = remaining_credits >= TABLE_ROLL_COST
	if roll_military_button:
		roll_military_button.disabled = 			remaining_credits < _weapon_cost(TABLE_ROLL_COST)
		roll_military_button.text = "Military Weapon Table (%d cr)" 			% _weapon_cost(TABLE_ROLL_COST)
	if roll_gear_button:
		roll_gear_button.disabled = not can_afford_roll
	if roll_gadget_button:
		roll_gadget_button.disabled = not can_afford_roll

	if confirm_purchase_button:
		confirm_purchase_button.disabled = cart_items.is_empty() or cart_total > current_credits

	if sell_button:
		sell_button.disabled = items_sold_this_turn >= MAX_ITEMS_SOLD_PER_TURN

## Event Handlers
func _on_phase_started(data: Dictionary) -> void:
	## Handle phase started events
	var phase_name = data.get("phase_name", "")
	if phase_name == "purchase_items":
		pass

## Public API
func is_purchase_completed() -> bool:
	## Check if purchase phase is completed
	return purchase_completed

func get_purchased_items() -> Array:
	## Get list of purchased items
	return cart_items.duplicate()

func get_remaining_credits() -> int:
	## Get credits remaining after cart
	return current_credits - cart_total

func reset_purchase_phase() -> void:
	## Reset for new turn
	cart_items.clear()
	cart_total = 0
	items_sold_this_turn = 0
	purchase_completed = false
	_update_ui_display()
