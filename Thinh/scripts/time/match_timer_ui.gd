extends Control

@export var match_duration_seconds: float = 300.0 # 300 = 5 min, 600 = 10 min
@export var player: Node = null # Optional: assign WormPlayer in Inspector

@onready var timer_label: Label = $TimerLabel
@onready var match_timer: Timer = $MatchTimer
@onready var result_panel: Panel = $ResultPanel
@onready var result_label: Label = $ResultPanel/VBoxContainer/ResultLabel
@onready var restart_button: Button = $ResultPanel/VBoxContainer/RestartButton

var _game_over: bool = false

func _ready() -> void:
	result_panel.visible = false
	restart_button.pressed.connect(_on_restart_pressed)

	# Connect to player's died signal
	if not is_instance_valid(player):
		player = get_tree().root.find_child("WormPlayer", true, false)

	if is_instance_valid(player) and player.has_signal("died"):
		player.died.connect(_on_player_died)

	# Start match countdown
	match_timer.one_shot = true
	match_timer.timeout.connect(_on_match_timer_timeout)
	match_timer.start(match_duration_seconds)

func _process(_delta: float) -> void:
	if _game_over:
		return

	var time_left := ceili(match_timer.time_left)
	var minutes := time_left / 60
	var seconds := time_left % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

func _on_match_timer_timeout() -> void:
	if _game_over:
		return
	_end_game(true, "YOU SURVIVED!")

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
