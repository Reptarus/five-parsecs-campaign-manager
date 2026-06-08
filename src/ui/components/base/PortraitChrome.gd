class_name PortraitChrome
extends Node

## Self-wiring portrait de-clip helper for screens that do NOT extend
## CampaignScreenBase (so can't use its `_apply_portrait_chrome`). Trims a root
## MarginContainer's LEFT/RIGHT margins in portrait to reclaim design width on the
## 360dp floor, and restores them in landscape — reacting to rotation via
## `ResponsiveManager.layout_class_changed`. Desktop/landscape stays unchanged.
##
## Usage (in a screen's _ready, after its own setup):
##   var pc := PortraitChrome.new()
##   add_child(pc)
##   pc.setup($MarginContainer)            # or get_node_or_null("MarginContainer")
##
## Margins only (it never reparents or restyles) — pair with an HBox->HFlow scene
## edit for non-wrapping button rows, per docs/sop/responsive-adaptive-ui.md.

var _mc: MarginContainer = null
var _portrait_lr: int = 4
var _landscape_lr: int = 20
var _rm: Node = null
var _wired: bool = false

func setup(margin_container: MarginContainer, portrait_lr: int = 4, landscape_lr: int = -1) -> void:
	_mc = margin_container
	_portrait_lr = portrait_lr
	# Capture the scene's ORIGINAL L/R margin as the landscape restore value (robust
	# across screens with different base margins — managers are 20, the dashboard 24),
	# unless an explicit landscape value is passed.
	if landscape_lr >= 0:
		_landscape_lr = landscape_lr
	elif _mc:
		_landscape_lr = _mc.get_theme_constant("margin_left", "MarginContainer")
	_ensure_wired()
	_apply()

func _ready() -> void:
	_ensure_wired()
	_apply()

func _ensure_wired() -> void:
	if _wired:
		return
	_rm = get_node_or_null("/root/ResponsiveManager")
	if _rm and _rm.has_signal("layout_class_changed") \
			and not _rm.layout_class_changed.is_connected(_on_layout_changed):
		_rm.layout_class_changed.connect(_on_layout_changed)
		_wired = true

func _on_layout_changed(_cols: int) -> void:
	_apply()

func _is_portrait() -> bool:
	if _rm and _rm.has_method("is_portrait"):
		return _rm.is_portrait()
	var vp := get_viewport()
	if vp == null:
		return false
	var s := vp.get_visible_rect().size
	return s.y > s.x

func _apply() -> void:
	if _mc == null or not is_instance_valid(_mc):
		return
	var lr: int = _portrait_lr if _is_portrait() else _landscape_lr
	_mc.add_theme_constant_override("margin_left", lr)
	_mc.add_theme_constant_override("margin_right", lr)
