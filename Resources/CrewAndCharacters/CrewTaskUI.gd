class_name CrewTaskUI
extends CampaignResponsiveLayout

signal task_completed(character: Character, task: String, result: Dictionary)

const TOUCH_BUTTON_HEIGHT := 60
const PORTRAIT_LIST_HEIGHT_RATIO := 0.4  # Crew list takes 40% in portrait mode

# Fix onready vars to use proper paths
@onready var crew_list := $PanelContainer/MarginContainer/VBoxContainer/HSplitContainer/LeftPanel/CrewList as ItemList
@onready var task_assignment := $PanelContainer/MarginContainer/VBoxContainer/HSplitContainer/RightPanel/TaskAssignment as OptionButton
@onready var task_description := $PanelContainer/MarginContainer/VBoxContainer/HSplitContainer/RightPanel/TaskDescriptionLabel as Label
@onready var skill_info := $PanelContainer/MarginContainer/VBoxContainer/HSplitContainer/RightPanel/SkillInfoLabel as Label
@onready var result_label := $PanelContainer/MarginContainer/VBoxContainer/HSplitContainer/RightPanel/ResultLabel as Label

# Fix constructor issue by removing _init
var task_manager: CrewTaskManager
var selected_character: Character
var selected_task: String

func _ready() -> void:
    super._ready()
    var game_state_manager = get_node("/root/GameStateManager")
    if game_state_manager:
        task_manager = CrewTaskManager.new(game_state_manager)
    else:
        push_error("GameStateManager not found")
    _setup_crew_tasks()
    _connect_signals()

func _setup_crew_tasks() -> void:
    _setup_crew_list()
    _setup_task_options()
    _setup_buttons()

func _apply_portrait_layout() -> void:
    super._apply_portrait_layout()
    
    # Stack panels vertically
    main_container.set("vertical", true)
    
    # Adjust panel sizes for portrait mode
    var viewport_height = get_viewport_rect().size.y
    left_panel.custom_minimum_size.y = viewport_height * PORTRAIT_LIST_HEIGHT_RATIO
    right_panel.custom_minimum_size.y = viewport_height * (1 - PORTRAIT_LIST_HEIGHT_RATIO)
    
    # Make controls touch-friendly
    _adjust_touch_sizes(true)
    
    # Adjust margins for mobile
    $PanelContainer/MarginContainer.add_theme_constant_override("margin_left", 10)
    $PanelContainer/MarginContainer.add_theme_constant_override("margin_right", 10)

func _apply_landscape_layout() -> void:
    super._apply_landscape_layout()
    
    # Side by side layout
    main_container.set("vertical", false)
    
    # Reset panel sizes
    left_panel.custom_minimum_size = Vector2(300, 0)
    right_panel.custom_minimum_size = Vector2(500, 0)
    
    # Reset control sizes
    _adjust_touch_sizes(false)
    
    # Reset margins
    $PanelContainer/MarginContainer.add_theme_constant_override("margin_left", 20)
    $PanelContainer/MarginContainer.add_theme_constant_override("margin_right", 20)

func _adjust_touch_sizes(is_portrait: bool) -> void:
    var button_height = TOUCH_BUTTON_HEIGHT if is_portrait else TOUCH_BUTTON_HEIGHT * 0.75
    
    # Adjust all buttons
    for button in get_tree().get_nodes_in_group("touch_buttons"):
        button.custom_minimum_size.y = button_height
    
    # Adjust task assignment dropdown
    if task_assignment:
        task_assignment.custom_minimum_size.y = button_height
    
    # Adjust list items
    if crew_list:
        crew_list.fixed_item_height = button_height

func _setup_crew_list() -> void:
    if crew_list:
        crew_list.add_to_group("touch_lists")

func _setup_task_options() -> void:
    if task_assignment:
        task_assignment.add_to_group("touch_controls")
        _populate_task_options()

func _setup_buttons() -> void:
    var resolve_button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/ResolveTask
    var back_button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/BackButton
    
    for button in [resolve_button, back_button]:
        if button:
            button.add_to_group("touch_buttons")
            button.custom_minimum_size = Vector2(200, TOUCH_BUTTON_HEIGHT)

func _populate_task_options() -> void:
    if task_assignment:
        task_assignment.clear()
        for task in GlobalEnums.CrewTask.values():
            task_assignment.add_item(GlobalEnums.CrewTask.keys()[task])

func _connect_signals() -> void:
    if crew_list:
        crew_list.item_selected.connect(_on_crew_selected)
    if task_assignment:
        task_assignment.item_selected.connect(_on_task_selected)

func _on_crew_selected(index: int) -> void:
    selected_character = task_manager.get_crew_member(index)
    _update_skill_info()

func _on_task_selected(index: int) -> void:
    selected_task = GlobalEnums.CrewTask.keys()[index]
    _update_task_description()

func _update_skill_info() -> void:
    if skill_info and selected_character:
        skill_info.text = "Character Skills: %s" % selected_character.get_skills_text()

func _update_task_description() -> void:
    if task_description and selected_task:
        var task_type = GlobalEnums.CrewTask[selected_task]
        task_description.text = task_manager.get_task_description(task_type)
