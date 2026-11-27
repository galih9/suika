@tool
extends EditorExportPlugin

const EXPORT_PRESETS_PATH := "res://export_presets.cfg"
const PLUGIN_DIR_PREFIX := "res://addons/auto_version/"


func _get_name() -> String:
	return "AutoVersion"


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if path.begins_with(PLUGIN_DIR_PREFIX):
		skip()


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var prev_version := AppVersion.get_version_string()
	var next_version := AppVersion.bump_patch(prev_version)
	ProjectSettings.set_setting(AppVersion.SETTING_VERSION, next_version)
	var save_err := ProjectSettings.save()
	if save_err != OK:
		push_warning("[AutoVersion] Failed to save project.godot (error %d)" % save_err)

	var preset := get_export_preset()
	var preset_name := preset.get_preset_name() if preset != null else ""
	var next_code := -1
	var current_code_var: Variant = preset.get("version/code") if preset != null else null
	if current_code_var is int:
		next_code = int(current_code_var) + 1
		preset.set("version/code", next_code)
		var current_name_var: Variant = preset.get("version/name")
		if current_name_var is String and not String(current_name_var).strip_edges().is_empty():
			preset.set("version/name", next_version)

		if FileAccess.file_exists(EXPORT_PRESETS_PATH):
			var cfg := ConfigFile.new()
			var load_err := cfg.load(EXPORT_PRESETS_PATH)
			if load_err == OK:
				var updated_code := bump_config_file_version_code(cfg, preset_name, next_version, next_code)
				if updated_code > 0:
					var cfg_err := cfg.save(EXPORT_PRESETS_PATH)
					if cfg_err != OK:
						push_warning("[AutoVersion] Failed to save export_presets.cfg (error %d)" % cfg_err)
			else:
				push_warning("[AutoVersion] Failed to load export_presets.cfg (error %d)" % load_err)

	if next_code > 0:
		print("[AutoVersion] Bumped version: %s -> %s (code -> %d)" % [prev_version, next_version, next_code])
	else:
		print("[AutoVersion] Bumped version: %s -> %s" % [prev_version, next_version])


static func bump_config_file_version_code(
	cfg: ConfigFile,
	preset_name: String,
	next_version: String,
	explicit_next_code: int = -1
) -> int:
	for section in cfg.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		if not preset_name.is_empty() and str(cfg.get_value(section, "name", "")) != preset_name:
			continue
		var options_section := section + ".options"
		if not cfg.has_section_key(options_section, "version/code"):
			continue
		var current_code_var: Variant = cfg.get_value(options_section, "version/code", 0)
		if not (current_code_var is int):
			continue
		var next_code: int = explicit_next_code if explicit_next_code > 0 else int(current_code_var) + 1
		cfg.set_value(options_section, "version/code", next_code)
		if cfg.has_section_key(options_section, "version/name"):
			var existing_name := str(cfg.get_value(options_section, "version/name", "")).strip_edges()
			if not existing_name.is_empty():
				cfg.set_value(options_section, "version/name", next_version)
		return next_code
	return -1
