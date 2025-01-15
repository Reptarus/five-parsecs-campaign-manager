@tool
extends BaseTest

# Load required scripts
const UIManager = preload("res://src/ui/screens/UIManager.gd")
const GameplayOptionsMenu = preload("res://src/ui/screens/gameplay_options_menu.gd")

# Test variables
var ui_manager: Node
var options_menu: Node

func before_all() -> void:
    super.before_all()
    ui_manager = _create_ui_manager()
    options_menu = _create_options_menu()
    add_child(ui_manager)
    add_child(options_menu)
    track_node(ui_manager)
    track_node(options_menu)
    
func after_all() -> void:
    super.after_all()

func before_each() -> void:
    super.before_each()
    # Reset UI state before each test
    if ui_manager.has_method("reset"):
        ui_manager.reset()

func _create_ui_manager() -> Node:
    var manager := Node.new()
    manager.set_script(UIManager)
    return manager

func _create_options_menu() -> Node:
    var menu := Node.new()
    menu.set_script(GameplayOptionsMenu)
    return menu

# UI Manager Tests
func test_ui_manager_initialization() -> void:
    assert_not_null(ui_manager, "UI Manager should be initialized")
    assert_true(ui_manager.is_inside_tree(), "UI Manager should be in scene tree")

func test_screen_transitions() -> void:
    var transition_successful = ui_manager.transition_to_screen("main_menu")
    assert_true(transition_successful, "Should transition to main menu")
    assert_eq(ui_manager.get_current_screen(), "main_menu", "Current screen should be main menu")

func test_invalid_screen_transition():
    var transition_successful = ui_manager.transition_to_screen("nonexistent_screen")
    assert_false(transition_successful, "Should fail transitioning to invalid screen")

# Options Menu Tests
func test_options_menu_initialization():
    assert_not_null(options_menu, "Options menu should be initialized")
    assert_true(options_menu.is_inside_tree(), "Options menu should be in scene tree")

func test_options_menu_settings():
    var initial_volume = options_menu.get_volume()
    options_menu.set_volume(0.5)
    assert_eq(options_menu.get_volume(), 0.5, "Volume should be updated")
    options_menu.set_volume(initial_volume)

# UI State Tests
func test_ui_state_persistence():
    var initial_state = ui_manager.get_ui_state()
    ui_manager.transition_to_screen("options")
    options_menu.set_volume(0.7)
    var new_state = ui_manager.get_ui_state()
    assert_ne(initial_state, new_state, "UI state should change after modifications")

# UI Navigation Tests
func test_screen_history():
    ui_manager.transition_to_screen("main_menu")
    ui_manager.transition_to_screen("options")
    ui_manager.go_back()
    assert_eq(ui_manager.get_current_screen(), "main_menu", "Should return to previous screen")

func test_navigation_stack():
    ui_manager.transition_to_screen("main_menu")
    ui_manager.transition_to_screen("options")
    ui_manager.transition_to_screen("gameplay")
    assert_eq(ui_manager.get_navigation_stack().size(), 3, "Navigation stack should track screen history")

# UI Event Tests
func test_ui_events():
    var event_received = false
    ui_manager.connect("screen_changed", func(screen_name): event_received = true)
    ui_manager.transition_to_screen("main_menu")
    assert_true(event_received, "Should receive screen changed event")

# UI Animation Tests
func test_transition_animations():
    var animation_completed = false
    ui_manager.connect("transition_completed", func(): animation_completed = true)
    ui_manager.transition_to_screen("main_menu")
    await get_tree().create_timer(1.0).timeout
    assert_true(animation_completed, "Screen transition animation should complete")

# UI Responsiveness Tests
func test_ui_responsiveness():
    var viewport_size = get_viewport().get_visible_rect().size
    ui_manager.transition_to_screen("main_menu")
    await get_tree().create_timer(0.1).timeout
    var main_menu = ui_manager.get_current_screen_node()
    assert_true(main_menu.size.x <= viewport_size.x, "UI should fit viewport width")
    assert_true(main_menu.size.y <= viewport_size.y, "UI should fit viewport height")