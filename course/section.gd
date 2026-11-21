class_name Section
extends Node3D
## One hand-built piece of the Course. Its origin is the middle of its start, at floor height 0,
## and it runs [member length] along its -Z. Every Section is [constant WIDTH] wide with open
## edges, and starts and ends at floor height 0, so any two can be laid end to end.

## How wide every Section is, m.
const WIDTH := 8.0
## The shortest a Section can be, m. The Course lays Sections until they reach far enough ahead,
## so a Section of no length would never get there.
const MIN_LENGTH := 1.0
## The easiest and hardest a Section can be.
const MIN_DIFFICULTY := 1
const MAX_DIFFICULTY := 3

## How far the Section runs along the Course, m.
@export_range(1.0, 200.0, 0.5, "or_greater", "suffix:m") var length: float = 20.0:
	set(value):
		length = maxf(value, MIN_LENGTH)
## How hard the Section is, from 1 to 3. Harder Sections unlock further along the Course.
@export_range(1, 3) var difficulty: int = 1:
	set(value):
		difficulty = clampi(value, MIN_DIFFICULTY, MAX_DIFFICULTY)
