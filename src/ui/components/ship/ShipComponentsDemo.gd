extends Control

## Ship Components Demo Scene
## Demonstrates all three ship UI components

@onready var damage_panel: ShipDamageStatusPanel = $VBox/DamagePanel
@onready var passage_panel: CommercialPassagePanel = $VBox/PassagePanel
@onready var purchase_dialog: ShipPurchaseDialog = $PurchaseDialog
@onready var test_buttons: VBoxContainer = $VBox/TestButtons

# Test data
var test_hull: int = 100
var test_max_hull: int = 100
var test_credits: int = 500


func _ready() -> void:
	_setup_test_buttons()
	_connect_component_signals()

	# Initialize components with test data
	damage_panel.update_display(test_hull, test_max_hull)
	passage_panel.set_crew_size(6)


func _setup_test_buttons() -> void:
	## Create test buttons to demo functionality
	var damage_btn := Button.new()
	damage_btn.text = "Damage Ship (-25 hull)"
	damage_btn.custom_minimum_size.y = 48
	damage_btn.pressed.connect(_on_damage_ship)
	test_buttons.add_child(damage_btn)

	var repair_btn := Button.new()
	repair_btn.text = "Repair Ship (full)"
	repair_btn.custom_minimum_size.y = 48
	repair_btn.pressed.connect(_on_repair_ship)
	test_buttons.add_child(repair_btn)

	var purchase_btn := Button.new()
	purchase_btn.text = "Open Purchase Dialog"
	purchase_btn.custom_minimum_size.y = 48
	purchase_btn.pressed.connect(_on_show_purchase_dialog)
	test_buttons.add_child(purchase_btn)

	var crew_btn := Button.new()
	crew_btn.text = "Change Crew Size (random)"
	crew_btn.custom_minimum_size.y = 48
	crew_btn.pressed.connect(_on_change_crew_size)
	test_buttons.add_child(crew_btn)


func _connect_component_signals() -> void:
	## Connect component signals
	damage_panel.repair_requested.connect(_on_repair_requested)
	passage_panel.passage_booked.connect(_on_passage_booked)
	purchase_dialog.ship_purchased.connect(_on_ship_purchased)
	purchase_dialog.dialog_cancelled.connect(_on_purchase_cancelled)


func _on_damage_ship() -> void:
	## Test: Damage the ship
	test_hull = max(0, test_hull - 25)
	damage_panel.update_display(test_hull, test_max_hull)
	print("Ship damaged! Hull: %d/%d" % [test_hull, test_max_hull])


func _on_repair_ship() -> void:
	## Test: Repair the ship
	test_hull = test_max_hull
	damage_panel.update_display(test_hull, test_max_hull)
	print("Ship repaired! Hull: %d/%d" % [test_hull, test_max_hull])


func _on_show_purchase_dialog() -> void:
	## Test: Show purchase dialog
	purchase_dialog.show_dialog(test_credits)


func _on_change_crew_size() -> void:
	## Test: Change crew size
	var new_size := randi_range(1, 8)
	passage_panel.set_crew_size(new_size)
	print("Crew size changed to: %d" % new_size)


func _on_repair_requested() -> void:
	## Handle repair request from damage panel
	print("Repair requested! Cost: %d credits" % ((test_max_hull - test_hull) * 5))


func _on_passage_booked(destination: String) -> void:
	## Handle passage booking
	var cost := passage_panel.get_total_cost()
	print("Passage booked to %s for %d credits" % [destination, cost])


func _on_ship_purchased(ship_data: Dictionary) -> void:
	## Handle ship purchase
	print("Ship purchased: %s" % ship_data.name)
	print("Cost: %d credits" % ship_data.cost)
	print("Hull: %d" % ship_data.hull)
	print("Used loan: %s" % ship_data.used_loan)

	# Update test data
	test_hull = ship_data.hull
	test_max_hull = ship_data.hull
	damage_panel.update_display(test_hull, test_max_hull)


func _on_purchase_cancelled() -> void:
	## Handle purchase cancellation
	print("Purchase cancelled")
