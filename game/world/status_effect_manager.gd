extends Node
class_name StatusEffectManager

## É centralizado aqui todo efeito temporário aplicado ao jogador (velocidade,
## dano, pulo extra, invencibilidade, invisibilidade). Em vez de cada efeito
## multiplicar/dividir um valor isolado com timer próprio (frágil quando vários
## efeitos do mesmo tipo se sobrepõem ou o jogador morre no meio do processo),
## cada coleta apenas registra uma entrada numa lista; o valor final é sempre
## recalculado do zero a partir de TODAS as entradas vivas. Isso elimina a
## possibilidade de "perder a conta" ao empilhar ou remover efeitos fora de ordem.

@export_group("limites de segurança")
@export var max_speed_multiplier: float = 4.0
@export var max_damage_multiplier: float = 4.0

signal stats_changed

# Bônus multiplicativos: somados entre si antes de aplicar (não multiplicados),
# então 2 itens de +50% resultam em +100% (2.0x), não em 1.5 * 1.5.
var _speed_bonuses: Array[Dictionary] = []      # {bonus: float, remaining: float}
var _damage_bonuses: Array[Dictionary] = []

# Contadores: cada entrada soma um valor fixo (ex: pulos extras).
var _extra_jump_entries: Array[Dictionary] = []  # {amount: int, remaining: float}

# Booleanos: ativo enquanto houver pelo menos 1 entrada viva.
var _invincibility_entries: Array[Dictionary] = []  # {remaining: float}
var _invisibility_entries: Array[Dictionary] = []

# Valores públicos — o player.gd lê direto daqui, sem precisar de callback.
var speed_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var extra_jumps: int = 0
var is_invincible: bool = false
var is_invisible: bool = false

func _process(delta: float) -> void:
	var changed: bool = false
	changed = _tick_array(_speed_bonuses, delta) or changed
	changed = _tick_array(_damage_bonuses, delta) or changed
	changed = _tick_array(_extra_jump_entries, delta) or changed
	changed = _tick_array(_invincibility_entries, delta) or changed
	changed = _tick_array(_invisibility_entries, delta) or changed

	if changed:
		_recalculate_all()

func _tick_array(entries: Array[Dictionary], delta: float) -> bool:
	# Duração 0 é tratada como permanente: nunca expira por tempo,
	# só é removida via clear_all().
	var removed_any: bool = false
	for i in range(entries.size() - 1, -1, -1):
		if entries[i]["remaining"] <= 0.0:
			continue
		entries[i]["remaining"] -= delta
		if entries[i]["remaining"] <= 0.0:
			entries.remove_at(i)
			removed_any = true
	return removed_any

func _recalculate_all() -> void:
	var speed_bonus_sum: float = 0.0
	for entry in _speed_bonuses:
		speed_bonus_sum += entry["bonus"]
	speed_multiplier = clampf(1.0 + speed_bonus_sum, 1.0, max_speed_multiplier)

	var damage_bonus_sum: float = 0.0
	for entry in _damage_bonuses:
		damage_bonus_sum += entry["bonus"]
	damage_multiplier = clampf(1.0 + damage_bonus_sum, 1.0, max_damage_multiplier)

	var jump_sum: int = 0
	for entry in _extra_jump_entries:
		jump_sum += entry["amount"]
	extra_jumps = jump_sum

	is_invincible = not _invincibility_entries.is_empty()
	is_invisible = not _invisibility_entries.is_empty()

	stats_changed.emit()

# ========================================================== #
# API pública chamada pelos ItemEffect (game/itens/effects/)
# ========================================================== #

func add_speed_bonus(bonus: float, duration: float) -> void:
	_speed_bonuses.append({"bonus": bonus, "remaining": duration})
	_recalculate_all()

func add_damage_bonus(bonus: float, duration: float) -> void:
	_damage_bonuses.append({"bonus": bonus, "remaining": duration})
	_recalculate_all()

func add_extra_jumps(amount: int, duration: float) -> void:
	print("📈 5. STATUS MANAGER: Recebeu +", amount, " pulos extras!")
	_extra_jump_entries.append({"amount": amount, "remaining": duration})
	_recalculate_all()
	print("✅ 6. SUCESSO! Total de pulos extras agora é: ", extra_jumps)

func add_invincibility(duration: float) -> void:
	_invincibility_entries.append({"remaining": duration})
	_recalculate_all()

func add_invisibility(duration: float) -> void:
	_invisibility_entries.append({"remaining": duration})
	_recalculate_all()

# ========================================================== #
# Limpeza total — chamada pelo player.gd em morte/respawn/knockdown.
# Resolve o cenário de "morrer no meio da coleta": como tudo aqui é
# estado simples de array (sem await pendente nem Tween próprio), uma
# chamada única zera tudo de forma síncrona e segura.
# ========================================================== #

func clear_all() -> void:
	_speed_bonuses.clear()
	_damage_bonuses.clear()
	_extra_jump_entries.clear()
	_invincibility_entries.clear()
	_invisibility_entries.clear()
	_recalculate_all()