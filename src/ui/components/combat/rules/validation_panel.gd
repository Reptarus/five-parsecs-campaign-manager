@tool
extends PanelContainer

## Signals
signal validation_completed(rule: Dictionary, context: String, is_valid: bool)

## Node References
@onready var message_label: Label = %MessageLabel
@onready var details_label: Label = %DetailsLabel
@onready var icon_texture: TextureRect = %IconTexture

## Properties
# Using built-in Godot icons temporarily
var success_icon: Texture2D = null
var error_icon: Texture2D = null

## Called when the node enters scene tree
func _ready() -> void:
	if not Engine.is_editor_hint():
		hide()
		_setup_icons()
		_validate_ui_elements()

## Sets up default icons
func _setup_icons() -> void:
	# Attempt to load from theme with fallbacks
	success_icon = get_theme_icon("StatusSuccess", "EditorIcons")
	error_icon = get_theme_icon("StatusError", "EditorIcons")
	
	# Fallbacks if theme icons aren't available
	if not success_icon:
		push_warning("ValidationPanel: StatusSuccess icon not found in theme, using fallback")
		# Create a simple green placeholder texture
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0.8, 0, 1.0))
		success_icon = ImageTexture.create_from_image(img)
		
	if not error_icon:
		push_warning("ValidationPanel: StatusError icon not found in theme, using fallback")
		# Create a simple red placeholder texture
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.8, 0, 0, 1.0))
		error_icon = ImageTexture.create_from_image(img)

## Validates that all UI elements are available
func _validate_ui_elements() -> bool:
	var elements_valid = true
	
	if not is_instance_valid(message_label):
		push_error("ValidationPanel: MessageLabel not found")
		elements_valid = false
	
	if not is_instance_valid(details_label):
		push_error("ValidationPanel: DetailsLabel not found")
		elements_valid = false
	
	if not is_instance_valid(icon_texture):
		push_error("ValidationPanel: IconTexture not found")
		elements_valid = false
	
	return elements_valid

## Shows success message
func show_success(message: String, details: String = "") -> void:
	if not _validate_ui_elements():
		push_error("ValidationPanel: Cannot show success message - UI elements missing")
		return
		
	message_label.text = message
	details_label.text = details
	
	if success_icon:
		icon_texture.texture = success_icon
	
	_show_message()
	validation_completed.emit({}, "", true)

## Shows error message
func show_error(message: String, details: String = "") -> void:
	if not _validate_ui_elements():
		push_error("ValidationPanel: Cannot show error message - UI elements missing")
		return
		
	message_label.text = message
	details_label.text = details
	
	if error_icon:
		icon_texture.texture = error_icon
	
	_show_message()
	validation_completed.emit({}, "", false)

## Shows validation panel
func _show_message() -> void:
	show()
	
	# Safely create timer (with error handling)
	if not is_instance_valid(get_tree()):
		push_warning("ValidationPanel: Scene tree is null, cannot auto-hide")
		return
		
	var timer = get_tree().create_timer(3.0)
	if not timer:
		push_warning("ValidationPanel: Failed to create auto-hide timer")
		return
		
	# Auto-hide after delay
	await timer.timeout
	hide()