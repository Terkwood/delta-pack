extends Node2D

func _ready():
	$"Panel/VBoxContainer/Version Label".text = "Running v%s" % Version.version()
