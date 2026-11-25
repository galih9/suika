class_name FruitPool
extends Node

## Pre-warmed object pool for Fruit bodies with O(1) acquire, release, and 1-frame quarantine.

const INITIAL_POOL_SIZE := 32

var fruits_container: Node2D
var active_fruits: Array[Fruit] = []
var _free_list: Array[Fruit] = []
var _quarantine_list: Array[Fruit] = []
var _contact_callback: Callable
var _sticky_callback: Callable
var _charged_callback: Callable
var _pre_release_callback: Callable


func initialize(
	container: Node2D,
	contact_callback: Callable,
	sticky_callback: Callable = Callable(),
	charged_callback: Callable = Callable(),
	pre_release_callback: Callable = Callable()
) -> void:
	fruits_container = container
	_contact_callback = contact_callback
	_sticky_callback = sticky_callback
	_charged_callback = charged_callback
	_pre_release_callback = pre_release_callback
	for i in range(INITIAL_POOL_SIZE):
		var fruit := _create_fruit()
		_free_list.append(fruit)


func _create_fruit() -> Fruit:
	var fruit := Fruit.new()
	fruit.deactivate_to_pool()
	if _contact_callback.is_valid():
		fruit.merge_contact.connect(_contact_callback)
	if _sticky_callback.is_valid():
		fruit.sticky_contact.connect(_sticky_callback)
	if _charged_callback.is_valid():
		fruit.charged_bounced.connect(_charged_callback)
	if fruits_container != null:
		fruits_container.add_child(fruit)
	return fruit


func acquire() -> Fruit:
	var fruit: Fruit
	if _free_list.is_empty():
		fruit = _create_fruit()
	else:
		fruit = _free_list.pop_back()
	fruit.in_pool = false
	fruit.pool_index = active_fruits.size()
	active_fruits.append(fruit)
	return fruit


func release(fruit: Fruit) -> void:
	if fruit == null or fruit.in_pool:
		return
	if _pre_release_callback.is_valid():
		_pre_release_callback.call(fruit)
	fruit.deactivate_to_pool()
	var idx := fruit.pool_index
	var last_idx := active_fruits.size() - 1
	if idx >= 0 and idx <= last_idx:
		if idx != last_idx:
			var swapped := active_fruits[last_idx]
			active_fruits[idx] = swapped
			swapped.pool_index = idx
		active_fruits.pop_back()
	fruit.pool_index = -1
	_quarantine_list.append(fruit)


func flush_quarantine() -> void:
	if _quarantine_list.is_empty():
		return
	for fruit in _quarantine_list:
		_free_list.append(fruit)
	_quarantine_list.clear()


func release_all() -> void:
	while not active_fruits.is_empty():
		var fruit := active_fruits[active_fruits.size() - 1]
		release(fruit)
	flush_quarantine()


func get_total_allocated() -> int:
	return active_fruits.size() + _free_list.size() + _quarantine_list.size()
