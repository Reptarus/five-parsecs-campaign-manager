extends Control
class_name PortraitSelector

## Simple Portrait Selector Component
## Uses Godot's built-in FileDialog instead of over-engineered PortraitManager
## Framework Bible compliant: simple, direct implementation

signal portrait_selected(portrait_path: String)
signal portrait_cleared()

@onready var portrait_preview: TextureRect = $PortraitPreview
@onready var select_button: Button = $SelectButton
@onready var clear_button: Button = $ClearButton

var current_portrait_path: String = ""
var portrait_texture: Texture2D = null
var file_dialog: FileDialog

func _ready() -> void:
	# Create file dialog programmatically - simple and effective
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.png,*.jpg,*.jpeg", "Image files")
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)
	
	# Connect UI signals
	if select_button:
		select_button.pressed.connect(_on_select_pressed)
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)
	if file_dialog:
		file_dialog.file_selected.connect(_on_file_selected)

func _on_select_pressed() -> void:
	"""Handle select button press"""
	if file_dialog:
		file_dialog.popup_centered()

func _on_clear_pressed() -> void:
	"""Handle clear button press"""
	clear_portrait()

func _on_file_selected(path: String) -> void:
	"""Handle file selection from dialog - Simple Godot-native implementation"""
	var image = Image.load_from_file(path)
	if image:
		# Simple validation - check if it's a valid image
		if image.get_width() > 0 and image.get_height() > 0:
			portrait_texture = ImageTexture.create_from_image(image)
			current_portrait_path = path
			_update_preview()
			portrait_selected.emit(path)
			print("PortraitSelector: Portrait loaded successfully: ", path)
		else:
			_show_error_dialog("Invalid image file")
	else:
		_show_error_dialog("Could not load image file")

func _update_preview() -> void:
	"""Update the portrait preview"""
	if not portrait_preview:
		return
	
	if portrait_texture:
		portrait_preview.texture = portrait_texture
		portrait_preview.modulate = Color.WHITE
	else:
		portrait_preview.texture = null
		portrait_preview.modulate = Color.GRAY

func clear_portrait() -> void:
	"""Clear the current portrait"""
	current_portrait_path = ""
	portrait_texture = null
	_update_preview()
	portrait_cleared.emit()

func set_portrait_from_path(path: String) -> void:
	"""Set portrait from a file path"""
	if path.is_empty():
		clear_portrait()
		return
	
	# Portrait manager not available - use direct image loading
	var texture = ImageTexture.create_from_image(Image.load_from_file(path))
	if texture:
		portrait_texture = texture
		current_portrait_path = path
		_update_preview()

func get_portrait_texture() -> Texture2D:
	"""Get the current portrait texture"""
	return portrait_texture

func get_portrait_path() -> String:
	"""Get the current portrait path"""
	return current_portrait_path

func _show_error_dialog(message: String) -> void:
	"""Show error dialog"""
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = message
	error_dialog.title = "Portrait Error"
	get_viewport().add_child(error_dialog)
	error_dialog.popup_centered()
	error_dialog.confirmed.connect(func(): error_dialog.queue_free())
