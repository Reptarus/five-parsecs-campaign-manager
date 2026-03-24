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
	_build_end_phase_panic_ui()

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

# =====================================================
# END PHASE PANIC (Core Rules p.113)
# =====================================================
# SEPARATE from morale checks. At end of each round:
# Roll D6 per enemy killed THIS round. Each die within
# the enemy's Panic range = one enemy Bails (closest to
# enemy battlefield edge first).

var _panic_section: VBoxContainer
var _panic_range_spin: SpinBox
var _panic_kills_spin: SpinBox
var _panic_roll_button: Button
var _panic_result_label: RichTextLabel

## Build the End Phase Panic UI section (called from _ready)
func _build_end_phase_panic_ui() -> void:
	var parent: Node = $VBox if has_node("VBox") else self
	if not parent:
		return

	var sep := HSeparator.new()
	parent.add_child(sep)

	_panic_section = VBoxContainer.new()
	_panic_section.add_theme_constant_override("separation", 4)
	parent.add_child(_panic_section)

	var header := Label.new()
	header.text = "End Phase — Panic Rolls (p.113)"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	_panic_section.add_child(header)

	# Panic range input
	var range_row := HBoxContainer.new()
	range_row.add_theme_constant_override("separation", 8)
	_panic_section.add_child(range_row)

	var range_lbl := Label.new()
	range_lbl.text = "Enemy Panic Range:"
	range_lbl.add_theme_font_size_override("font_size", 14)
	range_lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	range_row.add_child(range_lbl)

	_panic_range_spin = SpinBox.new()
	_panic_range_spin.min_value = 0
	_panic_range_spin.max_value = 6
	_panic_range_spin.value = 1
	_panic_range_spin.custom_minimum_size = Vector2(70, 40)
	_panic_range_spin.tooltip_text = "0 = fight to the death. 1-2 = typical. Check enemy stats."
	range_row.add_child(_panic_range_spin)

	# Kills this round input (auto-populated from casualties_this_round)
	var kills_row := HBoxContainer.new()
	kills_row.add_theme_constant_override("separation", 8)
	_panic_section.add_child(kills_row)

	var kills_lbl := Label.new()
	kills_lbl.text = "Kills This Round:"
	kills_lbl.add_theme_font_size_override("font_size", 14)
	kills_lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	kills_row.add_child(kills_lbl)

	_panic_kills_spin = SpinBox.new()
	_panic_kills_spin.min_value = 0
	_panic_kills_spin.max_value = 20
	_panic_kills_spin.value = 0
	_panic_kills_spin.custom_minimum_size = Vector2(70, 40)
	kills_row.add_child(_panic_kills_spin)

	# Roll button
	_panic_roll_button = Button.new()
	_panic_roll_button.text = "Roll End Phase Panic"
	_panic_roll_button.custom_minimum_size.y = 44
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.55, 0.15, 0.15, 0.8)
	btn_style.set_corner_radius_all(6)
	_panic_roll_button.add_theme_stylebox_override("normal", btn_style)
	_panic_roll_button.pressed.connect(_on_roll_end_phase_panic)
	_panic_section.add_child(_panic_roll_button)

	# Result display
	_panic_result_label = RichTextLabel.new()
	_panic_result_label.bbcode_enabled = true
	_panic_result_label.fit_content = true
	_panic_result_label.custom_minimum_size = Vector2(0, 40)
	_panic_result_label.scroll_active = false
	_panic_result_label.add_theme_font_size_override("normal_font_size", 14)
	_panic_result_label.add_theme_color_override("default_color", UIColors.COLOR_TEXT_PRIMARY)
	_panic_section.add_child(_panic_result_label)

func _on_roll_end_phase_panic() -> void:
	var kills: int = int(_panic_kills_spin.value)
	var panic_range: int = int(_panic_range_spin.value)

	if kills <= 0:
		_panic_result_label.text = "[color=#808080]No kills this round — no panic rolls needed.[/color]"
		return

	if panic_range <= 0:
		_panic_result_label.text = "[color=#808080]Panic range 0 — enemies fight to the death![/color]"
		return

	# Roll D6 per kill (Core Rules p.113)
	var rolls: Array[int] = []
	var bails: int = 0
	for i: int in range(kills):
		var roll: int = randi_range(1, 6)
		rolls.append(roll)
		if roll <= panic_range:
			bails += 1

	# Build result display
	var bbcode := "[b]End Phase Panic Rolls[/b]\n"
	bbcode += "Panic Range: [b]%d[/b] (die <= %d = Bail)\n" % [panic_range, panic_range]
	bbcode += "Rolls: "
	for i: int in range(rolls.size()):
		var r: int = rolls[i]
		if r <= panic_range:
			bbcode += "[color=#10B981][b]%d[/b][/color] " % r
		else:
			bbcode += "%d " % r
	bbcode += "\n\n"

	if bails > 0:
		bbcode += "[color=#10B981][b]%d enemy/enemies Bail![/b][/color]\n" % bails
		bbcode += "Remove %d figures closest to the enemy battlefield edge.\n" % bails
		bbcode += "[color=#808080](Bailed enemies do not count as killed)[/color]"

		# Update tracker state
		fled_enemies += bails
		enemies_remaining = maxi(0, enemies_remaining - bails)
		enemy_fled.emit(bails)
		_update_display()
	else:
		bbcode += "[color=#D97706]No enemies Bail — they hold firm.[/color]"

	_panic_result_label.text = bbcode
