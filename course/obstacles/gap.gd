class_name Gap
extends Marker3D
## Marks a stretch of a Section with no floor, which the Runner must jump across. Placed at the
## near edge of the Gap, in the middle across, at floor height 0. The Gap runs along -Z to the
## floor beyond; the floor itself makes the Gap, not this marker.

## How far a Gap reaches, and so the speed the Runner needs to jump across it.
enum Size {
	## Within a jump at Run speed.
	SHORT,
	## Beyond a jump at Run speed, but within one at the speed a Slide reaches.
	LONG,
}

## How far the Gap reaches: a Short gap needs only Run speed to jump across, a Long gap the speed
## a Slide reaches.
@export var size := Size.SHORT
