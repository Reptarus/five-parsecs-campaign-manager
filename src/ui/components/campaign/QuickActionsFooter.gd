extends PanelContainer
class_name QuickActionsFooter

## Quick Actions Footer Component
## 6-icon grid for primary campaign actions (Save, Characters, Ship, Trading, World, Settings)
## Part of Campaign Dashboard UI modernization (Phase 4)
## Responsive: Grid on mobile, horizontal bar on desktop

# Design constants from BaseCampaignPanel
const SPACING_SM := 8
const SPACING_MD := 16
const FONT_SIZE_XS := 11
const FONT_SIZE_SM := 14
const TOUCH_TARGET_COMFORT := 56
const BREAKPOINT_TABLET := 768

# Color palette - Deep Space Theme
const COLOR_PRIMARY := Color("#0a0d14")
const COLOR_SECONDARY := Color("#111827")
const COLOR_BORDER := Color("#374151")
const COLOR_CYAN := Color("#06b6d4")        # Save
const COLOR_BLUE := Color("#3b82f6")        # Characters
const COLOR_PURPLE := Color("#8b5cf6")      # Ship
const COLOR_AMBER := Color("#f59e0b")       # Trading
const COLOR_EMERALD := Color("#10b981")     # World
const COLOR_TEXT_SECONDARY := Color("#9ca3af")  # Settings
const COLOR_TEXT_PRIMARY := Color("#f3f4f6")

# Signals for each action
signal save_pressed()
signal characters_pressed()
signal ship_pressed()
signal trading_pressed()
signal world_pressed()
signal settings_pressed()

# UI References
var actions_container: Container  # GridContainer or HBoxContainer based on layout
var action_buttons: Array[Control] = []

# Layout state
var is_mobile_layout: bool = true

# Action definitions
const ACTIONS := [
	{"name": "Save", "icon": "💾", "color": COLOR_CYAN, "signal_name": "save_pressed"},
	{"name": "Characters", "icon": "👥", "color": COLOR_BLUE, "signal_name": "characters_pressed"},
	{"name": "Ship", "icon": "🚀", "color": COLOR_PURPLE, "signal_name": "ship_pressed"},
	{"name": "Trading", "icon": "💰", "color": COLOR_AMBER, "signal_name": "trading_pressed"},
	{"name": "World", "icon": "🌍", "color": COLOR_EMERALD, "signal_name": "world_pressed"},
	{"name": "Settings", "icon": "⚙️", "color": COLOR_TEXT_SECONDARY, "signal_name": "settings_pressed"}
]


func _ready() -> void:
	_setup_responsive_layout()
	_apply_footer_style()

	# Connect viewport resize for responsive updates
	get_viewport().size_changed.connect(_on_viewport_resized)


func _setup_responsive_layout() -> void:
	"""Initialize layout based on current viewport size"""
	var viewport_width := get_viewport().get_visible_rect().size.x
	is_mobile_layout = viewport_width < BREAKPOINT_TABLET

	_create_actions_container()


func _create_actions_container() -> void:
	"""Create the appropriate container based on layout mode"""
	# Clear existing container
	if actions_container:
		actions_container.queue_free()
		actions_container = null

	action_buttons.clear()

	if is_mobile_layout:
		# Mobile: 3-column grid (2 rows × 3 columns)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", SPACING_SM)
		grid.add_theme_constant_override("v_separation", SPACING_SM)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions_container = grid
	else:
		# Desktop: Horizontal bar centered
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", SPACING_MD)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions_container = hbox

	add_child(actions_container)

	# Create action buttons
	for action in ACTIONS:
		var button := _create_action_button(action)
		actions_container.add_child(button)
		action_buttons.append(button)


func _create_action_button(action: Dictionary) -> Control:
	"""Create a single action button with icon and label"""
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	container.custom_minimum_size = Vector2(72, 72)  # Touch-friendly size

	# Rounded corners using PanelContainer for better styling
	var icon_panel := PanelContainer.new()
	icon_panel.name = "IconPanel"
	icon_panel.custom_minimum_size = Vector2(48, 48)
	icon_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_panel.mouse_filter = Control.MOUSE_FILTER_PASS  # Pass clicks to parent

	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = action["color"]
	icon_style.set_corner_radius_all(12)
	icon_panel.add_theme_stylebox_override("panel", icon_style)

	# Icon label
	var icon_label := Label.new()
	icon_label.text = action["icon"]
	icon_label.add_theme_font_size_override("font_size", 24)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_label.mouse_filter = Control.MOUSE_FILTER_PASS  # Pass clicks to parent
	icon_panel.add_child(icon_label)

	container.add_child(icon_panel)

	# Action name label
	var name_label := Label.new()
	name_label.text = action["name"]
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS  # Pass clicks to parent
	container.add_child(name_label)

	# Make clickable with hover feedback
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.gui_input.connect(_on_action_input.bind(action["signal_name"]))
	container.mouse_entered.connect(_on_action_hover_enter.bind(container, action["color"]))
	container.mouse_exited.connect(_on_action_hover_exit.bind(container, action["color"]))

	return container


func _apply_footer_style() -> void:
	"""Apply subtle glass styling to footer"""
	var style := StyleBoxFlat.new()

	# Very subtle background (more transparent than cards)
	style.bg_color = Color(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, 0.6)

	# Minimal border
	style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.3)
	style.set_border_width_all(1)

	# Subtle rounded corners
	style.set_corner_radius_all(12)

	# Comfortable padding
	style.set_content_margin_all(SPACING_MD)

	add_theme_stylebox_override("panel", style)


func _on_action_input(event: InputEvent, signal_name: String) -> void:
	"""Handle action button clicks"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Find the container that was clicked for visual feedback
			_play_click_animation(signal_name)
			
			# Emit the corresponding signal
			match signal_name:
				"save_pressed":
					save_pressed.emit()
					print("QuickActionsFooter: Save pressed")
				"characters_pressed":
					characters_pressed.emit()
					print("QuickActionsFooter: Characters pressed")
				"ship_pressed":
					ship_pressed.emit()
					print("QuickActionsFooter: Ship pressed")
				"trading_pressed":
					trading_pressed.emit()
					print("QuickActionsFooter: Trading pressed")
				"world_pressed":
					world_pressed.emit()
					print("QuickActionsFooter: World pressed")
				"settings_pressed":
					settings_pressed.emit()
					print("QuickActionsFooter: Settings pressed")

func _play_click_animation(signal_name: String) -> void:
	"""Play a quick press animation on the button"""
	# Find which button was pressed
	for i in range(ACTIONS.size()):
		if ACTIONS[i]["signal_name"] == signal_name:
			if i < action_buttons.size():
				var container := action_buttons[i]
				var icon_panel := container.get_node_or_null("IconPanel") as PanelContainer
				if icon_panel:
					# Quick scale down then up animation
					var tween := create_tween()
					tween.tween_property(icon_panel, "scale", Vector2(0.9, 0.9), 0.05)
					tween.tween_property(icon_panel, "scale", Vector2(1.15, 1.15), 0.1)
			break

func _on_action_hover_enter(container: Control, base_color: Color) -> void:
	"""Handle mouse hover enter - scale up and brighten"""
	var icon_panel := container.get_node_or_null("IconPanel") as PanelContainer
	if icon_panel:
		# Scale up animation
		var tween := create_tween()
		tween.tween_property(icon_panel, "scale", Vector2(1.15, 1.15), 0.1).set_ease(Tween.EASE_OUT)
		
		# Brighten the icon background
		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = base_color.lightened(0.2)
		hover_style.set_corner_radius_all(12)
		icon_panel.add_theme_stylebox_override("panel", hover_style)
		
		# Center the pivot for scaling
		icon_panel.pivot_offset = icon_panel.size / 2

func _on_action_hover_exit(container: Control, base_color: Color) -> void:
	"""Handle mouse hover exit - restore original state"""
	var icon_panel := container.get_node_or_null("IconPanel") as PanelContainer
	if icon_panel:
		# Scale back animation
		var tween := create_tween()
		tween.tween_property(icon_panel, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
		
		# Restore original color
		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = base_color
		normal_style.set_corner_radius_all(12)
		icon_panel.add_theme_stylebox_override("panel", normal_style)


func _on_viewport_resized() -> void:
	"""Handle viewport resize to update layout responsively"""
	var viewport_width := get_viewport().get_visible_rect().size.x
	var new_mobile_state := viewport_width < BREAKPOINT_TABLET

	# Only recreate if layout mode changed
	if new_mobile_state != is_mobile_layout:
		is_mobile_layout = new_mobile_state
		_create_actions_container()
		print("QuickActionsFooter: Layout changed to %s" % ("mobile" if is_mobile_layout else "desktop"))


## Public API for enabling/disabling actions

func enable_action(action_name: String) -> void:
	"""Enable a specific action button"""
	_set_action_state(action_name, true)


func disable_action(action_name: String) -> void:
	"""Disable a specific action button"""
	_set_action_state(action_name, false)


func _set_action_state(action_name: String, enabled: bool) -> void:
	"""Internal method to enable/disable action buttons"""
	for i in range(ACTIONS.size()):
		if ACTIONS[i]["name"] == action_name:
			if i < action_buttons.size():
				action_buttons[i].modulate = Color.WHITE if enabled else Color(0.5, 0.5, 0.5, 0.5)
				action_buttons[i].mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
			break


func set_badge_count(action_name: String, count: int) -> void:
	"""Set a notification badge on an action button (future enhancement)"""
	# Future: Add small notification badge to action buttons
	# For now, just log
	print("QuickActionsFooter: Badge count %d for %s" % [count, action_name])
