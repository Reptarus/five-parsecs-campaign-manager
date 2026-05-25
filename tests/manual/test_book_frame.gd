## Manual visual test for the two-layer book chrome system.
##
## Launch by setting `res://tests/manual/test_book_frame.tscn` as the main
## scene in Project Settings → Application → Run → Main Scene, OR by
## opening the .tscn and pressing F6 (Play Current Scene).
##
## Tests BOTH layers together (per plan revision 2026-05-23):
##   - OUTER: a single BookFrame wrapping the whole test scene with page-level
##     ornaments (the .ai-extracted SVGs at native size, anchored to corners)
##   - INNER: a grid of CalloutCards demonstrating the 5 semantic colors
##
## Use this to:
##   - Verify ornament SVGs load and tint correctly at page scale
##   - Tune BookFrame.CONTENT_MARGIN and EDGE_INSET
##   - Tune CalloutCard.PADDING_TOP / BORDER_WIDTH / spacing
##   - Confirm aspect-ratio independence (resize window — ornaments stay
##     pinned to corners at native size; callouts scale within their slots)
##
## Pre-req: ornament SVGs must exist at res://assets/ui/borders/ornaments/.
## Missing files render as the gradient fallback (BookFrame silent-fallback).
extends Control

const BookFrameScript = preload("res://src/ui/components/common/BookFrame.gd")
const CalloutCardScript = preload("res://src/ui/components/common/CalloutCard.gd")


func _ready() -> void:
	# Dark background so chrome stands out
	var bg := ColorRect.new()
	bg.color = Color("#1A1A2E")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.show_behind_parent = true
	add_child(bg)

	# Outer layer: single BookFrame wrapping the whole scene
	var book_frame: Control = BookFrameScript.new()
	book_frame.border_color = Color("#D4A017")  # gold, matches rulebook
	add_child(book_frame)

	# Inner grid of callout cards — slotted INSIDE the BookFrame's content area
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	book_frame.add_content_child(grid)

	# 6 callout cards demonstrating each semantic color
	var fixtures := [
		{"title": "Crew Status", "color": CalloutCardScript.COLOR_NEUTRAL,
		 "body": "Generic content card. Neutral light-gray border."},
		{"title": "Active Mission", "color": CalloutCardScript.COLOR_PRIMARY,
		 "body": "Primary focus card — current narrative thread, active mission, or the player's next action."},
		{"title": "Equipment Stash", "color": CalloutCardScript.COLOR_SUCCESS,
		 "body": "Positive / owned content — inventory, completed objectives, gained advantages."},
		{"title": "Upkeep Due", "color": CalloutCardScript.COLOR_WARNING,
		 "body": "Caution content — low resources, approaching deadlines, soft warnings."},
		{"title": "Rivals", "color": CalloutCardScript.COLOR_DANGER,
		 "body": "Hostile / critical content — enemies, threats, lost battles, urgent attention."},
		{"title": "Story Track", "color": CalloutCardScript.COLOR_PRIMARY,
		 "body": "Sample with a description below.",
		 "description": "Long-form secondary text. Smaller font, muted color. Wraps if needed."},
	]

	for fixture in fixtures:
		var card := _make_callout(
			fixture["title"],
			fixture["color"],
			fixture["body"],
			fixture.get("description", "")
		)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(280, 180)
		grid.add_child(card)


func _make_callout(title: String, border_color: Color, body_text: String,
		description: String = "") -> Control:
	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color("#E0E0E0"))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var callout: PanelContainer = CalloutCardScript.new()
	callout.title_text = title
	callout.border_color = border_color

	if description != "":
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		vbox.add_child(body)
		var desc := Label.new()
		desc.text = description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color("#808080"))
		vbox.add_child(desc)
		callout.add_content_child(vbox)
	else:
		callout.add_content_child(body)
	return callout
