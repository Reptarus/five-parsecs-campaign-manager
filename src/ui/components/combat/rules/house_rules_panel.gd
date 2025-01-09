@tool
extends PanelContainer

## Signals
signal rule_added(rule: Dictionary)
signal rule_removed(rule_id: String)
signal rule_modified(rule: Dictionary)
signal rules_cleared

## Node references 
@onready var rules_list: ItemList = %RulesList
@onready var add_rule_button: Button = %AddRuleButton
@onready var remove_rule_button: Button = %RemoveRuleButton
@onready var edit_rule_button: Button = %EditRuleButton
@onready var category_filter: OptionButton = %CategoryFilter

## Properties
var active_rules: Dictionary = {}
var rule_categories: Dictionary = {
	"combat": "Combat Rules",
	"movement": "Movement Rules",
	"terrain": "Terrain Effects",
	"morale": "Morale Rules",
	"equipment": "Equipment Rules"
}

## Called when node enters scene tree
func _ready() -> void:
	if not Engine.is_editor_hint():
		add_rule_button.pressed.connect(_on_add_rule_pressed)
		remove_rule_button.pressed.connect(_on_remove_rule_pressed)
		edit_rule_button.pressed.connect(_on_edit_rule_pressed)
		category_filter.item_selected.connect(_on_category_filter_changed)
		rules_list.item_selected.connect(_on_rule_selected)
		
		_setup_category_filter()
		_update_button_states()

## Sets up the category filter dropdown
func _setup_category_filter() -> void:
	category_filter.clear()
	category_filter.add_item("All Categories", 0)
	
	var index = 1
	for key in rule_categories:
		category_filter.add_item(rule_categories[key], index)
		category_filter.set_item_metadata(index, key)
		index += 1

## Adds a new house rule
func add_rule(rule_data: Dictionary) -> void:
	if not _validate_rule_data(rule_data):
		push_error("Invalid rule data provided")
		return
		
	var rule_id = rule_data.get("id", str(Time.get_unix_time_from_system()))
	active_rules[rule_id] = rule_data
	_refresh_rules_list()
	rule_added.emit(rule_data)

## Removes a house rule
func remove_rule(rule_id: String) -> void:
	if active_rules.has(rule_id):
		var rule = active_rules[rule_id]
		active_rules.erase(rule_id)
		_refresh_rules_list()
		rule_removed.emit(rule_id)

## Modifies an existing house rule
func modify_rule(rule_id: String, new_data: Dictionary) -> void:
	if active_rules.has(rule_id) and _validate_rule_data(new_data):
		active_rules[rule_id] = new_data
		_refresh_rules_list()
		rule_modified.emit(new_data)

## Validates rule data structure
func _validate_rule_data(rule_data: Dictionary) -> bool:
	var required_fields = ["name", "category", "description", "effects"]
	for field in required_fields:
		if not rule_data.has(field):
			return false
	return true

## Updates the rules list display
func _refresh_rules_list() -> void:
	rules_list.clear()
	var current_category = category_filter.get_selected_metadata()
	
	for rule_id in active_rules:
		var rule = active_rules[rule_id]
		if current_category == null or rule.category == current_category:
			var text = "%s (%s)" % [rule.name, rule_categories[rule.category]]
			rules_list.add_item(text)
			rules_list.set_item_metadata(rules_list.item_count - 1, rule_id)

## Updates button states based on selection
func _update_button_states() -> void:
	var has_selection = rules_list.get_selected_items().size() > 0
	remove_rule_button.disabled = not has_selection
	edit_rule_button.disabled = not has_selection

## Button press handlers
func _on_add_rule_pressed() -> void:
	# TODO: Show rule creation dialog
	pass

func _on_remove_rule_pressed() -> void:
	var selected = rules_list.get_selected_items()
	if selected.size() > 0:
		var rule_id = rules_list.get_item_metadata(selected[0])
		remove_rule(rule_id)

func _on_edit_rule_pressed() -> void:
	var selected = rules_list.get_selected_items()
	if selected.size() > 0:
		var rule_id = rules_list.get_item_metadata(selected[0])
		# TODO: Show rule edit dialog
		pass

func _on_category_filter_changed(_index: int) -> void:
	_refresh_rules_list()

func _on_rule_selected(_index: int) -> void:
	_update_button_states()

## Gets all active rules
func get_active_rules() -> Array:
	return active_rules.values()

## Gets rules by category
func get_rules_by_category(category: String) -> Array:
	return active_rules.values().filter(func(rule): return rule.category == category)

## Clears all rules
func clear_rules() -> void:
	active_rules.clear()
	_refresh_rules_list()
	rules_cleared.emit()

## Exports rules to dictionary
func export_rules() -> Dictionary:
	return active_rules.duplicate()

## Imports rules from dictionary
func import_rules(rules: Dictionary) -> void:
	active_rules = rules.duplicate()
	_refresh_rules_list()