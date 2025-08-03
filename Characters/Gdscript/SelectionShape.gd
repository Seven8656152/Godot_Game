extends Area2D

var battle_manager: Node = null


func _ready():
	# 连接鼠标进入信号
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	if not battle_manager:
		battle_manager = get_node("/root/BattleManager") 


func _on_mouse_entered():
	if _is_point_skill_active():
		var character = get_parent().get_parent() as Character
		character.set_highlight(true)

func _on_mouse_exited():
	if _is_point_skill_active():
		var character = get_parent().get_parent() as Character
		character.set_highlight(false)



func _is_point_skill_active() -> bool:
	if battle_manager and battle_manager.current_skill:
		return battle_manager.current_skill.area_shape == SkillResource.AreaShape.POINT
	return false
