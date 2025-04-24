@tool
extends Control

var GutEditorGlobals = load('res://addons/gut/gui/editor_globals.gd')
var TestScript = load('res://addons/gut/test.gd')
var GutConfigGui = load('res://addons/gut/gui/gut_config_gui.gd')
var ScriptTextEditors = load('res://addons/gut/gui/script_text_editor_controls.gd')


var _interface = null;
var _is_running = false;
var _gut_config = load('res://addons/gut/gut_config.gd').new()
var _gut_config_gui = null
var _gut_plugin = null
var _light_color = Color(0, 0, 0, .5)
var _panel_button = null
var _last_selected_path = null
var _user_prefs = null


@onready var _ctrls = {
	run_button = $layout/ControlBar/RunAll,
	shortcuts_button = $layout/ControlBar/Shortcuts,
	settings_button = $layout/ControlBar/Settings,
	run_results_button = $layout/ControlBar/RunResultsBtn,
	output_button = $layout/ControlBar/OutputBtn,
	shortcut_dialog = $BottomPanelShortcuts,
	run_at_cursor = $layout/ControlBar/RunAtCursor
}

# Create proxy objects for missing components
class DummyOutput:
	func clear(): pass
	func add_text(_text): pass
	func load_file(_path): pass
	func get_rich_text_edit(): return self

class DummyRunResults:
	func clear(): pass
	func add_centered_text(_text): pass
	func set_output_control(_ctrl): pass
	func set_interface(_interface): pass
	func set_script_text_editors(_editors): pass
	func load_json_results(_results): pass
	func set_show_orphans(_show): pass

var _dummy_output = DummyOutput.new()
var _dummy_run_results = DummyRunResults.new()

func _init():
	pass


func _ready():
	GutEditorGlobals.create_temp_directory()

	_user_prefs = GutEditorGlobals.user_prefs
	
	# Setup dummy controls for missing components
	if !has_node("layout/RSplit/CResults/TabBar/OutputText"):
		_ctrls.output = _dummy_output
		_ctrls.output_ctrl = _dummy_output
	else:
		_ctrls.output = $layout/RSplit/CResults/TabBar/OutputText.get_rich_text_edit()
		_ctrls.output_ctrl = $layout/RSplit/CResults/TabBar/OutputText

	if !has_node("layout/RSplit/sc/Settings"):
		_ctrls.settings = Node.new()
		add_child(_ctrls.settings)
		_ctrls.settings.name = "DummySettings"
	else:
		_ctrls.settings = $layout/RSplit/sc/Settings
	
	if !has_node("layout/RSplit/CResults/ControlBar/Light3D"):
		var light = Control.new()
		light.custom_minimum_size = Vector2(30, 30)
		add_child(light)
		light.name = "DummyLight"
		_ctrls.light = light
	else:
		_ctrls.light = $layout/RSplit/CResults/ControlBar/Light3D
	
	# Setup dummy result controls
	_ctrls.results = {
		bar = Control.new(),
		passing = Label.new(),
		failing = Label.new(),
		pending = Label.new(),
		errors = Label.new(),
		warnings = Label.new(),
		orphans = Label.new()
	}
	
	if !has_node("layout/RSplit/CResults/TabBar/RunResults"):
		_ctrls.run_results = _dummy_run_results
	else:
		_ctrls.run_results = $layout/RSplit/CResults/TabBar/RunResults

	_gut_config_gui = GutConfigGui.new(_ctrls.settings)

	hide_settings(!_ctrls.settings_button.button_pressed)

	_gut_config.load_options(GutEditorGlobals.editor_run_gut_config_path)
	_gut_config_gui.set_options(_gut_config.options)
	_apply_options_to_controls()

	_ctrls.shortcuts_button.icon = get_theme_icon('Shortcut', 'EditorIcons')
	_ctrls.settings_button.icon = get_theme_icon('Tools', 'EditorIcons')
	_ctrls.run_results_button.icon = get_theme_icon('AnimationTrackGroup', 'EditorIcons') # Tree
	_ctrls.output_button.icon = get_theme_icon('Font', 'EditorIcons')

	_ctrls.run_results.set_output_control(_ctrls.output_ctrl)

	var check_import = load('res://addons/gut/images/red.png')
	if (check_import == null):
		_ctrls.run_results.add_centered_text("GUT got some new images that are not imported yet.  Please restart Godot.")
		print('GUT got some new images that are not imported yet.  Please restart Godot.')
	else:
		_ctrls.run_results.add_centered_text("Let's run some tests!")


func _apply_options_to_controls():
	hide_settings(_user_prefs.hide_settings.value)
	hide_result_tree(_user_prefs.hide_result_tree.value)
	hide_output_text(_user_prefs.hide_output_text.value)
	_ctrls.run_results.set_show_orphans(!_gut_config.options.hide_orphans)


func _process(delta):
	if (_is_running):
		if (!_interface.is_playing_scene()):
			_is_running = false
			_ctrls.output_ctrl.add_text("\ndone")
			load_result_output()
			_gut_plugin.make_bottom_panel_item_visible(self)

# ---------------
# Private
# ---------------

func load_shortcuts():
	_ctrls.shortcut_dialog.load_shortcuts()
	_apply_shortcuts()


func _is_test_script(script):
	var from = script.get_base_script()
	while (from and from.resource_path != 'res://addons/gut/test.gd'):
		from = from.get_base_script()

	return from != null


func _show_errors(errs):
	_ctrls.output_ctrl.clear()
	var text = "Cannot run tests, you have a configuration error:\n"
	for e in errs:
		text += str('*  ', e, "\n")
	text += "Check your settings ----->"
	_ctrls.output_ctrl.add_text(text)
	hide_output_text(false)
	hide_settings(false)


func _save_config():
	_user_prefs.hide_settings.value = !_ctrls.settings_button.button_pressed
	_user_prefs.hide_result_tree.value = !_ctrls.run_results_button.button_pressed
	_user_prefs.hide_output_text.value = !_ctrls.output_button.button_pressed
	_user_prefs.save_it()

	_gut_config.options = _gut_config_gui.get_options(_gut_config.options)
	var w_result = _gut_config.write_options(GutEditorGlobals.editor_run_gut_config_path)
	if (w_result != OK):
		push_error(str('Could not write options to ', GutEditorGlobals.editor_run_gut_config_path, ': ', w_result))
	else:
		_gut_config_gui.mark_saved()


func _run_tests():
	GutEditorGlobals.create_temp_directory()

	var issues = _gut_config_gui.get_config_issues()
	if (issues.size() > 0):
		_show_errors(issues)
		return

	write_file(GutEditorGlobals.editor_run_bbcode_results_path, 'Run in progress')
	_save_config()
	_apply_options_to_controls()

	_ctrls.output_ctrl.clear()
	_ctrls.run_results.clear()
	_ctrls.run_results.add_centered_text('Running...')

	_interface.play_custom_scene('res://addons/gut/gui/run_from_editor.tscn')
	_is_running = true
	_ctrls.output_ctrl.add_text('Running...')


func _apply_shortcuts():
	_ctrls.run_button.shortcut = _ctrls.shortcut_dialog.get_run_all()

	_ctrls.run_at_cursor.get_script_button().shortcut = \
		_ctrls.shortcut_dialog.get_run_current_script()
	_ctrls.run_at_cursor.get_inner_button().shortcut = \
		_ctrls.shortcut_dialog.get_run_current_inner()
	_ctrls.run_at_cursor.get_test_button().shortcut = \
		_ctrls.shortcut_dialog.get_run_current_test()

	_panel_button.shortcut = _ctrls.shortcut_dialog.get_panel_button()


func _run_all():
	_gut_config.options.selected = null
	_gut_config.options.inner_class = null
	_gut_config.options.unit_test_name = null

	_run_tests()


# ---------------
# Events
# ---------------
func _on_results_bar_draw(bar):
	bar.draw_rect(Rect2(Vector2(0, 0), bar.size), Color(0, 0, 0, .2))


func _on_Light_draw():
	var l = _ctrls.light
	l.draw_circle(Vector2(l.size.x / 2, l.size.y / 2), l.size.x / 2, _light_color)


func _on_editor_script_changed(script):
	if (script):
		set_current_script(script)


func _on_RunAll_pressed():
	_run_all()


func _on_Shortcuts_pressed():
	_ctrls.shortcut_dialog.popup_centered()

func _on_bottom_panel_shortcuts_visibility_changed():
	_apply_shortcuts()
	_ctrls.shortcut_dialog.save_shortcuts()

func _on_RunAtCursor_run_tests(what):
	_gut_config.options.selected = what.script
	_gut_config.options.inner_class = what.inner_class
	_gut_config.options.unit_test_name = what.test_method

	_run_tests()


func _on_Settings_pressed():
	hide_settings(!_ctrls.settings_button.button_pressed)
	_save_config()


func _on_OutputBtn_pressed():
	hide_output_text(!_ctrls.output_button.button_pressed)
	_save_config()


func _on_RunResultsBtn_pressed():
	hide_result_tree(!_ctrls.run_results_button.button_pressed)
	_save_config()


# Currently not used, but will be when I figure out how to put
# colors into the text results
func _on_UseColors_pressed():
	pass

# ---------------
# Public
# ---------------
func hide_result_tree(should):
	_ctrls.run_results.visible = !should
	_ctrls.run_results_button.button_pressed = !should

# Compatibility alias for hide_result_tree
func _hide_result_tree(should = true):
	hide_result_tree(should)

func hide_settings(should):
	var s_scroll = _ctrls.settings.get_parent()
	s_scroll.visible = !should

	# collapse only collapses the first control, so we move
	# settings around to be the collapsed one
	if (should):
		s_scroll.get_parent().move_child(s_scroll, 0)
	else:
		s_scroll.get_parent().move_child(s_scroll, 1)

	$layout/RSplit.collapsed = should
	_ctrls.settings_button.button_pressed = !should

# Compatibility alias for hide_settings
func _hide_settings(should = true):
	hide_settings(should)

func hide_output_text(should):
	$layout/RSplit/CResults/TabBar/OutputText.visible = !should
	_ctrls.output_button.button_pressed = !should

# Compatibility alias for hide_output_text
func _hide_output_text(should = true):
	hide_output_text(should)


func load_result_output():
	_ctrls.output_ctrl.load_file(GutEditorGlobals.editor_run_bbcode_results_path)

	var summary = get_file_as_text(GutEditorGlobals.editor_run_json_results_path)
	var test_json_conv = JSON.new()
	if (test_json_conv.parse(summary) != OK):
		return
	var results = test_json_conv.get_data()

	_ctrls.run_results.load_json_results(results)

	var summary_json = results['test_scripts']['props']
	_ctrls.results.passing.text = str(summary_json.passing)
	_ctrls.results.passing.get_parent().visible = true

	_ctrls.results.failing.text = str(summary_json.failures)
	_ctrls.results.failing.get_parent().visible = true

	_ctrls.results.pending.text = str(summary_json.pending)
	_ctrls.results.pending.get_parent().visible = _ctrls.results.pending.text != '0'

	_ctrls.results.errors.text = str(summary_json.errors)
	_ctrls.results.errors.get_parent().visible = _ctrls.results.errors.text != '0'

	_ctrls.results.warnings.text = str(summary_json.warnings)
	_ctrls.results.warnings.get_parent().visible = _ctrls.results.warnings.text != '0'

	_ctrls.results.orphans.text = str(summary_json.orphans)
	_ctrls.results.orphans.get_parent().visible = _ctrls.results.orphans.text != '0' and !_gut_config.options.hide_orphans

	if (summary_json.tests == 0):
		_light_color = Color(1, 0, 0, .75)
	elif (summary_json.failures != 0):
		_light_color = Color(1, 0, 0, .75)
	elif (summary_json.pending != 0):
		_light_color = Color(1, 1, 0, .75)
	else:
		_light_color = Color(0, 1, 0, .75)
	_ctrls.light.visible = true
	_ctrls.light.queue_redraw()


func set_current_script(script):
	if (script):
		if (_is_test_script(script)):
			var file = script.resource_path.get_file()
			_last_selected_path = script.resource_path.get_file()
			_ctrls.run_at_cursor.activate_for_script(script.resource_path)


func set_interface(value):
	_interface = value
	_interface.get_script_editor().connect("editor_script_changed", Callable(self, '_on_editor_script_changed'))

	var ste = ScriptTextEditors.new(_interface.get_script_editor())
	_ctrls.run_results.set_interface(_interface)
	_ctrls.run_results.set_script_text_editors(ste)
	_ctrls.run_at_cursor.set_script_text_editors(ste)
	set_current_script(_interface.get_script_editor().get_current_script())


func set_plugin(value):
	_gut_plugin = value


func set_panel_button(value):
	_panel_button = value

# ------------------------------------------------------------------------------
# Write a file.
# ------------------------------------------------------------------------------
func write_file(path, content):
	var f = FileAccess.open(path, FileAccess.WRITE)
	if (f != null):
		f.store_string(content)
	f = null;

	return FileAccess.get_open_error()


# ------------------------------------------------------------------------------
# Returns the text of a file or an empty string if the file could not be opened.
# ------------------------------------------------------------------------------
func get_file_as_text(path):
	var to_return = ''
	var f = FileAccess.open(path, FileAccess.READ)
	if (f != null):
		to_return = f.get_as_text()
	f = null
	return to_return


# ------------------------------------------------------------------------------
# return if_null if value is null otherwise return value
# ------------------------------------------------------------------------------
func nvl(value, if_null):
	if (value == null):
		return if_null
	else:
		return value
