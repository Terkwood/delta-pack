extends Node2D

const _PATCH_NAME = "test-0.0.0_to_test-0.0.0-DELTA.bin"


func _ready():
	var metadata_request = get_node_or_null("MetadataRequest")
	if metadata_request:
		metadata_request.request("https://jsonplaceholder.typicode.com/todos/1")
	
	var delta_bin_request = get_node_or_null("DeltaBinRequest")
	if delta_bin_request:
		delta_bin_request.request("http://127.0.0.1:8080/%s" % _PATCH_NAME)


func _on_MetadataRequest_request_completed(result, response_code, headers, body):
	var json = JSON.parse(body.get_string_from_utf8())
	print("Fake metadata result: %s" % json.result)


func _on_DeltaBinRequest_request_completed(result, response_code, headers, body):
	if response_code == 200:
		var file = File.new() 
		file.open(_PATCH_NAME, File.WRITE)
		file.store_buffer(body)
		file.close()
		
		var patch_status = get_node_or_null("CenterContainer/VBoxContainer/Patch Status")
		if patch_status:
			patch_status.test_patch(_PATCH_NAME)
			
			ProjectSettings.load_resource_pack("res://test-0.0.0-DELTA.pck")
			get_tree().change_scene("res://Main.tscn")
	else:
		printerr("Bad response to delta bin request: %d" % response_code)
		var warning_label = Label.new()
		warning_label.text = "Make sure you start the mock patch server via `sh mock-patch-server/run.sh`"
		warning_label.autowrap = true
		warning_label.anchor_left = 0
		warning_label.anchor_right = 1
		$CenterContainer/VBoxContainer.add_child(warning_label)
		$"CenterContainer/VBoxContainer/Patch Status".hide()
		$CenterContainer/VBoxContainer/TextureRect.hide()
