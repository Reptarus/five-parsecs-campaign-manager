extends PanelContainer
class_name StoryTrackSection

## Story Track Section Component
## Displays quest progress, milestones, and narrative state
## Part of Campaign Dashboard UI modernization (Phase 3c)

# Design constants from BaseCampaignPanel
const SPACING_XS := 4
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24
const FONT_SIZE_XS := 11
const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18

# Color palette - Deep Space Theme
const COLOR_SECONDARY := Color("#111827")
const COLOR_TERTIARY := Color("#1f2937")
const COLOR_BORDER := Color("#374151")
const COLOR_PURPLE := Color("#8b5cf6")      # Story track accent
const COLOR_EMERALD := Color("#10b981")     # Completed milestones
const COLOR_TEXT_PRIMARY := Color("#f3f4f6")
const COLOR_TEXT_SECONDARY := Color("#9ca3af")

# Signals
signal story_details_requested()

# UI References
var main_vbox: VBoxContainer
var header_hbox: HBoxContainer
var book_icon: Label
var title_label: Label
var progress_bar: ProgressBar
var milestones_container: HBoxContainer
var current_quest_label: Label
var next_objective_label: Label

# Story track data
var story_progress: float = 0.0  # 0-100 percentage
var total_milestones: int = 5
var completed_milestones: int = 0
var current_quest: String = "No active quest"
var next_objective: String = ""


func _ready() -> void:
	_setup_ui()
	_apply_glass_style()


func _setup_ui() -> void:
	"""Build the story track section UI"""
	# Main container
	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", SPACING_SM)
	add_child(main_vbox)

	# Header: Book Icon + "Story Track"
	header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", SPACING_SM)
	main_vbox.add_child(header_hbox)

	book_icon = Label.new()
	book_icon.text = "📖"
	book_icon.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	book_icon.add_theme_color_override("font_color", COLOR_PURPLE)
	header_hbox.add_child(book_icon)

	title_label = Label.new()
	title_label.text = "STORY TRACK"
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_label)

	# Progress Bar (purple gradient theme)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 12)
	progress_bar.show_percentage = false
	progress_bar.value = 0
	_style_progress_bar()
	main_vbox.add_child(progress_bar)

	# Milestone Markers
	milestones_container = HBoxContainer.new()
	milestones_container.add_theme_constant_override("separation", 4)
	milestones_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_create_milestone_markers()
	main_vbox.add_child(milestones_container)

	# Current Quest Name
	current_quest_label = Label.new()
	current_quest_label.text = current_quest
	current_quest_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	current_quest_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	current_quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(current_quest_label)

	# Next Objective
	next_objective_label = Label.new()
	next_objective_label.text = next_objective
	next_objective_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	next_objective_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	next_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(next_objective_label)

	# Make card clickable
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func _apply_glass_style() -> void:
	"""Apply glass morphism styling with purple accent"""
	var style := StyleBoxFlat.new()

	# Semi-transparent background with slight purple tint
	var bg_color := COLOR_SECONDARY
	bg_color = bg_color.lerp(COLOR_PURPLE, 0.05)  # Subtle purple tint
	style.bg_color = Color(bg_color.r, bg_color.g, bg_color.b, 0.8)

	# Purple-tinted border
	style.border_color = Color(COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b, 0.3)
	style.set_border_width_all(1)

	# Rounded corners
	style.set_corner_radius_all(16)

	# Padding
	style.set_content_margin_all(SPACING_MD)

	add_theme_stylebox_override("panel", style)


func _style_progress_bar() -> void:
	"""Apply purple gradient styling to progress bar"""
	# Background
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = COLOR_BORDER
	bg_style.set_corner_radius_all(6)
	progress_bar.add_theme_stylebox_override("background", bg_style)

	# Fill (purple gradient effect)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = COLOR_PURPLE
	fill_style.set_corner_radius_all(6)
	progress_bar.add_theme_stylebox_override("fill", fill_style)


func _create_milestone_markers() -> void:
	"""Create milestone circles on a connecting line"""
	# Clear existing markers
	for child in milestones_container.get_children():
		child.queue_free()

	# Create milestone indicators
	for i in range(total_milestones):
		var milestone := PanelContainer.new()
		milestone.custom_minimum_size = Vector2(32, 32)

		# Style based on completion status
		var style := StyleBoxFlat.new()
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL

		if i < completed_milestones:
			# Completed milestone - green with checkmark
			style.bg_color = COLOR_EMERALD
			label.text = "✓"
			label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
			label.add_theme_color_override("font_color", Color.WHITE)
		elif i == completed_milestones:
			# Current milestone - purple with number
			style.bg_color = COLOR_PURPLE
			label.text = str(i + 1)
			label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
			label.add_theme_color_override("font_color", Color.WHITE)
		else:
			# Future milestone - gray with number
			style.bg_color = COLOR_BORDER
			label.text = str(i + 1)
			label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
			label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

		style.set_corner_radius_all(16)  # Circular
		milestone.add_theme_stylebox_override("panel", style)
		milestone.add_child(label)
		milestones_container.add_child(milestone)


func _on_gui_input(event: InputEvent) -> void:
	"""Handle click on section to show story details"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			story_details_requested.emit()
			print("StoryTrackSection: Story details requested")


## Public API for setting story data

func set_story_data(data: Dictionary) -> void:
	"""Update section with story track data"""
	current_quest = data.get("quest_name", "No active quest")
	next_objective = data.get("next_objective", "")
	completed_milestones = data.get("milestones_completed", 0)
	total_milestones = data.get("milestones_total", 5)

	# Calculate progress percentage
	if total_milestones > 0:
		story_progress = (float(completed_milestones) / float(total_milestones)) * 100.0
	else:
		story_progress = 0.0

	_update_display()


func _update_display() -> void:
	"""Refresh UI with current story data"""
	if not is_inside_tree():
		return

	current_quest_label.text = current_quest

	# Format next objective with prefix
	if next_objective.is_empty():
		next_objective_label.text = ""
		next_objective_label.hide()
	else:
		next_objective_label.text = "Next: " + next_objective
		next_objective_label.show()

	# Update progress bar
	progress_bar.value = story_progress

	# Recreate milestone markers
	_create_milestone_markers()


func set_progress(completed: int, total: int) -> void:
	"""Update milestone progress"""
	completed_milestones = clampi(completed, 0, total)
	total_milestones = maxi(total, 1)

	if total_milestones > 0:
		story_progress = (float(completed_milestones) / float(total_milestones)) * 100.0

	_update_display()


func set_current_quest(quest_name: String, objective: String = "") -> void:
	"""Update current quest and objective text"""
	current_quest = quest_name
	next_objective = objective
	_update_display()


func clear_story() -> void:
	"""Clear story data and show inactive state"""
	current_quest = "No active quest"
	next_objective = ""
	completed_milestones = 0
	story_progress = 0.0
	_update_display()
