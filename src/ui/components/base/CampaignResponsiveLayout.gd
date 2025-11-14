class_name FPCM_CampaignResponsiveLayout
extends Control

const VERTICAL = 1
const HORIZONTAL = 0
const PORTRAIT_SIDEBAR_HEIGHT_RATIO := 0.4 # Sidebar takes 40% in portrait mode
const LANDSCAPE_SIDEBAR_WIDTH := 300.0 # Fixed sidebar width in landscape mode
const TOUCH_BUTTON_HEIGHT := 60.0 # Height for touch-friendly buttons

var main_container: Container = null
@onready var sidebar := _get_or_create_sidebar()
@onready var main_content := _get_or_create_main_content()

func _ready() -> void:
	# Create main container if not exists
	if not main_container:
		main_container = HBoxContainer.new()
		main_container.name = "MainContainer"
		add_child(main_container)

	_setup_touch_controls()
	_connect_signals()
	_check_orientation()

func _check_orientation() -> void:
	"""Check and apply appropriate layout based on viewport orientation"""
	var viewport_size = get_viewport_rect().size
	if viewport_size.x < viewport_size.y:
		_apply_portrait_layout()
	else:
		_apply_landscape_layout()

func _setup_touch_controls() -> void:
	if OS.has_feature("mobile"):
		for button in get_tree().get_nodes_in_group("touch_buttons"):
			button.custom_minimum_size.y = TOUCH_BUTTON_HEIGHT

		for list in get_tree().get_nodes_in_group("touch_lists"):
			list.fixed_item_height = TOUCH_BUTTON_HEIGHT

func _connect_signals() -> void:
	if sidebar and sidebar.has_signal("back_pressed"):
		sidebar.back_pressed.connect(_on_back_pressed)

func initialize(parent_control: Control) -> void:
	# Connect to the parent _control and set up responsive behavior
	var parent_size = parent_control.size
	size = parent_size

	# Connect to parent resizing
	parent_control.resized.connect(func():
		size = parent_control.size
	)

	# Add this layout to the parent
	if not is_inside_tree():
		parent_control.add_child(self)

	# Force layout update
	_check_orientation()

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
	var button_height: float = TOUCH_BUTTON_HEIGHT if is_portrait else TOUCH_BUTTON_HEIGHT * 0.75

	# Adjust all buttons
	for button in get_tree().get_nodes_in_group("touch_buttons"):
		button.custom_minimum_size.y = button_height

	# Adjust list items
	for list in get_tree().get_nodes_in_group("touch_lists"):
		list.fixed_item_height = button_height

func _get_or_create_sidebar() -> Control:
	if has_node("MainContainer/Sidebar"):
		return $MainContainer/Sidebar
	
	var sidebar_node = VBoxContainer.new()
	sidebar_node.name = "Sidebar"
	if main_container:
		main_container.add_child(sidebar_node)
	return sidebar_node

func _get_or_create_main_content() -> Control:
	if has_node("MainContainer/MainContent"):
		return $MainContainer/MainContent
	
	var content_node = VBoxContainer.new()
	content_node.name = "MainContent"
	if main_container:
		main_container.add_child(content_node)
	return content_node

func _on_back_pressed() -> void:
	# Override in child classes
	pass