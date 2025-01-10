class_name CampaignResponsiveLayout
extends ResponsiveContainer

const VERTICAL = 1
const HORIZONTAL = 0
const PORTRAIT_SIDEBAR_HEIGHT_RATIO := 0.4 # Sidebar takes 40% in portrait mode
const LANDSCAPE_SIDEBAR_WIDTH := 300.0 # Fixed sidebar width in landscape mode
const TOUCH_BUTTON_HEIGHT := 60.0 # Height for touch-friendly buttons

@onready var sidebar := $MainContainer/Sidebar if has_node("MainContainer/Sidebar") else null
@onready var main_content := $MainContainer/MainContent if has_node("MainContainer/MainContent") else null

func _ready() -> void:
    super._ready()
    _setup_touch_controls()
    _connect_signals()

func _setup_touch_controls() -> void:
    if OS.has_feature("mobile"):
        for button in get_tree().get_nodes_in_group("touch_buttons"):
            button.custom_minimum_size.y = TOUCH_BUTTON_HEIGHT
        
        for list in get_tree().get_nodes_in_group("touch_lists"):
            list.fixed_item_height = TOUCH_BUTTON_HEIGHT

func _connect_signals() -> void:
    if sidebar and sidebar.has_signal("back_pressed"):
        sidebar.back_pressed.connect(_on_back_pressed)

func _apply_portrait_layout() -> void:
    if not main_container or not sidebar or not main_content:
        return
    
    # Stack panels vertically
    main_container.set("orientation", VERTICAL)
    
    # Adjust panel sizes for portrait mode
    var viewport_height = get_viewport_rect().size.y
    sidebar.custom_minimum_size.y = viewport_height * PORTRAIT_SIDEBAR_HEIGHT_RATIO
    sidebar.custom_minimum_size.x = 0
    
    # Make controls touch-friendly
    _adjust_touch_sizes(true)

func _apply_landscape_layout() -> void:
    if not main_container or not sidebar or not main_content:
        return
    
    # Side by side layout
    main_container.set("orientation", HORIZONTAL)
    
    # Reset panel sizes
    sidebar.custom_minimum_size = Vector2(LANDSCAPE_SIDEBAR_WIDTH, 0)
    
    # Reset control sizes
    _adjust_touch_sizes(false)

func _adjust_touch_sizes(is_portrait: bool) -> void:
    var button_height = TOUCH_BUTTON_HEIGHT if is_portrait else TOUCH_BUTTON_HEIGHT * 0.75
    
    # Adjust all buttons
    for button in get_tree().get_nodes_in_group("touch_buttons"):
        button.custom_minimum_size.y = button_height
    
    # Adjust list items
    for list in get_tree().get_nodes_in_group("touch_lists"):
        list.fixed_item_height = button_height

func _on_back_pressed() -> void:
    # Override in child classes
    pass