class_name Hud
extends CanvasLayer
## What the Player sees while an Attempt runs: the Distance.

@onready var _distance: Label = $Distance


## Shows [param metres] as the Distance.
func show_distance(metres: int) -> void:
	_distance.text = "%d m" % metres
