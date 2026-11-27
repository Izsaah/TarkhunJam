extends Control

@export var npc_spawner: Node2D

@onready var timer_label: Label = $TimerLabel
@onready var result_panel: Panel = $ResultPanel
@onready var result_label: Label = $ResultPanel/VBoxContainer/ResultLabel
@onready var restart_button: Button = $ResultPanel/VBoxContainer/RestartButton

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_panel.visible = false
	restart_button.pressed.connect(_on_restart_pressed)

	if not is_instance_valid(npc_spawner):
		npc_spawner = get_tree().root.find_child("NPCSpawner", true, false)

	if is_instance_valid(npc_spawner):
		npc_spawner.time_updated.connect(_on_time_updated)
		npc_spawner.game_ended.connect(_on_game_ended)
	else:
		push_error("MatchTimerUI: Could not find NPCSpawner!")

func _on_time_updated(seconds_left: int) -> void:
	var minutes := int(seconds_left / 60.0)
	var seconds := seconds_left % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

func _on_game_ended(is_win: bool, message: String) -> void:
	result_label.text = message
	result_label.modulate = Color.GREEN if is_win else Color.RED
	result_panel.visible = true

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()