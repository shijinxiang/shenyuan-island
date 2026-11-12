extends Node3D
## Pixel Dreamer Movement VFX. Looping presets run on their own. One-shots (landing, jump, dash, footstep, blink): call play().
## Rapid footsteps: spawn a new instance per step with free_after set, so earlier dust is not cut off.
@export var repeat_every := 0.0
@export var play_on_ready := false
@export var free_after := 0.0  ## seconds after play() to queue_free() (0 = keep)
var _t := 0.0
var _life := -1.0

func _ready() -> void:
	if play_on_ready:
		play()

func play() -> void:
	for p in find_children("*", "GPUParticles3D", true, false):
		if p.one_shot:
			p.restart()
	if free_after > 0.0:
		_life = free_after

func _process(delta: float) -> void:
	if _life >= 0.0:
		_life -= delta
		if _life < 0.0:
			queue_free()
	if repeat_every > 0.0:
		_t += delta
		if _t >= repeat_every:
			_t = 0.0
			play()
