extends Node

var total_kills = 0

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
		"crit_chance": return base_value * 0.35 # e.g., King = ~5% Crit Chance
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
