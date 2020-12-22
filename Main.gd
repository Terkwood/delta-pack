extends Node2D

onready var _patch_status = $"CenterContainer/VBoxContainer/Patch Status"

func _on_Timer_timeout():
	ProjectSettings.load_resource_pack("res://test-0.0.0-PATCHED.pck")
	get_tree().change_scene("res://Main.tscn")

func _ready():
	_patch_status.test_patch()
