class_name PixelView
extends CanvasLayer
## The Runner's pixelated view. Draws the world into a low-res view [member height] pixels tall,
## as wide as the window's aspect ratio allows, and scales it up over the whole window with
## nearest-neighbour filtering. Sits below the default canvas layer, so the HUD and EndScreen draw
## sharp at full resolution on top. Its camera copies [member source]'s global transform, FOV and
## near and far planes every frame, so whatever moves that camera moves the view.

## Height of the low-res view, pixels. Fixed: there is no pixel-size setting. Its width follows
## the window's aspect ratio.
const HEIGHT := 240

## The camera the view follows. Set by whatever holds the view; until then the view keeps still.
var source: Camera3D

@onready var _viewport: SubViewport = $LowResViewport
@onready var _camera: Camera3D = $LowResViewport/Camera
@onready var _screen: TextureRect = $Screen


func _ready() -> void:
	_screen.texture = _viewport.get_texture()


# In _process, not _physics_process: the size and camera only feed rendering, so they are
# brought up to date once per drawn frame, after whatever moved the source camera this frame.
func _process(_delta: float) -> void:
	var window := get_viewport().get_visible_rect().size
	var width := maxi(roundi(HEIGHT * window.x / window.y), 1)
	_viewport.size = Vector2i(width, HEIGHT)
	if source != null:
		_camera.global_transform = source.global_transform
		_camera.fov = source.fov
		_camera.near = source.near
		_camera.far = source.far
