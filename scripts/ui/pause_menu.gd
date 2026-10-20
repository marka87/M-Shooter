extends CanvasLayer
class_name PauseMenu

## Pause-Einblendung mit Weiterspielen, Hauptmenue und Beenden.
## Wird vom GameManager einmal erzeugt und per show()/hide() umgeschaltet.

@onready var resume_button: Button = $Center/VBox/ResumeButton
@onready var menu_button: Button = $Center/VBox/MenuButton
@onready var quit_button: Button = $Center/VBox/QuitButton


func _ready() -> void:
	resume_button.pressed.connect(GameManager.toggle_pause)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(GameManager.quit_game)
	visibility_changed.connect(_on_visibility_changed)


## Beim Einblenden den ersten Button fokussieren (Tastatur/Gamepad-Bedienung)
func _on_visibility_changed() -> void:
	if visible:
		resume_button.grab_focus()


func _on_menu_pressed() -> void:
	GameManager.toggle_pause()
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
