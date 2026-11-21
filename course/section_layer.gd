class_name SectionLayer
extends Node3D
## Lays the Course's Sections end to end along its own -Z, the Course heading, and frees them
## again: it begins with the start Section, keeps picked Sections laid well ahead of a point
## along the Course and frees those well behind it. Picks at random, by the unlock and no-repeat
## rules. Every place along the Course here is in metres from this node's origin.

## The flat Section laid first. Never picked again.
var start_section: PackedScene
## The Sections picked from.
var section_list: SectionList
## How far ahead of the followed point the laid Sections always reach, m.
var keep_ahead := 250.0
## How far behind the followed point a Section must have ended before it is freed, m.
var keep_behind := 40.0
## How far along the Course the Distance starts, m: unlocks are measured from here.
var distance_start := 0.0
## The Distance a Section of each difficulty must start at to be picked, m. A difficulty with no
## entry may be picked anywhere.
var unlocks: Dictionary[int, float] = { }

## The Sections laid, in order along the Course.
var _laid: Array[Section] = []
## How far along the Course the laid Sections reach, where the next one starts, m.
var _laid_to := 0.0
var _rng := RandomNumberGenerator.new()
## The scene last picked from the list, which is never picked again straight after.
var _last_picked: PackedScene
var _difficulties: Dictionary[PackedScene, int] = { }


## Frees every laid Section and lays the start Section alone. A [param course_seed] other than 0
## picks the same Sections every time; 0 picks fresh ones.
func restart(course_seed: int) -> void:
	for section: Section in _laid:
		remove_child(section)
		section.queue_free()
	_laid.clear()
	_laid_to = 0.0
	_last_picked = null
	if course_seed != 0:
		_rng.seed = course_seed
	else:
		_rng.randomize()
	_lay(start_section)


## Lays picked Sections until they reach [member keep_ahead] beyond [param along] m along the
## Course, and frees those that ended more than [member keep_behind] behind it.
func follow(along: float) -> void:
	_lay_ahead(along + keep_ahead)
	_free_behind(along - keep_behind)


## The Sections now laid, in order along the Course.
func sections() -> Array[Section]:
	return _laid.duplicate()


## Lays picked Sections until they reach [param to] m along the Course.
func _lay_ahead(to: float) -> void:
	while _laid_to < to:
		var scene := _pick()
		if scene == null:
			return
		_lay(scene)
		_last_picked = scene


## Frees the Sections that ended before [param behind] m along the Course.
func _free_behind(behind: float) -> void:
	while not _laid.is_empty() and _start_of(_laid[0]) + _laid[0].length < behind:
		var gone: Section = _laid.pop_front()
		gone.queue_free()


## Picks at random a Section to start where the laid Sections reach: one unlocked there, and not
## the one picked last, unless it is the only one unlocked. Null if none is unlocked.
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


## True if a Section of [param difficulty] may start where the laid Sections reach.
func _is_unlocked(difficulty: int) -> bool:
	var unlock: float = unlocks.get(difficulty, 0.0)
	return _laid_to - distance_start >= unlock


## The difficulty [param scene]'s Section declares. Instances each scene once to find out.
func _difficulty_of(scene: PackedScene) -> int:
	if not _difficulties.has(scene):
		var section: Section = scene.instantiate()
		_difficulties[scene] = section.difficulty
		section.free()
	return _difficulties[scene]


## How far along the Course [param section] starts, m.
func _start_of(section: Section) -> float:
	return section.position.dot(Vector3.FORWARD)


## Lays [param scene] where the laid Sections reach.
func _lay(scene: PackedScene) -> void:
	var section: Section = scene.instantiate()
	section.position = Vector3.FORWARD * _laid_to
	add_child(section)
	_laid.append(section)
	_laid_to += section.length
