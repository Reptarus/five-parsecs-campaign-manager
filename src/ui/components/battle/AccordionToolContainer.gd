class_name FPCM_AccordionToolContainer
extends ScrollContainer

## Accordion container for battle tool components.
## Wraps each tool in a collapsible section with touch-friendly headers.
## Exclusive mode: only one section open at a time (saves vertical space).
## Pattern based on CheatSheetPanel._build_section() / _toggle_section().

# Design tokens
const SPACING_SM: int = UIColors.SPACING_SM
const TOUCH_TARGET_MIN: int = UIColors.TOUCH_TARGET_MIN
const FONT_SIZE_MD: int = UIColors.FONT_SIZE_MD
const COLOR_ELEVATED: Color = UIColors.COLOR_ELEVATED
const COLOR_ACCENT: Color = UIColors.COLOR_ACCENT
const COLOR_BORDER: Color = UIColors.COLOR_BORDER
const COLOR_TEXT_PRIMARY: Color = UIColors.COLOR_TEXT_PRIMARY

var _vbox: VBoxContainer
var _section_headers: Array[Button] = []
var _section_bodies: Array[Control] = []
var _section_titles: Array[String] = []

## Only one section open at a time
var exclusive_mode: bool = true


func _init() -> void:
	# Create _vbox eagerly so add_section() works before _ready()
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 4)
	add_child(_vbox)


## Add a collapsible section wrapping a tool component
func add_section(title: String, content: Control) -> void:
	var index := _section_bodies.size()

	# Header button
	var header := Button.new()
	header.text = "[+] %s" % title
	header.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	header.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var header_style := StyleBoxFlat.new()
	header_style.bg_color = COLOR_ELEVATED
	header_style.set_corner_radius_all(4)
	header_style.set_content_margin_all(SPACING_SM)
	header.add_theme_stylebox_override("normal", header_style)

	var hover_style := header_style.duplicate()
	hover_style.bg_color = COLOR_ACCENT
	header.add_theme_stylebox_override("hover", hover_style)
	header.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

	header.pressed.connect(_toggle_section.bind(index))
	_vbox.add_child(header)
	_section_headers.append(header)

	# Body — starts collapsed
	content.visible = false
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_child(content)
	_section_bodies.append(content)
	_section_titles.append(title)


func _toggle_section(index: int) -> void:
	if index < 0 or index >= _section_bodies.size():
		return

	var body: Control = _section_bodies[index]
	var was_open := body.visible

	if exclusive_mode:
		# Close all sections
		for i in _section_bodies.size():
			_section_bodies[i].visible = false
			_section_headers[i].text = "[+] %s" % _section_titles[i]

	# Toggle the clicked section
	body.visible = not was_open
	if body.visible:
		_section_headers[index].text = "[-] %s" % _section_titles[index]
	else:
		_section_headers[index].text = "[+] %s" % _section_titles[index]


## Open a specific section by index
func open_section(index: int) -> void:
	if index < 0 or index >= _section_bodies.size():
		return
	if exclusive_mode:
		for i in _section_bodies.size():
			_section_bodies[i].visible = false
			_section_headers[i].text = "[+] %s" % _section_titles[i]
	_section_bodies[index].visible = true
	_section_headers[index].text = "[-] %s" % _section_titles[index]


## Collapse all sections
func collapse_all() -> void:
	for i in _section_bodies.size():
		_section_bodies[i].visible = false
		_section_headers[i].text = "[+] %s" % _section_titles[i]
