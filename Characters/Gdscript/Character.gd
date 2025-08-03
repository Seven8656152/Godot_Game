class_name Character
extends CharacterBody2D

# 角色属性
#region 角色属性
@export var portrait: Texture
@export var character_name: String = "Character"
@export var team: String = "players" 
@export var level: int = 0
@export var max_health: int = 300
@export var energy: int = 4
@export var move_range: int = 300
@export var D_Atk :int = 15
@export var D_Def :int = 10
@export var M_Atk :int = 15
@export var M_Def :int = 10
@export var Add_DMG :int = 0
@export var D_Strike :int = 0
@export var Multi_Cast :int = 0
@export var Ele_Air :float = 0
@export var Ele_Water :float = 0
@export var Ele_Fire :float = 0
@export var Ele_Earth :float = 0
@export var Ele_Light :float = 0
@export var Ele_Dark :float = 0
@export var Co_Strike :float = 0
@export var Heal :float = 0
@export var Strength :float = 1
@export var Scope :float = 1
@export var Magicka :float = 1
@export var skills: Array[SkillResource] = []
#endregion

var Mouse_follow :bool = false
var current_skill: SkillResource = null
var move_indicator: Node2D
var camera_angle = Vector2(1.0, 0.7)
var initial_position: Vector2 = Vector2.ZERO
var grid_position: Vector2 = Vector2.ZERO
var has_moved: bool = false
var is_selected: bool = false
var current_damage_timers: Array = []
var current_damage_data: Dictionary = {}
var health: int:
	set(value):
		var new_value = clamp(value, 0, max_health)
		if health != new_value:
			health = new_value
			emit_signal("health_changed", health)


# 状态机
enum CharacterState { IDLE, MOVING, CASTING, HURT, DEAD }
enum CastingSubState { PREPARE1, PREPARE2, PREPARE3, FINISHED }
var Character_state: CharacterState = CharacterState.IDLE
var prev_state: CharacterState = CharacterState.IDLE  # 上一个状态（用于恢复）

# casting动画变量
var casting_sub_state: CastingSubState = CastingSubState.PREPARE1
var current_skill_count: int = 0
var skills_executed: int = 0
var animation_queue: Array = []


# 状态效果系统
var active_status_effects: Array[Dictionary] = [] # 存储当前生效的状态效果

signal health_changed(new_health)
signal position_changed(new_grid_pos)
signal died()
signal skill_sequence_completed()  # 添加技能序列完成的信号
signal skill_executed( skill: SkillResource, character:Character, targets: Array, continuous_type: String , continuous_duration: int ) 
signal hit_by_skill( skill: SkillResource, character:Character, targets: Array, continuous_type: String , continuous_duration: int ) 

func _ready():
	set_process(false)
	health = max_health
	add_to_group(team)
	scale = Vector2(global_position.y/1500 +0.7,global_position.y/1500 +0.7)
	if team == "players" and BattleManager:
		BattleManager.register_player_character(self)
	$AnimationPlayer.animation_finished.connect(_on_animation_player_animation_finished)
	
	
	# 预加载指示器场景
	var indicator_scene = preload("res://move_indicator/move_indicator.tscn")
	move_indicator = indicator_scene.instantiate()
	
	# 安全添加子节点
	get_parent().call_deferred("add_child", move_indicator)
	
	# 初始隐藏
	if move_indicator:
		move_indicator.hide_indicator()
		
	# 初始状态
	set_state(CharacterState.IDLE)
	
	print("角色初始化: ", character_name)
	
	# 检查健康条节点
	var health_bar = get_node_or_null("HealthBar")
	if health_bar:
		if not health_changed.is_connected(health_bar.update_health):
			health_changed.connect(health_bar.update_health)
		# 初始更新
		health_bar.update_health(health)


func _physics_process(delta: float) -> void:
	if Mouse_follow:
		$Sprite2D.flip_h = get_global_mouse_position().x < global_position.x
	elif Mouse_follow == false and velocity.x != 0:
		$Sprite2D.flip_h = velocity.x < 0 
	
	scale = Vector2(global_position.y/1500 +0.7,global_position.y/1500 +0.7)
	# 更新状态效果
	update_status_effects(delta)


# 状态转换函数
func set_state(new_state: CharacterState):
	# 保存上一个状态
	prev_state = Character_state
	
	if Character_state == new_state:
		return # 避免重复设置相同状态
		
	# 退出当前状态
	match Character_state:
		CharacterState.IDLE:
			on_exit_idle_state()
		CharacterState.MOVING:
			on_exit_moving_state()
		CharacterState.CASTING:
			on_exit_casting_state()
		CharacterState.HURT:
			on_exit_hurt_state()
	
	# 更新当前状态
	Character_state = new_state
	
	# 进入新状态
	match new_state:
		CharacterState.IDLE:
			on_enter_idle_state()
		CharacterState.MOVING:
			on_enter_moving_state()
		CharacterState.CASTING:
			on_enter_casting_state()
		CharacterState.HURT:
			on_enter_hurt_state()
		CharacterState.DEAD:
			on_enter_dead_state()


#region 状态机运作
# --- IDLE 状态 ---
func on_enter_idle_state():
	# 空闲状态默认动画
	$AnimationPlayer.play("idle")

func on_exit_idle_state():
	pass

# --- MOVING 状态 ---
func on_enter_moving_state():
	set_process(true)
	# 播放移动动画
	if $AnimationPlayer.current_animation != "move":
		$AnimationPlayer.play("move",-1,1.0,true)


func on_exit_moving_state():
	set_process(false)
	# 移动结束逻辑
	$AnimationPlayer.play("idle")
	# 更新网格位置
	grid_position = Vector2(int(global_position.x), int(global_position.y))
	emit_signal("position_changed", grid_position)

# --- CASTING 状态 ---
func on_enter_casting_state():
	# 初始化施法状态
	casting_sub_state = CastingSubState.PREPARE1
	


func on_exit_casting_state():
	# 停止所有动画
	casting_sub_state = CastingSubState.FINISHED

# --- HURT 状态 ---
func on_enter_hurt_state():
	# 播放受伤动画
	if $AnimationPlayer.current_animation != "hurt":
		$AnimationPlayer.play("hurt",-1,1.0,false)
	# 应用视觉反馈（闪烁）
	# $Sprite2D.material.set_shader_parameter("enabled", true)

func on_exit_hurt_state():
	# 停止闪烁效果
	# $Sprite2D.material.set_shader_parameter("enabled", false)
	# 返回空闲状态
	set_state(CharacterState.IDLE)

# --- DEAD 状态 ---
func on_enter_dead_state():
	# 播放死亡动画
	$AnimationPlayer.play("death")
	# 禁用所有交互和碰撞
	set_process(false)
	set_physics_process(false)
	$CollisionShape2D.disabled = true
	# 发出死亡信号
	emit_signal("died")
	# 延迟移除角色
	await $AnimationPlayer.animation_finished
	queue_free()

#endregion


func set_selected(selected: bool):
	is_selected = selected
	# 更新视觉表现
	$Location/SelectionIndicator.visible = selected
	set_state(CharacterState.IDLE)
	# 设置并显示指示器
	if move_indicator and !has_moved :
		move_indicator.set_indicator(initial_position, move_range, camera_angle)
		move_indicator.show_indicator()
	
	Mouse_follow = false


var active_targets = []
var effect_timers = []
var damage_data = {}
var heal_data = {}
var status_effects = []

# 技能序列执行相关变量
var is_executing_sequence: bool = false
var current_sequence_index: int = 0
var skill_sequence_data: Array = []

func execute_skill(skill: SkillResource,character: Character, targets: Array, continuous_type: String = "非持续技能", continuous_duration: int = 0) -> void:
	# 如果是该角色在时间轴上的第一个技能
	var caster = character
	current_skill = skill
	if skills_executed == 0:
		set_state(CharacterState.CASTING)
		casting_sub_state = CastingSubState.PREPARE1
		$AnimationPlayer.play("cast_prepare1")
		await get_tree().create_timer(2.0).timeout
		
	# 添加到动画队列（用于跟踪技能数量）
	animation_queue.append({
		"skill": skill,
		"targets": targets
	})
	
	print("角色 %s 执行技能: %s" % [character_name, skill.name])
	
	# 获取技能目标
	active_targets = targets
	print("检测到目标数: ", active_targets.size())
	
	# 发出技能执行完成信号，包含持续技能信息
	caster.emit_signal("skill_executed",current_skill, caster, targets, continuous_type, continuous_duration, )
	for target in targets:
		target.emit_signal("hit_by_skill",current_skill, caster, targets, continuous_type, continuous_duration, )
	
	# 处理所有效果类型
	for effect_type in skill.effect_types:
		match effect_type:
			SkillResource.EffectType.DAMAGE:
				_setup_damage_effect(skill)
			SkillResource.EffectType.HEAL:
				_setup_heal_effect(skill)
			SkillResource.EffectType.BUFF, SkillResource.EffectType.DEBUFF:
				_setup_status_effects(skill)
	
	
	# 等待技能释放完成
	await get_tree().create_timer(skill.cast_time).timeout
	
	# 更新技能计数
	skills_executed += 1
	
	 # 如果是该角色的最后一个技能
	if skills_executed >= current_skill_count:
		# 切换到结束状态
		await $AnimationPlayer.animation_finished
		casting_sub_state = CastingSubState.PREPARE3
		$AnimationPlayer.play("cast_prepare3")
		await $AnimationPlayer.animation_finished
		
		# 重置状态
		casting_sub_state = CastingSubState.FINISHED
		set_state(CharacterState.IDLE)
		
		# 重置计数器
		current_skill_count = 0
		skills_executed = 0
		animation_queue.clear()
	
	# 清理计时器
	for timer in current_damage_timers:
		if is_instance_valid(timer):
			timer.queue_free()
	current_damage_timers.clear()
	
	# 清除临时数据
	active_targets.clear()
	damage_data.clear()
	heal_data.clear()
	status_effects.clear()
	
	# 重置当前技能
	current_skill = null
	



# 执行技能序列 - 新增方法用于并行时间轴执行
func execute_skill_sequence(skills_data: Array) -> void:
	if skills_data.is_empty():
		print("警告: 角色 %s 的技能序列为空" % character_name)
		emit_signal("skill_sequence_completed")
		return
	
	# 设置序列执行状态
	is_executing_sequence = true
	current_sequence_index = 0
	skill_sequence_data = skills_data
	
	print("角色 %s 开始执行技能序列，共 %d 个技能" % [character_name, skills_data.size()])
	
	# 设置技能计数（用于现有的动画系统）
	set_skill_count(skills_data.size())
	
	# 开始执行第一个技能
	await _execute_next_skill_in_sequence()
	
	# 序列执行完成
	is_executing_sequence = false
	current_sequence_index = 0
	skill_sequence_data.clear()
	
	print("角色 %s 技能序列执行完成" % character_name)
	emit_signal("skill_sequence_completed")


# 执行序列中的下一个技能
func _execute_next_skill_in_sequence() -> void:
	if current_sequence_index >= skill_sequence_data.size():
		return
	
	var skill_data = skill_sequence_data[current_sequence_index]
	var skill = skill_data.skill
	var targets = skill_data.targets
	
	print("角色 %s 执行序列中的技能 %d/%d: %s" % [character_name, current_sequence_index + 1, skill_sequence_data.size(), skill.name])
	
	# 执行当前技能
	await _execute_single_skill_optimized(skill, targets)
	
	# 移动到下一个技能
	current_sequence_index += 1
	
	# 如果还有更多技能，继续执行
	if current_sequence_index < skill_sequence_data.size():
		await _execute_next_skill_in_sequence()


# 优化的单个技能执行方法
func _execute_single_skill_optimized(skill: SkillResource, targets: Array) -> void:
	current_skill = skill
	
	# 如果是序列中的第一个技能，设置casting状态
	if current_sequence_index == 0:
		set_state(CharacterState.CASTING)
		casting_sub_state = CastingSubState.PREPARE1
		$AnimationPlayer.play("cast_prepare1")
	
	print("角色 %s 执行技能: %s" % [character_name, skill.name])
	
	# 获取技能影响区域内的目标
	active_targets = targets
	print("检测到目标数: ", active_targets.size())
	
	# 处理所有效果类型
	for effect_type in skill.effect_types:
		match effect_type:
			SkillResource.EffectType.DAMAGE:
				_setup_damage_effect(skill)
			SkillResource.EffectType.HEAL:
				_setup_heal_effect(skill)
			SkillResource.EffectType.BUFF, SkillResource.EffectType.DEBUFF:
				_setup_status_effects(skill)
	
	# 等待技能释放完成
	await get_tree().create_timer(skill.cast_time).timeout
	
	# 等待所有伤害时间点完成
	await _wait_for_all_damage_timers()
	
	# 更新技能计数
	skills_executed += 1
	
	# 如果是序列中的最后一个技能
	if current_sequence_index >= skill_sequence_data.size() - 1:
		# 切换到结束状态
		if $AnimationPlayer.current_animation != "cast_prepare3":
			casting_sub_state = CastingSubState.PREPARE3
			$AnimationPlayer.play("cast_prepare3")
			await $AnimationPlayer.animation_finished
		
		# 重置状态
		casting_sub_state = CastingSubState.FINISHED
		set_state(CharacterState.IDLE)
		
		# 重置计数器
		current_skill_count = 0
		skills_executed = 0
		animation_queue.clear()
	
	# 清理当前技能的资源
	_cleanup_skill_resources()
	
	# 发出技能执行完成信号
	emit_signal("skill_executed")


# 等待所有伤害计时器完成
func _wait_for_all_damage_timers() -> void:
	if current_damage_timers.is_empty():
		return
	
	# 等待所有计时器完成
	var max_wait_time = 0.0
	for timer in current_damage_timers:
		if is_instance_valid(timer):
			max_wait_time = max(max_wait_time, timer.wait_time)
	
	if max_wait_time > 0:
		await get_tree().create_timer(max_wait_time).timeout


# 清理技能资源
func _cleanup_skill_resources() -> void:
	# 清理计时器
	for timer in current_damage_timers:
		if is_instance_valid(timer):
			timer.queue_free()
	current_damage_timers.clear()
	
	# 清除临时数据
	active_targets.clear()
	damage_data.clear()
	heal_data.clear()
	status_effects.clear()
	
	# 重置当前技能
	current_skill = null


# 检查技能执行是否完成
func is_skill_execution_complete() -> bool:
	return not is_executing_sequence and Character_state != CharacterState.CASTING


# 处理动画完成事件
func _on_animation_player_animation_finished(anim_name):
	match anim_name:
		"cast_prepare1":
			if casting_sub_state == CastingSubState.PREPARE1:
				$AnimationPlayer.play("cast_prepare2")
				casting_sub_state = CastingSubState.PREPARE2
		
		"cast_prepare2":
			if casting_sub_state == CastingSubState.PREPARE2:
				# 继续循环播放prepare2
				$AnimationPlayer.play("cast_prepare2")
		
		"cast_prepare3":
			# 自动回到IDLE状态
			set_state(CharacterState.IDLE)

# 设置该角色在时间轴上的技能数量
func set_skill_count(count: int):
	current_skill_count = count
	skills_executed = 0

# 设置伤害效果
func _setup_damage_effect(skill: SkillResource):
	if active_targets.is_empty():
		return
	# 存储伤害数据
	current_damage_data = skill.calculate_damage(self, active_targets[0])
	# 清除之前的计时器
	for timer in current_damage_timers:
		if is_instance_valid(timer):
			timer.queue_free()
	current_damage_timers.clear()
	# 为每个伤害时间点创建计时器
	for i in range(skill.damage_times.size()):
		var hit_time = skill.damage_times[i]
		# 创建计时器
		var timer = Timer.new()
		add_child(timer)
		timer.wait_time = hit_time
		timer.one_shot = true
		# 使用闭包捕获当前伤害数据
		timer.timeout.connect(func(): 
			_apply_damage_to_targets(active_targets, current_damage_data)
		)
		timer.start()
		current_damage_timers.append(timer)

# 应用伤害到目标
func _apply_damage_to_targets(targets: Array, damage_data: Dictionary):
	for target in targets:
		if is_instance_valid(target) and target.health > 0:
			if current_skill and current_skill.is_valid_target(self, target):
				print("应用伤害: ", damage_data["damage"], " 到 ", target.character_name)
				target.take_damage(damage_data["damage"], damage_data["element"])

# 伤害计时器超时
func _on_damage_timer_timeout(_ignore_param = 0):
	print("伤害计时器触发，目标数: ", active_targets.size())
	for target in active_targets:
		if is_instance_valid(target) and target.health > 0:
			# 使用 current_skill 检查目标有效性
			if current_skill and current_skill.is_valid_target(self, target):
				target.take_damage(damage_data["damage"], damage_data["element"])
				print("对 %s 造成 %d 点伤害" % [target.character_name, damage_data["damage"]])

# 设置治疗效果
func _setup_heal_effect(skill: SkillResource):
	if active_targets.is_empty():
		return
	
	# 计算治疗数据
	heal_data = skill.calculate_heal(self, active_targets[0])
	
	# 立即应用治疗
	for target in active_targets:
		if is_instance_valid(target) and target.health > 0:
			if current_skill and current_skill.is_valid_target(self, target) == false :
				target.take_heal(heal_data["heal"])


# 设置状态效果
func _setup_status_effects(skill: SkillResource):
	if active_targets.is_empty():
		return
	
	# 创建状态效果
	status_effects = skill.create_status_effect()
	
	# 立即应用状态效果
	for target in active_targets:
		if is_instance_valid(target):
			target.apply_status_effect(status_effects)


# 应用状态效果
func apply_status_effect(effect: Dictionary):
	# 添加效果到活动效果列表
	active_status_effects.append(effect)
	
	# 应用效果属性
	_apply_status_effect_modifiers(effect, true)
	
	# 设置效果计时器
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = effect["duration"]
	timer.one_shot = true
	timer.timeout.connect(_on_status_effect_timeout.bind(effect))
	timer.start()

# 状态效果超时
func _on_status_effect_timeout(effect: Dictionary):
	# 移除效果
	active_status_effects.erase(effect)
	
	# 移除效果属性
	_apply_status_effect_modifiers(effect, false)

# 应用状态效果属性修改
func _apply_status_effect_modifiers(effect: Dictionary, apply: bool):
	# 修复：使用GDScript兼容的三元表达式
	var multiplier
	if apply:
		multiplier = 1
	else:
		multiplier = -1
	
	match effect["stat"]:
		SkillResource.StatType.D_ATK:
			D_Atk += effect["amount"] * multiplier
		SkillResource.StatType.M_ATK:
			M_Atk += effect["amount"] * multiplier
		SkillResource.StatType.D_DEF:
			D_Def += effect["amount"] * multiplier
		SkillResource.StatType.M_DEF:
			M_Def += effect["amount"] * multiplier
		SkillResource.StatType.MAX_HEALTH:
			max_health += effect["amount"] * multiplier
			# 确保当前生命值不超过新的最大生命值
			health = min(health, max_health)
		SkillResource.StatType.HEALTH_REGEN:
			Heal += effect["amount"] * multiplier
		# 添加其他属性处理...

# 更新状态效果
func update_status_effects(delta: float):
	# 处理持续恢复效果
	for effect in active_status_effects:
		if effect["stat"] == SkillResource.StatType.HEALTH_REGEN:
			# 每秒恢复生命值
			health = min(health + effect["amount"] * delta, max_health)

# 角色受到伤害
func take_damage(amount: int, element: SkillResource.ElementType):
	set_state(CharacterState.HURT)
	health -= amount
	
	# 显示伤害数字
	show_damage_number(amount, element)
	
	if health <= 0:
		set_state(CharacterState.DEAD)

func show_damage_number(amount: int, element: SkillResource.ElementType):
	var damage_scene = preload("res://DamageDisplay/damage_number.tscn")
	var damage_node = damage_scene.instantiate()
	var offset = Vector2(randf_range(-20, 20), -50)
	
	add_child(damage_node)
	
	if damage_node.has_method("setup_damage"):
		damage_node.setup_damage(amount, element, offset)
	else:
		push_error("伤害数字节点缺少 setup 方法！")
	
	print("显示伤害数字: ", amount)

# 角色治疗函数
func take_heal(amount: int):
	await get_tree().create_timer(1).timeout
	health = min(health + amount, max_health)
	# 显示治疗数值
	show_heal_number(amount)

func show_heal_number(amount: int):
	var damage_scene = preload("res://DamageDisplay/damage_number.tscn")
	var damage_node = damage_scene.instantiate()
	var offset = Vector2(randf_range(-20, 20), -50)
	
	add_child(damage_node)
	
	if damage_node.has_method("setup_heal"):
		damage_node.setup_heal(amount, offset)
	else:
		push_error("伤害数字节点缺少 setup 方法！")
	
	print("显示伤害数字: ", amount)


func set_highlight(active: bool) -> void:
	var sprite = $Sprite2D
	if not sprite:
		return
	
	# 避免重复设置相同状态
	if active == (sprite.material != null):
		return
	
	if active:
		# 创建高亮材质
		var shader_material = ShaderMaterial.new()
		shader_material.shader = preload("res://Resource/Shader/highlight.gdshader")
		shader_material.set_shader_parameter("highlight_color", Color(0, 0.5, 0.6, 0.1))
		shader_material.set_shader_parameter("highlight_intensity", 1.0)
		sprite.material = shader_material
		
	else:
		sprite.material = null


func get_portrait():
	return self.portrait

# 获取碰撞体半径
func get_collision_radius() -> float:
	return 50

# 清理资源
func _exit_tree():
	if move_indicator and is_instance_valid(move_indicator):
		move_indicator.queue_free()


# 判断目标是否是盟友
func is_enemy_of(target: Character) -> bool:
	return team != target.team
func is_ally_of(target: Character) -> bool:
	return team == target.team


func _on_area_indicator_area_entered(area: Area2D) -> void:
	pass # Replace with function body.


func _on_selection_shape_mouse_entered() -> void:
	pass # Replace with function body.
