extends Object
class_name EquipmentFormatter

## EquipmentFormatter - Utility for Equipment Display with Keywords
## Static methods for extracting and formatting equipment data with clickable keywords
## Works with Equipment resources and raw data dictionaries

# Preload to avoid global class name conflict
const KeywordTooltipUtil = preload("res://src/ui/components/tooltips/KeywordTooltip.gd")

## Extract traits from equipment resource/dictionary
static func extract_traits(equipment: Variant) -> Array[String]:
	"""
	Extract traits array from Equipment resource or dictionary.
	
	Returns array of trait strings like ["Assault", "Bulky"]
	"""
	var traits: Array[String] = []
	
	if equipment == null:
		return traits
	
	# Handle Equipment resource (assuming it has traits property)
	if equipment is Resource:
		if "traits" in equipment:
			var trait_data = equipment.get("traits")
			if trait_data is Array:
				for trait_item in trait_data:
					if trait_item is String:
						traits.append(trait_item)
	
	# Handle dictionary data
	elif equipment is Dictionary:
		if "traits" in equipment:
			var trait_data = equipment["traits"]
			if trait_data is Array:
				for trait_item in trait_data:
					if trait_item is String:
						traits.append(trait_item)
	
	return traits

## Extract equipment name
static func extract_name(equipment: Variant) -> String:
	"""Extract equipment name from resource or dictionary"""
	if equipment == null:
		return "Unknown Equipment"
	
	# Handle Resource
	if equipment is Resource:
		if "equipment_name" in equipment:
			return equipment.get("equipment_name")
		elif "name" in equipment:
			return equipment.get("name")
	
	# Handle Dictionary
	elif equipment is Dictionary:
		if "equipment_name" in equipment:
			return equipment["equipment_name"]
		elif "name" in equipment:
			return equipment["name"]
	
	return "Unknown Equipment"

## Format equipment for display with keywords
static func format_for_display(equipment: Variant, include_traits: bool = true) -> String:
	"""
	Format equipment with clickable keyword traits.
	
	Returns BBCode string like: "Infantry Laser ([url=keyword:Assault]Assault[/url], [url=keyword:Bulky]Bulky[/url])"
	"""
	var name = extract_name(equipment)
	
	if not include_traits:
		return name
	
	var traits = extract_traits(equipment)
	return KeywordTooltipUtil.format_equipment_with_keywords(name, traits)

## Format equipment list for ItemList or RichTextLabel
static func format_list_item(equipment: Variant, show_quantity: bool = false) -> String:
	"""
	Format equipment for list display.
	
	If show_quantity=true, looks for 'quantity' property and prepends: "2x Infantry Laser (Assault, Bulky)"
	"""
	var formatted = format_for_display(equipment)
	
	if show_quantity:
		var qty = _extract_quantity(equipment)
		if qty > 1:
			formatted = "%dx %s" % [qty, formatted]
	
	return formatted

static func _extract_quantity(equipment: Variant) -> int:
	"""Extract quantity from equipment data"""
	if equipment == null:
		return 1
	
	# Handle Resource
	if equipment is Resource:
		if "quantity" in equipment:
			return int(equipment.get("quantity"))
	
	# Handle Dictionary
	elif equipment is Dictionary:
		if "quantity" in equipment:
			return int(equipment["quantity"])
	
	return 1

## Create BBCode color-coded equipment display
static func format_with_category_color(equipment: Variant) -> String:
	"""
	Format equipment with category-based color coding.
	
	Weapon: Blue, Armor: Green, Consumable: Yellow, etc.
	"""
	var name = extract_name(equipment)
	var category = _extract_category(equipment)
	var traits = extract_traits(equipment)
	
	var color_code = _get_category_color(category)
	var colored_name = "[color=%s]%s[/color]" % [color_code, name]
	
	if traits.is_empty():
		return colored_name
	
	# Add traits with keywords
	var formatted_traits: Array[String] = []
	for trait_item in traits:
		formatted_traits.append("[url=keyword:%s]%s[/url]" % [trait_item, trait_item])
	
	return "%s (%s)" % [colored_name, ", ".join(formatted_traits)]

static func _extract_category(equipment: Variant) -> String:
	"""Extract equipment category"""
	if equipment == null:
		return "misc"
	
	# Handle Resource
	if equipment is Resource:
		if "category" in equipment:
			return equipment.get("category")
		elif "type" in equipment:
			return equipment.get("type")
	
	# Handle Dictionary
	elif equipment is Dictionary:
		if "category" in equipment:
			return equipment["category"]
		elif "type" in equipment:
			return equipment["type"]
	
	return "misc"

static func _get_category_color(category: String) -> String:
	"""Get color code for equipment category"""
	match category.to_lower():
		"weapon", "gun", "melee":
			return "#4FC3F7"  # Cyan
		"armor", "shield", "protection":
			return "#10B981"  # Green
		"consumable", "grenade", "gear":
			return "#D97706"  # Orange
		"implant", "mod", "upgrade":
			return "#8B5CF6"  # Purple
		_:
			return "#E0E0E0"  # Default white

## Extract all unique keywords from equipment list
static func extract_all_keywords(equipment_list: Array) -> Array[String]:
	"""
	Extract all unique traits/keywords from an array of equipment.
	
	Useful for pre-highlighting keywords in descriptions.
	"""
	var keywords: Array[String] = []
	
	for equipment in equipment_list:
		var traits = extract_traits(equipment)
		for trait_item in traits:
			if not keywords.has(trait_item):
				keywords.append(trait_item)
	
	return keywords

## Create tooltip-enabled ItemList
static func populate_item_list(item_list: ItemList, equipment_array: Array, tooltip_node: Node) -> void:
	"""
	Populate ItemList with equipment, but note: ItemList doesn't support BBCode.

	This is a fallback method. For clickable keywords, use RichTextLabel instead.
	ItemList displays plain text without keyword links.
	"""
	item_list.clear()

	for equipment in equipment_array:
		var name = extract_name(equipment)
		var traits = extract_traits(equipment)

		# ItemList doesn't support BBCode, so format as plain text
		var display_text = name
		if not traits.is_empty():
			display_text += " (" + ", ".join(traits) + ")"

		item_list.add_item(display_text)

	push_warning("EquipmentFormatter: ItemList doesn't support BBCode keywords. Use RichTextLabel for interactive keywords.")

# ========== IMPLANT FORMATTING ==========

## Format implant with stat bonus indicator
static func format_implant(implant: Dictionary) -> String:
	"""
	Format implant name with stat bonus.

	Args:
		implant: Dictionary with 'name' and 'stat_bonus' fields

	Returns:
		Formatted string like "Neural Link (+1 Savvy)"
	"""
	var implant_name := implant.get("name", "Unknown Implant")
	var stat_bonus: Dictionary = implant.get("stat_bonus", {})

	if stat_bonus.is_empty():
		return implant_name

	# Format stat bonuses as readable text
	var bonus_text: Array[String] = []
	for stat_name in stat_bonus:
		var bonus_value: int = stat_bonus[stat_name]
		var formatted_stat := stat_name.capitalize()
		bonus_text.append("+%d %s" % [bonus_value, formatted_stat])

	return "%s (%s)" % [implant_name, ", ".join(bonus_text)]

## Format implant list for display
static func format_implant_list(implants: Array) -> String:
	"""
	Format array of implants as BBCode list.

	Returns:
		BBCode string with bullet points
	"""
	if implants.is_empty():
		return "[color=#808080]No implants[/color]"

	var formatted_lines: Array[String] = []
	for implant in implants:
		if implant is Dictionary:
			var formatted := format_implant(implant)
			formatted_lines.append("• %s" % formatted)

	return "\n".join(formatted_lines)
