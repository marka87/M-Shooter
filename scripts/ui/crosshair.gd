extends Control
class_name Crosshair

## Fadenkreuz nach den Einstellungen (Form, Farbe, Groesse aus dem GameManager), mit dunklem Rand.

const SHAPES: Array[String] = ["Punkt", "Kreuz", "Kreuz mit Punkt", "Kreis"]
const COLORS: Array[Color] = [Color(1, 1, 1), Color(0.3, 1, 0.4), Color(0.3, 0.9, 1), Color(1, 0.9, 0.2), Color(1, 0.35, 0.8)]
const COLOR_NAMES: Array[String] = ["Weiß", "Grün", "Cyan", "Gelb", "Pink"]


func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	var color: Color = COLORS[clampi(GameManager.crosshair_color, 0, COLORS.size() - 1)]
	var s: float = GameManager.crosshair_size
	var outline := Color(0, 0, 0, 0.6)
	match GameManager.crosshair_shape:
		0:
			draw_circle(c, s * 0.35 + 1.0, outline)
			draw_circle(c, s * 0.35, color)
		1, 2:
			var gap: float = s * 0.4
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(c + d * gap, c + d * (gap + s), outline, 4.0)
				draw_line(c + d * gap, c + d * (gap + s), color, 2.0)
			if GameManager.crosshair_shape == 2:
				draw_circle(c, 1.5, color)
		3:
			draw_arc(c, s, 0.0, TAU, 32, outline, 4.0)
			draw_arc(c, s, 0.0, TAU, 32, color, 2.0)
			draw_circle(c, 1.5, color)
