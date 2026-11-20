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
