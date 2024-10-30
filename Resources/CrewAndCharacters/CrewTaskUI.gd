class_name CrewTaskUI
extends VBoxContainer

signal task_completed(character: Character, result: Dictionary)

@onready var crew_list: ItemList = $CrewList
@onready var task_option: OptionButton = $TaskAssignment
@onready var resolve_button: Button = $ResolveTask
@onready var result_label: Label = $ResultLabel
@onready var skill_info_label: Label = $SkillInfoLabel
@onready var task_description_label: Label = $TaskDescriptionLabel

var task_manager: CrewTaskManager
var selected_character: Character
var current_task_difficulty: int = 0

func _ready() -> void:
    resolve_button.pressed.connect(_on_resolve_pressed)
    crew_list.item_selected.connect(_on_crew_selected)
    task_option.item_selected.connect(_on_task_selected)
    
    _populate_task_options()

func initialize(crew: Array, manager: CrewTaskManager) -> void:
    task_manager = manager
    _populate_crew_list(crew)

func _populate_crew_list(crew: Array) -> void:
    crew_list.clear()
    for character in crew:
        var display_text = "%s (%s)" % [character.name, character.background]
        crew_list.add_item(display_text)
        if character.is_busy or character.recover_time > 0:
            var idx = crew_list.get_item_count() - 1
            crew_list.set_item_disabled(idx, true)

func _on_crew_selected(index: int) -> void:
    selected_character = game_state.current_crew.members[index]
    _update_skill_info()
    _update_ui()

func _update_skill_info() -> void:
    if !selected_character:
        return
        
    var task = task_option.selected
    var relevant_skill = task_manager.get_relevant_skill(selected_character, task)
    var difficulty = task_manager.get_task_difficulty(task)
    current_task_difficulty = difficulty
    
    skill_info_label.text = """
    Relevant Skill: %s (%d)
    Task Difficulty: %d
    Success Chance: %d%%
    """ % [
        task_manager.get_skill_name(task),
        relevant_skill,
        difficulty,
        _calculate_success_chance(relevant_skill, difficulty)
    ]

func _calculate_success_chance(skill: int, difficulty: int) -> int:
    # Based on Core Rules dice mechanics
    var success_threshold = difficulty
    var dice_sides = 6
    var success_range = dice_sides - success_threshold + 1
    return (success_range * 100) / dice_sides

func _on_task_selected(index: int) -> void:
    if selected_character:
        task_description_label.text = task_manager.get_task_description(index)
        _update_skill_info()
    _update_ui()

func _show_result(result: Dictionary) -> void:
    var outcome_text = "[b]Task Result:[/b]\n"
    outcome_text += _format_outcome(result)
    result_label.text = outcome_text

func _format_outcome(result: Dictionary) -> String:
    var text = ""
    match result["outcome"]:
        TaskResult.CRITICAL_SUCCESS:
            text += "[color=green]Exceptional Success! (Natural 6)[/color]\n"
        TaskResult.SUCCESS:
            text += "[color=blue]Success![/color]\n"
        TaskResult.PARTIAL_SUCCESS:
            text += "[color=yellow]Partial Success[/color]\n"
        TaskResult.FAILURE:
            text += "[color=red]Failure[/color]\n"
        TaskResult.CRITICAL_FAILURE:
            text += "[color=dark_red]Critical Failure! (Natural 1)[/color]\n"
    
    text += "\n[b]Rewards:[/b]\n"
    for reward in result["rewards"]:
        var value = result["rewards"][reward]
        match reward:
            "credits":
                text += "- Credits: %d\n" % value
            "experience":
                text += "- Experience: %d\n" % value
            "item":
                text += "- Found: %s\n" % value
            "story_points":
                text += "- Story Points: %d\n" % value
            "morale_loss":
                text += "- [color=red]Morale decreased[/color]\n"
            _:
                text += "- %s: %s\n" % [reward, value]
    
    return text

func _update_ui() -> void:
    resolve_button.disabled = !selected_character or selected_character.is_busy
