extends PlanetfallScreenBase

## Planetfall Turn Controller — 18-step campaign turn.
## Placeholder that will be expanded in the Turn Sequence sprints.
## TODO: Full 18-step phase panel system.

const HubFeatureCardClass = preload("res://src/ui/components/common/HubFeatureCard.gd")

var _campaign: Resource
var _content: VBoxContainer


func _setup_screen() -> void:
	_campaign = _get_planetfall_campaign()
	_build_placeholder()


func _build_placeholder() -> void:
	var layout := _create_scroll_layout()
	_content = layout.content

	var header := Label.new()
	header.text = "PLANETFALL — CAMPAIGN TURN"
	header.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_XL))
	header.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(header)

	var turn_num: int = 0
	if _campaign and "campaign_turn" in _campaign:
		turn_num = _campaign.campaign_turn

	var turn_lbl := Label.new()
	turn_lbl.text = "Turn %d — 18-step turn controller coming in Turn Sequence sprint" % (turn_num + 1)
	turn_lbl.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_MD))
	turn_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	turn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(turn_lbl)

	var back_card := HubFeatureCardClass.new()
	back_card.setup("", "Return to Dashboard", "Go back to the colony overview")
	back_card.card_pressed.connect(func(): _navigate("planetfall_dashboard"))
	_content.add_child(back_card)
