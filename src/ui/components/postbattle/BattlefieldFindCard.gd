extends PanelContainer
class_name BattlefieldFindCard

## Battlefield Find Result Card - Post-Battle System
## Displays a single battlefield find with narrative description and actions
## Based on Five Parsecs Core Rulebook p.66 (Battlefield Finds Table)
##
## Usage: setup(find_data) where find_data contains:
##   - type: LootCategory enum value
##   - description: String (narrative text)
##   - credits: int (if applicable)
##   - item: String (item name if applicable)
##
## Signal Architecture: Signals up to parent when add to stash requested

# ============ SIGNALS ============
signal add_to_stash_requested(find_data: Dictionary)

# ============ CONSTANTS ============
const LootSystemConstants = preload("res://src/core/systems/LootSystemConstants.gd")

# Design System (from UIColors)
const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN

const COLOR_SECONDARY := UIColors.COLOR_SECONDARY
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_WARNING := UIColors.COLOR_WARNING       # Amber - Credits/Debris
const COLOR_SUCCESS := UIColors.COLOR_SUCCESS       # Green - Equipment
const COLOR_ACCENT := UIColors.COLOR_BLUE           # Blue - Quest/Info
const COLOR_BORDER := UIColors.COLOR_BORDER

# ============ PRIVATE VARIABLES ============
var _find_data: Dictionary = {}

# ============ @ONREADY REFERENCES ============
@onready var _main_vbox: VBoxContainer = $VBoxContainer
@onready var _header_row: HBoxContainer = $VBoxContainer/HeaderRow
@onready var _find_icon: ColorRect = $VBoxContainer/HeaderRow/FindIcon
@onready var _find_title: Label = $VBoxContainer/HeaderRow/FindTitle
@onready var _description_label: RichTextLabel = $VBoxContainer/DescriptionLabel
@onready var _value_row: HBoxContainer = $VBoxContainer/ValueRow
@onready var _add_to_stash_button: Button = $VBoxContainer/AddToStashButton

# ============ LIFECYCLE METHODS ============
func _ready() -> void:
	_setup_ui_structure()
	_connect_signals()

# ============ PUBLIC INTERFACE ============
func setup(find_data: Dictionary) -> void:
	## Configure card with battlefield find data
	##
	## Args:
	## find_data: Dictionary with keys:
	## - type: LootCategory enum
	## - description: String
	## - credits: int (optional)
	## - item: String (optional)
	_find_data = find_data
	_update_display()

# ============ PRIVATE HELPER METHODS ============
func _setup_ui_structure() -> void:
	## Programmatic UI setup fallback if scene missing nodes
	if not is_instance_valid(_main_vbox):
		_main_vbox = VBoxContainer.new()
		_main_vbox.name = "VBoxContainer"
		_main_vbox.add_theme_constant_override("separation", SPACING_SM)
		add_child(_main_vbox)

	if not is_instance_valid(_header_row):
		_header_row = HBoxContainer.new()
		_header_row.name = "HeaderRow"
		_header_row.add_theme_constant_override("separation", SPACING_SM)
		_main_vbox.add_child(_header_row)

		_find_icon = ColorRect.new()
		_find_icon.name = "FindIcon"
		_find_icon.custom_minimum_size = Vector2(24, 24)
		_header_row.add_child(_find_icon)

		_find_title = Label.new()
		_find_title.name = "FindTitle"
		_find_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_header_row.add_child(_find_title)

	if not is_instance_valid(_description_label):
		_description_label = RichTextLabel.new()
		_description_label.name = "DescriptionLabel"
		_description_label.bbcode_enabled = true
		_description_label.fit_content = true
		_description_label.scroll_active = false
		_description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_main_vbox.add_child(_description_label)

	if not is_instance_valid(_value_row):
		_value_row = HBoxContainer.new()
		_value_row.name = "ValueRow"
		_value_row.add_theme_constant_override("separation", SPACING_SM)
		_main_vbox.add_child(_value_row)

	if not is_instance_valid(_add_to_stash_button):
		_add_to_stash_button = Button.new()
		_add_to_stash_button.name = "AddToStashButton"
		_add_to_stash_button.text = "Add to Stash"
		_add_to_stash_button.custom_minimum_size.y = TOUCH_TARGET_MIN
		_add_to_stash_button.visible = false  # Hidden by default
		_main_vbox.add_child(_add_to_stash_button)

	# Apply panel styling
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SECONDARY
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	add_theme_stylebox_override("panel", style)

func _connect_signals() -> void:
	## Connect internal signals
	if is_instance_valid(_add_to_stash_button):
		_add_to_stash_button.pressed.connect(_on_add_to_stash_pressed)

func _update_display() -> void:
	## Update UI based on find_data
	var find_type: int = _find_data.get("type", LootSystemConstants.LootCategory.NOTHING)
	var description: String = _find_data.get("description", "")
	var credits: int = _find_data.get("credits", 0)
	var item: String = _find_data.get("item", "")

	# Configure header (icon color + title)
	var title: String = ""
	var icon_color := COLOR_TEXT_SECONDARY

	match find_type:
		LootSystemConstants.LootCategory.WEAPON:
			title = "Weapon Found!"
			icon_color = COLOR_SUCCESS
		LootSystemConstants.LootCategory.CONSUMABLE:
			title = "Usable Goods"
			icon_color = COLOR_SUCCESS
		LootSystemConstants.LootCategory.QUEST_RUMOR:
			title = "Curious Data Stick"
			icon_color = COLOR_ACCENT
		LootSystemConstants.LootCategory.SHIP_PART:
			title = "Starship Part"
			icon_color = COLOR_WARNING
		LootSystemConstants.LootCategory.TRINKET:
			title = "Personal Trinket"
			icon_color = COLOR_WARNING
		LootSystemConstants.LootCategory.DEBRIS:
			title = "Debris"
			icon_color = COLOR_WARNING
		LootSystemConstants.LootCategory.VITAL_INFO:
			title = "Vital Info"
			icon_color = COLOR_ACCENT
		LootSystemConstants.LootCategory.NOTHING:
			title = "Nothing Found"
			icon_color = COLOR_TEXT_SECONDARY

	_find_icon.color = icon_color
	_find_title.text = title
	_find_title.add_theme_font_size_override("font_size", 18)
	_find_title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

	# Configure description with BBCode colors
	var colored_desc := _colorize_description(description, find_type)
	_description_label.text = colored_desc

	# Configure value row
	_clear_value_row()

	if credits > 0:
		var credits_label := Label.new()
		credits_label.text = "[color=#f59e0b]%d Credits[/color]" % credits
		credits_label.add_theme_font_size_override("font_size", 16)
		credits_label.add_theme_color_override("font_color", COLOR_WARNING)
		_value_row.add_child(credits_label)

	if not item.is_empty():
		var item_label := Label.new()
		item_label.text = item
		item_label.add_theme_font_size_override("font_size", 16)
		item_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		_value_row.add_child(item_label)

	# Show Add to Stash button for applicable finds
	_add_to_stash_button.visible = _is_stashable(find_type)

func _colorize_description(description: String, find_type: int) -> String:
	## Add BBCode colors to description text
	var color_code := "#9ca3af"  # Default gray

	match find_type:
		LootSystemConstants.LootCategory.WEAPON, \
		LootSystemConstants.LootCategory.CONSUMABLE:
			color_code = "#10b981"  # Green
		LootSystemConstants.LootCategory.QUEST_RUMOR, \
		LootSystemConstants.LootCategory.VITAL_INFO:
			color_code = "#3b82f6"  # Blue
		LootSystemConstants.LootCategory.SHIP_PART, \
		LootSystemConstants.LootCategory.TRINKET, \
		LootSystemConstants.LootCategory.DEBRIS:
			color_code = "#f59e0b"  # Amber
		LootSystemConstants.LootCategory.NOTHING:
			color_code = "#6b7280"  # Muted gray

	return "[color=%s]%s[/color]" % [color_code, description]

func _is_stashable(find_type: int) -> bool:
	## Check if find type can be added to ship stash
	match find_type:
		LootSystemConstants.LootCategory.WEAPON, \
		LootSystemConstants.LootCategory.CONSUMABLE, \
		LootSystemConstants.LootCategory.SHIP_PART, \
		LootSystemConstants.LootCategory.TRINKET:
			return true
		_:
			return false

func _clear_value_row() -> void:
	## Remove all children from value row
	for child in _value_row.get_children():
		child.queue_free()

# ============ SIGNAL HANDLERS ============
func _on_add_to_stash_pressed() -> void:
	## Emit signal to parent when add to stash requested (call up, signal up)
	add_to_stash_requested.emit(_find_data)
	print("BattlefieldFindCard: Add to stash requested for: %s" % _find_data.get("item", "Unknown"))
