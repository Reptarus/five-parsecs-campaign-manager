class_name GalacticWarProgressPanel
extends PanelContainer

## Galactic War Progress Display Component
##
## Mobile-first UI component for displaying active galactic war tracks.
## Shows progress bars, next thresholds, and active effects.
## Touch-optimized with 48dp minimum touch targets.

## Signals

signal war_details_requested(track_id: String)
signal help_requested()

## Design System Constants (from BaseCampaignPanel)

const SPACING_XS := 4
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24
const SPACING_XL := 32

const TOUCH_TARGET_MIN := 48
const TOUCH_TARGET_COMFORT := 56

const FONT_SIZE_XS := 11
const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18
const FONT_SIZE_XL := 24

const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_INPUT := Color("#1E1E36")
const COLOR_BORDER := Color("#3A3A5C")

const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_ACCENT_HOVER := Color("#3A7199")

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")

const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")

## State

var war_manager: GalacticWarManager = null
var expanded_tracks: Dictionary = {}  # track_id -> bool
var main_container: VBoxContainer = null

## Initialization

func _ready() -> void:
	_setup_ui()
	_connect_to_war_manager()

func _setup_ui() -> void:
	"""Initialize UI structure"""
	# Panel styling
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = SPACING_MD
	style.content_margin_right = SPACING_MD
	style.content_margin_top = SPACING_MD
	style.content_margin_bottom = SPACING_MD
	add_theme_stylebox_override("panel", style)
	
	# Main container
	main_container = VBoxContainer.new()
	main_container.add_theme_constant_override("separation", SPACING_LG)
	add_child(main_container)
	
	# Header
	var header = _create_header()
	main_container.add_child(header)
	
	# Tracks container (populated on refresh)
	var tracks_container = VBoxContainer.new()
	tracks_container.name = "TracksContainer"
	tracks_container.add_theme_constant_override("separation", SPACING_LG)
	main_container.add_child(tracks_container)

func _create_header() -> HBoxContainer:
	"""Create panel header with title and help button"""
	var header = HBoxContainer.new()
	
	var title = Label.new()
	title.text = "Galactic War Status"
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	var help_btn = Button.new()
	help_btn.text = "?"
	help_btn.custom_minimum_size = Vector2(TOUCH_TARGET_MIN, TOUCH_TARGET_MIN)
	help_btn.tooltip_text = "Learn about Galactic War mechanics"
	help_btn.pressed.connect(_on_help_pressed)
	header.add_child(help_btn)
	
	return header

func _connect_to_war_manager() -> void:
	"""Connect to GalacticWarManager autoload"""
	war_manager = get_node_or_null("/root/GalacticWarManager")
	
	if not war_manager:
		push_warning("GalacticWarProgressPanel: GalacticWarManager not found")
		return
	
	# Connect signals
	if war_manager.has_signal("war_track_advanced"):
		war_manager.war_track_advanced.connect(_on_war_track_advanced)
	if war_manager.has_signal("war_threshold_reached"):
		war_manager.war_threshold_reached.connect(_on_war_threshold_reached)
	if war_manager.has_signal("war_track_activated"):
		war_manager.war_track_activated.connect(_on_war_track_activated)
	
	print("GalacticWarProgressPanel: Connected to GalacticWarManager")

## Public API

func refresh_display() -> void:
	"""Refresh the war tracks display"""
	if not war_manager:
		return
	
	var tracks_container = main_container.get_node_or_null("TracksContainer")
	if not tracks_container:
		return
	
	# Clear existing tracks
	for child in tracks_container.get_children():
		child.queue_free()
	
	# Get active war tracks
	var active_tracks = war_manager.get_active_war_tracks()
	
	if active_tracks.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No active galactic conflicts"
		empty_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
		empty_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		tracks_container.add_child(empty_label)
		return
	
	# Create card for each active track
	for track_data in active_tracks:
		var track_card = _create_war_track_card(track_data)
		tracks_container.add_child(track_card)

func _create_war_track_card(track: Dictionary) -> PanelContainer:
	"""Create a war track display card"""
	var panel = PanelContainer.new()
	
	# Card styling
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BASE
	style.border_color = _get_track_color(track.get("id", ""))
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = SPACING_MD
	style.content_margin_right = SPACING_MD
	style.content_margin_top = SPACING_SM
	style.content_margin_bottom = SPACING_SM
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	panel.add_child(vbox)
	
	# Header (track name + progress)
	var header = _create_track_header(track)
	vbox.add_child(header)
	
	# Progress bar
	var progress_bar = _create_progress_bar(track)
	vbox.add_child(progress_bar)
	
	# Next threshold info
	var next_threshold = _create_next_threshold(track)
	vbox.add_child(next_threshold)
	
	# Active effects (if any)
	var effects = _create_active_effects(track)
	if effects:
		vbox.add_child(effects)
	
	return panel

func _create_track_header(track: Dictionary) -> HBoxContainer:
	"""Create track header with name and progress value"""
	var header = HBoxContainer.new()
	header.custom_minimum_size.y = TOUCH_TARGET_MIN  # Touch target compliance
	
	var name_label = Label.new()
	name_label.text = track.get("name", "Unknown War")
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(name_label)
	
	var progress_label = Label.new()
	var current = track.get("current_progress", 0)
	var max_progress = track.get("max_progress", 20)
	progress_label.text = "[%d/%d]" % [current, max_progress]
	progress_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	progress_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	progress_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(progress_label)
	
	return header

func _create_progress_bar(track: Dictionary) -> ProgressBar:
	"""Create progress bar with threshold markers"""
	var progress_bar = ProgressBar.new()
	
	var current = track.get("current_progress", 0)
	var max_progress = track.get("max_progress", 20)
	
	progress_bar.min_value = 0
	progress_bar.max_value = max_progress
	progress_bar.value = current
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size.y = 8  # 8px height per spec
	
	# Styling
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = _get_track_color(track.get("id", ""))
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = COLOR_INPUT
	progress_bar.add_theme_stylebox_override("background", bg_style)
	
	return progress_bar

func _create_next_threshold(track: Dictionary) -> Label:
	"""Create label showing next threshold"""
	var label = Label.new()
	label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	
	var current = track.get("current_progress", 0)
	var thresholds = track.get("thresholds", {})
	
	# Find next threshold
	var next_threshold = null
	var next_value = 999
	
	for threshold_key in thresholds.keys():
		var threshold_int = int(threshold_key)
		if threshold_int > current and threshold_int < next_value:
			next_value = threshold_int
			next_threshold = thresholds[threshold_key]
	
	if next_threshold:
		label.text = "Next: %s (%d)" % [next_threshold.get("name", "Unknown"), next_value]
	else:
		label.text = "Maximum progress reached"
		label.add_theme_color_override("font_color", COLOR_WARNING)
	
	return label

func _create_active_effects(track: Dictionary) -> PanelContainer:
	"""Create panel showing active effects from this track"""
	var track_id = track.get("id", "")
	var current = track.get("current_progress", 0)
	var thresholds = track.get("thresholds", {})
	
	# Find current threshold
	var current_threshold = null
	var current_threshold_value = 0
	
	for threshold_key in thresholds.keys():
		var threshold_int = int(threshold_key)
		if threshold_int <= current and threshold_int > current_threshold_value:
			current_threshold_value = threshold_int
			current_threshold = thresholds[threshold_key]
	
	if not current_threshold or not "effects" in current_threshold:
		return null
	
	# Create effects panel
	var effects_panel = PanelContainer.new()
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(COLOR_WARNING.r, COLOR_WARNING.g, COLOR_WARNING.b, 0.2)
	style.border_color = COLOR_WARNING
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = SPACING_SM
	style.content_margin_right = SPACING_SM
	style.content_margin_top = SPACING_SM
	style.content_margin_bottom = SPACING_SM
	effects_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_XS)
	effects_panel.add_child(vbox)
	
	# Icon + header
	var header = HBoxContainer.new()
	var icon_label = Label.new()
	icon_label.text = "⚠️"
	icon_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	header.add_child(icon_label)
	
	var header_label = Label.new()
	header_label.text = current_threshold.get("name", "Active Effects")
	header_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	header_label.add_theme_color_override("font_color", COLOR_WARNING)
	header.add_child(header_label)
	vbox.add_child(header)
	
	# Effect description
	var desc_label = Label.new()
	desc_label.text = current_threshold.get("description", "")
	desc_label.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	desc_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	
	return effects_panel

func _get_track_color(track_id: String) -> Color:
	"""Get color scheme for war track"""
	match track_id:
		"unity_expansion":
			return Color("#2D5A7B")
		"corporate_war":
			return Color("#7B522D")
		"alien_incursion":
			return Color("#5A2D7B")
		"pirate_uprising":
			return Color("#7B2D2D")
		_:
			return COLOR_ACCENT

## Signal Handlers

func _on_war_track_advanced(_track_id: String, _new_value: int, _old_value: int) -> void:
	"""Handle war track advancement"""
	refresh_display()

func _on_war_threshold_reached(track_id: String, threshold: int, event_data: Dictionary) -> void:
	"""Handle threshold reached event"""
	refresh_display()
	
	# Could show notification popup here
	print("GalacticWarProgressPanel: Threshold reached - %s at %d" % [track_id, threshold])

func _on_war_track_activated(track_id: String) -> void:
	"""Handle new war track activation"""
	refresh_display()
	print("GalacticWarProgressPanel: New war track activated - %s" % track_id)

func _on_help_pressed() -> void:
	"""Handle help button press"""
	help_requested.emit()
