@tool
class_name AppVersion
extends RefCounted

## Semantic version helper shared by the editor export plugin and runtime UI.

const DEFAULT_VERSION := "1.0.0"
const SETTING_VERSION := "application/config/version"


static func parse_semver(version: String) -> Dictionary:
	var cleaned := version.strip_edges()
	if cleaned.begins_with("v") or cleaned.begins_with("V"):
		cleaned = cleaned.substr(1).strip_edges()

	if cleaned.is_empty():
		return {"major": 1, "minor": 0, "patch": 0, "valid": false}

	var core := cleaned
	var dash_idx := core.find("-")
	var plus_idx := core.find("+")
	var cut_idx := -1
	if dash_idx >= 0 and plus_idx >= 0:
		cut_idx = mini(dash_idx, plus_idx)
	elif dash_idx >= 0:
		cut_idx = dash_idx
	elif plus_idx >= 0:
		cut_idx = plus_idx
	if cut_idx >= 0:
		core = core.substr(0, cut_idx)

	if core.is_empty():
		return {"major": 1, "minor": 0, "patch": 0, "valid": false}

	var parts := core.split(".")
	if parts.is_empty() or parts.size() > 3:
		return {"major": 1, "minor": 0, "patch": 0, "valid": false}

	var nums: Array[int] = [0, 0, 0]
	for i in range(parts.size()):
		var part := parts[i]
		if not _is_non_negative_digits(part):
			return {"major": 1, "minor": 0, "patch": 0, "valid": false}
		nums[i] = int(part)

	return {"major": nums[0], "minor": nums[1], "patch": nums[2], "valid": true}


static func _is_non_negative_digits(text: String) -> bool:
	if text.is_empty():
		return false
	for i in range(text.length()):
		var code := text.unicode_at(i)
		if code < 48 or code > 57:
			return false
	return true


static func format_semver(major: int, minor: int, patch: int) -> String:
	return "%d.%d.%d" % [maxi(major, 0), maxi(minor, 0), maxi(patch, 0)]


static func bump_patch(version: String) -> String:
	var parsed := parse_semver(version)
	return format_semver(int(parsed.major), int(parsed.minor), int(parsed.patch) + 1)


static func get_version_string() -> String:
	var raw := str(ProjectSettings.get_setting(SETTING_VERSION, DEFAULT_VERSION)).strip_edges()
	if raw.begins_with("v") or raw.begins_with("V"):
		raw = raw.substr(1).strip_edges()
	if raw.is_empty():
		return DEFAULT_VERSION
	return raw


static func get_display_version() -> String:
	return "v" + get_version_string()
