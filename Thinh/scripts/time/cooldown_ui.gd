extends Control

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var cooldown_label: Label = $CooldownLabel
@onready var timer: Timer = $CooldownTimer

var _duration: float = 1.0

func _ready() -> void:
	progress_bar.value = 0.0
	cooldown_label.text = ""
	timer.one_shot = true
	timer.timeout.connect(_on_cooldown_finished)

func _process(_delta: float) -> void:
	if timer.is_stopped():
		return

	var time_left := timer.time_left
	# Fill from 100% down to 0% as cooldown finishes
	progress_bar.value = (time_left / _duration) * 100.0
	cooldown_label.text = "%.1f" % time_left

func start_cooldown(duration: float) -> void:
	if duration <= 0.0:
		return
	_duration = duration
	progress_bar.value = 100.0
	timer.start(duration)

func is_ready() -> bool:
	return timer.is_stopped()

func _on_cooldown_finished() -> void:
	progress_bar.value = 0.0
	cooldown_label.text = ""
