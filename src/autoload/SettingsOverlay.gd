extends CanvasLayer

## Persistent Settings Gear Button — always-available overlay
## Sits at CanvasLayer 99 (below TransitionManager at 100)
## Hidden on MainMenu (which has its own Options button)
## Navigates to SettingsScreen via SceneRouter on press

const COLOR_GEAR_BG := Color("#252542")
const COLOR_GEAR_BG_HOVER := Color("#3A3A5C")
const COLOR_GEAR_TEXT := Color("#E0E0E0")
const GEAR_SIZE := 48  # ISSUE-037: meet TOUCH_TARGET_MIN
const GEAR_MARGIN := 12

var _gear_button: Button
var _hidden_scenes: Array[String] = ["MainMenu", "SettingsScreen"]


func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS

	_gear_button = Button.new()
	_gear_button.text = "\u2699"  # Unicode gear symbol ⚙
	_gear_button.custom_minimum_size = Vector2(GEAR_SIZE, GEAR_SIZE)
	_gear_button.size = Vector2(GEAR_SIZE, GEAR_SIZE)
	_gear_button.add_theme_font_size_override("font_size", 22)
	_gear_button.add_theme_color_override("font_color", COLOR_GEAR_TEXT)
	_gear_button.accessibility_name = "Open Settings"
	_gear_button.tooltip_text = "Settings"
	_gear_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_gear_button.focus_mode = Control.FOCUS_NONE

	# Style
	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_GEAR_BG
	normal.set_corner_radius_all(GEAR_SIZE / 2)
	normal.set_content_margin_all(4)
	_gear_button.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = COLOR_GEAR_BG_HOVER
	hover.set_corner_radius_all(GEAR_SIZE / 2)
	hover.set_content_margin_all(4)
	_gear_button.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = COLOR_GEAR_BG_HOVER
	pressed.set_corner_radius_all(GEAR_SIZE / 2)
	pressed.set_content_margin_all(4)
	_gear_button.add_theme_stylebox_override("pressed", pressed)

	_gear_button.pressed.connect(_on_gear_pressed)
	add_child(_gear_button)

	# Position in top-right — CanvasLayer children need manual positioning
	get_tree().root.size_changed.connect(_reposition)
	call_deferred("_reposition")

	# Listen for scene changes to hide on MainMenu/SettingsScreen
	var router = get_node_or_null("/root/SceneRouter")
	if router and router.has_signal("scene_changed"):
		router.scene_changed.connect(_on_scene_changed)

	# Also check on tree changes
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)

	# Initial visibility check (MainMenu may already be loaded before this autoload)
	call_deferred("_update_visibility")


func _reposition() -> void:
	if not _gear_button:
		return
	var vp_size: Vector2 = get_tree().root.get_visible_rect().size
	_gear_button.position = Vector2(
		vp_size.x - GEAR_SIZE - GEAR_MARGIN,
		GEAR_MARGIN
	)


func _on_gear_pressed() -> void:
	var router = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("settings")


func _on_scene_changed(_new_scene: String, _previous_scene: String) -> void:
	_update_visibility()


func _on_node_added(_node: Node) -> void:
	if not is_inside_tree():
		return
	if _node.is_inside_tree() and _node.get_parent() == get_tree().root:
		call_deferred("_update_visibility")


func _on_node_removed(_node: Node) -> void:
	if not is_inside_tree():
		return
	call_deferred("_update_visibility")


func _update_visibility() -> void:
	if not _gear_button or not is_inside_tree():
		return
	var root := get_tree().root
	if not root:
		return
	var should_hide := false
	for child in root.get_children():
		if child.name in _hidden_scenes:
			should_hide = true
			break
	_gear_button.visible = not should_hide
