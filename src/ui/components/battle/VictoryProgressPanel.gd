@tool
extends PanelContainer
class_name VictoryProgressPanel

## Victory Progress Tracker - Displays battle objective status
## Shows victory conditions, progress percentage, and turns remaining

signal victory_condition_met(condition_type: String)
signal defeat_condition_triggered(reason: String)
signal objective_status_changed(objective_id: String, status: String)
## Player override of objective progress (companion app — the player owns the
## physical table). value is int for counter objectives, bool for toggles.
signal objective_progress_input(condition_id: String, value)

const StepperControlScene = preload("res://src/ui/components/common/StepperControl.gd")

# Design system constants (from UIColors)
const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const SPACING_LG := UIColors.SPACING_LG
const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN

const COLOR_ELEVATED := UIColors.COLOR_ELEVATED
const COLOR_TERTIARY := UIColors.COLOR_TERTIARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_ACCENT
const COLOR_SUCCESS := UIColors.COLOR_SUCCESS
const COLOR_WARNING := UIColors.COLOR_WARNING
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY

const FONT_SIZE_SM := UIColors.FONT_SIZE_SM
const FONT_SIZE_MD := UIColors.FONT_SIZE_MD
const FONT_SIZE_LG := UIColors.FONT_SIZE_LG

# Victory condition data
var _conditions: Array[Dictionary] = []
var _overall_progress: float = 0.0
var _turns_remaining: int = -1  # -1 = no limit

# UI references
var _header_label: Label
var _progress_bar: ProgressBar
var _progress_label: Label
var _conditions_container: VBoxContainer
var _turns_label: Label
# set_conditions() now has external callers (BattleObjectiveTracker) that may
# (in edge orderings) fire before _ready() builds the UI. Data is stored either
# way; rendering is deferred until the UI exists.
var _ui_built: bool = false

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	## Build UI programmatically with proper design system styling
	# Set panel background style
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(COLOR_ELEVATED, 0.9)  # Slightly transparent
	panel_style.border_color = COLOR_BORDER
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(SPACING_MD)
	add_theme_stylebox_override("panel", panel_style)

	# Main vertical container
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", SPACING_SM)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(main_vbox)

	# === HEADER ===
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", SPACING_SM)

	var icon := Label.new()
	icon.text = "🎯"
	icon.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	icon.add_theme_color_override("font_color", COLOR_ACCENT)
	header_hbox.add_child(icon)

	_header_label = Label.new()
	_header_label.text = "VICTORY CONDITIONS"
	_header_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_header_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(_header_label)

	main_vbox.add_child(header_hbox)

	# === SEPARATOR ===
	var separator := HSeparator.new()
	separator.modulate = COLOR_BORDER
	main_vbox.add_child(separator)

	# === PROGRESS BAR ===
	var progress_section := VBoxContainer.new()
	progress_section.add_theme_constant_override("separation", 4)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 20)
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false

	# Style progress bar
	var progress_bg := StyleBoxFlat.new()
	progress_bg.bg_color = COLOR_TERTIARY
	progress_bg.set_corner_radius_all(4)
	_progress_bar.add_theme_stylebox_override("background", progress_bg)

	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = COLOR_ACCENT
	progress_fill.set_corner_radius_all(4)
	_progress_bar.add_theme_stylebox_override("fill", progress_fill)

	progress_section.add_child(_progress_bar)

	# Progress percentage label
	_progress_label = Label.new()
	_progress_label.text = "Progress: 0%"
	_progress_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_progress_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_section.add_child(_progress_label)

	main_vbox.add_child(progress_section)

	# === CONDITIONS CONTAINER ===
	_conditions_container = VBoxContainer.new()
	_conditions_container.add_theme_constant_override("separation", SPACING_SM)
	_conditions_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_conditions_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_conditions_container)

	# === TURNS REMAINING ===
	_turns_label = Label.new()
	_turns_label.text = "Turns Remaining: --"
	_turns_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	_turns_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_turns_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turns_label.visible = false
	main_vbox.add_child(_turns_label)

	# UI is now built — render any state set before _ready().
	_ui_built = true
	_update_conditions_display()
	_recalculate_overall_progress()
	_update_turns_display()

func set_conditions(conditions: Array) -> void:
	## Set victory conditions to track
	_conditions.clear()
	for condition in conditions:
		var condition_dict := {
			"id": condition.get("id", ""),
			"name": condition.get("name", "Unknown Objective"),
			"description": condition.get("description", ""),
			"progress": condition.get("progress", 0.0),
			"status": condition.get("status", "pending"),
			# Companion-app override metadata (BattleObjectiveTracker rows).
			"interactive": condition.get("interactive", false),
			"input_kind": condition.get("input_kind", "none"),
			"input_max": condition.get("input_max", 1)
		}
		_conditions.append(condition_dict)
	_update_conditions_display()
	_recalculate_overall_progress()

func update_condition_progress(condition_id: String, progress: float, status: String = "") -> void:
	## Update specific condition progress (0.0-1.0)
	for condition in _conditions:
		if condition.get("id") == condition_id:
			var old_status: String = str(condition.get("status", "pending"))
			condition["progress"] = clamp(progress, 0.0, 1.0)
			if status != "":
				condition["status"] = status
			# Auto-complete on full progress (one-shot via status delta below)
			if progress >= 1.0 and str(condition.get("status", "")) != "complete":
				condition["status"] = "complete"
			var new_status: String = str(condition.get("status", "pending"))

			# Emit ONLY on an actual status change. This signal is named
			# *_changed and is logged to the battle log — firing it every
			# refresh (e.g. "pending" each round) is spam. Also routes the
			# dedicated complete/defeat signals, which previously never fired.
			if new_status != old_status:
				objective_status_changed.emit(condition_id, new_status)
				if new_status == "complete":
					victory_condition_met.emit(condition_id)
				elif new_status == "failed":
					defeat_condition_triggered.emit(condition_id)

			break

	_update_conditions_display()
	_recalculate_overall_progress()

func set_turns_remaining(turns: int) -> void:
	## Set turns remaining (-1 for no limit)
	_turns_remaining = turns
	_update_turns_display()

func _update_conditions_display() -> void:
	## Clear and rebuild condition rows
	if not _ui_built or _conditions_container == null:
		return  # state stored; rendered when _setup_ui() completes
	# Clear existing condition rows
	for child in _conditions_container.get_children():
		child.queue_free()

	# Create new condition rows
	for condition in _conditions:
		var condition_row := _create_condition_row(condition)
		_conditions_container.add_child(condition_row)

	# Show placeholder if no conditions
	if _conditions.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No victory conditions set"
		placeholder.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		placeholder.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_conditions_container.add_child(placeholder)

func _create_condition_row(condition: Dictionary) -> HBoxContainer:
	## Create a single condition row with status icon, name, and progress
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_SM)
	hbox.custom_minimum_size.y = 32

	# Status icon
	var status_icon := Label.new()
	var status: String = condition.get("status", "pending")
	match status:
		"complete":
			status_icon.text = "✓"
			status_icon.add_theme_color_override("font_color", COLOR_SUCCESS)
		"failed":
			status_icon.text = "✕"
			status_icon.add_theme_color_override("font_color", COLOR_WARNING)
		_:
			status_icon.text = "○"
			status_icon.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

	status_icon.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	status_icon.custom_minimum_size = Vector2(24, 24)
	status_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(status_icon)

	# Objective name
	var name_label := Label.new()
	name_label.text = condition.get("name", "Unknown")
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hbox.add_child(name_label)

	# Progress percentage
	var progress: float = condition.get("progress", 0.0)
	var progress_label := Label.new()
	progress_label.text = "%d%%" % int(progress * 100.0)
	progress_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)

	# Color based on progress
	if progress >= 1.0:
		progress_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	elif progress >= 0.5:
		progress_label.add_theme_color_override("font_color", COLOR_ACCENT)
	else:
		progress_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

	progress_label.custom_minimum_size.x = 48
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(progress_label)

	# Companion-app override control: the app cannot see the physical table
	# (which marker, who exited), so the player drives spatial/uncovered
	# objectives manually. Auto-derived rows (FIGHT_OFF, survival) are read-only.
	if bool(condition.get("interactive", false)):
		var cond_id: String = condition.get("id", "")
		match str(condition.get("input_kind", "none")):
			"counter":
				var input_max: int = int(condition.get("input_max", 1))
				var have: int = int(round(
					float(condition.get("progress", 0.0)) * float(input_max)))
				var stepper := StepperControlScene.new()
				stepper.value_changed.connect(
					func(v: int) -> void:
						objective_progress_input.emit(cond_id, v))
				hbox.add_child(stepper)
				# setup() touches nodes built in _ready(); defer until in-tree.
				stepper.call_deferred("setup", have, 0, input_max, 1)
			"bool":
				var chk := CheckButton.new()
				chk.button_pressed = (
					str(condition.get("status", "")) == "complete")
				chk.custom_minimum_size.y = TOUCH_TARGET_MIN
				chk.toggled.connect(
					func(pressed: bool) -> void:
						objective_progress_input.emit(cond_id, pressed))
				hbox.add_child(chk)
			_:
				pass

	return hbox

func _recalculate_overall_progress() -> void:
	## Average all condition progress and update overall bar
	if not _ui_built or _progress_bar == null:
		return  # state stored; rendered when _setup_ui() completes
	if _conditions.is_empty():
		_overall_progress = 0.0
		_progress_bar.value = 0.0
		_progress_label.text = "Progress: 0%"
		return

	var total := 0.0
	for condition in _conditions:
		total += condition.get("progress", 0.0)

	_overall_progress = total / float(_conditions.size())
	_progress_bar.value = _overall_progress * 100.0
	_progress_label.text = "Progress: %d%%" % int(_overall_progress * 100.0)

	# Update progress bar color based on progress
	var progress_fill := StyleBoxFlat.new()
	if _overall_progress >= 0.75:
		progress_fill.bg_color = COLOR_SUCCESS
	elif _overall_progress >= 0.5:
		progress_fill.bg_color = COLOR_ACCENT
	else:
		progress_fill.bg_color = Color(COLOR_ACCENT, 0.6)
	progress_fill.set_corner_radius_all(4)
	_progress_bar.add_theme_stylebox_override("fill", progress_fill)

func _update_turns_display() -> void:
	## Update turns remaining label
	if not _ui_built or _turns_label == null:
		return  # state stored; rendered when _setup_ui() completes
	if _turns_remaining < 0:
		_turns_label.visible = false
	else:
		_turns_label.text = "Turns Remaining: %d" % _turns_remaining
		_turns_label.visible = true

		# Warning color if low on turns
		if _turns_remaining <= 2:
			_turns_label.add_theme_color_override("font_color", COLOR_WARNING)
		else:
			_turns_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

## Public interface methods

func get_overall_progress() -> float:
	## Get overall progress (0.0-1.0)
	return _overall_progress

func is_victory_achieved() -> bool:
	## Check if all conditions are complete
	if _conditions.is_empty():
		return false

	for condition in _conditions:
		if condition.get("status", "pending") != "complete":
			return false

	return true

func is_defeat_triggered() -> bool:
	## Check if any defeat condition is triggered
	for condition in _conditions:
		if condition.get("status", "") == "failed":
			return true
	return false

func reset_progress() -> void:
	## Reset all progress to initial state
	_conditions.clear()
	_overall_progress = 0.0
	_turns_remaining = -1
	_update_conditions_display()
	_recalculate_overall_progress()
	_update_turns_display()
