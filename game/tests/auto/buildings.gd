extends Node
## Self-playing test for the building generator. It replaces the void with a test street of
## its own (ground strips, sun and sky exist only here), puts generated buildings on both
## sides, photographs them by day, at dusk and at night, checks the API contract and the
## budgets, records the frame rate, and writes result.json. The exit code is not trusted.

const WORLD: String = "void"        # read by Game: this test runs in the void (see autoload/game.gd)
const ROAD_W: float = 12.0
const PAVE_W: float = 3.6
const LOT_DEPTH: float = 30.0
const GALLERY_Z: float = -600.0

var _result: Dictionary = {"test": "buildings", "pass": false, "notes": [], "checks": {}}
var _root: Node3D
var _cam: Camera3D
var _sun: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _street: Array[CityBuilding] = []
var _far_block: Array[CityBuilding] = []
var _gallery: Dictionary = {}
var _lots: Array[Dictionary] = []
var _lamps: Array[Node3D] = []
var _last_img: Image
var _diff: float = 0.0
var _bright_dark: int = 0
var _bright_lit: int = 0
var _vertices_checked: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	var old := get_tree().current_scene
	if old != null:
		old.queue_free()
	await get_tree().process_frame
	_root = Node3D.new()
	_root.name = "BuildingsTest"
	get_tree().root.add_child(_root)
	get_tree().current_scene = _root
	_build_world()
	var t0 := Time.get_ticks_msec()
	_build_street()
	_result["build_ms_40"] = Time.get_ticks_msec() - t0
	_build_gallery()
	_check_api()
	if DisplayServer.get_name() == "headless":
		# without graphics (AGENTS.md rule 6): every code check above has run; the pictures,
		# the frame rate and the night pixel count need a real window and are skipped
		_result["headless"] = true
		_result["skipped"] = ["pictures", "fps", "set_lit_lights_signs_and_rooms (pixel count)"]
		var lit_ok := true
		var probe := _street[0]
		probe.set_lit(1.0)
		for mi: MeshInstance3D in [probe.body_mesh, probe.glass_mesh, probe.detail_mesh]:
			if mi != null and not is_equal_approx(float(mi.get_instance_shader_parameter("lit")), 1.0):
				lit_ok = false
		probe.set_lit(0.0)
		_result["checks"]["set_lit_sets_instance_uniform"] = lit_ok
		_conclude()
		return
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.near = 0.05
	_cam.far = 2000.0
	_root.add_child(_cam)
	_cam.make_current()
	await _settle(1.5)

	_day()
	var north0: float = _lots[0]["x0"]
	await _shot("01_street_eye_day", Vector3(north0 + 2.0, 1.7, -ROAD_W / 2.0 - 1.4), Vector3(north0 + 60.0, 4.0, -ROAD_W / 2.0 - 6.0))
	await _shot("02_street_car_day", Vector3(north0 - 4.0, 1.3, 1.8), Vector3(north0 + 60.0, 3.5, 0.0))
	await _shot("03_street_reverse_day", Vector3(north0 + 150.0, 1.7, ROAD_W / 2.0 + 1.4), Vector3(north0 + 90.0, 5.0, 0.0))
	# fps with forty buildings in view, looking down the whole street
	await _measure_fps("fps_street_40", Vector3(north0 - 6.0, 1.7, 0.0), Vector3(north0 + 120.0, 6.0, 0.0))
	# straight-on elevation of each style
	var obb: CityBuilding = _gallery["open_all"]
	await _shot("16_open_back_corner", obb.global_position + Vector3(22.0, 2.0, -LOT_DEPTH - 16.0), obb.global_position + Vector3(0.0, 7.0, -LOT_DEPTH * 0.5), 60.0)
	for st: String in CityBuilding.STYLES:
		var b: CityBuilding = _gallery[st]
		var h := b.top_height
		var dist := maxf(b.lot_width * 1.1, h * 1.25) * 1.45
		var c := b.global_position + Vector3(0, h * 0.5, 0)
		await _shot("04_elevation_" + st, c + Vector3(0, 0, dist), c, 32.0)
	# close-ups
	var shop_b := _first_style(_street, ["brick", "terracotta"])
	if shop_b != null:
		var p := shop_b.global_position
		await _shot("05_shopfront_3m", p + _dir(shop_b, Vector3(-shop_b.lot_width * 0.18, 1.6, 3.0)), p + _dir(shop_b, Vector3(-shop_b.lot_width * 0.18, 1.9, 0.0)), 70.0)
		await _shot("06_upper_windows", p + _dir(shop_b, Vector3(shop_b.lot_width * 0.35, shop_b.roof_height * 0.55, 5.5)), p + _dir(shop_b, Vector3(-shop_b.lot_width * 0.1, shop_b.roof_height * 0.6, -1.0)), 55.0)
	var modern_b := _first_style(_street, ["glass", "midcentury", "brutalist"])
	if modern_b != null:
		var p := modern_b.global_position
		await _shot("07_modern_windows", p + _dir(modern_b, Vector3(modern_b.lot_width * 0.4, 7.0, 6.0)), p + _dir(modern_b, Vector3(-modern_b.lot_width * 0.1, 8.0, -1.0)), 55.0)
	# the corner building at the start of the north side, both street faces
	var corner := _street[0]
	var cp := corner.global_position
	await _shot("08_corner", cp + Vector3(-corner.lot_width * 0.5 - 9.0, 1.7, 9.0), cp + Vector3(-corner.lot_width * 0.1, 5.0, -8.0), 70.0)
	await _shot("09_roof_oblique", Vector3(north0 + 20.0, 42.0, 26.0), Vector3(north0 + 70.0, 8.0, -12.0), 60.0)

	_dusk()
	_set_lit(0.65)
	await _shot("10_street_dusk", Vector3(north0 + 2.0, 1.7, -ROAD_W / 2.0 - 1.4), Vector3(north0 + 60.0, 4.0, -ROAD_W / 2.0 - 6.0))
	_night()
	_set_lit(0.0)
	await _settle(0.4)
	var dark := await _shot("11_street_night_unlit", Vector3(north0 - 4.0, 1.3, 1.8), Vector3(north0 + 60.0, 3.5, 0.0))
	var dark_img := _last_img
	_set_lit(1.0)
	var lit := await _shot("12_street_night", Vector3(north0 - 4.0, 1.3, 1.8), Vector3(north0 + 60.0, 3.5, 0.0))
	_diff = _image_diff(dark_img, _last_img)
	_bright_dark = _bright_count(dark_img)
	_bright_lit = _bright_count(_last_img)
	await _shot("13_street_eye_night", Vector3(north0 + 2.0, 1.7, -ROAD_W / 2.0 - 1.4), Vector3(north0 + 60.0, 4.0, -ROAD_W / 2.0 - 6.0))
	if shop_b != null:
		var p := shop_b.global_position
		await _shot("14_shopfront_night", p + _dir(shop_b, Vector3(-shop_b.lot_width * 0.1, 1.7, 5.0)), p + _dir(shop_b, Vector3(-shop_b.lot_width * 0.1, 2.6, 0.0)), 70.0)
	await _shot("15_roof_night", Vector3(north0 + 20.0, 42.0, 26.0), Vector3(north0 + 70.0, 8.0, -12.0), 60.0)
	await _measure_fps("fps_street_40_night", Vector3(north0 - 6.0, 1.7, 0.0), Vector3(north0 + 120.0, 6.0, 0.0))
	var checks: Dictionary = _result["checks"]
	_result["night_luminance_unlit"] = snappedf(dark, 0.0001)
	_result["night_luminance_lit"] = snappedf(lit, 0.0001)
	_result["night_image_change"] = snappedf(_diff, 0.0001)
	_result["night_bright_pixels_unlit"] = _bright_dark
	_result["night_bright_pixels_lit"] = _bright_lit
	checks["set_lit_lights_signs_and_rooms"] = _bright_lit > maxi(200, int(_bright_dark * 1.5)) and lit > dark
	_conclude()


func _conclude() -> void:
	var checks: Dictionary = _result["checks"]
	var ok := true
	for k: String in checks:
		if not bool(checks[k]):
			ok = false
			(_result["notes"] as Array).append("check failed: " + k)
	_result["pass"] = ok
	_finish()


# --- world ------------------------------------------------------------------------------

func _build_world() -> void:
	_sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	_env.ssr_enabled = not OS.get_cmdline_user_args().has("--no-ssr")
	_env.ssao_enabled = true
	_env.ssil_enabled = true
	_env.glow_enabled = true
	_env.glow_intensity = 0.35
	_env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = _env
	_root.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 220.0
	_root.add_child(_sun)
	# test-only ground: road and pavements along x, and a cross street at the first corner
	var road := StandardMaterial3D.new()
	road.albedo_color = Color(0.09, 0.09, 0.09)
	road.roughness = 0.9
	var pave := StandardMaterial3D.new()
	pave.albedo_color = Color(0.42, 0.41, 0.39)
	pave.roughness = 0.85
	_ground(Vector3(-60.0, -0.14, -ROAD_W / 2.0), Vector3(420.0, -0.13, ROAD_W / 2.0), road)
	for side: float in [-1.0, 1.0]:
		var z0 := side * ROAD_W / 2.0
		var z1 := side * (ROAD_W / 2.0 + PAVE_W)
		_ground(Vector3(-60.0, -0.14, minf(z0, z1)), Vector3(420.0, 0.0, maxf(z0, z1)), pave)
	_ground(Vector3(-60.0, -0.14, -400.0), Vector3(-60.0 + ROAD_W, -0.13, 400.0), road)
	_ground(Vector3(-200.0, -0.14, GALLERY_Z - 40.0), Vector3(200.0, 0.0, GALLERY_Z + 12.0), pave)
	# test-only street lamps (the real ones belong to the streets), lit at dusk and night
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.15, 0.16, 0.17)
	steel.metallic = 0.8
	var led := StandardMaterial3D.new()
	led.albedo_color = Color.BLACK
	led.emission_enabled = true
	led.emission = Color(1.0, 0.88, 0.7)
	led.emission_energy_multiplier = 8.0
	for i: int in 9:
		for side: float in [-1.0, 1.0]:
			var lamp := Node3D.new()
			lamp.position = Vector3(-40.0 + float(i) * 30.0 + (15.0 if side > 0.0 else 0.0), 0.0, side * (ROAD_W / 2.0 + 0.5))
			var pole := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.06
			cyl.bottom_radius = 0.1
			cyl.height = 8.0
			pole.mesh = cyl
			pole.position.y = 4.0
			pole.material_override = steel
			lamp.add_child(pole)
			var head := MeshInstance3D.new()
			var hb := BoxMesh.new()
			hb.size = Vector3(0.7, 0.08, 0.28)
			head.mesh = hb
			head.position = Vector3(0, 8.0, -side * 0.9)
			head.material_override = led
			lamp.add_child(head)
			var arm := MeshInstance3D.new()
			var ab := BoxMesh.new()
			ab.size = Vector3(0.06, 0.06, 1.0)
			arm.mesh = ab
			arm.position = Vector3(0, 8.05, -side * 0.45)
			arm.material_override = steel
			lamp.add_child(arm)
			var light := SpotLight3D.new()
			light.position = Vector3(0, 7.9, -side * 0.9)
			light.rotation.x = deg_to_rad(-90.0)
			light.light_color = Color(1.0, 0.88, 0.7)
			light.light_energy = 18.0
			light.spot_range = 24.0
			light.spot_angle = 70.0
			light.name = "Light"
			lamp.add_child(light)
			_root.add_child(lamp)
			_lamps.append(lamp)


func _ground(lo: Vector3, hi: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = hi - lo
	mi.mesh = bm
	mi.position = (lo + hi) * 0.5
	mi.material_override = mat
	_root.add_child(mi)


func _build_street() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var front := ROAD_W / 2.0 + PAVE_W
	for block: int in 2:
		var start := -60.0 + ROAD_W + 0.0 + float(block) * 190.0
		for side: int in 2:
			var x := start
			for i: int in 10:
				var seed := block * 20 + side * 10 + i + 1
				var w := snappedf(rng.randf_range(15.0, 30.0), 0.5)
				var opts := {"open_neg_x": i == 0 and block == 0 and side == 0}
				var b := CityBuilding.create(w, LOT_DEPTH, seed, opts)
				if side == 0:
					b.position = Vector3(x + w / 2.0, 0.0, -front)
				else:
					b.position = Vector3(x + w / 2.0, 0.0, front)
					b.rotation.y = PI
				_root.add_child(b)
				if block == 0:
					_street.append(b)
					_lots.append({"seed": seed, "x0": x, "w": w, "side": side})
				else:
					_far_block.append(b)
				x += w


func _build_gallery() -> void:
	var x := -150.0
	for st: String in CityBuilding.STYLES:
		var b := CityBuilding.create(24.0, LOT_DEPTH, 100 + CityBuilding.STYLES.find(st), {"style": st, "open_pos_x": true})
		b.position = Vector3(x, 0.0, GALLERY_Z)
		_root.add_child(b)
		_gallery[st] = b
		x += 60.0
	var ob := CityBuilding.create(20.0, LOT_DEPTH, 200, {"style": "brick", "open_neg_x": true, "open_pos_x": true, "open_back": true, "floors": 4})
	ob.position = Vector3(x + 20.0, 0.0, GALLERY_Z)
	_root.add_child(ob)
	_gallery["open_all"] = ob


# --- checks -----------------------------------------------------------------------------

func _check_api() -> void:
	var checks: Dictionary = _result["checks"]
	var all: Array[CityBuilding] = []
	all.append_array(_street)
	all.append_array(_far_block)
	for st: String in _gallery:
		all.append(_gallery[st])
	var bounds_ok := true
	var budget_ok := true
	var collision_ok := true
	var max_tris := 0
	var max_surf := 0
	var styles_seen: Dictionary = {}
	var per: Array = []
	var lit_on := 0
	var lit_total := 0
	_vertices_checked = 0
	var vertices_built := 0
	for b: CityBuilding in all:
		vertices_built += int(b.stats["vertices"])
		var why := _bounds_problem(b)
		if why != "":
			bounds_ok = false
			(_result["notes"] as Array).append("%s: %s" % [b.name, why])
		var tris: int = b.stats["triangles"]
		var surf: int = b.stats["surfaces"]
		max_tris = maxi(max_tris, tris)
		max_surf = maxi(max_surf, surf)
		if tris > 40000 or surf > 10:
			budget_ok = false
		var body := b.get_node_or_null("Collision") as StaticBody3D
		if body == null or body.get_child_count() == 0:
			collision_ok = false
		styles_seen[b.style] = int(styles_seen.get(b.style, 0)) + 1
		per.append({"name": String(b.name), "style": b.style, "floors": b.floors, "w": b.lot_width, "tris": tris, "surfaces": surf, "windows": b.stats["windows"]})
		var share := _lit_share(b)
		lit_on += share.x
		lit_total += share.y
	checks["bounds_within_lot"] = bounds_ok
	# the bounds check read every vertex the generator built (it would pass vacuously on
	# meshes that came back empty)
	_result["bounds_vertices_checked"] = _vertices_checked
	_result["vertices_built"] = vertices_built
	checks["bounds_checked_every_vertex"] = _vertices_checked > 0 and _vertices_checked == vertices_built
	# a colonnade on an open side is a walkway, not an invisible wall
	var col_b := CityBuilding.create(24.0, 30.0, 77, {"style": "brutalist", "open_pos_x": true, "open_back": true})
	var walk_points: Array[Vector3] = [Vector3(12.0 - 1.5, 1.0, -10.0), Vector3(0.0, 1.0, -30.0 + 1.5), Vector3(0.0, 1.0, -1.5)]
	var blocked := 0
	for pt: Vector3 in walk_points:
		if _in_collision(col_b, pt):
			blocked += 1
	checks["colonnade_walkable_on_open_faces"] = blocked == 0 and _in_collision(col_b, Vector3(0.0, 1.0, -15.0))
	col_b.free()
	checks["budget_tris_40k_surfaces_10"] = budget_ok
	checks["collision_present"] = collision_ok
	_result["max_triangles"] = max_tris
	_result["max_surfaces"] = max_surf
	_result["styles_seen"] = styles_seen
	_result["buildings"] = per
	checks["five_or_more_styles"] = styles_seen.size() >= 5
	# determinism: the same arguments give the same vertices; another seed does not
	var a1 := CityBuilding.create(21.0, 30.0, 7, {"open_pos_x": true})
	var a2 := CityBuilding.create(21.0, 30.0, 7, {"open_pos_x": true})
	var a3 := CityBuilding.create(21.0, 30.0, 8, {"open_pos_x": true})
	checks["deterministic_same_seed"] = str(a1.stats["fingerprint"]) == str(a2.stats["fingerprint"])
	checks["different_seed_differs"] = str(a1.stats["fingerprint"]) != str(a3.stats["fingerprint"])
	_sweep()
	var forced := CityBuilding.create(18.0, 30.0, 3, {"style": "midcentury", "floors": 4})
	checks["opts_force_style_and_floors"] = forced.style == "midcentury" and forced.floors == 4
	for n: CityBuilding in [a1, a2, a3, forced]:
		n.free()
	# share of rooms that light at night (offices and homes only)
	var frac := float(lit_on) / maxf(1.0, float(lit_total))
	_result["night_lit_window_share"] = snappedf(frac, 0.001)
	checks["night_lit_share_believable"] = frac > 0.28 and frac < 0.66
	# neighbours differ: no two adjacent lots with the same style and floor count and width
	var copies := 0
	for i: int in range(1, _street.size()):
		var p := _street[i - 1]
		var q := _street[i]
		if p.style == q.style and p.floors == q.floors and absf(p.lot_width - q.lot_width) < 0.6:
			copies += 1
	_result["neighbour_near_copies"] = copies
	checks["neighbours_not_copies"] = copies == 0


## Every style, at the extremes of storeys and lot width, with every combination of open
## sides: built, checked against the lot and the budgets, and freed. No pictures.
func _sweep() -> void:
	var checks: Dictionary = _result["checks"]
	var combos: Array[Dictionary] = [
		{}, {"open_neg_x": true}, {"open_pos_x": true}, {"open_neg_x": true, "open_pos_x": true},
		{"open_back": true}, {"open_neg_x": true, "open_pos_x": true, "open_back": true},
	]
	var n := 0
	var bad: Array[String] = []
	var worst_tris := 0
	var seed := 500
	for st: String in CityBuilding.STYLES:
		for fl: int in [1, 2, 0, 12]:
			for w: float in [15.0, 30.0]:
				for opts: Dictionary in combos:
					var o := opts.duplicate()
					o["style"] = st
					if fl > 0:
						o["floors"] = fl
					seed += 1
					var b := CityBuilding.create(w, LOT_DEPTH, seed, o)
					n += 1
					var why := _bounds_problem(b)
					var tris: int = b.stats["triangles"]
					worst_tris = maxi(worst_tris, tris)
					if why != "":
						bad.append("%s f%d w%.0f %s: %s" % [st, b.floors, w, str(opts.keys()), why])
					elif tris > 40000 or int(b.stats["surfaces"]) > 10:
						bad.append("%s f%d w%.0f %s: budget %d tris" % [st, b.floors, w, str(opts.keys()), tris])
					elif b.get_node_or_null("Collision") == null or b.style != st:
						bad.append("%s f%d w%.0f %s: no collision or wrong style" % [st, b.floors, w, str(opts.keys())])
					b.free()
	_result["sweep_buildings"] = n
	_result["sweep_worst_triangles"] = worst_tris
	_result["sweep_problems"] = bad.slice(0, 12)
	checks["sweep_all_styles_floors_widths_open_sides"] = bad.is_empty()


## True if a building-local point lies inside one of the building's collision boxes.
func _in_collision(b: CityBuilding, p: Vector3) -> bool:
	var body := b.get_node_or_null("Collision") as StaticBody3D
	if body == null:
		return false
	for cs: Node in body.get_children():
		var shape := (cs as CollisionShape3D).shape as BoxShape3D
		if shape != null and AABB((cs as Node3D).position - shape.size * 0.5, shape.size).has_point(p):
			return true
	return false


## Every vertex inside the lot: x within +-w/2 and z within [-depth, 0] below the clear
## height; above it, up to the overhang allowance past the front and any open side.
func _bounds_problem(b: CityBuilding) -> String:
	var hw := b.lot_width / 2.0 + 0.002
	for mi: MeshInstance3D in [b.body_mesh, b.glass_mesh, b.detail_mesh]:
		if mi == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			_vertices_checked += verts.size()
			for v: Vector3 in verts:
				if absf(v.x) > hw:
					# past a side line only where that side faces a street, and only overhead
					var open := b.open_pos_x if v.x > 0.0 else b.open_neg_x
					if not open or v.y < CityBuilding.CLEAR_HEIGHT - 0.001 or absf(v.x) > hw + CityBuilding.OVERHANG:
						return "x %.3f outside lot at y %.2f (%s)" % [v.x, v.y, mi.name]
				if v.z < -b.lot_depth - 0.002:
					if not b.open_back or v.y < CityBuilding.CLEAR_HEIGHT - 0.001 or v.z < -b.lot_depth - CityBuilding.OVERHANG - 0.002:
						return "z %.3f behind lot at y %.2f (%s)" % [v.z, v.y, mi.name]
				if v.y < CityBuilding.CLEAR_HEIGHT - 0.001 and v.z > 0.002:
					return "z %.3f over pavement at y %.2f (%s)" % [v.z, v.y, mi.name]
				if v.z > CityBuilding.OVERHANG + 0.002:
					return "overhang %.3f too far (%s)" % [v.z, mi.name]
				if v.y < -0.01:
					return "below pavement y %.3f" % v.y
	return ""


func _hash11(p: float) -> float:
	p = fposmod(p * 0.1031, 1.0)
	p *= p + 33.33
	p *= p + p
	return fposmod(p, 1.0)


## Counts lit rooms the way the glass shader decides them (x lit, y total).
func _lit_share(b: CityBuilding) -> Vector2i:
	if b.glass_mesh == null:
		return Vector2i.ZERO
	var arr := b.glass_mesh.mesh.surface_get_arrays(0)
	var c0: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
	var c1: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM1]
	var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var on := 0
	var total := 0
	var i := 0
	while i < col.size():           # four vertices per pane
		var kind := roundi(c0[i * 4 + 2])
		if kind == 0 or kind == 1:
			total += 1
			var share := col[i].r * (0.8 if kind == 0 else 1.0)
			if _hash11(c1[i * 4 + 3] * 2.3 + 0.7) < share:
				on += 1
		i += 4
	return Vector2i(on, total)


func _first_style(list: Array[CityBuilding], styles: Array) -> CityBuilding:
	for b: CityBuilding in list:
		if styles.has(b.style) and b.rotation.y == 0.0 and not b.name.ends_with("1"):
			return b
	for b: CityBuilding in list:
		if styles.has(b.style):
			return b
	return null


## A building-local offset turned into world space.
func _dir(b: CityBuilding, local: Vector3) -> Vector3:
	return b.global_basis * local


# --- lighting moods ---------------------------------------------------------------------

func _day() -> void:
	_sun.visible = true
	_sun.rotation_degrees = Vector3(-38.0, -35.0, 0.0)
	_sun.light_color = Color(1.0, 0.96, 0.9)
	_sun.light_energy = 1.4
	_sky_mat.sky_top_color = Color(0.32, 0.48, 0.74)
	_sky_mat.sky_horizon_color = Color(0.70, 0.76, 0.82)
	_sky_mat.ground_horizon_color = Color(0.55, 0.55, 0.55)
	_sky_mat.ground_bottom_color = Color(0.2, 0.2, 0.2)
	_sky_mat.sky_energy_multiplier = 1.0
	_env.ambient_light_energy = 1.0
	_lamps_on(false)
	_set_lit(0.0)


func _dusk() -> void:
	_sun.rotation_degrees = Vector3(-5.0, -70.0, 0.0)
	_sun.light_color = Color(1.0, 0.62, 0.36)
	_sun.light_energy = 0.7
	_sky_mat.sky_top_color = Color(0.12, 0.16, 0.34)
	_sky_mat.sky_horizon_color = Color(0.85, 0.50, 0.32)
	_sky_mat.ground_horizon_color = Color(0.3, 0.22, 0.2)
	_sky_mat.ground_bottom_color = Color(0.05, 0.05, 0.05)
	_sky_mat.sky_energy_multiplier = 0.6
	_lamps_on(true)


func _night() -> void:
	_sun.visible = false
	# an overcast city night: low cloud lit orange-grey by the town, a faint fill on the walls
	_sky_mat.sky_top_color = Color(0.012, 0.014, 0.024)
	_sky_mat.sky_horizon_color = Color(0.07, 0.055, 0.045)
	_sky_mat.ground_horizon_color = Color(0.03, 0.025, 0.02)
	_sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.01)
	_sky_mat.sky_energy_multiplier = 1.0
	_env.ambient_light_energy = 1.6


func _lamps_on(on: bool) -> void:
	for l: Node3D in _lamps:
		(l.get_node("Light") as Light3D).visible = on


func _set_lit(v: float) -> void:
	for b: CityBuilding in _street + _far_block:
		b.set_lit(v)
	for st: String in _gallery:
		(_gallery[st] as CityBuilding).set_lit(v)


# --- capture ----------------------------------------------------------------------------

func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw


## Places the camera, waits for the frame to settle, saves a picture, returns mean luminance.
func _shot(label: String, from: Vector3, at: Vector3, fov: float = 70.0) -> float:
	_cam.fov = fov
	_cam.global_position = from
	_cam.look_at(at, Vector3.UP)
	await _settle(0.7)
	var img := get_viewport().get_texture().get_image()
	_last_img = img
	if Game.out_dir != "":
		DirAccess.make_dir_recursive_absolute(Game.out_dir)
		img.save_png(Game.out_dir.path_join(label + ".png"))
	var sum := 0.0
	var n := 0
	for y: int in range(0, img.get_height(), 8):
		for x: int in range(0, img.get_width(), 8):
			sum += img.get_pixel(x, y).get_luminance()
			n += 1
	return sum / maxf(1.0, float(n))


## Pixels bright enough to read as a light source (signs, lit rooms, lamps).
func _bright_count(img: Image) -> int:
	var n := 0
	for y: int in range(0, img.get_height(), 2):
		for x: int in range(0, img.get_width(), 2):
			if img.get_pixel(x, y).get_luminance() > 0.6:
				n += 1
	return n


func _image_diff(a: Image, b: Image) -> float:
	var sum := 0.0
	var n := 0
	for y: int in range(0, a.get_height(), 6):
		for x: int in range(0, a.get_width(), 6):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			sum += absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)
			n += 3
	return sum / maxf(1.0, float(n))


func _measure_fps(label: String, from: Vector3, at: Vector3) -> void:
	_cam.fov = 70.0
	_cam.global_position = from
	_cam.look_at(at, Vector3.UP)
	# measure without the vertical sync cap, so the number shows the headroom
	var vsync := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _settle(1.0)
	var frames := 0
	var t0 := Time.get_ticks_usec()
	var worst := 0.0
	var last := t0
	while Time.get_ticks_usec() - t0 < 2000000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
		frames += 1
	var secs := float(Time.get_ticks_usec() - t0) / 1000000.0
	DisplayServer.window_set_vsync_mode(vsync)
	_result[label] = {
		"fps": snappedf(float(frames) / secs, 0.1),
		"worst_frame_ms": snappedf(worst, 0.1),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
	}


func _finish() -> void:
	if Game.out_dir != "":
		DirAccess.make_dir_recursive_absolute(Game.out_dir)
		var f := FileAccess.open(Game.out_dir.path_join("result.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(_result, "  "))
		f.close()
	print("AUTO pass=", _result["pass"])
	get_tree().quit(0)
