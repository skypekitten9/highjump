class_name BestDistance
extends RefCounted
## The Best distance, kept in a file between sessions. In the web build, [code]user://[/code] is
## the browser's storage, so it lasts across page reloads.


## The Best distance saved at [param path], in whole metres. A missing or corrupt save counts as 0.
static func read(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var text := FileAccess.get_file_as_string(path).strip_edges()
	if not text.is_valid_int():
		return 0
	return maxi(text.to_int(), 0)


## Saves [param metres] as the Best distance at [param path].
static func write(path: String, metres: int) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning(
			"Could not save the Best distance to %s: %s" % [path, FileAccess.get_open_error()]
		)
		return
	file.store_string(str(metres))
	file.close()
