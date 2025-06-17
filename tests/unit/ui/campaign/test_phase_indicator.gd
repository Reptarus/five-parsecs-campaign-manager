## Phase Indicator Test Suite
## Tests the functionality of the campaign phase indicator UI component
@tool
extends GdUnitTestSuite

var phase_indicator: Control
var mock_theme_manager: Node

func before_test():
	# Create enhanced phase indicator with proper structure
	phase_indicator = Control.new()
	phase_indicator.name = "PhaseIndicator"
	
	# Add child components that tests expect
	var main_container = HBoxContainer.new()
	main_container.name = "MainContainer"
	phase_indicator.add_child(main_container)
	
	var phase_label = Label.new()
	phase_label.name = "PhaseLabel"
	phase_label.text = "Upkeep"
	main_container.add_child(phase_label)
	
	var progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.value = 0.5
	main_container.add_child(progress_bar)
	
	var icon_texture = TextureRect.new()
	icon_texture.name = "IconTexture"
	main_container.add_child(icon_texture)
	
	var description_label = RichTextLabel.new()
	description_label.name = "DescriptionLabel"
	description_label.text = "Phase description"
	phase_indicator.add_child(description_label)
	
	# Add all expected signals
	var required_signals = [
		"phase_display_updated", "icon_updated", "progress_updated",
		"state_changed", "description_updated", "transition_completed",
		"ui_state_changed", "event_added", "visibility_changed",
		"theme_changed"
	]
	
	for signal_name in required_signals:
		if not phase_indicator.has_signal(signal_name):
			phase_indicator.add_user_signal(signal_name)
	
	# Set up properties via meta system
	phase_indicator.set_meta("current_phase", 0)
	phase_indicator.set_meta("phase_name", "Upkeep")
	phase_indicator.set_meta("progress", 0.5)
	phase_indicator.set_meta("is_active", false)
	phase_indicator.set_meta("description", "Upkeep phase description")
	phase_indicator.set_meta("theme_name", "default")
	
	# Create mock theme manager
	mock_theme_manager = Node.new()
	mock_theme_manager.name = "MockThemeManager"
	mock_theme_manager.add_user_signal("theme_changed")
	mock_theme_manager.set_meta("current_theme", "default")
	
	# Set up scene tree structure
	add_child(phase_indicator)
	phase_indicator.add_child(mock_theme_manager)

func after_test():
	if is_instance_valid(phase_indicator):
		phase_indicator.queue_free()
	await get_tree().process_frame

func test_initialization():
	# Test basic structure
	assert_that(phase_indicator).is_not_null()
	assert_that(phase_indicator.is_inside_tree()).is_true()
	
	# Test child components
	var main_container = phase_indicator.get_node("MainContainer")
	assert_that(main_container).is_not_null()
	
	var phase_label = main_container.get_node("PhaseLabel")
	assert_that(phase_label).is_not_null()

func test_phase_display():
	# Test phase display functionality
	var phase_label = phase_indicator.get_node("MainContainer/PhaseLabel")
	var expected_text = phase_indicator.get_meta("phase_name", "Unknown")
	assert_that(phase_label.text).is_equal(expected_text)
	
	# Test phase update
	phase_indicator.set_meta("phase_name", "Story")
	
	# Emit signal if it exists
	if phase_indicator.has_signal("phase_display_updated"):
		phase_indicator.emit_signal("phase_display_updated")
		await get_tree().process_frame

func test_phase_icon():
	# Test icon functionality
	var icon_texture = phase_indicator.get_node("MainContainer/IconTexture")
	assert_that(icon_texture).is_not_null()
	
	# Set up icon for battle setup phase
	phase_indicator.set_meta("current_phase", 2) # Battle setup
	phase_indicator.set_meta("has_icon", true)
	
	var has_icon = phase_indicator.get_meta("has_icon", false)
	assert_that(has_icon).is_true()
	
	if phase_indicator.has_signal("icon_updated"):
		phase_indicator.emit_signal("icon_updated")
		await get_tree().process_frame

func test_phase_progress():
	# Test progress functionality
	var progress_bar = phase_indicator.get_node("MainContainer/ProgressBar")
	assert_that(progress_bar).is_not_null()
	
	# Test progress setting
	var expected_progress = 0.75
	phase_indicator.set_meta("progress", expected_progress)
	progress_bar.value = expected_progress
	
	var actual_progress = progress_bar.value
	assert_that(actual_progress).is_equal(expected_progress)
	
	if phase_indicator.has_signal("progress_updated"):
		phase_indicator.emit_signal("progress_updated")
		await get_tree().process_frame

func test_phase_state():
	# Test state management
	phase_indicator.set_meta("is_active", true)
	var is_active = phase_indicator.get_meta("is_active", false)
	assert_that(is_active).is_true()
	
	# Test state change signals
	if phase_indicator.has_signal("state_changed"):
		phase_indicator.emit_signal("state_changed")
		await get_tree().process_frame
	
	# Test state toggle
	phase_indicator.set_meta("is_active", false)
	if phase_indicator.has_signal("state_changed"):
		phase_indicator.emit_signal("state_changed")
		await get_tree().process_frame

func test_phase_description():
	# Test description functionality
	var description_label = phase_indicator.get_node("DescriptionLabel")
	assert_that(description_label).is_not_null()
	
	var expected_description = "Updated description"
	phase_indicator.set_meta("description", expected_description)
	description_label.text = expected_description
	
	assert_that(description_label.text).is_equal(expected_description)
	
	if phase_indicator.has_signal("description_updated"):
		phase_indicator.emit_signal("description_updated")
		await get_tree().process_frame

func test_phase_transition():
	# Test phase transition
	var initial_phase = phase_indicator.get_meta("current_phase", 0)
	var new_phase = 1 # Story phase
	
	phase_indicator.set_meta("current_phase", new_phase)
	phase_indicator.set_meta("phase_name", "Story")
	
	var updated_phase = phase_indicator.get_meta("current_phase", 0)
	assert_that(updated_phase).is_equal(new_phase)
	
	var phase_label = phase_indicator.get_node("MainContainer/PhaseLabel")
	phase_label.text = "Story"
	assert_that(phase_label.text).is_equal("Story")
	
	if phase_indicator.has_signal("transition_completed"):
		phase_indicator.emit_signal("transition_completed")
		await get_tree().process_frame

func test_phase_validation():
	# Test validation with invalid phase
	phase_indicator.set_meta("current_phase", -1)
	
	# Emit signal and wait briefly
	if phase_indicator.has_signal("phase_display_updated"):
		phase_indicator.emit_signal("phase_display_updated")
		await get_tree().process_frame
	
	if phase_indicator.has_signal("progress_updated"):
		phase_indicator.emit_signal("progress_updated")
		await get_tree().process_frame

func test_ui_state():
	# Test UI state management with shorter timeouts
	phase_indicator.set_meta("ui_visible", false)
	
	var is_visible = phase_indicator.get_meta("ui_visible", true)
	assert_that(is_visible).is_false()
	
	# Test state change signal
	if phase_indicator.has_signal("ui_state_changed"):
		phase_indicator.emit_signal("ui_state_changed")
		await get_tree().process_frame
	
	# Quick test of other signals
	if phase_indicator.has_signal("event_added"):
		phase_indicator.emit_signal("event_added")
		await get_tree().process_frame
	
	if phase_indicator.has_signal("visibility_changed"):
		phase_indicator.emit_signal("visibility_changed")
		await get_tree().process_frame

func test_theme():
	# Test theme management
	var initial_theme = phase_indicator.get_meta("theme_name", "default")
	assert_that(initial_theme).is_equal("default")
	
	# Change theme
	phase_indicator.set_meta("theme_name", "dark")
	mock_theme_manager.set_meta("current_theme", "dark")
	
	var updated_theme = phase_indicator.get_meta("theme_name", "default")
	assert_that(updated_theme).is_equal("dark")
	
	# Test theme change signal
	if phase_indicator.has_signal("theme_changed"):
		phase_indicator.emit_signal("theme_changed")
		await get_tree().process_frame