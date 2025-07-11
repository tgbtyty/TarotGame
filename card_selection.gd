extends Control

@onready var card_container = $HBoxContainer
@onready var card_ui_scene = preload("res://card_ui.tscn")

var player = null
var cards = []

func _ready():
	player = get_tree().get_first_node_in_group("players")

func start_selection():
	# Clear old cards
	for child in card_container.get_children():
		child.queue_free()
	
	cards.clear()
	# Generate 3 unique cards
	while cards.size() < 3:
		var new_card = GameManager.generate_card()
		var is_duplicate = false
		for existing_card in cards:
			if existing_card.name == new_card.name:
				is_duplicate = true
				break
		if not is_duplicate:
			cards.append(new_card)

	# Create and display the card UI
	for card_data in cards:
		var card_instance = card_ui_scene.instantiate()
		card_container.add_child(card_instance)
		card_instance.display_card(card_data)
		card_instance.card_chosen.connect(_on_card_chosen)
	
	show()
	get_tree().paused = true

func _on_card_chosen(chosen_card_data):
	# Apply effects
	for card_data in cards:
		if card_data.name == chosen_card_data.name:
			# Apply player buff
			player.apply_card_buff(card_data)
		else:
			# Apply enemy buff
			GameManager.apply_passed_card(card_data)
	
	# End selection
	hide()
	get_tree().paused = false
