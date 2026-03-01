class_name FPCM_CombatSituationPanel
extends PanelContainer

## Combat Situation Panel
##
## Quick toggles for common combat modifiers during tabletop play.
## Calculates total modifier and displays hit requirements.
##
## Reference: Core Rules Combat Modifiers

# Signals
signal modifiers_changed(total: int)

# UI References
@onready var title_label: Label = $VBox/TitleLabel
@onready var toggles_container: VBoxContainer = $VBox/TogglesContainer
@onready var total_label: Label = $VBox/TotalLabel
@onready var hit_requirement_label: Label = $VBox/HitRequirementLabel

# Modifier definitions
var modifiers: Dictionary = {
	"cover_light": {"name": "Light Cover", "value": -1, "active": false},
	"cover_heavy": {"name": "Heavy Cover", "value": -2, "active": false},
	"elevated": {"name": "Elevated (+1 to hit)", "value": 1, "active": false},
	"point_blank": {"name": "Point Blank (≤6\")", "value": 1, "active": false},
	"long_range": {"name": "Long Range (>12\")", "value": -1, "active": false},
	"moving_target": {"name": "Target Dashed", "value": -1, "active": false},
	"aimed": {"name": "Aimed Shot", "value": 1, "active": false},
	"stunned_shooter": {"name": "Shooter Stunned", "value": -1, "active": false},
	"prone": {"name": "Target Prone", "value": -1, "active": false},
	"flanking": {"name": "Flanking", "value": 1, "active": false}
}

# Base values
var base_combat_skill: int = 0

func _ready() -> void:
	_setup_panel_style()
	_build_toggles()
	_update_display()

func _setup_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 3
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color.DODGER_BLUE
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

func _build_toggles() -> void:
	if not toggles_container:
		return

	# Clear existing
	for child in toggles_container.get_children():
		child.queue_free()

	# Create toggle for each modifier
	for key in modifiers:
		var mod: Dictionary = modifiers[key]
		var check := CheckBox.new()

		var value_str := "+%d" % mod.value if mod.value > 0 else str(mod.value)
		check.text = "%s (%s)" % [mod.name, value_str]
		check.name = key
		check.toggled.connect(_on_modifier_toggled.bind(key))

		# Color based on modifier type
		if mod.value > 0:
			check.add_theme_color_override("font_color", UIColors.COLOR_EMERALD)
		else:
			check.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))

		toggles_container.add_child(check)

## Set shooter's combat skill
func set_combat_skill(skill: int) -> void:
	base_combat_skill = skill
	_update_display()

## Get total modifier
func get_total_modifier() -> int:
	var total := 0
	for key in modifiers:
		if modifiers[key].active:
			total += modifiers[key].value
	return total

## Get hit requirement (need to roll >= this)
func get_hit_requirement() -> int:
	var total_mod := get_total_modifier()
	# Base hit is 4+, modified by combat skill and situation
	# Higher combat skill = easier to hit
	# Positive modifiers = easier to hit
	return max(2, 4 - base_combat_skill - total_mod)

## Clear all modifiers
func clear_all() -> void:
	for key in modifiers:
		modifiers[key].active = false

	# Update UI checkboxes
	if toggles_container:
		for child in toggles_container.get_children():
			if child is CheckBox:
				child.button_pressed = false

	_update_display()

## Set specific modifier
func set_modifier(key: String, active: bool) -> void:
	if modifiers.has(key):
		modifiers[key].active = active

		# Update checkbox
		if toggles_container:
			var check = toggles_container.get_node_or_null(key)
			if check and check is CheckBox:
				check.button_pressed = active

		_update_display()

func _on_modifier_toggled(pressed: bool, key: String) -> void:
	if modifiers.has(key):
		modifiers[key].active = pressed

		# Handle mutually exclusive modifiers
		if pressed:
			if key == "cover_light" and modifiers["cover_heavy"].active:
				set_modifier("cover_heavy", false)
			elif key == "cover_heavy" and modifiers["cover_light"].active:
				set_modifier("cover_light", false)
			elif key == "point_blank" and modifiers["long_range"].active:
				set_modifier("long_range", false)
			elif key == "long_range" and modifiers["point_blank"].active:
				set_modifier("point_blank", false)

		_update_display()
		modifiers_changed.emit(get_total_modifier())

func _update_display() -> void:
	# Total modifier
	if total_label:
		var total := get_total_modifier()
		var sign_str := "+" if total >= 0 else ""
		total_label.text = "Total Modifier: %s%d" % [sign_str, total]

		if total > 0:
			total_label.add_theme_color_override("font_color", UIColors.COLOR_EMERALD)
		elif total < 0:
			total_label.add_theme_color_override("font_color", UIColors.COLOR_RED)
		else:
			total_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)

	# Hit requirement
	if hit_requirement_label:
		var requirement := get_hit_requirement()
		hit_requirement_label.text = "Need %d+ to hit" % requirement

		if requirement <= 3:
			hit_requirement_label.add_theme_color_override("font_color", UIColors.COLOR_EMERALD)
		elif requirement >= 6:
			hit_requirement_label.add_theme_color_override("font_color", UIColors.COLOR_RED)
		else:
			hit_requirement_label.add_theme_color_override("font_color", UIColors.COLOR_AMBER)
