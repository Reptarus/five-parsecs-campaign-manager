extends "res://addons/gut/test.gd"

const CampaignResponsiveLayout = preload("res://src/ui/components/base/CampaignResponsiveLayout.gd")

var layout: CampaignResponsiveLayout
var layout_changed_signal_emitted := false
var last_layout: String

func before_each() -> void:
	layout = CampaignResponsiveLayout.new()
	add_child(layout)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	layout.queue_free()

func _reset_signals() -> void:
	layout_changed_signal_emitted = false
	last_layout = ""

func _connect_signals() -> void:
	if layout.has_signal("layout_changed"):
		layout.connect("layout_changed", _on_layout_changed)

func _on_layout_changed(new_layout: String) -> void:
	layout_changed_signal_emitted = true
	last_layout = new_layout

func test_initial_setup() -> void:
	assert_not_null(layout)
	assert_true(layout is Control)
	assert_true(layout.size.x > 0)
	assert_true(layout.size.y > 0)

func test_campaign_layout_change() -> void:
	# Test desktop layout
	layout.size = Vector2(1920, 1080)
	layout._update_layout()
	
	assert_true(layout_changed_signal_emitted, "Layout changed signal should be emitted")
	assert_eq(last_layout, "desktop", "Should change to desktop layout")
	assert_true(layout.is_desktop_layout(), "Should be in desktop layout")
	
	# Reset signals
	_reset_signals()
	
	# Test tablet layout
	layout.size = Vector2(1024, 768)
	layout._update_layout()
	
	assert_true(layout_changed_signal_emitted, "Layout changed signal should be emitted")
	assert_eq(last_layout, "tablet", "Should change to tablet layout")
	assert_true(layout.is_tablet_layout(), "Should be in tablet layout")
	
	# Reset signals
	_reset_signals()
	
	# Test mobile layout
	layout.size = Vector2(480, 800)
	layout._update_layout()
	
	assert_true(layout_changed_signal_emitted, "Layout changed signal should be emitted")
	assert_eq(last_layout, "mobile", "Should change to mobile layout")
	assert_true(layout.is_mobile_layout(), "Should be in mobile layout")

func test_campaign_panel_layout() -> void:
	var panel = Panel.new()
	layout.add_child(panel)
	
	# Test desktop layout
	layout.size = Vector2(1920, 1080)
	layout._update_layout()
	
	assert_true(panel.size.x <= layout.size.x)
	assert_true(panel.size.y <= layout.size.y)
	
	# Test mobile layout
	layout.size = Vector2(320, 480)
	layout._update_layout()
	
	assert_true(panel.size.x <= layout.size.x)
	assert_true(panel.size.y <= layout.size.y)

func test_campaign_layout_persistence() -> void:
	# Set desktop layout
	layout.size = Vector2(1920, 1080)
	layout._update_layout()
	var initial_layout = last_layout
	
	# Resize slightly but stay in desktop range
	layout.size = Vector2(1800, 1000)
	layout._update_layout()
	
	assert_eq(last_layout, initial_layout)
	assert_true(layout.is_desktop_layout())

func test_campaign_layout_thresholds() -> void:
	# Test desktop threshold
	layout.size = Vector2(1366, 768)
	layout._update_layout()
	assert_eq(last_layout, "desktop")
	assert_true(layout.is_desktop_layout())
	
	# Test tablet threshold
	layout.size = Vector2(768, 1024)
	layout._update_layout()
	assert_eq(last_layout, "tablet")
	assert_true(layout.is_tablet_layout())
	
	# Test mobile threshold
	layout.size = Vector2(320, 480)
	layout._update_layout()
	assert_eq(last_layout, "mobile")
	assert_true(layout.is_mobile_layout())

func test_campaign_orientation_change() -> void:
	# Test landscape
	layout.size = Vector2(1024, 768)
	layout._update_layout()
	var landscape_layout = last_layout
	
	# Test portrait
	layout.size = Vector2(768, 1024)
	layout._update_layout()
	var portrait_layout = last_layout
	
	assert_ne(landscape_layout, portrait_layout)

func test_campaign_layout_helpers() -> void:
	# Test desktop
	layout.size = Vector2(1920, 1080)
	layout._update_layout()
	
	assert_true(layout.is_desktop_layout())
	assert_false(layout.is_tablet_layout())
	assert_false(layout.is_mobile_layout())
	
	# Test tablet
	layout.size = Vector2(1024, 768)
	layout._update_layout()
	
	assert_false(layout.is_desktop_layout())
	assert_true(layout.is_tablet_layout())
	assert_false(layout.is_mobile_layout())
	
	# Test mobile
	layout.size = Vector2(320, 480)
	layout._update_layout()
	
	assert_false(layout.is_desktop_layout())
	assert_false(layout.is_tablet_layout())
	assert_true(layout.is_mobile_layout())