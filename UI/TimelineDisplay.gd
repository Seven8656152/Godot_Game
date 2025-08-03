extends CanvasLayer
class_name TimelineDisplay

@onready var tracks_container: VBoxContainer = $TracksContainer
@onready var confirm_button: Button = $ConfirmButton

# 时间轴数据结构：{角色: [技能列表]}
var timeline_data: Dictionary = {}
# 每个角色的行动序列：{角色: [ {skill, start_time, end_time, hits} ]}
var character_actions: Dictionary = {}
# 整个时间轴的总时长
var total_time: float = 0.0

# 元素颜色映射
const ELEMENT_COLORS = {
	SkillResource.ElementType.Ele_Air: Color.SKY_BLUE,
	SkillResource.ElementType.Ele_Water: Color.DEEP_SKY_BLUE,
	SkillResource.ElementType.Ele_Fire: Color.ORANGE_RED,
	SkillResource.ElementType.Ele_Earth: Color.SADDLE_BROWN,
	SkillResource.ElementType.Ele_Light: Color.GOLD,
	SkillResource.ElementType.Ele_Dark: Color.PURPLE
}

func _ready():
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_button_pressed)
	
	visible = false
	call_deferred("ensure_tracks")

# 确保有3条轨道
func ensure_tracks():
	if not is_instance_valid(tracks_container):
		return
	
	while tracks_container.get_child_count() < 3:
		var new_track = HBoxContainer.new()
		new_track.name = "Track_" + str(tracks_container.get_child_count() + 1)
		new_track.custom_minimum_size = Vector2(1200, 30)
		new_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var portrait = TextureRect.new()
		portrait.name = "Portrait"
		portrait.custom_minimum_size = Vector2(30, 30)
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		new_track.add_child(portrait)
		
		var timeline = Control.new()
		timeline.name = "Timeline"
		timeline.custom_minimum_size = Vector2(1170, 30)
		timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		timeline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		new_track.add_child(timeline)
		
		tracks_container.add_child(new_track)
	
	# 连接绘制信号
	for i in range(tracks_container.get_child_count()):
		var track = tracks_container.get_child(i)
		if track.get_child_count() >= 2:
			var timeline = track.get_child(1)
			if timeline and not timeline.draw.is_connected(_draw_timeline):
				timeline.draw.connect(_draw_timeline.bind(timeline))

# 添加角色行动
func add_action(character: Character, skill: SkillResource, target: Array):
	if not character:
		return
	
	# 初始化角色数据结构
	if not character_actions.has(character):
		character_actions[character] = []
	
	# 计算新技能的开始时间（前一个技能的结束时间）
	var start_time = 0.0
	if character_actions[character].size() > 0:
		var last_action = character_actions[character][-1]
		start_time = last_action.end_time
	
	# 创建新技能记录
	var new_action = {
		"skill": skill,
		"start_time": start_time,
		"end_time": start_time + skill.cast_time,
		"hits": []
	}
	
	# 添加伤害时间点（转换为绝对时间）
	if skill.has_effect_type(SkillResource.EffectType.DAMAGE):
		for hit_time in skill.damage_times:
			new_action.hits.append({
				"time": start_time + hit_time,  # 绝对时间
				"element": skill.element_type
			})
	
	# 添加到角色行动序列
	character_actions[character].append(new_action)
	
	# 更新总时间
	if new_action.end_time > total_time:
		total_time = new_action.end_time
	
	# 更新UI
	update_display()

# 更新UI显示
func update_display():
	if not is_instance_valid(tracks_container) or tracks_container.get_child_count() < 3:
		return
	
	# 为每个轨道分配角色
	var track_characters = []
	for character in character_actions.keys():
		if track_characters.size() < 3:
			track_characters.append(character)
	
	# 设置轨道内容
	for i in range(3):
		var track = tracks_container.get_child(i)
		
		if track.get_child_count() < 2:
			continue
			
		var portrait = track.get_child(0) as TextureRect
		var timeline = track.get_child(1) as Control
		
		if i < track_characters.size():
			var character = track_characters[i]
			portrait.texture = character.portrait
			portrait.visible = true
			
			# 存储角色所有行动的数据
			if timeline:
				timeline.set_meta("character", character)
				timeline.set_meta("actions", character_actions[character])
				timeline.set_meta("total_time", total_time)
				timeline.queue_redraw()
		else:
			portrait.visible = false
			if timeline:
				timeline.set_meta("actions", [])
				timeline.set_meta("total_time", 0.0)
				timeline.queue_redraw()

# 绘制时间轴
func _draw_timeline(timeline: Control):
	# 检查元数据
	if not timeline.has_meta("actions") or not timeline.has_meta("total_time"):
		return
	
	var actions = timeline.get_meta("actions")
	var total_time = timeline.get_meta("total_time")
	
	# 如果没有行动，绘制空白背景
	if actions.size() == 0 or total_time <= 0:
		var size = timeline.size
		timeline.draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.1, 0.3), true)
		return
	
	var size = timeline.size
	var bg_color = Color(0.1, 0.1, 0.1, 0.7)
	var line_color = Color(0.5, 0.5, 0.5)
	
	# 绘制背景
	timeline.draw_rect(Rect2(Vector2.ZERO, size), bg_color, true)
	
	# 绘制时间线
	var center_y = size.y / 2
	timeline.draw_line(Vector2(0, center_y), Vector2(size.x, center_y), line_color, 1.0)
	
	# 绘制技能区块
	for action in actions:
		var start_x = (action.start_time / total_time) * size.x
		var end_x = (action.end_time / total_time) * size.x
		var skill_width = end_x - start_x
		
		# 绘制技能背景
		var skill_color = Color(0.2, 0.2, 0.3, 0.3)
		timeline.draw_rect(Rect2(start_x, 0, skill_width, size.y), skill_color, true)
		
		# 绘制技能边界
		timeline.draw_line(Vector2(start_x, 0), Vector2(start_x, size.y), Color(0.4, 0.4, 0.5), 1.0)
		timeline.draw_line(Vector2(end_x, 0), Vector2(end_x, size.y), Color(0.4, 0.4, 0.5), 1.0)
		
		# 绘制技能名称
		if skill_width > 50:  # 只在有足够空间时绘制名称
			var font = Control.new().get_theme_default_font()
			var font_size = 10
			var skill_name = action.skill.name
			var text_width = font.get_string_size(skill_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var text_x = start_x + 5
			
			# 确保文本不超出技能区块
			if text_x + text_width > end_x - 5:
				skill_name = skill_name.substr(0, min(8, skill_name.length())) + ".."
				text_width = font.get_string_size(skill_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			
			timeline.draw_string(
				font,
				Vector2(text_x, center_y - 5),
				skill_name,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				Color(0.8, 0.8, 1.0)
			)
	
	# 绘制时间刻度（每0.25秒一个刻度）
	if total_time > 0:
		# 绘制主刻度（整数秒）
		for t in range(0, int(total_time) + 1):
			var x_pos = (t / total_time) * size.x
			
			# 绘制主刻度线
			var main_line_height = 15
			timeline.draw_line(
				Vector2(x_pos, center_y - main_line_height / 2),
				Vector2(x_pos, center_y + main_line_height / 2),
				line_color, 1.5
			)
			
			# 添加主刻度标签
			var font = Control.new().get_theme_default_font()
			var font_size = 12
			var label = str(t) + "s"
			var label_width = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var label_pos = Vector2(x_pos - label_width / 2, center_y + 20)
			
			timeline.draw_string(
				font,
				label_pos,
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size
			)
		
		# 绘制次刻度（0.25秒间隔）
		var quarter_seconds = int(total_time * 4)  # 总四分之一秒数
		for q in range(1, quarter_seconds):  # 跳过0秒
			var time = q * 0.25
			var x_pos = (time / total_time) * size.x
			
			# 只绘制非整数秒的刻度
			if fmod(time, 1.0) != 0:
				var sub_line_height = 10
				timeline.draw_line(
					Vector2(x_pos, center_y - sub_line_height / 2),
					Vector2(x_pos, center_y + sub_line_height / 2),
					Color(0.5, 0.5, 0.5, 0.7), 0.8
				)
	
	# 绘制伤害点
	for action in actions:
		for hit in action.hits:
			var x_pos = (hit.time / total_time) * size.x
			var color = ELEMENT_COLORS.get(hit.element, Color.WHITE)
			
			# 绘制伤害点
			timeline.draw_circle(Vector2(x_pos, center_y), 6, color)
			
			# 绘制白色外圈
			timeline.draw_arc(Vector2(x_pos, center_y), 7, 0, TAU, 32, Color(1, 1, 1, 0.8), 1.5)
			
			# 绘制元素首字母
			var element_char = _get_element_char(hit.element)
			var font = Control.new().get_theme_default_font()
			var font_size = 10
			var char_size = font.get_string_size(element_char, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_pos = Vector2(x_pos - char_size.x / 2, center_y + char_size.y / 2 - 2)
			
			timeline.draw_string(
				font,
				text_pos,
				element_char,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				Color(0, 0, 0, 0.8)
			)

# 获取元素首字母
func _get_element_char(element: SkillResource.ElementType) -> String:
	match element:
		SkillResource.ElementType.Ele_Air: return "A"
		SkillResource.ElementType.Ele_Water: return "W"
		SkillResource.ElementType.Ele_Fire: return "F"
		SkillResource.ElementType.Ele_Earth: return "E"
		SkillResource.ElementType.Ele_Light: return "L"
		SkillResource.ElementType.Ele_Dark: return "D"
		_: return "?"

# 确认按钮按下
func _on_confirm_button_pressed():
	if BattleManager:
		BattleManager.execute_timeline()
	clear_timeline()

# 清空时间轴
func clear_timeline():
	character_actions.clear()
	total_time = 0.0
	
	if is_instance_valid(tracks_container):
		for i in range(tracks_container.get_child_count()):
			var track = tracks_container.get_child(i)
			if track.get_child_count() >= 2:
				var timeline = track.get_child(1) as Control
				if timeline:
					timeline.set_meta("actions", [])
					timeline.set_meta("total_time", 0.0)
					timeline.queue_redraw()
			
			# 隐藏头像
			if track.get_child_count() > 0:
				var portrait = track.get_child(0) as TextureRect
				if portrait:
					portrait.visible = false
