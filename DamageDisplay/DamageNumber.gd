extends Node2D

# 配置参数
@export var move_speed: float = 100.0
@export var fade_duration: float = 1.0
@export var font_size: int = 36
@export var outline_size: int = 4
@export var outline_color: Color = Color(0, 0, 0, 0.8)
@export var lifetime: float = 2.0

var label: Label
var start_position: Vector2
var target_offset: Vector2
var timer: float = 0.0
var element_color: Color = Color.WHITE
var damage_amount: int = 0

func _ready():
	# 创建标签
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)
	add_child(label)
	
	# 设置初始位置和随机偏移
	start_position = Vector2.ZERO
	target_offset = Vector2(randf_range(-50, 50), randf_range(-100, -150))
	
	# 设置文本和颜色 - 使用实际的damage_amount
	label.text = str(damage_amount)  # 这里使用变量而不是固定值
	label.modulate = element_color
	
	# 开始生命周期计时
	timer = lifetime


func setup_damage(amount: int, element: SkillResource.ElementType, position_offset: Vector2):
	# 设置伤害值
	damage_amount = amount
	
	# 更新标签文本
	if label:
		label.text = str(damage_amount)
		
	# 根据元素类型设置颜色
	match element:
		SkillResource.ElementType.Ele_Fire:
			element_color = Color(1, 0.5, 0.3)
		SkillResource.ElementType.Ele_Water:
			element_color = Color(0.3, 0.5, 1)
		SkillResource.ElementType.Ele_Earth:
			element_color = Color(0.8, 0.6, 0.2)
		SkillResource.ElementType.Ele_Light:
			element_color = Color(1, 1, 0.6)
		SkillResource.ElementType.Ele_Dark:
			element_color = Color(0.8, 0.3, 1)
		_:
			element_color = Color(1, 1, 1)
	
	# 设置颜色
	if label:
		label.modulate = element_color
	
	# 设置位置偏移
	position = position_offset

func setup_heal(amount: int, position_offset: Vector2):
	# 设置伤害值
	damage_amount = amount
	
	# 更新标签文本
	if label:
		label.text = str(damage_amount)
		
		label.modulate = Color(0.1, 0.9, 0.3)
	
	# 设置位置偏移
	position = position_offset


func _process(delta):
	# 确保文本是最新的（双重保障）
	if label and label.text != str(damage_amount):
		label.text = str(damage_amount)
	
	# 更新计时器
	timer -= delta
	
	# 当时间结束时移除节点
	if timer <= 0:
		queue_free()
		return
	
	# 计算动画进度 (0-1)
	var progress = 1.0 - (timer / lifetime)
	
	# 位置动画
	var new_position = start_position.lerp(target_offset, progress)
	position = new_position
	
	# 淡出动画
	if progress > 0.5:
		var fade_progress = (progress - 0.5) * 2.0
		label.modulate.a = 1.0 - fade_progress
	
	# 缩放动画
	var scale_value = 1.0
	if progress < 0.2:
		scale_value = 1.0 + sin(progress * 15.0) * 0.3
	elif progress < 0.4:
		scale_value = 1.0 - sin(progress * 10.0) * 0.1
	
	scale = Vector2(scale_value, scale_value)
