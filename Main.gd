extends Node2D

func _ready():
	$"Panel/VBoxContainer/Version Label".text = "Running v%s" % Version.version()
	

func _on_Timer_timeout():
	ProjectSettings.load_resource_pack("res://test-0.0.0-a.pck")
	get_tree().change_scene("res://Main.tscn")
