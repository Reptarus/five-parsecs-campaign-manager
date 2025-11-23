extends ResponsiveContainer
class_name ComparisonPanel

## ComparisonPanel - Equipment comparison UI
## Side-by-side stat comparison for weapons/armor

signal item_selected(item: Variant)

@onready var items_container = $GridContainer
@onready var add_item_button = $ActionBar/AddItemButton

var compared_items: Array = []
const MAX_ITEMS: int = 3

func _ready() -> void:
	if add_item_button:
		add_item_button.pressed.connect(_on_add_item_pressed)

func add_item_to_comparison(item: Variant) -> void:
	"""Add item to comparison"""
	if compared_items.size() >= MAX_ITEMS:
		push_warning("Maximum items reached")
		return
	
	compared_items.append(item)
	_refresh_comparison()

func remove_item(index: int) -> void:
	"""Remove item from comparison"""
	if index >= 0 and index < compared_items.size():
		compared_items.remove_at(index)
		_refresh_comparison()

func _refresh_comparison() -> void:
	"""Refresh comparison display"""
	_clear_container()
	
	if compared_items.size() < 2:
		_show_placeholder()
		return
	
	# Get comparison data
	var comparison = EquipmentComparisonTool.compare_weapons(compared_items)
	
	# Display comparison grid
	_display_comparison_grid(comparison)

func _clear_container() -> void:
	"""Clear items container"""
	if not items_container:
		return
	for child in items_container.get_children():
		child.queue_free()

func _show_placeholder() -> void:
	"""Show placeholder when not enough items"""
	var label = Label.new()
	label.text = "Add at least 2 items to compare"
	items_container.add_child(label)

func _display_comparison_grid(comparison: Dictionary) -> void:
	"""Display comparison in grid format"""
	# Create header row with item names
	for item in comparison.items:
		var name_label = Label.new()
		name_label.text = item.name
		items_container.add_child(name_label)
	
	# Create stat rows
	_add_stat_row("Cost", comparison.items.map(func(i): return str(i.cost) + " cr"))
	_add_stat_row("Range", comparison.items.map(func(i): return str(i.range) + '"'))
	_add_stat_row("Damage", comparison.items.map(func(i): return str(i.damage)))

func _add_stat_row(stat_name: String, values: Array) -> void:
	"""Add a stat comparison row"""
	# Stat name
	var name_label = Label.new()
	name_label.text = stat_name
	items_container.add_child(name_label)
	
	# Values
	for value in values:
		var value_label = Label.new()
		value_label.text = value
		items_container.add_child(value_label)

func _on_add_item_pressed() -> void:
	"""Request item selection"""
	# TODO: Open item picker dialog
	pass
