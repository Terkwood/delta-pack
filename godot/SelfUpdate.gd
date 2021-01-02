extends Node2D

const _DOWNLOAD_WORKDIR = "user://delta"
const _DELTA_SERVER = "http://127.0.0.1:45819"
const _MAC_SYSTEM_INSTALL_DIR = "/Applications/Godot.app/Contents/MacOS"
const _USER_FILES_PREFIX = "user://"
const _RELEASE_RESOURCE_PATH = "res://release.tres"

var _deltas = []
var _diffs_to_fetch = []
var _fetching
var _last_intermediate_pck = _primary_pck_path()

onready var _version = load(_RELEASE_RESOURCE_PATH).version

func _ready():
	var working_dir = Directory.new()
	if !working_dir.dir_exists(_DOWNLOAD_WORKDIR):
		working_dir.make_dir_recursive(_DOWNLOAD_WORKDIR)
	
	var version_label = get_node_or_null("CenterContainer/VBoxContainer/Version Label")
	if version_label and _version:
		version_label.text = "Running v%s" % _version
	
	var metadata_request = get_node_or_null("MetadataRequest")
	if metadata_request and _version:
		var req_url = "%s/deltas?from_version=%s" % [ _DELTA_SERVER, _version ]
		metadata_request.request(req_url)
	

func _load_final_pack(pck_file):
	if ProjectSettings.load_resource_pack(pck_file):
		print("Refreshing main scene.")
		var root = get_tree().get_root()
		
		# Sort of a forceful scouring.
		# We could potentially just use change_scene here.
		var main_scene = get_tree().get_current_scene()
		root.remove_child(main_scene)
		main_scene.call_deferred("free")
		
		# We must refresh the version resource so that we know
		# when to stop applying updates.
		ResourceLoader.load(_RELEASE_RESOURCE_PATH, "", true).take_over_path(_RELEASE_RESOURCE_PATH)
		
		var refreshed_main_scene = load("res://SelfUpdate.tscn").instance()
		root.add_child(refreshed_main_scene)
	else:
		printerr("!!! ... Oh No.  Failed To Load Resource Pack ... !!!")

func _fetch_next_diff():
	if _diffs_to_fetch.empty():
		if _fetching:
			var final_pck_name = _intermediate_pck_path(_fetching)
			_fetching = null
			print("All patches applied!")
			var dd = Directory.new()
			var ppp = _primary_pck_path()
			if dd.copy(final_pck_name, ppp) == OK:
				_clean_up_workdir()
				_load_final_pack(ppp)
				return
			else:
				printerr("FINAL COPY FAILED!")
				return
	else:
		if _fetching:
			# We just finished fetching, but hold on to the output PCK path
			# so that we can apply the next diff to it
			_last_intermediate_pck = _user_path_to_os(_intermediate_pck_path(_fetching))
		var delta = _diffs_to_fetch.pop_front()
		_fetching = delta
		var id = delta['id']
		var diff_url = delta['diff_url']
		if id and diff_url:
			var delta_bin_request = get_node_or_null("DeltaBinRequest")
			if delta_bin_request:
				delta_bin_request.request(diff_url)
			print("Fetching %s" % diff_url)
			return
		else:
			printerr("Cannot apply patch: malformed delta response")
			return

func _on_MetadataRequest_request_completed(result, response_code, headers, body):
	if response_code != HTTPClient.RESPONSE_OK:
		printerr("Invalid response from delta server (%s)" % response_code)
		return
	var json = JSON.parse(body.get_string_from_utf8())
	if typeof(json.result) == TYPE_ARRAY:
		print("Fetching %d patches" % json.result.size())
		_deltas = json.result
		_diffs_to_fetch = json.result
		_fetch_next_diff()
		return
	else:
		printerr("Unexpected data from delta server")
		return


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
		var diff_file_path = _workdir_path(diff_file_path_last_part)
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
			
			var output_pck_path = _intermediate_pck_path(_fetching)
			
			var ipp = _last_intermediate_pck
			var dfp = _user_path_to_os(diff_file_path)
			var opp = _user_path_to_os(output_pck_path)
			print("apply diff to:")
			print("\t%s" % ipp)
			print("\t%s" % dfp)
			print("\t%s" % opp)
			if !patch_status.apply_patch(ipp, dfp, opp):
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
				printerr("Checksum FAILED: v%s PCK. [ -- !!! ABORT !!! -- ]" % _fetching['release_version'])
	
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


func _primary_pck_path():
	if OS.has_feature("editor") and _main_pack_env_arg():
		# try to use a path passed as $MAIN_PACK environment variable.
		# this isn't realistic, but it might be useful for testing
		return _main_pack_env_arg()

	var exec_base_dir = OS.get_executable_path().get_base_dir()
	match OS.get_name():
		"OSX":
			if _is_systemwide_install(exec_base_dir):
				# This is only for dev support.  Standard export flow
				# does not fall in to this case
				return _main_pack_env_arg()
			return _mac_pck_path(exec_base_dir)
		"Windows":
			return _win_pck_path(exec_base_dir)
		"X11":
			return _linux_pck_path(exec_base_dir)
		_:
			return ERR_UNAVAILABLE

# For Godot games exported to Mac OSX:
# The PCK is nested inside the folder structure of the application,
# and uses the name of the app as configured in Project Settings.
func _mac_pck_path(exec_base_dir: String):
	var pf = File.new()
	var split_exec_base_dir = exec_base_dir.split("/")
	var main_pack = ""
	for i in range(0, split_exec_base_dir.size() - 1):
		main_pack += "/%s" % split_exec_base_dir[i]
	main_pack += "/Resources/%s.pck" % ProjectSettings.get("application/config/name")
	main_pack = main_pack.substr(1)
	if !pf.file_exists(main_pack):
		return ERR_FILE_NOT_FOUND
	else:
		return main_pack

# For exported Godot games in Windows Desktop:
# PCK is adjacent to the executable, and shares the same, basic name
# as the executable.  e.g.   "test.exe" and "test.pck"
func _win_pck_path(exec_base_dir: String):
	var exec_split = OS.get_executable_path().split("\\")
	var exec_file_only = exec_split[exec_split.size() - 1]
	var exec_no_extension = exec_file_only.split(".")[0]
	if exec_no_extension == null:
		return ERR_FILE_UNRECOGNIZED
	return "%s\\%s.pck" % [ exec_base_dir, exec_no_extension ]

# For exported Godot games in Linux/X11:
# PCK is adjacent to the executable, and shares the same, basic name
# as the executable.  e.g.   "test." and "test.pck"
func _linux_pck_path(exec_base_dir: String):
	var exec_split = OS.get_executable_path().split("/")
	var exec_file_only = exec_split[exec_split.size() - 1]
	var exec_no_extension = exec_file_only.split(".")[0]
	if exec_no_extension == null:
		return ERR_FILE_UNRECOGNIZED
	return "%s/%s.pck" % [ exec_base_dir, exec_no_extension ]


####
#### DEV SUPPORT FUNCTIONS
####
# this is only used to support running from the editor, or
# from manually invoking a godot executable that was not
# distributed as part of the export process
func _main_pack_env_arg():
	return OS.get_environment("MAIN_PACK")

# Caution: This only supports Mac
func _is_systemwide_install(exec_base_dir: String):
	return exec_base_dir == _MAC_SYSTEM_INSTALL_DIR and _main_pack_env_arg()

# path to a an intermediate PCK
func _workdir_path(filename: String):
	return "%s/%s" % [ _DOWNLOAD_WORKDIR, filename ]

func _intermediate_pck_path(delta: Dictionary):
	var release_version = delta['release_version']
	if !release_version:
		printerr("unknown release version: cannot create a new PCK file")
		return
	return _workdir_path("%s.pck" % release_version)
	

func _user_path_to_os(path: String):
	var norm = path.strip_edges().to_lower()
	var parts = norm.split(_USER_FILES_PREFIX)
	if parts.size() != 2:
		printerr("unexpected format for user file path")
		return path
	var rem = parts[1]
	
	return "%s/%s" % [ OS.get_user_data_dir(), rem ]

func _clean_up_workdir():
	var dir = Directory.new()
	if dir.open(_DOWNLOAD_WORKDIR) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir():
				if dir.remove(file_name) != OK:
					printerr("Could not clean up file: %s" % file_name)
			file_name = dir.get_next()
	else:
		printerr("Could not open %s for cleanup" % _DOWNLOAD_WORKDIR)

