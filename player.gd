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

# --- Buffs ---
var is_repelling = false

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

# --- Node References ---
@onready var muzzle = $Muzzle
@onready var dash_bar = $DashBar
@onready var pushback_area = $PushbackArea
@onready var health_bar = get_node_or_null("/root/Main/HUD_Layer/HealthBar")
@onready var special_label = get_node_or_null("/root/Main/HUD_Layer/SpecialCooldownLabel")
@onready var ammo_label = get_node_or_null("/root/Main/HUD_Layer/AmmoLabel")
@onready var reload_indicator = get_node_or_null("/root/Main/HUD_Layer/ReloadIndicator")


func _ready():
	current_health = max_health
	current_ammo = magazine_size
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	if special_label:
		special_label.text = "Special: Ready"
	
	if dash_bar:
		dash_bar.max_value = $DashCooldown.wait_time
		dash_bar.value = dash_bar.max_value
		dash_bar.visible = false
		
	if ammo_label:
		ammo_label.text = "%d / %d" % [current_ammo, magazine_size]
	if reload_indicator:
		reload_indicator.value = 0
		reload_indicator.visible = false


func _physics_process(_delta):
	# --- Handle Autofire ---
	if Input.is_action_pressed("shoot") and can_shoot and current_ammo > 0 and not is_reloading:
		shoot()
		
	# --- Handle Blue Orb Repel ---
	if is_repelling:
		push_back_nearby_enemies()
	
	# Update UI elements every frame
	if special_label and not $SpecialCooldown.is_stopped():
		special_label.text = "Special: %.1fs" % $SpecialCooldown.time_left
	
	if dash_bar and dash_bar.visible:
		dash_bar.value = $DashCooldown.time_left
		
	if is_reloading and reload_indicator:
		var reload_timer = $ReloadTimer
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
	# Shooting logic was moved to _physics_process for autofire
	if event.is_action_pressed("dash") and not is_dashing and can_dash:
		start_dash()
	
	if event.is_action_pressed("reload") and not is_reloading and current_ammo < magazine_size:
		reload_gun()
	
	if event.is_action_pressed("special") and can_use_special and current_ammo > 0 and not is_reloading:
		fan_the_hammer()

func apply_card_buff(card_data):
	match card_data.suit:
		"Cups":
			max_health += card_data.value
			current_health += card_data.value
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
			current_ammo = magazine_size
			ammo_label.text = "%d / %d" % [current_ammo, magazine_size]

func take_damage(amount):
	if is_repelling: return # Blue orb makes you immune to touch damage
	
	current_health -= amount
	if health_bar:
		health_bar.value = current_health
	
	push_back_nearby_enemies()
	
	if current_health <= 0:
		current_health = 0
		player_died.emit()
		hide()
		$CollisionShape2D.set_deferred("disabled", true)

func push_back_nearby_enemies():
	var bodies = pushback_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemies"):
			var push_direction = (body.global_position - global_position).normalized()
			body.apply_knockback(push_direction)


func start_dash():
	is_dashing = true
	can_dash = false
	$DashCooldown.start()
	if dash_bar:
		dash_bar.visible = true
	
	var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_direction != Vector2.ZERO:
		dash_direction = input_direction.normalized()
	else:
		dash_direction = Vector2.RIGHT.rotated(global_rotation)
	
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
	bullet.speed = 900
	bullet.damage = base_bullet_damage
	get_tree().root.add_child(bullet)
	bullet.global_transform = muzzle.global_transform
	
	var fire_rate = 0.5 / attack_speed_multiplier
	get_tree().create_timer(fire_rate).timeout.connect(func(): can_shoot = true)
	
	if current_ammo == 0 and not is_reloading:
		reload_gun()


func reload_gun():
	# Don't interrupt a reload
	if is_reloading: return
	
	is_reloading = true
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
		bullet.damage = base_bullet_damage
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


func apply_yellow_orb_effect():
	# 1. Fill ammo
	if not is_reloading: current_ammo = magazine_size
	if ammo_label: ammo_label.text = "%d / %d" % [current_ammo, magazine_size]
	
	# 2. Double attack speed for 3 seconds
	attack_speed_multiplier *= 2
	var tween = get_tree().create_tween()
	tween.tween_interval(3.0) # Wait 3 seconds
	tween.tween_callback(func(): attack_speed_multiplier /= 2) # Revert speed
	tween.tween_callback(func(): # 3. Fill ammo again
		if not is_reloading: current_ammo = magazine_size
		if ammo_label: ammo_label.text = "%d / %d" % [current_ammo, magazine_size]
	)

func apply_green_orb_effect():
	var heal_amount = max_health * 0.25
	# min() prevents overhealing
	current_health = min(max_health, current_health + heal_amount)
	if health_bar:
		health_bar.value = current_health

func apply_blue_orb_effect():
	is_repelling = true
	var tween = get_tree().create_tween()
	tween.tween_interval(5.0) # Wait 5 seconds
	# CORRECTED: This now properly sets 'is_repelling' to false.
	tween.tween_callback(func(): is_repelling = false) # Turn off repel effect


func _on_orb_collector_area_area_entered(area: Area2D) -> void:
		if area.is_in_group("orbs"):
			match area.orb_type:
				"yellow":
					apply_yellow_orb_effect()
				"green":
					apply_green_orb_effect()
				"blue":
					apply_blue_orb_effect()
			area.queue_free()
