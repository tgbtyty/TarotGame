extends Area2D

@export var speed = 1000
var damage = 5

func _physics_process(_delta):
	position += transform.x * speed * _delta

func _on_body_entered(body):
	# Check if the body we hit is in the "enemies" group
	if body.is_in_group("enemies"):
		body.take_damage(damage) # Call the enemy's damage function
		queue_free() # Destroy the bullet on hit
	
	# This part is for walls, which we can add later
	if body is TileMap:
		queue_free()

func _on_visible_on_screen_enabler_2d_screen_exited():
	queue_free()
