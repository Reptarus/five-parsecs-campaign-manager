@tool
extends PanelContainer

## Signals
signal rule_saved(rule_id: String, rule_data: Dictionary)
signal rule_deleted(rule_id: String)
signal preview_requested(rule_data: Dictionary)

## Node References
@onready var type_option: OptionButton = %TypeOption
@onready var name_edit: LineEdit = %NameEdit
@onready var description_edit: TextEdit = %DescriptionEdit
@onready var fields_container: VBoxContainer = %FieldsContainer
@onready var save_button: Button = %SaveButton
@onready var delete_button: Button = %DeleteButton
@onready var preview_button: Button = %PreviewButton

## Properties
var current_rule_id: String = ""
var current_type: String = ""
var field_controls: Dictionary = {}

## Called when the node enters scene tree
func _ready() -> void:
	if not Engine.is_editor_hint():
		_validate_components()
		_setup_signals()
		_setup_type_options()
		_update_button_states()

## Validates all required components are present
func _validate_components() -> bool:
	var all_valid = true
	
	if not is_instance_valid(type_option):
		push_error("RuleEditor: type_option not found")
		all_valid = false
	
	if not is_instance_valid(name_edit):
		push_error("RuleEditor: name_edit not found")
		all_valid = false
	
	if not is_instance_valid(description_edit):
		push_error("RuleEditor: description_edit not found")
		all_valid = false
	
	if not is_instance_valid(fields_container):
		push_error("RuleEditor: fields_container not found")
		all_valid = false
	
	if not is_instance_valid(save_button):
		push_error("RuleEditor: save_button not found")
		all_valid = false
	
	if not is_instance_valid(delete_button):
		push_error("RuleEditor: delete_button not found")
		all_valid = false
	
	if not is_instance_valid(preview_button):
		push_error("RuleEditor: preview_button not found")
		all_valid = false
		
	return all_valid

## Sets up internal signals
func _setup_signals() -> void:
	if not _validate_components():
		push_warning("RuleEditor: Cannot set up signals - missing components")
		return
		
	type_option.item_selected.connect(_on_type_selected)
	name_edit.text_changed.connect(_on_name_changed)
	save_button.pressed.connect(_on_save_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	preview_button.pressed.connect(_on_preview_pressed)

## Sets up rule type options
func _setup_type_options() -> void:
	if not is_instance_valid(type_option):
		return
		
	type_option.clear()
	
	# Add default option
	type_option.add_item("Select Type", 0)
	type_option.set_item_metadata(0, "")
	
	# Add rule types from parent if available
	var parent_node = get_parent()
	if not is_instance_valid(parent_node) or not parent_node.has("rule_templates"):
		push_warning("RuleEditor: Parent doesn't have rule_templates, using empty set")
		return
	
	var templates = parent_node.rule_templates
	if typeof(templates) != TYPE_DICTIONARY:
		push_warning("RuleEditor: Parent has invalid rule_templates format")
		return
		
	# Add rule types
	var index = 1
	for type in templates:
		var template = templates[type]
		if typeof(template) == TYPE_DICTIONARY and template.has("name"):
			type_option.add_item(template.name, index)
			type_option.set_item_metadata(index, type)
			index += 1

## Loads a rule for editing
func load_rule(rule_id: String, rule_data: Dictionary) -> void:
	if not _validate_components():
		push_warning("RuleEditor: Cannot load rule - missing components")
		return
		
	if not _is_valid_rule_data(rule_data):
		push_warning("RuleEditor: Attempted to load invalid rule data")
		return
		
	current_rule_id = rule_id
	
	# Set basic fields
	name_edit.text = rule_data.get("name", "")
	description_edit.text = rule_data.get("description", "")
	
	# Set rule type
	var type = rule_data.get("type", "")
	var type_found = false
	for i in range(type_option.item_count):
		if type_option.get_item_metadata(i) == type:
			type_option.select(i)
			_on_type_selected(i)
			type_found = true
			break
	
	if not type_found:
		push_warning("RuleEditor: Could not find matching type for: " + type)
		return
	
	# Set field values
	if rule_data.has("fields") and typeof(rule_data.fields) == TYPE_ARRAY:
		for field in rule_data.fields:
			if typeof(field) != TYPE_DICTIONARY or not field.has("name") or not field.has("value"):
				continue
				
			if field_controls.has(field.name):
				_set_control_value(field_controls[field.name], field.value)
	
	_update_button_states()

## Creates field controls for rule type
func _create_field_controls(type: String) -> void:
	# Clear existing fields
	for child in fields_container.get_children():
		child.queue_free()
	field_controls.clear()
	
	if type.is_empty():
		return
	
	var parent_node = get_parent()
	if not is_instance_valid(parent_node) or not parent_node.has("rule_templates"):
		push_warning("RuleEditor: Parent doesn't have rule_templates, cannot create fields")
		return
		
	var templates = parent_node.rule_templates
	if not templates.has(type):
		push_warning("RuleEditor: Template not found for type: " + type)
		return
		
	var template = templates[type]
	if not template.has("fields") or typeof(template.fields) != TYPE_ARRAY:
		push_warning("RuleEditor: Template missing fields array")
		return
	
	for field_name in template.fields:
		if typeof(field_name) != TYPE_STRING or field_name.is_empty():
			push_warning("RuleEditor: Invalid field name in template")
			continue
			
		var field_container = HBoxContainer.new()
		fields_container.add_child(field_container)
		
		var label = Label.new()
		label.text = field_name.capitalize()
		field_container.add_child(label)
		
		var control = _create_field_control(field_name)
		if control:
			field_container.add_child(control)
			field_controls[field_name] = control
		else:
			push_warning("RuleEditor: Failed to create control for field: " + field_name)

## Creates appropriate control for field type
func _create_field_control(field_name: String) -> Control:
	match field_name:
		"value":
			var spinbox = SpinBox.new()
			spinbox.min_value = -10
			spinbox.max_value = 10
			spinbox.step = 1
			return spinbox
		"condition", "target", "resource_type":
			var option = OptionButton.new()
			_populate_field_options(option, field_name)
			return option
		"state_key":
			var edit = LineEdit.new()
			edit.placeholder_text = "Enter state key"
			return edit
		"operator":
			var option = OptionButton.new()
			option.add_item("Equals", 0)
			option.add_item("Not Equals", 1)
			option.add_item("Greater Than", 2)
			option.add_item("Less Than", 3)
			return option
		_:
			var edit = LineEdit.new()
			edit.placeholder_text = "Enter value"
			return edit

## Populates options for field type
func _populate_field_options(option: OptionButton, field_name: String) -> void:
	if not is_instance_valid(option):
		return
		
	match field_name:
		"condition":
			option.add_item("Always", 0)
			option.add_item("In Combat", 1)
			option.add_item("Out of Combat", 2)
			option.add_item("Low Health", 3)
			option.add_item("High Health", 4)
		"target":
			option.add_item("Self", 0)
			option.add_item("Ally", 1)
			option.add_item("Enemy", 2)
			option.add_item("All", 3)
		"resource_type":
			option.add_item("Credits", 0)
			option.add_item("Ammo", 1)
			option.add_item("Medical", 2)
			option.add_item("Fuel", 3)

## Gets current rule data
func get_rule_data() -> Dictionary:
	if not _validate_components():
		push_warning("RuleEditor: Cannot get rule data - missing components")
		return {}
		
	var data = {
		"name": name_edit.text,
		"description": description_edit.text,
		"type": current_type,
		"fields": []
	}
	
	for field_name in field_controls:
		var control = field_controls[field_name]
		if not is_instance_valid(control):
			push_warning("RuleEditor: Invalid control for field: " + field_name)
			continue
			
		var value = _get_control_value(control)
		data.fields.append({
			"name": field_name,
			"value": value
		})
	
	return data

## Sets a value to a specific control based on its type
func _set_control_value(control: Control, value: Variant) -> void:
	if not is_instance_valid(control):
		return
		
	if control is SpinBox:
		control.value = float(value) if value != null else 0
	elif control is OptionButton:
		var found = false
		for i in range(control.get_item_count()):
			var item_value = control.get_item_id(i)
			if item_value == value:
				control.select(i)
				found = true
				break
		if not found and control.get_item_count() > 0:
			control.select(0)
	elif control is LineEdit:
		control.text = str(value) if value != null else ""

## Gets value from control
func _get_control_value(control: Control) -> Variant:
	if control is SpinBox:
		return control.value
	elif control is OptionButton:
		return control.get_selected_metadata() if control.get_selected_metadata() != null else control.get_selected_id()
	elif control is LineEdit:
		return control.text
	return null

## Updates button states
func _update_button_states() -> void:
	if not _validate_components():
		return
		
	var has_type = not current_type.is_empty()
	var has_name = not name_edit.text.is_empty()
	
	save_button.disabled = not (has_type and has_name)
	delete_button.disabled = current_rule_id.is_empty()
	preview_button.disabled = not (has_type and has_name)

## Checks if rule data has required fields
func _is_valid_rule_data(rule_data: Dictionary) -> bool:
	if not rule_data.has("type") or typeof(rule_data.type) != TYPE_STRING:
		return false
		
	if not rule_data.has("name") or typeof(rule_data.name) != TYPE_STRING:
		return false
		
	return true

## Signal Handlers
func _on_type_selected(index: int) -> void:
	if not is_instance_valid(type_option):
		return
		
	if index < 0 or index >= type_option.get_item_count():
		push_warning("RuleEditor: Invalid type selection index")
		return
		
	current_type = type_option.get_item_metadata(index)
	_create_field_controls(current_type)
	_update_button_states()

func _on_name_changed(_new_text: String) -> void:
	_update_button_states()

func _on_save_pressed() -> void:
	var rule_data = get_rule_data()
	if _is_valid_rule_data(rule_data):
		rule_saved.emit(current_rule_id, rule_data)
	else:
		push_warning("RuleEditor: Cannot save - invalid rule data")

func _on_delete_pressed() -> void:
	rule_deleted.emit(current_rule_id)
	current_rule_id = ""
	_update_button_states()

func _on_preview_pressed() -> void:
	var rule_data = get_rule_data()
	if _is_valid_rule_data(rule_data):
		preview_requested.emit(rule_data)
	else:
		push_warning("RuleEditor: Cannot preview - invalid rule data")