extends Button

## Reusable "?" help button that opens help content for a specific chapter/section.
## Place on any screen and set help_chapter/help_section to link to relevant content.
##
## Usage:
##   var btn = preload("res://src/ui/help/HelpButton.gd").new()
##   btn.help_chapter = "02"
##   btn.help_section = "captain_creation"
##   header.add_child(btn)

@export var help_chapter: String = ""
@export var help_section: String = ""
@export var compact: bool = false  # Small icon-only mode

const HelpContentLoaderScript = preload("res://src/ui/help/HelpContentLoader.gd")

func _ready() -> void:
	text = "?" if compact else "? Help"
	tooltip_text = "Open help guide"
	custom_minimum_size = Vector2(36, 36) if compact else Vector2(80, 36)
	_apply_style()
	pressed.connect(_on_pressed)


func _apply_style() -> void:
	# Cyan circle/pill button style matching Deep Space theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.176, 0.353, 0.482, 0.8)  # COLOR_ACCENT with alpha
	style.set_corner_radius_all(18 if compact else 8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.227, 0.443, 0.6, 0.9)  # COLOR_ACCENT_HOVER
	add_theme_stylebox_override("hover", hover_style)

	var pressed_style := style.duplicate()
	pressed_style.bg_color = Color(0.14, 0.28, 0.39, 0.9)
	add_theme_stylebox_override("pressed", pressed_style)

	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_color", Color(0.878, 0.878, 0.878))  # COLOR_TEXT_PRIMARY


func _on_pressed() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if not router:
		push_warning("HelpButton: SceneRouter not found")
		return

	# Build context for HelpScreen to open at the right chapter/section
	var context := {}
	if not help_chapter.is_empty():
		# Resolve short chapter ID to full ID
		var loader := HelpContentLoaderScript.new()
		loader.ensure_loaded()
		var full_id := loader._resolve_chapter_id(help_chapter)
		context["chapter_id"] = full_id
	if not help_section.is_empty():
		context["section_id"] = help_section

	router.navigate_to("help", context)


## Update the help target at runtime (e.g., when campaign phase changes).
func set_help_target(chapter: String, section: String = "") -> void:
	help_chapter = chapter
	help_section = section
