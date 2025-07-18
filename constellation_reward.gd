extends Control

signal keystone_chosen(offering_data)
signal offer_scrapped

@onready var card_1 = $HBoxContainer/ConstellationCardUi
@onready var card_2 = $HBoxContainer/ConstellationCardUi2
@onready var scrap_button = $ScrapButton

func _ready():
	card_1.keystone_selected.connect(on_keystone_chosen)
	card_2.keystone_selected.connect(on_keystone_chosen)
	scrap_button.pressed.connect(_on_scrap_button_pressed)
	hide()

func show_offerings(offerings: Array):
	if offerings.is_empty():
		# No valid offerings, so just skip to the next part of the game loop
		offer_scrapped.emit()
		return
	
	# Display the first offering
	card_1.display_offering(offerings[0])
	card_1.show()
	
	# Display the second offering if it exists, otherwise hide the card
	if offerings.size() > 1:
		card_2.display_offering(offerings[1])
		card_2.show()
	else:
		card_2.hide()
	
	show()
	get_tree().paused = true

func on_keystone_chosen(offering_data):
	keystone_chosen.emit(offering_data)
	hide()

func _on_scrap_button_pressed():
	offer_scrapped.emit()
	hide()
