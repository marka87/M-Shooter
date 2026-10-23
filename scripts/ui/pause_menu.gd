extends CanvasLayer
class_name PauseMenu

## Pause-Einblendung mit Weiterspielen, Hauptmenue, Beenden und der Armfarbe (gilt sofort).
## Wird vom GameManager einmal erzeugt und per show()/hide() umgeschaltet.

@onready var resume_button: Button = $Center/VBox/ResumeButton
@onready var menu_button: Button = $Center/VBox/MenuButton
@onready var quit_button: Button = $Center/VBox/QuitButton
@onready var arms_color_option: OptionButton = $Center/VBox/ArmsRow/ArmsColorOption


func _ready() -> void:
	resume_button.pressed.connect(GameManager.toggle_pause)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(GameManager.quit_game)
	for color_name in ViewHands.COLOR_NAMES:
		arms_color_option.add_item(color_name)
	arms_color_option.item_selected.connect(_on_arms_color_selected)
	visibility_changed.connect(_on_visibility_changed)


## Beim Einblenden den ersten Button fokussieren (Tastatur/Gamepad-Bedienung)
func _on_visibility_changed() -> void:
	if visible:
		arms_color_option.selected = GameManager.arms_color
		resume_button.grab_focus()


func _on_arms_color_selected(index: int) -> void:
	GameManager.arms_color = index
	GameManager.save_settings()


func _on_menu_pressed() -> void:
	GameManager.toggle_pause()
	Net.leave()
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
