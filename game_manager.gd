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

# --- Weapon Database ---
var weapon_database: Dictionary = {}

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
	# NEW: This function now builds our weapon database at the start of the game
	build_weapon_database()
	
# NEW: This function "tempers" the raw card value based on the effect type
func get_scaled_value(rank_number, effect_type):
	var base_value = 0
	if rank_number <= 10:
		base_value = rank_number
	else:
		base_value = 10 + (rank_number - 10) * 2

	match effect_type:
		"max_health": return base_value * 2 # e.g., King = 14*2 = 28 HP
		"phys_resist", "elemental_resist", "all_resist": return base_value * 0.5 # e.g., King = 7% Resist
		"move_speed", "atk_speed", "reload_speed": return base_value # e.g., King = 14% Speed
		"max_ammo": return base_value
		"phys_dmg", "fire_dmg", "cold_dmg", "lightning_dmg": return base_value
		"crit_chance": return base_value * 0.45 # e.g., King = ~5% Crit Chance
		"chaos_dmg": return Vector2(0, base_value * 2) # e.g., King = 14-28 Chaos
		"crit_dmg": return base_value * 2.5 # e.g., King = 35% Crit Damage
		"special_dmg": return base_value * 0.6 # e.g., King = ~8% Special Damage
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

func get_random_reward_weapon(current_weapon_name):
	var weapon_pool = weapon_database.keys()
	weapon_pool.erase(current_weapon_name) # Can't get a reward for the weapon you already have
	var reward_weapon_name = weapon_pool.pick_random()
	return weapon_database[reward_weapon_name]
