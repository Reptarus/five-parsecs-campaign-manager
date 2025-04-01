# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Control

const Self = preload("res://src/ui/resource/ResourceDisplay.gd")
const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const ResourceItem = preload("res://src/ui/resource/ResourceItem.gd")
const ResourceSystem = preload("res://src/core/systems/ResourceSystem.gd")

@onready var resource_container: VBoxContainer = $MainContainer/ResourceContainer
@onready var history_container: VBoxContainer = $MainContainer/HistoryContainer
@onready var transaction_list: ItemList = $MainContainer/HistoryContainer/TransactionList
@onready var filter_type: OptionButton = $MainContainer/HistoryContainer/FilterContainer/FilterType
@onready var market_info_container: VBoxContainer = $MainContainer/MarketContainer
@onready var market_state_label: Label = $MainContainer/MarketContainer/MarketStateLabel
@onready var resource_system: Node # Changed from ResourceSystem to Node type for flexibility

signal resource_clicked(type: int)
signal market_update_requested

# Resource item template
const RESOURCE_ITEM_SCENE = preload("res://src/ui/resource/ResourceItem.tscn")

# Market update timer
var update_timer: Timer

func _ready() -> void:
	# Get reference to resource system - try autoload first
	resource_system = get_node_or_null("/root/ResourceSystem")
	
	# Try fallback path if not found
	if not resource_system:
		resource_system = get_node_or_null("/root/Game/Systems/ResourceSystem")
	
	if not resource_system:
		push_error("ResourceSystem not found")
		return
	
	# Connect signals
	resource_system.resource_changed.connect(_on_resource_changed)
	resource_system.transaction_recorded.connect(_on_transaction_recorded)
	resource_system.validation_failed.connect(_on_validation_failed)
	
	# Setup UI
	_setup_filter_options()
	_setup_resource_display()
	_setup_history_display()
	_setup_market_display()
	
	# Setup market update timer
	update_timer = Timer.new()
	add_child(update_timer)
	update_timer.timeout.connect(_on_market_update_timer)
	update_timer.start(300.0) # 5 minutes

func _setup_filter_options() -> void:
	filter_type.clear()
	filter_type.add_item("All Resources", -1)
	
	for type in GameEnums.ResourceType.values():
		if type != GameEnums.ResourceType.NONE:
			var type_name = GameEnums.ResourceType.keys()[type].capitalize()
			filter_type.add_item(type_name, type)

func _setup_market_display() -> void:
	_update_market_state_display()

func _update_market_state_display() -> void:
	# Safely access market state with proper type checking
	var market_state = 0.0
	
	if resource_system.has("_market") and resource_system._market is Dictionary and resource_system._market.has("market_state"):
		market_state = resource_system._market.market_state
	
	var state_text = "Market State: "
	
	if market_state > 0.3:
		state_text += "Boom (+"
	elif market_state > 0:
		state_text += "Growth (+"
	elif market_state > -0.3:
		state_text += "Stable ("
	else:
		state_text += "Recession ("
	
	state_text += str(int(market_state * 100)) + "%)"
	market_state_label.text = state_text

func _setup_resource_display() -> void:
	# Clear existing items
	for child in resource_container.get_children():
		if child is ResourceItem:
			child.queue_free()
	
	# Create resource items
	for type in GameEnums.ResourceType.values():
		if type != GameEnums.ResourceType.NONE:
			var item = RESOURCE_ITEM_SCENE.instantiate()
			resource_container.add_child(item)
			
			# Use safe method calls with fallbacks
			var current_amount = 0
			var market_value = 0
			
			if resource_system.has_method("get_resource"):
				current_amount = resource_system.get_resource(type)
			elif resource_system.has_method("get_resource_amount"):
				current_amount = resource_system.get_resource_amount(type)
			
			if resource_system.has_method("get_market_value"):
				market_value = resource_system.get_market_value(type)
			
			var trend = 0
			if market_value > current_amount:
				trend = 1
			elif market_value < current_amount:
				trend = -1
			
			item.setup(
				type,
				current_amount,
				market_value,
				trend
			)
			item.pressed.connect(_on_resource_item_pressed.bind(type))

func _setup_history_display() -> void:
	transaction_list.clear()
	
	if resource_system.has_method("get_transaction_history"):
		var history = resource_system.get_transaction_history()
		for transaction in history:
			_add_transaction_to_list(transaction)

# Updated to use dictionary instead of class type
func _add_transaction_to_list(transaction: Dictionary) -> void:
	var time_str = Time.get_datetime_string_from_unix_time(transaction.get("timestamp", 0))
	
	# Handle different dictionary structures for compatibility
	var amount_str = ""
	if transaction.has("transaction_type"):
		amount_str = ("+" if transaction.transaction_type == "ADD" else "-")
	else:
		amount_str = ("+" if transaction.get("type", "") == "ADD" else "-")
	
	if transaction.has("change_amount"):
		amount_str += str(transaction.change_amount)
	elif transaction.has("amount"):
		amount_str += str(transaction.amount)
	else:
		amount_str += "0"
	
	var type_idx = 0
	if transaction.has("resource_type"):
		type_idx = transaction.resource_type
	elif transaction.has("type"):
		type_idx = transaction.type
	
	var type_str = "Unknown"
	if type_idx >= 0 and type_idx < GameEnums.ResourceType.size():
		type_str = GameEnums.ResourceType.keys()[type_idx].capitalize()
	
	var balance = 0
	if transaction.has("new_value"):
		balance = transaction.new_value
	elif transaction.has("balance"):
		balance = transaction.balance
	
	var source = transaction.get("source", "system")
	
	var text = "%s | %s %s | Source: %s | Balance: %d" % [
		time_str,
		amount_str,
		type_str,
		source,
		balance
	]
	
	transaction_list.add_item(text)
	# Auto-scroll to bottom
	transaction_list.ensure_current_is_visible()

func _on_resource_changed(type: int, amount: int) -> void:
	# Update resource display
	for child in resource_container.get_children():
		if child is ResourceItem and child.resource_type == type:
			var market_value = 0
			if resource_system.has_method("get_market_value"):
				market_value = resource_system.get_market_value(type)
				
			var trend = 0
			if market_value > amount:
				trend = 1
			elif market_value < amount:
				trend = -1
			child.update_values(amount, market_value, trend)
			break

# Updated to use dictionary instead of class type
func _on_transaction_recorded(transaction: Dictionary) -> void:
	_add_transaction_to_list(transaction)

func _on_validation_failed(type: int, amount: int, reason: String) -> void:
	# Show error notification
	var type_str = "Unknown"
	if type >= 0 and type < GameEnums.ResourceType.size():
		type_str = GameEnums.ResourceType.keys()[type].capitalize()
	OS.alert("Resource validation failed for %s: %s" % [type_str, reason])

func _on_resource_item_pressed(type: int) -> void:
	resource_clicked.emit(type)

func _on_clear_history_pressed() -> void:
	transaction_list.clear()

func _on_filter_type_selected(index: int) -> void:
	var selected_type = filter_type.get_item_id(index)
	transaction_list.clear()
	
	if resource_system.has_method("get_transaction_history"):
		var history = resource_system.get_transaction_history(selected_type)
		for transaction in history:
			_add_transaction_to_list(transaction)

func _on_market_update_timer() -> void:
	market_update_requested.emit()
	_update_market_state_display()
	_setup_resource_display() # Refresh display with new values
