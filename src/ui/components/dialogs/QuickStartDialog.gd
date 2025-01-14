class_name QuickStartDialog
extends Control

signal import_requested(data: Dictionary)
signal template_selected(template: String)

@onready var import_button := $VBoxContainer/ImportButton
@onready var template_list := $VBoxContainer/TemplateList
@onready var gesture_manager: GestureManager

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var templates := {
    "Solo Campaign": {
        "crew_size": GameEnums.CrewSize.FOUR,
        "difficulty": GameEnums.DifficultyLevel.NORMAL,
        "victory_condition": GameEnums.CampaignVictoryType.TURNS_20,
        "mobile_friendly": true
    },
    "Standard Campaign": {
        "crew_size": GameEnums.CrewSize.FIVE,
        "difficulty": GameEnums.DifficultyLevel.NORMAL,
        "victory_condition": GameEnums.CampaignVictoryType.TURNS_50,
        "mobile_friendly": true
    },
    "Challenge Campaign": {
        "crew_size": GameEnums.CrewSize.SIX,
        "difficulty": GameEnums.DifficultyLevel.HARDCORE,
        "victory_condition": GameEnums.CampaignVictoryType.QUESTS_10,
        "mobile_friendly": false
    }
}

func _ready() -> void:
    _setup_gesture_support()
    _setup_mobile_ui()
    import_button.pressed.connect(_on_import_pressed)
    _populate_templates()

func _setup_gesture_support() -> void:
    gesture_manager = GestureManager.new()
    add_child(gesture_manager)
    gesture_manager.swipe_detected.connect(_on_swipe)
    gesture_manager.long_press_detected.connect(_on_long_press)

func _setup_mobile_ui() -> void:
    if OS.has_feature("mobile"):
        var viewport_size = get_viewport().get_visible_rect().size
        custom_minimum_size = Vector2(0, viewport_size.y * 0.8)
        position = Vector2(0, viewport_size.y * 0.2)
        
        template_list.add_theme_constant_override("v_separation", 20)
        template_list.add_theme_constant_override("h_separation", 20)

func _populate_templates() -> void:
    template_list.clear()
    for template_name in templates:
        if not OS.has_feature("mobile") or templates[template_name]["mobile_friendly"]:
            template_list.add_item(template_name)

func _on_swipe(direction: Vector2) -> void:
    if direction.y > 0.8: # Swipe down
        hide()
    elif direction.x != 0: # Horizontal swipe
        var current_index = template_list.get_selected_items()[0] if template_list.get_selected_items().size() > 0 else -1
        current_index += 1 if direction.x > 0 else -1
        current_index = clamp(current_index, 0, template_list.item_count - 1)
        template_list.select(current_index)
        _on_template_selected(current_index)

func _on_long_press(position: Vector2) -> void:
    var item_at_pos = template_list.get_item_at_position(position)
    if item_at_pos >= 0:
        var template_name = template_list.get_item_text(item_at_pos)
        _show_template_details(template_name)

func _on_import_pressed() -> void:
    var file_dialog = FileDialog.new()
    file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    file_dialog.add_filter("*.json", "Campaign Data")
    file_dialog.file_selected.connect(_on_file_selected)
    add_child(file_dialog)
    file_dialog.popup_centered()

func _on_file_selected(path: String) -> void:
    var file = FileAccess.open(path, FileAccess.READ)
    var json = JSON.new()
    var parse_result = json.parse(file.get_as_text())
    if parse_result == OK:
        import_requested.emit(json.data)
    else:
        push_error("Failed to parse import file")

func _on_template_selected(index: int) -> void:
    var template_name = template_list.get_item_text(index)
    template_selected.emit(template_name)

func _show_template_details(template_name: String) -> void:
    if template_name in templates:
        var details = templates[template_name]
        # Show details implementation
        pass