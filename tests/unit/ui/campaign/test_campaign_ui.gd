## Campaign UI Test Suite
## Tests the UI components and interactions for the campaign system
@tool
extends "res://tests/fixtures/base/game_test.gd"

# Type-safe instance variables
var _campaign_ui: Node = null
# _game_state is already defined in parent class

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Create and initialize the UI
	_campaign_ui = Node.new()
	_campaign_ui.name = "CampaignUI"
	add_child_autofree(_campaign_ui)
	
	# Create game state if not already created
	if not _game_state:
		_game_state = Node.new()
		_game_state.name = "GameState"
		add_child_autofree(_game_state)
	
	# Initialize UI with direct method call instead of using TypeSafeMixin
	if _campaign_ui.has_method("initialize"):
		_campaign_ui.initialize(_game_state)
	else:
		push_error("Campaign UI doesn't have initialize method")
		return
		
	track_test_node(_campaign_ui)
	
	await stabilize_engine()

func after_each() -> void:
	_campaign_ui = null
	_game_state = null
	await super.after_each()

# UI Initialization Tests
func test_ui_initialization() -> void:
	assert_not_null(_campaign_ui, "Campaign UI should be initialized")
	
	var is_visible: bool = TypeSafeMixin._call_node_method_bool(_campaign_ui, "is_visible", [])
	assert_true(is_visible, "UI should be visible after initialization")
	
	var current_phase: int = TypeSafeMixin._call_node_method_int(_campaign_ui, "get_current_phase", [])
	assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.NONE, "Should start in NONE phase")

# Resource Display Tests
func test_resource_display() -> void:
	watch_signals(_campaign_ui)
	
	# Test credits display
	TypeSafeMixin._call_node_method_bool(_campaign_ui, "update_credits", [100])
	var credits_text = str(TypeSafeMixin._call_node_method(_campaign_ui, "get_credits_text", []))
	assert_eq(credits_text, "100", "Credits display should match value")
	verify_signal_emitted(_campaign_ui, "credits_updated")
	
	# Test reputation display
	TypeSafeMixin._call_node_method_bool(_campaign_ui, "update_reputation", [5])
	var reputation_text = str(TypeSafeMixin._call_node_method(_campaign_ui, "get_reputation_text", []))
	assert_eq(reputation_text, "5", "Reputation display should match value")
	verify_signal_emitted(_campaign_ui, "reputation_updated")

# Campaign Status Tests
func test_campaign_status() -> void:
	watch_signals(_campaign_ui)
	
	# Test campaign name
	TypeSafeMixin._call_node_method_bool(_campaign_ui, "set_campaign_name", ["Test Campaign"])
	var campaign_name = str(TypeSafeMixin._call_node_method(_campaign_ui, "get_campaign_name", []))
	assert_eq(campaign_name, "Test Campaign", "Campaign name should match")
	verify_signal_emitted(_campaign_ui, "campaign_name_updated")
	
	# Test campaign status
	TypeSafeMixin._call_node_method_bool(_campaign_ui, "set_campaign_status", ["Active"])
	var status = str(TypeSafeMixin._call_node_method(_campaign_ui, "get_campaign_status", []))
	assert_eq(status, "Active", "Campaign status should match")
	verify_signal_emitted(_campaign_ui, "status_updated")

# Navigation Tests
func test_navigation() -> void:
	watch_signals(_campaign_ui)
	
	# Test menu navigation
	var success: bool = TypeSafeMixin._call_node_method_bool(_campaign_ui, "navigate_to", ["crew"])
	assert_true(success, "Should navigate to crew menu")
	verify_signal_emitted(_campaign_ui, "navigation_changed")
	
	# Test back navigation
	success = TypeSafeMixin._call_node_method_bool(_campaign_ui, "navigate_back", [])
	assert_true(success, "Should navigate back")
	verify_signal_emitted(_campaign_ui, "navigation_changed")

# Menu Tests
func test_menu_interactions() -> void:
	watch_signals(_campaign_ui)
	
	# Test menu visibility
	TypeSafeMixin._call_node_method_bool(_campaign_ui, "show_menu", ["options"])
	var is_menu_visible: bool = TypeSafeMixin._call_node_method_bool(_campaign_ui, "is_menu_visible", ["options"])
	assert_true(is_menu_visible, "Options menu should be visible")
	verify_signal_emitted(_campaign_ui, "menu_visibility_changed")
	
	# Test menu selection
	var success: bool = TypeSafeMixin._call_node_method_bool(_campaign_ui, "select_menu_item", ["save_game"])
	assert_true(success, "Should select menu item")
	verify_signal_emitted(_campaign_ui, "menu_item_selected")

# Dialog Tests
func test_dialogs() -> void:
	watch_signals(_campaign_ui)
	
	# Test confirmation dialog
	TypeSafeMixin._call_node_method_bool(_campaign_ui, "show_confirmation_dialog", ["Test confirmation"])
	var is_dialog_visible: bool = TypeSafeMixin._call_node_method_bool(_campaign_ui, "is_dialog_visible", [])
	assert_true(is_dialog_visible, "Confirmation dialog should be visible")
	verify_signal_emitted(_campaign_ui, "dialog_shown")
	
	# Test dialog result
	TypeSafeMixin._call_node_method_bool(_campaign_ui, "confirm_dialog", [])
	verify_signal_emitted(_campaign_ui, "dialog_confirmed")

# Notification Tests
func test_notifications() -> void:
	watch_signals(_campaign_ui)
	
	# Test notification display
	TypeSafeMixin._call_node_method_bool(_campaign_ui, "show_notification", ["Test notification"])
	var notification_text = str(TypeSafeMixin._call_node_method(_campaign_ui, "get_notification_text", []))
	assert_eq(notification_text, "Test notification", "Notification text should match")
	verify_signal_emitted(_campaign_ui, "notification_shown")
	
	# Test notification timeout
	await get_tree().create_timer(2.0).timeout
	var is_notification_visible: bool = TypeSafeMixin._call_node_method_bool(_campaign_ui, "is_notification_visible", [])
	assert_false(is_notification_visible, "Notification should hide after timeout")
	verify_signal_emitted(_campaign_ui, "notification_hidden")

# Error Handling Tests
func test_error_handling() -> void:
	watch_signals(_campaign_ui)
	
	# Test invalid navigation
	var success: bool = TypeSafeMixin._call_node_method_bool(_campaign_ui, "navigate_to", ["invalid_menu"])
	assert_false(success, "Should not navigate to invalid menu")
	verify_signal_not_emitted(_campaign_ui, "navigation_changed")
	
	# Test invalid menu item
	success = TypeSafeMixin._call_node_method_bool(_campaign_ui, "select_menu_item", ["invalid_item"])
	assert_false(success, "Should not select invalid menu item")
	verify_signal_not_emitted(_campaign_ui, "menu_item_selected")

# UI State Tests
func test_ui_state() -> void:
	watch_signals(_campaign_ui)
	
	# Test UI enable/disable
	TypeSafeMixin._call_node_method_bool(_campaign_ui, "set_ui_enabled", [false])
	var is_enabled: bool = TypeSafeMixin._call_node_method_bool(_campaign_ui, "is_ui_enabled", [])
	assert_false(is_enabled, "UI should be disabled")
	verify_signal_emitted(_campaign_ui, "ui_state_changed")
	
	# Test UI visibility
	TypeSafeMixin._call_node_method_bool(_campaign_ui, "set_ui_visible", [false])
	var is_visible: bool = TypeSafeMixin._call_node_method_bool(_campaign_ui, "is_visible", [])
	assert_false(is_visible, "UI should be hidden")
	verify_signal_emitted(_campaign_ui, "visibility_changed")

# Theme Tests
func test_theme_handling() -> void:
	watch_signals(_campaign_ui)
	
	# Test theme change
	var success: bool = TypeSafeMixin._call_node_method_bool(_campaign_ui, "set_theme", ["dark"])
	assert_true(success, "Should change theme")
	
	var current_theme = str(TypeSafeMixin._call_node_method(_campaign_ui, "get_current_theme", []))
	assert_eq(current_theme, "dark", "Current theme should match")
	verify_signal_emitted(_campaign_ui, "theme_changed")
