class_name PixelView
extends CanvasLayer
## The Runner's pixelated view. Draws the world into a low-res view [member height] pixels tall,
## as wide as the window's aspect ratio allows, and scales it up over the whole window with
## nearest-neighbour filtering. Sits below the default canvas layer, so the HUD and EndScreen draw
## sharp at full resolution on top. Its camera copies [member source]'s global transform and FOV
## every frame, so whatever moves that camera moves the view.

## Height of the low-res view, pixels. Its width follows the window's aspect ratio.
@export_range(1, 1080) var height := 240:
	set(value):
		height = maxi(value, 1)

## The camera the view follows. Set by whatever holds the view; until then the view keeps still.
var source: Camera3D

@onready var _viewport: SubViewport = $Viewport
@onready var _camera: Camera3D = $Viewport/Camera
@onready var _screen: TextureRect = $Screen


func _ready() -> void:
	_screen.texture = _viewport.get_texture()


func _process(_delta: float) -> void:
	var window := get_viewport().get_visible_rect().size
	var width := maxi(roundi(height * window.x / window.y), 1)
	_viewport.size = Vector2i(width, height)
	if source != null:
		_camera.global_transform = source.global_transform
		_camera.fov = source.fov
