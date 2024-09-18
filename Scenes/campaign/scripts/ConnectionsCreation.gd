extends Control

signal connections_created

@onready var connections_list = $VBoxContainer/ConnectionsList
@onready var add_connection_button = $VBoxContainer/AddConnectionButton
@onready var tutorial_label = $TutorialLabel
@onready var character1_dropdown = $VBoxContainer/HBoxContainer/Character1Dropdown
@onready var character2_dropdown = $VBoxContainer/HBoxContainer/Character2Dropdown
@onready var relationship_dropdown = $VBoxContainer/HBoxContainer/RelationshipDropdown
@onready var finalize_button = $VBoxContainer/FinalizeButton

var characters = []  # This should be populated with the created characters
var connections = []  # Store the created connections

const RELATIONSHIPS = [
    "Friend",
    "Rival",
    "Mentor",
    "Student",
    "Sibling",
    "Lover",
    "Ex-lover",
    "Colleague",
    "Enemy",
    "Acquaintance"
]

func _ready():
    if TutorialManager.is_tutorial_active:
        tutorial_label.text = TutorialManager.get_tutorial_text("connections_creation")
        tutorial_label.show()
    else:
        tutorial_label.hide()

    add_connection_button.connect("pressed", _on_add_connection_pressed)
    finalize_button.connect("pressed", finalize_connections)

    _populate_dropdowns()

func _populate_dropdowns():
    for character in characters:
        character1_dropdown.add_item(character.name)
        character2_dropdown.add_item(character.name)
    
    for relationship in RELATIONSHIPS:
        relationship_dropdown.add_item(relationship)

func _on_add_connection_pressed():
    var character1_index = character1_dropdown.selected
    var character2_index = character2_dropdown.selected
    var relationship = relationship_dropdown.get_item_text(relationship_dropdown.selected)

    if character1_index == character2_index:
        _show_error("A character cannot have a connection with themselves.")
        return

    if _connection_exists(character1_index, character2_index):
        _show_error("This connection already exists.")
        return

    var connection = {
        "character1": characters[character1_index],
        "character2": characters[character2_index],
        "relationship": relationship
    }
    
    connections.append(connection)
    _update_connections_list()

func _connection_exists(char1_index: int, char2_index: int) -> bool:
    for connection in connections:
        if (connection.character1 == characters[char1_index] and connection.character2 == characters[char2_index]) or \
           (connection.character1 == characters[char2_index] and connection.character2 == characters[char1_index]):
            return true
    return false

func _update_connections_list():
    connections_list.clear()
    for connection in connections:
        connections_list.add_item(f"{connection.character1.name} - {connection.relationship} - {connection.character2.name}")

func _show_error(message: String):
    var error_dialog = AcceptDialog.new()
    error_dialog.dialog_text = message
    add_child(error_dialog)
    error_dialog.popup_centered()

func finalize_connections():
    if connections.is_empty():
        _show_error("Please create at least one connection before finalizing.")
        return

    save_connections_to_game_state()

    emit_signal("connections_created")
    if TutorialManager.is_tutorial_active:
        TutorialManager.set_step("save_campaign")

func save_connections_to_game_state():
    if GameState.has_method("set_character_connections"):
        GameState.set_character_connections(connections)
    else:
        print("Warning: GameState does not have a method to set character connections.")

func set_characters(char_list: Array):
    characters = char_list
    _populate_dropdowns()

# Optional: Method to get the created connections
func get_connections() -> Array:
    return connections
