extends GdUnitTestSuite
## Every RunnerTuning feel value is shown in the Inspector with a unit and a valid range, and the
## default tuning preset sits inside those ranges.

const DEFAULT_TUNING := preload("res://runner/default_runner_tuning.tres")


## The tuning's exported feel values: script variables shown in the Inspector.
func _feel_values(tuning: RunnerTuning) -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	for property: Dictionary in tuning.get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR:
			values.append(property)
	return values


## The lowest value a feel value's range allows.
func _range_minimum(property: Dictionary) -> float:
	var hint_string: String = property["hint_string"]
	return hint_string.split(",")[0].to_float()


func test_every_feel_value_has_a_range_with_a_unit() -> void:
	var values := _feel_values(RunnerTuning.new())
	assert_array(values).is_not_empty()
	for property: Dictionary in values:
		var value_name: String = property["name"]
		var hint: int = property["hint"]
		var hint_string: String = property["hint_string"]
		var has_range := hint == PROPERTY_HINT_RANGE
		var has_unit := hint_string.contains("suffix:")
		assert_bool(has_range).override_failure_message("%s has no range" % value_name).is_true()
		assert_bool(has_unit).override_failure_message("%s shows no unit" % value_name).is_true()


func test_default_preset_sits_inside_every_range() -> void:
	var tuning: RunnerTuning = DEFAULT_TUNING
	for property: Dictionary in _feel_values(tuning):
		var value_name: String = property["name"]
		var hint_string: String = property["hint_string"]
		var parts := hint_string.split(",")
		var value: float = tuning.get(value_name)
		var above_minimum := value >= _range_minimum(property)
		var below_maximum := parts.has("or_greater") or value <= parts[1].to_float()
		var message := "%s is outside its range %s" % [value_name, hint_string]
		assert_bool(above_minimum and below_maximum).override_failure_message(message).is_true()


func test_slide_boost_cooldown_cannot_be_zero() -> void:
	for property: Dictionary in _feel_values(RunnerTuning.new()):
		if property["name"] == "slide_boost_cooldown":
			assert_float(_range_minimum(property)).is_greater(0.0)
			assert_float(_range_minimum(property)).is_equal(RunnerTuning.MIN_SLIDE_BOOST_COOLDOWN)
			return
	fail("slide_boost_cooldown is not a feel value")


func test_slide_boost_cooldown_set_outside_the_inspector_never_reaches_zero() -> void:
	var tuning := RunnerTuning.new()
	tuning.slide_boost_cooldown = 0.0
	assert_float(tuning.slide_boost_cooldown).is_greater(0.0)
	tuning.slide_boost_cooldown = -1.0
	assert_float(tuning.slide_boost_cooldown).is_greater(0.0)


func test_default_mantle_values() -> void:
	var tuning: RunnerTuning = DEFAULT_TUNING
	assert_float(tuning.mantle_reach).is_equal(1.6)
	assert_float(tuning.mantle_clearance).is_equal(0.25)
	assert_float(tuning.mantle_leap_gravity_scale).is_equal(2.0)
	assert_float(tuning.mantle_inward_speed).is_equal(3.0)
	assert_float(tuning.mantle_input_angle).is_equal(60.0)


func test_mantle_leap_gravity_set_outside_the_inspector_never_reaches_zero() -> void:
	var tuning := RunnerTuning.new()
	tuning.mantle_leap_gravity_scale = 0.0
	assert_float(tuning.mantle_leap_gravity_scale).is_greater(0.0)
	tuning.mantle_leap_gravity_scale = -1.0
	assert_float(tuning.mantle_leap_gravity_scale).is_greater(0.0)


func test_mantle_values_set_outside_the_inspector_stay_in_bounds() -> void:
	var tuning := RunnerTuning.new()
	tuning.mantle_reach = -1.0
	tuning.mantle_clearance = -1.0
	tuning.mantle_inward_speed = -1.0
	tuning.mantle_input_angle = -10.0
	assert_float(tuning.mantle_reach).is_equal(0.0)
	assert_float(tuning.mantle_clearance).is_equal(0.0)
	assert_float(tuning.mantle_inward_speed).is_equal(0.0)
	assert_float(tuning.mantle_input_angle).is_equal(0.0)
	tuning.mantle_input_angle = 120.0
	assert_float(tuning.mantle_input_angle).is_equal(90.0)
