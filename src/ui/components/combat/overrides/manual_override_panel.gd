@tool
extends PanelContainer

## Signals
signal override_requested(context: String, current_value: int)
signal override_applied(value: int)
signal override_cancelled

## Node references
@onready var override_type_label: Label = %OverrideTypeLabel
@onready var current_value_label: Label = %CurrentValueLabel
@onready var override_value_spinbox: SpinBox = %OverrideValueSpinBox
@onready var apply_button: Button = %ApplyButton
@onready var cancel_button: Button = %CancelButton

## Properties
var current_context: String = ""
var current_value: int = 0
var min_value: int = 1
var max_value: int = 6

## Called when the node enters the scene tree
func _ready() -> void:
	if not Engine.is_editor_hint():
		apply_button.pressed.connect(_on_apply_pressed)
		cancel_button.pressed.connect(_on_cancel_pressed)
		override_value_spinbox.value_changed.connect(_on_value_changed)
		hide()

## Shows the override panel for a specific context
func show_override(context: String, value: int, min_val: int = 1, max_val: int = 6) -> void:
	current_context = context
	current_value = value
	min_value = min_val
	max_value = max_val
	
	override_type_label.text = _get_context_label(context)
	current_value_label.text = "Current Value: %d" % value
	
	override_value_spinbox.min_value = min_val
	override_value_spinbox.max_value = max_val
	override_value_spinbox.value = value
	
	show()

## Converts context string to user-friendly label
func _get_context_label(context: String) -> String:
	var parts := context.split("_")
	var label := ""
	for part in parts:
		label += part.capitalize() + " "
	return label.strip_edges()

## Called when the apply button is pressed
func _on_apply_pressed() -> void:
	override_applied.emit(int(override_value_spinbox.value))
	hide()

## Called when the cancel button is pressed
func _on_cancel_pressed() -> void:
	override_cancelled.emit()
	hide()

## Called when the override value changes
func _on_value_changed(value: float) -> void:
	apply_button.disabled = value == current_value