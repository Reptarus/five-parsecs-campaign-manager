@tool
extends PanelContainer

## Signals
signal validation_completed(rule: Dictionary, context: String, is_valid: bool)

## Node References
@onready var message_label: Label = %MessageLabel
@onready var details_label: Label = %DetailsLabel
@onready var icon_texture: TextureRect = %IconTexture

## Properties
var success_icon: Texture2D = preload("res://assets/icons/success.png")
var error_icon: Texture2D = preload("res://assets/icons/error.png")

## Called when the node enters scene tree
func _ready() -> void:
	if not Engine.is_editor_hint():
		hide()

## Shows success message
func show_success(message: String, details: String = "") -> void:
	message_label.text = message
	details_label.text = details
	icon_texture.texture = success_icon
	
	_show_message()
	validation_completed.emit({}, "", true)

## Shows error message
func show_error(message: String, details: String = "") -> void:
	message_label.text = message
	details_label.text = details
	icon_texture.texture = error_icon
	
	_show_message()
	validation_completed.emit({}, "", false)

## Shows validation panel
func _show_message() -> void:
	show()
	
	# Auto-hide after delay
	await get_tree().create_timer(3.0).timeout
	hide()