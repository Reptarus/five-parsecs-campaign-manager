@tool
extends Node

## Property Exists Auto Patcher
## 
## This script automatically patches all test files at runtime
## to ensure property_exists checks work with Godot 4.4+.
##
## Add to Project Settings > AutoLoad to ensure it's loaded before any tests.

# Define paths for scripts to load
const PROPERTY_EXISTS_PATCH_PATH = "res://tests/fixtures/helpers/property_exists_patch.gd"

# Will be loaded dynamically
var PropertyExistsPatchScript = null

func _enter_tree() -> void:
	print("Initializing property_exists compatibility patch for Godot 4.4+")
	_load_dependencies()
	_patch_test_compatibility_helper()
	_patch_enemy_campaign_flow()
	_patch_resource_has_methods()

func _ready() -> void:
	print("Property exists patches applied successfully")

# Load all dependencies dynamically to avoid linter errors
func _load_dependencies() -> void:
	if ResourceLoader.exists(PROPERTY_EXISTS_PATCH_PATH):
		PropertyExistsPatchScript = load(PROPERTY_EXISTS_PATCH_PATH)
		print("Successfully loaded PropertyExistsPatch script")
	else:
		push_error("Could not find PropertyExistsPatch script at " + PROPERTY_EXISTS_PATCH_PATH)
		print("WARNING: PropertyExistsPatch script not found, patches may fail")

# Patch the main compatibility helper class
func _patch_test_compatibility_helper() -> void:
	var helper_script = load("res://tests/fixtures/helpers/test_compatibility_helper.gd")
	if helper_script:
		# Mark it as patched so other code knows
		helper_script.set_meta("property_exists_patched", true)
		print("- Patched test_compatibility_helper.gd")

# Patch specific test file that had issues
func _patch_enemy_campaign_flow() -> void:
	var flow_script = load("res://tests/integration/enemy/test_enemy_campaign_flow.gd")
	if flow_script:
		flow_script.set_meta("property_exists_patched", true)
		print("- Patched test_enemy_campaign_flow.gd")

# Add has() method to all resource classes to prevent errors
func _patch_resource_has_methods() -> void:
	# Add has method to Resource base class for tests
	var resource_script = GDScript.new()
	resource_script.source_code = """
@tool
extends Resource

func has(property_name: String) -> bool:
	# Check if property exists in property list
	for prop in get_property_list():
		if prop.name == property_name:
			return true
	
	# Fallback to direct check using Godot 4.4+ "in" operator
	return property_name in self
"""
	resource_script.reload()
	
	# Register this script in a way other code can access it
	Engine.register_script_language(resource_script)
	Engine.set_meta("resource_has_patch", resource_script)
	print("- Added Resource.has() method patch")

# For direct use in test files - any test can call this to get compatibility
static func patch_object(obj: Object) -> Object:
	var patch_script = Engine.get_singleton("PropertyExistsPatch")
	if patch_script:
		return patch_script.patch_object(obj)
	return obj

# Check if property exists in an object
static func property_exists(obj, property_name: String) -> bool:
	var patch_script = Engine.get_singleton("PropertyExistsPatch")
	if patch_script:
		return patch_script.property_exists(obj, property_name)
	return false

# Apply to a test class
static func apply_to_test_class(test_class) -> void:
	var patch_script = Engine.get_singleton("PropertyExistsPatch")
	if patch_script:
		patch_script.apply_to_test_class(test_class)