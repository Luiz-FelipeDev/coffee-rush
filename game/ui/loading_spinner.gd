extends Control

# spinner desenhado por codigo (sem precisar de nenhuma imagem/sprite).
# desenha um arco que gira continuamente enquanto o node estiver visivel.

@export var spin_speed: float = 4.0          # radianos por segundo
@export var arc_color: Color = Color(1, 1, 1, 1)
@export var arc_width: float = 6.0

var _angle: float = 0.0


func _process(delta: float) -> void:
	if not visible:
		return

	_angle += spin_speed * delta
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = min(size.x, size.y) / 2.0 - arc_width

	# e desenhado apenas 3/4 do circulo, para o giro ficar visivel
	# (um circulo completo girando pareceria estatico)
	draw_arc(center, radius, _angle, _angle + TAU * 0.75, 32, arc_color, arc_width, true)
