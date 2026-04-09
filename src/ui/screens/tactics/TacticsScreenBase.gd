extends "res://src/ui/screens/campaign/CampaignScreenBase.gd"
class_name TacticsScreenBase

## Base class for all Tactics UI screens.
## Extends CampaignScreenBase for access to the full factory method library,
## responsive layout system, and UIColors design tokens.
## Adds Tactics-specific campaign access and content width constraint.

const MAX_FORM_WIDTH := 800


## Return the current TacticsCampaignCore from GameState.
func _get_tactics_campaign():
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


## Create a standard Tactics scroll + content root layout.
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


## Create a styled action button matching Deep Space theme.
func _create_action_button(text: String, is_primary: bool = false) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, TOUCH_TARGET_COMFORT)
	_style_button(btn, is_primary)
	return btn
