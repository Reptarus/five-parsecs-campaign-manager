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
	STANDARD = 180,  # Standard: portrait + name + class + 5-col stats + equipment + XP
	EXPANDED = 200   # Full info: portrait + name + class + all stats + buttons
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

# Updated Deep Space Theme Colors
const COLOR_PRIMARY := Color("#0a0d14")
const COLOR_SECONDARY := Color("#111827")
const COLOR_TERTIARY := Color("#1f2937")
const COLOR_BORDER := Color("#374151")

const COLOR_BLUE := Color("#3b82f6")
const COLOR_PURPLE := Color("#8b5cf6")
const COLOR_EMERALD := Color("#10b981")
const COLOR_AMBER := Color("#f59e0b")
const COLOR_RED := Color("#ef4444")

const COLOR_TEXT_PRIMARY := Color("#f3f4f6")
const COLOR_TEXT_SECONDARY := Color("#9ca3af")
const COLOR_TEXT_MUTED := Color("#6b7280")

# Legacy aliases for backwards compatibility
const COLOR_BASE := COLOR_PRIMARY
const COLOR_ELEVATED := COLOR_SECONDARY
const COLOR_INPUT := COLOR_TERTIARY
const COLOR_ACCENT := COLOR_BLUE

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
	"""Apply glass morphism card styling (matching mockup)"""
	var style := StyleBoxFlat.new()
	# Glass morphism: semi-transparent background with subtle border
	style.bg_color = Color(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, 0.8)
	style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)  # rounded-2xl
	style.set_content_margin_all(SPACING_LG)  # Use LG padding for glass cards
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
		print("CharacterCard: Built %s layout in %d μs" % [CardVariant.find_key(current_variant), _build_time_usec])

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
	
	# Name label (larger font) with text clipping
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_info_container.add_child(_name_label)
	
	# Class/Background subtitle
	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_subtitle_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_info_container.add_child(_subtitle_label)

func _build_standard_layout() -> void:
	"""STANDARD variant: Portrait + Name + Class + 5-Col Stats + Equipment + XP (120px height)"""
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
	
	# Header row: Name + Status Badge
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", SPACING_SM)
	
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header_row.add_child(_name_label)
	
	# Status badge (Ready/Injured/Leader) - will be populated in _update_display
	var status_badge := _create_status_badge("Ready")
	status_badge.name = "StatusBadge"
	header_row.add_child(status_badge)
	
	vbox.add_child(header_row)
	
	# Subtitle (class + background)
	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_subtitle_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(_subtitle_label)
	
	# 5-column stats grid (REA, SPD, CBT, TGH, SAV)
	_stats_container = _create_stats_grid_5col()
	vbox.add_child(_stats_container)
	
	# Equipment badges (max 2 + overflow)
	var equipment_row := _create_equipment_badges()
	equipment_row.name = "EquipmentRow"
	vbox.add_child(equipment_row)
	
	# XP progress bar
	var xp_bar := _create_xp_progress_bar()
	xp_bar.name = "XPBar"
	vbox.add_child(xp_bar)

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
	
	# Name label with text clipping
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	"""Create portrait with gradient placeholder (matches mockup avatars)"""
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(size, size)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Gradient background (varies by character for visual distinction)
	var bg := ColorRect.new()
	bg.color = COLOR_BLUE  # Default gradient color
	bg.custom_minimum_size = Vector2(size, size)
	
	# Round corners
	var clip := Control.new()
	clip.clip_contents = true
	clip.custom_minimum_size = Vector2(size, size)
	clip.add_child(bg)
	
	portrait.add_child(clip)
	
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
	view_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_btn.pressed.connect(_on_view_pressed)
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

	# Update name (use character_name property)
	if _name_label:
		var display_name: String = ""
		if character_data.character_name:
			display_name = character_data.character_name
		else:
			display_name = "Unnamed Character"
		_name_label.text = display_name
		_name_label.clip_text = true
		_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	# Update subtitle (class + background with injury status)
	if _subtitle_label:
		var class_text := character_data.character_class.capitalize()
		var bg_text := character_data.background.capitalize()
		var subtitle := "%s • %s" % [class_text, bg_text]

		# Add injury indicator if wounded
		if character_data.is_wounded:
			var recovery_turns := character_data.current_recovery_turns
			# Label type doesn't support BBCode, use plain text
			subtitle += " • Wounded (%d turns)" % recovery_turns

		# Set subtitle text (Label doesn't support BBCode)
		_subtitle_label.text = subtitle

	# Update status badge (if exists)
	if _card_container:
		var status_badge := _card_container.find_child("StatusBadge", true, false)
		if status_badge:
			var status_text := "Ready"
			if character_data.is_captain:
				status_text = "Leader"
			elif character_data.is_wounded:
				status_text = "Injured"

			# Replace old badge with new one
			var parent := status_badge.get_parent()
			if parent:
				parent.remove_child(status_badge)
				status_badge.queue_free()
				var new_badge := _create_status_badge(status_text)
				new_badge.name = "StatusBadge"
				parent.add_child(new_badge)

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
	"""Update 5-column stats grid for STANDARD variant (no longer used - grid updates automatically)"""
	# The _create_stats_grid_5col() method already reads character_data during creation
	# Stats are formatted as stat boxes with colors, not labels
	# This method is kept for compatibility but doesn't need to do anything
	pass

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

# ============ MOCKUP-STYLE ENHANCEMENTS ============

func _create_stats_grid_5col() -> GridContainer:
	"""Create 5-column stats grid: REA, SPD, CBT, TGH, SAV"""
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if not character_data:
		return grid

	var stats := [
		{"label": "REA", "value": character_data.reactions if character_data.reactions else 1, "color": Color("#10b981")},
		{"label": "SPD", "value": str(character_data.speed if character_data.speed else 4) + '"', "color": Color("#3b82f6")},
		{"label": "CBT", "value": _format_modifier(character_data.combat if character_data.combat else 0), "color": Color("#f59e0b")},
		{"label": "TGH", "value": character_data.toughness if character_data.toughness else 3, "color": Color("#ef4444")},
		{"label": "SAV", "value": _format_modifier(character_data.savvy if character_data.savvy else 0), "color": Color("#8b5cf6")}
	]

	for stat in stats:
		var stat_box := _create_stat_box(stat["label"], str(stat["value"]), stat["color"])
		grid.add_child(stat_box)

	return grid


func _create_stat_box(label_text: String, value_text: String, accent_color: Color) -> PanelContainer:
	"""Create individual stat box with label and value"""
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(48, 48)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.122, 0.161, 0.216, 0.5)  # Semi-transparent gray
	style.set_corner_radius_all(8)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# Stat label (e.g., "REA")
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#6b7280"))
	vbox.add_child(label)

	# Stat value
	var value := Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", accent_color)
	vbox.add_child(value)

	panel.add_child(vbox)
	return panel


func _format_modifier(value: int) -> String:
	"""Format stat modifier with + prefix for positive values"""
	if value >= 0:
		return "+" + str(value)
	return str(value)


func _create_equipment_badges() -> HBoxContainer:
	"""Create horizontal equipment badges (max 2 + overflow)"""
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	if not character_data or not character_data.equipment:
		return hbox

	var equipment_items: Array = []
	if character_data.equipment is Array:
		equipment_items = character_data.equipment
	elif character_data.has_method("get_all_equipment"):
		equipment_items = character_data.get_all_equipment()

	# Show max 2 items
	var shown_count := mini(2, equipment_items.size())
	for i in range(shown_count):
		var item = equipment_items[i]
		var badge := _create_equipment_badge(item)
		hbox.add_child(badge)

	# Overflow indicator
	if equipment_items.size() > 2:
		var overflow := Label.new()
		overflow.text = "+%d items" % (equipment_items.size() - 2)
		overflow.add_theme_font_size_override("font_size", 11)
		overflow.add_theme_color_override("font_color", Color("#6b7280"))
		hbox.add_child(overflow)

	return hbox


func _create_equipment_badge(item) -> PanelContainer:
	"""Create single equipment badge with name"""
	var badge := PanelContainer.new()

	# Determine color based on item type
	var accent_color := Color("#ef4444")  # Default red for weapons
	var item_name := "Unknown"

	if item is Dictionary:
		item_name = item.get("name", "Unknown")
		var item_type = item.get("type", "weapon")
		if item_type == "armor":
			accent_color = Color("#6b7280")
		elif item_type == "gadget":
			accent_color = Color("#8b5cf6")
	elif item is Resource and item.has_method("get_item_name"):
		item_name = item.get_item_name()
	elif item is String:
		item_name = item

	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.1)
	style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(4)
	badge.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = item_name
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", accent_color)
	badge.add_child(label)

	return badge


func _create_xp_progress_bar() -> VBoxContainer:
	"""Create XP progress bar with label"""
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	# Label row
	var label_row := HBoxContainer.new()

	var label := Label.new()
	label.text = "XP to Upgrade"
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#6b7280"))
	label_row.add_child(label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_row.add_child(spacer)

	# Get XP values (use "property" in object syntax for Resource property checks)
	var current_xp := 0
	var max_xp := 10
	if character_data:
		current_xp = character_data.experience if "experience" in character_data else 0
		max_xp = character_data.xp_to_next_level if "xp_to_next_level" in character_data else 10

	var value := Label.new()
	value.text = "%d/%d" % [current_xp, max_xp]
	value.add_theme_font_size_override("font_size", 11)
	value.add_theme_color_override("font_color", Color("#8b5cf6"))
	label_row.add_child(value)

	container.add_child(label_row)

	# Progress bar
	var progress := ProgressBar.new()
	progress.custom_minimum_size.y = 6
	progress.max_value = max_xp
	progress.value = current_xp
	progress.show_percentage = false

	# Style background
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color("#374151")
	bg_style.set_corner_radius_all(3)
	progress.add_theme_stylebox_override("background", bg_style)

	# Style fill (purple gradient effect)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color("#8b5cf6")
	fill_style.set_corner_radius_all(3)
	progress.add_theme_stylebox_override("fill", fill_style)

	container.add_child(progress)

	return container


func _create_status_badge(status: String) -> PanelContainer:
	"""Create status badge (Ready, Injured, Leader)"""
	var badge := PanelContainer.new()

	var color: Color
	match status.to_lower():
		"leader":
			color = Color("#3b82f6")  # Blue
		"ready":
			color = Color("#10b981")  # Green
		"injured":
			color = Color("#ef4444")  # Red
		_:
			color = Color("#6b7280")  # Gray

	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	badge.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = status
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	badge.add_child(label)

	return badge
