# Universal Safe Resource Loading - Apply to ALL files
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
class_name UniversalResourceLoader
extends RefCounted

static func load_resource_safe(path: String, expected_type: String = "", context: String = "") -> Resource:
	if (path.is_empty()):
		push_error("CRASH PREVENTION: Empty resource path - %s" % context)
		return null

	if not ResourceLoader.exists(path):
		push_error("CRASH PREVENTION: Resource not found: %s (%s) - %s" % [path, expected_type, context])
		return null

	var resource = ResourceLoader.load(path)
	if not resource:
		push_error("CRASH PREVENTION: Resource failed to load: %s (%s) - %s" % [path, expected_type, context])
		return null

	# Type validation if expected_type is provided
	if not (expected_type.is_empty()):
		var resource_class = resource.get_class()
		if resource_class != expected_type and not resource.is_class(expected_type):
			push_warning("Resource type mismatch: expected %s, got %s for %s - %s" % [expected_type, resource_class, path, context])

	return resource

static func preload_safe(path: String, expected_type: String = "", context: String = "") -> Resource:
	# Note: preload() is compile-time, so we simulate it with load() and validation
	return load_resource_safe(path, expected_type, context)

static func load_script_safe(path: String, context: String = "") -> GDScript:
	var script_resource = load_resource_safe(path, "GDScript", context)
	if not script_resource:
		return null

	if not script_resource is GDScript:
		push_error("CRASH PREVENTION: Loaded resource is not a GDScript: %s - %s" % [path, context])
		return null

	return script_resource as GDScript

static func load_scene_safe(path: String, context: String = "") -> PackedScene:
	var scene_resource = load_resource_safe(path, "PackedScene", context)
	if not scene_resource:
		return null

	if not scene_resource is PackedScene:
		push_error("CRASH PREVENTION: Loaded resource is not a PackedScene: %s - %s" % [path, context])
		return null

	return scene_resource as PackedScene

static func load_texture_safe(path: String, context: String = "") -> Texture2D:
	var texture_resource = load_resource_safe(path, "Texture2D", context)
	if not texture_resource:
		return null

	if not texture_resource is Texture2D:
		push_error("CRASH PREVENTION: Loaded resource is not a Texture2D: %s - %s" % [path, context])
		return null

	return texture_resource as Texture2D

static func load_json_safe(path: String, context: String = "") -> Dictionary:
	if (path.is_empty()):
		push_error("CRASH PREVENTION: Empty JSON file path - %s" % context)
		return {}

	if not FileAccess.file_exists(path):
		push_error("CRASH PREVENTION: JSON file not found: %s - %s" % [path, context])
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("CRASH PREVENTION: Failed to open JSON file: %s - %s" % [path, context])
		return {}

	var json_string = file.get_as_text()
	if file: file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("CRASH PREVENTION: Failed to parse JSON: %s (Error: %d) - %s" % [path, parse_result, context])
		return {}

	var data = json.data
	if not data is Dictionary:
		push_warning("JSON root is not a Dictionary in %s - %s" % [path, context])
		return {}

	return data as Dictionary

static func load_audio_safe(path: String, context: String = "") -> AudioStream:
	var audio_resource = load_resource_safe(path, "AudioStream", context)
	if not audio_resource:
		return null

	if not audio_resource is AudioStream:
		push_error("CRASH PREVENTION: Loaded resource is not an AudioStream: %s - %s" % [path, context])
		return null

	return audio_resource as AudioStream

static func resource_exists(path: String) -> bool:
	if (path.is_empty()):
		return false

	return ResourceLoader.exists(path)

static func get_resource_type(path: String) -> String:
	if not resource_exists(path):
		return ""

	var resource = ResourceLoader.load(path)
	if not resource:
		return ""

	return resource.get_class()
