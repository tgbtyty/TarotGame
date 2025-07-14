extends CharacterBody2D

signal died

var base_speed = 125
var base_health = 20
var base_attack_damage = 20
var knockback_force = 400

# Final stats after buffs
var speed
var health
var attack_damage

var can_attack = true
var is_knocked_back = false # NEW: Flag to interrupt AI
var player = null

func _ready():
	player = get_tree().get_first_node_in_group("players")
	
	# Apply global buffs from GameManager
	speed = base_speed * GameManager.enemy_speed_multiplier
	attack_damage = base_attack_damage + GameManager.enemy_damage_bonus
	scale *= GameManager.enemy_size_multiplier

func initialize(round_number):
	var round_health = base_health + (round_number - 1) * 1
	health = round_health + GameManager.enemy_health_bonus

func _physics_process(_delta):
	# UPDATED: Only move if not being knocked back
	if not is_knocked_back:
		if player and player.current_health > 0:
			var direction = (player.global_position - global_position).normalized()
			velocity = direction * speed
			move_and_slide()
			check_for_player_collision()
	else:
		# While being knocked back, just apply the knockback velocity
		move_and_slide()

# NEW: Function to apply a knockback force
func apply_knockback(direction):
	is_knocked_back = true
	velocity = direction * knockback_force
	# After a short time, stop the knockback and resume normal AI
	get_tree().create_timer(0.15).timeout.connect(func():
		velocity = Vector2.ZERO
		is_knocked_back = false
	)

func take_damage(amount):
	health -= amount
	if health <= 0:
		died.emit()
		queue_free()

func check_for_player_collision():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider() == player and can_attack:
			attack()
			
func attack():
	can_attack = false
	player.take_damage(attack_damage)
	get_tree().create_timer(0.5).timeout.connect(func(): can_attack = true)
