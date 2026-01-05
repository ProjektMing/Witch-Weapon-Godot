# =============================================================================
# 主故事列表控制器 (MainStoryList Controller)
# =============================================================================
# 
# 功能概述：
# 这个脚本控制游戏主菜单的故事选择界面，提供以下核心功能：
# 1. 故事缩略图的横向拖拽浏览（支持惯性滑动和边界回弹）
# 2. 故事点击后的展开动画效果（选中故事放大，其他故事收缩变暗）
# 3. 剧集列表的动态加载和显示
# 4. 平滑的UI过渡动画和视觉反馈
#
# 主要组件说明：
# - Story01~Story10: 十个故事节点，每个包含BackNet/TextureRect/TextureButton结构
# - BackgroundColor: 展开时的背景遮罩
# - BackArea: 用户点击返回的区域
#
# 动画系统：
# 使用基于时间的补间动画，支持多种缓动函数，实现流畅的视觉效果
# 包括位置移动、缩放变化、透明度过渡、着色器效果等多层动画
#
# 作者: [项目团队]
# 版本: 优化版本
# 最后修改: 2025年8月
# =============================================================================

extends Control

# ==================== 信号定义 ====================

# ==================== 节点引用 ====================
# 主要UI组件的快速访问引用
@onready var story01: Control = $"Story01"
@onready var background_color: ColorRect = $"BackgroundColor"
@onready var back_area: Control = $"BackgroundColor/BackArea"

# ==================== 常量配置 ====================
# 故事节点名称到故事ID的映射表
const STORY_MAPPING: Dictionary = {
	"Story01": "chapter1", "Story02": "chapter2", "Story03": "chapter3",
	"Story04": "bathophobia", "Story05": "traumareflex", "Story06": "imperialpresence",
	"Story07": "apocalypse", "Story08": "stardustdescends", "Story09": "chaoscalculus",
	"Story10": "deathconfession"
}

# 剧集列表场景的文件路径
const EPISODE_LIST_SCENE_PATH: String = "res://scenes/main/episode_story_list.tscn"

# ==================== 着色器和UI资源 ====================
# 黑色过渡着色器，用于故事切换时的视觉效果
var black_transition_shader = preload("res://scripts/shader/black_transition.gdshader")
# 其他故事节点的材质和按钮组件缓存
var other_stories_materials: Array = []
var other_stories_buttons: Array = []

# ==================== 拖拽物理参数 ====================
# 拖拽状态控制
var is_dragging: bool = false
var drag_velocity: float = 0.0
var drag_start_pos: Vector2
# 交互阈值和物理参数
const CLICK_THRESHOLD: float = 5.0    # 区分点击和拖拽的像素阈值
const FRICTION: float = 0.985         # 拖拽摩擦系数
const BOUNDARY_SPRING: float = 0.1    # 边界回弹弹性系数

# ==================== 动画控制参数 ====================
# 动画时长和状态参数
const ANIMATION_DURATION: float = 1.0       # 主动画时长
const BLACK_TRANSITION_DURATION: float = 0.6 # 黑色过渡动画时长
const BACK_BUTTON_DELAY: float = 0.2        # 返回按钮生效延迟
const BUTTON_FADE_START: float = 0.5        # 按钮淡出开始时间点

# 动画目标值
const TARGET_POSITION: Vector2 = Vector2(106, 38)  # 展开后的目标位置
const TARGET_SCALE: float = 1.9                   # 展开后的缩放比例
const TARGET_MODULATE_ALPHA: float = 1.0          # 目标透明度
const NUM_LEFT_OFFSET: float = 90.0               # Num节点左移距离
const NUM_ANIMATION_DELAY: float = 0.0            # Num节点动画延迟

# 其他故事动画参数
const OTHER_STORY_SHRINK_FACTOR: float = 0.1      # 其他故事收缩比例
const OTHER_STORY_FOLLOW_FACTOR: float = 1.0      # 跟随移动比例

# ==================== 动画状态变量 ====================
# UI组件引用
var selected_back_net: Control = null         # 选中的BackNet节点
var selected_texture_rect: Control = null     # 选中的TextureRect节点
var selected_num_node: Control = null         # 选中的Num节点
var selected_story_node: Control = null       # 选中的故事节点
var episode_list_instance: Control = null     # 剧集列表场景实例

# 状态变量
var is_animating: bool = false               # 是否正在播放动画
var is_expanded: bool = false                # 是否处于展开状态
var back_button_enabled: bool = false        # 返回按钮是否可用
var animation_timer: float = 0.0             # 动画计时器

# 动画数据
var other_stories_data: Array = []           # 其他故事的动画数据
var selected_story_motion_vector: Vector2 = Vector2.ZERO  # 选中故事的移动向量

# 动画状态缓存字典 - 存储动画过程中需要的原始状态信息
var animation_cache = {
	"original_position": Vector2.ZERO,          # 原始位置
	"original_scale": Vector2.ONE,              # 原始缩放
	"original_modulate_alpha": 0.0,            # 原始透明度
	"background_modulate_alpha": 0.0,          # 背景透明度
	"is_returning": false,                      # 是否为返回动画
	"true_original_position": Vector2.ZERO,     # 真实原始位置
	"true_original_scale": Vector2.ONE,         # 真实原始缩放
	"original_z_index": 0,                     # 原始z轴索引
	"original_num_z_index": 0,                 # Num节点原始z轴索引
	"original_num_position": Vector2.ZERO,      # Num节点原始位置
	"true_original_num_position": Vector2.ZERO  # Num节点真实原始位置
}

# ==================== 主生命周期函数 ====================
## 组件初始化 - 在节点准备就绪时调用
func _ready():
	_setup_story_buttons()  # 设置所有故事按钮的点击事件
	_init_background()      # 初始化背景组件
	_init_back_nets()       # 初始化所有BackNet的透明度
	_setup_back_area()      # 设置BackArea的点击事件

## 每帧更新函数 - 处理动画和物理效果
func _process(delta):
	if not _is_list_active():
		is_dragging = false
		drag_velocity = 0.0
		return

	# 如果正在播放动画，更新所有动画相关内容
	if is_animating:
		_update_animation(delta)              # 更新主动画
		_update_other_stories_animation(delta) # 更新其他故事动画
		_update_black_transition(delta)       # 更新黑色过渡动画
		_update_button_fade(delta)            # 更新按钮淡出效果
	# 如果未展开且无动画，更新拖拽物理效果
	elif not is_expanded:
		_update_drag_physics()                # 更新拖拽物理效果

## 输入事件处理 - 管理用户的拖拽操作
func _input(event):
	if not _is_list_active():
		is_dragging = false
		drag_velocity = 0.0
		return

	# 检查设置界面是否打开
	var main_menu = get_tree().get_first_node_in_group("main_menu")
	if main_menu and main_menu.has_method("is_settings_open") and main_menu.is_settings_open():
		is_dragging = false
		drag_velocity = 0.0
		return

	# 如果正在动画或已展开，禁用所有拖拽输入
	if is_animating or is_expanded:
		is_dragging = false
		drag_velocity = 0.0
		return
	_handle_drag_input(event)  # 处理拖拽输入

func _is_list_active() -> bool:
	if not visible or modulate.a < 0.5:
		return false

	var main_menu = get_tree().get_first_node_in_group("main_menu")
	if main_menu and main_menu.get("_is_switching"):
		return false

	return true

# ==================== 初始化函数组 ====================
## 设置BackArea的点击事件 - 使用户可以点击返回
func _setup_back_area():
	if back_area and back_area is TextureButton:
		back_area.pressed.connect(_on_back_area_pressed)

## 设置所有故事按钮的点击事件 - 循环创建Story01-Story10的按钮事件
func _setup_story_buttons():
	for i in range(10):
		var story_node = get_node_or_null("Story%02d" % (i + 1))
		if story_node:
			var button = story_node.get_node_or_null("BackNet/TextureRect/TextureButton")
			if button and button is TextureButton:
				button.gui_input.connect(_on_button_input.bind(story_node))

## 初始化背景 - 设置背景的初始状态为透明且隐藏
func _init_background():
	if background_color:
		background_color.modulate.a = 0.0
		background_color.visible = false

## 初始化所有BackNet和Num节点的透明度和z_index
func _init_back_nets():
	for i in range(10):
		var story_node = get_node_or_null("Story%02d" % (i + 1))
		if not story_node:
			continue
			
		# 设置BackNet的初始状态
		var back_net = story_node.get_node_or_null("BackNet")
		if back_net:
			back_net.self_modulate.a = 0.0
			back_net.z_index = -1
			
		# 设置Num节点的初始状态
		var num_node = story_node.get_node_or_null("BackNet/Num")
		if num_node:
			num_node.z_index = 0

# ==================== 输入事件处理组 ====================
## BackArea点击处理 - 用户点击返回区域时的处理逻辑
func _on_back_area_pressed():
	# 只有在展开状态且非动画中且返回按钮已启用时才响应
	if not (is_expanded and not is_animating and back_button_enabled):
		return
		
	# 根据当前状态选择退出方式
	if episode_list_instance:
		_start_concurrent_exit_animations()  # 同时退出剧集列表和故事
	else:
		restore_selected_story()             # 直接恢复故事

## 同时开始退出动画 - 协调剧集列表和主界面的退出
func _start_concurrent_exit_animations():
	if not episode_list_instance:
		return
	
	# 连接退出动画开始信号（避免重复连接）
	if not episode_list_instance.is_connected("exit_animation_started", _on_episode_exit_started):
		episode_list_instance.exit_animation_started.connect(_on_episode_exit_started)
	
	# 同时启动两个退出动画
	if episode_list_instance.has_method("play_exit_animation"):
		episode_list_instance.play_exit_animation()  # 播放剧集退出动画
	restore_selected_story()                      # 开始故事返回动画

## 剧集退出动画开始回调 - 清理引用并执行后续逻辑
func _on_episode_exit_started():
	episode_list_instance = null  # 清除引用，让episode自己处理销毁

	# 重新启用设置按钮
	var main_menu = get_tree().get_first_node_in_group("main_menu")
	if main_menu and main_menu.has_node("SettingsButton"):
		main_menu.get_node("SettingsButton").disabled = false

## 剧集列表退出动画完成回调
func _on_episode_list_exit_completed():
	episode_list_instance = null
	# 开始恢复主界面动画
	restore_selected_story()

## 拖拽输入处理 - 处理用户的鼠标拖拽操作
func _handle_drag_input(event: InputEvent):
	# 鼠标按钮事件处理
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_start_pos = event.position
			drag_velocity = 0.0
		else:
			is_dragging = false
	# 鼠标移动事件处理（需要超过阈值才算拖拽）
	elif event is InputEventMouseMotion and is_dragging:
		if event.position.distance_to(drag_start_pos) > CLICK_THRESHOLD:
			drag_velocity = event.relative.x
			_move_all_stories(drag_velocity)

# 按钮点击处理相关变量
var button_press_pos: Vector2  # 记录按钮按下时的位置

## 按钮输入处理 - 区分点击和拖拽，只有点击才触发故事展开
func _on_button_input(event: InputEvent, story_node: Control):
	# 如果已经展开或正在动画，不响应新的点击
	if is_expanded or is_animating:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			button_press_pos = event.position  # 记录按下位置
		elif not event.pressed:
			# 只有移动距离小于阈值才触发点击（区分点击和拖拽）
			if event.position.distance_to(button_press_pos) < CLICK_THRESHOLD:
				_start_expand_animation(story_node)

# ==================== 核心动画系统 ====================
## 开始展开动画 - 故事点击后的主要展开动画入口
func _start_expand_animation(story_node: Control):
	# 防止重复触发动画
	if is_animating or is_expanded:
		return
	
	# 获取关键节点引用
	var nodes = _get_story_nodes(story_node)
	if not nodes:
		return
	
	# 设置选中的节点引用
	_set_selected_nodes(nodes, story_node)
	
	# 初始化动画状态
	_init_animation_state()
	
	# 缓存原始状态用于动画和返回
	_cache_original_states(nodes)
	
	# 准备动画环境
	_prepare_animation_environment(story_node, nodes)
	
	# 开始相关动画效果
	_start_related_animations(story_node)

## 获取故事节点的关键子组件
func _get_story_nodes(story_node: Control) -> Dictionary:
	var back_net = story_node.get_node_or_null("BackNet")
	var texture_rect = back_net.get_node_or_null("TextureRect") if back_net else null
	var num_node = back_net.get_node_or_null("Num") if back_net else null
	
	if not back_net or not texture_rect:
		push_error("无法找到故事节点的关键组件: " + story_node.name)
		return {}
	
	return {
		"back_net": back_net,
		"texture_rect": texture_rect,
		"num_node": num_node
	}

## 设置选中的节点引用
func _set_selected_nodes(nodes: Dictionary, story_node: Control):
	selected_back_net = nodes.back_net
	selected_texture_rect = nodes.texture_rect
	selected_num_node = nodes.num_node
	selected_story_node = story_node

## 初始化动画状态
func _init_animation_state():
	back_button_enabled = false
	is_animating = true
	is_dragging = false
	drag_velocity = 0.0
	animation_timer = 0.0

## 缓存原始状态用于动画插值
func _cache_original_states(nodes: Dictionary):
	var back_net = nodes.back_net
	var texture_rect = nodes.texture_rect
	var num_node = nodes.num_node
	
	# 缓存当前状态作为动画起点
	animation_cache.original_position = back_net.global_position
	animation_cache.original_scale = texture_rect.scale
	animation_cache.original_modulate_alpha = back_net.self_modulate.a
	animation_cache.background_modulate_alpha = background_color.modulate.a if background_color else 0.0
	animation_cache.is_returning = false
	animation_cache.original_z_index = back_net.z_index
	
	# 保存真实的原始状态用于返回动画
	animation_cache.true_original_position = back_net.global_position
	animation_cache.true_original_scale = texture_rect.scale
	
	# 缓存Num节点状态
	if num_node:
		animation_cache.original_num_z_index = num_node.z_index
		animation_cache.original_num_position = num_node.position
		animation_cache.true_original_num_position = num_node.position

## 准备动画环境 - 设置z_index和背景
func _prepare_animation_environment(story_node: Control, nodes: Dictionary):
	var back_net = nodes.back_net
	var num_node = nodes.num_node
	
	# 计算选中故事的移动向量
	selected_story_motion_vector = TARGET_POSITION - back_net.global_position
	
	# 显示和设置背景
	if background_color:
		background_color.visible = true
	
	# 设置z_index使选中故事显示在最上层
	back_net.z_index = 1
	if num_node:
		num_node.z_index = 1
	
	# 将故事节点移到合适的层级
	var bg_index = background_color.get_index() if background_color else get_child_count()
	move_child(story_node, bg_index - 1)

## 启动相关的动画效果
func _start_related_animations(story_node: Control):
	_prepare_other_stories_animation(story_node)  # 准备其他故事的动画数据
	_start_black_transition_for_others(story_node) # 开始其他故事的变黑动画
	_collect_other_buttons(story_node)            # 收集其他故事的按钮用于淡出

# ==================== 其他故事动画管理 ====================
## 准备其他故事的动画数据 - 计算每个故事相对于选中故事的位置关系
func _prepare_other_stories_animation(selected_story: Control):
	other_stories_data.clear()
	
	var current_back_net = selected_story.get_node("BackNet")
	var selected_pos = current_back_net.global_position
	
	# 遍历所有故事节点，收集非选中故事的动画数据
	for i in range(10):
		var story_node = get_node_or_null("Story%02d" % (i + 1))
		if not story_node or story_node == selected_story:
			continue
			
		var back_net = story_node.get_node_or_null("BackNet")
		if back_net:
			var story_data = {
				"node": back_net,
				"original_position": back_net.global_position,
				"true_original_position": back_net.global_position,
				"to_selected_vector": selected_pos - back_net.global_position  # 到选中故事的向量
			}
			other_stories_data.append(story_data)

## 更新其他故事的动画 - 处理收缩和跟随移动效果
func _update_other_stories_animation(_delta: float):
	var progress = animation_timer / ANIMATION_DURATION
	
	if not animation_cache.is_returning:
		# 展开动画：其他故事收缩并跟随选中故事移动
		var eased_progress = _ease_out_cubic(progress)
		
		for story_data in other_stories_data:
			var back_net = story_data.node
			if not back_net:
				continue
				
			var original_pos = story_data.original_position
			# 组合两个移动向量：收缩向选中故事 + 跟随选中故事移动
			var shrink_movement = story_data.to_selected_vector * OTHER_STORY_SHRINK_FACTOR
			var follow_movement = selected_story_motion_vector * OTHER_STORY_FOLLOW_FACTOR
			var target_pos = original_pos + shrink_movement + follow_movement
			
			back_net.global_position = original_pos.lerp(target_pos, eased_progress)
	else:
		# 返回动画：所有故事返回原位
		var eased_progress = _ease_out_cubic(progress)
		
		for story_data in other_stories_data:
			var back_net = story_data.node
			if not back_net:
				continue
				
			var current_pos = story_data.get("current_position", back_net.global_position)
			var original_pos = story_data.true_original_position
			back_net.global_position = current_pos.lerp(original_pos, eased_progress)

## 准备其他故事的返回动画数据 - 保存当前位置作为返回动画的起点
func _prepare_other_stories_return_animation():
	for story_data in other_stories_data:
		if story_data.node:
			story_data["current_position"] = story_data.node.global_position

## 恢复选中故事到原位 - 用户点击返回或完成操作后的主要恢复函数
func restore_selected_story():
	if not selected_back_net or not selected_texture_rect or is_animating:
		return
	
	# 禁用返回按钮并设置为返回动画模式
	back_button_enabled = false
	animation_cache.is_returning = true
	is_animating = true
	animation_timer = 0.0
	
	# 缓存当前状态作为返回动画的起始点
	_cache_current_state_for_return()
	
	# 准备其他故事的返回动画和材质恢复
	_prepare_other_stories_return_animation()
	_restore_other_stories_material()

## 缓存当前状态用于返回动画的插值计算
func _cache_current_state_for_return():
	animation_cache.original_position = selected_back_net.global_position
	animation_cache.original_scale = selected_texture_rect.scale
	animation_cache.original_modulate_alpha = selected_back_net.self_modulate.a
	animation_cache.background_modulate_alpha = background_color.modulate.a if background_color else 0.0
	
	# 缓存Num节点的当前位置
	if selected_num_node:
		animation_cache.original_num_position = selected_num_node.position

# ==================== UI元素动画管理 ====================
## 收集其他故事的按钮引用 - 用于后续的淡出动画
func _collect_other_buttons(selected_story: Control):
	other_stories_buttons.clear()
	
	for i in range(10):
		var story_node = get_node_or_null("Story%02d" % (i + 1))
		if story_node and story_node != selected_story:
			var button = story_node.get_node_or_null("BackNet/TextureRect/TextureButton")
			if button:
				other_stories_buttons.append(button)

## 为其他故事应用黑色过渡着色器 - 创建视觉聚焦效果
func _start_black_transition_for_others(selected_story: Control):
	other_stories_materials.clear()
	
	for i in range(10):
		var story_node = get_node_or_null("Story%02d" % (i + 1))
		if story_node and story_node != selected_story:
			var texture_rect = story_node.get_node_or_null("BackNet/TextureRect")
			if texture_rect:
				# 创建并配置着色器材质
				var shader_material = ShaderMaterial.new()
				shader_material.shader = black_transition_shader
				shader_material.set_shader_parameter("transition_progress", 0.0)
				shader_material.set_shader_parameter("edge_sharpness", 5.0)
				texture_rect.material = shader_material
				other_stories_materials.append(shader_material)

## 更新按钮淡出效果 - 在动画过程中逐渐隐藏/显示其他故事的按钮
func _update_button_fade(_delta: float):
	var progress = animation_timer / ANIMATION_DURATION
	
	if not animation_cache.is_returning:
		# 展开动画：在动画进度超过50%后开始淡出按钮
		if progress >= BUTTON_FADE_START:
			var fade_progress = (progress - BUTTON_FADE_START) / (1.0 - BUTTON_FADE_START)
			var fade_alpha = 1.0 - _ease_out_quad(fade_progress)
			_update_buttons_alpha(fade_alpha)
	else:
		# 返回动画：逐渐恢复所有按钮的透明度
		var restore_alpha = _ease_out_quad(progress)
		_update_buttons_alpha(restore_alpha)

## 统一更新所有按钮的透明度和可见性
func _update_buttons_alpha(alpha: float):
	for button in other_stories_buttons:
		if button:
			button.visible = alpha > 0.01  # 透明度过低时隐藏
			button.modulate.a = alpha

## 更新黑色过渡动画 - 控制其他故事的黑化进度
func _update_black_transition(_delta: float):
	var progress = animation_timer / ANIMATION_DURATION
	
	if not animation_cache.is_returning:
		# 展开动画：逐渐黑化其他故事
		var eased_progress = _ease_out_quad(progress)
		for shader_mat in other_stories_materials:
			if shader_mat:
				shader_mat.set_shader_parameter("transition_progress", eased_progress)
	# 返回动画的黑色过渡在_restore_other_stories_material中处理

# ==================== 主动画更新系统 ====================
## 主动画更新函数 - 每帧调用，处理选中故事的位置、缩放、透明度等动画
func _update_animation(delta: float):
	# 防御性检查：确保必需的节点引用存在
	if not selected_back_net or not selected_texture_rect:
		return
		
	# 更新动画计时器
	animation_timer += delta
	
	# 获取动画参数（根据展开/返回状态设置不同的目标值）
	var anim_params = _get_animation_parameters()
	
	# 执行主动画（在动画时长内）
	if animation_timer < ANIMATION_DURATION:
		_apply_animation_interpolation(anim_params)
	else:
		# 动画完成，应用最终状态并清理
		_finalize_animation(anim_params)

## 获取当前动画的目标参数（根据展开或返回模式）
func _get_animation_parameters() -> Dictionary:
	return {
		# 位置动画参数
		"from_pos": animation_cache.original_position,
		"to_pos": TARGET_POSITION if not animation_cache.is_returning else animation_cache.true_original_position,
		
		# 缩放动画参数
		"from_scale": animation_cache.original_scale,
		"to_scale": Vector2(TARGET_SCALE, TARGET_SCALE) if not animation_cache.is_returning else animation_cache.true_original_scale,
		
		# 透明度动画参数
		"from_alpha": animation_cache.original_modulate_alpha,
		"to_alpha": TARGET_MODULATE_ALPHA if not animation_cache.is_returning else 0.0,
		
		# 背景透明度参数
		"from_bg_alpha": animation_cache.background_modulate_alpha,
		"to_bg_alpha": TARGET_MODULATE_ALPHA if not animation_cache.is_returning else 0.0,
		
		# Num节点位置动画参数
		"from_num_pos": animation_cache.original_num_position,
		"to_num_pos": animation_cache.true_original_num_position + Vector2(-NUM_LEFT_OFFSET, 0) if not animation_cache.is_returning else animation_cache.true_original_num_position
	}

## 应用动画插值（在动画进行中调用）
func _apply_animation_interpolation(params: Dictionary):
	var progress = animation_timer / ANIMATION_DURATION
	var eased_cubic = _ease_out_cubic(progress)  # 主要用于位置和透明度
	var eased_quad = _ease_out_quad(progress)    # 主要用于缩放和背景
	
	# 应用位置插值（使用三次缓出，更加平滑）
	selected_back_net.global_position = params.from_pos.lerp(params.to_pos, eased_cubic)
	
	# 应用缩放插值（使用二次缓出，更加自然）
	selected_texture_rect.scale = params.from_scale.lerp(params.to_scale, eased_quad)
	
	# 应用透明度插值
	selected_back_net.self_modulate.a = lerpf(params.from_alpha, params.to_alpha, eased_cubic)
	
	# 应用Num节点位置动画（如果存在）
	if selected_num_node:
		# 计算Num节点动画的延迟进度
		var num_progress = clamp(progress - NUM_ANIMATION_DELAY, 0, 1) / (1 - NUM_ANIMATION_DELAY) if NUM_ANIMATION_DELAY < 1 else progress
		var num_eased = _ease_out_cubic(num_progress)
		selected_num_node.position = params.from_num_pos.lerp(params.to_num_pos, num_eased)
	
	# 应用背景透明度插值
	if background_color:
		background_color.modulate.a = lerpf(params.from_bg_alpha, params.to_bg_alpha, eased_quad)
		
	else:
		# 动画完成，应用最终状态并清理
		_finalize_animation(params)

## 动画完成后的最终化处理（设置最终状态并清理动画标志）
func _finalize_animation(params: Dictionary):
	# 设置所有组件的最终状态
	selected_back_net.global_position = params.to_pos
	selected_texture_rect.scale = params.to_scale
	selected_back_net.self_modulate.a = params.to_alpha
	
	# 设置Num节点最终位置
	if selected_num_node:
		selected_num_node.position = params.to_num_pos
	
	# 处理返回动画特有的清理工作
	if animation_cache.is_returning:
		_cleanup_return_animation()
	
	# 处理背景状态
	if background_color:
		background_color.modulate.a = params.to_bg_alpha
		# 如果是返回动画且透明度为0，隐藏背景
		if animation_cache.is_returning and params.to_bg_alpha == 0.0:
			background_color.visible = false
	
	# 清理动画状态并更新展开标志
	is_animating = false
	is_expanded = not animation_cache.is_returning
	
	# 调用动画完成回调
	_on_animation_complete()

## 清理返回动画的相关状态（恢复z_index和按钮状态）
func _cleanup_return_animation():
	# 恢复选中故事的z_index
	selected_back_net.z_index = -1
	
	# 恢复Num节点的z_index
	if selected_num_node:
		selected_num_node.z_index = animation_cache.original_num_z_index
	
	# 确保所有按钮都恢复可见性和透明度
	_restore_all_buttons()

## 恢复所有按钮的可见性和透明度
func _restore_all_buttons():
	for button in other_stories_buttons:
		if button:
			button.visible = true
			button.modulate.a = 1.0

## 恢复其他故事的材质
func _restore_other_stories_material():
	for i in range(10):
		var story_node = get_node_or_null("Story%02d" % (i + 1))
		if story_node and story_node != selected_story_node:
			var texture_rect = story_node.get_node_or_null("BackNet/TextureRect")
			if texture_rect:
				# 创建反向动画
				var shader_material = texture_rect.material
				if shader_material and shader_material is ShaderMaterial:
					# 使用tween来平滑恢复
					var tween = get_tree().create_tween()
					
					# 恢复透明度过渡（从当前值到0）
					tween.tween_method(
						func(value): shader_material.set_shader_parameter("transition_progress", value),
						shader_material.get_shader_parameter("transition_progress"),
						0.0,
						ANIMATION_DURATION
					)
					
					tween.finished.connect(func(): texture_rect.material = null)

# ==================== 物理模拟 ====================
## 更新拖拽物理效果
func _update_drag_physics():
	if not is_dragging:
		# 应用惯性
		if abs(drag_velocity) > 0.1:
			drag_velocity *= FRICTION
			_move_all_stories(drag_velocity)
		
		# 边界检测和回弹
		if story01.position.x > 0:
			_move_all_stories(-story01.position.x * BOUNDARY_SPRING)
		elif story01.position.x < -2500:
			_move_all_stories((-2500 - story01.position.x) * BOUNDARY_SPRING)

## 移动所有故事节点
func _move_all_stories(offset: float):
	for child in get_children():
		if child is Control and child != background_color:
			child.position.x += offset

# ==================== 工具函数 ====================
## 缓动函数：二次缓出
func _ease_out_quad(t: float) -> float:
	return 1.0 - pow(1.0 - t, 2.0)

## 缓动函数：三次缓出
func _ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

## 动画完成回调
func _on_animation_complete():
	print("Animation completed for BackNet: ", selected_back_net.name)
	print("TextureRect scaled: ", selected_texture_rect.name)
	print("BackNet modulate alpha: ", selected_back_net.self_modulate.a)
	print("BackNet z_index: ", selected_back_net.z_index)
	if selected_num_node:
		print("Num node z_index: ", selected_num_node.z_index)
	print("Background visible: ", background_color.visible if background_color else false)
	print("Is expanded: ", is_expanded)
	
	# 如果不是返回动画，加载剧集列表场景
	if not animation_cache.is_returning and is_expanded:
		_load_episode_list()
		# 延迟启用返回按钮
		get_tree().create_timer(BACK_BUTTON_DELAY).timeout.connect(func(): back_button_enabled = true)
	else:
		# 如果是返回动画，立即禁用返回按钮
		back_button_enabled = false

# ==================== 场景加载 ====================
## 加载剧集列表场景
func _load_episode_list():
	if not selected_story_node:
		return
	
	# 获取对应的故事ID
	var story_id = STORY_MAPPING.get(selected_story_node.name, "")
	if story_id == "":
		push_error("未找到故事节点的映射: " + selected_story_node.name)
		return
	
	# 加载场景
	var episode_scene = load(EPISODE_LIST_SCENE_PATH)
	if not episode_scene:
		push_error("无法加载场景: " + EPISODE_LIST_SCENE_PATH)
		return
	
	# 实例化场景
	episode_list_instance = episode_scene.instantiate()
	
	# 将场景添加到当前场景树（确保在最上层）
	add_child(episode_list_instance)
	move_child(episode_list_instance, get_child_count() - 1)

	# 设置故事ID（假设场景有set_story方法）
	if episode_list_instance.has_method("set_story"):
		episode_list_instance.set_story(story_id)

	# 禁用设置按钮
	var main_menu = get_tree().get_first_node_in_group("main_menu")
	if main_menu and main_menu.has_node("SettingsButton"):
		main_menu.get_node("SettingsButton").disabled = true

	print("加载剧集列表场景，故事ID: ", story_id)

## 隐藏剧集列表场景
func _hide_episode_list():
	if episode_list_instance:
		# 可以选择添加淡出动画
		episode_list_instance.queue_free()
		episode_list_instance = null
