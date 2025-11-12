@tool
extends EditorScript

func _run():
	var converter = preload("res://src/tools/JSONToResourceConverter.gd").new()
	converter._run()