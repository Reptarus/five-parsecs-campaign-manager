class_name StarshipTravelEvents
extends Resource

var game_state: GameState

func set_game_state(_game_state: GameState) -> void:
	game_state = _game_state

func generate_travel_event() -> Dictionary:
	var roll: int = randi() % 100 + 1
	match roll:
		1, 2, 3, 4, 5, 6, 7: return asteroids_event()
		8, 9, 10, 11, 12: return navigation_trouble_event()
		13, 14, 15, 16, 17: return raided_event()
		18, 19, 20, 21, 22, 23, 24, 25: return deep_space_wreckage_event()
		26, 27, 28, 29: return drive_trouble_event()
		30, 31, 32, 33, 34, 35, 36, 37, 38: return down_time_event()
		39, 40, 41, 42, 43, 44: return distress_call_event()
		45, 46, 47, 48, 49, 50: return patrol_ship_event()
		51, 52, 53: return cosmic_phenomenon_event()
		54, 55, 56, 57, 58, 59, 60: return escape_pod_event()
		61, 62, 63, 64, 65, 66: return accident_event()
		67, 68, 69, 70, 71, 72, 73, 74, 75: return travel_time_event()
		76, 77, 78, 79, 80, 81, 82, 83, 84, 85: return uneventful_trip_event()
		86, 87, 88, 89, 90, 91: return time_to_reflect_event()
		92, 93, 94, 95: return time_to_read_a_book_event()
		96, 97, 98, 99, 100: return locked_in_the_library_data_by_night_event()
	return {} # This should never happen

func asteroids_event() -> Dictionary:
	var event := {
		"name": "Asteroids",
		"description": "Rocky debris everywhere, maybe from a recent collision?",
		"action": func() -> String:
			if game_state.current_crew.ship.has_upgrade("Probe Launcher"):
				var roll := randi() % 6 + 1
				if roll >= 3:
					return "Successfully avoided the asteroid field."
				else:
					return asteroid_damage()
			else:
				var success_count := 0
				for i in range(3):
					var roll := randi() % 6 + 1 + game_state.current_crew.get_best_savvy()
					if roll >= 4:
						success_count += 1
				if success_count == 3:
					return "Successfully navigated through the asteroid field."
				else:
					return asteroid_damage()
	}
	return event

func asteroid_damage() -> String:
	var damage := randi() % 6 + 1
	game_state.current_crew.ship.take_damage(damage, game_state)
	return "Ship took " + str(damage) + " Hull Point damage from asteroids."

func navigation_trouble_event() -> Dictionary:
	return {
		"name": "Navigation Trouble",
		"description": "Is this place even on the star maps?",
		"action": func() -> String:
			game_state.remove_story_point(1)
			if game_state.current_crew.ship.is_damaged():
				var injured_crew := game_state.current_crew.get_random_member()
				injured_crew.roll_injury()
				return "Lost 1 story point and " + injured_crew.name + " was injured due to system failures."
			return "Lost 1 story point due to navigation troubles."
	}

func raided_event() -> Dictionary:
	return {
		"name": "Raided",
		"description": "Your vessel catches the eye of some pirates.",
		"action": func() -> String:
			var roll := randi() % 6 + 1 + game_state.current_crew.get_best_savvy()
			if roll >= 6:
				return "Successfully intimidated the pirates and avoided conflict."
			else:
				game_state.start_battle("Pirates", 3)
				return "Engaged in battle with pirates."
	}

func deep_space_wreckage_event() -> Dictionary:
	return {
		"name": "Deep Space Wreckage",
		"description": "You find an old wreck drifting through empty space.",
		"action": func() -> String:
			var gear1 := game_state.loot_generator.generate_gear()
			var gear2 := game_state.loot_generator.generate_gear()
			gear1.is_damaged = true
			gear2.is_damaged = true
			game_state.add_to_inventory(gear1)
			game_state.add_to_inventory(gear2)
			return "Found two damaged items: " + gear1.name + " and " + gear2.name
	}

func drive_trouble_event() -> Dictionary:
	return {
		"name": "Drive Trouble",
		"description": "It's not supposed to make that sound.",
		"action": func() -> String:
			var success_count := 0
			for i in range(3):
				var roll := randi() % 6 + 1 + game_state.current_crew.get_best_savvy()
				if roll >= 6:
					success_count += 1
			if success_count == 3:
				return "Successfully fixed the drive trouble."
			else:
				game_state.current_crew.ship.ground_for_turns(3 - success_count)
				return "Ship grounded for " + str(3 - success_count) + " turns due to drive trouble."
	}

func down_time_event() -> Dictionary:
	return {
		"name": "Down-time",
		"description": "It's a long time to just sit here.",
		"action": func() -> String:
			var crew_member := game_state.current_crew.get_random_member()
			crew_member.add_xp(1)
			var repaired_item := game_state.current_crew.repair_random_item()
			return crew_member.name + " gained 1 XP. " + (repaired_item.name + " was repaired." if repaired_item else "No items were repaired.")
	}

func distress_call_event() -> Dictionary:
	return {
		"name": "Distress Call",
		"description": "\"This is Licensed Trader Cyberwolf\".",
		"action": func() -> String:
			var roll := randi() % 6 + 1
			match roll:
				1:
					var damage := randi() % 6 + 2
					game_state.current_crew.ship.take_damage(damage, game_state)
					return "Ship struck by debris wave, took " + str(damage) + " Hull Point damage."
				2:
					return "Found only drifting wreckage."
				3, 4:
					var new_crew := game_state.character_generator.generate_character()
					game_state.current_crew.add_member(new_crew)
					return "Rescued a crew member: " + new_crew.name
				5, 6:
					if roll + game_state.current_crew.get_best_savvy() >= 7:
						var loot := game_state.loot_generator.generate_loot()
						game_state.add_to_inventory(loot)
						return "Successfully saved the ship. Received " + loot.name + " as reward."
					else:
						var damage := randi() % 6 + 2
						game_state.current_crew.ship.take_damage(damage, game_state)
						return "Failed to save the ship. Took " + str(damage) + " Hull Point damage from debris."
	}

func patrol_ship_event() -> Dictionary:
	return {
		"name": "Patrol Ship",
		"description": "A Unity patrol vessel hails you.",
		"action": func() -> String:
			var confiscated_items := []
			for i in range(2):
				var roll := randi() % 6 - 3
				if roll > 0:
					var item := game_state.current_crew.remove_random_item()
					if item:
						confiscated_items.append(item)
			game_state.set_next_world_safe()
			return str(confiscated_items.size()) + " items confiscated. Next world cannot be Invaded."
	}

func cosmic_phenomenon_event() -> Dictionary:
	return {
		"name": "Cosmic Phenomenon",
		"description": "A crew member sees a strange manifestation in space.",
		"action": func() -> String:
			var crew_member := game_state.current_crew.get_random_member()
			crew_member.add_luck(1)
			var result := crew_member.name + " gained 1 Luck."
			if game_state.current_crew.has_precursor():
				game_state.add_story_point()
				result += " Precursor predicts it's a good omen. Gained 1 story point."
			return result
	}

func escape_pod_event() -> Dictionary:
	return {
		"name": "Escape Pod",
		"description": "You find an escape pod drifting through space.",
		"action": func() -> String:
			var roll := randi() % 6 + 1
			match roll:
				1:
					var new_rival := game_state.rival_generator.generate_rival()
					game_state.add_rival(new_rival.name)
					return "Rescued a wanted criminal. Gained a new Rival: " + new_rival.name
				2, 3:
					var credits := randi() % 3 + 1
					var loot := game_state.loot_generator.generate_loot()
					game_state.add_credits(credits)
					game_state.add_to_inventory(loot)
					return "Rescued survivor. Gained " + str(credits) + " credits and " + loot.name
				4:
					game_state.add_quest_rumor()
					game_state.add_story_point()
					return "Rescued survivor with interesting information. Gained 1 Quest Rumor and 1 story point."
				5, 6:
					var new_crew := game_state.character_generator.generate_character()
					if roll == 6:
						new_crew.add_xp(10)
					game_state.current_crew.add_member(new_crew)
					return "Rescued " + new_crew.name + " who joined the crew" + (" with 10 XP" if roll == 6 else "") + "."
	}

func accident_event() -> Dictionary:
	return {
		"name": "Accident",
		"description": "A crew member gets injured while doing a routine maintenance task.",
		"action": func() -> String:
			var crew_member := game_state.current_crew.get_random_member()
			crew_member.injure(1)
			var damaged_item := game_state.current_crew.damage_random_item()
			return crew_member.name + " was injured and " + (damaged_item.name if damaged_item else "no item was") + " damaged."
	}

func travel_time_event() -> Dictionary:
	return {
		"name": "Travel-time",
		"description": "Local conditions force you to jump to the very edge of the system and approach under standard drives.",
		"action": func() -> String:
			for member in game_state.current_crew.members:
				if member.is_injured():
					member.heal(1)
			return "All injured crew members rested for one campaign turn."
	}

func uneventful_trip_event() -> Dictionary:
	return {
		"name": "Uneventful Trip",
		"description": "A lot of time playing cards and cleaning guns.",
		"action": func() -> String:
			var repaired_item := game_state.current_crew.repair_random_item()
			return repaired_item.name + " was repaired." if repaired_item else "No items were repaired."
	}

func time_to_reflect_event() -> Dictionary:
	return {
		"name": "Time to Reflect",
		"description": "How is the story unfolding? What did it all mean?",
		"action": func() -> String:
			game_state.add_story_point()
			return "Gained 1 story point."
	}

func time_to_read_a_book_event() -> Dictionary:
	return {
		"name": "Time to Read a Book",
		"description": "There's time to sit, have a read, and maybe even indulge in a bit of education.",
		"action": func() -> String:
			var roll := randi() % 6 + 1
			var xp_gains := []
			match roll:
				1, 2:
					var crew_member := game_state.current_crew.get_random_member()
					crew_member.add_xp(3)
					xp_gains.append(crew_member.name + ": 3 XP")
				3, 4:
					var crew_member1 := game_state.current_crew.get_random_member()
					var crew_member2 := game_state.current_crew.get_random_member()
					while crew_member2 == crew_member1:
						crew_member2 = game_state.current_crew.get_random_member()
					crew_member1.add_xp(2)
					crew_member2.add_xp(1)
					xp_gains.append(crew_member1.name + ": 2 XP")
					xp_gains.append(crew_member2.name + ": 1 XP")
				5, 6:
					var crew_members := game_state.current_crew.get_random_members(3)
					for member in crew_members:
						member.add_xp(1)
						xp_gains.append(member.name + ": 1 XP")
			return "XP gained: " + ", ".join(xp_gains)
	}

func locked_in_the_library_data_by_night_event() -> Dictionary:
	return {
		"name": "Locked in the Library Data by Night",
		"description": "Pouring over old records and fragments of data, the captain has unearthed some intriguing information about the sector of space you are heading into.",
		"action": func() -> String:
			var worlds: Array[Location] = []
			for i in range(3):
				worlds.append(game_state.generate_new_world())
			game_state.set_available_worlds(worlds)
			return "Generated 3 potential worlds to visit. You must choose one of these due to fuel limitations."
	}
