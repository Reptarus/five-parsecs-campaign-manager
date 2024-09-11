extends Control

@onready var resolution_option: OptionButton = $ResolutionOption
@onready var fullscreen_toggle: CheckButton = $FullscreenToggle
@onready var vsync_toggle: CheckButton = $VSyncToggle
@onready var quality_option: OptionButton = $QualityOption

var resolutions = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
var quality_levels = ["Low", "Medium", "High"]

func _ready():
    setup_resolution_options()
    setup_quality_options()
    load_current_settings()

func setup_resolution_options():
    for res in resolutions:
        resolution_option.add_item(str(res.x) + "x" + str(res.y))

func setup_quality_options():
    for quality in quality_levels:
        quality_option.add_item(quality)

func load_current_settings():
    var config = ConfigFile.new()
    config.load("user://video_settings.cfg")
    
    var current_resolution = config.get_value("video", "resolution", Vector2i(1920, 1080))
    resolution_option.select(resolutions.find(current_resolution))
    
    fullscreen_toggle.button_pressed = config.get_value("video", "fullscreen", false)
    vsync_toggle.button_pressed = config.get_value("video", "vsync", true)
    quality_option.select(config.get_value("video", "quality", 1))  # Default to Medium

func _on_resolution_option_item_selected(index):
    DisplayServer.window_set_size(resolutions[index])

func _on_fullscreen_toggle_toggled(button_pressed):
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if button_pressed else DisplayServer.WINDOW_MODE_WINDOWED)

func _on_vsync_toggle_toggled(button_pressed):
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if button_pressed else DisplayServer.VSYNC_DISABLED)

func _on_quality_option_item_selected(index):
    match index:
        0:  # Low
            get_viewport().msaa_3d = Viewport.MSAA_DISABLED
            get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
        1:  # Medium
            get_viewport().msaa_3d = Viewport.MSAA_2X
            get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
        2:  # High
            get_viewport().msaa_3d = Viewport.MSAA_4X
            get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
    # Add more quality settings as needed

func _on_apply_button_pressed():
    var config = ConfigFile.new()
    config.set_value("video", "resolution", resolutions[resolution_option.selected])
    config.set_value("video", "fullscreen", fullscreen_toggle.button_pressed)
    config.set_value("video", "vsync", vsync_toggle.button_pressed)
    config.set_value("video", "quality", quality_option.selected)
    config.save("user://video_settings.cfg")

func _on_back_button_pressed():
    # Return to previous menu
    get_tree().change_scene_to_file("res://assets/scenes/menus/main_menu.tscn")
