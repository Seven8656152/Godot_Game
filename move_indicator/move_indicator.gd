extends Node2D

@export var max_move_range: float = 100.0
@export var camera_angle: Vector2 = Vector2(0.5, 0.5)  # 控制椭圆形状
@export var center_fill_color: Color = Color(1, 1, 1.0, 0.2)  # 中心颜色
@export var edge_fill_color: Color = Color(1, 1, 1.0, 0.0)    # 边缘颜色
@export var edge_color: Color = Color(0.8, 0.9, 1.0, 0.2)     # 边缘线颜色

@onready var ellipse_area: Polygon2D = $EllipseArea
@onready var ellipse_edge: Line2D = $EllipseEdge

# 椭圆质量（顶点数）
var ellipse_quality: int = 64

# 存储Shader材质以便更新
var shader_mat: ShaderMaterial = null

func _ready():
	# 确保节点存在
	if ellipse_area == null:
		ellipse_area = $EllipseArea
	if ellipse_edge == null:
		ellipse_edge = $EllipseEdge
	
	# 使用Shader材质
	create_radial_shader_material()
	
	# 设置边缘线属性
	if ellipse_edge:
		ellipse_edge.default_color = edge_color
		ellipse_edge.width = 2.0
		ellipse_edge.antialiased = true
	
	# 初始状态隐藏
	visible = false
	
	# 调试：强制显示并设置默认值
	call_deferred("debug_show_indicator")

# 调试函数
func debug_show_indicator():
	show_indicator()
	#set_indicator(Vector2.ZERO, 100.0, Vector2(0.5, 0.5))
	print("Debug: Showing indicator")
	
	# 测试渐变颜色 - 中心红色，边缘蓝色
	set_center_color(Color(0.0, 0.0, 0.5, 0.1))  # 红色
	set_edge_color(Color(0.0, 0.0, 1.0, 0.1))    # 蓝色

# 创建径向渐变的Shader材质
func create_radial_shader_material():
	# 确保没有现有材质干扰
	if ellipse_area.material:
		ellipse_area.material = null
	
	var shader_code = """
	shader_type canvas_item;
	
	uniform vec4 center_color : source_color;
	uniform vec4 edge_color : source_color;
	
	void fragment() {
		// 计算从中心到当前点的距离
		vec2 center = vec2(0.5, 0.5);
		float dist = distance(UV, center);
		
		// 创建径向渐变
		vec4 color = mix(center_color, edge_color, dist);
		
		// 应用颜色
		COLOR = color;
	}
	"""
	
	var new_shader = Shader.new()
	new_shader.code = shader_code
	
	# 创建新材质
	shader_mat = ShaderMaterial.new()
	shader_mat.shader = new_shader
	
	# 设置渐变颜色
	update_shader_colors()
	
	# 应用材质
	ellipse_area.material = shader_mat
	ellipse_area.antialiased = true
	ellipse_area.texture = null

# 更新指示器形状和大小
func update_indicator():
	# 生成椭圆多边形
	var points = generate_ellipse(max_move_range, camera_angle)
	
	# 设置填充区域
	ellipse_area.polygon = points
	
	# 设置UV坐标以确保Shader正确工作
	set_uv_coordinates(points)
	
	# 设置边缘线
	update_ellipse_edge(points)
	
	# 更新Shader参数
	update_shader_colors()

# 设置UV坐标 - 关键修复
func set_uv_coordinates(points: PackedVector2Array):
	var uvs = PackedVector2Array()
	
	# 计算边界
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF
	
	for point in points:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)
	
	# 确保有有效的范围
	if min_x == max_x:
		max_x = min_x + 1.0
	if min_y == max_y:
		max_y = min_y + 1.0
	
	var width = max_x - min_x
	var height = max_y - min_y
	
	# 创建UV坐标 - 映射到0-1范围
	for point in points:
		var uv_x = (point.x - min_x) / width
		var uv_y = (point.y - min_y) / height
		uvs.append(Vector2(uv_x, uv_y))
	
	ellipse_area.uv = uvs


# 更新Shader颜色参数
func update_shader_colors():
	if shader_mat:
		shader_mat.set_shader_parameter("center_color", center_fill_color)
		shader_mat.set_shader_parameter("edge_color", edge_fill_color)

# 更新椭圆边缘线
func update_ellipse_edge(points: PackedVector2Array):
	if !ellipse_edge || points.size() < 3:
		return
		
	# 直接使用多边形点
	ellipse_edge.points = points
	ellipse_edge.default_color = edge_color

# 生成椭圆顶点
func generate_ellipse(radius: float, aspect: Vector2) -> PackedVector2Array:
	var points = PackedVector2Array()
	
	for i in range(ellipse_quality):
		var angle = i * TAU / ellipse_quality
		var point = Vector2(
			radius * aspect.x * cos(angle),
			radius * aspect.y * sin(angle)
		)
		points.append(point)
	
	# 添加闭合点（连接回第一个点）
	points.append(points[0])
	return points

# 显示指示器
func show_indicator():
	visible = true

# 隐藏指示器
func hide_indicator():
	visible = false

# 设置位置和半径
func set_indicator(new_position: Vector2, move_range: float, angle: Vector2):
	position = new_position
	max_move_range = move_range
	camera_angle = angle
	update_indicator()

# 设置中心颜色
func set_center_color(color: Color):
	center_fill_color = color
	update_shader_colors()

# 设置边缘颜色
func set_edge_color(color: Color):
	edge_fill_color = color
	update_shader_colors()

# 强制显示渐变效果（调试用）
func force_gradient_effect():
	# 设置明显的渐变颜色
	set_center_color(Color(1.0, 0.0, 0.0, 1.0))  # 红色
	set_edge_color(Color(0.0, 0.0, 1.0, 1.0))    # 蓝色
