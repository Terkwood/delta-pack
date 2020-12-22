extends Node2D

func _on_Timer_timeout():
	ProjectSettings.load_resource_pack("res://test-0.0.0-PATCHED.pck")
	get_tree().change_scene("res://Main.tscn")

func _ready():
	var patch_status = get_node_or_null("CenterContainer/VBoxContainer/Patch Status")
	if patch_status:
		patch_status.test_patch()
	
	var http_request = get_node_or_null("HTTPRequest")
	if http_request:
		http_request.request("https://jsonplaceholder.typicode.com/todos/1")

func _on_HTTPRequest_request_completed(result, response_code, headers, body):
	var json = JSON.parse(body.get_string_from_utf8())
	print("HTTP result: %s" % json.result)
