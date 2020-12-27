extends Node2D

const _HACK_INPUT_PCK_NAME = "test-0.0.0.pck"
const _RELEASE_VERSIONS_PATH = "user://release_versions"

const _DELTA_SERVER = "http://127.0.0.1:45819"

const _HARDCODED_VERSION = "0.0.0"

var _deltas = []
var _diffs_to_fetch = []
var _fetching

func _ready():
	print("executable path base dir: %s" % OS.get_executable_path().get_base_dir())
	
	var working_dir = Directory.new()
	if !working_dir.dir_exists(_RELEASE_VERSIONS_PATH):
		working_dir.make_dir(_RELEASE_VERSIONS_PATH)
	
	var app_version = _HARDCODED_VERSION
	var version_label = get_node_or_null("CenterContainer/VBoxContainer/Version Label")
	if version_label and app_version:
		version_label.text = "Running v%s" % app_version
	
	var metadata_request = get_node_or_null("MetadataRequest")
	if metadata_request and app_version:
		metadata_request.request("%s/deltas?from_version=%s" % [_DELTA_SERVER, app_version])
	

func _load_final_pack(pck_file):
	print("LOADING BRAVE NEW PACK")
	ProjectSettings.load_resource_pack(pck_file)
	get_tree().change_scene("res://Main.tscn")

func _fetch_next_diff():
	if _diffs_to_fetch.empty():
		var final_pck_name = _versioned_pck_path(_fetching)
		_fetching = null
		print("All patches applied!")
		_load_final_pack(final_pck_name)
		return
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
			print("Fetching %s" % diff_url)
			return
		else:
			printerr("Cannot apply patch: malformed delta response")
			return

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
		var diff_file_path_last_part = su[su.size() - 1]
		if !diff_file_path_last_part:
			printerr("failed to determine file name to save patch")
			return
		var diff_file_path = _working_path(diff_file_path_last_part)
		var file = File.new()
		if file.open(diff_file_path, File.WRITE) != OK:
			printerr("Failed to open diff file for writing")
			return
		file.store_buffer(body)
		file.close()
		
		var patch_status = get_node_or_null("CenterContainer/VBoxContainer/Patch Status")
		if patch_status:
			var diff_b2bsum = _fetching['diff_b2bsum']
			if !diff_b2bsum:
				printerr("Unknown checksum for diff, aborting")
				return
			if !patch_status.verify_checksum(_user_path_to_os(diff_file_path), diff_b2bsum):
				printerr("diff failed checksum verification")
				return
			print("Checksum OK: %s" % diff_file_path_last_part)
			
			var output_pck_path = _versioned_pck_path(_fetching)
			
			if !patch_status.apply_diff(_current_pck_path(), _user_path_to_os(diff_file_path), _user_path_to_os(output_pck_path)):
				printerr("Could not apply patch")
				return
	
			var expected_pck_b2bsum = _fetching['expected_pck_b2bsum']
			if !expected_pck_b2bsum:
				printerr("Cannot find checksum for output PCK, aborting")
				return
			
			var pck_chksum_ok = patch_status.verify_checksum(_user_path_to_os(output_pck_path), expected_pck_b2bsum)
			if pck_chksum_ok:
				print("Checksum OK: v%s PCK" % _fetching['release_version'])
				_fetch_next_diff()
			else:
				printerr("Checksum FAILED: v%s PCK. [ -- !!! ABORT !!! -- ]")
	
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

# Placeholder: we need some way to bootstrap figuring
#   out the initial PCK based on the app name,
#   versus saving version info for subsequent PCK updates
#   somewhere in , e.g.   user://release_versions/current.txt
func _current_pck_path():
	return _HACK_INPUT_PCK_NAME
func _working_path(release_version):
	return "%s/%s" % [ _RELEASE_VERSIONS_PATH, release_version ]
func _versioned_pck_path(delta):
	var release_version = delta['release_version']
	if !release_version:
		printerr("unknown release version: cannot create a new PCK file")
		return
	return _working_path("%s.pck" % release_version)
	

const _USER_PREFIX = "user://"
func _user_path_to_os(path: String):
	var norm = path.strip_edges().to_lower()
	var parts = norm.split(_USER_PREFIX)
	if parts.size() != 2:
		printerr("unexpected format for user file path")
		return path
	var rem = parts[1]
	
	return "%s/%s" % [ OS.get_user_data_dir(), rem ]

