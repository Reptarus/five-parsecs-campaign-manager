class_name AttackResolutionOverlay
extends PanelContainer

## Translucent attack-resolution overlay for ASSISTED battle mode.
##
## When the player initiates an attack, this overlay surfaces the to-hit math
## directly on the battle UI: target threshold, base 1D6 + Combat formula, and
## the modifier breakdown — all sourced from BattleCalculations static helpers.
## NO new formulas are authored here; every value comes from BattleCalculations.

const BC = preload("res://src/core/battle/BattleCalculations.gd")

## Show an attack-resolution overlay anchored at the global mouse position.
## attacker / target / weapon are dictionaries with the standard battle-state keys.
static func show_for_attack(parent: Control, attacker: Dictionary, target: Dictionary,
		weapon: Dictionary, range_inches: float) -> void:
	if parent == null:
		return
	var overlay := AttackResolutionOverlay.new()
	parent.add_child(overlay)
	overlay._render(attacker, target, weapon, range_inches)
	overlay.global_position = parent.get_global_mouse_position() - Vector2(120, 60)

func _ready() -> void:
	# Translucent dark panel with cyan accent border
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.10, 0.92)
	style.border_color = Color(0.31, 0.76, 0.97, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _render(attacker: Dictionary, target: Dictionary, weapon: Dictionary,
		range_inches: float) -> void:
	# Pull threshold from BattleCalculations' Core Rules to-hit table (p.44)
	var in_cover: bool = bool(target.get("in_cover", false))
	var weapon_range: int = int(weapon.get("range", BC.RIFLE_RANGE))
	var threshold: int
	if range_inches <= float(BC.POINT_BLANK_RANGE):
		threshold = BC.HIT_COVER_CLOSE if in_cover else BC.HIT_OPEN_CLOSE
	else:
		threshold = BC.HIT_COVER_RANGE if in_cover else BC.HIT_OPEN_RANGE

	# Modifier from existing static helper — no formula duplication
	var modifier: int = BC.calculate_hit_modifier(
		int(attacker.get("combat", 0)),
		in_cover,
		bool(attacker.get("elevated", false)),
		bool(target.get("elevated", false)),
		range_inches,
		weapon_range,
		bool(attacker.get("stunned", false)),
		bool(attacker.get("suppressed", false)),
		bool(attacker.get("aim", false)),
		str(attacker.get("species", "")))

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.custom_minimum_size = Vector2(220, 0)
	label.add_theme_font_size_override("normal_font_size", 13)
	label.add_theme_color_override("default_color", Color(0.93, 0.93, 0.93))
	var modifier_str: String = "%+d" % modifier if modifier != 0 else "0"
	label.text = "[b]Hit on %d+[/b]\n1D6 + %d Combat\nModifier: %s\n[i](Core Rules p.44)[/i]" % [
		threshold, int(attacker.get("combat", 0)), modifier_str
	]
	add_child(label)

	# Auto-dismiss after 4s; player can click the overlay to dismiss earlier
	var tree := get_tree()
	if tree:
		var dismiss_timer: SceneTreeTimer = tree.create_timer(4.0)
		dismiss_timer.timeout.connect(queue_free)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		queue_free()
