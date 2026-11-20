class_name Course
extends Level
## The endless, straight Course: Sections laid end to end along the Course heading, which is the
## Course node's -Z. It begins with the start Section, with the Runner standing at its start.

## The flat Section every Course begins with. Never picked again.
@export var start_section: PackedScene = preload("res://course/sections/start.tscn")
## The Sections the Course picks from.
@export var section_list: SectionList = preload("res://course/sections.tres")
## Seed for picking Sections; 0 picks a fresh random Course each time.
@export var course_seed := 0
## How far ahead of the Runner the laid Sections always reach, so the Player never sees the end, m.
@export_range(10.0, 1000.0, 1.0, "or_greater", "suffix:m") var keep_ahead: float = 250.0
## How far behind the Runner a Section must have ended before it is freed, m.
@export_range(0.0, 500.0, 1.0, "or_greater", "suffix:m") var keep_behind: float = 40.0
## How far along the Course a Section must start for difficulty 2 to be picked, m.
@export_range(0.0, 2000.0, 1.0, "or_greater", "suffix:m") var difficulty_2_unlock: float = 150.0
## How far along the Course a Section must start for difficulty 3 to be picked, m.
@export_range(0.0, 2000.0, 1.0, "or_greater", "suffix:m") var difficulty_3_unlock: float = 400.0

## The Sections laid, in order along the Course.
var _laid: Array[Section] = []
## How far along the Course the next Section starts, m.
var _end := 0.0
var _rng := RandomNumberGenerator.new()
## The scene last picked from the list, which is never picked again straight after.
var _last_picked: PackedScene
var _difficulties: Dictionary[PackedScene, int] = { }

@onready var _sections: Node3D = $Sections
@onready var _runner: Runner = $Runner


func _ready() -> void:
	super()
	if course_seed != 0:
		_rng.seed = course_seed
	_runner.course_heading = heading()
	_lay(start_section)
	_lay_ahead()


func _physics_process(_delta: float) -> void:
	_lay_ahead()
	_free_behind()


## The Course heading: the fixed direction in the world the Course leads in.
func heading() -> Vector3:
	return -global_basis.z.normalized()


## The Sections now laid, in order along the Course.
func sections() -> Array[Section]:
	return _laid.duplicate()


## How far along the Course the Runner is, m.
func _runner_along() -> float:
	return (_runner.global_position - global_position).dot(heading())


## Lays picked Sections until they reach [member keep_ahead] beyond the Runner.
func _lay_ahead() -> void:
	while _end < _runner_along() + keep_ahead:
		var scene := _pick()
		if scene == null:
			return
		_lay(scene)
		_last_picked = scene


## Picks at random a Section to start at the end of the Course: one unlocked there, and not the
## one picked last, unless it is the only one unlocked. Null if none is unlocked.
func _pick() -> PackedScene:
	var unlocked: Array[PackedScene] = []
	for scene: PackedScene in section_list.sections:
		if _is_unlocked(_difficulty_of(scene)):
			unlocked.append(scene)
	if unlocked.size() > 1:
		unlocked.erase(_last_picked)
	if unlocked.is_empty():
		return null
	return unlocked[_rng.randi_range(0, unlocked.size() - 1)]


## True if a Section of [param difficulty] may start at the end of the Course.
func _is_unlocked(difficulty: int) -> bool:
	if difficulty >= 3:
		return _end >= difficulty_3_unlock
	if difficulty == 2:
		return _end >= difficulty_2_unlock
	return true


## The difficulty [param scene]'s Section declares. Instances each scene once to find out.
func _difficulty_of(scene: PackedScene) -> int:
	if not _difficulties.has(scene):
		var section: Section = scene.instantiate()
		_difficulties[scene] = section.difficulty
		section.free()
	return _difficulties[scene]


## Frees the Sections that ended more than [member keep_behind] behind the Runner.
func _free_behind() -> void:
	var behind := _runner_along() - keep_behind
	while not _laid.is_empty() and _start_of(_laid[0]) + _laid[0].length < behind:
		var gone: Section = _laid.pop_front()
		gone.queue_free()


## How far along the Course [param section] starts, m.
func _start_of(section: Section) -> float:
	return (section.global_position - global_position).dot(heading())


## Lays [param scene] at the end of the Course.
func _lay(scene: PackedScene) -> void:
	var section: Section = scene.instantiate()
	section.position = Vector3.FORWARD * _end
	_sections.add_child(section)
	_laid.append(section)
	_end += section.length
