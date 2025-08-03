extends CanvasLayer

# 节点引用
@onready var container = $EnergyBarContainer
@onready var fill = $EnergyBarContainer/FillContainer/Fill
@onready var background = $EnergyBarContainer/FillContainer/Background
@onready var value_label = $EnergyBarContainer/ValueLabel
@onready var title_label = $EnergyBarContainer/TitleLabel

# 能量变化动画
var tween: Tween

func _ready():
	# 确保BattleManager存在
	if not BattleManager:
		await get_tree().process_frame
	
	# 初始设置
	background.color = Color(0.2, 0.2, 0.2, 0.8)
	fill.color = Color(0.2, 0.8, 0.2)
	
	# 连接信号
	BattleManager.connect("energy_changed", _on_energy_changed)
	get_viewport().connect("size_changed", _on_viewport_size_changed)
	
	# 初始更新
	_on_energy_changed(BattleManager.total_energy)
	_on_viewport_size_changed()  # 初始位置调整

func _on_energy_changed(new_energy):
	# 确保所有节点都已准备就绪
	if not is_instance_valid(fill) or not is_instance_valid(value_label):
		return
	
	var max_energy = BattleManager.max_energy
	if max_energy <= 0:
		max_energy = 1  # 避免除以零
	
	# 计算填充比例
	var fill_ratio = clamp(new_energy / float(max_energy), 0.0, 1.0)
	
	# 更新标签文本
	value_label.text = "%d/%d" % [new_energy, max_energy]
	
	# 停止之前的动画
	if tween and tween.is_valid() and tween.is_running():
		tween.kill()
	
	# 创建平滑动画
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(fill, "size:x", background.size.x * fill_ratio, 0.3)
	
	# 根据能量水平改变颜色
	if fill_ratio < 0.2:
		tween.parallel().tween_property(fill, "color", Color(0.8, 0.1, 0.1), 0.3)
	elif fill_ratio < 0.5:
		tween.parallel().tween_property(fill, "color", Color(0.9, 0.7, 0.1), 0.3)
	else:
		tween.parallel().tween_property(fill, "color", Color(0.2, 0.8, 0.2), 0.3)

# 处理窗口大小变化
func _on_viewport_size_changed():
	# 确保容器节点有效
	if not is_instance_valid(container):
		return
	
	# 获取视口大小
	var viewport_size = get_viewport().get_visible_rect().size
	
	# 更新位置到屏幕顶部中央
	container.position.x = (viewport_size.x - container.size.x) / 2
	container.position.y = 20
	
	# 重新调整填充条大小（如果背景大小改变）
	if is_instance_valid(fill) and is_instance_valid(background):
		var max_energy = BattleManager.max_energy if BattleManager else 100
		var new_energy = BattleManager.total_energy if BattleManager else 0
		var fill_ratio = clamp(new_energy / float(max_energy), 0.0, 1.0)
		fill.size.x = background.size.x * fill_ratio
