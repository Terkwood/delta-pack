extends Node

func _load_text_file(path):
	var f = File.new()
	var err = f.open(path, File.READ)
	if err != OK:
		printerr("Could not open file, error code ", err)
		return null
	var text = f.get_as_text()
	f.close()
	return text

func version() -> String:
	return _load_text_file("res://version.txt")
