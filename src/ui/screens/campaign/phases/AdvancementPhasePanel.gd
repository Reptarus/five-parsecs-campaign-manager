extends "res://src/ui/screens/campaign/phases/BasePhasePanel.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const ThisClass = preload("res://src/ui/screens/campaign/phases/AdvancementPhasePanel.gd")
const CompendiumEquipmentRef = preload("res://src/data/compendium_equipment.gd")

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var crew_section_label: Label = $VBoxContainer/CrewLabel
@onready var crew_list: ItemList = $VBoxContainer/CrewList
@onready var character_info: RichTextLabel = $VBoxContainer/CharacterInfo
@onready var advancement_label: Label = $VBoxContainer/AdvancementLabel
@onready var advancement_options: ItemList = $VBoxContainer/AdvancementOptions
@onready var apply_button: Button = $VBoxContainer/ApplyButton
@onready var done_button: Button = $VBoxContainer/DoneButton

var selected_crew_member = null # Character instance or Dictionary
var selected_crew_index: int = -1
var available_advancements: Array = []
var selected_advancement: Dictionary = {}

# XP costs from core rules
var advancement_costs: Dictionary = {
	"REACTION": 7,
	"COMBAT": 7,
	"SPEED": 5,
	"SAVVY": 5,
	"TOUGHNESS": 6,
	"LUCK": 10,
	"TRAINING": {
		"PILOT": 20,
		"MECHANIC": 15,
		"MEDICAL": 20,
		"MERCHANT": 10,
		"SECURITY": 10,
		"BROKER": 15,
		"BOT_TECH": 10
	}
}

# Maximum values from core rules
var max_stats: Dictionary = {
	"REACTION": 6,
	"COMBAT": 5,
	"SPEED": 8,
	"SAVVY": 5,
	"TOUGHNESS": 6,
	"LUCK": 1 # Humans can have 3
}

func _ready() -> void:
	super._ready()
	_style_phase_title(title_label)
	_style_section_label(crew_section_label)
	_style_item_list(crew_list)
	_style_rich_text(character_info)
	_style_section_label(advancement_label)
	_style_item_list(advancement_options)
	_style_phase_button(apply_button)
	_style_phase_button(done_button, true)
	_connect_signals()

func _connect_signals() -> void:
	if crew_list:
		crew_list.item_selected.connect(_on_crew_selected)
	if advancement_options:
		advancement_options.item_selected.connect(_on_advancement_selected)
	if apply_button:
		apply_button.pressed.connect(_on_apply_pressed)
	if done_button:
		done_button.pressed.connect(_on_done_pressed)

func _get_campaign_safe():
	return game_state.campaign if game_state else null

func _get_crew_members() -> Array:
	var campaign = _get_campaign_safe()
	if not campaign:
		return []
	if campaign.has_method("get_active_crew_members"):
		return campaign.get_active_crew_members()
	if campaign.has_method("get_crew_members"):
		return campaign.get_crew_members()
	if "crew_data" in campaign:
		return campaign.crew_data.get("members", [])
	return []

func _get_credits() -> int:
	var campaign = _get_campaign_safe()
	if not campaign:
		return 0
	if "credits" in campaign:
		return campaign.credits
	return 0

func _member_get(member, prop: String, default_val = null):
	if member is Dictionary:
		return member.get(prop, default_val)
	elif prop in member:
		return member.get(prop) if member.has_method("get") else member[prop]
	return default_val

func _member_has_method(member, method_name: String) -> bool:
	if member is Dictionary:
		return false
	return member.has_method(method_name) if member else false

func setup_phase() -> void:
	super.setup_phase()
	_load_crew()
	_update_ui()

func _load_crew() -> void:
	if not crew_list:
		return
	crew_list.clear()
	var members = _get_crew_members()
	if members.is_empty():
		crew_list.add_item("No Crew Members")
		return
	for member in members:
		# Bots don't get XP
		if _member_get(member, "is_bot", false):
			continue

		var name_str: String = _member_get(member, "character_name", "Unknown")
		var level: int = _member_get(member, "level", 1)
		var text = "%s (Level %d)" % [name_str, level]

		var experience: int = _member_get(member, "experience", 0)
		var next_level_xp: int = 100
		if _member_has_method(member, "get_experience_for_next_level"):
			next_level_xp = member.get_experience_for_next_level()
		if experience >= next_level_xp:
			text += " - LEVEL UP AVAILABLE"
		crew_list.add_item(text)

func _update_ui() -> void:
	if not selected_crew_member:
		if character_info:
			character_info.text = "Select a crew member"
		if advancement_options:
			advancement_options.clear()
		if apply_button:
			apply_button.disabled = true
		return

	_update_character_info()
	_update_advancement_options()

func _update_character_info() -> void:
	if not character_info:
		return
	var name_str: String = _member_get(selected_crew_member, "character_name", "Unknown")
	var level: int = _member_get(selected_crew_member, "level", 1)
	var experience: int = _member_get(selected_crew_member, "experience", 0)
	var next_level_xp: int = 100
	if _member_has_method(selected_crew_member, "get_experience_for_next_level"):
		next_level_xp = selected_crew_member.get_experience_for_next_level()

	var info := "[b]%s[/b]\n" % name_str
	info += "Level: %d\n" % level
	info += "Experience: %d/%d\n" % [experience, next_level_xp]

	info += "\n[b]Stats:[/b]\n"
	info += "Reaction: %d/%d\n" % [_member_get(selected_crew_member, "reaction", 1), max_stats.REACTION]
	info += "Combat: %d/%d\n" % [_member_get(selected_crew_member, "combat", 0), max_stats.COMBAT]
	info += "Speed: %d/%d\n" % [_member_get(selected_crew_member, "speed", 4), max_stats.SPEED]
	info += "Savvy: %d/%d\n" % [_member_get(selected_crew_member, "savvy", 0), max_stats.SAVVY]
	info += "Toughness: %d/%d\n" % [_member_get(selected_crew_member, "toughness", 3), max_stats.TOUGHNESS]
	info += "Luck: %d/%d\n" % [_member_get(selected_crew_member, "luck", 0), max_stats.LUCK]

	_set_keyword_text(character_info, info)

func _update_advancement_options() -> void:
	if not advancement_options:
		return
	advancement_options.clear()
	available_advancements = _get_available_advancements()

	for advancement in available_advancements:
		var text = advancement.name
		if advancement.get("type") == "COMPENDIUM" or advancement.get("currency") == "credits":
			text += " (%d credits)" % advancement.cost
		elif _member_get(selected_crew_member, "is_bot", false):
			text += " (%d credits)" % advancement.cost
		else:
			text += " (%d XP)" % advancement.cost
		advancement_options.add_item(text)

		if not _can_apply_advancement(advancement):
			var idx = advancement_options.item_count - 1
			advancement_options.set_item_disabled(idx, true)
			advancement_options.set_item_custom_fg_color(idx, Color(0.5, 0.5, 0.5))
			advancement_options.set_item_tooltip(idx, _get_requirement_tooltip(advancement))

func _get_available_advancements() -> Array:
	var advancements = []
	if not selected_crew_member:
		return advancements

	# Add stat improvements
	advancements.append_array([
		{
			"name": "Increase Reaction",
			"type": "STAT",
			"stat": "reaction",
			"amount": 1,
			"cost": advancement_costs.REACTION,
			"max": max_stats.REACTION
		},
		{
			"name": "Increase Combat",
			"type": "STAT",
			"stat": "combat",
			"amount": 1,
			"cost": advancement_costs.COMBAT,
			"max": max_stats.COMBAT
		},
		{
			"name": "Increase Speed",
			"type": "STAT",
			"stat": "speed",
			"amount": 1,
			"cost": advancement_costs.SPEED,
			"max": max_stats.SPEED
		},
		{
			"name": "Increase Savvy",
			"type": "STAT",
			"stat": "savvy",
			"amount": 1,
			"cost": advancement_costs.SAVVY,
			"max": max_stats.SAVVY
		},
		{
			"name": "Increase Toughness",
			"type": "STAT",
			"stat": "toughness",
			"amount": 1,
			"cost": advancement_costs.TOUGHNESS,
			"max": max_stats.TOUGHNESS
		},
		{
			"name": "Increase Luck",
			"type": "STAT",
			"stat": "luck",
			"amount": 1,
			"cost": advancement_costs.LUCK,
			"max": max_stats.LUCK
		}
	])

	# Psionic training (Compendium DLC, Core Rules pp.96-101)
	var dlc = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if dlc and dlc.is_feature_enabled(dlc.ContentFlag.PSIONICS):
		var char_psionic: String = _member_get(selected_crew_member, "psionic_power", "")
		var char_enhanced: bool = _member_get(selected_crew_member, "psionic_power_enhanced", false)
		var crew_has_psionic: bool = _crew_has_psionic_member()

		# Acquire: character is already psionic (learn another), OR no psionic in crew yet
		if char_psionic != "" or not crew_has_psionic:
			advancements.append({
				"name": "Acquire Psionic Power",
				"type": "PSIONICS",
				"stat": "",
				"amount": 0,
				"cost": 12,
				"max": 0,
				"training_key": "psionics",
				"description": "Roll D10 for a new psionic power (Core Rules p.101)"
			})

		# Enhance: character must already have a power and not be enhanced
		if char_psionic != "" and not char_enhanced:
			advancements.append({
				"name": "Enhance Psionic Power",
				"type": "PSIONICS_ENHANCE",
				"stat": "",
				"amount": 0,
				"cost": 6,
				"max": 0,
				"training_key": "psionics_enhance",
				"description": "+1D6 to projection roll for chosen power (Core Rules p.101)"
			})

	# Compendium DLC: Advanced training + bot upgrades (cost in credits, not XP)
	var compendium_items: Array[Dictionary] = CompendiumEquipmentRef.get_advancement_phase_items()
	for item in compendium_items:
		advancements.append({
			"name": item.get("name", "Unknown"),
			"type": "COMPENDIUM",
			"compendium_id": item.get("id", ""),
			"cost": item.get("cost", 0),
			"currency": item.get("currency", "credits"),
			"instruction": item.get("instruction", ""),
			"description": item.get("description", ""),
		})

	return advancements

func _can_apply_advancement(advancement: Dictionary) -> bool:
	if not selected_crew_member:
		return false
	var is_bot: bool = _member_get(selected_crew_member, "is_bot", false)
	var experience: int = _member_get(selected_crew_member, "experience", 0)
	var credits: int = _get_credits()

	# Compendium items always cost credits
	if advancement.type == "COMPENDIUM":
		return credits >= advancement.cost

	# Check XP cost for non-bots
	if not is_bot and experience < advancement.cost:
		return false

	# Check credit cost for bots
	if is_bot and credits < advancement.cost:
		return false

	# Check stat maximums
	if advancement.type == "STAT":
		var current_value: int = _member_get(selected_crew_member, advancement.stat, 0)
		if current_value >= advancement.max:
			return false
		# Psionic restriction: Cannot increase Combat through XP (Core Rules p.96)
		var char_psionic_check: String = _member_get(selected_crew_member, "psionic_power", "")
		if char_psionic_check != "" and advancement.stat == "combat":
			return false

	return true

func _get_requirement_tooltip(advancement: Dictionary) -> String:
	var tooltip = ""
	var is_bot: bool = _member_get(selected_crew_member, "is_bot", false)
	var experience: int = _member_get(selected_crew_member, "experience", 0)
	var credits: int = _get_credits()

	if not is_bot and experience < advancement.cost:
		tooltip = "Not enough XP (need %d)" % advancement.cost

	if is_bot and credits < advancement.cost:
		tooltip = "Not enough credits (need %d)" % advancement.cost

	if advancement.type == "STAT":
		var current_value: int = _member_get(selected_crew_member, advancement.stat, 0)
		if current_value >= advancement.max:
			tooltip = "Maximum value reached"
		var tip_psionic: String = _member_get(selected_crew_member, "psionic_power", "")
		if tip_psionic != "" and advancement.stat == "combat":
			tooltip = "Psionics cannot increase Combat Skill (Core Rules p.96)"

	return tooltip

func _on_crew_selected(index: int) -> void:
	var members = _get_crew_members()
	# Filter out bots for indexing
	var non_bot_members: Array = []
	for m in members:
		if not _member_get(m, "is_bot", false):
			non_bot_members.append(m)
	if index >= 0 and index < non_bot_members.size():
		selected_crew_member = non_bot_members[index]
		selected_crew_index = index
	_update_ui()

func _on_advancement_selected(index: int) -> void:
	if index >= 0 and index < available_advancements.size():
		selected_advancement = available_advancements[index]
		if apply_button:
			apply_button.disabled = not _can_apply_advancement(selected_advancement)

func _on_apply_pressed() -> void:
	if not selected_crew_member or not _can_apply_advancement(selected_advancement):
		return

	var is_bot: bool = _member_get(selected_crew_member, "is_bot", false)

	match selected_advancement.type:
		"STAT":
			var current_val: int = _member_get(selected_crew_member, selected_advancement.stat, 0)
			if selected_crew_member is Dictionary:
				selected_crew_member[selected_advancement.stat] = current_val + selected_advancement.amount
			else:
				selected_crew_member.set(selected_advancement.stat, current_val + selected_advancement.amount)
		"PSIONICS":
			# Acquire psionic power — roll D10, assign from psionic_powers.json
			var psionic_data: Dictionary = _load_psionic_powers_json()
			var power_ids: Array = psionic_data.keys()
			if not power_ids.is_empty():
				var roll_index: int = randi_range(0, power_ids.size() - 1)
				var new_power_id: String = power_ids[roll_index]
				var current_power: String = _member_get(selected_crew_member, "psionic_power", "")
				if new_power_id == current_power and power_ids.size() > 1:
					roll_index = (roll_index + 1) % power_ids.size()
					new_power_id = power_ids[roll_index]
				if selected_crew_member is Dictionary:
					selected_crew_member["psionic_power"] = new_power_id
				else:
					selected_crew_member.set("psionic_power", new_power_id)
		"PSIONICS_ENHANCE":
			# Enhance existing psionic power — +1D6 projection bonus
			if selected_crew_member is Dictionary:
				selected_crew_member["psionic_power_enhanced"] = true
			else:
				selected_crew_member.set("psionic_power_enhanced", true)

	# Deduct cost
	if is_bot:
		var campaign = _get_campaign_safe()
		if campaign and "credits" in campaign:
			campaign.credits -= selected_advancement.cost
	else:
		if selected_crew_member is Dictionary:
			selected_crew_member["experience"] = _member_get(selected_crew_member, "experience", 0) - selected_advancement.cost
		else:
			selected_crew_member.experience -= selected_advancement.cost

	# Log advancement to CampaignJournal
	var journal = get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("auto_create_character_event"):
		var char_id: String = _member_get(selected_crew_member, "character_id",
			_member_get(selected_crew_member, "id", ""))
		var char_name: String = _member_get(selected_crew_member, "character_name",
			_member_get(selected_crew_member, "name", "Unknown"))
		var adv_desc: String = ""
		match selected_advancement.type:
			"STAT":
				adv_desc = "%s +%d" % [selected_advancement.stat.capitalize(), selected_advancement.amount]
			"PSIONICS":
				adv_desc = "Acquired psionic power: %s" % _member_get(selected_crew_member, "psionic_power", "unknown")
			"PSIONICS_ENHANCE":
				adv_desc = "Enhanced psionic power"
		journal.auto_create_character_event(char_id, "advancement", {
			"character_name": char_name,
			"advancement": adv_desc,
			"cost": selected_advancement.cost,
			"is_bot": is_bot
		})

	_update_ui()

func _on_done_pressed() -> void:
	complete_phase()

func validate_phase_requirements() -> bool:
	return game_state != null

func get_phase_data() -> Dictionary:
	return {
		"crew_count": _get_crew_members().size(),
	}

func _crew_has_psionic_member() -> bool:
	## Check if any crew member already has a psionic power (one psionic per crew rule, Core Rules p.96)
	var members := _get_crew_members()
	for member in members:
		var power: String = _member_get(member, "psionic_power", "")
		if power != "":
			return true
	return false

func _load_psionic_powers_json() -> Dictionary:
	## Load psionic powers from JSON data file
	var path := "res://data/psionic_powers.json"
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}
