# =============================================================================
# Mod工程管理器 (Project Manager)
# =============================================================================
# 功能概述：
# 1. 显示所有已创建的mod工程
# 2. 新建mod工程
# 3. 打开选中的工程进入编辑器
# 4. 删除选中的工程
# 5. 返回到同人列表界面
# =============================================================================

extends Control

# 节点引用
@onready var project_list: VBoxContainer = $WindowPanel/Margin/Content/Body/LeftPanel/ProjectScrollContainer/ProjectList
@onready var project_scroll: ScrollContainer = get_node_or_null("WindowPanel/Margin/Content/Body/LeftPanel/ProjectScrollContainer") as ScrollContainer
@onready var background: ColorRect = get_node_or_null("Background") as ColorRect
@onready var window_panel: Control = get_node_or_null("WindowPanel") as Control
@onready var detail_scroll: ScrollContainer = get_node_or_null("WindowPanel/Margin/Content/Body/RightPanel/DetailScroll") as ScrollContainer
@onready var new_project_button: Button = $WindowPanel/Margin/Content/Footer/NewProjectButton
@onready var open_project_button: Button = $WindowPanel/Margin/Content/Footer/OpenProjectButton
@onready var delete_project_button: Button = $WindowPanel/Margin/Content/Footer/DeleteProjectButton
@onready var back_button: Button = $WindowPanel/Margin/Content/Header/BackButton
@onready var new_project_dialog: Window = $NewProjectDialog
@onready var project_name_input: LineEdit = $NewProjectDialog/DialogContent/ProjectNameInput
@onready var new_project_error_label: Label = get_node_or_null("NewProjectDialog/DialogContent/ErrorLabel") as Label
@onready var empty_label: Label = get_node_or_null("EmptyLabel") as Label
@onready var search_input: LineEdit = get_node_or_null("WindowPanel/Margin/Content/Header/SearchInput") as LineEdit
@onready var delete_confirm_dialog: ConfirmationDialog = get_node_or_null("DeleteConfirmDialog") as ConfirmationDialog
@onready var preview_file_dialog: FileDialog = get_node_or_null("PreviewFileDialog") as FileDialog
@onready var export_zip_dialog: FileDialog = get_node_or_null("ExportZipDialog") as FileDialog
@onready var install_mods_confirm_dialog: ConfirmationDialog = get_node_or_null("InstallModsConfirmDialog") as ConfirmationDialog

@onready var project_title_input: LineEdit = get_node_or_null("WindowPanel/Margin/Content/Body/RightPanel/DetailScroll/DetailMargin/DetailForm/NameRow/ProjectTitleInput") as LineEdit
@onready var project_preview: TextureRect = get_node_or_null("WindowPanel/Margin/Content/Body/RightPanel/DetailScroll/DetailMargin/DetailForm/NameRow/ProjectPreview") as TextureRect
@onready var project_desc_input: TextEdit = get_node_or_null("WindowPanel/Margin/Content/Body/RightPanel/DetailScroll/DetailMargin/DetailForm/ProjectDescInput") as TextEdit
@onready var episode_list: VBoxContainer = get_node_or_null("WindowPanel/Margin/Content/Body/RightPanel/DetailScroll/DetailMargin/DetailForm/EpisodeList") as VBoxContainer
@onready var add_episode_button: Button = get_node_or_null("WindowPanel/Margin/Content/Body/RightPanel/DetailScroll/DetailMargin/DetailForm/EpisodesHeader/AddEpisodeButton") as Button
@onready var export_zip_button: Button = get_node_or_null("WindowPanel/Margin/Content/Body/RightPanel/DetailScroll/DetailMargin/DetailForm/ProjectActions/ExportZipButton") as Button
@onready var install_to_mods_button: Button = get_node_or_null("WindowPanel/Margin/Content/Body/RightPanel/DetailScroll/DetailMargin/DetailForm/ProjectActions/InstallToModsButton") as Button
@onready var right_panel: Control = get_node_or_null("WindowPanel/Margin/Content/Body/RightPanel") as Control
@onready var _footer_actions: HBoxContainer = get_node_or_null("WindowPanel/Margin/Content/Footer") as HBoxContainer
@onready var _detail_actions: Control = get_node_or_null("WindowPanel/Margin/Content/Body/RightPanel/DetailScroll/DetailMargin/DetailForm/ProjectActions") as Control
@onready var episode_rename_dialog: ConfirmationDialog = get_node_or_null("EpisodeRenameDialog") as ConfirmationDialog
@onready var episode_rename_input: LineEdit = get_node_or_null("EpisodeRenameDialog/EpisodeRenameContent/EpisodeRenameInput") as LineEdit
@onready var episode_rename_error_label: Label = get_node_or_null("EpisodeRenameDialog/EpisodeRenameContent/EpisodeRenameErrorLabel") as Label
@onready var episode_delete_confirm_dialog: ConfirmationDialog = get_node_or_null("EpisodeDeleteConfirmDialog") as ConfirmationDialog

# 常量
const PROJECTS_PATH: String = "user://mod_projects"
const MODS_PATH: String = "user://mods"
const EDITOR_SCENE_PATH: String = "res://scenes/editor/mod_editor.tscn"
const UI_FONT: FontFile = preload("res://assets/gui/font/方正兰亭准黑_GBK.ttf")
const DEFAULT_PREVIEW_IMAGE: String = "res://assets/gui/main_menu/Story00_Main_01.png"
const PROJECT_PREVIEW_FILE: String = "preview/cover.png"
const PROJECT_PREVIEW_SIZE: Vector2i = Vector2i(206, 178)

const ENTER_ANIMATION_DURATION: float = 0.18
const EXIT_ANIMATION_DURATION: float = 0.16
const TRANSITION_ANIMATION_DURATION: float = 0.18
const MAX_PROJECT_FOLDER_NAME_LENGTH: int = 24
const MAX_PROJECT_TITLE_LENGTH: int = 24
const MAX_PROJECT_DESC_LENGTH: int = 120
const MAX_EPISODE_TITLE_LENGTH: int = 24
const MAX_PROJECT_DESC_LINES: int = 3
const EPISODE_DRAG_THRESHOLD: float = 6.0
const EXPORT_ZIP_ENABLED: bool = false  # 暂时禁用：导出ZIP功能仍有问题，避免误用

# 与 mod_editor.gd 的 enum BlockType 保持一致（用于导出/打包）
enum BlockType {
	TEXT_ONLY,
	DIALOG,
	SHOW_CHARACTER_1,
	HIDE_CHARACTER_1,
	SHOW_CHARACTER_2,
	HIDE_CHARACTER_2,
	SHOW_CHARACTER_3,
	HIDE_CHARACTER_3,
	HIDE_ALL_CHARACTERS,
	BACKGROUND,
	MUSIC,
	EXPRESSION,
	SHOW_BACKGROUND,
	CHANGE_MUSIC,
	STOP_MUSIC,
	MOVE_CHARACTER_1_LEFT,
	MOVE_CHARACTER_2_LEFT,
	MOVE_CHARACTER_3_LEFT,
	CHANGE_EXPRESSION_1,
	CHANGE_EXPRESSION_2,
	CHANGE_EXPRESSION_3,
	HIDE_BACKGROUND,
	HIDE_BACKGROUND_FADE,
	CHARACTER_LIGHT_1,
	CHARACTER_LIGHT_2,
	CHARACTER_LIGHT_3,
	CHARACTER_DARK_1,
	CHARACTER_DARK_2,
	CHARACTER_DARK_3,
}

# 变量
var selected_project: String = ""
var project_items: Array = []
var pending_delete_project: String = ""

var _row_style_normal: StyleBoxFlat
var _row_style_selected: StyleBoxFlat

var _is_loading_details: bool = false
var _selected_episode_title: String = ""
var _selected_episode_path: String = ""
var _last_preview_dir: String = ""
var _pending_export_project: String = ""
var _pending_install_project: String = ""
var _is_exiting: bool = false
var _is_transitioning: bool = false
var _is_sanitizing_text: bool = false
var _active_editor: Node = null
var _packaging_error_dialog: AcceptDialog = null
var _packaging_character_scene_cache: Dictionary = {}
var _packaging_character_expressions_cache: Dictionary = {}
var _pending_rename_episode_title: String = ""
var _pending_delete_episode_title: String = ""
var _pending_create_episode_folder: String = ""
var _episode_dragging: bool = false
var _episode_drag_start_pos: Vector2 = Vector2.ZERO
var _episode_drag_panel: PanelContainer = null
var _episode_drag_moved: bool = false

func _ready():
	_ensure_projects_root()
	_init_row_styles()
	_load_projects()
	_relayout_project_action_buttons()
	_apply_delete_button_danger_style()
	_update_action_buttons_state()

	if export_zip_button:
		export_zip_button.tooltip_text = "导出ZIP功能暂时禁用"

	if project_scroll and not project_scroll.gui_input.is_connected(_on_project_scroll_gui_input):
		project_scroll.gui_input.connect(_on_project_scroll_gui_input)

	if background and not background.gui_input.is_connected(_on_background_gui_input):
		background.gui_input.connect(_on_background_gui_input)

	if search_input:
		search_input.text_changed.connect(_on_search_text_changed)

	if new_project_button and not new_project_button.pressed.is_connected(_on_new_project_button_pressed):
		new_project_button.pressed.connect(_on_new_project_button_pressed)
	if open_project_button and not open_project_button.pressed.is_connected(_on_open_project_button_pressed):
		open_project_button.pressed.connect(_on_open_project_button_pressed)
	if delete_project_button and not delete_project_button.pressed.is_connected(_on_delete_project_button_pressed):
		delete_project_button.pressed.connect(_on_delete_project_button_pressed)
	if back_button and not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)

	if new_project_dialog:
		var confirm_button := new_project_dialog.get_node_or_null("DialogContent/ButtonRow/ConfirmButton") as Button
		if confirm_button and not confirm_button.pressed.is_connected(_on_confirm_new_project):
			confirm_button.pressed.connect(_on_confirm_new_project)
		var cancel_button := new_project_dialog.get_node_or_null("DialogContent/ButtonRow/CancelButton") as Button
		if cancel_button and not cancel_button.pressed.is_connected(_on_cancel_new_project):
			cancel_button.pressed.connect(_on_cancel_new_project)
		if project_name_input and not project_name_input.text_changed.is_connected(_clear_new_project_error):
			project_name_input.text_changed.connect(_clear_new_project_error)

	if delete_confirm_dialog:
		delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)

	if preview_file_dialog and not preview_file_dialog.file_selected.is_connected(_on_preview_file_selected):
		preview_file_dialog.file_selected.connect(_on_preview_file_selected)
	if export_zip_dialog and not export_zip_dialog.file_selected.is_connected(_on_export_zip_path_selected):
		export_zip_dialog.file_selected.connect(_on_export_zip_path_selected)
	if install_mods_confirm_dialog and not install_mods_confirm_dialog.confirmed.is_connected(_on_install_mods_confirmed):
		install_mods_confirm_dialog.confirmed.connect(_on_install_mods_confirmed)

	if project_title_input:
		project_title_input.text_changed.connect(_on_project_title_changed)
	if project_desc_input:
		project_desc_input.text_changed.connect(_on_project_desc_changed)
	if add_episode_button:
		add_episode_button.pressed.connect(_on_add_episode_pressed)
	if project_preview and not project_preview.gui_input.is_connected(_on_project_preview_gui_input):
		project_preview.gui_input.connect(_on_project_preview_gui_input)
	if export_zip_button and not export_zip_button.pressed.is_connected(_on_export_zip_pressed):
		export_zip_button.pressed.connect(_on_export_zip_pressed)
	if install_to_mods_button and not install_to_mods_button.pressed.is_connected(_on_install_to_mods_pressed):
		install_to_mods_button.pressed.connect(_on_install_to_mods_pressed)

	if episode_rename_dialog and not episode_rename_dialog.confirmed.is_connected(_on_episode_rename_confirmed):
		episode_rename_dialog.confirmed.connect(_on_episode_rename_confirmed)
	if episode_rename_dialog and episode_rename_dialog.has_signal("canceled") and not episode_rename_dialog.canceled.is_connected(_on_episode_rename_dialog_canceled):
		episode_rename_dialog.canceled.connect(_on_episode_rename_dialog_canceled)
	if episode_rename_dialog and episode_rename_dialog.has_signal("close_requested") and not episode_rename_dialog.close_requested.is_connected(_on_episode_rename_dialog_canceled):
		episode_rename_dialog.close_requested.connect(_on_episode_rename_dialog_canceled)
	if episode_rename_input and not episode_rename_input.text_changed.is_connected(_clear_episode_rename_error):
		episode_rename_input.text_changed.connect(_clear_episode_rename_error)
	if episode_delete_confirm_dialog and not episode_delete_confirm_dialog.confirmed.is_connected(_on_episode_delete_confirmed):
		episode_delete_confirm_dialog.confirmed.connect(_on_episode_delete_confirmed)

	_update_empty_state()
	_apply_search_filter(search_input.text if search_input else "")
	_show_empty_project_details()
	_update_action_buttons_state()
	_configure_detail_scroll_ui()
	_play_enter_animation()

func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning or _is_exiting:
		return
	if event.is_action_pressed("ui_cancel"):
		_request_exit_to_menu()
		get_viewport().set_input_as_handled()

func _play_enter_animation() -> void:
	if background:
		background.modulate.a = 0.0
	if window_panel:
		window_panel.modulate.a = 0.0
		window_panel.scale = Vector2(0.985, 0.985)

	var tween := create_tween()
	tween.set_parallel(true)
	if background:
		tween.tween_property(background, "modulate:a", 1.0, ENTER_ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if window_panel:
		tween.tween_property(window_panel, "modulate:a", 1.0, ENTER_ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(window_panel, "scale", Vector2.ONE, ENTER_ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _request_exit_to_menu() -> void:
	if _is_exiting or _is_transitioning:
		return
	_is_exiting = true

	# 防止退出过程中继续交互
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if window_panel:
		window_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if background:
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tween := create_tween()
	tween.set_parallel(true)
	if window_panel:
		tween.tween_property(window_panel, "modulate:a", 0.0, EXIT_ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if background:
		tween.tween_property(background, "modulate:a", 0.0, EXIT_ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)

func _set_project_manager_visible_for_editor(visible_flag: bool) -> void:
	# 编辑器打开时：隐藏自身，避免遮挡/接收输入；返回时恢复。
	visible = visible_flag
	mouse_filter = Control.MOUSE_FILTER_STOP if visible_flag else Control.MOUSE_FILTER_IGNORE
	if window_panel:
		window_panel.mouse_filter = Control.MOUSE_FILTER_STOP if visible_flag else Control.MOUSE_FILTER_IGNORE
	if background:
		background.mouse_filter = Control.MOUSE_FILTER_STOP if visible_flag else Control.MOUSE_FILTER_IGNORE

	if visible_flag:
		var parent := get_parent()
		if parent:
			parent.move_child(self, parent.get_child_count() - 1)

func _on_editor_tree_exited() -> void:
	_active_editor = null
	_is_transitioning = false
	_set_project_manager_visible_for_editor(true)
	_refresh_episode_rows_ui()
	_update_action_buttons_state()

func _configure_detail_scroll_ui() -> void:
	if detail_scroll == null:
		return

	# 预留滚动条占位：若支持 scroll mode，则强制始终显示竖向滚动条，避免内容被突然挤压。
	var has_vertical_scroll_mode := false
	var has_horizontal_scroll_mode := false
	for prop in detail_scroll.get_property_list():
		var prop_name := str(prop.get("name", ""))
		if prop_name == "vertical_scroll_mode":
			has_vertical_scroll_mode = true
		elif prop_name == "horizontal_scroll_mode":
			has_horizontal_scroll_mode = true

	# Godot 4: ScrollMode 0=DISABLED 1=AUTO 2=SHOW_ALWAYS 3=SHOW_NEVER
	if has_vertical_scroll_mode:
		detail_scroll.set("vertical_scroll_mode", 2)
	if has_horizontal_scroll_mode:
		detail_scroll.set("horizontal_scroll_mode", 3)

func _relayout_project_action_buttons() -> void:
	if _footer_actions == null:
		return

	var insert_after: Node = open_project_button if open_project_button else null
	if export_zip_button:
		_move_footer_action_button(export_zip_button, insert_after)
		insert_after = export_zip_button
	if install_to_mods_button:
		_move_footer_action_button(install_to_mods_button, insert_after)
		insert_after = install_to_mods_button

	if _detail_actions:
		_detail_actions.visible = false
		_detail_actions.queue_free()

func _move_footer_action_button(button: Button, after: Node) -> void:
	if _footer_actions == null or button == null:
		return

	var parent := button.get_parent()
	if parent and parent != _footer_actions:
		parent.remove_child(button)
	if button.get_parent() != _footer_actions:
		_footer_actions.add_child(button)

	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 20)

	if after and after.get_parent() == _footer_actions:
		var idx: int = after.get_index()
		_footer_actions.move_child(button, idx + 1)

func _apply_delete_button_danger_style() -> void:
	if delete_project_button == null:
		return
	delete_project_button.add_theme_color_override("font_color", Color(1, 0.35, 0.35, 1))
	delete_project_button.add_theme_color_override("font_hover_color", Color(1, 0.45, 0.45, 1))
	delete_project_button.add_theme_color_override("font_pressed_color", Color(1, 0.25, 0.25, 1))
	delete_project_button.add_theme_color_override("font_disabled_color", Color(1, 0.35, 0.35, 0.35))

func _update_action_buttons_state() -> void:
	var has_project := not selected_project.is_empty()
	var has_episode := has_project and not _selected_episode_title.is_empty()

	if open_project_button:
		open_project_button.disabled = not has_episode
	if delete_project_button:
		delete_project_button.disabled = not has_project
	if add_episode_button:
		add_episode_button.disabled = not has_project
	if export_zip_button:
		export_zip_button.disabled = (not EXPORT_ZIP_ENABLED) or (not has_project)
	if install_to_mods_button:
		install_to_mods_button.disabled = not has_project

func _show_new_project_error(message: String) -> void:
	if new_project_error_label:
		new_project_error_label.text = message
		new_project_error_label.visible = not message.is_empty()

func _clear_new_project_error(_new_text: String = "") -> void:
	if new_project_error_label:
		new_project_error_label.text = ""
		new_project_error_label.visible = false

func _show_episode_rename_error(message: String) -> void:
	if episode_rename_error_label:
		episode_rename_error_label.text = message
		episode_rename_error_label.visible = not message.is_empty()

func _clear_episode_rename_error(_new_text: String = "") -> void:
	if episode_rename_error_label:
		episode_rename_error_label.text = ""
		episode_rename_error_label.visible = false

func _on_episode_rename_dialog_canceled() -> void:
	_pending_create_episode_folder = ""
	_pending_rename_episode_title = ""
	_clear_episode_rename_error()

func _reopen_episode_rename_dialog() -> void:
	if episode_rename_dialog == null:
		return
	episode_rename_dialog.popup_centered()
	if episode_rename_input:
		episode_rename_input.grab_focus()

func _is_valid_project_folder_name(folder_name: String) -> bool:
	var s := folder_name.strip_edges()
	if s.is_empty() or s.length() > MAX_PROJECT_FOLDER_NAME_LENGTH:
		return false

	for ch in s:
		var code := ch.unicode_at(0)
		var is_ascii_digit := code >= 48 and code <= 57
		var is_ascii_upper := code >= 65 and code <= 90
		var is_ascii_lower := code >= 97 and code <= 122
		var is_underscore := code == 95
		var is_dash := code == 45
		var is_cjk := code >= 0x4E00 and code <= 0x9FFF
		if not (is_ascii_digit or is_ascii_upper or is_ascii_lower or is_underscore or is_dash or is_cjk):
			return false

	return true

func _strip_control_chars(text: String, allow_newlines: bool) -> String:
	var out := ""
	for ch in text:
		var code := ch.unicode_at(0)
		if code == 10 and allow_newlines:
			out += ch
			continue
		if code < 32 or code == 127:
			continue
		out += ch
	return out

func _clamp_text_lines(text: String, max_lines: int) -> String:
	if max_lines <= 0:
		return ""

	var lines := text.split("\n")
	if lines.size() <= max_lines:
		return text

	lines.resize(max_lines)
	return "\n".join(lines)

func _sanitize_project_title(title: String) -> String:
	var s := _strip_control_chars(title, false).strip_edges()
	for forbidden in ["\\", "/", ":", "*", "?", "\"", "<", ">", "|", "`"]:
		s = s.replace(forbidden, "")
	if s.length() > MAX_PROJECT_TITLE_LENGTH:
		s = s.substr(0, MAX_PROJECT_TITLE_LENGTH)
	return s

func _sanitize_project_desc(desc: String) -> String:
	var s := _strip_control_chars(desc, true)
	s = s.replace("\r", "")
	for forbidden in ["\\", ":", "*", "?", "\"", "<", ">", "|", "`"]:
		s = s.replace(forbidden, "")
	s = _clamp_text_lines(s, MAX_PROJECT_DESC_LINES)
	if s.length() > MAX_PROJECT_DESC_LENGTH:
		s = s.substr(0, MAX_PROJECT_DESC_LENGTH)
	return s

func _sanitize_episode_title(title: String) -> String:
	var s := _strip_control_chars(title, false).strip_edges()
	# 不允许会影响路径/脚本生成的字符
	for forbidden in ["\\", "/", ":", "*", "?", "\"", "<", ">", "|"]:
		s = s.replace(forbidden, "")
	if s.length() > MAX_EPISODE_TITLE_LENGTH:
		s = s.substr(0, MAX_EPISODE_TITLE_LENGTH)
	return s

func _ensure_projects_root() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("mod_projects"):
		dir.make_dir("mod_projects")

func _ensure_mods_root() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("mods"):
		dir.make_dir("mods")

func _init_row_styles() -> void:
	_row_style_normal = StyleBoxFlat.new()
	_row_style_normal.bg_color = Color(1, 1, 1, 0.04)
	_row_style_normal.corner_radius_top_left = 10
	_row_style_normal.corner_radius_top_right = 10
	_row_style_normal.corner_radius_bottom_right = 10
	_row_style_normal.corner_radius_bottom_left = 10
	_row_style_normal.content_margin_left = 12
	_row_style_normal.content_margin_right = 12
	_row_style_normal.content_margin_top = 10
	_row_style_normal.content_margin_bottom = 10

	_row_style_selected = StyleBoxFlat.new()
	_row_style_selected.bg_color = Color(0.35, 0.55, 1.0, 0.16)
	_row_style_selected.border_width_left = 1
	_row_style_selected.border_width_top = 1
	_row_style_selected.border_width_right = 1
	_row_style_selected.border_width_bottom = 1
	_row_style_selected.border_color = Color(0.5, 0.7, 1.0, 0.55)
	_row_style_selected.corner_radius_top_left = 10
	_row_style_selected.corner_radius_top_right = 10
	_row_style_selected.corner_radius_bottom_right = 10
	_row_style_selected.corner_radius_bottom_left = 10
	_row_style_selected.content_margin_left = 12
	_row_style_selected.content_margin_right = 12
	_row_style_selected.content_margin_top = 10
	_row_style_selected.content_margin_bottom = 10

func _update_empty_state() -> void:
	if not empty_label:
		return
	var is_empty := project_items.is_empty()
	empty_label.visible = is_empty
	if is_empty:
		empty_label.text = "还没有任何Mod工程\n点击下方“新建工程”开始"

func _on_search_text_changed(new_text: String) -> void:
	_apply_search_filter(new_text)

func _apply_search_filter(query: String) -> void:
	if not search_input and query.is_empty():
		return

	query = query.strip_edges()
	if query.is_empty():
		for item in project_items:
			var panel: Control = item.get("panel")
			if panel:
				panel.visible = true
		return

	var has_any_visible := false
	var query_lower := query.to_lower()
	for item in project_items:
		var panel: Control = item.get("panel")
		if not panel:
			continue
		var project_name: String = item.get("name", "")
		var is_match := project_name.to_lower().find(query_lower) != -1
		panel.visible = is_match
		has_any_visible = has_any_visible or is_match

	if not selected_project.is_empty():
		for item in project_items:
			if item.get("name", "") == selected_project:
				var selected_panel: Control = item.get("panel")
				if selected_panel and not selected_panel.visible:
					_clear_project_selection()
				break

	if not has_any_visible:
		_clear_project_selection()

func _on_row_gui_input(event: InputEvent, project_name: String) -> void:
	# 单击行不视为“选择工程”，避免用户未点“选择”按钮也被误选中。
	# 双击行视为快捷操作：先选择该工程，再尝试打开。
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
		_on_project_selected(project_name)
		_on_open_project_button_pressed()

func _on_project_scroll_gui_input(event: InputEvent) -> void:
	# 点击列表空白处：取消选择（更符合直觉）
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not selected_project.is_empty():
			_clear_project_selection()
			get_viewport().set_input_as_handled()

func _on_background_gui_input(event: InputEvent) -> void:
	# 点击弹窗外区域：返回主界面（更符合直觉）
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_request_exit_to_menu()
		get_viewport().set_input_as_handled()

func _load_projects():
	"""加载所有工程"""
	_ensure_projects_root()
	# 清空现有列表
	for child in project_list.get_children():
		child.queue_free()
	project_items.clear()
	_update_empty_state()
	_clear_project_selection()
	pending_delete_project = ""

	# 读取工程文件夹
	var dir = DirAccess.open(PROJECTS_PATH)
	if not dir:
		print("工程文件夹不存在")
		return

	dir.list_dir_begin()
	var project_name = dir.get_next()
	while project_name != "":
		if dir.current_is_dir() and not project_name.begins_with("."):
			_create_project_item(project_name)
		project_name = dir.get_next()
	dir.list_dir_end()

	_update_empty_state()
	_apply_search_filter(search_input.text if search_input else "")
	if selected_project.is_empty():
		_show_empty_project_details()

func _create_project_item(project_name: String):
	"""创建工程列表项"""
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 56)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if _row_style_normal:
		row_panel.add_theme_stylebox_override("panel", _row_style_normal)
	row_panel.gui_input.connect(_on_row_gui_input.bind(project_name))

	var item_container := HBoxContainer.new()
	item_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_container.alignment = BoxContainer.ALIGNMENT_CENTER
	item_container.add_theme_constant_override("separation", 12)

	# 工程名称标签
	var label = Label.new()
	label.text = project_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))

	# 选择按钮
	var select_button = Button.new()
	select_button.text = "选择"
	select_button.pressed.connect(_toggle_project_selection.bind(project_name))
	select_button.custom_minimum_size = Vector2(56, 34)
	select_button.add_theme_font_override("font", UI_FONT)
	select_button.add_theme_font_size_override("font_size", 16)

	item_container.add_child(label)
	item_container.add_child(select_button)
	row_panel.add_child(item_container)
	project_list.add_child(row_panel)
	project_items.append({"name": project_name, "panel": row_panel, "button": select_button})
	_refresh_project_item_ui()

func _toggle_project_selection(project_name: String) -> void:
	if selected_project == project_name:
		_clear_project_selection()
		return
	_on_project_selected(project_name)

func _refresh_project_item_ui() -> void:
	for item in project_items:
		var panel: Control = item.get("panel")
		var button: Button = item.get("button")
		var project_name := str(item.get("name", ""))

		if panel:
			if project_name == selected_project and _row_style_selected:
				panel.add_theme_stylebox_override("panel", _row_style_selected)
			elif _row_style_normal:
				panel.add_theme_stylebox_override("panel", _row_style_normal)

		if button:
			button.text = "取消选择" if project_name == selected_project else "选择"

func _on_project_selected(project_name: String):
	"""选择工程"""
	selected_project = project_name

	_refresh_project_item_ui()

	_load_project_details(project_name)
	_update_action_buttons_state()

func _clear_project_selection() -> void:
	selected_project = ""
	_refresh_project_item_ui()
	_show_empty_project_details()
	_update_action_buttons_state()

func _show_empty_project_details() -> void:
	_set_right_panel_visible(false)
	if project_title_input:
		project_title_input.text = ""
		project_title_input.editable = false
	if project_desc_input:
		project_desc_input.text = ""
		project_desc_input.editable = false
	if project_preview:
		project_preview.texture = _load_texture_any(DEFAULT_PREVIEW_IMAGE)
	if episode_list:
		for child in episode_list.get_children():
			child.queue_free()
	if add_episode_button:
		add_episode_button.disabled = true
	if export_zip_button:
		export_zip_button.disabled = true
	if install_to_mods_button:
		install_to_mods_button.disabled = true
	_selected_episode_title = ""
	_selected_episode_path = ""
	_update_action_buttons_state()

func _set_right_panel_visible(visible_flag: bool) -> void:
	if right_panel:
		right_panel.visible = visible_flag

func _is_blank_project_config(config: Dictionary) -> bool:
	var episodes_any: Variant = config.get("episodes", {})
	if typeof(episodes_any) != TYPE_DICTIONARY:
		return true
	return (episodes_any as Dictionary).is_empty()

func _get_project_root(project_name: String) -> String:
	return PROJECTS_PATH + "/" + project_name

func _get_mod_config_path(project_name: String) -> String:
	return _get_project_root(project_name) + "/mod_config.json"

func _load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()
	if err != OK:
		return {}
	if typeof(json.data) == TYPE_DICTIONARY:
		return json.data
	return {}

func _save_json_file(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func _ensure_mod_config(project_name: String) -> Dictionary:
	var config_path := _get_mod_config_path(project_name)
	var config := _load_json_file(config_path)

	var root := _get_project_root(project_name)
	var legacy_project_json := _load_json_file(root + "/project.json")
	var legacy_title := str(legacy_project_json.get("project_name", project_name))
	var today := Time.get_date_string_from_system()

	if config.is_empty():
		config = {
			"mod_id": project_name,
			"title": legacy_title,
			"author": "",
			"version": "1.0.0",
			"description": "",
			"preview_image": DEFAULT_PREVIEW_IMAGE,
			"episodes": {},
			"custom_characters": [],
			"custom_music": {},
			"custom_images": {"backgrounds": [], "roles": []},
			"created_date": today,
			"last_updated": today
		}

		# 兼容旧项目：把根目录作为第1节
		if FileAccess.file_exists(root + "/project.json"):
			config["episodes"]["第1节"] = "export/story.tscn"

		_save_json_file(config_path, config)
	else:
		if not config.has("preview_image"):
			config["preview_image"] = DEFAULT_PREVIEW_IMAGE
		if not config.has("episodes") or typeof(config.get("episodes")) != TYPE_DICTIONARY:
			config["episodes"] = {}
		if not config.has("title"):
			config["title"] = legacy_title
		if not config.has("description"):
			config["description"] = ""
		_save_json_file(config_path, config)

	return config

func _load_project_details(project_name: String) -> void:
	_is_loading_details = true
	var config := _ensure_mod_config(project_name)

	if _is_blank_project_config(config):
		_selected_episode_title = ""
		_selected_episode_path = ""
		_set_right_panel_visible(false)
		_is_loading_details = false
		_update_action_buttons_state()
		return

	_set_right_panel_visible(true)

	if project_title_input:
		project_title_input.editable = true
		project_title_input.text = str(config.get("title", project_name))
	if project_desc_input:
		project_desc_input.editable = true
		project_desc_input.text = str(config.get("description", ""))

	if project_preview:
		var preview_path := str(config.get("preview_image", DEFAULT_PREVIEW_IMAGE))
		var resolved := _resolve_project_relative_path(project_name, preview_path)
		var tex := _load_texture_any(resolved)
		project_preview.texture = tex if tex else _load_texture_any(DEFAULT_PREVIEW_IMAGE)

	_reload_episode_list(config)
	_is_loading_details = false
	_update_action_buttons_state()

func _reload_episode_list(config: Dictionary) -> void:
	_selected_episode_title = ""
	_selected_episode_path = ""
	if episode_list == null:
		_update_action_buttons_state()
		return

	for child in episode_list.get_children():
		child.queue_free()
	var episodes: Dictionary = config.get("episodes", {})
	if typeof(episodes) != TYPE_DICTIONARY:
		_update_action_buttons_state()
		return

	for key_any in (episodes as Dictionary).keys():
		var title := str(key_any)
		var path := str((episodes as Dictionary).get(title, ""))
		_create_episode_row(title, path)

	_update_action_buttons_state()

func _create_episode_row(title: String, path: String) -> void:
	if episode_list == null:
		return

	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 44)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	row_panel.mouse_default_cursor_shape = Control.CURSOR_DRAG
	row_panel.gui_input.connect(_on_episode_row_gui_input.bind(row_panel, title, path))
	if _row_style_normal:
		row_panel.add_theme_stylebox_override("panel", _row_style_normal)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))

	var rename_button := Button.new()
	rename_button.text = "改名"
	rename_button.custom_minimum_size = Vector2(72, 34)
	rename_button.add_theme_font_override("font", UI_FONT)
	rename_button.add_theme_font_size_override("font_size", 16)
	rename_button.pressed.connect(_on_episode_rename_pressed.bind(title))

	var delete_button := Button.new()
	delete_button.text = "删除"
	delete_button.custom_minimum_size = Vector2(72, 34)
	delete_button.add_theme_font_override("font", UI_FONT)
	delete_button.add_theme_font_size_override("font_size", 16)
	delete_button.pressed.connect(_on_episode_delete_pressed.bind(title))

	row.add_child(label)
	row.add_child(rename_button)
	row.add_child(delete_button)
	row_panel.add_child(row)
	episode_list.add_child(row_panel)

func _refresh_episode_rows_ui() -> void:
	if episode_list == null:
		return

	for child in episode_list.get_children():
		var panel := child as PanelContainer
		if panel == null:
			continue
		var row := panel.get_child(0) as HBoxContainer
		var label := row.get_child(0) as Label if row else null
		var title := label.text if label else ""
		if title == _selected_episode_title and _row_style_selected:
			panel.add_theme_stylebox_override("panel", _row_style_selected)
		elif _row_style_normal:
			panel.add_theme_stylebox_override("panel", _row_style_normal)

func _on_episode_row_gui_input(event: InputEvent, panel: PanelContainer, title: String, path: String) -> void:
	if panel == null or episode_list == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_selected_episode_title = title
			_selected_episode_path = path
			_refresh_episode_rows_ui()
			_update_action_buttons_state()

			_episode_dragging = true
			_episode_drag_moved = false
			_episode_drag_panel = panel
			_episode_drag_start_pos = get_viewport().get_mouse_position()

			get_viewport().set_input_as_handled()
		else:
			if _episode_dragging and _episode_drag_panel == panel:
				_episode_dragging = false
				_episode_drag_panel = null
				if _episode_drag_moved:
					_commit_episode_order()
				_episode_drag_moved = false
				get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _episode_dragging and _episode_drag_panel == panel:
		var mouse_pos := get_viewport().get_mouse_position()
		if mouse_pos.distance_to(_episode_drag_start_pos) < EPISODE_DRAG_THRESHOLD and not _episode_drag_moved:
			return

		var target_index := _get_episode_drop_index(mouse_pos.y, panel)
		if target_index != panel.get_index():
			episode_list.move_child(panel, target_index)
			_episode_drag_moved = true
		get_viewport().set_input_as_handled()

func _get_episode_drop_index(mouse_y: float, dragging_panel: PanelContainer) -> int:
	if episode_list == null:
		return 0

	var children := episode_list.get_children()
	var index := 0
	for child in children:
		if child == dragging_panel:
			continue
		var control := child as Control
		if control == null:
			continue
		var rect := control.get_global_rect()
		var mid_y := rect.position.y + rect.size.y * 0.5
		if mouse_y < mid_y:
			return index
		index += 1

	return maxi(0, episode_list.get_child_count() - 1)

func _commit_episode_order() -> void:
	if selected_project.is_empty() or episode_list == null:
		return

	var config := _ensure_mod_config(selected_project)
	var episodes: Dictionary = config.get("episodes", {})
	if typeof(episodes) != TYPE_DICTIONARY:
		return

	var new_episodes: Dictionary = {}
	for child in episode_list.get_children():
		var panel := child as PanelContainer
		if panel == null:
			continue
		var row := panel.get_child(0) as HBoxContainer
		var label := row.get_child(0) as Label if row else null
		if label == null:
			continue
		var title := label.text
		if title.is_empty() or not episodes.has(title):
			continue
		new_episodes[title] = episodes.get(title)

	config["episodes"] = new_episodes
	_touch_config(selected_project, config)

func _touch_config(project_name: String, config: Dictionary) -> void:
	config["last_updated"] = Time.get_date_string_from_system()
	_save_json_file(_get_mod_config_path(project_name), config)

func _resolve_project_relative_path(project_name: String, path: String) -> String:
	var trimmed := path.strip_edges()
	if trimmed.is_empty():
		return DEFAULT_PREVIEW_IMAGE
	if trimmed.begins_with("res://") or trimmed.begins_with("user://"):
		return trimmed
	if trimmed.find(":/") != -1 or trimmed.begins_with("/"):
		return trimmed
	return _get_project_root(project_name) + "/" + trimmed

func _load_texture_any(path: String) -> Texture2D:
	if path.begins_with("res://"):
		var res: Resource = load(path)
		return res as Texture2D
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)

func _make_cover_thumbnail(src: Image, target_size: Vector2i) -> Image:
	var result := Image.new()
	if src == null:
		return result
	var w: int = src.get_width()
	var h: int = src.get_height()
	if w <= 0 or h <= 0:
		return result

	var scale_x: float = float(target_size.x) / float(w)
	var scale_y: float = float(target_size.y) / float(h)
	var scale_factor: float = maxf(scale_x, scale_y)
	var resized_w: int = maxi(1, ceili(float(w) * scale_factor))
	var resized_h: int = maxi(1, ceili(float(h) * scale_factor))

	var resized_img: Image = src.duplicate() as Image
	if resized_img == null:
		return result
	resized_img.resize(resized_w, resized_h, Image.INTERPOLATE_LANCZOS)
	var crop_x: int = maxi(0, int(float(resized_w - target_size.x) / 2.0))
	var crop_y: int = maxi(0, int(float(resized_h - target_size.y) / 2.0))

	result = Image.create(target_size.x, target_size.y, false, resized_img.get_format())
	result.blit_rect(resized_img, Rect2i(crop_x, crop_y, target_size.x, target_size.y), Vector2i.ZERO)
	return result

func _on_project_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if selected_project.is_empty():
			push_error("请先选择一个工程再设置预览图")
			return
		if preview_file_dialog == null:
			return
		preview_file_dialog.current_dir = _last_preview_dir if not _last_preview_dir.is_empty() else ProjectSettings.globalize_path(_get_project_root(selected_project))
		preview_file_dialog.popup_centered_ratio(0.8)

func _on_preview_file_selected(path: String) -> void:
	if selected_project.is_empty():
		return
	_last_preview_dir = path.get_base_dir()

	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_error("无法加载图片: " + path)
		return

	var thumb := _make_cover_thumbnail(img, PROJECT_PREVIEW_SIZE)
	if thumb.is_empty():
		push_error("图片处理失败: " + path)
		return

	var root_dir := DirAccess.open(_get_project_root(selected_project))
	if root_dir:
		root_dir.make_dir_recursive("preview")

	var save_path := _get_project_root(selected_project) + "/" + PROJECT_PREVIEW_FILE
	var save_err := thumb.save_png(save_path)
	if save_err != OK:
		push_error("无法保存预览图: " + save_path)
		return

	var config := _ensure_mod_config(selected_project)
	config["preview_image"] = PROJECT_PREVIEW_FILE
	_touch_config(selected_project, config)

	if project_preview:
		project_preview.texture = ImageTexture.create_from_image(thumb)

func _on_export_zip_pressed() -> void:
	if not EXPORT_ZIP_ENABLED:
		_show_info_dialog("导出ZIP暂时不可用", "导出ZIP功能暂时禁用（目前仍有问题），请先使用“导入到Mods”进行测试。")
		return
	if selected_project.is_empty():
		return
	_begin_export_zip_for_project(selected_project)

func _on_export_zip_project_pressed(project_name: String) -> void:
	if not EXPORT_ZIP_ENABLED:
		_show_info_dialog("导出ZIP暂时不可用", "导出ZIP功能暂时禁用（目前仍有问题），请先使用“导入到Mods”进行测试。")
		return
	_begin_export_zip_for_project(project_name)

func _begin_export_zip_for_project(project_name: String) -> void:
	if not EXPORT_ZIP_ENABLED:
		return
	if export_zip_dialog == null:
		return

	var errors: Array[String] = _validate_project_for_packaging(project_name)
	if not errors.is_empty():
		_show_packaging_blocked("无法导出ZIP", errors)
		_pending_export_project = ""
		return

	_pending_export_project = project_name
	var config := _ensure_mod_config(project_name)
	var mod_id: String = str(config.get("mod_id", project_name)).strip_edges()
	var file_name: String = _sanitize_folder_name(mod_id)
	if file_name.is_empty():
		file_name = _sanitize_folder_name(project_name)
	export_zip_dialog.current_file = "%s.zip" % file_name
	export_zip_dialog.popup_centered_ratio(0.8)

func _on_export_zip_path_selected(path: String) -> void:
	if _pending_export_project.is_empty():
		return
	var project_name: String = _pending_export_project
	_pending_export_project = ""

	var errors: Array[String] = _validate_project_for_packaging(project_name)
	if not errors.is_empty():
		_show_packaging_blocked("无法导出ZIP", errors)
		return

	var err := _export_project_zip(project_name, path)
	if err != OK:
		push_error("导出ZIP失败: " + str(err))

func _on_install_to_mods_pressed() -> void:
	if selected_project.is_empty():
		return
	_begin_install_to_mods_for_project(selected_project)

func _on_install_to_mods_project_pressed(project_name: String) -> void:
	_begin_install_to_mods_for_project(project_name)

func _begin_install_to_mods_for_project(project_name: String) -> void:
	_pending_install_project = project_name

	var errors: Array[String] = _validate_project_for_packaging(project_name)
	if not errors.is_empty():
		_show_packaging_blocked("无法导入到Mods", errors)
		_pending_install_project = ""
		return

	var target_folder := _get_mod_folder_name_for_project(project_name)
	if target_folder.is_empty():
		push_error("无法确定mod文件夹名称")
		_pending_install_project = ""
		return
	_ensure_mods_root()
	var target_path := MODS_PATH + "/" + target_folder
	if DirAccess.open(target_path) != null:
		if install_mods_confirm_dialog:
			install_mods_confirm_dialog.popup_centered()
			return
	_on_install_mods_confirmed()

func _on_install_mods_confirmed() -> void:
	if _pending_install_project.is_empty():
		return
	var project_name: String = _pending_install_project
	_pending_install_project = ""

	var errors: Array[String] = _validate_project_for_packaging(project_name)
	if not errors.is_empty():
		_show_packaging_blocked("无法导入到Mods", errors)
		return

	var target_folder := _get_mod_folder_name_for_project(project_name)
	if target_folder.is_empty():
		return
	_ensure_mods_root()
	var target_path := MODS_PATH + "/" + target_folder
	if DirAccess.open(target_path) != null:
		_delete_directory_recursive(target_path)
	var err := _build_mod_folder(project_name, MODS_PATH, target_folder)
	if err != OK:
		push_error("导入到Mods失败: " + str(err))

func _sanitize_folder_name(raw_name: String) -> String:
	var s := raw_name.strip_edges()
	s = s.replace("\\", "_").replace("/", "_").replace(":", "_").replace("*", "_")
	s = s.replace("?", "_").replace("\"", "_").replace("<", "_").replace(">", "_").replace("|", "_")
	return s

func _get_packaging_error_dialog() -> AcceptDialog:
	if _packaging_error_dialog != null and is_instance_valid(_packaging_error_dialog):
		return _packaging_error_dialog
	_packaging_error_dialog = AcceptDialog.new()
	_packaging_error_dialog.title = "提示"
	add_child(_packaging_error_dialog)
	return _packaging_error_dialog

func _show_info_dialog(title: String, text: String) -> void:
	var dialog := _get_packaging_error_dialog()
	dialog.title = title
	dialog.dialog_text = text
	dialog.popup_centered_ratio(0.7)

func _show_packaging_blocked(action_title: String, errors: Array[String]) -> void:
	var dialog := _get_packaging_error_dialog()
	var max_lines := 12
	var shown: Array[String] = []
	for i in range(mini(max_lines, errors.size())):
		shown.append(errors[i])

	var body := "\n".join(shown)
	if errors.size() > max_lines:
		body += "\n…（还有 %d 条）" % (errors.size() - max_lines)

	dialog.title = action_title
	dialog.dialog_text = "%s：检测到不合规脚本块，已取消创建/覆盖。\n\n%s" % [action_title, body]
	dialog.popup_centered_ratio(0.7)

func _validate_project_for_packaging(project_name: String) -> Array[String]:
	var errors: Array[String] = []

	var config := _ensure_mod_config(project_name)
	var episodes_any: Variant = config.get("episodes", {})
	if typeof(episodes_any) != TYPE_DICTIONARY:
		errors.append("工程配置的 episodes 字段无效，无法导出/导入。")
		return errors

	var episodes: Dictionary = episodes_any as Dictionary
	if episodes.is_empty():
		errors.append("该工程没有任何剧情节，无法导出/导入。")
		return errors

	var root := _get_project_root(project_name)
	for episode_title_any in episodes.keys():
		var episode_title: String = str(episode_title_any)
		var src_scene_rel: String = str(episodes.get(episode_title_any, "")).strip_edges()
		var episode_project := _resolve_episode_project_json_for_packaging(root, src_scene_rel)
		if episode_project.is_empty() or not FileAccess.file_exists(episode_project):
			errors.append("剧情节「%s」找不到工程文件 project.json，无法导出/导入。" % episode_title)
			continue

		var episode_data := _load_json_file(episode_project)
		var scripts_any: Variant = episode_data.get("scripts", [])
		if typeof(scripts_any) != TYPE_ARRAY:
			errors.append("剧情节「%s」的 scripts 数据无效，无法导出/导入。" % episode_title)
			continue

		var scripts: Array = scripts_any as Array
		var episode_errors: Array[String] = _validate_scripts_for_packaging(root, episode_title, scripts)
		for err_text in episode_errors:
			errors.append(err_text)

	return errors

func _resolve_episode_project_json_for_packaging(project_root: String, src_scene_rel: String) -> String:
	var root_candidate := project_root + "/project.json"
	var rel := src_scene_rel.replace("\\", "/").strip_edges()

	# 优先尝试根目录（兼容旧结构/导出结构）；不存在时再尝试 episodes/<ep>/project.json
	if rel.is_empty() or rel.begins_with("export/"):
		return root_candidate if FileAccess.file_exists(root_candidate) else ""

	# 支持：episodes/ep01（文件夹） 或 episodes/ep01/xxx.tscn（场景）
	if rel.begins_with("episodes/"):
		var base_dir := rel.get_base_dir() if rel.ends_with(".tscn") else rel
		base_dir = base_dir.trim_suffix("/")
		var candidate := project_root + "/" + base_dir + "/project.json"
		if FileAccess.file_exists(candidate):
			return candidate

	# 兜底：从路径中提取 epXX
	var folder := _extract_ep_name_from_path(rel)
	if not folder.is_empty():
		var candidate := project_root + "/episodes/%s/project.json" % folder
		if FileAccess.file_exists(candidate):
			return candidate
		# 兼容老结构：episode 文件夹可能在根目录下
		candidate = project_root + "/%s/project.json" % folder
		if FileAccess.file_exists(candidate):
			return candidate

	# 兜底：根目录
	return root_candidate if FileAccess.file_exists(root_candidate) else ""

func _validate_scripts_for_packaging(project_root: String, episode_title: String, scripts: Array) -> Array[String]:
	var errors: Array[String] = []

	var slot_visible := [false, false, false]
	var slot_character := ["", "", ""]
	var background_visible: bool = false
	var music_playing: bool = false

	for i in range(scripts.size()):
		var entry_any: Variant = scripts[i]
		if typeof(entry_any) != TYPE_DICTIONARY:
			errors.append("剧情节「%s」第%d个脚本块结构无效（不是Dictionary）。" % [episode_title, i + 1])
			continue
		var entry: Dictionary = entry_any as Dictionary

		var type_any: Variant = entry.get("type", -1)
		var block_type: int = -1
		if typeof(type_any) == TYPE_INT or typeof(type_any) == TYPE_FLOAT:
			block_type = int(type_any)
		elif typeof(type_any) == TYPE_STRING:
			var type_str := str(type_any).strip_edges()
			if type_str.is_valid_int():
				block_type = int(type_str)
			else:
				errors.append("剧情节「%s」第%d个脚本块：脚本块类型无效（%s）。" % [episode_title, i + 1, type_str])
				continue
		else:
			errors.append("剧情节「%s」第%d个脚本块：脚本块类型无效。" % [episode_title, i + 1])
			continue

		if block_type < 0 or block_type > BlockType.CHARACTER_DARK_3:
			errors.append("剧情节「%s」第%d个脚本块：脚本块类型超出范围（%d）。" % [episode_title, i + 1, block_type])
			continue
		var params_any: Variant = entry.get("params", {})
		var params: Dictionary = params_any as Dictionary if typeof(params_any) == TYPE_DICTIONARY else {}

		var prefix := "剧情节「%s」第%d个脚本块：" % [episode_title, i + 1]

		match block_type:
			BlockType.TEXT_ONLY:
				var text: String = str(params.get("text", ""))
				if text.is_empty():
					errors.append(prefix + "文本内容不能为空。")
					continue

			BlockType.DIALOG:
				var text: String = str(params.get("text", ""))
				var speaker: String = str(params.get("speaker", ""))
				if text.is_empty():
					errors.append(prefix + "对话内容不能为空。")
					continue
				if speaker.is_empty():
					errors.append(prefix + "说话人不能为空。")
					continue
				if speaker.length() > 10:
					errors.append(prefix + "说话人名称不能超过10个字符。")
					continue

			BlockType.SHOW_CHARACTER_1, BlockType.SHOW_CHARACTER_2, BlockType.SHOW_CHARACTER_3:
				var slot := 1
				if block_type == BlockType.SHOW_CHARACTER_2:
					slot = 2
				elif block_type == BlockType.SHOW_CHARACTER_3:
					slot = 3

				var character_name: String = str(params.get("character_name", "")).strip_edges()
				if character_name.is_empty():
					errors.append(prefix + "角色名称不能为空（请从资源列表选择）。")
					continue
				if not _packaging_character_exists(project_root, character_name):
					errors.append(prefix + "角色资源不存在：%s（请从资源列表选择）。" % character_name)
					continue

				# 基础校验：x_position 必须在 0-1 之间
				var x_any: Variant = params.get("x_position", 0.0)
				var x_pos: float = 0.0
				if typeof(x_any) == TYPE_STRING:
					x_pos = (x_any as String).to_float()
				else:
					x_pos = float(x_any)
				if is_nan(x_pos) or is_inf(x_pos) or x_pos < 0.0 or x_pos > 1.0:
					errors.append(prefix + "X位置必须在0-1之间。")
					continue

				var expression_text: String = str(params.get("expression", "")).strip_edges()
				if not expression_text.is_empty():
					var expressions: Array[String] = _packaging_get_character_expressions(project_root, character_name)
					if not expressions.has(expression_text):
						errors.append(prefix + "表情不存在：%s（角色：%s）。" % [expression_text, character_name])
						continue

				slot_visible[slot - 1] = true
				slot_character[slot - 1] = character_name

			BlockType.HIDE_CHARACTER_1, BlockType.HIDE_CHARACTER_2, BlockType.HIDE_CHARACTER_3:
				var slot := 1
				if block_type == BlockType.HIDE_CHARACTER_2:
					slot = 2
				elif block_type == BlockType.HIDE_CHARACTER_3:
					slot = 3
				if not bool(slot_visible[slot - 1]) or str(slot_character[slot - 1]).is_empty():
					errors.append(prefix + "必须先显示角色%d（且未隐藏）才能隐藏。" % slot)
					continue
				slot_visible[slot - 1] = false
				slot_character[slot - 1] = ""

			BlockType.HIDE_ALL_CHARACTERS:
				var any_visible := false
				for s in slot_visible:
					if bool(s):
						any_visible = true
						break
				if not any_visible:
					errors.append(prefix + "至少显示一个角色才能隐藏所有角色。")
					continue
				slot_visible = [false, false, false]
				slot_character = ["", "", ""]

			BlockType.EXPRESSION, BlockType.CHANGE_EXPRESSION_1, BlockType.CHANGE_EXPRESSION_2, BlockType.CHANGE_EXPRESSION_3:
				var slot := 1
				if block_type == BlockType.CHANGE_EXPRESSION_2:
					slot = 2
				elif block_type == BlockType.CHANGE_EXPRESSION_3:
					slot = 3
				if not bool(slot_visible[slot - 1]) or str(slot_character[slot - 1]).is_empty():
					errors.append(prefix + "必须先显示角色%d（且未隐藏）才能切换表情。" % slot)
					continue
				var expression_text: String = str(params.get("expression", "")).strip_edges()
				if expression_text.is_empty():
					errors.append(prefix + "表情不能为空。")
					continue
				var character_name: String = str(slot_character[slot - 1])
				var expressions: Array[String] = _packaging_get_character_expressions(project_root, character_name)
				if not expressions.has(expression_text):
					errors.append(prefix + "表情不存在：%s（角色：%s）。" % [expression_text, character_name])
					continue

			BlockType.CHARACTER_LIGHT_1, BlockType.CHARACTER_LIGHT_2, BlockType.CHARACTER_LIGHT_3, BlockType.CHARACTER_DARK_1, BlockType.CHARACTER_DARK_2, BlockType.CHARACTER_DARK_3:
				var slot := 1
				if block_type in [BlockType.CHARACTER_LIGHT_2, BlockType.CHARACTER_DARK_2]:
					slot = 2
				elif block_type in [BlockType.CHARACTER_LIGHT_3, BlockType.CHARACTER_DARK_3]:
					slot = 3
				if not bool(slot_visible[slot - 1]) or str(slot_character[slot - 1]).is_empty():
					errors.append(prefix + "必须先显示角色%d（且未隐藏）才能变更明暗。" % slot)
					continue

				# 基础校验：duration 必须是 >=0 的有效数字
				var duration_any: Variant = params.get("duration", 0.35)
				var duration: float = 0.0
				if typeof(duration_any) == TYPE_STRING:
					duration = (duration_any as String).to_float()
				else:
					duration = float(duration_any)
				if is_nan(duration) or is_inf(duration) or duration < 0.0:
					errors.append(prefix + "时长必须是>=0的有效数字。")
					continue

				if block_type in [BlockType.CHARACTER_LIGHT_1, BlockType.CHARACTER_LIGHT_2, BlockType.CHARACTER_LIGHT_3]:
					var expression_text: String = str(params.get("expression", "")).strip_edges()
					if not expression_text.is_empty():
						var character_name: String = str(slot_character[slot - 1])
						var expressions: Array[String] = _packaging_get_character_expressions(project_root, character_name)
						if not expressions.has(expression_text):
							errors.append(prefix + "表情不存在：%s（角色：%s）。" % [expression_text, character_name])
							continue

			BlockType.MOVE_CHARACTER_1_LEFT, BlockType.MOVE_CHARACTER_2_LEFT, BlockType.MOVE_CHARACTER_3_LEFT:
				var slot := 1
				if block_type == BlockType.MOVE_CHARACTER_2_LEFT:
					slot = 2
				elif block_type == BlockType.MOVE_CHARACTER_3_LEFT:
					slot = 3
				if not bool(slot_visible[slot - 1]) or str(slot_character[slot - 1]).is_empty():
					errors.append(prefix + "必须先显示角色%d（且未隐藏）才能移动位置。" % slot)
					continue

				# 基础校验：to_xalign / duration
				var to_xalign_any: Variant = params.get("to_xalign", -0.25)
				var to_xalign: float = 0.0
				if typeof(to_xalign_any) == TYPE_STRING:
					to_xalign = (to_xalign_any as String).to_float()
				else:
					to_xalign = float(to_xalign_any)
				if is_nan(to_xalign) or is_inf(to_xalign):
					errors.append(prefix + "目标X位置必须是有效数字。")
					continue

				var duration_any: Variant = params.get("duration", 0.3)
				var duration: float = 0.0
				if typeof(duration_any) == TYPE_STRING:
					duration = (duration_any as String).to_float()
				else:
					duration = float(duration_any)
				if is_nan(duration) or is_inf(duration) or duration < 0.0:
					errors.append(prefix + "时长必须是>=0的有效数字。")
					continue

				var expression_text: String = str(params.get("expression", "")).strip_edges()
				if not expression_text.is_empty():
					var character_name: String = str(slot_character[slot - 1])
					var expressions: Array[String] = _packaging_get_character_expressions(project_root, character_name)
					if not expressions.has(expression_text):
						errors.append(prefix + "表情不存在：%s（角色：%s）。" % [expression_text, character_name])
						continue

			BlockType.BACKGROUND, BlockType.SHOW_BACKGROUND:
				var bg_path: String = str(params.get("background_path", "")).strip_edges()
				if bg_path.is_empty():
					errors.append(prefix + "背景路径不能为空（请从资源列表选择）。")
					continue
				if block_type == BlockType.SHOW_BACKGROUND:
					var fade_any: Variant = params.get("fade_time", 0.0)
					var fade_time: float = 0.0
					if typeof(fade_any) == TYPE_STRING:
						fade_time = (fade_any as String).to_float()
					else:
						fade_time = float(fade_any)
					if is_nan(fade_time) or is_inf(fade_time) or fade_time < 0.0:
						errors.append(prefix + "渐变时间不能小于0。")
						continue
				if not _packaging_is_valid_background_path(project_root, bg_path):
					errors.append(prefix + "背景资源不合法/不存在：%s（请从资源列表选择）。" % bg_path)
					continue
				background_visible = true

			BlockType.HIDE_BACKGROUND, BlockType.HIDE_BACKGROUND_FADE:
				if not background_visible:
					errors.append(prefix + "必须先显示背景才能隐藏背景。")
					continue
				background_visible = false

			BlockType.MUSIC, BlockType.CHANGE_MUSIC:
				var music_path: String = str(params.get("music_path", "")).strip_edges()
				if music_path.is_empty():
					errors.append(prefix + "音乐路径不能为空（请从资源列表选择）。")
					continue
				if not _packaging_is_valid_music_path(project_root, music_path):
					errors.append(prefix + "音乐资源不合法/不存在：%s（请从资源列表选择）。" % music_path)
					continue
				music_playing = true

			BlockType.STOP_MUSIC:
				if not music_playing:
					errors.append(prefix + "必须先播放/切换音乐才能停止音乐。")
					continue
				music_playing = false

			_:
				# 其他类型不做额外校验
				pass

	return errors

func _packaging_character_exists(project_root: String, character_name: String) -> bool:
	return _packaging_get_character_scene(project_root, character_name) != null

func _packaging_get_character_scene(project_root: String, character_name: String) -> PackedScene:
	var cache_key := project_root + "|" + character_name
	if _packaging_character_scene_cache.has(cache_key):
		var cached: Variant = _packaging_character_scene_cache[cache_key]
		return cached as PackedScene

	var scene_path := "res://scenes/character/" + character_name + ".tscn"
	if ResourceLoader.exists(scene_path):
		var scene := load(scene_path) as PackedScene
		_packaging_character_scene_cache[cache_key] = scene
		return scene

	# 尝试自定义角色：user://mod_projects/<project>/characters/<name>.tscn
	var custom_path := project_root + "/characters/" + character_name + ".tscn"
	if FileAccess.file_exists(custom_path):
		var custom_scene := load(custom_path) as PackedScene
		_packaging_character_scene_cache[cache_key] = custom_scene
		return custom_scene

	_packaging_character_scene_cache[cache_key] = null
	return null

func _packaging_get_character_expressions(project_root: String, character_name: String) -> Array[String]:
	var cache_key := project_root + "|" + character_name
	if _packaging_character_expressions_cache.has(cache_key):
		var cached: Variant = _packaging_character_expressions_cache[cache_key]
		if typeof(cached) == TYPE_ARRAY:
			return cached as Array[String]
		return []

	var scene := _packaging_get_character_scene(project_root, character_name)
	if scene == null:
		_packaging_character_expressions_cache[cache_key] = []
		return []

	var instance := scene.instantiate()
	if instance == null:
		_packaging_character_expressions_cache[cache_key] = []
		return []

	var unique: Dictionary = {}
	var expressions: Array[String] = []
	var raw: Variant = instance.get("expression_list")
	if typeof(raw) == TYPE_ARRAY:
		for entry in (raw as Array):
			if typeof(entry) == TYPE_STRING:
				var expression_name := (entry as String).strip_edges()
				if not expression_name.is_empty() and not unique.has(expression_name):
					unique[expression_name] = true
					expressions.append(expression_name)

	instance.free()
	_packaging_character_expressions_cache[cache_key] = expressions
	return expressions

func _packaging_dir_has_any_entry(dir_path: String) -> bool:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return false
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		if entry_name != "." and entry_name != "..":
			dir.list_dir_end()
			return true
		entry_name = dir.get_next()
	dir.list_dir_end()
	return false

func _packaging_resource_exists(path: String) -> bool:
	if path.is_empty():
		return false
	if path.begins_with("res://"):
		return ResourceLoader.exists(path) or ResourceLoader.exists(path + ".remap")
	if path.begins_with("user://"):
		return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".remap")
	return FileAccess.file_exists(path)

func _packaging_is_valid_background_path(project_root: String, input_path: String) -> bool:
	var raw := input_path.strip_edges()
	if raw.is_empty():
		return false

	# 支持 mod 相对路径（与 mod_config.json 一致）
	if raw.begins_with("images/"):
		return FileAccess.file_exists(project_root + "/" + raw)

	# 内置资源：只允许背景资源目录内的路径
	var base_dirs: Array[String] = []
	var bg_dir_new := "res://assets/images/bg/"
	var bg_dir_old := "res://assets/background/"
	if _packaging_dir_has_any_entry(bg_dir_new):
		base_dirs.append(bg_dir_new)
	if _packaging_dir_has_any_entry(bg_dir_old):
		base_dirs.append(bg_dir_old)
	if base_dirs.is_empty():
		base_dirs = [bg_dir_new, bg_dir_old]

	if raw.begins_with("res://"):
		for base_dir in base_dirs:
			if raw.begins_with(base_dir) and _packaging_resource_exists(raw):
				return true
		return false

	# 支持用户输入文件名或相对路径（与资源列表显示一致）
	for base_dir in base_dirs:
		var candidate := base_dir + raw
		if _packaging_resource_exists(candidate):
			return true
	return false

func _packaging_is_valid_music_path(project_root: String, input_path: String) -> bool:
	var raw := input_path.strip_edges()
	if raw.is_empty():
		return false

	# 支持 mod 相对路径（与 mod_config.json 一致）
	if raw.begins_with("music/"):
		return FileAccess.file_exists(project_root + "/" + raw)

	var base_dir := "res://assets/audio/music/"
	if raw.begins_with("res://"):
		if not raw.begins_with(base_dir):
			return false
		return _packaging_resource_exists(raw)

	var candidate := base_dir + raw
	return _packaging_resource_exists(candidate)

func _get_mod_folder_name_for_project(project_name: String) -> String:
	var config := _ensure_mod_config(project_name)
	var mod_id: String = str(config.get("mod_id", project_name)).strip_edges()
	var folder := _sanitize_folder_name(mod_id)
	if folder.is_empty():
		folder = _sanitize_folder_name(project_name)
	return folder

func _export_project_zip(project_name: String, zip_path: String) -> int:
	var folder := _get_mod_folder_name_for_project(project_name)
	if folder.is_empty():
		return ERR_INVALID_DATA

	var temp_root := "user://__mod_export_tmp"
	if DirAccess.open(temp_root) != null:
		_delete_directory_recursive(temp_root)
	var dir := DirAccess.open("user://")
	if dir:
		dir.make_dir("__mod_export_tmp")

	var err := _build_mod_folder(project_name, temp_root, folder)
	if err != OK:
		return err

	err = _zip_folder(temp_root + "/" + folder, zip_path, folder)
	_delete_directory_recursive(temp_root)
	return err

func _zip_folder(source_folder: String, zip_path: String, root_in_zip: String) -> int:
	if not ClassDB.class_exists("ZIPPacker"):
		return ERR_UNAVAILABLE
	var zip: Object = ClassDB.instantiate("ZIPPacker")
	if zip == null:
		return ERR_UNAVAILABLE
	var err: int = int(zip.call("open", zip_path))
	if err != OK:
		return err

	var files: Array[String] = []
	_collect_files_recursive(source_folder, files)
	for file_path in files:
		var rel := file_path.substr(source_folder.length() + 1).replace("\\", "/")
		var inside := ("%s/%s" % [root_in_zip, rel]).replace("\\", "/")
		var s_err: int = int(zip.call("start_file", inside))
		if s_err != OK:
			zip.call("close")
			return s_err
		var bytes := _read_all_bytes(file_path)
		var w_err: int = int(zip.call("write_file", bytes))
		if w_err != OK:
			if zip.has_method("close_file"):
				zip.call("close_file")
			zip.call("close")
			return w_err
		if zip.has_method("close_file"):
			zip.call("close_file")

	zip.call("close")
	return OK

func _collect_files_recursive(path: String, out_files: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		if entry_name == "." or entry_name == "..":
			entry_name = dir.get_next()
			continue
		var full := path + "/" + entry_name
		if dir.current_is_dir():
			_collect_files_recursive(full, out_files)
		else:
			out_files.append(full)
		entry_name = dir.get_next()
	dir.list_dir_end()

func _read_all_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var byte_count: int = f.get_length()
	var bytes: PackedByteArray = f.get_buffer(byte_count)
	f.close()
	return bytes

func _build_mod_folder(project_name: String, out_root: String, mod_folder: String) -> int:
	var out_mod_root := out_root + "/" + mod_folder
	var root_dir := DirAccess.open(out_root)
	if root_dir == null:
		return ERR_CANT_OPEN
	if not root_dir.dir_exists(mod_folder):
		root_dir.make_dir(mod_folder)

	# 复制 mod_config.json
	var config := _ensure_mod_config(project_name)
	var normalized_episodes: Dictionary = {}
	var src_episodes: Dictionary = config.get("episodes", {})
	if typeof(src_episodes) == TYPE_DICTIONARY:
		for episode_title in (src_episodes as Dictionary).keys():
			var episode_idx := _parse_episode_index(str(episode_title))
			if episode_idx <= 0:
				continue
			normalized_episodes[str(episode_title)] = "story/ep%02d.tscn" % episode_idx
	config["episodes"] = normalized_episodes
	_save_json_file(out_mod_root + "/mod_config.json", config)

	# icon.png：优先使用工程预览图
	var preview_abs := ProjectSettings.globalize_path(_get_project_root(project_name) + "/" + PROJECT_PREVIEW_FILE)
	var icon_path: String = out_mod_root + "/icon.png"
	if FileAccess.file_exists(preview_abs):
		_copy_file(preview_abs, icon_path)
	else:
		# 注意：导出版本中 `Image.load("res://xxx.png")` 可能找不到源文件（资源被导入/重映射），
		# 这里改为按资源加载 Texture2D，再从 Texture2D 获取 Image。
		var tex := _load_texture_any(DEFAULT_PREVIEW_IMAGE)
		if tex != null:
			var img: Image = tex.get_image()
			if img != null and not img.is_empty():
				var thumb := _make_cover_thumbnail(img, PROJECT_PREVIEW_SIZE)
				if not thumb.is_empty():
					thumb.save_png(icon_path)

	# 复制可选资源目录（若存在）
	for folder_name in ["music", "images", "characters"]:
		var src: String = _get_project_root(project_name) + "/" + folder_name
		if DirAccess.open(src) != null:
			_copy_directory_recursive(src, out_mod_root + "/" + folder_name)

	# 导出剧情节到 story/
	var story_dir := DirAccess.open(out_mod_root)
	if story_dir:
		story_dir.make_dir("story")

	for episode_title in normalized_episodes.keys():
		var episode_idx := _parse_episode_index(str(episode_title))
		if episode_idx <= 0:
			continue

		var out_ep_name := "ep%02d" % episode_idx
		var src_scene_rel := ""
		if typeof(src_episodes) == TYPE_DICTIONARY:
			src_scene_rel = str((src_episodes as Dictionary).get(episode_title, ""))

		var episode_project := ""
		var root_candidate := _get_project_root(project_name) + "/project.json"
		var from_path := _extract_ep_name_from_path(src_scene_rel)
		var folder := from_path if not from_path.is_empty() else out_ep_name

		# 优先尝试根目录（兼容旧结构/导出结构）；不存在时再尝试 episodes/<ep>/project.json
		if FileAccess.file_exists(root_candidate) and (src_scene_rel.begins_with("export/") or episode_idx == 1):
			episode_project = root_candidate
		else:
			var candidate := _get_project_root(project_name) + "/episodes/%s/project.json" % folder
			if FileAccess.file_exists(candidate):
				episode_project = candidate
			elif FileAccess.file_exists(root_candidate):
				episode_project = root_candidate
			else:
				# 兼容老结构：episode 文件夹可能在根目录下
				candidate = _get_project_root(project_name) + "/%s/project.json" % folder
				if FileAccess.file_exists(candidate):
					episode_project = candidate

		var episode_data := _load_json_file(episode_project) if not episode_project.is_empty() else {}
		var scripts_any: Variant = episode_data.get("scripts", [])
		var scripts: Array = scripts_any as Array

		var gd_code := _generate_story_gdscript(scripts)
		var gd_path := out_mod_root + "/story/%s.gd" % out_ep_name
		_write_text_file(gd_path, gd_code)
		var tscn_code := _generate_story_scene(mod_folder, out_ep_name)
		var tscn_path := out_mod_root + "/story/%s.tscn" % out_ep_name
		_write_text_file(tscn_path, tscn_code)
	return OK

func _extract_ep_name_from_path(path: String) -> String:
	if path.is_empty():
		return ""
	var parts := path.replace("\\", "/").split("/")
	for part in parts:
		var s := str(part)
		if s.begins_with("ep") and s.length() == 4 and s.substr(2, 2).is_valid_int():
			return s
	var base := path.get_file().get_basename()
	if base.begins_with("ep") and base.length() == 4 and base.substr(2, 2).is_valid_int():
		return base
	return ""

func _copy_file(from_abs: String, to_path: String) -> void:
	var bytes := _read_all_bytes(from_abs)
	var f := FileAccess.open(to_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(bytes)
	f.close()

func _copy_directory_recursive(from_path: String, to_path: String) -> void:
	var dir := DirAccess.open(from_path)
	if dir == null:
		return
	var out_dir := DirAccess.open(to_path.get_base_dir())
	if out_dir:
		out_dir.make_dir_recursive(to_path.get_file())
	var dst_dir := DirAccess.open(to_path)
	if dst_dir == null:
		return
	dir.list_dir_begin()
	var entry_name: String = str(dir.get_next())
	while entry_name != "":
		if entry_name == "." or entry_name == "..":
			entry_name = str(dir.get_next())
			continue
		var src: String = from_path + "/" + entry_name
		var dst: String = to_path + "/" + entry_name
		if dir.current_is_dir():
			_copy_directory_recursive(src, dst)
		else:
			var bytes := _read_all_bytes(src)
			var f := FileAccess.open(dst, FileAccess.WRITE)
			if f:
				f.store_buffer(bytes)
				f.close()
		entry_name = str(dir.get_next())
	dir.list_dir_end()

func _write_text_file(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(content)
	f.close()

func _generate_story_scene(mod_folder: String, episode_name: String) -> String:
	var scene := "[gd_scene load_steps=3 format=3]\n\n"
	scene += "[ext_resource type=\"Script\" path=\"res://mods/%s/story/%s.gd\" id=\"1_script\"]\n" % [mod_folder, episode_name]
	scene += "[ext_resource type=\"PackedScene\" path=\"res://scenes/dialog/NovelInterface.tscn\" id=\"2_novel\"]\n\n"
	scene += "[node name=\"Story\" type=\"Node2D\"]\n"
	scene += "script = ExtResource(\"1_script\")\n\n"
	scene += "[node name=\"NovelInterface\" parent=\".\" instance=ExtResource(\"2_novel\")]\n"
	return scene

func _generate_story_gdscript(scripts: Array) -> String:
	var code := "extends Node2D\n\n"
	code += "@onready var novel_interface = $NovelInterface\n\n"
	code += "func _ready():\n"
	code += "\tif novel_interface.has_method(\"wait_until_initialized\"):\n"
	code += "\t\tawait novel_interface.wait_until_initialized()\n"
	code += "\telse:\n"
	code += "\t\tawait get_tree().process_frame\n"
	code += "\t\tawait get_tree().process_frame\n"
	code += "\tnovel_interface.scene_completed.connect(_on_scene_completed)\n"
	code += "\t_start_story()\n\n"
	code += "func _start_story():\n"
	var wrote_any: bool = false

	for i in range(scripts.size()):
		var entry_any: Variant = scripts[i]
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var block_type: int = int(entry.get("type", 0))
		var params_any: Variant = entry.get("params", {})
		var params: Dictionary = params_any as Dictionary

		match block_type:
			BlockType.TEXT_ONLY:
				var text: String = str(params.get("text", ""))
				code += "\tawait novel_interface.show_text_only(\"%s\")\n" % text.c_escape()
				wrote_any = true
			BlockType.DIALOG:
				var speaker: String = str(params.get("speaker", ""))
				var text: String = str(params.get("text", ""))
				code += "\tawait novel_interface.show_dialog(\"%s\", \"%s\")\n" % [text.c_escape(), speaker.c_escape()]
				wrote_any = true
			BlockType.SHOW_CHARACTER_1:
				var char_name: String = str(params.get("character_name", ""))
				var expression: String = str(params.get("expression", ""))
				var x_pos: float = float(params.get("x_position", 0.0))
				code += "\tnovel_interface.show_character(\"%s\", \"%s\", %.2f)\n" % [char_name.c_escape(), expression.c_escape(), x_pos]
				wrote_any = true
			BlockType.HIDE_CHARACTER_1:
				code += "\tawait novel_interface.hide_character()\n"
				wrote_any = true
			BlockType.SHOW_CHARACTER_2:
				var char_name: String = str(params.get("character_name", ""))
				var expression: String = str(params.get("expression", ""))
				var x_pos: float = float(params.get("x_position", 0.0))
				code += "\tnovel_interface.show_2nd_character(\"%s\", \"%s\", %.2f)\n" % [char_name.c_escape(), expression.c_escape(), x_pos]
				wrote_any = true
			BlockType.HIDE_CHARACTER_2:
				code += "\tawait novel_interface.hide_2nd_character()\n"
				wrote_any = true
			BlockType.SHOW_CHARACTER_3:
				var char_name: String = str(params.get("character_name", ""))
				var expression: String = str(params.get("expression", ""))
				var x_pos: float = float(params.get("x_position", 0.0))
				code += "\tnovel_interface.show_3rd_character(\"%s\", \"%s\", %.2f)\n" % [char_name.c_escape(), expression.c_escape(), x_pos]
				wrote_any = true
			BlockType.HIDE_CHARACTER_3:
				code += "\tawait novel_interface.hide_3rd_character()\n"
				wrote_any = true
			BlockType.MOVE_CHARACTER_1_LEFT:
				var to_xalign: float = float(params.get("to_xalign", -0.25))
				var duration: float = float(params.get("duration", 0.3))
				var enable_bc: bool = bool(params.get("enable_brightness_change", true))
				var expression: String = str(params.get("expression", ""))
				code += "\tawait novel_interface.character_move_left(%.4f, %.4f, %s, \"%s\")\n" % [to_xalign, duration, str(enable_bc).to_lower(), expression.c_escape()]
				wrote_any = true
			BlockType.MOVE_CHARACTER_2_LEFT:
				var to_xalign: float = float(params.get("to_xalign", -0.25))
				var duration: float = float(params.get("duration", 0.3))
				var enable_bc: bool = bool(params.get("enable_brightness_change", true))
				var expression: String = str(params.get("expression", ""))
				code += "\tawait novel_interface.character_2nd_move_left(%.4f, %.4f, %s, \"%s\")\n" % [to_xalign, duration, str(enable_bc).to_lower(), expression.c_escape()]
				wrote_any = true
			BlockType.MOVE_CHARACTER_3_LEFT:
				var to_xalign: float = float(params.get("to_xalign", -0.25))
				var duration: float = float(params.get("duration", 0.3))
				var enable_bc: bool = bool(params.get("enable_brightness_change", true))
				var expression: String = str(params.get("expression", ""))
				code += "\tawait novel_interface.character_3rd_move_left(%.4f, %.4f, %s, \"%s\")\n" % [to_xalign, duration, str(enable_bc).to_lower(), expression.c_escape()]
				wrote_any = true
			BlockType.HIDE_ALL_CHARACTERS:
				code += "\tawait novel_interface.hide_all_characters()\n"
				wrote_any = true
			BlockType.BACKGROUND:
				var bg_path: String = str(params.get("background_path", ""))
				code += "\tawait novel_interface.change_background(\"%s\")\n" % bg_path.c_escape()
				wrote_any = true
			BlockType.SHOW_BACKGROUND:
				var bg_path: String = str(params.get("background_path", ""))
				var fade_time: float = float(params.get("fade_time", 0.0))
				code += "\tawait novel_interface.show_background(\"%s\", %.2f)\n" % [bg_path.c_escape(), fade_time]
				wrote_any = true
			BlockType.HIDE_BACKGROUND:
				code += "\tawait novel_interface.hide_background()\n"
				wrote_any = true
			BlockType.HIDE_BACKGROUND_FADE:
				code += "\tawait novel_interface.hide_background_with_fade()\n"
				wrote_any = true
			BlockType.MUSIC:
				var music_path: String = str(params.get("music_path", ""))
				code += "\tnovel_interface.play_music(\"%s\")\n" % music_path.c_escape()
				wrote_any = true
			BlockType.CHANGE_MUSIC:
				var music_path: String = str(params.get("music_path", ""))
				code += "\tawait novel_interface.change_music(\"%s\")\n" % music_path.c_escape()
				wrote_any = true
			BlockType.STOP_MUSIC:
				code += "\tnovel_interface.stop_music()\n"
				code += "\tawait get_tree().process_frame\n"
				wrote_any = true
			BlockType.EXPRESSION, BlockType.CHANGE_EXPRESSION_1:
				var expression: String = str(params.get("expression", "")).strip_edges()
				if not expression.is_empty():
					code += "\tnovel_interface.change_expression(\"%s\")\n" % expression.c_escape()
				code += "\tawait get_tree().process_frame\n"
				wrote_any = true
			BlockType.CHANGE_EXPRESSION_2:
				var expression: String = str(params.get("expression", "")).strip_edges()
				if not expression.is_empty():
					code += "\tnovel_interface.change_2nd_expression(\"%s\")\n" % expression.c_escape()
				code += "\tawait get_tree().process_frame\n"
				wrote_any = true
			BlockType.CHANGE_EXPRESSION_3:
				var expression: String = str(params.get("expression", "")).strip_edges()
				if not expression.is_empty():
					code += "\tnovel_interface.change_3rd_expression(\"%s\")\n" % expression.c_escape()
				code += "\tawait get_tree().process_frame\n"
				wrote_any = true
			BlockType.CHARACTER_LIGHT_1:
				var duration: float = float(params.get("duration", 0.35))
				var expression: String = str(params.get("expression", ""))
				code += "\tawait novel_interface.character_light(%.4f, \"%s\")\n" % [duration, expression.c_escape()]
				wrote_any = true
			BlockType.CHARACTER_LIGHT_2:
				var duration: float = float(params.get("duration", 0.35))
				var expression: String = str(params.get("expression", ""))
				code += "\tawait novel_interface.character_2nd_light(%.4f, \"%s\")\n" % [duration, expression.c_escape()]
				wrote_any = true
			BlockType.CHARACTER_LIGHT_3:
				var duration: float = float(params.get("duration", 0.35))
				var expression: String = str(params.get("expression", ""))
				code += "\tawait novel_interface.character_3rd_light(%.4f, \"%s\")\n" % [duration, expression.c_escape()]
				wrote_any = true
			BlockType.CHARACTER_DARK_1:
				code += "\tawait novel_interface.character_dark()\n"
				wrote_any = true
			BlockType.CHARACTER_DARK_2:
				code += "\tawait novel_interface.character_2nd_dark()\n"
				wrote_any = true
			BlockType.CHARACTER_DARK_3:
				code += "\tawait novel_interface.character_3rd_dark()\n"
				wrote_any = true
			_:
				code += "\tawait get_tree().process_frame\n"
				wrote_any = true

	if not wrote_any:
		code += "\tpass\n"

	code += "\n\t# 调用剧情结束函数（返回到主界面/列表时需要）\n"
	code += "\tif novel_interface.has_method(\"end_story_episode\"):\n"
	code += "\t\tawait novel_interface.end_story_episode(0.5)\n"
	code += "\telse:\n"
	code += "\t\tawait get_tree().process_frame\n"

	code += "\nfunc _on_scene_completed():\n"
	code += "\tprint(\"Story completed\")\n"
	return code

func _on_project_title_changed(new_text: String) -> void:
	if _is_loading_details:
		return
	if selected_project.is_empty():
		return
	if _is_sanitizing_text:
		return

	var sanitized := _sanitize_project_title(new_text)
	if project_title_input and project_title_input.text != sanitized:
		_is_sanitizing_text = true
		project_title_input.text = sanitized
		_is_sanitizing_text = false

	var config := _ensure_mod_config(selected_project)
	config["title"] = sanitized
	_touch_config(selected_project, config)

func _on_project_desc_changed() -> void:
	if _is_loading_details:
		return
	if selected_project.is_empty():
		return
	if project_desc_input == null:
		return
	if _is_sanitizing_text:
		return

	var sanitized := _sanitize_project_desc(project_desc_input.text)
	if project_desc_input.text != sanitized:
		_is_sanitizing_text = true
		project_desc_input.text = sanitized
		_is_sanitizing_text = false

	var config := _ensure_mod_config(selected_project)
	config["description"] = sanitized
	_touch_config(selected_project, config)

func _parse_episode_index(title: String) -> int:
	if not (title.begins_with("第") and title.ends_with("节")):
		return -1
	var num_str := title.substr(1, title.length() - 2)
	if not num_str.is_valid_int():
		return -1
	return int(num_str)

func _episode_folder_from_title(title: String) -> String:
	var idx := _parse_episode_index(title)
	if idx <= 0:
		return ""
	return "ep%02d" % idx

func _on_add_episode_pressed() -> void:
	if selected_project.is_empty():
		return
	var config := _ensure_mod_config(selected_project)
	var episodes: Dictionary = config.get("episodes", {})
	if typeof(episodes) != TYPE_DICTIONARY:
		episodes = {}
		config["episodes"] = episodes

	_pending_create_episode_folder = _allocate_episode_folder(episodes.size() + 1)
	_pending_rename_episode_title = ""
	if episode_rename_dialog:
		episode_rename_dialog.title = "新建剧情节"
	if episode_rename_input:
		episode_rename_input.text = ""
	_clear_episode_rename_error()
	if episode_rename_dialog:
		episode_rename_dialog.popup_centered()

func _add_episode_internal(config: Dictionary, episodes: Dictionary, title: String, folder: String) -> void:
	var episode_root := _get_project_root(selected_project) + "/episodes/" + folder
	var dir := DirAccess.open(_get_project_root(selected_project))
	if dir:
		dir.make_dir_recursive("episodes/" + folder)

	var episode_config := {
		"project_name": "%s - %s" % [str(config.get("title", selected_project)), title],
		"created_time": Time.get_datetime_string_from_system(),
		"scripts": []
	}
	_save_json_file(episode_root + "/project.json", episode_config)

	episodes[title] = "episodes/%s" % folder
	_touch_config(selected_project, config)
	_reload_episode_list(config)
	_selected_episode_title = title
	_selected_episode_path = str(episodes.get(title, ""))
	_refresh_episode_rows_ui()
	_update_action_buttons_state()

func _on_episode_delete_pressed(title: String) -> void:
	if selected_project.is_empty():
		return
	_pending_delete_episode_title = title
	if episode_delete_confirm_dialog:
		episode_delete_confirm_dialog.dialog_text = '确定删除剧情节"%s"？此操作不可撤销。' % title
		episode_delete_confirm_dialog.popup_centered()
		return
	_on_episode_delete_confirmed()

func _on_episode_delete_confirmed() -> void:
	if selected_project.is_empty() or _pending_delete_episode_title.is_empty():
		return

	var config := _ensure_mod_config(selected_project)
	var episodes: Dictionary = config.get("episodes", {})
	if typeof(episodes) != TYPE_DICTIONARY:
		_pending_delete_episode_title = ""
		return

	var old_title := _pending_delete_episode_title
	_pending_delete_episode_title = ""
	var path := str(episodes.get(old_title, ""))
	episodes.erase(old_title)

	# 尝试删除对应目录（若存在）
	var folder := _extract_ep_name_from_path(path)
	if folder.is_empty():
		folder = _episode_folder_from_title(old_title)
	if not folder.is_empty():
		_delete_directory_recursive(_get_project_root(selected_project) + "/episodes/" + folder)

	_touch_config(selected_project, config)
	_reload_episode_list(config)
	if episode_list and episode_list.get_child_count() > 0:
		var first_panel := episode_list.get_child(0) as PanelContainer
		var row := first_panel.get_child(0) as HBoxContainer if first_panel else null
		var label := row.get_child(0) as Label if row else null
		if label:
			var new_episodes: Dictionary = config.get("episodes", {})
			if typeof(new_episodes) == TYPE_DICTIONARY:
				_selected_episode_title = label.text
				_selected_episode_path = str((new_episodes as Dictionary).get(_selected_episode_title, ""))
	_refresh_episode_rows_ui()
	_update_action_buttons_state()

func _on_episode_rename_pressed(title: String) -> void:
	if selected_project.is_empty():
		return
	_pending_rename_episode_title = title
	if episode_rename_input:
		episode_rename_input.text = title
	_clear_episode_rename_error()
	if episode_rename_dialog:
		episode_rename_dialog.title = "重命名剧情节"
		episode_rename_dialog.popup_centered()

func _on_episode_rename_confirmed() -> void:
	if selected_project.is_empty():
		return
	if episode_rename_input == null:
		return

	var new_title := _sanitize_episode_title(episode_rename_input.text)
	if new_title.is_empty():
		_show_episode_rename_error("剧情节名称不能为空")
		call_deferred("_reopen_episode_rename_dialog")
		return

	var config := _ensure_mod_config(selected_project)
	var episodes: Dictionary = config.get("episodes", {})
	if typeof(episodes) != TYPE_DICTIONARY:
		return

	# 新建模式：使用用户输入作为标题创建剧情节
	if not _pending_create_episode_folder.is_empty():
		if episodes.has(new_title):
			_show_episode_rename_error("剧情节名称已存在，请换一个")
			call_deferred("_reopen_episode_rename_dialog")
			return

		var folder := _pending_create_episode_folder
		_pending_create_episode_folder = ""
		_add_episode_internal(config, episodes, new_title, folder)
		if episode_rename_dialog:
			episode_rename_dialog.title = "重命名剧情节"
		_clear_episode_rename_error()
		return

	# 重命名模式
	if _pending_rename_episode_title.is_empty():
		return

	var old_title := _pending_rename_episode_title
	if new_title == old_title:
		_pending_rename_episode_title = ""
		_clear_episode_rename_error()
		return
	if episodes.has(new_title):
		_show_episode_rename_error("剧情节名称已存在，请换一个")
		call_deferred("_reopen_episode_rename_dialog")
		return

	var path := str(episodes.get(old_title, ""))

	# 保持原有顺序：按当前 UI 列表顺序重建 episodes 字典，仅替换 key。
	if episode_list:
		var ordered: Dictionary = {}
		for child in episode_list.get_children():
			var panel := child as PanelContainer
			if panel == null:
				continue
			var row := panel.get_child(0) as HBoxContainer
			var label := row.get_child(0) as Label if row else null
			if label == null:
				continue
			var t := label.text
			if t.is_empty():
				continue
			var key := new_title if t == old_title else t
			var value: String = path if t == old_title else str(episodes.get(t, ""))
			ordered[key] = value
		config["episodes"] = ordered
	else:
		episodes.erase(old_title)
		episodes[new_title] = path
	_pending_rename_episode_title = ""
	_selected_episode_title = new_title
	_selected_episode_path = path

	_touch_config(selected_project, config)
	_reload_episode_list(config)
	if typeof(config.get("episodes")) == TYPE_DICTIONARY:
		_selected_episode_path = str((config.get("episodes") as Dictionary).get(_selected_episode_title, ""))
	_refresh_episode_rows_ui()
	_update_action_buttons_state()

func _allocate_episode_folder(preferred_index: int) -> String:
	var base := "ep%02d" % max(1, preferred_index)
	var episodes_root := _get_project_root(selected_project) + "/episodes/" + base
	if DirAccess.open(episodes_root) == null:
		return base

	var i := 1
	while true:
		var candidate := "ep%02d" % i
		if DirAccess.open(_get_project_root(selected_project) + "/episodes/" + candidate) == null:
			return candidate
		i += 1
	return base

func _on_new_project_button_pressed():
	"""新建工程按钮点击"""
	project_name_input.text = ""
	_clear_new_project_error()
	new_project_dialog.visible = true
	new_project_dialog.popup_centered()

func _on_confirm_new_project():
	"""确认新建工程"""
	var project_name = project_name_input.text.strip_edges()

	if project_name.is_empty():
		_show_new_project_error("工程名称不能为空")
		return
	if not _is_valid_project_folder_name(project_name):
		_show_new_project_error("工程名称仅支持中文/英文/数字/下划线/短横线，长度不超过%d" % MAX_PROJECT_FOLDER_NAME_LENGTH)
		return

	_ensure_projects_root()

	# 检查工程名是否已存在
	var dir = DirAccess.open(PROJECTS_PATH)
	if not dir:
		_show_new_project_error("无法创建工程目录")
		return
	if dir.dir_exists(project_name):
		_show_new_project_error("工程已存在，请换一个名称")
		return

	# 创建工程文件夹
	dir.make_dir(project_name)

	# 创建章节配置文件（mod_config.json）+ 默认第1节
	var mod_config := _ensure_mod_config(project_name)
	var folder := "ep01"
	var episode_root := _get_project_root(project_name) + "/episodes/" + folder
	var root_dir := DirAccess.open(_get_project_root(project_name))
	if root_dir:
		root_dir.make_dir_recursive("episodes/" + folder)
	var episode_config := {
		"project_name": "%s - 第1节" % str(mod_config.get("title", project_name)),
		"created_time": Time.get_datetime_string_from_system(),
		"scripts": []
	}
	_save_json_file(episode_root + "/project.json", episode_config)
	var episodes: Dictionary = mod_config.get("episodes", {})
	if typeof(episodes) != TYPE_DICTIONARY:
		episodes = {}
	mod_config["episodes"] = episodes
	episodes["第1节"] = "episodes/%s" % folder
	_touch_config(project_name, mod_config)

	new_project_dialog.visible = false
	if search_input:
		search_input.text = ""
	_load_projects()
	print("创建工程成功: " + project_name)
	_select_project_and_show_details(project_name)

func _select_project_and_show_details(project_name: String) -> void:
	if project_name.is_empty():
		return
	if _is_transitioning or _is_exiting:
		return

	_on_project_selected(project_name)

	# 默认选中第1节，方便玩家直接继续操作（但不自动进入编辑器）
	if episode_list and episode_list.get_child_count() > 0:
		var first_panel := episode_list.get_child(0) as PanelContainer
		var row := first_panel.get_child(0) as HBoxContainer if first_panel else null
		var label := row.get_child(0) as Label if row else null
		if label:
			var config := _ensure_mod_config(project_name)
			var episodes: Dictionary = config.get("episodes", {})
			if typeof(episodes) == TYPE_DICTIONARY:
				var title := label.text
				_selected_episode_title = title
				_selected_episode_path = str((episodes as Dictionary).get(title, ""))
				_refresh_episode_rows_ui()
				_update_action_buttons_state()

func _on_cancel_new_project():
	"""取消新建工程"""
	new_project_dialog.visible = false

func _on_open_project_button_pressed():
	"""打开选中剧情节"""
	if selected_project.is_empty():
		return
	if _selected_episode_path.is_empty():
		push_error("请先选择一个剧情节")
		return

	var editor_scene = load(EDITOR_SCENE_PATH)
	if not editor_scene:
		push_error("无法加载编辑器场景: " + EDITOR_SCENE_PATH)
		return

	# 传递工程路径（剧情节工程目录）
	var root := _get_project_root(selected_project)
	var episode_dir := root
	var folder_from_path := _extract_ep_name_from_path(_selected_episode_path)
	if not folder_from_path.is_empty():
		var candidate := root + "/episodes/" + folder_from_path
		if not FileAccess.file_exists(candidate + "/project.json"):
			push_error("找不到该剧情节工程: " + candidate)
			return
		episode_dir = candidate
	elif _selected_episode_path.begins_with("export/"):
		episode_dir = root
	else:
		var folder := _episode_folder_from_title(_selected_episode_title)
		if folder.is_empty():
			push_error("该剧情节不是由编辑器创建，暂不支持打开: " + _selected_episode_path)
			return

		var candidate := root + "/episodes/" + folder
		if not FileAccess.file_exists(candidate + "/project.json"):
			push_error("找不到该剧情节工程: " + candidate)
			return
		episode_dir = candidate

	_transition_to_editor(editor_scene, episode_dir)

func _transition_to_editor(editor_scene: PackedScene, episode_dir: String) -> void:
	if _is_transitioning or _is_exiting:
		return
	_is_transitioning = true

	# 黑场过渡层（加到父节点上，确保覆盖住接下来要打开的编辑器）
	var overlay := ColorRect.new()
	overlay.name = "TransitionOverlay"
	overlay.color = Color.BLACK
	overlay.modulate.a = 0.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 4095

	var parent := get_parent()
	if parent:
		parent.add_child(overlay)
		parent.move_child(overlay, parent.get_child_count() - 1)

	var tween_in := create_tween()
	tween_in.tween_property(overlay, "modulate:a", 1.0, TRANSITION_ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween_in.finished

	# 打开编辑器
	var editor = editor_scene.instantiate()
	_active_editor = editor
	if editor is Control:
		editor.z_index = z_index + 1
		editor.mouse_filter = Control.MOUSE_FILTER_STOP
	if parent:
		parent.add_child(editor)
		parent.move_child(editor, parent.get_child_count() - 1)
		parent.move_child(overlay, parent.get_child_count() - 1)

	if editor.has_method("load_project"):
		editor.load_project(episode_dir)

	# 过渡层淡出，然后关闭工程管理器
	# 注意：tween 若挂在本节点上，在 queue_free() 后会被引擎停止，导致遮罩不消失（黑屏）。
	# 这里把 tween 挂在 overlay 上，确保即使本节点释放也能正常淡出。
	var tween_out := overlay.create_tween()
	tween_out.tween_property(overlay, "modulate:a", 0.0, TRANSITION_ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_out.tween_callback(func(): overlay.queue_free())

	# 不销毁工程管理器：返回按钮应回到工程管理器（更符合“上一页”的直觉）。
	# 另外，编辑器不处理 ESC，这里保持 _is_transitioning=true 防止本节点响应 ui_cancel。
	_set_project_manager_visible_for_editor(false)
	if _active_editor != null and not _active_editor.tree_exited.is_connected(_on_editor_tree_exited):
		_active_editor.tree_exited.connect(_on_editor_tree_exited, CONNECT_ONE_SHOT)

func _on_delete_project_button_pressed():
	"""删除工程"""
	if selected_project.is_empty():
		return

	pending_delete_project = selected_project
	if delete_confirm_dialog:
		delete_confirm_dialog.dialog_text = '确定删除工程"%s"？此操作不可撤销。' % pending_delete_project
		delete_confirm_dialog.popup_centered()
		return

	_on_delete_confirmed()

func _on_delete_confirmed() -> void:
	if pending_delete_project.is_empty():
		return

	var project_path = PROJECTS_PATH + "/" + pending_delete_project
	_delete_directory_recursive(project_path)
	print("删除工程成功: " + pending_delete_project)

	pending_delete_project = ""
	_load_projects()

func _delete_directory_recursive(path: String):
	"""递归删除目录"""
	var absolute_path := ProjectSettings.globalize_path(path)
	var dir = DirAccess.open(absolute_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		var file_path = absolute_path + "/" + file_name
		if dir.current_is_dir():
			_delete_directory_recursive(file_path)
		else:
			DirAccess.remove_absolute(file_path)
		file_name = dir.get_next()
	dir.list_dir_end()

	DirAccess.remove_absolute(absolute_path)

func _on_back_button_pressed():
	"""返回按钮"""
	_request_exit_to_menu()
