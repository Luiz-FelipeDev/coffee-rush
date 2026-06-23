extends ItemEffect
class_name SlowMotionEffect

@export var time_scale: float = 0.25

func apply(player: Node) -> void:
    # Triggers the global autoload manager
    SlowMotionManager.trigger(time_scale, duration)