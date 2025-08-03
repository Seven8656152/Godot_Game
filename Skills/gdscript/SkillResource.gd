class_name SkillResource
extends Resource

#region 枚举定义
enum TargetType { ENEMY, ALLY, ALL }
enum ElementType {Ele_Air, Ele_Water, Ele_Fire, Ele_Earth, Ele_Light, Ele_Dark}
enum DamageType { D_Atk, M_Atk }
enum AreaShape { 
	POINT,          # 单体目标
	ELLIPSE_MOUSE,  # 以鼠标位置为中心的椭圆
	ELLIPSE_SELF,   # 以自身为中心的椭圆
	ELLIPSE_SECTOR, # 以自身为中心的椭圆扇形
	RECTANGLE       # 以自身为起点的长方形
}

enum EffectType {
	DAMAGE,      # 伤害效果
	HEAL,        # 恢复效果
	BUFF,        # 增益效果
	DEBUFF       # 减益效果
}

enum StatType {
	D_ATK,
	M_ATK,
	D_DEF,
	M_DEF,
	MAX_HEALTH,
	HEALTH_REGEN,
	ENERGY_REGEN,
	MOVE_SPEED,
	ATTACK_SPEED,
	CRIT_CHANCE,
	CRIT_DAMAGE
}
#endregion

#region 基础属性
@export_group("Basic Properties")
@export var name: String = "Skill"
@export var description: String = "Skill description"
@export var icon: Texture2D 
@export var energy_cost: int = 1 # 能量消耗
@export var cast_time: float = 1.0 # 技能释放时间
@export var target_type: TargetType = TargetType.ENEMY
@export var area_shape: AreaShape = AreaShape.POINT  # 技能范围形状
@export var Continuous_skills: bool = false
@export var skill_distance: int = 100 # 技能攻击距离（施法距离）
@export var skill_range: int = 100 # 技能范围（影响范围）
@export var animation_name: String = "attack"
#endregion

#region 区域形状参数
@export_group("Area Shape Parameters")
@export var sector_angle: float = 90.0  # 扇形角度（度）
@export var ellipse_width: float = 1.5  # 椭圆宽度比例
@export var inner_ellipse_major = 60   #矩形宽度
@export var outer_ellipse_major = 300   #矩形长度
#endregion

#region 技能效果
@export_group("Skill Effects")
@export var effect_types: Array[EffectType] = [EffectType.DAMAGE] # 技能包含的效果类型

# 伤害效果参数
@export_subgroup("Damage Effect")
@export var damage_type: DamageType = DamageType.D_Atk
@export var element_type: ElementType = ElementType.Ele_Light
@export var damage_base: int = 10 # 基础伤害
@export var damage_times: Array[float] = [0.5] # 伤害时间点数组
@export var D_Atk_bonus: float = 0 
@export var M_Atk_bonus: float = 0

# 恢复效果参数
@export_subgroup("Heal Effect")
@export var heal_amount: int = 20 # 基础治疗量
@export var heal_percentage: float = 0.0 # 最大生命值百分比治疗

# Buff/Debuff效果参数
@export_subgroup("Buff/Debuff Effect")
@export var buff_duration: float = 10.0 # 效果持续时间
@export var buff_stat: StatType = StatType.D_ATK # 影响的属性
@export var buff_amount: float = 10.0 # 属性变化量
@export var buff_is_percentage: bool = false # 是否为百分比加成
@export var buff_stacks: int = 1 # 可叠加层数
@export var buff_is_dispellable: bool = true # 是否可被驱散
#endregion

#region 效果计算
# 计算伤害效果
func calculate_damage(caster: Character, target: Character) -> Dictionary:
	var base_damage = damage_base
	var element_bonus: float = 0
	var attack_bonus: float = 0
	var attribute_bonus :float = (D_Atk_bonus * caster.D_Atk) + (M_Atk_bonus * caster.M_Atk)
	
	# 元素类型的伤害计算
	match element_type:
		ElementType.Ele_Air:
			element_bonus = (base_damage + attribute_bonus) * (caster.Ele_Air / 100 + 1)
		ElementType.Ele_Fire:
			element_bonus = (base_damage + attribute_bonus) * (caster.Ele_Fire / 100 + 1)
		ElementType.Ele_Water:
			element_bonus = (base_damage + attribute_bonus) * (caster.Ele_Water / 100 + 1)
		ElementType.Ele_Earth:
			element_bonus = (base_damage + attribute_bonus) * (caster.Ele_Earth / 100 + 1)
		ElementType.Ele_Light:
			element_bonus = (base_damage + attribute_bonus) * (caster.Ele_Light / 100 + 1)
		ElementType.Ele_Dark:
			element_bonus = (base_damage + attribute_bonus) * (caster.Ele_Dark / 100 + 1)
	
	# 防御率计算 + 神力打击/多重施法计算
	var ERA: float = 0.0
	match damage_type:
		DamageType.D_Atk:  
			ERA = target.D_Def * (1 - (caster.D_Strike * 0.05)) / (target.D_Def * (1 - (caster.D_Strike * 0.05)) + 30)
			attack_bonus = element_bonus
		DamageType.M_Atk: 
			ERA = target.M_Def / (target.M_Def + 30)
			attack_bonus = element_bonus * (0.5 + (caster.Multi_Cast * 0.025)) if caster.Multi_Cast != 0 else element_bonus
	
	# 最终伤害公式
	var final_damage = max(1, attack_bonus * (1 - ERA))
	
	return {
		"damage": int(final_damage),
		"element": element_type
	}

# 计算恢复效果
func calculate_heal(caster: Character, target: Character) -> Dictionary:
	var total_heal = heal_amount
	
	if heal_percentage > 0:
		total_heal += target.max_health * heal_percentage
	
	return {
		"heal": int(total_heal),
	}

# 创建buff/debuff效果
func create_status_effect() -> Dictionary:
	return {
		"duration": buff_duration,
		"stat": buff_stat,
		"amount": buff_amount,
		"is_percentage": buff_is_percentage,
		"stacks": buff_stacks,
		"is_dispellable": buff_is_dispellable,
		"is_buff": effect_types.has(EffectType.BUFF) # 标记是buff还是debuff
	}
#endregion

#region 检查目标是否友方

func is_valid_target(caster: Character, target: Character) -> bool:
	# 确保目标有效且不是施法者自身
	if target == caster:
		return false
	
	# 检查团队关系
	match target_type:
		TargetType.ENEMY: 
			return caster.is_enemy_of(target)
		TargetType.ALLY: 
			return caster.is_ally_of(target)
		TargetType.ALL: 
			if caster.is_enemy_of(target):
				return true
			if caster.is_ally_of(target):
				return false
	
	return false
#endregion

#region 辅助功能
# 验证伤害时间点
func validate_damage_times():
	if effect_types.has(EffectType.DAMAGE):
		damage_times.sort()
		for time in damage_times:
			if time > cast_time:
				push_warning("技能 %s 的伤害时间点 %.1f 超过了释放时间 %.1f" % [name, time, cast_time])

# 检查是否包含特定效果类型
func has_effect_type(effect_type: EffectType) -> bool:
	return effect_types.has(effect_type)
#endregion
