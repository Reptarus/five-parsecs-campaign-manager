extends PanelContainer
class_name CharacterCard

## Reusable Character Card Component
## Supports 3 variants: COMPACT (80px), STANDARD (120px), EXPANDED (160px)
## Performance optimized for scrolling lists (<1ms instantiation)
## Signal architecture: call-down-signal-up pattern

# ============ SIGNALS (Up Communication) ============
signal card_tapped()  # Single tap/click on card body
signal view_details_pressed()  # "View" button pressed
signal edit_pressed()  # "Edit" button pressed
signal remove_pressed()  # "Remove" button pressed

# ============ ENUMS ============
enum CardVariant {
	COMPACT = 80,    # Minimal info: portrait + name + class
	STANDARD = 120,  # Standard: portrait + name + class + key stats
	EXPANDED = 160   # Full info: portrait + name + class + all stats + buttons
}

# ============ CONSTANTS (From BaseCampaignPanel) ============
const SPACING_XS := 4
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

const TOUCH_TARGET_MIN := 48
const TOUCH_TARGET_COMFORT := 56

const FONT_SIZE_XS := 11
const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18

const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_INPUT := Color("#1E1E36")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_ACCENT_HOVER := Color("#3A7199")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_TEXT_DISABLED := Color("#404040")

# ============ PROPERTIES ============
var current_variant: CardVariant = CardVariant.STANDARD
var character_data: Character = null

# ============ NODE REFERENCES (Lazy-loaded) ============
var _card_container: Control = null
var _portrait: TextureRect = null
var _info_container: VBoxContainer = null
var _name_label: Label = null
var _subtitle_label: Label = null
var _stats_container: Control = null
var _button_container: HBoxContainer = null

# Performance tracking
var _build_time_usec: int = 0

# ============ LIFECYCLE ============
func _ready() -> void:
	custom_minimum_size = Vector2(0, CardVariant.STANDARD)
	_setup_card_style()
	_build_layout()
	
	# Update display if character was set before _ready
	if character_data != null:
		_update_display()

func _gui_input(event: InputEvent) -> void:
	# Mobile-first input handling
	var is_tap := false
	if event is InputEventScreenTouch:
		is_tap = event.pressed
	elif event is InputEventMouseButton:
		is_tap = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	
	if is_tap:
		card_tapped.emit()

# ============ PUBLIC INTERFACE (Call Down) ============
func set_character(character: Character) -> void:
	"""Bind character data and update display"""
	if not character:
		push_error("CharacterCard: Cannot set null character")
		return
	
	character_data = character
	
	# Update display immediately if nodes exist (after _ready)
	# Otherwise it will update when _ready completes
	if _name_label != null:
		_update_display()

func set_variant(variant: CardVariant) -> void:
	"""Switch card layout variant at runtime"""
	if current_variant == variant:
		return
	
	current_variant = variant
	custom_minimum_size.y = variant
	
	if is_inside_tree():
		_rebuild_layout()

func get_variant() -> CardVariant:
	"""Get current card variant"""
	return current_variant

func get_character() -> Character:
	"""Get bound character data"""
	return character_data

# ============ PRIVATE METHODS ============
func _setup_card_style() -> void:
	"""Apply card styling with elevation"""
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	add_theme_stylebox_override("panel", style)

func _build_layout() -> void:
	"""Build card layout based on current variant"""
	var start_time := Time.get_ticks_usec()
	
	match current_variant:
		CardVariant.COMPACT:
			_build_compact_layout()
		CardVariant.STANDARD:
			_build_standard_layout()
		CardVariant.EXPANDED:
			_build_expanded_layout()
	
	_build_time_usec = Time.get_ticks_usec() - start_time
	if OS.is_debug_build():
		print("CharacterCard: Built %s layout in %d μs" % [CardVariant.keys()[current_variant], _build_time_usec])

func _rebuild_layout() -> void:
	"""Rebuild layout when variant changes"""
	# Clear existing children
	for child in get_children():
		child.queue_free()
	
	_card_container = null
	_portrait = null
	_info_container = null
	_name_label = null
	_subtitle_label = null
	_stats_container = null
	_button_container = null
	
	_build_layout()
	_update_display()

func _build_compact_layout() -> void:
	"""COMPACT variant: Portrait + Name + Class (80px height)"""
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_SM)
	add_child(hbox)
	_card_container = hbox
	
	# Portrait (64x64 square)
	_portrait = _create_portrait(64)
	hbox.add_child(_portrait)
	
	# Info column
	_info_container = VBoxContainer.new()
	_info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_info_container)
	
	# Name label (larger font)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_info_container.add_child(_name_label)
	
	# Class/Background subtitle
	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_subtitle_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_info_container.add_child(_subtitle_label)

func _build_standard_layout() -> void:
	"""STANDARD variant: Portrait + Name + Class + Key Stats (120px height)"""
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_MD)
	add_child(hbox)
	_card_container = hbox
	
	# Portrait (96x96 square)
	_portrait = _create_portrait(96)
	hbox.add_child(_portrait)
	
	# Info column
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_XS)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	_info_container = vbox
	
	# Name label
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	vbox.add_child(_name_label)
	
	# Subtitle (class + background)
	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_subtitle_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(_subtitle_label)
	
	# Key stats (compact horizontal layout)
	_stats_container = _create_key_stats_row()
	vbox.add_child(_stats_container)

func _build_expanded_layout() -> void:
	"""EXPANDED variant: Portrait + Name + All Stats + Action Buttons (160px height)"""
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_MD)
	add_child(hbox)
	_card_container = hbox
	
	# Portrait (128x128 square)
	_portrait = _create_portrait(128)
	hbox.add_child(_portrait)
	
	# Right side column
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	_info_container = vbox
	
	# Name label
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	vbox.add_child(_name_label)
	
	# Subtitle
	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_subtitle_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(_subtitle_label)
	
	# All stats grid (3 columns)
	_stats_container = _create_full_stats_grid()
	vbox.add_child(_stats_container)
	
	# Action buttons
	_button_container = _create_action_buttons()
	vbox.add_child(_button_container)

func _create_portrait(size: int) -> TextureRect:
	"""Create portrait placeholder (lazy-load textures for performance)"""
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(size, size)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Placeholder background
	var bg := ColorRect.new()
	bg.color = COLOR_INPUT
	bg.custom_minimum_size = Vector2(size, size)
	portrait.add_child(bg)
	
	return portrait

func _create_key_stats_row() -> HBoxContainer:
	"""Create compact horizontal stats row for STANDARD variant"""
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_SM)
	
	# Pool stat labels for reuse (performance optimization)
	for stat_name in ["Combat", "Reactions", "Savvy"]:
		var stat_label := _create_stat_label(stat_name, 0)
		hbox.add_child(stat_label)
	
	return hbox

func _create_full_stats_grid() -> GridContainer:
	"""Create full stats grid for EXPANDED variant (3 columns)"""
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", SPACING_SM)
	grid.add_theme_constant_override("v_separation", SPACING_XS)
	
	# All stats
	for stat_name in ["Combat", "Reactions", "Toughness", "Savvy", "Speed", "Luck"]:
		var stat_label := _create_stat_label(stat_name, 0)
		grid.add_child(stat_label)
	
	return grid

func _create_stat_label(stat_name: String, value: int) -> Label:
	"""Create stat label with consistent styling"""
	var label := Label.new()
	label.text = "%s: %d" % [stat_name.substr(0, 3).to_upper(), value]  # "COM: 4"
	label.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	return label

func _create_action_buttons() -> HBoxContainer:
	"""Create action button row for EXPANDED variant"""
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_XS)
	
	# View button (primary action)
	var view_btn := Button.new()
	view_btn.text = "View"
	view_btn.custom_minimum_size.y = TOUCH_TARGET_MIN
	view_btn.size_flags_horizontal = Conbl.SIZE_EXPAND_FILL
	view_btn.pressed.connect(_on_view_prbed)
	hbox.add_child(view_btn)
	
	# Edit button (secondary)
	var edit_btn := Button.new()
	edit_btn.text = "Edit"
	edit_btn.custom_minimum_size.y = TOUCH_TARGET_MIN
	edit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_btn.pressed.connect(_on_edit_pressed)
	hbox.add_child(edit_btn)
	
	# Remove button (danger)
	var remove_btn := Button.new()
	remove_btn.text = "Remove"
	remove_btn.custom_minimum_size.y = TOUCH_TARGET_MIN
	remove_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remove_btn.pressed.connect(_on_remove_pressed)
	hbox.add_child(remove_btn)
	
	return hbox

func _update_display() -> void:
	"""Update card display with character data"""
	if not character_data:
		return
	
	# Update name (use .name property, not get_display_name())
	if _name_label:
		_name_label.text = character_data.name if character_data.name else "Unnamed Character"
	
	# Update subtitle (class + background)
	if _subtitle_label:
		var class_text := character_data.character_class.capitalize()
		var bg_text := character_data.background.capitalize()
		_subtitle_label.text = "%s • %s" % [class_text, bg_text]
	
	# Update stats based on variant and ensure stats container is visible
	if _stats_container:
		_stats_container.visible = true  # Ensure stats are shown
		match current_variant:
			CardVariant.COMPACT:
				_stats_container.visible = false  # No stats in compact
			CardVariant.STANDARD:
				_update_key_stats()
			CardVariant.EXPANDED:
				_update_full_stats()

func _update_key_stats() -> void:
	"""Update key stats for STANDARD variant"""
	if not _stats_container or not character_data:
		return
	
	var stats := [character_data.combat, character_data.reactions, character_data.savvy]
	var stat_names := ["Combat", "Reactions", "Savvy"]
	
	for i in range(mini(_stats_container.get_child_count(), 3)):
		var label := _stats_container.get_child(i) as Label
		if label:
			label.text = "%s: %d" % [stat_names[i].substr(0, 3).to_upper(), stats[i]]

func _update_full_stats() -> void:
	"""Update all stats for EXPANDED variant"""
	if not _stats_container or not character_data:
		return
	
	var stats := [
		character_data.combat,
		character_data.reactions,
		character_data.toughness,
		character_data.savvy,
		character_data.speed,
		character_data.luck
	]
	var stat_names := ["Combat", "Reactions", "Toughness", "Savvy", "Speed", "Luck"]
	
	for i in range(mini(_stats_container.get_child_count(), 6)):
		var label := _stats_container.get_child(i) as Label
		if label:
			label.text = "%s: %d" % [stat_names[i].substr(0, 3).to_upper(), stats[i]]

# ============ SIGNAL HANDLERS ============
func _on_view_pressed() -> void:
	"""Handle View button press (EXPANDED variant)"""
	view_details_pressed.emit()

func _on_edit_pressed() -> void:
	"""Handle Edit button press (EXPANDED variant)"""
	edit_pressed.emit()

func _on_remove_pressed() -> void:
	"""Handle Remove button press (EXPANDED variant)"""
	remove_pressed.emit()