extends Control

signal back_pressed

# 分辨率列表（16:9比例）
const RESOLUTIONS_16_9 = [
	Vector2i(1920, 1080),
	Vector2i(1680, 945),
	Vector2i(1600, 900),
	Vector2i(1366, 768),
	Vector2i(1280, 720),
	Vector2i(960, 540),
	Vector2i(854, 480)
]

@onready var borderless_btn = $MainPanel/ContentArea/SettingsContent/HBoxContainer/DisplaySettings/ModeButtons/BorderlessBtn
@onready var windowed_btn = $MainPanel/ContentArea/SettingsContent/HBoxContainer/DisplaySettings/ModeButtons/WindowedBtn
@onready var screen_list = $MainPanel/ContentArea/SettingsContent/HBoxContainer/DisplaySettings/ScreenList
@onready var resolution_list = $MainPanel/ContentArea/SettingsContent/HBoxContainer/DisplaySettings/ResolutionList
@onready var master_volume_slider = $MainPanel/ContentArea/SettingsContent/HBoxContainer/AudioSettings/MasterVolumeSlider
@onready var music_volume_slider = $MainPanel/ContentArea/SettingsContent/HBoxContainer/AudioSettings/MusicVolumeSlider
@onready var sfx_volume_slider = $MainPanel/ContentArea/SettingsContent/HBoxContainer/AudioSettings/SFXVolumeSlider

# 面板节点
@onready var settings_content = $MainPanel/ContentArea/SettingsContent
@onready var thanks_content = $MainPanel/ContentArea/ThanksContent

# 按钮节点
@onready var setting_button = $MainPanel/SidePanel/VBoxContainer/SettingButton
@onready var thanks_button = $MainPanel/SidePanel/VBoxContainer/ThanksButton

# 按钮纹理资源
var setting_idle_texture: Texture2D
var setting_clicked_texture: Texture2D
var thanks_idle_texture: Texture2D
var thanks_clicked_texture: Texture2D

# 当前选择的屏幕索引
var current_screen: int = 0
# 窗口模式下的分辨率（不包括无边框全屏）
var windowed_resolution: Vector2i = Vector2i(1280, 720)
# 窗口顶部最小边距（确保标题栏可见）
const MIN_TOP_MARGIN: int = 50

# B站个人主页链接（请在这里填写实际链接）
var bilibili_urls = {
	"yang": "https://space.bilibili.com/157725171",  # YANG-301的B站主页
	"fusu": "https://space.bilibili.com/364706064",  # 不死扶苏233的B站主页
	"sakura": "https://space.bilibili.com/28626",  # 樱天澈的B站主页
	"snow": "https://space.bilibili.com/6105216",  # 雪凌殇的B站主页
	"lazy": "https://space.bilibili.com/274983449"  # 见习食神懒羊羊的B站主页
}

func _ready():
	# 加载按钮纹理资源
	setting_idle_texture = load("res://assets/gui/settings/setting_idle.png")
	setting_clicked_texture = load("res://assets/gui/settings/setting_clicked.png")
	thanks_idle_texture = load("res://assets/gui/settings/thanks_idle.png")
	thanks_clicked_texture = load("res://assets/gui/settings/thanks_clicked.png")

	# 初始化屏幕列表
	_populate_screen_list()

	# 加载保存的设置（包括屏幕、分辨率等）
	_load_settings()

	# 初始化分辨率列表（需要在加载设置后，因为要知道保存的窗口分辨率）
	_populate_resolution_list()

	# 设置初始窗口模式按钮状态
	_update_window_mode_buttons()

	# 默认显示设置页面
	_show_settings_page()

func _populate_screen_list():
	screen_list.clear()
	var screen_count = DisplayServer.get_screen_count()

	for i in range(screen_count):
		var screen_size = DisplayServer.screen_get_size(i)
		var screen_name = "显示器 %d (%dx%d)" % [i + 1, screen_size.x, screen_size.y]
		screen_list.add_item(screen_name)
		screen_list.set_item_metadata(i, i)

	# 获取当前窗口所在的屏幕
	current_screen = DisplayServer.window_get_current_screen()
	screen_list.selected = current_screen

func _populate_resolution_list():
	# 获取当前屏幕尺寸
	var screen_size = DisplayServer.screen_get_size(current_screen)
	var is_borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)

	# 用于比较的分辨率（无边框模式下使用保存的窗口分辨率，否则使用当前窗口大小）
	var compare_resolution = windowed_resolution if is_borderless else DisplayServer.window_get_size()

	resolution_list.clear()

	# 添加16:9的分辨率选项（不超过当前屏幕尺寸）
	for res in RESOLUTIONS_16_9:
		if res.x <= screen_size.x and res.y <= screen_size.y:
			var text = str(res.x) + " x " + str(res.y)
			resolution_list.add_item(text)
			resolution_list.set_item_metadata(resolution_list.get_item_count() - 1, res)

	# 选中当前分辨率
	for i in range(resolution_list.get_item_count()):
		var res = resolution_list.get_item_metadata(i)
		if res == compare_resolution:
			resolution_list.selected = i
			break

func _update_window_mode_buttons():
	var is_borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)

	# 重置所有按钮
	borderless_btn.button_pressed = false
	windowed_btn.button_pressed = false

	# 设置当前模式按钮（只看是否无边框）
	if is_borderless:
		borderless_btn.button_pressed = true
	else:
		windowed_btn.button_pressed = true

# 辅助函数：安全地居中窗口到屏幕（确保标题栏可见）
func _center_window_to_screen(window_size: Vector2i, screen_index: int) -> Vector2i:
	var screen_size = DisplayServer.screen_get_size(screen_index)
	var screen_position = DisplayServer.screen_get_position(screen_index)

	# 计算居中位置
	var center_x = screen_position.x + (screen_size.x - window_size.x) / 2
	var center_y = screen_position.y + (screen_size.y - window_size.y) / 2

	# 确保窗口顶部至少距离屏幕顶部MIN_TOP_MARGIN像素
	if center_y < screen_position.y + MIN_TOP_MARGIN:
		center_y = screen_position.y + MIN_TOP_MARGIN

	return Vector2i(center_x, center_y)

func _load_settings():
	# 从GameConfig加载设置
	var config = ConfigFile.new()
	var err = config.load(GameConfig.CONFIG_FILE_PATH)

	if err == OK:
		# 加载音量设置
		master_volume_slider.value = config.get_value("audio", "master_volume", 100)
		music_volume_slider.value = config.get_value("audio", "music_volume", 100)
		sfx_volume_slider.value = config.get_value("audio", "sfx_volume", 100)

		# 应用音量设置
		_apply_audio_settings()

		# 加载屏幕设置
		var saved_screen = config.get_value("display", "screen", 0)
		# 确保屏幕索引有效
		var screen_count = DisplayServer.get_screen_count()
		if saved_screen >= 0 and saved_screen < screen_count:
			current_screen = saved_screen
			screen_list.selected = current_screen
		else:
			current_screen = 0
			screen_list.selected = 0

		# 加载窗口模式（始终为窗口模式）
		var saved_borderless = config.get_value("display", "borderless", false)

		# 加载分辨率
		var saved_width = config.get_value("display", "resolution_x", 1280)
		var saved_height = config.get_value("display", "resolution_y", 720)
		var saved_size = Vector2i(saved_width, saved_height)
		windowed_resolution = saved_size  # 保存到变量

		# 应用窗口设置
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, saved_borderless)
		DisplayServer.window_set_current_screen(current_screen)

		# 根据窗口模式设置位置和大小到指定屏幕
		var screen_position = DisplayServer.screen_get_position(current_screen)
		var screen_size = DisplayServer.screen_get_size(current_screen)

		if saved_borderless:
			# 无边框全屏模式，窗口大小等于屏幕大小
			DisplayServer.window_set_size(screen_size)
			DisplayServer.window_set_position(screen_position)
		else:
			# 窗口模式，使用保存的分辨率并居中到屏幕（确保顶部可见）
			DisplayServer.window_set_size(saved_size)
			var window_pos = _center_window_to_screen(saved_size, current_screen)
			DisplayServer.window_set_position(window_pos)

func _save_settings():
	var config = ConfigFile.new()
	config.load(GameConfig.CONFIG_FILE_PATH)  # 先加载现有配置

	# 保存音量设置
	config.set_value("audio", "master_volume", master_volume_slider.value)
	config.set_value("audio", "music_volume", music_volume_slider.value)
	config.set_value("audio", "sfx_volume", sfx_volume_slider.value)

	# 保存窗口模式
	var mode = DisplayServer.window_get_mode()
	var is_borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	config.set_value("display", "window_mode", mode)
	config.set_value("display", "borderless", is_borderless)

	# 保存屏幕
	config.set_value("display", "screen", current_screen)

	# 保存分辨率（只保存窗口模式下的分辨率，无边框全屏不保存）
	if not is_borderless:
		windowed_resolution = DisplayServer.window_get_size()

	config.set_value("display", "resolution_x", windowed_resolution.x)
	config.set_value("display", "resolution_y", windowed_resolution.y)

	config.save(GameConfig.CONFIG_FILE_PATH)

func _apply_audio_settings():
	# 设置音频总线音量
	var master_db = linear_to_db(master_volume_slider.value / 100.0)
	var music_db = linear_to_db(music_volume_slider.value / 100.0)
	var sfx_db = linear_to_db(sfx_volume_slider.value / 100.0)

	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), master_db)

	# 如果有音乐和音效总线，也设置它们
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, music_db)

	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, sfx_db)

# 窗口模式按钮回调
func _on_borderless_btn_pressed():
	# 检查是否已经是无边框模式，避免重复触发
	if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS):
		return

	# 确保窗口在正确的屏幕上
	DisplayServer.window_set_current_screen(current_screen)

	# 获取屏幕信息
	var screen_size = DisplayServer.screen_get_size(current_screen)
	var screen_position = DisplayServer.screen_get_position(current_screen)

	# 设置窗口模式和大小
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(screen_size)
	DisplayServer.window_set_position(screen_position)

	# 最后设置无边框标志（确保窗口已经在正确位置和大小）
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

	_update_window_mode_buttons()
	_populate_resolution_list()  # 刷新分辨率列表以匹配新模式
	_save_settings()

func _on_windowed_btn_pressed():
	# 检查是否已经是窗口模式，避免重复触发
	if not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS):
		return

	# 先取消无边框标志
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

	# 确保窗口在正确的屏幕上
	DisplayServer.window_set_current_screen(current_screen)

	# 设置窗口模式和大小
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(windowed_resolution)

	# 居中窗口到当前屏幕（确保顶部可见）
	var window_pos = _center_window_to_screen(windowed_resolution, current_screen)
	DisplayServer.window_set_position(window_pos)

	_update_window_mode_buttons()
	_populate_resolution_list()  # 刷新分辨率列表以匹配新模式
	_save_settings()

# 屏幕选择回调
func _on_screen_selected(index: int):
	current_screen = index
	# 刷新分辨率列表（不同屏幕可能有不同的最大分辨率）
	_populate_resolution_list()
	# 移动窗口到新屏幕
	_move_window_to_current_screen()
	_save_settings()

func _move_window_to_current_screen():
	var is_borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	var screen_position = DisplayServer.screen_get_position(current_screen)
	var screen_size = DisplayServer.screen_get_size(current_screen)

	if is_borderless:
		# 无边框全屏模式，设置窗口大小为屏幕大小
		DisplayServer.window_set_size(screen_size)
		DisplayServer.window_set_position(screen_position)
	else:
		# 窗口模式，使用保存的窗口分辨率并居中到屏幕（确保顶部可见）
		DisplayServer.window_set_size(windowed_resolution)
		var window_pos = _center_window_to_screen(windowed_resolution, current_screen)
		DisplayServer.window_set_position(window_pos)

	# 确保窗口在正确的屏幕上
	DisplayServer.window_set_current_screen(current_screen)

# 分辨率选择回调
func _on_resolution_selected(index: int):
	var selected_res = resolution_list.get_item_metadata(index)
	if selected_res:
		var is_borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)

		# 更新窗口分辨率变量
		windowed_resolution = selected_res

		if is_borderless:
			# 无边框全屏模式下，只保存分辨率设置，不改变当前窗口
			# （切换到窗口模式时会使用这个分辨率）
			_save_settings()
		else:
			# 窗口模式下，立即应用新分辨率
			DisplayServer.window_set_size(selected_res)

			# 居中窗口到当前屏幕（确保顶部可见）
			var window_pos = _center_window_to_screen(selected_res, current_screen)
			DisplayServer.window_set_position(window_pos)

			# 确保窗口在正确的屏幕上
			DisplayServer.window_set_current_screen(current_screen)
			_save_settings()

# 音量滑块回调
func _on_master_volume_changed(_value: float):
	_apply_audio_settings()
	_save_settings()

func _on_music_volume_changed(_value: float):
	_apply_audio_settings()
	_save_settings()

func _on_sfx_volume_changed(_value: float):
	_apply_audio_settings()
	_save_settings()

# 返回按钮回调
func _on_back_button_pressed():
	back_pressed.emit()

# 页面切换
func _on_setting_button_pressed():
	_show_settings_page()

func _on_thanks_button_pressed():
	_show_thanks_page()

func _show_settings_page():
	settings_content.visible = true
	thanks_content.visible = false
	setting_button.texture_normal = setting_clicked_texture
	thanks_button.texture_normal = thanks_idle_texture

func _show_thanks_page():
	settings_content.visible = false
	thanks_content.visible = true
	setting_button.texture_normal = setting_idle_texture
	thanks_button.texture_normal = thanks_clicked_texture

# B站链接点击处理
func _open_bilibili_url(url: String):
	if url == "":
		print("该用户的B站链接尚未配置")
		return
	OS.shell_open(url)

func _on_contributor_fusu_pressed():
	_open_bilibili_url(bilibili_urls["fusu"])

func _on_contributor_yang_pressed():
	_open_bilibili_url(bilibili_urls["yang"])

func _on_thanks_sakura_pressed():
	_open_bilibili_url(bilibili_urls["sakura"])

func _on_thanks_snow_pressed():
	_open_bilibili_url(bilibili_urls["snow"])

func _on_thanks_lazy_pressed():
	_open_bilibili_url(bilibili_urls["lazy"])

# 头像浮动动画辅助函数
func _float_avatar_up(avatar_container: Control):
	"""向上浮动动画"""
	if not avatar_container:
		return

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	# 向上浮动8像素
	tween.tween_property(avatar_container, "position:y", -8.0, 0.3)
	# 轻微放大
	tween.tween_property(avatar_container, "scale", Vector2(1.05, 1.05), 0.3)

func _float_avatar_down(avatar_container: Control):
	"""恢复原位动画"""
	if not avatar_container:
		return

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	# 恢复原始位置
	tween.tween_property(avatar_container, "position:y", 0.0, 0.3)
	# 恢复原始大小
	tween.tween_property(avatar_container, "scale", Vector2(1.0, 1.0), 0.3)

# 各个头像的悬停事件处理
func _on_avatar_yang_entered():
	var container = $MainPanel/ContentArea/ThanksContent/VBoxContainer/ContributorsGrid/Contributor2/AvatarContainer
	_float_avatar_up(container)

func _on_avatar_yang_exited():
	var container = $MainPanel/ContentArea/ThanksContent/VBoxContainer/ContributorsGrid/Contributor2/AvatarContainer
	_float_avatar_down(container)

func _on_avatar_fusu_entered():
	var container = $MainPanel/ContentArea/ThanksContent/VBoxContainer/ContributorsGrid/Contributor1/AvatarContainer
	_float_avatar_up(container)

func _on_avatar_fusu_exited():
	var container = $MainPanel/ContentArea/ThanksContent/VBoxContainer/ContributorsGrid/Contributor1/AvatarContainer
	_float_avatar_down(container)

func _on_avatar_sakura_entered():
	var container = $MainPanel/ContentArea/ThanksContent/VBoxContainer/ThanksGrid/Thanks1/AvatarContainer
	_float_avatar_up(container)

func _on_avatar_sakura_exited():
	var container = $MainPanel/ContentArea/ThanksContent/VBoxContainer/ThanksGrid/Thanks1/AvatarContainer
	_float_avatar_down(container)

func _on_avatar_snow_entered():
	var container = $MainPanel/ContentArea/ThanksContent/VBoxContainer/ThanksGrid/Thanks2/AvatarContainer
	_float_avatar_up(container)

func _on_avatar_snow_exited():
	var container = $MainPanel/ContentArea/ThanksContent/VBoxContainer/ThanksGrid/Thanks2/AvatarContainer
	_float_avatar_down(container)

func _on_avatar_lazy_entered():
	var container = $MainPanel/ContentArea/ThanksContent/VBoxContainer/ThanksGrid/Thanks3/AvatarContainer
	_float_avatar_up(container)

func _on_avatar_lazy_exited():
	var container = $MainPanel/ContentArea/ThanksContent/VBoxContainer/ThanksGrid/Thanks3/AvatarContainer
	_float_avatar_down(container)

# 显示设置界面（带淡入动画）
func show_settings():
	visible = true
	modulate.a = 0

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

# 隐藏设置界面（带淡出动画）
func hide_settings():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)

	await tween.finished
	visible = false
