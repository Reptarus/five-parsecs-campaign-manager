class_name ShipManagerUI
extends Control

const ShipComponentQuery = preload("res://src/core/ship/ShipComponentQuery.gd")

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
var _components_db: Array = []
var _components_rules: Dictionary = {}

func _ready() -> void:
	_load_components_database()
	_load_ship_data()
	_refresh_display()

func _load_components_database() -> void:
	## Load Core Rules components from JSON (pp.60-62)
	var path := "res://data/ship_components.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("ShipManager: ship_components.json not found")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("ShipManager: Failed to parse ship_components.json")
		return
	if json.data is Dictionary:
		_components_db = json.data.get("components", [])
		_components_rules = json.data.get("rules", {})

func _load_ship_data() -> void:
	## Load ship data from GameStateManager
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("get_ship"):
		ship_data = gsm.get_ship()
		if not ship_data.is_empty():
			return

	# Fallback to default data
	ship_data = {
		"name": "Wandering Star",
		"type": "Worn Freighter",
		"hull_points": 30,
		"max_hull": 30,
		"debt": 25,
		"fuel": "full",
		"traits": [],
		"components": []
	}

func _refresh_display() -> void:
	## Refresh all ship information displays
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
	## Refresh ship traits display
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
	## Refresh ship components display (Core Rules pp.60-62)
	for child in upgrades_list.get_children():
		child.queue_free()

	# Show installed components
	for comp_id in ship_data.get("components", []):
		var comp_name: String = _get_component_name(comp_id)
		var panel = _create_upgrade_panel(comp_name, true)
		upgrades_list.add_child(panel)

	# Show available components for purchase
	var available: Array[Dictionary] = _get_available_components()
	for comp in available:
		var panel = _create_upgrade_panel(
			comp.get("name", ""), false)
		upgrades_list.add_child(panel)

func _create_upgrade_panel(upgrade_name: String, owned: bool) -> PanelContainer:
	## Create a panel for ship upgrade
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
		owned_label.modulate = UIColors.COLOR_EMERALD
		hbox.add_child(owned_label)
	else:
		var cost_label: Label = Label.new()
		var cost: int = _get_component_cost(upgrade_name)
		cost_label.text = str(cost) + " cr"
		hbox.add_child(cost_label)

		var buy_button: Button = Button.new()
		buy_button.text = "Purchase"
		buy_button.pressed.connect(
			_on_upgrade_purchased.bind(upgrade_name))
		hbox.add_child(buy_button)

	return panel

func _get_available_components() -> Array[Dictionary]:
	## Get components not yet installed (Core Rules pp.60-62)
	var installed: Array = ship_data.get("components", [])
	var available: Array[Dictionary] = []
	for comp in _components_db:
		if comp is Dictionary:
			var comp_id: String = comp.get("id", "")
			if comp_id not in installed:
				available.append(comp)
	return available

func _get_component_name(comp_id: String) -> String:
	for comp in _components_db:
		if comp is Dictionary and comp.get("id", "") == comp_id:
			return comp.get("name", comp_id)
	return comp_id.capitalize().replace("_", " ")

func _get_component_cost(comp_name: String) -> int:
	## Get cost from JSON, apply Standard Issue discount
	var base_cost: int = 10
	for comp in _components_db:
		if comp is Dictionary and comp.get("name", "") == comp_name:
			base_cost = int(comp.get("cost", 10))
			break
	# Standard Issue trait: -1cr (Core Rules p.30)
	var discount: int = _components_rules.get(
		"standard_issue_trait_discount", 1)
	var traits: Array = ship_data.get("traits", [])
	for t in traits:
		if "standard issue" in str(t).to_lower():
			base_cost = maxi(0, base_cost - discount)
			break
	return base_cost

func _calculate_travel_cost() -> int:
	## Travel cost with trait + component modifiers (Core Rules pp.30, 61-62)
	var base_cost: int = 5
	var traits: Array = ship_data.get("traits", [])
	var components: Array = ship_data.get("components", [])

	# Ship trait modifiers
	for t in traits:
		var tl: String = str(t).to_lower()
		if "fuel" in tl and "efficient" in tl:
			base_cost -= 1
		elif "fuel" in tl and "hog" in tl:
			base_cost += 1

	# +1 per 3 billable components (Core Rules p.61)
	# Miniaturized excluded (Compendium p.28)
	var billable: int = ShipComponentQuery.get_billable_component_count()
	if billable > 0:
		@warning_ignore("integer_division")
		base_cost += billable / 3

	# Military Fuel Converters: -2cr (Core Rules p.62)
	if ShipComponentQuery.has_component("military_fuel_converters"):
		base_cost -= 2

	return maxi(0, base_cost)

func _calculate_repair_cost() -> int:
	## Calculate cost to fully repair the ship
	var current = ship_data.get("hull_points", 0)
	var maximum = ship_data.get("max_hull", 30)
	var damage = maximum - current
	return damage # 1 credit per hull point

func _on_hull_changed(_value: float) -> void:
	## Handle hull points change
	ship_data["hull_points"] = int(_value)

func _on_debt_changed(_value: float) -> void:
	## Handle debt amount change
	ship_data["debt"] = int(_value)

func _on_back_pressed() -> void:
	## Handle back button press
	if has_node("/root/SceneRouter"):
		get_node("/root/SceneRouter").navigate_back()
	else:
		# Fallback - emit a signal or use get_tree().change_scene_to_file()
		pass

func _on_travel_pressed() -> void:
	## Handle travel button press
	var cost = _calculate_travel_cost()
	travel_initiated.emit()

func _on_refuel_pressed() -> void:
	## Handle refuel button press
	ship_data["fuel"] = "full"
	_refresh_display()

func _on_repair_pressed() -> void:
	## Handle repair button press
	var cost = _calculate_repair_cost()

	# Check if player has enough credits
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("get_credits"):
		var current_credits = game_state.get_credits()
		if current_credits < cost:
			return
		game_state.remove_credits(cost)
	else:
		pass
	
	ship_data["hull_points"] = ship_data.get("max_hull", 30)
	_refresh_display()
	ship_repaired.emit(ship_data.get("max_hull", 30))

func _on_upgrade_pressed() -> void:
	## Handle upgrade button press
	pass

func _on_pay_debt_pressed() -> void:
	## Handle pay debt button press
	var debt = ship_data.get("debt", 0)
	if debt > 0:
		ship_data["debt"] = 0
		_refresh_display()
		debt_paid.emit(debt)

func _on_upgrade_purchased(comp_name: String) -> void:
	## Handle component purchase (Core Rules p.60)
	var cost: int = _get_component_cost(comp_name)
	var comp_id: String = ""
	for comp in _components_db:
		if comp is Dictionary and comp.get("name", "") == comp_name:
			comp_id = comp.get("id", "")
			break

	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("get_credits"):
		var current_credits: int = game_state.get_credits()
		if current_credits < cost:
			return
		game_state.remove_credits(cost)

	if not ship_data.has("components"):
		ship_data["components"] = []
	ship_data["components"].append(comp_id)

	# Journal entry for component installation (Core Rules p.60)
	var journal: Node = get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("create_entry"):
		journal.create_entry({
			"type": "purchase",
			"title": "Component Installed: %s" % comp_name,
			"description": (
				"Installed %s for %d credits. "
				+ "Operational next turn. (Core Rules p.60)"
			) % [comp_name, cost],
			"tags": ["ship_component", "installation", comp_id],
			"auto_generated": true,
			"stats": {"credits_spent": cost},
		})

	_refresh_display()
	upgrade_purchased.emit(
		{"name": comp_name, "id": comp_id, "cost": cost})
