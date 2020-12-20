extends Node2D

func _on_Timer_timeout():
	ProjectSettings.load_resource_pack("res://test-0.0.0-PATCHED.pck")
	get_tree().change_scene("res://Main.tscn")
