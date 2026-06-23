extends Resource
class_name ItemEffect

## Classe base de qualquer efeito aplicável por um item coletável.
## Cada efeito concreto sobrescreve apply(); se precisar de duração,
## ele mesmo gerencia seu timer e a reversão, mantendo o pickup "burro".

@export var duration: float = 0.0  # 0 = instantâneo/permanente, sem timer de reversão

func apply(player: Node) -> void:
	pass