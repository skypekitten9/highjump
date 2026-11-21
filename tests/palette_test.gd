extends GdUnitTestSuite
## Every colour the game sets is one of the four palette colours: material albedo in the Course,
## every Section it knows or that sits in the Sections folder, and the greybox; their sky and sun;
## and the HUD and EndScreen's font, outline and background colours, alpha ignored. Lit surfaces
## show their true palette colour: tonemapping is Linear and the sun lighting the world is white.

const CourseScene := preload("res://course/course.tscn")
const GreyboxScene := preload("res://levels/greybox/greybox.tscn")
const HudScene := preload("res://course/hud.tscn")
const EndScreenScene := preload("res://course/end_screen.tscn")
## The palette, lightest to darkest.
const PALETTE: Array[String] = ["F7D794", "FBA17E", "FF9A00", "EE6200"]


## Where Section scenes live; an unregistered Section there is checked too.
const SECTIONS_DIR := "res://course/sections/"


## Every Section scene: the Course's start Section, those it picks from, and any other scene in
## [constant SECTIONS_DIR], each once.
func _all_section_scenes() -> Array[PackedScene]:
	var course: Course = auto_free(CourseScene.instantiate())
	var scenes: Array[PackedScene] = [course.start_section]
	scenes.append_array(course.section_list.sections)
	for file: String in ResourceLoader.list_directory(SECTIONS_DIR):
		if file.get_extension() == "tscn":
			var scene := load(SECTIONS_DIR + file) as PackedScene
			if not scenes.has(scene):
				scenes.append(scene)
	return scenes


## The Course, every Section it knows and the greybox, not yet in the tree.
func _worlds() -> Array[Node]:
	var worlds := _lit_worlds()
	for scene: PackedScene in _all_section_scenes():
		worlds.append(auto_free(scene.instantiate()))
	return worlds


## [param root] and every node under it.
func _nodes(root: Node) -> Array[Node]:
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	return nodes


## Where [param node] is, for failure messages.
func _named(node: Node) -> String:
	var root := node if node.owner == null else node.owner
	return "%s in %s" % [root.get_path_to(node), root.scene_file_path]


## Fails unless [param colour], set at [param where], is a palette colour, alpha ignored.
func _assert_on_palette(colour: Color, where: String) -> void:
	var hex := colour.to_html(false).to_upper()
	var message := "%s is %s, not a palette colour" % [where, hex]
	assert_array(PALETTE).override_failure_message(message).contains([hex])


## Every material set on [param node].
func _materials(node: Node) -> Array[Material]:
	var materials: Array[Material] = []
	var geometry := node as GeometryInstance3D
	if geometry and geometry.material_override:
		materials.append(geometry.material_override)
	var csg := node as CSGShape3D
	if csg and "material" in csg and csg.get("material"):
		materials.append(csg.get("material") as Material)
	var mesh_instance := node as MeshInstance3D
	if mesh_instance and mesh_instance.mesh:
		for surface: int in mesh_instance.mesh.get_surface_count():
			for material: Material in [
				mesh_instance.get_surface_override_material(surface),
				mesh_instance.mesh.surface_get_material(surface),
			]:
				if material:
					materials.append(material)
	return materials


func test_every_material_albedo_in_the_course_sections_and_greybox_is_a_palette_colour() -> void:
	var checked := 0
	for world: Node in _worlds():
		for node: Node in _nodes(world):
			for material: Material in _materials(node):
				var base := material as BaseMaterial3D
				if base:
					_assert_on_palette(base.albedo_color, "%s albedo" % _named(node))
					checked += 1
	assert_int(checked).is_greater_equal(1)


## The Course and the greybox, not yet in the tree: the worlds with their own sky and sun.
func _lit_worlds() -> Array[Node]:
	return [auto_free(CourseScene.instantiate()), auto_free(GreyboxScene.instantiate())]


## The one environment set in [param world].
func _environment(world: Node) -> Environment:
	var found := world.find_children("*", "WorldEnvironment", true, false)
	var message := "%s has no single WorldEnvironment" % world.scene_file_path
	assert_int(found.size()).override_failure_message(message).is_equal(1)
	return (found[0] as WorldEnvironment).environment


## Every sun in [param world].
func _suns(world: Node) -> Array[DirectionalLight3D]:
	var suns: Array[DirectionalLight3D] = []
	for node: Node in world.find_children("*", "DirectionalLight3D", true, false):
		suns.append(node as DirectionalLight3D)
	return suns


func test_every_sky_colour_in_the_course_and_greybox_is_a_palette_colour() -> void:
	for world: Node in _lit_worlds():
		var sky := _environment(world).sky.sky_material as ProceduralSkyMaterial
		var where := world.scene_file_path
		var message := "%s has no procedural sky" % where
		assert_object(sky).override_failure_message(message).is_not_null()
		_assert_on_palette(sky.sky_top_color, "%s sky top" % where)
		_assert_on_palette(sky.sky_horizon_color, "%s sky horizon" % where)
		_assert_on_palette(sky.ground_horizon_color, "%s ground horizon" % where)
		_assert_on_palette(sky.ground_bottom_color, "%s ground bottom" % where)


func test_every_sun_disk_drawn_in_the_course_and_greybox_sky_is_a_palette_colour() -> void:
	for world: Node in _lit_worlds():
		for sun: DirectionalLight3D in _suns(world):
			if sun.sky_mode != DirectionalLight3D.SKY_MODE_LIGHT_ONLY:
				_assert_on_palette(sun.light_color, "%s sun disk" % _named(sun))


func test_the_course_and_greybox_are_tonemapped_linearly() -> void:
	for world: Node in _lit_worlds():
		var message := "%s is not tonemapped linearly" % world.scene_file_path
		var mode := _environment(world).tonemap_mode
		var linear := Environment.TONE_MAPPER_LINEAR
		assert_int(mode).override_failure_message(message).is_equal(linear)


func test_the_sun_lighting_the_course_and_greybox_is_white() -> void:
	for world: Node in _lit_worlds():
		var lighting := 0
		for sun: DirectionalLight3D in _suns(world):
			if sun.sky_mode == DirectionalLight3D.SKY_MODE_SKY_ONLY:
				continue
			lighting += 1
			var message := "%s lights the world in %s, not white" % [_named(sun), sun.light_color]
			var white := sun.light_color.is_equal_approx(Color.WHITE)
			assert_bool(white).override_failure_message(message).is_true()
		var none := "%s has no sun lighting it" % world.scene_file_path
		assert_int(lighting).override_failure_message(none).is_greater_equal(1)


func test_every_ui_colour_in_the_hud_and_end_screen_is_a_palette_colour() -> void:
	var checked := 0
	for scene: PackedScene in [HudScene, EndScreenScene]:
		var ui: Node = auto_free(scene.instantiate())
		await scene_runner(ui).simulate_frames(1)
		for node: Node in _nodes(ui):
			var label := node as Label
			if label:
				_assert_on_palette(label.get_theme_color("font_color"), "%s font" % _named(label))
				checked += 1
				if label.get_theme_constant("outline_size") > 0:
					var outline := label.get_theme_color("font_outline_color")
					_assert_on_palette(outline, "%s outline" % _named(label))
			var rect := node as ColorRect
			if rect:
				_assert_on_palette(rect.color, "%s background" % _named(rect))
				checked += 1
	assert_int(checked).is_greater_equal(1)
