# HealthBar.gd
extends Control

@onready var health_bar: TextureProgressBar = $TextureProgressBar
@export_category("Textures")
@export var frame_texture: Texture2D
@export var fill_texture: Texture2D

var max_health: int = 100
var tween: Tween

func _ready():
	# 确保节点加载
	if not health_bar:
		health_bar = $TextureProgressBar
		if not health_bar:
			push_error("健康条节点未初始化")
			return
	
	# 获取父节点角色
	var parent = get_parent()
	if parent and parent is Character:
		# 连接信号
		if not parent.health_changed.is_connected(update_health):
			parent.health_changed.connect(update_health)
		
		# 初始设置
		max_health = parent.max_health
		health_bar.max_value = max_health
		health_bar.value = parent.health
		setup_health_bar()
	else:
		push_error("父节点不是Character类型")

func setup_health_bar():
	if health_bar:
		health_bar.texture_progress = fill_texture
		health_bar.texture_under = frame_texture
		# 设置默认颜色
		health_bar.tint_progress = Color(0.2, 0.8, 0.2)  # 绿色

# 更新生命值
func update_health(new_health):
	if not health_bar:
		return
	
	# 添加平滑动画
	if tween and tween.is_valid():
		tween.kill()
	
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(health_bar, "value", new_health, 0.3)
	
	# 添加视觉反馈 - 颜色变化
	var health_ratio = float(new_health) / max_health
	if health_ratio > 0.7:
		tween.parallel().tween_property(health_bar, "tint_progress", Color(0.2, 0.8, 0.2), 0.3)  # 绿色
	elif health_ratio > 0.3:
		tween.parallel().tween_property(health_bar, "tint_progress", Color(0.9, 0.7, 0.1), 0.3)  # 黄色
	else:
		tween.parallel().tween_property(health_bar, "tint_progress", Color(0.8, 0.1, 0.1), 0.3)  # 红色
