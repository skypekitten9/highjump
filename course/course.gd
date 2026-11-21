class_name Course
extends Level
## The endless, straight Course: Sections laid end to end along the Course heading, which is the
## Course node's -Z. It begins with the start Section, with the Runner standing at its start.
## Runs the Attempt too: it ends when the Runner falls or Stalls, and the end screen appears. Jump
## or a click then starts a new Attempt: a fresh Runner on a freshly laid Course.
## While the mouse isn't captured the Attempt pauses: the Runner, the Course and the Stall clock
## stand still. The click that captures the mouse again resumes it.

## Emitted when the Attempt ends, by [param ending].
signal attempt_ended(ending: Ending)

## How an Attempt ended.
enum Ending {
	NONE,
	FALL,
	STALL,
}

## The shortest [member stall_time] can be, s. With none, the Runner would always have made no
## progress in it.
const MIN_STALL_TIME := 0.05

## The flat Section every Course begins with. Never picked again.
@export var start_section: PackedScene = preload("res://course/sections/start.tscn")
## The Sections the Course picks from.
@export var section_list: SectionList = preload("res://course/sections.tres")
## The Runner the Course makes for each Attempt.
@export var runner_scene: PackedScene = preload("res://runner/runner.tscn")
## How far along the start Section the Runner starts each Attempt, m.
@export_range(0.0, 30.0, 0.5, "or_greater", "suffix:m") var runner_start: float = 2.0
## Seed for picking Sections; 0 picks a fresh random Course each time.
@export var course_seed := 0
## How far ahead of the Runner the laid Sections always reach, so the Player never sees the end, m.
@export_range(10.0, 1000.0, 1.0, "or_greater", "suffix:m") var keep_ahead: float = 250.0
## How far behind the Runner a Section must have ended before it is freed, m.
@export_range(0.0, 500.0, 1.0, "or_greater", "suffix:m") var keep_behind: float = 40.0
## The Distance a Section must start at for difficulty 2 to be picked, m.
@export_range(0.0, 2000.0, 1.0, "or_greater", "suffix:m") var difficulty_2_unlock: float = 150.0
## The Distance a Section must start at for difficulty 3 to be picked, m.
@export_range(0.0, 2000.0, 1.0, "or_greater", "suffix:m") var difficulty_3_unlock: float = 400.0

## How far below floor height 0 the Runner's feet must be for it to have fallen, m.
@export_range(0.0, 100.0, 0.5, "or_greater", "suffix:m") var fall_depth: float = 10.0
## The Runner Stalls if it gets less than [member stall_progress] along the Course in this long, s.
@export_range(0.1, 10.0, 0.05, "or_greater", "suffix:s") var stall_time: float = 1.0:
	set(value):
		stall_time = maxf(value, MIN_STALL_TIME)
## How far along the Course the Runner must get in [member stall_time] not to Stall, m.
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:m") var stall_progress: float = 1.0
## Where the Best distance is saved between sessions.
@export var best_distance_path := "user://best_distance.save"

var _ending := Ending.NONE
## How long the Attempt has run, s.
var _attempt_time := 0.0
## How far along the Course the Runner was, oldest first, going back to the newest at least
## [member stall_time] old.
var _progress: Array[ProgressSample] = []
## The Distance: the furthest along the Course the Runner has got this Attempt, from where it
## started, in whole metres.
var _distance := 0
## The Best distance: the greatest Distance of any Attempt, in whole metres.
var _best_distance := 0
## Whether the Attempt is paused, because the mouse isn't captured.
var _paused := false

var _runner: Runner

@onready var _sections: SectionLayer = $Sections
@onready var _end_screen: EndScreen = $EndScreen
@onready var _hud: Hud = $Hud


func _ready() -> void:
	super()
	_best_distance = BestDistance.read(best_distance_path)
	_start_attempt()


func _unhandled_input(event: InputEvent) -> void:
	# While paused (or about to be, the capture having just gone), an input only ever captures the
	# mouse again, which Level does: the capturing click is not also a retry. The Attempt resumes
	# on the next physics frame, so the click is spent by then.
	var pausing := _paused or not mouse.is_captured()
	super(event)
	if pausing:
		return
	if is_attempt_over() and _is_retry(event):
		_start_attempt()


func _physics_process(delta: float) -> void:
	_set_paused(not mouse.is_captured())
	if _paused:
		return
	_sections.follow(runner_along())
	if not is_attempt_over():
		_attempt_time += delta
		_note_distance()
		_check_for_end()


## True once the Attempt has ended.
func is_attempt_over() -> bool:
	return _ending != Ending.NONE


## True while the Attempt is paused, because the mouse isn't captured.
func is_paused() -> bool:
	return _paused


## How the Attempt ended; [constant Ending.NONE] while it runs.
func ending() -> Ending:
	return _ending


## The Distance: how far along the Course heading the Runner has got this Attempt, from where it
## started, in whole metres. Never goes down.
func distance() -> int:
	return _distance


## The Best distance: the greatest Distance of any Attempt, kept between sessions, in whole metres.
func best_distance() -> int:
	return _best_distance


## The Course heading: the fixed direction in the world the Course leads in.
func heading() -> Vector3:
	return -global_basis.z.normalized()


## The Sections now laid, in order along the Course.
func sections() -> Array[Section]:
	return _sections.sections()


## How far along the Course the Runner is, m.
func runner_along() -> float:
	return _along(_runner.global_position)


## How far along the Course [param point] is, m.
func _along(point: Vector3) -> float:
	return (point - global_position).dot(heading())


## Starts an Attempt: the end screen gone, a fresh Runner standing still on the start Section,
## and a freshly picked Course ahead of it. A seeded Course picks the same Sections every time.
func _start_attempt() -> void:
	_ending = Ending.NONE
	_attempt_time = 0.0
	_progress.clear()
	_distance = 0
	_hud.show_distance(_distance)
	_end_screen.hide()
	_replace_runner()
	_sections.start_section = start_section
	_sections.section_list = section_list
	_sections.keep_ahead = keep_ahead
	_sections.keep_behind = keep_behind
	_sections.distance_start = runner_start
	_sections.unlocks = { 2: difficulty_2_unlock, 3: difficulty_3_unlock }
	_sections.restart(course_seed)
	_sections.follow(runner_along())


## Pauses the Attempt if [param paused], resumes it if not: the Runner stands still while it is
## paused, and responds again when it resumes, unless the Attempt is over.
func _set_paused(paused: bool) -> void:
	if paused == _paused:
		return
	_paused = paused
	_hud.show_paused(paused)
	if paused:
		_runner.process_mode = Node.PROCESS_MODE_DISABLED
	elif not is_attempt_over():
		_runner.process_mode = Node.PROCESS_MODE_INHERIT


## Replaces the Runner, if there is one, with a fresh one standing at the start of the Course.
func _replace_runner() -> void:
	if _runner != null:
		remove_child(_runner)
		_runner.queue_free()
	_runner = runner_scene.instantiate()
	_runner.name = "Runner"
	_runner.position = Vector3.FORWARD * runner_start
	add_child(_runner)
	_runner.course_heading = heading()


## True if [param event] is the Player asking for a new Attempt: jump, or a click.
func _is_retry(event: InputEvent) -> bool:
	if event.is_action_pressed("jump"):
		return true
	var click := event as InputEventMouseButton
	return click != null and click.pressed


## Raises the Distance to where the Runner is now, if that is further, and shows it.
func _note_distance() -> void:
	_distance = maxi(_distance, floori(runner_along() - runner_start))
	_hud.show_distance(_distance)


## Ends the Attempt if the Runner has fallen or Stalled.
func _check_for_end() -> void:
	var feet: float = _runner.global_position.y - global_position.y
	if feet < -fall_depth:
		_end_attempt(Ending.FALL)
	elif _has_stalled():
		_end_attempt(Ending.STALL)


## Notes how far along the Course the Runner is now, and true if it got less than
## [member stall_progress] along it in the last [member stall_time]. Never true before the
## Attempt has run that long.
func _has_stalled() -> bool:
	var along := runner_along()
	_progress.append(ProgressSample.new(_attempt_time, along))
	var since: float = _attempt_time - stall_time
	while _progress.size() > 1 and _progress[1].time <= since:
		_progress.pop_front()
	var oldest: ProgressSample = _progress[0]
	return oldest.time <= since and along - oldest.along < stall_progress


## Ends the Attempt by [param how]: the Runner stops responding, a Distance beyond the Best
## distance is saved as the new one, and the end screen appears.
func _end_attempt(how: Ending) -> void:
	_ending = how
	_runner.process_mode = Node.PROCESS_MODE_DISABLED
	var new_best := _distance > _best_distance
	if new_best:
		_best_distance = _distance
		BestDistance.write(best_distance_path, _best_distance)
	_end_screen.show_ending(how, _distance, _best_distance, new_best)
	attempt_ended.emit(how)


## How far along the Course the Runner was at a time into the Attempt.
class ProgressSample:
	## Time into the Attempt, s.
	var time: float
	## How far along the Course the Runner was then, m.
	var along: float


	func _init(p_time: float, p_along: float) -> void:
		time = p_time
		along = p_along
