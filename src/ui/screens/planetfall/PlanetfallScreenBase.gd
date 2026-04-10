extends "res://src/ui/screens/campaign/CampaignScreenBase.gd"
class_name PlanetfallScreenBase

## Base class for all Planetfall UI screens.
## Extends CampaignScreenBase for access to the full factory method library,
## responsive layout system, and Deep Space design tokens.
## Adds Planetfall-specific campaign access and content width constraint.
## Follows the same pattern as BugHuntScreenBase.

const MAX_FORM_WIDTH := 800


## Return the current PlanetfallCampaignCore from GameState.
## Overrides the base _get_campaign() which expects FiveParsecsCampaignCore.
func _get_planetfall_campaign():
	var gs := get_node_or_null("/root/GameState")
	if not gs:
		return null
	if gs.has_method("get_current_campaign"):
		var campaign = gs.get_current_campaign()
		if campaign and campaign is Resource:
			return campaign
	return null


## Apply MAX_FORM_WIDTH centering to a container.
## Centers the content on wide screens, fills on mobile.
func _apply_content_max_width(container: Control) -> void:
	if not container:
		return
	var vp := get_viewport()
	if not vp:
		return
	var vp_width: float = vp.get_visible_rect().size.x
	if vp_width > MAX_FORM_WIDTH + SPACING_XL * 2:
		var margin: float = (vp_width - MAX_FORM_WIDTH) / 2.0
		container.offset_left = margin
		container.offset_right = -margin
	else:
		container.offset_left = SPACING_MD
		container.offset_right = -SPACING_MD


## Create a standard Planetfall scroll + content root layout.
## Returns {scroll: ScrollContainer, content: VBoxContainer}.
func _create_scroll_layout() -> Dictionary:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(content)

	return {"scroll": scroll, "content": content}


## Navigate via SceneRouter.
func _navigate(route_key: String) -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to(route_key)


## Create a styled action button matching Deep Space theme.
func _create_action_button(text: String, is_primary: bool = false) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, TOUCH_TARGET_COMFORT)
	_style_button(btn, is_primary)
	return btn


## Create a colored pill badge (text + border).
func _create_pill(text: String, color: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.2)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	lbl.add_theme_color_override("font_color", color)
	pill.add_child(lbl)
	return pill


## Create a class-colored pill for Planetfall character cards.
func _create_class_pill(character_class: String) -> PanelContainer:
	var color: Color
	match character_class.to_lower():
		"scientist":
			color = Color("#3b82f6")  # Blue
		"scout":
			color = Color("#10B981")  # Green
		"trooper":
			color = Color("#f59e0b")  # Amber
		_:
			color = Color("#808080")  # Gray
	return _create_pill(character_class.capitalize(), color)


## Create a loyalty badge for Planetfall characters.
func _create_loyalty_pill(loyalty: String) -> PanelContainer:
	var color: Color
	match loyalty.to_lower():
		"loyal":
			color = Color("#10B981")  # Green
		"committed":
			color = Color("#808080")  # Gray
		"disloyal":
			color = Color("#DC2626")  # Red
		_:
			color = Color("#808080")
	return _create_pill(loyalty.capitalize(), color)
