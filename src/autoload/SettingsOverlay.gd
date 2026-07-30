extends CanvasLayer

## Persistent Settings Gear Button — always-available overlay
## Sits at CanvasLayer 99 (below TransitionManager at 100)
## Hidden on MainMenu (which has its own Options button)
##
## IMPORTANT: Opens settings as an inline overlay (not a scene transition)
## so that battle/campaign state is never destroyed. The SettingsScreen is
## lazy-instantiated as a child of this CanvasLayer and the game tree is
## paused while settings are visible.

const SettingsScreenScript = preload("res://src/ui/screens/settings/SettingsScreen.gd")
const BugReportDialogScript = preload("res://src/ui/components/common/BugReportDialog.gd")

const COLOR_GEAR_BG := Color("#252542")
const COLOR_GEAR_BG_HOVER := Color("#3A3A5C")
const COLOR_GEAR_TEXT := Color("#E0E0E0")
const COLOR_DIMMER := Color(0.0, 0.0, 0.0, 0.6)
const GEAR_SIZE := 48  # ISSUE-037: meet TOUCH_TARGET_MIN
const GEAR_MARGIN := 12

var _gear_button: Button
var _bug_button: Button
var _bug_dialog: Window
var _dimmer: ColorRect
var _settings_panel: SettingsScreen
var _hidden_scenes: Array[String] = ["MainMenu", "SettingsScreen"]
## The bug reporter stays available on MainMenu — a tester can hit a bug there
## too — so it deliberately does NOT reuse _hidden_scenes.
var _bug_hidden_scenes: Array[String] = ["SettingsScreen"]


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

	_bug_button = _make_round_button("⚠", "Report a Bug")  # ⚠
	_bug_button.pressed.connect(_on_bug_pressed)
	add_child(_bug_button)

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


## Builds a round chrome button matching the settings gear.
func _make_round_button(glyph: String, label: String) -> Button:
	var b := Button.new()
	b.text = glyph
	b.custom_minimum_size = Vector2(GEAR_SIZE, GEAR_SIZE)
	b.size = Vector2(GEAR_SIZE, GEAR_SIZE)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", COLOR_GEAR_TEXT)
	b.accessibility_name = label
	b.tooltip_text = label
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.focus_mode = Control.FOCUS_NONE

	for state in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = COLOR_GEAR_BG if state == "normal" else COLOR_GEAR_BG_HOVER
		s.set_corner_radius_all(GEAR_SIZE / 2)
		s.set_content_margin_all(4)
		b.add_theme_stylebox_override(state, s)
	return b


func _reposition() -> void:
	if not _gear_button:
		return
	var vp_size: Vector2 = get_tree().root.get_visible_rect().size
	_gear_button.position = Vector2(
		vp_size.x - GEAR_SIZE - GEAR_MARGIN,
		GEAR_MARGIN
	)
	if _bug_button:
		# One slot to the left of the gear.
		_bug_button.position = Vector2(
			vp_size.x - (GEAR_SIZE * 2) - (GEAR_MARGIN * 2),
			GEAR_MARGIN
		)
	# Keep dimmer and settings panel filling the viewport
	if _dimmer:
		_dimmer.position = Vector2.ZERO
		_dimmer.size = vp_size
	if _settings_panel:
		_settings_panel.position = Vector2.ZERO
		_settings_panel.size = vp_size


func _on_gear_pressed() -> void:
	# Guard: already showing
	if _settings_panel and _settings_panel.visible:
		return
	_show_settings_overlay()


func _on_bug_pressed() -> void:
	# Guard: already open
	if is_instance_valid(_bug_dialog):
		return
	_bug_dialog = BugReportDialogScript.show_report(self)


## Opens the bug reporter from anywhere. Public so SettingsScreen (and any
## future caller) reaches the same single instance guard.
func open_bug_report() -> void:
	_on_bug_pressed()


func _show_settings_overlay() -> void:
	# Lazy-create the dimmer and settings panel on first use
	if not _dimmer:
		_dimmer = ColorRect.new()
		_dimmer.color = COLOR_DIMMER
		_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks through
		_dimmer.visible = false
		add_child(_dimmer)

	if not _settings_panel:
		_settings_panel = SettingsScreenScript.new()
		_settings_panel.overlay_mode = true
		_settings_panel.visible = false
		_settings_panel.back_requested.connect(_hide_settings_overlay)
		add_child(_settings_panel)

	# Size to viewport
	var vp_size: Vector2 = get_tree().root.get_visible_rect().size
	_dimmer.position = Vector2.ZERO
	_dimmer.size = vp_size
	_settings_panel.position = Vector2.ZERO
	_settings_panel.size = vp_size

	# Show overlay and pause the game
	_dimmer.visible = true
	_settings_panel.visible = true
	_gear_button.visible = false
	# The bug button must hide too. In overlay mode SettingsScreen is a child of
	# this autoload rather than a root scene, so the _bug_hidden_scenes name
	# check cannot see it — hide it explicitly here. _hide_settings_overlay()
	# calls _update_visibility(), which restores it.
	if _bug_button:
		_bug_button.visible = false
	get_tree().paused = true


func _hide_settings_overlay() -> void:
	if _dimmer:
		_dimmer.visible = false
	if _settings_panel:
		_settings_panel.visible = false

	get_tree().paused = false
	_update_visibility()  # Restores gear button if appropriate


func _unhandled_input(event: InputEvent) -> void:
	if _settings_panel and _settings_panel.visible and event.is_action_pressed("ui_cancel"):
		_hide_settings_overlay()
		get_viewport().set_input_as_handled()


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
	# Hide chrome when the settings overlay is showing
	if _settings_panel and _settings_panel.visible:
		_gear_button.visible = false
		if _bug_button:
			_bug_button.visible = false
		return

	var live_scene_names: Array[String] = []
	for child in root.get_children():
		live_scene_names.append(child.name)

	var hide_gear := false
	for n in _hidden_scenes:
		if n in live_scene_names:
			hide_gear = true
			break
	_gear_button.visible = not hide_gear

	if _bug_button:
		var hide_bug := false
		for n in _bug_hidden_scenes:
			if n in live_scene_names:
				hide_bug = true
				break
		_bug_button.visible = not hide_bug


## Screen area this overlay currently occupies, in design-space coordinates, as
## the union of its VISIBLE buttons (empty Rect2 when nothing is showing).
##
## This overlay floats above every screen, so top-anchored content that ignores it
## gets drawn under the gear / bug buttons. That happened twice — the MainMenu
## title and the tutorial card title both rendered beneath the bug button — so the
## geometry lives here rather than being re-derived per screen. The set of visible
## buttons VARIES by screen (_hidden_scenes hides the gear on MainMenu and
## SettingsScreen; _bug_hidden_scenes hides the bug button only on SettingsScreen),
## which is why callers must ask at layout time instead of hardcoding a band.
func get_reserved_rect() -> Rect2:
	var out := Rect2()
	var first := true
	for b in [_gear_button, _bug_button]:
		if b == null or not is_instance_valid(b) or not b.is_visible_in_tree():
			continue
		var r: Rect2 = b.get_global_rect()
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		if first:
			out = r
			first = false
		else:
			out = out.merge(r)
	return out


## Convenience for the common case: the y a top-anchored control must start below
## in order to clear this overlay. Returns 0.0 when nothing is reserved.
func get_reserved_bottom() -> float:
	var r := get_reserved_rect()
	return 0.0 if r.size.y <= 0.0 else r.end.y
