class_name CrewManagementUI
extends CampaignResponsiveLayout

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

signal task_completed(character: Character, task: GlobalEnums.CrewTask, result: Dictionary)

const TOUCH_BUTTON_HEIGHT := 60
const PORTRAIT_LIST_HEIGHT_RATIO := 0.4

@onready var crew_list := $PanelContainer/MarginContainer/VBoxContainer/HSplitContainer/LeftPanel/CrewList as ItemList
@onready var task_assignment := $PanelContainer/MarginContainer/VBoxContainer/HSplitContainer/RightPanel/TaskAssignment as OptionButton
@onready var task_description := $PanelContainer/MarginContainer/VBoxContainer/HSplitContainer/RightPanel/TaskDescriptionLabel as Label
@onready var skill_info := $PanelContainer/MarginContainer/VBoxContainer/HSplitContainer/RightPanel/SkillInfoLabel as Label
@onready var result_label := $PanelContainer/MarginContainer/VBoxContainer/HSplitContainer/RightPanel/ResultLabel as Label

var crew_manager: CrewSystem
var selected_character: Character
var selected_task: GlobalEnums.CrewTask
var game_state: GameState

func _ready() -> void:
    super._ready()
    game_state = get_node("/root/GameStateManager").get_game_state()
    if not game_state:
        push_error("Failed to get GameState")
        return
    crew_manager = CrewSystem.new(game_state)
    _setup_ui()
    _connect_signals()

func _setup_ui() -> void:
    _setup_crew_list()
    _setup_task_options()
    _setup_buttons()
    _apply_current_layout()

func _setup_crew_list() -> void:
    _update_crew_list()

func _setup_task_options() -> void:
    task_assignment.clear()
    for task in GlobalEnums.CrewTask.keys():
        task_assignment.add_item(task.capitalize())

func _setup_buttons() -> void:
    var assign_button = $PanelContainer/MarginContainer/VBoxContainer/HSplitContainer/RightPanel/AssignButton as Button
    var complete_button = $PanelContainer/MarginContainer/VBoxContainer/HSplitContainer/RightPanel/CompleteButton as Button

    assign_button.pressed.connect(_on_assign_button_pressed)
    complete_button.pressed.connect(_on_complete_button_pressed)

func _apply_current_layout() -> void:
    var screen_size = get_viewport().size
    var portrait_list_height = screen_size.y * PORTRAIT_LIST_HEIGHT_RATIO
    crew_list.rect_min_size = Vector2(0, portrait_list_height)
    task_assignment.rect_min_size = Vector2(0, TOUCH_BUTTON_HEIGHT)
    task_description.rect_min_size = Vector2(0, TOUCH_BUTTON_HEIGHT)
    skill_info.rect_min_size = Vector2(0, TOUCH_BUTTON_HEIGHT)
    result_label.rect_min_size = Vector2(0, TOUCH_BUTTON_HEIGHT)

func _connect_signals() -> void:
    crew_list.item_selected.connect(_on_crew_selected)
    task_assignment.item_selected.connect(_on_task_selected)
    crew_manager.task_completed.connect(_on_task_completed)
    crew_manager.crew_updated.connect(_on_crew_updated)

func _on_crew_selected(index: int) -> void:
    selected_character = crew_manager.members[index] if index >= 0 else null
    _update_character_display()

func _on_task_selected(index: int) -> void:
    if index >= 0:
        var task_name = GlobalEnums.CrewTask.keys()[index]
        selected_task = GlobalEnums.CrewTask[task_name]
        task_description.text = crew_manager.get_task_description(selected_task)

func _on_task_completed(character: Character, task: GlobalEnums.CrewTask) -> void:
    var result = _generate_task_result(character, task)
    task_completed.emit(character, task, result)
    _update_character_display()

func _on_crew_updated() -> void:
    _update_crew_list()

func _update_crew_list() -> void:
    crew_list.clear()
    for member in crew_manager.members:
        crew_list.add_item(member.name)

func _update_character_display() -> void:
    if not selected_character:
        return
    
    skill_info.text = "Skills:\n" + selected_character.get_skills_text()
    var current_task = crew_manager.active_tasks.get(selected_character, null)
    if current_task != null:
        var task_index = GlobalEnums.CrewTask.values().find(current_task)
        if task_index != -1:
            task_assignment.select(task_index)
            task_assignment.disabled = true
    else:
        task_assignment.disabled = false

func _generate_task_result(character: Character, task: GlobalEnums.CrewTask) -> Dictionary:
    var success = randf() < character.get_task_success_chance(task)
    var rewards = {}
    var consequences = {}

    if success:
        rewards = character.get_task_rewards(task)
    else:
        consequences = character.get_task_consequences(task)

    return {
        "success": success,
        "rewards": rewards,
        "consequences": consequences
    }

# Missing function declarations
func _on_assign_button_pressed() -> void:
    if selected_character and selected_task != null:
        if crew_manager.assign_task(selected_character, selected_task):
            _update_character_display()

func _on_complete_button_pressed() -> void:
    if selected_character:
        crew_manager.complete_task(selected_character)
        _update_character_display()