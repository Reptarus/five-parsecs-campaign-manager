# Resources/CharacterCreation.gd
class_name CharacterCreation
extends Resource

var species_options: Array[String] = ["Human", "Alien", "Robot"]
var background_options: Array[String] = ["Soldier", "Scientist", "Engineer", "Medic"]
var motivation_options: Array[String] = ["Revenge", "Discovery", "Wealth", "Glory"]
var class_options: Array[String] = ["Warrior", "Technician", "Explorer", "Medic"]

func get_random_options() -> Dictionary:
	return {
		"species": species_options[randi() % species_options.size()],
		"background": background_options[randi() % background_options.size()],
		"motivation": motivation_options[randi() % motivation_options.size()],
		"character_class": class_options[randi() % class_options.size()]
	}

func create_random_character() -> Character:
	var options = get_random_options()
	return Character.create(options.species, options.background, options.motivation, options.character_class)

func get_background_data(background: String) -> Dictionary:
	var background_data = {}
	match background:
		"Peaceful, High-Tech Colony":
			background_data = {"savvy": 1, "items": ["Tech Gadget"], "rumors": ["Advanced Technology"], "story_points": 1}
		"Giant, Overcrowded, Dystopian City":
			background_data = {"speed": 1, "items": ["Urban Survival Kit"], "rumors": ["Underground Movement"], "story_points": 1}
		"Low-Tech Colony":
			background_data = {"items": ["Basic Tools"], "rumors": ["Old World Secrets"], "story_points": 1}
		"Mining Colony":
			background_data = {"toughness": 1, "items": ["Mining Equipment"], "rumors": ["Hidden Resources"], "story_points": 1}
		"Military Brat":
			background_data = {"combat_skill": 1, "items": ["Military Gear"], "rumors": ["Military Secrets"], "story_points": 1}
		"Space Station":
			background_data = {"items": ["Space Gear"], "rumors": ["Station Politics"], "story_points": 1}
		"Military Outpost":
			background_data = {"reactions": 1, "items": ["Outpost Supplies"], "rumors": ["Outpost Incidents"], "story_points": 1}
		"Drifter":
			background_data = {"items": ["Travel Gear"], "rumors": ["Wandering Tales"], "story_points": 1}
		"Lower Megacity Class":
			background_data = {"items": ["Street Gear"], "rumors": ["City Gossip"], "story_points": 1}
		"Wealthy Merchant Family":
			background_data = {"items": ["Trade Goods"], "rumors": ["Market Trends"], "story_points": 1}
		"Frontier Gang":
			background_data = {"toughness": 1, "items": ["Gang Gear"], "rumors": ["Gang Wars"], "story_points": 1}
		"Religious Cult":
			background_data = {"items": ["Cult Relics"], "rumors": ["Cult Prophecies"], "story_points": 1}
		"War-Torn Hell-Hole":
			background_data = {"reactions": 1, "items": ["War Gear"], "rumors": ["War Stories"], "story_points": 1}
		_:
			background_data = {"items": ["Unknown"], "rumors": ["Unknown"], "story_points": 0}
	return background_data

func get_class_data(character_class: String) -> Dictionary:
	var class_data = {}
	match character_class:
		"Warrior":
			class_data = {"combat_skill": 1, "toughness": 1, "items": ["Weapon"], "rumors": ["Battle Tactics"], "story_points": 1}
		"Engineer":
			class_data = {"savvy": 1, "speed": 1, "items": ["Engineering Tools"], "rumors": ["Tech Innovations"], "story_points": 1}
		"Explorer":
			class_data = {"speed": 1, "reactions": 1, "items": ["Exploration Gear"], "rumors": ["Uncharted Territories"], "story_points": 1}
		"Medic":
			class_data = {"toughness": 1, "savvy": 1, "items": ["Medical Supplies"], "rumors": ["Medical Breakthroughs"], "story_points": 1}
		_:
			class_data = {"items": ["Unknown"], "rumors": ["Unknown"], "story_points": 0}
	return class_data
