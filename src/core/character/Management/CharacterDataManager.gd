extends Node

const SAVE_DIR = "user://saves/"
const CHARACTER_FILE_EXTENSION = ".char.json"
const CREW_FILE_EXTENSION = ".crew.json"
const PORTRAIT_DIR = "user://portraits/"

var game_state_manager: GameStateManager

func _init(_game_state_manager: GameStateManager):
	game_state_manager = _game_state_manager
	_ensure_directories_exist()

func _ensure_directories_exist() -> void:
	var dirs = [SAVE_DIR, PORTRAIT_DIR]
	for dir in dirs:
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)

func save_character(character: Character, file_name: String) -> void:
	# Save portrait if it exists
	if character.portrait_path.length() > 0:
		var portrait_file_name = file_name + "_portrait.png"
		var portrait_path = PORTRAIT_DIR + portrait_file_name
		
		# Copy portrait to portraits directory
		if FileAccess.file_exists(character.portrait_path):
			var image = Image.new()
			var err = image.load(character.portrait_path)
			if err == OK:
				err = image.save_png(portrait_path)
				if err == OK:
					character.portrait_path = portrait_path
	
	# Save character data
	var file = FileAccess.open(SAVE_DIR + file_name + CHARACTER_FILE_EXTENSION, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(character.serialize()))
		file.close()
	else:
		push_error("Failed to open file for writing: " + SAVE_DIR + file_name + CHARACTER_FILE_EXTENSION)

func load_character(file_name: String) -> Character:
	var file = FileAccess.open(SAVE_DIR + file_name + CHARACTER_FILE_EXTENSION, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		file.close()
		if error == OK:
			var character = Character.new()
			character.deserialize(json.data)
			character.initialize_managers(game_state_manager)
			
			# Load portrait if it exists
			if character.portrait_path.length() > 0 and FileAccess.file_exists(character.portrait_path):
				var image = Image.new()
				var err = image.load(character.portrait_path)
				if err != OK:
					push_error("Failed to load portrait: " + character.portrait_path)
					character.portrait_path = ""
			else:
				character.portrait_path = ""
			
			return character
		else:
			push_error("JSON Parse Error: " + json.get_error_message())
	else:
		push_error("Failed to open file for reading: " + SAVE_DIR + file_name + CHARACTER_FILE_EXTENSION)
	return null

func save_crew(crew: Array[Character], file_name: String) -> void:
	# Save each character's portrait
	for character in crew:
		if character.portrait_path.length() > 0:
			var portrait_file_name = file_name + "_" + character.character_name.to_lower().replace(" ", "_") + "_portrait.png"
			var portrait_path = PORTRAIT_DIR + portrait_file_name
			
			# Copy portrait to portraits directory
			if FileAccess.file_exists(character.portrait_path):
				var image = Image.new()
				var err = image.load(character.portrait_path)
				if err == OK:
					err = image.save_png(portrait_path)
					if err == OK:
						character.portrait_path = portrait_path
	
	# Save crew data
	var crew_data = crew.map(func(character: Character): return character.serialize())
	var file = FileAccess.open(SAVE_DIR + file_name + CREW_FILE_EXTENSION, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(crew_data))
		file.close()
	else:
		push_error("Failed to open file for writing: " + SAVE_DIR + file_name + CREW_FILE_EXTENSION)

func load_crew(file_name: String) -> Array[Character]:
	var file = FileAccess.open(SAVE_DIR + file_name + CREW_FILE_EXTENSION, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		file.close()
		if error == OK:
			var characters: Array[Character] = []
			for char_data in json.data:
				var character = Character.new()
				character.deserialize(char_data)
				character.initialize_managers(game_state_manager)
				
				# Load portrait if it exists
				if character.portrait_path.length() > 0 and FileAccess.file_exists(character.portrait_path):
					var image = Image.new()
					var err = image.load(character.portrait_path)
					if err != OK:
						push_error("Failed to load portrait: " + character.portrait_path)
						character.portrait_path = ""
				else:
					character.portrait_path = ""
				
				characters.append(character)
			return characters
		else:
			push_error("JSON Parse Error: " + json.get_error_message())
	else:
		push_error("Failed to open file for reading: " + SAVE_DIR + file_name + CREW_FILE_EXTENSION)
	return []

func get_all_saved_characters() -> Array[String]:
	var dir = DirAccess.open(SAVE_DIR)
	var characters: Array[String] = []
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(CHARACTER_FILE_EXTENSION):
				characters.append(file_name.trim_suffix(CHARACTER_FILE_EXTENSION))
			file_name = dir.get_next()
	else:
		push_error("An error occurred when trying to access the save directory.")
	return characters

func get_all_saved_crews() -> Array[String]:
	var dir = DirAccess.open(SAVE_DIR)
	var crews: Array[String] = []
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(CREW_FILE_EXTENSION):
				crews.append(file_name.trim_suffix(CREW_FILE_EXTENSION))
			file_name = dir.get_next()
	else:
		push_error("An error occurred when trying to access the save directory.")
	return crews
