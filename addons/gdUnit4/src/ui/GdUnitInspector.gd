@tool
class_name GdUnitInspecor
extends Panel


var _command_handler := GdUnitCommandHandler.instance()


func _ready() -> void:
	GdUnitCommandHandler.instance().gdunit_runner_start.connect(func() -> void:
		var control :Control = get_parent_control()
		# if the tab is floating we dont need to set as current
		if control is TabContainer:
			var tab_container :TabContainer = control
			for tab_index in tab_container.get_tab_count():
				if tab_container.get_tab_title(tab_index) == "GdUnit":
					tab_container.set_current_tab(tab_index)
	)

	# propagete the test_counters_changed signal to the progress bar
	%MainPanel.test_counters_changed.connect(%ProgressBar._on_test_counter_changed)

func _process(_delta: float) -> void:
	_command_handler._do_process()


func _on_status_bar_request_discover_tests() -> void:
	await _command_handler.cmd_discover_tests()
