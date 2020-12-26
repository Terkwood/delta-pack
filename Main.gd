extends Node2D

const _DELTA_SERVER = "http://127.0.0.1:45819"

var _deltas = []
var _diffs_to_fetch = []
var _fetching

func _ready():
	var app_version = ProjectSettings.get("application/config/version")
	var version_label = get_node_or_null("CenterContainer/VBoxContainer/Version Label")
	if version_label and app_version:
		version_label.text = "Running v%s" % app_version
	
	var metadata_request = get_node_or_null("MetadataRequest")
	if metadata_request and app_version:
		metadata_request.request("%s/deltas?from_version=%s" % [_DELTA_SERVER, app_version])
	

enum MoreDiffs { YES, NO, ERR }

func _fetch_next_diff():
	if _diffs_to_fetch.empty():
		_fetching = null
		return MoreDiffs.NO
	else:
		var delta = _diffs_to_fetch.pop_front()
		_fetching = delta
		var id = delta['id']
		var diff_url = delta['diff_url']
		if id and diff_url:
			pass
			var delta_bin_request = get_node_or_null("DeltaBinRequest")
			if delta_bin_request:
				delta_bin_request.request(diff_url)
			print("fetching from %s" % diff_url)
			return MoreDiffs.YES
		else:
			printerr("Cannot apply patch: malformed delta response")
			return MoreDiffs.ERR

func _on_MetadataRequest_request_completed(result, response_code, headers, body):
	var json = JSON.parse(body.get_string_from_utf8())
	if typeof(json.result) == TYPE_ARRAY:
		print("Fetching %d patches" % json.result.size())
		_deltas = json.result
		_diffs_to_fetch = json.result
		_fetch_next_diff()
	else:
		printerr("Not an array")


func _on_DeltaBinRequest_request_completed(result, response_code, headers, body):
	if response_code == 200:
		var patch_name = _fetching['diff_url'].split("/").last()
		var file = File.new() 
		file.open(patch_name, File.WRITE)
		file.store_buffer(body)
		file.close()
		
		var patch_status = get_node_or_null("CenterContainer/VBoxContainer/Patch Status")
		if patch_status:
			patch_status.test_patch(patch_name)
			
			# note this isn't sandbox-safe file naming for godot ...
			#   ... as the file is opened by rust !!   ... watch out
			var pck_chksum_ok = patch_status.verify_checksum("test-0.0.0-DELTA.pck", "80417e1017a3be2e153fd5e8fbf342d30861a14ae15488c3cf1a850fac98e3c1f5a2e6c2262ce1bb70c3cd23c9a1a01fa8ba24fab9d24138849e81bdc8eebd49")
			if pck_chksum_ok:
				print("validated checksum of output PCK")			
				print("LOADING BRAVE NEW PACK")
				ProjectSettings.load_resource_pack("res://test-0.0.0-DELTA.pck")
				get_tree().change_scene("res://Main.tscn")
			else:
				printerr("FAILED CHECKSUM !!! ABORT !!!")
	
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
