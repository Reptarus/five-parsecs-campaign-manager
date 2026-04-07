class_name PersistentResourceBar
extends CanvasLayer

## Thin overlay bar showing key campaign resources at the top of the screen.
## Visible during phase screens, hidden on dashboard (which has its own header).
## Credits | Story Points | Patrons | Rivals — always in view during spend decisions.
## Inspired by Fallout Wasteland Warfare companion app persistent resource display.

var _bg: PanelContainer
var _resource_labels: Dictionary = {}  # "credits" -> Label, etc.
var _bar_visible: bool = false

func _init() -> void:
	layer = 80  # Below notifications (90), loading (99), transitions (100)

func _ready() -> void:
	_build_ui()
	_update_values()
	# Start hidden
	_set_bar_visible(false)

func _build_ui() -> void:
	_bg = PanelContainer.new()
	_bg.position = Vector2.ZERO
	var vp := get_viewport()
	var vp_width: float = vp.get_visible_rect().size.x if vp else 1920.0
	_bg.size = Vector2(vp_width, 36)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		UIColors.COLOR_SECONDARY.r,
		UIColors.COLOR_SECONDARY.g,
		UIColors.COLOR_SECONDARY.b,
		0.92
	)
	style.content_margin_left = UIColors.SPACING_MD
	style.content_margin_right = UIColors.SPACING_MD
	style.content_margin_top = UIColors.SPACING_XS
	style.content_margin_bottom = UIColors.SPACING_XS
	_bg.add_theme_stylebox_override("panel", style)
	add_child(_bg)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UIColors.SPACING_LG)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_bg.add_child(hbox)

	# Resource displays
	_add_resource(hbox, "credits", "💰", UIColors.COLOR_AMBER)
	_add_resource(hbox, "story_points", "✦", UIColors.COLOR_PURPLE)
	_add_resource(hbox, "patrons", "👤", UIColors.COLOR_CYAN)
	_add_resource(hbox, "rivals", "⚔", UIColors.COLOR_RED)

	if vp:
		vp.size_changed.connect(_on_viewport_resized)

func _add_resource(
	parent: HBoxContainer,
	key: String,
	icon: String,
	color: Color
) -> void:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", UIColors.SPACING_XS)

	var icon_label := Label.new()
	icon_label.text = icon
	icon_label.add_theme_font_size_override("font_size", 14)
	icon_label.add_theme_color_override("font_color", color)
	container.add_child(icon_label)

	var value_label := Label.new()
	value_label.text = "0"
	value_label.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_SM
	)
	value_label.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	container.add_child(value_label)

	parent.add_child(container)
	_resource_labels[key] = value_label

func _on_viewport_resized() -> void:
	var vp := get_viewport()
	if vp and _bg:
		_bg.size.x = vp.get_visible_rect().size.x

## Update displayed values from the current campaign.
func _update_values() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	if not game_state:
		return
	var campaign = null
	if game_state.has_method("get_current_campaign"):
		campaign = game_state.get_current_campaign()
	if not campaign:
		return

	_set_resource("credits", campaign.credits if "credits" in campaign else 0)

	var sp: int = 0
	if "story_points" in campaign:
		sp = campaign.story_points
	elif "progress_data" in campaign:
		sp = campaign.progress_data.get("story_points", 0)
	_set_resource("story_points", sp)

	var patrons_count: int = 0
	if campaign.has_method("get_patrons"):
		patrons_count = campaign.get_patrons().size()
	elif "patron_data" in campaign:
		var pd: Dictionary = campaign.patron_data
		patrons_count = pd.get("patrons", []).size()
	_set_resource("patrons", patrons_count)

	var rivals_count: int = 0
	if campaign.has_method("get_rivals"):
		rivals_count = campaign.get_rivals().size()
	elif "rival_data" in campaign:
		var rd: Dictionary = campaign.rival_data
		rivals_count = rd.get("rivals", []).size()
	_set_resource("rivals", rivals_count)

func _set_resource(key: String, value: int) -> void:
	if key not in _resource_labels:
		return
	var label: Label = _resource_labels[key]
	var old_text: String = label.text
	label.text = str(value)
	# Animate on change
	if old_text != label.text and _bar_visible:
		label.pivot_offset = label.size / 2
		TweenFX.punch_in(label, 0.15, 0.25)

## Show the resource bar with a fold-in animation.
func show_bar() -> void:
	if _bar_visible:
		return
	_bar_visible = true
	_update_values()
	_set_bar_visible(true)
	if _bg:
		TweenFX.fold_in(_bg, 0.25)

## Hide the resource bar with a fold-out animation.
func hide_bar() -> void:
	if not _bar_visible:
		return
	_bar_visible = false
	if _bg:
		var tween := TweenFX.fold_out(_bg, 0.25)
		tween.finished.connect(func():
			_set_bar_visible(false)
		)
	else:
		_set_bar_visible(false)

func _set_bar_visible(vis: bool) -> void:
	if _bg:
		_bg.visible = vis

## Refresh values (call when resources change during a phase).
func refresh() -> void:
	_update_values()
