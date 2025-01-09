@tool
extends Window

## Signals
signal rule_saved(rule_data: Dictionary)
signal editing_cancelled

## Node references
@onready var name_edit: LineEdit = %NameEdit
@onready var category_option: OptionButton = %CategoryOption
@onready var description_edit: TextEdit = %DescriptionEdit
@onready var effects_container: VBoxContainer = %EffectsContainer
@onready var add_effect_button: Button = %AddEffectButton
@onready var save_button: Button = %SaveButton
@onready var cancel_button: Button = %CancelButton

## Properties
var editing_rule_id: String = ""
var rule_categories: Dictionary = {}
var current_effects: Array[Dictionary] = []

## Called when node enters scene tree
func _ready() -> void:
	if not Engine.is_editor_hint():
		save_button.pressed.connect(_on_save_pressed)
		cancel_button.pressed.connect(_on_cancel_pressed)
		add_effect_button.pressed.connect(_on_add_effect_pressed)
		close_requested.connect(_on_cancel_pressed)
		
		_setup_category_options()

## Sets up the category dropdown
func _setup_category_options() -> void:
	category_option.clear()
	
	var index = 0
	for key in rule_categories:
		category_option.add_item(rule_categories[key], index)
		category_option.set_item_metadata(index, key)
		index += 1

## Shows dialog for creating a new rule
func show_create() -> void:
	editing_rule_id = ""
	title = "Create House Rule"
	_clear_form()
	show()
	_center_dialog()

## Shows dialog for editing an existing rule
func show_edit(rule_data: Dictionary) -> void:
	editing_rule_id = rule_data.get("id", "")
	title = "Edit House Rule"
	_populate_form(rule_data)
	show()
	_center_dialog()

## Centers the dialog on screen
func _center_dialog() -> void:
	var screen_size = DisplayServer.screen_get_size()
	position = (screen_size - size) / 2

## Clears the form fields
func _clear_form() -> void:
	name_edit.text = ""
	category_option.selected = 0
	description_edit.text = ""
	current_effects.clear()
	_refresh_effects_list()

## Populates form with existing rule data
func _populate_form(rule_data: Dictionary) -> void:
	name_edit.text = rule_data.get("name", "")
	
	var category = rule_data.get("category", "")
	for i in range(category_option.item_count):
		if category_option.get_item_metadata(i) == category:
			category_option.selected = i
			break
			
	description_edit.text = rule_data.get("description", "")
	current_effects = rule_data.get("effects", []).duplicate()
	_refresh_effects_list()

## Refreshes the effects list display
func _refresh_effects_list() -> void:
	# Clear existing effect widgets
	for child in effects_container.get_children():
		child.queue_free()
	
	# Add effect widgets
	for effect in current_effects:
		_add_effect_widget(effect)

## Adds a new effect widget to the container
func _add_effect_widget(effect_data: Dictionary = {}) -> void:
	var effect_widget = HBoxContainer.new()
	
	var type_option = OptionButton.new()
	type_option.add_item("Modifier", 0)
	type_option.add_item("Override", 1)
	type_option.add_item("Restriction", 2)
	
	var value_edit = SpinBox.new()
	value_edit.min_value = -10
	value_edit.max_value = 10
	value_edit.step = 1
	
	var description_edit = LineEdit.new()
	description_edit.placeholder_text = "Effect description"
	description_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var remove_button = Button.new()
	remove_button.text = "Remove"
	
	effect_widget.add_child(type_option)
	effect_widget.add_child(value_edit)
	effect_widget.add_child(description_edit)
	effect_widget.add_child(remove_button)
	
	if not effect_data.is_empty():
		type_option.selected = effect_data.get("type", 0)
		value_edit.value = effect_data.get("value", 0)
		description_edit.text = effect_data.get("description", "")
	
	remove_button.pressed.connect(func():
		effect_widget.queue_free()
		_update_current_effects()
	)
	
	effects_container.add_child(effect_widget)

## Updates the current effects array from widgets
func _update_current_effects() -> void:
	current_effects.clear()
	
	for child in effects_container.get_children():
		if child is HBoxContainer:
			var type_option = child.get_child(0) as OptionButton
			var value_edit = child.get_child(1) as SpinBox
			var description_edit = child.get_child(2) as LineEdit
			
			current_effects.append({
				"type": type_option.selected,
				"value": value_edit.value,
				"description": description_edit.text
			})

## Validates form data
func _validate_form() -> bool:
	if name_edit.text.strip_edges().is_empty():
		return false
	if description_edit.text.strip_edges().is_empty():
		return false
	return true

## Button handlers
func _on_save_pressed() -> void:
	if not _validate_form():
		# TODO: Show validation error
		return
	
	_update_current_effects()
	
	var rule_data = {
		"id": editing_rule_id if not editing_rule_id.is_empty() else str(Time.get_unix_time_from_system()),
		"name": name_edit.text.strip_edges(),
		"category": category_option.get_selected_metadata(),
		"description": description_edit.text.strip_edges(),
		"effects": current_effects.duplicate()
	}
	
	rule_saved.emit(rule_data)
	hide()

func _on_cancel_pressed() -> void:
	editing_cancelled.emit()
	hide()

func _on_add_effect_pressed() -> void:
	_add_effect_widget()