@tool

static var GutUserPreferences = load("res://addons/gut/gui/gut_user_preferences.gd")
static var Compatibility = load("res://addons/gut/compatibility.gd")
static var temp_directory = 'user://gut_temp_directory'

static var editor_run_gut_config_path = 'gut_editor_config.json':
	# This avoids having to use path_join wherever we want to reference this
	# path.  The value is not supposed to change.  Could it be a constant
	# instead?  Probably, but I didn't like repeating the directory part.
	# Do I like that this is a bit witty.  Absolutely.
	get: return temp_directory.path_join(editor_run_gut_config_path)
	# Should this print a message or something instead?  Probably, but then I'd
	# be repeating even more code than if this was just a constant.  So I didn't,
	# even though I wanted to put make the message a easter eggish fun message.
	# I didn't, so this dumb comment will have to serve as the easter eggish fun.
	set(v): pass


static var editor_run_bbcode_results_path = 'gut_editor.bbcode':
	get: return temp_directory.path_join(editor_run_bbcode_results_path)
	set(v): pass


static var editor_run_json_results_path = 'gut_editor.json':
	get: return temp_directory.path_join(editor_run_json_results_path)
	set(v): pass


static var editor_shortcuts_path = 'gut_editor_shortcuts.cfg':
	get: return temp_directory.path_join(editor_shortcuts_path)
	set(v): pass


static var _user_prefs = null
static var user_prefs = _user_prefs:
	# workaround not being able to reference EditorInterface when not in
	# the editor.  This shouldn't be referenced by anything not in the
	# editor.
	get:
		if (_user_prefs == null and Engine.is_editor_hint()):
			# Use compatibility module to create user preferences
			var compatibility = Compatibility.new()
			_user_prefs = compatibility.create_user_preferences(EditorInterface.get_editor_settings())
			if _user_prefs == null:
				push_error("GutUserPreferences could not be created")
		return _user_prefs


static func create_temp_directory():
	if not DirAccess.dir_exists_absolute(temp_directory):
		var err = DirAccess.make_dir_recursive_absolute(temp_directory)
		if err != OK:
			push_error("Failed to create temp directory: %s" % [temp_directory])

# Initialize with proper constructor method that avoids using GDScript.new()
static func create_user_preferences(editor_settings):
	# Use compatibility to avoid using GDScript.new()
	var compatibility = Compatibility.new()
	return compatibility.create_user_preferences(editor_settings)
  