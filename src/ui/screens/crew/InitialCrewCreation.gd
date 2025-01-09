class_name InitialCrewCreationUI
extends Control

signal crew_created(crew_data: Dictionary)

@onready var crew_size_option := $CrewSizeOption
@onready var crew_name_input := $CrewNameInput
@onready var character_list := $CharacterList
@onready var create_button := $CreateButton

var crew_data := {
    "name": "",
    "size": 4,
    "characters": []
}

func _ready() -> void:
    _connect_signals()
    _setup_options()

func _connect_signals() -> void:
    crew_size_option.value_changed.connect(_on_crew_size_changed)
    crew_name_input.text_changed.connect(_on_crew_name_changed)
    create_button.pressed.connect(_on_create_pressed)

func _setup_options() -> void:
    crew_size_option.setup(4, "Select the size of your starting crew")
    create_button.disabled = true

func _on_crew_size_changed(size: int) -> void:
    crew_data.size = size
    _validate_crew()

func _on_crew_name_changed(new_name: String) -> void:
    crew_data.name = new_name
    _validate_crew()

func _on_character_selected(character: Dictionary) -> void:
    if not crew_data.characters.has(character):
        if crew_data.characters.size() < crew_data.size:
            crew_data.characters.append(character)
    else:
        crew_data.characters.erase(character)
    
    _validate_crew()

func _validate_crew() -> bool:
    var valid = not crew_data.name.strip_edges().is_empty() and crew_data.characters.size() == crew_data.size
    create_button.disabled = not valid
    return valid

func _on_create_pressed() -> void:
    if _validate_crew():
        crew_created.emit(crew_data)