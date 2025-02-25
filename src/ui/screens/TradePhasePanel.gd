extends BasePhasePanel
class_name TradePhasePanel

signal item_purchased(item_data: Dictionary)
signal item_sold(item_data: Dictionary)
signal trading_completed

@onready var credits_label: Label = $VBoxContainer/CreditsLabel
@onready var available_items: ItemList = $VBoxContainer/AvailableItems
@onready var inventory_items: ItemList = $VBoxContainer/InventoryItems
@onready var item_details: RichTextLabel = $VBoxContainer/ItemDetails
@onready var buy_button: Button = $VBoxContainer/ButtonContainer/BuyButton
@onready var sell_button: Button = $VBoxContainer/ButtonContainer/SellButton
@onready var complete_button: Button = $VBoxContainer/CompleteButton

var current_credits: int = 0
var available_market_items: Array[Dictionary] = []
var inventory: Array[Dictionary] = []
var selected_market_item: Dictionary
var selected_inventory_item: Dictionary

func _ready() -> void:
	super._ready()
	buy_button.pressed.connect(_on_buy_button_pressed)
	sell_button.pressed.connect(_on_sell_button_pressed)
	complete_button.pressed.connect(_on_complete_button_pressed)
	available_items.item_selected.connect(_on_market_item_selected)
	inventory_items.item_selected.connect(_on_inventory_item_selected)
	
	# Initialize UI state
	buy_button.disabled = true
	sell_button.disabled = true
	update_credits_display()

func setup_phase() -> void:
	super.setup_phase()
	# Load market items and inventory from campaign data
	load_market_items()
	load_inventory()
	update_credits_display()

func load_market_items() -> void:
	available_items.clear()
	available_market_items.clear()
	
	# TODO: Load actual market items from campaign data
	# For now, using sample items
	var sample_items = [
		{"name": "Medkit", "cost": 100, "description": "Heals wounds and restores health"},
		{"name": "Ammo Pack", "cost": 50, "description": "Restocks ammunition"},
		{"name": "Armor Plate", "cost": 200, "description": "Provides additional protection"}
	]
	
	for item in sample_items:
		available_market_items.append(item)
		available_items.add_item(item.name + " (" + str(item.cost) + " credits)")

func load_inventory() -> void:
	inventory_items.clear()
	inventory.clear()
	
	# TODO: Load actual inventory from campaign data
	# For now, using sample inventory
	var sample_inventory = [
		{"name": "Pistol", "value": 75, "description": "Standard sidearm"},
		{"name": "Rations", "value": 25, "description": "Basic food supplies"}
	]
	
	for item in sample_inventory:
		inventory.append(item)
		inventory_items.add_item(item.name + " (" + str(item.value) + " credits)")

func update_credits_display() -> void:
	credits_label.text = "Credits: " + str(current_credits)

func _on_market_item_selected(index: int) -> void:
	if index >= 0 and index < available_market_items.size():
		selected_market_item = available_market_items[index]
		buy_button.disabled = selected_market_item.cost > current_credits
		item_details.text = selected_market_item.name + "\n" + selected_market_item.description + "\nCost: " + str(selected_market_item.cost) + " credits"

func _on_inventory_item_selected(index: int) -> void:
	if index >= 0 and index < inventory.size():
		selected_inventory_item = inventory[index]
		sell_button.disabled = false
		item_details.text = selected_inventory_item.name + "\n" + selected_inventory_item.description + "\nValue: " + str(selected_inventory_item.value) + " credits"

func _on_buy_button_pressed() -> void:
	if selected_market_item.cost <= current_credits:
		current_credits -= selected_market_item.cost
		emit_signal("item_purchased", selected_market_item)
		update_credits_display()
		# Refresh market and inventory
		load_market_items()
		load_inventory()

func _on_sell_button_pressed() -> void:
	current_credits += selected_inventory_item.value
	emit_signal("item_sold", selected_inventory_item)
	update_credits_display()
	# Refresh market and inventory
	load_market_items()
	load_inventory()

func _on_complete_button_pressed() -> void:
	emit_signal("trading_completed")

func validate_phase_requirements() -> bool:
	return true # No specific requirements for trade phase

func get_phase_data() -> Dictionary:
	return {
		"credits": current_credits,
		"purchased_items": [], # TODO: Track purchased items
		"sold_items": [] # TODO: Track sold items
	}