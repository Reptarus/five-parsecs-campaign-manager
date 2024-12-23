class_name CrewPreviewList
extends VBoxContainer

signal crew_member_selected(index: int)

const Character = preload("res://src/core/character/Base/Character.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

func update_crew(crew_members: Array) -> void:
	# Clear existing children
	for child in get_children():
		child.queue_free()
	
	# Add crew members to the preview
	for i in range(crew_members.size()):
		var member = crew_members[i]
		if member == null:
			continue
		
		var member_box = HBoxContainer.new()
		member_box.size_flags_horizontal = SIZE_EXPAND_FILL
		
		# Portrait
		var portrait = TextureRect.new()
		portrait.custom_minimum_size = Vector2(64, 64)
		portrait.expand_mode = 1  # EXPAND_FILL = 1
		portrait.stretch_mode = 4  # KEEP_ASPECT_CENTERED = 4
		if member.portrait_path:
			var image = Image.new()
			if image.load(member.portrait_path) == OK:
				portrait.texture = ImageTexture.create_from_image(image)
		member_box.add_child(portrait)
		
		# Info container
		var info_container = VBoxContainer.new()
		info_container.size_flags_horizontal = SIZE_EXPAND_FILL
		
		# Name
		var name_label = Label.new()
		name_label.text = member.character_name
		name_label.add_theme_font_size_override("font_size", 18)
		info_container.add_child(name_label)
		
		# Class and Origin
		var details_label = Label.new()
		var character_class_name = GlobalEnums.CharacterClass.keys()[member.character_class].capitalize().replace("_", " ")
		var origin_name = GlobalEnums.Origin.keys()[member.origin].capitalize().replace("_", " ")
		details_label.text = "%s - %s" % [character_class_name, origin_name]
		info_container.add_child(details_label)
		
		# Stats - Updated to match Core Rules exactly
		var stats_label = Label.new()
		if member.stats:
			stats_label.text = "Reactions: %d | Speed: %d\" | Combat Skill: %+d | Toughness: %d | Savvy: %+d | Luck: %d" % [
				member.stats.reactions,
				member.stats.speed,
				member.stats.combat_skill,
				member.stats.toughness,
				member.stats.savvy,
				member.stats.luck
			]
			info_container.add_child(stats_label)
		
		# Equipment
		var equipment_label = Label.new()
		var equipment_text = "Equipment:"
		
		# Weapon
		if member.equipped_weapon:
			equipment_text += "\nWeapon: " + member.equipped_weapon.name
			equipment_text += " (Range: %d\", Shots: %d, Damage: %d)" % [
				member.equipped_weapon.range,
				member.equipped_weapon.shots,
				member.equipped_weapon.damage
			]
			if not member.equipped_weapon.special_rules.is_empty():
				equipment_text += "\nTraits: " + ", ".join(member.equipped_weapon.special_rules)
		
		# Gear
		if not member.equipped_gear.is_empty():
			equipment_text += "\nGear:"
			for gear in member.equipped_gear:
				equipment_text += "\n- " + gear.name
		
		# Gadgets
		if not member.equipped_gadgets.is_empty():
			equipment_text += "\nGadgets:"
			for gadget in member.equipped_gadgets:
				equipment_text += "\n- " + gadget.name
		
		equipment_label.text = equipment_text
		info_container.add_child(equipment_label)
		
		member_box.add_child(info_container)
		
		# Make the whole box clickable
		var button = Button.new()
		button.flat = true
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.size_flags_vertical = SIZE_EXPAND_FILL
		button.pressed.connect(_on_member_selected.bind(i))
		member_box.add_child(button)
		
		add_child(member_box)

func _on_member_selected(index: int) -> void:
	crew_member_selected.emit(index)
