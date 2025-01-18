@tool
extends "res://tests/test_base.gd"

const UIManager := preload("res://src/ui/screens/UIManager.gd")
const OptionsMenu := preload("res://src/ui/screens/gameplay_options_menu.gd")
const TestHelper := preload("res://tests/fixtures/test_helper.gd")

var ui_manager: Node
var options_menu: Node

func before_each() -> void:
    super.before_each()
    ui_manager = Node.new()
    ui_manager.set_script(UIManager)
    options_menu = Node.new()
    options_menu.set_script(OptionsMenu)
    add_child(ui_manager)
    add_child(options_menu)

func after_each() -> void:
    super.after_each()
    ui_manager = null
    options_menu = null

func test_initial_state() -> void:
    assert_false(options_menu.visible, "Options menu should start hidden")
    assert_true(ui_manager.has_method("show_options"), "UI Manager should have show_options method")

func test_show_options() -> void:
    ui_manager.show_options()
    assert_true(options_menu.visible, "Options menu should be visible")

func test_hide_options() -> void:
    ui_manager.show_options()
    ui_manager.hide_options()
    assert_false(options_menu.visible, "Options menu should be hidden")