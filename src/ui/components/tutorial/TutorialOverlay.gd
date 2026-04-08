# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends CanvasLayer


signal tutorial_completed
signal tutorial_skipped

const DIMMED_COLOR := Color(0, 0, 0, 0.6)
const HIGHLIGHT_BORDER_COLOR := Color("#4FC3F7")
const ANIMATION_TIME := 0.3

# Layer 95: between Notifications (90) and Loading (99)
const TUTORIAL_LAYER := 95

var _dimmed_rect: ColorRect
var _highlight_border: ReferenceRect
var _tooltip_panel: PanelContainer
var _tooltip_label: Label
var _step_label: Label
var _next_button: Button
var _skip_button: Button

var current_step := 0
var tutorial_steps: Array
var current_tween: Tween

func _ready() -> void:
	layer = TUTORIAL_LAYER
	_setup_overlay()
	set_process_input(true)

func _setup_overlay() -> void:
	# Full-screen dim background (blocks clicks on dimmed areas)
	_dimmed_rect = ColorRect.new()
	_dimmed_rect.color = DIMMED_COLOR
	_dimmed_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dimmed_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dimmed_rect)

	# Highlight border around target element
	_highlight_border = ReferenceRect.new()
	_highlight_border.border_color = HIGHLIGHT_BORDER_COLOR
	_highlight_border.border_width = 3.0
	_highlight_border.editor_only = false
	_highlight_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_highlight_border)

	# Tooltip panel with Deep Space styling
	_tooltip_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#1A1A2E")
	panel_style.border_color = Color("#4FC3F7")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	_tooltip_panel.add_theme_stylebox_override("panel", panel_style)
	_tooltip_panel.custom_minimum_size = Vector2(300, 0)
	add_child(_tooltip_panel)

	# Layout inside tooltip
	var tooltip_vbox := VBoxContainer.new()
	tooltip_vbox.add_theme_constant_override("separation", 8)
	_tooltip_panel.add_child(tooltip_vbox)

	_tooltip_label = Label.new()
	_tooltip_label.add_theme_color_override("font_color", Color("#E0E0E0"))
	_tooltip_label.add_theme_font_size_override("font_size", 14)
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_vbox.add_child(_tooltip_label)

	# Step indicator + buttons row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	tooltip_vbox.add_child(btn_row)

	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", 11)
	_step_label.add_theme_color_override("font_color", Color("#808080"))
	_step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(_step_label)

	_skip_button = Button.new()
	_skip_button.text = "Skip"
	_skip_button.flat = true
	_skip_button.custom_minimum_size = Vector2(60, 36)
	_skip_button.add_theme_font_size_override("font_size", 13)
	_skip_button.add_theme_color_override("font_color", Color("#808080"))
	_skip_button.pressed.connect(_on_skip_pressed)
	btn_row.add_child(_skip_button)

	_next_button = Button.new()
	_next_button.text = "Next"
	_next_button.custom_minimum_size = Vector2(80, 36)
	_next_button.add_theme_font_size_override("font_size", 13)
	var next_style := StyleBoxFlat.new()
	next_style.bg_color = Color("#2D5A7B")
	next_style.set_corner_radius_all(4)
	_next_button.add_theme_stylebox_override("normal", next_style)
	_next_button.add_theme_color_override("font_color", Color("#E0E0E0"))
	_next_button.pressed.connect(_on_next_pressed)
	btn_row.add_child(_next_button)

	# Initially hidden
	hide_overlay()

func start_tutorial(steps: Array) -> void:
	tutorial_steps = steps
	current_step = 0
	show_current_step()

func show_current_step() -> void:
	if current_step >= tutorial_steps.size():
		complete_tutorial()
		return

	var step: Dictionary = tutorial_steps[current_step]
	var target_path: String = step.get("target_path", "")
	var target: Control = null

	if not target_path.is_empty():
		# Try to find target relative to the main scene
		var root := get_tree().current_scene
		if root:
			target = root.get_node_or_null(target_path)

	if target and target is Control:
		# Ensure visible in scroll containers
		var scroll := _find_parent_scroll(target)
		if scroll:
			scroll.ensure_control_visible(target)
		var target_rect := target.get_global_rect()
		_animate_highlight(target_rect)
		_position_tooltip(target_rect, step.get("tooltip_position", "bottom"))
	else:
		# No target — center the tooltip
		_highlight_border.visible = false
		_center_tooltip()

	_tooltip_label.text = step.get("text", "")
	_step_label.text = "%d / %d" % [current_step + 1, tutorial_steps.size()]
	_next_button.text = "Done" if current_step == tutorial_steps.size() - 1 else "Next"
	_tooltip_panel.visible = true
	_dimmed_rect.visible = true

func _find_parent_scroll(node: Node) -> ScrollContainer:
	var parent := node.get_parent()
	while parent:
		if parent is ScrollContainer:
			return parent
		parent = parent.get_parent()
	return null

func _animate_highlight(target_rect: Rect2) -> void:
	if current_tween:
		current_tween.kill()

	_highlight_border.visible = true
	current_tween = create_tween()
	current_tween.tween_property(
		_highlight_border, "position", target_rect.position - Vector2(4, 4), ANIMATION_TIME
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	current_tween.parallel().tween_property(
		_highlight_border, "size", target_rect.size + Vector2(8, 8), ANIMATION_TIME
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _position_tooltip(target_rect: Rect2, position_hint: String = "bottom") -> void:
	# Wait for tooltip to size itself
	await get_tree().process_frame
	var tooltip_size := _tooltip_panel.size
	var viewport_size := get_viewport().get_visible_rect().size
	var pos := Vector2.ZERO
	var gap := 12.0

	match position_hint:
		"top":
			pos = Vector2(target_rect.position.x, target_rect.position.y - tooltip_size.y - gap)
		"bottom":
			pos = Vector2(target_rect.position.x, target_rect.end.y + gap)
		"left":
			pos = Vector2(target_rect.position.x - tooltip_size.x - gap, target_rect.position.y)
		"right":
			pos = Vector2(target_rect.end.x + gap, target_rect.position.y)
		_:
			pos = Vector2(target_rect.position.x, target_rect.end.y + gap)

	# Keep within viewport
	pos.x = clampf(pos.x, 8.0, viewport_size.x - tooltip_size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, viewport_size.y - tooltip_size.y - 8.0)
	_tooltip_panel.position = pos

func _center_tooltip() -> void:
	await get_tree().process_frame
	var viewport_size := get_viewport().get_visible_rect().size
	var tooltip_size := _tooltip_panel.size
	_tooltip_panel.position = (viewport_size - tooltip_size) / 2.0

func _on_next_pressed() -> void:
	current_step += 1
	show_current_step()

func _on_skip_pressed() -> void:
	hide_overlay()
	tutorial_skipped.emit()

func complete_tutorial() -> void:
	hide_overlay()
	tutorial_completed.emit()

func hide_overlay() -> void:
	_highlight_border.visible = false
	_dimmed_rect.visible = false
	_tooltip_panel.visible = false
