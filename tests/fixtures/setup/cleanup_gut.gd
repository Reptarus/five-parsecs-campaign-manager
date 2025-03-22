@tool
extends Node

## Cleanup script that runs after all tests are complete
##
## Handles cleanup of temporary files, test artifacts, and logging

func _init() -> void:
	cleanup_temp_files()
	archive_logs()
	generate_summary()

func cleanup_temp_files() -> void:
	var dir: DirAccess = DirAccess.open("res://tests/")
	if dir:
		# Clean up any temporary files created during tests
		var files: PackedStringArray = dir.get_files()
		for file_name: String in files:
			if file_name.ends_with(".tmp") or file_name.ends_with(".temp"):
				var _err: Error = dir.remove(file_name)
				# Optionally handle error

func archive_logs() -> void:
	var current_date: Dictionary = Time.get_datetime_dict_from_system()
	var date_string: String = "%d_%02d_%02d" % [current_date.year, current_date.month, current_date.day]
	
	# Archive test execution log
	var dir: DirAccess = DirAccess.open("res://tests/logs/")
	if dir:
		if FileAccess.file_exists("res://tests/logs/test_execution.log"):
			var _err: Error = dir.copy("test_execution.log", "archive/test_execution_%s.log" % date_string)
			# Optionally handle error
		
		if FileAccess.file_exists("res://tests/logs/gut_run.log"):
			var _err: Error = dir.copy("gut_run.log", "archive/gut_run_%s.log" % date_string)
			# Optionally handle error

func generate_summary() -> void:
	var summary: String = """
	Test Run Summary
	---------------
	Date:%s
	Time:%s
	
	Results stored in: res://tests/reports/results.xml
	Logs archived in: res://tests/logs/archive/
	
	Check the test report for detailed results.
	"""
	
	var current_time: Dictionary = Time.get_datetime_dict_from_system()
	var date_string: String = "%d-%02d-%02d" % [current_time.year, current_time.month, current_time.day]
	var time_string: String = "%02d:%02d:%02d" % [current_time.hour, current_time.minute, current_time.second]
	
	summary = summary % [date_string, time_string]
	
	var file: FileAccess = FileAccess.open("res://tests/reports/summary.txt", FileAccess.WRITE)
	if file:
		var _success: bool = file.store_string(summary)
		# Optionally handle error