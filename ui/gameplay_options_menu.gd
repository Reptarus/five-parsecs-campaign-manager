extends Control

@onready var difficulty_option: OptionButton = $DifficultyOption
@onready var tutorial_toggle: CheckButton = $TutorialToggle
@onready var auto_save_toggle: CheckButton = $AutoSaveToggle
@onready var language_option: OptionButton = $LanguageOption

var difficulty_levels = ["Easy", "Normal", "Hard", "Nightmare"]
var languages = ["English", "Spanish", "French", "German", "Japanese"]

func _ready():
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
    var config = ConfigFile.new()
    config.load("user://gameplay_settings.cfg")
    
    difficulty_option.select(config.get_value("gameplay", "difficulty", 1))  # Default to Normal
    tutorial_toggle.button_pressed = config.get_value("gameplay", "tutorial", true)
    auto_save_toggle.button_pressed = config.get_value("gameplay", "auto_save", true)
    language_option.select(config.get_value("gameplay", "language", 0))  # Default to English

func _on_difficulty_option_item_selected(index):
    var difficulty = difficulty_levels[index]
    print("Difficulty changed to: ", difficulty)
    # You might want to emit a signal or call a method to update the game's difficulty
    # For example:
    # emit_signal("difficulty_changed", difficulty)
    # or
    # GameManager.set_difficulty(difficulty)

func _on_tutorial_toggle_toggled(button_pressed):
    print("Tutorial toggled: ", "On" if button_pressed else "Off")
    # You might want to update a global setting or emit a signal
    # For example:
    # GameManager.set_tutorial_enabled(button_pressed)
    # or
    # emit_signal("tutorial_toggled", button_pressed)

func _on_auto_save_toggle_toggled(button_pressed):
    print("Auto-save toggled: ", "On" if button_pressed else "Off")
    # Update the auto-save setting in your game
    # For example:
    # GameManager.set_auto_save_enabled(button_pressed)
    # or
    # emit_signal("auto_save_toggled", button_pressed)

func _on_language_option_item_selected(index):
    var language = languages[index]
    print("Language changed to: ", language)
    # Implement language change logic here
    # You might need to reload text resources or emit a signal to update the UI language
    # For example:
    # TranslationServer.set_locale(language)
    # emit_signal("language_changed", language)
    # get_tree().call_group("translatable", "update_language")

func _on_apply_button_pressed():
    var config = ConfigFile.new()
    config.set_value("gameplay", "difficulty", difficulty_option.selected)
    config.set_value("gameplay", "tutorial", tutorial_toggle.button_pressed)
    config.set_value("gameplay", "auto_save", auto_save_toggle.button_pressed)
    config.set_value("gameplay", "language", language_option.selected)
    config.save("user://gameplay_settings.cfg")

func _on_back_button_pressed():
    get_node("/root/Main").goto_scene("res://assets/scenes/menus/options_menu/master_options_menu.tscn")
