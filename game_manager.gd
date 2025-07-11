extends Node

# --- Global Enemy Stat Modifiers ---
var enemy_health_bonus = 0
var enemy_damage_bonus = 0
var enemy_speed_multiplier = 1.0
var enemy_size_multiplier = 1.0

# --- Card Data ---
var suits = ["Cups", "Swords", "Wands", "Pentacles"]
var ranks = {
	1: "Ace", 2: "2", 3: "3", 4: "4", 5: "5", 6: "6", 7: "7", 8: "8", 9: "9", 10: "10",
	11: "Page", 12: "Knight", 13: "Queen", 14: "King"
}

func get_card_value(rank_number):
	if rank_number <= 10:
		return rank_number
	# Page, Knight, Queen, King have higher values
	return 10 + (rank_number - 10) * 2

func generate_card():
	var suit = suits.pick_random()
	var rank_number = ranks.keys().pick_random()
	var card_value = get_card_value(rank_number)
	
	var card = {
		"suit": suit,
		"rank_name": ranks[rank_number],
		"value": card_value,
		"name": "%s of %s" % [ranks[rank_number], suit]
	}
	return card

func apply_passed_card(card_data):
	match card_data.suit:
		"Cups":
			enemy_health_bonus += card_data.value
		"Swords":
			enemy_damage_bonus += card_data.value
		"Pentacles":
			# Additive percentage increase
			enemy_speed_multiplier += (card_data.value / 100.0)
		"Wands":
			# Additive percentage increase
			enemy_size_multiplier += (card_data.value / 100.0)
