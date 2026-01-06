class_name ShipManagerUI
extends Control

signal ship_repaired(hull_points: int)
signal debt_paid(amount: int)
signal upgrade_purchased(upgrade: Dictionary)
signal travel_initiated()

@onready var ship_name: Label = %ShipName
@onready var ship_type: Label = %ShipType
@onready var current_hull: SpinBox = %CurrentHull
@onready var max_hull: Label = %MaxHull
@onready var debt_amount: SpinBox = %DebtAmount
@onready var ship_traits: VBoxContainer = %ShipTraits
@onready var upgrades_list: VBoxContainer = %UpgradesList
@onready var fuel_level: Label = %FuelLevel
@onready var cost_amount: Label = %CostAmount

var ship_data: Dictionary = {}

func _ready() -> void:
	print("ShipManager: Initializing...")
	_load_ship_data()
	_refresh_display()

func _load_ship_data() -> void:
	"""Load ship data from campaign manager"""
	# Connect to campaign manager
	var campaign_mgr = get_node_or_null("/root/CampaignManager")
	if campaign_mgr and campaign_mgr.has_method("get_ship_data"):
		ship_data = campaign_mgr.get_ship_data()
		return
	
	# Fallback to default data if campaign manager not available
	ship_data = {
		"name": "Wandering Star",
		"type": "Worn Freighter",
		"hull_points": 25,
		"max_hull": 30,
		"debt": 15,
		"fuel": "full",
		"traits": ["Fuel Efficient", "Worn"],
		"upgrades": ["Emergency Drives", "Enhanced Medical Bay"]
	}

func _refresh_display() -> void:
	"""Refresh all ship information displays"""
	if ship_data.is_empty():
		return

	ship_name.text = "Ship Name: " + ship_data.get("name", "Unknown")
	ship_type.text = "Type: " + ship_data.get("type", "Unknown")

	current_hull.max_value = ship_data.get("max_hull", 30)
	current_hull.value = ship_data.get("hull_points", 30)
	max_hull.text = "/ " + str(ship_data.get("max_hull", 30))

	debt_amount.value = ship_data.get("debt", 0)

	fuel_level.text = ship_data.get("fuel", "Empty")
	cost_amount.text = str(_calculate_travel_cost()) + " credit"

	_refresh_traits()
	_refresh_upgrades()

func _refresh_traits() -> void:
	"""Refresh ship traits display"""
	# Clear existing traits
	for child in ship_traits.get_children():
		if child.name != "Label":
			child.queue_free()

	# Add traits
	for ship_trait in ship_data.get("traits", []):
		var trait_label: Label = Label.new()
		trait_label.text = "• " + ship_trait
		ship_traits.add_child(trait_label)

func _refresh_upgrades() -> void:
	"""Refresh ship upgrades display"""
	# Clear existing upgrades
	for child in upgrades_list.get_children():
		child.queue_free()

	# Add current upgrades
	for upgrade in ship_data.get("upgrades", []):
		var upgrade_panel = _create_upgrade_panel(upgrade, true)
		upgrades_list.add_child(upgrade_panel)

	# Add available upgrades
	var available_upgrades = _get_available_upgrades()
	for upgrade in available_upgrades:
		var upgrade_panel = _create_upgrade_panel(upgrade, false)
		upgrades_list.add_child(upgrade_panel)

func _create_upgrade_panel(upgrade_name: String, owned: bool) -> PanelContainer:
	"""Create a panel for ship upgrade"""
	var panel: PanelContainer = PanelContainer.new()
	var hbox = HBoxContainer.new()
	panel.add_child(hbox)

	# Upgrade _name
	var name_label: Label = Label.new()
	name_label.text = upgrade_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	if owned:
		var owned_label: Label = Label.new()
		owned_label.text = "INSTALLED"
		owned_label.modulate = Color.GREEN
		hbox.add_child(owned_label)
	else:
		var cost_label: Label = Label.new()
		cost_label.text = str(_get_upgrade_cost(upgrade_name)) + " credits"
		hbox.add_child(cost_label)

		var buy_button: Button = Button.new()
		buy_button.text = "Purchase"
		buy_button.pressed.connect(_on_upgrade_purchased.bind(upgrade_name))
		hbox.add_child(buy_button)

	return panel

func _get_available_upgrades() -> Array[String]:
	"""Get list of available ship upgrades"""
	var all_upgrades = [
		"Emergency Drives", "Enhanced Medical Bay", "Armored Hull",
		"Fuel Efficient Engines", "Expanded Cargo Bay", "Advanced Sensors",
		"Defensive Turrets", "Stealth Systems", "Navigation Computer"
	]

	var current_upgrades = ship_data.get("upgrades", [])
	var available: Array[String] = []

	for upgrade in all_upgrades:
		if upgrade not in current_upgrades:
			available.append(upgrade)

	return available

func _get_upgrade_cost(upgrade_name: String) -> int:
	"""Get the cost of a specific upgrade"""
	var upgrade_costs = {
		"Emergency Drives": 8,
		"Enhanced Medical Bay": 6,
		"Armored Hull": 10,
		"Fuel Efficient Engines": 7,
		"Expanded Cargo Bay": 5,
		"Advanced Sensors": 9,
		"Defensive Turrets": 12,
		"Stealth Systems": 15,
		"Navigation Computer": 4
	}
	return upgrade_costs.get(upgrade_name, 5)

func _calculate_travel_cost() -> int:
	"""Calculate cost of travel based on ship traits"""
	var base_cost: int = 1

	# Check for fuel efficient trait
	if "Fuel Efficient" in ship_data.get("traits", []):
		return 0 # Free travel

	return base_cost

func _calculate_repair_cost() -> int:
	"""Calculate cost to fully repair the ship"""
	var current = ship_data.get("hull_points", 0)
	var maximum = ship_data.get("max_hull", 30)
	var damage = maximum - current
	return damage # 1 credit per hull point

func _on_hull_changed(_value: float) -> void:
	"""Handle hull points change"""
	ship_data["hull_points"] = int(_value)

func _on_debt_changed(_value: float) -> void:
	"""Handle debt amount change"""
	ship_data["debt"] = int(_value)

func _on_back_pressed() -> void:
	"""Handle back button press"""
	print("ShipManager: Back pressed")
	if has_node("/root/SceneRouter"):
		get_node("/root/SceneRouter").navigate_back()
	else:
		# Fallback - emit a signal or use get_tree().change_scene_to_file()
		print("SceneRouter not found - implement fallback navigation")

func _on_travel_pressed() -> void:
	"""Handle travel button press"""
	var cost = _calculate_travel_cost()
	print("ShipManager: Travel initiated, cost: ", cost)
	travel_initiated.emit()

func _on_refuel_pressed() -> void:
	"""Handle refuel button press"""
	ship_data["fuel"] = "full"
	_refresh_display()
	print("ShipManager: Ship refueled")

func _on_repair_pressed() -> void:
	"""Handle repair button press"""
	var cost = _calculate_repair_cost()
	print("ShipManager: Repair cost: ", cost)

	# Check if player has enough credits
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("get_credits"):
		var current_credits = game_state.get_credits()
		if current_credits < cost:
			print("Not enough credits for repair. Need: %d, Have: %d" % [cost, current_credits])
			return
		game_state.remove_credits(cost)
	else:
		print("Warning: Cannot verify credits - proceeding with repair")
	
	ship_data["hull_points"] = ship_data.get("max_hull", 30)
	_refresh_display()
	ship_repaired.emit(ship_data.get("max_hull", 30))

func _on_upgrade_pressed() -> void:
	"""Handle upgrade button press"""
	print("ShipManager: Upgrade pressed")

func _on_pay_debt_pressed() -> void:
	"""Handle pay debt button press"""
	var debt = ship_data.get("debt", 0)
	if debt > 0:
		ship_data["debt"] = 0
		_refresh_display()
		debt_paid.emit(debt)
		print("ShipManager: Debt paid: ", debt)

func _on_upgrade_purchased(upgrade_name: String) -> void:
	"""Handle upgrade purchase"""
	var cost = _get_upgrade_cost(upgrade_name)
	print("ShipManager: Purchasing upgrade: ", upgrade_name, " for ", cost, " credits")

	# Check if player has enough credits
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("get_credits"):
		var current_credits = game_state.get_credits()
		if current_credits < cost:
			print("Not enough credits for upgrade. Need: %d, Have: %d" % [cost, current_credits])
			return
		game_state.remove_credits(cost)
	else:
		print("Warning: Cannot verify credits - proceeding with upgrade")
	
	ship_data.get("upgrades", []).append(upgrade_name)
	_refresh_display()
	upgrade_purchased.emit({"name": upgrade_name, "cost": cost})
