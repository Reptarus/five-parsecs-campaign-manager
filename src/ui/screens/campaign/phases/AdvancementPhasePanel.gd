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
var _bot_upgrade_installed_this_turn: bool = false  # Compendium p.28: max 1 per turn

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
	_wrap_advancement_content_in_cards()

func _wrap_advancement_content_in_cards() -> void:
	var vbox = $VBoxContainer
	if not vbox:
		return
	# Remove HSeparators
	for child in vbox.get_children():
		if child is HSeparator:
			child.queue_free()
	# Crew section: label + list + character info
	var crew_content := VBoxContainer.new()
	crew_content.add_theme_constant_override(
		"separation", UIColors.SPACING_SM)
	if crew_section_label \
		and crew_section_label.get_parent() == vbox:
		vbox.remove_child(crew_section_label)
		crew_content.add_child(crew_section_label)
	if crew_list and crew_list.get_parent() == vbox:
		vbox.remove_child(crew_list)
		crew_content.add_child(crew_list)
	if character_info \
		and character_info.get_parent() == vbox:
		vbox.remove_child(character_info)
		crew_content.add_child(character_info)
	var crew_card := _create_phase_card(
		"Crew Members", crew_content)
	vbox.add_child(crew_card)
	vbox.move_child(crew_card, 1)
	# Advancement section: label + options
	var adv_content := VBoxContainer.new()
	adv_content.add_theme_constant_override(
		"separation", UIColors.SPACING_SM)
	if advancement_label \
		and advancement_label.get_parent() == vbox:
		vbox.remove_child(advancement_label)
		adv_content.add_child(advancement_label)
	if advancement_options \
		and advancement_options.get_parent() == vbox:
		vbox.remove_child(advancement_options)
		adv_content.add_child(advancement_options)
	var adv_card := _create_phase_card(
		"Advancement Options", adv_content)
	vbox.add_child(adv_card)
	vbox.move_child(adv_card, 2)

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
		var name_str: String = _member_get(member, "character_name", "Unknown")
		var is_bot: bool = _member_get(member, "is_bot", false)

		if is_bot:
			# Bots use credits for upgrades, not XP (Compendium p.28)
			var text := "%s (Bot — Upgrades via Credits)" % name_str
			crew_list.add_item(text)
		else:
			var level: int = _member_get(member, "level", 1)
			var text := "%s (Level %d)" % [name_str, level]
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

	var is_bot_char: bool = _member_get(
		selected_crew_member, "is_bot", false)
	var is_soulless_char: bool = _member_get(
		selected_crew_member, "is_soulless", false)

	# Stat improvements + psionics: non-bots only
	if not is_bot_char:
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

		# Psionic training (Compendium DLC, Compendium pp.19-22)
		var dlc_psi = Engine.get_main_loop().root.get_node_or_null(
			"/root/DLCManager") if Engine.get_main_loop() else null
		if dlc_psi and dlc_psi.is_feature_enabled(
				dlc_psi.ContentFlag.PSIONICS):
			var char_powers: Array = _member_get(
				selected_crew_member, "psionic_powers", [])
			var char_psionic: String = (
				char_powers[0] if not char_powers.is_empty()
				else "")
			var char_enhanced: bool = _member_get(
				selected_crew_member,
				"psionic_power_enhanced", false)
			var crew_has_psionic: bool = (
				_crew_has_psionic_member())

			if char_psionic != "" or not crew_has_psionic:
				advancements.append({
					"name": "Acquire Psionic Power",
					"type": "PSIONICS",
					"stat": "",
					"amount": 0,
					"cost": 12,
					"max": 0,
					"training_key": "psionics",
					"description": "Roll D10 for a new psionic power",
				})

			if char_psionic != "" and not char_enhanced:
				advancements.append({
					"name": "Enhance Psionic Power",
					"type": "PSIONICS_ENHANCE",
					"stat": "",
					"amount": 0,
					"cost": 6,
					"max": 0,
					"training_key": "psionics_enhance",
					"description": "+1D6 to projection roll",
				})

	# Compendium DLC: training + bot upgrades (credits, not XP)
	# Filtered by character type (Compendium pp.27-28)
	var compendium_items: Array[Dictionary] = []
	compendium_items.assign(
		CompendiumEquipmentRef.get_advancement_phase_items())
	for item in compendium_items:
		var cat: String = item.get("compendium_category", "")
		# Bot upgrades: only for bots, not Soulless (p.28)
		if cat == "bot_upgrade":
			if not is_bot_char or is_soulless_char:
				continue
		# Training: only for non-bots
		if cat == "training" and is_bot_char:
			continue
		advancements.append({
			"name": item.get("name", "Unknown"),
			"type": "COMPENDIUM",
			"compendium_id": item.get("id", ""),
			"compendium_category": cat,
			"cost": item.get("cost", 0),
			"currency": item.get("currency", "credits"),
			"instruction": item.get("instruction", ""),
			"description": item.get("description", ""),
			"one_per_crew": item.get("one_per_crew", false),
		})

	return advancements

func _can_apply_advancement(advancement: Dictionary) -> bool:
	if not selected_crew_member:
		return false
	var is_bot: bool = _member_get(selected_crew_member, "is_bot", false)
	var experience: int = _member_get(selected_crew_member, "experience", 0)
	var credits: int = _get_credits()

	# Compendium items: credits + type-specific checks
	if advancement.type == "COMPENDIUM":
		if credits < advancement.cost:
			return false
		var comp_id: String = advancement.get("compendium_id", "")
		var cat: String = advancement.get("compendium_category", "")
		# Bot upgrade enforcement (Compendium p.28)
		if cat == "bot_upgrade":
			# One of each per bot
			var existing: Array = _member_get(
				selected_crew_member, "bot_upgrades", [])
			if comp_id in existing:
				return false
			# One upgrade per campaign turn
			if _bot_upgrade_installed_this_turn:
				return false
		# Training one_per_crew: check crew traits
		if cat == "training" and advancement.get(
				"one_per_crew", false):
			if _any_crew_has_training(comp_id):
				return false
		return true

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

	if advancement.type == "COMPENDIUM":
		if credits < advancement.cost:
			return "Not enough credits (need %d)" % advancement.cost
		var comp_cat: String = advancement.get("compendium_category", "")
		var comp_cid: String = advancement.get("compendium_id", "")
		if comp_cat == "bot_upgrade":
			var upgrades: Array = _member_get(
				selected_crew_member, "bot_upgrades", [])
			if comp_cid in upgrades:
				return "Already installed on this Bot"
			if _bot_upgrade_installed_this_turn:
				return "One Bot upgrade per turn (Compendium p.28)"
		if comp_cat == "training" and advancement.get("one_per_crew", false):
			if _any_crew_has_training(comp_cid):
				return "Another crew member already has this"

	if advancement.type == "STAT":
		var current_value: int = _member_get(
			selected_crew_member, advancement.stat, 0)
		if current_value >= advancement.max:
			tooltip = "Maximum value reached"
		var tip_psionic: String = _member_get(
			selected_crew_member, "psionic_power", "")
		if tip_psionic != "" and advancement.stat == "combat":
			tooltip = "Psionics cannot increase Combat Skill"

	return tooltip

func _on_crew_selected(index: int) -> void:
	var members = _get_crew_members()
	if index >= 0 and index < members.size():
		selected_crew_member = members[index]
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
				# Check against ALL known powers (Compendium p.22: shift ±1 on duplicate)
				var known: Array = _member_get(selected_crew_member, "psionic_powers", [])
				if new_power_id in known and power_ids.size() > 1:
					roll_index = (roll_index + 1) % power_ids.size()
					new_power_id = power_ids[roll_index]
					if new_power_id in known and power_ids.size() > 2:
						roll_index = (roll_index - 2 + power_ids.size()) % power_ids.size()
						new_power_id = power_ids[roll_index]
				# Append to powers array
				if selected_crew_member is Dictionary:
					var powers: Array = selected_crew_member.get("psionic_powers", [])
					powers.append(new_power_id)
					selected_crew_member["psionic_powers"] = powers
				elif "psionic_powers" in selected_crew_member:
					selected_crew_member.psionic_powers.append(new_power_id)
		"PSIONICS_ENHANCE":
			# Enhance existing psionic power — +1D6 projection bonus
			if selected_crew_member is Dictionary:
				selected_crew_member["psionic_power_enhanced"] = true
			else:
				selected_crew_member.set("psionic_power_enhanced", true)
		"COMPENDIUM":
			# Apply training or bot upgrade (Compendium pp.27-28)
			var comp_id: String = selected_advancement.get(
				"compendium_id", "")
			var cat: String = selected_advancement.get(
				"compendium_category", "")
			if cat == "bot_upgrade":
				if _member_has_method(
						selected_crew_member, "add_bot_upgrade"):
					selected_crew_member.add_bot_upgrade(comp_id)
				elif selected_crew_member is Dictionary:
					var upgrades: Array = selected_crew_member.get(
						"bot_upgrades", [])
					if comp_id not in upgrades:
						upgrades.append(comp_id)
					selected_crew_member["bot_upgrades"] = upgrades
				_bot_upgrade_installed_this_turn = true
			elif cat == "training":
				# Store training as Character trait
				var trait_name: String = _training_id_to_trait(
					comp_id)
				if _member_has_method(
						selected_crew_member, "add_trait"):
					selected_crew_member.add_trait(trait_name)
				elif selected_crew_member is Dictionary:
					var traits_arr: Array = selected_crew_member.get(
						"traits", [])
					if trait_name not in traits_arr:
						traits_arr.append(trait_name)
					selected_crew_member["traits"] = traits_arr

	# Deduct cost — COMPENDIUM items always use campaign credits
	if selected_advancement.type == "COMPENDIUM":
		var campaign = _get_campaign_safe()
		if campaign and "credits" in campaign:
			campaign.credits -= selected_advancement.cost
	elif is_bot:
		var campaign = _get_campaign_safe()
		if campaign and "credits" in campaign:
			campaign.credits -= selected_advancement.cost
	else:
		if selected_crew_member is Dictionary:
			selected_crew_member["experience"] = _member_get(
				selected_crew_member, "experience", 0) - selected_advancement.cost
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
			"COMPENDIUM":
				adv_desc = selected_advancement.get("name", "Compendium item")
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

func _any_crew_has_training(training_id: String) -> bool:
	## Check if any crew member has a one_per_crew training trait
	var trait_name: String = _training_id_to_trait(training_id)
	for member in _get_crew_members():
		if _member_has_method(member, "has_trait"):
			if member.has_trait(trait_name):
				return true
		elif member is Dictionary:
			if trait_name in member.get("traits", []):
				return true
	return false

static func _training_id_to_trait(training_id: String) -> String:
	## Map compendium training IDs to Character trait names
	match training_id:
		"freelancer_cert":
			return "Freelancer Certification"
		"instructor":
			return "Instructor"
		"survival_course":
			return "Survival Course"
		"fixer":
			return "Fixer"
		"tactical_course":
			return "Tactical Course"
	return training_id.replace("_", " ").capitalize()

func _load_psionic_powers_json() -> Dictionary:
	## Load psionic powers from JSON data file
	var path := "res://data/psionic_powers.json"
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
