class_name CampaignResponsiveLayout
extends ResponsiveContainer

# Common margins and spacing for campaign screens
const PORTRAIT_PANEL_RATIO := 0.4  # Left panel takes 40% in portrait mode
const LANDSCAPE_PANEL_RATIO := 0.35  # Left panel takes 35% in landscape mode
const MIN_PANEL_WIDTH := 300.0
const HEADER_HEIGHT := 80.0
const FOOTER_HEIGHT := 60.0

# Common UI elements that most campaign screens will have
@onready var header_container: Control = $HeaderContainer
@onready var main_container: Control = $MainContainer
@onready var footer_container: Control = $FooterContainer
@onready var left_panel: Control = $MainContainer/LeftPanel
@onready var right_panel: Control = $MainContainer/RightPanel

func _ready() -> void:
    super._ready()
    _setup_base_layout()

func _setup_base_layout() -> void:
    # Set up the basic layout structure
    custom_minimum_size = Vector2(MIN_PANEL_WIDTH * 2, 400)
    
    # Configure containers
    header_container.custom_minimum_size.y = HEADER_HEIGHT
    footer_container.custom_minimum_size.y = FOOTER_HEIGHT

func _apply_portrait_layout() -> void:
    # Stack panels vertically in portrait mode
    main_container.set("theme_override_constants/separation", 10)
    
    # Adjust panel sizes
    left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    
    # Set custom minimum sizes
    left_panel.custom_minimum_size = Vector2(0, get_viewport_rect().size.y * PORTRAIT_PANEL_RATIO)
    right_panel.custom_minimum_size = Vector2(0, 0)

func _apply_landscape_layout() -> void:
    # Place panels side by side in landscape mode
    main_container.set("theme_override_constants/separation", 20)
    
    # Adjust panel sizes
    left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    
    # Set custom minimum sizes
    left_panel.custom_minimum_size = Vector2(MIN_PANEL_WIDTH, 0)
    right_panel.custom_minimum_size = Vector2(MIN_PANEL_WIDTH, 0)
    
    # Set stretch ratios
    left_panel.size_flags_stretch_ratio = LANDSCAPE_PANEL_RATIO
    right_panel.size_flags_stretch_ratio = 1.0 - LANDSCAPE_PANEL_RATIO

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        _handle_resize()

func _handle_resize() -> void:
    var size = get_viewport_rect().size
    if size.x < min_width:
        _apply_portrait_layout()
    else:
        _apply_landscape_layout() 