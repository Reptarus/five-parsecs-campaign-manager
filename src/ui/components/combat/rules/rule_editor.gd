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
		_setup_signals()
		_setup_type_options()
		_update_button_states()

## Sets up internal signals
func _setup_signals() -> void:
	type_option.item_selected.connect(_on_type_selected)
	name_edit.text_changed.connect(_on_name_changed)
	save_button.pressed.connect(_on_save_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	preview_button.pressed.connect(_on_preview_pressed)

## Sets up rule type options
func _setup_type_options() -> void:
	type_option.clear()
	
	# Add default option
	type_option.add_item("Select Type", 0)
	type_option.set_item_metadata(0, "")
	
	# Add rule types
	var index = 1
	for type in get_parent().rule_templates:
		var template = get_parent().rule_templates[type]
		type_option.add_item(template.name, index)
		type_option.set_item_metadata(index, type)
		index += 1

## Loads a rule for editing
func load_rule(rule_id: String, rule_data: Dictionary) -> void:
	current_rule_id = rule_id
	
	# Set basic fields
	name_edit.text = rule_data.get("name", "")
	description_edit.text = rule_data.get("description", "")
	
	# Set rule type
	var type = rule_data.get("type", "")
	for i in range(type_option.item_count):
		if type_option.get_item_metadata(i) == type:
			type_option.select(i)
			_on_type_selected(i)
			break
	
	# Set field values
	if rule_data.has("fields"):
		for field in rule_data.fields:
			if field_controls.has(field.name):
				field_controls[field.name].value = field.value
	
	_update_button_states()

## Creates field controls for rule type
func _create_field_controls(type: String) -> void:
	# Clear existing fields
	for child in fields_container.get_children():
		child.queue_free()
	field_controls.clear()
	
	if type.is_empty():
		return
	
	var template = get_parent().rule_templates[type]
	if not template.has("fields"):
		return
	
	for field_name in template.fields:
		var field_container = HBoxContainer.new()
		fields_container.add_child(field_container)
		
		var label = Label.new()
		label.text = field_name.capitalize()
		field_container.add_child(label)
		
		var control = _create_field_control(field_name)
		field_container.add_child(control)
		field_controls[field_name] = control

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
	var data = {
		"name": name_edit.text,
		"description": description_edit.text,
		"type": current_type,
		"fields": []
	}
	
	for field_name in field_controls:
		var control = field_controls[field_name]
		var value = _get_control_value(control)
		data.fields.append({
			"name": field_name,
			"value": value
		})
	
	return data

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
	var has_type = not current_type.is_empty()
	var has_name = not name_edit.text.is_empty()
	
	save_button.disabled = not (has_type and has_name)
	delete_button.disabled = current_rule_id.is_empty()
	preview_button.disabled = not (has_type and has_name)

## Signal Handlers
func _on_type_selected(index: int) -> void:
	current_type = type_option.get_item_metadata(index)
	_create_field_controls(current_type)
	_update_button_states()

func _on_name_changed(_new_text: String) -> void:
	_update_button_states()

func _on_save_pressed() -> void:
	rule_saved.emit(current_rule_id, get_rule_data())

func _on_delete_pressed() -> void:
	rule_deleted.emit(current_rule_id)
	current_rule_id = ""
	_update_button_states()

func _on_preview_pressed() -> void:
	preview_requested.emit(get_rule_data())