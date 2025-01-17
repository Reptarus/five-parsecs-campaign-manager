@tool
extends Control
class_name PhaseIndicator

# Signals
signal phase_clicked(phase_name: String)

# Constants
const PHASE_COLORS = {
	"preparation": Color(0.2, 0.6, 1.0),  # Blue
	"campaign": Color(0.2, 0.8, 0.2),     # Green
	"battle": Color(0.8, 0.2, 0.2),       # Red
	"resolution": Color(0.8, 0.8, 0.2),   # Yellow
	"downtime": Color(0.6, 0.4, 0.8)      # Purple
}

# Node references
@onready var phase_label: Label = $PhaseLabel
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var next_phase_label: Label = $NextPhaseLabel
@onready var phase_description: Label = $PhaseDescription

# Properties
var current_phase: String = "preparation":
	set(value):
		if current_phase != value:
			current_phase = value
			_update_display()

var phase_progress: float = 0.0:
	set(value):
		phase_progress = clamp(value, 0.0, 1.0)
		if progress_bar:
			progress_bar.value = phase_progress * 100

var phase_description_text: String = "":
	set(value):
		phase_description_text = value
		if phase_description:
			phase_description.text = value

func _ready() -> void:
	_setup_ui()
	_update_display()
	
func _setup_ui() -> void:
	# Set up the visual style and layout
	custom_minimum_size = Vector2(200, 80)
	
	# Configure progress bar
	if progress_bar:
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = 0
		
	# Configure labels
	if phase_label:
		phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
	if next_phase_label:
		next_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		next_phase_label.modulate = Color(1, 1, 1, 0.7)
		
	if phase_description:
		phase_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		phase_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		phase_description.custom_minimum_size = Vector2(180, 0)

func _update_display() -> void:
	if not is_inside_tree():
		return
		
	# Update phase label
	if phase_label:
		phase_label.text = current_phase.capitalize()
		
	# Update color
	if current_phase in PHASE_COLORS:
		modulate = PHASE_COLORS[current_phase]
		
	# Update next phase
	var next_phase = _get_next_phase()
	if next_phase_label:
		next_phase_label.text = "Next: " + next_phase.capitalize()

func _get_next_phase() -> String:
	var phases = PHASE_COLORS.keys()
	var current_index = phases.find(current_phase)
	if current_index == -1 or current_index == phases.size() - 1:
		return phases[0]
	return phases[current_index + 1]

func set_phase_complete() -> void:
	phase_progress = 1.0
	
func reset_progress() -> void:
	phase_progress = 0.0

# Input handling
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			emit_signal("phase_clicked", current_phase)

# Public methods
func highlight_phase(duration: float = 0.3) -> void:
	# Create a temporary highlight effect
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.5, duration * 0.5)
	tween.tween_property(self, "modulate:a", 1.0, duration * 0.5)

func set_phase_data(phase_name: String, progress: float = 0.0, description: String = "") -> void:
	current_phase = phase_name
	phase_progress = progress
	phase_description_text = description 
