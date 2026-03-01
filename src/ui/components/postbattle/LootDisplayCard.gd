extends PanelContainer
class_name LootDisplayCard

## Reusable Loot Item Card Component
## Displays a single loot item with visual presentation
## Signal architecture: call-down-signal-up pattern
## Touch-friendly with 48px minimum height

# ============ SIGNALS (Up Communication) ============
signal item_selected(item_data: Dictionary)  # User tapped/clicked the item card

# ============ CONSTANTS (Design System) ============
const SPACING_XS := UIColors.SPACING_XS
const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD

const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN

const FONT_SIZE_XS := UIColors.FONT_SIZE_XS
const FONT_SIZE_SM := UIColors.FONT_SIZE_SM
const FONT_SIZE_MD := UIColors.FONT_SIZE_MD

# Colors from UIColors
const COLOR_SECONDARY := UIColors.COLOR_SECONDARY
const COLOR_TERTIARY := UIColors.COLOR_TERTIARY
const COLOR_BORDER := UIColors.COLOR_BORDER

const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_TEXT_MUTED := UIColors.COLOR_TEXT_MUTED

# Rarity colors
const RARITY_COMMON := UIColors.COLOR_TEXT_PRIMARY   # White
const RARITY_UNCOMMON := UIColors.COLOR_EMERALD      # Green
const RARITY_RARE := UIColors.COLOR_BLUE             # Blue
const RARITY_EPIC := UIColors.COLOR_PURPLE           # Purple
const RARITY_LEGENDARY := UIColors.COLOR_AMBER       # Amber

# ============ PROPERTIES ============
var item_data: Dictionary = {}

# ============ ONREADY NODE REFERENCES ============
@onready var _item_icon: TextureRect = null
@onready var _item_name: Label = null
@onready var _item_description: Label = null
@onready var _rarity_badge: Label = null
@onready var _value_label: Label = null

# ============ LIFECYCLE ============
func _ready() -> void:
	custom_minimum_size.y = TOUCH_TARGET_MIN
	_setup_card_style()
	_build_layout()

	# Update display if data was set before _ready
	if not item_data.is_empty():
		_update_display()

func _gui_input(event: InputEvent) -> void:
	# Mobile-first input handling
	var is_tap := false
	if event is InputEventScreenTouch:
		is_tap = event.pressed
	elif event is InputEventMouseButton:
		is_tap = event.pressed and event.button_index == MOUSE_BUTTON_LEFT

	if is_tap:
		item_selected.emit(item_data)

# ============ PUBLIC INTERFACE (Call Down) ============
func setup(data: Dictionary) -> void:
	## Set item data and update display
	if data.is_empty():
		push_warning("LootDisplayCard: Empty item data provided")
		return

	item_data = data

	# Update display immediately if nodes exist (after _ready)
	if _item_name != null:
		_update_display()

# ============ PRIVATE METHODS ============
func _setup_card_style() -> void:
	## Apply card styling with subtle background
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SECONDARY
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	add_theme_stylebox_override("panel", style)

func _build_layout() -> void:
	## Build card layout: icon + info + value
	# Main horizontal container
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_MD)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.name = "MainHBox"
	add_child(hbox)

	# Item icon (32x32)
	_item_icon = TextureRect.new()
	_item_icon.custom_minimum_size = Vector2(32, 32)
	_item_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_item_icon.name = "ItemIcon"
	hbox.add_child(_item_icon)

	# Info container (name + description + rarity)
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", SPACING_XS)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.name = "InfoVBox"
	hbox.add_child(info_vbox)

	# Item name
	_item_name = Label.new()
	_item_name.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	_item_name.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_item_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_item_name.name = "ItemName"
	info_vbox.add_child(_item_name)

	# Item description
	_item_description = Label.new()
	_item_description.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_item_description.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_item_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_item_description.max_lines_visible = 2
	_item_description.name = "ItemDescription"
	info_vbox.add_child(_item_description)

	# Rarity badge
	_rarity_badge = Label.new()
	_rarity_badge.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	_rarity_badge.name = "RarityBadge"
	info_vbox.add_child(_rarity_badge)

	# Value label (right-aligned)
	_value_label = Label.new()
	_value_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	_value_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value_label.custom_minimum_size.x = 80
	_value_label.name = "ValueLabel"
	hbox.add_child(_value_label)

func _update_display() -> void:
	## Update all UI elements from item_data
	if not is_inside_tree():
		return

	# Item name
	_item_name.text = item_data.get("name", "Unknown Item")

	# Item description
	var description: String = item_data.get("description", "")
	_item_description.text = description
	_item_description.visible = not description.is_empty()

	# Rarity badge
	var rarity: String = item_data.get("rarity", "common").to_lower()
	_rarity_badge.text = rarity.capitalize()
	_rarity_badge.add_theme_color_override("font_color", _get_rarity_color(rarity))

	# Value display
	if item_data.has("value"):
		var value: int = item_data.get("value", 0)
		_value_label.text = "%d CR" % value
		_value_label.visible = true
	else:
		_value_label.visible = false

	# Icon placeholder (using emoji for now - replace with TextureRect later)
	# TODO: Replace with actual item type icons when asset system is ready
	var item_type: String = item_data.get("type", "gear").to_lower()
	_set_icon_placeholder(item_type)

func _set_icon_placeholder(item_type: String) -> void:
	## Set placeholder icon based on item type (emoji fallback)
	# For now, we'll use a ColorRect as a placeholder
	# In production, this would load actual item icons
	var placeholder := ColorRect.new()
	placeholder.custom_minimum_size = Vector2(32, 32)

	# Color by item type
	match item_type:
		"weapon":
			placeholder.color = Color("#ef4444")  # Red
		"armor":
			placeholder.color = Color("#3b82f6")  # Blue
		"gear":
			placeholder.color = Color("#10b981")  # Green
		"consumable":
			placeholder.color = Color("#f59e0b")  # Amber
		"credits":
			placeholder.color = Color("#fbbf24")  # Yellow
		_:
			placeholder.color = COLOR_BORDER

	# Clear existing icon children and add placeholder
	for child in _item_icon.get_children():
		child.queue_free()
	_item_icon.add_child(placeholder)

func _get_rarity_color(rarity: String) -> Color:
	## Get color for rarity level
	match rarity:
		"uncommon":
			return RARITY_UNCOMMON
		"rare":
			return RARITY_RARE
		"epic":
			return RARITY_EPIC
		"legendary":
			return RARITY_LEGENDARY
		_:  # "common" or unknown
			return RARITY_COMMON
