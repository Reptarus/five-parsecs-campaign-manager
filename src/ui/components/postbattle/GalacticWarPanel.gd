class_name GalacticWarPanel
extends PanelContainer

## Galactic War Status Panel for Post-Battle Sequence
##
## Displays active war tracks with progress bars, thresholds, and narrative effects.
## Mobile-optimized with 48dp touch targets and responsive design.
## Shows campaign-ending warnings when tracks approach maximum progress.

## Signals

signal war_panel_closed()
signal war_track_selected(track_id: String)

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
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")

const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")
const COLOR_SUCCESS := Color("#10B981")

## Campaign Ending Thresholds

const CRITICAL_THRESHOLD := 8  # Warning at threshold 8/10
const MAX_THRESHOLD := 10      # Campaign ending at 10/10

## State

var war_manager: GalacticWarManager = null
var war_events: Array[Dictionary] = []
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
	style.set_corner_radius_all(8)
	style.content_margin_left = SPACING_LG
	style.content_margin_right = SPACING_LG
	style.content_margin_top = SPACING_LG
	style.content_margin_bottom = SPACING_LG
	add_theme_stylebox_override("panel", style)
	
	# Main container
	main_container = VBoxContainer.new()
	main_container.add_theme_constant_override("separation", SPACING_LG)
	add_child(main_container)
	
	# Header
	var header = _create_header()
	main_container.add_child(header)
	
	# Scroll container for war tracks
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 200
	main_container.add_child(scroll)
	
	# Tracks container
	var tracks_container = VBoxContainer.new()
	tracks_container.name = "TracksContainer"
	tracks_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracks_container.add_theme_constant_override("separation", SPACING_MD)
	scroll.add_child(tracks_container)
	
	# Footer with close button
	var footer = _create_footer()
	main_container.add_child(footer)

func _create_header() -> VBoxContainer:
	"""Create panel header with title and description"""
	var header = VBoxContainer.new()
	header.add_theme_constant_override("separation", SPACING_SM)
	
	var title = Label.new()
	title.text = "Galactic War Status"
	title.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	header.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Large-scale conflicts affecting the sector"
	subtitle.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	subtitle.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(subtitle)
	
	# Separator
	var sep = HSeparator.new()
	sep.modulate = COLOR_BORDER
	header.add_child(sep)
	
	return header

func _create_footer() -> HBoxContainer:
	"""Create footer with close button"""
	var footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var close_btn = Button.new()
	close_btn.text = "Continue"
	close_btn.custom_minimum_size = Vector2(200, TOUCH_TARGET_MIN)
	close_btn.pressed.connect(_on_close_pressed)
	footer.add_child(close_btn)
	
	return footer

func _connect_to_war_manager() -> void:
	"""Connect to GalacticWarManager autoload"""
	war_manager = get_node_or_null("/root/GalacticWarManager")
	
	if not war_manager:
		push_warning("GalacticWarPanel: GalacticWarManager not found")
		return
	
	print("GalacticWarPanel: Connected to GalacticWarManager")

## Public API

func setup(events: Array) -> void:
	"""Setup panel with war progression events"""
	war_events = events.duplicate()
	refresh_display()

func refresh_display() -> void:
	"""Refresh the war tracks display"""
	if not war_manager:
		_show_no_war_manager_message()
		return
	
	var tracks_container = main_container.find_child("TracksContainer", true, false)
	if not tracks_container:
		return
	
	# Clear existing tracks
	for child in tracks_container.get_children():
		child.queue_free()
	
	# Get active war tracks
	var active_tracks = war_manager.get_active_war_tracks()
	
	if active_tracks.is_empty():
		_show_no_active_wars(tracks_container)
		return
	
	# Show turn events summary if any
	if war_events.size() > 0:
		var events_summary = _create_events_summary()
		tracks_container.add_child(events_summary)
	
	# Create card for each active track
	for track_data in active_tracks:
		var track_card = _create_war_track_card(track_data)
		tracks_container.add_child(track_card)

func _show_no_war_manager_message() -> void:
	"""Show error message when GalacticWarManager not available"""
	var tracks_container = main_container.find_child("TracksContainer", true, false)
	if not tracks_container:
		return
	
	for child in tracks_container.get_children():
		child.queue_free()
	
	var error_label = Label.new()
	error_label.text = "⚠️ Galactic War Manager not available"
	error_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	error_label.add_theme_color_override("font_color", COLOR_WARNING)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tracks_container.add_child(error_label)

func _show_no_active_wars(container: VBoxContainer) -> void:
	"""Show peaceful status when no wars active"""
	var peaceful_panel = PanelContainer.new()
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(COLOR_SUCCESS.r, COLOR_SUCCESS.g, COLOR_SUCCESS.b, 0.2)
	style.border_color = COLOR_SUCCESS
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = SPACING_MD
	style.content_margin_right = SPACING_MD
	style.content_margin_top = SPACING_MD
	style.content_margin_bottom = SPACING_MD
	peaceful_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	
	var icon_label = Label.new()
	icon_label.text = "✨"
	icon_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon_label)
	
	var message = Label.new()
	message.text = "No Active Galactic Conflicts"
	message.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	message.add_theme_color_override("font_color", COLOR_SUCCESS)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(message)
	
	var desc = Label.new()
	desc.text = "The sector enjoys a rare period of relative peace. Enjoy it while it lasts."
	desc.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)
	
	peaceful_panel.add_child(vbox)
	container.add_child(peaceful_panel)

func _create_events_summary() -> PanelContainer:
	"""Create summary of this turn's war events"""
	var panel = PanelContainer.new()
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(COLOR_WARNING.r, COLOR_WARNING.g, COLOR_WARNING.b, 0.2)
	style.border_color = COLOR_WARNING
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = SPACING_MD
	style.content_margin_right = SPACING_MD
	style.content_margin_top = SPACING_MD
	style.content_margin_bottom = SPACING_MD
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	
	var header = Label.new()
	header.text = "📰 This Turn's Events"
	header.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	header.add_theme_color_override("font_color", COLOR_WARNING)
	vbox.add_child(header)
	
	for event in war_events:
		var event_label = Label.new()
		event_label.text = "• " + _format_event_text(event)
		event_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		event_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(event_label)
	
	panel.add_child(vbox)
	return panel

func _format_event_text(event: Dictionary) -> String:
	"""Format event data into readable text"""
	var event_type = event.get("type", "unknown")
	
	match event_type:
		"war_advancement_roll":
			var track_name = event.get("track_name", "Unknown War")
			var roll = event.get("roll", 0)
			var advanced = event.get("advanced", false)
			if advanced:
				return "%s advanced (rolled %d)" % [track_name, roll]
			else:
				return "%s held steady (rolled %d)" % [track_name, roll]
		
		"war_threshold":
			var track_name = event.get("track_name", "Unknown War")
			var threshold_name = event.get("event_name", "Threshold")
			return "⚠️ %s: %s" % [track_name, threshold_name]
		
		"war_track_activated":
			var track_name = event.get("track_name", "Unknown War")
			return "🚨 NEW CONFLICT: %s has begun!" % track_name
		
		_:
			return "Galactic event occurred"

func _create_war_track_card(track: Dictionary) -> PanelContainer:
	"""Create a war track display card"""
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Card styling - use danger color for critical tracks
	var current = track.get("current_progress", 0)
	var is_critical = current >= CRITICAL_THRESHOLD
	
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BASE
	style.border_color = COLOR_DANGER if is_critical else _get_track_color(track.get("faction", ""))
	style.set_border_width_all(2 if is_critical else 1)
	style.set_corner_radius_all(6)
	style.content_margin_left = SPACING_MD
	style.content_margin_right = SPACING_MD
	style.content_margin_top = SPACING_MD
	style.content_margin_bottom = SPACING_MD
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	panel.add_child(vbox)
	
	# Critical warning banner
	if is_critical:
		var warning = _create_critical_warning(track)
		vbox.add_child(warning)
	
	# Header (track name + faction)
	var header = _create_track_header(track)
	vbox.add_child(header)
	
	# Progress bar with current/max display
	var progress_section = _create_progress_section(track)
	vbox.add_child(progress_section)
	
	# Current threshold effects (narrative)
	var current_effects = _create_current_threshold_display(track)
	if current_effects:
		vbox.add_child(current_effects)
	
	# Next threshold preview
	var next_threshold = _create_next_threshold_preview(track)
	if next_threshold:
		vbox.add_child(next_threshold)
	
	return panel

func _create_critical_warning(track: Dictionary) -> PanelContainer:
	"""Create critical warning banner for near-ending tracks"""
	var panel = PanelContainer.new()
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(COLOR_DANGER.r, COLOR_DANGER.g, COLOR_DANGER.b, 0.3)
	style.border_color = COLOR_DANGER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = SPACING_SM
	style.content_margin_right = SPACING_SM
	style.content_margin_top = SPACING_SM
	style.content_margin_bottom = SPACING_SM
	panel.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = "⚠️ CRITICAL - Campaign ending imminent!"
	label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	label.add_theme_color_override("font_color", COLOR_DANGER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	
	return panel

func _create_track_header(track: Dictionary) -> VBoxContainer:
	"""Create track header with name and faction"""
	var header = VBoxContainer.new()
	header.add_theme_constant_override("separation", SPACING_XS)
	
	var name_label = Label.new()
	name_label.text = track.get("name", "Unknown War")
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	header.add_child(name_label)
	
	var faction_label = Label.new()
	faction_label.text = "Faction: " + track.get("faction", "Unknown")
	faction_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	faction_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	header.add_child(faction_label)
	
	var desc_label = Label.new()
	desc_label.text = track.get("description", "")
	desc_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	desc_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(desc_label)
	
	return header

func _create_progress_section(track: Dictionary) -> VBoxContainer:
	"""Create progress bar with labels"""
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", SPACING_XS)
	
	# Progress label
	var current = track.get("current_progress", 0)
	var max_progress = track.get("max_progress", 10)
	
	var label = Label.new()
	label.text = "Progress: %d / %d" % [current, max_progress]
	label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	section.add_child(label)
	
	# Progress bar
	var progress_bar = ProgressBar.new()
	progress_bar.min_value = 0
	progress_bar.max_value = max_progress
	progress_bar.value = current
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size.y = 12
	
	# Color based on danger level
	var fill_style = StyleBoxFlat.new()
	if current >= CRITICAL_THRESHOLD:
		fill_style.bg_color = COLOR_DANGER
	elif current >= 5:
		fill_style.bg_color = COLOR_WARNING
	else:
		fill_style.bg_color = _get_track_color(track.get("faction", ""))
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = COLOR_INPUT
	progress_bar.add_theme_stylebox_override("background", bg_style)
	
	section.add_child(progress_bar)
	
	return section

func _create_current_threshold_display(track: Dictionary) -> PanelContainer:
	"""Display current threshold effects and narrative"""
	var current = track.get("current_progress", 0)
	var thresholds = track.get("thresholds", {})
	
	# Find highest reached threshold
	var current_threshold = null
	var current_threshold_value = 0
	
	for threshold_key in thresholds.keys():
		var threshold_int = int(threshold_key)
		if threshold_int <= current and threshold_int > current_threshold_value:
			current_threshold_value = threshold_int
			current_threshold = thresholds[threshold_key]
	
	if not current_threshold:
		return null
	
	var panel = PanelContainer.new()
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(COLOR_WARNING.r, COLOR_WARNING.g, COLOR_WARNING.b, 0.15)
	style.border_color = COLOR_WARNING
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = SPACING_SM
	style.content_margin_right = SPACING_SM
	style.content_margin_top = SPACING_SM
	style.content_margin_bottom = SPACING_SM
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_XS)
	
	var header = Label.new()
	header.text = "Current Status: " + current_threshold.get("name", "Active")
	header.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	header.add_theme_color_override("font_color", COLOR_WARNING)
	vbox.add_child(header)
	
	var narrative = Label.new()
	narrative.text = current_threshold.get("narrative", current_threshold.get("description", ""))
	narrative.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	narrative.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	narrative.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(narrative)
	
	panel.add_child(vbox)
	return panel

func _create_next_threshold_preview(track: Dictionary) -> PanelContainer:
	"""Show preview of next threshold"""
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
	
	if not next_threshold:
		return null
	
	var panel = PanelContainer.new()
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(COLOR_INPUT.r, COLOR_INPUT.g, COLOR_INPUT.b, 0.5)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = SPACING_SM
	style.content_margin_right = SPACING_SM
	style.content_margin_top = SPACING_SM
	style.content_margin_bottom = SPACING_SM
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_XS)
	
	var header = Label.new()
	header.text = "Next at %d: %s" % [next_value, next_threshold.get("name", "Unknown")]
	header.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	header.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(header)
	
	var desc = Label.new()
	desc.text = next_threshold.get("description", "")
	desc.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)
	
	panel.add_child(vbox)
	return panel

func _get_track_color(faction: String) -> Color:
	"""Get color scheme for faction"""
	match faction:
		"Unity":
			return Color("#5A7B9E")  # Cool blue-gray
		"Converted":
			return Color("#9E5A7B")  # Sickly purple
		"Swarm":
			return Color("#7B9E5A")  # Organic green
		"Corporations":
			return Color("#9E8E5A")  # Gold/corporate
		"Pirates":
			return Color("#9E5A5A")  # Blood red
		"Precursors":
			return Color("#7A5A9E")  # Mysterious purple
		_:
			return COLOR_ACCENT

## Signal Handlers

func _on_close_pressed() -> void:
	"""Handle close button press"""
	war_panel_closed.emit()
	print("GalacticWarPanel: Panel closed")
