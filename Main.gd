extends Node2D

const _HACK_INPUT_PCK_NAME = "test-0.0.0.pck"

const _DELTA_PCKS_PATH = "user://delta/pcks"

const _VERSION_CONFIG_PATH = "user://delta/version.cfg"
const _VERSION_CONFIG_SECTION = "release"
const _VERSION_CONFIG_KEY = "version"

# TODO DOC
# TODO DOC
# TODO DOC
# TODO DOC
# TODO DOC
const _PROJECT_SETTINGS_DELTA_INIT_VERSION = "application/config/delta_init_version"


const _DELTA_SERVER = "http://127.0.0.1:45819"

const _HARDCODED_VERSION = "0.0.0"

var _deltas = []
var _diffs_to_fetch = []
var _fetching

var _hack_version = _HARDCODED_VERSION

func _ready():
	pass
	pass
	pass # TODO we must figure out whether there is a more recent version
	pass # TODO     of the game   ... that we should load ... 
	pass
	pass
	
	var working_dir = Directory.new()
	if !working_dir.dir_exists(_DELTA_PCKS_PATH):
		working_dir.make_dir_recursive(_DELTA_PCKS_PATH)
	
	var app_version = _version()
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
				
			_write_version_config(_fetching['release_version'])
	
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

# Placeholder: we need some way to bootstrap figuring
#   out the initial PCK based on the app name,
#   versus saving version info for subsequent PCK updates
#   somewhere in , e.g.   user://release_versions/current.txt
func _current_pck_path():
	pass # What version are we running?
	pass # Are we running the very first version that the user has ever downloaded??!
	pass # If so, what version is THAT?
	pass # ASSUME it's the first version, at the beginning of the release version list:
	pass #    ... then we need to apply all updates against a PCK file in a strange location
	pass #    ... 
	print("executable path base dir: %s" % OS.get_executable_path().get_base_dir())
	pass #    ... for Mac, this will look like ../Resources/{APPNAME}.pck
	pass # Next, ASSUME that this is the first time the user has downloaded the game,
	pass #    ... but that it is NOT the very first version of the game to be released.
	pass #    ... ... THEN we need to populate the user space with the correct version,
	pass #    ... ... which can be found in ProjectSettings
	pass # Finally, ASSUME that the user has previously run the update utility.  Then
	pass #    ... there should be a loadable ConfigFile in the delta userspace
	print("Version config file shall reside here: %s" % _VERSION_CONFIG_PATH)
	return _HACK_INPUT_PCK_NAME
func _working_path(release_version):
	return "%s/%s" % [ _DELTA_PCKS_PATH, release_version ]
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

func _write_version_config(semver: String):
	if not semver:
		printerr("Empty semver")
		return FAILED
	else:
		var cvf = ConfigFile.new()
		cvf.load(_VERSION_CONFIG_PATH)
		cvf.set_value(_VERSION_CONFIG_SECTION, _VERSION_CONFIG_KEY, semver)
		var ret_save = cvf.save(_VERSION_CONFIG_PATH)
		if ret_save == OK:
			return OK
		else:
			printerr("Could not save version config")
			return ret_save

func _version():
	if File.new().file_exists(_VERSION_CONFIG_PATH):
		var cf = ConfigFile.new()
		cf.load(_VERSION_CONFIG_PATH)
		return cf.get_value(_VERSION_CONFIG_SECTION, _VERSION_CONFIG_KEY, "0.0.0")
	else:
		return ProjectSettings.get(_PROJECT_SETTINGS_DELTA_INIT_VERSION)
