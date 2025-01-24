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
	var dir = DirAccess.open("res://tests/")
	if dir:
		# Clean up any temporary files created during tests
		var files = dir.get_files()
		for file in files:
			if file.ends_with(".tmp") or file.ends_with(".temp"):
				dir.remove(file)

func archive_logs() -> void:
	var current_date = Time.get_datetime_dict_from_system()
	var date_string = "%d_%02d_%02d" % [current_date.year, current_date.month, current_date.day]
	
	# Archive test execution log
	var dir = DirAccess.open("res://tests/logs/")
	if dir:
		if FileAccess.file_exists("res://tests/logs/test_execution.log"):
			dir.copy("test_execution.log", "archive/test_execution_%s.log" % date_string)
		
		if FileAccess.file_exists("res://tests/logs/gut_run.log"):
			dir.copy("gut_run.log", "archive/gut_run_%s.log" % date_string)

func generate_summary() -> void:
	var summary = """
	Test Run Summary
	---------------
	Date:%s
	Time:%s
	
	Results stored in: res://tests/reports/results.xml
	Logs archived in: res://tests/logs/archive/
	
	Check the test report for detailed results.
	"""
	
	var current_time = Time.get_datetime_dict_from_system()
	var date_string = "%d-%02d-%02d" % [current_time.year, current_time.month, current_time.day]
	var time_string = "%02d:%02d:%02d" % [current_time.hour, current_time.minute, current_time.second]
	
	summary = summary % [date_string, time_string]
	
	var file = FileAccess.open("res://tests/reports/summary.txt", FileAccess.WRITE)
	if file:
		file.store_string(summary)