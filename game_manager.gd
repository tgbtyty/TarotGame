extends Node

var total_kills = 0
var total_tokens = 0

# --- Global Enemy Stat Modifiers ---
var enemy_health_bonus = 0
var enemy_damage_bonus = 0 # Now just for physical
var enemy_speed_multiplier = 1.0
var enemy_size_multiplier = 1.0
var enemy_crit_chance = 0.0
var enemy_crit_damage = 0.0
var enemy_all_resist = 0.0
var enemy_fire_damage_bonus = 0.0
var enemy_cold_damage_bonus = 0.0
var enemy_lightning_damage_bonus = 0.0
var enemy_chaos_damage_bonus = Vector2.ZERO

# --- Constellation Progression ---
var constellation_pity_counter = 0
var owned_keystones = {} # e.g., {"leo_inferno": true}
var keystone_counts = {"Leo": 0}
var is_avatar = false
var avatar_of = ""

# --- Weapon Database ---
var weapon_database: Dictionary = {}
var constellation_database: Dictionary = {}

# --- Card Data ---
var ranks = {
	1: "Ace", 2: "2", 3: "3", 4: "4", 5: "5", 6: "6", 7: "7", 8: "8", 9: "9", 10: "10",
	11: "Page", 12: "Knight", 13: "Queen", 14: "King"
}

# NEW: Each suit now has 4 distinct possible effects
var suit_effects = {
	"Cups": ["max_health", "phys_resist", "move_speed", "max_ammo"],
	"Swords": ["phys_dmg", "atk_speed", "reload_speed", "crit_chance"],
	"Wands": ["fire_dmg", "cold_dmg", "lightning_dmg", "elemental_resist"],
	"Pentacles": ["chaos_dmg", "crit_dmg", "special_dmg", "all_resist"]
}

func _ready():
	build_weapon_database()
	build_constellation_database()
	
# NEW: This function "tempers" the raw card value based on the effect type
func get_scaled_value(rank_number, effect_type):
	var base_value = 0
	if rank_number <= 10:
		base_value = rank_number
	else:
		base_value = 10 + (rank_number - 10) * 2

	match effect_type:
		"max_health": return base_value * 2 # e.g., King = 14*2 = 28 HP
		"phys_resist", "elemental_resist", "all_resist": return base_value # e.g., King = 7% Resist
		"move_speed", "atk_speed", "reload_speed": return base_value # e.g., King = 14% Speed
		"max_ammo": return base_value
		"phys_dmg", "cold_dmg", "lightning_dmg": return base_value
		"fire_dmg": return base_value * 2;
		"crit_chance": return base_value # e.g., King = ~5% Crit Chance
		"chaos_dmg": return Vector2(0, base_value * 2) # e.g., King = 14-28 Chaos
		"crit_dmg": return base_value * 2.5 # e.g., King = 35% Crit Damage
		"special_dmg": return base_value # e.g., King = ~8% Special Damage
		_: return base_value

func generate_card():
	var suit = suit_effects.keys().pick_random()
	var effect_type = suit_effects[suit].pick_random()
	var rank_number = ranks.keys().pick_random()
	
	var card = {
		"suit": suit,
		"rank_name": ranks[rank_number],
		"rank_number": rank_number,
		"effect_type": effect_type,
		"name": "%s of %s" % [ranks[rank_number], suit]
	}
	return card
	
func generate_fire_card():
	var suit = suit_effects.keys().get(2)
	var effect_type = suit_effects[suit].get(0)
	var rank_number = ranks.keys().pick_random()
	
	var card = {
		"suit": suit,
		"rank_name": ranks[rank_number],
		"rank_number": rank_number,
		"effect_type": effect_type,
		"name": "%s of %s" % [ranks[rank_number], suit]
	}
	return card

func apply_passed_card(card_data):
	var effect = card_data.effect_type
	var value = get_scaled_value(card_data.rank_number, effect)
	
	# UPDATED: All cases are now filled out
	match effect:
		"max_health": enemy_health_bonus += value
		"phys_resist": enemy_all_resist += value / 100.0 # Passed resist buffs all enemy resists
		"move_speed": enemy_speed_multiplier += value / 100.0
		"max_ammo": enemy_size_multiplier += value / 100.0
		"phys_dmg": enemy_damage_bonus += value
		"atk_speed": enemy_speed_multiplier += value / 100.0 # Player atk speed becomes enemy move speed
		"reload_speed": enemy_damage_bonus += value
		"crit_chance": enemy_crit_chance += value / 100.0
		"fire_dmg": enemy_fire_damage_bonus += value
		"cold_dmg": enemy_cold_damage_bonus += value
		"lightning_dmg": enemy_lightning_damage_bonus += value
		"elemental_resist": enemy_health_bonus += value * 2 # Passed elemental resist gives enemies health
		"chaos_dmg": 
			enemy_chaos_damage_bonus.x += value.x
			enemy_chaos_damage_bonus.y += value.y
		"crit_dmg": enemy_crit_damage += value / 100.0
		"special_dmg": enemy_health_bonus += value * 2
		"all_resist": enemy_all_resist += value / 100.0
func build_weapon_database():
	# PISTOL (Base Gun)
	var pistol_dmg = DamageInfo.new()
	pistol_dmg.physical_damage = 5
	var pistol = WeaponData.new()
	pistol.weapon_name = "Pistol"
	pistol.description = "A reliable sidearm. Standard performance."
	pistol.base_max_ammo = 20
	pistol.base_reload_time = 1.0
	pistol.base_fire_rate = 0.5
	pistol.base_damage = pistol_dmg
	weapon_database["Pistol"] = pistol
	
	# SHOTGUN
	var shotgun_dmg = DamageInfo.new()
	shotgun_dmg.physical_damage = 20
	var shotgun = WeaponData.new()
	shotgun.weapon_name = "Shotgun"
	shotgun.description = "Fires 4 pellets in a cone. Added damage is divided among pellets."
	shotgun.base_max_ammo = 2
	shotgun.base_reload_time = 0.75
	shotgun.base_fire_rate = 0.3
	shotgun.base_damage = shotgun_dmg
	shotgun.added_damage_divisor = 4.0 # Divides added damage by 4
	weapon_database["Shotgun"] = shotgun
	
	# SNIPER
	var sniper_dmg = DamageInfo.new()
	sniper_dmg.physical_damage = 50
	var sniper = WeaponData.new()
	sniper.weapon_name = "Sniper"
	sniper.description = "A slow, powerful shot that pierces all enemies. Added damage is doubled. Speed/ammo modifiers are halved."
	sniper.base_max_ammo = 1
	sniper.base_reload_time = 1.0
	sniper.base_fire_rate = 0.5
	sniper.base_damage = sniper_dmg
	sniper.added_damage_multiplier = 2.0 # Doubles added damage
	sniper.stat_modifier_multiplier = 0.5 # Halves buffs to speed/ammo
	weapon_database["Sniper"] = sniper
	
		# FLAMETHROWER (NEW)
	var ft_dmg = DamageInfo.new()
	ft_dmg.fire_damage = 20
	var flamethrower = WeaponData.new()
	flamethrower.weapon_name = "Flamethrower"
	flamethrower.description = "A continuous stream of fire that damages enemies in a cone. Cannot deal Physical damage."
	flamethrower.base_max_ammo = 50
	flamethrower.base_reload_time = 1.5 # Reloads the whole tank
	flamethrower.base_fire_rate = 0.1 # Fires very fast
	flamethrower.base_damage = ft_dmg
	flamethrower.accepts_physical_damage_buffs = false # This is the important flag
	weapon_database["Flamethrower"] = flamethrower

func get_random_reward_weapon(current_weapon_name):
	var weapon_pool = weapon_database.keys()
	weapon_pool.erase(current_weapon_name) # Can't get a reward for the weapon you already have
	var reward_weapon_name = weapon_pool.pick_random()
	return weapon_database[reward_weapon_name]


func get_constellation_offerings():
	var offerings = []
	var available_constellations = constellation_database.keys()
	
	while offerings.size() < 2 and not available_constellations.is_empty():
		var const_name = available_constellations.pick_random()
		var constellation = constellation_database[const_name]
		
		# Check for Avatar offering
		if keystone_counts.get(const_name, 0) >= 4:
			var avatar_offering = KeystoneData.new()
			avatar_offering.key_id = "avatar_%s" % const_name.to_lower()
			avatar_offering.key_name = "Become the Avatar of %s" % const_name
			avatar_offering.description = "Unlock the ultimate power of %s, enhancing all of its Keystones." % const_name
			offerings.append({"constellation": constellation, "keystone": avatar_offering})
			available_constellations.erase(const_name)
			continue

		# Get a random unowned keystone
		var unowned_keystones = []
		for keystone in constellation.keystones:
			if not owned_keystones.has(keystone.key_id):
				unowned_keystones.append(keystone)
		
		if not unowned_keystones.is_empty():
			offerings.append({"constellation": constellation, "keystone": unowned_keystones.pick_random()})
		
		available_constellations.erase(const_name)
		
	return offerings
	
func should_constellation_appear(chosen_card_rank):
	if is_avatar: return false
	
	constellation_pity_counter += 1
	if constellation_pity_counter >= 7:
		return true
	
	# Lower rank cards give a higher chance. A rank of 1 gives a 20% bonus (5+20=25%)
	var rank_bonus = (14 - chosen_card_rank) / 14.0 * 0.20 
	var final_chance = 0.05 + rank_bonus
	
	return 1 #randf() < final_chance
	
func build_constellation_database():
	# --- LEO ---
	var leo = ConstellationData.new()
	leo.const_name = "Leo"
	
	var k1 = KeystoneData.new()
	k1.key_id = "leo_inferno"; k1.key_name = "Become the Inferno"; k1.description = "Deal ONLY fire damage. Double your fire damage. All other damage types REDUCE your fire damage by the same amount."; k1.avatar_description = "Avatar: Convert all damage to fire instead of reducing it."
	
	var k2 = KeystoneData.new()
	k2.key_id = "leo_burn_world"; k2.key_name = "Burn the World"; k2.description = "You and all enemies can no longer gain fire resistance. Enemies convert all their damage to fire."; k2.avatar_description = "Avatar: Enemies can now have negative fire resistance."

	var k3 = KeystoneData.new()
	k3.key_id = "leo_char_flesh"; k3.key_name = "Char the Flesh"; k3.description = "Your burns can now stack up to 10. Dealing non-fire damage heals enemies."; k3.avatar_description = "Avatar: Burn ticks reduce enemy fire resistance by 4%."

	var k4 = KeystoneData.new()
	k4.key_id = "leo_herald_ash"; k4.key_name = "Herald of Ash"; k4.description = "Enemies that die while burning heal you for 1% of your max health."; k4.avatar_description = "Avatar: Whenever enemies burn, they burn all nearby enemies."
	
	var k5 = KeystoneData.new()
	k5.key_id = "leo_fan_flames"; k5.key_name = "Fan the Flames"; k5.description = "Your burns deal damage and expire twice as fast. Burning enemies gain 30% movement speed."; k5.avatar_description = "Avatar: Passively burn nearby enemies every 0.5 seconds."

	leo.keystones = [k1, k2, k3, k4, k5]
	constellation_database["Leo"] = leo
	# (Add other constellations here in the future)
	
		# --- SAGITTARIUS (NEW) ---
	var sagittarius = ConstellationData.new()
	sagittarius.const_name = "Sagittarius"
	
	# UPDATED: Changed variable names to be unique
	var sk1 = KeystoneData.new()
	sk1.key_id = "sagi_blot_skies"; sk1.key_name = "Blot out the skies"; sk1.description = "Double your projectiles. Projectiles are fired in random directions around you instead of where you're aiming."; sk1.avatar_description = "Avatar: Triple your projectiles."
	var sk2 = KeystoneData.new()
	sk2.key_id = "sagi_throatseeker"; sk2.key_name = "Throatseeker"; sk2.description = "Your projectiles bend toward enemies, giving them a slight homing effect."; sk2.avatar_description = "Avatar: Your projectiles have true homing."
	var sk3 = KeystoneData.new()
	sk3.key_id = "sagi_heartpiercer"; sk3.key_name = "Heartpiercer"; sk3.description = "Projectiles gain damage as they travel, dealing up to 30% MORE damage, but start with 20% LESS damage."; sk3.avatar_description = "Avatar: Projectiles gain up to 200% MORE damage as they travel."
	var sk4 = KeystoneData.new()
	sk4.key_id = "sagi_herald_shrapnel"; sk4.key_name = "Herald of Shrapnel"; sk4.description = "Your projectiles have +2 pierce. Deal 10% less damage."; sk4.avatar_description = "Avatar: Your projectiles have +10 pierce."
	var sk5 = KeystoneData.new()
	sk5.key_id = "sagi_zhuge_liang"; sk5.key_name = "Zhuge Liang"; sk5.description = "Your projectiles have 20% increased lifespan/range."; sk5.avatar_description = "Avatar: Your projectiles have 200% increased lifespan/range."

	sagittarius.keystones = [sk1, sk2, sk3, sk4, sk5]
	constellation_database["Sagittarius"] = sagittarius
	
