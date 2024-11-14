class_name TutorialOverlay
extends CanvasLayer

signal overlay_clicked(position: Vector2)

const HIGHLIGHT_COLOR := Color(1, 1, 0, 0.3)
const HIGHLIGHT_BORDER_COLOR := Color(1, 1, 0, 0.8)
const ARROW_TEXTURE := preload("res://assets/Basic assets/Icons/10.png")

@onready var highlight_rect := ColorRect.new()
@onready var content_panel := $ContentPanel
@onready var content_label := $ContentPanel/MarginContainer/VBoxContainer/ContentLabel
@onready var next_button := $ContentPanel/MarginContainer/VBoxContainer/ButtonContainer/NextButton
@onready var skip_button := $ContentPanel/MarginContainer/VBoxContainer/ButtonContainer/SkipButton

var current_target: Control
var current_step: Dictionary
var tween: Tween

func _ready() -> void:
	highlight_rect.color = HIGHLIGHT_COLOR
	highlight_rect.visible = false
	add_child(highlight_rect)
	
	# Make sure we're on top
	layer = 128
	
	# Connect signals
	next_button.pressed.connect(_on_next_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	
	# Start hidden
	hide()

func highlight_control(target: Control, step_data: Dictionary) -> void:
	if not is_instance_valid(target):
		return
		
	current_target = target
	current_step = step_data
	
	var target_rect = target.get_global_rect()
	highlight_rect.size = target_rect.size + Vector2(10, 10)
	highlight_rect.position = target_rect.position - Vector2(5, 5)
	highlight_rect.visible = true
	
	# Position content panel
	_position_content_panel(target_rect)
	
	# Start highlight animation
	_animate_highlight()

func _position_content_panel(target_rect: Rect2) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = content_panel.size
	
	# Try to position to the right
	var new_pos = target_rect.position + Vector2(target_rect.size.x + 10, 0)
	
	# If it would go off screen, try below
	if new_pos.x + panel_size.x > viewport_size.x:
		new_pos = target_rect.position + Vector2(0, target_rect.size.y + 10)
		
		# If still off screen, try above
		if new_pos.y + panel_size.y > viewport_size.y:
			new_pos = target_rect.position - Vector2(0, panel_size.y + 10)
	
	content_panel.position = new_pos

func _animate_highlight() -> void:
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.tween_property(highlight_rect, "modulate:a", 0.3, 0.5)
	tween.tween_property(highlight_rect, "modulate:a", 0.8, 0.5)
	tween.set_loops()

func update_content(content: Dictionary) -> void:
	content_label.text = content.get("text", "")
	
	# Update button visibility based on step data
	next_button.visible = content.get("show_next_button", true)
	skip_button.visible = content.get("can_skip", true)

func clear_highlight() -> void:
	highlight_rect.visible = false
	if tween:
		tween.kill()
	current_target = null

func _on_next_pressed() -> void:
	emit_signal("tutorial_step_completed", current_step.get("id", ""))

func _on_skip_pressed() -> void:
	emit_signal("tutorial_track_completed")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		emit_signal("overlay_clicked", event.position)
