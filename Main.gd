extends Node2D

const _HACK_INPUT_PCK_NAME = "test-0.0.0.pck"
const _HACK_OUTPUT_PCK_NAME = "test-0.0.0-DELTA.pck"

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
		var diff_url = _fetching['diff_url']
		if !diff_url:
			printerr("failed to determine diff URL to save patch")
			return
		var su = diff_url.split("/")
		var diff_file_path = su[su.size() - 1]
		if !diff_file_path:
			printerr("failed to determine file name to save patch")
			return
		var file = File.new()
		file.open(diff_file_path, File.WRITE)
		file.store_buffer(body)
		file.close()
		
		var patch_status = get_node_or_null("CenterContainer/VBoxContainer/Patch Status")
		if patch_status:
			var diff_b2bsum = _fetching['diff_b2bsum']
			if !diff_b2bsum:
				printerr("Unknown checksum for diff, aborting")
				return
			if !patch_status.verify_checksum(diff_file_path, diff_b2bsum):
				printerr("diff failed checksum verification")
				return
			
			if !patch_status.apply_diff(_HACK_INPUT_PCK_NAME, diff_file_path, _HACK_OUTPUT_PCK_NAME):
				printerr("Could not apply patch")
				return
			
			# note this isn't sandbox-safe file naming for godot ...
			#   ... as the file is opened by rust !!   ... watch out
			var expected_pck_b2bsum = _fetching['expected_pck_b2bsum']
			if !expected_pck_b2bsum:
				printerr("Cannot find checksum for output PCK, aborting")
				return
			
			var pck_chksum_ok = patch_status.verify_checksum(_HACK_OUTPUT_PCK_NAME, expected_pck_b2bsum)
			if pck_chksum_ok:
				print("validated checksum of output PCK")			
				print("LOADING BRAVE NEW PACK")
				
				### TODO!  We shouldn't load until we're done with everything
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
