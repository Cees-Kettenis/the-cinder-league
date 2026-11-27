extends Control
## Draws a small pile and transfers a few representative coins as the result settles.

const Symbol = preload("res://game/screens/ui_symbol.gd")
const COINS := 5
const FIRST_COIN := .06
const COIN_GAP := .105
const FLIGHT_TIME := .48
const DURATION := FIRST_COIN + (COINS - 1) * COIN_GAP + FLIGHT_TIME + .02

var elapsed := 0.0:
	set(value):
		elapsed = value
		queue_redraw()
var _gaining: bool
var _start_layers: int
var _end_layers: int

func _init(before: int, after: int) -> void:
	custom_minimum_size = Vector2(40, 38)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1
	_gaining = after > before
	_start_layers = 0 if before == 0 else (3 if _gaining else 6)
	_end_layers = 0 if after == 0 else (6 if _gaining else 3)

func transfer_fraction() -> float:
	# Money changes when a won coin hits the pile or a lost coin leaves it.
	var transferred_at := FIRST_COIN + (FLIGHT_TIME if _gaining else 0.0)
	return float(clampi(1 + floori((elapsed - transferred_at) / COIN_GAP), 0, COINS)) / COINS

func _draw() -> void:
	var ground := Vector2(size.x * .5, size.y * .76)
	var layers := roundi(lerpf(_start_layers, _end_layers, transfer_fraction()))
	for layer in layers:
		_draw_coin(ground - Vector2(0, layer * 3.15), 11.5, 0.0, .34, 1.0)
	for index in COINS:
		var travel := (elapsed - FIRST_COIN - index * COIN_GAP) / FLIGHT_TIME
		if travel <= 0.0 or travel >= 1.0:
			continue
		var completed := float(index) / COINS if _gaining else float(index + 1) / COINS
		var top := maxf(0.0, lerpf(_start_layers, _end_layers, completed) - .6)
		var pile := ground - Vector2(0, top * 3.15)
		var drift := (float(index) - 2.0) * 9.0
		var point: Vector2
		if _gaining:
			point = pile + Vector2(drift * (1.0 - travel), -41.0 * (1.0 - travel * travel))
		else:
			point = pile + Vector2(drift * sqrt(travel), 58.0 * travel * travel - 8.0 * travel)
		var flatness := lerpf(.25, .93, absf(cos((travel * 1.4 + index * .13) * TAU)))
		var opacity := smoothstep(0.0, .14, travel) if _gaining else 1.0 - smoothstep(.57, 1.0, travel)
		_draw_coin(point, 8.1, drift * .028 * sin(PI * travel), flatness, opacity)

func _draw_coin(at: Vector2, radius: float, rotation: float, tilt: float, opacity: float) -> void:
	draw_set_transform(at, rotation, Vector2(1, tilt))
	draw_circle(Vector2(0, 2.5), radius, Color("#a9602d", opacity), true)
	draw_circle(Vector2.ZERO, radius, Color(Symbol.GOLD, opacity), true)
	draw_arc(Vector2.ZERO, radius * .69, 0, TAU, 18, Color("#ae6d31", opacity), 1.3, true)
	draw_arc(Vector2.ZERO, radius * .88, 3.4, 5.0, 9, Color(Symbol.CREAM, opacity), 1.2, true)
	draw_set_transform(Vector2.ZERO)
