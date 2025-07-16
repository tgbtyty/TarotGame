extends Area2D

@export var speed = 1000
var damage_info: DamageInfo
var pierce_count: int = 1 # How many enemies the bullet can hit before breaking

func _physics_process(_delta):
	position += transform.x * speed * _delta

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		pierce_count -= 1
		body.take_damage(damage_info)
		if pierce_count <= 0:
			queue_free() # Destroy the bullet if it's out of pierces
	
	if body is TileMap:
		queue_free()

func _on_visible_on_screen_enabler_2d_screen_exited():
	queue_free()
