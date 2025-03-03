extends Control

const Character = preload("res://src/core/character/Base/Character.gd")
const CharacterStats = preload("res://src/core/character/Base/CharacterStats.gd")
const CharacterTableRoller = preload("res://src/core/character/Generation/CharacterTableRoller.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal captain_created(captain_data: Dictionary)
signal back_pressed

@onready var name_input := %NameInput
@onready var origin_option := %OriginOption
@onready var background_option := %BackgroundOption
@onready var class_option := %ClassOption
@onready var confirm_button := %ConfirmButton
@onready var back_button := %BackButton
@onready var preview_label := %PreviewLabel
@onready var preview_info := %PreviewInfo
@onready var title_label := %TitleLabel

func _ready() -> void:
	_setup_ui()
	_connect_signals()

func _setup_ui() -> void:
	_populate_dropdowns()
	confirm_button.disabled = true

func _connect_signals() -> void:
	name_input.text_changed.connect(_on_name_changed)
	origin_option.item_selected.connect(_on_origin_selected)
	background_option.item_selected.connect(_on_background_selected)
	class_option.item_selected.connect(_on_class_selected)
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _populate_dropdowns() -> void:
	# Populate origin dropdown
	for origin in GlobalEnums.Origin.keys():
		origin_option.add_item(origin)
	
	# Populate class dropdown
	for class_type in GlobalEnums.CharacterClass.keys():
		class_option.add_item(class_type)

func _on_name_changed(new_text: String) -> void:
	confirm_button.disabled = new_text.strip_edges().is_empty()
	_update_preview()

func _on_origin_selected(_index: int) -> void:
	_update_preview()

func _on_background_selected(_index: int) -> void:
	_update_preview()

func _on_class_selected(_index: int) -> void:
	_update_preview()

func _on_confirm_pressed() -> void:
	var captain_data = {
		"name": name_input.text,
		"origin": GlobalEnums.Origin.values()[origin_option.selected],
		"class": GlobalEnums.CharacterClass.values()[class_option.selected]
	}
	captain_created.emit(captain_data)

func _on_back_pressed() -> void:
	back_pressed.emit()

func _update_preview() -> void:
	var preview_text = "[center][color=yellow]Captain Preview[/color][/center]\n\n"
	
	if not name_input.text.strip_edges().is_empty():
		preview_text += "[color=lime]Name:[/color] %s\n" % name_input.text
	
	if origin_option.selected >= 0:
		preview_text += "[color=lime]Origin:[/color] %s\n" % GlobalEnums.Origin.keys()[origin_option.selected]
	
	if class_option.selected >= 0:
		preview_text += "[color=lime]Class:[/color] %s\n" % GlobalEnums.CharacterClass.keys()[class_option.selected]
	
	preview_label.text = preview_text
