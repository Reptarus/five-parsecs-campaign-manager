extends Control

## Example usage of LootDisplayCard component
## This demonstrates how to instantiate and use the loot card

@onready var container: VBoxContainer = $VBoxContainer

func _ready() -> void:
	_create_example_cards()

func _create_example_cards() -> void:
	"""Create example loot cards with different rarities and types"""

	# Example 1: Common weapon loot
	var weapon_card := _create_loot_card({
		"name": "Infantry Laser",
		"description": "Standard-issue laser rifle with reliable performance",
		"type": "weapon",
		"rarity": "common",
		"value": 150
	})
	container.add_child(weapon_card)

	# Example 2: Uncommon armor loot
	var armor_card := _create_loot_card({
		"name": "Ballistic Vest",
		"description": "Lightweight armor providing basic protection",
		"type": "armor",
		"rarity": "uncommon",
		"value": 250
	})
	container.add_child(armor_card)

	# Example 3: Rare gear loot
	var gear_card := _create_loot_card({
		"name": "Med-Kit",
		"description": "Advanced medical supplies for field treatment",
		"type": "gear",
		"rarity": "rare",
		"value": 300
	})
	container.add_child(gear_card)

	# Example 4: Epic consumable loot
	var consumable_card := _create_loot_card({
		"name": "Combat Stimulant",
		"description": "Enhances combat reflexes temporarily",
		"type": "consumable",
		"rarity": "epic",
		"value": 500
	})
	container.add_child(consumable_card)

	# Example 5: Credits loot (no rarity badge typically)
	var credits_card := _create_loot_card({
		"name": "Credits",
		"description": "Standard galactic currency",
		"type": "credits",
		"rarity": "common",
		"value": 1000
	})
	container.add_child(credits_card)

func _create_loot_card(item_data: Dictionary) -> LootDisplayCard:
	"""Helper to create and setup a loot card"""
	var card := LootDisplayCard.new()

	# Connect signal to handle item selection
	card.item_selected.connect(_on_item_selected)

	# Setup card with data
	card.setup(item_data)

	return card

func _on_item_selected(item_data: Dictionary) -> void:
	"""Handle loot card selection"""
	print("Loot item selected: %s (Value: %d CR)" % [
		item_data.get("name", "Unknown"),
		item_data.get("value", 0)
	])
