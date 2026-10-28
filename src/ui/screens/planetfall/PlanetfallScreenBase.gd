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
## The content sits in a column centred on the screen and no wider than `max_width`,
## with at least a SPACING_MD gutter on a phone. It used to fill the scroll edge to edge
## with no margin: on a tablet every card stretched across 2560 px, and on a phone the
## text touched the glass.
func _create_scroll_layout(max_width: int = MAX_FORM_WIDTH) -> Dictionary:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_scroll_margin = MarginContainer.new()
	_scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_margin.add_theme_constant_override("margin_top", SPACING_LG)
	_scroll_margin.add_theme_constant_override("margin_bottom", SPACING_XL)
	scroll.add_child(_scroll_margin)
	_scroll_max_width = max_width

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", SPACING_LG)
	_scroll_margin.add_child(content)

	_fit_scroll_column()
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_fit_scroll_column):
		vp.size_changed.connect(_fit_scroll_column)
	# Keep the top of the page clear of the Settings / bug-report buttons. The base
	# screen's own call looks for a MarginContainer among the SCREEN's children, and this
	# one sits inside the scroll, so the band was never reserved and a centred title ran
	# under the buttons in portrait.
	var so := get_node_or_null("/root/SettingsOverlay")
	if so and so.has_method("reserve_band_on"):
		so.reserve_band_on(scroll)
	return {"scroll": scroll, "content": content}


var _scroll_margin: MarginContainer
var _scroll_max_width: int = MAX_FORM_WIDTH


## Width arithmetic in the design space the layout uses, so get_visible_rect() is the
## right reading; orientation questions go to ResponsiveManager.
func _fit_scroll_column() -> void:
	if not is_instance_valid(_scroll_margin) or not is_inside_tree():
		return
	var width: float = get_viewport().get_visible_rect().size.x
	var side: int = maxi(SPACING_MD, int((width - _scroll_max_width) / 2.0))
	_scroll_margin.add_theme_constant_override("margin_left", side)
	_scroll_margin.add_theme_constant_override("margin_right", side)


## The keys colony_stats() returns, in the order the screens show them.
const COLONY_STAT_ORDER := [
	"MORALE", "INTEGRITY", "SP", "RM", "BP", "RP", "AP", "GRUNTS", "MILESTONES"]


## The colony's numbers as {key: [short label, full label, value]}. The turn screen's
## strip and the dashboard both read this, so they cannot disagree about a value or read
## it from a different key (the dashboard showed no Raw Materials, Build or Research
## Points at all until 2026-10-28).
static func colony_stats(campaign: Resource) -> Dictionary:
	if campaign == null:
		return {}
	var bd: Variant = campaign.buildings_data if "buildings_data" in campaign else {}
	var rd: Variant = campaign.research_data if "research_data" in campaign else {}
	return {
		"MORALE": ["Morale", "Colony Morale", _stat(campaign, "colony_morale")],
		"INTEGRITY": ["Integrity", "Colony Integrity", _stat(campaign, "colony_integrity")],
		"SP": ["SP", "Story Points", _stat(campaign, "story_points")],
		"RM": ["RM", "Raw Materials", _stat(campaign, "raw_materials")],
		"BP": ["BP", "Build Points",
				int((bd as Dictionary).get("current_bp", 0)) if bd is Dictionary else 0],
		"RP": ["RP", "Research Points",
				int((rd as Dictionary).get("current_rp", 0)) if rd is Dictionary else 0],
		"AP": ["AP", "Augmentation Points", _stat(campaign, "augmentation_points")],
		"GRUNTS": ["Grunts", "Grunts", _stat(campaign, "grunts")],
		"MILESTONES": ["Milestones", "Milestones",
				"%d/7" % _stat(campaign, "milestones_completed")],
	}


static func _stat(campaign: Resource, field: String) -> int:
	return int(campaign.get(field)) if field in campaign else 0


## Navigate via SceneRouter.
func _navigate(route_key: String) -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to(route_key)


## Create a styled action button matching Deep Space theme.
func _create_action_button(text: String, is_primary: bool = false) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	_style_button(btn, is_primary)
	return btn


## Create a colored pill badge (text + border).
func _create_pill(text: String, color: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.2)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_XS))
	lbl.add_theme_color_override("font_color", color)
	pill.add_child(lbl)
	return pill


## Create a class-colored pill for Planetfall character cards.
func _create_class_pill(character_class: String) -> PanelContainer:
	var color: Color
	match character_class.to_lower():
		"scientist":
			color = UIColors.COLOR_BLUE  # Blue
		"scout":
			color = UIColors.COLOR_EMERALD  # Green
		"trooper":
			color = UIColors.COLOR_AMBER  # Amber
		_:
			color = UIColors.COLOR_TEXT_SECONDARY  # Gray
	return _create_pill(character_class.capitalize(), color)


## Create a loyalty badge for Planetfall characters.
func _create_loyalty_pill(loyalty: String) -> PanelContainer:
	var color: Color
	match loyalty.to_lower():
		"loyal":
			color = UIColors.COLOR_EMERALD  # Green
		"committed":
			color = UIColors.COLOR_TEXT_SECONDARY  # Gray
		"disloyal":
			color = UIColors.COLOR_RED  # Red
		_:
			color = UIColors.COLOR_TEXT_SECONDARY
	return _create_pill(loyalty.capitalize(), color)
