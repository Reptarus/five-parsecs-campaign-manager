extends PanelContainer
class_name InjuryResultCard

## Injury Result Card Component
## Displays crew injury with recovery timeline for post-battle system
## Mobile-optimized with 48px minimum touch targets
## Signal architecture: call-down-signal-up pattern

# ============ SIGNALS (Up Communication) ============
signal crew_selected(crew_id: String)

# ============ CONSTANTS (Design System) ============
const SPACING_SM := 8
const SPACING_MD := 16

const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16

const TOUCH_TARGET_MIN := 48

# Color Palette - Deep Space Theme
const COLOR_SECONDARY := Color("#111827")
const COLOR_BORDER := Color("#374151")
const COLOR_WARNING := Color("#f59e0b")  # Minor injury (amber)
const COLOR_DANGER := Color("#ef4444")   # Serious injury (red)
const COLOR_CRITICAL := Color("#991b1b") # Critical/Fatal (dark red)
const COLOR_TEXT_PRIMARY := Color("#f3f4f6")
const COLOR_TEXT_SECONDARY := Color("#9ca3af")

# ============ PROPERTIES ============
var injury_data: Dictionary = {}

# ============ NODE REFERENCES ============
@onready var _portrait: ColorRect = null
@onready var _crew_name_label: Label = null
@onready var _injury_type_label: Label = null
@onready var _recovery_time_label: Label = null
@onready var _severity_icon: ColorRect = null

# ============ LIFECYCLE ============
func _ready() -> void:
	custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	_setup_card_style()
	_build_layout()

func _gui_input(event: InputEvent) -> void:
	"""Handle touch/click input for crew selection"""
	var is_tap := false
	if event is InputEventScreenTouch:
		is_tap = event.pressed
	elif event is InputEventMouseButton:
		is_tap = event.pressed and event.button_index == MOUSE_BUTTON_LEFT

	if is_tap and injury_data.has("crew_id"):
		crew_selected.emit(injury_data["crew_id"])

# ============ PUBLIC INTERFACE (Call Down) ============
func setup(data: Dictionary) -> void:
	"""
	Setup injury card with data
	Expected fields:
	- crew_id: String
	- crew_name: String
	- injury_type: String
	- severity: String (minor, serious, critical)
	- recovery_turns: int
	- is_fatal: bool
	"""
	if not data.has("crew_id") or not data.has("crew_name"):
		push_error("InjuryResultCard: Invalid data - missing crew_id or crew_name")
		return

	injury_data = data

	# Update display if nodes exist (after _ready)
	if _crew_name_label != null:
		_update_display()

# ============ PRIVATE METHODS ============
func _setup_card_style() -> void:
	"""Apply glass morphism card styling"""
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, 0.8)
	style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(SPACING_MD)
	add_theme_stylebox_override("panel", style)

func _build_layout() -> void:
	"""Build card layout structure"""
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_MD)
	add_child(hbox)

	# Character Portrait (48x48 placeholder)
	_portrait = ColorRect.new()
	_portrait.custom_minimum_size = Vector2(48, 48)
	_portrait.color = Color("#374151")  # Gray placeholder
	hbox.add_child(_portrait)

	# Info VBox (name, injury type, recovery time)
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# Crew Name (FONT_SIZE_MD - 16)
	_crew_name_label = Label.new()
	_crew_name_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	_crew_name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	info_vbox.add_child(_crew_name_label)

	# Injury Type (colored by severity)
	_injury_type_label = Label.new()
	_injury_type_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	info_vbox.add_child(_injury_type_label)

	# Recovery Time
	_recovery_time_label = Label.new()
	_recovery_time_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_recovery_time_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	info_vbox.add_child(_recovery_time_label)

	# Severity Icon (color-coded indicator)
	_severity_icon = ColorRect.new()
	_severity_icon.custom_minimum_size = Vector2(12, 12)
	hbox.add_child(_severity_icon)

func _update_display() -> void:
	"""Update card display with injury data"""
	if not injury_data or injury_data.is_empty():
		return

	# Update crew name
	if _crew_name_label:
		_crew_name_label.text = injury_data.get("crew_name", "Unknown")

	# Update injury type with color-coded severity
	if _injury_type_label:
		var injury_type: String = injury_data.get("injury_type", "Unknown Injury")
		var severity: String = injury_data.get("severity", "minor").to_lower()
		var color := _get_severity_color(severity)

		_injury_type_label.text = injury_type
		_injury_type_label.add_theme_color_override("font_color", color)

	# Update recovery time or FATAL indicator
	if _recovery_time_label:
		var is_fatal: bool = injury_data.get("is_fatal", false)
		if is_fatal:
			_recovery_time_label.text = "FATAL"
			_recovery_time_label.add_theme_color_override("font_color", COLOR_CRITICAL)
		else:
			var recovery_turns: int = injury_data.get("recovery_turns", 0)
			var turns_text := "turn" if recovery_turns == 1 else "turns"
			_recovery_time_label.text = "Recovers in %d %s" % [recovery_turns, turns_text]
			_recovery_time_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

	# Update severity icon color
	if _severity_icon:
		var severity: String = injury_data.get("severity", "minor").to_lower()
		var is_fatal: bool = injury_data.get("is_fatal", false)

		if is_fatal:
			_severity_icon.color = COLOR_CRITICAL
		else:
			_severity_icon.color = _get_severity_color(severity)

func _get_severity_color(severity: String) -> Color:
	"""Get color based on injury severity"""
	match severity.to_lower():
		"minor":
			return COLOR_WARNING  # Amber
		"serious":
			return COLOR_DANGER   # Red
		"critical":
			return COLOR_CRITICAL # Dark red
		_:
			return COLOR_WARNING  # Default to amber
