extends Control
class_name KeywordTooltip

## KeywordTooltip - Interactive BBCode Tooltip for Game Keywords
## Displays keyword definitions with related terms and bookmarking
## Responsive design: mobile bottom sheet, desktop popover
## Performance: <100ms display time, reuses dialog instance

## Signals
signal tooltip_opened(keyword: String)
signal tooltip_closed()
signal keyword_bookmarked(keyword: String)
signal related_keyword_clicked(keyword: String)
signal rule_reference_clicked(rule_page: String)

## Display modes for responsive design
enum DisplayMode {
	MOBILE,    # <600px: Bottom sheet (60% viewport, slide-up)
	TABLET,    # 600-900px: Centered modal (480px width)
	DESKTOP    # >900px: Contextual popover (420px, near keyword)
}

## Design System Constants (from BaseCampaignPanel)
const COLOR_ELEVATED := Color("#252542")     # Card backgrounds
const COLOR_BORDER := Color("#3A3A5C")       # Card borders
const COLOR_FOCUS := Color("#4FC3F7")        # Focus ring (cyan)
const COLOR_TEXT_PRIMARY := Color("#E0E0E0") # Main content
const COLOR_TEXT_SECONDARY := Color("#808080") # Descriptions
const COLOR_SUCCESS := Color("#10B981")      # Green (for bookmarks)
const TOUCH_TARGET_COMFORT := 56             # Button height
const SPACING_MD := 16                       # Padding

## Performance optimization
const DEBOUNCE_TIMEOUT := 0.3  # 300ms cooldown between taps

## Internal state
var _dialog: AcceptDialog = null
var _rich_text: RichTextLabel = null
var _bookmark_button: Button = null
var _current_keyword: String = ""
var _formatted_cache: Dictionary = {}  # keyword → BBCode string
var _last_tap_time: float = 0.0
var _current_mode: DisplayMode = DisplayMode.DESKTOP

func _ready() -> void:
	# Lazy creation - dialog created on first use
	pass

## Public API

func format_keyword_text(keyword_data: Dictionary) -> String:
	"""
	Format keyword data as BBCode with clickable related terms.
	
	Args:
		keyword_data: Dictionary with keys: term, definition, related (optional), rule_page (optional)
	
	Returns:
		BBCode string with formatted keyword info and clickable links
	"""
	if not keyword_data.has("term") or not keyword_data.has("definition"):
		push_warning("KeywordTooltip: Invalid keyword data - missing term or definition")
		return "[color=#DC2626]Invalid keyword data[/color]"
	
	var term: String = keyword_data["term"]
	var definition: String = keyword_data["definition"]
	var related: Array = keyword_data.get("related", [])
	var rule_page: int = keyword_data.get("rule_page", 0)
	
	# Build BBCode
	var bbcode := ""
	
	# Title
	bbcode += "[font_size=20][b]%s[/b][/font_size]\n\n" % term
	
	# Definition
	bbcode += "[color=#E0E0E0]%s[/color]\n\n" % definition
	
	# Related keywords (clickable)
	if related.size() > 0:
		bbcode += "[color=#808080]Related:[/color] "
		for i in range(related.size()):
			var related_term: String = related[i]
			bbcode += "[url=keyword:%s][color=#4FC3F7]%s[/color][/url]" % [related_term, related_term]
			if i < related.size() - 1:
				bbcode += ", "
		bbcode += "\n\n"
	
	# Rule reference (clickable)
	if rule_page > 0:
		bbcode += "[url=rule:%d][color=#4FC3F7]→ Rules p.%d[/color][/url]" % [rule_page, rule_page]
	
	return bbcode

func show_for_keyword(keyword: String, position: Vector2) -> void:
	"""
	Display tooltip for the specified keyword at the given position.
	
	Args:
		keyword: The keyword term to display
		position: Screen position for contextual placement (desktop mode)
	"""
	# Debounce rapid taps
	var current_time := Time.get_ticks_msec() / 1000.0
	if current_time - _last_tap_time < DEBOUNCE_TIMEOUT:
		return
	_last_tap_time = current_time
	
	# Lazy-create dialog on first use
	if _dialog == null:
		_create_dialog()
	
	# Fetch keyword data from KeywordDB
	var keyword_data := KeywordDB.get_keyword(keyword)
	
	# Check cache first
	var bbcode_text: String
	if _formatted_cache.has(keyword):
		bbcode_text = _formatted_cache[keyword]
	else:
		bbcode_text = format_keyword_text(keyword_data)
		_formatted_cache[keyword] = bbcode_text
	
	# Update dialog content
	_rich_text.text = bbcode_text
	_current_keyword = keyword
	
	# Update bookmark button state
	_update_bookmark_button()
	
	# Determine display mode based on viewport size
	_current_mode = _get_display_mode()
	
	# Position and style dialog based on mode
	_apply_display_mode(position)
	
	# Show dialog
	_dialog.popup_centered()
	
	# Emit signal
	tooltip_opened.emit(keyword)

func hide_tooltip() -> void:
	"""Dismiss the tooltip."""
	if _dialog and _dialog.visible:
		_dialog.hide()
		tooltip_closed.emit()

func toggle_bookmark(keyword: String) -> void:
	"""Toggle bookmark state for the specified keyword."""
	KeywordDB.toggle_bookmark(keyword)
	_update_bookmark_button()
	keyword_bookmarked.emit(keyword)

## Internal Methods

func _create_dialog() -> void:
	"""Create and configure the AcceptDialog instance."""
	_dialog = AcceptDialog.new()
	_dialog.title = "Keyword Info"
	_dialog.dialog_hide_on_ok = true
	_dialog.ok_button_text = "Close"
	_dialog.unresizable = false
	
	# Create content container
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(380, 0)
	
	# Create RichTextLabel for formatted text
	_rich_text = RichTextLabel.new()
	_rich_text.bbcode_enabled = true
	_rich_text.fit_content = true
	_rich_text.scroll_active = false
	_rich_text.custom_minimum_size = Vector2(0, 100)
	
	# Style RichTextLabel
	_rich_text.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_rich_text.add_theme_color_override("font_selected_color", COLOR_FOCUS)
	
	# Connect meta_clicked for related keywords and rule references
	_rich_text.meta_clicked.connect(_on_meta_clicked)
	
	content.add_child(_rich_text)
	
	# Create bookmark button
	var button_container := HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	_bookmark_button = Button.new()
	_bookmark_button.text = "⭐ Bookmark"
	_bookmark_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	_bookmark_button.pressed.connect(_on_bookmark_pressed)
	
	button_container.add_child(_bookmark_button)
	content.add_child(button_container)
	
	# Add content to dialog
	_dialog.add_child(content)
	
	# Add dialog to scene tree
	add_child(_dialog)
	
	# Connect close signal
	_dialog.confirmed.connect(_on_dialog_closed)
	_dialog.canceled.connect(_on_dialog_closed)

func _get_display_mode() -> DisplayMode:
	"""Determine display mode based on viewport size."""
	var viewport_size := get_viewport_rect().size
	var width := viewport_size.x
	
	if width < 600:
		return DisplayMode.MOBILE
	elif width < 900:
		return DisplayMode.TABLET
	else:
		return DisplayMode.DESKTOP

func _apply_display_mode(position: Vector2) -> void:
	"""Apply styling and positioning based on display mode."""
	match _current_mode:
		DisplayMode.MOBILE:
			# Bottom sheet: 60% viewport height, full width
			var viewport_size := get_viewport_rect().size
			_dialog.size = Vector2(viewport_size.x * 0.9, viewport_size.y * 0.6)
			_dialog.position = Vector2(viewport_size.x * 0.05, viewport_size.y * 0.4)
		
		DisplayMode.TABLET:
			# Centered modal: 480px width
			_dialog.size = Vector2(480, 0)
			_dialog.reset_size()
		
		DisplayMode.DESKTOP:
			# Contextual popover: 420px width, near keyword
			_dialog.size = Vector2(420, 0)
			_dialog.position = position + Vector2(20, 20)  # Slight offset
			_dialog.reset_size()

func _update_bookmark_button() -> void:
	"""Update bookmark button state based on KeywordDB."""
	if not _bookmark_button:
		return
	
	var is_bookmarked := KeywordDB.is_bookmarked(_current_keyword)
	if is_bookmarked:
		_bookmark_button.text = "⭐ Bookmarked"
		_bookmark_button.add_theme_color_override("font_color", COLOR_SUCCESS)
	else:
		_bookmark_button.text = "☆ Bookmark"
		_bookmark_button.remove_theme_color_override("font_color")

func _on_meta_clicked(meta: Variant) -> void:
	"""Handle clicks on BBCode meta tags (related keywords, rule references)."""
	var meta_str := str(meta)
	
	if meta_str.begins_with("keyword:"):
		var related_keyword := meta_str.substr(8)  # Remove "keyword:" prefix
		related_keyword_clicked.emit(related_keyword)
		# Show tooltip for related keyword
		show_for_keyword(related_keyword, _dialog.position)
	
	elif meta_str.begins_with("rule:"):
		var rule_page := meta_str.substr(5)  # Remove "rule:" prefix
		rule_reference_clicked.emit(rule_page)

func _on_bookmark_pressed() -> void:
	"""Handle bookmark button press."""
	toggle_bookmark(_current_keyword)

func _on_dialog_closed() -> void:
	"""Handle dialog close."""
	tooltip_closed.emit()
