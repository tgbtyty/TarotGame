extends CharacterBody2D

signal died

var base_speed = 125
var base_health = 20
var base_attack_damage = 20

# These will be the final stats after buffs
var speed
var health
var attack_damage

var can_attack = true
var player = null

func _ready():
	player = get_tree().get_first_node_in_group("players")
	
	# Apply global buffs from GameManager
	speed = base_speed * GameManager.enemy_speed_multiplier
	health = base_health + GameManager.enemy_health_bonus
	attack_damage = base_attack_damage + GameManager.enemy_damage_bonus
	scale *= GameManager.enemy_size_multiplier

func _physics_process(_delta):
	if player and player.current_health > 0:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
		check_for_player_collision()

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
