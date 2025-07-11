extends Area2D

@export var speed = 1000
var damage = 5 # This will be overwritten by the player script

func _physics_process(_delta):
	position += transform.x * speed * _delta

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		body.take_damage(damage)
		queue_free()
	
	if body is TileMap:
		queue_free()

func _on_visible_on_screen_enabler_2d_screen_exited():
	queue_free()
