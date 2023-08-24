extends Spatial


const MOUSE_RAY_LENGTH: float = 20.0
const SEE_THROUGH_ROTATION_DIFF: float = 10.0
const MAGNET_SIZE := Vector2(3, 2)

const INITIAL_STATE = {
	"strength": 20.0,
	"rotation": 0.0,
	"size": 3.5,
	"zoom": 1.0,
	"active_area": 0,
}

onready var magnet_rotate := $MagnetRotate
onready var magnet := $MagnetRotate/Magnet
onready var ui: BaseUI
onready var area_loop := $MagnetRotate/Magnet/Loop
onready var area_square := $MagnetRotate/Magnet/Square
onready var areas = [area_loop, area_square]

var current_strength: float = INITIAL_STATE.strength
var current_rotation: float = INITIAL_STATE.rotation
var current_size: float = INITIAL_STATE.size
var current_zoom: float = INITIAL_STATE.zoom
var area_selected: bool = false
var active_area: int = INITIAL_STATE.active_area setget set_active_area
var area_outside_amount: float = 0.0


func _ready() -> void:
	var use_simple_ui := false
	# check command line arguments
	var arguments = {}
	for argument in OS.get_cmdline_args():
		if argument.find("=") > -1:
			var key_value = argument.split("=")
			arguments[key_value[0].lstrip("--")] = key_value[1]
		else:
			# Options without an argument will be present in the dictionary,
			# with the value set to an empty string.
			arguments[argument.lstrip("--")] = ""
	if "simpleui" in arguments:
		use_simple_ui = true
	# check arguments to web build
	if OS.has_feature("JavaScript"):
		var mode = JavaScript.eval("""
			var url_string = window.location.href;
			var url = new URL(url_string);
			url.searchParams.get("mode")
		""")
		if mode != null:
			if mode == "simple":
				use_simple_ui = true
	$DefaultUI.hide()
	$SimpleUI.hide()
	if !use_simple_ui:
		ui = $DefaultUI
		$SimpleUI.queue_free()
	else:
		ui = $SimpleUI
		$DefaultUI.queue_free()
	ui.show()
	
	set_active_area(active_area)
	ui.field_strength = current_strength
	magnet.set_field_strength(current_strength)
	magnet.see_through = Vector2.ZERO
	ui.set_area_size(current_size)
	update_power()
	
	var screen_scale = OS.get_screen_scale()
	# currently no proper hidpi support on linux
	if OS.get_name() == "X11":
		var dpi = OS.get_screen_dpi(OS.get_current_screen())
		screen_scale = dpi / 121.0
		if !is_equal_approx(1.0, screen_scale):
			OS.set_window_size(OS.get_window_size() * screen_scale)
	get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_DISABLED, SceneTree.STRETCH_ASPECT_IGNORE, Vector2(600, 600), screen_scale)


func _process(_delta):
	if ui.showing_hints:
		var camera := get_viewport().get_camera()
		ui.area_pos_2d = camera.unproject_position(get_active_area().global_translation)
		ui.magnet_corner_pos_2d = camera.unproject_position(magnet.to_global(Vector3(-1.4, 0.7, 1)))


func get_active_area() -> MeasurementArea:
	return areas[active_area]


func set_active_area(value: int) -> void:
	var old_area = get_active_area()
	active_area = value
	for area in areas:
		area.active = false
		area.size = current_size * 0.01
	var area = get_active_area()
	area.transform = old_area.transform
	# for some reason rotation is not set when setting the transform
	# so we need to copy that separately
	area.rot = old_area.rot
	area.squish_amount = old_area.squish_amount
	area.active = true
	ui.set_visible_area_type(area.get_area_type())


func calculate_flux(field_strength: float) -> float:
	var area_normal := Vector3(0, 1, 0)
	area_normal = area_normal.rotated(Vector3.BACK, deg2rad(current_rotation))
	area_normal = area_normal.normalized()
	var field_normal := Vector3.UP
	var amount: float = area_normal.dot(field_normal)
	var area: float = get_active_area().calc_area()
	# field_strength is in mT
	return field_strength * 0.001 * area * amount


func update_power() -> void:
	var flux := calculate_flux(current_strength) * (1.0 - area_outside_amount)
	ui.power = flux


func _on_UI_change_field_strength(strength) -> void:
	current_strength = strength
	magnet.set_field_strength(strength)
	update_power()


func rotate_area(rotation: float) -> void:
	var area := get_active_area()
	# adjust rotation to be between 0 and 360 degrees
	if rotation < 0:
		rotation += float((int(abs(rotation)) / 360 + 1) * 360)
	if rotation >= 360:
		rotation -= float((int(rotation) / 360) * 360)
	current_rotation = rotation
	area.rot = current_rotation
	area.move_and_collide(Vector3.ZERO)
	ui.area_rotation = current_rotation
	update_magnet_area_pos()
	update_area_partial_outside_amount()
	update_power()


func _on_UI_rotate_area_to(value: float) -> void:
	value = round(value)
	rotate_area(value)


func rotate_magnet(value: Vector2) -> void:
	# rotate magnet
	magnet.rotation_degrees.y += value.x
	magnet_rotate.rotation_degrees.x = clamp(magnet_rotate.rotation_degrees.x + value.y, -100, 80)
	# make top or bottom part see-through
	var rotate_see_through_top = clamp(abs(80 - magnet_rotate.rotation_degrees.x), 0, SEE_THROUGH_ROTATION_DIFF)
	var see_through_top: float = 0
	if rotate_see_through_top <= 0:
		see_through_top = 1
	else:
		var see_through_amount: float = 1.0 - rotate_see_through_top / SEE_THROUGH_ROTATION_DIFF
		see_through_top = see_through_amount
	var rotate_see_through_bot = clamp(abs(-100 - magnet_rotate.rotation_degrees.x), 0, SEE_THROUGH_ROTATION_DIFF)
	var see_through_bot: float = 0
	if rotate_see_through_bot <= 0:
		see_through_bot = 1
	else:
		var see_through_amount: float = 1.0 - rotate_see_through_bot / SEE_THROUGH_ROTATION_DIFF
		see_through_bot = see_through_amount
	magnet.see_through = Vector2(see_through_top, see_through_bot)
	# squish area if needed
	var max_see_through_amount: float = max(see_through_top, see_through_bot)
	var area := get_active_area()
	area.squish_amount = max_see_through_amount


func move_area_by(diff: Vector3) -> void:
	var area := get_active_area()
	var t: Vector3 = area.translation
	var target := t + diff
	target.x = clamp(target.x, -(MAGNET_SIZE.x * 0.5 + 1), MAGNET_SIZE.x * 0.5 + 1)
	target.y = clamp(target.y, -0.7, 0.7)
	target.z = clamp(target.z, -(MAGNET_SIZE.y * 0.5 + 1), MAGNET_SIZE.y * 0.5 + 1)
	area.move_and_collide(target - t)
	update_magnet_area_pos()
	update_area_partial_outside_amount()
	update_power()


func change_area_size(size: float) -> void:
	var area := get_active_area()
	current_size = size
	var s: float = size * 0.01
	area.size = s
	area.move_and_collide(Vector3.ZERO)
	update_magnet_area_pos()
	update_area_partial_outside_amount()
	update_power()


func _on_UI_change_area_size(size: float) -> void:
	change_area_size(size)


func update_mouse_target() -> void:
	# find out what the user wants to interact with,
	# the magnet or the area
	var camera := get_viewport().get_camera()
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_from := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos) 
	var ray_to := ray_from + ray_dir * MOUSE_RAY_LENGTH
	var space_state := get_world().direct_space_state
	# only check for intersections on layer 2 and 3 (mask for those layers is 6)
	# these layers contain the area and the top and bottom halves of the magnet
	var layer_mask: int = 6
	if max(magnet.see_through.x, magnet.see_through.y) > 0.5:
		# if the magnet is invisible, ignore it
		layer_mask = 2
	var selection := space_state.intersect_ray(ray_from, ray_to, [], layer_mask, true, true)
	if selection.empty():
		# intersecting with nothing -> rotate the magnet
		area_selected = false
	else:
		# intersecting with something -> check if this is the area
		if selection.rid == get_active_area().get_collision_rid():
			# intersecting with the area -> move the area
			area_selected = true
		else:
			# intersecting with something else -> rotate the magnet
			area_selected = false


func reset_mouse_target() -> void:
	area_selected = false


func update_magnet_area_pos() -> void:
	magnet.area_pos_y = get_active_area().translation.y


func update_area_partial_outside_amount() -> void:
	# this assumes a rectangular area
	
	# calculate rotation amount
	var area_normal := Vector3(0, 1, 0)
	area_normal = area_normal.rotated(Vector3.BACK, deg2rad(current_rotation))
	area_normal = area_normal.normalized()
	var field_normal := Vector3.UP
	var rotation_amount: float = abs(area_normal.dot(field_normal))
	
	var area := get_active_area()
	# convert from centimeters to space units
	var size: float = area.size * 10.0
	var left_outside: float = (-(area.translation.x - size * rotation_amount + MAGNET_SIZE.x * 0.5)) / (size * rotation_amount) * 0.5
	var right_outside: float = (area.translation.x + size * rotation_amount - MAGNET_SIZE.x * 0.5) / (size * rotation_amount) * 0.5
	var front_outside: float = (area.translation.z + size - MAGNET_SIZE.y * 0.5) / size * 0.5
	var back_outside: float = (-(area.translation.z - size + MAGNET_SIZE.y * 0.5)) / size * 0.5
	left_outside = clamp(left_outside, 0, 1)
	right_outside = clamp(right_outside, 0, 1)
	front_outside = clamp(front_outside, 0, 1)
	back_outside = clamp(back_outside, 0, 1)
	var left: bool = left_outside > 0
	var right: bool = right_outside > 0
	var front: bool = front_outside > 0
	var back: bool = back_outside > 0
	
	var inside: float = 1.0
	
	if left || right || front || back:
		if left:
			inside *= 1.0 - left_outside
		if right:
			inside *= 1.0 - right_outside
		if front:
			inside *= 1.0 - front_outside
		if back:
			inside *= 1.0 - back_outside
	
	var outside = 1.0 - inside
	
	area_outside_amount = clamp(outside, 0, 1)


func _on_UI_update_mouse_target() -> void:
	update_mouse_target()


func _on_UI_reset_mouse_target():
	reset_mouse_target()


func _on_UI_mouse_moved(diff: Vector2, pos: Vector2) -> void:
	if area_selected:
		# move area on a plane that is parallel to the camera
		# / move it by the distance the cursor has travelled
		var area := get_active_area()
		var camera := get_viewport().get_camera()
		var cam_pos := camera.global_translation
		var cam_trans := camera.global_transform
		var to_area: Vector3 = area.global_translation - cam_pos
		var area_plane_dist := abs(cam_trans.basis.z.dot(to_area))
		var plane := Plane(cam_trans.basis.z, -area_plane_dist)
		var from := plane.intersects_ray(Vector3.ZERO, camera.project_ray_normal(pos))
		var to := plane.intersects_ray(Vector3.ZERO, camera.project_ray_normal(pos + diff))
		if from != null && to != null:
			var diff3d := to - from
			move_area_by(diff3d)
	else:
		rotate_magnet(diff / 10.0)


func _on_UI_reset_state() -> void:
	var tween := $MagnetRotate/TweenMagnet
	# reset parameters
	current_strength = INITIAL_STATE.strength
	current_rotation = INITIAL_STATE.rotation
	current_size = INITIAL_STATE.size
	set_zoom(INITIAL_STATE.zoom)
	# reset area type
	if active_area != INITIAL_STATE.active_area:
		set_active_area(INITIAL_STATE.active_area)
	# reset area position, rotation and size
	var area := get_active_area()
	tween.interpolate_property(area, "translation", area.translation, Vector3.ZERO, 0.1, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_property(area, "rot", area.rot, current_rotation, 0.1, Tween.TRANS_SINE, Tween.EASE_OUT)
	area.size = current_size * 0.01
	area.squish_amount = 0
	magnet.area_pos_y = 0
	area_outside_amount = 0
	# reset magnet rotation
	tween.interpolate_property(magnet, "rotation_degrees", magnet.rotation_degrees, Vector3.ZERO, 0.1, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_property(magnet_rotate, "rotation_degrees", magnet_rotate.rotation_degrees, Vector3.ZERO, 0.1, Tween.TRANS_SINE, Tween.EASE_OUT)
	# reset magnet transparency
	magnet.see_through = Vector2.ZERO
	# reset magnet field strength
	magnet.set_field_strength(current_strength)
	# calculate new power value
	update_power()
	# update remaining ui
	ui.field_strength = current_strength
	ui.area_rotation = current_rotation
	ui.area_size = current_size
	ui.on_reset()
	tween.start()


func _on_UI_zoom(amount) -> void:
	if !area_selected:
		set_zoom(current_zoom + amount)
	else:
		# move area closer to / further away from the camera
		var area := get_active_area()
		var camera := get_viewport().get_camera()
		var to_area: Vector3 = area.global_translation - camera.global_translation
		var move: Vector3 = to_area.normalized() * amount
		move_area_by(move)


func set_zoom(amount: float) -> void:
	current_zoom = clamp(amount, 0.5, 2)
	var current_pos: Vector3 = $Camera.translation
	var target_pos: Vector3 = Vector3(0, 0.5, 2.5) * current_zoom
	var tween = $Camera/Tween
	tween.interpolate_property($Camera, "translation", current_pos, target_pos, 0.1, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()


func _on_UI_change_area_type():
	var next_active_area = (active_area + 1) % areas.size()
	set_active_area(next_active_area)
	update_power()
