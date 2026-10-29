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


## Create a standard Tactics scroll + content root layout.
## Returns {scroll: ScrollContainer, content: VBoxContainer}.
## The content sits in a column centred on the screen, no wider than MAX_FORM_WIDTH, with
## at least a SPACING_MD gutter on a phone. The margins are INSIDE the scroll, as in
## PlanetfallScreenBase. ⚠ It used to centre by moving the full-rect scroll's own
## offsets. That left the screen with neither of the two shapes
## SettingsOverlay.reserve_band_on() looks for (a MarginContainer, or a vertical box), so
## the band was never reserved and the dashboard title ran under the Settings and
## bug-report buttons in portrait (Sprint U, 2026-10-28). It also shrank the drag area to
## the 800 px column on a tablet, and its size_changed lambda kept the scroll that
## _rebuild() frees.
func _create_scroll_layout() -> Dictionary:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_scroll_margin = MarginContainer.new()
	_scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_margin.add_theme_constant_override("margin_top", SPACING_LG)
	_scroll_margin.add_theme_constant_override("margin_bottom", SPACING_XL)
	scroll.add_child(_scroll_margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", SPACING_LG)
	_scroll_margin.add_child(content)

	_fit_scroll_column()
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_fit_scroll_column):
		vp.size_changed.connect(_fit_scroll_column)
	var so := get_node_or_null("/root/SettingsOverlay")
	if so and so.has_method("reserve_band_on"):
		so.reserve_band_on(scroll)
	return {"scroll": scroll, "content": content}


var _scroll_margin: MarginContainer


## Width arithmetic in the design space the layout uses, so get_visible_rect() is the
## right reading; orientation questions go to ResponsiveManager.
func _fit_scroll_column() -> void:
	if not is_instance_valid(_scroll_margin) or not is_inside_tree():
		return
	var width: float = get_viewport().get_visible_rect().size.x
	var side: int = maxi(SPACING_MD, int((width - MAX_FORM_WIDTH) / 2.0))
	_scroll_margin.add_theme_constant_override("margin_left", side)
	_scroll_margin.add_theme_constant_override("margin_right", side)


## Create a styled action button matching Deep Space theme.
func _create_action_button(text: String, is_primary: bool = false) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	_style_button(btn, is_primary)
	return btn
