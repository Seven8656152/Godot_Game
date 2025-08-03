extends Node2D

var current_skill: SkillResource = null
var character_position: Vector2 = Vector2.ZERO
var mouse_pos: Vector2 = Vector2.ZERO
var points :PackedVector2Array = []


# 区域节点
@onready var area_indicator: Area2D = $AreaIndicator
@onready var collision_polygon: CollisionPolygon2D = $AreaIndicator/CollisionPolygon2D
@onready var polygon: Polygon2D = $AreaIndicator/Polygon2D  # 可视化填充

func _ready():
	if not BattleManager:
		await get_tree().process_frame
	
	BattleManager.connect("skill_selected", _on_skill_selected)
	BattleManager.connect("character_selected", _on_character_selected)
	visible = false


func _physics_process(delta: float) -> void:
	if visible and current_skill and BattleManager.selected_character:
		character_position = BattleManager.selected_character.global_position
		mouse_pos = get_global_mouse_position()
		update_display()

func _on_skill_selected(skill: SkillResource):
	current_skill = skill
	visible = skill != null
	if visible and BattleManager.selected_character:
		character_position = BattleManager.selected_character.global_position
		BattleManager.selected_character.Mouse_follow = true
		_apply_polygon(false)
		update_display()
		set_process(true)


func _on_character_selected(_character: Character):
	if visible and current_skill:
		current_skill = null
		visible = false
		set_process(false)
		clear_highlights()


func update_display():
	if not current_skill:
		return
	
	# 更新区域形状
	match current_skill.area_shape:
		SkillResource.AreaShape.POINT:
			update_point_shape(mouse_pos)
		SkillResource.AreaShape.ELLIPSE_MOUSE:
			update_ellipse_shape(mouse_pos)
		SkillResource.AreaShape.ELLIPSE_SELF:
			update_ellipse_shape(character_position)
		SkillResource.AreaShape.ELLIPSE_SECTOR:
			update_sector_shape()
		SkillResource.AreaShape.RECTANGLE:
			update_rectangle_shape()
	
	highlight_targets_in_range(current_skill)

# --- 形状生成方法 ---
func update_point_shape(center: Vector2):
	if collision_polygon.polygon.is_empty():
		points = _create_circle_polygon(
		center, 
		current_skill.skill_range * current_skill.ellipse_width,
		current_skill.skill_range
		)
		_apply_polygon(true)
		area_indicator.global_position = center
	else:
		area_indicator.global_position = center


func update_ellipse_shape(center: Vector2):
	if collision_polygon.polygon.is_empty():
		points = _create_ellipse_polygon(
		center,
		current_skill.skill_range * current_skill.ellipse_width,
		current_skill.skill_range
		)
		_apply_polygon(true)
		area_indicator.global_position = center
	else:
		area_indicator.global_position = center

func update_sector_shape():
	points = _create_sector_polygon(
	character_position,
	current_skill.skill_range * current_skill.ellipse_width,
	current_skill.skill_range,
	(mouse_pos - character_position).angle(),
	deg_to_rad(current_skill.sector_angle)
	)
	_apply_polygon(true)
	area_indicator.global_position = Vector2.ZERO

# 创建切线四边形
func update_rectangle_shape():
	# 获取椭圆参数
	var inner_a = current_skill.inner_ellipse_major  
	var inner_b = inner_a * 2 / 3   
	var outer_a = current_skill.outer_ellipse_major  
	var outer_b = outer_a * 2 / 3 
	
	# 计算方向角度
	var direction = (mouse_pos - character_position).normalized()
	var theta = direction.angle() - PI / 2
	
	# 生成四边形点集
	points = _create_tangent_quadrilateral(
		character_position,
		inner_a, inner_b,
		outer_a, outer_b,
		theta
	)
	
	_apply_polygon(true)
	area_indicator.global_position = Vector2.ZERO

func _create_tangent_quadrilateral(
	center: Vector2, 
	inner_a: float, inner_b: float, 
	outer_a: float, outer_b: float, 
	theta: float
) -> PackedVector2Array:
	var points_arr = PackedVector2Array()
	
	# 1. 计算内椭圆上的两个对称点 (P1, P2)
	var P1 = center + Vector2(inner_a * cos(theta), inner_b * sin(theta))
	var P2 = center + Vector2(inner_a * cos(theta + PI), inner_b * sin(theta + PI))
	
	# 2. 计算切线方向
	# 内椭圆上点的切线方向向量 (-a*sinθ, b*cosθ)
	var tangent_dir1 = Vector2(-inner_a * sin(theta), inner_b * cos(theta)).normalized()
	
	# 3. 计算切线与外椭圆的交点 (P3, P4)
	var P3 = _find_ellipse_intersection(P1, tangent_dir1, center, outer_a, outer_b)
	var P4 = _find_ellipse_intersection(P2, tangent_dir1, center, outer_a, outer_b)
	
	# 4. 按顺序组合点集 (形成四边形)
	points_arr.append(P1)
	points_arr.append(P2)
	points_arr.append(P4)
	points_arr.append(P3)
	
	return points_arr


# 计算射线与椭圆的交点
func _find_ellipse_intersection(
	start_point: Vector2, 
	direction: Vector2, 
	center: Vector2, 
	a: float, b: float
) -> Vector2:
	# 转换到以椭圆中心为原点的坐标系
	var x0 = start_point.x - center.x
	var y0 = start_point.y - center.y
	var dx = direction.x
	var dy = direction.y
	
	# 解二次方程: At² + Bt + C = 0
	var A = (dx * dx) / (a * a) + (dy * dy) / (b * b)
	var B = 2 * (x0 * dx) / (a * a) + 2 * (y0 * dy) / (b * b)
	var C = (x0 * x0) / (a * a) + (y0 * y0) / (b * b) - 1
	
	# 计算判别式
	var discriminant = B * B - 4 * A * C
	if discriminant < 0:
		# 如果没有交点，返回延长线上的点
		return start_point + direction * 1000
	
	# 计算两个解
	var sqrt_disc = sqrt(discriminant)
	var t1 = (-B + sqrt_disc) / (2 * A)
	var t2 = (-B - sqrt_disc) / (2 * A)
	
	# 选择正数解（向前延伸方向）
	var t = max(t1, t2)
	if t < 0:
		t = min(t1, t2)
	
	# 返回交点坐标
	return start_point + direction * t


# --- 多边形生成工具方法 ---
func _create_circle_polygon(center: Vector2, radius: float, segments: int = 32) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points 

func _create_ellipse_polygon(center: Vector2, a: float, b: float, segments: int = 32) -> PackedVector2Array:
	points = []
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(a * cos(angle), b * sin(angle)))
	return points

func _create_sector_polygon(center: Vector2, a: float, b: float, direction: float, angle: float) -> PackedVector2Array:
	points = []
	points.append(center)
	var segments = max(16, int(angle / (PI / 16)))
	for i in range(segments + 1):
		var current_angle = direction - angle/2 + i * angle/segments
		points.append(center + Vector2(a * cos(current_angle), b * sin(current_angle)))
	return points

func _create_rectangle_polygon(start: Vector2, length: float, width: float, angle: float) -> PackedVector2Array:
	var dir = Vector2(cos(angle), sin(angle))
	var perp = Vector2(-dir.y, dir.x)
	var half_width = width / 2
	
	return PackedVector2Array([
		start - perp * half_width,
		start + perp * half_width,
		start + dir * length + perp * half_width,
		start + dir * length - perp * half_width
	])

func _apply_polygon(active: bool):
	collision_polygon.polygon = []
	polygon.polygon = []
	polygon.color = Color(1, 1, 1, 0)
	
	if active:
		collision_polygon.polygon = points
		polygon.polygon = points
		polygon.color = Color(0.2, 0.3, 0.8, 0.3)


# --- 目标高亮 ---
func highlight_targets_in_range(temp_current_skill:SkillResource):
	var all_characters = []
	match temp_current_skill.target_type:
		SkillResource.TargetType.ENEMY:
			all_characters = get_tree().get_nodes_in_group("enemies")
		SkillResource.TargetType.ALLY:
			all_characters = get_tree().get_nodes_in_group("players")
		SkillResource.TargetType.ALL:
			all_characters = get_tree().get_nodes_in_group("players") + get_tree().get_nodes_in_group("enemies")
	
	for character in all_characters:
		var in_range = area_indicator.overlaps_body(character)
		character.set_highlight(in_range)	

func clear_highlights():
	var all_characters = get_tree().get_nodes_in_group("players") + get_tree().get_nodes_in_group("enemies")
	for character in all_characters:
		character.set_highlight(false)


func get_targets_in_area(confirm_skill: SkillResource) -> Array:
	var all_targets = []
	var affected_targets = []
	match confirm_skill.target_type:
		SkillResource.TargetType.ENEMY:
			all_targets = get_tree().get_nodes_in_group("enemies")
		SkillResource.TargetType.ALLY:
			all_targets = get_tree().get_nodes_in_group("players")
		SkillResource.TargetType.ALL:
			all_targets = get_tree().get_nodes_in_group("players") + get_tree().get_nodes_in_group("enemies")
	
	for target in all_targets:
		var is_target = area_indicator.overlaps_body(target)
		if is_target:
			affected_targets.append(target)
	
	return affected_targets


func _input(event):
	var affected_targets = []
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and visible and current_skill:
			affected_targets = get_targets_in_area(current_skill)
			print(affected_targets)
			BattleManager.confirm_skill_position(affected_targets)
			BattleManager.selected_character.set_state(BattleManager.selected_character.CharacterState.IDLE)
			BattleManager.selected_character.Mouse_follow = false
			set_process(false)
			clear_highlights()
			
			
		elif event.button_index == MOUSE_BUTTON_RIGHT and visible and current_skill:
			current_skill = null
			visible = false
			BattleManager.selected_character.Mouse_follow = false
			set_process(false)
			clear_highlights()
