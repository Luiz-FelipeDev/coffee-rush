extends Node

# É centralizado aqui o controle de Engine.time_scale para evitar que
# múltiplas fontes (itens, habilidades, cutscenes) entrem em conflito
# alterando o tempo global ao mesmo tempo.

@export var default_scale: float = 0.25
@export var default_fade_in_time: float = 0.15
@export var default_hold_time: float = 1.5
@export var default_fade_out_time: float = 0.5

var _active_tween: Tween

func trigger(scale_amount: float = -1.0, hold_time: float = -1.0, fade_in_time: float = -1.0, fade_out_time: float = -1.0) -> void:
	# É interrompido qualquer efeito anterior em andamento para evitar
	# que dois gatilhos sobrepostos deixem o time_scale em estado inconsistente.
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		Engine.time_scale = 1.0

	var target_scale: float = scale_amount if scale_amount > 0.0 else default_scale
	var target_hold: float = hold_time if hold_time >= 0.0 else default_hold_time
	var in_time: float = fade_in_time if fade_in_time >= 0.0 else default_fade_in_time
	var out_time: float = fade_out_time if fade_out_time >= 0.0 else default_fade_out_time

	_active_tween = create_tween()
	# É ignorada a escala de tempo atual: a duração do fade é sempre em segundos reais.
	_active_tween.set_ignore_time_scale(true)

	_active_tween.tween_property(Engine, "time_scale", target_scale, in_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_interval(target_hold)
	_active_tween.tween_property(Engine, "time_scale", 1.0, out_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)