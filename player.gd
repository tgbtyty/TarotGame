extends CharacterBody2D

signal player_died

@export var speed = 350
@export var dash_speed = 900
@export var bullet_scene: PackedScene

# --- Player Stats ---
var max_health = 100
var current_health
var base_bullet_damage = 5
var attack_speed_multiplier = 1.0
var reload_speed_multiplier = 1.0

# --- Dash Variables ---
var dash_direction = Vector2.ZERO
var is_dashing = false
var can_dash = true

# --- Gun Variables ---
var magazine_size = 20
var current_ammo
var can_shoot = true
var is_reloading = false

# --- Special Variables ---
var can_use_special = true

# --- UI Node References ---
@onready var muzzle = $Muzzle
@onready var dash_bar = $DashBar
# UPDATED all paths below to use "HUD_Layer"
@onready var health_bar = get_node_or_null("/root/Main/HUD_Layer/HealthBar")
@onready var special_label = get_node_or_null("/root/Main/HUD_Layer/SpecialCooldownLabel")
@onready var ammo_label = get_node_or_null("/root/Main/HUD_Layer/AmmoLabel")
@onready var reload_indicator = get_node_or_null("/root/Main/HUD_Layer/ReloadIndicator")


func _ready():
	current_health = max_health
	current_ammo = magazine_size
	
	# Health bar setup
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	# Special cooldown label setup
	if special_label:
		special_label.text = "Special: Ready"
	
	# Dash bar setup
	if dash_bar:
		dash_bar.max_value = $DashCooldown.wait_time
		dash_bar.value = dash_bar.max_value
		dash_bar.visible = false
		
	# Ammo UI Setup
	if ammo_label:
		ammo_label.text = "%d / %d" % [current_ammo, magazine_size]
	if reload_indicator:
		reload_indicator.value = 0
		reload_indicator.visible = false


func _physics_process(_delta):
	# Update UI elements every frame
	if special_label and not $SpecialCooldown.is_stopped():
		special_label.text = "Special: %.1fs" % $SpecialCooldown.time_left
	
	if dash_bar and dash_bar.visible:
		dash_bar.value = $DashCooldown.time_left
		
	if is_reloading and reload_indicator:
		var reload_timer = $ReloadTimer
		# Calculate fill based on time passed, not time left
		var time_passed = reload_timer.wait_time - reload_timer.time_left
		reload_indicator.value = (time_passed / reload_timer.wait_time) * 100

	# Movement logic
	if is_dashing:
		velocity = dash_direction * dash_speed
	else:
		var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		velocity = input_direction * speed
		look_at(get_global_mouse_position())
	
	move_and_slide()
	
	var screen_size = get_viewport_rect().size
	global_position.x = clamp(global_position.x, 0, screen_size.x)
	global_position.y = clamp(global_position.y, 0, screen_size.y)


func _unhandled_input(event):
	if event.is_action_pressed("dash") and not is_dashing and can_dash:
		start_dash()
	
	if event.is_action_pressed("shoot") and can_shoot and current_ammo > 0 and not is_reloading:
		shoot()
	
	if event.is_action_pressed("reload") and not is_reloading and current_ammo < magazine_size:
		reload_gun()
	
	if event.is_action_pressed("special") and can_use_special and current_ammo > 0 and not is_reloading:
		fan_the_hammer()

func apply_card_buff(card_data):
	match card_data.suit:
		"Cups":
			max_health += card_data.value
			current_health += card_data.value # Heal for the same amount
			health_bar.max_value = max_health
			health_bar.value = current_health
		"Swords":
			base_bullet_damage += card_data.value
		"Pentacles":
			var multiplier = card_data.value / 100.0
			attack_speed_multiplier += multiplier
			reload_speed_multiplier += multiplier
		"Wands":
			magazine_size += card_data.value
			# Also refill ammo
			current_ammo = magazine_size
			ammo_label.text = "%d / %d" % [current_ammo, magazine_size]

func take_damage(amount):
	current_health -= amount
	if current_health < 0:
		current_health = 0
	
	if health_bar:
		health_bar.value = current_health
	
	if current_health == 0:
		player_died.emit()
		hide()
		$CollisionShape2D.set_deferred("disabled", true)


func start_dash():
	is_dashing = true
	can_dash = false
	$DashCooldown.start()
	if dash_bar:
		dash_bar.visible = true
	
	dash_direction = (get_global_mouse_position() - global_position).normalized()
	
	get_tree().create_timer(0.2).timeout.connect(func(): is_dashing = false)


func shoot():
	if not bullet_scene:
		print("ERROR: Bullet scene not set on player!")
		return
	
	current_ammo -= 1
	can_shoot = false
	
	if ammo_label:
		ammo_label.text = "%d / %d" % [current_ammo, magazine_size]
	
	var bullet = bullet_scene.instantiate()
	bullet.speed = 1200
	bullet.damage = base_bullet_damage # Use the new damage variable
	get_tree().root.add_child(bullet)
	bullet.global_transform = muzzle.global_transform
	
	# Apply attack speed multiplier
	var fire_rate = 0.5 / attack_speed_multiplier
	get_tree().create_timer(fire_rate).timeout.connect(func(): can_shoot = true)
	
	if current_ammo == 0 and not is_reloading:
		reload_gun()


func reload_gun():
	is_reloading = true
	# Apply reload speed multiplier
	$ReloadTimer.wait_time = 1.0 / reload_speed_multiplier
	$ReloadTimer.start()
	
	if ammo_label:
		ammo_label.text = "Reloading..."
	if reload_indicator:
		reload_indicator.visible = true


func fan_the_hammer():
	can_use_special = false
	can_shoot = false
	$SpecialCooldown.start()
	
	if special_label:
		special_label.text = "Special: 6.0s"
	
	var bullets_to_fire = current_ammo
	current_ammo = 0
	
	if ammo_label:
		ammo_label.text = "%d / %d" % [current_ammo, magazine_size]
	
	for i in bullets_to_fire:
		if not bullet_scene: return
		var bullet = bullet_scene.instantiate()
		bullet.speed = 2000
		bullet.damage = base_bullet_damage # Special also uses new damage
		get_tree().root.add_child(bullet)
		
		var spread = deg_to_rad(randf_range(-15, 15))
		bullet.global_position = muzzle.global_position
		bullet.global_rotation = muzzle.global_rotation + spread
		
		await get_tree().create_timer(0.05).timeout
	
	reload_gun()
	can_shoot = true


func _on_special_cooldown_timeout():
	can_use_special = true
	if special_label:
		special_label.text = "Special: Ready"


func _on_dash_cooldown_timeout():
	can_dash = true
	if dash_bar:
		dash_bar.visible = false


func _on_reload_timer_timeout():
	is_reloading = false
	current_ammo = magazine_size
	
	if ammo_label:
		ammo_label.text = "%d / %d" % [current_ammo, magazine_size]
	if reload_indicator:
		reload_indicator.visible = false
		reload_indicator.value = 0
