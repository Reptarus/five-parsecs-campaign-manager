const GutUtils = preload("res://addons/gut/utils.gd")

# ##############################################################################
#(G)odot (U)nit (T)est class
#
# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2025 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################
# This class wraps around the various printers and supplies formatting for the
# various message types (error, warning, etc).
# ##############################################################################
var types: Dictionary = {
	debug = 'debug',
	deprecated = 'deprecated',
	error = 'error',
	failed = 'failed',
	info = 'info',
	normal = 'normal',
	orphan = 'orphan',
	passed = 'passed',
	pending = 'pending',
	risky = 'risky',
	warn = 'warn',
}

var fmts: Dictionary = {
	red = 'red',
	yellow = 'yellow',
	green = 'green',

	bold = 'bold',
	underline = 'underline',

	none = null
}

var _type_data: Dictionary = {
	types.debug: {disp = 'DEBUG', enabled = true, fmt = fmts.bold},
	types.deprecated: {disp = 'DEPRECATED', enabled = true, fmt = fmts.none},
	types.error: {disp = 'ERROR', enabled = true, fmt = fmts.red},
	types.failed: {disp = 'Failed', enabled = true, fmt = fmts.red},
	types.info: {disp = 'INFO', enabled = true, fmt = fmts.bold},
	types.normal: {disp = 'NORMAL', enabled = true, fmt = fmts.none},
	types.orphan: {disp = 'Orphans', enabled = true, fmt = fmts.yellow},
	types.passed: {disp = 'Passed', enabled = true, fmt = fmts.green},
	types.pending: {disp = 'Pending', enabled = true, fmt = fmts.yellow},
	types.risky: {disp = 'Risky', enabled = true, fmt = fmts.yellow},
	types.warn: {disp = 'WARNING', enabled = true, fmt = fmts.yellow},
}

var _logs: Dictionary = {
	types.warn: [],
	types.error: [],
	types.info: [],
	types.debug: [],
	types.deprecated: [],
}

var _printers: Dictionary = {
	terminal = null,
	gui = null,
	console = null
}

var _gut: Object = null
var _indent_level: int = 0
var _min_indent_level: int = 0
var _indent_string: String = '    '
var _less_test_names: bool = false
var _yield_calls: int = 0
var _last_yield_text: String = ''

func _init() -> void:
	# Try to safely create printer instances
	_printers.terminal = null
	_printers.console = null
	
	# Try to create terminal printer
	if GutUtils != null and "Printers" in GutUtils and GutUtils.Printers != null:
		if "TerminalPrinter" in GutUtils.Printers:
			_printers.terminal = GutUtils.Printers.TerminalPrinter.new()
		if "ConsolePrinter" in GutUtils.Printers:
			_printers.console = GutUtils.Printers.ConsolePrinter.new()
	
	# Disable console printer by default
	if _printers.console != null and _printers.console.has_method("set_disabled"):
		_printers.console.set_disabled(true)

func get_indent_text() -> String:
	var pad = ''
	for i in range(_indent_level):
		pad += _indent_string

	return pad

func _indent_text(text: String) -> String:
	var to_return = text
	var ending_newline = ''

	if (text.ends_with("\n")):
		ending_newline = "\n"
		to_return = to_return.left(to_return.length() - 1)

	var pad = get_indent_text()
	to_return = to_return.replace("\n", "\n" + pad)
	to_return += ending_newline

	return pad + to_return

func _should_print_to_printer(key_name: String) -> bool:
	return _printers.has(key_name) and _printers[key_name] != null and !_printers[key_name].get_disabled()

func _print_test_name() -> bool:
	if (_gut == null):
		return false

	# Check if _gut has the required method before trying to call it
	if not _gut.has_method("get_current_test_object"):
		# This is a fallback for Godot 4.4 compatibility
		return false

	var cur_test = _gut.get_current_test_object()
	if (cur_test == null):
		return false

	# Check if cur_test has the required property
	if not cur_test.has("has_printed_name"):
		# Add the property if it doesn't exist
		cur_test.set("has_printed_name", false)

	if (!cur_test.has_printed_name):
		var param_text = ''
		# Check if cur_test has the required property
		if cur_test.has("arg_count") and cur_test.arg_count > 0:
			# Just an FYI, parameter_handler in gut might not be set yet so can't
			# use it here for cooler output.
			param_text = '<parameterized>'
		_output(str('* ', cur_test.name, param_text, "\n"))
		cur_test.has_printed_name = true
		
	return true

func _output(text: String, fmt = null) -> void:
	for key in _printers:
		if (_should_print_to_printer(key)):
			# Ensure printer has send method before calling it
			if _printers[key].has_method("send"):
				_printers[key].send(text, fmt)

func _log(text: String, fmt = fmts.none) -> void:
	_print_test_name()
	var indented = _indent_text(text)
	_output(indented, fmt)

# ---------------
# Get Methods
# ---------------
func get_warnings() -> Array:
	return get_log_entries(types.warn)

func get_errors() -> Array:
	return get_log_entries(types.error)

func get_infos() -> Array:
	return get_log_entries(types.info)

func get_debugs() -> Array:
	return get_log_entries(types.debug)

func get_deprecated() -> Array:
	return get_log_entries(types.deprecated)

func get_count(log_type = null) -> int:
	var count = 0
	if (log_type == null):
		for key in _logs:
			count += _logs[key].size()
	else:
		count = _logs[log_type].size()
	return count

func get_log_entries(log_type: String) -> Array:
	if not _logs.has(log_type):
		return []
	return _logs[log_type]

# ---------------
# Log methods
# ---------------
func _output_type(type: String, text: String) -> void:
	if not _type_data.has(type):
		push_warning("Unknown log type: " + type)
		return
		
	var td = _type_data[type]
	if (!td.enabled):
		# if(_logs.has(type)):
		# 	_logs[type].append(text)
		return

	_print_test_name()
	if (type != types.normal):
		if (_logs.has(type)):
			_logs[type].append(text)

		var start = str('[', td.disp, ']')
		if (text != null and text != ''):
			start += ':  '
		else:
			start += ' '
		var indented_start = _indent_text(start)
		var indented_end = _indent_text(text)
		indented_end = indented_end.lstrip(_indent_string)
		_output(indented_start, td.fmt)
		_output(indented_end + "\n")


func debug(text: String) -> void:
	_output_type(types.debug, text)

# supply some text or the name of the deprecated method and the replacement.
func deprecated(text: String, alt_method: String = "") -> void:
	var msg = text
	if (alt_method and alt_method != ""):
		msg = str('The method ', text, ' is deprecated, use ', alt_method, ' instead.')
	_output_type(types.deprecated, msg)

func error(text: String) -> void:
	_output_type(types.error, text)
	if (_gut != null and _gut.has_method("_fail_for_error")):
		_gut._fail_for_error(text)

func failed(text: String) -> void:
	_output_type(types.failed, text)

func info(text: String) -> void:
	_output_type(types.info, text)

func orphan(text: String) -> void:
	_output_type(types.orphan, text)

func passed(text: String) -> void:
	_output_type(types.passed, text)

func pending(text: String) -> void:
	_output_type(types.pending, text)

func risky(text: String) -> void:
	_output_type(types.risky, text)

func warn(text: String) -> void:
	_output_type(types.warn, text)

func log(text: String = '', fmt = fmts.none) -> void:
	end_yield()
	if (text == ''):
		_output("\n")
	else:
		_log(text + "\n", fmt)

func lograw(text: String, fmt = fmts.none) -> void:
	_output(text, fmt)

# Print the test name if we aren't skipping names of tests that pass (basically
# what _less_test_names means))
func log_test_name() -> bool:
	# suppress output if we haven't printed the test name yet and
	# what to print is the test name.
	if (!_less_test_names):
		return _print_test_name()
	return false

# ---------------
# Misc
# ---------------
func get_gut() -> Object:
	return _gut

func set_gut(gut: Object) -> void:
	_gut = gut
	if (_gut == null):
		_printers.gui = null
	else:
		if (_printers.gui == null):
			# Try to create the GUI printer directly and handle any errors silently
			var new_printer = null
			
			# Safely attempt to create a new printer
			if GutUtils != null and "Printers" in GutUtils and GutUtils.Printers != null:
				# Check if the GutGuiPrinter property exists directly in GutUtils.Printers
				if "GutGuiPrinter" in GutUtils.Printers:
					# Try to instantiate it
					new_printer = GutUtils.Printers.GutGuiPrinter.new()
			
			# If successful, assign the new printer
			if new_printer != null:
				_printers.gui = new_printer


func get_indent_level() -> int:
	return _indent_level

func set_indent_level(indent_level: int) -> void:
	_indent_level = max(_min_indent_level, indent_level)

func get_indent_string() -> String:
	return _indent_string

func set_indent_string(indent_string: String) -> void:
	_indent_string = indent_string

func clear() -> void:
	for key in _logs:
		_logs[key].clear()

func inc_indent() -> void:
	_indent_level += 1

func dec_indent() -> void:
	_indent_level = max(_min_indent_level, _indent_level - 1)

func is_type_enabled(type: String) -> bool:
	if not _type_data.has(type):
		return false
	return _type_data[type].enabled

func set_type_enabled(type: String, is_enabled: bool) -> void:
	if not _type_data.has(type):
		push_warning("Unknown log type: " + type)
		return
	_type_data[type].enabled = is_enabled

func get_less_test_names() -> bool:
	return _less_test_names

func set_less_test_names(less_test_names: bool) -> void:
	_less_test_names = less_test_names

func disable_printer(name: String, is_disabled: bool) -> void:
	if not _printers.has(name):
		push_warning("Unknown printer: " + name)
		return
		
	if (_printers[name] != null and _printers[name].has_method("set_disabled")):
		_printers[name].set_disabled(is_disabled)

func is_printer_disabled(name: String) -> bool:
	if not _printers.has(name) or _printers[name] == null:
		return true
		
	if not _printers[name].has_method("get_disabled"):
		return true
		
	return _printers[name].get_disabled()

func disable_formatting(is_disabled: bool) -> void:
	for key in _printers:
		if _printers[key] != null and _printers[key].has_method("set_format_enabled"):
			_printers[key].set_format_enabled(!is_disabled)

func disable_all_printers(is_disabled: bool) -> void:
	for p in _printers:
		disable_printer(p, is_disabled)

func get_printer(printer_key: String) -> Variant:
	if not _printers.has(printer_key):
		return null
	return _printers[printer_key]

func _yield_text_terminal(text: String) -> void:
	var printer = _printers.get('terminal')
	if printer == null:
		return
		
	if not printer.has_method("clear_line") or not printer.has_method("back"):
		return
		
	if (_yield_calls != 0):
		printer.clear_line()
		printer.back(_last_yield_text.length())
	
	if printer.has_method("send"):
		printer.send(text, fmts.yellow)

func _end_yield_terminal() -> void:
	var printer = _printers.get('terminal')
	if printer == null:
		return
		
	if not printer.has_method("clear_line") or not printer.has_method("back"):
		return
		
	printer.clear_line()
	printer.back(_last_yield_text.length())

func _yield_text_gui(text: String) -> void:
	# This function is intentionally left empty
	pass
	# var lbl = _gut.get_gui().get_waiting_label()
	# lbl.visible = true
	# lbl.set_bbcode('[color=yellow]' + text + '[/color]')

func _end_yield_gui() -> void:
	# This function is intentionally left empty
	pass
	# var lbl = _gut.get_gui().get_waiting_label()
	# lbl.visible = false
	# lbl.set_text('')

# This is used for displaying the "yield detected" and "yielding to" messages.
func yield_msg(text: String) -> void:
	if (_type_data.has(types.warn) and _type_data[types.warn].enabled):
		self.log(text, fmts.yellow)

# This is used for the animated "waiting" message
func yield_text(text: String) -> void:
	_yield_text_terminal(text)
	_yield_text_gui(text)
	_last_yield_text = text
	_yield_calls += 1

# This is used for the animated "waiting" message
func end_yield() -> void:
	if (_yield_calls == 0):
		return
	_end_yield_terminal()
	_end_yield_gui()
	_yield_calls = 0
	_last_yield_text = ''

func get_gui_bbcode() -> String:
	var printer = _printers.get('gui')
	if printer == null:
		return ""
		
	if not printer.has_method("get_bbcode"):
		return ""
		
	return printer.get_bbcode()
