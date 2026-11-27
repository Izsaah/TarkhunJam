extends Control

signal wave_triggered(wave_index: int, total_waves: int, intelligence: float)

@export_range(0.0, 1.0) var normal_tier_start: float = 0.4 # Normal starts at 40% of waves
@export_range(0.0, 1.0) var smart_tier_start: float = 0.8  # Smart starts at 80% of waves
@export var match_duration_seconds: float = 300.0
@export var wave_interval_seconds: float = 60.0
@export var player: Node = null

@onready var timer_label: Label = $TimerLabel
@onready var match_timer: Timer = $MatchTimer
@onready var result_panel: Panel = $ResultPanel
@onready var result_label: Label = $ResultPanel/VBoxContainer/ResultLabel
@onready var restart_button: Button = $ResultPanel/VBoxContainer/RestartButton

var _game_over: bool = false
var _last_wave_index: int = -1
var _total_waves: int = 1
var _wave_elapsed: float = 0.0

func _ready() -> void:
	result_panel.visible = false
	restart_button.pressed.connect(_on_restart_pressed)

	if not is_instance_valid(player):
		player = get_tree().root.find_child("WormPlayer", true, false)

	if is_instance_valid(player) and player.has_signal("died"):
		player.died.connect(_on_player_died)

	_total_waves = maxi(1, int(ceil(match_duration_seconds / maxf(1.0, wave_interval_seconds))))

	match_timer.one_shot = true
	match_timer.timeout.connect(_on_match_timer_timeout)
	match_timer.start(match_duration_seconds)

	# Trigger Wave 0 after all nodes finish _ready()
	trigger_next_wave.call_deferred()

func _process(delta: float) -> void:
	if _game_over:
		return

	var time_left := ceili(match_timer.time_left)
	var minutes := int(time_left / 60.0)
	var seconds := time_left % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

	# Trigger next wave when interval (e.g. 60s) is reached
	if _last_wave_index + 1 < _total_waves:
		_wave_elapsed += delta
		if _wave_elapsed >= wave_interval_seconds:
			trigger_next_wave()

func trigger_next_wave() -> void:
	if _game_over or _last_wave_index + 1 >= _total_waves:
		return

	_last_wave_index += 1
	_wave_elapsed = 0.0

	var progress := float(_last_wave_index) / float(_total_waves)
	var ai_tier: int = 0 # Dumb
	if progress >= smart_tier_start:
		ai_tier = 2 # Smart
	elif progress >= normal_tier_start:
		ai_tier = 1 # Normal

	wave_triggered.emit(_last_wave_index, _total_waves, ai_tier)

func _on_match_timer_timeout() -> void:
	if _game_over:
		return
	_end_game(true, "YOU SURVIVED!")

func win_game(message: String = "YOU WIN!") -> void:
	if _game_over:
		return
	_end_game(true, message)

func _on_player_died(_reason: String) -> void:
	if _game_over:
		return
	_end_game(false, "GAME OVER")

func _end_game(is_win: bool, message: String) -> void:
	_game_over = true
	match_timer.stop()

	result_label.text = message
	result_label.modulate = Color.GREEN if is_win else Color.RED
	result_panel.visible = true

	get_tree().paused = true

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
