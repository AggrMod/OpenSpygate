extends Node3D
## Calder: the edge of downtown, the first piece of the city. A 3 x 3 grid of streets around four blocks,
## with pavements, street furniture, signals at the centre junction, and a sky that follows the hour.
## Everything is built in code so the scene file stays one readable line. Past the outer pavements there is void.
##
## Tests read `player`, `car`, `sky` and `roads` from this node, as they do in the void.
## Buildings come from another module: if res://worlds/city/buildings/building.gd exists, each lot gets
## `create(width, depth, seed, opts)` placed on it; otherwise the lots stay void behind invisible barriers.

const BUILDING_SCRIPT: String = "res://worlds/city/buildings/building.gd"
## The car stands in the eastbound parking lane of Corder St, in a bay, with the whole street ahead of it.
const CAR_AT: Vector3 = Vector3(-76.6, 0.05, CityRoads.LANE + CityRoads.PARKING / 2.0)
## The player starts on the pavement beside the car's driver side, facing east along the street.
const SPAWN_AT: Vector3 = Vector3(CAR_AT.x - 1.2, CityRoads.KERB_H, CityRoads.HALF_ROAD + 1.6)
const VIEW_DISTANCE: float = 420.0

var player: Player
var car: Vehicle
var sky: CitySky
var roads: CityRoads
var furniture: Node3D
var buildings: Array[Node3D] = []


func _ready() -> void:
	if Game.world != "city":
		return          # Game is about to swap in the world that was asked for
	sky = CitySky.new()
	add_child(sky)
	sky.hour = Game.start_hour
	roads = CityRoads.new()
	roads.name = "Roads"
	add_child(roads)
	roads.build()
	roads.set_wetness(Game.start_wet)
	_build_furniture()
	_build_lots()
	if ResourceLoader.exists(Vehicle.MODEL):
		car = Vehicle.new()
		car.name = "Car"
		add_child(car)
		car.global_transform = Transform3D(Basis.looking_at(Vector3(1.0, 0.0, 0.0)), CAR_AT)
	player = Player.new()
	player.position = SPAWN_AT
	add_child(player)
	player.rotation.y = -PI / 2.0          # facing east, along the street toward the signals
	player.camera.far = VIEW_DISTANCE


func _build_furniture() -> void:
	var script_path := "res://worlds/city/furniture.gd"
	if not ResourceLoader.exists(script_path):
		return
	furniture = (load(script_path) as GDScript).new() as Node3D
	furniture.name = "Furniture"
	# Keep the pavement clear where the player starts, so the first view is the street, not a tree trunk.
	furniture.set("keep_clear", [Vector2(SPAWN_AT.x, SPAWN_AT.z)])
	add_child(furniture)
	furniture.call("build", roads)
	if furniture.has_method("set_night"):
		sky.night_changed.connect(Callable(furniture, "set_night"))
		furniture.call("set_night", maxf(sky.night, 0.0))


## Put a building on every lot if the buildings module is present; otherwise keep people out of the void.
func _build_lots() -> void:
	var builder: Script = null
	if ResourceLoader.exists(BUILDING_SCRIPT):
		builder = load(BUILDING_SCRIPT) as Script
	for lot: Dictionary in roads.lots():
		var made: Node3D = null
		if builder != null:
			var opts := {"open_neg_x": lot["open_neg_x"], "open_pos_x": lot["open_pos_x"], "open_back": false}
			made = builder.call("create", lot["width"], lot["depth"], lot["seed"], opts) as Node3D
		if made == null:
			add_child(roads.lot_barrier(lot))
			continue
		made.transform = lot["transform"]
		add_child(made)
		buildings.append(made)
		if made.has_method("set_lit"):
			sky.night_changed.connect(Callable(made, "set_lit"))
			made.call("set_lit", maxf(sky.night, 0.0))


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("time_forward"):
		sky.advance(1.0)
	if car == null or not Input.is_action_just_pressed("interact"):
		return
	if car.driver != null:
		if absf(car.speed) < 3.0:
			car.leave()
	elif player.global_position.distance_to(car.global_position) < 3.2:
		car.enter(player)
