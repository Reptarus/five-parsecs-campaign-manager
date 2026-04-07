class_name LoadingScreen
extends CanvasLayer

## Itemized loading screen with three-state task indicators.
## Shows pending (dim dot), active (cyan pulse), complete (green check).
## Inspired by Fallout Wasteland Warfare companion app loading modal.
##
## Usage:
##   var ls := LoadingScreen.new()
##   add_child(ls)
##   ls.start_loading(PackedStringArray([
##       "Loading Campaign Data",
##       "Loading Crew Roster",
##       "Loading World State",
##   ]))
##   # Then call ls.set_task_active(0), ls.complete_task(0), etc.

signal loading_complete

# ── State ─────────────────────────────────────────────────────────────
var _task_rows: Array[Dictionary] = []  # {icon: Label, name: Label, state: int}
var _bg: ColorRect
var _container: VBoxContainer

enum TaskState { PENDING, ACTIVE, COMPLETE }

const ICON_PENDING := "·"
const ICON_ACTIVE := "◉"
const ICON_COMPLETE := "✓"

func _init() -> void:
	layer = 99  # Below TransitionManager at 100

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Full-screen background
	_bg = ColorRect.new()
	_bg.color = UIColors.COLOR_PRIMARY
	_bg.position = Vector2.ZERO
	var vp := get_viewport()
	_bg.size = vp.get_visible_rect().size if vp else Vector2(1920, 1080)
	add_child(_bg)
	if vp:
		vp.size_changed.connect(_on_viewport_resized)

	# Centered content
	_container = VBoxContainer.new()
	_container.add_theme_constant_override(
		"separation", UIColors.SPACING_MD
	)
	add_child(_container)

	# Title
	var title_label := Label.new()
	title_label.text = "LOADING"
	title_label.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_XL
	)
	title_label.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container.add_child(title_label)

	# Separator
	var sep := HSeparator.new()
	sep.modulate = UIColors.COLOR_BORDER
	_container.add_child(sep)

	_center_container()

func _on_viewport_resized() -> void:
	var vp := get_viewport()
	if not vp:
		return
	var vp_size: Vector2 = vp.get_visible_rect().size
	if _bg:
		_bg.size = vp_size
	_center_container()

func _center_container() -> void:
	if not _container:
		return
	var vp := get_viewport()
	if not vp:
		return
	var vp_size: Vector2 = vp.get_visible_rect().size
	# Center the container
	_container.position = Vector2(
		vp_size.x * 0.25,
		vp_size.y * 0.3
	)
	_container.custom_minimum_size = Vector2(vp_size.x * 0.5, 0)

## Start loading with a list of task names.
func start_loading(tasks: PackedStringArray) -> void:
	_task_rows.clear()
	for task_name: String in tasks:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(
			"separation", UIColors.SPACING_SM
		)

		var icon_label := Label.new()
		icon_label.text = ICON_PENDING
		icon_label.add_theme_font_size_override(
			"font_size", UIColors.FONT_SIZE_MD
		)
		icon_label.add_theme_color_override(
			"font_color", UIColors.COLOR_TEXT_MUTED
		)
		icon_label.custom_minimum_size = Vector2(24, 0)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(icon_label)

		var name_label := Label.new()
		name_label.text = task_name
		name_label.add_theme_font_size_override(
			"font_size", UIColors.FONT_SIZE_MD
		)
		name_label.add_theme_color_override(
			"font_color", UIColors.COLOR_TEXT_SECONDARY
		)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		_container.add_child(row)
		_task_rows.append({
			"icon": icon_label,
			"name": name_label,
			"state": TaskState.PENDING,
		})

## Mark a task as currently active (cyan pulsing indicator).
func set_task_active(idx: int) -> void:
	if idx < 0 or idx >= _task_rows.size():
		return
	var row: Dictionary = _task_rows[idx]
	row["state"] = TaskState.ACTIVE
	var icon: Label = row["icon"]
	icon.text = ICON_ACTIVE
	icon.add_theme_color_override(
		"font_color", UIColors.COLOR_CYAN
	)
	# Pulsing animation (looping — must stop in complete_task)
	TweenFX.glow_pulse(icon, 1.2, 0.05, 0.3)

	var name_lbl: Label = row["name"]
	name_lbl.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)

## Mark a task as complete (green checkmark).
func complete_task(idx: int) -> void:
	if idx < 0 or idx >= _task_rows.size():
		return
	var row: Dictionary = _task_rows[idx]
	row["state"] = TaskState.COMPLETE
	var icon: Label = row["icon"]
	# Stop looping glow_pulse before changing state
	TweenFX.stop(icon, TweenFX.Animations.GLOW_PULSE)
	icon.modulate = Color.WHITE  # Reset any glow_pulse modulation
	icon.scale = Vector2.ONE
	icon.text = ICON_COMPLETE
	icon.add_theme_color_override(
		"font_color", UIColors.COLOR_EMERALD
	)

	var name_lbl: Label = row["name"]
	name_lbl.add_theme_color_override(
		"font_color", UIColors.COLOR_EMERALD
	)

	# Check if all tasks complete
	var all_done := true
	for r: Dictionary in _task_rows:
		if r["state"] != TaskState.COMPLETE:
			all_done = false
			break
	if all_done:
		loading_complete.emit()

## Dismiss the loading screen with a fade-out, then free.
func dismiss() -> void:
	if _bg:
		var tween := create_tween()
		tween.tween_property(_bg, "modulate:a", 0.0, 0.3)
		tween.parallel().tween_property(
			_container, "modulate:a", 0.0, 0.3
		)
		tween.finished.connect(queue_free)
	else:
		queue_free()

## Run a simulated loading sequence for visual polish.
## Completes all tasks with staggered timing, then emits loading_complete.
func run_sequence(delay_per_task: float = 0.15) -> void:
	for i: int in range(_task_rows.size()):
		set_task_active(i)
		await get_tree().create_timer(delay_per_task).timeout
		complete_task(i)
