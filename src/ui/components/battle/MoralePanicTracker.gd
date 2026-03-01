class_name FPCM_MoralePanicTracker
extends PanelContainer

## Morale and Panic Tracker
##
## Tracks enemy morale state and panic conditions during battle.
## Handles morale checks when casualties occur.
##
## Reference: Core Rules p.114 "Morale"

const FiveParsecsCampaignPanel = preload("res://src/ui/screens/campaign/panels/BaseCampaignPanel.gd")

# Signals
signal morale_check_triggered(enemies_remaining: int, casualties: int)
signal enemy_fled(fled_count: int)
signal panic_occurred(panic_type: String)

# UI References
@onready var title_label: Label = $VBox/TitleLabel
@onready var morale_value_label: Label = $VBox/MoraleRow/MoraleValueLabel
@onready var status_label: Label = $VBox/StatusLabel
@onready var casualties_label: Label = $VBox/CasualtiesLabel
@onready var result_container: VBoxContainer = $VBox/ResultContainer
@onready var roll_button: Button = $VBox/ButtonContainer/RollButton

# Morale state
var base_morale: int = 3
var morale_modifier: int = 0
var total_enemies: int = 0
var enemies_remaining: int = 0
var casualties_this_round: int = 0
var fled_enemies: int = 0

func _ready() -> void:
	_setup_panel_style()
	_setup_buttons()
	_update_display()

func _setup_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = FiveParsecsCampaignPanel.COLOR_ELEVATED  # Design system: card backgrounds
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_width_left = 3  # Accent border (morale indicator)
	style.border_color = Color.INDIAN_RED  # Keep red for morale specialty
	style.set_content_margin_all(FiveParsecsCampaignPanel.SPACING_MD)  # Design system: 16px
	add_theme_stylebox_override("panel", style)

func _setup_buttons() -> void:
	if roll_button:
		roll_button.pressed.connect(_on_roll_morale)

## Initialize enemy count
func set_enemy_count(count: int) -> void:
	total_enemies = count
	enemies_remaining = count
	casualties_this_round = 0
	fled_enemies = 0
	_update_display()

## Set base morale value
func set_base_morale(value: int) -> void:
	base_morale = value
	_update_display()

## Apply morale modifier (e.g., from deployment conditions)
func set_morale_modifier(modifier: int) -> void:
	morale_modifier = modifier
	_update_display()

## Register a casualty
func add_casualty() -> void:
	if enemies_remaining > 0:
		enemies_remaining -= 1
		casualties_this_round += 1
		_update_display()

		# Check if morale check needed
		if _needs_morale_check():
			morale_check_triggered.emit(enemies_remaining, casualties_this_round)

## Roll morale check
func roll_morale_check() -> Dictionary:
	var roll := randi_range(1, 6) + randi_range(1, 6)
	var effective_morale := base_morale + morale_modifier
	var result := {
		"roll": roll,
		"target": effective_morale,
		"success": roll <= effective_morale,
		"fled": 0,
		"panic": ""
	}

	if result.success:
		# Morale holds
		result.panic = ""
	else:
		# Morale breaks - determine panic
		var panic_roll := randi_range(1, 6)

		if enemies_remaining <= 2:
			# Few remaining - they flee
			result.fled = enemies_remaining
			result.panic = "ROUT"
		elif panic_roll <= 2:
			# Fall back
			result.panic = "FALL_BACK"
		elif panic_roll <= 4:
			# One flees
			result.fled = 1
			result.panic = "ONE_FLEES"
		else:
			# Duck for cover
			result.panic = "DUCK"

		# Apply fled enemies
		if result.fled > 0:
			fled_enemies += result.fled
			enemies_remaining -= result.fled
			enemy_fled.emit(result.fled)

		panic_occurred.emit(result.panic)

	_display_result(result)
	casualties_this_round = 0  # Reset for next round
	return result

## Reset for new round
func new_round() -> void:
	casualties_this_round = 0
	_clear_result()
	_update_display()

func _needs_morale_check() -> bool:
	# Morale check when first casualty each round
	return casualties_this_round == 1

func _update_display() -> void:
	# Morale value
	if morale_value_label:
		var effective := base_morale + morale_modifier
		var mod_text := ""
		if morale_modifier != 0:
			var sign := "+" if morale_modifier > 0 else ""
			mod_text = " (%s%d)" % [sign, morale_modifier]
		morale_value_label.text = "Morale: %d%s" % [effective, mod_text]

	# Status
	if status_label:
		status_label.text = "Enemies: %d / %d (Fled: %d)" % [enemies_remaining, total_enemies, fled_enemies]

		if enemies_remaining == 0:
			status_label.add_theme_color_override("font_color", UIColors.COLOR_EMERALD)
		elif enemies_remaining <= total_enemies / 2:
			status_label.add_theme_color_override("font_color", UIColors.COLOR_AMBER)
		else:
			status_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)

	# Casualties
	if casualties_label:
		if casualties_this_round > 0:
			casualties_label.text = "Casualties this round: %d" % casualties_this_round
			casualties_label.add_theme_color_override("font_color", UIColors.COLOR_AMBER)
			casualties_label.visible = true
		else:
			casualties_label.visible = false

func _display_result(result: Dictionary) -> void:
	if not result_container:
		return

	# Clear previous results
	for child in result_container.get_children():
		child.queue_free()

	# Roll result
	var roll_label := Label.new()
	roll_label.text = "Rolled: %d vs %d" % [result.roll, result.target]
	result_container.add_child(roll_label)

	# Outcome
	var outcome_label := Label.new()
	if result.success:
		outcome_label.text = "Morale Holds!"
		outcome_label.add_theme_color_override("font_color", UIColors.COLOR_EMERALD)
	else:
		outcome_label.text = "Morale Breaks!"
		outcome_label.add_theme_color_override("font_color", UIColors.COLOR_RED)
	outcome_label.add_theme_font_size_override("font_size", 16)
	result_container.add_child(outcome_label)

	# Panic effect
	if not result.panic.is_empty():
		var panic_label := Label.new()
		match result.panic:
			"ROUT":
				panic_label.text = "ROUT: All remaining enemies flee!"
			"FALL_BACK":
				panic_label.text = "Fall Back: Enemies retreat 6\" toward edge"
			"ONE_FLEES":
				panic_label.text = "One enemy flees the battlefield"
			"DUCK":
				panic_label.text = "Duck: Enemies take cover (no advance)"

		panic_label.add_theme_color_override("font_color", UIColors.COLOR_AMBER)
		panic_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		result_container.add_child(panic_label)

	# Fled count
	if result.fled > 0:
		var fled_label := Label.new()
		fled_label.text = "%d enemy/enemies fled" % result.fled
		fled_label.add_theme_color_override("font_color", Color.GOLD)
		result_container.add_child(fled_label)

	_update_display()

func _clear_result() -> void:
	if result_container:
		for child in result_container.get_children():
			child.queue_free()

func _on_roll_morale() -> void:
	roll_morale_check()
