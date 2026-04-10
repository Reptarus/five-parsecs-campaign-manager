class_name DLCActivationToast
extends CanvasLayer

## Transient toast notification when DLC is purchased mid-session.
## Shows at top-center, auto-fades after 5 seconds.
## Wire to StoreManager.purchase_completed signal.

const DLCContentCatalogRef = preload(
	"res://src/ui/screens/store/DLCContentCatalog.gd")

const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const FONT_SIZE_SM := UIColors.FONT_SIZE_SM
const FONT_SIZE_MD := UIColors.FONT_SIZE_MD
const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN
const COLOR_EMERALD := UIColors.COLOR_EMERALD
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_CYAN := UIColors.COLOR_CYAN

var _panel: PanelContainer = null

func show_activation(dlc_id: String) -> void:
	var pack_name: String = DLCContentCatalogRef.get_pack_name(
		dlc_id)
	_build_ui(pack_name)
	# Auto-dismiss after 5s
	var tween := create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(_panel, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)

func _build_ui(pack_name: String) -> void:
	layer = 100  # Above everything

	_panel = PanelContainer.new()
	# Center at top
	_panel.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_TOP)
	_panel.offset_top = 20
	_panel.offset_bottom = 80

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1A2E1A")
	style.border_color = COLOR_EMERALD
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(SPACING_MD)
	_panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_SM)
	_panel.add_child(hbox)

	# Checkmark
	var check := Label.new()
	check.text = "✓"
	check.add_theme_font_size_override(
		"font_size", FONT_SIZE_MD)
	check.add_theme_color_override(
		"font_color", COLOR_EMERALD)
	hbox.add_child(check)

	# Message
	var msg := Label.new()
	msg.text = "%s Activated!" % pack_name
	msg.add_theme_font_size_override(
		"font_size", FONT_SIZE_MD)
	msg.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	hbox.add_child(msg)

	# Manage button
	var manage_btn := Button.new()
	manage_btn.text = "Manage Features"
	manage_btn.flat = true
	manage_btn.custom_minimum_size.y = TOUCH_TARGET_MIN
	manage_btn.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	manage_btn.add_theme_color_override(
		"font_color", COLOR_CYAN)
	manage_btn.pressed.connect(_on_manage_pressed)
	hbox.add_child(manage_btn)

	# Dismiss X
	var dismiss := Button.new()
	dismiss.text = "✕"
	dismiss.flat = true
	dismiss.custom_minimum_size = Vector2(
		TOUCH_TARGET_MIN, TOUCH_TARGET_MIN)
	dismiss.pressed.connect(queue_free)
	hbox.add_child(dismiss)

	add_child(_panel)

func _on_manage_pressed() -> void:
	var DLCDialogScript := load(
		"res://src/ui/dialogs/DLCManagementDialog.gd")
	if DLCDialogScript:
		var root = get_tree().root if get_tree() else null
		if root:
			var dialog: AcceptDialog = DLCDialogScript.new()
			root.add_child(dialog)
			dialog.popup_centered()
	queue_free()

## Static helper — call from anywhere to show toast.
static func show_for_dlc(dlc_id: String) -> void:
	var ml: SceneTree = Engine.get_main_loop() as SceneTree
	if not ml:
		return
	var root: Window = ml.root
	if not root:
		return
	var _Self = load("res://src/ui/components/dlc/DLCActivationToast.gd")
	var toast = _Self.new()
	root.add_child(toast)
	toast.show_activation(dlc_id)
