class_name EndScreen
extends CanvasLayer
## What the Player sees when an Attempt ends: how it ended, its Distance, the Best distance, and
## how to start the next.

@onready var _title: Label = $Centre/Lines/Title
@onready var _distance: Label = $Centre/Lines/Distance
@onready var _best: Label = $Centre/Lines/Best
@onready var _new_best: Label = $Centre/Lines/NewBest


## Shows the screen for an Attempt that ended by [param ending] at [param distance] m, with
## [param best] m the Best distance; [param new_best] if this Attempt just set it.
func show_ending(ending: Course.Ending, distance: int, best: int, new_best: bool) -> void:
	_title.text = "You stalled" if ending == Course.Ending.STALL else "You fell"
	_distance.text = "Distance: %d m" % distance
	_best.text = "Best: %d m" % best
	_new_best.visible = new_best
	visible = true
