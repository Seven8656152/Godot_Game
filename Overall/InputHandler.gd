extends Node

func _input(event):
	if BattleManager.current_state != BattleManager.BattleState.PLAYER_TURN:
		return
		
	
	# 角色选择快捷键
	if event.is_action_pressed("select_char1"):
		BattleManager.select_character_by_index(0)
	elif event.is_action_pressed("select_char2"):
		BattleManager.select_character_by_index(1)
	elif event.is_action_pressed("select_char3"):
		BattleManager.select_character_by_index(2)
	
	
	# 技能选择快捷键
	if event.is_action_pressed("skill1"):
		BattleManager.select_skill(0)
	elif event.is_action_pressed("skill2"):
		BattleManager.select_skill(1)
	elif event.is_action_pressed("skill3"):
		BattleManager.select_skill(2)
	
