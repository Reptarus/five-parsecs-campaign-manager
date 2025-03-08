extends Control

const GameManager = preload("res://src/core/managers/GameStateManager.gd")

@onready var difficulty_option: OptionButton = $DifficultyOption
@onready var tutorial_toggle: CheckButton = $TutorialToggle
@onready var auto_save_toggle: CheckButton = $AutoSaveToggle
@onready var language_option: OptionButton = $LanguageOption

var difficulty_levels = ["Easy", "Normal", "Hard", "Nightmare"]
var languages = ["English", "Spanish", "French", "German", "Japanese"]

var game_manager: GameManager

func _ready():
    game_manager = get_node_or_null("/root/GameManager")
    if not game_manager:
        push_error("GameManager not found")
        return
        
    setup_difficulty_options()
    setup_language_options()
    load_current_settings()

func setup_difficulty_options():
    for difficulty in difficulty_levels:
        difficulty_option.add_item(difficulty)

func setup_language_options():
    for language in languages:
        language_option.add_item(language)

func load_current_settings():
    var settings = game_manager.settings
    
    difficulty_option.select(settings.difficulty)
    tutorial_toggle.button_pressed = not settings.disable_tutorial_popup
    auto_save_toggle.button_pressed = settings.auto_save
    language_option.select(settings.language)

func _on_difficulty_option_item_selected(index):
    game_manager.settings.difficulty = index
    print("Difficulty changed to: ", difficulty_levels[index])

func _on_tutorial_toggle_toggled(button_pressed):
    game_manager.settings.disable_tutorial_popup = not button_pressed
    print("Tutorial toggled: ", "On" if button_pressed else "Off")

func _on_auto_save_toggle_toggled(button_pressed):
    game_manager.settings.auto_save = button_pressed
    print("Auto-save toggled: ", "On" if button_pressed else "Off")

func _on_language_option_item_selected(index):
    game_manager.settings.language = index
    var language = languages[index]
    print("Language changed to: ", language)
    # Implement language change logic here
    # For example:
    # TranslationServer.set_locale(language)
    # get_tree().call_group("translatable", "update_language")

func _on_apply_button_pressed():
    game_manager.save_settings()
    print("Settings saved")

func _on_back_button_pressed():
    get_tree().change_scene_to_file("res://src/ui/screens/mainmenu/MainMenu.tscn")
