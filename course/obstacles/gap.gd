class_name Gap
extends Marker3D
## Marks a stretch of a Section with no floor, which the Runner must jump across. Placed at the
## near edge of the Gap, in the middle across, at the height of the floor it is jumped from:
## floor height 0, or higher for a Gap that takes off higher than it lands. The Gap runs along
## -Z to the floor beyond, which is never higher than the take-off; the floor itself makes the
## Gap, not this marker.

## How far a Gap reaches, and so the speed the Runner needs to jump across it.
enum Size {
	## Within a jump at Run speed.
	SHORT,
	## Beyond a jump at Run speed, landing without a Mantle, but within one at the speed a Slide
	## begins with. A jump at Run speed that ends in a Mantle onto the far edge may still reach
	## across.
	LONG,
	## Beyond a jump at the speed a Slide begins with, but within one at the speed a Slide begun
	## at the top of the Slope that runs right to its near edge reaches at the bottom.
	WIDE,
}

## How far the Gap reaches: a Short gap needs only Run speed to jump across, a Long gap the speed
## a Slide begins with to land beyond it without a Mantle, and a Wide gap the speed a Slide gains
## down the Slope before it.
@export var size := Size.SHORT
