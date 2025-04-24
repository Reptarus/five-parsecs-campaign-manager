# Logbook.gd
extends "res://src/ui/components/base/CampaignResponsiveLayout.gd"

@onready var crew_select := $MarginContainer/HBoxContainer/Sidebar/CrewSelect
@onready var entry_list := $MarginContainer/HBoxContainer/Sidebar/EntryList
@onready var entry_content := $MarginContainer/HBoxContainer/MainContent/EntryContent
@onready var notes_edit := $MarginContainer/HBoxContainer/MainContent/NotesEdit

const PORTRAIT_LIST_HEIGHT_RATIO := 0.4 # Crew list takes 40% in portrait mode
const LogbookClass := "res://src/ui/components/logbook/logbook.gd" # Class reference as string path

# Use parent's ThisClass for parent class references, use LogbookClass for self-references

func _ready() -> void:
    super._ready()
    _setup_logbook()
    _connect_signals()

func _setup_logbook() -> void:
    _setup_crew_selector()
    _setup_buttons()
    entry_list.add_to_group("touch_lists")

func _apply_portrait_layout() -> void:
    super._apply_portrait_layout()
    
    # Stack panels vertically
    main_container.set("vertical", true)
    
    # Adjust panel sizes for portrait mode
    var viewport_height = get_viewport_rect().size.y
    sidebar.custom_minimum_size.y = viewport_height * PORTRAIT_LIST_HEIGHT_RATIO
    
    # Make controls touch-friendly
    _adjust_touch_sizes(true)

func _apply_landscape_layout() -> void:
    super._apply_landscape_layout()
    
    # Side by side layout
    main_container.set("vertical", false)
    
    # Reset panel sizes
    sidebar.custom_minimum_size = Vector2(300, 0)
    
    # Reset control sizes
    _adjust_touch_sizes(false)

func _adjust_touch_sizes(is_portrait: bool) -> void:
    var button_height = TOUCH_BUTTON_HEIGHT if is_portrait else TOUCH_BUTTON_HEIGHT * 0.75
    
    # Adjust all buttons
    for button in get_tree().get_nodes_in_group("touch_buttons"):
        button.custom_minimum_size.y = button_height
    
    # Adjust crew selector
    crew_select.custom_minimum_size.y = button_height
    
    # Adjust list items
    entry_list.fixed_item_height = button_height

func _setup_crew_selector() -> void:
    crew_select.add_to_group("touch_controls")
    # Add crew members to selector
    pass

func _setup_buttons() -> void:
    var new_entry_button = $MarginContainer/HBoxContainer/Sidebar/ButtonsContainer/NewEntryButton
    var delete_entry_button = $MarginContainer/HBoxContainer/Sidebar/ButtonsContainer/DeleteEntryButton
    var export_button = $MarginContainer/HBoxContainer/Sidebar/ExportButton
    var back_button = $MarginContainer/HBoxContainer/Sidebar/BackButton
    var save_button = $MarginContainer/HBoxContainer/MainContent/SaveButton
    
    for button in [new_entry_button, delete_entry_button, export_button, back_button, save_button]:
        button.add_to_group("touch_buttons")
        button.custom_minimum_size.x = 150

func _connect_signals() -> void:
    # Connect existing signals
    pass