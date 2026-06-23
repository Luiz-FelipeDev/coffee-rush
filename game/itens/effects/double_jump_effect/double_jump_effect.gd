# double_jump_effect.gd
extends ItemEffect
class_name DoubleJumpEffect

@export var extra_jumps: int = 1

func apply(player: Node) -> void:
    print("🚀 3. RODANDO SCRIPT DO PULO DUPLO!")
    var status: StatusEffectManager = player.get_node_or_null("StatusEffectManager")
    
    if status:
        print("🟢 4. STATUS MANAGER ENCONTRADO! Adicionando ", extra_jumps, " pulos.")
        status.add_extra_jumps(extra_jumps, duration)
    else:
        print("🔴 ERRO FATAL: O StatusEffectManager NÃO FOI ENCONTRADO dentro do Player!")