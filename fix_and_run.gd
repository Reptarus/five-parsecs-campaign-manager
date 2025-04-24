@tool
extends SceneTree

## Fix issues and run all tests

func _init():
	print("First fixing issues...")
	
	var fix_script = load("res://tools/fix_gut_issues.gd")
	if fix_script:
		print("Loaded fix script, executing...")
		var fixer = fix_script.new()
		yield_timeout(2.0) # Wait for fixes to complete
	else:
		print("Failed to load fix script!")
	
	print("Now running tests...")
	
	var cmdline_args = [
		"-s", "res://addons/gut/gut_cmdln.gd",
		"-d",
		"-gdir=res://tests/unit",
		"-glog=3",
		"-gexit"
	]
	
	var output = []
	var exit_code = OS.execute(OS.get_executable_path(), cmdline_args, output, true)
	
	for line in output:
		print(line)
	
	print("Tests completed with exit code: %d" % exit_code)
	quit()

func yield_timeout(seconds: float):
	var start_time = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_time < seconds * 1000:
		await process_frame