extends Node

## Interactive Smoke Test Script - Phase 3C.1
## User-friendly interface for running integration smoke tests
## Provides real-time feedback and multiple execution modes

const IntegrationSmokeRunner = preload("res://src/core/testing/IntegrationSmokeRunner.gd")

## UI elements for interactive feedback
var main_container: VBoxContainer
var mode_selector: OptionButton
var start_button: Button
var results_display: RichTextLabel
var progress_bar: ProgressBar
var status_label: Label

## Test execution state
var smoke_runner: IntegrationSmokeRunner
var is_running: bool = false
var current_test_count: int = 0
var total_test_count: int = 0

func _ready() -> void:
	_create_interactive_ui()
	_connect_signals()
	
	print("=== Interactive Smoke Test Runner Ready ===")
	print("Use this interface to run integration smoke tests with real-time feedback")

func _create_interactive_ui() -> void:
	"""Create interactive UI for smoke test execution"""
	
	# Main container
	main_container = VBoxContainer.new()
	main_container.name = "SmokeTestInterface"
	add_child(main_container)
	
	# Title
	var title_label = Label.new()
	title_label.text = "🔥 Integration Smoke Test Runner - Phase 3C.1"
	title_label.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title_label)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = "Fast validation of backend systems and UI-backend connectivity"
	desc_label.add_theme_font_size_override("font_size", 14)
	main_container.add_child(desc_label)
	
	# Separator
	var separator1 = HSeparator.new()
	main_container.add_child(separator1)
	
	# Mode selection
	var mode_container = HBoxContainer.new()
	main_container.add_child(mode_container)
	
	var mode_label = Label.new()
	mode_label.text = "Test Mode:"
	mode_container.add_child(mode_label)
	
	mode_selector = OptionButton.new()
	mode_selector.add_item("Fast (< 10s) - Essential checks only")
	mode_selector.add_item("Comprehensive (< 30s) - All smoke tests")
	mode_selector.add_item("Continuous - Ongoing monitoring")
	mode_selector.add_item("Backend Validation - Syntax & Context Check")
	mode_selector.add_item("Workflow Simulation - Full E2E Testing")
	mode_selector.selected = 1  # Default to comprehensive
	mode_container.add_child(mode_selector)
	
	# Control buttons
	var button_container = HBoxContainer.new()
	main_container.add_child(button_container)
	
	start_button = Button.new()
	start_button.text = "🚀 Run Smoke Tests"
	start_button.pressed.connect(_on_start_button_pressed)
	button_container.add_child(start_button)
	
	var clear_button = Button.new()
	clear_button.text = "🧹 Clear Results"
	clear_button.pressed.connect(_on_clear_button_pressed)
	button_container.add_child(clear_button)
	
	# Progress tracking
	var progress_container = VBoxContainer.new()
	main_container.add_child(progress_container)
	
	status_label = Label.new()
	status_label.text = "Ready to run smoke tests"
	progress_container.add_child(status_label)
	
	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_container.add_child(progress_bar)
	
	# Results display
	var results_container = VBoxContainer.new()
	main_container.add_child(results_container)
	
	var results_label = Label.new()
	results_label.text = "Test Results:"
	results_container.add_child(results_label)
	
	results_display = RichTextLabel.new()
	results_display.custom_minimum_size = Vector2(800, 400)
	results_display.bbcode_enabled = true
	results_display.scroll_following = true
	results_display.text = "[color=gray]Test results will appear here...[/color]"
	results_container.add_child(results_display)

func _connect_signals() -> void:
	"""Connect smoke runner signals for real-time feedback"""
	pass  # Will be connected when smoke_runner is created

func _on_start_button_pressed() -> void:
	"""Handle start button press"""
	if is_running:
		print("Smoke tests already running, please wait...")
		return
	
	_start_smoke_tests()

func _on_clear_button_pressed() -> void:
	"""Handle clear button press"""
	results_display.text = "[color=gray]Test results cleared. Ready to run new tests...[/color]"
	progress_bar.value = 0
	status_label.text = "Ready to run smoke tests"
	current_test_count = 0
	total_test_count = 0

func _start_smoke_tests() -> void:
	"""Start smoke test execution with selected mode"""
	if is_running:
		return
	
	is_running = true
	start_button.disabled = true
	start_button.text = "⏳ Running Tests..."
	
	# Clear previous results
	results_display.text = ""
	progress_bar.value = 0
	current_test_count = 0
	
	# Get selected mode
	var selected_mode = mode_selector.selected
	var smoke_mode = IntegrationSmokeRunner.SmokeTestMode.COMPREHENSIVE
	
	match selected_mode:
		0:
			smoke_mode = IntegrationSmokeRunner.SmokeTestMode.FAST
			total_test_count = 2
		1:
			smoke_mode = IntegrationSmokeRunner.SmokeTestMode.COMPREHENSIVE
			total_test_count = 5
		2:
			smoke_mode = IntegrationSmokeRunner.SmokeTestMode.CONTINUOUS
			total_test_count = 2
		3:
			# Backend validation mode
			_run_backend_validation()
			return
		4:
			# Workflow simulation mode
			_run_workflow_simulation()
			return
	
	# Create and configure smoke runner
	smoke_runner = IntegrationSmokeRunner.new(smoke_mode)
	
	# Connect signals for real-time feedback
	smoke_runner.smoke_test_started.connect(_on_smoke_test_started)
	smoke_runner.smoke_test_completed.connect(_on_smoke_test_completed)
	smoke_runner.smoke_test_suite_completed.connect(_on_smoke_test_suite_completed)
	
	# Display initial status
	status_label.text = "Starting %s smoke tests..." % IntegrationSmokeRunner.SmokeTestMode.keys()[smoke_mode]
	_append_result("[color=blue][b]🔥 SMOKE TEST EXECUTION STARTED[/b][/color]")
	_append_result("[color=blue]Mode: %s[/color]" % IntegrationSmokeRunner.SmokeTestMode.keys()[smoke_mode])
	_append_result("[color=blue]Expected tests: %d[/color]" % total_test_count)
	_append_result("")
	
	# Execute smoke tests asynchronously
	var result = smoke_runner.execute_smoke_tests()
	# Note: In real implementation, this would be called asynchronously

func _on_smoke_test_started(test_name: String) -> void:
	"""Handle smoke test start"""
	status_label.text = "Running: %s" % test_name
	_append_result("[color=yellow]🔄 Starting: %s[/color]" % test_name)

func _on_smoke_test_completed(test_name: String, result: IntegrationSmokeRunner.SmokeTestResult, duration_ms: int) -> void:
	"""Handle smoke test completion"""
	current_test_count += 1
	
	# Update progress
	if total_test_count > 0:
		progress_bar.value = (float(current_test_count) / float(total_test_count)) * 100
	
	# Display result with appropriate color
	var result_color = "red"
	var result_icon = "❌"
	
	match result:
		IntegrationSmokeRunner.SmokeTestResult.PASSED:
			result_color = "green"
			result_icon = "✅"
		IntegrationSmokeRunner.SmokeTestResult.WARNING:
			result_color = "orange"
			result_icon = "⚠️"
		IntegrationSmokeRunner.SmokeTestResult.FAILED:
			result_color = "red"
			result_icon = "❌"
		IntegrationSmokeRunner.SmokeTestResult.CRITICAL:
			result_color = "purple"
			result_icon = "🚨"
	
	_append_result("[color=%s]%s %s (%dms) - %s[/color]" % [
		result_color, 
		result_icon, 
		test_name, 
		duration_ms,
		IntegrationSmokeRunner.SmokeTestResult.keys()[result]
	])

func _on_smoke_test_suite_completed(overall_result: IntegrationSmokeRunner.SmokeTestResult, total_duration_ms: int) -> void:
	"""Handle smoke test suite completion"""
	is_running = false
	start_button.disabled = false
	start_button.text = "🚀 Run Smoke Tests"
	
	progress_bar.value = 100
	
	# Display final results
	_append_result("")
	_append_result("[color=blue][b]🏁 SMOKE TEST EXECUTION COMPLETED[/b][/color]")
	
	var result_color = "red"
	var result_icon = "❌"
	var status_text = "FAILED"
	
	match overall_result:
		IntegrationSmokeRunner.SmokeTestResult.PASSED:
			result_color = "green"
			result_icon = "✅"
			status_text = "PASSED"
		IntegrationSmokeRunner.SmokeTestResult.WARNING:
			result_color = "orange"
			result_icon = "⚠️"
			status_text = "WARNING"
		IntegrationSmokeRunner.SmokeTestResult.FAILED:
			result_color = "red"
			result_icon = "❌"
			status_text = "FAILED"
		IntegrationSmokeRunner.SmokeTestResult.CRITICAL:
			result_color = "purple"
			result_icon = "🚨"
			status_text = "CRITICAL"
	
	_append_result("[color=%s][b]%s Overall Result: %s[/b][/color]" % [result_color, result_icon, status_text])
	_append_result("[color=blue]Total Duration: %dms[/color]" % total_duration_ms)
	_append_result("[color=blue]Tests Completed: %d/%d[/color]" % [current_test_count, total_test_count])
	
	# Update status label
	status_label.text = "Tests completed: %s (%dms)" % [status_text, total_duration_ms]
	
	# Generate detailed report
	_generate_detailed_report()
	
	# Cleanup
	if smoke_runner:
		smoke_runner.queue_free()
		smoke_runner = null

func _append_result(text: String) -> void:
	"""Append text to results display"""
	if results_display.text.is_empty() or results_display.text == "[color=gray]Test results will appear here...[/color]":
		results_display.text = text
	else:
		results_display.text += "\n" + text
	
	# Auto-scroll to bottom
	call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
	"""Scroll results display to bottom"""
	results_display.scroll_to_line(results_display.get_line_count() - 1)

func _generate_detailed_report() -> void:
	"""Generate detailed smoke test report"""
	if not smoke_runner:
		return
	
	var report = smoke_runner.get_smoke_test_report()
	
	_append_result("")
	_append_result("[color=cyan][b]📊 DETAILED REPORT[/b][/color]")
	_append_result("[color=cyan]Execution Time: %s[/color]" % report.execution_time)
	_append_result("[color=cyan]Mode: %s[/color]" % report.mode)
	_append_result("")
	
	# Results breakdown
	_append_result("[color=cyan][b]Results Breakdown:[/b][/color]")
	_append_result("[color=green]  ✅ Passed: %d[/color]" % report.results_breakdown.passed)
	_append_result("[color=orange]  ⚠️ Warnings: %d[/color]" % report.results_breakdown.warnings)
	_append_result("[color=red]  ❌ Failed: %d[/color]" % report.results_breakdown.failed)
	_append_result("[color=purple]  🚨 Critical: %d[/color]" % report.results_breakdown.critical)
	_append_result("")
	
	# Performance metrics
	_append_result("[color=cyan][b]Performance Metrics:[/b][/color]")
	_append_result("[color=cyan]  Average Test Duration: %dms[/color]" % report.performance_metrics.average_test_duration_ms)
	_append_result("[color=cyan]  Performance Rating: %s[/color]" % report.performance_metrics.performance_rating)
	_append_result("")
	
	# Individual test details
	_append_result("[color=cyan][b]Individual Test Results:[/b][/color]")
	for test_detail in report.test_details:
		var detail_color = "red"
		var detail_icon = "❌"
		
		match test_detail.result:
			"PASSED":
				detail_color = "green"
				detail_icon = "✅"
			"WARNING":
				detail_color = "orange"
				detail_icon = "⚠️"
			"FAILED":
				detail_color = "red"
				detail_icon = "❌"
			"CRITICAL":
				detail_color = "purple"
				detail_icon = "🚨"
		
		_append_result("[color=%s]  %s %s (%dms)[/color]" % [
			detail_color,
			detail_icon,
			test_detail.name,
			test_detail.duration_ms
		])
		_append_result("[color=%s]    %s[/color]" % [detail_color, test_detail.message])
	
	_append_result("")
	
	# Final recommendation
	_append_result("[color=cyan][b]🎯 RECOMMENDATION:[/b][/color]")
	match report.overall_result:
		"PASSED":
			_append_result("[color=green]System is ready for production use 🚀[/color]")
		"WARNING":
			_append_result("[color=orange]System has minor issues but is usable ⚠️[/color]")
		"FAILED":
			_append_result("[color=red]System has significant issues, investigate before use ❌[/color]")
		"CRITICAL":
			_append_result("[color=purple]System has critical failures, immediate attention required 🚨[/color]")
	
	_append_result("")
	_append_result("[color=gray]--- End of Report ---[/color]")

## Utility methods for command-line usage

static func run_fast_smoke_tests() -> void:
	"""Run fast smoke tests programmatically"""
	print("Running fast smoke tests...")
	var runner = IntegrationSmokeRunner.new(IntegrationSmokeRunner.SmokeTestMode.FAST)
	var result = runner.execute_smoke_tests()
	print("Fast smoke tests result: %s" % IntegrationSmokeRunner.SmokeTestResult.keys()[result])

static func run_comprehensive_smoke_tests() -> void:
	"""Run comprehensive smoke tests programmatically"""
	print("Running comprehensive smoke tests...")
	var runner = IntegrationSmokeRunner.new(IntegrationSmokeRunner.SmokeTestMode.COMPREHENSIVE)
	var result = runner.execute_smoke_tests()
	print("Comprehensive smoke tests result: %s" % IntegrationSmokeRunner.SmokeTestResult.keys()[result])

static func run_continuous_monitoring() -> void:
	"""Start continuous monitoring mode"""
	print("Starting continuous monitoring mode...")
	var runner = IntegrationSmokeRunner.new(IntegrationSmokeRunner.SmokeTestMode.CONTINUOUS)
	# In a real implementation, this would run periodically
	var result = runner.execute_smoke_tests()
	print("Continuous monitoring result: %s" % IntegrationSmokeRunner.SmokeTestResult.keys()[result])

## Command-line interface for automated testing

func _run_backend_validation() -> void:
	"""Run Python-based backend validation"""
	is_running = true
	start_button.disabled = true
	start_button.text = "⏳ Running Backend Validation..."
	
	results_display.text = ""
	status_label.text = "Running comprehensive backend validation..."
	
	_append_result("[color=blue][b]🔧 BACKEND VALIDATION STARTED[/b][/color]")
	_append_result("[color=blue]Running Python test runner with backend validation mode[/color]")
	_append_result("")
	
	# Execute Python backend validation
	var python_command = [
		"python",
		"automation/test_runner.py",
		"--mode", "backend",
		"--godot-path", "godot",  # You may need to adjust this path
		"--output-format", "text"
	]
	
	var output = []
	OS.execute("python", ["automation/test_runner.py", "--mode", "backend", "--output-format", "text"], output)
	
	# Display results
	for line in output:
		_append_result("[color=white]%s[/color]" % line)
	
	is_running = false
	start_button.disabled = false
	start_button.text = "🚀 Run Smoke Tests"
	status_label.text = "Backend validation completed"

func _run_workflow_simulation() -> void:
	"""Run comprehensive workflow simulation"""
	is_running = true
	start_button.disabled = true
	start_button.text = "⏳ Running Workflow Simulation..."
	
	results_display.text = ""
	status_label.text = "Running comprehensive workflow simulation..."
	
	_append_result("[color=blue][b]🚀 WORKFLOW SIMULATION STARTED[/b][/color]")
	_append_result("[color=blue]Executing headless workflow simulator[/color]")
	_append_result("")
	
	# Execute headless workflow simulator
	var output = []
	OS.execute("godot", ["--headless", "--script", "scripts/headless_workflow_simulator.gd"], output)
	
	# Display results
	for line in output:
		_append_result("[color=white]%s[/color]" % line)
	
	is_running = false
	start_button.disabled = false
	start_button.text = "🚀 Run Smoke Tests"
	status_label.text = "Workflow simulation completed"

func _unhandled_input(event: InputEvent) -> void:
	"""Handle keyboard shortcuts for quick test execution"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				print("F1 pressed - Running fast smoke tests")
				if not is_running:
					mode_selector.selected = 0
					_start_smoke_tests()
			KEY_F2:
				print("F2 pressed - Running comprehensive smoke tests")
				if not is_running:
					mode_selector.selected = 1
					_start_smoke_tests()
			KEY_F3:
				print("F3 pressed - Running continuous monitoring")
				if not is_running:
					mode_selector.selected = 2
					_start_smoke_tests()
			KEY_F4:
				print("F4 pressed - Running backend validation")
				if not is_running:
					mode_selector.selected = 3
					_start_smoke_tests()
			KEY_F5:
				print("F5 pressed - Running workflow simulation")
				if not is_running:
					mode_selector.selected = 4
					_start_smoke_tests()
			KEY_F6:
				print("F6 pressed - Running complete validation suite")
				if not is_running:
					_run_complete_validation_suite()
			KEY_ESCAPE:
				print("ESC pressed - Clearing results")
				_on_clear_button_pressed()

func _run_complete_validation_suite() -> void:
	"""Run complete validation suite combining backend validation and workflow simulation"""
	is_running = true
	start_button.disabled = true
	start_button.text = "⏳ Running Complete Validation Suite..."
	
	results_display.text = ""
	status_label.text = "Running comprehensive end-to-end validation..."
	
	_append_result("[color=blue][b]🚀 COMPLETE VALIDATION SUITE STARTED[/b][/color]")
	_append_result("[color=blue]Comprehensive backend validation + workflow simulation[/color]")
	_append_result("[color=blue]This combines Python static analysis with GDScript runtime validation[/color]")
	_append_result("")
	
	# Phase 1: Python Backend Validation
	_append_result("[color=cyan][b]Phase 1: Backend Syntax & Context Validation[/b][/color]")
	status_label.text = "Phase 1/2: Running Python backend validation..."
	
	var python_output = []
	var python_exit_code = OS.execute("python", [
		"automation/test_runner.py", 
		"--mode", "backend", 
		"--output-format", "text"
	], python_output)
	
	# Display Python validation results
	if python_exit_code == 0:
		_append_result("[color=green]✅ Phase 1: Backend validation PASSED[/color]")
	else:
		_append_result("[color=red]❌ Phase 1: Backend validation FAILED (exit code: %d)[/color]" % python_exit_code)
	
	for line in python_output:
		_append_result("[color=white]  %s[/color]" % line)
	
	_append_result("")
	
	# Phase 2: Workflow Simulation
	_append_result("[color=cyan][b]Phase 2: Headless Workflow Simulation[/b][/color]")
	status_label.text = "Phase 2/2: Running headless workflow simulation..."
	
	var workflow_output = []
	var workflow_exit_code = OS.execute("godot", [
		"--headless", 
		"--script", 
		"scripts/headless_workflow_simulator.gd"
	], workflow_output)
	
	# Display workflow simulation results
	if workflow_exit_code == 0:
		_append_result("[color=green]✅ Phase 2: Workflow simulation PASSED[/color]")
	else:
		_append_result("[color=red]❌ Phase 2: Workflow simulation FAILED (exit code: %d)[/color]" % workflow_exit_code)
	
	for line in workflow_output:
		_append_result("[color=white]  %s[/color]" % line)
	
	_append_result("")
	
	# Final Results Summary
	_append_result("[color=blue][b]🏁 COMPLETE VALIDATION SUITE FINISHED[/b][/color]")
	
	var overall_success = (python_exit_code == 0 and workflow_exit_code == 0)
	if overall_success:
		_append_result("[color=green][b]✅ OVERALL RESULT: PASSED[/b][/color]")
		_append_result("[color=green]Both backend validation and workflow simulation completed successfully[/color]")
		_append_result("[color=green]System is ready for user input testing - no syntax/context errors detected[/color]")
	else:
		_append_result("[color=red][b]❌ OVERALL RESULT: FAILED[/b][/color]")
		_append_result("[color=red]Issues detected that could cause problems during user testing[/color]")
		if python_exit_code != 0:
			_append_result("[color=red]• Backend validation detected syntax or context errors[/color]")
		if workflow_exit_code != 0:
			_append_result("[color=red]• Workflow simulation detected runtime issues[/color]")
		_append_result("[color=red]Review the detailed output above and fix issues before user testing[/color]")
	
	# Reset UI state
	is_running = false
	start_button.disabled = false
	start_button.text = "🚀 Run Smoke Tests"
	status_label.text = "Complete validation suite finished: %s" % ("PASSED" if overall_success else "FAILED")

func _notification(what: int) -> void:
	"""Handle cleanup on exit"""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if smoke_runner:
			smoke_runner.queue_free()
		get_tree().quit()