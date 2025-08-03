extends Node2D

@onready var holy_light_texture: Node2D = $Holy_Light_Texture
@onready var holy_light_light: Sprite2D = $Holy_Light_Texture/Holy_Light_Light
@onready var holy_light_sword: Sprite2D = $Holy_Light_Texture/Holy_Light_Sword
@onready var character: Character = $".."
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_player_2: AnimationPlayer = $AnimationPlayer2

var animation_target: Array = []
var rng = RandomNumberGenerator.new()

func _ready():
	character.connect("skill_executed",_on_skill_executed)
	character.connect("hit_by_skill",_on_hit_by_skill)
	rng.randomize()  # 初始化独立种子
	holy_light_light.visible = false
	holy_light_sword.visible = false

func _on_skill_executed( skill, caster, targets: Array, continuous_type, continuous_duration):
	animation_target = targets
	
	if continuous_type == "非持续技能" or "持续技能2":
		pass
		
	if continuous_type == "持续技能1":
		animation_player.play("Holy_Light/Light1")
		await animation_player.animation_finished
		
		animation_player.play("Holy_Light/Light2")
		await animation_player.animation_finished
			
		while  continuous_duration > 1:
			animation_player.play("Holy_Light/Light2")
			await animation_player.animation_finished
			animation_player.play("Holy_Light/Light2")
			await animation_player.animation_finished
			continuous_duration -= 1
		
		animation_player.play("Holy_Light/Light3")
		await animation_player.animation_finished


func _on_hit_by_skill( skill, caster, targets: Array, continuous_type, continuous_duration):
	if skill.name != "Holy_Light":
		return
		
	
	if skill.is_valid_target(character, caster) == true :
		animation_player_2.play("Holy_Light/Sword")
	
	if continuous_type == "非持续技能" or "持续技能2":
		pass
		
	if continuous_type == "持续技能1":
		animation_player.play("Holy_Light/Light1")
		await animation_player.animation_finished
		
		animation_player.play("Holy_Light/Light2")
		await animation_player.animation_finished
			
		while  continuous_duration > 1:
			animation_player.play("Holy_Light/Light2")
			await animation_player.animation_finished
			animation_player.play("Holy_Light/Light2")
			await animation_player.animation_finished
			continuous_duration -= 1
		
		animation_player.play("Holy_Light/Light3")
		await animation_player.animation_finished
