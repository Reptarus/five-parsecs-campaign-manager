extends CampaignResponsiveLayout

# Add deferred loading variables
var _ui_components: Dictionary = {}
var _is_initialized: bool = false

@onready var title_label := $TitleLabel
@onready var info_container := $HBoxContainer
@onready var mission_info := $HBoxContainer/MissionInfoPanel
@onready var enemy_info := $HBoxContainer/EnemyInfoPanel
@onready var battlefield_preview := $HBoxContainer/BattlefieldPreview
@onready var bottom_panel := $BottomPanel

const TOUCH_BUTTON_HEIGHT := 60
const PORTRAIT_INFO_HEIGHT_RATIO := 0.4  # Info panels take 40% in portrait mode

func _ready() -> void:
	super._ready()
	initialize()

func initialize() -> void:
	if _is_initialized:
		return
		
	_ui_components = {
		"mission_info": preload("res://Resources/BattlePhase/Scenes/MissionInfoPanel.tscn"),
		"enemy_info": preload("res://Resources/BattlePhase/Scenes/EnemyInfoPanel.tscn"),
		"battlefield_preview": preload("res://Resources/BattlePhase/Scenes/BattlefieldPreview.tscn")
	}
	
	_setup_pre_battle()
	_is_initialized = true

func cleanup() -> void:
	if _is_initialized:
		_ui_components.clear()
		_is_initialized = false

func _setup_pre_battle() -> void:
	_setup_info_panels()
	_setup_preview()
	_setup_crew_panel()

func _apply_portrait_layout() -> void:
	super._apply_portrait_layout()
	
	# Stack panels vertically using BaseContainer enum
	info_container.set("orientation", BaseContainer.Orientation.VERTICAL)
	
	# Adjust panel sizes for portrait mode
	var viewport_height = get_viewport_rect().size.y
	mission_info.custom_minimum_size.y = viewport_height * PORTRAIT_INFO_HEIGHT_RATIO * 0.5
	enemy_info.custom_minimum_size.y = viewport_height * PORTRAIT_INFO_HEIGHT_RATIO * 0.5
	battlefield_preview.custom_minimum_size.y = viewport_height * (1 - PORTRAIT_INFO_HEIGHT_RATIO)
	
	# Make controls touch-friendly
	_adjust_touch_sizes(true)
	
	# Adjust margins for mobile
	$MarginContainer.add_theme_constant_override("margin_left", 10)
	$MarginContainer.add_theme_constant_override("margin_right", 10)

func _apply_landscape_layout() -> void:
	super._apply_landscape_layout()
	
	# Side by side layout using BaseContainer enum
	info_container.set("orientation", BaseContainer.Orientation.HORIZONTAL)
	
	# Reset panel sizes
	mission_info.custom_minimum_size = Vector2(300, 0)
	enemy_info.custom_minimum_size = Vector2(300, 0)
	battlefield_preview.custom_minimum_size = Vector2(600, 0)
	
	# Reset control sizes
	_adjust_touch_sizes(false)
	
	# Reset margins
	$MarginContainer.add_theme_constant_override("margin_left", 20)
	$MarginContainer.add_theme_constant_override("margin_right", 20)

func _adjust_touch_sizes(is_portrait: bool) -> void:
	var button_height = TOUCH_BUTTON_HEIGHT if is_portrait else TOUCH_BUTTON_HEIGHT * 0.75
	
	# Adjust all buttons
	for button in get_tree().get_nodes_in_group("touch_buttons"):
		button.custom_minimum_size.y = button_height
	
	# Adjust character boxes in bottom panel
	for box in get_tree().get_nodes_in_group("character_boxes"):
		box.custom_minimum_size.y = button_height * 1.5

func _setup_info_panels() -> void:
	# Add touch group to interactive elements
	for panel in [mission_info, enemy_info]:
		for child in panel.get_children():
			if child is Button:
				child.add_to_group("touch_buttons")

func _setup_preview() -> void:
	# Setup battlefield preview
	pass

func _setup_crew_panel() -> void:
	# Add character boxes to touch group
	for box in bottom_panel.get_node("VBoxContainer").get_children():
		box.add_to_group("character_boxes")

func _connect_signals() -> void:
	# Connect your existing signals here
	pass
