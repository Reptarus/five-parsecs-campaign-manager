@tool
extends EditorPlugin
var VersionConversion = null
var Compatibility = null
var Polyfill = null
var _bottom_panel = null

func _init():
	# Load polyfill first
	if ResourceLoader.exists("res://addons/gut/temp/gdscript_polyfill.gd"):
		Polyfill = load("res://addons/gut/temp/gdscript_polyfill.gd")
	
	# Load required modules with error checking
	if ResourceLoader.exists("res://addons/gut/version_conversion.gd"):
		VersionConversion = load("res://addons/gut/version_conversion.gd")
		
	if ResourceLoader.exists("res://addons/gut/compatibility.gd"):
		Compatibility = load("res://addons/gut/compatibility.gd").new()
	
	# Check classes using the compatibility layer
	if Compatibility:
		Compatibility.error_if_not_all_classes_imported([VersionConversion])


func _version_conversion():
	var EditorGlobals = null
	if ResourceLoader.exists("res://addons/gut/gui/editor_globals.gd"):
		EditorGlobals = load("res://addons/gut/gui/editor_globals.gd")
	
	if not EditorGlobals:
		push_error("Could not load editor_globals.gd")
		return false
	
	# Safely check for method using polyfill if available
	var has_method = false
	if Polyfill:
		has_method = Polyfill.object_has_method(EditorGlobals, "create_temp_directory")
	else:
		# Fallback
		has_method = EditorGlobals.has_method("create_temp_directory")
	
	if has_method:
		EditorGlobals.create_temp_directory()
	else:
		push_error("editor_globals.gd is missing create_temp_directory method")
		return false

	if Compatibility:
		Compatibility.error_if_not_all_classes_imported([VersionConversion, EditorGlobals])

	# Make sure VersionConversion has the convert method before calling it
	if VersionConversion:
		var has_convert = false
		if Polyfill:
			has_convert = Polyfill.object_has_method(VersionConversion, "convert")
		else:
			# Fallback
			has_convert = VersionConversion.has_method("convert")
			
		if has_convert:
			VersionConversion.convert()
			return true
		else:
			push_error("VersionConversion is missing convert method")
			
	return false


func _enter_tree():
	if not _version_conversion():
		return

	# Create the panel more safely
	if ResourceLoader.exists('res://addons/gut/gui/GutBottomPanel.tscn'):
		var panel_scene = load('res://addons/gut/gui/GutBottomPanel.tscn')
		if panel_scene:
			_bottom_panel = panel_scene.instantiate()
		else:
			push_error("Failed to load GutBottomPanel.tscn")
			return
	else:
		push_error("GutBottomPanel.tscn not found")
		return
		
	if not _bottom_panel:
		push_error("Failed to instantiate GutBottomPanel")
		return

	var button = add_control_to_bottom_panel(_bottom_panel, 'GUT')
	if button:
		button.shortcut_in_tooltip = true

	# Set up the panel
	if _bottom_panel.has_method("set_interface"):
		_bottom_panel.set_interface(get_editor_interface())
	
	if _bottom_panel.has_method("set_plugin"):
		_bottom_panel.set_plugin(self)
	
	if _bottom_panel.has_method("set_panel_button"):
		_bottom_panel.set_panel_button(button)
	
	if _bottom_panel.has_method("load_shortcuts"):
		_bottom_panel.load_shortcuts()
	else:
		push_warning("GutBottomPanel missing load_shortcuts method")


func _exit_tree():
	# Clean-up of the plugin goes here
	if _bottom_panel:
		remove_control_from_bottom_panel(_bottom_panel)
		_bottom_panel.free()
	_bottom_panel = null

# This seems like a good idea at first, but it deletes the settings for ALL
# projects.  If by chance you want to do that you can uncomment this, reload the
# project and then disable GUT.
# func _disable_plugin():
#	var GutEditorGlobals = load('res://addons/gut/gui/editor_globals.gd')
# 	GutEditorGlobals.user_prefs.erase_al