extends Sprite2D

@onready var selection_shape: Area2D = $SelectionShape
@onready var character: Character = $".."


func _ready():
	if selection_shape == null:
		for child in get_children():
			if child is Area2D:
				selection_shape = child
				break
	selection_shape.mouse_entered.connect(character.set_highlight.bind(true))
	selection_shape.mouse_exited.connect(character.set_highlight.bind(false))
