extends Control

signal connections_created

@onready var connections_list: ItemList = $VBoxContainer/ConnectionsList
@onready var add_connection_button: Button = $VBoxContainer/AddConnectionButton
@onready var tutorial_label: Label = $TutorialLabel
@onready var character1_dropdown: OptionButton = $VBoxContainer/HBoxContainer/Character1Dropdown
@onready var character2_dropdown: OptionButton = $VBoxContainer/HBoxContainer/Character2Dropdown
@onready var relationship_dropdown: OptionButton = $VBoxContainer/HBoxContainer/RelationshipDropdown
@onready var finalize_button: Button = $VBoxContainer/FinalizeButton

var characters: Array[Character] = []
var connections: Array[Dictionary] = []
var extended_connections_manager: ExtendedConnectionsManager

const RELATIONSHIPS: Array[String] = [
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

func _ready() -> void:
    if not GameStateManager:
        push_error("GameStateManager not found. Ensure it's properly set up.")
        return

    # Create a new GameState instance to pass to ExtendedConnectionsManager
    var temp_game_state = GameState.new()
    # Copy relevant data from MockGameState to GameState if needed
    # For example: temp_game_state.some_property = GameStateManager.game_state.some_property

    extended_connections_manager = ExtendedConnectionsManager.new(temp_game_state)
    
    if GameStateManager.game_state.is_tutorial_active:
        if GameStateManager.game_state.story_track and GameStateManager.game_state.story_track.current_event:
            tutorial_label.text = GameStateManager.game_state.story_track.current_event.instruction
            tutorial_label.show()
        else:
            push_warning("Tutorial is active but story_track or current_event is missing.")
            tutorial_label.hide()
    else:
        tutorial_label.hide()

    add_connection_button.pressed.connect(_on_add_connection_pressed)
    finalize_button.pressed.connect(finalize_connections)

    _populate_dropdowns()

func _populate_dropdowns() -> void:
    for character in characters:
        character1_dropdown.add_item(character.name)
        character2_dropdown.add_item(character.name)
    
    for relationship in RELATIONSHIPS:
        relationship_dropdown.add_item(relationship)

func _on_add_connection_pressed() -> void:
    var character1_index: int = character1_dropdown.selected
    var character2_index: int = character2_dropdown.selected
    var relationship: String = relationship_dropdown.get_item_text(relationship_dropdown.selected)

    if character1_index == character2_index:
        _show_error("A character cannot have a connection with themselves.")
        return

    if _connection_exists(character1_index, character2_index):
        _show_error("This connection already exists.")
        return

    var connection: Dictionary = extended_connections_manager.generate_connection()
    connection["character1"] = characters[character1_index]
    connection["character2"] = characters[character2_index]
    connection["relationship"] = relationship
    
    connections.append(connection)
    _update_connections_list()

func _connection_exists(char1_index: int, char2_index: int) -> bool:
    for connection in connections:
        if (connection["character1"] == characters[char1_index] and connection["character2"] == characters[char2_index]) or \
           (connection["character1"] == characters[char2_index] and connection["character2"] == characters[char1_index]):
            return true
    return false

func _update_connections_list() -> void:
    connections_list.clear()
    for connection in connections:
        var char1_name: String = connection["character1"].name
        var char2_name: String = connection["character2"].name
        var relationship: String = connection["relationship"]
        var connection_text: String = "%s - %s - %s" % [char1_name, relationship, char2_name]
        connections_list.add_item(connection_text)

func _show_error(message: String) -> void:
    var error_dialog: AcceptDialog = AcceptDialog.new()
    error_dialog.dialog_text = message
    add_child(error_dialog)
    error_dialog.popup_centered()

func finalize_connections() -> void:
    if connections.is_empty():
        _show_error("Please create at least one connection before finalizing.")
        return

    save_connections_to_game_state()

    connections_created.emit()
    if GameStateManager.game_state.is_tutorial_active:
        GameStateManager.game_state.current_state = GlobalEnums.CampaignPhase.CREW_CREATION

func save_connections_to_game_state() -> void:
    GameStateManager.game_state.character_connections = connections

func set_characters(char_list: Array[Character]) -> void:
    characters = char_list
    _populate_dropdowns()

func get_connections() -> Array[Dictionary]:
    return connections
