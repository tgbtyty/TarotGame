extends Area2D

@export var speed = 1000
var damage_info: DamageInfo # The bullet now carries a package of damage info

func _physics_process(_delta):
	position += transform.x * speed * _delta

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		# Pass the entire damage package to the enemy
		body.take_damage(damage_info)
		queue_free()
	
	if body is TileMap:
		queue_free()

func _on_visible_on_screen_enabler_2d_screen_exited():
	queue_free()
