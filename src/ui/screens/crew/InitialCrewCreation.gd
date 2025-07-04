class_name FPCM_InitialCrewCreationUI
extends Control

## Five Parsecs Initial Crew Creation UI
## Integrates with CharacterGeneration system for complete crew creation

# Safe imports using Universal Safety System
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd")
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const FiveParsecsCharacterGeneration = preload("res://src/core/character/CharacterGeneration.gd")
const CoreCharacter = preload("res://src/core/character/Base/Character.gd")

signal crew_created(crew_data: Dictionary)
signal character_generated(character: CoreCharacter)

@onready var crew_size_option := $CrewSizeOption
@onready var crew_name_input := $CrewNameInput
@onready var character_list := $CharacterList
@onready var create_button := $CreateButton
@onready var generate_button := $GenerateButton
@onready var character_details := $CharacterDetails

var crew_data := {
    "name": "",
    "size": 4,
    "characters": []
}

# Character generation system
var generated_characters: Array[CoreCharacter] = []
var character_manager: Node = null

func _ready() -> void:
    _initialize_character_system()
    _connect_signals()
    _setup_options()

func _initialize_character_system() -> void:
    """Initialize connection to character generation system"""
    # Connect to CharacterManager through GameStateManager
    var game_state = get_node_or_null("/root/GameStateManager")
    if game_state and game_state.has_method("get_manager"):
        character_manager = game_state.get_manager("CharacterManager")
        if character_manager:
            print("InitialCrewCreation: Connected to CharacterManager")
        else:
            push_warning("InitialCrewCreation: CharacterManager not available")
    else:
        push_warning("InitialCrewCreation: GameStateManager not available")

func _connect_signals() -> void:
    crew_size_option.value_changed.connect(_on_crew_size_changed)
    crew_name_input.text_changed.connect(_on_crew_name_changed)
    create_button.pressed.connect(_on_create_pressed)
    
    # Connect character generation button if available
    if generate_button:
        generate_button.pressed.connect(_on_generate_character)
    
    # Connect character list selection
    if character_list and character_list.has_signal("item_selected"):
        character_list.item_selected.connect(_on_character_list_selected)

func _setup_options() -> void:
    crew_size_option.setup(4, "Select the size of your starting crew")
    create_button.disabled = true
    
    # Enable character generation if components are available
    if generate_button:
        generate_button.text = "Generate Character"
        generate_button.disabled = false
    
    # Setup character list
    if character_list:
        character_list.clear()
    
    _update_ui_state()

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
    var valid = not crew_data.name.strip_edges().is_empty() and generated_characters.size() == crew_data.size
    create_button.disabled = not valid
    return valid

func _on_generate_character() -> void:
    """Generate a new Five Parsecs character using the sophisticated generation system"""
    if generated_characters.size() >= crew_data.size:
        push_warning("InitialCrewCreation: Crew already at maximum size")
        return
    
    # Use FiveParsecsCharacterGeneration for official rules compliance
    var character = FiveParsecsCharacterGeneration.generate_random_character()
    
    if character:
        generated_characters.append(character)
        
        # Add to UI list
        var character_name = "%s (%s)" % [
            character.character_name if character.has_method("get") or character.character_name else "Unknown",
            _get_class_name(character.character_class) if character.has_method("get") or character.character_class else "Unknown Class"
        ]
        
        if character_list:
            character_list.add_item(character_name)
            # Auto-select the new character
            character_list.select(character_list.get_item_count() - 1)
            _display_character_details(character)
        
        # Convert to dictionary format for crew_data
        var character_dict = _character_to_dict(character)
        crew_data.characters.append(character_dict)
        
        _update_ui_state()
        
        # Emit signal using Universal Safety System
        UniversalSignalManager.emit_signal_safe(
            self, 
            "character_generated", 
            [character], 
            "InitialCrewCreation character generation"
        )
        
        print("InitialCrewCreation: Generated character: ", character_name)
    else:
        push_error("InitialCrewCreation: Failed to generate character")

func _character_to_dict(character: CoreCharacter) -> Dictionary:
    """Convert Character object to dictionary format"""
    return {
        "name": character.character_name if character.has_method("get") or character.character_name else "Unknown",
        "class": character.character_class if character.has_method("get") or character.character_class else 0,
        "background": character.background if character.has_method("get") or character.background else 0,
        "origin": character.origin if character.has_method("get") or character.origin else 0,
        "reaction": character.reaction if character.has_method("get") or character.reaction else 1,
        "speed": character.speed if character.has_method("get") or character.speed else 4,
        "combat": character.combat if character.has_method("get") or character.combat else 0,
        "toughness": character.toughness if character.has_method("get") or character.toughness else 3,
        "savvy": character.savvy if character.has_method("get") or character.savvy else 0,
        "character_object": character
    }

func _get_class_name(class_id: int) -> String:
    """Get class name for display"""
    var GlobalEnums = UniversalResourceLoader.load_script_safe(
        "res://src/core/systems/GlobalEnums.gd", 
        "InitialCrewCreation class name lookup"
    )
    
    if GlobalEnums and GlobalEnums.CharacterClass and GlobalEnums.CharacterClass.size() > class_id:
        return GlobalEnums.CharacterClass.keys()[class_id]
    return "Unknown"

func _display_character_details(character: CoreCharacter) -> void:
    """Display character details in the UI"""
    if not character_details:
        return
    
    var details = "[b]%s[/b]\n\n" % (character.character_name if character.character_name else "Unknown")
    details += "Class: %s\n" % _get_class_name(character.character_class if character.character_class else 0)
    details += "\n[b]Attributes:[/b]\n"
    details += "Reactions: %d\n" % (character.reaction if character.reaction else 1)
    details += "Speed: %d\"\n" % (character.speed if character.speed else 4)
    details += "Combat Skill: +%d\n" % (character.combat if character.combat else 0)
    details += "Toughness: %d\n" % (character.toughness if character.toughness else 3)
    details += "Savvy: +%d\n" % (character.savvy if character.savvy else 0)
    
    character_details.text = details

func _on_character_list_selected(index: int) -> void:
    """Handle character selection in list"""
    if index >= 0 and index < generated_characters.size():
        _display_character_details(generated_characters[index])

func _update_ui_state() -> void:
    """Update UI state based on current crew data"""
    # Update generate button
    if generate_button:
        generate_button.disabled = generated_characters.size() >= crew_data.size
        if generated_characters.size() >= crew_data.size:
            generate_button.text = "Crew Complete"
        else:
            generate_button.text = "Generate Character (%d/%d)" % [generated_characters.size(), crew_data.size]
    
    # Update create button
    _validate_crew()

func _on_create_pressed() -> void:
    if _validate_crew():
        # Ensure we have the complete crew data with generated characters
        var final_crew_data = crew_data.duplicate()
        final_crew_data["generated_characters"] = generated_characters
        
        UniversalSignalManager.emit_signal_safe(
            self,
            "crew_created",
            [final_crew_data],
            "InitialCrewCreation crew completion"
        )
        
        print("InitialCrewCreation: Crew created with %d characters" % generated_characters.size())