class_name GameManager
extends Node

# 战斗状态
enum BattleState { PLAYER_TURN, ANIMATION, ENEMY_TURN }

var current_state: BattleState
var selected_character: Character = null
var current_skill: SkillResource = null
var current_targets: Array = []
var time_line: Array = [] # 时间轴队列: [{character, skill, targets}]
var total_energy: int = 0
var max_energy: int = 100
var player_characters: Array[Character] = []  # 存储玩家角色的数组
var move_speed = 400
var last_skill:SkillResource = null
var last_targets: Array = []

@onready var timeline_display: TimelineDisplay = null

signal character_selected(character)
signal skill_selected(skill)
signal energy_changed(new_value)
signal battle_state_changed(new_state)

func _ready():
	
	await get_tree().process_frame
	timeline_display = get_node("/root/BattleScene/UI/TimelineDisplay")
	# 确保初始状态正确
	timeline_display.visible = false
	
	start_player_turn()


func _physics_process(delta: float) -> void:
	character_move()

# 添加角色到管理器
func register_player_character(character: Character):
	if character.team == "players" and not player_characters.has(character):
		player_characters.append(character)
		# 按角色在场景树中的顺序排序
		player_characters.sort_custom(func(a, b): return a.get_index() < b.get_index())

# 按索引选择角色
func select_character_by_index(index: int):
	if index < 0 or index >= player_characters.size():
		push_warning("Invalid character index: " + str(index))
		return
	var character = player_characters[index]
	if character == selected_character:
		return
	select_character(character)
	


# 选择角色
func select_character(character: Character):
	if current_state != BattleState.PLAYER_TURN:
		return
	
	# 取消之前的选择
	if selected_character:
		selected_character.set_selected(false)
		selected_character.move_indicator.hide_indicator()
	
	selected_character = character
	character.set_selected(true)
	emit_signal("character_selected", character)


# 角色移动
func character_move():
	if not selected_character or selected_character.has_moved:
		return
	
	# 获取椭圆参数
	var a = selected_character.move_range
	var b = selected_character.move_range * selected_character.camera_angle.y
	var center = selected_character.initial_position  # 椭圆中心是角色初始位置
	var threshold: float = 1.01  # 边界阈值
	
	# 1. 处理输入
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# 2. 计算期望速度并移动角色
	selected_character.velocity = input_vector * move_speed
	selected_character.move_and_slide()
	
	# 转换角色状态机
	if selected_character.Character_state != selected_character.CharacterState.MOVING and selected_character.velocity != Vector2.ZERO:
		selected_character.set_state(Character.CharacterState.MOVING)
	elif selected_character.Character_state == selected_character.CharacterState.MOVING and selected_character.velocity == Vector2.ZERO:
		selected_character.set_state(Character.CharacterState.IDLE)
	
	# 3. 计算当前位置相对于椭圆中心的偏移
	var current_pos = selected_character.global_position
	var relative_position = current_pos - center
	
	# 4. 计算椭圆方程值：(x/a)^2 + (y/b)^2
	var ellipse_value = pow(relative_position.x / a, 2) + pow(relative_position.y / b, 2)
	
	# 5. 限制角色在椭圆范围内
	if ellipse_value > threshold:
		# 计算缩放因子使点回到椭圆上
		var scale_factor = 1.0 / sqrt(ellipse_value)
		var clamped_position = center + relative_position * scale_factor
		selected_character.global_position = clamped_position



# 选择技能
func select_skill(skill_index: int):
	if not selected_character or not selected_character.skills.size() > skill_index:
		return
	
		# 检查能量是否足够
	if total_energy < selected_character.skills[skill_index].energy_cost:
		print("Not enough energy!")
		return
	
	current_skill = selected_character.skills[skill_index]
	
	emit_signal("skill_selected", current_skill)


# 确认技能位置
func confirm_skill_position(affected_targets: Array):
	current_targets = affected_targets
	
	if not selected_character or not current_skill:
		return
	
	# 检查能量是否足够
	if total_energy < current_skill.energy_cost:
		print("Not enough energy!")
		return
	
	# 扣除能量
	total_energy -= current_skill.energy_cost
	emit_signal("energy_changed", total_energy)
	
	# 检测是否为持续性技能
	var continuous_result = detect_continuous_skill(current_skill)
	
	# 添加到时间轴
	var action = {
		"character": selected_character,
		"skill": current_skill,
		"targets": affected_targets,
		"continuous_type": continuous_result.type,
		"continuous_duration": continuous_result.duration
	}
	
	# 如果是持续技能2，需要更新时间轴中对应的持续技能1
	if continuous_result.type == "持续技能2":
		if continuous_result.target_index != -1:
			update_continuous_skill_1_duration(continuous_result.target_index)
		else:
			# 如果找不到对应的持续技能1，将当前技能标记为持续技能1
			print("错误：找不到对应的持续技能1，将当前技能标记为持续技能1")
			action.continuous_type = "持续技能1"
			action.continuous_duration = 1
	
	time_line.append(action)
	
	# 添加到时间轴显示
	if timeline_display and selected_character and current_skill:
		timeline_display.add_action(selected_character, current_skill, affected_targets)
	
	# 更新last_skill为当前技能
	last_skill = current_skill
	last_targets = affected_targets
	
	# 重置当前选择
	current_skill = null
	emit_signal("skill_selected", null)
	
	selected_character.has_moved = true
	selected_character.move_indicator.hide_indicator()

# 执行时间轴
func execute_timeline():
	if time_line.is_empty():
		end_player_turn()
		return
	
	current_state = BattleState.ANIMATION
	emit_signal("battle_state_changed", current_state)
	
	# 调用并行执行逻辑
	await execute_timeline_parallel()
	
	# 清空时间轴
	time_line.clear()
	timeline_display.clear_timeline()
	
	# 切换到敌人回合
	end_player_turn()

# 并行执行时间轴
func execute_timeline_parallel():
	# 按角色分组时间轴数据
	var character_skill_groups = group_actions_by_character()
	
	if character_skill_groups.is_empty():
		return
	
	# 统计每个角色的技能数量并通知角色
	for character in character_skill_groups:
		var skill_count = character_skill_groups[character].size()
		character.set_skill_count(skill_count)
	
	# 使用信号来跟踪完成状态
	var completed_characters = 0
	var total_characters = character_skill_groups.size()
	
	# 为每个角色启动并行执行协程
	for character in character_skill_groups:
		var skills_data = character_skill_groups[character]
		# 启动协程但不等待，让它们并行执行
		_execute_character_skills_async(character, skills_data, func(): completed_characters += 1)
	
	# 等待所有角色完成执行
	while completed_characters < total_characters:
		await get_tree().process_frame

# 按角色分组时间轴数据
func group_actions_by_character() -> Dictionary:
	var character_skill_groups = {}
	
	for action in time_line:
		var character = action.character
		if not character_skill_groups.has(character):
			character_skill_groups[character] = []
		character_skill_groups[character].append(action)
	
	return character_skill_groups

# 执行单个角色的所有技能
func execute_character_skills(character: Character, skills_data: Array):
	# 按顺序执行该角色的所有技能
	for i in range(skills_data.size()):
		var action = skills_data[i]
		
		# 等待当前技能完全执行完毕（包括所有伤害时间点）
		await character.execute_skill(action.skill, action.character,action.targets, action.continuous_type, action.continuous_duration)
		
	# 确保技能执行完全结束后才继续下一个技能
	# 等待角色不再处于CASTING状态
	while character.Character_state == Character.CharacterState.CASTING:
		await get_tree().process_frame
		
		# 额外等待一帧确保所有效果都已处理完毕
	await get_tree().process_frame

# 异步执行单个角色的技能序列（用于并行执行）
func _execute_character_skills_async(character: Character, skills_data: Array, completion_callback: Callable):
	# 使用协程异步执行角色技能
	var execution_coroutine = func():
		await execute_character_skills(character, skills_data)
		# 执行完成后调用回调函数
		completion_callback.call()
	
	# 启动协程
	execution_coroutine.call()

# 结束玩家回合
func end_player_turn():
	set_process(false)
	current_state = BattleState.ENEMY_TURN
	emit_signal("battle_state_changed", current_state)
	
	# 执行敌人AI
	execute_enemy_turn()

# 执行敌人回合
func execute_enemy_turn():
	# 敌人AI逻辑
	for enemy in get_tree().get_nodes_in_group("enemies"):
		# 简化的敌人AI：移动到随机位置并使用随机技能
		var possible_moves = get_valid_moves(enemy.grid_position, enemy.move_range)
		if possible_moves.size() > 0:
			var random_move = possible_moves[randi() % possible_moves.size()]
			enemy.move_to(random_move)
		
		if enemy.skills.size() > 0:
			var random_skill = enemy.skills[randi() % enemy.skills.size()]
			var target_pos = get_random_player_position()
			enemy.execute_skill(random_skill, target_pos)
	
	# 结束敌人回合
	start_player_turn()

# 开始玩家回合
func start_player_turn():
	set_process(true)
	current_state = BattleState.PLAYER_TURN
	emit_signal("battle_state_changed", current_state)
	
	# 重置玩家角色状态
	for player in get_tree().get_nodes_in_group("players"):
		player.has_moved = false
		player.initial_position = player.global_position
	
	# 重新计算能量
	recalculate_energy()
	
	# 安全地显示时间轴
	if timeline_display:
		timeline_display.visible = true
		timeline_display.clear_timeline()
	else:
		push_error("Cannot show TimelineDisplay - reference is null")

# 重新计算能量
func recalculate_energy():
	total_energy = max_energy
	emit_signal("energy_changed", total_energy)

# 辅助函数：验证移动位置有效性
func is_valid_move_position(grid_pos: Vector2) -> bool:
	# 实现网格位置验证逻辑
	return true

# 辅助函数：获取有效移动位置
func get_valid_moves(from_pos: Vector2, range: int) -> Array:
	# 返回有效移动位置数组
	return []

# 辅助函数：获取随机玩家位置
func get_random_player_position() -> Vector2:
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		return players[randi() % players.size()].grid_position
	return Vector2.ZERO

# 在状态切换时通知ActionUI
func set_battle_state(new_state: BattleState):
	current_state = new_state
	emit_signal("battle_state_changed", new_state)

# 检测持续性技能
func detect_continuous_skill(current_skill: SkillResource) -> Dictionary:
	# 如果技能不是持续性技能，直接返回非持续技能
	if not current_skill.Continuous_skills:
		return {
			"type": "非持续技能",
			"duration": 0,
			"target_index": -1
		}
	
	# 如果没有上一个技能，或者当前技能与上一个技能不同名，标记为持续技能1
	if last_skill == null or current_skill.name != last_skill.name or current_targets != last_targets:
		return {
			"type": "持续技能1",
			"duration": 1,
			"target_index": -1
		}
	
	# 如果当前技能与上一个技能同名，标记为持续技能2，并查找对应的持续技能1
	var target_index = find_continuous_skill_1_in_timeline(current_skill.name)
	return {
		"type": "持续技能2",
		"duration": 0,
		"target_index": target_index
	}

# 在时间轴中向前查找持续技能1
func find_continuous_skill_1_in_timeline(skill_name: String) -> int:
	# 从时间轴末尾向前查找
	for i in range(time_line.size() - 1, -1, -1):
		var action = time_line[i]
		
		# 如果找到同名技能
		if action.skill.name == skill_name:
			# 如果是持续技能1，返回其索引
			if action.continuous_type == "持续技能1":
				return i
			# 如果是持续技能2，继续向前查找
			elif action.continuous_type == "持续技能2":
				continue
		
		# 如果遇到不同名的技能，停止查找
		else:
			break
	
	# 如果没有找到对应的持续技能1，返回-1
	print("警告：未找到对应的持续技能1，技能名称：", skill_name)
	return -1

# 更新时间轴中持续技能1的持续时间
func update_continuous_skill_1_duration(target_index: int):
	if target_index >= 0 and target_index < time_line.size():
		var target_action = time_line[target_index]
		if target_action.continuous_type == "持续技能1":
			target_action.continuous_duration += 1
			print("更新持续技能1持续时间：", target_action.skill.name, " 持续时间：", target_action.continuous_duration)
		else:
			print("错误：目标索引处的技能不是持续技能1")
	else:
		print("错误：无效的目标索引：", target_index)
