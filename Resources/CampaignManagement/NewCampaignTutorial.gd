extends CampaignResponsiveLayout

signal tutorial_step_completed(step: String)

@onready var content_container := $MainContainer/ContentContainer
@onready var navigation_container := $MainContainer/NavigationContainer

var current_step := 0
var tutorial_steps := []

func _ready() -> void:
    super._ready()
    _setup_tutorial()
    _load_tutorial_steps()

func _setup_tutorial() -> void:
    _setup_content_panel()
    _setup_navigation_panel()

func _setup_content_panel() -> void:
    var scroll = ScrollContainer.new()
    var content = RichTextLabel.new()
    content.bbcode_enabled = true
    content.name = "ContentLabel"
    scroll.add_child(content)
    content_container.add_child(scroll)

func _setup_navigation_panel() -> void:
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 20)
    
    var next_button = Button.new()
    next_button.text = "Next"
    next_button.custom_minimum_size.y = 60
    next_button.add_to_group("touch_controls")
    next_button.pressed.connect(_on_next_pressed)
    
    var skip_button = Button.new()
    skip_button.text = "Skip Tutorial"
    skip_button.custom_minimum_size.y = 60
    skip_button.add_to_group("touch_controls")
    skip_button.pressed.connect(_on_skip_pressed)
    
    vbox.add_child(next_button)
    vbox.add_child(skip_button)
    navigation_container.add_child(vbox)

func _apply_portrait_layout() -> void:
    super._apply_portrait_layout()
    
    get_main_container().set("vertical", true)
    
    content_container.custom_minimum_size.y = get_viewport_rect().size.y * 0.7
    navigation_container.custom_minimum_size.y = get_viewport_rect().size.y * 0.3
    
    _adjust_touch_sizes(true)

func _apply_landscape_layout() -> void:
    super._apply_landscape_layout()
    
    get_main_container().set("vertical", false)
    
    content_container.custom_minimum_size = Vector2(600, 0)
    navigation_container.custom_minimum_size = Vector2(200, 0)
    
    _adjust_touch_sizes(false)

func _adjust_touch_sizes(is_portrait: bool) -> void:
    var base_size = 60 if is_portrait else 40
    for control in get_tree().get_nodes_in_group("touch_controls"):
        control.custom_minimum_size.y = base_size

func _on_next_pressed() -> void:
    current_step += 1
    if current_step < tutorial_steps.size():
        _show_current_step()
    else:
        tutorial_step_completed.emit("completed")

func _on_skip_pressed() -> void:
    tutorial_step_completed.emit("skipped")

func _show_current_step() -> void:
    var content = content_container.get_node("ContentLabel")
    content.text = tutorial_steps[current_step]

func _load_tutorial_steps() -> void:
    tutorial_steps = [
        "Welcome to Five Parsecs From Home!",
        "Let's start by creating your crew...",
        "Now let's learn about basic combat...",
        # Add more steps as needed
    ]

func get_main_container() -> Container:
    return main_container