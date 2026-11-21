class_name Gap
extends Marker3D
## Marks a stretch of a Section with no floor, which the Runner must jump across. Placed at the
## near edge of the Gap, in the middle across, at floor height 0. The Gap runs along -Z to the
## floor beyond; the floor itself makes the Gap, not this marker.

## A long Gap needs the speed a Slide reaches to jump across; a short one only Run speed.
@export var long := false
