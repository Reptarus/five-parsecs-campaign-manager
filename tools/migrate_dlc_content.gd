@tool
extends SceneTree

## DLC Content Migration CLI Tool
##
## Command-line tool for migrating and validating DLC content.
##
## Usage:
##   godot --headless --script tools/migrate_dlc_content.gd -- <command> [options]
##
## Commands:
##   migrate <input> <output> <type> <dlc_id>  - Migrate single file
##   batch                                      - Run batch migration plan
##   validate <file>                            - Validate single file
##   audit <file>                               - Audit file for DLC content
##   test                                       - Test all autoloads

const DLCContentMigrator = preload("res://src/core/utils/DLCContentMigrator.gd")
const DLCContentValidator = preload("res://src/core/utils/DLCContentValidator.gd")
const DLCAutoloadSetup = preload("res://src/core/utils/DLCAutoloadSetup.gd")

var migrator: DLCContentMigrator
var validator: DLCContentValidator
var autoload_setup: DLCAutoloadSetup

func _init() -> void:
	migrator = DLCContentMigrator.new()
	validator = DLCContentValidator.new()
	autoload_setup = DLCAutoloadSetup.new()

	# Parse command line arguments
	var args := OS.get_cmdline_args()

	# Skip Godot's own arguments
	var user_args := []
	var found_separator := false
	for arg in args:
		if found_separator:
			user_args.append(arg)
		elif arg == "--":
			found_separator = true

	if user_args.is_empty():
		print_usage()
		quit()
		return

	var command := user_args[0]

	match command:
		"migrate":
			if user_args.size() < 5:
				print("Error: migrate requires 4 arguments")
				print("Usage: migrate <input> <output> <type> <dlc_id>")
				quit(1)
				return
			cmd_migrate(user_args[1], user_args[2], user_args[3], user_args[4])

		"migrate-core":
			if user_args.size() < 4:
				print("Error: migrate-core requires 3 arguments")
				print("Usage: migrate-core <input> <output> <type>")
				quit(1)
				return
			cmd_migrate_core(user_args[1], user_args[2], user_args[3])

		"batch":
			cmd_batch_migrate()

		"validate":
			if user_args.size() < 2:
				print("Error: validate requires file path")
				print("Usage: validate <file>")
				quit(1)
				return
			cmd_validate(user_args[1])

		"audit":
			if user_args.size() < 2:
				print("Error: audit requires file path")
				print("Usage: audit <file>")
				quit(1)
				return
			cmd_audit(user_args[1])

		"test":
			cmd_test_autoloads()

		"help":
			print_usage()

		_:
			print("Unknown command: %s" % command)
			print_usage()
			quit(1)

	quit()

func print_usage() -> void:
	print("""
=== DLC Content Migration Tool ===

Usage:
  godot --headless --script tools/migrate_dlc_content.gd -- <command> [options]

Commands:
  migrate <input> <output> <type> <dlc_id>
      Migrate a single file to DLC format
      Example: migrate data/species.json data/species_tt.json species trailblazers_toolkit

  migrate-core <input> <output> <type>
      Migrate a file marking it as core content
      Example: migrate-core data/species.json data/species_core.json species

  batch
      Run batch migration using predefined migration plan
      Migrates all known files to correct DLC format

  validate <file>
      Validate a file against DLC schemas
      Example: validate data/species.json

  audit <file>
      Audit a file to identify DLC content distribution
      Example: audit data/species.json

  test
      Test all DLC autoloads are properly configured

  help
      Show this help message

Examples:
  # Migrate Trailblazer's Toolkit species
  godot --headless --script tools/migrate_dlc_content.gd -- migrate \\
    data/dlc/tt_species.json \\
    data/migrated/tt_species.json \\
    species \\
    trailblazers_toolkit

  # Mark core content
  godot --headless --script tools/migrate_dlc_content.gd -- migrate-core \\
    data/species.json \\
    data/migrated/species_core.json \\
    species

  # Run full batch migration
  godot --headless --script tools/migrate_dlc_content.gd -- batch

  # Validate migrated file
  godot --headless --script tools/migrate_dlc_content.gd -- validate \\
    data/migrated/tt_species.json

  # Audit existing file
  godot --headless --script tools/migrate_dlc_content.gd -- audit \\
    data/species.json

==================================
""")

func cmd_migrate(input: String, output: String, content_type: String, dlc_id: String) -> void:
	print("\n=== Migrating File ===")
	print("Input: %s" % input)
	print("Output: %s" % output)
	print("Type: %s" % content_type)
	print("DLC: %s" % dlc_id)
	print()

	if migrator.migrate_file(input, output, content_type, dlc_id, false):
		print("✓ Migration successful")
		migrator.print_migration_log()
	else:
		print("✗ Migration failed")
		quit(1)

func cmd_migrate_core(input: String, output: String, content_type: String) -> void:
	print("\n=== Migrating Core Content ===")
	print("Input: %s" % input)
	print("Output: %s" % output)
	print("Type: %s" % content_type)
	print()

	if migrator.migrate_file(input, output, content_type, "", true):
		print("✓ Migration successful")
		migrator.print_migration_log()
	else:
		print("✗ Migration failed")
		quit(1)

func cmd_batch_migrate() -> void:
	print("\n=== Batch Migration ===")
	print("Generating migration plan...")

	var plan := migrator.generate_migration_plan()
	print("Plan includes %d files\n" % plan.size())

	# Create output directory if needed
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("data/migrated"):
		dir.make_dir_recursive("data/migrated")
		print("Created output directory: data/migrated")

	var results := migrator.batch_migrate(plan)

	print("\n=== Batch Migration Results ===")
	print("Total: %d" % results.total)
	print("Success: %d" % results.success)
	print("Failed: %d" % results.failed)

	if results.failed > 0:
		print("\nErrors:")
		for error in results.errors:
			print("  • %s" % error)
		quit(1)
	else:
		print("\n✓ All migrations successful")
		migrator.print_migration_log()

func cmd_validate(file_path: String) -> void:
	print("\n=== Validating File ===")
	print("File: %s\n" % file_path)

	var validation := validator.validate_file(file_path)
	validator.print_validation_report(validation)

	if not validation.valid:
		quit(1)

func cmd_audit(file_path: String) -> void:
	print("\n=== Auditing File ===")
	print("File: %s\n" % file_path)

	var audit := migrator.audit_file(file_path)
	migrator.print_audit_report(audit)

func cmd_test_autoloads() -> void:
	print("\n=== Testing DLC Autoloads ===\n")

	# Verify autoloads
	autoload_setup.print_diagnostics()

	# Test functionality
	var all_working := autoload_setup.test_autoloads()

	if not all_working:
		print("\n✗ Some autoloads failed")
		quit(1)
	else:
		print("\n✓ All autoloads working correctly")
