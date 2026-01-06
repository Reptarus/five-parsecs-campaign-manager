extends Control
class_name PurchaseItemsComponent

## Purchase Items Component - Shopping/Trading System
## Implements Core Rules p.123 - Post-battle item purchasing
## - Buy weapons/gear (3 credits per roll on tables)
## - Sell items (1 credit each, max 3 per turn)
## - Buy basic items (Handgun, Blade, Colony Rifle, Shotgun for 1 credit)

# Event bus integration
const CampaignTurnEventBus = preload("res://src/core/events/CampaignTurnEventBus.gd")
const TradingSystem = preload("res://src/core/systems/TradingSystem.gd")
var event_bus: CampaignTurnEventBus = null

# Market system integration
var trading_system: TradingSystem = null
var equipment_manager: Node = null

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

# Basic items available for 1 credit each
var basic_items: Array[Dictionary] = [
	{"name": "Handgun", "type": "weapon", "category": "low_tech", "cost": 1},
	{"name": "Blade", "type": "weapon", "category": "melee", "cost": 1},
	{"name": "Colony Rifle", "type": "weapon", "category": "low_tech", "cost": 1},
	{"name": "Shotgun", "type": "weapon", "category": "low_tech", "cost": 1}
]

func _ready() -> void:
	name = "PurchaseItemsComponent"
	print("PurchaseItemsComponent: Initialized - Five Parsecs shopping system")

	_initialize_event_bus()
	_connect_ui_signals()
	_setup_initial_state()

func _initialize_event_bus() -> void:
	"""Connect to the centralized event bus"""
	event_bus = get_node_or_null("/root/CampaignTurnEventBus")
	if event_bus:
		event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
		print("PurchaseItemsComponent: Connected to event bus")

	# Initialize market systems
	equipment_manager = get_node_or_null("/root/EquipmentManager")
	trading_system = TradingSystem.new()
	if equipment_manager:
		print("PurchaseItemsComponent: Connected to EquipmentManager")

func _exit_tree() -> void:
	"""Cleanup event bus subscriptions to prevent memory leaks"""
	if event_bus:
		event_bus.unsubscribe_from_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)

func _connect_ui_signals() -> void:
	"""Connect UI button signals"""
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
	"""Initialize component state"""
	cart_items.clear()
	cart_total = 0
	items_sold_this_turn = 0
	purchase_completed = false
	_populate_basic_items()
	_update_ui_display()

## Public API
func initialize_purchase_phase(credits: int, stash: Array) -> void:
	"""Initialize purchase phase with current credits and stash"""
	current_credits = credits
	stash_items = stash.duplicate(true)
	items_sold_this_turn = 0
	purchase_completed = false

	_populate_sell_items()
	_update_ui_display()

	print("PurchaseItemsComponent: Initialized with %d credits, %d stash items" % [credits, stash.size()])

	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, {
			"phase_name": "purchase_items",
			"credits": credits
		})

func _populate_basic_items() -> void:
	"""Populate basic items list"""
	if not basic_items_list:
		return

	basic_items_list.clear()
	for item in basic_items:
		basic_items_list.add_item("%s (%d credit)" % [item.name, item.cost])

func _populate_sell_items() -> void:
	"""Populate sellable items from stash"""
	if not sell_items_list:
		return

	sell_items_list.clear()
	for item in stash_items:
		var item_name = item.get("name", "Unknown Item") if item is Dictionary else str(item)
		var damaged = item.get("damaged", false) if item is Dictionary else false
		if not damaged:  # Can only sell undamaged items
			sell_items_list.add_item("%s (+%d credit)" % [item_name, SELL_PRICE_PER_ITEM])

## Purchase Actions
func _on_basic_item_selected(index: int) -> void:
	"""Add basic item to cart"""
	if index < 0 or index >= basic_items.size():
		return

	var item = basic_items[index].duplicate()
	_add_to_cart(item)

func _on_roll_military_pressed() -> void:
	"""Roll on Military Weapons Table (3 credits)"""
	if current_credits - cart_total < TABLE_ROLL_COST:
		print("PurchaseItemsComponent: Not enough credits for table roll")
		return

	var result = _roll_on_military_table()
	_add_to_cart(result)

func _on_roll_gear_pressed() -> void:
	"""Roll on Gear Table (3 credits)"""
	if current_credits - cart_total < TABLE_ROLL_COST:
		print("PurchaseItemsComponent: Not enough credits for table roll")
		return

	var result = _roll_on_gear_table()
	_add_to_cart(result)

func _on_roll_gadget_pressed() -> void:
	"""Roll on Gadget Table (3 credits)"""
	if current_credits - cart_total < TABLE_ROLL_COST:
		print("PurchaseItemsComponent: Not enough credits for table roll")
		return

	var result = _roll_on_gadget_table()
	_add_to_cart(result)

func _add_to_cart(item: Dictionary) -> void:
	"""Add item to shopping cart"""
	cart_items.append(item)
	cart_total += item.get("cost", 0)
	_update_cart_display()
	_update_ui_display()
	print("PurchaseItemsComponent: Added %s to cart (total: %d)" % [item.name, cart_total])

func _on_sell_pressed() -> void:
	"""Sell selected item"""
	if not sell_items_list or sell_items_list.get_selected_items().is_empty():
		return

	if items_sold_this_turn >= MAX_ITEMS_SOLD_PER_TURN:
		print("PurchaseItemsComponent: Maximum items sold this turn (%d)" % MAX_ITEMS_SOLD_PER_TURN)
		return

	var selected = sell_items_list.get_selected_items()[0]
	if selected >= 0 and selected < stash_items.size():
		var item = stash_items[selected]
		var item_name = item.get("name", "Unknown") if item is Dictionary else str(item)

		stash_items.remove_at(selected)
		current_credits += SELL_PRICE_PER_ITEM
		items_sold_this_turn += 1

		_populate_sell_items()
		_update_ui_display()

		print("PurchaseItemsComponent: Sold %s for %d credit" % [item_name, SELL_PRICE_PER_ITEM])

func _on_sell_item_selected(index: int) -> void:
	"""Quick-sell on double-click"""
	if index >= 0:
		sell_items_list.select(index)
		_on_sell_pressed()

func _on_confirm_purchase_pressed() -> void:
	"""Confirm and complete purchase"""
	if cart_total > current_credits:
		print("PurchaseItemsComponent: Not enough credits!")
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
		print("PurchaseItemsComponent: Refunded %d credits for %d failed items" % [refund_amount, items_failed])

	# Update local state with actual items added
	current_credits -= (cart_total - refund_amount)

	print("PurchaseItemsComponent: Added %d/%d items to ship stash" % [items_added, cart_items.size()])

	purchase_completed = true

	print("PurchaseItemsComponent: Purchase complete - spent %d credits on %d items" % [cart_total, cart_items.size()])

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

## Table Rolls (Simplified - expand with full tables later)
func _roll_on_military_table() -> Dictionary:
	"""Roll D100 on Military Weapons Table (Core Rules p.28)"""
	var roll = randi() % 100 + 1
	var result = {"cost": TABLE_ROLL_COST, "type": "weapon", "category": "military"}

	if roll <= 25:
		result["name"] = "Military Rifle"
	elif roll <= 45:
		result["name"] = "Infantry Laser"
	elif roll <= 50:
		result["name"] = "Marksman's Rifle"
	elif roll <= 60:
		result["name"] = "Needle Rifle"
	elif roll <= 75:
		result["name"] = "Auto Rifle"
	elif roll <= 80:
		result["name"] = "Rattle Gun"
	elif roll <= 95:
		result["name"] = "Boarding Saber"
	else:
		result["name"] = "Shatter Axe"

	print("PurchaseItemsComponent: Rolled %d on Military Table - %s" % [roll, result.name])
	return result

func _roll_on_gear_table() -> Dictionary:
	"""Roll D100 on Gear Table (Core Rules p.29)"""
	var roll = randi() % 100 + 1
	var result = {"cost": TABLE_ROLL_COST, "type": "gear"}

	# Simplified - expand with full 100-entry table
	if roll <= 10:
		result["name"] = "Beam Light"
	elif roll <= 20:
		result["name"] = "Bipod"
	elif roll <= 30:
		result["name"] = "Combat Armor"
	elif roll <= 40:
		result["name"] = "Communicator"
	elif roll <= 52:
		result["name"] = "Frag Vest"
	elif roll <= 65:
		result["name"] = "Laser Sight"
	elif roll <= 80:
		result["name"] = "Med-patch"
	elif roll <= 90:
		result["name"] = "Nano-doc"
	else:
		result["name"] = "Scanner Bot"

	print("PurchaseItemsComponent: Rolled %d on Gear Table - %s" % [roll, result.name])
	return result

func _roll_on_gadget_table() -> Dictionary:
	"""Roll D100 on Gadget Table (Core Rules p.29)"""
	var roll = randi() % 100 + 1
	var result = {"cost": TABLE_ROLL_COST, "type": "gadget"}

	# Simplified - expand with full 100-entry table
	if roll <= 9:
		result["name"] = "Analyzer"
	elif roll <= 17:
		result["name"] = "Battle Visor"
	elif roll <= 27:
		result["name"] = "Displacer"
	elif roll <= 41:
		result["name"] = "Duplicator"
	elif roll <= 55:
		result["name"] = "Jump Belt"
	elif roll <= 70:
		result["name"] = "Repair Bot"
	elif roll <= 83:
		result["name"] = "Screen Generator"
	elif roll <= 93:
		result["name"] = "Stealth Gear"
	else:
		result["name"] = "Stim-pack"

	print("PurchaseItemsComponent: Rolled %d on Gadget Table - %s" % [roll, result.name])
	return result

## UI Updates
func _update_cart_display() -> void:
	"""Update shopping cart display"""
	if not cart_list:
		return

	cart_list.clear()
	for item in cart_items:
		cart_list.add_item("%s (%d cr)" % [item.name, item.cost])

func _update_ui_display() -> void:
	"""Update all UI elements"""
	if credits_display:
		var remaining = current_credits - cart_total
		credits_display.text = "Credits: %d (Cart: %d, Remaining: %d)" % [current_credits, cart_total, remaining]

	# Update button states
	var can_afford_roll = (current_credits - cart_total) >= TABLE_ROLL_COST
	if roll_military_button:
		roll_military_button.disabled = not can_afford_roll
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
	"""Handle phase started events"""
	var phase_name = data.get("phase_name", "")
	if phase_name == "purchase_items":
		print("PurchaseItemsComponent: Purchase phase started")

## Public API
func is_purchase_completed() -> bool:
	"""Check if purchase phase is completed"""
	return purchase_completed

func get_purchased_items() -> Array:
	"""Get list of purchased items"""
	return cart_items.duplicate()

func get_remaining_credits() -> int:
	"""Get credits remaining after cart"""
	return current_credits - cart_total

func reset_purchase_phase() -> void:
	"""Reset for new turn"""
	cart_items.clear()
	cart_total = 0
	items_sold_this_turn = 0
	purchase_completed = false
	_update_ui_display()
	print("PurchaseItemsComponent: Reset for new turn")
