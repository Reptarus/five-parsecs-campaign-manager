extends Control

signal crew_created(crew_data: Dictionary)

@onready var name_input := $VBoxContainer/NameInput
@onready var class_dropdown := $VBoxContainer/ClassDropdown
@onready var origin_dropdown := $VBoxContainer/OriginDropdown
@onready var create_button := $VBoxContainer/CreateButton

func _ready() -> void:
	_setup_ui()
	_connect_signals()

func _setup_ui() -> void:
	_populate_dropdowns()
	create_button.disabled = true

func _connect_signals() -> void:
	name_input.text_changed.connect(_on_name_changed)
	class_dropdown.item_selected.connect(_on_class_selected)
	origin_dropdown.item_selected.connect(_on_origin_selected)
	create_button.pressed.connect(_on_create_pressed)

func _populate_dropdowns() -> void:
	# Populate class dropdown
	for class_type in GlobalEnums.CharacterClass.keys():
		class_dropdown.add_item(class_type)
	
	# Populate origin dropdown
	for origin in GlobalEnums.Origin.keys():
		origin_dropdown.add_item(origin)

func _on_name_changed(new_text: String) -> void:
	create_button.disabled = new_text.strip_edges().is_empty()

func _on_class_selected(_index: int) -> void:
	pass

func _on_origin_selected(_index: int) -> void:
	pass

func _on_create_pressed() -> void:
	var crew_data = {
		"name": name_input.text,
		"class": class_dropdown.selected,
		"origin": origin_dropdown.selected
	}
	crew_created.emit(crew_data)