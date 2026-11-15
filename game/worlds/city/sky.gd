class_name CitySky
extends Node3D
## Sky, sun, moon, ambient light and haze, all driven by one number: the hour of the day (0 to 24).
## The sun follows a real path for a river port at 38.6 degrees north in late spring; a solar noon of 12.9
## puts golden hour near 18.8, dusk near 19.6 and full night after 21. Owns the WorldEnvironment.

signal night_changed(amount: float)

const LATITUDE: float = 38.6
const DECLINATION: float = 10.0
const SOLAR_NOON: float = 12.9
const MOON_LAG: float = 9.6          # the moon stands where the sun stood this many hours earlier
const MOON_DECLINATION: float = -4.0
const ADVANCE_RATE: float = 0.8      # hours per second when time is moved forward

## Keyframes by sun elevation (degrees): sky zenith and horizon colour, sunlight colour and energy, exposure.
const KEYS: Array = [
	[-90.0, Vector3(0.0009, 0.0013, 0.0028), Vector3(0.0040, 0.0036, 0.0036), Vector3(1.0, 0.4, 0.2), 0.0, 1.7],
	[-18.0, Vector3(0.0010, 0.0014, 0.0030), Vector3(0.0045, 0.0040, 0.0040), Vector3(1.0, 0.4, 0.2), 0.0, 1.7],
	[-10.0, Vector3(0.0030, 0.0050, 0.0120), Vector3(0.0180, 0.0130, 0.0110), Vector3(1.0, 0.4, 0.2), 0.0, 1.65],
	[-5.0, Vector3(0.0120, 0.0200, 0.0500), Vector3(0.0900, 0.0550, 0.0400), Vector3(1.0, 0.4, 0.2), 0.0, 1.5],
	[-2.0, Vector3(0.0300, 0.0500, 0.1200), Vector3(0.3000, 0.1600, 0.0900), Vector3(1.0, 0.42, 0.2), 0.0, 1.3],
	[0.0, Vector3(0.0500, 0.0850, 0.2000), Vector3(0.6000, 0.3200, 0.1500), Vector3(1.0, 0.45, 0.2), 0.35, 1.3],
	[4.0, Vector3(0.0700, 0.1300, 0.3100), Vector3(0.8500, 0.5300, 0.3000), Vector3(1.0, 0.62, 0.34), 0.9, 1.15],
	[10.0, Vector3(0.0850, 0.1700, 0.4200), Vector3(0.7800, 0.6600, 0.5400), Vector3(1.0, 0.80, 0.58), 1.35, 1.05],
	[25.0, Vector3(0.0900, 0.2000, 0.5200), Vector3(0.6200, 0.6800, 0.7600), Vector3(1.0, 0.93, 0.84), 1.4, 0.95],
	[60.0, Vector3(0.0950, 0.2200, 0.5800), Vector3(0.5800, 0.6700, 0.7900), Vector3(1.0, 0.97, 0.92), 1.45, 0.95],
	[90.0, Vector3(0.0950, 0.2200, 0.5800), Vector3(0.5800, 0.6700, 0.7900), Vector3(1.0, 0.97, 0.92), 1.45, 0.95],
]

var hour: float = 12.0: set = set_hour
var night: float = -1.0              ## 0 by day, 1 at night
var sun_elevation: float = 0.0       ## degrees
var environment: Environment
var key_light: DirectionalLight3D    ## the sun by day, the moon by night
var _sky_mat: ShaderMaterial
var _target: float = -1.0


func _init() -> void:
	name = "Sky"


func _ready() -> void:
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://worlds/city/shaders/sky_city.gdshader") as Shader
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_sky_contribution = 1.0
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.6
	environment.ssr_enabled = true
	environment.ssr_max_steps = 56
	environment.ssr_fade_in = 0.1
	environment.ssr_fade_out = 2.0
	environment.ssr_depth_tolerance = 0.3
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.2
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_sky_affect = 0.0
	environment.fog_sun_scatter = 0.25
	# Volumetric fog only after dark, lit only by the street lamps: halos and cones in the damp air.
	environment.volumetric_fog_density = 0.0
	environment.volumetric_fog_length = 80.0
	environment.volumetric_fog_detail_spread = 2.0
	environment.volumetric_fog_ambient_inject = 0.0
	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)
	key_light = DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.shadow_enabled = true
	key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	key_light.directional_shadow_max_distance = 140.0
	key_light.shadow_bias = 0.03
	key_light.shadow_normal_bias = 1.2
	key_light.shadow_blur = 1.2
	key_light.light_volumetric_fog_energy = 0.0
	add_child(key_light)
	_apply()


func set_hour(value: float) -> void:
	hour = fposmod(value, 24.0)
	if is_inside_tree() and environment != null:
		_apply()


## Move the clock forward smoothly (one press of the time key is one hour).
func advance(hours: float) -> void:
	if _target < 0.0:
		_target = hour
	_target += hours


func _process(delta: float) -> void:
	if _target < 0.0:
		return
	var step := minf(ADVANCE_RATE * delta, _target - hour)
	if step <= 0.0001:
		hour = _target
		_target = -1.0
		return
	hour = hour + step
	if _target >= 24.0 and hour < 1.0:
		_target -= 24.0


## Direction toward a body on the sky for a given hour angle and declination (+X east, -Z north).
static func sky_direction(hours_from_noon: float, declination: float) -> Vector3:
	var lat := deg_to_rad(LATITUDE)
	var dec := deg_to_rad(declination)
	var ha := deg_to_rad(hours_from_noon * 15.0)
	var sin_el := sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(ha)
	var el := asin(clampf(sin_el, -1.0, 1.0))
	var cos_az := (sin(dec) - sin(el) * sin(lat)) / maxf(cos(el) * cos(lat), 1e-5)
	var az := acos(clampf(cos_az, -1.0, 1.0))
	if ha > 0.0:
		az = TAU - az
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el)).normalized()


func sun_direction() -> Vector3:
	return sky_direction(hour - SOLAR_NOON, DECLINATION)


func moon_direction() -> Vector3:
	return sky_direction(hour - SOLAR_NOON - MOON_LAG, MOON_DECLINATION)


func _sample(e: float) -> Array:
	for k: int in KEYS.size() - 1:
		var a: Array = KEYS[k]
		var b: Array = KEYS[k + 1]
		if e <= b[0]:
			var t := clampf((e - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
			t = t * t * (3.0 - 2.0 * t)
			return [
				(a[1] as Vector3).lerp(b[1], t), (a[2] as Vector3).lerp(b[2], t), (a[3] as Vector3).lerp(b[3], t),
				lerpf(a[4], b[4], t), lerpf(a[5], b[5], t),
			]
	var last: Array = KEYS[KEYS.size() - 1]
	return [last[1], last[2], last[3], last[4], last[5]]


func _apply() -> void:
	var sun := sun_direction()
	var moon := moon_direction()
	sun_elevation = rad_to_deg(asin(sun.y))
	var k := _sample(sun_elevation)
	var zenith: Vector3 = k[0]
	var horizon: Vector3 = k[1]
	var sun_col: Vector3 = k[2]
	var sun_energy: float = k[3]
	var exposure: float = k[4]
	var amount := clampf((2.0 - sun_elevation) / 9.0, 0.0, 1.0)
	amount = amount * amount * (3.0 - 2.0 * amount)
	var moon_up := clampf(moon.y * 6.0, 0.0, 1.0)

	_sky_mat.set_shader_parameter("sun_dir", sun)
	_sky_mat.set_shader_parameter("moon_dir", moon)
	_sky_mat.set_shader_parameter("zenith_col", zenith)
	_sky_mat.set_shader_parameter("horizon_col", horizon)
	_sky_mat.set_shader_parameter("sun_col", sun_col)
	_sky_mat.set_shader_parameter("sun_disc", 40.0 * clampf(sun_elevation + 1.0, 0.0, 1.0))
	_sky_mat.set_shader_parameter("glow", clampf((sun_elevation + 6.0) / 6.0, 0.0, 1.0))
	_sky_mat.set_shader_parameter("night", amount)
	_sky_mat.set_shader_parameter("stars", clampf((-sun_elevation - 6.0) / 8.0, 0.0, 1.0))
	_sky_mat.set_shader_parameter("moon_bright", 1.6 * amount * moon_up)
	# Cloud light: sunlit by day, coloured by the low sun, faintly lit by moon and town at night.
	var day := clampf((sun_elevation + 4.0) / 14.0, 0.0, 1.0)
	var lit := Vector3(1.0, 0.97, 0.93).lerp(sun_col, 0.6) * (0.25 + 0.95 * day)
	lit = lit * clampf((sun_elevation + 6.0) / 8.0, 0.02, 1.0)
	var shade := horizon.lerp(zenith, 0.4) * 0.9 + Vector3(0.02, 0.02, 0.025) * day
	_sky_mat.set_shader_parameter("cloud_lit", lit)
	_sky_mat.set_shader_parameter("cloud_shade", shade)

	# The key light is the sun until it has set, then the moon.
	var moon_energy := 0.06 * moon_up * clampf((-sun_elevation - 3.0) / 6.0, 0.0, 1.0)
	if sun_energy > 0.0 or sun_elevation > -3.0:
		key_light.global_basis = Basis.looking_at(-sun, Vector3.UP if absf(sun.y) < 0.99 else Vector3.FORWARD)
		key_light.light_color = Color(sun_col.x, sun_col.y, sun_col.z)
		key_light.light_energy = sun_energy
	else:
		key_light.global_basis = Basis.looking_at(-moon, Vector3.UP if absf(moon.y) < 0.99 else Vector3.FORWARD)
		key_light.light_color = Color(0.62, 0.72, 1.0)
		key_light.light_energy = moon_energy
	key_light.visible = key_light.light_energy > 0.001
	key_light.light_angular_distance = 0.5

	environment.ambient_light_energy = 1.0
	environment.tonemap_exposure = exposure
	var fog := horizon.lerp(zenith, 0.25)
	environment.fog_light_color = Color(fog.x, fog.y, fog.z)
	environment.fog_light_energy = 1.0
	environment.fog_density = lerpf(0.0022, 0.0045, amount)
	environment.glow_hdr_threshold = lerpf(1.2, 0.9, amount)
	environment.volumetric_fog_enabled = amount > 0.15
	environment.volumetric_fog_density = lerpf(0.0, 0.0022, clampf((amount - 0.15) / 0.85, 0.0, 1.0))

	if absf(amount - night) > 0.004 or (amount != night and (amount == 0.0 or amount == 1.0)):
		night = amount
		night_changed.emit(night)
