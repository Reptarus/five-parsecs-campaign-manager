extends Control
class_name PortraitSelector

## Portrait Selector Component
## Reusable UI component for selecting character portraits

const PortraitManager = preload("res://src/utils/PortraitManager.gd")

signal portrait_selected(portrait_path: String)
signal portrait_cleared()

@onready var portrait_preview: TextureRect = $PortraitPreview
@onready var select_button: Button = $SelectButton
@onready var clear_button: Button = $ClearButton
@onready var file_dialog: FileDialog = $FileDialog

var current_portrait_path: String = ""
var portrait_texture: Texture2D = null
var portrait_manager: PortraitManager

func _ready() -> void:
	portrait_manager = PortraitManager.new()
	portrait_manager.portrait_loaded.connect(_on_portrait_loaded)
	portrait_manager.portrait_error.connect(_on_portrait_error)
	
	# Connect signals
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
	"""Handle file selection from dialog"""
	var texture = portrait_manager.import_portrait(path)
	if texture:
		portrait_texture = texture
		current_portrait_path = path
		_update_preview()
		portrait_selected.emit(path)

func _on_portrait_loaded(path: String) -> void:
	"""Handle successful portrait load"""
	print("PortraitSelector: Portrait loaded: ", path)

func _on_portrait_error(error_message: String) -> void:
	"""Handle portrait loading error"""
	_show_error_dialog(error_message)

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
	
	var texture = portrait_manager.load_portrait_from_path(path)
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
