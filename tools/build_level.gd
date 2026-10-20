extends SceneTree

## Baut die func_godot-Map einer Level-Vorlage und speichert das fertige Level.
## Aufruf (aus dem Projektordner):
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/build_level.gd -- <vorlage.tscn> <ziel.tscn>
## Beispiel: ... -- res://levels/neon_foundry_template.tscn res://levels/neon_foundry.tscn
## Im Editor geht dasselbe ueber den Knopf "Build Map" am FuncGodotMap-Knoten.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Aufruf: -- <vorlage.tscn> <ziel.tscn>")
		quit(1)
		return
	var packed: PackedScene = load(args[0])
	var level: Node = packed.instantiate()
	root.add_child(level)

	var built := 0
	for map in level.find_children("*", "FuncGodotMap", true, false):
		map.build()
		# Erzeugte Knoten muessen zur Szene gehoeren, sonst werden sie nicht gespeichert
		for node in map.find_children("*", "", true, false):
			node.owner = level
		built += 1
		print("Map gebaut: ", map.name, " (", map.get_child_count(), " Knoten)")

	root.remove_child(level)
	var out := PackedScene.new()
	var err := out.pack(level)
	if err == OK:
		err = ResourceSaver.save(out, args[1])
	print("Gespeichert: ", args[1], " -> ", error_string(err))
	level.free()
	quit(0 if err == OK and built > 0 else 1)
