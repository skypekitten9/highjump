extends GdUnitTestSuite
## The music plays from the start once, then loops from the loop start to the end of the song
## (see docs/adr/0009). It plays on the Music bus for the whole session: a new Attempt doesn't
## restart it.

const CourseScene := preload("res://course/course.tscn")
const Song := preload("res://music/retro.ogg")
const SEED := 4711
## Where these tests' Courses save the Best distance, so the Player's own is never touched.
const SAVE_PATH := "user://music_test.save"
## The song's sample rate, Hz.
const SAMPLE_RATE := 44100.0
## The sample the loop starts at: a downbeat exactly 208 beats before the song's end.
const LOOP_START_SAMPLE := 838008
## The song's length, in samples: it ends where the loop jumps back.
const LENGTH_SAMPLES := 6454013
## How far the Music bus sits below Master, dB.
const MUSIC_BUS_DB := -6.0


func after_test() -> void:
	DirAccess.remove_absolute(SAVE_PATH)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## A fresh, seeded Course, not yet in the tree.
func _course() -> Course:
	var course: Course = auto_free(CourseScene.instantiate())
	course.course_seed = SEED
	course.best_distance_path = SAVE_PATH
	return course


func _music_of(course: Course) -> AudioStreamPlayer:
	return course.get_node("Music")


func test_the_song_loops_back_to_the_loop_start() -> void:
	assert_bool(Song.loop).is_true()
	assert_float(Song.loop_offset).is_equal_approx(LOOP_START_SAMPLE / SAMPLE_RATE, 1.0e-6)


func test_the_song_ends_exactly_208_beats_after_the_loop_start() -> void:
	var beats_at_98_bpm := 208.0 * 60.0 / 98.0
	assert_float(Song.get_length()).is_equal_approx(LENGTH_SAMPLES / SAMPLE_RATE, 1.0e-3)
	assert_float(Song.get_length() - Song.loop_offset).is_equal_approx(beats_at_98_bpm, 1.0e-3)


func test_the_music_bus_is_quieter_than_master() -> void:
	var bus := AudioServer.get_bus_index("Music")
	assert_int(bus).is_not_equal(-1)
	assert_float(AudioServer.get_bus_volume_db(bus)).is_equal(MUSIC_BUS_DB)
	assert_str(AudioServer.get_bus_send(bus)).is_equal("Master")


func test_the_course_plays_the_song_on_the_music_bus() -> void:
	var course := _course()
	var scene := scene_runner(course)
	await scene.simulate_frames(1, 16)

	var music := _music_of(course)
	assert_object(music.stream).is_same(Song)
	assert_str(music.bus).is_equal("Music")
	assert_bool(music.playing).is_true()


func test_a_new_attempt_does_not_restart_the_music() -> void:
	var course := _course()
	var scene := scene_runner(course)
	await scene.simulate_frames(30, 16)
	var playback := _music_of(course).get_stream_playback()
	var runner: Runner = course.get_node("Runner")
	runner.global_position.x = Section.WIDTH * 2.0
	for _frame: int in 120:
		if course.is_attempt_over():
			break
		await scene.simulate_frames(1, 16)
	assert_bool(course.is_attempt_over()).is_true()

	scene.simulate_action_pressed("jump")
	await scene.simulate_frames(1, 16)

	assert_bool(course.is_attempt_over()).is_false()
	assert_bool(_music_of(course).playing).is_true()
	assert_object(_music_of(course).get_stream_playback()).is_same(playback)


func test_pausing_does_not_stop_the_music() -> void:
	var course := _course()
	var scene := scene_runner(course)
	await scene.simulate_frames(30, 16)

	scene.simulate_action_pressed("release_mouse")
	await scene.simulate_frames(30, 16)

	assert_bool(course.is_paused()).is_true()
	assert_bool(_music_of(course).playing).is_true()
