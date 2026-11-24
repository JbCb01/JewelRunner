extends CanvasLayer

## Tło poziomu (za całą sceną): obraz przewijany paralaksą albo animowany spritesheet.
## Działa w przestrzeni ekranu (CanvasLayer), więc nie zależy od rozmiaru poziomu.
##   texture_path   – obraz tła (poziomy 2–3) albo spritesheet klatek (poziom 4)
##   frame_count    – >1 oznacza animowany spritesheet (klatki ułożone poziomo, każda frame_size)
##   pixel_scale    – powiększenie pikseli obrazu (małe tła 384x216 / 512x240 -> 2x)
##   scroll_factor  – jak szybko tło przesuwa się względem kamery w poziomie (0 = stoi w miejscu)
##   vertical_factor– delikatne przesunięcie w pionie przy wspinaniu się nad ekran

@export var texture_path: String = ""
@export var frame_count: int = 1
@export var frame_size: Vector2i = Vector2i(640, 360)
@export var frames_per_second: float = 8.0
@export var pixel_scale: float = 2.0
@export var scroll_factor: float = 0.25
@export var vertical_factor: float = 0.12
@export var anchor_bottom: bool = true

var _rect: TextureRect
var _atlas: AtlasTexture
var _tex: Texture2D
var _frame: int = 0
var _frame_t: float = 0.0
var _base_cam_y: float = INF

func _ready() -> void:
	layer = -20
	follow_viewport_enabled = false
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		return
	_tex = load(texture_path) as Texture2D
	_rect = TextureRect.new()
	_rect.name = "BackgroundImage"
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if frame_count > 1:
		_atlas = AtlasTexture.new()
		_atlas.atlas = _tex
		_atlas.region = Rect2(0, 0, frame_size.x, frame_size.y)
		_rect.texture = _atlas
		_rect.stretch_mode = TextureRect.STRETCH_SCALE
	else:
		_rect.texture = _tex
		_rect.stretch_mode = TextureRect.STRETCH_TILE
		_rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(_rect)
	_layout()

func _process(delta: float) -> void:
	if _rect == null:
		return
	if frame_count > 1 and frames_per_second > 0.0:
		_frame_t += delta
		var step: float = 1.0 / frames_per_second
		while _frame_t >= step:
			_frame_t -= step
			_frame = (_frame + 1) % frame_count
			_atlas.region = Rect2(_frame * frame_size.x, 0, frame_size.x, frame_size.y)
	_layout()

func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var cam: Camera2D = get_viewport().get_camera_2d()
	var cam_pos: Vector2 = cam.get_screen_center_position() if cam else Vector2.ZERO
	if frame_count > 1:
		# Animowane tło: zawsze wypełnia cały ekran (klatki mają rozmiar ekranu)
		_rect.position = Vector2.ZERO
		_rect.size = vp
		return
	var tw: float = float(_tex.get_width())
	var th: float = float(_tex.get_height())
	if _base_cam_y == INF:
		_base_cam_y = cam_pos.y
	# Kafelkowanie w poziomie z paralaksą; obraz powiększony pixel_scale razy
	_rect.scale = Vector2(pixel_scale, pixel_scale)
	_rect.size = Vector2(vp.x / pixel_scale + tw * 2.0, th)
	var shift: float = fposmod(cam_pos.x * scroll_factor / pixel_scale, tw)
	var y_off: float = (vp.y - th * pixel_scale) if anchor_bottom else 0.0
	y_off += clampf((_base_cam_y - cam_pos.y) * vertical_factor, 0.0, th * pixel_scale - vp.y + 40.0) if anchor_bottom else 0.0
	_rect.position = Vector2(-shift * pixel_scale, y_off)
