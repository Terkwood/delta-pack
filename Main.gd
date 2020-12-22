extends Node2D

func _on_Timer_timeout():
	ProjectSettings.load_resource_pack("res://test-0.0.0-PATCHED.pck")
	get_tree().change_scene("res://Main.tscn")

func _ready():
	var patch_status = get_node_or_null("CenterContainer/VBoxContainer/Patch Status")
	if patch_status:
		patch_status.test_patch()
