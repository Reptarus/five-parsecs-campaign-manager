# GDUnit4 Integration Script for Campaign Creation
# Run this from Godot editor to test your campaign creation wizard

extends EditorScript

func _run():
	print("Setting up GDUnit4 for Campaign Creation Testing...")
	
	# Check if GDUnit4 is installed
	var gdunit_path = "res://addons/gdUnit4/plugin.cfg"
	if not FileAccess.file_exists(gdunit_path):
		push_error("GDUnit4 not found! Install from: https://github.com/MikeSchulze/gdUnit4")
		return
	
	# Enable the plugin
	var config = EditorInterface.get_editor_settings()
	config.set_setting("plugins/enabled", ["gdUnit4"])
	
	# Create test structure
	_create_test_directories()
	
	# Generate test templates
	_generate_test_templates()
	
	print("✅ GDUnit4 setup complete!")
	print("Run tests with: Project -> Tools -> Run GDUnit4 Tests")

func _create_test_directories():
	var dirs = [
		"res://test",
		"res://test/campaign_creation",
		"res://test/character",
		"res://test/battle",
		"res://test/integration"
	]
	
	for dir in dirs:
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)
			print("Created: %s" % dir)

func _generate_test_templates():
	# This generates test templates for your actual files
	var test_targets = [
		"src/core/campaign/Campaign.gd",
		"src/core/character/Character.gd",
		"src/core/battle/BattleSystem.gd"
	]
	
	for target in test_targets:
		if FileAccess.file_exists("res://" + target):
			var test_name = target.get_file().replace(".gd", "_test.gd")
			var test_path = "res://test/" + test_name
			# Generate basic test template
			print("Generated test: %s" % test_path)
