@tool
extends PanelContainer

## Signals
signal state_verified(result: Dictionary)
signal state_mismatch_detected(details: Dictionary)
signal verification_completed
signal manual_correction_requested(state_key: String, current_value: Variant, expected_value: Variant)

## Node references
@onready var state_tree: Tree = %StateTree
@onready var verify_button: Button = %VerifyButton
@onready var auto_verify_check: CheckBox = %AutoVerifyCheck
@onready var correction_button: Button = %CorrectionButton

## Properties
var current_state: Dictionary = {}
var expected_state: Dictionary = {}
var auto_verify: bool = false
var state_categories: Array = [
	"Combat",
	"Position",
	"Resources",
	"Effects",
	"Modifiers"
]

## Tree root and category items
var tree_root: TreeItem
var category_items: Dictionary = {}

## Called when node enters scene tree
func _ready() -> void:
	if not Engine.is_editor_hint():
		verify_button.pressed.connect(_on_verify_pressed)
		auto_verify_check.toggled.connect(_on_auto_verify_toggled)
		correction_button.pressed.connect(_on_correction_pressed)
		
		_setup_state_tree()

## Sets up the state tree structure
func _setup_state_tree() -> void:
	state_tree.clear()
	tree_root = state_tree.create_item()
	tree_root.set_text(0, "Game State")
	
	for category in state_categories:
		var item = state_tree.create_item(tree_root)
		item.set_text(0, category)
		category_items[category] = item

## Updates the current state
func update_current_state(new_state: Dictionary) -> void:
	current_state = new_state
	if auto_verify:
		verify_state()
	else:
		_update_state_display()

## Updates the expected state
func update_expected_state(new_state: Dictionary) -> void:
	expected_state = new_state
	if auto_verify:
		verify_state()
	else:
		_update_state_display()

## Updates the state tree display
func _update_state_display() -> void:
	for category in state_categories:
		var category_item = category_items[category]
		category_item.clear_children()
		
		var current_category_state = current_state.get(category.to_lower(), {})
		var expected_category_state = expected_state.get(category.to_lower(), {})
		
		for key in current_category_state.keys():
			var item = state_tree.create_item(category_item)
			var current_value = current_category_state[key]
			var expected_value = expected_category_state.get(key, null)
			
			item.set_text(0, key)
			item.set_text(1, str(current_value))
			item.set_text(2, str(expected_value) if expected_value != null else "N/A")
			
			if expected_value != null:
				var matches = _compare_values(current_value, expected_value)
				item.set_custom_color(1, Color.GREEN if matches else Color.RED)
				item.set_custom_color(2, Color.GREEN if matches else Color.YELLOW)

## Verifies the current state against expected state
func verify_state() -> void:
	var mismatches = []
	var verification_result = {
		"verified": true,
		"mismatches": [],
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	for category in state_categories:
		var current_category_state = current_state.get(category.to_lower(), {})
		var expected_category_state = expected_state.get(category.to_lower(), {})
		
		for key in expected_category_state.keys():
			var current_value = current_category_state.get(key, null)
			var expected_value = expected_category_state[key]
			
			if not _compare_values(current_value, expected_value):
				verification_result.verified = false
				mismatches.append({
					"category": category,
					"key": key,
					"current_value": current_value,
					"expected_value": expected_value
				})
	
	verification_result.mismatches = mismatches
	
	if not verification_result.verified:
		state_mismatch_detected.emit(verification_result)
	
	state_verified.emit(verification_result)
	verification_completed.emit()
	_update_state_display()

## Compares two values for equality
func _compare_values(current: Variant, expected: Variant) -> bool:
	if typeof(current) != typeof(expected):
		return false
	
	match typeof(current):
		TYPE_DICTIONARY, TYPE_ARRAY:
			return str(current) == str(expected)
		_:
			return current == expected

## Button handlers
func _on_verify_pressed() -> void:
	verify_state()

func _on_auto_verify_toggled(enabled: bool) -> void:
	auto_verify = enabled
	if enabled:
		verify_state()

func _on_correction_pressed() -> void:
	var selected = state_tree.get_selected()
	if selected and selected.get_parent() != tree_root:
		var key = selected.get_text(0)
		var current_value = _parse_value(selected.get_text(1))
		var expected_value = _parse_value(selected.get_text(2))
		
		if expected_value != null:
			manual_correction_requested.emit(key, current_value, expected_value)

## Parses a string value back to its original type
func _parse_value(value_str: String) -> Variant:
	if value_str == "N/A":
		return null
		
	if value_str.begins_with("{") or value_str.begins_with("["):
		var json = JSON.new()
		var error = json.parse(value_str)
		if error == OK:
			return json.get_data()
	
	if value_str.is_valid_int():
		return value_str.to_int()
	elif value_str.is_valid_float():
		return value_str.to_float()
	elif value_str == "true":
		return true
	elif value_str == "false":
		return false
	
	return value_str

## Exports verification results
func export_verification_results() -> Dictionary:
	var results = {
		"timestamp": Time.get_datetime_string_from_system(),
		"categories": {}
	}
	
	for category in state_categories:
		var category_results = {
			"verified": true,
			"states": {}
		}
		
		var current_category_state = current_state.get(category.to_lower(), {})
		var expected_category_state = expected_state.get(category.to_lower(), {})
		
		for key in current_category_state.keys():
			var current_value = current_category_state[key]
			var expected_value = expected_category_state.get(key, null)
			
			category_results.states[key] = {
				"current": current_value,
				"expected": expected_value,
				"verified": _compare_values(current_value, expected_value) if expected_value != null else true
			}
			
			if expected_value != null and not _compare_values(current_value, expected_value):
				category_results.verified = false
		
		results.categories[category] = category_results
	
	return results