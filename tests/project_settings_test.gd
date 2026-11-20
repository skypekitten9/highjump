extends GdUnitTestSuite
## Guards the engine settings that docs/adr/0001 relies on.

const ERROR := 2


func test_strict_typing_warnings_are_errors() -> void:
	for warning: String in [
		"untyped_declaration",
		"unsafe_property_access",
		"unsafe_method_access",
		"unsafe_call_argument",
	]:
		var level: int = ProjectSettings.get_setting("debug/gdscript/warnings/" + warning)
		assert_int(level).override_failure_message("%s is not Error" % warning).is_equal(ERROR)


func test_crouch_is_bound_to_left_ctrl_and_c() -> void:
	var keys: Array[Array] = []
	for event: InputEvent in InputMap.action_get_events("crouch"):
		var key := event as InputEventKey
		if key:
			keys.append([key.physical_keycode, key.location])
	assert_array(keys).contains_exactly_in_any_order(
		[[KEY_CTRL, KEY_LOCATION_LEFT], [KEY_C, KEY_LOCATION_UNSPECIFIED]]
	)
