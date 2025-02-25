@tool
extends ComponentTestBase

const TerrainTooltip := preload("res://src/ui/components/combat/TerrainTooltip.gd")

# Override _create_component_instance to provide the specific component
func _create_component_instance() -> Control:
	return TerrainTooltip.new()

func test_initial_setup() -> void:
	await test_component_structure()
	
	# Additional component-specific checks
	assert_false(_component.visible)
	assert_not_null(_component.get_node("VBoxContainer"))
	assert_not_null(_component.get_node("VBoxContainer/TypeLabel"))
	assert_not_null(_component.get_node("VBoxContainer/CoverLabel"))
	assert_not_null(_component.get_node("VBoxContainer/MovementLabel"))
	assert_not_null(_component.get_node("VBoxContainer/DescriptionLabel"))

func test_show_tooltip() -> void:
	var test_terrain := {
		"type": "forest",
		"cover": 2,
		"movement_cost": 1.5,
		"description": "Dense forest providing good cover"
	}
	_component.show_tooltip(test_terrain)
	
	assert_true(_component.visible)
	var type_label := _component.get_node("VBoxContainer/TypeLabel") as Label
	var cover_label := _component.get_node("VBoxContainer/CoverLabel") as Label
	var movement_label := _component.get_node("VBoxContainer/MovementLabel") as Label
	var description_label := _component.get_node("VBoxContainer/DescriptionLabel") as Label
	
	assert_true(type_label.text.contains("forest"))
	assert_true(cover_label.text.contains("2"))
	assert_true(movement_label.text.contains("1.5"))
	assert_eq(description_label.text, test_terrain.description)

func test_hide_tooltip() -> void:
	_component.show()
	_component.hide_tooltip()
	assert_false(_component.visible)

func test_update_position() -> void:
	var test_pos := Vector2(100, 100)
	_component.update_position(test_pos)
	assert_eq(_component.position, test_pos)
	
	# Test position clamping to viewport
	var viewport_size: Vector2i = get_viewport().size
	var far_pos := Vector2(viewport_size.x + 100, viewport_size.y + 100)
	_component.update_position(far_pos)
	assert_true(_component.position.x <= viewport_size.x - _component.size.x)
	assert_true(_component.position.y <= viewport_size.y - _component.size.y)

# Additional tests using base class functionality
func test_component_theme() -> void:
	await super.test_component_theme()
	
	# Additional theme checks for terrain tooltip
	assert_component_theme_color("font_color")
	assert_component_theme_color("background_color")
	assert_component_theme_font("normal_font")
	assert_component_theme_font("bold_font")

func test_component_layout() -> void:
	await super.test_component_layout()
	
	# Additional layout checks for terrain tooltip
	var container := _component.get_node("VBoxContainer")
	assert_true(container.size.x >= 200,
		"Tooltip should have minimum width")
	assert_true(container.size.y >= 100,
		"Tooltip should have minimum height")

func test_component_performance() -> void:
	start_performance_monitoring()
	
	# Perform terrain tooltip specific operations
	var test_terrains := [
		{
			"type": "forest",
			"cover": 2,
			"movement_cost": 1.5,
			"description": "Dense forest"
		},
		{
			"type": "mountain",
			"cover": 3,
			"movement_cost": 2.0,
			"description": "Rocky terrain"
		},
		{
			"type": "water",
			"cover": 0,
			"movement_cost": 3.0,
			"description": "Deep water"
		}
	]
	
	for terrain in test_terrains:
		_component.show_tooltip(terrain)
		_component.update_position(Vector2(100, 100))
		await get_tree().process_frame
		_component.hide_tooltip()
		await get_tree().process_frame
	
	var metrics := stop_performance_monitoring()
	assert_performance_metrics(metrics, {
		"layout_updates": 15,
		"draw_calls": 10,
		"theme_lookups": 25
	})

func test_tooltip_interaction() -> void:
	# Test tooltip with different terrain types
	var test_terrains := [
		{
			"type": "forest",
			"cover": 2,
			"movement_cost": 1.5,
			"description": "Dense forest"
		},
		{
			"type": "mountain",
			"cover": 3,
			"movement_cost": 2.0,
			"description": "Rocky terrain"
		}
	]
	
	for terrain in test_terrains:
		_component.show_tooltip(terrain)
		assert_true(_component.visible)
		
		var type_label := _component.get_node("VBoxContainer/TypeLabel") as Label
		var cover_label := _component.get_node("VBoxContainer/CoverLabel") as Label
		var movement_label := _component.get_node("VBoxContainer/MovementLabel") as Label
		var description_label := _component.get_node("VBoxContainer/DescriptionLabel") as Label
		
		assert_true(type_label.text.contains(terrain.type))
		assert_true(cover_label.text.contains(str(terrain.cover)))
		assert_true(movement_label.text.contains(str(terrain.movement_cost)))
		assert_eq(description_label.text, terrain.description)
		
		_component.hide_tooltip()
		assert_false(_component.visible)
		await get_tree().process_frame

func test_accessibility(control: Control = _component) -> void:
	await super.test_accessibility(control)
	
	# Additional accessibility checks for terrain tooltip
	var labels := _component.find_children("*", "Label")
	for label in labels:
		assert_true(label.clip_text, "Labels should clip text to prevent overflow")
		assert_true(label.size.x > 0, "Labels should have minimum width")
		
		# Check text contrast
		var background_color: Color = label.get_parent().get_theme_color("background_color")
		var text_color: Color = label.get_theme_color("font_color")
		var contrast_ratio := _calculate_contrast_ratio(text_color, background_color)
		assert_gt(contrast_ratio, 4.5, "Text contrast ratio should meet WCAG AA standards")

# Helper method for calculating contrast ratio
func _calculate_contrast_ratio(color1: Color, color2: Color) -> float:
	var l1 := _get_relative_luminance(color1)
	var l2 := _get_relative_luminance(color2)
	var lighter := maxf(l1, l2)
	var darker := minf(l1, l2)
	return (lighter + 0.05) / (darker + 0.05)

func _get_relative_luminance(color: Color) -> float:
	var r := _gamma_correct(color.r)
	var g := _gamma_correct(color.g)
	var b := _gamma_correct(color.b)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b

func _gamma_correct(value: float) -> float:
	return value if value <= 0.03928 else pow((value + 0.055) / 1.055, 2.4)