extends Area2D

var orb_type = "green" # Default type, will be changed by the spawner
@onready var color_rect = $ColorRect

func set_type(type):
	orb_type = type
	match orb_type:
		"yellow":
			color_rect.color = Color.GOLD
		"green":
			color_rect.color = Color.SPRING_GREEN
		"blue":
			color_rect.color = Color.DODGER_BLUE
# This function will run when the timer ends
func _on_timer_timeout():
	queue_free() # This destroys the orb
