extends Node2D

const _bodyPartScene = preload("res://Thinh/scenes/body.tscn")
const _tailPartScene = preload("res://Thinh/scenes/tail.tscn")
const _bodyDistance = 4

@export var randomize_length: bool = false # Unchecked for Player, Checked for NPC
@export var default_body_parts: int = 1   # Used when randomize_length is false
@export var min_body_parts: int = 6        # Used when randomize_length is true
@export var max_body_parts: int = 25

var _bodyPartCount: int = 10
var _scaleY = 0.8
var _bodyParts = []
var _positionsHistory = []
var _movementHistory: int = 100

func _ready():
	if randomize_length:
		_bodyPartCount = randi_range(min_body_parts, max_body_parts)
	else:
		_bodyPartCount = default_body_parts
		
	_movementHistory = (_bodyPartCount + 2) * _bodyDistance
	CreateSnakeParts()

# We add parts in reverse order
func CreateSnakeParts():
	AddTailParts()
	
	var adjustForTailParts = 2
	for i in range(_bodyPartCount - adjustForTailParts):
		AddBodyPart()
		
func _physics_process(_delta):
	# Adds a positionHistory to the end of the stack
	_positionsHistory.push_back({pos = %Head.position, rot = %Head.rotation})
	
	if _positionsHistory.size() > _movementHistory:
		# Removes the positionHistory from the top of the stack
		_positionsHistory.pop_front()

	UpdateBodyParts()

func AddTailParts():
	var tailPart = _tailPartScene.instantiate()
	%BodyPartContainer.add_child(tailPart)
	_bodyParts.append(tailPart)
	tailPart.scale = Vector2(1, _scaleY)
	

# Reminder: Body parts hidden by default. Goto
# body scene and make visible to see different start.
func AddBodyPart():
	var bodyPart = _bodyPartScene.instantiate()
	%BodyPartContainer.add_child(bodyPart)
	_bodyParts.append(bodyPart)
	bodyPart.scale = Vector2(1, _scaleY)
	_scaleY += 0.01
	if _scaleY > 1.0:
		_scaleY = 1.0

func UpdateBodyParts():
	var totalParts = _bodyParts.size()
	
	for i in range(totalParts):
		# _bodyParts[totalParts - 1] is closest to the head, _bodyParts[0] is the tail
		var offset = (totalParts - i) * _bodyDistance
		var historyIndex = _positionsHistory.size() - 1 - offset
		
		if historyIndex >= 0:
			var historyPoint = _positionsHistory[historyIndex]
			var bodyPart = _bodyParts[i]
			bodyPart.position = historyPoint["pos"]
			bodyPart.rotation = historyPoint["rot"]
			bodyPart.visible = true

	var _movementHistory = (_bodyPartCount + 1) * _bodyDistance
