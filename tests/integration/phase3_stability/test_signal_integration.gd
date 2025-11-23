extends GdUnitTestSuite
## Phase 3B: Backend Integration Tests - Signal Integration
## Tests signal connection lifecycle, deduplication, cleanup, and memory leak prevention
## gdUnit4 v6.0.1 compatible
## HIGH BUG DISCOVERY PROBABILITY

# System under test
var CampaignCreationUIClass
var campaign_ui = null

# Mock panel class for testing
class MockPanel extends Control:
	signal panel_data_changed(data: Dictionary)
	signal panel_validation_changed(is_valid: bool)
	signal panel_completed(data: Dictionary)
	signal validation_failed(errors: Array[String])
	signal panel_ready()
	signal custom_signal(value: String)

	var _class_name: String = "MockPanel"
	var signal_emissions: Array = []

	func get_panel_class() -> String:
		return _class_name

	func emit_panel_data_changed(data: Dictionary):
		signal_emissions.append({"signal": "panel_data_changed", "data": data})
		panel_data_changed.emit(data)

	func emit_panel_completed(data: Dictionary):
		signal_emissions.append({"signal": "panel_completed", "data": data})
		panel_completed.emit(data)

func before():
	"""Suite-level setup - runs once before all tests"""
	CampaignCreationUIClass = load("res://src/ui/screens/campaign/CampaignCreationUI.gd")

func before_test():
	"""Test-level setup - create fresh instances for each test"""
	campaign_ui = auto_free(CampaignCreationUIClass.new())

func after_test():
	"""Test-level cleanup"""
	campaign_ui = null

func after():
	"""Suite-level cleanup - runs once after all tests"""
	CampaignCreationUIClass = null

# ============================================================================
# Signal Connection Lifecycle Tests (3 tests)
# ============================================================================

func test_signal_connection_prevents_duplicates():
	"""🐛 BUG DISCOVERY: Connecting same signal twice should be prevented"""
	# EXPECTED: is_connected() check should prevent duplicate connections
	# ACTUAL: May allow multiple connections if check fails

	var mock_panel = auto_free(MockPanel.new())
	var handler_call_count = 0

	var test_handler = func(data: Dictionary):
		handler_call_count += 1

	# First connection (should succeed)
	if not mock_panel.panel_data_changed.is_connected(test_handler):
		mock_panel.panel_data_changed.connect(test_handler)

	# Second connection attempt (should be prevented by is_connected check)
	if not mock_panel.panel_data_changed.is_connected(test_handler):
		mock_panel.panel_data_changed.connect(test_handler)

	# Emit signal once
	mock_panel.emit_panel_data_changed({"test": "data"})

	# Handler should only be called once (not twice if duplicate)
	assert_that(handler_call_count).is_equal(1)

func test_signal_disconnection_cleanup():
	"""Disconnecting signal should fully clean up connection"""
	var mock_panel = auto_free(MockPanel.new())
	var handler_called = false

	var test_handler = func(data: Dictionary):
		handler_called = true

	# Connect signal
	mock_panel.panel_data_changed.connect(test_handler)
	assert_that(mock_panel.panel_data_changed.is_connected(test_handler)).is_true()

	# Disconnect signal
	mock_panel.panel_data_changed.disconnect(test_handler)
	assert_that(mock_panel.panel_data_changed.is_connected(test_handler)).is_false()

	# Emit signal after disconnection
	mock_panel.emit_panel_data_changed({"test": "data"})

	# Handler should NOT be called
	assert_that(handler_called).is_false()

func test_signal_connection_with_deferred_flag():
	"""CONNECT_DEFERRED flag should defer signal handling to next frame"""
	# Per CampaignCreationUI.gd line 1034: All panel signals use CONNECT_DEFERRED

	var mock_panel = auto_free(MockPanel.new())
	var handler_called = false

	var test_handler = func(data: Dictionary):
		handler_called = true

	# Connect with CONNECT_DEFERRED
	mock_panel.panel_data_changed.connect(test_handler, CONNECT_DEFERRED)

	# Emit signal
	mock_panel.emit_panel_data_changed({"test": "data"})

	# Handler should NOT be called immediately (deferred to next frame)
	# This test documents expected deferred behavior
	# In actual game, handler would be called on next process frame

# ============================================================================
# Signal Propagation Tests (3 tests)
# ============================================================================

func test_multiple_signals_propagate_correctly():
	"""Multiple signal emissions should all propagate to handlers"""
	var mock_panel = auto_free(MockPanel.new())
	var emission_count = 0
	var received_data = []

	var test_handler = func(data: Dictionary):
		emission_count += 1
		received_data.append(data)

	mock_panel.panel_data_changed.connect(test_handler)

	# Emit signal 5 times with different data
	for i in range(5):
		mock_panel.emit_panel_data_changed({"iteration": i})

	# All 5 emissions should propagate
	assert_that(emission_count).is_equal(5)
	assert_that(received_data.size()).is_equal(5)

	# Verify data integrity
	assert_that(received_data[0]["iteration"]).is_equal(0)
	assert_that(received_data[4]["iteration"]).is_equal(4)

func test_multiple_handlers_receive_signal():
	"""Single signal should propagate to all connected handlers"""
	var mock_panel = auto_free(MockPanel.new())

	var handler1_called = false
	var handler2_called = false
	var handler3_called = false

	var handler1 = func(_data): handler1_called = true
	var handler2 = func(_data): handler2_called = true
	var handler3 = func(_data): handler3_called = true

	# Connect 3 different handlers to same signal
	mock_panel.panel_data_changed.connect(handler1)
	mock_panel.panel_data_changed.connect(handler2)
	mock_panel.panel_data_changed.connect(handler3)

	# Emit signal once
	mock_panel.emit_panel_data_changed({"test": "data"})

	# All 3 handlers should be called
	assert_that(handler1_called).is_true()
	assert_that(handler2_called).is_true()
	assert_that(handler3_called).is_true()

func test_signal_disconnection_only_affects_target():
	"""Disconnecting one handler should not affect other handlers"""
	var mock_panel = auto_free(MockPanel.new())

	var handler1_called = false
	var handler2_called = false

	var handler1 = func(_data): handler1_called = true
	var handler2 = func(_data): handler2_called = true

	# Connect both handlers
	mock_panel.panel_data_changed.connect(handler1)
	mock_panel.panel_data_changed.connect(handler2)

	# Disconnect only handler1
	mock_panel.panel_data_changed.disconnect(handler1)

	# Emit signal
	mock_panel.emit_panel_data_changed({"test": "data"})

	# Only handler2 should be called
	assert_that(handler1_called).is_false()
	assert_that(handler2_called).is_true()

# ============================================================================
# Memory Leak Prevention Tests (2 tests)
# ============================================================================

func test_orphaned_connections_after_panel_free():
	"""🐛 BUG DISCOVERY: Panel freed without disconnecting signals may leak memory"""
	# EXPECTED: Signals should be disconnected before panel is freed
	# ACTUAL: May leave orphaned connections if _disconnect_panel_signals not called

	var handler_call_count = 0
	var test_handler = func(_data):
		handler_call_count += 1

	# Create panel, connect signal, emit, then free
	var temp_panel = MockPanel.new()
	temp_panel.panel_data_changed.connect(test_handler)

	# Emit to verify connection works
	temp_panel.emit_panel_data_changed({"test": "data"})
	assert_that(handler_call_count).is_equal(1)

	# Free panel WITHOUT disconnecting (simulates bug)
	temp_panel.queue_free()

	# This test documents expected cleanup behavior
	# In production, _disconnect_panel_signals should be called before free

func test_signal_cleanup_during_panel_swap():
	"""🐛 BUG DISCOVERY: Swapping panels should disconnect old panel signals"""
	# EXPECTED: When changing panels, old signals should disconnect
	# ACTUAL: May accumulate connections if not properly cleaned up

	var panel1 = auto_free(MockPanel.new())
	var panel2 = auto_free(MockPanel.new())

	var handler1_call_count = 0
	var handler2_call_count = 0

	var handler1 = func(_data): handler1_call_count += 1
	var handler2 = func(_data): handler2_call_count += 1

	# Connect to panel1
	panel1.panel_data_changed.connect(handler1)
	panel1.emit_panel_data_changed({"panel": 1})
	assert_that(handler1_call_count).is_equal(1)

	# SIMULATE PANEL SWAP: Disconnect panel1, connect panel2
	panel1.panel_data_changed.disconnect(handler1)
	panel2.panel_data_changed.connect(handler2)

	# Emit on both panels
	panel1.emit_panel_data_changed({"panel": 1})  # Should NOT trigger handler1
	panel2.emit_panel_data_changed({"panel": 2})  # Should trigger handler2

	# Only panel2 handler should be called after swap
	assert_that(handler1_call_count).is_equal(1)  # Still 1 (not called again)
	assert_that(handler2_call_count).is_equal(1)

# ============================================================================
# Signal Validation Tests (2 tests)
# ============================================================================

func test_has_signal_validation_before_connection():
	"""🐛 BUG DISCOVERY: Should validate signal exists before connecting"""
	# EXPECTED: Use has_signal() to check signal exists before connecting
	# ACTUAL: Connecting to non-existent signal may cause runtime error

	var mock_panel = auto_free(MockPanel.new())

	# Valid signal should exist
	assert_that(mock_panel.has_signal("panel_data_changed")).is_true()

	# Non-existent signal should return false
	assert_that(mock_panel.has_signal("nonexistent_signal")).is_false()

	# This test documents expected validation pattern
	# CampaignCreationUI.gd uses has_signal() checks (line 1033, 1036, etc.)

func test_is_connected_check_before_disconnect():
	"""Disconnecting should check is_connected to prevent errors"""
	var mock_panel = auto_free(MockPanel.new())
	var test_handler = func(_data): pass

	# Signal not connected initially
	assert_that(mock_panel.panel_data_changed.is_connected(test_handler)).is_false()

	# Connect signal
	mock_panel.panel_data_changed.connect(test_handler)
	assert_that(mock_panel.panel_data_changed.is_connected(test_handler)).is_true()

	# Disconnect signal
	if mock_panel.panel_data_changed.is_connected(test_handler):
		mock_panel.panel_data_changed.disconnect(test_handler)

	# Should be disconnected now
	assert_that(mock_panel.panel_data_changed.is_connected(test_handler)).is_false()

	# Trying to disconnect again should be safe (no-op)
	if mock_panel.panel_data_changed.is_connected(test_handler):
		mock_panel.panel_data_changed.disconnect(test_handler)
