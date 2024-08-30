class_name BattlefieldGenerator
extends Node

var game_state: GameState

func _init(_game_state: GameState):
	game_state = _game_state

func generate_battlefield(mission_type: String) -> Dictionary:
	var battlefield = {
		"deployment_condition": generate_deployment_condition(mission_type),
		"notable_sight": generate_notable_sight(mission_type),
		"terrain": generate_terrain()
	}
	return battlefield

func generate_deployment_condition(mission_type: String) -> Dictionary:
	var roll = randi() % 100 + 1
	var condition = {}
	match mission_type:
		"Opportunity", "Patron":
			if roll <= 40:
				condition = {"name": "No Condition", "effect": "Standard deployment"}
			elif roll <= 45:
				condition = {"name": "Small encounter", "effect": "A random crew member must sit out this fight. Reduce enemy numbers by -1 (-2 if they initially outnumber you)"}
			elif roll <= 50:
				condition = {"name": "Poor visibility", "effect": "Maximum visibility is 1D6+8\". Reroll at the start of each round."}
			elif roll <= 55:
				condition = {"name": "Brief engagement", "effect": "At the end of each round, roll 2D6. If the roll is equal or below the round number, the game ends inconclusively."}
			elif roll <= 60:
				condition = {"name": "Toxic environment", "effect": "Whenever a combatant is Stunned, roll 1D6+Savvy skill (0 for enemies). Failure to roll a 4+ becomes a casualty."}
			elif roll <= 65:
				condition = {"name": "Surprise encounter", "effect": "The enemy can't act in the first round."}
			elif roll <= 75:
				condition = {"name": "Delayed", "effect": "2 random crew members won't start on the table. At the end of each round, roll 1D6: If the roll is equal or below the round number, they may be placed at any point of your own battlefield edge."}
			elif roll <= 80:
				condition = {"name": "Slippery ground", "effect": "All movement at ground level is -1 Speed."}
			elif roll <= 85:
				condition = {"name": "Bitter struggle", "effect": "Enemy Morale is +1."}
			elif roll <= 90:
				condition = {"name": "Caught off guard", "effect": "Your squad all act in the Slow Actions phase in Round 1."}
			else:
				condition = {"name": "Gloomy", "effect": "Maximum visibility is 9\". Characters that fire can be fired upon at any range, however."}
		"Rival":
			if roll <= 10:
				condition = {"name": "No Condition", "effect": "Standard deployment"}
			elif roll <= 15:
				condition = {"name": "Small encounter", "effect": "A random crew member must sit out this fight. Reduce enemy numbers by -1 (-2 if they initially outnumber you)"}
			elif roll <= 20:
				condition = {"name": "Poor visibility", "effect": "Maximum visibility is 1D6+8\". Reroll at the start of each round."}
			elif roll <= 25:
				condition = {"name": "Brief engagement", "effect": "At the end of each round, roll 2D6. If the roll is equal or below the round number, the game ends inconclusively."}
			elif roll <= 30:
				condition = {"name": "Toxic environment", "effect": "Whenever a combatant is Stunned, roll 1D6+Savvy skill (0 for enemies). Failure to roll a 4+ becomes a casualty."}
			elif roll <= 45:
				condition = {"name": "Surprise encounter", "effect": "The enemy can't act in the first round."}
			elif roll <= 50:
				condition = {"name": "Delayed", "effect": "2 random crew members won't start on the table. At the end of each round, roll 1D6: If the roll is equal or below the round number, they may be placed at any point of your own battlefield edge."}
			elif roll <= 60:
				condition = {"name": "Slippery ground", "effect": "All movement at ground level is -1 Speed."}
			elif roll <= 75:
				condition = {"name": "Bitter struggle", "effect": "Enemy Morale is +1."}
			elif roll <= 90:
				condition = {"name": "Caught off guard", "effect": "Your squad all act in the Slow Actions phase in Round 1."}
			else:
				condition = {"name": "Gloomy", "effect": "Maximum visibility is 9\". Characters that fire can be fired upon at any range, however."}
		"Quest":
			if roll <= 5:
				condition = {"name": "No Condition", "effect": "Standard deployment"}
			elif roll <= 10:
				condition = {"name": "Small encounter", "effect": "A random crew member must sit out this fight. Reduce enemy numbers by -1 (-2 if they initially outnumber you)"}
			elif roll <= 25:
				condition = {"name": "Poor visibility", "effect": "Maximum visibility is 1D6+8\". Reroll at the start of each round."}
			elif roll <= 30:
				condition = {"name": "Brief engagement", "effect": "At the end of each round, roll 2D6. If the roll is equal or below the round number, the game ends inconclusively."}
			elif roll <= 40:
				condition = {"name": "Toxic environment", "effect": "Whenever a combatant is Stunned, roll 1D6+Savvy skill (0 for enemies). Failure to roll a 4+ becomes a casualty."}
			elif roll <= 50:
				condition = {"name": "Surprise encounter", "effect": "The enemy can't act in the first round."}
			elif roll <= 60:
				condition = {"name": "Delayed", "effect": "2 random crew members won't start on the table. At the end of each round, roll 1D6: If the roll is equal or below the round number, they may be placed at any point of your own battlefield edge."}
			elif roll <= 65:
				condition = {"name": "Slippery ground", "effect": "All movement at ground level is -1 Speed."}
			elif roll <= 80:
				condition = {"name": "Bitter struggle", "effect": "Enemy Morale is +1."}
			elif roll <= 90:
				condition = {"name": "Caught off guard", "effect": "Your squad all act in the Slow Actions phase in Round 1."}
			else:
				condition = {"name": "Gloomy", "effect": "Maximum visibility is 9\". Characters that fire can be fired upon at any range, however."}
	return condition

func generate_notable_sight(mission_type: String) -> Dictionary:
	var roll = randi() % 100 + 1
	var sight = {}
	match mission_type:
		"Opportunity", "Patron":
			if roll <= 20:
				sight = {"name": "Nothing special", "effect": "No effect"}
			elif roll <= 30:
				sight = {"name": "Documentation", "effect": "Gain a Quest Rumor"}
			elif roll <= 40:
				sight = {"name": "Priority target", "effect": "Select a random enemy figure. Add +1 to their Toughness. If they are slain, gain 1D3 credits."}
			elif roll <= 50:
				sight = {"name": "Loot cache", "effect": "Roll once on the Loot Table"}
			elif roll <= 60:
				sight = {"name": "Shiny bits", "effect": "Gain 1 credit"}
			elif roll <= 70:
				sight = {"name": "Really shiny bits", "effect": "Gain 2 credits"}
			elif roll <= 80:
				sight = {"name": "Person of interest", "effect": "Gain +1 story point"}
			elif roll <= 90:
				sight = {"name": "Peculiar item", "effect": "Gain +2 XP"}
			else:
				sight = {"name": "Curious item", "effect": "Roll 1D6. On a 1-4, it can be sold for 1 credit. On a 5-6, roll on the Loot Table"}
		"Rival":
			if roll <= 40:
				sight = {"name": "Nothing special", "effect": "No effect"}
			elif roll <= 50:
				sight = {"name": "Documentation", "effect": "Gain a Quest Rumor"}
			elif roll <= 60:
				sight = {"name": "Priority target", "effect": "Select a random enemy figure. Add +1 to their Toughness. If they are slain, gain 1D3 credits."}
			elif roll <= 70:
				sight = {"name": "Loot cache", "effect": "Roll once on the Loot Table"}
			elif roll <= 75:
				sight = {"name": "Shiny bits", "effect": "Gain 1 credit"}
			elif roll <= 80:
				sight = {"name": "Really shiny bits", "effect": "Gain 2 credits"}
			elif roll <= 90:
				sight = {"name": "Person of interest", "effect": "Gain +1 story point"}
			elif roll <= 95:
				sight = {"name": "Peculiar item", "effect": "Gain +2 XP"}
			else:
				sight = {"name": "Curious item", "effect": "Roll 1D6. On a 1-4, it can be sold for 1 credit. On a 5-6, roll on the Loot Table"}
		"Quest":
			if roll <= 10:
				sight = {"name": "Nothing special", "effect": "No effect"}
			elif roll <= 25:
				sight = {"name": "Documentation", "effect": "Gain a Quest Rumor"}
			elif roll <= 35:
				sight = {"name": "Priority target", "effect": "Select a random enemy figure. Add +1 to their Toughness. If they are slain, gain 1D3 credits."}
			elif roll <= 50:
				sight = {"name": "Loot cache", "effect": "Roll once on the Loot Table"}
			elif roll <= 55:
				sight = {"name": "Shiny bits", "effect": "Gain 1 credit"}
			elif roll <= 65:
				sight = {"name": "Really shiny bits", "effect": "Gain 2 credits"}
			elif roll <= 80:
				sight = {"name": "Person of interest", "effect": "Gain +1 story point"}
			elif roll <= 90:
				sight = {"name": "Peculiar item", "effect": "Gain +2 XP"}
			else:
				sight = {"name": "Curious item", "effect": "Roll 1D6. On a 1-4, it can be sold for 1 credit. On a 5-6, roll on the Loot Table"}
	return sight

func generate_terrain() -> Array:
	var terrain = []
	# Generate 2-3 large terrain features
	for i in range(randi() % 2 + 2):
		terrain.append(generate_large_terrain())
	# Generate 4-6 small terrain features
	for i in range(randi() % 3 + 4):
		terrain.append(generate_small_terrain())
	# Generate 2-4 linear terrain features
	for i in range(randi() % 3 + 2):
		terrain.append(generate_linear_terrain())
	return terrain

func generate_large_terrain() -> Dictionary:
	var types = ["Hill", "Large Building", "Forested Area", "Comms Dish", "Crashed Spaceship"]
	return {"type": "Large", "name": types[randi() % types.size()]}

func generate_small_terrain() -> Dictionary:
	var types = ["Boulder", "Small Building", "Shipping Container", "Vehicle Wreck", "Scattered Bushes"]
	return {"type": "Small", "name": types[randi() % types.size()]}

func generate_linear_terrain() -> Dictionary:
	var types = ["Wall", "Fence", "Barricade", "Trench", "Pipeline"]
	return {"type": "Linear", "name": types[randi() % types.size()]}
