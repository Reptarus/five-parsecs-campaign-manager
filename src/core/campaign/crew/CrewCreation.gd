class_name CrewCreation
extends Control

signal crew_confirmed(crew: Crew)
signal creation_cancelled
signal crew_created(crew_data: Dictionary)

const MAX_CREW_SIZE = 6
const MIN_CREW_SIZE = 3
const STARTING_CREDITS = 1000

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const CharacterBox = preload("res://src/ui/components/character/CharacterBox.tscn")
const CharacterCreator = preload("res://src/ui/CharacterCreator.tscn")
const CaptainCreation = preload("res://src/ui/CaptainCreation.tscn")

@onready var crew_size_label = $MainContainer/HeaderPanel/MarginContainer/HeaderContent/CrewInfoContainer/CrewSizeLabel
@onready var credits_label = $MainContainer/HeaderPanel/MarginContainer/HeaderContent/CrewInfoContainer/CreditsLabel
@onready var crew_list = $MainContainer/ContentContainer/LeftPanel/MarginContainer/VBoxContainer/CrewList
@onready var character_box = $MainContainer/ContentContainer/RightPanel/MarginContainer/VBoxContainer/CharacterBox
@onready var add_member_button = $MainContainer/ContentContainer/RightPanel/MarginContainer/VBoxContainer/ActionButtons/AddCrewMemberButton
@onready var remove_member_button = $MainContainer/ContentContainer/RightPanel/MarginContainer/VBoxContainer/ActionButtons/RemoveCrewMemberButton
@onready var back_button = $MainContainer/FooterPanel/MarginContainer/HBoxContainer/BackButton
@onready var confirm_button = $MainContainer/FooterPanel/MarginContainer/HBoxContainer/ConfirmButton

var crew: Crew
var selected_member: Character
var is_initial_creation: bool = true
var credits: int = STARTING_CREDITS

func _ready() -> void:
    crew = Crew.new()
    _connect_signals()
    _update_ui()
    
    # Disable remove button initially
    remove_member_button.disabled = true

func _connect_signals() -> void:
    add_member_button.pressed.connect(_on_add_member_pressed)
    remove_member_button.pressed.connect(_on_remove_member_pressed)
    back_button.pressed.connect(_on_back_pressed)
    confirm_button.pressed.connect(_on_confirm_pressed)

func initialize(existing_crew: Crew = null) -> void:
    if existing_crew:
        crew = existing_crew
        is_initial_creation = false
        credits = existing_crew.credits
    _update_ui()

func _update_ui() -> void:
    # Update labels
    crew_size_label.text = "Crew Size: %d/%d" % [crew.get_member_count(), MAX_CREW_SIZE]
    credits_label.text = "Credits: %d" % credits
    
    # Update crew list
    _refresh_crew_list()
    
    # Update buttons
    add_member_button.disabled = crew.get_member_count() >= MAX_CREW_SIZE
    confirm_button.disabled = not _can_confirm()

func _refresh_crew_list() -> void:
    # Clear existing list
    for child in crew_list.get_children():
        child.queue_free()
    
    # Add crew members
    for member in crew.members:
        var member_box = preload("res://src/ui/components/character/CharacterBox.tscn").instantiate()
        member_box.update_display(member)
        
        # Make it clickable
        var button = Button.new()
        button.custom_minimum_size = Vector2(0, 150)
        button.add_child(member_box)
        button.pressed.connect(_on_member_selected.bind(member))
        
        crew_list.add_child(button)

func _on_member_selected(member: Character) -> void:
    selected_member = member
    character_box.update_display(member)
    remove_member_button.disabled = false

func _on_add_member_pressed() -> void:
    # Show character creation dialog
    var creator = preload("res://src/ui/CharacterCreator.tscn").instantiate()
    add_child(creator)
    creator.character_created.connect(_on_character_created)
    creator.creation_cancelled.connect(func(): creator.queue_free())

func _on_character_created(character: Character) -> void:
    if crew.add_member(character):
        _update_ui()
    else:
        # Show error message
        var dialog = AcceptDialog.new()
        dialog.dialog_text = "Cannot add more crew members. Maximum size reached."
        add_child(dialog)
        dialog.popup_centered()

func _on_remove_member_pressed() -> void:
    if selected_member and crew.remove_member(selected_member):
        selected_member = null
        character_box.update_display(null)
        remove_member_button.disabled = true
        _update_ui()

func _on_back_pressed() -> void:
    creation_cancelled.emit()

func _on_confirm_pressed() -> void:
    if _can_confirm():
        crew_confirmed.emit(crew)

func _can_confirm() -> bool:
    var member_count = crew.get_member_count()
    if is_initial_creation:
        return member_count >= MIN_CREW_SIZE and member_count <= MAX_CREW_SIZE
    return true

# Tutorial crew setup
func setup_tutorial_crew() -> void:
    # Load tutorial crew data
    var file = FileAccess.open("res://data/tutorial_character_creation_data.json", FileAccess.READ)
    if file:
        var json = JSON.new()
        var error = json.parse(file.get_as_text())
        file.close()
        
        if error == OK:
            var data = json.data
            
            # Create tutorial crew members
            for member_data in data.get("tutorial_crew", []):
                var character = Character.new()
                character.deserialize(member_data)
                crew.add_member(character)
        
        _update_ui()

# Export functionality
func export_crew_to_pdf() -> void:
    # TODO: Implement PDF export
    pass