extends SceneTree

func _initialize() -> void:
	call_deferred("_run_check")

func _run_check() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn") as PackedScene
	var main_node: Node = packed.instantiate()
	root.add_child(main_node)
	await process_frame
	await process_frame
	var data: Node = root.get_node("GameData")
	var window: Window = root as Window
	window.size = Vector2i(956, 440)
	await process_frame
	var hero: Node2D = main_node.get_node("Hero") as Node2D
	var sprite: AnimatedSprite2D = hero.get_node("Sprite") as AnimatedSprite2D
	var background: TextureRect = main_node.get_node("BackgroundLayer/Background") as TextureRect
	var foods: Node2D = main_node.get_node("Foods") as Node2D
	var enemy_nodes: Array[Node] = get_nodes_in_group("enemies")
	print("Layout runtime check: view=", data.view_size(), " belt_top=", data.belt_top())
	print("background pos=", background.position, " size=", background.size, " texture=", background.texture.get_size())
	print("hero pos=", hero.position, " scale=", sprite.scale, " foods=", foods.get_child_count(), " enemies=", enemy_nodes.size())
	for food_node in foods.get_children():
		var food: Node2D = food_node as Node2D
		var area: CollisionShape2D = food.get_node("CollisionShape2D") as CollisionShape2D
		print("food=", food.name, " center=", food.position, " card=", food.get("card_rect").size if food.get("card_rect") != null else "n/a", " collision=", area.shape.get_rect().size if area.shape is RectangleShape2D else Vector2.ZERO)
	quit()
