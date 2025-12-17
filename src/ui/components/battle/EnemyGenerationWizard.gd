class_name FPCM_EnemyGenerationWizard
extends PanelContainer

## Enemy Generation Wizard
##
## Step-by-step wizard for generating enemies according to Five Parsecs rules.
## Handles enemy type selection, quantity calculation, and stat generation.
##
## Reference: Core Rules Enemy Tables

## Design System Constants (from BaseCampaignPanel)
const COLOR_PRIMARY := Color("#0a0d14")      # Darkest background
const COLOR_SECONDARY := Color("#111827")    # Card backgrounds
const COLOR_TERTIARY := Color("#1f2937")     # Elevated elements
const COLOR_BORDER := Color("#374151")       # Border color
const COLOR_BLUE := Color("#3b82f6")         # Primary accent
const COLOR_EMERALD := Color("#10b981")      # Success
const COLOR_AMBER := Color("#f59e0b")        # Warning/credits
const COLOR_RED := Color("#ef4444")          # Danger/threat
const COLOR_CYAN := Color("#06b6d4")         # Highlights
const COLOR_TEXT_PRIMARY := Color("#f3f4f6") # Bright text
const COLOR_TEXT_SECONDARY := Color("#9ca3af") # Gray text

const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

const EnemyGenerator = preload("res://src/core/systems/EnemyGenerator.gd")
const WeaponTableSystem = preload("res://src/core/battle/WeaponTableSystem.gd")

# Signals
signal enemies_generated(enemies: Array)
signal generation_cancelled()

# UI References
@onready var title_label: Label = $VBox/TitleLabel
@onready var step_indicator: Label = $VBox/StepIndicator
@onready var step_container: VBoxContainer = $VBox/StepContainer
@onready var enemy_list_container: VBoxContainer = $VBox/EnemyListScroll/EnemyListContainer
@onready var nav_container: HBoxContainer = $VBox/NavContainer
@onready var back_button: Button = $VBox/NavContainer/BackButton
@onready var next_button: Button = $VBox/NavContainer/NextButton

# Systems
var enemy_generator: EnemyGenerator
var weapon_system: WeaponTableSystem

# Wizard state
var current_step: int = 0
var total_steps: int = 4

# Generation parameters
var mission_type: String = "Patrol"
var difficulty: int = 2
var crew_size: int = 4
var enemy_category: String = ""
var generated_enemies: Array = []

# Step UI elements
var mission_type_option: OptionButton
var difficulty_slider: HSlider
var crew_size_spin: SpinBox
var category_option: OptionButton
var enemy_count_label: Label

func _ready() -> void:
	enemy_generator = EnemyGenerator.new()
	weapon_system = WeaponTableSystem.new()
	_setup_panel_style()
	_setup_navigation()
	_show_step(0)

func _setup_panel_style() -> void:
	var style := StyleBoxFlat.new()
	# Glass morphism background
	style.bg_color = Color(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, 0.8)
	style.set_corner_radius_all(16)
	# Subtle border
	style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
	style.set_border_width_all(1)
	# Generous padding
	style.set_content_margin_all(SPACING_LG)
	add_theme_stylebox_override("panel", style)

func _setup_navigation() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_pressed)

func _show_step(step: int) -> void:
	current_step = step

	# Update step indicator
	if step_indicator:
		step_indicator.text = "Step %d of %d" % [step + 1, total_steps]

	# Clear step container
	if step_container:
		for child in step_container.get_children():
			child.queue_free()

	# Build step UI
	match step:
		0: _build_mission_step()
		1: _build_difficulty_step()
		2: _build_category_step()
		3: _build_result_step()

	# Update navigation
	_update_navigation()

func _build_mission_step() -> void:
	var label := Label.new()
	label.text = "Select Mission Type"
	label.add_theme_font_size_override("font_size", 14)
	step_container.add_child(label)

	var desc := Label.new()
	desc.text = "Mission type determines enemy category probabilities."
	desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	step_container.add_child(desc)

	mission_type_option = OptionButton.new()
	mission_type_option.add_item("Patrol")
	mission_type_option.add_item("Investigate")
	mission_type_option.add_item("Hunt")
	mission_type_option.add_item("Bounty")
	mission_type_option.add_item("Guard")
	mission_type_option.add_item("Defend")
	mission_type_option.add_item("Deliver")
	mission_type_option.add_item("Trade")
	mission_type_option.add_item("Explore")
	mission_type_option.add_item("Salvage")
	mission_type_option.item_selected.connect(_on_mission_selected)

	# Set current selection
	for i in range(mission_type_option.item_count):
		if mission_type_option.get_item_text(i) == mission_type:
			mission_type_option.selected = i
			break

	step_container.add_child(mission_type_option)

	# Crew size
	var crew_label := Label.new()
	crew_label.text = "\nCrew Size:"
	step_container.add_child(crew_label)

	var crew_row := HBoxContainer.new()
	crew_size_spin = SpinBox.new()
	crew_size_spin.min_value = 1
	crew_size_spin.max_value = 8
	crew_size_spin.value = crew_size
	crew_size_spin.value_changed.connect(_on_crew_size_changed)
	crew_row.add_child(crew_size_spin)
	step_container.add_child(crew_row)

func _build_difficulty_step() -> void:
	var label := Label.new()
	label.text = "Set Difficulty Level"
	label.add_theme_font_size_override("font_size", 14)
	step_container.add_child(label)

	var desc := Label.new()
	desc.text = "Higher difficulty adds more enemies with better stats."
	desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	step_container.add_child(desc)

	difficulty_slider = HSlider.new()
	difficulty_slider.min_value = 1
	difficulty_slider.max_value = 5
	difficulty_slider.step = 1
	difficulty_slider.value = difficulty
	difficulty_slider.custom_minimum_size.x = 200
	difficulty_slider.value_changed.connect(_on_difficulty_changed)
	step_container.add_child(difficulty_slider)

	var diff_label := Label.new()
	diff_label.text = _get_difficulty_text(difficulty)
	diff_label.name = "DiffLabel"
	step_container.add_child(diff_label)

	# Show expected enemy count
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	step_container.add_child(spacer)

	enemy_count_label = Label.new()
	_update_enemy_count_preview()
	step_container.add_child(enemy_count_label)

func _build_category_step() -> void:
	var label := Label.new()
	label.text = "Enemy Category"
	label.add_theme_font_size_override("font_size", 14)
	step_container.add_child(label)

	var desc := Label.new()
	desc.text = "Roll or select enemy category manually."
	desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	step_container.add_child(desc)

	# Roll button
	var roll_btn := Button.new()
	roll_btn.text = "Roll Random Category"
	roll_btn.pressed.connect(_on_roll_category)
	step_container.add_child(roll_btn)

	# Or manual selection
	var or_label := Label.new()
	or_label.text = "— or select manually —"
	or_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	or_label.add_theme_color_override("font_color", Color("#808080"))  # Gray - secondary text
	step_container.add_child(or_label)

	category_option = OptionButton.new()
	category_option.add_item("Criminal Elements")
	category_option.add_item("Military/Security")
	category_option.add_item("Alien Hostiles")
	category_option.add_item("Pirates/Raiders")
	category_option.add_item("Wildlife")
	category_option.add_item("Cultists")
	category_option.item_selected.connect(_on_category_selected)
	step_container.add_child(category_option)

	# Show current selection
	var selection_label := Label.new()
	selection_label.name = "SelectionLabel"
	if enemy_category.is_empty():
		selection_label.text = "No category selected"
		selection_label.add_theme_color_override("font_color", COLOR_AMBER)
	else:
		selection_label.text = "Selected: %s" % enemy_category
		selection_label.add_theme_color_override("font_color", COLOR_EMERALD)
	step_container.add_child(selection_label)

func _build_result_step() -> void:
	var label := Label.new()
	label.text = "Generated Enemies"
	label.add_theme_font_size_override("font_size", 14)
	step_container.add_child(label)

	# Generate enemies if not already done
	if generated_enemies.is_empty():
		_generate_enemies()

	# Display enemies
	if enemy_list_container:
		for child in enemy_list_container.get_children():
			child.queue_free()

		for i in range(generated_enemies.size()):
			var enemy = generated_enemies[i]
			var entry := _create_enemy_display(enemy, i + 1)
			enemy_list_container.add_child(entry)

	# Summary
	var summary := Label.new()
	summary.text = "\nTotal: %d enemies" % generated_enemies.size()
	summary.add_theme_color_override("font_color", COLOR_AMBER)
	step_container.add_child(summary)

func _create_enemy_display(enemy: Resource, index: int) -> Control:
	# Glass card for each enemy
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(COLOR_TERTIARY.r, COLOR_TERTIARY.g, COLOR_TERTIARY.b, 0.6)
	card_style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.3)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(SPACING_MD)
	card.add_theme_stylebox_override("panel", card_style)
	
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", SPACING_SM)

	# Header with name and threat badge
	var header := HBoxContainer.new()
	var name_label := Label.new()
	var enemy_name: String = enemy.get_meta("name") if enemy.has_meta("name") else "Unknown"
	name_label.text = "%d. %s" % [index, enemy_name]
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	header.add_child(name_label)
	
	# Threat level badge
	var threat_badge := _create_threat_badge(enemy)
	header.add_child(threat_badge)
	container.add_child(header)

	# Stats row with color coding
	var stats_label := Label.new()
	var combat: int = enemy.get_meta("combat") if enemy.has_meta("combat") else enemy.get_meta("combat_skill") if enemy.has_meta("combat_skill") else 3
	var toughness: int = enemy.get_meta("toughness") if enemy.has_meta("toughness") else 3
	var speed: int = enemy.get_meta("speed") if enemy.has_meta("speed") else 4
	stats_label.text = "Combat: %d | Toughness: %d | Speed: %d" % [combat, toughness, speed]
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	container.add_child(stats_label)

	# Weapons
	var weapons = enemy.get_meta("weapons") if enemy.has_meta("weapons") else []
	if weapons.size() > 0:
		var weapons_label := Label.new()
		var weapons_arr: Array = weapons if weapons is Array else [weapons]
		weapons_label.text = "Weapons: %s" % ", ".join(weapons_arr)
		weapons_label.add_theme_font_size_override("font_size", 11)
		weapons_label.add_theme_color_override("font_color", COLOR_AMBER)
		container.add_child(weapons_label)

	card.add_child(container)
	return card

func _create_threat_badge(enemy: Resource) -> PanelContainer:
	"""Create threat level badge based on enemy stats"""
	var combat: int = enemy.get_meta("combat") if enemy.has_meta("combat") else enemy.get_meta("combat_skill") if enemy.has_meta("combat_skill") else 3
	var toughness: int = enemy.get_meta("toughness") if enemy.has_meta("toughness") else 3
	var threat_score := combat + toughness
	
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(48, 20)
	
	var badge_style := StyleBoxFlat.new()
	badge_style.set_corner_radius_all(4)
	badge_style.set_content_margin_all(4)
	
	var badge_label := Label.new()
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 10)
	
	# Color code by threat level
	if threat_score <= 4:
		badge_style.bg_color = COLOR_EMERALD
		badge_label.text = "LOW"
	elif threat_score <= 6:
		badge_style.bg_color = COLOR_AMBER
		badge_label.text = "MED"
	else:
		badge_style.bg_color = COLOR_RED
		badge_label.text = "HIGH"
	
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.add_child(badge_label)
	return badge

func _generate_enemies() -> void:
	generated_enemies.clear()

	# Create a mock mission resource
	var mission := Resource.new()
	mission.set_meta("mission_type", mission_type)
	mission.set_meta("difficulty", difficulty)

	# If category was manually selected, create enemies from that category
	if not enemy_category.is_empty():
		var count := enemy_generator._calculate_enemy_count(difficulty, crew_size)
		for i in range(count):
			var enemy := enemy_generator._create_enemy(enemy_category, difficulty)
			# Add rolled weapon
			var weapon := weapon_system.roll_enemy_weapon(enemy_category)
			if weapon:
				enemy.set_meta("weapons", [weapon.name])
			generated_enemies.append(enemy)
	else:
		generated_enemies = enemy_generator.generate_enemies_for_mission(mission, crew_size)

func _update_navigation() -> void:
	if back_button:
		back_button.visible = current_step > 0
		back_button.text = "Back"

	if next_button:
		if current_step == total_steps - 1:
			next_button.text = "Finish"
		elif current_step == 2:
			next_button.text = "Generate"
		else:
			next_button.text = "Next"

func _update_enemy_count_preview() -> void:
	if enemy_count_label:
		# Explain dice mechanics based on crew size
		var dice_text := ""
		match crew_size:
			6:
				dice_text = "Roll 2D6, pick HIGHER"
			5:
				dice_text = "Roll 1D6"
			4:
				dice_text = "Roll 2D6, pick LOWER"
			_:
				dice_text = "Roll 2D6, pick HIGHER (default)"
		
		# Calculate sample count (for preview purposes)
		var sample_count := enemy_generator._calculate_enemy_count(difficulty, crew_size)
		enemy_count_label.text = "Enemy Count: %s (Sample: %d)" % [dice_text, sample_count]
		enemy_count_label.add_theme_color_override("font_color", COLOR_AMBER)

func _get_difficulty_text(diff: int) -> String:
	match diff:
		1: return "Easy (fewer, weaker enemies)"
		2: return "Normal (balanced encounter)"
		3: return "Hard (more, tougher enemies)"
		4: return "Veteran (challenging encounter)"
		5: return "Elite (deadly encounter)"
		_: return "Unknown"

func _on_mission_selected(index: int) -> void:
	mission_type = mission_type_option.get_item_text(index)

func _on_crew_size_changed(value: float) -> void:
	crew_size = int(value)

func _on_difficulty_changed(value: float) -> void:
	difficulty = int(value)

	# Update label
	var diff_label = step_container.get_node_or_null("DiffLabel")
	if diff_label:
		diff_label.text = _get_difficulty_text(difficulty)

	_update_enemy_count_preview()

func _on_roll_category() -> void:
	var categories := ["criminal", "military", "alien", "pirate", "wildlife", "cultists"]
	enemy_category = categories.pick_random()

	# Update selection label
	var selection_label = step_container.get_node_or_null("SelectionLabel")
	if selection_label:
		selection_label.text = "Selected: %s" % enemy_category
		selection_label.add_theme_color_override("font_color", COLOR_EMERALD)

func _on_category_selected(index: int) -> void:
	match index:
		0: enemy_category = "criminal"
		1: enemy_category = "military"
		2: enemy_category = "alien"
		3: enemy_category = "pirate"
		4: enemy_category = "wildlife"
		5: enemy_category = "cultists"
		_: enemy_category = "criminal"

	# Update selection label
	var selection_label = step_container.get_node_or_null("SelectionLabel")
	if selection_label:
		selection_label.text = "Selected: %s" % enemy_category
		selection_label.add_theme_color_override("font_color", COLOR_EMERALD)

func _on_back_pressed() -> void:
	if current_step > 0:
		_show_step(current_step - 1)

func _on_next_pressed() -> void:
	if current_step < total_steps - 1:
		# Validate current step
		if current_step == 2 and enemy_category.is_empty():
			# Auto-roll category if none selected
			_on_roll_category()

		_show_step(current_step + 1)
	else:
		# Finished
		enemies_generated.emit(generated_enemies)
		hide()

## Reset wizard
func reset() -> void:
	current_step = 0
	mission_type = "Patrol"
	difficulty = 2
	crew_size = 4
	enemy_category = ""
	generated_enemies.clear()
	_show_step(0)

## Get generated enemies
func get_generated_enemies() -> Array:
	return generated_enemies
                                                                                                                                             