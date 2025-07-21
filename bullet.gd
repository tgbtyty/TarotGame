extends Area2D

@export var speed = 1000
var damage_info: DamageInfo
var pierce_count: int = 1
var lifespan: float = 2.0
var homing_strength: float = 0.0

var travel_time: float = 0.0
var target_enemy = null
var velocity: Vector2 = Vector2.ZERO

func _ready():
	# This print statement will help us debug the lifespan.
	print("Bullet spawned with lifespan: ", lifespan)
	$LifespanTimer.wait_time = lifespan
	$LifespanTimer.start()

func _physics_process(delta):
	travel_time += delta
	
	var forward_direction = Vector2.RIGHT.rotated(rotation)
	
	# KEYSTONE: "Throatseeker" homing logic
	if homing_strength > 0:
		if not is_instance_valid(target_enemy):
			target_enemy = find_closest_enemy()
		
		if is_instance_valid(target_enemy):
			# UPDATED: Aim at the predicted position, not the current one
			var target_pos = predict_intercept_point(target_enemy)
			var direction_to_target = (target_pos - global_position).normalized()
			var distance_to_target = global_position.distance_to(target_enemy.global_position)
			
			if distance_to_target > 30:
				rotation = lerp_angle(rotation, direction_to_target.angle(), homing_strength * delta * 5)
				forward_direction = Vector2.RIGHT.rotated(rotation)

	# --- Final Movement ---
	var velocity = forward_direction * speed
	position += velocity * delta


func _on_body_entered(body):
	if body.is_in_group("enemies"):
		pierce_count -= 1
		
		var final_damage = damage_info.duplicate(true)
		
		if GameManager.owned_keystones.has("sagi_heartpiercer"):
			var max_bonus = 0.30
			if GameManager.is_avatar and GameManager.avatar_of == "Sagittarius":
				max_bonus = 2.00
			
			var damage_multiplier = 1.0 + (travel_time / lifespan * max_bonus)
			final_damage.physical_damage *= damage_multiplier
			# (apply to other damage types too if needed)

		body.take_damage(final_damage)
		if pierce_count <= 0:
			queue_free()
	
	if body is TileMap:
		queue_free()

func find_closest_enemy():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy = null
	var min_dist_sq = INF
	
	for enemy in enemies:
		var dist_sq = global_position.distance_squared_to(enemy.global_position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_enemy = enemy
			
	return closest_enemy

func _on_lifespan_timer_timeout():
	print("Lifespan timer expired! Deleting bullet.")
	queue_free()

func _on_visible_on_screen_enabler_2d_screen_exited():
	queue_free()

func predict_intercept_point(target):
	var target_pos = target.global_position
	var target_vel = target.velocity
	var bullet_pos = global_position
	
	# To prevent division by zero if bullet speed is somehow 0
	if speed == 0:
		return target_pos

	var time_to_intercept = bullet_pos.distance_to(target_pos) / speed
	var predicted_position = target_pos + target_vel * time_to_intercept
	
	return predicted_position
