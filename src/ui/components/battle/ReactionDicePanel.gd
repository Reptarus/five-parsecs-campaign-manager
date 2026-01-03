class_name FPCM_ReactionDicePanel
extends PanelContainer

## Reaction Dice Assignment Panel
##
## Tracks and manages reaction dice for crew members during battle.
## Allows spending dice for reactions, overwatch, etc.
##
## Reference: Core Rules p.108 "Reactions"

const FiveParsecsCampaignPanel = preload("res://src/ui/screens/campaign/panels/BaseCampaignPanel.gd")

# Signals
signal dice_spent(character_name: String, remaining: int)
signal all_dice_reset()

# UI References
@onready var title_label: Label = $VBox/TitleLabel
@onready var round_label: Label = $VBox/RoundLabel
@onready var crew_container: VBoxContainer = $VBox/ScrollContainer/CrewContainer
@onready var total_label: Label = $VBox/TotalLabel
@onready var reset_button: Button = $VBox/ButtonContainer/ResetButton

# Crew dice tracking
var crew_dice: Dictionary = {}  # character_name -> {max: int, current: int}
var current_round: int = 1

func _ready() -> void:
	_setup_panel_style()
	_setup_buttons()

func _setup_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = FiveParsecsCampaignPanel.COLOR_ELEVATED  # Design system: card backgrounds
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_width_left = 3  # Accent border (reaction dice indicator)
	style.border_color = Color.SKY_BLUE  # Keep blue for reaction specialty
	style.set_content_margin_all(FiveParsecsCampaignPanel.SPACING_MD)  # Design system: 16px for inner card padding
	add_theme_stylebox_override("panel", style)

func _setup_buttons() -> void:
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)

## Initialize with crew data
func set_crew(crew: Array) -> void:
	crew_dice.clear()

	for member in crew:
		var name: String = ""
		var reactions: int = 1

		# Get name and reaction stat
		# Sprint 26.3: Character-Everywhere - crew members are always Character objects
		if member is Character:
			name = member.character_name if "character_name" in member else (member.name if "name" in member else "Unknown")
			reactions = member.reactions if "reactions" in member else 1
		elif member is Resource:
			name = member.get_meta("name") if member.has_meta("name") else "Unknown"
			reactions = member.get_meta("reactions") if member.has_meta("reactions") else 1
		elif member is Dictionary:
			name = member.get("name", member.get("character_name", "Unknown"))
			reactions = member.get("reactions", 1)
		else:
			continue

		crew_dice[name] = {
			"max": reactions,
			"current": reactions
		}

	_update_display()

## Add a crew member manually
func add_crew_member(name: String, reactions: int = 1) -> void:
	crew_dice[name] = {
		"max": reactions,
		"current": reactions
	}
	_update_display()

## Spend a reaction die
func spend_die(character_name: String) -> bool:
	if not crew_dice.has(character_name):
		return false

	if crew_dice[character_name].current <= 0:
		return false

	crew_dice[character_name].current -= 1
	_update_display()
	dice_spent.emit(character_name, crew_dice[character_name].current)
	return true

## Get remaining dice for character
func get_remaining(character_name: String) -> int:
	if not crew_dice.has(character_name):
		return 0
	return crew_dice[character_name].current

## Get total remaining dice
func get_total_remaining() -> int:
	var total := 0
	for data in crew_dice.values():
		total += data.current
	return total

## Reset all dice for new round
func reset_all_dice() -> void:
	for name in crew_dice:
		crew_dice[name].current = crew_dice[name].max
	current_round += 1
	_update_display()
	all_dice_reset.emit()

## Set current round
func set_round(round_num: int) -> void:
	current_round = round_num
	if round_label:
		round_label.text = "Round %d" % round_num

func _update_display() -> void:
	# Update round label
	if round_label:
		round_label.text = "Round %d" % current_round

	# Clear crew container
	if crew_container:
		for child in crew_container.get_children():
			child.queue_free()

		# Create entry for each crew member
		for name in crew_dice:
			var entry := _create_crew_entry(name, crew_dice[name])
			crew_container.add_child(entry)

	# Update total
	if total_label:
		var total := get_total_remaining()
		total_label.text = "Total Remaining: %d" % total
		if total == 0:
			total_label.add_theme_color_override("font_color", Color.RED)
		else:
			total_label.add_theme_color_override("font_color", Color.GREEN)

func _create_crew_entry(name: String, data: Dictionary) -> Control:
	var container := HBoxContainer.new()
	container.custom_minimum_size.y = 48  # TOUCH_TARGET_MIN (mobile-first design)

	# Name label
	var name_label := Label.new()
	name_label.text = name
	name_label.custom_minimum_size.x = 120
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(name_label)

	# Dice display
	var dice_label := Label.new()
	dice_label.text = "%d / %d" % [data.current, data.max]
	dice_label.custom_minimum_size.x = 50
	dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if data.current == 0:
		dice_label.add_theme_color_override("font_color", Color.RED)
	elif data.current < data.max:
		dice_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		dice_label.add_theme_color_override("font_color", Color.GREEN)

	container.add_child(dice_label)

	# Spend button
	var spend_btn := Button.new()
	spend_btn.text = "Spend"
	spend_btn.custom_minimum_size.x = 60
	spend_btn.disabled = data.current <= 0
	spend_btn.pressed.connect(_on_spend_pressed.bind(name))
	container.add_child(spend_btn)

	return container

func _on_spend_pressed(character_name: String) -> void:
	spend_die(character_name)

func _on_reset_pressed() -> void:
	reset_all_dice()
