extends Node

# References to the WorldGenerator and UI elements
@onready var world_generator: Node = $"../WorldGenerator"
@onready var display_container: VBoxContainer = $"../GeneratedWorldDisplay/Panel/VBoxContainer"

# UI elements
var world_info_label: Label
var location_list: ItemList
var generate_button: Button
var explore_button: Button

# Current world data
var current_world: Dictionary = {}
var selected_location_index: int = -1

func _ready() -> void:
    # Create UI elements
    _create_ui_elements()
    
    # Connect signals
    world_generator.connect("world_generated", _on_world_generated)
    world_generator.connect("location_discovered", _on_location_discovered)
    
    generate_button.connect("pressed", _on_generate_pressed)
    explore_button.connect("pressed", _on_explore_pressed)
    location_list.connect("item_selected", _on_location_selected)
    
    # Disable exploration initially
    explore_button.disabled = true

func _create_ui_elements() -> void:
    # Create header
    var header = Label.new()
    header.text = "Five Parsecs World Generator Example"
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_theme_font_size_override("font_size", 20)
    display_container.add_child(header)
    
    # Create world info section
    world_info_label = Label.new()
    world_info_label.text = "No world generated yet"
    world_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    display_container.add_child(world_info_label)
    
    # Create location list
    var location_section = Label.new()
    location_section.text = "Locations:"
    display_container.add_child(location_section)
    
    location_list = ItemList.new()
    location_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    location_list.custom_minimum_size = Vector2(0, 200)
    display_container.add_child(location_list)
    
    # Create buttons
    var button_container = HBoxContainer.new()
    display_container.add_child(button_container)
    
    generate_button = Button.new()
    generate_button.text = "Generate New World"
    generate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button_container.add_child(generate_button)
    
    explore_button = Button.new()
    explore_button.text = "Explore Selected Location"
    explore_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    explore_button.disabled = true
    button_container.add_child(explore_button)

func _on_generate_pressed() -> void:
    # Generate a new world with the current campaign turn (example: turn 3)
    current_world = world_generator.generate_world(3)
    
    # Update the UI with the new world data
    _update_world_info()
    _update_location_list()
    
    # Reset selection
    selected_location_index = -1
    explore_button.disabled = true

func _on_world_generated(world_data: Dictionary) -> void:
    # This is called automatically when a world is generated
    print("World generated: " + world_data.name)

func _on_location_selected(index: int) -> void:
    selected_location_index = index
    explore_button.disabled = false

func _on_explore_pressed() -> void:
    if selected_location_index >= 0 and selected_location_index < current_world.locations.size():
        var location = world_generator.discover_location(current_world, selected_location_index)
        
        # Update the UI to show the explored location
        _update_location_list()
        
        # Show exploration results
        var dialog = AcceptDialog.new()
        dialog.title = "Location Explored"
        dialog.dialog_text = "You explored: " + location.name + "\n\n" + _get_location_details(location)
        add_child(dialog)
        dialog.popup_centered(Vector2(400, 300))

func _on_location_discovered(location_data: Dictionary) -> void:
    # This is called automatically when a location is discovered
    print("Location discovered: " + location_data.name)
    
    # Could add custom logic here like faction encounters, etc.

func _update_world_info() -> void:
    if current_world.is_empty():
        world_info_label.text = "No world generated yet"
        return
    
    var info_text = "World: " + current_world.name + " (" + current_world.type_name + ")\n"
    info_text += "Danger Level: " + str(current_world.danger_level) + "\n"
    
    # Add traits information
    info_text += "\nTraits:\n"
    if current_world.traits.is_empty():
        info_text += "None\n"
    else:
        for trait_id in current_world.traits:
            info_text += "- " + trait_id + "\n"
    
    # Add special features
    info_text += "\nSpecial Features:\n"
    if current_world.special_features.is_empty():
        info_text += "None\n"
    else:
        for feature in current_world.special_features:
            info_text += "- " + feature + "\n"
    
    world_info_label.text = info_text

func _update_location_list() -> void:
    location_list.clear()
    
    if current_world.is_empty() or not current_world.has("locations"):
        return
    
    for i in range(current_world.locations.size()):
        var location = current_world.locations[i]
        var name = location.name
        
        # Mark explored locations
        if location.explored:
            name += " (Explored)"
        
        location_list.add_item(name)
        
        # Add danger indicator
        var danger_mod = location.danger_mod
        var indicator = ""
        
        if danger_mod > 0:
            indicator = " ⚠️ " * danger_mod
        elif danger_mod < 0:
            indicator = " 🛡️ " * abs(danger_mod)
            
        location_list.set_item_tooltip(i, location.description + indicator)

func _get_location_details(location: Dictionary) -> String:
    var details = "Description: " + location.description + "\n"
    details += "Resources: " + str(location.resources) + "\n"
    
    if location.has("special_features") and not location.special_features.is_empty():
        details += "\nSpecial Features:\n"
        for feature in location.special_features:
            details += "- " + feature + "\n"
    
    return details