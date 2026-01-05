# 模组管理器：管理已安装的 user://mods 下的模组（查看信息 / 删除 / 导入 ZIP）

extends Control

signal mods_changed

const MODS_FOLDER_PATH: String = "user://mods"
const MOD_CONFIG_FILENAME: String = "mod_config.json"
const MOD_ICON_FILENAME: String = "icon.png"

@onready var backdrop: ColorRect = $"Backdrop"
@onready var close_button: Button = $"Window/Margin/Root/Header/CloseButton"
@onready var mod_list: ItemList = $"Window/Margin/Root/Body/LeftColumn/ModList"
@onready var import_zip_button: Button = $"Window/Margin/Root/Body/LeftColumn/LeftButtons/ImportZipButton"
@onready var refresh_button: Button = $"Window/Margin/Root/Body/LeftColumn/LeftButtons/RefreshButton"
@onready var delete_button: Button = $"Window/Margin/Root/Body/LeftColumn/LeftButtons/DeleteButton"
@onready var icon_rect: TextureRect = $"Window/Margin/Root/Body/RightColumn/Icon"
@onready var mod_title_label: Label = $"Window/Margin/Root/Body/RightColumn/ModTitleLabel"
@onready var mod_info_text: RichTextLabel = $"Window/Margin/Root/Body/RightColumn/ModInfoText"
@onready var message_dialog: AcceptDialog = $"MessageDialog"
@onready var confirm_delete_dialog: ConfirmationDialog = $"ConfirmDeleteDialog"
@onready var import_zip_dialog: FileDialog = $"ImportZipDialog"

var _mods: Array[Dictionary] = []
var _selected_index: int = -1
var _pending_delete_folder: String = ""
var _mods_dirty: bool = false


func _ready() -> void:
	mod_list.allow_reselect = true
	mod_list.select_mode = ItemList.SELECT_SINGLE

	backdrop.gui_input.connect(_on_backdrop_gui_input)
	close_button.pressed.connect(_close)
	refresh_button.pressed.connect(_refresh_mods)
	import_zip_button.pressed.connect(_open_import_dialog)
	import_zip_dialog.file_selected.connect(_on_import_zip_selected)
	delete_button.pressed.connect(_on_delete_pressed)
	confirm_delete_dialog.confirmed.connect(_on_confirm_delete)
	mod_list.item_selected.connect(_on_mod_selected)

	_ensure_mods_folder_exists()
	_refresh_mods()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _close() -> void:
	if _mods_dirty:
		mods_changed.emit()
	queue_free()


func _open_import_dialog() -> void:
	import_zip_dialog.popup_centered_ratio(0.8)


func _show_message(title: String, text: String) -> void:
	message_dialog.title = title
	message_dialog.dialog_text = text
	message_dialog.popup_centered()


func _ensure_mods_folder_exists() -> void:
	var user_dir: DirAccess = DirAccess.open("user://")
	if not user_dir:
		push_error("无法打开 user:// 目录")
		return
	if not user_dir.dir_exists("mods"):
		var err: int = user_dir.make_dir("mods")
		if err != OK:
			push_error("无法创建 mods 目录: user://mods")


func _refresh_mods() -> void:
	_mods = _scan_mods()

	mod_list.clear()
	for i in range(_mods.size()):
		var mod_data: Dictionary = _mods[i]
		var display_title: String = _get_mod_display_title(mod_data)
		mod_list.add_item(display_title)
		mod_list.set_item_metadata(i, mod_data.get("folder_name", ""))

	_selected_index = -1
	_clear_details()


func _clear_details() -> void:
	delete_button.disabled = true
	icon_rect.texture = null
	mod_title_label.text = "未选择模组"
	mod_info_text.text = ""


func _on_mod_selected(index: int) -> void:
	_selected_index = index
	_update_details()


func _update_details() -> void:
	if _selected_index < 0 or _selected_index >= _mods.size():
		_clear_details()
		return

	var mod_data: Dictionary = _mods[_selected_index]
	delete_button.disabled = false

	var folder_name: String = str(mod_data.get("folder_name", ""))
	var config_ok: bool = bool(mod_data.get("config_ok", false))
	var config_error: String = str(mod_data.get("config_error", ""))
	var config: Dictionary = mod_data.get("config", {}) as Dictionary
	var icon_texture: Texture2D = mod_data.get("icon_texture", null) as Texture2D

	icon_rect.texture = icon_texture

	if config_ok:
		var title: String = str(config.get("title", folder_name))
		mod_title_label.text = title

		var author: String = str(config.get("author", ""))
		var version: String = str(config.get("version", ""))
		var description: String = str(config.get("description", ""))

		mod_info_text.text = _format_mod_info(folder_name, author, version, description)
	else:
		mod_title_label.text = folder_name
		mod_info_text.text = "该模组的配置文件无效：%s\n\n你可以选择删除该模组。" % config_error


func _format_mod_info(folder_name: String, author: String, version: String, description: String) -> String:
	var lines: Array[String] = []
	lines.append("[b]文件夹：[/b]%s" % folder_name)
	if not author.is_empty():
		lines.append("[b]作者：[/b]%s" % author)
	if not version.is_empty():
		lines.append("[b]版本：[/b]%s" % version)
	if not description.is_empty():
		lines.append("")
		lines.append("[b]描述：[/b]%s" % description)
	return "\n".join(lines)


func _get_mod_display_title(mod_data: Dictionary) -> String:
	var folder_name: String = str(mod_data.get("folder_name", ""))
	var config_ok: bool = bool(mod_data.get("config_ok", false))
	if not config_ok:
		return "%s（配置无效）" % folder_name

	var config: Dictionary = mod_data.get("config", {}) as Dictionary
	var title: String = str(config.get("title", folder_name))
	var version: String = str(config.get("version", ""))
	if not version.is_empty():
		return "%s v%s" % [title, version]
	return title


func _scan_mods() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	var mods_dir: DirAccess = DirAccess.open(MODS_FOLDER_PATH)
	if not mods_dir:
		return result

	mods_dir.list_dir_begin()
	var folder_name: String = mods_dir.get_next()
	while folder_name != "":
		if mods_dir.current_is_dir() and not folder_name.begins_with("."):
			result.append(_load_mod_folder(folder_name))
		folder_name = mods_dir.get_next()
	mods_dir.list_dir_end()

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("folder_name", "")).nocasecmp_to(str(b.get("folder_name", ""))) < 0
	)
	return result


func _load_mod_folder(folder_name: String) -> Dictionary:
	var mod_path: String = MODS_FOLDER_PATH + "/" + folder_name
	var config_path: String = mod_path + "/" + MOD_CONFIG_FILENAME
	var icon_path: String = mod_path + "/" + MOD_ICON_FILENAME

	var config_result: Dictionary = _try_load_mod_config(config_path)
	var icon_texture: Texture2D = _load_mod_icon(icon_path)

	return {
		"folder_name": folder_name,
		"mod_path": mod_path,
		"config_ok": bool(config_result.get("ok", false)),
		"config": config_result.get("data", {}),
		"config_error": str(config_result.get("error", "")),
		"icon_texture": icon_texture,
	}


func _try_load_mod_config(config_path: String) -> Dictionary:
	if not FileAccess.file_exists(config_path):
		return {"ok": false, "data": {}, "error": "缺少 %s" % MOD_CONFIG_FILENAME}

	var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		return {"ok": false, "data": {}, "error": "无法读取配置文件"}

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_err: int = json.parse(json_string)
	if parse_err != OK:
		return {"ok": false, "data": {}, "error": "JSON 解析失败"}

	if typeof(json.data) != TYPE_DICTIONARY:
		return {"ok": false, "data": {}, "error": "配置内容不是对象(JSON Dictionary)"}

	return {"ok": true, "data": json.data as Dictionary, "error": ""}


func _load_mod_icon(icon_path: String) -> Texture2D:
	if not FileAccess.file_exists(icon_path):
		return null
	var image: Image = Image.new()
	var err: int = image.load(icon_path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)


func _on_delete_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _mods.size():
		_show_message("提示", "请先选择一个模组。")
		return

	var mod_data: Dictionary = _mods[_selected_index]
	var folder_name: String = str(mod_data.get("folder_name", ""))
	var display_title: String = _get_mod_display_title(mod_data)

	_pending_delete_folder = folder_name
	confirm_delete_dialog.dialog_text = "确定删除模组「%s」吗？\n\n此操作不可撤销。" % display_title
	confirm_delete_dialog.popup_centered()


func _on_confirm_delete() -> void:
	if _pending_delete_folder.is_empty():
		return

	var folder_name: String = _pending_delete_folder
	_pending_delete_folder = ""

	var err: String = _delete_mod_folder(folder_name)
	if not err.is_empty():
		_show_message("删除失败", err)
		return

	_mods_dirty = true
	_show_message("删除成功", "已删除模组：%s" % folder_name)
	_refresh_mods()


func _delete_mod_folder(folder_name: String) -> String:
	if folder_name.is_empty() or folder_name.find("..") != -1 or folder_name.find("/") != -1 or folder_name.find("\\") != -1:
		return "模组文件夹名不合法。"

	var mod_path: String = MODS_FOLDER_PATH + "/" + folder_name
	if not _dir_exists(mod_path):
		return "模组不存在：%s" % folder_name

	var err: int = _delete_directory_recursive(mod_path)
	if err != OK:
		return "删除失败（错误码 %d）。" % err

	return ""


func _dir_exists(path: String) -> bool:
	var abs_path: String = ProjectSettings.globalize_path(path)
	return DirAccess.open(abs_path) != null


func _delete_directory_recursive(path: String) -> int:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var dir: DirAccess = DirAccess.open(absolute_path)
	if not dir:
		return ERR_CANT_OPEN

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var file_path: String = absolute_path + "/" + file_name
		if dir.current_is_dir():
			var err_sub: int = _delete_directory_recursive(file_path)
			if err_sub != OK:
				dir.list_dir_end()
				return err_sub
		else:
			var err_remove: int = DirAccess.remove_absolute(file_path)
			if err_remove != OK:
				dir.list_dir_end()
				return err_remove
		file_name = dir.get_next()
	dir.list_dir_end()

	return DirAccess.remove_absolute(absolute_path)


func _on_import_zip_selected(zip_path: String) -> void:
	var result: Dictionary = _import_zip(zip_path)
	if bool(result.get("ok", false)):
		_mods_dirty = true
		_show_message("导入成功", str(result.get("message", "导入完成。")))
		_refresh_mods()
	else:
		_show_message("导入失败", str(result.get("message", "未知错误。")))


func _import_zip(zip_path: String) -> Dictionary:
	if not FileAccess.file_exists(zip_path):
		return {"ok": false, "message": "找不到 ZIP 文件。"}

	var zip: ZIPReader = ZIPReader.new()
	var err_open: int = zip.open(zip_path)
	if err_open != OK:
		return {"ok": false, "message": "无法打开 ZIP（错误码 %d）。" % err_open}

	var entries: PackedStringArray = zip.get_files()
	if entries.is_empty():
		return {"ok": false, "message": "ZIP 内没有任何文件。"}

	var config_entry: String = ""
	for entry in entries:
		if entry.ends_with("/") or entry.is_empty():
			continue
		if entry.get_file() == MOD_CONFIG_FILENAME:
			if not config_entry.is_empty():
				return {"ok": false, "message": "ZIP 内存在多个 %s，无法判断模组根目录。" % MOD_CONFIG_FILENAME}
			config_entry = entry

	if config_entry.is_empty():
		return {"ok": false, "message": "ZIP 内缺少 %s。" % MOD_CONFIG_FILENAME}

	# 仅允许：mod_config.json 或 <folder>/mod_config.json
	var config_parts: PackedStringArray = config_entry.split("/", false)
	if config_parts.size() > 2:
		return {"ok": false, "message": "%s 必须位于压缩包根目录或根目录下唯一文件夹中。" % MOD_CONFIG_FILENAME}

	var top_folder: String = ""
	if config_parts.size() == 2:
		top_folder = config_parts[0]

	var raw_folder_name: String = top_folder if not top_folder.is_empty() else zip_path.get_file().get_basename()
	var folder_name: String = _sanitize_folder_name(raw_folder_name)
	if folder_name.is_empty():
		var timestamp: int = int(Time.get_unix_time_from_system())
		folder_name = "mod_%d" % timestamp

	var dest_mod_path: String = MODS_FOLDER_PATH + "/" + folder_name
	if _dir_exists(dest_mod_path):
		return {"ok": false, "message": "已存在同名模组文件夹：%s\n请先删除或更换 ZIP 文件名后重试。" % folder_name}

	# 安全校验：禁止路径穿越
	for entry in entries:
		if not _is_safe_zip_entry(entry):
			return {"ok": false, "message": "ZIP 内包含非法路径，已拒绝导入。"}

	var user_dir: DirAccess = DirAccess.open("user://")
	if not user_dir:
		return {"ok": false, "message": "无法访问 user:// 目录。"}

	var err_mkdir: int = user_dir.make_dir_recursive("mods/" + folder_name)
	if err_mkdir != OK:
		return {"ok": false, "message": "无法创建目标目录（错误码 %d）。" % err_mkdir}

	var extracted_any: bool = false
	var prefix: String = top_folder + "/" if not top_folder.is_empty() else ""

	for entry in entries:
		if entry.is_empty():
			continue
		if not prefix.is_empty() and not entry.begins_with(prefix):
			continue

		var rel: String = entry
		if not prefix.is_empty():
			rel = entry.substr(prefix.length())

		if rel.is_empty():
			continue

		var dest_path: String = dest_mod_path + "/" + rel
		var base_dir: String = dest_path.get_base_dir()
		var rel_dir: String = base_dir.replace("user://", "")
		if not rel_dir.is_empty():
			var err_dir: int = user_dir.make_dir_recursive(rel_dir)
			if err_dir != OK:
				_delete_directory_recursive(dest_mod_path)
				return {"ok": false, "message": "创建目录失败（错误码 %d）。" % err_dir}

		if entry.ends_with("/"):
			continue

		var data: PackedByteArray = zip.read_file(entry)
		var out: FileAccess = FileAccess.open(dest_path, FileAccess.WRITE)
		if not out:
			_delete_directory_recursive(dest_mod_path)
			return {"ok": false, "message": "写入文件失败：%s" % rel}
		out.store_buffer(data)
		out.close()
		extracted_any = true

	if not extracted_any:
		_delete_directory_recursive(dest_mod_path)
		return {"ok": false, "message": "没有可导入的文件。"}

	var dest_config_path: String = dest_mod_path + "/" + MOD_CONFIG_FILENAME
	var cfg_check: Dictionary = _try_load_mod_config(dest_config_path)
	if not bool(cfg_check.get("ok", false)):
		_delete_directory_recursive(dest_mod_path)
		return {"ok": false, "message": "导入后的配置文件无效：%s" % str(cfg_check.get("error", ""))}

	return {"ok": true, "message": "已导入到：%s" % dest_mod_path}


func _is_safe_zip_entry(entry: String) -> bool:
	if entry.begins_with("/") or entry.begins_with("\\"):
		return false
	if entry.find(":") != -1:
		return false
	var parts: PackedStringArray = entry.split("/", false)
	for part in parts:
		if part == "..":
			return false
	return true


func _sanitize_folder_name(raw_name: String) -> String:
	var stripped: String = raw_name.strip_edges()
	if stripped.is_empty():
		return ""

	var out := PackedStringArray()
	for i in range(stripped.length()):
		var ch: String = stripped.substr(i, 1)
		var code: int = ch.unicode_at(0)
		var is_digit: bool = code >= 48 and code <= 57
		var is_upper: bool = code >= 65 and code <= 90
		var is_lower: bool = code >= 97 and code <= 122
		if is_digit or is_upper or is_lower or ch == "_" or ch == "-":
			out.append(ch)
		else:
			out.append("_")

	var joined: String = "".join(out)
	while joined.find("__") != -1:
		joined = joined.replace("__", "_")
	joined = joined.strip_edges()
	joined = joined.trim_prefix("_").trim_suffix("_")

	if joined.length() > 32:
		joined = joined.substr(0, 32)

	return joined
